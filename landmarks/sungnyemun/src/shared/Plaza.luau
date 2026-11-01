--!strict
-- 숭례문 광장과 둘레 도로·보도 데이터. 단위 m, 출처 ID는 SOURCES.md.
-- 좌표는 자료(refs/plaza-notes.md)가 적은 그대로 건물 축 (X, Z) — 정면 = +Z, 원점 = 문루 중심 지면.
-- 세계 좌표(진북 −Z)로는 Shared.Site로 한 번 바꿔 놓는다(ADR 0004). 바꾼 값은 plaza-notes 1-1 진북 표와 같다.
-- 높이 모형은 ADR 0006: 광장은 문 앞이 가장 낮은 그릇, 둘레 보도·도로는 한 기울어진 면.

local Plaza = {}

local W = Vector3.new(-1, 0, 0) -- 세종대로 폭을 재는 방향 (건물 축 −X)
-- 소월로 폭을 재는 방향: E1→E6 연석 전체 방향(40, 63)에 수직. 문루 중심에서 바깥(반지름 방향)으로 재면
-- E3–E6에서 반지름이 연석과 거의 나란해 차도가 4 m 남짓으로 좁아졌다 (도로 차량 차로 검사에서 드러남, 2026-11-01)
local E = Vector3.new(63, 0, -40).Unit

-- 광장 바깥 연석선, 서쪽 남단에서 북쪽을 돌아 동쪽 → 남쪽 경계(건물 쪽 보도)로 닫는다.
-- { X, Z, 맞은편 연석까지 도로 폭, 잴 방향 } — 방향이 없으면 문루 중심에서 바깥으로 뻗는 방향.
-- 점: S13 영상 판독 ±2 m (E1·E2 ±5 m, 남쪽 경계 ±3 m). 서측 도로 폭: S13 세종대로 연석–연석 31–38 m, 건물 축 X로 잰 값이라 −X로 늘인다.
-- 근사: 북측 교차로 폭은 횡단보도 C1·C2(Z −80…−100)가 도로 위에 오게 잡았다. 소월로 16.25 m = 5차로 × 3.25 (사용자 임의값, 현장 확인 전)
Plaza.curb = {
	{ 0, 100, 32, W }, { -3, 90, 32, W }, { -6, 72, 33, W }, { -9, 62, 35, W }, { -14, 50, 38, W }, { -19, 38, 36, W }, -- W1–W6 세종대로
	{ -23, 28, 34, W }, { -25, 15, 32, W }, { -25.5, 5, 31.5, W }, { -26.5, -5, 31, W }, { -28, -15, 32, W }, { -25.5, -25, 36 }, -- W7–W12
	{ -15, -39, 60 }, { 0, -44, 60 }, { 15, -39, 50 }, { 30, -27, 25 }, -- N1–N4 숭례문 교차로
	{ 45, -8, 16.25, E }, { 55, 15, 16.25, E }, { 60, 27, 16.25, E }, { 67, 37, 16.25, E }, { 75, 45, 16.25, E }, { 85, 55, 16.25, E }, -- E1–E6 소월로
	{ 85, 62, 0 }, { 75, 80, 0 }, { 57, 94, 0 }, { 28, 100, 0 }, { 5, 102, 0 }, -- 남쪽: 도로 없이 보도가 건물 블록에 붙는다
}

Plaza.bandWidth = 4 -- 근사: 연석 안쪽 포장 띠(보도·자전거길) 폭. S13 3–7 m
Plaza.curbHeight = 0.15 -- 근사: 보도와 차도 단차 (사용자 임의값 2026-11-01)
Plaza.farRadius = 400 -- 근사: 도로 맞은편 보도·블록 바닥을 이 반지름까지 깐다. 주변 건물 실루엣(반지름 약 250 m)보다 넉넉히 넓게

-- 세종대로 남쪽 연장: W1(1번)의 도로와 남쪽 끝 점(마지막 번)~W1 사이 보도를 이 방향(건물 축)으로 땅 끝까지 잇는다.
-- S12 세종대로 두 차로군 중심선(way 218926711, 585341901) 건물 축 Z 110→290 구간 방향. 직선으로 둔다 (근사: 실제는 서울역 쪽으로 살짝 휜다)
Plaza.sejongSouth = Vector3.new(0.13, 0, 1).Unit

-- 연석선 꼭짓점 i를 문루 중심에서 바깥으로 dr m 늘인 점 (건물 축 x, z)
function Plaza.radial(i: number, dr: number): (number, number)
	local q = Plaza.curb[(i - 1) % #Plaza.curb + 1]
	local len = math.sqrt(q[1] ^ 2 + q[2] ^ 2)
	return q[1] * (len + dr) / len, q[2] * (len + dr) / len
end

-- 꼭짓점 i의 맞은편 연석 (자료에 잴 방향이 있으면 그 방향, 없으면 바깥으로). 이 점들을 이은 다각형 안이 광장+도로다
function Plaza.roadFar(i: number): (number, number)
	local q = Plaza.curb[(i - 1) % #Plaza.curb + 1]
	local dir = q[4] :: Vector3?
	if dir then
		return q[1] + dir.X * q[3], q[2] + dir.Z * q[3]
	end
	return Plaza.radial(i, q[3])
end

-- 보행 경계: 맞은편 연석 점을 바깥으로 이만큼(m) 늘인 선. 방문자는 도로를 건너 맞은편 보도까지만 간다 (사용자 결정 2026-11-01).
-- 근사: 맞은편 보도 폭. 주변 건물 실루엣은 맞은편 연석에서 2 m 이상 떨어져 있어(Silhouette 생성 조건) 이 선 밖에 있다
Plaza.walkMargin = 2
Plaza.walkHeight = 6 -- 보행 경계 벽 높이 (점프로 넘지 못할 만큼)

-- 보행 경계 꼭짓점 i (건물 축 x, z). 세종대로 남쪽 연장·북쪽 도로도 이 선에서 끊긴다
function Plaza.boundary(i: number): (number, number)
	local x, z = Plaza.roadFar(i)
	local len = math.sqrt(x * x + z * z)
	return x * (len + Plaza.walkMargin) / len, z * (len + Plaza.walkMargin) / len
end

-- 점 (x, z)에서 세종대로 남쪽 방향으로 땅 끝(farRadius)까지 간 점
function Plaza.toEdge(x: number, z: number): (number, number)
	local d = Plaza.sejongSouth
	local pd = x * d.X + z * d.Z
	local t = -pd + math.sqrt(pd * pd - (x * x + z * z) + Plaza.farRadius ^ 2)
	return x + d.X * t, z + d.Z * t
end

-- 횡단보도 중심선 양 끝 (S13 판독). 폭 근사 5 m (S13 줄무늬 길이 5–6 m)
Plaza.crosswalks = {
	{ -40, -78, -8, -100 }, -- C1 교차로 북측, 세종대로 북쪽 가지
	{ 0, -97, 20, -72 }, -- C2 교차로 북동, 남대문로 가지
	{ 12, -50, 28, -38 }, -- C3 광장 북동 모서리 → 소월로 건너편
}
Plaza.crosswalkWidth = 5

-- 지붕 분해 표식: 정면 흙 마당 가운데, 문루 정면(육축 남측면 Z 5.5)에서 약 40 m. 근사: 분해해 다 벌어진 문루(높이 약 40 m)가
-- 고개를 들면 한 화면에 드는 거리로 잡았다. { x, z } 건물 축 m, 높이는 광장 바닥. 크기 { 폭, 높이, 두께 } m
Plaza.roofSplitMarker = { x = 0, z = 45, size = { 0.6, 0.5, 0.25 } }

-- 높이: 문루 중심 지면(홍예 통로 바닥, Y = 0)에서 잰 m.
-- S7 p.589~590: 육축 전면 중앙 ↔ 전면 출입구(마사토 포장 시작점) 레벨차 2.49 m, 후면 ↔ 배면 출입구 1.14 m.
-- 근사: 두 출입구의 Z(전면 65 = 흙 마당 남쪽 끝 S13, 후면 −37 = 문루 뒤 흙 마당 북쪽 끝 S13)
local FRONT = { z = 65, h = 2.49 }
local BACK = { z = -37, h = 1.14 }
local FLAT = { -12, 15 } -- 근사: 육축 앞뒤로 문루 지면 높이 그대로인 구간 (Z)

-- 둘레 보도 윗면: 두 출입구 높이를 지나는 한 면(건물 축 Z 방향으로만 기운다). 근사: 실제 도로 경사 자료 없음 (plaza-notes 4절)
function Plaza.sidewalk(z: number): number
	return BACK.h + (z - BACK.z) * (FRONT.h - BACK.h) / (FRONT.z - BACK.z)
end

function Plaza.road(z: number): number
	return Plaza.sidewalk(z) - Plaza.curbHeight
end

-- 광장 바닥: 육축 앞뒤 평지에서 출입구까지 고르게 오르는 그릇. 보도보다 늘 연석 높이만큼은 낮다
function Plaza.floor(z: number): number
	local bowl = 0
	if z > FLAT[2] then
		bowl = FRONT.h * math.min(1, (z - FLAT[2]) / (FRONT.z - FLAT[2]))
	elseif z < FLAT[1] then
		bowl = BACK.h * math.min(1, (FLAT[1] - z) / (FLAT[1] - BACK.z))
	end
	return math.min(bowl, Plaza.sidewalk(z) - Plaza.curbHeight)
end

-- 광장 바닥 구역: Z 구간마다 가운데 흙(마사토) 마당 X 범위. 나머지는 잔디, 박석 구간은 폭 전체 박석.
-- S13 영상 판독: 정면 축 흙 마당 폭 약 26 m Z 11→65, 박석 광장 Z 62→100, 문루 뒤 흙 마당 X −4…13 Z −9…−37
Plaza.zones = {
	{ z0 = 62, z1 = math.huge, kind = "Bakseok" },
	{ z0 = 6, z1 = 62, kind = "Masato", x0 = -13, x1 = 13 },
	{ z0 = -6, z1 = 6, kind = "Masato", x0 = -math.huge, x1 = math.huge }, -- 근사: 육축 양옆(유구 노출 구역 자리)도 흙
	{ z0 = -37, z1 = -6, kind = "Masato", x0 = -4, x1 = 13 },
}

-- 점 (x, z)가 다각형 poly({ {x, z}, ... }) 안인가 (건물 축)
function Plaza.inside(x: number, z: number, poly: { { number } }): boolean
	local c = false
	for i, p in poly do
		local q = poly[i % #poly + 1]
		if (p[2] > z) ~= (q[2] > z) and x < p[1] + (q[1] - p[1]) * (z - p[2]) / (q[2] - p[2]) then
			c = not c
		end
	end
	return c
end

local curbPoly, farPoly, boundaryPoly, southRoad = {}, {}, {}, {}
for i, q in Plaza.curb do
	curbPoly[i] = { q[1], q[2] }
	farPoly[i] = { Plaza.roadFar(i) }
	boundaryPoly[i] = { Plaza.boundary(i) }
end
do
	local w1, w1far = curbPoly[1], farPoly[1]
	southRoad = { w1, w1far, { Plaza.toEdge(w1far[1], w1far[2]) }, { Plaza.toEdge(w1[1], w1[2]) } }
end

-- 점 (x, z)가 차도(아스팔트) 위인가: 연석과 맞은편 연석 사이 고리, 또는 세종대로 남쪽 연장
function Plaza.onRoad(x: number, z: number): boolean
	return (Plaza.inside(x, z, farPoly) and not Plaza.inside(x, z, curbPoly)) or Plaza.inside(x, z, southRoad)
end

-- 점 (x, z)가 연석 안(광장 바닥·안쪽 보도 띠)인가
function Plaza.plazaSide(x: number, z: number): boolean
	return Plaza.inside(x, z, curbPoly)
end

-- 점 (x, z)가 보행 경계 안인가 (방문자가 걸어 가 볼 수 있는 곳)
function Plaza.walkable(x: number, z: number): boolean
	return Plaza.inside(x, z, boundaryPoly)
end

return Plaza
