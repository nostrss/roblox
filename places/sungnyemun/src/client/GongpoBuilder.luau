--!strict
-- Gongpo 데이터로 주간포 한 세트를 EditableMesh로 짓는다. 클라이언트 전용:
-- 서버에서 만든 EditableMesh는 아직 클라이언트로 복제되지 않는다(Content.fromObject 제약).
-- 같은 모양 부재(반복 부재)는 메시를 한 번만 만들고 MeshPart를 복제해 쓴다.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local G = require(ReplicatedStorage.Shared.Gongpo)

local s = Units.studs
local WOOD = Color3.fromRGB(150, 95, 60)

-- 단순 다각형(반시계) 귀 자르기 삼각분할. 반시계 삼각형의 정점 번호 목록을 돌려준다.
local function triangulate(pts: { Vector2 }): { { number } }
	local idx = {}
	for i in pts do
		idx[i] = i
	end
	local function cross(o: Vector2, a: Vector2, b: Vector2): number
		return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X)
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

-- 메시 하나에 여러 입체를 쌓는다. 면마다 법선을 따로 둬 모서리가 각지게 보인다.
type Mesh = { em: EditableMesh, min: Vector3, max: Vector3 }

local function newMesh(): Mesh
	return { em = AssetService:CreateEditableMesh(), min = Vector3.one * math.huge, max = -Vector3.one * math.huge }
end

local function face(m: Mesh, ps: { Vector3 }, tris: { { number } }) -- ps 좌표는 m, 바깥에서 볼 때 반시계
	local ids = {}
	for i, p in ps do
		local v = Vector3.new(s(p.X), s(p.Y), s(p.Z))
		ids[i] = m.em:AddVertex(v)
		m.min, m.max = m.min:Min(v), m.max:Max(v)
	end
	local nid = m.em:AddNormal()
	for _, t in tris do
		local fid = m.em:AddTriangle(ids[t[1]], ids[t[2]], ids[t[3]])
		m.em:SetFaceNormals(fid, { nid, nid, nid })
	end
end

local QUAD = { { 1, 2, 3 }, { 1, 3, 4 } }

-- XY 평면 프로파일을 Z 방향 두께 t로 돌출
local function extrude(m: Mesh, profile: G.Profile, t: number)
	local pts, area = {}, 0
	for i, p in profile do
		pts[i] = Vector2.new(p[1], p[2])
	end
	for i, a in pts do
		local b = pts[i % #pts + 1]
		area += a.X * b.Y - b.X * a.Y
	end
	if area < 0 then -- 시계 방향이면 반시계로 뒤집는다
		local r = {}
		for i = #pts, 1, -1 do
			table.insert(r, pts[i])
		end
		pts = r
	end
	local tris = triangulate(pts)
	local front, back, backTris = {}, {}, {}
	for i, p in pts do
		front[i] = Vector3.new(p.X, p.Y, t / 2)
		back[i] = Vector3.new(p.X, p.Y, -t / 2)
	end
	for i, tri in tris do
		backTris[i] = { tri[1], tri[3], tri[2] }
	end
	face(m, front, tris)
	face(m, back, backTris)
	for i, a in pts do
		local b = pts[i % #pts + 1]
		face(m, {
			Vector3.new(a.X, a.Y, -t / 2),
			Vector3.new(b.X, b.Y, -t / 2),
			Vector3.new(b.X, b.Y, t / 2),
			Vector3.new(a.X, a.Y, t / 2),
		}, QUAD)
	end
end

-- 밑면 bottom, 윗면 top 정사각형인 각뿔대. y0부터 높이 h
local function frustum(m: Mesh, bottom: number, top: number, y0: number, h: number)
	local function ring(w: number, y: number): { Vector3 }
		local r = w / 2
		return { Vector3.new(-r, y, r), Vector3.new(r, y, r), Vector3.new(r, y, -r), Vector3.new(-r, y, -r) }
	end
	local lo, hi = ring(bottom, y0), ring(top, y0 + h)
	face(m, { hi[1], hi[2], hi[3], hi[4] }, QUAD)
	face(m, { lo[4], lo[3], lo[2], lo[1] }, QUAD)
	for i = 1, 4 do
		local j = i % 4 + 1
		face(m, { lo[i], lo[j], hi[j], hi[i] }, QUAD)
	end
end

-- 메시를 MeshPart로. 정점이 메시 중심 기준이 되도록 옮겨 두고, 그 중심 위치를 함께 돌려준다.
local function toPart(m: Mesh, name: string): (MeshPart, Vector3)
	local center = (m.min + m.max) / 2
	for _, v in m.em:GetVertices() do
		m.em:SetPosition(v, m.em:GetPosition(v) - center)
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(m.em))
	part.Name = name
	part.Size = m.max - m.min
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Wood
	part.Color = WOOD
	return part, center
end

-- 부재 종류마다 MeshPart 원형 하나
local function templates(): { [string]: { part: MeshPart, center: Vector3 } }
	local out = {}
	local function add(name: string, m: Mesh)
		local part, center = toPart(m, name)
		out[name] = { part = part, center = center }
	end

	local judu = newMesh()
	frustum(judu, G.judu.bottom, G.judu.top, 0, G.judu.foot)
	frustum(judu, G.judu.top, G.judu.top, G.judu.foot, G.judu.height - G.judu.foot)
	add("Judu", judu)

	local soro = newMesh()
	frustum(soro, G.soro.bottom, G.soro.top, 0, G.soro.foot)
	frustum(soro, G.soro.top, G.soro.top, G.soro.foot, G.soro.height - G.soro.foot)
	add("Soro", soro)

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
		local m = newMesh()
		extrude(m, profile, G.thickness)
		add(kind == "small" and "SoCheomcha" or "DaeCheomcha", m)
	end

	for i, profile in G.jegong do
		local m = newMesh()
		extrude(m, profile, G.thickness)
		add("Jegong" .. i, m)
	end
	return out
end

-- origin: 주두 밑면 중심, LookVector = 바깥(쇠서 쪽). 첨차·소로 높이는 메시 안에 들어 있다.
local cache: { [string]: { part: MeshPart, center: Vector3 } }? = nil

return function(origin: CFrame, parent: Instance): Model
	if not cache then
		cache = templates()
	end
	local t = cache :: { [string]: { part: MeshPart, center: Vector3 } }
	local model = Instance.new("Model")
	model.Name = "Gongpo"

	local function place(name: string, cf: CFrame)
		local tpl = t[name]
		local p = tpl.part:Clone()
		p.CFrame = origin * cf * CFrame.new(tpl.center)
		p.Parent = model
	end

	-- 데이터는 +Z가 바깥, CFrame은 -Z(LookVector)가 앞이므로 Z를 뒤집는다
	local out = function(k: number): number
		return -k * G.outset
	end

	place("Judu", CFrame.identity)
	for _, row in G.cheomchas do
		local kind, k, y0 = row[1] :: string, row[2] :: number, row[3] :: number
		-- 높이는 메시 프로파일(0~height) 기준이라 밑면 높이만큼 올린다. L1 주심 소첨차는 높이 0.155라 위아래로 늘린다
		local name = kind == "small" and "SoCheomcha" or "DaeCheomcha"
		local scaleY = (row[4] :: number) / G.cheomcha.height
		local tpl = t[name]
		local p = tpl.part:Clone()
		p.Size = Vector3.new(p.Size.X, p.Size.Y * scaleY, p.Size.Z)
		p.CFrame = origin * CFrame.new(0, s(y0), s(out(k))) * CFrame.new(tpl.center.X, tpl.center.Y * scaleY, tpl.center.Z)
		p.Parent = model
	end
	for i = 1, #G.jegong do
		-- 프로파일 u(바깥 +)를 로컬 -Z로: Y축으로 +90° 돌리면 로컬 X가 -Z가 된다
		place("Jegong" .. i, CFrame.Angles(0, math.pi / 2, 0))
	end
	for _, row in G.soros do
		place("Soro", CFrame.new(s(row[1]), s(row[3]), s(out(row[2]))))
	end

	model.Parent = parent
	return model
end
