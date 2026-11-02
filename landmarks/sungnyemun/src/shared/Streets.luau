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
-- 메시는 Studio AI 메시 생성으로 만들었다 (S46). 앞이 −Z로 나오므로 돌리지 않는다 (Studio에서 5종 확인). 특정 차종이 아니다. 메시를 못 받으면 상자로 보인다
local ENGINE = 9112735838 -- S20

local function bus(meshId: number, texture: number, color: Color3): Traffic.Kind
	return {
		boxes = { { size = Vector3.new(2.5, 3.2, 11), at = Vector3.new(0, 1.6, 0), mesh = meshId, texture = texture } },
		colors = { color },
		lamp = Vector3.new(0.9, 0.75, 5.52),
		shadow = true,
		spot = true,
		engine = { id = ENGINE, volume = 0.7, speed = 0.75 },
	}
end

local function car(meshId: number, texture: number, color: Color3, height: number): Traffic.Kind
	return {
		boxes = { { size = Vector3.new(1.85, height, 4.7), at = Vector3.new(0, height / 2, 0), mesh = meshId, texture = texture } },
		colors = { color },
		lamp = Vector3.new(0.65, 0.7, 2.36),
		engine = { id = ENGINE, volume = 0.45, speed = 1 },
	}
end

-- 색: 서울 시내버스 간선 파랑·지선 초록, 택시 꽃담황토 주황
local blueBus = bus(98189549187324, 131511123801289, Color3.fromRGB(40, 90, 190))
local greenBus = bus(91404385864241, 128231080467625, Color3.fromRGB(70, 160, 60))
local taxi = car(115031979282474, 125122848979477, Color3.fromRGB(225, 130, 50), 1.6)
local whiteCar = car(116477144088305, 116902220895007, Color3.fromRGB(235, 235, 235), 1.45)
local blackCar = car(126977215622932, 99878769423911, Color3.fromRGB(20, 20, 22), 1.5)

local cars = { whiteCar, whiteCar, blackCar, blackCar, taxi, taxi }

-- 차로 하나: Shared.Lanes의 차로 가운데선을 세계 좌표로
local function lane(road: Lanes.Road, name: string, speed: number, gap: { number }, kinds: { Traffic.Kind }): Traffic.Lane
	local l = road.lanes[name]
	return { path = world(Lanes.line(road, l.t, l.dir)), speed = speed, gap = gap, kinds = kinds }
end

local buses = { blueBus }
local sowolKinds = { whiteCar, blackCar, blackCar, taxi, greenBus }
local config: Traffic.Config = {
	max = 14,
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
