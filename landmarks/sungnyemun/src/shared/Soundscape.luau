--!strict
-- 숭례문 환경음 데이터 (core Ambience가 재생). 에셋 출처는 SOURCES.md S16~S19.
-- 크기는 모바일 기준으로 낮게 잡았다. 전체 크기는 SoundService.Ambience(SoundGroup) 하나로 조절한다.
-- 근사: 값은 모두 귀로 다듬기 전 첫 값이다.
-- 풍경(風磬)은 넣지 않는다: S3·S7 보고서 전문에 풍경·풍탁이 없다 (지붕 철물·토수까지 적은 보고서). 성문 문루라 사찰 전각과 다르다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Core.Units)
local Ambience = require(ReplicatedStorage.Core.Ambience)
local D = require(script.Parent.Dimensions)
local Plaza = require(script.Parent.Plaza)
local Y = require(script.Parent.Yukchuk)
local site = require(script.Parent.Site)

local S = Units.studs(1)
local L = D.level

-- 지면(통로 바닥, Y = 0) 위 높이(m)
local baseTop = 0 - L.ground -- 육축 윗면(T.B.M. ±0) 8.14
local upperFloor = L.upperFloor - L.ground -- 상층 마루 13.57

-- 도로 중심선: 연석과 맞은편 연석의 가운데를 광장 둘레 차례로 잇는다 (도로 없는 남쪽 점은 뺀다).
-- 세종대로 남쪽 연장 끝에서 시작한다. 높이는 차도 면 + 1 m (차 소리 나는 높이)
local road: { Vector3 } = {}
local function add(x: number, z: number)
	table.insert(road, site:PointToWorldSpace(Vector3.new(x, Plaza.road(z) + 1, z) * S))
end
do
	local w1 = Plaza.curb[1]
	local fx, fz = Plaza.roadFar(1)
	local ax, az = Plaza.toEdge(w1[1], w1[2])
	local bx, bz = Plaza.toEdge(fx, fz)
	add((ax + bx) / 2, (az + bz) / 2)
	for i, q in Plaza.curb do
		if q[3] > 0 then
			local x, z = Plaza.roadFar(i)
			add((q[1] + x) / 2, (q[2] + z) / 2)
		end
	end
end

-- 홍예 통로: 북측면~남측면, 넓은 통로 폭, 반자 높이까지 (건물 축 → 세계, ADR 0004)
local passageH = Y.passage.ceiling - L.ground
local passage: Ambience.Zone = {
	cframe = site * CFrame.new(Vector3.new(0, passageH / 2, (D.wall.north + D.wall.south) / 2) * S),
	size = Vector3.new(Y.passage.width, passageH, D.wall.south - D.wall.north) * S,
	reverb = Enum.ReverbType.StoneCorridor,
}

-- 해 높이 기준점은 core TimeOfDay와 맞춘다: 노을 색조 0.25, 조명 켬 0.03, 밤 색조 −0.06
local config: Ambience.Config = {
	volume = 0.8,
	layers = {
		-- 바람: 광장은 잔잔하게, 육축 위·문루 상층으로 오를수록 세게 (+캐릭터 허리 높이 약 1 m)
		Wind = {
			id = 9114057128,
			volume = 0.4,
			byHeight = { { 3, 0.4 }, { baseTop + 1, 0.75 }, { upperFloor + 1, 1 } },
			sway = 0.25,
		},
		-- 차 소리: 광장 세 면 도로에서 가까울수록 크게. 낮밤 없이 같다
		Traffic = { id = 9112888844, volume = 0.5, line = road, rolloff = { 8, 160 }, sway = 0.1 },
		-- 새: 낮. 노을 무렵 줄고 조명이 켜질 때쯤 그친다
		Birds = { id = 9116969794, volume = 0.3, bySun = { { 0.03, 0 }, { 0.25, 1 } }, sway = 0.15 },
		-- 풀벌레: 밤. 조명이 켜질 무렵 시작해 밤 색조에서 가장 크다
		Insects = { id = 9112764573, volume = 0.25, bySun = { { -0.06, 1 }, { 0.1, 0 } }, sway = 0.1 },
	},
	zones = { passage },
}

return config
