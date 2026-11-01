--!strict
-- 숭례문 둘레 도로 차량 데이터 (core Traffic이 움직인다). 단위 m, 출처 ID는 SOURCES.md.
-- 차로 경로는 Shared.Lanes의 차로 가운데선 (우측 통행, 보행 경계 안에서는 차도 위인지 Lanes가 시작할 때 검사한다).
-- 높이는 차도 면 Plaza.road(z) 그대로 (둘레 도로는 한 기울어진 면, ADR 0006). 차는 보행 경계 밖 멀리서 나와 멀리서 사라진다.
-- 근사: 차 크기·색·속도·빈도는 모두 눈대중 첫 값이다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Core.Units)
local Traffic = require(ReplicatedStorage.Core.Traffic)
local Plaza = require(script.Parent.Plaza)
local Lanes = require(script.Parent.Lanes)
local site = require(script.Parent.Site)

local S = Units.studs(1)

-- 건물 축 꺾은선 → 세계 좌표(스터드), 높이는 차도 면
local function world(points: { Vector3 }): { Vector3 }
	local out = {}
	for i, p in points do
		out[i] = site:PointToWorldSpace(Vector3.new(p.X, Plaza.road(p.Z), p.Z) * S)
	end
	return out
end

-- 차 종류. 앞 = −Z, 바닥 = 0. 크기: 시내버스 약 11 × 2.5 × 3.2 m, 승용차·택시 약 4.7 × 1.85 × 1.5 m
local DARK = Color3.fromRGB(28, 28, 30) -- 바퀴 자리·차 밑
local GLASS = Color3.fromRGB(40, 48, 56) -- 유리
local ENGINE = 9112735838 -- S20

local function bus(colors: { Color3 }): Traffic.Kind
	return {
		boxes = {
			{ size = Vector3.new(2.5, 2.85, 11), at = Vector3.new(0, 0.35 + 2.85 / 2, 0) },
			{ size = Vector3.new(2.3, 0.4, 10.2), at = Vector3.new(0, 0.2, 0), color = DARK },
			{ size = Vector3.new(2.54, 1.1, 9.4), at = Vector3.new(0, 2.15, 0.4), color = GLASS }, -- 옆 창 띠
			{ size = Vector3.new(2.3, 1.3, 0.04), at = Vector3.new(0, 2.05, -5.5), color = GLASS }, -- 앞 유리
		},
		colors = colors,
		lamp = Vector3.new(0.9, 0.75, 5.52),
		shadow = true,
		spot = true,
		engine = { id = ENGINE, volume = 0.7, speed = 0.75 },
	}
end

local function car(colors: { Color3 }, sign: boolean?): Traffic.Kind
	local boxes: { Traffic.Box } = {
		{ size = Vector3.new(1.85, 0.75, 4.7), at = Vector3.new(0, 0.2 + 0.75 / 2, 0) },
		{ size = Vector3.new(1.7, 0.25, 4.0), at = Vector3.new(0, 0.125, 0), color = DARK },
		{ size = Vector3.new(1.65, 0.55, 2.5), at = Vector3.new(0, 0.95 + 0.55 / 2, 0.25), color = GLASS }, -- 지붕까지 유리 덩어리
	}
	if sign then
		table.insert(boxes, { size = Vector3.new(0.6, 0.22, 0.25), at = Vector3.new(0, 1.5 + 0.11, 0.25), color = Color3.fromRGB(235, 235, 225) }) -- 택시 표시등
	end
	return {
		boxes = boxes,
		colors = colors,
		lamp = Vector3.new(0.65, 0.7, 2.36),
		engine = { id = ENGINE, volume = 0.45, speed = 1 },
	}
end

-- 색: 서울 시내버스 간선 파랑·지선 초록·광역 빨강, 택시 꽃담황토 주황. 근사: 색값은 눈대중
local blueBus = bus({ Color3.fromRGB(40, 90, 190) })
local greenBus = bus({ Color3.fromRGB(70, 160, 60) })
local redBus = bus({ Color3.fromRGB(200, 40, 40) })
local taxi = car({ Color3.fromRGB(225, 130, 50) }, true)
local sedan = car({
	Color3.fromRGB(235, 235, 235), -- 흰색
	Color3.fromRGB(20, 20, 22), -- 검정
	Color3.fromRGB(160, 162, 166), -- 은색
	Color3.fromRGB(80, 82, 88), -- 진회색
	Color3.fromRGB(30, 45, 80), -- 남색
})

local cars = { sedan, sedan, sedan, sedan, taxi, taxi }

-- 차로 하나: Shared.Lanes의 차로 가운데선을 세계 좌표로
local function lane(road: Lanes.Road, name: string, speed: number, gap: { number }, kinds: { Traffic.Kind }): Traffic.Lane
	local l = road.lanes[name]
	return { path = world(Lanes.line(road, l.t, l.dir)), speed = speed, gap = gap, kinds = kinds }
end

local buses = { blueBus, blueBus, redBus }
local sowolKinds = { sedan, sedan, sedan, taxi, greenBus }
local config: Traffic.Config = {
	max = 8,
	lanes = {
		lane(Lanes.sejong, "north", 12, { 6, 30 }, cars),
		lane(Lanes.sejong, "south", 12, { 6, 30 }, cars),
		lane(Lanes.sejong, "busNorth", 10, { 15, 50 }, buses),
		lane(Lanes.sejong, "busSouth", 10, { 15, 50 }, buses),
		lane(Lanes.sowol, "inbound", 11, { 8, 40 }, sowolKinds),
		lane(Lanes.sowol, "outbound", 11, { 8, 40 }, sowolKinds),
	},
}

return config
