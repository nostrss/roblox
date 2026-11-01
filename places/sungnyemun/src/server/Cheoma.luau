--!strict
-- 처마의 평연(나란한 서까래)과 부연을 짓는다. 서까래는 단면이 둥근 Part, 부연은 MemberMeshes의 Buyeon 메시.
-- 서까래 밑면은 안쪽 받침 도리와 외목도리 윗면에 닿고(Chukbu에서 짓는 값), 앙곡만큼 외목도리 닿는 점을 축으로 끝을 들어 올린다.
-- 모서리: 추녀(밑면을 도리 대각선 교차점에 얹음)·사래(추녀 윗면 휜 구간에 얹음)·갈모산방, 선자연은 부채 중심(안쪽 받침 도리 모서리)에서 처마선으로.
-- 마감: 서까래·부연 윗면에 개판, 끝에 초매기·이매기(처마선을 따라 토막으로), 공포 출목 장여 사이에 순각판.
-- 원점 = 문루 중심 지면, 건물 축(정면 = +Z, 정면 기준 동쪽 = +X).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local K = require(ReplicatedStorage.Shared.Chukbu)
local C = require(ReplicatedStorage.Shared.Cheoma)
local G = require(ReplicatedStorage.Shared.Gongpo)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local WOOD = Color3.fromRGB(120, 60, 45) -- 석간주 근사 (단청은 F 단계)

local function half(bays: { number }): number
	local t = 0
	for _, b in bays do
		t += b
	end
	return t / 2
end

-- 앙곡 표 { 거리, 오름 } 직선 보간
local function riseAt(t: { { number } }, a: number): number
	a = math.abs(a)
	if a <= t[1][1] then
		return t[1][2]
	end
	for i = 2, #t do
		local p, q = t[i - 1], t[i]
		if a <= q[1] then
			return p[2] + (q[2] - p[2]) * (a - p[1]) / (q[1] - p[1])
		end
	end
	local p, q = t[#t - 1], t[#t] -- 범위 밖은 마지막 기울기로 늘린다 (모서리 쪽 선자연 끝)
	return q[2] + (q[2] - p[2]) * (a - q[1]) / (q[1] - p[1])
end

-- 한 면: lat = 면을 따라가는 축, out = 바깥 수평. 면 위 점은 (a = lat 좌표, Vector2(d = out 거리, h = 레벨))
type Face = { lat: Vector3, out: Vector3 }

local function at(f: Face, a: number, p: Vector2): Vector3
	return (f.lat * a + f.out * p.X + Vector3.yAxis * (p.Y - D.level.ground)) * S
end

local function dir(f: Face, v: Vector2): Vector3
	return f.out * v.X + Vector3.yAxis * v.Y
end

local function laterals(count: number, spacing: number): { number }
	local out = {}
	for i = 1, count do
		table.insert(out, (i - (count + 1) / 2) * spacing)
	end
	return out
end

local function rotate(p: Vector2, pivot: Vector2, angle: number): Vector2
	local v, c, sn = p - pivot, math.cos(angle), math.sin(angle)
	return pivot + Vector2.new(v.X * c - v.Y * sn, v.X * sn + v.Y * c)
end

-- 처마선 위 점: 초매기·이매기 단면 밑면 가운데(스터드)와 받침 부재 윗면 법선
type Pt = { p: Vector3, n: Vector3 }

-- 서까래·부연 윗면 선(tailTop → tipTop, 스터드)에 개판을 덮고, maegi가 있으면 끝에서 물린 자리를 처마선 점으로 모은다
local function cover(model: Model, boardName: string, tailTop: Vector3, tipTop: Vector3, up: Vector3, width: number, maegi: any?, pts: { Pt }?)
	local w = (tipTop - tailTop).Unit
	local stop = tipTop
	if maegi then
		stop -= w * (maegi.setback + maegi.width) * S
		table.insert(pts :: { Pt }, { p = tipTop - w * (maegi.setback + maegi.width / 2) * S, n = up })
	end
	local p = Instance.new("Part")
	p.Name = boardName
	setup(p, WOOD)
	p.Size = Vector3.new((stop - tailTop).Magnitude, C.gaepan * S, width * S)
	p.CFrame = CFrame.fromMatrix((tailTop + stop) / 2 + up * (C.gaepan / 2 * S), w, up)
	p.Parent = model
end

-- 서까래 하나. 밑면 선이 sIn·sOut(도리 윗면)을 지나고 sOut 밖 overhang 수평거리에서 끝난다. 끝을 rise만큼 들도록 sOut 축으로 돌린 각을 돌려준다.
-- 윗면에 개판(너비 width)을 덮고, pts가 있으면 초매기 자리를 모은다
local function rafter(model: Model, name: string, f: Face, a: number, sIn: Vector2, sOut: Vector2, overhang: number, spec: any, rise: number, width: number, pts: { Pt }?): number
	local u = (sOut - sIn).Unit
	local tip = sOut + u * (overhang / u.X) + Vector2.new(0, rise)
	local u2 = (tip - sOut).Unit
	local n = Vector2.new(-u2.Y, u2.X) -- 위쪽 법선
	local c = sOut + u2 * ((tip - sOut).Magnitude - spec.length / 2) + n * (spec.dia / 2)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	setup(p, WOOD)
	p.Size = Vector3.new(spec.length, spec.dia, spec.dia) * S
	local pos = at(f, a, c)
	p.CFrame = CFrame.lookAt(pos, pos + dir(f, u2)) * CFrame.Angles(0, math.pi / 2, 0)
	p.Parent = model
	local tipTop = tip + n * spec.dia
	cover(model, "Gaepan", at(f, a, tipTop - u2 * spec.length), at(f, a, tipTop), dir(f, n), width, pts and C.chomaegi, pts)
	return math.atan2(u2.Y, u2.X) - math.atan2(u.Y, u.X)
end

-- 부연 메시 하나를 윗면 꼬리·끝 점(스터드 좌표)에 맞춰 놓고, 윗면에 부연개판을 덮고 이매기 자리를 모은다
local function buyeonAt(model: Model, src: MeshPart, name: string, tail: Vector3, tip: Vector3, length: number, width: number, pts: { Pt })
	local B = C.buyeon
	local w = (tip - tail).Unit
	local m = (Vector3.yAxis - w * w.Y).Unit
	local height = B.profile[2][2] -- 윗면 v
	local k = length / B.profile[3][1] -- 메시(하층 길이)를 이 길이로 늘림
	local p = src:Clone()
	p.Name = name
	setup(p, WOOD)
	p.Size = Vector3.new(length, height, B.width) * S
	p.CFrame = CFrame.fromMatrix(tail + (w * (length / 2 - B.topFrom * k) - m * (height / 2)) * S, w, m)
	p.Parent = model
	cover(model, "BuyeonGaepan", tail, tip, m, width, C.imaegi, pts)
end

-- 평연 부연: 윗면 꼬리·끝 점(외목도리 중심·윗면 기준)을 서까래와 같은 각만큼 sOut 축으로 돌려 놓는다
local function buyeon(model: Model, src: MeshPart, f: Face, a: number, sOut: Vector2, spec: any, angle: number, width: number, pts: { Pt })
	local tail = rotate(sOut + Vector2.new(spec.tail[1], spec.tail[2]), sOut, angle)
	local tip = rotate(sOut + Vector2.new(spec.tip[1], spec.tip[2]), sOut, angle)
	buyeonAt(model, src, "Buyeon", at(f, a, tail), at(f, a, tip), spec.length, width, pts)
end

-- 측면 외곽선 메시를 놓는다. origin = 외곽선 (0,0)의 자리(스터드), uAxis·vAxis = 외곽선 u·v 방향, scale = 외곽선 늘림
local function profileAt(model: Model, src: MeshPart, name: string, origin: Vector3, uAxis: Vector3, vAxis: Vector3, scale: Vector2, width: number)
	local u0, u1, v0, v1 = math.huge, -math.huge, math.huge, -math.huge
	for _, q in C.profiles[name] do
		u0, u1, v0, v1 = math.min(u0, q[1]), math.max(u1, q[1]), math.min(v0, q[2]), math.max(v1, q[2])
	end
	local p = src:Clone()
	p.Name = name
	setup(p, WOOD)
	p.Size = Vector3.new((u1 - u0) * scale.X, (v1 - v0) * scale.Y, width) * S
	p.CFrame = CFrame.fromMatrix(origin + (uAxis * (u0 + u1) / 2 * scale.X + vAxis * (v0 + v1) / 2 * scale.Y) * S, uAxis, vAxis)
	p.Parent = model
end

local function lerpTable(t: { { number } }, x: number): number
	for i = 2, #t do
		local p, q = t[i - 1], t[i]
		if x <= q[1] then
			return p[2] + (q[2] - p[2]) * math.max(x - p[1], 0) / (q[1] - p[1])
		end
	end
	return t[#t][2]
end

local function slopeDeg(sIn: Vector2, sOut: Vector2): number
	return math.deg(math.atan2(sIn.Y - sOut.Y, sOut.X - sIn.X))
end

-- 층 하나의 모서리 정보
type Layer = { E: any, hx: number, hz: number, inner: any, outset: number, outerTop: number }

-- 한 면의 처마선: out = 바깥, lat = 면을 따라 + 방향, h·hLat = 기둥열 반폭(out·lat 방향), cho·i = 초매기·이매기 점
type Eave = { out: Vector3, lat: Vector3, h: number, hLat: number, cho: { Pt }, i: { Pt } }

-- 처마선 점들을 lat 순으로 이어 초매기·이매기를 놓는다. 양 끝은 모서리 대각선 면(추녀·사래 위)까지 늘린다.
-- ponytail: 토막마다 곧은 Part라 꺾이는 바깥쪽에 아주 작은 틈이 생긴다(앙곡 구간에서 1cm 안팎)
local function maegi(model: Model, name: string, ev: Eave, pts: { Pt }, spec: any)
	table.sort(pts, function(a: Pt, b: Pt): boolean
		return a.p:Dot(ev.lat) < b.p:Dot(ev.lat)
	end)
	local function toDiagonal(p: Pt, q: Pt, sgn: number): Pt -- q → p 방향으로 대각선 면까지
		local corner = (ev.out * ev.h + ev.lat * sgn * ev.hLat) * S
		local nrm = ev.out - ev.lat * sgn
		local d = p.p - q.p
		return { p = p.p + d * ((corner - p.p):Dot(nrm) / d:Dot(nrm)), n = p.n }
	end
	local run = table.clone(pts)
	table.insert(run, 1, toDiagonal(pts[1], pts[2], -1))
	table.insert(run, toDiagonal(pts[#pts], pts[#pts - 1], 1))
	for i = 2, #run do
		local a, b = run[i - 1], run[i]
		local x = (b.p - a.p).Unit
		local up = a.n + b.n
		up = (up - x * up:Dot(x)).Unit
		local p = Instance.new("Part")
		p.Name = name
		setup(p, WOOD)
		p.Size = Vector3.new((b.p - a.p).Magnitude, spec.height * S, spec.width * S)
		p.CFrame = CFrame.fromMatrix((a.p + b.p) / 2 + up * (spec.height / 2 * S), x, up)
		p.Parent = model
	end
end

-- 한 면의 선자연·선자부연 (모서리 하나, 면 하나). aC·dC = 부채 중심, h = 그 면 기둥열 반폭, lastA = 마지막 평연, 돌려주는 값 = 선자연 수
local function fan(model: Model, src: MeshPart?, Y: Layer, f: Face, h: number, hLat: number, row: any, spacing: number, riseTable: any, ev: Eave): number
	local E, inner = Y.E, Y.inner
	local sIn, sOut = Vector2.new(h - inner.inset, inner.top), Vector2.new(h + Y.outset, Y.outerTop)
	local u = (sOut - sIn).Unit
	local endBottom = Y.outerTop + u.Y / u.X * E.overhang -- 평연 끝 밑면 (앙곡 전)
	local dEnd = h + Y.outset + E.overhang
	local aC, dC = hLat - inner.inset, h - inner.inset
	local lastA = (row.count - 1) / 2 * row.spacing
	local ch, dia = E.chunyeo, E.jangyeon.dia
	-- 끝 자리: 추녀와 겹치기 전까지
	local ends = {}
	local k = 1
	while true do
		local a = lastA + k * spacing
		local d = dEnd + lerpTable(E.fan.anheori, a - lastA)
		local v = Vector2.new(a - aC, d - dC)
		if math.deg(math.atan2(v.X, v.Y)) > 45 - math.deg(math.atan((ch.width + dia) / 2 / v.Magnitude)) then
			break
		end
		table.insert(ends, { a, d })
		k += 1
	end
	local pc = at(f, aC, Vector2.new(dC, inner.top))
	-- 평연 부연 꼬리·끝을 서까래 끝 밑면 기준으로 옮긴 값
	local B = E.buyeon
	local tailRel = Vector2.new(B.tail[1] - E.overhang, B.tail[2] - (endBottom - Y.outerTop))
	local tipRel = Vector2.new(B.tip[1] - E.overhang, B.tip[2] - (endBottom - Y.outerTop))
	for i, e in ends do
		local pe = at(f, e[1], Vector2.new(e[2], endBottom + riseAt(riseTable, e[1])))
		local w = pe - pc
		local wu = w.Unit
		local n = (Vector3.yAxis - wu * wu.Y).Unit
		local length = w.Magnitude / S + E.fan.tail
		local p = Instance.new("Part")
		p.Name = "Seonjayeon"
		p.Shape = Enum.PartType.Cylinder
		setup(p, WOOD)
		p.Size = Vector3.new(length, dia, dia) * S
		local c = (pc + pe) / 2 - wu * E.fan.tail / 2 * S + n * dia / 2 * S
		p.CFrame = CFrame.lookAt(c, c + wu) * CFrame.Angles(0, math.pi / 2, 0)
		p.Parent = model
		-- ponytail: 개판은 끝 간격 너비 그대로라 부채 중심 쪽에서 서로 겹친다(지붕 안쪽)
		local tipTop = pe + n * dia * S
		cover(model, "Gaepan", tipTop - wu * length * S, tipTop, n, spacing, C.chomaegi, ev.cho)
		if src then
			local hu = Vector3.new(w.X, 0, w.Z).Unit
			local tail = pe + (hu * tailRel.X + Vector3.yAxis * tailRel.Y) * S
			local tip = pe + (hu * tipRel.X + Vector3.yAxis * tipRel.Y) * S
			local len = B.length + (E.fan.buyeonLength - B.length) * (if #ends > 1 then (i - 1) / (#ends - 1) else 1)
			tip += (tip - tail).Unit * (len - B.length) * S
			buyeonAt(model, src :: MeshPart, "SeonjaBuyeon", tail, tip, len, spacing, ev.i)
		end
	end
	return #ends
end

-- 순각판: 출목 장여 사이마다 건물을 한 바퀴 두르는 판 (앞뒤 판이 모서리까지, 양옆 판은 그 사이).
-- ponytail: 판을 면마다 한 장으로 이어 공포 제공·대보가 판을 뚫고 지난다(실제는 판을 따내 끼움, 밑에서 보면 같다)
local function sungakpan(model: Model, hx: number, hz: number, outerTop: number, spec: any)
	local P = C.sungakpan
	local y = outerTop + spec.top - P.thickness / 2 - D.level.ground
	local function slab(pos: Vector3, size: Vector3)
		local p = Instance.new("Part")
		p.Name = "Sungakpan"
		setup(p, WOOD)
		p.Size = size * S
		p.CFrame = CFrame.new(pos * S)
		p.Parent = model
	end
	for k = spec.from, spec.to - 1 do
		local off = (k + 0.5) * G.outset
		local ax, az = hx + off, hz + off
		for _, sg in { -1, 1 } do
			slab(Vector3.new(0, y, sg * az), Vector3.new(2 * ax + P.width, P.thickness, P.width))
			slab(Vector3.new(sg * ax, y, 0), Vector3.new(P.width, P.thickness, 2 * az - P.width))
		end
	end
end

-- 모서리 하나 (sx, sz = 동서·남북 부호): 추녀·사래·갈모산방
local function corner(model: Model, meshes: Instance?, Y: Layer, sx: number, sz: number)
	local E, inner = Y.E, Y.inner
	local ch = E.chunyeo
	local function mesh(name: string): MeshPart?
		local m = meshes and meshes:FindFirstChild(name)
		return if m and m:IsA("MeshPart") then m else nil
	end
	local g = Vector3.new(sx, 0, sz).Unit
	local base = Vector3.new(sx * Y.hx, 0, sz * Y.hz)
	local function world(dd: number, H: number): Vector3 -- 모서리 기둥에서 대각선 거리 dd, 레벨 H
		return (base + g * dd + Vector3.yAxis * (H - D.level.ground)) * S
	end
	-- 추녀: 밑면 물매 = 외목도리·안쪽 받침 도리 대각선 교차점을 잇는 선
	local r2 = math.sqrt(2)
	local dOut, dIn = Y.outset * r2, -inner.inset * r2
	local th = math.atan2(Y.outerTop - inner.top, dOut - dIn)
	local c, s = math.cos(th), math.sin(th)
	local D0 = ch.scrollD - (ch.scroll[1] * c - ch.scroll[2] * s)
	local uSeat = (dOut - D0 + ch.seat * s) / c
	local H0 = Y.outerTop - (uSeat * s + ch.seat * c)
	local function pt(q: { number }): Vector2
		return Vector2.new(D0 + q[1] * c - q[2] * s, H0 + q[1] * s + q[2] * c)
	end
	local cm = mesh(ch.mesh)
	if cm then
		profileAt(model, cm, ch.mesh, world(D0, H0), g * c + Vector3.yAxis * s, -g * s + Vector3.yAxis * c, Vector2.one, ch.width)
	end
	-- 사래: 밑면 곧은 부분을 추녀 윗면 휜 구간(kink → tip)에 얹는다
	local sm, sr = mesh("Sarae"), E.sarae
	if sm then
		local K0, T0 = pt(ch.kink), pt(ch.tip)
		local dv = (T0 - K0).Unit
		local prof = C.profiles.Sarae
		local scale = Vector2.new(sr.length / 3.716, sr.height / 0.329) -- 메시 = S4 173 하층사래
		local o = K0 - dv * prof[2][1] * scale.X
		profileAt(model, sm, "Sarae", world(o.X, o.Y), g * dv.X + Vector3.yAxis * dv.Y, -g * dv.Y + Vector3.yAxis * dv.X, scale, sr.width)
	end
	-- 갈모산방: 외목도리 위, 두꺼운 쪽이 모서리 교차점. 면 둘. ponytail: 선자연 밑면과 5~10cm 겹친다(지붕 안이라 안 보임)
	local gm, gl = mesh("Galmo"), E.galmo
	if gm then
		local cx, cz = sx * (Y.hx + Y.outset), sz * (Y.hz + Y.outset)
		local o = Vector3.new(cx, Y.outerTop - D.level.ground, cz) * S
		local scale = Vector2.new(gl.length / 1.342, 1)
		profileAt(model, gm, "Galmo", o, Vector3.new(-sx, 0, 0), Vector3.yAxis, scale, gl.width)
		profileAt(model, gm, "Galmo", o, Vector3.new(0, 0, -sz), Vector3.yAxis, scale, gl.width)
	end
end

return function()
	if workspace:FindFirstChild("Cheoma") then
		return
	end
	local folder = CollectionService:GetTagged(Tags.MEMBER_MESHES)[1]
	local src = folder and folder:FindFirstChild("Buyeon")
	for _, name in { "Chunyeo", "UpperChunyeo", "Sarae", "Galmo" } do
		if not (folder and folder:FindFirstChild(name)) then
			warn(`처마: MemberMeshes에 {name}이 없어 건너뜀 (places/sungnyemun/meshes/{name}.obj 업로드 필요)`)
		end
	end
	if not (src and src:IsA("MeshPart")) then
		warn("처마: MemberMeshes에 Buyeon이 없어 부연은 건너뜀 (places/sungnyemun/meshes/Buyeon.obj 업로드 필요)")
		src = nil
	end
	local L = D.level
	local root = Instance.new("Model")
	root.Name = "Cheoma"
	local count = { jangyeon = 0, danyeon = 0, buyeon = 0, seonja = { Lower = 0, Upper = 0 } }

	-- 층마다 { 데이터, 앞뒤 기둥열 반폭, 양옆 기둥열 반폭, 안쪽 받침(inset, 윗면), 외목도리(outset, 윗면) }
	local layers = {
		{ "Lower", C.lower, half(D.lowerSideBays), half(D.lowerBays), K.lowerInnerDori, K.lowerOuterDori.outset, L.lowerEave + K.lowerOuterDori.dia },
		{ "Upper", C.upper, half(D.upperSideBays), half(D.upperBays), K.jungdori, K.upperOuterDori.outset, L.upperEave + K.upperOuterDori.dia },
	}
	for _, layer in layers do
		local name, E, hz, hx, inner, outset, outerTop = layer[1], layer[2] :: any, layer[3] :: number, layer[4] :: number, layer[5] :: any, layer[6] :: number, layer[7] :: number
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = root
		sungakpan(model, hx, hz, outerTop, if name == "Lower" then C.sungakpan.lower else C.sungakpan.upper)
		-- 면마다 처마선 (out 방향으로 찾는다)
		local eaves: { [string]: Eave } = {}
		local function eave(f: Face, h: number, hLat: number): Eave
			local key = `{math.round(f.out.X)},{math.round(f.out.Z)}`
			if not eaves[key] then
				eaves[key] = { out = f.out, lat = Vector3.new(math.abs(f.lat.X), 0, math.abs(f.lat.Z)), h = h, hLat = hLat, cho = {}, i = {} }
			end
			return eaves[key]
		end
		-- 면 4개: { 면, 기둥열 반폭(out 방향), 평연 }
		local faces = {
			{ { lat = Vector3.xAxis, out = Vector3.zAxis }, hz, E.front, E.rise.front }, -- 남
			{ { lat = Vector3.xAxis, out = -Vector3.zAxis }, hz, E.front, E.rise.front }, -- 북
			{ { lat = Vector3.zAxis, out = Vector3.xAxis }, hx, E.side, E.rise.side }, -- 동
			{ { lat = Vector3.zAxis, out = -Vector3.xAxis }, hx, E.side, E.rise.side }, -- 서
		}
		for _, fc in faces do
			local f, h, row, riseTable = fc[1] :: Face, fc[2] :: number, fc[3] :: any, fc[4] :: any
			local sIn, sOut = Vector2.new(h - inner.inset, inner.top), Vector2.new(h + outset, outerTop)
			assert(math.abs(slopeDeg(sIn, sOut) - E.slope) < 0.5, `{name} 장연 물매 {slopeDeg(sIn, sOut)}° (S4 017 {E.slope}°)`)
			local ev = eave(f, h, if f.lat == Vector3.xAxis then hx else hz)
			for _, a in laterals(row.count, row.spacing) do
				local angle = rafter(model, "Jangyeon", f, a, sIn, sOut, E.overhang, E.jangyeon, riseAt(riseTable, a), row.spacing, ev.cho)
				count.jangyeon += 1
				if src then
					buyeon(model, src :: MeshPart, f, a, sOut, E.buyeon, angle, row.spacing, ev.i)
					count.buyeon += 1
				end
			end
			-- 상층 단연: 앞뒤 면만, 종도리 → 중도리. 앙곡 없음
			if E.danyeon and f.lat == Vector3.xAxis then
				local dn, jd = E.danyeon, K.jongdori
				local dIn, dOut = Vector2.new(0, jd.top), sIn
				assert(math.abs(slopeDeg(dIn, dOut) - dn.slope) < 0.5, `단연 물매 {slopeDeg(dIn, dOut)}° (S4 017 {dn.slope}°)`)
				for _, a in laterals(E.danyeonCount, row.spacing) do
					rafter(model, "Danyeon", f, a, dIn, dOut, dn.overhang, dn, 0, row.spacing)
					count.danyeon += 1
				end
			end
		end
		-- 모서리 넷
		local Y: Layer = { E = E, hx = hx, hz = hz, inner = inner, outset = outset, outerTop = outerTop }
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				corner(model, folder, Y, sx, sz)
				local front: Face = { lat = Vector3.xAxis * sx, out = Vector3.zAxis * sz }
				local side: Face = { lat = Vector3.zAxis * sz, out = Vector3.xAxis * sx }
				count.seonja[name] += fan(model, src, Y, front, hz, hx, E.front, E.fan.front, E.rise.front, eave(front, hz, hx))
				count.seonja[name] += fan(model, src, Y, side, hx, hz, E.side, E.fan.side, E.rise.side, eave(side, hx, hz))
			end
		end
		for _, ev in eaves do
			maegi(model, "Chomaegi", ev, ev.cho, { width = C.chomaegi.width, height = E.chomaegiHeight })
			if src then
				maegi(model, "Imaegi", ev, ev.i, C.imaegi)
			end
		end
	end
	-- 선자연: 모서리마다 하층 7+7, 상층 12+11 (추녀와 겹치기 전까지 S4 011·012 간격으로 센 결과, 선자연_001 길이가 S4 177·178과 같음)
	assert(count.seonja.Lower == 56 and count.seonja.Upper == 92, `선자연 수 하층 {count.seonja.Lower}·상층 {count.seonja.Upper}`)
	-- S4 011·012: 장연 하층 (68+20)×2 + 상층 (59+10)×2 = 314, 단연 49×2, 부연은 장연마다 하나
	assert(count.jangyeon == 314 and count.danyeon == 98, `서까래 수 장연 {count.jangyeon}·단연 {count.danyeon}`)
	assert(not src or count.buyeon == 314, `부연 수 {count.buyeon}`)
	root.Parent = workspace
end
