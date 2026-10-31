--!strict
-- 숭례문 회색 박스: Dimensions 실측값으로 덩어리 형태를 세운다. 세부 형태(곡선 지붕·공포·기와)는 Studio에서.
-- 원점 = 문루 중심의 지면, 정면(남) = +Z, 동 = +X.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local WallStones = require(ReplicatedStorage.Shared.WallStones)

local s = Units.studs
local L = D.level

local STONE = Color3.fromRGB(150, 150, 145)
local MORTAR = Color3.fromRGB(95, 95, 92)
local GRANITE = Color3.fromRGB(200, 196, 186)
local WOOD = Color3.fromRGB(120, 70, 50)
local ROOF = Color3.fromRGB(70, 70, 75)

-- 실측 가정값(도면에 없음). ponytail: 회색 박스용 근사, 실제 형태는 Studio 모델로 대체
local PARAPET_THICKNESS = 0.6
local BASE_MARGIN = 0.6 -- 문루 기단이 하층 기둥 중심 밖으로 나간 거리
local STONE_DEPTH = 0.3 -- 면에 붙이는 돌 두께
local JOINT = 0.015 -- 줄눈 절반 폭 (도면 사각형을 이만큼씩 줄인다)

local function y(level: number): number -- T.B.M. 기준 높이 → 지면 기준 높이
	return level - L.ground
end

local function positions(bays: { number }): { number } -- 주칸 → 중심 기준 기둥 좌표
	local total = 0
	for _, b in bays do
		total += b
	end
	local out = { -total / 2 }
	for _, b in bays do
		table.insert(out, out[#out] + b)
	end
	return out
end

return function()
	if workspace:FindFirstChild("SungnyemunGreybox") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "SungnyemunGreybox"

	local function part(name: string, cf: CFrame, size: Vector3, color: Color3, class: string?): BasePart
		local p = Instance.new((class or "Part") :: any) :: BasePart
		p.Name = name
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.Size = size
		p.CFrame = cf
		p.Parent = model
		return p
	end

	-- 두 꼭짓점(m)으로 블록
	local function block(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3): BasePart
		return part(
			name,
			CFrame.new(s((x0 + x1) / 2), s((y0 + y1) / 2), s((z0 + z1) / 2)),
			Vector3.new(s(x1 - x0), s(y1 - y0), s(z1 - z0)),
			color
		)
	end

	-- 석축: 남·북 반쪽마다 홍예 통로 폭이 다르다. ponytail: 통로 천장은 평평, 아치 곡선은 Studio에서
	local W, Dp, H = D.wall.width, D.wall.depth, y(0)
	local crown = y(D.arch.crown)
	for _, half in { { "South", 0, Dp / 2, D.arch.southWidth }, { "North", -Dp / 2, 0, D.arch.northWidth } } do
		local name, z0, z1, w = half[1] :: string, half[2] :: number, half[3] :: number, half[4] :: number
		block("Wall" .. name .. "West", -W / 2, 0, z0, -w / 2, H, z1, MORTAR)
		block("Wall" .. name .. "East", w / 2, 0, z0, W / 2, H, z1, MORTAR)
		block("Wall" .. name .. "OverArch", -w / 2, crown, z0, w / 2, H, z1, MORTAR)
	end

	-- 남측면 돌: 도면의 돌 사각형을 면 앞에 붙인다. 땅에 묻힌 부분은 자르고, 홍예 통로를 막는 돌은 뺀다.
	local rng = Random.new(1)
	local aw, faceZ = D.arch.southWidth, Dp / 2
	for _, st in WallStones.south do
		local x0, y0, x1, y1 = st[1] + JOINT, math.max(H + st[2] + JOINT, 0), st[3] - JOINT, H + st[4] - JOINT
		local inOpening = x1 > -aw / 2 and x0 < aw / 2 and y0 < crown
		if y1 > y0 and not inOpening then
			local out = faceZ + rng:NextNumber(0.01, 0.05) -- 돌마다 튀어나온 정도를 달리해 겹친 면 깜빡임을 막는다
			local p = block("Stone", x0, y0, out - STONE_DEPTH, x1, y1, out, GRANITE)
			p.Material = Enum.Material.Limestone
			p.Color = GRANITE:Lerp(Color3.fromRGB(120, 115, 105), rng:NextNumber(0, 0.25))
		end
	end

	-- 여장
	local t, top = PARAPET_THICKNESS, y(L.parapetTop)
	block("ParapetSouth", -W / 2, H, Dp / 2 - t, W / 2, top, Dp / 2, STONE)
	block("ParapetNorth", -W / 2, H, -Dp / 2, W / 2, top, -Dp / 2 + t, STONE)
	block("ParapetWest", -W / 2, H, -Dp / 2 + t, -W / 2 + t, top, Dp / 2 - t, STONE)
	block("ParapetEast", W / 2 - t, H, -Dp / 2 + t, W / 2, top, Dp / 2 - t, STONE)

	-- 문루 기단 (기둥·창방·평방은 Chukbu)
	local xs, zs = positions(D.lowerBays), positions(D.lowerSideBays)
	local ux, uz = positions(D.upperBays), positions(D.upperSideBays)
	local lx, lz = xs[#xs], zs[#zs] -- 하층 기둥열 반폭
	local m = BASE_MARGIN
	block("PavilionBase", -lx - m, H, -lz - m, lx + m, y(L.pavilionFloor), lz + m, STONE)

	-- 상층 벽·공포대: 기둥 위~처마선을 기둥열 크기 덩어리로 채운다. ponytail: 상층 공포·창호는 부재로 교체 예정
	local px, pz = ux[#ux], uz[#uz]
	block("UpperWall", -px, y(L.upperFloor), -pz, px, y(L.upperColumnTop), pz, WOOD)
	block("UpperBrackets", -px, y(L.upperColumnTop), -pz, px, y(L.upperEave), pz, WOOD)

	-- 하층 지붕: 외목도리 위~상층 마루를 채운 판. ponytail: 경사·곡선 없음
	local lo = D.eaveOverhang.lower
	block("LowerRoof", -lx - lo, y(L.lowerEave + 0.400), -lz - lo, lx + lo, y(L.upperFloor), lz + lo, ROOF) -- 0.400 = 외목도리 지름(S4 099)

	-- 상층 지붕: 앞뒤 두 경사면(박공 형태). ponytail: 우진각 모서리·처마 곡선은 Studio 모델로
	local hx, hz = ux[#ux] + D.eaveOverhang.upper, uz[#uz] + D.eaveOverhang.upper
	local y0, y1 = y(L.upperEave), y(L.ridgeTop)
	local size = Vector3.new(s(hx * 2), s(y1 - y0), s(hz))
	local mid = s((y0 + y1) / 2)
	part("UpperRoofSouth", CFrame.new(0, mid, s(hz / 2)) * CFrame.Angles(0, math.pi, 0), size, ROOF, "WedgePart")
	part("UpperRoofNorth", CFrame.new(0, mid, s(-hz / 2)), size, ROOF, "WedgePart")

	-- 남쪽 광장 시작 위치
	local spawnPoint = Instance.new("SpawnLocation")
	spawnPoint.Anchored = true
	spawnPoint.Size = Vector3.new(12, 1, 12)
	spawnPoint.CFrame = CFrame.new(0, 0.5, s(Dp / 2 + 20))
	spawnPoint.Parent = model

	CollectionService:AddTag(model, Tags.GREYBOX)
	model.Parent = workspace
end
