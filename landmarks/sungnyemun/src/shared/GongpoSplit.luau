--!strict
-- 숭례문 공포 모형 분해 데이터 (core Split이 움직인다). 문루 하층 마루 위 전시대에 하층 주간포 한 벌을 실측 크기로 올리고
-- (서버 Gongpo가 같은 생성기로 짓는다), 전시대(분해 표식)를 누르면 아래 겹부터 위로 벌어진다.
-- 겹은 부재 밑면 높이로 자동으로 나눈다. 제공은 쇠서 끝 처짐 대신 주심(u = 0) 자리 아랫변을 밑면으로 본다.
-- 소리·접촉 기준·빠르기는 지붕 분해(Shared.RoofSplit)와 같은 값을 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Split = require(ReplicatedStorage.Core.Split)
local Units = require(ReplicatedStorage.Core.Units)
local G = require(script.Parent.Gongpo)
local Roof = require(script.Parent.RoofSplit)

local M = {
	-- 전시대: 건물 축 좌표(m, 정면 +Z). 하층 서협칸 북쪽 반 칸 가운데 = 동협칸 북쪽 문루 계단의 맞은편 자리.
	-- 어칸(통로)과 남쪽 반 칸을 비우고, 북쪽 둘레(z −3.848)와 고주 줄(z 0)에서 각각 1.27 m 떨어진다.
	-- 모형 바깥(쇠서 쪽)은 어칸 쪽(동, +X): 어칸에서 다가오면 쇠서 끝이, 남쪽 반 칸으로 돌면 제공 옆모습이 보인다
	exhibit = {
		x = -5.464, -- 서협칸 가운데 (기둥 −7.388 ~ −3.540)
		z = -1.924, -- 북쪽 반 칸 가운데 (−3.848 ~ 0)
		outward = Vector3.xAxis,
		size = { 2.4, 0.7, 1.3 }, -- 근사: 길이(X, 출목 방향) · 높이 · 너비(Z). 모형(출목 방향 약 2.1 m, 벽 방향 약 1.1 m)보다 조금 크게, 윗면이 허리 높이
		-- 전시 조명: 문루 안이 어두워 모형만 비춘다. 기구는 보이지 않는다(전시대 Attachment의 SpotLight, 문루 고증에 부재를 더하지 않음).
		-- 낮밤과 상관없이 늘 켜진다(NightLight 태그 없음). Studio에서 맞출 때는 이 값들만 바꾼다
		light = {
			from = { 1.2, 3.4, 1.8 }, -- 기구 자리 (m, 전시대 윗면 가운데 기준, 건물 축). 동남쪽 위 = 어칸·남쪽 반 칸에서 보이는 면을 비춤
			at = 1.2, -- 겨누는 높이 (m, 전시대 윗면 위). 다 벌어진 모형(약 2.1 m) 가운데쯤
			angle = 70, -- 빛 원뿔 각(°). 기구에서 약 3 m 거리에 지름 약 4 m = 다 벌어진 모형 전체
			range = 6, -- 닿는 거리 (m). 아래 마루까지는 약하게만 닿는다
			brightness = 4,
			color = Color3.fromRGB(255, 226, 190), -- 따뜻한 흰색 (약 3,500 K)
		},
	},
	settings = {
		gap = 0.2, -- 근사: 겹 사이 틈. 모형 키 0.9 m라 지붕(0.6)보다 작게, 다 벌어지면 꼭대기가 마루 위 약 2.8 m
		tolerance = 0.02, -- 밑면이 2 cm 안이면 같은 겹
		leaveDistance = 15, -- 근사: 전시대에서 15 m 멀어지면 조립 (문루 하층을 벗어나면)
		sounds = Roof.sounds,
		contactEpsilon = Roof.contactEpsilon,
		leadMs = Roof.leadMs,
		timeScale = Roof.timeScale,
	},
}

-- 프로파일 아랫변이 u = 0을 지나는 높이
local function centerBottom(profile: { { number } }): number
	local m = math.huge
	for i, a in profile do
		local b = profile[i % #profile + 1]
		if (a[1] <= 0) ~= (b[1] <= 0) then
			m = math.min(m, a[2] + (b[2] - a[2]) * (0 - a[1]) / (b[1] - a[1]))
		end
	end
	return m
end

-- 클라이언트: 전시대 위 부재를 밑면 높이(m, 전시대 윗면 기준)로 겹을 나눈다
function M.collect(marker: BasePart): Split.Plan
	local S = Units.studs(1)
	local top = marker.CFrame * CFrame.new(0, marker.Size.Y / 2, 0)
	local items = {}
	for _, p in (marker.Parent :: Instance):GetDescendants() do
		if p:IsA("BasePart") and p ~= marker then
			local bottom = (top:ToObjectSpace(p.CFrame).Y - p.Size.Y / 2) / S
			local profile = G.jegong[p.Name]
			if profile then -- 메시 상자 밑 = 프로파일 최저점(쇠서 끝) → 주심 자리 아랫변으로
				local v0 = math.huge
				for _, q in profile do
					v0 = math.min(v0, q[2])
				end
				bottom += centerBottom(profile) - v0
			end
			table.insert(items, { part = p, bottom = bottom })
		end
	end
	return Split.byBottom(items, M.settings.tolerance, M.settings.gap * S)
end

return M
