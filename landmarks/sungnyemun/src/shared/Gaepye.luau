--!strict
-- 숭례문 개폐의식 회차 데이터 (core Ceremony가 재생한다). 근거 refs/pasu-notes.md, 기획 refs/pasu-plan.html "게임 회차".
-- 흐름은 "인정에 닫고 파루에 연다"(pasu-notes §6, 도성문 제도). 실제 행사는 10:00 개문, 15:30 폐문이고 여기서는 압축했다 (자막으로 안내).
-- 시간은 모두 제안값. 기획 시간표는 괄호 값이고, 파수군이 없는 1단계라 지루한 구간을 줄였다. 파수군이 들어오면 괄호 값으로 되돌린다.
-- 해설 문장은 직접 썼다. 인물이 없으니 호군·군사의 동작이 눈앞에 있는 것처럼 쓰지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ceremony = require(ReplicatedStorage.Core.Ceremony)
local I18n = require(ReplicatedStorage.Core.I18n)

I18n.add({
	["gaepye.start"] = { ko = "개폐의식 시작", en = "Watch the gate ceremony" },
	["gaepye.busy"] = { ko = "개폐의식 진행 중", en = "Ceremony in progress" },
	["gaepye.injeong"] = {
		ko = "인정 신호예요. 조선의 도성문은 밤에 인정이 울리면 닫혔어요.",
		en = "The night signal, injeong. In Joseon times, this was when Seoul's city gates shut.",
	},
	["gaepye.check"] = {
		ko = "실제 행사에서는 문을 닫기 전에 표신과 부험을 확인해요.",
		en = "At the real ceremony, officers check two tokens, the pyosin and buheom, before the gate moves.",
	},
	["gaepye.close"] = {
		ko = "판문이 닫혀요. 통로 안에 있다면 북쪽으로 나갈 수 있어요.",
		en = "The doors swing shut. Caught in the passage? You can still walk out the north side.",
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
		ko = "실제 행사에서는 문을 열기 전에도 표신과 부험을 확인해요.",
		en = "At the real ceremony, the tokens are checked again before opening.",
	},
	["gaepye.open"] = {
		ko = "판문이 열려요. 곧 통로로 다시 지나갈 수 있어요.",
		en = "The doors swing open, and the road through the gate is back.",
	},
	["gaepye.end"] = {
		ko = "개폐의식을 마쳤어요.",
		en = "That's the end of the gate ceremony.",
	},
})

-- 신호음: 구간 시작부터 잰 초. 나각·나발은 공식, 징과 폐문 때 북은 보도 (pasu-notes §5). 간격은 제안값
local NIGHT_SIGNAL = { { at = 0, sound = "jing" }, { at = 3, sound = "nagak" }, { at = 7, sound = "nabal" } }

local config: Ceremony.Config = {
	phases = {
		{ len = 12, caption = "gaepye.injeong", signals = NIGHT_SIGNAL }, -- 인정 신호 (15)
		{ len = 10, caption = "gaepye.check" }, -- 표신·부험 확인 (30)
		{ -- 폐문 (20)
			len = 16,
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
		{ len = 20, caption = "gaepye.hold", signals = { { at = 0, sound = "doorShut" } } }, -- 닫힌 채 정지 (25). 문이 완전히 닫히는 순간 = 이 구간 시작
		{ len = 12, caption = "gaepye.paru", signals = NIGHT_SIGNAL }, -- 파루 신호 (15)
		{ len = 8, caption = "gaepye.recheck" }, -- 재확인 (20)
		{ len = 16, caption = "gaepye.open", gate = "open", signals = { { at = 0, sound = "door" }, { at = 6.9, sound = "door" } } }, -- 개문 (20). 개문 때 북은 근거 없음
		{ len = 8, caption = "gaepye.end" }, -- 예필 (15)
	},
	-- 에셋 ID를 넣는 자리. id 0 = 조용히 건너뛴다
	sounds = {
		nagak = { id = 72606801022810, volume = 0.5 }, -- refs/pasu/sound/Nagak_1.wav (2026-11-01 사용자 업로드) S29
		nabal = { id = 97604800311484, volume = 0.5 }, -- refs/pasu/sound/Nabal_1.wav (2026-11-01 사용자 업로드) S30
		jing = { id = 105025809103848, volume = 0.5 }, -- refs/pasu/sound/Jing_1.wav 강 (2026-11-01 사용자 업로드) S31. 대안: Jing_2 96900612545655
		yonggoA = { id = 105984165957935, volume = 0.5 }, -- refs/pasu/sound/Yonggo_1.wav (2026-11-01 사용자 업로드) S32
		yonggoB = { id = 77610549643743, volume = 0.5 }, -- refs/pasu/sound/Yonggo_2.wav (2026-11-01 사용자 업로드) S33
		door = { id = 95190972742619, volume = 0.5 }, -- 판문이 움직이기 시작할 때 (폐문·개문). "Metal Gate Open" (S35)
		doorShut = { id = 5930776732, volume = 0.5 }, -- 완전히 닫힐 때 (개문 때는 없음). "doormetalgateclose1" (S36)
	},
	volume = 0.8,
	-- 근사: 한 짝 끝이 벽 쪽으로 물러나 사람(폭 0.68 m)이 지나갈 틈이 생기는 각이 약 30° = 닫힘 0.67. 그보다 조금 일찍 막는다
	blockFrom = 0.6,
	button = "gaepye.start",
	buttonBusy = "gaepye.busy",
}

return config
