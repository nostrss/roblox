--!strict
-- 입장 안내: 접속할 때 한 번 뜨고 버튼을 누르면 닫힌다. 저장하지 않고 리스폰 때도 다시 뜨지 않는다.
-- 문구 키는 Place 데이터가 넘긴다. 클라이언트 전용. 카메라는 건드리지 않는다.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

export type Place = {
	eyebrow: string,
	title: string,
	intro: string,
	items: { { title: string, desc: string } },
	source: string,
}

-- 시안의 두 크기. 화면에 맞추는 건 UIScale 하나가 맡는다 (fillX·fillY = 화면에서 차지할 최대 비율)
local REGULAR = {
	width = 680, left = 250, gap = 28, padX = 26, padTop = 22, padBottom = 14,
	eyebrow = 13, title = 34, body = 14, item = 14, desc = 13, foot = 11.5, button = 44,
	fillX = 0.8, fillY = 0.9,
}
local COMPACT = {
	width = 610, left = 214, gap = 20, padX = 18, padTop = 12, padBottom = 8,
	eyebrow = 12, title = 26, body = 13.5, item = 13.5, desc = 13, foot = 11, button = 38, -- 시안보다 조금 크다: 실제 글꼴이 좁아 휴대폰 높이에 여유가 있다
	fillX = 0.95, fillY = 0.98,
}
local COMPACT_BELOW = Vector2.new(720, 440) -- 쓸 수 있는 넓이·높이가 이보다 작으면 COMPACT
local MAX_SCALE = 1.6 -- 큰 화면에서 키우는 한계

local STRIP = Color3.fromHex("c4502f")
local PANEL = Color3.fromHex("1b2023")
local HEADING = Color3.fromHex("8fd0b8")
local TITLE = Color3.fromHex("eef0ec")
local BODY = Color3.fromHex("d4d8d3")
local LINE = Color3.fromHex("39423f")
local BUTTON = Color3.fromHex("3b8d74")
local FOOT = Color3.fromHex("9aa39f")
local DIM = Color3.fromHex("080a0c")

local REGULAR_FONT = Font.fromEnum(Enum.Font.BuilderSans)
local BOLD_FONT = Font.fromEnum(Enum.Font.BuilderSansBold)

local DISPLAY_ORDER = 100 -- 시간대 버튼·터치 조작 위
local CLOSE_ACTION = "IntroClose"

-- 내용만큼 세로로 늘어나는 세로 줄
local function stack(parent: Instance, order: number, gap: number): Frame
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, gap)
	layout.Parent = f
	f.Parent = parent
	return f
end

local function label(parent: Instance, order: number, str: string, size: number, color: Color3, font: Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.fromScale(1, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.FontFace = font or REGULAR_FONT
	l.TextSize = size
	l.TextColor3 = color
	l.Text = str
	l.Parent = parent
	return l
end

local function panel(parent: Instance, m: typeof(REGULAR), place: Place, text: (string) -> string, close: () -> ()): (Frame, UIScale)
	local root = stack(parent, 0, 0)
	root.Name = "Panel"
	root.Size = UDim2.fromOffset(m.width, 0)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.BackgroundTransparency = 0
	root.BackgroundColor3 = PANEL
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, 0, 4)
	strip.BackgroundColor3 = STRIP
	strip.BorderSizePixel = 0
	strip.Parent = root

	local body = stack(root, 1, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, m.padTop)
	padding.PaddingBottom = UDim.new(0, m.padBottom)
	padding.PaddingLeft = UDim.new(0, m.padX)
	padding.PaddingRight = UDim.new(0, m.padX)
	padding.Parent = body

	-- 왼쪽(머리글·제목·소개글) | 세로줄 | 오른쪽(할 수 있는 일)
	local columns = Instance.new("Frame")
	columns.LayoutOrder = 1
	columns.Size = UDim2.fromScale(1, 0)
	columns.AutomaticSize = Enum.AutomaticSize.Y
	columns.BackgroundTransparency = 1
	columns.Parent = body

	local left = stack(columns, 0, 2)
	left.Size = UDim2.fromOffset(m.left, 0)
	label(left, 1, text(place.eyebrow), m.eyebrow, HEADING)
	label(left, 2, text(place.title), m.title, TITLE, BOLD_FONT)
	label(left, 3, text(place.intro), m.body, BODY)

	local rightX = m.left + m.gap
	local line = Instance.new("Frame")
	line.Position = UDim2.fromOffset(rightX, 0)
	line.Size = UDim2.new(0, 1, 1, 0)
	line.BackgroundColor3 = LINE
	line.BorderSizePixel = 0
	line.Parent = columns

	local right = stack(columns, 0, 6)
	right.Position = UDim2.fromOffset(rightX + m.gap, 0)
	right.Size = UDim2.new(1, -(rightX + m.gap), 0, 0)
	for n, item in place.items do
		local row = stack(right, n, 0)
		label(row, 1, text(item.title), m.item, HEADING, BOLD_FONT)
		label(row, 2, text(item.desc), m.desc, BODY)
	end

	local button = Instance.new("TextButton")
	button.Name = "Start"
	button.LayoutOrder = 2
	button.Size = UDim2.fromOffset(0, m.button)
	button.AutomaticSize = Enum.AutomaticSize.X
	button.BackgroundColor3 = BUTTON
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.new(1, 1, 1)
	button.FontFace = BOLD_FONT
	button.TextSize = m.body + 1
	button.Text = text("intro.start")
	local buttonPad = Instance.new("UIPadding")
	buttonPad.PaddingLeft = UDim.new(0, 42)
	buttonPad.PaddingRight = UDim.new(0, 42)
	buttonPad.Parent = button
	button.Activated:Connect(close)
	button.Parent = body

	local foot = label(body, 3, text(place.source), m.foot, FOOT)
	foot.TextXAlignment = Enum.TextXAlignment.Center
	return root, scale
end

local Intro = {}

-- container 크기에 맞춰 패널을 짓고, 크기가 바뀌면 다시 맞춘다
function Intro.build(container: GuiBase2d, place: Place, text: (string) -> string, close: () -> ())
	local metrics: typeof(REGULAR)? = nil
	local root: Frame, scale: UIScale
	local function fit()
		local area = container.AbsoluteSize
		local m = if area.X < COMPACT_BELOW.X or area.Y < COMPACT_BELOW.Y then COMPACT else REGULAR
		if m ~= metrics then
			metrics = m
			if root then
				root:Destroy()
			end
			root, scale = panel(container, m, place, text, close)
			root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		end
		-- AbsoluteSize에는 UIScale이 곱해져 있다
		local natural = root.AbsoluteSize / scale.Scale
		if natural.Y > 0 then
			local want = math.min(MAX_SCALE, area.X * m.fillX / natural.X, area.Y * m.fillY / natural.Y)
			if math.abs(want - scale.Scale) > 0.01 then
				scale.Scale = want
			end
		end
	end
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

-- 클라이언트 시작 때 한 번 부른다
function Intro.start(place: Place)
	local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local function layer(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
		local gui = Instance.new("ScreenGui")
		gui.Name = name
		gui.ResetOnSpawn = false
		gui.DisplayOrder = order
		gui.ScreenInsets = insets
		gui.Parent = playerGui
		return gui
	end

	-- 뒤 화면 덮개는 상단 바 밑까지 온 화면, 패널은 상단 바·노치 안쪽 (ScreenGui가 따로인 이유)
	local dimGui = layer("IntroDim", DISPLAY_ORDER, Enum.ScreenInsets.None)
	local dim = Instance.new("TextButton") -- 버튼이라야 뒤 UI로 입력이 새지 않는다
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = DIM
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.AutoButtonColor = false
	dim.Selectable = false
	dim.Modal = true -- 일인칭·시프트 락에서도 마우스를 풀어 준다
	dim.Text = ""
	dim.Parent = dimGui
	local gui = layer("Intro", DISPLAY_ORDER + 1, Enum.ScreenInsets.CoreUISafeInsets)

	ProximityPromptService.Enabled = false -- 안내가 떠 있는 동안 E 키·프롬프트로 화차가 발사되지 않게

	local function close()
		ContextActionService:UnbindAction(CLOSE_ACTION)
		ProximityPromptService.Enabled = true
		dimGui:Destroy()
		gui:Destroy()
	end

	-- 게임패드 A는 선택 상태와 상관없이 닫는다 (점프로 새지 않는다)
	ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonA)

	Intro.build(gui, place, require(script.Parent.I18n).text, close)
end

return Intro
