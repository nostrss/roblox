--!strict
-- 숭례문 석축(육축): 몸채, 네 면 무사석, 홍예·통로·반자, 성문, 여장, 석누조, 동·서 계단 (데이터 Shared.Yukchuk·WallStones).
-- 건물 축으로 짓고 init.server가 건물 자리로 돌린다(ADR 0004). Part만 쓴다. 홍예 곡선은 홍예석 한 장씩(11장)으로 줄였다.
-- 높이 h = 통로 바닥(지면, Y 0) 위 m. 도면 level은 y()로 바꾼다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local Y = require(ReplicatedStorage.Shared.Yukchuk)
local WallStones = require(ReplicatedStorage.Shared.WallStones)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local UP = Vector3.yAxis
local W2 = D.wall.width / 2
local ZS, ZN = D.wall.south, D.wall.north
local STONE_DEPTH = 0.3 -- 면에 붙이는 돌 두께
local JOINT = 0.015 -- 줄눈 절반 폭 (도면 사각형을 이만큼씩 줄인다)
local SLICES = 10 -- 홍예 위 몸채를 나누는 켜 수

local function y(level: number): number
	return level - D.level.ground
end
local H = y(0) -- 석축 윗면

local model: Model
local rng = Random.new(1)

local function part(name: string, cf: CFrame, size: Vector3, class: string?): BasePart
	local p = Instance.new((class or "Part") :: any) :: BasePart
	p.Name = name
	setup(p, true)
	p.Size = size * S
	p.CFrame = CFrame.new(cf.Position * S) * cf.Rotation
	p.Parent = model
	return p
end

local function block(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): BasePart?
	if x1 - x0 < 1e-3 or y1 - y0 < 1e-3 or z1 - z0 < 1e-3 then
		return nil
	end
	return part(name, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, y1 - y0, z1 - z0))
end

local function shade(p: BasePart?, amount: number)
	if p then
		p.Color = p.Color:Lerp(Color3.fromRGB(120, 115, 105), rng:NextNumber(0, amount)) -- 돌마다 명도를 흔든다
	end
end

-- 홍예 하나의 단면 값
type Arch = { ri: number, re: number, spring: number }
local function arch(a: typeof(Y.arches.south)): Arch
	local ri = a.span / 2
	return { ri = ri, re = ri + a.ring, spring = y(a.crown) - ri }
end
local southArch, northArch = arch(Y.arches.south), arch(Y.arches.north)

-- 홍예 구간(z0..z1): 홍예석 고리 + 둘레 몸채. 홍예 위 몸채는 켜마다 바깥 원에 닿는 곳에서 자른다
local function vault(a: Arch, z0: number, z1: number, course: number)
	local W = W2
	for sx = -1, 1, 2 do
		block("YukchukBody", math.min(sx * a.ri, sx * W), 0, z0, math.max(sx * a.ri, sx * W), a.spring, z1)
		for k = 1, SLICES do
			local ya, yb = (k - 1) * a.re / SLICES, k * a.re / SLICES
			local xe = math.sqrt(a.re ^ 2 - ya ^ 2)
			block("YukchukBody", math.min(sx * xe, sx * W), a.spring + ya, z0, math.max(sx * xe, sx * W), a.spring + yb, z1)
		end
	end
	block("YukchukBody", -W, a.spring + a.re, z0, W, H, z1)

	-- 켜 사이 계단 모양 틈과 홍예석 사이 V자 줄눈 뒤를 메우는 바깥 고리 (홍예석 가운데 반지름부터, 면에서 조금 들여 앞 돌에 가린다)
	local rb, nb = a.re + 0.6, 24
	local r0, r1 = (a.ri + a.re) / 2, a.re + 0.55
	for i = 0, nb - 1 do
		local t = (i + 0.5) * math.pi / nb
		local r = (r0 + r1) / 2
		part(
			"YukchukBody",
			CFrame.new(r * math.cos(t), a.spring + r * math.sin(t), (z0 + z1) / 2) * CFrame.Angles(0, 0, t - math.pi / 2),
			Vector3.new(2 * rb * math.sin(math.pi / nb / 2) + 0.05, r1 - r0, math.max(z1 - z0 - 0.12, 0.01))
		)
	end

	-- 홍예석: 켜(course)마다 반원을 voussoirs장으로 나눈다. 가운데 반지름의 현 길이로 만들어 안쪽은 맞닿고 바깥은 줄눈처럼 벌어진다
	local n = Y.arches.voussoirs
	local rm = (a.ri + a.re) / 2
	local courses = math.max(1, math.round((z1 - z0) / course))
	local len = (z1 - z0) / courses
	for c = 0, courses - 1 do
		local zc = z0 + (c + 0.5) * len
		for i = 0, n - 1 do
			local t = (i + 0.5) * math.pi / n
			local p = part(
				"Hongyeseok",
				CFrame.new(rm * math.cos(t), a.spring + rm * math.sin(t), zc) * CFrame.Angles(0, 0, t - math.pi / 2),
				Vector3.new(2 * rm * math.sin(math.pi / n / 2) - 2 * JOINT, a.re - a.ri, len - 2 * JOINT)
			)
			shade(p, 0.2)
		end
	end
end

-- 면 하나의 돌. 면 좌표 u(가로)·level 높이 → 면 앞에 두께 STONE_DEPTH로 붙인다
type Face = { stones: { WallStones.Stone }, origin: Vector3, u: Vector3, out: Vector3, arch: Arch? }
local landingZ = Y.hyeopmun.z1 -- 계단 꼭대기 참의 남쪽 끝 = 협문 남쪽 끝

local function skip(f: Face, u0: number, h0: number, u1: number, h1: number): boolean
	if u1 - u0 < 0.12 or h1 - h0 < 0.08 then
		return true -- 문짝 줄·선 조각
	end
	local a = f.arch
	if a then
		if h0 < a.spring and u0 < a.ri - 0.05 and u1 > -a.ri + 0.05 then
			return true -- 홍예 문 안 (북측 입면은 문짝이 돌처럼 잡힌다)
		end
		if h1 > a.spring + 0.05 then -- 홍예석 자리: 사각형에서 홍예 중심까지 가장 가까운 거리가 바깥 반지름 안
			local dx = math.clamp(0, u0, u1)
			local dy = math.max(h0, a.spring) - a.spring
			if math.sqrt(dx * dx + dy * dy) < a.re - 0.05 then
				return true
			end
		end
	elseif u1 > ZN and u0 < landingZ then -- 동·서면: 계단·참 뒤는 가리고, 협문 자리 위는 문턱이 되지 않게 비운다
		if h0 < H or (u1 > Y.hyeopmun.z0 and h1 > H) then
			return true
		end
	end
	return false
end

local function face(f: Face)
	for _, st in f.stones do
		local u0, u1 = st[1] + JOINT, st[3] - JOINT
		local h0, h1 = math.max(y(st[2]) + JOINT, 0), y(st[4]) - JOINT
		if h1 > h0 and not skip(f, u0, h0, u1, h1) then
			local out = rng:NextNumber(0.01, 0.05) -- 돌마다 튀어나온 정도를 달리해 겹친 면 깜빡임을 막는다
			local pos = f.origin + f.u * (u0 + u1) / 2 + UP * (h0 + h1) / 2 + f.out * (out - STONE_DEPTH / 2)
			shade(part("Stone", CFrame.fromMatrix(pos, f.u, UP), Vector3.new(u1 - u0, h1 - h0, STONE_DEPTH)), 0.25)
		end
	end
end

-- 여장 한 구간: 전돌 몸 + 옥개. 두 꼭짓점(x, z)으로 바깥·안 모서리를 준다
local function parapet(x0: number, z0: number, x1: number, z1: number)
	local P = Y.parapet
	local top = y(D.level.parapetTop)
	block("YeojangJeon", x0, H, z0, x1, top - P.roofThickness, z1)
	local over = (P.roofWidth - P.thickness) / 2
	local thinX = x1 - x0 < z1 - z0 -- 두께 방향
	if thinX then
		block("Okgaejeon", x0 - over, top - P.roofThickness, z0, x1 + over, top, z1)
	else
		block("Okgaejeon", x0, top - P.roofThickness, z0 - over, x1, top, z1 + over)
	end
end

-- 계단: sx = 1 동, −1 서. 석축 면에서 바깥(sx)으로 참 → 디딤돌이 지면까지 내려간다
local function stairs(sx: number, width: number)
	local T = Y.stairs
	local riser = H / T.risers
	local function xr(a: number, b: number): (number, number) -- 면에서 잰 거리 a..b → 건물 축 x 범위
		local p, q = sx * (W2 + a), sx * (W2 + b)
		return math.min(p, q), math.max(p, q)
	end
	local lx0, lx1 = xr(0, T.landing)
	block("Dideumdol", lx0, 0, ZN, lx1, H, landingZ)
	for k = 1, T.risers - 1 do
		local a = T.landing + (k - 1) * T.tread
		local x0, x1 = xr(a, a + T.tread)
		shade(block("Dideumdol", x0, 0, ZN, x1, H - k * riser, ZN + width), 0.15)
	end

	-- 소맷돌: 북쪽 옆, 디딤돌 바깥 모서리 선 위로 rail.height. 참 위는 수평, 경사는 한 장으로
	local R = T.rail
	local rz = ZN + R.width / 2
	local px0, px1 = xr(0, T.landing)
	block("Somaetdol", px0, H, ZN, px1, H + R.height, ZN + R.width)
	local run = T.risers * T.tread
	local top = Vector3.new(sx * (W2 + T.landing), H, rz)
	local foot = Vector3.new(sx * (W2 + T.landing + run), 0, rz)
	local along = (foot - top).Unit
	local normal = along:Cross(Vector3.zAxis * sx).Unit -- 경사면에 수직, 위쪽
	if normal.Y < 0 then
		normal = -normal
	end
	local thick = R.height + 0.5 -- 디딤돌 이빨 사이를 메우도록 아래로 늘인다
	local mid = (top + foot) / 2 + normal * (R.height - thick / 2)
	part("Somaetdol", CFrame.lookAt(mid, mid + along, normal), Vector3.new(R.width, thick, (foot - top).Magnitude))
end

return function()
	if workspace:FindFirstChild("Yukchuk") then
		return
	end
	model = Instance.new("Model")
	model.Name = "Yukchuk"

	-- 통로: 남측 홍예 | 넓은 통로(반자널 천장) | 북측 홍예
	local A = Y.arches
	local zDoor = ZS - A.south.length -- 남측 홍예 안쪽 끝 = 성문 자리
	local zNorth = ZN + A.north.length
	vault(southArch, zDoor, ZS, A.south.course)
	vault(northArch, ZN, zNorth, A.north.course)

	local P = Y.passage
	local pw, hc = P.width / 2, y(P.ceiling)
	block("YukchukBody", -W2, 0, zNorth, -pw, hc, zDoor)
	block("YukchukBody", pw, 0, zNorth, W2, hc, zDoor)
	block("YukchukBody", -W2, hc, zNorth, W2, H, zDoor)

	-- 성문: 상둔테 아래 두 짝, 통로 벽 쪽으로 열어 둔다. 바깥면(닫혔을 때 남쪽)에 철엽
	local G = Y.gate
	local dz = zDoor - G.dunte.width / 2
	block("Dunte", -G.dunte.length / 2, G.leafHeight, zDoor - G.dunte.width, G.dunte.length / 2, G.leafHeight + G.dunte.height, zDoor)
	for sx = -1, 1, 2 do
		local hinge = CFrame.new(sx * G.leafWidth, 0.02, dz) * CFrame.Angles(0, math.rad(-sx * G.openAngle), 0)
		part("Seongmun", hinge * CFrame.new(-sx * G.leafWidth / 2, G.leafHeight / 2, -G.thickness / 2), Vector3.new(G.leafWidth, G.leafHeight, G.thickness))
		part("Cheoryeop", hinge * CFrame.new(-sx * G.leafWidth / 2, G.leafHeight / 2, G.plate / 2), Vector3.new(G.leafWidth, G.leafHeight, G.plate))
	end

	-- 반자널: 성문 자리(상둔테 위)부터 북쪽으로 동서로 걸친 널 (홍예 반자)
	local pk = P.plank
	local pw1 = P.banja.length / pk.count
	for i = 0, pk.count - 1 do
		local z1 = zDoor - i * pw1
		block("Banjaneol", -pk.length / 2, hc - pk.thickness, z1 - pw1 + 0.005, pk.length / 2, hc, z1 - 0.005)
	end

	-- 통로 바닥 판석: 줄마다 반 장씩 엇갈려 깐다. 윗면은 광장 바닥보다 2 cm 높게 (겹친 면 깜빡임 방지)
	local sl = P.slab
	local row = 0
	local zr = ZN
	while zr < ZS - 1e-3 do
		local z1 = math.min(zr + sl.width, ZS)
		local zc = (zr + z1) / 2
		local half = if zc > zDoor then southArch.ri elseif zc < zNorth then northArch.ri else pw
		local x = -half - (row % 2) * sl.length / 2
		while x < half do
			local x0, x1 = math.max(x, -half), math.min(x + sl.length, half)
			shade(block("Panseok", x0 + JOINT, 0.02 - sl.thickness, zr + JOINT, x1 - JOINT, 0.02, z1 - JOINT), 0.2)
			x += sl.length
		end
		zr = z1
		row += 1
	end

	-- 네 면 무사석
	face({ stones = WallStones.south, origin = Vector3.new(0, 0, ZS), u = Vector3.xAxis, out = Vector3.zAxis, arch = southArch })
	face({ stones = WallStones.north, origin = Vector3.new(0, 0, ZN), u = Vector3.xAxis, out = -Vector3.zAxis, arch = northArch })
	face({ stones = WallStones.east, origin = Vector3.new(W2, 0, 0), u = Vector3.zAxis, out = Vector3.xAxis })
	face({ stones = WallStones.west, origin = Vector3.new(-W2, 0, 0), u = Vector3.zAxis, out = -Vector3.xAxis })

	-- 여장: 남·북은 끝까지, 동·서는 그 사이. 동·서 협문 자리는 비운다
	local Pp = Y.parapet
	local i, t = Pp.inset, Pp.thickness
	parapet(-W2 + i, ZS - i - t, W2 - i, ZS - i)
	parapet(-W2 + i, ZN + i, W2 - i, ZN + i + t)
	for sx = -1, 1, 2 do
		local x0, x1 = math.min(sx * (W2 - i), sx * (W2 - i - t)), math.max(sx * (W2 - i), sx * (W2 - i - t))
		parapet(x0, ZN + i + t, x1, Y.hyeopmun.z0)
		parapet(x0, Y.hyeopmun.z1, x1, ZS - i - t)
	end

	-- 석누조: 남·북면 여장 지대석 아래로 내민다
	local N = Y.nujo
	local n0, n1 = y(N.top - N.height), y(N.top)
	for _, u in N.south do
		block("Nujo", u - N.width / 2, n0, ZS - (N.length - N.out), u + N.width / 2, n1, ZS + N.out)
	end
	for _, u in N.north do
		block("Nujo", u - N.width / 2, n0, ZN - N.out, u + N.width / 2, n1, ZN + (N.length - N.out))
	end

	stairs(1, Y.stairs.east.width)
	stairs(-1, Y.stairs.west.width)

	model.Parent = workspace
end
