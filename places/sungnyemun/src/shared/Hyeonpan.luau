--!strict
-- 현판 "崇禮門". 단위 m, 출처 ID는 SOURCES.md. 판·테두리는 블록, 글씨는 흰 글씨 PNG(textures/hyeonpan_glyphs.png)를 판면에 Decal로.
-- 크기: 가로 1.89(위 선대 끝~끝)·세로 2.82·깊이 0.256(테두리 포함 전체로 봄) — 사용자 제공(2026-11-01).
-- 부분 비율: S9 사진판독(가로 189 cm = 1708 px, 세로 282 cm = 2297 px). refs/hyeonpan-notes.md 1절.
return {
	width = 1.89, height = 2.82, depth = 0.256,
	-- 아래에서 위로: 다리 0.215 → 아래 띠 0.258 → 판면 2.21 → 위 띠(선대) 0.137
	legs = 0.215, bottomBand = 0.258, panelHeight = 2.21, topBand = 0.137,
	body = 1.15, -- 테두리 몸체 바깥 폭 (S9 1035 px)
	panelWidth = 0.75, -- 검은 판면 폭 (S9 677 px). 글씨 PNG 814×2400 과 같은 비율
	panelRecess = 0.10, -- 판면이 테두리 앞면보다 들어간 깊이. 단면 자료 없음(근사)
	line = 0.025, -- 테두리 색대(황·장단) 폭. 근사
	leg = { width = 0.10, inset = 0.10 }, -- 다리 2개, 몸체 가장자리에서 안쪽으로. 근사
	-- 걸기: 위 선대 뒷면 기준점. 상층 남쪽 어칸 가운데, 상층 공포(제공 끝 z 4.61) 바로 앞, 장연 밑 (Play에서 잰 값에 맞춤)
	hang = { top = 8.45, back = 4.76 },
	-- 윗부분을 앞으로 숙인다: 걸쇠 위 1,150·아래 760 (S7 p.567 [표 6-14]) 차이를 현판 높이로 나눈 각
	-- ponytail: 걸쇠 박은 자리가 없어 각을 이 차이로만 잡음 (≈ 7.9°)
	tiltDeg = math.deg(math.atan((1.150 - 0.760) / 2.82)),
	colors = { -- S9 사진판독 (refs/hyeonpan-notes.md 4절), 문양 구성은 S7 p.455
		panel = Color3.fromHex("#292726"),
		green = Color3.fromHex("#457455"), -- 테두리 바탕 (녹)
		yellow = Color3.fromHex("#CEAB57"), -- 판면 둘레 색대 (황)
		jangdan = Color3.fromHex("#854529"), -- 바깥 가장자리 색대 (장단)
		samcheong = Color3.fromHex("#45647F"), -- 선대 끝 (삼청)
	},
	-- 글씨 텍스처 에셋. 비어 있으면 글씨 없이 판만 놓는다 (textures/hyeonpan_glyphs.png 를 Studio에서 올린 뒤 ID를 적는다)
	glyphs = "rbxassetid://137258514659455", -- textures/hyeonpan_glyphs.png (2026-11-01 업로드)
}
