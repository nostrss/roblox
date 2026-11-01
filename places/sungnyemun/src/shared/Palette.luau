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
	myeonseok = { material = Enum.Material.Granite, color = Color3.fromRGB(196, 190, 182) }, -- 육축 면석·홍예석·계단석 (돌마다 Yukchuk이 명도를 흔든다)
	panseok = { material = Enum.Material.Granite, color = Color3.fromRGB(170, 166, 158) }, -- 홍예 통로 바닥 판석
	soe = { material = Enum.Material.Metal, color = Color3.fromRGB(58, 54, 52) }, -- 성문 철엽 (S7 p.564 철엽·광두정)
	jeondol = { material = Enum.Material.Concrete, color = Color3.fromRGB(118, 118, 115) }, -- 여장 전돌 회색 (S7 p.200). Brick 재질은 무늬가 붉어 회색 전돌로 안 보임 → 사진 필요
	deulgireum = { material = Enum.Material.Wood, color = Color3.fromRGB(150, 112, 74) }, -- 들기름칠 소나무. 근사: 색 자료 없음
	gidan = { material = Enum.Material.Granite, color = Color3.fromRGB(160, 156, 150) }, -- 문루 기단
	-- 성곽: 신재 포천석 담회색에 약간 담홍색 (S7 p.469·497)
	seongdol = { material = Enum.Material.Cobblestone, color = Color3.fromRGB(184, 174, 166) }, -- 체성 면석·단부
	yeojangseok = { material = Enum.Material.Granite, color = Color3.fromRGB(178, 170, 162) }, -- 여장석·미석
	okgaeseok = { material = Enum.Material.Granite, color = Color3.fromRGB(150, 145, 140) }, -- 여장 옥개석 (그늘져 보여 한 단 어둡게)
	-- 광장·도로 (색은 S13 영상·사용자 항공 사진을 눈으로 참고)
	masato = { material = Enum.Material.Sand, color = Color3.fromRGB(196, 176, 140) }, -- 흙(마사토) 마당
	bakseok = { material = Enum.Material.Slate, color = Color3.fromRGB(168, 164, 156) }, -- 박석 광장
	jandi = { material = Enum.Material.Grass, color = Color3.fromRGB(92, 120, 64) }, -- 잔디, 성곽 뒤 비탈
	bodo = { material = Enum.Material.Pavement, color = Color3.fromRGB(150, 146, 140) }, -- 보도 포장
	asphalt = { material = Enum.Material.Asphalt, color = Color3.fromRGB(58, 58, 60) }, -- 차도
	ongbyeok = { material = Enum.Material.Granite, color = Color3.fromRGB(165, 160, 152) }, -- 광장 가장자리 석축 옹벽
	hoengdan = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(230, 230, 226) }, -- 횡단보도 흰 줄
	-- 차선 (근사: 색값은 눈대중. 흰 줄은 횡단보도와 같은 색)
	chaseonYellow = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(230, 170, 40) }, -- 중앙선
	chaseonBlue = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(40, 90, 200) }, -- 버스전용차로 경계
	-- 주변 건물 실루엣: 창·간판 없는 무채색 덩어리 세 톤 (근사: 색 자료 없음, 문루보다 눈에 띄지 않게 낮은 채도)
	silhouetteA = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(178, 176, 170) },
	silhouetteB = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(156, 156, 154) },
	silhouetteC = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(190, 184, 172) },
}

-- 부재 이름(Part.Name) → 칠. 없는 이름은 뇌록 (S7: 목부 일반이 뇌록 주바탕)
local byName: { [string]: string } = {
	Pyeongju = "seokganju", Uju = "seokganju", Goju = "seokganju", GwiGoju = "seokganju", UpperPyeongju = "seokganju",
	-- 문루 마루 (Munru): 귀틀·장선·동바리·마루널은 들기름칠 (S4 181~185 부재표 마감)
	JangGwiteul = "deulgireum", DongGwiteul = "deulgireum", Jangseon = "deulgireum", Dongbari = "deulgireum", Maruneol = "deulgireum",
	-- 문루 계단·난간은 석간주 (S4 186~202 부재표 마감)
	Yeoppan = "seokganju", Didimpan = "seokganju", Chaepan = "seokganju", Dwitneol = "seokganju",
	Eomjigidung = "seokganju", NanganJibang = "seokganju", Gungpan = "seokganju", NanganDdijang = "seokganju",
	NanganDongja = "seokganju", Hayeop = "seokganju", Dollandae = "seokganju",
	-- 상층 벽·하층 하인방 (S4 137~143·203 부재표 마감 석간주)
	GwiteulInbang = "seokganju", HaInbang = "seokganju", MunInbang = "seokganju", Munseon = "seokganju", Panchang = "seokganju", WallGuard = "seokganju",
	Gaepan = "yeonbaek",
	LowerJibungFront = "giwa", LowerJibungSide = "giwa", UpperJibungFront = "giwa", UpperJibungSide = "giwa",
	MaruCap = "giwa", Sumaksae = "giwa", Ammaksae = "giwa",
	Maru = "yangseong", Yeonmaru = "yangseong",
	Japsang = "wajae", Yongdu = "wajae", Chwidu = "wajae", Tosu = "wajae",
	-- 육축 (Yukchuk). 성문은 S4 064 부재표 마감 석간주, 반자널·둔테 칠은 자료 없음 → 목부 일반 뇌록·석간주 근사
	YukchukBody = "seokchuk", Stone = "myeonseok", Hongyeseok = "myeonseok", Nujo = "myeonseok",
	Dideumdol = "myeonseok", Somaetdol = "myeonseok", Panseok = "panseok",
	YeojangJeon = "jeondol", Okgaejeon = "giwa", -- 여장 전돌·옥개전 (S7 p.198 옥개전은 기와처럼 구운 것)
	Seongmun = "seokganju", Dunte = "seokganju", Cheoryeop = "soe", Banjaneol = "noerok",
	PavilionBase = "gidan",
	SeongBody = "seongdol", SeongBack = "jandi", Yeojang = "yeojangseok", Miseok = "yeojangseok", Okgae = "okgaeseok",
	Masato = "masato", Bakseok = "bakseok", Jandi = "jandi", Bodo = "bodo", Asphalt = "asphalt", Ongbyeok = "ongbyeok", Hoengdan = "hoengdan",
	ChaseonWhite = "hoengdan", ChaseonYellow = "chaseonYellow", ChaseonBlue = "chaseonBlue",
	SilhouetteA = "silhouetteA", SilhouetteB = "silhouetteB", SilhouetteC = "silhouetteC",
}

local function of(name: string): Paint
	return paint[byName[name] or "noerok"]
end

return { paint = paint, byName = byName, of = of }
