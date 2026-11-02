--!strict
-- 숭례문 개폐의식 인물 12명과 깃발 데이터 (core Figures가 움직인다). 단위 m, 건물 축(정면 +Z, 왼쪽 +X는 인물 기준). 시간은 회차 구간 시작(T)에서 잰다.
-- 인물은 모두 가상의 인물이다. 복식은 사진을 보고 색과 형태만 읽어 상자로 다시 만들었고 사진 픽셀은 없다 (SOURCES.md S37~S40, refs/pasu-notes.md §13.1).
-- 근거 없는 제안값: 모든 자리·간격·경로·시각, 12명의 역할 배분, 깃발 8기와 색 배치 (기획 refs/pasu-plan.html 평면도. 실제 도열은 약 20명 이상).
-- 역할 근거:
--   호군·파수군: 공식 사진 sa02·sa03 캡션으로 확인.
--   금루관(청록 철릭·징), 선전관(사모·단령): 사진에 이름 캡션이 없다. 역할은 추정이다.
--   나각수·나발수(황립·황철릭): 황철릭 도열은 숭례문 사진으로 확인. 무엇을 부는지는 숭례문 사진으로 못 읽었다. 악기 배정은 추정이다.
--   금군: 황 전복으로 뒀다. 유일한 캡션(MH-2022)은 연보라 전복인데 덕수궁 병력일 수 있고, 2023 영상의 표신 확인 상대는 황 전복이라 어긋난다.
--   초관: 사진에서 식별하지 못해 넣지 않았다. 덕수궁 복식·의장기 문양은 옮기지 않는다.
-- 근무 자리 (사진별 정리 refs/pasu-notes.md §13.6): 파수군은 벽 앞 왼쪽(−X) 2 + 오른쪽(+X) 1, 호군은 그보다 앞 가운데 (official/sg05, sp04. 둘 다 호군 1 + 3 = 4명이고 홍예 안에는 아무도 서지 않는다).
--   mh22_yOciYX는 왼쪽 1 + 오른쪽 3, sp01은 양옆 2명이라 고정 배치는 아니다. 왼쪽 2 + 오른쪽 1은 두 사진이 같아 골랐다. X는 sg05에서 잰 근사값, 벽에서 떨어진 거리와 호군의 Z는 사진으로 못 재 제안값이다.
--   sg05·sp04의 오른쪽·왼쪽 한 명은 청 전복이지만 여기 파수군은 황·홍만 쓰기로 해서 황으로 뒀다 (어긋남).
-- 문을 움직이는 7·8번은 사진 판단대로 문 북쪽에 있다 (pasu-notes §13.2). 남쪽에서는 문만 움직여 보인다. 이 둘은 창을 들지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Figures = require(ReplicatedStorage.Core.Figures)
local D = require(script.Parent.Dimensions)
local Plaza = require(script.Parent.Plaza)
local Y = require(script.Parent.Yukchuk)
local site = require(script.Parent.Site)

local hex = Color3.fromHex
local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- Part 원기둥 축(X)을 세운다
local METAL = Enum.Material.SmoothPlastic

-- 복식 색 (기획 "디자인 시안". 사진 표본 + 눈대중 근사)
local C = {
	black = hex("#14151C"),
}

type Joint = Figures.Joint
local function rod(joint: Joint, length: number, width: number, x: number, y: number, z: number, color: Color3): Figures.Box
	return { joint = joint, size = Vector3.new(length, width, width), at = CFrame.new(x, y, z) * UPRIGHT, color = color, shape = CYL, material = METAL }
end

-- 복식 메시: Studio AI 메시 생성으로 만들었다 (S46). 사진 픽셀은 없고, 프롬프트에 사진에서 읽은 색과 형태만 적었다. 사람 얼굴은 가상이다.
-- { mesh, texture, yaw } yaw = 메시 앞이 인물 앞(+Z)을 보게 돌리는 각. 생성 메시는 앞이 −Z다 (Play 확인)
local M = {
	head = { 73698535879637, 101211243302770, 180 },
	dome = { 97713933935158, 106588093262999, 0 }, -- 전립 몸통 반구
	vestYellow = { 96192919519974, 121443490045288, 180 },
	vestRed = { 96087331470781, 95097345748557, 180 },
	vestHogun = { 84715772709355, 91187563165060, 180 },
	robePlayer = { 135248797050814, 104320011705643, 180 },
	robeSeonjeon = { 80800079919262, 111082606304659, 180 },
	robeGeumru = { 75131082643337, 128830974974503, 180 },
	armPurple = { 124968232742241, 125575726064405, 180 },
	skirt = { 84995893448823, 119103880034870, 180 },
	boot = { 94620698467497, 81450217428794, 180 },
	woldoHead = { 124066811321553, 72243445607698, 180 }, -- 자루 없는 칼날과 금 물림쇠
	nagak = { 101582088917154, 120202421355661, 0 }, -- 뾰족한 끝이 메시 +Y
	hand = { 78808390872339, 130602473875533, 180 },
}
-- 메시를 받지 못했을 때 상자로 지을 때의 색
local FALLBACK = hex("#6E6A72")
local GOLD, RED, BRONZE = hex("#C9A227"), hex("#C8142E"), hex("#A0853C")
local BRASS = Enum.Material.Metal

-- 메시 한 조각: 크기 (m), 가운데 자리 (m)
local function mesh(joint: Joint, m: { number }, w: number, h: number, d: number, x: number, y: number, z: number, shadow: boolean?): Figures.Box
	return {
		joint = joint, size = Vector3.new(w, h, d), at = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(m[3]), 0),
		color = FALLBACK, shadow = shadow, mesh = m[1], texture = m[2],
	}
end

-- 두 점을 잇는 원기둥. 점은 그 자세에서 놓일 자리(m)이고, frame은 그 관절의 자세 변환이다 (없으면 내린 자세 그대로)
local function bar(joint: Joint, a: Vector3, b: Vector3, width: number, color: Color3, frame: CFrame?, material: Enum.Material?): Figures.Box
	local at = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	return {
		joint = joint, size = Vector3.new((b - a).Magnitude, width, width), at = if frame then frame:Inverse() * at else at,
		color = color, shape = CYL, material = material or METAL,
	}
end
local function ball(joint: Joint, d: number, p: Vector3, color: Color3, frame: CFrame?): Figures.Box
	local at = CFrame.new(p)
	return {
		joint = joint, size = Vector3.new(d, d, d), at = if frame then frame:Inverse() * at else at,
		color = color, shape = Enum.PartType.Ball, material = METAL,
	}
end
-- 상자. frame은 bar와 같다
local function slab(joint: Joint, size: Vector3, at: CFrame, color: Color3, frame: CFrame?, material: Enum.Material?): Figures.Box
	return { joint = joint, size = size, at = if frame then frame:Inverse() * at else at, color = color, material = material or METAL }
end

-- 손 자리: 내린 팔에서 손 가운데 (m). 팔 메시 아래 끝에서 조금 위
local HAND_X, HAND_Y = 0.24, 0.74
local function handAt(side: "armL" | "armR", pose: string): (Vector3, CFrame)
	local frame = Figures.armFrame(side, pose)
	return frame * Vector3.new(if side == "armL" then HAND_X else -HAND_X, HAND_Y, 0), frame
end

export type Dress = {
	torso: { number },
	sleeve: Color3,
	grip: { armL: boolean?, armR: boolean? }?, -- 물건을 쥔 손. 손바닥과 손가락으로 조립한 주먹을 쓴다
	gripAcross: boolean?, -- 쥔 물건이 가로다 (등채). 없으면 세로 (자루)
	inner: number?, -- 속저고리 폭 (m). 옷이 좁으면 줄인다
	hat: { Figures.Box },
	skirt: boolean?, -- 앞자락 아래 치마
	torsoHeight: number, -- 어깨(y 1.42)에서 앞자락 끝까지 (m)
	torsoDepth: number,
}

-- 주먹: 물건이 손바닥 가운데를 지나고 손가락 네 개가 그 앞을 감싼다. 생성한 손 메시는 이 크기에서 펴진 손처럼 보였다
local SKIN = hex("#E3AE94")
local function fist(j: Joint, x: number, across: boolean?): { Figures.Box }
	local out = { ball(j, 0.08, Vector3.new(x, HAND_Y, 0), SKIN) }
	for i = 0, 3 do
		local s = (i - 1.5) * 0.023
		local c = if across then Vector3.new(x + s, HAND_Y, 0.034) else Vector3.new(x, HAND_Y + s, 0.034)
		local half = if across then Vector3.new(0, 0.034, 0) else Vector3.new(0.034, 0, 0)
		table.insert(out, bar(j, c - half, c + half, 0.026, SKIN))
	end
	return out
end

-- 몸 한 벌: 약 1.7 m (머리 꼭대기), 모자 포함 약 1.75 m. 조각마다 core Figures의 관절 하나를 따라 움직인다
local function body(d: Dress): { Figures.Box }
	local b: { Figures.Box } = {
		mesh("legL", M.boot, 0.17, 0.46, 0.3, 0.1, 0.23, 0.02),
		mesh("legR", M.boot, 0.17, 0.46, 0.3, -0.1, 0.23, 0.02),
		mesh("upper", d.torso, 0.6, d.torsoHeight, d.torsoDepth, 0, 1.42 - d.torsoHeight / 2, 0, true),
		mesh("upper", M.head, 0.235, 0.345, 0.22, 0, 1.54, 0.01),
	}
	-- 속저고리: 민소매 옷의 진동 구멍이 검게 뚫려 보이지 않게 안쪽을 소매 색으로 메운다
	table.insert(b, slab("upper", Vector3.new(d.inner or 0.27, 0.26, 0.08), CFrame.new(0, 1.14, 0), d.sleeve))
	-- 모두 민소매 옷 + 팔 메시 (옷 메시에 소매가 있으면 팔을 들 때 소매가 이중으로 보였다).
	-- 팔 메시 하나를 sleeve 색으로 칠해 쓴다: 색마다 생성하면 모양이 제각각이고, 칠하면 메시의 손도 소매 색이 되므로
	-- 팔을 줄여 끝이 토시 위에 오게 해 소매처럼 보이게 하고, 그 아래에 손 메시를 단다
	for _, s in { { "armL", 1 }, { "armR", -1 } } do
		local j, side = s[1] :: Joint, s[2] :: number
		local arm = mesh(j, M.armPurple, 0.135, 0.5, 0.135, side * HAND_X, 1.03, 0)
		arm.tint, arm.color, arm.material = true, d.sleeve, METAL -- Fabric 무늬는 뜨개처럼 보였다
		table.insert(b, arm)
		table.insert(b, rod(j, 0.04, 0.095, side * HAND_X, 0.795, 0, hex("#E8E4DA"))) -- 토시
		local gripped = d.grip and (d.grip :: any)[j]
		if gripped then
			for _, f in fist(j, side * HAND_X, d.gripAcross) do
				table.insert(b, f)
			end
		else
			table.insert(b, mesh(j, M.hand, 0.1, 0.17, 0.08, side * HAND_X, HAND_Y - 0.02, 0))
		end
		-- 어깨: 팔 메시 윗단이 컵처럼 열려 있어 납작한 반구로 막는다 (공을 쓰면 옷 위로 튀어나왔다)
		local cap = mesh(j, M.dome, 0.13, 0.035, 0.13, side * HAND_X, 1.272, 0)
		cap.tint, cap.color, cap.material = true, d.sleeve, METAL
		table.insert(b, cap)
	end
	if d.skirt then
		local skirt = mesh("root", M.skirt, 0.44, 0.64, 0.38, 0, 0.53, 0)
		skirt.tint, skirt.color, skirt.material = true, hex("#3D3A62"), METAL -- 사진 치마 색. 메시 그림은 너무 밝은 파랑이다
		table.insert(b, skirt)
	end
	for _, h in d.hat do
		table.insert(b, h)
	end
	return b
end

-- 모자는 이마까지 내려 씌운다: 챙 밑면 = BRIM, 몸통이 머리 윗부분을 덮는다
local BRIM = 1.615

-- 챙 넓은 모자 공통: 반구 몸통 하나 + 얇은 챙. 사용자가 가장 자연스럽다고 고른 전립의 비율을 갓·황립도 그대로 쓴다.
-- 통짜 메시는 몸통이 두 단으로 나오거나 너무 커서 쓰지 않는다
local CROWN, CROWN_H, BRIM_D = 0.27, 0.15, 0.48
local function wideHat(color: Color3, under: Color3): { Figures.Box }
	local dome = mesh("upper", M.dome, CROWN, CROWN_H, CROWN, 0, BRIM + 0.012 + CROWN_H / 2, 0)
	dome.tint, dome.color = true, color
	return {
		rod("upper", 0.008, BRIM_D - 0.01, 0, BRIM + 0.004, 0, under), -- 챙 안
		rod("upper", 0.012, BRIM_D, 0, BRIM + 0.014, 0, color), -- 챙
		dome,
	}
end

-- 전립 (sa02·sa03): 황·홍 끈 띠, 금 꼭지, 꼭지에서 챙 밖으로 늘어진 상모, 챙 끝에서 가슴으로 모이는 굵은 구슬 패영
local function jeollip(): { Figures.Box }
	local top = BRIM + 0.012 + CROWN_H
	local brimEdge = Vector3.new(-BRIM_D / 2, BRIM + 0.012, 0) -- 인물 오른쪽. 사진의 상모 자리
	local out = wideHat(hex("#14151C"), hex("#334693"))
	for _, part in {
		rod("upper", 0.016, CROWN + 0.012, 0, BRIM + 0.028, 0, hex("#DB1F3E")), -- 끈 띠
		rod("upper", 0.016, CROWN + 0.004, 0, BRIM + 0.044, 0, hex("#E8B92F")),
		ball("upper", 0.03, Vector3.new(0, top + 0.012, 0), GOLD), -- 꼭지
		bar("upper", Vector3.new(0, top, 0), brimEdge, 0.014, RED), -- 상모 끈
		bar("upper", brimEdge, brimEdge - Vector3.new(0, 0.2, 0), 0.04, RED), -- 상모 술
		ball("upper", 0.04, brimEdge, RED),
	} do
		table.insert(out, part)
	end
	local amber, garnet = hex("#D07A28"), hex("#7A2A1E")
	for side = -1, 1, 2 do
		local p0, p1, p2 = Vector3.new(side * 0.135, BRIM, 0.02), Vector3.new(side * 0.135, 1.3, 0.07), Vector3.new(0, 1.24, 0.15)
		for i = 0, 8 do
			local k = i / 8
			local q = p0:Lerp(p1, k):Lerp(p1:Lerp(p2, k), k)
			table.insert(out, ball("upper", 0.03, q, if i % 3 == 2 then garnet else amber))
		end
	end
	return out
end

-- 호군 (sa02): 보라 소매 + 청 민소매 전복. 두 손으로 붉은 등채를 가로로 들고, 왼쪽 허리에 환도, 오른쪽에 황 수건
local function hogun(): { Figures.Box }
	local b = body({ torso = M.vestHogun, inner = 0.36, sleeve = hex("#3E3360"), grip = { armL = true, armR = true }, gripAcross = true, hat = jeollip(), torsoHeight = 1.2, torsoDepth = 0.36 })
	-- 등채: 오른팔에 붙인다. 왼팔은 grip·command에서 같은 만큼 움직여 손이 떨어지지 않는다
	local r, frame = handAt("armR", "grip")
	local l = handAt("armL", "grip")
	local dir = (l - r).Unit
	table.insert(b, bar("armR", r - dir * 0.13, r + dir * 0.03, 0.03, hex("#2B211C"), frame)) -- 손잡이
	table.insert(b, bar("armR", r + dir * 0.03, r + dir * 0.05, 0.034, GOLD, frame, BRASS))
	table.insert(b, bar("armR", r + dir * 0.05, l + dir * 0.17, 0.02, hex("#C4122C"), frame)) -- 붉은 자루
	table.insert(b, bar("armR", l + dir * 0.17, l + dir * 0.19, 0.024, GOLD, frame, BRASS))
	-- 환도: 손잡이가 앞으로 올라오고 칼집은 뒤로 내려간다. 칼자루에서 붉은 술이 늘어진다
	local hilt = Vector3.new(0.29, 0.86, 0.1)
	local back = (Vector3.new(0.29, 0.46, -0.4) - hilt).Unit
	table.insert(b, bar("root", hilt, hilt - back * 0.16, 0.032, hex("#8A7B66")))
	table.insert(b, bar("root", hilt - back * 0.005, hilt + back * 0.012, 0.07, GOLD, nil, BRASS)) -- 코등이
	table.insert(b, bar("root", hilt + back * 0.012, hilt + back * 0.68, 0.042, C.black)) -- 칼집
	table.insert(b, bar("root", hilt + back * 0.12, hilt + back * 0.14, 0.046, GOLD, nil, BRASS))
	table.insert(b, bar("root", hilt - back * 0.08, Vector3.new(0.31, 0.5, 0.17), 0.008, RED))
	table.insert(b, bar("root", Vector3.new(0.31, 0.5, 0.17), Vector3.new(0.31, 0.34, 0.17), 0.036, RED))
	-- 황 수건 (sa02): 허리에 묶어 접힌 채 늘어진 천. 길이가 다른 세 자락과 매듭
	local towel = hex("#C9B21E")
	for _, f in { { -0.15, 0.34, 0.075, 0.12 }, { -0.115, 0.27, 0.06, -0.1 }, { -0.18, 0.2, 0.05, 0.25 } } do
		local x, len, w, a = f[1], f[2], f[3], f[4]
		local cf = CFrame.new(x, 0.8, 0.16) * CFrame.Angles(0, 0, a) * CFrame.new(0, -len / 2, 0)
		table.insert(b, slab("root", Vector3.new(w, len, 0.012), cf, towel, nil, Enum.Material.Fabric))
	end
	table.insert(b, ball("root", 0.06, Vector3.new(-0.145, 0.81, 0.16), towel))
	-- 끈과 주머니 (sa02): 왼쪽 허리에서 늘어진 두 가닥 황 끈 끝에 작은 주머니
	local cord = hex("#CDA861")
	table.insert(b, bar("root", Vector3.new(0.09, 0.83, 0.16), Vector3.new(0.13, 0.3, 0.19), 0.012, cord))
	table.insert(b, bar("root", Vector3.new(0.13, 0.83, 0.16), Vector3.new(0.15, 0.3, 0.19), 0.012, cord))
	table.insert(b, ball("root", 0.07, Vector3.new(0.14, 0.27, 0.19), cord))
	return b
end

-- 긴 자루 칼 (sa03): 땅을 짚고 오른손으로 쥔다. 위쪽 끝이 바깥으로 조금 기운다
local POLE_LENGTH = 2.35
local function pole(): { Figures.Box }
	local h, frame = handAt("armR", "pole")
	local up = Vector3.new(-0.08, 1, 0.02).Unit
	local foot = h - up * (h.Y / up.Y)
	local function along(a: number): Vector3
		return foot + up * (POLE_LENGTH * a)
	end
	-- 칼날 머리는 전체의 약 1/5 (전에는 자루와 한 메시라 칼날이 사진보다 컸다)
	local headLength = POLE_LENGTH * 0.21
	local center = along(1) - up * (headLength / 2)
	local cf = CFrame.lookAt(center, center + Vector3.new(0, 0, -1), up) * CFrame.Angles(0, math.pi, 0)
	return {
		bar("armR", foot, along(0.8), 0.036, hex("#6B3A22"), frame), -- 자루
		bar("armR", foot, along(0.03), 0.044, GOLD, frame, BRASS), -- 물미
		bar("armR", along(0.5), along(0.79), 0.042, hex("#1E1E22"), frame), -- 감개
		{ joint = "armR", size = Vector3.new(0.13, headLength, 0.04), at = frame:Inverse() * cf, color = FALLBACK, mesh = M.woldoHead[1], texture = M.woldoHead[2] },
	}
end

-- 파수군 (sa03 / 홍 전복 sg05·sp04)
local function jeongbyeong(torso: { number }, spear: boolean): { Figures.Box }
	local b = body({ torso = torso, inner = 0.36, sleeve = hex("#3E3360"), grip = if spear then { armR = true } else nil, hat = jeollip(), skirt = true, torsoHeight = 1.0, torsoDepth = 0.34 })
	if spear then
		for _, p in pole() do
			table.insert(b, p)
		end
	end
	return b
end

-- 약시함 (sp03: 두 손으로 가슴 앞에 든 짙은 적갈 상자. 약시함이라는 것은 추정). 왼팔에 붙인다
local function yaksiham(): { Figures.Box }
	local l, frame = handAt("armL", "carrybox")
	local r = handAt("armR", "carrybox")
	local c = CFrame.new((l + r) / 2 + Vector3.new(0, 0.08, 0))
	local wood, lid = hex("#4F2318"), hex("#3B1A12")
	return {
		slab("armL", Vector3.new(0.34, 0.13, 0.2), c, wood, frame, Enum.Material.Wood),
		slab("armL", Vector3.new(0.36, 0.035, 0.22), c * CFrame.new(0, 0.08, 0), lid, frame, Enum.Material.Wood),
		slab("armL", Vector3.new(0.045, 0.07, 0.008), c * CFrame.new(0, 0.035, 0.103), GOLD, frame, BRASS), -- 걸쇠
		slab("armL", Vector3.new(0.012, 0.135, 0.204), c * CFrame.new(-0.13, 0, 0), GOLD, frame, BRASS), -- 띠쇠
		slab("armL", Vector3.new(0.012, 0.135, 0.204), c * CFrame.new(0.13, 0, 0), GOLD, frame, BRASS),
	}
end

-- 표신·부험: 손에 쥔 작은 패 (모양은 근사). 내린 팔 기준이라 hold 자세에서 손과 함께 가슴 앞으로 온다
local function token(): { Figures.Box }
	local at = CFrame.new(-HAND_X + 0.01, HAND_Y - 0.03, 0.05)
	return {
		slab("armR", Vector3.new(0.085, 0.145, 0.01), at, GOLD, nil, BRASS),
		slab("armR", Vector3.new(0.07, 0.13, 0.014), at, hex("#3B2118"), nil, Enum.Material.Wood),
	}
end

-- 갓 (sp03): 전립과 같은 둥근 몸통에 짙은 갈색 띠. 평평한 원기둥 몸통은 서양 중절모처럼 보였고, 사용자가 전립 비율을 가장 자연스럽다고 골랐다
local function gat(): { Figures.Box }
	local out = wideHat(C.black, C.black)
	table.insert(out, rod("upper", 0.02, CROWN + 0.008, 0, BRIM + 0.032, 0, hex("#3A2A1C")))
	return out
end

-- 황립 (mh22): 누런 챙 넓은 모자
local function hwangnip(): { Figures.Box }
	return wideHat(hex("#D9B24A"), hex("#B8913A"))
end

-- 금루관 후보 (sp03·sp07, 역할 추정). 징은 왼손에 끈으로 늘어뜨려 세워 들고, 오른손 채로 친다
local function geumrugwan(): { Figures.Box }
	local b = body({ torso = M.robeGeumru, grip = { armL = true, armR = true }, sleeve = hex("#23907F"), hat = gat(), torsoHeight = 1.22, torsoDepth = 0.4 })
	local l, frame = handAt("armL", "gong")
	local center = l + Vector3.new(0.03, -0.21, 0.06)
	local face = CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0) -- 원기둥 축(X)을 앞으로
	table.insert(b, bar("armL", l, center + Vector3.new(0, 0.16, 0), 0.012, hex("#3A2A1C"), frame)) -- 끈
	local function disc(thick: number, d: number, shift: number, color: Color3): Figures.Box
		local s = slab("armL", Vector3.new(thick, d, d), face * CFrame.new(shift, 0, 0), color, frame)
		s.shape = CYL
		return s
	end
	table.insert(b, disc(0.03, 0.34, 0, BRONZE))
	table.insert(b, disc(0.05, 0.36, 0.012, hex("#5E4E24"))) -- 테: 앞면(원판 축 −X)보다 뒤로 물려 앞을 가리지 않게
	table.insert(b, disc(0.04, 0.12, -0.012, hex("#B89A4A"))) -- 가운데 볼록한 부분
	-- 채: strike 자세에서 끝이 징 가운데에 닿는 길이와 방향으로 오른팔에 붙인다
	local r, armFrame = handAt("armR", "strike")
	local tip = center + Vector3.new(0, 0, 0.05)
	local dir = (tip - r).Unit
	table.insert(b, bar("armR", r - dir * 0.04, tip - dir * 0.03, 0.016, hex("#5A2E22"), armFrame))
	table.insert(b, ball("armR", 0.06, tip - dir * 0.03, hex("#D8CDB6"), armFrame)) -- 감싼 채 머리
	return b
end

-- 사모 (sp03): 낮은 앞 몸통, 그 뒤로 솟은 몸통, 뒤쪽 양옆의 날개. 통짜 메시는 날개가 넓은 원판으로 나와 쓰지 않는다
local function samo(): { Figures.Box }
	local function capPart(w: number, h: number, y: number, z: number): Figures.Box
		local m = mesh("upper", M.dome, w, h, w, 0, y + h / 2, z)
		m.tint, m.color = true, C.black
		return m
	end
	local out = { capPart(0.265, 0.12, BRIM, 0), capPart(0.19, 0.19, BRIM + 0.02, -0.035) }
	for side = -1, 1, 2 do
		-- 날개: 납작하게 누른 반구로 옆으로 긴 타원 판을 만든다 (둥근 판은 귀처럼 보였다)
		local wing = mesh("upper", M.dome, 0.15, 0.008, 0.042, side * 0.155, BRIM + 0.115, -0.085)
		wing.at = CFrame.new(side * 0.155, BRIM + 0.115, -0.085) * CFrame.Angles(math.pi / 2, 0, 0)
		wing.tint, wing.color = true, C.black
		table.insert(out, wing)
	end
	return out
end

local function seonjeongwan(): { Figures.Box } -- 선전관 후보 (sp03, 역할 추정)
	local b = body({ torso = M.robeSeonjeon, grip = { armR = true }, sleeve = hex("#1F3FA8"), hat = samo(), torsoHeight = 1.25, torsoDepth = 0.3 })
	for _, p in token() do
		table.insert(b, p)
	end
	return b
end
local function geumgun(): { Figures.Box } -- 금군: 복식 어긋남은 머리 주석
	local b = jeongbyeong(M.vestYellow, false)
	for _, p in token() do
		table.insert(b, p)
	end
	return b
end

local function player(instrument: { Figures.Box }, open: boolean?): { Figures.Box } -- 나각수·나발수 후보 (mh22 도열, 악기 배정 추정)
	local b = body({ torso = M.robePlayer, grip = if open then nil else { armR = true }, sleeve = hex("#D9B568"), hat = hwangnip(), torsoHeight = 1.22, torsoDepth = 0.4 })
	for _, i in instrument do
		table.insert(b, i)
	end
	return b
end
local MOUTH = Vector3.new(0, 1.465, 0.13)
-- 나각 (official/sp02에서 형태만: 입에 댄 좁은 끝에서 넓은 몸통으로 굵어지고 손이 몸통 쪽을 받친다. sp02 배경은 숭례문이 아니다).
local function nagak(): { Figures.Box }
	local h, frame = handAt("armR", "blow")
	local dir = (h - MOUTH).Unit
	local L = (h - MOUTH).Magnitude -- 넓은 끝이 손바닥에 닿는다 (대기 자세에서도 손에서 떨어지지 않게)
	local center = MOUTH + dir * (L / 2)
	-- 메시 +Y(뾰족한 끝)가 입을 본다
	local cf = CFrame.lookAt(center, center + dir:Cross(Vector3.xAxis), -dir)
	return {
		{ joint = "armR", size = Vector3.new(L * 0.43, L, L * 0.38), at = frame:Inverse() * cf, color = hex("#D8B08C"), mesh = M.nagak[1], texture = M.nagak[2] },
	}
end
-- 나발: 입에서 손을 지나 앞으로 뻗는 긴 금속관. 끝이 나팔처럼 벌어진다
local function nabal(): { Figures.Box }
	local h, frame = handAt("armR", "longblow")
	local dir = (h - MOUTH).Unit
	local brass = hex("#C9A227")
	return {
		bar("armR", MOUTH, MOUTH + dir * 0.82, 0.024, brass, frame, BRASS),
		bar("armR", MOUTH + dir * 0.76, MOUTH + dir * 0.86, 0.05, brass, frame, BRASS),
		bar("armR", MOUTH + dir * 0.85, MOUTH + dir * 0.9, 0.09, brass, frame, BRASS),
	}
end

-- 시간표 만들기: 사람 하나의 열쇠 자리를 차례로 잇는다
local SPEED = 1.25 -- 걷는 속도 m/s. 차분한 행진 (근사)
local MARCH = 1.6 -- 입장·퇴장 구간 속도 m/s. 먼 자리까지 입취위·퇴장 구간 안에 오간다 (근사)
type Route = { keys: { Figures.Key }, t: number, x: number, z: number }
local function from(t: number, x: number, z: number, face: number?): Route
	return { keys = { { at = t, x = x, z = z, face = face } }, t = t, x = x, z = z }
end
local function go(r: Route, x: number, z: number, speed: number?)
	r.t += math.sqrt((x - r.x) ^ 2 + (z - r.z) ^ 2) / (speed or SPEED)
	r.x, r.z = x, z
	table.insert(r.keys, { at = r.t, x = x, z = z })
end
-- t까지 그 자리에 pose 자세로 face를 보며 선다. 앞선 걸음이 t에 못 닿으면 데이터가 틀린 것이다
local function stay(r: Route, t: number, pose: string?, face: number?)
	assert(t >= r.t - 1e-6, `시간표가 겹친다: {t} < {r.t}`)
	local last = r.keys[#r.keys]
	last.pose, last.face = pose, face or last.face
	r.t = t
	table.insert(r.keys, { at = t, x = r.x, z = r.z })
end

local SOUTH, NORTH, TO_X, TO_MINUS_X = 0, math.pi, math.pi / 2, -math.pi / 2
local LINE_Z = 8.4 -- 남측면 앞 판석 띠
-- 인물이 나타나고 사라지는 자리: 북측면에서 약 15.6 m 북쪽 흙 마당. 더 멀면 25초 안에 양끝 자리까지 못 온다 (22 + 7 + 10 m ÷ MARCH = 24.4초).
-- ponytail: 북쪽 가까이 선 방문자에게는 서서히 나타나는 모습이 보인다. 안 보이게 하려면 입취위·퇴장 구간을 늘린다
local NORTH_START = -22
local ARCH_X = 1.2 -- 통로를 지나는 두 줄의 X
local HOGUN_POST = 10.5 -- 호군 근무 자리 Z. 제안값: 도열 자리와 같다. sg05·sp04에서 앞 가운데인 것만 사진 근거
local POST = { left = -4.2, far = -5.0, right = 5.4 } -- 근무 파수군 X. 근사: sg05 벽 앞 발 위치를 홍예 폭으로 환산

-- T: 회차 구간 시작 시각, LEN: 구간 길이 (Gaepye.luau)
return function(T: { [string]: number }, LEN: { [string]: number }): Figures.Config
	local G = Y.gate
	local hingeZ = (D.wall.south - Y.arches.south.length) - G.dunte.width / 2

	-- 북쪽에서 통로로 나와 자기 자리로
	local function enter(x: number, z: number, delay: number): Route
		local side = if x < 0 then -1 else 1
		local r = from(T.enter + delay, side * ARCH_X, NORTH_START, SOUTH)
		go(r, side * ARCH_X, 7, MARCH)
		go(r, x, z, MARCH)
		return r
	end
	-- 자기 자리에서 통로로 들어가 북쪽으로
	local function leave(r: Route, delay: number)
		local side = if r.x < 0 then -1 else 1
		stay(r, T.exit + delay, nil, SOUTH)
		go(r, side * ARCH_X, 7, MARCH)
		go(r, side * ARCH_X, NORTH_START, MARCH)
	end

	-- 문 곁 자리: 문짝 닫힘 k일 때. 내내 남쪽(문 쪽)을 보고 두 손을 문짝 북쪽 면에 댄 채 걷는다.
	-- 손이 닿는 자리는 처음에는 문짝 끝, 다 닫히면 경첩에서 HAND_END m. 몸은 그 자리에서 REACH m 북쪽이다
	local REACH, HAND_END, WALL_CLEAR = 0.62, 1.35, 0.25
	local function beside(sx: number, k: number): (number, number, number)
		local a = math.rad(G.openAngle) * (1 - k)
		local r = G.leafWidth + (HAND_END - G.leafWidth) * k
		local x = sx * G.leafWidth - sx * math.cos(a) * r - sx * WALL_CLEAR * (1 - k) -- 처음에는 통로 벽에서 떨어져 선다
		local z = hingeZ - math.sin(a) * r - G.thickness - REACH
		return x, z, SOUTH
	end
	-- 문 움직임(core Ceremony의 smoothstep)을 16칸으로 따라간다. 닫을 때는 앞으로 밀고, 열 때는 그대로 뒷걸음으로 당긴다
	local function followDoor(r: Route, sx: number, t0: number, len: number, closing: boolean)
		stay(r, t0, nil, SOUTH)
		for i = 1, 16 do
			local u = i / 16
			local k = u * u * (3 - 2 * u)
			local x, z, face = beside(sx, if closing then k else 1 - k)
			local last = r.keys[#r.keys]
			last.pose = "push"
			last.silent = true -- 문짝을 따라가는 동안은 발소리를 내지 않는다
			last.face = face
			r.t, r.x, r.z = t0 + len * u, x, z
			table.insert(r.keys, { at = r.t, x = x, z = z, face = face })
		end
	end

	-- 1 호군: 근무 자리(문 앞 가운데, 홍예에서 약 5 m 앞) → 표신 확인 → 문 앞 → 근무 자리
	local r1 = from(0, 0, HOGUN_POST, SOUTH)
	stay(r1, T.check + 1, nil, SOUTH)
	go(r1, 0, 16)
	stay(r1, T.check + 16, nil, NORTH)
	go(r1, 0, 8.6)
	stay(r1, T.close, nil, NORTH)
	stay(r1, T.close + 3, "command", NORTH)
	stay(r1, T.open, nil, NORTH)
	stay(r1, T.open + 3, "command", NORTH)
	stay(r1, T.finish + 1, nil, NORTH)
	go(r1, 0, HOGUN_POST)
	stay(r1, T.exit, nil, SOUTH)

	-- 2 선전관, 3 금군: 줄 → 흙 마당에서 마주 선다 → 문 앞 → 재확인 → 줄
	local function checker(x: number, delay: number, faceIn: number): Route
		local sx = if x < 0 then -1 else 1
		local r = enter(x, LINE_Z, delay)
		stay(r, T.check, nil, SOUTH)
		go(r, sx * 1.3, 14)
		stay(r, T.check + 16, "hold", faceIn)
		go(r, sx * 1.8, 8.6)
		stay(r, T.recheck + 1, nil, NORTH)
		go(r, sx * 0.8, 9.6)
		stay(r, T.recheck + 10, "hold", faceIn)
		go(r, sx * 1.8, 8.6)
		stay(r, T.finish, nil, NORTH)
		go(r, x, LINE_Z)
		return r
	end
	local r2 = checker(-9.2, 1.2, TO_X)
	local r3 = checker(9.2, 1.2, TO_MINUS_X)
	leave(r2, 0.35) -- 같은 줄 앞뒤 사람과 겹치지 않는 값 (5·6번보다 약 1.4 m 앞)
	leave(r3, 0.35)

	-- 4 금루관: 호군 곁. 인정·파루에 징
	local r4 = enter(2.3, 10.5, 2.4)
	stay(r4, T.injeong, nil, SOUTH)
	stay(r4, T.injeong + 3, "strike", SOUTH)
	stay(r4, T.check + 16, nil, SOUTH)
	go(r4, 3.8, 8.6)
	stay(r4, T.paru, nil, NORTH)
	stay(r4, T.paru + 3, "strike", NORTH)
	stay(r4, T.finish + 1, nil, NORTH)
	go(r4, 2.3, 10.5)
	leave(r4, 0.4)

	-- 5 나각수, 6 나발수: 양끝. 신호음 시각(Gaepye NIGHT_SIGNAL)에 맞춰 분다
	local r5 = enter(-11.2, LINE_Z, 0)
	stay(r5, T.injeong + 3, nil, SOUTH)
	stay(r5, T.injeong + 10, "blow", SOUTH)
	stay(r5, T.paru + 3, nil, SOUTH)
	stay(r5, T.paru + 10, "blow", SOUTH)
	leave(r5, 0)
	local r6 = enter(11.2, LINE_Z, 0)
	stay(r6, T.injeong + 7, nil, SOUTH)
	stay(r6, T.injeong + 15, "longblow", SOUTH)
	stay(r6, T.paru + 7, nil, SOUTH)
	stay(r6, T.paru + 15, "longblow", SOUTH)
	leave(r6, 0)

	-- 7·8 파수군: 줄 → 통로를 지나 문 북쪽 → 닫고 → 기다렸다 열고 → 줄
	local function pusher(x: number, delay: number): Route
		local sx = if x < 0 then -1 else 1
		local r = enter(x, LINE_Z, delay)
		stay(r, T.check + 6, nil, SOUTH)
		go(r, sx * 1.4, 7)
		go(r, sx * 1.4, -0.8)
		local tx, tz = beside(sx, 0)
		go(r, tx, tz)
		followDoor(r, sx, T.close, LEN.close, true)
		stay(r, T.open, nil, 0)
		followDoor(r, sx, T.open, LEN.open, false)
		stay(r, T.finish, nil)
		go(r, sx * 1.4, -0.8)
		go(r, sx * 1.4, 7)
		go(r, x, LINE_Z)
		return r
	end
	local r7, r8 = pusher(-3.4, 2.4), pusher(3.4, 3.6)
	leave(r7, 0)
	leave(r8, 0)

	-- 9·10·11 근무 파수군: 홍예 양옆 → 줄 → 근무 자리. 긴 자루 칼을 짚고 선다
	local function dutyMan(post: number, x: number): Route
		local r = from(0, post, 7, SOUTH)
		stay(r, T.enter + 14, nil, SOUTH)
		go(r, x, LINE_Z)
		return r
	end
	local function backToPost(r: Route, post: number)
		stay(r, T.exit + 8, nil, SOUTH)
		go(r, post, 7)
		stay(r, r.t + 1, nil, SOUTH)
	end
	local r9 = dutyMan(POST.left, -5.2)
	backToPost(r9, POST.left)
	local r10 = dutyMan(POST.right, 5.2)
	backToPost(r10, POST.right)
	local r11 = dutyMan(POST.far, -7.1)
	backToPost(r11, POST.far)

	-- 12 파수군: 약시함을 들고 호군 곁으로 (제11화 프레임, sp03. 약시함은 추정). 두 손이 상자로 차서 근무 인원과 나눴다
	local r12 = enter(7.1, LINE_Z, 4.8)
	stay(r12, T.check, nil, SOUTH)
	go(r12, 1, 16.6)
	stay(r12, T.check + 15, nil, TO_MINUS_X)
	go(r12, 7.1, LINE_Z)
	leave(r12, 0.8)

	local BOTH = { armL = true, armR = true }
	local POLE = { armR = true }
	local figures: { Figures.Figure } = {
		{ boxes = hogun(), keys = r1.keys, duty = true, rest = "grip", carry = BOTH },
		{ boxes = seonjeongwan(), keys = r2.keys },
		{ boxes = geumgun(), keys = r3.keys },
		{ boxes = geumrugwan(), keys = r4.keys, rest = "gong", carry = BOTH },
		{ boxes = player(nagak(), true), keys = r5.keys, rest = "nagakRest", carry = { armR = true } }, -- 불지 않을 때는 나각을 가슴 앞에 받쳐 든다
		{ boxes = player(nabal()), keys = r6.keys, rest = "horn", carry = { armR = true } },
		{ boxes = jeongbyeong(M.vestYellow, false), keys = r7.keys },
		{ boxes = jeongbyeong(M.vestYellow, false), keys = r8.keys },
		{ boxes = jeongbyeong(M.vestYellow, true), keys = r9.keys, duty = true, rest = "pole", carry = POLE },
		{ boxes = jeongbyeong(M.vestYellow, true), keys = r10.keys, duty = true, rest = "pole", carry = POLE },
		{ boxes = jeongbyeong(M.vestRed, true), keys = r11.keys, duty = true, rest = "pole", carry = POLE },
		{ boxes = jeongbyeong(M.vestRed, false), keys = r12.keys, rest = "carrybox", carry = BOTH },
	}
	for _, f in figures do
		assert(f.duty or f.keys[#f.keys].at <= T.exit + LEN.exit, "퇴장이 회차 안에 끝나지 않는다")
	end
	for _, p in yaksiham() do
		table.insert(figures[12].boxes, p)
	end

	-- 깃발: 남측면 앞 좌우 8기. 사람 키의 약 2배, 끝에 붉은 술. 색 조합은 사진에서 읽었고 문양은 근거가 없어 넣지 않는다. 배치는 제안값
	local props: { Figures.Box } = {}
	local FLAGS = { { "#C8142E", "#E8B92F" }, { "#E8B92F", "#14151C" }, { "#1E44B8", "#C8142E" }, { "#23336E", "#23336E" } }
	local POLE = 3.4
	for side = -1, 1, 2 do
		for i, x in { 6.2, 8.2, 10.2, 12.2 } do
			local c = FLAGS[i]
			local px = side * x
			local function prop(size: Vector3, at: CFrame, color: string, shape: Enum.PartType?, shadow: boolean?)
				table.insert(props, { joint = "root", size = size, at = at, color = hex(color), shape = shape, shadow = shadow, material = if shape then METAL else nil })
			end
			prop(Vector3.new(0.5, 0.15, 0.5), CFrame.new(px, 0.075, 6.4), "#3A3634") -- 받침
			prop(Vector3.new(POLE, 0.05, 0.05), CFrame.new(px, POLE / 2, 6.4) * UPRIGHT, "#7A3A22", CYL)
			prop(Vector3.new(0.12, 0.3, 0.12), CFrame.new(px, POLE - 0.1, 6.4), "#C8142E") -- 술
			prop(Vector3.new(1.0, 1.3, 0.02), CFrame.new(px - side * 0.52, POLE - 0.95, 6.4), c[1], nil, true) -- 기폭
			prop(Vector3.new(1.0, 0.2, 0.025), CFrame.new(px - side * 0.52, POLE - 1.5, 6.4), c[2]) -- 아래 띠
		end
	end

	return {
		site = site,
		ground = function(_x: number, z: number): number
			if z <= D.wall.south and z >= D.wall.north then
				return 0.02 -- 통로 판석 윗면 (server Yukchuk)
			end
			return Plaza.floor(z)
		end,
		figures = figures,
		props = props,
	}
end
