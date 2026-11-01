--!strict
-- 발사대: 다가가 누르면 캐릭터가 포물선을 그리며 정해진 착지점에 내려앉는다. 서버(serve)와 클라이언트(start)가 같이 require한다.
-- 물리로 쏘지 않는다: 착지점에서 거꾸로 초기 속도를 구하고(arc), 비행 중에는 클라이언트가 매 프레임 그 포물선 위 자리를 넣는다.
--   캐릭터 물리는 그 클라이언트가 소유하므로 자리를 넣는 쪽도 클라이언트다. 서버는 거리·쿨다운을 보고 허가만 하고,
--   불꽃·연기는 서버가 캐릭터와 발사대에 붙여 모두에게 보인다.
-- 소리는 발사 신호를 받은 각 클라이언트가 직접 낸다: 서버에서 내면 Sound가 복제되고 처음 불러오는 만큼 비행보다 늦는다.
--   접속 때 음원마다 원본 Sound를 SoundService에 불러 두고(살아 있는 동안 음원이 메모리에 남는다) 울릴 때 복제하면 바로 울린다.
-- 비행 자세(놀이 계획 "화차 비행 자세 미리보기" D안): 선 채로 진행 방향으로 살짝 기울어 흔들리고, 팔은 빙빙 허우적, 다리는 버둥.
--   몸 기울기는 나는 사람 클라이언트가 HumanoidRootPart CFrame으로 넣어 복제된다. 팔다리(관절 Transform)는 복제되지 않으므로
--   서버가 발사를 모든 클라이언트에 알리고(출발 서버 시각 포함) 각 클라이언트가 그 캐릭터의 팔다리를 같은 공식(pose)으로 움직인다.
-- 발사대 모양: Tags.LAUNCHER가 붙은 Model이 workspace에 있으면 그것을, 없으면 Place가 넘긴 상자(boxes)로 짓는다.
--   출발점 = 발사대 경계 상자 윗면 가운데. 착지점은 Place 데이터의 점에서 아래로 쏜 광선이 처음 닿는 면.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Split = require(script.Parent.Split)
local Tags = require(script.Parent.Tags)
local Units = require(script.Parent.Units)

-- 발사대 상자 하나 (m). cf = 발사대 바닥 가운데 기준 자리·방향(위치 m), 앞 = −Z. Traffic.Box와 같되 기울일 수 있게 CFrame
-- light가 있으면 그 상자 안에 밤에만 켜지는 PointLight (Tags.NIGHT_LIGHT, 밝기·범위 m·색). 그림자는 끈다 (모바일)
export type Box = {
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	light: { brightness: number, range: number, color: Color3 }?,
}

export type Config = {
	site: CFrame, -- 발사대 바닥 가운데 세계 자리(스터드)·방향. 앞 = −Z (Studio 모델을 쓰면 무시)
	boxes: { Box }, -- 첫 상자에 프롬프트를 단다
	fixtures: { Box }, -- 발사대 둘레 기구(조명 등). Studio 모델로 바꿔도 site 자리에 늘 짓는다
	landing: Vector3, -- 착지점 위 세계 좌표(스터드). 여기서 아래로 광선을 쏴 닿는 면에 내린다
	apex: number, -- 포물선 꼭대기가 출발·착지 중 높은 쪽보다 이만큼(m) 위
	sounds: { fire: Split.Sfx, land: Split.Sfx }, -- 발사(발사대에서, 비행이 끝나면 멈춤) · 착지(캐릭터에서). id 0 = 소리 없음
	screams: { Split.Sfx }, -- 나는 사람 비명(캐릭터에서, 매번 하나 무작위, 좁게 들림, 착지 때 줄여 끔). 비어 있으면 없음
}

local GRAVITY = Units.studs(9.81) -- 비행 포물선의 중력(스터드/s²). 실측 비율에 맞춰 실제 중력 (workspace.Gravity와 따로)
local COOLDOWN = 2 -- 착지 뒤 다시 탈 수 있기까지(초)
local REACH = 12 -- 프롬프트 거리(스터드). 서버는 여기에 여유 6을 더해 다시 잰다
local REMOTE = "Launcher"
local ROLLOFF = { 10, 150 } -- 발사음·착지음 { 최소, 최대 } 거리(m)
local Launcher = {}

local SCREAM_ROLLOFF = { 4, 40 } -- 비명 { 최소, 최대 } 거리(m). 사람 목소리라 좁게

-- 비행 자세 D안 (각 rad, 시간 s). 미리보기 pose('D')를 그대로 옮김
local POSE = {
	blendIn = { 0.04, 0.12 }, -- 비행 진행(0~1) 이 구간에서 서 있는 자세 → 허우적으로
	blendOut = { 0.88, 0.95 }, -- 이 구간에서 다시 서 있는 자세로 (발로 내려앉게)
	lean = 0.15, -- 몸 기울기 = lean × (접선각 − 90°)
	sway = { 0.1, 1.3 }, -- 흔들림 { 진폭, Hz }
	arm = { 1.7, 0.55 }, -- 팔 돌리기 { Hz, 팔꿈치 굽힘 }. 좌우 반 바퀴 어긋남
	leg = { 2.6, 0.6, 0.15, 0.9 }, -- 다리 { Hz, 엉덩이 진폭, 무릎 기본 굽힘, 무릎 추가 굽힘 }
	rest = 0.28, -- 서 있을 때 팔이 몸에서 벌어진 각 (미리보기 기준, 섞을 때 빙빙 각의 기준)
}

local function smooth(a: number, b: number, t: number): number
	local k = math.clamp((t - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

-- a에서 b 쪽으로 가장 짧게 돈 각 차
local function turn(a: number, b: number): number
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end

-- 진행 u(0~1)·흐른 시간 t(s)에서 { 섞임 w, 몸 기울기, 관절 이름 → X축 회전 }. 접선각 tangent(rad, 수평 0)
function Launcher.pose(u: number, t: number, tangent: number): (number, number, { [string]: number })
	local P = POSE
	local w = smooth(P.blendIn[1], P.blendIn[2], u) * (1 - smooth(P.blendOut[1], P.blendOut[2], u))
	local lean = (P.lean * (tangent - math.pi / 2) + P.sway[1] * math.sin(2 * math.pi * P.sway[2] * t)) * w
	local ph = 2 * math.pi * P.arm[1] * t
	local s = math.sin(2 * math.pi * P.leg[1] * t)
	local knee = function(k: number): number
		return -(P.leg[3] + P.leg[4] * k) * w
	end
	return w, lean, {
		-- 팔: 서 있는 각(아래, 미리보기 π∓rest)에서 빙빙 각 쪽으로 w만큼
		LeftShoulder = turn(math.pi - P.rest, ph) * w,
		RightShoulder = turn(math.pi + P.rest, ph + math.pi) * w,
		LeftElbow = P.arm[2] * w,
		RightElbow = P.arm[2] * w,
		LeftHip = P.leg[2] * s * w,
		RightHip = -P.leg[2] * s * w,
		LeftKnee = knee(0.5 + 0.5 * s),
		RightKnee = knee(0.5 - 0.5 * s),
	}
end
assert(select(1, Launcher.pose(0, 0, 1)) == 0 and select(1, Launcher.pose(1, 0, -1)) == 0, "pose가 출발·착지 때 서 있는 자세가 아니다")


-- from → to 포물선: 초기 속도와 비행 시간. 꼭대기 = max(from.Y, to.Y) + apex(스터드)
function Launcher.arc(from: Vector3, to: Vector3, apex: number): (Vector3, number)
	local top = math.max(from.Y, to.Y) + apex
	local vy = math.sqrt(2 * GRAVITY * (top - from.Y))
	local T = (vy + math.sqrt(2 * GRAVITY * (top - to.Y))) / GRAVITY
	return Vector3.new((to.X - from.X) / T, vy, (to.Z - from.Z) / T), T
end

function Launcher.at(from: Vector3, v0: Vector3, t: number): Vector3
	return from + v0 * t - Vector3.new(0, GRAVITY * t * t / 2, 0)
end

do -- 검산: 끝 시각에 착지점에 닿는다
	local a, b = Vector3.new(0, 2, 0), Vector3.new(30, 50, -100)
	local v0, T = Launcher.arc(a, b, 20)
	assert((Launcher.at(a, v0, T) - b).Magnitude < 1e-3, "arc가 착지점에 닿지 않는다")
end

-- site 기준 상자들을 Model 하나로 짓는다
local function boxes(name: string, site: CFrame, list: { Box }): Model
	local S = Units.studs(1)
	local model = Instance.new("Model")
	model.Name = name
	for i, b in list do
		local p = Instance.new("Part")
		p.Name = if i == 1 then "Root" else "Box"
		p.Shape = b.shape or Enum.PartType.Block
		p.Anchored = true
		p.Size = b.size * S
		p.CFrame = site * (b.cf.Rotation + b.cf.Position * S)
		p.Color = b.color
		p.Material = b.material or Enum.Material.Wood
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = b.size.Magnitude > 0.3
		local l = b.light
		if l then
			local light = Instance.new("PointLight")
			light.Brightness = l.brightness
			light.Range = Units.studs(l.range)
			light.Color = l.color
			light.Shadows = false
			light.Parent = p
			CollectionService:AddTag(light, Tags.NIGHT_LIGHT)
		end
		p.Parent = model
		if i == 1 then
			model.PrimaryPart = p
		end
	end
	model.Parent = workspace
	return model
end

local function build(config: Config): Model
	local model = boxes("Launcher", config.site, config.boxes)
	CollectionService:AddTag(model, Tags.LAUNCHER)
	return model
end

-- 서버에서 한 번 부른다 (착지할 지붕이 다 놓이고 건물 자리로 돈 뒤)
function Launcher.serve(config: Config)
	local remote = Instance.new("RemoteEvent")
	remote.Name = REMOTE
	remote.Parent = ReplicatedStorage

	local model = CollectionService:GetTagged(Tags.LAUNCHER)[1] :: Model? or build(config)
	if #config.fixtures > 0 then
		boxes("LauncherFixtures", config.site, config.fixtures)
	end
	local m = model :: Model
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 멀리서도 프롬프트 문구를 클라이언트가 바꿀 수 있게
	local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	local cf, size = m:GetBoundingBox()
	local from = cf.Position + Vector3.new(0, size.Y / 2, 0)

	-- 착지점: 지붕이 다 놓인 지금 한 번 광선으로 구한다 (사람이 서 있을 때 구하면 머리 위가 된다)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { m }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(config.landing, Vector3.new(0, -Units.studs(60), 0), params)
	if not hit then
		warn(`발사대: 착지점 {config.landing} 아래에 딛을 면이 없다 — 화차를 끈다`)
		return
	end
	local target = hit.Position

	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = REACH
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	local busy: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and humanoid and humanoid.Health > 0) then
			return
		end
		if (root.Position - anchor.Position).Magnitude > REACH + 6 or (busy[player] or 0) > os.clock() then
			return
		end
		local _, T = Launcher.arc(from, target, Units.studs(config.apex))
		busy[player] = os.clock() + T + COOLDOWN
		-- 비명은 서버가 하나 골라 모두가 같은 소리를 듣는다 (비어 있으면 클라이언트에서 nil)
		remote:FireAllClients(player, from, target, Units.studs(config.apex), workspace:GetServerTimeNow(), anchor, math.random(math.max(#config.screams, 1)))

		-- 불꽃·연기: 발사대 앞에서 한 번 피어오르고, 비행하는 동안 캐릭터 뒤를 따른다 (모두에게 보이게 서버에서)
		local puff = Instance.new("Smoke")
		puff.RiseVelocity = 4
		puff.Size = 3
		puff.Opacity = 0.4
		puff.Parent = anchor
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 0
		fire.Parent = root
		local trail = Instance.new("Smoke")
		trail.RiseVelocity = 0
		trail.Size = 2
		trail.Opacity = 0.3
		trail.Parent = root
		task.delay(T, function()
			fire.Enabled, trail.Enabled = false, false
		end)
		task.delay(1.2, function()
			puff.Enabled = false
		end)
		task.delay(T + 4, function()
			for _, e in { puff, fire, trail } :: { Instance } do
				e:Destroy()
			end
		end)
	end)
end

-- 클라이언트에서 한 번 부른다: 프롬프트 문구, 소리 미리 불러오기, 허가가 오면 비행과 소리
function Launcher.start(config: Config)
	local I18n = require(script.Parent.I18n)
	local player = Players.LocalPlayer

	local function label(inst: Instance)
		if inst:IsA("ProximityPrompt") then
			inst.ObjectText = I18n("launcher.name")
			inst.ActionText = I18n("launcher.fire")
		end
	end
	local function watch(model: Instance)
		for _, d in model:GetDescendants() do
			label(d)
		end
		model.DescendantAdded:Connect(label)
	end
	for _, m in CollectionService:GetTagged(Tags.LAUNCHER) do
		watch(m)
	end
	CollectionService:GetInstanceAddedSignal(Tags.LAUNCHER):Connect(watch)

	-- 소리 원본: 재생하지 않고 음원을 붙들어 둔다. 울릴 때는 복제본을 쓴다
	local originals: { [Split.Sfx]: Sound } = {}
	local function original(sfx: Split.Sfx, rolloff: { number })
		if sfx.id ~= 0 then
			local s = Instance.new("Sound")
			s.Name = `Launcher_{sfx.id}`
			s.SoundId = `rbxassetid://{sfx.id}`
			s.Volume = sfx.volume
			s.PlaybackSpeed = sfx.speed or 1
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = Units.studs(rolloff[1])
			s.RollOffMaxDistance = Units.studs(rolloff[2])
			s.Parent = SoundService
			originals[sfx] = s
		end
	end
	original(config.sounds.fire, ROLLOFF)
	original(config.sounds.land, ROLLOFF)
	for _, sfx in config.screams do
		original(sfx, SCREAM_ROLLOFF)
	end
	task.spawn(function()
		local list: { Instance } = {}
		for _, s in originals do
			table.insert(list, s)
		end
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
	local function ring(sfx: Split.Sfx?, parent: Instance?): Sound?
		local source = sfx and originals[sfx]
		if not (sfx and source) then
			return nil
		end
		local s = source:Clone()
		s.Parent = parent
		s.TimePosition = sfx.offset or 0
		s:Play()
		task.delay(8, s.Destroy, s)
		return s
	end

	task.spawn(function() -- 서버가 지붕을 다 지은 뒤에 만들므로 기다리는 동안 다른 클라이언트 준비를 막지 않게
		local remote = ReplicatedStorage:WaitForChild(REMOTE) :: RemoteEvent
		remote.OnClientEvent:Connect(function(flyer: Player, from: Vector3, to: Vector3, apex: number, launched: number, anchor: BasePart?, screamIndex: number)
			local whoosh = ring(config.sounds.fire, anchor) -- 캐릭터가 스트리밍으로 안 보여도 발사대 소리는 들리게 맨 앞에서
			local character = flyer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not (character and root and humanoid) then
				return
			end
			local mine = flyer == player
			local lift = Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0) -- 발 → HumanoidRootPart 중심
			local a, b = from + lift, to + lift
			local v0, T = Launcher.arc(a, b, apex)
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit -- 날아가는 쪽을 보게
			local upright = CFrame.lookAt(Vector3.zero, flat)
			local scream = ring(config.screams[screamIndex], root)
			-- 시간: 내 비행은 받은 순간부터, 남의 비행은 서버 출발 시각에 맞춘다
			local t0 = if mine then os.clock() else os.clock() - (workspace:GetServerTimeNow() - launched)
			local function now(): number
				return math.min(os.clock() - t0, T)
			end
			local function tangent(t: number): number
				return math.atan2(v0.Y - GRAVITY * t, Vector3.new(v0.X, 0, v0.Z).Magnitude)
			end

			-- 팔다리: 애니메이션이 Transform을 쓴 뒤(Stepped)에 덮어쓴다. 관절은 Motor6D 또는 새 아바타 리그의 AnimationConstraint
			local joints: { [string]: any } = {}
			for name in select(3, Launcher.pose(0, 0, 0)) :: { [string]: number } do
				local j = character:FindFirstChild(name, true)
				if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
					joints[name] = j
				end
			end
			local limbs: RBXScriptConnection
			local function finish()
				limbs:Disconnect()
				for _, j in joints do
					j.Transform = CFrame.identity
				end
				-- 소리: 음원 길이와 상관없이 발사음은 착지 때 멈추고, 비명은 0.4초에 걸쳐 줄인다
				if whoosh then
					whoosh:Stop()
				end
				if scream then
					TweenService:Create(scream, TweenInfo.new(0.4), { Volume = 0 }):Play()
				end
				if root.Parent then
					ring(config.sounds.land, root)
				end
			end
			limbs = RunService.Stepped:Connect(function()
				local t = now()
				if t >= T or not character.Parent then
					finish()
					return
				end
				local _, _, angles = Launcher.pose(t / T, t, tangent(t))
				for name, j in joints do
					j.Transform = CFrame.Angles(angles[name], 0, 0)
				end
			end)
			if not mine then
				return
			end

			-- 내 캐릭터: 포물선 위 자리 + 진행 방향 기울기
			humanoid:ChangeState(Enum.HumanoidStateType.Physics) -- 비행 중에는 휴머노이드가 움직임에 끼어들지 않게
			local conn: RBXScriptConnection
			conn = RunService.Heartbeat:Connect(function()
				if not root.Parent or humanoid.Health <= 0 then
					conn:Disconnect()
					return
				end
				local t = now()
				local p = Launcher.at(a, v0, t)
				local _, lean = Launcher.pose(t / T, t, tangent(t))
				-- lean < 0 = 앞으로 숙임. X축 양의 회전은 머리를 뒤로 젖히므로 그대로 넣는다
				root.CFrame = CFrame.new(p) * upright * CFrame.Angles(lean, 0, 0)
				root.AssemblyLinearVelocity = v0 - Vector3.new(0, GRAVITY * t, 0) -- 다른 사람 화면에서 부드럽게 보이게
				if t >= T then
					conn:Disconnect()
					root.AssemblyLinearVelocity = Vector3.zero
					root.CFrame = CFrame.new(b + Vector3.new(0, 0.2, 0)) * upright
					humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
				end
			end)
		end)
	end)
end

return Launcher
