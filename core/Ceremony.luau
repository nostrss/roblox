--!strict
-- 회차: 데이터로 적은 구간을 차례로 재생하는 행사 한 번 (첫 사용: 숭례문 개폐의식). 서버(serve)와 클라이언트(start)가 같이 require한다.
-- 모두 시각 하나에서 계산한다: 서버가 시작 서버 시각을 RemoteEvent의 StartedAt 속성에 적으면, 어느 순간의 장면이든 at(구간표, 흐른 시간)으로 정해진다.
--   그래서 도중 접속한 방문자도 속성을 읽어 같은 장면을 보고, 끝을 알리는 타이머도 없다. 시각은 GetServerTimeNow, 하늘·시간대와 무관하다(ADR 0007).
-- 문: 클라이언트가 매 프레임 자기 화면에서 돌린다. 서버 값은 늘 열린 자리다.
--   서버에서 돌리면 CFrame이 복제 주기마다 끊겨 보이고, 부딪히는 문은 사람을 밀어낸다. 그래서 문은 표시만 하고(Tags.GATE_LEAF, 부딪힘 없음)
--   길을 막는 판정은 서버가 보이지 않는 막이(Tags.GATE_BARRIER)의 CanCollide로 한다. 막이는 사람이 그 자리를 비운 뒤에야 켠다.
-- 소리: 클라이언트가 Launcher처럼 원본을 미리 불러 두고 복제해 울린다. 이미 지난 신호음은 도중 접속자에게 울리지 않는다.
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Figures = require(script.Parent.Figures)
local Split = require(script.Parent.Split)
local Tags = require(script.Parent.Tags)
local Units = require(script.Parent.Units)
local text = require(script.Parent.I18n).text

export type Phase = {
	len: number, -- 초
	caption: string, -- 자막 다국어 키
	gate: ("close" | "open")?, -- 이 구간 내내 문이 닫히거나 열린다
	signals: { { at: number, sound: string } }?, -- 구간 시작부터 at초에 울릴 소리 (sounds 키)
}

export type Config = {
	phases: { Phase },
	sounds: { [string]: Split.Sfx }, -- id 0 = 소리 없음 (조용히 건너뛴다)
	volume: number, -- SoundGroup "Ceremony" 전체 크기. Studio에 미리 두면 그 값을 쓴다
	blockFrom: number, -- 문 닫힘 정도(0 열림 ~ 1 닫힘)가 이 값 이상이면 막이를 켠다
	button: string, -- 시작 버튼 다국어 키
	buttonBusy: string, -- 진행 중 버튼 다국어 키
	figures: Figures.Config?, -- 회차를 따라 움직이는 인물과 기물 (core Figures)
	footsteps: { sound: string, rolloff: { number } }?, -- 인물이 걷는 동안 걷는 무리 가운데에서 도는 발소리 하나. sound = sounds 키, rolloff = { 최소, 최대 } 거리(m)
}

local REMOTE = "Ceremony"
local ATTRIBUTE = "StartedAt"
local CLEARANCE = 2 -- 막이 면에서 이 거리(스터드) 안에 캐릭터 중심이 있으면 아직 켜지 않는다 (몸 반 폭 1 + 서버가 보는 위치 지연)
local BARRIER_STEP = 0.1 -- 서버가 막이를 다시 판정하는 간격(초)

local Ceremony = {}

-- 흐른 시간 t(초) → (지금 구간 번호, 문 닫힘 0~1). 회차가 끝났으면 구간 번호 nil
function Ceremony.at(phases: { Phase }, t: number): (number?, number)
	local start, closed = 0, 0
	for i, p in phases do
		local stop = start + p.len
		if p.gate and t > start then
			local k = math.clamp((t - start) / p.len, 0, 1)
			k = k * k * (3 - 2 * k)
			closed = if p.gate == "close" then k else 1 - k
		end
		if t < stop then
			return i, closed
		end
		start = stop
	end
	return nil, 0
end

function Ceremony.duration(phases: { Phase }): number
	local total = 0
	for _, p in phases do
		total += p.len
	end
	return total
end

do -- 검산: 도중 접속해도 시간만으로 같은 상태가 나온다
	local P: { Phase } = { { len = 2, caption = "a" }, { len = 2, caption = "b", gate = "close" }, { len = 2, caption = "c" }, { len = 2, caption = "d", gate = "open" } }
	local function check(t: number, phase: number?, closed: number)
		local i, c = Ceremony.at(P, t)
		assert(i == phase and math.abs(c - closed) < 1e-6, `at({t}) = {i}, {c}`)
	end
	check(-1, 1, 0) -- 기기 시계가 살짝 앞선 경우
	check(0, 1, 0)
	check(3, 2, 0.5)
	check(5, 3, 1)
	check(7, 4, 0.5)
	check(8, nil, 0)
	check(100, nil, 0)
	assert(Ceremony.duration(P) == 8, "duration이 틀렸다")
end

-- 회차가 끝나기 전 값: 문이 열린 채 끝나야 평소 모습으로 돌아간다
local function validate(config: Config)
	local total = Ceremony.duration(config.phases)
	local _, closed = Ceremony.at(config.phases, total - 1e-6)
	assert(closed < 1e-3, "회차가 문을 닫은 채 끝난다")
	for _, p in config.phases do
		for _, s in p.signals or {} do
			assert(config.sounds[s.sound], `없는 소리 키: {s.sound}`)
		end
	end
	assert(not config.footsteps or config.sounds[config.footsteps.sound], "없는 발소리 키")
end

local function occupied(barrier: BasePart): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local q = barrier.CFrame:PointToObjectSpace(root.Position)
			local half = barrier.Size / 2
			if math.abs(q.Z) < half.Z + CLEARANCE and math.abs(q.X) < half.X + CLEARANCE and math.abs(q.Y) < half.Y + CLEARANCE then
				return true
			end
		end
	end
	return false
end

-- 서버에서 한 번 부른다. 돌려주는 begin()이 회차를 시작한다 (진행 중이면 무시). 언제 부를지는 부르는 쪽이 정한다
function Ceremony.serve(config: Config): () -> ()
	validate(config)
	local remote = Instance.new("RemoteEvent")
	remote.Name = REMOTE
	remote.Parent = ReplicatedStorage
	local total = Ceremony.duration(config.phases)

	return function()
		local now = workspace:GetServerTimeNow()
		local started = remote:GetAttribute(ATTRIBUTE) :: number?
		if started and now - started < total then
			return
		end
		remote:SetAttribute(ATTRIBUTE, now)
		task.spawn(function()
			while true do
				local t = workspace:GetServerTimeNow() - now
				local phase, closed = Ceremony.at(config.phases, t)
				local block = phase ~= nil and closed >= config.blockFrom
				for _, b in CollectionService:GetTagged(Tags.GATE_BARRIER) do
					local barrier = b :: BasePart
					-- ponytail: 자리에 서 있는 사람이 있으면 온 서버의 막이를 미룬다. 개인별로 막으려면 캐릭터 충돌 그룹으로 바꾼다
					if not block or barrier.CanCollide or not occupied(barrier) then
						barrier.CanCollide = block
					end
				end
				if not phase then
					return
				end
				task.wait(BARRIER_STEP)
			end
		end)
	end
end

-- 시작 방식: 방문자 버튼. 주기로 바꿀 때는 이 함수 대신 주기 코드가 begin을 부른다
function Ceremony.startOnRequest(begin: () -> ())
	(ReplicatedStorage:FindFirstChild(REMOTE) :: RemoteEvent).OnServerEvent:Connect(function()
		begin()
	end)
end

-- 문 부재 하나를 닫힘 정도 closed 자리로. 열린 자리는 처음 볼 때 클라이언트 속성에 적어 둔다 (TimeOfDay.LitValue와 같은 이유)
local function swing(part: BasePart, closed: number)
	local open = part:GetAttribute("OpenCFrame") :: CFrame?
	if not open then
		open = part.CFrame
		part:SetAttribute("OpenCFrame", open)
	end
	local base = open :: CFrame
	if closed == 0 then
		part.CFrame = base -- 부동소수 오차 없이 원래 자리로
		return
	end
	local hinge = base * (part:GetAttribute("Hinge") :: CFrame)
	local angle = math.rad((part:GetAttribute("Swing") :: number) * closed)
	part.CFrame = hinge * CFrame.Angles(0, angle, 0) * hinge:Inverse() * base
end

local function ui(config: Config, request: () -> ()): (TextButton, TextLabel)
	local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	-- 시작 버튼: 상단 바 시간대 버튼(core TimeOfDay) 바로 아래, 같은 모양의 알약.
	-- 근사: 화면 위 약 58 px 안에서는 Play 시험 때 그려져도 눌리지 않았다 (y 4·30 실패, 70·120 성공. 원인은 확인 못 함). 그래서 그 아래에 둔다
	local top = Instance.new("ScreenGui")
	top.Name = "CeremonyButton"
	top.ResetOnSpawn = false
	top.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local button = Instance.new("TextButton")
	button.Name = "Start"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, 0, 0, 60)
	button.Size = UDim2.fromOffset(0, 40) -- 터치 크기
	button.AutomaticSize = Enum.AutomaticSize.X
	button.BackgroundColor3 = Color3.new(0, 0, 0)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	button.TextSize = 16
	button.AutoButtonColor = false
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = button
	button.Activated:Connect(request)
	button.Parent = top
	top.Parent = playerGui

	-- 자막: 조이스틱과 점프 사이 아래쪽 가운데. 폭 46 %면 가로 휴대폰에서 두 조작 사이에 든다
	local bottom = Instance.new("ScreenGui")
	bottom.Name = "CeremonyCaption"
	bottom.ResetOnSpawn = false
	bottom.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -12)
	caption.Size = UDim2.fromScale(0.46, 0)
	caption.AutomaticSize = Enum.AutomaticSize.Y
	caption.BackgroundColor3 = Color3.new(0, 0, 0)
	caption.BackgroundTransparency = 0.25
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.FontFace = Font.fromEnum(Enum.Font.BuilderSans)
	caption.TextSize = 16
	caption.TextWrapped = true
	caption.Visible = false
	Instance.new("UICorner", caption).CornerRadius = UDim.new(0, 8)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, math.huge)
	limit.Parent = caption
	local capPad = Instance.new("UIPadding")
	capPad.PaddingTop = UDim.new(0, 8)
	capPad.PaddingBottom = UDim.new(0, 8)
	capPad.PaddingLeft = UDim.new(0, 12)
	capPad.PaddingRight = UDim.new(0, 12)
	capPad.Parent = caption
	caption.Parent = bottom
	bottom.Parent = playerGui
	return button, caption
end

-- 클라이언트에서 한 번 부른다
function Ceremony.start(config: Config)
	validate(config)

	local group = SoundService:FindFirstChild("Ceremony") :: SoundGroup?
	if not group then
		local g = Instance.new("SoundGroup")
		g.Name = "Ceremony"
		g.Volume = config.volume
		g.Parent = SoundService
		group = g
	end
	-- 원본은 재생하지 않고 음원을 붙들어 둔다. 위치 없이 고르게 들린다 (SoundService 밑)
	local originals: { [string]: Sound } = {}
	local preload: { Instance } = {}
	for key, sfx in config.sounds do
		if sfx.id ~= 0 then
			local s = Instance.new("Sound")
			s.Name = `Ceremony_{key}`
			s.SoundId = `rbxassetid://{sfx.id}`
			s.Volume = sfx.volume
			s.PlaybackSpeed = sfx.speed or 1
			s.SoundGroup = group
			s.Parent = SoundService
			originals[key] = s
			table.insert(preload, s)
		end
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(preload)
	end)
	local function ring(key: string)
		local source = originals[key]
		if source then
			local s = source:Clone()
			s.Name = `{source.Name}_Playing`
			s.Parent = SoundService
			s.TimePosition = config.sounds[key].offset or 0
			s:Play()
			task.delay(20, s.Destroy, s)
		end
	end

	-- 신호음을 회차 시각 순으로 편다
	local schedule: { { at: number, sound: string } } = {}
	do
		local start = 0
		for _, p in config.phases do
			for _, s in p.signals or {} do
				table.insert(schedule, { at = start + s.at, sound = s.sound })
			end
			start += p.len
		end
		table.sort(schedule, function(a, b)
			return a.at < b.at
		end)
	end

	local setFigures = if config.figures then Figures.start(config.figures) else nil

	-- 발소리: 인물마다 붙이지 않고 소리원 하나를 걷는 무리 가운데로 옮긴다. 켜고 끄기는 매 프레임 t에서 나온 값으로만 정한다
	local stepSource = config.footsteps and originals[config.footsteps.sound]
	local stepEmitter: Attachment? = nil
	local stepSound: Sound? = nil
	if config.footsteps and stepSource then
		local a = Instance.new("Attachment") -- Ambience와 같은 파트 없는 3D 소리 자리
		a.Name = "Ceremony_Footsteps"
		a.Parent = workspace.Terrain
		local s = stepSource:Clone()
		s.Name = "Ceremony_Footsteps"
		s.Looped = true
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = Units.studs(config.footsteps.rolloff[1])
		s.RollOffMaxDistance = Units.studs(config.footsteps.rolloff[2])
		s.Parent = a
		stepEmitter, stepSound = a, s
	end
	local function footsteps(at: Vector3?)
		if stepEmitter and stepSound then
			if at and stepSound.Playing then
				stepEmitter.WorldPosition = stepEmitter.WorldPosition:Lerp(at, 0.1) -- 무리 가운데가 튀어도 소리가 튀지 않게
			elseif at then
				stepEmitter.WorldPosition = at
			end
			if (at ~= nil) ~= stepSound.Playing then
				stepSound.Playing = at ~= nil
			end
		end
	end

	task.spawn(function() -- 서버가 건물을 다 지은 뒤에 만들므로 기다리는 동안 다른 클라이언트 준비를 막지 않게
		local remote = ReplicatedStorage:WaitForChild(REMOTE) :: RemoteEvent
		local running = false
		local button, caption = ui(config, function()
			if not running then
				remote:FireServer()
			end
		end)
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke

		local function style()
			button.Text = text(if running then config.buttonBusy else config.button)
			button.Active = not running
			button.BackgroundTransparency = if running then 0.55 else 0.1
			button.TextTransparency = if running then 0.45 else 0
			stroke.Transparency = if running then 0.7 else 0.1
		end
		style()

		local shown: number? = nil
		local seen: number? = nil -- 지금 신호음을 맞춘 회차의 시작 시각
		local nextSignal = 1
		RunService.RenderStepped:Connect(function()
			local started = remote:GetAttribute(ATTRIBUTE) :: number?
			local t = if started then workspace:GetServerTimeNow() - started else math.huge
			local phase, closed = Ceremony.at(config.phases, t)
			local now = phase ~= nil

			if now then -- 스트리밍으로 다시 들어온 문짝도 다음 프레임에 제자리를 찾도록 진행 중에는 늘 맞춘다
				for _, p in CollectionService:GetTagged(Tags.GATE_LEAF) do
					swing(p :: BasePart, closed)
				end
				if setFigures then
					footsteps(setFigures(t))
				end
			end
			if now ~= running then
				running = now
				style()
				if not now then
					for _, p in CollectionService:GetTagged(Tags.GATE_LEAF) do
						swing(p :: BasePart, 0)
					end
					if setFigures then
						footsteps(setFigures(math.huge))
					end
				end
			end
			if phase ~= shown then
				shown = phase
				caption.Visible = phase ~= nil
				if phase then
					caption.Text = text(config.phases[phase].caption)
				end
			end

			if now and started ~= seen then
				seen = started
				nextSignal = 1
				while schedule[nextSignal] and schedule[nextSignal].at < t - 0.5 do -- 도중 접속: 지난 신호음은 건너뛴다
					nextSignal += 1
				end
			end
			while now and schedule[nextSignal] and schedule[nextSignal].at <= t do
				ring(schedule[nextSignal].sound)
				nextSignal += 1
			end
		end)
	end)
end

return Ceremony
