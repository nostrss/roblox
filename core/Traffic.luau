--!strict
-- 도로 차량: 차로 경로를 따라 차를 내보내고, 움직이고, 경로 끝에서 없앤다. 클라이언트 전용, Place가 경로·차 종류·빈도만 넘긴다.
-- 방문자마다 자기 화면에만 만든다 (서버는 모른다). 부딪힘·조회·닿기를 모두 꺼 사람을 그냥 지나간다.
-- 밤 등불(Neon)은 Tags.NIGHT_LIGHT로 core TimeOfDay가 켜고 끈다. 엔진 소리는 SoundService.Ambience(환경음과 같은 크기 조절)로 보낸다.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Tags = require(script.Parent.Tags)
local Units = require(script.Parent.Units)

-- 차 몸을 이루는 상자 하나 (m). at = 차 바닥 가운데에서 상자 중심까지, 앞 = −Z. color가 없으면 그 차의 몸 색
export type Box = { size: Vector3, at: Vector3, color: Color3?, material: Enum.Material? }

export type Kind = {
	boxes: { Box }, -- 첫 상자가 움직임의 뿌리. 그림자는 shadow일 때 첫 상자만
	colors: { Color3 }, -- 몸 색 후보 (차마다 하나 고른다)
	lamp: Vector3, -- 등 자리 (가운데에서 옆 x, 높이, 가운데에서 앞뒤 끝 z) m. 좌우·앞(흰빛)뒤(붉은빛) 네 개를 만든다
	shadow: boolean?,
	spot: boolean?, -- 앞에 SpotLight 하나 (모바일 부담 — 큰 차에만)
	engine: { id: number, volume: number, speed: number }?, -- 오디오 에셋 ID, Sound.Volume, PlaybackSpeed
}

export type Lane = {
	path: { Vector3 }, -- 세계 좌표(스터드) 꺾은선. 차는 1번 점에서 나와 마지막 점에서 사라진다
	speed: number, -- m/s. 한 차로는 한 속도 (앞차를 따라잡지 않게)
	gap: { number }, -- 다음 차까지 { 최소, 최대 } 초. 최소 × 속도가 가장 긴 차보다 길어야 겹치지 않는다
	kinds: { Kind }, -- 고르는 후보. 같은 종류를 여러 번 넣으면 더 자주 나온다
}

export type Config = { max: number, lanes: { Lane } } -- max = 한꺼번에 있는 차 수 상한 (모든 차로 합)

local ROLLOFF = { 6, 90 } -- 엔진 소리 { 최소, 최대 } 거리(m)
local HEAD = Color3.fromRGB(255, 240, 210)
local TAIL = Color3.fromRGB(200, 20, 20)

local Traffic = {}

-- 꺾은선 위 처음부터 s(스터드) 간 점. cum[i] = 1번 점부터 i번 점까지 길이
function Traffic.at(path: { Vector3 }, cum: { number }, s: number): Vector3
	s = math.clamp(s, 0, cum[#cum])
	for i = 2, #path do
		if s <= cum[i] then
			local seg = cum[i] - cum[i - 1]
			return path[i - 1]:Lerp(path[i], if seg > 0 then (s - cum[i - 1]) / seg else 0)
		end
	end
	return path[#path]
end
assert(Traffic.at({ Vector3.zero, Vector3.new(10, 0, 0) }, { 0, 10 }, 4) == Vector3.new(4, 0, 0), "at이 틀렸다")

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

type Car = { model: Model, root: BasePart, offset: CFrame, half: number, lane: Lane, cum: { number }, s: number }

-- 차 한 대. 뿌리(첫 상자)만 고정하고 나머지는 용접 — 뿌리 CFrame 하나만 옮기면 된다
local function build(kind: Kind): (Model, BasePart, CFrame, number)
	local S = Units.studs(1)
	local model = Instance.new("Model")
	model.Name = "Vehicle"
	local body = kind.colors[math.random(#kind.colors)]
	local root: BasePart? = nil
	local offset = CFrame.identity
	local half = 0
	for i, b in kind.boxes do
		local p = part("Body", b.size * S, b.color or body, b.material or Enum.Material.SmoothPlastic, model)
		local cf = CFrame.new(b.at * S)
		half = math.max(half, (math.abs(b.at.Z) + b.size.Z / 2) * S)
		if i == 1 then
			p.Anchored = true
			p.CastShadow = kind.shadow == true
			root, offset = p, cf
		else
			p.CFrame = cf
		end
	end
	local r = root :: BasePart
	r.CFrame = offset
	-- 등: 앞 두 개 흰빛, 뒤 두 개 붉은빛. 밤에만 보인다 (LitValue = 켜진 투명도, 낮 값은 TimeOfDay가 1로)
	local l = kind.lamp
	for _, side in { -1, 1 } do
		for _, back in { false, true } do
			local p = part(if back then "TailLamp" else "HeadLamp", Vector3.new(0.35, 0.15, 0.05) * S, if back then TAIL else HEAD, Enum.Material.Neon, model)
			p.CFrame = CFrame.new(Vector3.new(side * l.X, l.Y, if back then l.Z else -l.Z) * S)
			p:SetAttribute("LitValue", 0)
			p.Transparency = 1
		end
	end
	if kind.spot then
		local a = Instance.new("Attachment")
		a.CFrame = r.CFrame:ToObjectSpace(CFrame.new(Vector3.new(0, l.Y, -l.Z) * S) * CFrame.Angles(math.rad(-10), 0, 0))
		a.Parent = r
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 70
		light.Range = 40
		light.Color = HEAD
		light.Brightness = 0
		light.Enabled = false
		light:SetAttribute("LitValue", 2)
		light.Parent = a
	end
	for _, p in model:GetChildren() do
		if p ~= r and p:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = r, p
			w.Parent = p
		end
	end
	local e = kind.engine
	if e then
		local s = Instance.new("Sound")
		s.Name = "Engine"
		s.SoundId = `rbxassetid://{e.id}`
		s.Looped = true
		s.Volume = e.volume
		s.PlaybackSpeed = e.speed * (0.95 + math.random() * 0.1)
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = Units.studs(ROLLOFF[1])
		s.RollOffMaxDistance = Units.studs(ROLLOFF[2])
		s.SoundGroup = SoundService:FindFirstChild("Ambience") :: SoundGroup?
		s.Parent = r
	end
	CollectionService:AddTag(model, Tags.NIGHT_LIGHT)
	return model, r, offset, half
end

-- 차 자리: 경로 위 s에 바닥 가운데를 두고, 차 길이만큼 앞뒤 점을 잇는 방향을 본다 (꺾인 곳에서 부드럽게 돈다)
local function place(c: Car)
	local p = Traffic.at(c.lane.path, c.cum, c.s)
	local dir = Traffic.at(c.lane.path, c.cum, c.s + c.half) - Traffic.at(c.lane.path, c.cum, c.s - c.half)
	c.root.CFrame = CFrame.lookAt(p, p + dir) * c.offset
end

-- 클라이언트에서 한 번 부른다
function Traffic.start(config: Config)
	local folder = Instance.new("Folder")
	folder.Name = "Traffic"
	folder.Parent = workspace
	local cars: { Car } = {}

	for _, lane in config.lanes do
		local cum = { 0 }
		for i = 2, #lane.path do
			cum[i] = cum[i - 1] + (lane.path[i] - lane.path[i - 1]).Magnitude
		end
		task.spawn(function()
			while true do
				task.wait(lane.gap[1] + math.random() * (lane.gap[2] - lane.gap[1]))
				if #cars < config.max then
					local model, root, offset, half = build(lane.kinds[math.random(#lane.kinds)])
					local c: Car = { model = model, root = root, offset = offset, half = half, lane = lane, cum = cum, s = 0 }
					model.Parent = folder -- 용접은 들어갈 때 상자 사이 거리를 잰다 → 만든 자리 그대로 넣은 뒤 옮긴다
					place(c)
					local engine = root:FindFirstChild("Engine") :: Sound?
					if engine then
						engine.TimePosition = math.random() * 20 -- 차마다 소리 시작점을 달리한다
						engine:Play()
					end
					table.insert(cars, c)
				end
			end
		end)
	end

	RunService.Heartbeat:Connect(function(dt)
		for i = #cars, 1, -1 do
			local c = cars[i]
			c.s += Units.studs(c.lane.speed) * dt
			if c.s >= c.cum[#c.cum] then
				c.model:Destroy()
				table.remove(cars, i)
			else
				place(c)
			end
		end
		folder:SetAttribute("Count", #cars) -- Studio에서 동시 차 수를 볼 때
	end)
end

return Traffic
