--!strict
-- 지붕 분해(B안, 층별): 표식에서 누르면 내 화면에서만 문루가 겹별로 떠올라 벌어지고, 다시 누르면 맞물린다.
-- 분해 순서: 상층 전체를 들어 올림 → 상층 겹을 위 겹부터 → 하층 겹을 위 겹부터. 조립은 그 반대.
-- 부재는 Attribute 두 개로 찾는다: SplitLayer(겹 키) · SplitStory("lower" | "upper"). 서버 생성기가 mark로 붙인다.
-- 띄울 높이는 겹의 실제 높이 범위(세계 Y 경계)로 계산한다: 위 겹 밑이 아래 겹 위보다 틈(gap)만큼 위에 오게 쌓는다.
--   하층 맨 아래 겹은 틈만큼 뜨고, 상층은 통째로 다 벌어진 하층 맨 위 겹 위로 틈만큼 들어 올린다.
-- 소리: 아래에서 위로 쌓인 이웃 묶음 사이(육축–하층 기둥, 하층 겹 사이, 하층 기와–상층 기둥, 상층 겹 사이)를 "접촉"으로 두고,
--   매 프레임 두 묶음의 Y 오프셋 차가 contactEpsilon을 처음 넘는 프레임에 분리 소리, 다시 그 아래로 내려오는 프레임에 맞물림 소리를 낸다.
-- 이동: 겹마다 Y 오프셋 하나를 RenderStepped에서 보간해 그 겹 부재 전체를 workspace:BulkMoveTo로 한 번에 옮긴다
--   (부재 수천 개를 하나씩 Tween하지 않는다). 처음 CFrame은 처음 한 번 저장하고, 조립 끝에 그 값을 그대로 다시 쓴다.
-- 이 파일은 서버(mark)와 클라이언트(start)가 같이 require한다. 클라이언트 전용 모듈(I18n)은 start 안에서만 부른다.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Tags = require(script.Parent.Tags)
local Units = require(script.Parent.Units)

export type Story = "lower" | "upper"
export type Sfx = { id: number, volume: number, speed: number?, offset: number? } -- id 0 = 소리 없음. offset = 음원 앞 무음을 건너뛸 초
export type Config = {
	layers: { { key: string, members: { string } } }, -- 위 겹 → 아래 겹. members = 이 겹에 드는 부재 이름(Part.Name)
	gap: number, -- 겹 사이 틈 (m)
	leaveDistance: number, -- 표식에서 이만큼(m) 멀어지면 저절로 조립
	sounds: { split: Sfx, join: Sfx }, -- split = 접촉이 떨어지는 순간, join = 접촉이 다시 닿는 순간
	contactEpsilon: number, -- 접촉이 떨어졌다/닿았다고 보는 틈 (m)
	leadMs: number, -- 소리를 접촉 순간보다 이만큼(ms) 먼저 낸다 (귀로 맞추는 보정, 기본 0)
	timeScale: number, -- 움직임 빠르기 배율. 1 = 보통, 0.25 = 4배 느리게 (귀로 확인용)
}

local RoofSplit = {}
RoofSplit.LAYER = "SplitLayer"
RoofSplit.STORY = "SplitStory"

-- 움직임 (모든 Place 공통)
local DUR = 0.7 -- 한 단계가 오르내리는 시간(초)
local STAGGER = 0.3 -- 단계 사이 시작 간격(초)
local PAUSE = 0.35 -- 상층을 들어 올린 뒤 겹이 벌어지기까지 쉬는 시간(초)
local POOL = 4 -- 소리마다 미리 붙여 두고 돌려 쓰는 Sound 수 (겹쳐 울리기용)

local lookups: { [Config]: { [string]: string } } = {}
local warned: { [string]: boolean } = {}

-- 서버: target(BasePart 하나 또는 그 아래 전체)에 층과 겹을 붙인다. layer를 주면 이름과 상관없이 그 겹
function RoofSplit.mark(target: Instance, story: Story, config: Config, layer: string?)
	local lookup = lookups[config]
	if not lookup then
		lookup = {}
		for _, l in config.layers do
			for _, name in l.members do
				lookup[name] = l.key
			end
		end
		lookups[config] = lookup
	end
	local function apply(p: BasePart)
		local key = layer or lookup[p.Name]
		if not key then
			if not warned[p.Name] then
				warned[p.Name] = true
				warn(`지붕 분해: 겹이 정해지지 않은 부재 {p.Name} (Place 데이터 layers에 이름을 넣는다)`)
			end
			return
		end
		p:SetAttribute(RoofSplit.LAYER, key)
		p:SetAttribute(RoofSplit.STORY, story)
	end
	if target:IsA("BasePart") then
		apply(target)
	end
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") then
			apply(d)
		end
	end
end

type Group = {
	parts: { BasePart },
	orig: { CFrame },
	buf: { CFrame },
	minY: number,
	maxY: number,
	lift: number, -- 층 안에서 이 겹이 뜨는 높이(스터드)
	upper: boolean,
	step: number,
	applied: number,
}

type Contact = { below: Group?, above: Group, open: boolean } -- below nil = 육축(움직이지 않음)

-- 세계 Y 경계 (회전한 상자의 세로 반높이)
local function yRange(cf: CFrame, size: Vector3): (number, number)
	local h = math.abs(cf.RightVector.Y) * size.X / 2 + math.abs(cf.UpVector.Y) * size.Y / 2 + math.abs(cf.LookVector.Y) * size.Z / 2
	return cf.Y - h, cf.Y + h
end

-- 위 겹 → 아래 겹 목록에 띄울 높이를 매긴다. 맨 아래 겹은 base
local function stack(list: { Group }, base: number, gap: number)
	for i = #list, 1, -1 do
		local g, below = list[i], list[i + 1]
		g.lift = if below then below.lift + below.maxY + gap - g.minY else base
	end
end

-- 클라이언트: 표식 프롬프트를 달고 분해·조립을 돌린다
function RoofSplit.start(config: Config)
	local I18n = require(script.Parent.I18n)
	local S = Units.studs(1)
	local gap = config.gap * S

	local groups: { Group }? = nil
	local up = 0 -- 상층 전체를 들어 올리는 높이(스터드)
	local nSteps = 0
	local collided: { BasePart } = {}
	local contacts: { Contact } = {}

	local function collect(): { Group }
		local order: { [string]: number } = {}
		for i, l in config.layers do
			order[l.key] = i
		end
		local by: { [string]: Group } = {}
		for _, d in workspace:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			local key, story = d:GetAttribute(RoofSplit.LAYER), d:GetAttribute(RoofSplit.STORY)
			if type(key) ~= "string" or not order[key] or (story ~= "lower" and story ~= "upper") then
				continue
			end
			local id = `{story}/{key}`
			local g = by[id]
			if not g then
				g = { parts = {}, orig = {}, buf = {}, minY = math.huge, maxY = -math.huge, lift = 0, upper = story == "upper", step = 0, applied = 0 }
				by[id] = g
			end
			local lo, hi = yRange(d.CFrame, d.Size)
			table.insert(g.parts, d)
			table.insert(g.orig, d.CFrame)
			g.minY, g.maxY = math.min(g.minY, lo), math.max(g.maxY, hi)
		end
		local lower, upper = {}, {}
		for _, l in config.layers do
			table.insert(lower, by[`lower/{l.key}`])
			table.insert(upper, by[`upper/{l.key}`])
		end
		stack(lower, gap, gap)
		stack(upper, 0, gap)
		up = if #lower > 0 and #upper > 0 then lower[1].lift + lower[1].maxY + gap - upper[#upper].minY else 0
		-- 단계: 1 = 상층 들어 올리기, 그다음 상층 겹(위부터), 하층 겹(위부터)
		local all = {}
		for i, g in upper do
			g.step = 1 + i
			table.insert(all, g)
		end
		for i, g in lower do
			g.step = 1 + #upper + i
			table.insert(all, g)
		end
		nSteps = 1 + #upper + #lower
		-- 접촉: 아래에서 위로 쌓인 차례의 이웃 묶음 (하층 기둥 → … → 하층 기와 → 상층 기둥 → … → 상층 기와)
		local chain: { Group } = {}
		for i = #lower, 1, -1 do
			table.insert(chain, lower[i])
		end
		for i = #upper, 1, -1 do
			table.insert(chain, upper[i])
		end
		for i, g in chain do
			table.insert(contacts, { below = chain[i - 1], above = g, open = false })
		end
		return all
	end

	-- 소리: 미리 불러 붙여 둔 Sound를 돌려 쓴다 (울리는 순간에 만들거나 복제하지 않는다)
	local pools: { [string]: { sounds: { Sound }, next: number, offset: number } } = {}
	local preload: { Instance } = {}
	for kind, sfx in config.sounds :: { [string]: Sfx } do
		if sfx.id ~= 0 then
			local list = {}
			for i = 1, POOL do
				local s = Instance.new("Sound")
				s.Name = `RoofSplit_{kind}`
				s.SoundId = `rbxassetid://{sfx.id}`
				s.Volume = sfx.volume
				s.PlaybackSpeed = sfx.speed or 1
				s.Parent = SoundService
				table.insert(list, s)
			end
			pools[kind] = { sounds = list, next = 1, offset = sfx.offset or 0 }
			table.insert(preload, list[1])
		end
	end
	task.spawn(function()
		game:GetService("ContentProvider"):PreloadAsync(preload)
	end)
	local function play(kind: string)
		local pool = pools[kind]
		if not pool then
			return
		end
		local s = pool.sounds[pool.next]
		pool.next = pool.next % #pool.sounds + 1
		s.TimePosition = pool.offset
		s:Play()
	end

	local state: "assembled" | "splitting" | "split" | "joining" = "assembled"
	local pendingJoin = false
	local prompts: { ProximityPrompt } = {}
	local markerAt: Vector3? = nil -- 마지막으로 누른 표식 자리 (표식이 스트리밍으로 빠져도 거리를 잰다)

	local function refresh()
		local busy = state == "splitting" or state == "joining"
		for _, p in prompts do
			p.Enabled = not busy
			p.ActionText = I18n(if state == "assembled" then "roofSplit.split" else "roofSplit.join")
		end
	end

	local function move(g: Group, y: number)
		for i, cf in g.orig do
			g.buf[i] = cf + Vector3.new(0, y, 0)
		end
		workspace:BulkMoveTo(g.parts, g.buf, Enum.BulkMoveMode.FireCFrameChanged)
		g.applied = y
	end

	local run: (boolean) -> ()

	run = function(opening: boolean)
		if not groups then
			groups = collect()
		end
		local gs = groups :: { Group }
		state = if opening then "splitting" else "joining"
		refresh()
		if opening then
			-- 떠 있는 동안 내 캐릭터가 부재에 걸리지 않게
			for _, g in gs do
				for _, p in g.parts do
					if p.CanCollide then
						p.CanCollide = false
						table.insert(collided, p)
					end
				end
			end
		end
		local function startOf(k: number): number
			local j = if opening then k - 1 else nSteps - k
			local pause = if opening then (if k > 1 then PAUSE else 0) else (if k == 1 then PAUSE else 0)
			return j * STAGGER + pause
		end
		-- 시각 t(초)의 단계별 진행 (0 = 제자리, 1 = 다 벌어짐). 분해는 바로 출발(easeOutCubic), 조립은 속도를 실은 채 닿는다(easeInCubic)
		local function progress(t: number): { number }
			local P = {}
			for k = 1, nSteps do
				local raw = math.clamp((t - startOf(k)) / DUR, 0, 1)
				P[k] = if opening then 1 - (1 - raw) ^ 3 else 1 - raw ^ 3
			end
			return P
		end
		local function yOf(g: Group?, P: { number }): number
			if not g then
				return 0
			end
			return (if g.upper then up * P[1] else 0) + g.lift * P[g.step]
		end
		local total = startOf(if opening then nSteps else 1) + DUR
		local eps = config.contactEpsilon * S
		local lead = config.leadMs / 1000 * config.timeScale
		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - t0) * config.timeScale
			local done = t >= total
			local P = progress(t)
			-- 접촉이 열리고 닫히는 순간에 소리 (leadMs만큼 앞선 시각의 상태로 판정)
			local L = if lead > 0 then progress(t + lead) else P
			for _, c in contacts do
				local rel = yOf(c.above, L) - yOf(c.below, L)
				if not c.open and rel > eps then
					c.open = true
					play("split")
				elseif c.open and rel < eps then
					c.open = false
					play("join")
				end
			end
			for _, g in gs do
				if done and not opening then
					workspace:BulkMoveTo(g.parts, g.orig, Enum.BulkMoveMode.FireCFrameChanged) -- 처음 CFrame 그대로
					g.applied = 0
				else
					local y = yOf(g, P)
					if math.abs(y - g.applied) > 1e-4 then
						move(g, y)
					end
				end
			end
			if not done then
				return
			end
			conn:Disconnect()
			if opening then
				state = "split"
			else
				state = "assembled"
				for _, p in collided do
					p.CanCollide = true
				end
				table.clear(collided)
			end
			refresh()
			if pendingJoin and state == "split" then
				pendingJoin = false
				run(false)
			end
		end)
	end

	local function attach(inst: Instance)
		if not inst:IsA("BasePart") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = inst
		table.insert(prompts, prompt)
		refresh()
		prompt.Triggered:Connect(function()
			markerAt = inst.Position
			if state == "assembled" then
				run(true)
			elseif state == "split" then
				run(false)
			end
		end)
		prompt.Destroying:Connect(function()
			local i = table.find(prompts, prompt)
			if i then
				table.remove(prompts, i)
			end
		end)
	end
	for _, inst in CollectionService:GetTagged(Tags.ROOF_SPLIT_MARKER) do
		attach(inst)
	end
	CollectionService:GetInstanceAddedSignal(Tags.ROOF_SPLIT_MARKER):Connect(attach)

	-- 표식에서 멀어지면 저절로 조립 (벌어지는 중이면 다 벌어진 뒤)
	local player = Players.LocalPlayer
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 or (state ~= "split" and state ~= "splitting") then
			return
		end
		acc = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local at = markerAt
		if not (root and root:IsA("BasePart") and at) then
			return
		end
		if (root.Position - at).Magnitude > config.leaveDistance * S then
			if state == "split" then
				run(false)
			else
				pendingJoin = true
			end
		end
	end)
end

return RoofSplit
