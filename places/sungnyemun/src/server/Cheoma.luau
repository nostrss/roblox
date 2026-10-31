--!strict
-- 처마의 평연(나란한 서까래)과 부연을 짓는다. 서까래는 단면이 둥근 Part, 부연은 MemberMeshes의 Buyeon 메시.
-- 서까래 밑면은 안쪽 받침 도리와 외목도리 윗면에 닿고(Chukbu에서 짓는 값), 앙곡만큼 외목도리 닿는 점을 축으로 끝을 들어 올린다.
-- 원점 = 문루 중심 지면, 남 = +Z, 동 = +X. ponytail: 모서리 선자연·추녀·사래는 13번, 개판·초매기는 14번
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local K = require(ReplicatedStorage.Shared.Chukbu)
local C = require(ReplicatedStorage.Shared.Cheoma)

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
	return t[#t][2]
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

-- 서까래 하나. 밑면 선이 sIn·sOut(도리 윗면)을 지나고 sOut 밖 overhang 수평거리에서 끝난다. 끝을 rise만큼 들도록 sOut 축으로 돌린 각을 돌려준다
local function rafter(model: Model, name: string, f: Face, a: number, sIn: Vector2, sOut: Vector2, overhang: number, spec: any, rise: number): number
	local u = (sOut - sIn).Unit
	local tip = sOut + u * (overhang / u.X) + Vector2.new(0, rise)
	local u2 = (tip - sOut).Unit
	local n = Vector2.new(-u2.Y, u2.X) -- 위쪽 법선
	local c = sOut + u2 * ((tip - sOut).Magnitude - spec.length / 2) + n * (spec.dia / 2)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.Material = Enum.Material.Wood
	p.Color = WOOD
	p.Size = Vector3.new(spec.length, spec.dia, spec.dia) * S
	local pos = at(f, a, c)
	p.CFrame = CFrame.lookAt(pos, pos + dir(f, u2)) * CFrame.Angles(0, math.pi / 2, 0)
	p.Parent = model
	return math.atan2(u2.Y, u2.X) - math.atan2(u.Y, u.X)
end

-- 부연 하나: 윗면 꼬리·끝 점(외목도리 중심·윗면 기준)을 서까래와 같은 각만큼 sOut 축으로 돌려 놓는다
local function buyeon(model: Model, src: MeshPart, f: Face, a: number, sOut: Vector2, spec: any, angle: number)
	local B = C.buyeon
	local tail = rotate(sOut + Vector2.new(spec.tail[1], spec.tail[2]), sOut, angle)
	local tip = rotate(sOut + Vector2.new(spec.tip[1], spec.tip[2]), sOut, angle)
	local w = (tip - tail).Unit
	local m = Vector2.new(-w.Y, w.X)
	local height = B.profile[2][2] -- 윗면 v
	local k = spec.length / B.profile[3][1] -- 메시(하층 길이)를 이 층 길이로 늘림
	local c = tail + w * (spec.length / 2 - B.topFrom * k) - m * (height / 2)
	local p = src:Clone()
	p.Name = "Buyeon"
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Wood
	p.Color = WOOD
	p.Size = Vector3.new(spec.length, height, B.width) * S
	p.CFrame = CFrame.fromMatrix(at(f, a, c), dir(f, w), dir(f, m))
	p.Parent = model
end

local function slopeDeg(sIn: Vector2, sOut: Vector2): number
	return math.deg(math.atan2(sIn.Y - sOut.Y, sOut.X - sIn.X))
end

return function()
	if workspace:FindFirstChild("Cheoma") then
		return
	end
	local folder = CollectionService:GetTagged(Tags.MEMBER_MESHES)[1]
	local src = folder and folder:FindFirstChild("Buyeon")
	if not (src and src:IsA("MeshPart")) then
		warn("처마: MemberMeshes에 Buyeon이 없어 부연은 건너뜀 (places/sungnyemun/meshes/Buyeon.obj 업로드 필요)")
		src = nil
	end
	local L = D.level
	local root = Instance.new("Model")
	root.Name = "Cheoma"
	local count = { jangyeon = 0, danyeon = 0, buyeon = 0 }

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
			for _, a in laterals(row.count, row.spacing) do
				local angle = rafter(model, "Jangyeon", f, a, sIn, sOut, E.overhang, E.jangyeon, riseAt(riseTable, a))
				count.jangyeon += 1
				if src then
					buyeon(model, src :: MeshPart, f, a, sOut, E.buyeon, angle)
					count.buyeon += 1
				end
			end
			-- 상층 단연: 앞뒤 면만, 종도리 → 중도리. 앙곡 없음
			if E.danyeon and f.lat == Vector3.xAxis then
				local dn, jd = E.danyeon, K.jongdori
				local dIn, dOut = Vector2.new(0, jd.top), sIn
				assert(math.abs(slopeDeg(dIn, dOut) - dn.slope) < 0.5, `단연 물매 {slopeDeg(dIn, dOut)}° (S4 017 {dn.slope}°)`)
				for _, a in laterals(E.danyeonCount, row.spacing) do
					rafter(model, "Danyeon", f, a, dIn, dOut, dn.overhang, dn, 0)
					count.danyeon += 1
				end
			end
		end
	end
	-- S4 011·012: 장연 하층 (68+20)×2 + 상층 (59+10)×2 = 314, 단연 49×2, 부연은 장연마다 하나
	assert(count.jangyeon == 314 and count.danyeon == 98, `서까래 수 장연 {count.jangyeon}·단연 {count.danyeon}`)
	assert(not src or count.buyeon == 314, `부연 수 {count.buyeon}`)
	root.Parent = workspace
end
