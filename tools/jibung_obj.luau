--!strict
-- 지붕 곡면(기와골 포함)을 면마다 OBJ 메시로 굽고, 배치용 중심·크기를 JibungMeshes.luau 로 쓴다 (ADR 0002).
-- usage (저장소 루트에서):
--   luau tools/jibung_obj.luau | awk '/^#FILE /{f=$2; next} {print > f}'
-- 메시 4개(하층·상층 × 앞면·옆면). 뒷면·반대 옆면은 서버가 같은 메시를 180° 돌려 쓴다.
-- 좌표: 앞면 = 남(+Z) 면, 옆면 = 동(+X) 면. 단위 m로 만들고 OBJ는 스터드.
local J = require("../landmarks/sungnyemun/src/shared/Jibung")
local C = require("../landmarks/sungnyemun/src/shared/Cheoma")
local D = require("../landmarks/sungnyemun/src/shared/Dimensions")

local STUD = 0.34 -- core/Units.luau METERS_PER_STUD 와 같아야 한다

local function half(bays: { number }): number
	local t = 0
	for _, b in bays do
		t += b
	end
	return t / 2
end

-- 표 { x, y } 직선 보간. 범위 밖은 끝 기울기로 늘린다 (server/Cheoma.luau riseAt 과 같은 규칙)
local function interp(t: { { number } }, x: number): number
	if x <= t[1][1] then
		return t[1][2]
	end
	for i = 2, #t do
		local p, q = t[i - 1], t[i]
		if x <= q[1] then
			return p[2] + (q[2] - p[2]) * (x - p[1]) / (q[1] - p[1])
		end
	end
	local p, q = t[#t - 1], t[#t]
	return q[2] + (q[2] - p[2]) * (x - q[1]) / (q[1] - p[1])
end

-- 면 하나: h = 바깥 방향 기둥열 반폭, hLat = 면 방향 반폭, lastA = 마지막 평연(안허리 시작), rise = 앙곡 표
type Face = { h: number, hLat: number, lastA: number, rise: { { number } } }

-- 처마 끝에서 a 자리의 안허리(바깥으로 더 나옴)·앙곡(오름)
local function outAt(E: any, f: Face, a: number): number
	local x = math.abs(a) - f.lastA
	return if x > 0 then interp(E.fan.anheori, x) else 0
end
local function riseAt(f: Face, a: number): number
	return interp(f.rise, math.abs(a))
end

-- 기와골 단면 깊이 (수키와 중심 0, 간격 sp마다 반복). 맨 아래 깊이 = 1
local G = J.groove
local DEPTH = G.profile[#G.profile][2]
local function grooveAt(a: number, sp: number): number
	local u = math.abs(a - math.round(a / sp) * sp)
	return -interp(G.profile, u) / DEPTH
end

-- 가로 자리: 기와골 단면 점을 간격마다 늘어놓음
local function columns(limit: number, sp: number): { number }
	local us = {}
	for i = #G.profile, 2, -1 do
		table.insert(us, -G.profile[i][1])
	end
	for i = 1, #G.profile - 1 do
		table.insert(us, G.profile[i][1])
	end
	local out = {}
	local n = math.ceil(limit / sp) + 1
	for k = -n, n do
		for _, u in us do
			local a = k * sp + u
			if math.abs(a) < limit then
				table.insert(out, a)
			end
		end
	end
	return out
end

-- eave = 처마 끝 막새 자리 { a, e, 높이, 0 수막새 | 1 암막새 }, hip = +a 쪽 추녀마루 선 { a, e, 높이 } (위 끝 → 처마 끝)
type Mesh = { verts: { { number } }, faces: { { number } }, gol: number, eave: { { number } }, hip: { { number } } }

local function build(E: any, L: any, f: Face, other: Face): Mesh
	local m: Mesh = { verts = {}, faces = {}, gol = 0, eave = {}, hip = {} }
	local prof, rows, sp = L.profile, L.rows, L.spacing
	local function depth(e: number): number -- 기와골 깊이 (처마 쪽에서 얕아짐)
		return if L.depth then interp(L.depth, e) else DEPTH
	end
	local top, edge = prof[1][1], prof[#prof][1]
	-- 앙곡·안허리 비율: 위 끝 0 → 처마 꺾임점(단면 끝에서 두 번째 점, 이매기 바로 안쪽) 1. 꺾임점 바깥은 서까래 끝과 같이 다 받는다
	-- (처마 끝에서 1로 두면 이매기 자리에서 약 0.88만 받아 귀 쪽 지붕이 이매기·사래보다 낮아졌다)
	local kink = prof[#prof - 1][1]
	local function w(e: number): number
		return math.min(1, (e - top) / (kink - top))
	end
	local function vert(a: number, e: number, y: number): number -- a = 면 방향, e = 바깥(기둥열 기준)
		table.insert(m.verts, { a, y, f.h + e })
		return #m.verts
	end
	-- 추녀마루(대각선) 위 점: 두 면이 같은 값을 쓰도록 안허리·앙곡을 두 면 평균으로
	local function hip(e0: number): (number, number, number) -- a, e, 높이
		local e = e0
		for _ = 1, 4 do
			local o = (outAt(E, f, f.hLat + e) + outAt(E, other, other.hLat + e)) / 2
			e = e0 + o * w(e0)
		end
		local r = (riseAt(f, f.hLat + e) + riseAt(other, other.hLat + e)) / 2
		return f.hLat + e, e, interp(prof, e0) + r * w(e0) - depth(e0) / 2
	end
	-- 세로줄(기와골 단면 점)마다 처마 끝에서 위로 { e, 꼭짓점 }. 위 끝은 용마루 줄(rows[1]) 또는 추녀마루(대각선) 위 점.
	-- 세로줄끼리 잇기 때문에 추녀마루 쪽에서도 기와골이 대각선까지 그대로 간다
	local function hipAt(a: number): number -- |a| 자리의 추녀마루가 지나는 e0 (이분법)
		local lo, hi = top, edge
		for _ = 1, 40 do
			local mid = (lo + hi) / 2
			if (hip(mid)) < math.abs(a) then
				lo = mid
			else
				hi = mid
			end
		end
		return (lo + hi) / 2
	end
	local laTop, laEdge = hip(top), hip(edge)
	local cols = {}
	local function column(a: number, onHip: boolean)
		local col = {}
		local e1 = if onHip then hipAt(a) else top
		for k = #rows, 1, -1 do
			local e0 = rows[k]
			if e0 > e1 + 0.05 or (not onHip and e0 == top) then
				local ww = w(e0)
				table.insert(col, { -e0, vert(a, e0 + outAt(E, f, a) * ww, interp(prof, e0) + riseAt(f, a) * ww + grooveAt(a, sp) * depth(e0)) })
			end
		end
		if onHip then
			local la, le, ly = hip(e1)
			table.insert(col, { -e1, vert(if a < 0 then -la else la, le, ly) })
		end
		table.insert(cols, col)
	end
	column(-laEdge, true)
	local list = columns(laEdge - 0.02, sp)
	for _, a in list do
		column(a, math.abs(a) > laTop)
	end
	column(laEdge, true)
	-- 처마 끝 줄 (띠용): 세로줄 첫 점
	local edgeLine = {}
	for _, col in cols do
		if col[1][1] == -edge then
			table.insert(edgeLine, { 0, col[1][2] })
		end
	end
	-- 처마 끝 양 귀: 추녀마루 끝 점도 띠에 넣는다
	local lines = { edgeLine }
	local function tri(i: number, j: number, k: number)
		local a, b, c = m.verts[i], m.verts[j], m.verts[k]
		local ux, uz = b[1] - a[1], b[3] - a[3]
		local vx, vz = c[1] - a[1], c[3] - a[3]
		if uz * vx - ux * vz > 0 then -- 위(+Y)에서 볼 때 앞면이 되게 (Roblox 반시계)
			table.insert(m.faces, { i, j, k })
		else
			table.insert(m.faces, { i, k, j })
		end
	end
	-- 이웃한 두 세로줄을 e 순으로 지퍼처럼 잇는다
	for r = 1, #cols - 1 do
		local A, B = cols[r], cols[r + 1]
		local i, j = 1, 1
		while i < #A or j < #B do
			if j == #B or (i < #A and A[i + 1][1] <= B[j + 1][1]) then
				tri(A[i][2], A[i + 1][2], B[j][2])
				i += 1
			else
				tri(A[i][2], B[j + 1][2], B[j][2])
				j += 1
			end
		end
	end
	-- 처마 끝 띠 (바깥을 보게)
	local last = lines[1]
	for k = 1, #last - 1 do
		local p, q = m.verts[last[k][2]], m.verts[last[k + 1][2]]
		local p2 = vert(p[1], p[3] - f.h, p[2] - J.edgeDrop)
		local q2 = vert(q[1], q[3] - f.h, q[2] - J.edgeDrop)
		-- 바깥(+Z)에서 볼 때 반시계: p → p2 → q2, p → q2 → q (a가 커지는 방향 = +X)
		table.insert(m.faces, { last[k][2], p2, q2 })
		table.insert(m.faces, { last[k][2], q2, last[k + 1][2] })
	end
	-- 기와골 수 = 처마 끝에서 수키와 중심 수
	local la = hip(edge)
	m.gol = 2 * math.floor(la / sp) + 1
	-- 막새 자리: 수막새 = 수키와 중심(k·sp), 암막새 = 골 가운데((k+½)·sp). 귀 쪽은 추녀마루에 닿기 전까지
	for k = -math.ceil(la / sp), math.ceil(la / sp) do
		for kind = 0, 1 do
			local a = (k + kind / 2) * sp
			if math.abs(a) <= la - 0.15 then
				local y = interp(prof, edge) + riseAt(f, a) - kind * depth(edge)
				table.insert(m.eave, { a, edge + outAt(E, f, a), y, kind })
			end
		end
	end
	for i = 0, 12 do
		local a, e, y = hip(top + (edge - top) * i / 12)
		table.insert(m.hip, { a, e, y })
	end
	return m
end

local out = {}
local meta = {}
for _, layer in { { "Lower", C.lower, J.lower, D.lowerBays, D.lowerSideBays }, { "Upper", C.upper, J.upper, D.upperBays, D.upperSideBays } } do
	local name, E, L = layer[1] :: string, layer[2] :: any, layer[3] :: any
	local hx, hz = half(layer[4] :: { number }), half(layer[5] :: { number })
	local front: Face = { h = hz, hLat = hx, lastA = (E.front.count - 1) / 2 * E.front.spacing, rise = E.rise.front }
	local side: Face = { h = hx, hLat = hz, lastA = (E.side.count - 1) / 2 * E.side.spacing, rise = E.rise.side }
	for _, fc in { { "Front", front, side }, { "Side", side, front } } do
		local m = build(E, L, fc[2] :: Face, fc[3] :: Face)
		local mname = name .. "Jibung" .. fc[1]
		local f = fc[2] :: Face
		-- 막새·추녀마루 점을 월드 사분면 좌표 { x, 높이, z }로 (앞면 a = x, 옆면 a = z)
		local function place(list: { { number } })
			for _, q in list do
				local a, out = q[1], f.h + q[2]
				q[1], q[2] = if fc[1] == "Front" then a else out, q[3]
				q[3] = if fc[1] == "Front" then out else a
			end
		end
		place(m.eave)
		place(m.hip)
		if fc[1] == "Side" then -- 옆면은 동(+X) 면으로: (a, y, x) → (x = 바깥, z = a)
			for _, v in m.verts do
				v[1], v[3] = v[3], v[1]
			end
			for _, t in m.faces do
				t[2], t[3] = t[3], t[2]
			end
		end
		table.insert(out, { name = mname, mesh = m })
	end
end

for _, e in out do
	local m = e.mesh
	-- 넓이 0 삼각형(귀 끝·겹친 세로줄)은 버린다. 임포터도 버리므로, 남은 삼각형 꼭짓점으로 경계 상자를 잡아야 Studio 크기·중심과 맞는다
	local faces = {}
	for _, t in m.faces do
		local a, b, c = m.verts[t[1]], m.verts[t[2]], m.verts[t[3]]
		local u = vector.create(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local v = vector.create(c[1] - a[1], c[2] - a[2], c[3] - a[3])
		if vector.magnitude(vector.cross(u, v)) > 1e-8 then
			table.insert(faces, t)
		end
	end
	m.faces = faces
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, t in faces do
		for _, i in t do
			local v = m.verts[i]
			for k = 1, 3 do
				lo[k], hi[k] = math.min(lo[k], v[k]), math.max(hi[k], v[k])
			end
		end
	end
	local c = { (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2 }
	assert(#m.faces < 10000, `{e.name}: 삼각형 {#m.faces} (Studio 임포트 한도 안쪽으로)`)
	table.insert(meta, string.format("\t%s = { center = { %.4f, %.4f, %.4f }, size = { %.4f, %.4f, %.4f }, tris = %d, gol = %d,",
		e.name, c[1], c[2], c[3], hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3], #m.faces, m.gol))
	for _, key in { "eave", "hip" } do
		local pts = {}
		for _, q in (m :: any)[key] do
			table.insert(pts, if #q == 4 then string.format("{ %.3f, %.3f, %.3f, %d }", q[1], q[2], q[3], q[4]) else string.format("{ %.3f, %.3f, %.3f }", q[1], q[2], q[3]))
		end
		table.insert(meta, `\t\t{key} = \{ {table.concat(pts, ", ")} \},`)
	end
	table.insert(meta, "\t},")
	print("#FILE landmarks/sungnyemun/meshes/" .. e.name .. ".obj")
	print("# " .. e.name .. " — tools/jibung_obj.luau 로 생성. 손으로 고치지 말 것")
	for _, v in m.verts do
		-- Studio 3D Importer의 Y축 180° 뒤집힘 상쇄 (gongpo_obj.luau 와 같음)
		print(string.format("v %.4f %.4f %.4f", -(v[1] - c[1]) / STUD, (v[2] - c[2]) / STUD, -(v[3] - c[3]) / STUD))
	end
	for _, t in m.faces do
		print(string.format("f %d %d %d", t[1], t[2], t[3]))
	end
end

print("#FILE landmarks/sungnyemun/src/shared/JibungMeshes.luau")
print("--!strict")
print("-- tools/jibung_obj.luau 로 생성. 손으로 고치지 말 것")
print("-- 지붕 메시 경계 상자 (m, 레벨 기준). 앞면 = 남, 옆면 = 동. tris = 삼각형 수, gol = 처마 끝 기와골(수키와) 수")
print("-- eave = 막새 자리 { x, 높이, z, 0 수막새 | 1 암막새 } (처마 끝 수키와 등·골 바닥), hip = 동남 추녀마루 선 { x, 높이, z } (위 → 처마)")
print("return {")
for _, line in meta do
	print(line)
end
print("}")
