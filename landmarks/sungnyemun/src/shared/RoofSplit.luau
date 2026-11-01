--!strict
-- 숭례문 지붕 분해 데이터 (core RoofSplit이 움직인다). 겹 순서는 위 겹 → 아래 겹, 부재 이름 = 생성기의 Part.Name.
-- 층(SplitStory)은 생성기가 정한다. 고주·귀고주는 상층 기둥으로 센다: 하층 바닥에서 상층 기둥 위까지 이어지는 기둥이라
-- 하층에 두면 하층 기둥 겹 높이 범위가 상층까지 늘어나 하층 겹이 모두 그만큼 더 뜬다.
-- 상층 벽(인방·문선·판창, Munru)과 현판(Hyeonpan)은 생성기가 상층 기둥 겹으로 붙인다 (이름이 하층 하인방과 겹쳐 아래 목록에 없음).
-- 문루 마루·계단·하층 하인방(Munru), 조명(Jomyeong), 육축은 겹에 넣지 않는다 (움직이지 않음).
-- 표식 자리는 Shared.Plaza.roofSplitMarker.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoofSplit = require(ReplicatedStorage.Core.RoofSplit)

local config: RoofSplit.Config = {
	layers = {
		{ key = "giwa", members = { -- 기와면·마루·잡상
			"LowerJibungFront", "LowerJibungSide", "UpperJibungFront", "UpperJibungSide",
			"Maru", "MaruCap", "Yeonmaru", "Sumaksae", "Ammaksae", "Japsang", "Yongdu", "Chwidu", "Tosu",
		} },
		{ key = "gaepan", members = { "Gaepan", "BuyeonGaepan" } }, -- 개판
		{ key = "yeon", members = { -- 서까래·부연·추녀·사래·초매기·이매기·갈모산방
			"Jangyeon", "Danyeon", "Seonjayeon", "Buyeon", "SeonjaBuyeon", "Chunyeo", "UpperChunyeo", "Sarae", "Chomaegi", "Imaegi", "Galmo",
		} },
		{ key = "dori", members = { -- 도리·장여
			"LowerOuterDori", "LowerOuterJangyeo", "LowerInnerDori", "UpperOuterDori", "UpperOuterJangyeo", "UpperInnerDori", "Jungdori", "Jongdori",
		} },
		{ key = "gongpo", members = { "Sungakpan" } }, -- 공포·순각판 (공포는 Gongpo가 층 Model째로 이 겹에 넣는다)
		{ key = "bang", members = { -- 창방·평방·보
			"LowerChangbang", "UpperChangbang", "Pyeongbang", "Daebo", "Chungryang", "UpperDaebo", "UpperChungryang",
		} },
		{ key = "gidung", members = { "Pyeongju", "Uju", "Goju", "GwiGoju", "UpperPyeongju" } }, -- 기둥
	},
	gap = 0.6, -- 근사: 겹 사이 틈. 사람 키의 1/3쯤 벌려 겹이 따로 보이게
	leaveDistance = 60, -- 근사: 표식에서 60 m 멀어지면 조립 (표식이 문루 앞 약 40 m라 광장 끝·도로 쪽으로 나가면 돌아온다)
	contactEpsilon = 0.02, -- 이웃 겹 사이 틈이 2 cm를 넘으면 "떨어짐", 그 아래로 오면 "닿음" (소리 시점)
	leadMs = 0, -- 소리를 접촉 순간보다 먼저 낼 시간(ms). 귀로 늦게 들리면 올린다
	timeScale = 1, -- 움직임 빠르기. 0.25로 두면 4배 느리게 움직여 소리와 틈이 맞는지 귀로 확인할 수 있다
	-- 음원을 바꿀 때는 여기만: id, 음량, 재생 속도, offset(음원 앞 무음을 건너뛸 초)
	sounds = {
		split = { id = 9120917813, volume = 0.25, offset = 0 }, -- 분해 "톡": 나무 목탁 블록 가벼운 타격 (S21). 앞 무음 10 ms 안쪽이라 0
		join = { id = 9125654847, volume = 0.3, speed = 0.9, offset = 0 }, -- 조립 "딱": 나무판 낮은 타격, 조금 낮게 (S22). 앞 무음 20 ms 안쪽이라 0
	},
}

return config
