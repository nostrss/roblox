--!strict
-- 숭례문 개폐의식 회차 데이터 (core Ceremony가 재생한다). 근거 refs/pasu-notes.md, 기획 refs/pasu-plan.html "게임 회차".
-- 흐름은 "인정에 닫고 파루에 연다"(pasu-notes §6, 도성문 제도). 실제 행사는 10:00 개문, 15:30 폐문이고 여기서는 압축했다 (자막으로 안내).
-- 시간은 모두 제안값. 기획 시간표는 괄호 값이다. 인물 동작이 들어가도록 잡았고 인물 시간표(Pasugun)가 이 값을 따라간다.
-- 해설 문장은 직접 썼다. 역할명이 추정인 인물(금루관·선전관 등)은 자막에서 이름으로 단정하지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ceremony = require(ReplicatedStorage.Core.Ceremony)
local I18n = require(ReplicatedStorage.Core.I18n)
local Pasugun = require(script.Parent.Pasugun)

I18n.add({
	["gaepye.start"] = { ko = "개폐의식 시작", en = "Watch the gate ceremony" },
	["gaepye.busy"] = { ko = "개폐의식 진행 중", en = "Ceremony in progress" },
	["gaepye.enter"] = {
		ko = "호군과 파수군이 행진해 나와 남측면 앞에 늘어서요.",
		en = "The commander and the gate guards march out and line up along the south wall.",
	},
	["gaepye.injeong"] = {
		ko = "인정 신호예요. 조선의 도성문은 밤에 인정이 울리면 닫혔어요.",
		en = "The night signal, injeong. In Joseon times, this was when Seoul's city gates shut.",
	},
	["gaepye.check"] = {
		ko = "문을 닫기 전에 표신과 부험을 확인해요. 앞마당에서 마주 선 사람들을 보세요.",
		en = "Before the gate moves, two tokens are checked: the pyosin and the buheom. Watch the pair facing each other in the yard.",
	},
	["gaepye.close"] = {
		ko = "호군의 명령에 파수군이 문 안쪽에서 판문을 닫아요. 통로 안에 있다면 북쪽으로 나갈 수 있어요.",
		en = "On the commander's word, guards behind the doors swing them shut. Inside the passage? You can still walk out the north side.",
	},
	["gaepye.hold"] = {
		ko = "실제 행사는 오전 10시에 열고 오후 3시 30분에 닫아요. 여기서는 하룻밤을 몇 분으로 줄였어요.",
		en = "At the real ceremony, the doors open at 10:00 and close at 15:30. Here, a whole night is squeezed into a couple of minutes.",
	},
	["gaepye.paru"] = {
		ko = "파루 신호예요. 도성문은 새벽 파루에 다시 열렸어요.",
		en = "The dawn signal, paru. This was when the city gates opened again.",
	},
	["gaepye.recheck"] = {
		ko = "문을 열기 전에도 표신과 부험을 다시 확인해요.",
		en = "The tokens are checked once more before the gate opens.",
	},
	["gaepye.open"] = {
		ko = "호군의 명령에 판문이 열려요. 곧 통로로 다시 지나갈 수 있어요.",
		en = "On the commander's word, the doors swing open, and the road through the gate is back.",
	},
	["gaepye.end"] = {
		ko = "모두 제자리로 돌아와 개폐의식을 마쳐요.",
		en = "Everyone returns to the line, and the gate ceremony is complete.",
	},
	["gaepye.exit"] = {
		ko = "대열이 물러나고 호군과 파수군 셋이 문 앞에 남아 근무해요.",
		en = "The line marches off, leaving the commander and three guards on watch at the gate.",
	},
})

-- 신호음: 구간 시작부터 잰 초. 나각·나발은 공식, 징과 폐문 때 북은 보도 (pasu-notes §5). 간격은 제안값
local NIGHT_SIGNAL = { { at = 0, sound = "jing" }, { at = 3, sound = "nagak" }, { at = 7, sound = "nabal" } }

-- 구간 길이(초). 괄호는 기획 시간표. 인물 이동 시간에 맞췄다
local LEN = {
	enter = 25, -- 입취위 (25)
	injeong = 12, -- 인정 신호 (15)
	check = 22, -- 표신·부험 확인 (30)
	close = 16, -- 폐문 (20)
	hold = 20, -- 닫힌 채 정지 (25)
	paru = 12, -- 파루 신호 (15)
	recheck = 14, -- 재확인 (20)
	open = 16, -- 개문 (20)
	finish = 10, -- 예필 (15)
	exit = 25, -- 퇴장 (25)
}
local ORDER = { "enter", "injeong", "check", "close", "hold", "paru", "recheck", "open", "finish", "exit" }
local T: { [string]: number } = {}
do
	local t = 0
	for _, name in ORDER do
		T[name] = t
		t += (LEN :: any)[name]
	end
end

local config: Ceremony.Config = {
	phases = {
		{ len = LEN.enter, caption = "gaepye.enter" },
		{ len = LEN.injeong, caption = "gaepye.injeong", signals = NIGHT_SIGNAL },
		{ len = LEN.check, caption = "gaepye.check" },
		{
			len = LEN.close,
			caption = "gaepye.close",
			gate = "close",
			signals = {
				{ at = 0, sound = "door" },
				{ at = 6.9, sound = "door" }, -- 음원 6.94초 끝에 잇는다. 약 13.9초에 끝나고 doorShut까지 약 2초 무음
				{ at = 1, sound = "yonggoA" },
				{ at = 4, sound = "yonggoB" },
				{ at = 7, sound = "yonggoA" },
				{ at = 10, sound = "yonggoB" },
			},
		},
		{ len = LEN.hold, caption = "gaepye.hold", signals = { { at = 0, sound = "doorShut" } } }, -- 문이 완전히 닫히는 순간 = 이 구간 시작
		{ len = LEN.paru, caption = "gaepye.paru", signals = NIGHT_SIGNAL },
		{ len = LEN.recheck, caption = "gaepye.recheck" },
		{ len = LEN.open, caption = "gaepye.open", gate = "open", signals = { { at = 0, sound = "door" }, { at = 6.9, sound = "door" } } }, -- 개문 때 북은 근거 없음
		{ len = LEN.finish, caption = "gaepye.end" },
		{ len = LEN.exit, caption = "gaepye.exit" },
	},
	-- 에셋 ID를 넣는 자리. id 0 = 조용히 건너뛴다
	sounds = {
		nagak = { id = 72606801022810, volume = 0.5 }, -- refs/pasu/sound/Nagak_1.wav (2026-11-01 사용자 업로드) S29
		nabal = { id = 97604800311484, volume = 0.5 }, -- refs/pasu/sound/Nabal_1.wav (2026-11-01 사용자 업로드) S30
		jing = { id = 105025809103848, volume = 0.5 }, -- refs/pasu/sound/Jing_1.wav 강 (2026-11-01 사용자 업로드) S31. 대안: Jing_2 96900612545655
		yonggoA = { id = 105984165957935, volume = 0.5 }, -- refs/pasu/sound/Yonggo_1.wav (2026-11-01 사용자 업로드) S32
		yonggoB = { id = 77610549643743, volume = 0.5 }, -- refs/pasu/sound/Yonggo_2.wav (2026-11-01 사용자 업로드) S33
		door = { id = 95190972742619, volume = 0.5 }, -- 판문이 움직이기 시작할 때 (폐문·개문). "Metal Gate Open" (S35)
		-- 파수군 발소리 (S42). 음원 자체가 작다: PlaybackLoudness 평균 4.7·최고 47 (문 소리 46·107, 나각 280·362).
		-- 근사: 최고치가 문 소리와 비슷하고 평균은 그 아래가 되는 크기 (문 소리 Play 측정 기준, 사용자가 들어 보고 다듬는다)
		footstep = { id = 120362768144536, volume = 1.5 },
		doorShut = { id = 5930776732, volume = 0.5 }, -- 완전히 닫힐 때 (개문 때는 없음). "doormetalgateclose1" (S36)
	},
	volume = 0.8,
	-- 근사: 한 짝 끝이 벽 쪽으로 물러나 사람(폭 0.68 m)이 지나갈 틈이 생기는 각이 약 30° = 닫힘 0.67. 그보다 조금 일찍 막는다
	blockFrom = 0.6,
	button = "gaepye.start",
	buttonBusy = "gaepye.busy",
	figures = Pasugun(T, LEN :: any),
	footsteps = { sound = "footstep", rolloff = { 30, 150 } }, -- 근사: 거리(m). 시작 위치(문에서 약 60 m)에서도 들리게 넓혔다
}

return config
