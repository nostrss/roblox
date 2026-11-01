--!strict
-- 화면 문장 다국어 표. 키 → { ko, en }. 영어는 번역이 아니라 외국인 답사객이 읽기 자연스러운 말로 쓴다.
-- 클라이언트에서 부른다 (언어 = 방문자 로블록스 언어, 한국어가 아니면 영어).
-- ponytail: core 공통 문장만 담는 최소 표. 장소 해설·LocalizationTable 연동은 다국어 작업(28번)이 이 키를 이어받는다
local Players = game:GetService("Players")

local strings: { [string]: { ko: string, en: string } } = {
	["time.now"] = { ko = "지금", en = "Now" },
	["time.sunset"] = { ko = "노을", en = "Sunset" },
	["time.night"] = { ko = "밤", en = "Night" },
	["roofSplit.split"] = { ko = "분해해 보기", en = "Take it apart" },
	["roofSplit.join"] = { ko = "조립하기", en = "Put it back together" },
	["launcher.name"] = { ko = "화차", en = "Hwacha rocket cart" },
	["launcher.fire"] = { ko = "지붕으로 날아가기", en = "Fly up to the roof" },
}

local player = Players.LocalPlayer
local lang = if player and string.sub(player.LocaleId, 1, 2) == "ko" then "ko" else "en"

return function(key: string): string
	local s = strings[key]
	assert(s, `다국어 표에 없는 키: {key}`)
	return s[lang]
end
