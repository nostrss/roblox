--!strict
-- 좌우 복원 성곽: 육축 앞면 양 끝에서 八자로 뻗는 체성·여장·단부 (데이터 Shared.Seonggwak).
-- 건물 축으로 짓고 init.server가 건물 자리로 함께 돌린다(ADR 0004). Part만 쓴다. 곡선(동측 처음 8 m의 완만한 휨)은 직선으로 줄였다.
-- 팔 좌표: u = 성벽 길이 방향(육축 모서리 0), c = 바깥면에서 광장 쪽(+)으로 잰 거리, y = 지면(Y 0) 위 높이.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local G = require(ReplicatedStorage.Shared.Seonggwak)
local Plaza = require(ReplicatedStorage.Shared.Plaza)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local H = -D.level.ground -- 미석 상단 = 육축 상부면(level 0)의 지면 위 높이 (S7 p.521)
local BURY = 0.5 -- 체성 밑을 지면 아래로 묻는 깊이 (광장 바닥이 기울어도 틈이 안 생기게)
local UP = Vector3.yAxis

return function()
	if workspace:FindFirstChild("Seonggwak") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Seonggwak"
	local P = G.parapet

	local function arm(sx: number, A: typeof(G.east))
		local back = G.batter + G.topWidth -- 바깥 경사 + 윗면 = 체성 몸 뒤끝 (c = −back)

		-- 한 팔 구간(origin에서 dir 방향)을 짓는 도구
		local function frame(origin: Vector3, deg: number)
			local u = Vector3.new(sx * math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
			local n = u:Cross(UP)
			if n.Z < 0 then
				n = -n -- 바깥면 법선: 광장(+Z) 쪽
			end
			local function at(uu: number, y: number, c: number): Vector3
				return origin + u * uu + UP * y + n * c
			end
			local function box(name: string, u0: number, u1: number, c0: number, c1: number, y0: number, y1: number)
				local p = Instance.new("Part")
				p.Name = name
				setup(p, true)
				p.Size = Vector3.new(u1 - u0, y1 - y0, c1 - c0) * S
				p.CFrame = CFrame.fromMatrix(at((u0 + u1) / 2, (y0 + y1) / 2, (c0 + c1) / 2) * S, u, UP, u:Cross(UP))
				p.Parent = model
			end
			-- 쐐기: c0 쪽이 높고(y1) c1 쪽이 지면(y0)으로 내려가는 비탈
			local function slope(name: string, u0: number, u1: number, cHigh: number, cLow: number, y0: number, y1: number)
				local p = Instance.new("WedgePart")
				p.Name = name
				setup(p, true)
				local z = n * (cHigh > cLow and 1 or -1) -- WedgePart는 +Z 쪽이 높다
				p.Size = Vector3.new(u1 - u0, y1 - y0, math.abs(cHigh - cLow)) * S
				p.CFrame = CFrame.fromMatrix(at((u0 + u1) / 2, (y0 + y1) / 2, (cHigh + cLow) / 2) * S, UP:Cross(z), UP, z)
				p.Parent = model
			end
			return at, box, slope
		end

		local corner = Vector3.new(sx * D.wall.width / 2, 0, D.wall.south)
		local at, box, slope = frame(corner, G.angle)
		local ta = A.pitch - P.gap
		local t = P.thickness
		local lastDy = 0

		for i = 1, A.ta do
			local dy = A.stepUp[i] or 0
			lastDy = dy
			local u0, u1 = (i - 1) * A.pitch, i * A.pitch
			local b0 = i == 1 and -6 or u0 -- 근사: 첫 구간 몸은 육축 속으로 6 m 묻어 모서리 틈을 막는다
			local top = H + dy
			-- 체성: 몸(회곽로 높이까지) + 바깥 경사 면석 + 뒤 비탈
			box("SeongBody", b0, u1, -back, -G.batter, -BURY, top - G.walkwayDrop)
			slope("SeongBody", b0, u1, -G.batter, 0, -BURY, top - P.miseokThickness)
			slope("SeongBack", b0, u1, -back, -back - A.backWidth, -BURY, top - G.walkwayDrop)
			box("Miseok", math.max(b0, P.start), u1, -G.batter - t - P.miseokIn, -G.batter + P.miseokOut, top - P.miseokThickness, top)

			-- 여장 1타: 총안 자리에서 아래·위로 나눈다
			local s0, s1 = i == 1 and P.start or u0, u0 + ta
			local c0, c1 = -G.batter - t, -G.batter
			local base, roof = top - G.walkwayDrop, top + P.height - P.roofThickness
			local cursor = s0
			for k, center in P.holeCenters do
				local hc = u0 + center * ta / 3.75
				local h0, h1 = hc - P.holeWidth / 2, hc + P.holeWidth / 2
				box("Yeojang", cursor, h0, c0, c1, base, roof)
				box("Yeojang", h0, h1, c0, c1, base, top + P.holes[k][1])
				box("Yeojang", h0, h1, c0, c1, top + P.holes[k][2], roof)
				cursor = h1
			end
			box("Yeojang", cursor, s1, c0, c1, base, roof)
			box("Okgae", s0, s1, c0 - P.roofOverhang, c1 + P.roofOverhang, roof, top + P.height)
		end

		-- 단부: 여장 끝에서 (서측은 북쪽으로 꺾어) 계단식으로 낮아진다
		local L = A.ta * A.pitch
		local endAt, endBox = frame(at(L, 0, 0), G.angle - A.bend)
		local u, prevTop = 0, H + lastDy - G.walkwayDrop
		for _, seg in A.ends do
			local p = endAt(u + seg.length, 0, 0)
			local target = Plaza.floor(p.Z) + seg.lowTop
			for k = 1, seg.steps do
				local u0 = u + (k - 1) * seg.length / seg.steps
				local y1 = prevTop + (target - prevTop) * k / seg.steps
				endBox("SeongBody", u0, u0 + seg.length / seg.steps, -back, 0, -BURY, y1)
			end
			u += seg.length
			prevTop = target
		end
	end

	arm(1, G.east)
	arm(-1, G.west)
	model.Parent = workspace
end
