--!strict
-- 축부(기둥·창방·평방·보·도리) 단면과 길이. 단위 m, 출처 S4 부재 도면 B30 표·치수선 (SOURCES.md).
-- 위치는 Dimensions(주칸·레벨)에서 정한다. 원형 기둥 지름은 하단/상단 평균(민흘림은 생략).

return {
	column = {
		lowerDia = 0.561, -- S4 073 하층평주 하단 ~565 / 상단 ~556 (074 우주 같음)
		highDia = 0.568, highLength = 8.950, -- S4 075 고주 하단 ~585 / 상단 ~550, 길이 8,950
		cornerHighDia = 0.540, cornerHighLength = 6.077, -- S4 077 귀고주 하단 ~552 / 상단 ~528, 길이 6,077
		upperDia = 0.524, upperLength = 2.988, -- S4 078 상층평주 하단 524, 길이 2,988 (하층 대보·충량 위에 선다)
	},
	lowerChangbang = { width = 0.354, height = 0.477 }, -- S4 079 하평주창방. 윗면 = 기둥 상
	upperChangbang = { width = 0.323, height = 0.431 }, -- S4 081 상평주창방
	pyeongbang = { width = 0.385, height = 0.277 }, -- S4 088·090 하층·상층평방
	lowerBeam = { width = 0.462, height = 0.524, length = 5.160, base = 0.625 }, -- S4 092 하층대보·093 충량. 밑면 = 주두 밑 + 삼제공 자리(Gongpo)
	lowerOuterDori = { dia = 0.400, outset = 0.740 }, -- S4 099 하층외목도리 (외2출목). 윗면 레벨은 Dimensions
	lowerOuterJangyeo = { width = 0.108, height = 0.154 }, -- S4 113 하외목도리장여. 외목도리 바로 밑
	upperBeam = { width = 0.401, height = 0.462, length = 4.790, base = 0.820 }, -- S4 094 상층대보 (095 충량 462×462). 밑면 = 상층 주두 밑 + 사제공 자리
	upperOuterDori = { dia = 0.400, outset = 1.110 }, -- S4 102 상층외목도리 (외3출목)
	upperOuterJangyeo = { width = 0.108, height = 0.154 }, -- 하층 장여와 같은 단면으로 둔다 (S4 116 미확인)
	lowerInnerDori = { dia = 0.384, inset = 0.740, top = 4.883 }, -- S4 101 하층내목도리 지름, 윗면 S4 021 1F_INSIDE_DORI_UPPER +13.021 − 8.138
}
