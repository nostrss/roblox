--!strict
-- 숭례문 광장 바닥·둘레 보도·도로·횡단보도 (데이터 Shared.Plaza, 높이 모형 ADR 0006).
-- 자료 좌표(건물 축)를 Shared.Site로 세계 좌표에 바로 놓는다 — 이 Model은 건물 자리로 다시 돌리지 않는다.
-- 지형(Terrain)은 쓰지 않는다. 다듬기는 Studio에서. Part만 쓴다.
--   광장 바닥: 건물 축 Z 1 m 띠마다 기울인 판 (바닥 높이가 Z로만 변한다)
--   보도·도로: 연석선을 문루 중심에서 바깥으로 늘인 고리. 한 기울어진 면 위의 삼각형(WedgePart 2개)으로 채운다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Plaza = require(ReplicatedStorage.Shared.Plaza)
local site = require(ReplicatedStorage.Shared.Site)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local SLAB = 0.5 -- 보도·도로 판 두께 (연석 단차 0.15를 덮는다)
local FLOOR = 1 -- 광장 바닥 판 두께
local WALL = 0.4 -- 광장 가장자리 옹벽 두께

local model: Model

-- 건물 축 (x, z) m와 높이 h m → 세계 좌표(스터드)
local function world(x: number, h: number, z: number): Vector3
	return site:PointToWorldSpace(Vector3.new(x, h, z) * S)
end

-- 세계 좌표(스터드) 삼각형 a b c를 윗면으로 하는 두께 SLAB 판. WedgePart 2개로 직각삼각형 둘로 나눈다
local function triangle(name: string, a: Vector3, b: Vector3, c: Vector3)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-4 then
		return -- 넓이 없는 삼각형 (도로 폭 0인 남쪽 점)
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local down = (right.Y > 0 and -right or right) * SLAB * S / 2 -- 윗면이 삼각형에 오게 두께 절반만큼 내린다
	for i, piece in { { (a + b) / 2, right, back, math.abs(ab:Dot(back)) }, { (a + c) / 2, -right, -back, math.abs(ac:Dot(back)) } } do
		local p = Instance.new("WedgePart")
		p.Name = name
		setup(p, true)
		p.CastShadow = false
		p.Size = Vector3.new(SLAB * S, height, piece[4] :: number)
		p.CFrame = CFrame.fromMatrix((piece[1] :: Vector3) + down, piece[2] :: Vector3, up, piece[3] :: Vector3)
		p.Parent = model
	end
end

local radial, roadFar = Plaza.radial, Plaza.roadFar

-- 고리가 겹치지 않으려면 맞은편 연석 점들이 문루 중심을 한 바퀴 차례로 돌아야 한다
do
	local turn = 0
	for i = 1, #Plaza.curb do
		local x0, z0 = roadFar(i)
		local x1, z1 = roadFar(i + 1)
		local d = (math.atan2(z1, x1) - math.atan2(z0, x0) + math.pi) % (2 * math.pi) - math.pi
		assert(d >= 0, `맞은편 연석 점 {i}→{i + 1}이 거꾸로 돈다`)
		turn += d
	end
	assert(math.abs(turn - 2 * math.pi) < 1e-3, "맞은편 연석 점이 한 바퀴를 돌지 않는다")
end

-- 건물 축 네 점 (x, z) a→b→c→d(둘레 차례)를 한 면(높이 함수 h)으로 채운다
local function quad(name: string, h: (number) -> number, a: { number }, b: { number }, c: { number }, d: { number })
	local function pt(p: { number }): Vector3
		return world(p[1], h(p[2]), p[2])
	end
	triangle(name, pt(a), pt(b), pt(c))
	triangle(name, pt(a), pt(c), pt(d))
end

-- 두 고리 사이를 한 면(높이 함수 h)으로 채운다. inner·outer(i)는 꼭짓점 i의 (x, z). skip 번째 칸은 비운다
local function ring(name: string, inner: (number) -> (number, number), outer: (number) -> (number, number), h: (number) -> number, skip: number?)
	for i = 1, #Plaza.curb do
		if i ~= skip then
			quad(name, h, { inner(i) }, { outer(i) }, { outer(i + 1) }, { inner(i + 1) })
		end
	end
end

-- 연석선 다각형을 건물 축 z 직선으로 자른 x 범위 (광장은 z마다 한 구간)
local function xRange(z: number): (number, number)
	local lo, hi = math.huge, -math.huge
	local n = #Plaza.curb
	for i = 1, n do
		local p, q = Plaza.curb[i], Plaza.curb[i % n + 1]
		if (p[2] - z) * (q[2] - z) <= 0 and p[2] ~= q[2] then
			local x = p[1] + (q[1] - p[1]) * (z - p[2]) / (q[2] - p[2])
			lo, hi = math.min(lo, x), math.max(hi, x)
		end
	end
	return lo, hi
end

local function zoneAt(z: number)
	for _, zone in Plaza.zones do
		if z >= zone.z0 and z < zone.z1 then
			return zone
		end
	end
	return nil
end

-- 광장 바닥 판 하나: 건물 축 x0..x1, z0..z1, 윗면이 floor(z0)→floor(z1)로 기운다
local function floorStrip(name: string, x0: number, x1: number, z0: number, z1: number)
	if x1 - x0 < 0.05 then
		return
	end
	local h0, h1 = Plaza.floor(z0), Plaza.floor(z1)
	local len = math.sqrt((z1 - z0) ^ 2 + (h1 - h0) ^ 2) + 0.02 -- 이웃 띠와 2 cm 겹쳐 이음매 틈을 막는다
	local p = Instance.new("Part")
	p.Name = name
	setup(p, true)
	p.CastShadow = false
	p.Size = Vector3.new(x1 - x0, FLOOR, len) * S
	p.CFrame = site
		* CFrame.new(Vector3.new((x0 + x1) / 2, (h0 + h1) / 2, (z0 + z1) / 2) * S)
		* CFrame.Angles(-math.atan2(h1 - h0, z1 - z0), 0, 0)
		* CFrame.new(0, -FLOOR * S / 2, 0)
	p.Parent = model
end

-- 세계 좌표(스터드) 두 윗점 사이 옹벽. inward = 광장 쪽 수평 방향
local function retainingWall(topA: Vector3, topB: Vector3, bottom: number, inward: Vector3)
	local along = topB - topA
	local hgt = math.max(topA.Y, topB.Y) - bottom
	local p = Instance.new("Part")
	p.Name = "Ongbyeok"
	setup(p, true)
	p.Size = Vector3.new(WALL * S, hgt, along.Magnitude + WALL * S)
	local mid = (topA + topB) / 2 + inward * WALL * S / 2
	p.CFrame = CFrame.lookAt(mid, mid + along) * CFrame.new(0, -hgt / 2, 0)
	p.Parent = model
end

return function()
	if workspace:FindFirstChild("Gwangjang") then
		return
	end
	model = Instance.new("Model")
	model.Name = "Gwangjang"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 땅 끝(400 m)까지의 바닥이 실루엣 밑에서 스트리밍으로 빠지지 않게
	local band, n = Plaza.bandWidth, #Plaza.curb

	-- 보도 띠(연석 안쪽), 도로, 도로 맞은편 보도·블록 바닥
	ring("Bodo", function(i)
		return radial(i, -band)
	end, function(i)
		return radial(i, 0)
	end, Plaza.sidewalk)
	ring("Asphalt", function(i)
		return radial(i, 0)
	end, roadFar, Plaza.road)
	-- 맞은편 보도·블록 바닥은 땅 끝(farRadius)까지. 남쪽 끝 점(n)과 W1(1) 칸은 세종대로 남쪽 연장이 대신 채운다
	ring("Bodo", roadFar, function(i)
		local k = (i - 1) % n + 1
		local x, z = roadFar(k)
		if k == 1 or k == n then
			return Plaza.toEdge(x, z) -- 연장 도로·보도 가장자리와 맞춘다
		end
		local len = math.sqrt(x * x + z * z)
		return x * Plaza.farRadius / len, z * Plaza.farRadius / len
	end, Plaza.sidewalk, n)

	-- 세종대로 남쪽 연장: 광장 남서 끝(Z≈100)에서 끊기지 않고 땅 끝까지 간다. 동쪽 보도는 남쪽 끝 점~W1 사이 폭
	local w1, w1far, south = { Plaza.curb[1][1], Plaza.curb[1][2] }, { roadFar(1) }, { roadFar(n) }
	quad("Asphalt", Plaza.road, w1, w1far, { Plaza.toEdge(w1far[1], w1far[2]) }, { Plaza.toEdge(w1[1], w1[2]) })
	quad("Bodo", Plaza.sidewalk, south, w1, { Plaza.toEdge(w1[1], w1[2]) }, { Plaza.toEdge(south[1], south[2]) })

	-- 보행 경계: 맞은편 보도 바깥선을 따라 보이지 않는 벽. 그 밖(도로 연장·실루엣)으로는 못 간다
	for i = 1, n do
		local x0, z0 = Plaza.boundary(i)
		local x1, z1 = Plaza.boundary(i + 1)
		local a, b = world(x0, 0, z0), world(x1, 0, z1)
		local g0, g1 = Plaza.sidewalk(z0), Plaza.sidewalk(z1)
		local bottom, top = math.min(g0, g1) - 1, math.max(g0, g1) + Plaza.walkHeight
		local along = b - a
		local p = Instance.new("Part")
		p.Name = "Gyeonggye"
		setup(p, true)
		p.Transparency = 1
		p.CastShadow = false
		p.Size = Vector3.new(0.3 * S, (top - bottom) * S, along.Magnitude + 0.3 * S)
		local mid = (a + b) / 2
		p.CFrame = CFrame.lookAt(mid, mid + along) + Vector3.new(0, (bottom + top) / 2 * S, 0)
		p.Parent = model
	end

	-- 광장 가장자리 옹벽: 보도 띠 안쪽 선을 따라 광장 바닥에서 보도 높이까지
	for i = 1, n do
		local x0, z0 = radial(i, -band)
		local x1, z1 = radial(i + 1, -band)
		local a, b = world(x0, Plaza.sidewalk(z0), z0), world(x1, Plaza.sidewalk(z1), z1)
		local inward = site:VectorToWorldSpace(Vector3.new(-(x0 + x1), 0, -(z0 + z1))).Unit
		retainingWall(a, b, math.min(Plaza.floor(z0), Plaza.floor(z1)) * S - 0.3 * S, inward)
	end

	-- 광장 바닥: 1 m 띠. 띠 양 끝 x는 두 변 가운데 좁은 쪽 (끝 들쭉날쭉은 보도 띠 밑에 숨는다)
	local zMin, zMax = math.huge, -math.huge
	for _, q in Plaza.curb do
		zMin, zMax = math.min(zMin, q[2]), math.max(zMax, q[2])
	end
	for z0 = math.ceil(zMin), math.floor(zMax) - 1 do
		local z1 = z0 + 1
		local a0, a1 = xRange(z0)
		local b0, b1 = xRange(z1)
		local x0, x1 = math.max(a0, b0), math.min(a1, b1)
		local zone = zoneAt(z0 + 0.5)
		if not zone then
			floorStrip("Jandi", x0, x1, z0, z1)
		elseif zone.x0 == nil then
			floorStrip(zone.kind, x0, x1, z0, z1)
		else
			local m0, m1 = math.clamp(zone.x0 :: number, x0, x1), math.clamp(zone.x1 :: number, x0, x1)
			floorStrip("Jandi", x0, m0, z0, z1)
			floorStrip(zone.kind, m0, m1, z0, z1)
			floorStrip("Jandi", m1, x1, z0, z1)
		end
	end

	-- 횡단보도: 걷는 방향으로 0.5 m 줄무늬를 1 m 간격으로. 도로 면 기울기에 맞춰 눕힌다
	local k = (Plaza.road(1) - Plaza.road(0)) -- 도로 면의 건물 축 Z 기울기
	for _, c in Plaza.crosswalks do
		local dx, dz = c[3] - c[1], c[4] - c[2]
		local len = math.sqrt(dx * dx + dz * dz)
		for d = 0.5, len - 0.5, 1 do
			local x, z = c[1] + dx * d / len, c[2] + dz * d / len
			local p = Instance.new("Part")
			p.Name = "Hoengdan"
			setup(p)
			p.CastShadow = false
			p.Size = Vector3.new(0.5, 0.04, Plaza.crosswalkWidth) * S
			p.CFrame = site
				* CFrame.new(Vector3.new(x, Plaza.road(z) + 0.01, z) * S)
				* CFrame.Angles(-math.atan(k), 0, 0)
				* CFrame.Angles(0, math.atan2(-dz, dx), 0)
			p.Parent = model
		end
	end

	model.Parent = workspace
end
