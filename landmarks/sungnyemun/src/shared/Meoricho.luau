--!strict
-- 단청 머리초 (작업 표 25-②). 부재를 기둥 자리에서 [머리초 | 계풍 | 머리초] Part로 나누고 머리초에 투명 PNG Decal을 붙인다 (ADR 0009).
-- 그림: textures/meoricho/*.png (tools/meoricho_png.mjs가 SVG에서 굽는다). S7 pp.451~457 본문 서술을 따라 다시 그렸다 (SOURCES.md S7).
-- 뇌록 바탕 자리는 투명이라 Part 색(Palette 가칠)이 비친다 → 가칠 색을 바꿔도 다시 올리지 않는다.
-- a = 기둥이 왼쪽인 그림, b = 거울상(Decal은 뒤집을 수 없어 따로 올림). gyepung = 계풍 위아래 색긋기 줄(길이로 늘여도 같음).
-- ID가 비어 있으면 Decal 없이 부재만 나눈다. 1단계 범위: 하층 바깥 창방·평방·외목도리 (상층·메시 부재는 아직)
export type Motif = { height: number, a: string, b: string, gyepung: string }

return {
	-- 머리초 길이 (부재 면 높이 = 그림 높이일 때). 추정: S7 도판 비례를 눈으로 본 값 (시안), 수치 근거 없음.
	-- 면 높이가 다른 부재는 길이를 높이에 비례시켜 그림이 늘어나지 않게 한다 (도리 지름 0.400 → 0.922 m)
	length = 1.1,
	motifs = {
		-- 병머리초: 창방·도리 (S7 pp.452~453). 그림 1100×477 mm = 창방 높이
		byeong = {
			height = 0.477,
			a = "rbxassetid://98086634359626", -- byeong_a.png (2026-11-01 업로드)
			b = "rbxassetid://85806115364504", -- byeong_b.png
			gyepung = "rbxassetid://92038645381647", -- byeong_gyepung.png
		} :: Motif,
		-- 주화병머리초: 평방 (S7 p.453, 주화는 본문대로 녹). 그림 1100×277 mm = 평방 높이
		juhwa = {
			height = 0.277,
			a = "rbxassetid://71882638070006", -- juhwa_a.png
			b = "rbxassetid://89895594945266", -- juhwa_b.png
			gyepung = "rbxassetid://93395055333485", -- juhwa_gyepung.png
		} :: Motif,
	},
}
