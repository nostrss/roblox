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
local function box(joint: Joint, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: Color3, shadow: boolean?): Figures.Box
	return { joint = joint, size = Vector3.new(sx, sy, sz), at = CFrame.new(x, y, z), color = color, shadow = shadow }
end
local function rod(joint: Joint, length: number, width: number, x: number, y: number, z: number, color: Color3): Figures.Box
	return { joint = joint, size = Vector3.new(length, width, width), at = CFrame.new(x, y, z) * UPRIGHT, color = color, shape = CYL, material = METAL }
end

-- 복식 메시: Studio AI 메시 생성으로 만들었다 (S46). 사진 픽셀은 없고, 프롬프트에 사진에서 읽은 색과 형태만 적었다. 사람 얼굴은 가상이다.
-- { mesh, texture, yaw } yaw = 메시 앞이 인물 앞(+Z)을 보게 돌리는 각. 생성 메시는 앞이 −Z다 (Play 확인)
local M = {
	head = { 73698535879637, 101211243302770, 180 },
	jeollip = { 126342459365549, 116313543625603, 180 },
	samo = { 111329661539451, 138499598635680, 180 },
	hwangnip = { 113461766938981, 113968085371673, 180 },
	tallHat = { 95826553741572, 95695938878583, 180 },
	vestYellow = { 96192919519974, 121443490045288, 180 },
	vestRed = { 96087331470781, 95097345748557, 180 },
	robeHogun = { 98887586067697, 104207938350278, 180 },
	robePlayer = { 96476874038065, 105491455510964, 180 },
	robeSeonjeon = { 128169318337497, 120343294687032, 180 },
	robeGeumru = { 116640893349499, 72122075937487, 180 },
	armPurple = { 124968232742241, 125575726064405, 180 },
	armBlue = { 126225144238762, 108633295925143, 180 },
	armTeal = { 79972167450184, 76580250875662, 180 },
	armYellow = { 135660737297744, 105776217702940, 180 },
	skirt = { 84995893448823, 119103880034870, 180 },
	boot = { 94620698467497, 81450217428794, 180 },
	woldo = { 119464657900617, 118060206453782, 180 },
}
-- 메시를 받지 못했을 때 상자로 지을 때의 색
local FALLBACK = hex("#6E6A72")

-- 메시 한 조각: 크기 (m), 가운데 자리 (m)
local function mesh(joint: Joint, m: { number }, w: number, h: number, d: number, x: number, y: number, z: number, shadow: boolean?): Figures.Box
	return {
		joint = joint, size = Vector3.new(w, h, d), at = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(m[3]), 0),
		color = FALLBACK, shadow = shadow, mesh = m[1], texture = m[2],
	}
end

export type Dress = {
	torso: { number },
	arm: { number },
	hat: Figures.Box,
	skirt: boolean?, -- 앞자락 아래 치마
	torsoHeight: number, -- 어깨(y 1.42)에서 앞자락 끝까지 (m)
	torsoDepth: number,
}

-- 몸 한 벌: 약 5스터드 = 1.7 m (머리 꼭대기). 조각마다 core Figures의 관절 하나를 따라 움직인다
local function body(d: Dress): { Figures.Box }
	local b: { Figures.Box } = {
		mesh("legL", M.boot, 0.17, 0.46, 0.3, 0.1, 0.23, 0.02),
		mesh("legR", M.boot, 0.17, 0.46, 0.3, -0.1, 0.23, 0.02),
		mesh("upper", d.torso, 0.56, d.torsoHeight, d.torsoDepth, 0, 1.42 - d.torsoHeight / 2, 0, true),
		mesh("armL", d.arm, 0.17, 0.64, 0.17, 0.25, 1.05, 0),
		mesh("armR", d.arm, 0.17, 0.64, 0.17, -0.25, 1.05, 0),
		mesh("upper", M.head, 0.235, 0.345, 0.22, 0, 1.54, 0.01),
		d.hat,
	}
	if d.skirt then
		table.insert(b, mesh("root", M.skirt, 0.44, 0.64, 0.38, 0, 0.53, 0))
	end
	return b
end

local JEOLLIP = mesh("upper", M.jeollip, 0.56, 0.25, 0.56, 0, 1.78, 0)
-- 전립의 상모와 패영 (sa03): 메시에 없는 부분을 얹는다
local function jeollipTrim(b: { Figures.Box })
	local red, amber = hex("#C8142E"), hex("#B5622A")
	local function ball(d: number, x: number, y: number, z: number, color: Color3): Figures.Box
		return { joint = "upper", size = Vector3.new(d, d, d), at = CFrame.new(x, y, z), color = color, shape = Enum.PartType.Ball, material = METAL }
	end
	table.insert(b, rod("upper", 0.26, 0.05, 0.2, 1.52, -0.05, red)) -- 상모 술
	table.insert(b, ball(0.06, 0.2, 1.66, -0.05, red))
	for side = -1, 1, 2 do
		for i = 0, 5 do
			local k = i / 5
			table.insert(b, ball(0.028, side * (0.14 - 0.08 * k), 1.6 - 0.32 * k, 0.04 + 0.1 * k, amber))
		end
	end
end
local function hogun(): { Figures.Box } -- 호군 (sa02)
	local b = body({ torso = M.robeHogun, arm = M.armPurple, hat = JEOLLIP, torsoHeight = 1.22, torsoDepth = 0.4 })
	jeollipTrim(b)
	table.insert(b, { joint = "armR", size = Vector3.new(0.75, 0.03, 0.03), at = CFrame.new(-0.3, 0.74, 0.28) * CFrame.Angles(0, math.pi / 2, 0.15), color = hex("#C4122C"), shape = CYL, material = METAL }) -- 등채
	table.insert(b, { joint = "root", size = Vector3.new(0.85, 0.06, 0.05), at = CFrame.new(0.3, 0.72, -0.05) * CFrame.Angles(0, math.pi / 2, 0.9), color = C.black, shape = CYL, material = METAL }) -- 환도
	return b
end

local function jeongbyeong(torso: { number }, spear: boolean): { Figures.Box } -- 파수군 (sa03 / 홍 전복 sg05·sp04)
	local b = body({ torso = torso, arm = M.armPurple, hat = JEOLLIP, skirt = true, torsoHeight = 1.0, torsoDepth = 0.34 })
	jeollipTrim(b)
	if spear then
		table.insert(b, mesh("armR", M.woldo, 0.2, 2.5, 0.1, -0.34, 1.25, 0.1)) -- 긴 자루 칼 (sa03·sg05)
	end
	return b
end

local function geumrugwan(): { Figures.Box } -- 금루관 후보 (sp03·sp07, 역할 추정)
	local b = body({ torso = M.robeGeumru, arm = M.armTeal, hat = mesh("upper", M.tallHat, 0.3, 0.33, 0.3, 0, 1.84, 0), torsoHeight = 1.22, torsoDepth = 0.4 })
	table.insert(b, { joint = "armL", size = Vector3.new(0.03, 0.36, 0.36), at = CFrame.new(0.3, 0.72, 0.16) * CFrame.Angles(0, 0, math.pi / 2), color = hex("#8C7A3C"), shape = CYL, material = METAL }) -- 징
	table.insert(b, rod("armR", 0.34, 0.03, -0.3, 0.68, 0.06, hex("#5A2E22"))) -- 징채
	return b
end

local function seonjeongwan(): { Figures.Box } -- 선전관 후보 (sp03, 역할 추정)
	local b = body({ torso = M.robeSeonjeon, arm = M.armBlue, hat = mesh("upper", M.samo, 0.46, 0.18, 0.46, 0, 1.76, 0), torsoHeight = 1.25, torsoDepth = 0.3 })
	table.insert(b, box("armR", 0.1, 0.16, 0.02, -0.28, 0.66, 0.09, hex("#5A2E22"))) -- 표신 (모양은 근사)
	return b
end
local function geumgun(): { Figures.Box } -- 금군: 복식 어긋남은 머리 주석
	local b = jeongbyeong(M.vestYellow, false)
	table.insert(b, box("armR", 0.1, 0.16, 0.02, -0.28, 0.66, 0.09, hex("#5A2E22"))) -- 부험 (모양은 근사)
	return b
end

local function player(instrument: { Figures.Box }): { Figures.Box } -- 나각수·나발수 후보 (mh22 도열, 악기 배정 추정)
	local b = body({ torso = M.robePlayer, arm = M.armYellow, hat = mesh("upper", M.hwangnip, 0.52, 0.2, 0.52, 0, 1.76, 0), torsoHeight = 1.22, torsoDepth = 0.4 })
	for _, i in instrument do
		table.insert(b, i)
	end
	return b
end
-- 나각 (official/sp02에서 형태만: 입에 댄 좁은 끝에서 넓은 몸통으로 굵어지고 손이 몸통 쪽을 받친다. sp02 배경은 숭례문이 아니다).
-- 팔이 한 토막이라 손이 입에서 멀어 실물보다 길다. 근사: 길이 0.63 m, 지름 0.2 m
local function nagak(): { Figures.Box }
	local arm = Figures.armFrame("armR", "blow")
	local mouth = Vector3.new(0, 1.52, 0.14)
	local dir = (arm * Vector3.new(-0.3, 0.78, 0) - mouth).Unit
	local shell = hex("#D8B08C")
	local function piece(from_: number, to: number, width: number, color: Color3): Figures.Box
		local c = mouth + dir * (from_ + to) / 2
		local at = arm:Inverse() * CFrame.lookAt(c, c + dir) * CFrame.Angles(0, math.pi / 2, 0)
		return { joint = "armR", size = Vector3.new(to - from_, width, width), at = at, color = color, shape = CYL, material = METAL }
	end
	return { piece(0, 0.3, 0.07, shell), piece(0.27, 0.63, 0.2, shell), piece(0.4, 0.43, 0.21, hex("#A8744F")) }
end
local NABAL = {
	rod("armR", 1.05, 0.04, -0.3, 0.68, 0.1, hex("#C9A227")),
	rod("armR", 0.14, 0.13, -0.3, 0.16, 0.1, hex("#C9A227")), -- 나팔 끝
}

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
	stay(r1, T.check + 16, "stand", NORTH)
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

	-- 9·10·11 근무 파수군: 홍예 양옆 → 줄 → 근무 자리. 11은 약시함을 들고 호군 곁으로 (제11화 프레임, 약시함은 추정)
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
	stay(r11, T.check, nil, SOUTH)
	go(r11, -1, 16.6)
	stay(r11, T.check + 15, nil, TO_X)
	go(r11, -7.1, LINE_Z)
	backToPost(r11, POST.far)

	-- 12 파수군
	local r12 = enter(7.1, LINE_Z, 4.8)
	leave(r12, 0.8)

	local figures: { Figures.Figure } = {
		{ boxes = hogun(), keys = r1.keys, duty = true, carry = { armR = true } },
		{ boxes = seonjeongwan(), keys = r2.keys },
		{ boxes = geumgun(), keys = r3.keys },
		{ boxes = geumrugwan(), keys = r4.keys, carry = { armL = true } },
		{ boxes = player(nagak()), keys = r5.keys, carry = { armR = true } },
		{ boxes = player(NABAL), keys = r6.keys, rest = "horn", carry = { armR = true } },
		{ boxes = jeongbyeong(M.vestYellow, false), keys = r7.keys },
		{ boxes = jeongbyeong(M.vestYellow, false), keys = r8.keys },
		{ boxes = jeongbyeong(M.vestYellow, true), keys = r9.keys, duty = true, carry = { armR = true } },
		{ boxes = jeongbyeong(M.vestYellow, true), keys = r10.keys, duty = true, carry = { armR = true } },
		{ boxes = jeongbyeong(M.vestRed, true), keys = r11.keys, duty = true, rest = "carrybox", carry = { armL = true, armR = true } },
		{ boxes = jeongbyeong(M.vestRed, true), keys = r12.keys, carry = { armR = true } },
	}
	for _, f in figures do
		assert(f.duty or f.keys[#f.keys].at <= T.exit + LEN.exit, "퇴장이 회차 안에 끝나지 않는다")
	end
	-- 약시함: 11번 왼손 (모양·색은 근사, 프레임의 짙은 적갈 상자)
	table.insert(figures[11].boxes, box("armL", 0.24, 0.12, 0.16, 0.2, 0.74, 0.1, hex("#5A2E22")))

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
