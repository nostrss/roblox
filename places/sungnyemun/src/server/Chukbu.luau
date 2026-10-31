--!strict
-- 축부(기둥·창방·평방·대보·충량·하층 도리)를 Part로 짓는다. 단면이 일정한 부재라 메시 없이 Part로 충분하다.
-- 원점 = 문루 중심 지면, 남 = +Z, 동 = +X. ponytail: 초석·장화반·보머리 삼분두·상층 도리는 아직 (상층 도리는 상층 공포와 함께)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local K = require(ReplicatedStorage.Shared.Chukbu)

local s = Units.studs
local L = D.level
local WOOD = Color3.fromRGB(120, 60, 45) -- 석간주 근사 (단청은 F 단계)

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

	local function part(name: string, cf: CFrame, size: Vector3, cylinder: boolean?)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Material = Enum.Material.Wood
		p.Color = WOOD
		p.Size = Vector3.new(s(size.X), s(size.Y), s(size.Z))
		p.CFrame = cf
		if cylinder then
			p.Shape = Enum.PartType.Cylinder
		end
		p.Parent = model
	end
	-- 세로 원기둥: (x, z)에 y0~y1 (레벨)
	local function column(name: string, x: number, z: number, y0: number, y1: number, dia: number)
		part(name, CFrame.new(s(x), s((y(y0) + y(y1)) / 2), s(z)) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(y1 - y0, dia, dia), true)
	end
	-- 수평 부재: a→b (XZ 평면, m) 사이, 단면 w×h, 밑면 레벨 bottom. round면 지름 w 원형
	local function beam(name: string, a: Vector2, b: Vector2, bottom: number, w: number, h: number, round: boolean?)
		local mid, len = (a + b) / 2, (b - a).Magnitude
		local yc = s(y(bottom) + h / 2)
		local cf = CFrame.lookAt(Vector3.new(s(mid.X), yc, s(mid.Y)), Vector3.new(s(b.X), yc, s(b.Y)))
		if round then
			part(name, cf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(len, w, w), true)
		else
			part(name, cf, Vector3.new(w, h, len))
		end
	end

	local xs, zs = positions(D.lowerBays), positions(D.lowerSideBays)
	local ux, uz = positions(D.upperBays), positions(D.upperSideBays)
	local C = K.column
	local lx, lz, px, pz = xs[#xs], zs[#zs], ux[#ux], uz[#uz]

	-- 기둥: 하층 둘레 평주·우주, 가운데 줄 고주, 상층 모서리 귀고주, 상층 둘레 평주
	for i, x in xs do
		for j, z in zs do
			if i == 1 or i == #xs or j == 1 or j == #zs then
				local corner = (i == 1 or i == #xs) and (j == 1 or j == #zs)
				column(corner and "Uju" or "Pyeongju", x, z, L.plinthTop, L.lowerColumnTop, C.lowerDia)
			else
				column("Goju", x, z, L.plinthTop, L.plinthTop + C.highLength, C.highDia)
			end
		end
	end
	for i, x in ux do
		for j, z in uz do
			local edgeX, edgeZ = i == 1 or i == #ux, j == 1 or j == #uz
			if edgeX and edgeZ then
				column("GwiGoju", x, z, L.upperColumnTop - C.cornerHighLength, L.upperColumnTop, C.cornerHighDia)
			elseif edgeX or edgeZ then
				column("UpperPyeongju", x, z, L.upperColumnTop - C.upperLength, L.upperColumnTop, C.upperDia)
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
	ring(xs, zs, function(a, b)
		beam("LowerChangbang", a, b, L.lowerColumnTop - lc.height, lc.width, lc.height)
	end)
	ring(ux, uz, function(a, b)
		beam("UpperChangbang", a, b, L.upperColumnTop - uc.height, uc.width, uc.height)
	end)

	-- 평방: 기둥열을 따라 모서리까지 이어서 (모서리에서 평방 폭 절반만큼 더)
	local pb = K.pyeongbang
	for _, r in { { lx, lz, L.lowerColumnTop }, { px, pz, L.upperColumnTop } } do
		local hx, base = r[1] + pb.width / 2, r[3]
		for _, sgn in { -1, 1 } do
			beam("Pyeongbang", Vector2.new(-hx, sgn * r[2]), Vector2.new(hx, sgn * r[2]), base, pb.width, pb.height)
			beam("Pyeongbang", Vector2.new(sgn * r[1], -r[2] + pb.width / 2), Vector2.new(sgn * r[1], r[2] - pb.width / 2), base, pb.width, pb.height)
		end
	end

	-- 하층 대보(앞뒤, 고주 → 바깥)와 충량(양옆, 고주 → 바깥). 주상포 삼제공 자리를 지나 보머리가 밖으로 나간다
	local bm = K.lowerBeam
	local beamBottom = L.lowerColumnTop + D.lowerPyeongbangHeight + bm.base
	for i = 2, #xs - 1 do
		for _, sgn in { -1, 1 } do
			beam("Daebo", Vector2.new(xs[i], 0), Vector2.new(xs[i], sgn * bm.length), beamBottom, bm.width, bm.height)
		end
	end
	for _, sgn in { -1, 1 } do
		local from = sgn * xs[#xs - 1]
		beam("Chungryang", Vector2.new(from, 0), Vector2.new(from + sgn * bm.length, 0), beamBottom, bm.width, bm.height)
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
		beam("LowerOuterDori", a - d, b + d, doriBottom, od.dia, od.dia, true)
		beam("LowerOuterJangyeo", a, b, doriBottom - oj.height, oj.width, oj.height)
	end)
	rect(lx - id.inset, lz - id.inset, function(a, b)
		beam("LowerInnerDori", a, b, id.top - id.dia, id.dia, id.dia, true)
	end)

	model.Parent = workspace
end
