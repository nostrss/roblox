--!strict
-- 숭례문 야간 조명 기구: 육축·문루 투광등(SpotLight), 처마 밑 SurfaceLight, 광장 가로등(PointLight). 광원 14개 (모바일).
-- 첫 자리는 S15 사진(눈으로 참고)을 보고 대충 잡았다: 육축 면은 바닥에서 올려 비추고, 처마 밑 공포대가 밝고, 지붕 기와는 어둡다.
-- 자리·방향·밝기는 Studio에서 다듬는다 — 켜고 끄기는 태그(Tags.NIGHT_LIGHT)로 하므로 옮기거나 더한 기구도 태그만 붙이면 된다.
-- 여기 적은 Brightness가 켜진(밤) 밝기다. 클라이언트(core TimeOfDay)가 낮에는 0으로 내린다.
-- 건물 축(정면 +Z, m, 높이는 지면 기준)으로 짓고 init.server가 건물 자리로 돌린다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local Plaza = require(ReplicatedStorage.Shared.Plaza)

local S = Units.studs(1)
local L = D.level
local function y(level: number): number -- T.B.M. 기준 높이 → 지면 기준
	return level - L.ground
end

local WARM = Color3.fromRGB(255, 196, 132) -- 근사: S15 사진의 석축·처마 불빛 (나트륨등 같은 주황 백색)
local LAMP = Color3.fromRGB(230, 176, 112) -- Neon 등알이 Bloom에 하얗게 날리지 않게 낮춘 색

-- 투광등 { 기구 자리 (x, y, z), 비추는 점, 밝기 } — 육축 앞뒤 면을 광장 바닥에서 올려 비추고, 육축 윗면 여장 안쪽에서 하층 처마 밑을 비춘다
local front, back = D.wall.south, D.wall.north
local LIFT = 0.9 -- 기구를 바닥에서 띄우는 높이. 복셀 조명(Technology Voxel)은 바닥 판에 묻힌 광원을 가려 버린다 (Studio에서 확인)
local SPOTS = {
	{ Vector3.new(-6.5, Plaza.floor(front + 5) + LIFT, front + 5), Vector3.new(-7, 5, front), 8 },
	{ Vector3.new(6.5, Plaza.floor(front + 5) + LIFT, front + 5), Vector3.new(7, 5, front), 8 },
	{ Vector3.new(-6.5, Plaza.floor(back - 5) + LIFT, back - 5), Vector3.new(-7, 5, back), 8 },
	{ Vector3.new(6.5, Plaza.floor(back - 5) + LIFT, back - 5), Vector3.new(7, 5, back), 8 },
	{ Vector3.new(-7, y(0) + LIFT, front - 0.9), Vector3.new(-7, y(L.lowerEave), front + 1), 2 },
	{ Vector3.new(7, y(0) + LIFT, front - 0.9), Vector3.new(7, y(L.lowerEave), front + 1), 2 },
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

-- 가로등 { x, z } — 정면 흙 마당(X ±13) 양옆 잔디 가장자리. 근사: 실제 가로등 자리 자료 없음
local LAMPS = { { -15, 28 }, { 15, 28 }, { -15, 50 }, { 15, 50 } }
local POLE = 4 -- 근사: 가로등 높이(m)

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
		part("TugwangdeungPost", Vector3.new(0.1, LIFT, 0.1), CFrame.new((at - Vector3.new(0, LIFT / 2, 0)) * S), dark) -- 기구를 받치는 짧은 기둥
		local p = part("Tugwangdeung", Vector3.new(0.4, 0.25, 0.3), CFrame.lookAt(at * S, (s[2] :: Vector3) * S), dark)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Color = WARM
		light.Brightness = s[3] :: number
		light.Range = SPOT.range
		light.Angle = SPOT.angle
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
		light.Brightness = 1.5
		light.Range = 40
		light.Parent = globe
		CollectionService:AddTag(globe, Tags.NIGHT_LIGHT)
	end

	model.Parent = workspace
end
