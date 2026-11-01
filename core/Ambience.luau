--!strict
-- 환경음: 바람·차 소리·새·풀벌레처럼 계속 깔리는 소리와 울림 구역. 클라이언트 전용, Place가 데이터만 넘긴다.
-- 소리는 모두 이 클라이언트에만 만든다 (시간대가 방문자마다 다르고, 스트리밍으로 서버 파트가 빠져도 소리는 남게).
-- 레이어마다 기본 크기 × 높이 배율 × 해 높이 배율을 FADE초에 걸쳐 따라가고, 0이 되면 멈춰 동시 재생 수를 아낀다.
--   높이: 듣는 위치(캐릭터, 없으면 카메라)의 지면(Y = 0) 위 높이(m).
--   해 높이: Lighting:GetSunDirection().Y. core TimeOfDay가 방문자 화면 시각("지금/노을/밤")으로 맞춘 값이다(ADR 0007).
-- 전체 크기는 SoundService의 SoundGroup "Ambience" 하나가 쥔다. Studio에 미리 두면 그 값을 그대로 쓴다.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Units = require(script.Parent.Units)

-- { {x, 배율}, ... } x 오름차순. 사이는 직선, 바깥은 끝값
export type Curve = { { number } }

export type Layer = {
	id: number, -- 오디오 에셋 ID
	volume: number, -- 기본 크기 (Sound.Volume)
	byHeight: Curve?, -- 듣는 위치 높이(m) → 배율
	bySun: Curve?, -- 해 높이(-1~1) → 배율
	sway: number?, -- 반복감을 줄이는 느린 흔들림. 크기 ±sway, 재생 속도 ±sway/5
	line: { Vector3 }?, -- 세계 좌표(스터드) 꺾은선. 있으면 듣는 위치에서 가장 가까운 점에서 3D로 울린다
	rolloff: { number }?, -- line 소리의 { 최소, 최대 } 거리(m). 최소 거리 안은 그대로, 밖은 거리에 반비례로 준다
}

-- 울림 구역: 안에 들어서면 SoundService.AmbientReverb를 바꾼다 (발소리까지 울린다)
export type Zone = { cframe: CFrame, size: Vector3, reverb: Enum.ReverbType }

export type Config = { volume: number, layers: { [string]: Layer }, zones: { Zone }? }

local FADE = 4 -- 초. TimeOfDay 색조 전환과 같은 길이

local Ambience = {}

function Ambience.curve(c: Curve, x: number): number
	if x <= c[1][1] then
		return c[1][2]
	end
	for i = 2, #c do
		local a, b = c[i - 1], c[i]
		if x <= b[1] then
			return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
		end
	end
	return c[#c][2]
end
assert(Ambience.curve({ { 0, 0 }, { 10, 1 } }, 5) == 0.5 and Ambience.curve({ { 0, 0 }, { 10, 1 } }, 20) == 1, "curve 보간이 틀렸다")

-- 꺾은선 위에서 p에 가장 가까운 점
function Ambience.nearest(line: { Vector3 }, p: Vector3): Vector3
	local best, bestD = line[1], math.huge
	for i = 2, #line do
		local a, b = line[i - 1], line[i]
		local ab = b - a
		local q = a + ab * math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		local d = (q - p).Magnitude
		if d < bestD then
			best, bestD = q, d
		end
	end
	return best
end
assert(Ambience.nearest({ Vector3.zero, Vector3.new(10, 0, 0) }, Vector3.new(4, 0, 3)) == Vector3.new(4, 0, 0), "nearest가 틀렸다")

local function listener(): Vector3
	local character = (Players.LocalPlayer :: Player).Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else workspace.CurrentCamera.CFrame.Position
end

local function inside(z: Zone, p: Vector3): boolean
	local q = z.cframe:PointToObjectSpace(p)
	return math.abs(q.X) <= z.size.X / 2 and math.abs(q.Y) <= z.size.Y / 2 and math.abs(q.Z) <= z.size.Z / 2
end

-- 클라이언트에서 한 번 부른다
function Ambience.start(config: Config)
	local group = SoundService:FindFirstChild("Ambience") :: SoundGroup?
	if not group then
		local g = Instance.new("SoundGroup")
		g.Name = "Ambience"
		g.Volume = config.volume
		g.Parent = SoundService
		group = g
	end

	type Live = { layer: Layer, sound: Sound, emitter: Attachment?, gain: number, seed: number }
	local live: { Live } = {}
	for name, layer in config.layers do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = `rbxassetid://{layer.id}`
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = group
		local emitter: Attachment? = nil
		if layer.line then
			local a = Instance.new("Attachment") -- Terrain 밑 Attachment = 파트 없는 3D 소리 자리
			a.Name = `Ambience_{name}`
			a.WorldPosition = Ambience.nearest(layer.line, listener())
			a.Parent = workspace.Terrain
			local r = layer.rolloff or { 10, 150 }
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = Units.studs(r[1])
			s.RollOffMaxDistance = Units.studs(r[2])
			s.Parent = a
			emitter = a
		else
			s.Parent = SoundService -- 파트 밖 소리 = 위치 없이 고르게 들린다
		end
		table.insert(live, { layer = layer, sound = s, emitter = emitter, gain = 0, seed = #live * 7.3 })
	end

	local outdoor = SoundService.AmbientReverb
	RunService.Heartbeat:Connect(function(dt)
		local p = listener()
		local height = p.Y * Units.METERS_PER_STUD
		local sun = Lighting:GetSunDirection().Y
		local t = os.clock()
		local k = math.min(1, dt / FADE * 3) -- FADE초면 약 95 % 따라간다
		for _, l in live do
			local layer = l.layer
			local target = 1
			if layer.byHeight then
				target *= Ambience.curve(layer.byHeight, height)
			end
			if layer.bySun then
				target *= Ambience.curve(layer.bySun, sun)
			end
			l.gain += (target - l.gain) * k
			local sway = layer.sway or 0
			local s = l.sound
			s.Volume = layer.volume * l.gain * (1 + sway * math.noise(t / 7, l.seed))
			s.PlaybackSpeed = 1 + sway / 5 * math.noise(t / 11, l.seed + 0.5)
			s:SetAttribute("Gain", l.gain) -- 흔들림 전 배율 (Studio에서 값 다듬을 때 본다)
			local on = l.gain > 0.01
			if on ~= s.Playing then
				s.Playing = on -- 끌 때는 멈춤(자리 유지)
			end
			if l.emitter and on then
				local goal = Ambience.nearest(layer.line :: { Vector3 }, p)
				l.emitter.WorldPosition = l.emitter.WorldPosition:Lerp(goal, math.min(1, dt * 2)) -- 가장 가까운 도로가 바뀔 때 소리가 튀지 않게
			end
		end
		local reverb = outdoor
		for _, z in config.zones or {} do
			if inside(z, p) then
				reverb = z.reverb
				break
			end
		end
		if SoundService.AmbientReverb ~= reverb then
			SoundService.AmbientReverb = reverb
		end
	end)
end

return Ambience
