--!strict
-- 부재 종류 → (재질, 색) 한 표. 부재를 만드는 곳은 Member setup(서버)으로 이 표를 읽는다.
-- 나무는 2013 복구 때 의도한 가칠 색(ADR 0003). 문양은 아직 없다 — 단청(25번)은 이 표의 색을 바꾸거나 부재 항목을 더한다.
-- 색 근거: S7 수리보고서 4장 3절(정리 refs/dancheong-notes.md, 거기서는 D1). 도판 값을 동유칠 뒤 사진(S11, 어둡고 채도 낮음) 쪽으로 낮췄다.
-- 사진 텍스처는 쓰지 않는다. 기본 재질로 어색한 것은 보고에 "사진 필요"로 남긴다.

export type Paint = { material: Enum.Material, color: Color3 }

-- 단청 칠은 결이 보이지 않는 무광 면 → 나무 결 무늬가 드러나는 Wood 대신 Plastic
local PAINTED = Enum.Material.Plastic

local paint: { [string]: Paint } = {
	noerok = { material = PAINTED, color = Color3.fromHex("#34645A") }, -- 뇌록: 목부 일반 가칠 (S7 p.460, 표 4-26 p.421)
	seokganju = { material = PAINTED, color = Color3.fromHex("#7A2C20") }, -- 석간주: 기둥·판벽 (S7 p.421·456, S11 ≈ #80291D)
	yeonbaek = { material = PAINTED, color = Color3.fromHex("#E6E1D3") }, -- 연백: 연목개판 백색 가칠 (S7 p.451)
	giwa = { material = Enum.Material.Slate, color = Color3.fromRGB(72, 74, 78) }, -- 기와 회흑
	yangseong = { material = Enum.Material.Plaster, color = Color3.fromRGB(226, 222, 210) }, -- 양성바름 회백
	wajae = { material = Enum.Material.Slate, color = Color3.fromRGB(88, 88, 90) }, -- 잡상·취두·용두·토수 암회색 (S3 p.408)
	seokchuk = { material = Enum.Material.Granite, color = Color3.fromRGB(176, 172, 165) }, -- 육축 몸 (포천석 담회색, S7 p.469)
	myeonseok = { material = Enum.Material.Granite, color = Color3.fromRGB(196, 190, 182) }, -- 육축 면석 (돌마다 Greybox가 명도를 흔든다)
	jeondol = { material = Enum.Material.Concrete, color = Color3.fromRGB(118, 118, 115) }, -- 여장 전돌 회색 (S7 p.200). Brick 재질은 무늬가 붉어 회색 전돌로 안 보임 → 사진 필요
	gidan = { material = Enum.Material.Granite, color = Color3.fromRGB(160, 156, 150) }, -- 문루 기단
}

-- 부재 이름(Part.Name) → 칠. 없는 이름은 뇌록 (S7: 목부 일반이 뇌록 주바탕)
local byName: { [string]: string } = {
	Pyeongju = "seokganju", Uju = "seokganju", Goju = "seokganju", GwiGoju = "seokganju", UpperPyeongju = "seokganju",
	UpperWall = "seokganju", -- 상층 판벽 덩어리 (Greybox)
	Gaepan = "yeonbaek",
	LowerJibungFront = "giwa", LowerJibungSide = "giwa", UpperJibungFront = "giwa", UpperJibungSide = "giwa",
	MaruCap = "giwa", Sumaksae = "giwa", Ammaksae = "giwa",
	Maru = "yangseong", Yeonmaru = "yangseong",
	Japsang = "wajae", Yongdu = "wajae", Chwidu = "wajae", Tosu = "wajae",
	WallSouthWest = "seokchuk", WallSouthEast = "seokchuk", WallSouthOverArch = "seokchuk",
	WallNorthWest = "seokchuk", WallNorthEast = "seokchuk", WallNorthOverArch = "seokchuk",
	Stone = "myeonseok",
	ParapetSouth = "jeondol", ParapetNorth = "jeondol", ParapetWest = "jeondol", ParapetEast = "jeondol",
	PavilionBase = "gidan",
}

local function of(name: string): Paint
	return paint[byName[name] or "noerok"]
end

return { paint = paint, byName = byName, of = of }
