--!strict
-- 숭례문 둘레 도로(세종대로·소월로)의 차로 자리. 단위 m, 좌표는 건물 축 (x, 0, z), 출처 ID는 SOURCES.md.
-- 도로 하나 = 단면 줄. 단면 = { 안쪽 끝 a, 바깥쪽 끝 b } 두 점이고, 차로 안 자리는 a→b 비율 t(0~1)로 적는다.
-- 도로 차량(Shared.Streets)이 이 t로 달린다 — 차가 늘 같은 차로 위를 달린다.
-- a는 늘 광장 쪽 연석. 우측 통행이라 차로 t는 진행 방향 오른쪽 절반에서 고른다.
local Plaza = require(script.Parent.Plaza)

export type Road = {
	stations: { { Vector3 } }, -- { a, b }
	lanes: { [string]: { t: number, dir: number } }, -- 차가 달리는 차로 가운데. dir 1 = 단면 순서대로, −1 = 거꾸로
}

local Lanes = {}

local function curb(i: number): Vector3
	local q = Plaza.curb[i]
	return Vector3.new(q[1], 0, q[2])
end
local function far(i: number): Vector3
	local x, z = Plaza.roadFar(i)
	return Vector3.new(x, 0, z)
end
local function heading(deg: number): Vector3
	return Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
end
-- 횡단보도 i 양 끝 (Plaza.crosswalks 순서)
local function crossing(i: number): (Vector3, Vector3)
	local c = Plaza.crosswalks[i]
	return Vector3.new(c[1], 0, c[2]), Vector3.new(c[3], 0, c[4])
end

-- 보행 경계 밖 연장: 아스팔트는 보행 경계에서 끝나고(세종대로 남쪽만 땅 끝까지) 그 밖은 보도 면 위를 달린다.
-- 근사: 방향은 실제 도로 쪽으로, 주변 건물 실루엣 상자 사이 빈 곳을 지나게 골랐다(Play에서 상자와 겹침 검사, 건물 축 각도).
-- 세종대로 북쪽은 160 m에서 실루엣 상자(약 145 m)에 들어가 가려진 채 사라진다

-- 세종대로: 남쪽 연장 땅 끝 → 150 m → 광장 서쪽 W1–W12 → 교차로 북쪽 가지(횡단보도 C1) → 북쪽 연장. a = 광장 쪽 연석.
-- 단면(plaza-notes 2-1, S13 판독 Z 0–10, 연석–연석 약 32.5 m): 광장 쪽부터 북행 6차로 20.5 m · 중앙버스전용차로 북행·남행 3 m씩 · 남행 2차로 6 m
do
	local south = Plaza.sejongSouth
	local w1, f1 = curb(1), far(1)
	local ax, az = Plaza.toEdge(w1.X, w1.Z)
	local bx, bz = Plaza.toEdge(f1.X, f1.Z)
	local stations = { { Vector3.new(ax, 0, az), Vector3.new(bx, 0, bz) }, { w1 + south * 150, f1 + south * 150 } }
	for i = 1, 12 do
		table.insert(stations, { curb(i), far(i) })
	end
	local c1a, c1b = crossing(1) -- C1 (−40, −78) → (−8, −100): 광장 쪽(a)이 동쪽 끝
	table.insert(stations, { c1b, c1a })
	table.insert(stations, { c1b + heading(222) * 160, c1a + heading(222) * 160 })
	Lanes.sejong = {
		stations = stations,
		lanes = {
			north = { t = 20.5 / 32.5 * 2.5 / 6, dir = 1 }, -- 북행 3번째 차로
			south = { t = 28 / 32.5, dir = -1 }, -- 남행 안쪽 차로
			busNorth = { t = 22 / 32.5, dir = 1 },
			busSouth = { t = 25 / 32.5, dir = -1 },
		},
	} :: Road
end

-- 소월로: 남동쪽 연장 → 광장 동쪽 E6–E1 → N4 → 교차로 북동쪽 남대문로 가지(횡단보도 C2) → 북동쪽 연장. a = 광장 쪽 연석.
-- 단면(plaza-notes 사용자 결정, 임의값): 16.25 m = 5차로 × 3.25. 광장 쪽부터 나가는 2차로 · 들어오는 쪽 좌회전 1 · 들어오는 2차로
do
	local stations = { { curb(22) + heading(28) * 200, far(22) + heading(28) * 200 } }
	for i = 22, 16, -1 do
		table.insert(stations, { curb(i), far(i) })
	end
	local c2a, c2b = crossing(2) -- C2 (0, −97) → (20, −72): 광장 쪽(a)이 서쪽 끝
	table.insert(stations, { c2a, c2b })
	table.insert(stations, { c2a + heading(298) * 200, c2b + heading(298) * 200 })
	Lanes.sowol = {
		stations = stations,
		lanes = {
			inbound = { t = 0.7, dir = 1 }, -- 교차로로 들어오는 바깥쪽 첫 차로 (좌회전 차로 옆)
			outbound = { t = 0.3, dir = -1 },
		},
	} :: Road
end

-- 도로 road 위 비율 t 자리를 잇는 꺾은선 (단면 순서). dir −1이면 거꾸로
function Lanes.line(road: Road, t: number, dir: number?): { Vector3 }
	local out = {}
	for _, s in road.stations do
		table.insert(out, s[1]:Lerp(s[2], t))
	end
	if dir == -1 then
		local r = {}
		for i = #out, 1, -1 do
			table.insert(r, out[i])
		end
		return r
	end
	return out
end

-- 꺾은선 검사. 가운데와 양옆 side m 점을 step m마다 보고, 벗어난 점 수를 센다:
--   plaza = 연석 안(광장·안쪽 보도), strip = 보행 경계 안이지만 차도 밖(맞은편 보도), outside = 보행 경계 밖, total = 모든 점.
--   ends가 참이면 첫·마지막 변(보행 경계 밖 연장으로 나가는 변)의 strip은 세지 않는다 — 아스팔트가 맞은편 보도에서 끝나 그 띠를 건너야 한다
function Lanes.check(points: { Vector3 }, side: number, step: number, ends: boolean?): { [string]: number }
	local n = { plaza = 0, strip = 0, outside = 0, total = 0 }
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local v = b - a
		local len = v.Magnitude
		local r = Vector3.new(-v.Z, 0, v.X).Unit
		local edge = ends and (i == 2 or i == #points)
		for d = 0, len, step do
			local c = a + v * (d / len)
			for _, w in { -side, 0, side } do
				local p = c + r * w
				n.total += 1
				if Plaza.plazaSide(p.X, p.Z) then
					n.plaza += 1
				elseif not Plaza.walkable(p.X, p.Z) then
					n.outside += 1
				elseif not Plaza.onRoad(p.X, p.Z) and not edge then
					n.strip += 1
				end
			end
		end
	end
	return n
end

-- 시작 검사: 모든 차로 경로가 광장 쪽에 들어가지 않고, 보행 경계 안에서는 차도 위 (차 폭 절반 1.3 m 양옆까지)
for name, road in { sejong = Lanes.sejong, sowol = Lanes.sowol } do
	for lane, l in road.lanes do
		local n = Lanes.check(Lanes.line(road, l.t, l.dir), 1.3, 2, true)
		assert(n.plaza == 0 and n.strip == 0, `차로 경로 {name}.{lane}이 차도를 벗어난다: 광장 쪽 {n.plaza}, 맞은편 보도 {n.strip}`)
	end
end

return Lanes
