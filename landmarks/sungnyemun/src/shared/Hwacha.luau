--!strict
-- 숭례문 화차(발사대) 데이터 (core Launcher가 움직인다). 단위 m, 건물 축 좌표(정면 +Z, ADR 0004).
-- 모양은 놀이 계획 시안(바퀴 둘 수레 + 기울어진 신기전 틀, 앞면에 구멍 줄)을 상자로 옮긴 것. 근사: 치수·색은 모두 눈대중.
-- Studio에서 만든 화차 Model에 Tags.LAUNCHER를 붙여 두면 이 상자 대신 그것을 쓴다(자리도 그 모델 자리).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Core.Units)
local Launcher = require(ReplicatedStorage.Core.Launcher)
local D = require(script.Parent.Dimensions)
local Plaza = require(script.Parent.Plaza)
local site = require(script.Parent.Site)

local S = Units.studs(1)
local WOOD = Color3.fromRGB(138, 90, 52)
local DARK = Color3.fromRGB(31, 37, 34)
local RED = Color3.fromRGB(181, 68, 43)

-- 자리: 시작 위치(박석 광장 Z 68, Greybox) 오른쪽 앞. 앞(−Z)이 문루를 본다
local AT = { x = 5, z = 64 }

local TILT = math.rad(30) -- 신기전 틀이 앞으로 들린 각
local rack = CFrame.new(0, 1.12, 0) * CFrame.Angles(TILT, 0, 0) -- 틀 가운데 (바닥판 위)
local RACK = Vector3.new(1.0, 0.6, 0.9)

local boxes: { Launcher.Box } = {
	{ size = RACK, cf = rack, color = WOOD }, -- 신기전 틀 (첫 상자: 프롬프트)
	{ size = RACK + Vector3.new(0.02, -RACK.Y + 0.06, 0.02), cf = rack * CFrame.new(0, RACK.Y / 2 - 0.1, 0), color = RED }, -- 틀 위쪽을 두르는 붉은 띠
	{ size = Vector3.new(1.0, 0.12, 1.8), cf = CFrame.new(0, 0.75, 0.1), color = WOOD }, -- 바닥판
	{ size = Vector3.new(1.3, 0.08, 0.08), cf = CFrame.new(0, 0.45, 0.1), color = DARK }, -- 굴대
}
for _, x in { -0.6, 0.6 } do
	table.insert(boxes, { size = Vector3.new(0.08, 0.9, 0.9), cf = CFrame.new(x, 0.45, 0.1), color = WOOD, shape = Enum.PartType.Cylinder }) -- 바퀴
	table.insert(boxes, { size = Vector3.new(0.06, 0.06, 1.3), cf = CFrame.new(x * 0.65, 0.4, 1.45) * CFrame.Angles(math.rad(32), 0, 0), color = WOOD }) -- 끌채
end
-- 틀 앞면 구멍 줄 (5줄 × 8)
for row = 1, 5 do
	for col = 1, 8 do
		local x, y = (col - 4.5) * 0.11, (row - 3) * 0.1
		table.insert(boxes, { size = Vector3.new(0.05, 0.05, 0.02), cf = rack * CFrame.new(x, y, -RACK.Z / 2 - 0.005), color = DARK, material = Enum.Material.SmoothPlastic })
	end
end

-- 조명: 화차 양옆 나무 기둥에 팔을 내어 매단 초롱 (위 붉은 등·아래 푸른 등). 밤에만 붉은 등 안 PointLight가 켜진다(Tags.NIGHT_LIGHT).
-- 근사: 크기·밝기는 눈대중. 범위 8 m면 화차와 그 둘레 탑승 자리가 다 든다
local LAMP = { brightness = 1.0, range = 8, color = Color3.fromRGB(255, 196, 140) }
local BLUE = Color3.fromRGB(40, 70, 150)
local fixtures: { Launcher.Box } = {}
for _, side in { -1, 1 } do
	local x = side * 1.5
	table.insert(fixtures, { size = Vector3.new(0.1, 2.4, 0.1), cf = CFrame.new(x, 1.2, 0.2), color = WOOD }) -- 기둥
	table.insert(fixtures, { size = Vector3.new(0.5, 0.06, 0.06), cf = CFrame.new(x - side * 0.25, 2.35, 0.2), color = WOOD }) -- 팔
	local lx = x - side * 0.4
	table.insert(fixtures, { size = Vector3.new(0.28, 0.2, 0.28), cf = CFrame.new(lx, 2.08, 0.2), color = RED, material = Enum.Material.Fabric, light = LAMP }) -- 위 붉은 등
	table.insert(fixtures, { size = Vector3.new(0.28, 0.16, 0.28), cf = CFrame.new(lx, 1.9, 0.2), color = BLUE, material = Enum.Material.Fabric }) -- 아래 푸른 등
end

local config: Launcher.Config = {
	site = site * CFrame.new(Vector3.new(AT.x, Plaza.floor(AT.z), AT.z) * S),
	boxes = boxes,
	fixtures = fixtures,
	-- 착지: 상층 지붕 앞면 가운데, 용마루에서 2.5 m 앞. 이 점(용마루 끝 위)에서 아래로 쏜 광선이 지붕 걷는 면(server Jibung walk)에 닿는다
	landing = site:PointToWorldSpace(Vector3.new(0, D.level.ridgeEndTop - D.level.ground + 2, 2.5) * S),
	apex = 6, -- 근사: 꼭대기가 착지점보다 6 m 위. 날아가는 시간 약 3초
	-- 음원을 바꿀 때는 여기만: id, 음량, 재생 속도, offset(음원 앞 무음을 건너뛸 초)
	sounds = {
		fire = { id = 134201956270955, volume = 0.2, offset = 0.38 }, -- 발사 "펑": 옛 로블록스 로켓 발사기 폭발음 (S23, 1.6초). 발사 순간 화차에서 한 번. 앞 무음 약 0.39초(PlaybackLoudness로 잼)
		land = { id = 9113479620, volume = 0.4, offset = 0.14 }, -- 착지 "툭": 낮고 둔한 몸 떨어지는 소리 (S24). 앞 무음 약 0.15초
	},
	-- 비명: 발사 순간 나는 사람에게서 한 번 (매번 하나 무작위). 짧아서 끝까지 울린다
	screams = {
		-- 음량: 음원마다 원래 크기가 달라 최고 크기를 지붕 분해 효과음(S21·S22)과 비슷하게 맞춤
		{ id = 78392419910398, volume = 0.5 }, -- "yeahh!!" (S25, 1.4초)
		{ id = 115665220802967, volume = 0.2, offset = 0.14 }, -- "Yeah" (S26, 1.4초). 앞 무음 약 0.15초
	},
}

return config
