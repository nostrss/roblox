--!strict
-- 문루 마감(데이터 Shared.Munru): 하층·상층 장마루와 귀틀·장선·동바리, 문루 계단과 난간, 상층 벽.
-- 건물 축(정면 +Z, 동 +X)으로 짓고 init.server가 건물 자리로 돌린다(ADR 0004). Part만 쓴다.
-- 부딪힘: 걷는 면(마루널)·난간·벽만 켜고 받침 부재는 끈다. 계단은 보이지 않는 경사판 하나로 오른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local K = require(ReplicatedStorage.Shared.Chukbu)
local M = require(ReplicatedStorage.Shared.Munru)
local setup = require(script.Parent.Member)
local RoofSplit = require(ReplicatedStorage.Core.RoofSplit)
local Split = require(ReplicatedStorage.Shared.RoofSplit)

local S = Units.studs(1)
local L = D.level
local F, U = L.pavilionFloor, L.upperFloor -- 하층·상층 마루 윗면
local B = M.board

local model: Model
local rng = Random.new(2)

local function y(level: number): number
	return level - L.ground
end

local function positions(bays: { number }): { number }
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

-- cf·size는 m (cf의 Y는 지면 위 높이)
local function part(name: string, cf: CFrame, size: Vector3, collide: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	setup(p, collide)
	p.Size = size * S
	p.CFrame = CFrame.new(cf.Position * S) * cf.Rotation
	p.Parent = model
	return p
end

-- 두 꼭짓점 상자. 높이는 level
local function block(name: string, x0: number, l0: number, z0: number, x1: number, l1: number, z1: number, collide: boolean?): BasePart?
	if x1 - x0 < 1e-3 or l1 - l0 < 1e-3 or z1 - z0 < 1e-3 then
		return nil
	end
	return part(name, CFrame.new((x0 + x1) / 2, (y(l0) + y(l1)) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, l1 - l0, z1 - z0), collide)
end

-- 평면 사각형 r에서 구멍 h를 뺀 나머지 (최대 4개)
type Rect = { x0: number, x1: number, z0: number, z1: number }
local function minus(r: Rect, h: Rect?): { Rect }
	if not h or h.x0 >= r.x1 or h.x1 <= r.x0 or h.z0 >= r.z1 or h.z1 <= r.z0 then
		return { r }
	end
	local out = {}
	local ax0, ax1 = math.max(r.x0, h.x0), math.min(r.x1, h.x1)
	if r.x0 < h.x0 then
		table.insert(out, { x0 = r.x0, x1 = h.x0, z0 = r.z0, z1 = r.z1 })
	end
	if h.x1 < r.x1 then
		table.insert(out, { x0 = h.x1, x1 = r.x1, z0 = r.z0, z1 = r.z1 })
	end
	if r.z0 < h.z0 then
		table.insert(out, { x0 = ax0, x1 = ax1, z0 = r.z0, z1 = h.z0 })
	end
	if h.z1 < r.z1 then
		table.insert(out, { x0 = ax0, x1 = ax1, z0 = h.z1, z1 = r.z1 })
	end
	return out
end

-- 마루널: 동서로 긴 널을 남북으로 줄지어 깐다. 마루 가운데(x 0)에서 잇는다 (S7 p.262). 줄 사이 3 mm 틈으로 널 줄이 보이게
local function boards(r: Rect, top: number, hole: Rect?)
	local n = math.max(1, math.round((r.z1 - r.z0) / B.width))
	local w = (r.z1 - r.z0) / n
	for i = 0, n - 1 do
		for _, half in { { r.x0, 0 }, { 0, r.x1 } } do
			local row = { x0 = half[1], x1 = half[2], z0 = r.z0 + i * w + 0.0015, z1 = r.z0 + (i + 1) * w - 0.0015 }
			for _, q in minus(row, hole) do
				local p = block("Maruneol", q.x0, top - B.thickness, q.z0, q.x1, top, q.z1, true)
				if p then
					p.Color = p.Color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12)) -- 널마다 명도를 조금 흔든다
				end
			end
		end
	end
end

-- 칸마다 같은 간격으로 나눈 부재 x 좌표
local function spaced(cols: { number }, spacing: number): { number }
	local out = {}
	for i = 1, #cols - 1 do
		local bay = cols[i + 1] - cols[i]
		local n = math.max(1, math.round(bay / spacing))
		for k = 1, n do
			table.insert(out, cols[i] + (k - 0.5) * bay / n)
		end
	end
	return out
end

-- 상층 마루 계단 구멍 (계단 옆판 바깥 + 난간지방 폭)
local St = M.stair
local holeHalf = St.tread.length / 2 + St.stringer.thickness + M.railing.base.width
local hole: Rect = { x0 = St.top, x1 = St.opening, z0 = St.z - holeHalf, z1 = St.z + holeHalf }

local xs, zs = positions(D.lowerBays), positions(D.lowerSideBays)
local ux, uz = positions(D.upperBays), positions(D.upperSideBays)
local lx, lz, px, pz = xs[#xs], zs[#zs], ux[#ux], uz[#uz]

-- 17. 하층 장마루: 앞뒤 기둥열 장귀틀 → 장선(남북) → 마루널. 장선 가운데는 동바리가 받친다
local function lowerFloor()
	local G, J, Db = M.lower.jangGwiteul, M.lower.jangseon, M.lower.dongbari
	local jTop = F - B.thickness -- 장선 윗면
	local gTop = jTop - J.height -- 장귀틀 윗면
	for _, z in { -lz, lz } do
		for i = 1, #xs - 1 do
			local r = K.column.lowerDia / 2
			block("JangGwiteul", xs[i] + r, gTop - G.height, z - G.width / 2, xs[i + 1] - r, gTop, z + G.width / 2)
		end
	end
	for _, x in spaced(xs, J.spacing) do
		block("Jangseon", x - J.width / 2, gTop, -J.length / 2, x + J.width / 2, jTop, J.length / 2)
		block("Dongbari", x - Db.width / 2, 0, -Db.width / 2, x + Db.width / 2, gTop, Db.width / 2)
	end
	boards({ x0 = -lx, x1 = lx, z0 = -lz, z1 = lz }, F)
end

-- 17. 상층 장마루: 고주열 장귀틀(동서) → 동귀틀(남북, 장귀틀 ~ 하인방) → 마루널. 계단 구멍은 비운다
local function upperFloor()
	local G, Dg = M.upper.jangGwiteul, M.upper.dongGwiteul
	local top = U - B.thickness
	for i = 1, #ux - 1 do
		block("JangGwiteul", ux[i], top - G.height, -G.width / 2, ux[i + 1], top, G.width / 2)
	end
	local edge = pz - 0.054 -- 하인방 안쪽 면 (하인방 폭 108의 절반)
	for _, x in spaced(ux, Dg.spacing) do
		for _, sz in { -1, 1 } do
			local za, zb = sz * G.width / 2, sz * edge
			local r = { x0 = x - Dg.width / 2, x1 = x + Dg.width / 2, z0 = math.min(za, zb), z1 = math.max(za, zb) }
			for _, q in minus(r, hole) do
				block("DongGwiteul", q.x0, top - Dg.height, q.z0, q.x1, top, q.z1)
			end
		end
	end
	boards({ x0 = -px, x1 = px, z0 = -pz, z1 = pz }, U, hole)
end

-- 기울거나 누운 부재: a→b 를 따라 길이, 단면 w(옆)×h(위 = up 쪽)
local function along(name: string, a: Vector3, b: Vector3, w: number, h: number, up: Vector3, collide: boolean?): BasePart
	local mid = (a + b) / 2
	return part(name, CFrame.lookAt(mid, b, up), Vector3.new(w, h, (b - a).Magnitude), collide)
end

-- 세운 부재: 바닥 중심 p, 높이 h, 단면 w(가로) × depth(d 방향, 없으면 w)
local function post(name: string, p: Vector3, d: Vector3, w: number, h: number, depth: number?): BasePart
	local f = Vector3.new(d.X, 0, d.Z).Unit
	local c = p + Vector3.yAxis * h / 2
	return part(name, CFrame.lookAt(c, c + f), Vector3.new(w, h, depth or w), true)
end

-- 18. 난간: a→b 아랫선(m, Y는 지면 위)을 따라 (지방) 궁판·띠장·동자·하엽·돌란대. 엄지기둥은 부르는 쪽이 세운다
type Railing = typeof(M.stairRailing)
local function railing(R: Railing, a: Vector3, b: Vector3, base: { width: number, height: number }?)
	local d = b - a
	local flat = Vector3.new(d.X, 0, d.Z).Unit
	local up = flat:Cross(Vector3.yAxis):Cross(d.Unit) -- d에 수직이고 위를 보는 방향
	if up.Y < 0 then
		up = -up
	end
	local V = Vector3.yAxis
	local h = 0
	local function band(name: string, w: number, hh: number)
		along(name, a + V * (h + hh / 2), b + V * (h + hh / 2), w, hh, up, true)
		h += hh
	end
	if base then
		band("NanganJibang", base.width, base.height)
	end
	local P = R.panel
	local n = math.max(1, math.round(Vector3.new(d.X, 0, d.Z).Magnitude / P.length))
	local h0 = h
	for i = 1, n do
		local p0, p1 = a + d * (i - 1) / n, a + d * i / n
		along("Gungpan", p0 + V * (h0 + P.height / 2), p1 + V * (h0 + P.height / 2), P.thickness, P.height, up, true)
	end
	h += P.height
	band("NanganDdijang", R.rail.width, R.rail.height)
	for i = 1, n - 1 do
		local p = a + d * i / n + V * h
		post("NanganDongja", p, d, R.dongja.size, R.dongja.height)
		post("Hayeop", p + V * R.dongja.height, d, R.hayeop.across, R.hayeop.height, R.hayeop.along)
	end
	h += R.dongja.height + R.hayeop.height
	local rod = along("Dollandae", a + V * (h + R.handrail / 2), b + V * (h + R.handrail / 2), R.handrail, R.handrail, up, true)
	rod.Shape = Enum.PartType.Cylinder
	rod.Size = Vector3.new(rod.Size.Z, rod.Size.X, rod.Size.Y)
	rod.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
end

-- 18. 문루 계단: 동쪽 아래(하층 마루)에서 서쪽 위(상층 마루)로. 디딤 코 선 = foot→top
local function stair()
	local n = St.risers
	local r, g = (U - F) / n, St.going
	local xb = St.top + (n - 1) * g -- 첫 챌판 x
	local zc, half = St.z, St.tread.length / 2
	local A = Vector3.new(xb + g, y(F), zc) -- 디딤 코 선 아래 끝 (하층 마루)
	local Bt = Vector3.new(St.top, y(U), zc) -- 위 끝 (상층 마루 가장자리)
	local dir = (Bt - A).Unit
	local up = Vector3.new(-dir.Y, dir.X, 0) -- 디딤 코 선에 수직, 위쪽 (dir.X < 0)
	if up.Y < 0 then
		up = -up
	end
	for i = 1, n do
		local x = xb - (i - 1) * g
		local l0 = F + (i - 1) * r
		block("Chaepan", x - St.riser.thickness, l0, zc - half, x, F + i * r - St.tread.thickness, zc + half)
		if i < n then
			block("Didimpan", x - g, F + i * r - St.tread.thickness, zc - half, x + 0.02, F + i * r, zc + half)
		end
	end
	-- 옆판: 윗면이 디딤 코 선보다 above만큼 위
	local So = St.stringer
	local off = up * (So.above - So.depth / 2)
	for _, sz in { -1, 1 } do
		local z = Vector3.zAxis * sz * (half + So.thickness / 2)
		along("Yeoppan", A + off + z, Bt + off + z, So.thickness, So.depth, up)
	end
	-- 뒷널: 옆판 밑면 사이
	local Bo = St.soffit
	local so = up * (So.above - So.depth + Bo.thickness / 2)
	along("Dwitneol", A + so, Bt + so, Bo.width, Bo.thickness, up)
	-- 걷는 면: 디딤 코 선에서 반 단 내린 보이지 않는 경사판 (발이 디딤판 앞뒤 사이에 오게)
	local ramp = along("GyedanRamp", A - Vector3.yAxis * r / 2 - up * 0.1, Bt - Vector3.yAxis * r / 2 - up * 0.1, half * 2, 0.2, up, true)
	ramp.Transparency = 1

	-- 계단 난간: 옆판 윗면을 따라, 양 끝 엄지기둥은 아래·위 마루에 선다
	local SR = M.stairRailing
	for _, sz in { -1, 1 } do
		local z = Vector3.zAxis * sz * (half + So.thickness / 2)
		local a, b = A + up * So.above + z, Bt + up * So.above + z
		railing(SR, a, b)
		post("Eomjigidung", Vector3.new(A.X + SR.post.size / 2, y(F), A.Z) + z, dir, SR.post.size, SR.post.height)
		post("Eomjigidung", Vector3.new(Bt.X - SR.post.size / 2, y(U), Bt.Z) + z, dir, SR.post.size, SR.post.height)
	end

	-- 마루 난간: 상층 계단 구멍의 남·북 두 변(동쪽 끝에서 지방 길이만큼)과 동쪽 끝
	local R = M.railing
	local e = R.base.width / 2
	local x1, x0 = hole.x1 - e, hole.x1 - R.length
	local zs0, zs1 = hole.z0 + e, hole.z1 - e
	local Y = y(U)
	railing(R, Vector3.new(x0, Y, zs0), Vector3.new(x1, Y, zs0), R.base)
	railing(R, Vector3.new(x0, Y, zs1), Vector3.new(x1, Y, zs1), R.base)
	railing(R, Vector3.new(x1, Y, zs0), Vector3.new(x1, Y, zs1), R.base)
	for _, c in { Vector3.new(x0, Y, zs0), Vector3.new(x0, Y, zs1), Vector3.new(x1, Y, zs0), Vector3.new(x1, Y, zs1) } do
		post("Eomjigidung", c, Vector3.xAxis, R.post.size, R.post.height)
	end
end

-- 둘레(사각형) 기둥 사이 한 칸씩: a→b(기둥 중심), 안쪽 방향, 칸 번호
local function ring(cols: { number }, rows: { number }, fn: (Vector2, Vector2, Vector2, number) -> ())
	local x0, x1, z0, z1 = cols[1], cols[#cols], rows[1], rows[#rows]
	for i = 1, #cols - 1 do
		fn(Vector2.new(cols[i], z0), Vector2.new(cols[i + 1], z0), Vector2.new(0, 1), i)
		fn(Vector2.new(cols[i], z1), Vector2.new(cols[i + 1], z1), Vector2.new(0, -1), i)
	end
	for j = 1, #rows - 1 do
		fn(Vector2.new(x0, rows[j]), Vector2.new(x0, rows[j + 1]), Vector2.new(1, 0), 0)
		fn(Vector2.new(x1, rows[j]), Vector2.new(x1, rows[j + 1]), Vector2.new(-1, 0), 0)
	end
end

-- 수평 부재 a→b (평면 m), 높이 l0~l1 (level), 단면 폭 w
local function flat(name: string, a: Vector2, b: Vector2, l0: number, l1: number, w: number): BasePart
	local h = (y(l0) + y(l1)) / 2
	return along(name, Vector3.new(a.X, h, a.Y), Vector3.new(b.X, h, b.Y), w, l1 - l0, Vector3.yAxis, true)
end

-- 19. 상층 벽과 하층 하인방
local function walls()
	local W = M.wall
	local hi, mi, ms, ch = W.haInbang, W.munInbang, W.munseon, W.chang
	local bandTop, bandBottom = mi.bottom, hi.bottom + hi.height -- 판창 자리 (두 인방 사이)
	-- 상층 벽은 지붕 분해 때 상층 기둥과 같이 떠오른다 (상층 기둥 겹). 하층 하인방은 그대로
	local function up(p: BasePart): BasePart
		RoofSplit.mark(p, "upper", Split, "gidung")
		return p
	end
	ring(ux, uz, function(a, b, inward)
		local d = (b - a).Unit
		local r = K.column.upperDia / 2
		local a1, b1 = a + d * r, b - d * r -- 기둥 면 사이
		up(flat("GwiteulInbang", a1, b1, hi.bottom - W.gwiteulInbang.height, hi.bottom, W.gwiteulInbang.width))
		up(flat("HaInbang", a1, b1, hi.bottom, bandBottom, hi.width))
		up(flat("MunInbang", a1, b1, mi.bottom, mi.bottom + mi.height, mi.width))
		up(flat("Munseon", a1, a1 + d * ms.width, bandBottom, bandTop, ms.depth))
		up(flat("Munseon", b1 - d * ms.width, b1, bandBottom, bandTop, ms.depth))
		-- 판창: 문선 사이를 같은 폭으로 나눈 닫힌 널창, 인방 안쪽 면에 붙인다
		local a2, b2 = a1 + d * ms.width, b1 - d * ms.width
		local len = (b2 - a2).Magnitude
		local n = math.max(1, math.round(len / ch.width))
		local off = inward * (hi.width + ch.thickness) / 2
		local mid = (bandTop + bandBottom) / 2
		for k = 1, n do
			local p0, p1 = a2 + d * ((k - 1) * len / n + 0.003), a2 + d * (k * len / n - 0.003)
			up(flat("Panchang", p0 + off, p1 + off, mid - ch.height / 2, mid + ch.height / 2, ch.thickness))
		end
		-- 안쪽 면을 평평하게 막는 보이지 않는 벽. 인방·판창 턱을 사다리로 알고 기어올라 넘어가지 않게 (공포 위까지)
		local g = inward * (hi.width / 2 + ch.thickness + 0.03)
		up(flat("WallGuard", a1 + g, b1 + g, U, L.upperColumnTop + 1.5, 0.06)).Transparency = 1
	end)
	local lh = W.lowerHaInbang
	ring(xs, zs, function(a, b, _, i)
		if i == 3 then
			return -- 어칸 앞뒤는 드나드는 자리라 비운다 (S4 008)
		end
		local d = (b - a).Unit
		local r = K.column.lowerDia / 2
		flat("HaInbang", a + d * r, b - d * r, F - lh.below, F - lh.below + lh.height, lh.width)
	end)
end

return function()
	if workspace:FindFirstChild("Munru") then
		return
	end
	model = Instance.new("Model")
	model.Name = "Munru"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 지붕 분해가 클라이언트에서 부재 전체를 옮기므로 스트리밍으로 빠지지 않게
	lowerFloor()
	upperFloor()
	stair()
	walls()
	model.Parent = workspace
end
