--!strict
-- 축부(기둥·창방·평방·대보·충량·외목도리)를 Part로 짓는다. 단면이 일정한 부재라 메시 없이 Part로 충분하다.
-- 원점 = 문루 중심 지면, 건물 축(정면 = +Z, 정면 기준 동쪽 = +X). ponytail: 초석·장화반·보머리 삼분두, 상층 주심도리·종보·대공은 아직
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local K = require(ReplicatedStorage.Shared.Chukbu)
local setup = require(script.Parent.Member)
local RoofSplit = require(ReplicatedStorage.Core.RoofSplit)
local Split = require(ReplicatedStorage.Shared.RoofSplit)
local M = require(ReplicatedStorage.Shared.Meoricho)

local s = Units.studs
local L = D.level

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

return function()
	if workspace:FindFirstChild("Chukbu") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Chukbu"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 지붕 분해가 클라이언트에서 부재 전체를 옮기므로 스트리밍으로 빠지지 않게

	-- story: 지붕 분해 층 (고주·귀고주는 상층, Shared.RoofSplit 머리말)
	local function part(story: RoofSplit.Story, name: string, cf: CFrame, size: Vector3, cylinder: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		setup(p, true) -- 기둥 등 축부는 지금처럼 부딪힌다
		RoofSplit.mark(p, story, Split)
		p.Size = Vector3.new(s(size.X), s(size.Y), s(size.Z))
		p.CFrame = cf
		if cylinder then
			p.Shape = Enum.PartType.Cylinder
		end
		p.Parent = model
		return p
	end
	-- 세로 원기둥: (x, z)에 y0~y1 (레벨)
	local function column(story: RoofSplit.Story, name: string, x: number, z: number, y0: number, y1: number, dia: number)
		part(story, name, CFrame.new(s(x), s((y(y0) + y(y1)) / 2), s(z)) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(y1 - y0, dia, dia), true)
	end
	-- 수평 부재: a→b (XZ 평면, m) 사이, 단면 w×h, 밑면 레벨 bottom. round면 지름 w 원형
	-- 긴 옆면: 상자는 Right·Left, 원통(축 = 로컬 X)은 Back·Front. 앞쪽 면에서 보면 a가 왼쪽이다
	local function beam(story: RoofSplit.Story, name: string, a: Vector2, b: Vector2, bottom: number, w: number, h: number, round: boolean?): Part
		local mid, len = (a + b) / 2, (b - a).Magnitude
		local yc = s(y(bottom) + h / 2)
		local cf = CFrame.lookAt(Vector3.new(s(mid.X), yc, s(mid.Y)), Vector3.new(s(b.X), yc, s(b.Y)))
		if round then
			return part(story, name, cf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(len, w, w), true)
		end
		return part(story, name, cf, Vector3.new(w, h, len))
	end
	local function decal(p: Part, round: boolean?, left: string, right: string)
		for i, face in if round then { Enum.NormalId.Back, Enum.NormalId.Front } else { Enum.NormalId.Right, Enum.NormalId.Left } do
			local d = Instance.new("Decal")
			d.Name = "Meoricho"
			d.Face = face
			d.Texture = if i == 1 then left else right
			d.Parent = p
		end
	end

	-- 머리초 부재 (Shared.Meoricho, ADR 0009): a→b를 이웃한 기둥 자리 사이(칸)마다 [머리초 | 계풍 | 머리초]로 나눈다.
	-- cols = 기둥 중심(이 줄 위로 투영해 쓴다), off = 기둥 중심에서 머리초가 시작하는 거리. 칸 밖 양끝(모서리)은 문양 없는 토막.
	-- 머리초는 기둥 쪽에서 바깥으로 지어 앞쪽 면에 a 그림(기둥이 왼쪽), 뒤쪽 면에 b 그림(거울상)을 붙인다
	local meorichoWarned = false
	local function meoricho(story: RoofSplit.Story, name: string, a: Vector2, b: Vector2, bottom: number, w: number, h: number, round: boolean?,
		motif: M.Motif, cols: { Vector2 }, off: number)
		local len, u = (b - a).Magnitude, (b - a).Unit
		local m = M.length * (if round then w else h) / motif.height
		local at = function(t: number): Vector2
			return a + u * t
		end
		local function piece(t0: number, t1: number): Part?
			return if t1 - t0 > 0.01 then beam(story, name, at(t0), at(t1), bottom, w, h, round) else nil
		end
		local ts = {}
		for _, c in cols do
			table.insert(ts, (c - a):Dot(u))
		end
		table.sort(ts)
		local images = motif.a ~= "" and motif.b ~= ""
		if not images and not meorichoWarned then
			meorichoWarned = true
			warn("머리초: Shared.Meoricho 에셋 ID가 비어 있어 문양 없이 나눔 (textures/meoricho/*.png 업로드 필요)")
		end
		local first, last = len, 0
		for i = 1, #ts - 1 do
			local s0, s1 = math.max(ts[i] + off, 0), math.min(ts[i + 1] - off, len)
			first, last = math.min(first, s0), math.max(last, s1)
			local h0 = beam(story, name, at(s0), at(s0 + m), bottom, w, h, round)
			local h1 = beam(story, name, at(s1), at(s1 - m), bottom, w, h, round)
			local g = piece(s0 + m, s1 - m)
			if images then
				decal(h0, round, motif.a, motif.b)
				decal(h1, round, motif.a, motif.b)
				if g and motif.gyepung ~= "" then
					decal(g, round, motif.gyepung, motif.gyepung)
				end
			end
		end
		-- 바깥 기둥 너머로 나간 끝만 토막을 둔다 (창방처럼 기둥 중심에서 끝나면 기둥 속이라 짓지 않는다)
		if ts[1] > 0.01 then
			piece(0, first)
		end
		if ts[#ts] < len - 0.01 then
			piece(last, len)
		end
	end

	local xs, zs = positions(D.lowerBays), positions(D.lowerSideBays)
	local ux, uz = positions(D.upperBays), positions(D.upperSideBays)
	local C = K.column
	local lx, lz, px, pz = xs[#xs], zs[#zs], ux[#ux], uz[#uz]
	-- 기둥 자리 (meoricho가 줄 위로 투영한다): 앞뒤 줄은 x, 양옆 줄은 z
	local colsX, colsZ = {}, {}
	for _, x in xs do
		table.insert(colsX, Vector2.new(x, 0))
	end
	for _, z in zs do
		table.insert(colsZ, Vector2.new(0, z))
	end

	-- 기둥: 하층 둘레 평주·우주, 가운데 줄 고주, 상층 모서리 귀고주, 상층 둘레 평주
	for i, x in xs do
		for j, z in zs do
			if i == 1 or i == #xs or j == 1 or j == #zs then
				local corner = (i == 1 or i == #xs) and (j == 1 or j == #zs)
				column("lower", corner and "Uju" or "Pyeongju", x, z, L.plinthTop, L.lowerColumnTop, C.lowerDia)
			else
				column("upper", "Goju", x, z, L.plinthTop, L.plinthTop + C.highLength, C.highDia)
			end
		end
	end
	for i, x in ux do
		for j, z in uz do
			local edgeX, edgeZ = i == 1 or i == #ux, j == 1 or j == #uz
			if edgeX and edgeZ then
				column("upper", "GwiGoju", x, z, L.upperColumnTop - C.cornerHighLength, L.upperColumnTop, C.cornerHighDia)
			elseif edgeX or edgeZ then
				column("upper", "UpperPyeongju", x, z, L.upperColumnTop - C.upperLength, L.upperColumnTop, C.upperDia)
			end
		end
	end

	-- 둘레(사각형 모서리 4점) 한 바퀴를 칸마다 잇는 부재
	local function ring(cols: { number }, rows: { number }, fn: (Vector2, Vector2) -> ())
		local x0, x1, z0, z1 = cols[1], cols[#cols], rows[1], rows[#rows]
		for i = 1, #cols - 1 do
			fn(Vector2.new(cols[i], z0), Vector2.new(cols[i + 1], z0))
			fn(Vector2.new(cols[i], z1), Vector2.new(cols[i + 1], z1))
		end
		for j = 1, #rows - 1 do
			fn(Vector2.new(x0, rows[j]), Vector2.new(x0, rows[j + 1]))
			fn(Vector2.new(x1, rows[j]), Vector2.new(x1, rows[j + 1]))
		end
	end

	-- 창방: 기둥 사이, 윗면 = 기둥 상
	local lc, uc = K.lowerChangbang, K.upperChangbang
	-- 하층 창방: 머리초는 창방 옆면이 둥근 기둥에서 나오는 자리부터 (기둥 반지름, 창방 폭 절반으로 잰 현의 거리)
	local lcOff = math.sqrt((C.lowerDia / 2) ^ 2 - (lc.width / 2) ^ 2)
	ring(xs, zs, function(a, b)
		meoricho("lower", "LowerChangbang", a, b, L.lowerColumnTop - lc.height, lc.width, lc.height, false, M.motifs.byeong, { a, b }, lcOff)
	end)
	ring(ux, uz, function(a, b)
		beam("upper", "UpperChangbang", a, b, L.upperColumnTop - uc.height, uc.width, uc.height)
	end)

	-- 평방: 기둥열을 따라 모서리까지 이어서 (모서리에서 평방 폭 절반만큼 더)
	local pb = K.pyeongbang
	local pbRows: { { hx: number, hz: number, base: number, story: RoofSplit.Story } } = {
		{ hx = lx, hz = lz, base = L.lowerColumnTop, story = "lower" },
		{ hx = px, hz = pz, base = L.upperColumnTop, story = "upper" },
	}
	-- 하층 평방은 기둥 중심에서 머리초 둘이 뒷목끼리 맞닿게 나눈다 (상층은 아직 한 줄)
	for _, r in pbRows do
		local hx = r.hx + pb.width / 2
		for _, sgn in { -1, 1 } do
			local a1, b1 = Vector2.new(-hx, sgn * r.hz), Vector2.new(hx, sgn * r.hz)
			local a2, b2 = Vector2.new(sgn * r.hx, -r.hz + pb.width / 2), Vector2.new(sgn * r.hx, r.hz - pb.width / 2)
			if r.story == "lower" then
				meoricho("lower", "Pyeongbang", a1, b1, r.base, pb.width, pb.height, false, M.motifs.juhwa, colsX, 0)
				meoricho("lower", "Pyeongbang", a2, b2, r.base, pb.width, pb.height, false, M.motifs.juhwa, colsZ, 0)
			else
				beam(r.story, "Pyeongbang", a1, b1, r.base, pb.width, pb.height)
				beam(r.story, "Pyeongbang", a2, b2, r.base, pb.width, pb.height)
			end
		end
	end

	-- 하층 대보(앞뒤, 고주 → 바깥)와 충량(양옆, 고주 → 바깥). 주상포 삼제공 자리를 지나 보머리가 밖으로 나간다
	local bm = K.lowerBeam
	local beamBottom = L.lowerColumnTop + D.lowerPyeongbangHeight + bm.base
	for i = 2, #xs - 1 do
		for _, sgn in { -1, 1 } do
			beam("lower", "Daebo", Vector2.new(xs[i], 0), Vector2.new(xs[i], sgn * bm.length), beamBottom, bm.width, bm.height)
		end
	end
	for _, sgn in { -1, 1 } do
		local from = sgn * xs[#xs - 1]
		beam("lower", "Chungryang", Vector2.new(from, 0), Vector2.new(from + sgn * bm.length, 0), beamBottom, bm.width, bm.height)
	end

	-- 상층 대보(앞뒤)·충량(양옆): 고주 줄에서 바깥으로, 상층 주상포 사제공 자리를 지난다
	local ub = K.upperBeam
	local upperBeamBottom = L.upperColumnTop + D.upperPyeongbangHeight + ub.base
	for i = 2, #ux - 1 do
		for _, sgn in { -1, 1 } do
			beam("upper", "UpperDaebo", Vector2.new(ux[i], 0), Vector2.new(ux[i], sgn * ub.length), upperBeamBottom, ub.width, ub.height)
		end
	end
	for _, sgn in { -1, 1 } do
		local from = sgn * xs[#xs - 1]
		beam("upper", "UpperChungryang", Vector2.new(from, 0), Vector2.new(from + sgn * ub.length, 0), upperBeamBottom, ub.height, ub.height) -- 충량 462×462 (S4 095)
	end

	-- 하층 외목도리·장여(외2출목, 모서리에서 만남)와 내목도리(내2출목)
	local od, oj, id = K.lowerOuterDori, K.lowerOuterJangyeo, K.lowerInnerDori
	local doriBottom = L.lowerEave
	local function rect(hx: number, hz: number, fn: (Vector2, Vector2) -> ())
		fn(Vector2.new(-hx, -hz), Vector2.new(hx, -hz))
		fn(Vector2.new(-hx, hz), Vector2.new(hx, hz))
		fn(Vector2.new(-hx, -hz), Vector2.new(-hx, hz))
		fn(Vector2.new(hx, -hz), Vector2.new(hx, hz))
	end
	rect(lx + od.outset, lz + od.outset, function(a, b)
		local d = (b - a).Unit * od.dia / 2 -- 모서리에서 지름 절반 더 내밀어 왕지처럼 겹치게
		-- 머리초: 기둥 자리 사이 칸마다. ponytail: 모서리 왕지 토막은 문양 없음 (S7 연화머리초는 아직)
		meoricho("lower", "LowerOuterDori", a - d, b + d, doriBottom, od.dia, od.dia, true, M.motifs.byeong, if a.Y == b.Y then colsX else colsZ, 0)
		beam("lower", "LowerOuterJangyeo", a, b, doriBottom - oj.height, oj.width, oj.height)
	end)
	rect(lx - id.inset, lz - id.inset, function(a, b)
		beam("lower", "LowerInnerDori", a, b, id.top - id.dia, id.dia, id.dia, true)
	end)

	-- 상층 외목도리·장여(외3출목). 윗면 = S4 021 2F_OUTSIDE_DORI_UPPER
	local uod, uoj = K.upperOuterDori, K.upperOuterJangyeo
	rect(px + uod.outset, pz + uod.outset, function(a, b)
		local d = (b - a).Unit * uod.dia / 2
		beam("upper", "UpperOuterDori", a - d, b + d, L.upperEave, uod.dia, uod.dia, true)
		beam("upper", "UpperOuterJangyeo", a, b, L.upperEave - uoj.height, uoj.width, uoj.height)
	end)

	-- 상층 내목도리·중도리(둘레)와 종도리(용마루 밑 한 줄). ponytail: 받치는 종보·대공·동자주는 아직
	for _, d in { { "UpperInnerDori", K.upperInnerDori }, { "Jungdori", K.jungdori } } do
		local k = d[2]
		rect(px - k.inset, pz - k.inset, function(a, b)
			local e = (b - a).Unit * k.dia / 2
			beam("upper", d[1], a - e, b + e, k.top - k.dia, k.dia, k.dia, true)
		end)
	end
	local jd = K.jongdori
	beam("upper", "Jongdori", Vector2.new(-jd.halfLength, 0), Vector2.new(jd.halfLength, 0), jd.top - jd.dia, jd.dia, jd.dia, true)

	model.Parent = workspace
end
