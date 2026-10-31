--!strict
-- 공포 부재 데이터(Gongpo.luau)를 부재 종류마다 OBJ 메시로 굽는다. 단위 스터드, 메시 중심 = 경계 상자 중심.
-- usage (저장소 루트에서):
--   luau tools/gongpo_obj.luau | awk '/^#FILE /{f=d"/"$2".obj"; next} {print > f}' d=places/sungnyemun/meshes
-- 결과 .obj를 Studio 3D Importer로 올리고, MeshPart들을 MemberMeshes 태그를 단 Folder 하나에 넣는다.
-- 배치 코드(src/server/Gongpo.luau)는 MeshPart 크기·위치를 데이터에서 다시 정하므로 임포트 단위 설정은 상관없다.
local G = require("../places/sungnyemun/src/shared/Gongpo")

local STUD = 0.34 -- core/Units.luau METERS_PER_STUD 와 같아야 한다

type V = { number } -- { x, y, z } m

-- 단순 다각형(반시계) 귀 자르기 삼각분할
local function triangulate(pts: { { number } }): { { number } }
	local idx = {}
	for i in pts do
		idx[i] = i
	end
	local function cross(o: { number }, a: { number }, b: { number }): number
		return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
	end
	local tris = {}
	while #idx > 3 do
		local n, clipped = #idx, false
		for i = 1, n do
			local i0, i1, i2 = idx[(i - 2) % n + 1], idx[i], idx[i % n + 1]
			local a, b, c = pts[i0], pts[i1], pts[i2]
			if cross(a, b, c) > 1e-9 then
				local ear = true
				for _, j in idx do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = pts[j]
						if cross(a, b, p) >= 0 and cross(b, c, p) >= 0 and cross(c, a, p) >= 0 then
							ear = false
							break
						end
					end
				end
				if ear then
					table.insert(tris, { i0, i1, i2 })
					table.remove(idx, i)
					clipped = true
					break
				end
			end
		end
		assert(clipped, "삼각분할 실패: 자기 교차하는 프로파일")
	end
	table.insert(tris, { idx[1], idx[2], idx[3] })
	return tris
end

-- 면 단위로 정점을 따로 둬서(공유하지 않아) 임포터가 모서리를 각지게 둔다
type Mesh = { verts: { V }, faces: { { number } } }

local function face(m: Mesh, ps: { V }, tris: { { number } }) -- 바깥에서 볼 때 반시계
	local base = #m.verts
	for _, p in ps do
		table.insert(m.verts, p)
	end
	for _, t in tris do
		table.insert(m.faces, { base + t[1], base + t[2], base + t[3] })
	end
end

local QUAD = { { 1, 2, 3 }, { 1, 3, 4 } }

-- XY 평면 프로파일을 Z 방향 두께 t로 돌출
local function extrude(m: Mesh, profile: { { number } }, t: number)
	local pts, area = {}, 0
	for i, p in profile do
		local q = profile[i % #profile + 1]
		area += p[1] * q[2] - q[1] * p[2]
		pts[i] = p
	end
	if area < 0 then
		local r = {}
		for i = #pts, 1, -1 do
			table.insert(r, pts[i])
		end
		pts = r
	end
	local tris = triangulate(pts)
	local front, back, backTris = {}, {}, {}
	for i, p in pts do
		front[i] = { p[1], p[2], t / 2 }
		back[i] = { p[1], p[2], -t / 2 }
	end
	for i, tri in tris do
		backTris[i] = { tri[1], tri[3], tri[2] }
	end
	face(m, front, tris)
	face(m, back, backTris)
	for i, a in pts do
		local b = pts[i % #pts + 1]
		face(m, { { a[1], a[2], -t / 2 }, { b[1], b[2], -t / 2 }, { b[1], b[2], t / 2 }, { a[1], a[2], t / 2 } }, QUAD)
	end
end

-- 밑면 bottom, 윗면 top 정사각형인 각뿔대. y0부터 높이 h
local function frustum(m: Mesh, bottom: number, top: number, y0: number, h: number)
	local function ring(w: number, y: number): { V }
		local r = w / 2
		return { { -r, y, r }, { r, y, r }, { r, y, -r }, { -r, y, -r } }
	end
	local lo, hi = ring(bottom, y0), ring(top, y0 + h)
	face(m, { hi[1], hi[2], hi[3], hi[4] }, QUAD)
	face(m, { lo[4], lo[3], lo[2], lo[1] }, QUAD)
	for i = 1, 4 do
		local j = i % 4 + 1
		face(m, { lo[i], lo[j], hi[j], hi[i] }, QUAD)
	end
end

local meshes: { { name: string, mesh: Mesh } } = {}
local function add(name: string): Mesh
	local m = { verts = {}, faces = {} }
	table.insert(meshes, { name = name, mesh = m })
	return m
end

local judu = add("Judu")
frustum(judu, G.lower.judu.bottom, G.lower.judu.top, 0, G.lower.judu.foot)
frustum(judu, G.lower.judu.top, G.lower.judu.top, G.lower.judu.foot, G.lower.judu.height - G.lower.judu.foot)

local soro = add("Soro")
frustum(soro, G.soro.bottom, G.soro.top, 0, G.soro.foot)
frustum(soro, G.soro.top, G.soro.top, G.soro.foot, G.soro.height - G.soro.foot)

local c = G.cheomcha
for _, kind in { "small", "large" } do
	local L = (c.length :: any)[kind] :: number
	local rx, ry = c.endRadius[1], c.endRadius[2]
	local profile = { { L / 2, c.height }, { -L / 2, c.height } }
	for side = -1, 1, 2 do -- 왼쪽 끝 아래 → 오른쪽 끝 아래, 모서리를 타원 1/4로
		for k = 0, 6 do
			local a = math.rad(90 * k / 6)
			local x = side * (L / 2 - rx + rx * (side < 0 and math.cos(a) or math.sin(a)))
			local y = ry - ry * (side < 0 and math.sin(a) or math.cos(a))
			table.insert(profile, { x, y })
		end
	end
	extrude(add(kind == "small" and "SoCheomcha" or "DaeCheomcha"), profile, G.thickness)
end

local names = {}
for name in G.jegong do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	extrude(add(name), G.jegong[name], G.thickness)
end

extrude(add("Unggong"), G.unggong, G.thickness)

for _, e in meshes do
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, v in e.mesh.verts do
		for k = 1, 3 do
			lo[k], hi[k] = math.min(lo[k], v[k]), math.max(hi[k], v[k])
		end
	end
	print("#FILE " .. e.name)
	print("# " .. e.name .. " — tools/gongpo_obj.luau 로 생성. 손으로 고치지 말 것")
	for _, v in e.mesh.verts do
		-- Studio 3D Importer가 OBJ의 X(와 Z)를 뒤집어 들이므로 Y축 180° 돌려 써서 상쇄한다 (2026-10 확인: 제공 쇠서가 안쪽으로 감)
		print(string.format("v %.4f %.4f %.4f", -(v[1] - (lo[1] + hi[1]) / 2) / STUD, (v[2] - (lo[2] + hi[2]) / 2) / STUD, -(v[3] - (lo[3] + hi[3]) / 2) / STUD))
	end
	for _, f in e.mesh.faces do
		print(string.format("f %d %d %d", f[1], f[2], f[3]))
	end
end
