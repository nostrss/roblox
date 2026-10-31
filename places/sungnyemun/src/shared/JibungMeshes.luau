--!strict
-- tools/jibung_obj.luau 로 생성. 손으로 고치지 말 것
-- 지붕 메시 경계 상자 (m, 레벨 기준). 앞면 = 남, 옆면 = 동. tris = 삼각형 수, gol = 처마 끝 기와골(수키와) 수
return {
	LowerJibungFront = { center = { 0.0128, 4.8350, 5.3988 }, size = { 29.6457, 1.5240, 4.0977 }, tris = 7096, gol = 77 },
	LowerJibungSide = { center = { 12.7811, 4.8350, 0.0000 }, size = { 4.0863, 1.5240, 14.7900 }, tris = 3248, gol = 39 },
	UpperJibungFront = { center = { 0.0000, 10.4345, 3.3935 }, size = { 28.2800, 3.3550, 6.7871 }, tris = 8142, gol = 79 },
	UpperJibungSide = { center = { 10.7845, 10.4351, 0.0000 }, size = { 6.7931, 3.3537, 13.5200 }, tris = 3218, gol = 37 },
}
