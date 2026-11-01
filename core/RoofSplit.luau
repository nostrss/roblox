--!strict
-- 지붕 분해(B안, 층별): 표식에서 누르면 내 화면에서만 문루가 겹별로 떠올라 벌어지고, 다시 누르면 맞물린다.
-- 분해 순서: 상층 전체를 들어 올림 → 상층 겹을 위 겹부터 → 하층 겹을 위 겹부터. 조립은 그 반대.
-- 부재는 Attribute 두 개로 찾는다: SplitLayer(겹 키) · SplitStory("lower" | "upper"). 서버 생성기가 mark로 붙인다.
-- 띄울 높이는 겹의 실제 높이 범위(세계 Y 경계)로 계산한다: 위 겹 밑이 아래 겹 위보다 틈(gap)만큼 위에 오게 쌓는다.
--   하층 맨 아래 겹은 틈만큼 뜨고, 상층은 통째로 다 벌어진 하층 맨 위 겹 위로 틈만큼 들어 올린다.
-- 소리 판정·움직임·제자리 복원·프롬프트·멀어지면 조립은 core Split이 맡는다. 여기서는 겹을 모으고 띄울 높이와 단계를 정한다.
-- 접촉 차례: 육축–하층 기둥, 하층 겹 사이, 하층 기와–상층 기둥, 상층 겹 사이 (아래 → 위).
-- 이 파일은 서버(mark)와 클라이언트(start)가 같이 require한다.
local Split = require(script.Parent.Split)
local Tags = require(script.Parent.Tags)
local Units = require(script.Parent.Units)

export type Story = "lower" | "upper"
export type Sfx = Split.Sfx
export type Config = Split.Settings & {
	layers: { { key: string, members: { string } } }, -- 위 겹 → 아래 겹. members = 이 겹에 드는 부재 이름(Part.Name)
	gap: number, -- 겹 사이 틈 (m)
}

local RoofSplit = {}
RoofSplit.LAYER = "SplitLayer"
RoofSplit.STORY = "SplitStory"

local PAUSE = 0.35 -- 상층을 들어 올린 뒤 겹이 벌어지기까지 쉬는 시간(초)

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

type Group = { parts: { BasePart }, minY: number, maxY: number, lift: number, upper: boolean, step: number }

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

-- 클라이언트: Attribute로 겹을 모아 Split.Plan을 만들고 core Split에 맡긴다
function RoofSplit.start(config: Config)
	local gap = config.gap * Units.studs(1)
	Split.start(config, Tags.ROOF_SPLIT_MARKER, function(): Split.Plan
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
				g = { parts = {}, minY = math.huge, maxY = -math.huge, lift = 0, upper = story == "upper", step = 0 }
				by[id] = g
			end
			local lo, hi = yRange(d.CFrame, d.Size)
			table.insert(g.parts, d)
			g.minY, g.maxY = math.min(g.minY, lo), math.max(g.maxY, hi)
		end
		local lower, upper = {}, {}
		for _, l in config.layers do
			table.insert(lower, by[`lower/{l.key}`])
			table.insert(upper, by[`upper/{l.key}`])
		end
		stack(lower, gap, gap)
		stack(upper, 0, gap)
		local up = if #lower > 0 and #upper > 0 then lower[1].lift + lower[1].maxY + gap - upper[#upper].minY else 0
		-- 단계: 1 = 상층 들어 올리기, 그다음 상층 겹(위부터), 하층 겹(위부터)
		for i, g in upper do
			g.step = 1 + i
		end
		for i, g in lower do
			g.step = 1 + #upper + i
		end
		-- 접촉 차례: 아래에서 위로 (하층 기둥 → … → 하층 기와 → 상층 기둥 → … → 상층 기와). 하층 기둥 아래는 육축
		local groups: { Split.Layer } = {}
		local function add(g: Group)
			local moves = if g.upper then { { step = 1, rise = up }, { step = g.step, rise = g.lift } } else { { step = g.step, rise = g.lift } }
			table.insert(groups, { parts = g.parts, moves = moves })
		end
		for i = #lower, 1, -1 do
			add(lower[i])
		end
		for i = #upper, 1, -1 do
			add(upper[i])
		end
		return { groups = groups, steps = 1 + #upper + #lower, pause = PAUSE }
	end)
end

return RoofSplit
