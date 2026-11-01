--!strict
-- 분해 공통 엔진(클라이언트): 분해 표식에서 누르면 내 화면에서만 겹들이 떠올라 벌어지고, 다시 누르면 맞물린다.
-- 지붕 분해(core RoofSplit)와 모형 분해(Place 데이터 + Split.byBottom)가 같이 쓴다. 겹을 어떻게 나누고 얼마나 띄울지는
-- 부르는 쪽이 collect로 정해 넘기고(Plan), 여기서는 움직임·소리·제자리 복원·프롬프트·멀어지면 조립만 맡는다.
-- 이동: 겹마다 Y 오프셋 = Σ rise × (그 단계 진행). RenderStepped에서 겹 부재 전체를 workspace:BulkMoveTo로 한 번에 옮긴다.
--   처음 CFrame은 collect 때 한 번 저장하고, 조립 끝에 그 값을 그대로 다시 쓴다.
-- 소리: Plan.groups의 이웃 겹(아래 → 위, 맨 아래 겹은 움직이지 않는 바닥과)을 "접촉"으로 두고, 매 프레임 두 겹의 오프셋 차가
--   contactEpsilon을 처음 넘는 프레임에 분리 소리, 다시 그 아래로 내려오는 프레임에 맞물림 소리를 낸다.
-- 시간: 단계 k는 분해 때 (k−1)×STAGGER (+ k>1이면 pause) 에 출발해 easeOutCubic, 조립은 역순으로 easeInCubic.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Units = require(script.Parent.Units)

export type Sfx = { id: number, volume: number, speed: number?, offset: number? } -- id 0 = 소리 없음. offset = 음원 앞 무음을 건너뛸 초
export type Settings = {
	leaveDistance: number, -- 표식에서 이만큼(m) 멀어지면 저절로 조립
	sounds: { split: Sfx, join: Sfx }, -- split = 접촉이 떨어지는 순간, join = 접촉이 다시 닿는 순간
	contactEpsilon: number, -- 접촉이 떨어졌다/닿았다고 보는 틈 (m)
	leadMs: number, -- 소리를 접촉 순간보다 이만큼(ms) 먼저 낸다 (귀로 맞추는 보정, 기본 0)
	timeScale: number, -- 움직임 빠르기 배율. 1 = 보통, 0.25 = 4배 느리게 (귀로 확인용)
}
export type Move = { step: number, rise: number } -- 단계 step이 진행되는 만큼 rise(스터드) 오른다
export type Layer = { parts: { BasePart }, moves: { Move } } -- 겹 하나
export type Plan = {
	groups: { Layer }, -- 아래 겹 → 위 겹 (이웃끼리 접촉)
	steps: number,
	pause: number, -- 분해 때 단계 1 뒤, 조립 때 단계 1 앞에 쉬는 시간(초)
}

local Split = {}

-- 움직임 (모든 Place 공통)
local DUR = 0.7 -- 한 단계가 오르내리는 시간(초)
local STAGGER = 0.3 -- 단계 사이 시작 간격(초)
local POOL = 4 -- 소리마다 미리 붙여 두고 돌려 쓰는 Sound 수 (겹쳐 울리기용)

type Group = { parts: { BasePart }, orig: { CFrame }, buf: { CFrame }, moves: { Move }, applied: number }
type Contact = { below: Group?, above: Group, open: boolean } -- below nil = 움직이지 않는 바닥

-- 모형 분해 도우미: 부재를 밑면 높이(같은 단위, tolerance 안이면 같은 줄)로 겹을 나누고, 아래 겹부터 차례로
-- 그 겹과 위 겹 전체를 gap(스터드)만큼 들어 올리는 Plan. 맨 아래 겹은 움직이지 않는다
function Split.byBottom(items: { { part: BasePart, bottom: number } }, tolerance: number, gap: number): Plan
	table.sort(items, function(a, b)
		return a.bottom < b.bottom
	end)
	local groups: { Layer } = {}
	local last = -math.huge
	for _, it in items do
		if #groups == 0 or it.bottom - last > tolerance then
			last = it.bottom
			local moves = {}
			for k = 1, #groups do
				table.insert(moves, { step = k, rise = gap })
			end
			table.insert(groups, { parts = {}, moves = moves })
		end
		table.insert(groups[#groups].parts, it.part)
	end
	return { groups = groups, steps = math.max(#groups - 1, 0), pause = 0 }
end

-- tag가 붙은 표식(BasePart)에 프롬프트를 달고 분해·조립을 돌린다. collect는 처음 누를 때 한 번, 누른 표식과 함께 부른다
function Split.start(settings: Settings, tag: string, collect: (marker: BasePart) -> Plan)
	local I18n = require(script.Parent.I18n).text
	local S = Units.studs(1)

	local gs: { Group }? = nil
	local nSteps, pauseT = 0, 0
	local collided: { BasePart } = {}
	local contacts: { Contact } = {}

	local function prepare(marker: BasePart): { Group }
		local plan = collect(marker)
		nSteps, pauseT = plan.steps, plan.pause
		local out: { Group } = {}
		for i, l in plan.groups do
			local orig = {}
			for j, p in l.parts do
				orig[j] = p.CFrame
			end
			local g = { parts = l.parts, orig = orig, buf = {}, moves = l.moves, applied = 0 }
			table.insert(contacts, { below = out[i - 1], above = g, open = false })
			table.insert(out, g)
		end
		return out
	end

	-- 소리: 미리 불러 붙여 둔 Sound를 돌려 쓴다 (울리는 순간에 만들거나 복제하지 않는다)
	local pools: { [string]: { sounds: { Sound }, next: number, offset: number } } = {}
	local preload: { Instance } = {}
	for kind, sfx in settings.sounds :: { [string]: Sfx } do
		if sfx.id ~= 0 then
			local list = {}
			for _ = 1, POOL do
				local s = Instance.new("Sound")
				s.Name = `Split_{kind}`
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
		local groups = gs :: { Group }
		state = if opening then "splitting" else "joining"
		refresh()
		if opening then
			-- 떠 있는 동안 내 캐릭터가 부재에 걸리지 않게
			for _, g in groups do
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
			local pause = if opening then (if k > 1 then pauseT else 0) else (if k == 1 then pauseT else 0)
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
			local y = 0
			for _, m in g.moves do
				y += m.rise * P[m.step]
			end
			return y
		end
		local total = startOf(if opening then nSteps else 1) + DUR
		local eps = settings.contactEpsilon * S
		local lead = settings.leadMs / 1000 * settings.timeScale
		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - t0) * settings.timeScale
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
			for _, g in groups do
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
			if not gs then
				gs = prepare(inst)
			end
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
	for _, inst in CollectionService:GetTagged(tag) do
		attach(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(attach)

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
		if (root.Position - at).Magnitude > settings.leaveDistance * S then
			if state == "split" then
				run(false)
			else
				pendingJoin = true
			end
		end
	end)
end

return Split
