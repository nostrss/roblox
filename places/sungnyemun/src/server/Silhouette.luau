--!strict
-- 주변 건물 실루엣 (데이터 Shared.Silhouette). 창·간판 없는 상자 하나씩, 세계 좌표에 바로 놓는다 — 건물 자리로 돌리지 않는다.
-- 걸어 갈 수 없는 배경이라 부딪힘·조회·그림자를 모두 끈다(모바일 부담). 바닥은 둘레 보도 면(Plaza.sidewalk)에 1 m 묻는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Plaza = require(ReplicatedStorage.Shared.Plaza)
local boxes = require(ReplicatedStorage.Shared.Silhouette)
local site = require(ReplicatedStorage.Shared.Site)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local SINK = 1 -- 상자 바닥을 보도 면 아래로 묻는 깊이 (기운 면에서 뜨지 않게)
local TONES = { "SilhouetteA", "SilhouetteB", "SilhouetteC" }

-- 건물 축 (x, z) 점이 다각형 안인가
local function inside(x: number, z: number, poly: { { number } }): boolean
	local c = false
	for i, p in poly do
		local q = poly[i % #poly + 1]
		if (p[2] > z) ~= (q[2] > z) and x < p[1] + (q[1] - p[1]) * (z - p[2]) / (q[2] - p[2]) then
			c = not c
		end
	end
	return c
end

-- 보행 경계 안(광장·도로·맞은편 보도)과 세종대로 남쪽 연장 — 상자가 들어가면 안 되는 곳 (건물 축)
local keepOut: { { { number } } } = { {} }
for i = 1, #Plaza.curb do
	table.insert(keepOut[1], { Plaza.boundary(i) })
end
do
	local w1, w1far = { Plaza.curb[1][1], Plaza.curb[1][2] }, { Plaza.roadFar(1) }
	table.insert(keepOut, { w1, w1far, { Plaza.toEdge(w1far[1], w1far[2]) }, { Plaza.toEdge(w1[1], w1[2]) } })
end

return function()
	if workspace:FindFirstChild("Silhouette") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Silhouette"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 스트리밍 반경(모바일은 더 좁다) 밖 먼 상자도 늘 보이게. 상자 수가 적어 부담 없음
	for i, b in boxes do
		local x, z, u, v, deg, h = b[1], b[2], b[3], b[4], b[5], b[6]
		local rot = CFrame.Angles(0, -math.rad(deg), 0) -- 상자 +X(u축)를 세계 (cos, 0, sin)으로
		local frame = CFrame.new(site.Position + Vector3.new(x, 0, z) * S) * rot
		-- 네 귀와 변 위 2 m 간격 점이 도로·광장에 들어가지 않는지, 그 점들의 보도 높이 범위
		local lo, hi = math.huge, -math.huge
		for _, e in { { 1, 1, -1, 1 }, { -1, 1, -1, -1 }, { -1, -1, 1, -1 }, { 1, -1, 1, 1 } } do
			local steps = math.ceil(math.max(u, v) / 2)
			for k = 0, steps do
				local t = k / steps
				local du, dv = (e[1] + (e[3] - e[1]) * t) * u / 2, (e[2] + (e[4] - e[2]) * t) * v / 2
				local p = site:PointToObjectSpace(frame:PointToWorldSpace(Vector3.new(du, 0, dv) * S)) / S
				for _, poly in keepOut do
					assert(not inside(p.X, p.Z, poly), `실루엣 상자 {i}이 보행 경계 안이나 도로에 걸린다 ({x}, {z})`)
				end
				local g = Plaza.sidewalk(p.Z)
				lo, hi = math.min(lo, g), math.max(hi, g)
			end
		end
		local bottom, top = lo - SINK, (lo + hi) / 2 + h
		local p = Instance.new("Part")
		p.Name = TONES[i % #TONES + 1]
		setup(p)
		p.CastShadow = false
		p.Size = Vector3.new(u, top - bottom, v) * S
		p.CFrame = frame * CFrame.new(0, (bottom + top) / 2 * S, 0)
		p.Parent = model
	end
	model.Parent = workspace
end
