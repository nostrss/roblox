--!strict
-- 주변 건물 입면 텍스처 (tools/facade_png.mjs로 만들어 2026-11-02 업로드). 사진이 아니라 생성한 그림이고, 특정 건물을 그대로 옮긴 것이 아니다.
-- 타일 하나 = tileU × tileV m. 낮 텍스처의 유리 칸은 반투명이라 파트 색·반사가 비친다.
-- lit = 밤 창 불빛: 켜진 창만 불투명한 그림. SurfaceGui로 얹어 스스로 빛난다.
local rgb = Color3.fromRGB

return {
	tileU = 24, -- 8칸 × 3 m
	tileV = 28, -- 8층 × 3.5 m
	styles = {
		glass = { day = 106019247986807, lit = 125647246952855, base = rgb(44, 66, 86), reflect = 0.32 },
		darkglass = { day = 73966642810741, lit = 136131792331946, base = rgb(20, 26, 32), reflect = 0.4 },
		stone = { day = 81434705405161, lit = 98741912159522, base = rgb(44, 54, 62), reflect = 0.14 },
		tile = { day = 86766677415843, lit = 99193554037627, base = rgb(40, 48, 54), reflect = 0.12 },
		concrete = { day = 78509542081759, lit = 81431806445855, base = rgb(40, 46, 50), reflect = 0.08 },
		market = { day = 113898169202189, lit = 97112050366211, base = rgb(40, 46, 50), reflect = 0.06 },
	},
	shop = { day = 137253024688145, lit = 106444670928221, base = rgb(50, 58, 64), reflect = 0.12, tileU = 24, height = 4.5 },
	bakseok = { texture = 129104232474739, tile = 4 }, -- 박석 바닥: 4 m × 4 m 타일 (server Plaza)
}
