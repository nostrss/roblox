--!strict
-- 화면 문장 다국어 표. 키 → { ko, en }. 영어는 번역이 아니라 외국인 답사객이 읽기 자연스러운 말로 쓴다.
-- 클라이언트에서 부른다 (언어 = 방문자 로블록스 언어, 한국어가 아니면 영어).
-- 표에는 core 공통 문장이 들어 있고, Place 전용 문장은 Place 데이터가 add로 더한다 (core는 landmarks를 모른다).
-- ponytail: LocalizationTable 연동은 다국어 작업(28번)이 이 키를 이어받는다
local Players = game:GetService("Players")

export type Entries = { [string]: { ko: string, en: string } }

local strings: Entries = {
	["time.now"] = { ko = "지금", en = "Now" },
	["time.sunset"] = { ko = "노을", en = "Sunset" },
	["time.night"] = { ko = "밤", en = "Night" },
	["roofSplit.split"] = { ko = "분해해 보기", en = "Take it apart" },
	["roofSplit.join"] = { ko = "조립하기", en = "Put it back together" },
	["launcher.name"] = { ko = "화차", en = "Hwacha rocket cart" },
	["launcher.fire"] = { ko = "지붕으로 날아가기", en = "Fly up to the roof" },
	["intro.start"] = { ko = "둘러보기", en = "Start exploring" },
}

local player = Players.LocalPlayer
local lang = if player and string.sub(player.LocaleId, 1, 2) == "ko" then "ko" else "en"

local I18n = {}

function I18n.text(key: string): string
	local s = strings[key]
	assert(s, `다국어 표에 없는 키: {key}`)
	return (s :: any)[lang]
end

-- Place 전용 문장을 표에 더한다. 키가 겹치면 틀린 것이다
function I18n.add(entries: Entries)
	for key, s in entries do
		assert(not strings[key], `다국어 표에 이미 있는 키: {key}`)
		strings[key] = s
	end
end

return I18n
