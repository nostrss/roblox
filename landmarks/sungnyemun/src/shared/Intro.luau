--!strict
-- 숭례문 입장 안내 문구 (core Intro가 띄운다). 사실 대조: SOURCES.md S7.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local I18n = require(ReplicatedStorage.Core.I18n)
local Intro = require(ReplicatedStorage.Core.Intro)

I18n.add({
	["intro.eyebrow"] = { ko = "랜드마크 시리즈 · 서울", en = "Landmark Series · Seoul" },
	["intro.title"] = { ko = "숭례문", en = "Sungnyemun" },
	["intro.intro"] = {
		ko = "서울을 둘러싼 성곽의 남쪽 정문이에요. 1398년에 세워졌고, 2008년 화재로 크게 불탄 뒤 2013년에 복구했어요. 이곳은 복구된 모습을 실측 도면에 맞춰 실제 비율로 다시 지은 공간이에요.",
		en = "The main south gate of old Seoul's city wall, completed in 1398. A fire badly damaged it in 2008, and it was restored by 2013. This true-to-scale rebuild follows the survey drawings of the restored gate.",
	},
	["intro.walk.title"] = { ko = "걸어서 둘러보기", en = "Walk through it" },
	["intro.walk.desc"] = {
		ko = "홍예 문길을 지나 돌계단으로 올라가면 문루 안까지 들어갈 수 있어요.",
		en = "Pass through the arched gateway and climb the stone stairs into the pavilion.",
	},
	["intro.split.title"] = { ko = "분해해 보기", en = "Take it apart" },
	["intro.split.desc"] = {
		ko = "광장의 낮은 돌이나 문루 안 전시대를 누르면 짜임이 벌어져요.",
		en = "Press the low stone in the plaza or the stand inside to see how it fits together.",
	},
	["intro.hwacha.title"] = { ko = "화차 타고 지붕으로", en = "Ride the hwacha" },
	["intro.hwacha.desc"] = {
		ko = "시작 위치 옆 화차를 누르세요. 실제 숭례문에서는 못 하는 놀이예요.",
		en = "Press the rocket cart by the start to fly onto the roof. Don't try this at the real gate!",
	},
	["intro.time.title"] = { ko = "시간대 바꾸기", en = "Change the time of day" },
	["intro.time.desc"] = {
		ko = "기본은 지금 서울 시각이에요. 노을이나 밤으로 바꿔 볼 수 있어요.",
		en = "It follows the current time in Seoul. Switch to sunset or night any time.",
	},
	["intro.source"] = {
		ko = "자료: 국가유산청 (공공누리 제1유형) · © OpenStreetMap contributors",
		en = "Sources: Korea Heritage Service (KOGL Type 1) · © OpenStreetMap contributors",
	},
})

local place: Intro.Place = {
	eyebrow = "intro.eyebrow",
	title = "intro.title",
	intro = "intro.intro",
	items = {
		{ title = "intro.walk.title", desc = "intro.walk.desc" },
		{ title = "intro.split.title", desc = "intro.split.desc" },
		{ title = "intro.hwacha.title", desc = "intro.hwacha.desc" },
		{ title = "intro.time.title", desc = "intro.time.desc" },
	},
	source = "intro.source",
}
return place
