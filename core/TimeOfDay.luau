--!strict
-- 시간대(ADR 0007): 하늘·빛을 실제 서울 시각(KST)에 맞추고, 방문자가 "지금/노을/밤"을 고르면 자기 화면만 바꾼다.
-- 클라이언트 전용. 서버는 Lighting 시각·효과를 건드리지 않는다 (서버 값이 복제되면 방문자의 선택을 덮어쓴다).
-- 시각은 서버 시계(GetServerTimeNow)로 잰다 — 방문자 기기 시계가 틀려도 모두 같은 서울 시각을 본다.
-- 색조는 버튼이 아니라 해 높이로 정한다 → "지금"이 실제 노을 무렵이면 노을 색조가 된다.
--   낮 색조 = Studio에 둔 Lighting·효과 값 그대로(시작할 때 읽는다). 노을·밤 색조는 Place가 넘긴다. Ambient는 건드리지 않는다.
-- 야간 조명은 Tags.NIGHT_LIGHT로 찾는다 (Studio에서 더하거나 옮긴 것도 태그만 붙이면 같이 켜고 끈다). Tags.DAY_LIGHT는 그 반대로 켜고 끈다.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Tags = require(script.Parent.Tags)
local text = require(script.Parent.I18n).text

-- 효과 클래스 이름(Atmosphere, ColorCorrectionEffect, BloomEffect, SunRaysEffect, Clouds, 또는 "Lighting" 자체) → 속성 → 값.
-- 트윈되는 값(숫자·Color3)만 쓴다. 노을·밤에 적지 않은 속성은 낮(Studio) 값으로 돌아간다
export type Look = { [string]: { [string]: any } }
export type Looks = { sunset: Look, night: Look }

local TimeOfDay = {}

-- 유닉스 시각(초) → 서울 시각(시, 0~24). UTC+9, 서머타임 없음
function TimeOfDay.kst(unix: number): number
	return (unix / 3600 + 9) % 24
end
assert(TimeOfDay.kst(0) == 9 and TimeOfDay.kst(15 * 3600) == 0, "KST 환산이 틀렸다")

-- 버튼이 고정하는 시각. 로블록스 해는 날짜가 없어 6시에 뜨고 18시에 진다 (위도 37.56, Studio에서 GetSunDirection으로 확인).
-- ponytail: 계절(일몰 시각) 보정 없음 — 실제 서울 일몰(12월 17:15 ~ 6월 19:57)과 최대 두 시간 어긋난다. 맞추려면 kst()에서 날짜별 일출·일몰로 시각을 늘이고 줄인다
local CLOCK = { sunset = 17.6, night = 21 }
-- 해 높이(GetSunDirection().Y) 경계. 저녁 기준 약 17:00 노을 색조, 18:15 밤 색조, 17:52 조명 켬 (아침은 거꾸로)
local SUNSET_SUN, NIGHT_SUN, LIGHTS_SUN = 0.25, -0.06, 0.03
local FADE = TweenInfo.new(4, Enum.EasingStyle.Sine) -- 색조·조명이 바뀌는 시간

local lit = false -- 야간 조명이 켜진 상태인가
local LIGHT_TAGS = { [Tags.NIGHT_LIGHT] = false, [Tags.DAY_LIGHT] = true } -- 태그 → 야간 조명과 반대로 켜는가

local function switchable(i: Instance): boolean
	return i:IsA("Light") or (i:IsA("BasePart") and i.Material == Enum.Material.Neon)
end

-- 조명 하나를 지금 상태(lit, inverse면 그 반대)로. info가 없으면 바로
local function set(i: Instance, inverse: boolean, info: TweenInfo?)
	local isLight = i:IsA("Light")
	local on = lit ~= inverse
	-- 켜진 값(Studio·서버 값)을 처음 볼 때 인스턴스 속성에 적어 둔다 (클라이언트에만). 약한 키 표는 인스턴스 래퍼가 수거돼 값을 잃는다
	local full = i:GetAttribute("LitValue") :: number?
	if full == nil then
		full = if isLight then (i :: Light).Brightness else (i :: BasePart).Transparency
		i:SetAttribute("LitValue", full)
	end
	local goal = if isLight then { Brightness = if on then full else 0 } else { Transparency = if on then full else 1 }
	if isLight and on then
		(i :: Light).Enabled = true
	end
	if info then
		local tween = TweenService:Create(i, info, goal)
		if isLight and not on then
			tween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and lit == inverse then
					(i :: Light).Enabled = false -- 꺼진 조명은 계산에서도 뺀다 (모바일)
				end
			end)
		end
		tween:Play()
	else
		for k, v in goal do
			(i :: any)[k] = v
		end
		if isLight then
			(i :: Light).Enabled = on
		end
	end
end

local function eachSwitchable(root: Instance, fn: (Instance) -> ())
	if switchable(root) then
		fn(root)
	end
	for _, d in root:GetDescendants() do
		if switchable(d) then
			fn(d)
		end
	end
end

-- 효과 인스턴스. 없으면 클라이언트에만 만든다 (구름은 Terrain 밑, 낮에는 덮개 0)
local function effect(className: string): Instance
	if className == "Lighting" then
		return Lighting
	end
	local parent: Instance = if className == "Clouds" then workspace.Terrain else Lighting
	local inst = parent:FindFirstChildOfClass(className :: any)
	if not inst then
		inst = Instance.new(className :: any)
		if className == "Clouds" then
			(inst :: any).Cover = 0
		end
		inst.Parent = parent
	end
	return inst :: Instance
end

-- 시간대 고르기 UI. 모드는 ScreenGui의 Mode 속성 하나가 들고, 버튼은 그 값만 바꾼다
local MODES = { "now", "sunset", "night" }
local function picker(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "TimeOfDay"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets -- 상단 바 빈자리 오른쪽 (왼쪽 아래 조이스틱·오른쪽 아래 점프를 피한다)
	gui:SetAttribute("Mode", "now")
	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.fromScale(1, 0)
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row
	local buttons: { [string]: TextButton } = {}
	for n, mode in MODES do
		local b = Instance.new("TextButton")
		b.LayoutOrder = n
		b.Size = UDim2.new(0, 60, 1, -8) -- 상단 바 높이(44 px 이상)에 맞춘 터치 크기
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
		b.TextSize = 16
		b.Text = text(`time.{mode}`)
		Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
		local stroke = Instance.new("UIStroke") -- 밤하늘에서도 버튼 테두리가 보이게
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.7
		stroke.Parent = b
		b.Activated:Connect(function()
			gui:SetAttribute("Mode", mode)
		end)
		b.Parent = row
		buttons[mode] = b
	end
	local function highlight()
		for mode, b in buttons do
			local on = gui:GetAttribute("Mode") == mode
			local stroke = b:FindFirstChildOfClass("UIStroke") :: UIStroke
			b.BackgroundTransparency = if on then 0.1 else 0.55
			stroke.Transparency = if on then 0.1 else 0.7
		end
	end
	gui:GetAttributeChangedSignal("Mode"):Connect(highlight)
	highlight()
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return gui
end

-- 클라이언트에서 한 번 부른다. place = 이 Place의 노을·밤 색조
function TimeOfDay.start(place: Looks)
	-- 색조 표: 효과 인스턴스 → 속성 → 값. 낮은 Studio 값을 읽어 채우고, 노을·밤에 없는 속성은 낮 값
	local looks: { [string]: { [Instance]: { [string]: any } } } = { day = {}, sunset = {}, night = {} }
	for _, phase in { "sunset", "night" } do
		for className, props in (place :: any)[phase] :: Look do
			local inst = effect(className)
			looks.day[inst] = looks.day[inst] or {}
			looks[phase][inst] = table.clone(props)
			for k in props do
				looks.day[inst][k] = (inst :: any)[k]
			end
		end
	end
	for _, phase in { "sunset", "night" } do
		for inst, day in looks.day do
			local t = looks[phase][inst] or {}
			looks[phase][inst] = t
			for k, v in day do
				if t[k] == nil then
					t[k] = v
				end
			end
		end
	end

	local gui = picker()
	local phase: string? = nil
	local first = true
	local function update()
		local mode = gui:GetAttribute("Mode") :: string
		Lighting.ClockTime = if mode == "now" then TimeOfDay.kst(workspace:GetServerTimeNow()) else (CLOCK :: any)[mode]
		local y = Lighting:GetSunDirection().Y
		local info = if first then nil else FADE
		local p = if y > SUNSET_SUN then "day" elseif y > NIGHT_SUN then "sunset" else "night"
		if p ~= phase then
			phase = p
			for inst, props in looks[p] do
				if info then
					TweenService:Create(inst, info, props):Play()
				else
					for k, v in props do
						(inst :: any)[k] = v
					end
				end
			end
		end
		local l = y < LIGHTS_SUN
		if l ~= lit or first then
			lit = l
			for tag, inverse in LIGHT_TAGS do
				for _, root in CollectionService:GetTagged(tag) do
					eachSwitchable(root, function(i)
						set(i, inverse, info)
					end)
				end
			end
		end
		first = false
	end

	-- 스트리밍으로 들어오는(다시 들어오는) 조명은 지금 상태로 바로 맞춘다
	local function arrived(root: Instance, inverse: boolean)
		eachSwitchable(root, function(i)
			set(i, inverse)
		end)
		root.DescendantAdded:Connect(function(d)
			if switchable(d) then
				set(d, inverse)
			end
		end)
	end
	update()
	for tag, inverse in LIGHT_TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(root)
			arrived(root, inverse)
		end)
		for _, root in CollectionService:GetTagged(tag) do
			arrived(root, inverse)
		end
	end
	gui:GetAttributeChangedSignal("Mode"):Connect(update)
	task.spawn(function()
		while true do
			task.wait(5)
			if gui:GetAttribute("Mode") == "now" then
				update()
			end
		end
	end)
end

return TimeOfDay
