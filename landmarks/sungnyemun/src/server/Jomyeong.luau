--!strict
-- 숭례문 야간 조명 기구: 육축·문루 투광등(SpotLight), 처마 밑 SurfaceLight, 광장 가로등(PointLight). 광원 14개 (모바일).
-- 그리고 홍예 통로 빛·판문 빛 각 둘: 낮 조명(Tags.DAY_LIGHT)과 야간 조명. 한 번에 하나만 켜진다.
-- 첫 자리는 S15 사진(눈으로 참고)을 보고 대충 잡았다: 육축 면은 바닥에서 올려 비추고, 처마 밑 공포대가 밝고, 지붕 기와는 어둡다.
-- 자리·방향·밝기는 Studio에서 다듬는다 — 켜고 끄기는 태그(Tags.NIGHT_LIGHT)로 하므로 옮기거나 더한 기구도 태그만 붙이면 된다.
-- 여기 적은 Brightness가 켜진(밤) 밝기다. 클라이언트(core TimeOfDay)가 낮에는 0으로 내린다.
-- 건물 축(정면 +Z, m, 높이는 지면 기준)으로 짓고 init.server가 건물 자리로 돌린다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local Y = require(ReplicatedStorage.Shared.Yukchuk)
local Plaza = require(ReplicatedStorage.Shared.Plaza)
local RoofSplit = require(ReplicatedStorage.Core.RoofSplit)
local Split = require(ReplicatedStorage.Shared.RoofSplit)

local S = Units.studs(1)
local L = D.level
local function y(level: number): number -- T.B.M. 기준 높이 → 지면 기준
	return level - L.ground
end

local WARM = Color3.fromRGB(255, 196, 132) -- 근사: S15 사진의 석축·처마 불빛 (나트륨등 같은 주황 백색)
local LAMP = Color3.fromRGB(230, 176, 112) -- Neon 등알이 Bloom에 하얗게 날리지 않게 낮춘 색

-- 투광등 { 기구 자리 (x, y, z), 비추는 점, 밝기, Shadows } — 육축 앞뒤 면을 광장 바닥에서 올려 비추고, 육축 윗면 여장 안쪽에서 하층 처마 밑을 비춘다
-- 바닥 투광등은 Shadows를 켠다: 끄면 빛이 벽을 뚫고 홍예 통로로 새 벽과 반자가 날린다 (Play에서 확인)
local front, back = D.wall.south, D.wall.north
local LIFT = 0.9 -- 기구를 바닥에서 띄우는 높이. 복셀 조명(Technology Voxel)은 바닥 판에 묻힌 광원을 가려 버린다 (Studio에서 확인)
local SPOTS = {
	{ Vector3.new(-6.5, Plaza.floor(front + 5) + LIFT, front + 5), Vector3.new(-7, 5, front), 5, true },
	{ Vector3.new(6.5, Plaza.floor(front + 5) + LIFT, front + 5), Vector3.new(7, 5, front), 5, true },
	{ Vector3.new(-6.5, Plaza.floor(back - 5) + LIFT, back - 5), Vector3.new(-7, 5, back), 5, true },
	{ Vector3.new(6.5, Plaza.floor(back - 5) + LIFT, back - 5), Vector3.new(7, 5, back), 5, true },
	{ Vector3.new(-7, y(0) + LIFT, front - 0.9), Vector3.new(-7, y(L.lowerEave), front + 1), 2, false },
	{ Vector3.new(7, y(0) + LIFT, front - 0.9), Vector3.new(7, y(L.lowerEave), front + 1), 2, false },
}
local SPOT = { range = 60, angle = 100 } -- range 60 스터드(약 20 m)가 로블록스 최대

-- 처마 밑 SurfaceLight { 기둥열 Z(반폭), 기둥열 X 반폭, 높이 } — 기둥열 바로 밖 창방 아래에 숨긴 얇은 판에서 위로 공포·처마 밑을 비춘다
local function half(bays: { number }): number
	local t = 0
	for _, b in bays do
		t += b
	end
	return t / 2
end
local EAVES = {
	{ half(D.lowerSideBays) + 0.6, half(D.lowerBays), y(L.lowerColumnTop) - 0.6 },
	{ half(D.upperSideBays) + 0.6, half(D.upperBays), y(L.upperColumnTop) - 0.6 },
}
local EAVE = { brightness = 2, range = 16, angle = 80 }

local onFloor = Plaza.onFloor

-- 가로등 { x, z } — 정면 흙 마당(X ±13) 양옆 잔디 가장자리. 근사: 실제 가로등 자리 자료 없음.
-- 광장은 남쪽(+Z)으로 갈수록 서쪽이 좁아진다(Z 50에서 서쪽 연석 X −14) → 바닥 가장자리에서 2 m 안이 되도록 가운데 쪽으로 당긴다
local LAMP_MARGIN = 2
local LAMPS = {}
for _, xz in { { -15, 28 }, { 15, 28 }, { -15, 50 }, { 15, 50 } } do
	local x, z = xz[1], xz[2]
	while not onFloor(x, z, LAMP_MARGIN) and math.abs(x) > 0.5 do
		x -= math.sign(x) * 0.5
	end
	table.insert(LAMPS, { x, z })
end

-- 시작 검사: 가로등은 광장 바닥 가장자리에서 2 m 안, 투광등·처마 조명은 광장 바닥 위 (도로·보도에 서지 않는다)
for _, l in LAMPS do
	assert(onFloor(l[1], l[2], LAMP_MARGIN), `가로등 ({l[1]}, {l[2]})이 광장 바닥 가장자리 2 m 안에 없다`)
end
for _, s in SPOTS do
	local at = s[1] :: Vector3
	assert(onFloor(at.X, at.Z, 0), `투광등 ({at.X}, {at.Z})이 광장 바닥 밖이다`)
end
for _, e in EAVES do
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			assert(onFloor(sx * e[2], sz * e[1], 0), `처마 조명 끝 ({sx * e[2]}, {sz * e[1]})이 광장 바닥 밖이다`)
		end
	end
end
local POLE = 4 -- 근사: 가로등 높이(m)

-- 홍예 통로 빛: 해가 들지 않는 반자를 사진(S27)만큼 보이게 비춘다. 근사: 값은 Play에서 사진과 눈으로 맞췄다.
-- PointLight라 벽에 빛 경계가 없고 반자 남북이 고르다. Shadows는 반자 위 공포로 새지 않게 켠다 (Play에서 확인)
local TONGNO = {
	below = 2, -- 반자 아래 m
	range = 24, -- 닿는 거리(스터드). 통로 바닥까지 닿고, 북측 홍예 밖 바닥에 조금 샌다
	lights = { { Tags.DAY_LIGHT, Color3.new(1, 1, 1), 2 }, { Tags.NIGHT_LIGHT, WARM, 3 } }, -- { 태그, 색, 밝기 }. 저녁 "통로가 너무 어둡다" 지적으로 밤 밝기를 올렸다
}

-- 판문 빛: 판문이 있는 남측 홍예 안은 해도 투광등도 닿지 않아 닫힌 문이 까맣다. 통로 빛처럼 낮·밤 하나씩, 한 번에 하나만 켜진다. 근사: 값은 Play에서 눈으로 맞췄다
local PANMUN = {
	out = 1.6, -- 판문 자리에서 남쪽 m
	height = 3.5, -- 지면 위 m
	range = 20, -- 스터드
	lights = { { Tags.DAY_LIGHT, Color3.new(1, 1, 1), 0.9 }, { Tags.NIGHT_LIGHT, WARM, 2 } }, -- { 태그, 색, 밝기 }
}

local model: Model

local function part(name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Metal
	p.Color = color
	p.Size = size * S
	p.CFrame = cf
	p.Parent = model
	return p
end

return function()
	if workspace:FindFirstChild("Jomyeong") then
		return
	end
	model = Instance.new("Model")
	model.Name = "Jomyeong"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 멀리서도 불 켜진 문루가 보이게. 광원이 적어 부담 없음

	local dark = Color3.fromRGB(40, 40, 42)
	for _, s in SPOTS do
		-- 기구 앞면(Front, −Z)이 비추는 점을 본다
		local at = s[1] :: Vector3
		local post = part("TugwangdeungPost", Vector3.new(0.1, LIFT, 0.1), CFrame.new((at - Vector3.new(0, LIFT / 2, 0)) * S), dark) -- 기구를 받치는 짧은 기둥
		local p = part("Tugwangdeung", Vector3.new(0.4, 0.25, 0.3), CFrame.lookAt(at * S, (s[2] :: Vector3) * S), dark)
		if s[4] then -- 광장 바닥 등: 실제는 바닥에 묻혀 있다 (S41). 띄운 광원 자리는 그대로 두고 기구만 숨긴다 (파수군 앞을 가렸다)
			post.Transparency, p.Transparency = 1, 1
		end
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Color = WARM
		light.Brightness = s[3] :: number
		light.Range = SPOT.range
		light.Angle = SPOT.angle
		light.Shadows = s[4] :: boolean
		light.Parent = p
		CollectionService:AddTag(p, Tags.NIGHT_LIGHT)
	end

	for _, e in EAVES do
		for _, side in { 1, -1 } do
			local p = part("CheomaJomyeong", Vector3.new(e[2] * 2, 0.05, 0.05), CFrame.new(Vector3.new(0, e[3], side * e[1]) * S), dark)
			p.Transparency = 1
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Top
			light.Color = WARM
			light.Brightness = EAVE.brightness
			light.Range = EAVE.range
			light.Angle = EAVE.angle
			light.Parent = p
			CollectionService:AddTag(p, Tags.NIGHT_LIGHT)
			if e == EAVES[2] then
				RoofSplit.mark(p, "upper", Split, "gidung") -- 상층 처마 밑 조명판은 지붕 분해 때 상층과 같이 떠오른다
			end
		end
	end

	for _, xz in LAMPS do
		local x, z = xz[1], xz[2]
		local g = Plaza.floor(z)
		part("GarodeungPole", Vector3.new(0.12, POLE, 0.12), CFrame.new(Vector3.new(x, g + POLE / 2, z) * S), dark)
		-- 등 머리: Neon 등알은 태그로 낮에 투명해지고, 밤에 PointLight와 함께 켜진다
		local globe = part("Garodeung", Vector3.new(0.35, 0.35, 0.35), CFrame.new(Vector3.new(x, g + POLE + 0.1, z) * S), LAMP)
		globe.Shape = Enum.PartType.Ball
		globe.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = LAMP
		light.Brightness = 2
		light.Range = 56
		light.Parent = globe
		CollectionService:AddTag(globe, Tags.NIGHT_LIGHT)
	end

	-- 통로 가운데
	local doorZ = D.wall.south - Y.arches.south.length
	local tongno = Vector3.new(0, y(Y.passage.ceiling) - TONGNO.below, doorZ - Y.passage.banja.length / 2)
	for _, t in TONGNO.lights do
		local p = part("TongnoJomyeong", Vector3.new(0.05, 0.05, 0.05), CFrame.new(tongno * S), dark)
		p.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = t[2] :: Color3
		light.Brightness = t[3] :: number
		light.Range = TONGNO.range
		light.Shadows = true
		light.Parent = p
		CollectionService:AddTag(p, t[1] :: string)
	end

	for _, t in PANMUN.lights do
		local p = part("PanmunJomyeong", Vector3.new(0.05, 0.05, 0.05), CFrame.new(Vector3.new(0, PANMUN.height, doorZ + PANMUN.out) * S), dark)
		p.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = t[2] :: Color3
		light.Brightness = t[3] :: number
		light.Range = PANMUN.range
		light.Shadows = true
		light.Parent = p
		CollectionService:AddTag(p, t[1] :: string)
	end

	model.Parent = workspace
end
