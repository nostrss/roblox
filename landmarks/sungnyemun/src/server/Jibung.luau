--!strict
-- 지붕 곡면(기와골 포함) 메시를 놓는다. 메시는 tools/jibung_obj.luau 로 굽고, 경계 상자는 Shared.JibungMeshes (생성 파일).
-- 앞면(남)·옆면(동) 메시를 하나씩 올리고 뒷면·서쪽 면은 Y축 180°로 돌려 쓴다. 원점 = 문루 중심 지면.
-- 16번: 막새·마루(용마루·추녀마루·연마루)·잡상·취두·용두·토수를 단순 형상으로 얹는다 (ADR 0005, 데이터 Shared.Jibung.deco).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local J = require(ReplicatedStorage.Shared.Jibung)
local M = require(ReplicatedStorage.Shared.JibungMeshes)
local setup = require(script.Parent.Member)
local RoofSplit = require(ReplicatedStorage.Core.RoofSplit)
local Split = require(ReplicatedStorage.Shared.RoofSplit)

local S = Units.studs(1)
local Q = { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } -- 동남 기준 점을 네 귀로 (x, z 부호)

-- 단위 m·레벨 → 스터드 월드
local function W(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y - D.level.ground, z) * S
end

local function interp(t: { { number } }, x: number): number
	if x <= t[1][1] then
		return t[1][2]
	end
	for i = 2, #t do
		local p, q = t[i - 1], t[i]
		if x <= q[1] then
			return p[2] + (q[2] - p[2]) * (x - p[1]) / (q[1] - p[1])
		end
	end
	return t[#t][2]
end

local function half(bays: { number }): number
	local t = 0
	for _, b in bays do
		t += b
	end
	return t / 2
end

-- 지금 짓는 층 (지붕 분해 SplitStory). 층마다 도는 곳에서 바꾼다
local story: RoofSplit.Story = "lower"
local function storyOf(name: string): RoofSplit.Story -- "LowerJibungFront" 같은 이름의 앞머리로
	return if string.sub(name, 1, 5) == "Lower" then "lower" else "upper"
end

local function part(parent: Instance, name: string, cf: CFrame, size: Vector3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	setup(p, name == "Maru") -- 재질·색은 이름으로 Shared.Palette. 마루 몸체는 지붕 위를 걸을 때 딛고 넘는다
	RoofSplit.mark(p, story, Split)
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- 윗면이 A → B 선(레벨 m)에 닿고 아래로 h 내려오는 띠 (마루 몸체)
local function band(parent: Instance, name: string, A: Vector3, B: Vector3, h: number, w: number)
	local a, b = W(A.X, A.Y, A.Z), W(B.X, B.Y, B.Z)
	local d = (b - a).Unit
	local side = d:Cross(Vector3.yAxis).Unit
	local up = side:Cross(d).Unit
	part(parent, name, CFrame.fromMatrix((a + b) / 2 - up * (h * S / 2), d, up, side), Vector3.new((b - a).Magnitude, h * S, w * S))
end

-- 마루 하나: 점 { x, 윗면, z, 밑면 } 줄을 따라 양성 몸체 + 위 수키와 줄
local function maru(parent: Instance, pts: { { number } }, w: number, cap: number)
	for i = 1, #pts - 1 do
		local p, q = pts[i], pts[i + 1]
		local A, B = Vector3.new(p[1], p[2], p[3]), Vector3.new(q[1], q[2], q[3])
		local h = math.max(p[2] - p[4], q[2] - q[4]) + 0.1 -- 지붕 속으로 0.1 묻음
		band(parent, "Maru", A, B, h, w)
		band(parent, "MaruCap", A + Vector3.yAxis * 0.06, B + Vector3.yAxis * 0.06, 0.06, cap)
	end
end

-- 마루 위 블록 장식 (잡상·용두): 동남 마루 x 자리, 바닥 = 마루 윗면, 마루 방향(평면 대각선)으로 눕힌다
local function onHip(parent: Instance, name: string, x: number, top: { { number } }, size: { number }): { Part }
	local base = interp(top, x)
	local made = {}
	for _, q in Q do
		local sx, sz = q[1], q[2]
		local pos = W(sx * x, base + size[3] / 2, sz * (x - 7.388))
		local d = Vector3.new(sx, 0, sz).Unit
		local p = part(parent, name, CFrame.lookAt(pos, pos + d), Vector3.new(size[2], size[3], size[1]) * S)
		p.CastShadow = false
		table.insert(made, p)
	end
	return made
end

local function deco(root: Model)
	local K = J.deco
	local maruM, maksaeM, jangsikM = Instance.new("Model"), Instance.new("Model"), Instance.new("Model")
	maruM.Name, maksaeM.Name, jangsikM.Name = "Maru", "Maksae", "Jangsik"

	-- 막새: 굽기 도구가 적은 처마 끝 자리. 앞면은 바깥 = +Z, 옆면은 +X. 뒷면·서쪽은 180° 돌림
	-- ponytail: 처마 곡선의 평면 꺾임(안허리)·앙곡 기울기는 무시하고 면 바깥 방향으로만 세운다
	local su, am = K.maksae.su, K.maksae.am
	for name, b in M :: { [string]: any } do
		local n0 = if string.find(name, "Front") then Vector3.zAxis else Vector3.xAxis
		story = storyOf(name)
		for _, turn in { 1, -1 } do
			local n = n0 * turn
			local t = Vector3.yAxis:Cross(n)
			for _, q in b.eave do
				local edge = W(q[1] * turn, q[2], q[3] * turn)
				if q[4] == 0 then
					local pos = edge + n * (su.thick / 2) * S - Vector3.yAxis * (su.dia / 2) * S
					part(maksaeM, "Sumaksae", CFrame.fromMatrix(pos, n, Vector3.yAxis), Vector3.new(su.thick, su.dia, su.dia) * S, Enum.PartType.Cylinder)
				else
					local pos = edge + n * (am.thick / 2) * S - Vector3.yAxis * (am.height / 2) * S
					part(maksaeM, "Ammaksae", CFrame.fromMatrix(pos, t, Vector3.yAxis), Vector3.new(am.width, am.height, am.thick) * S)
				end
			end
		end
	end

	-- 추녀마루: 밑면 = 지붕 추녀마루 선(JibungMeshes …Front.hip), 윗면 = top 표. 표의 x 자리도 마디로 넣어 단(용두)이 살게 한다
	for _, layer in { "Lower", "Upper" } do
		local L = K[string.lower(layer)]
		story = storyOf(layer)
		local hip = (M :: any)[layer .. "JibungFront"].hip
		local xs = {}
		for _, h in hip do
			table.insert(xs, h[1])
		end
		for _, t in L.hipRidge.top do
			if t[1] > hip[1][1] and t[1] < hip[#hip][1] then
				table.insert(xs, t[1])
			end
		end
		table.sort(xs)
		local roofAt = {}
		for _, h in hip do
			table.insert(roofAt, { h[1], h[2] })
		end
		local pts = {}
		for _, x in xs do
			table.insert(pts, { x, interp(L.hipRidge.top, x), x - 7.388, interp(roofAt, x) })
		end
		for _, q in Q do
			local m = {}
			for _, p in pts do
				table.insert(m, { q[1] * p[1], p[2], q[2] * p[3], p[4] })
			end
			maru(maruM, m, L.hipRidge.width, L.hipRidge.cap)
		end
		onHip(jangsikM, "Yongdu", L.yongdu.x, L.hipRidge.top, { L.yongdu.length, L.yongdu.width, L.yongdu.height })
		for i, x in L.japsang.x do
			for _, p in onHip(jangsikM, "Japsang", x, L.hipRidge.top, L.japsang.size) do
				p:SetAttribute("JapsangName", K.japsangNames[i])
			end
		end
	end

	-- 용마루: 곡 = 끝이 올라가는 2차 곡선. 밑면 = 지붕 꼭대기(상층 추녀마루 선 첫 점)
	local R = K.ridge
	story = "upper"
	local roofTop = M.UpperJibungFront.hip[1][2]
	local pts = {}
	for i = -8, 8 do
		local x = R.half * i / 8
		table.insert(pts, { x, R.centerTop + (R.endTop - R.centerTop) * (x / R.half) ^ 2, 0, roofTop })
	end
	maru(maruM, pts, R.width, R.cap)
	local C = K.chwidu
	for _, sx in { 1, -1 } do
		part(jangsikM, "Chwidu", CFrame.new(W(sx * (C.x0 + C.x1) / 2, (C.top + C.bottom) / 2, 0)),
			Vector3.new(C.x1 - C.x0, C.top - C.bottom, C.width) * S)
	end

	-- 연마루: 하층 지붕 위 끝 네 변. 띠 안쪽 면 = 상층 기둥열 + inner
	local Y = K.lower.yeonmaru
	story = "lower"
	local hx, hz = half(D.upperBays) + Y.inner, half(D.upperSideBays) + Y.inner
	local h = Y.top - Y.bottom
	for _, s in { 1, -1 } do
		part(maruM, "Yeonmaru", CFrame.new(W(0, (Y.top + Y.bottom) / 2, s * (hz + Y.thick / 2))),
			Vector3.new(2 * (hx + Y.thick), h, Y.thick) * S)
		part(maruM, "Yeonmaru", CFrame.new(W(s * (hx + Y.thick / 2), (Y.top + Y.bottom) / 2, 0)),
			Vector3.new(Y.thick, h, 2 * hz) * S)
	end

	-- 토수: 사래 끝 촉에 끼운다. 사래 메시의 길이 축(+X) 끝 = 사래 끝 (server/Cheoma profileAt)
	local cheoma = workspace:FindFirstChild("Cheoma")
	for _, layer in { "Lower", "Upper" } do
		local T = K[string.lower(layer)].tosu
		story = storyOf(layer)
		local model = cheoma and cheoma:FindFirstChild(layer)
		for _, p in if model then model:GetDescendants() else {} do
			if p:IsA("BasePart") and p.Name == "Sarae" then
				local r = p.CFrame.RightVector
				local tip = p.CFrame.Position + r * p.Size.X / 2
				part(jangsikM, "Tosu", CFrame.fromMatrix(tip + r * (T.length / 2 - K.tosuTenon) * S, r, p.CFrame.UpVector),
					Vector3.new(T.length, T.height, T.width) * S)
			end
		end
	end

	maruM.Parent, maksaeM.Parent, jangsikM.Parent = root, root, root
end

-- 세 점(스터드)을 지나는 면이 윗면인 두께 thick 삼각 판 = 쐐기 두 개
local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, thick: number)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then -- 가장 긴 변을 b–c로
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-3 then
		return -- 넓이 없는 삼각형
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local down = (if right.Y > 0 then -right else right) * thick / 2 -- 판 윗면이 세 점 면에 오게
	local function wedge(mid: Vector3, x: Vector3, z: Vector3, edge: Vector3)
		local p = Instance.new("WedgePart")
		p.Name = "Walk"
		p.Anchored = true
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(thick, height, math.abs(edge:Dot(back)))
		p.CFrame = CFrame.fromMatrix(mid + down, x, up, z)
		p.Parent = parent
	end
	wedge((a + b) / 2, right, back, ab)
	wedge((a + c) / 2, -right, -back, ac)
end

-- 지붕 위 걷기: 기와 메시는 충돌이 없다(MemberMeshes Box, Member 주석). 층마다 네 면에 보이지 않는 삼각 판을 깐다.
-- 점은 메시 굽기 자료에서: 위 끝·모서리 = 추녀마루 선(hip) 처음·끝, 처마 = 단면 처마 끝 높이, 처마가 곧은(앙곡·안허리 없는) 구간 끝.
-- ponytail: 면을 평면 삼각형 몇 개로 줄여 기와골 요철·처마 곡은 무시한다 (기와 등보다 최대 약 0.15 m 낮음). 발이 묻어 보이면 삼각형을 늘린다
-- 저장된 Jibung이 있어도 짓도록 따로 된 루트 Model (init 건물 자리 목록에 있다)
local function walk()
	local folder = Instance.new("Model")
	folder.Name = "JibungWalk"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 착지·걷기는 클라이언트 물리라 늘 내려가 있어야 한다
	local thick = Units.studs(1)
	-- 처마 끝 점 중 가장 바깥이 곧은 구간의 끝: 바깥 좌표(out)가 최소인 점들의 along 최대값
	local function flat(eave: { { number } }, out: number, along: number): (number, number)
		local lo = math.huge
		for _, q in eave do
			lo = math.min(lo, q[out])
		end
		local ext = 0
		for _, q in eave do
			if q[out] < lo + 1e-3 then
				ext = math.max(ext, math.abs(q[along]))
			end
		end
		return lo, ext
	end
	for _, layer in { "Lower", "Upper" } do
		local front, side = (M :: any)[layer .. "JibungFront"], (M :: any)[layer .. "JibungSide"]
		local prof = J[string.lower(layer)].profile
		local y = prof[#prof][2]
		local t, c = front.hip[1], front.hip[#front.hip]
		local fz, fx = flat(front.eave, 3, 1)
		local sx, sz = flat(side.eave, 1, 3)
		local tris = {
			-- 앞면(+Z)
			{ { -t[1], t[2], t[3] }, { t[1], t[2], t[3] }, { fx, y, fz } },
			{ { -t[1], t[2], t[3] }, { fx, y, fz }, { -fx, y, fz } },
			{ { t[1], t[2], t[3] }, { c[1], c[2], c[3] }, { fx, y, fz } },
			{ { -t[1], t[2], t[3] }, { -fx, y, fz }, { -c[1], c[2], c[3] } },
			-- 옆면(+X). 상층은 위 끝이 한 점이라 셋째 삼각형이 없어진다
			{ { t[1], t[2], t[3] }, { c[1], c[2], c[3] }, { sx, y, sz } },
			{ { t[1], t[2], t[3] }, { sx, y, sz }, { sx, y, -sz } },
			{ { t[1], t[2], t[3] }, { sx, y, -sz }, { t[1], t[2], -t[3] } },
			{ { t[1], t[2], -t[3] }, { sx, y, -sz }, { c[1], c[2], -c[3] } },
		}
		for _, turn in { 1, -1 } do -- 뒷면·서쪽 면은 180° 돌림 (x, z 부호)
			for _, tri in tris do
				local v = {}
				for i, q in tri do
					v[i] = W(turn * q[1], q[2], turn * q[3])
				end
				triangle(folder, v[1], v[2], v[3], thick)
			end
		end
	end
	folder.Parent = workspace
end

return function()
	if not workspace:FindFirstChild("JibungWalk") then
		walk()
	end
	if workspace:FindFirstChild("Jibung") then
		return
	end
	local folder = CollectionService:GetTagged(Tags.MEMBER_MESHES)[1]
	local root = Instance.new("Model")
	root.Name = "Jibung"
	root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 지붕 분해가 클라이언트에서 부재 전체를 옮기므로 스트리밍으로 빠지지 않게
	for name, b in M :: { [string]: any } do
		local src = folder and folder:FindFirstChild(name)
		if not (src and src:IsA("MeshPart")) then
			warn(`지붕: MemberMeshes에 {name}이 없어 건너뜀 (landmarks/sungnyemun/meshes/{name}.obj 업로드 필요)`)
			continue
		end
		local cf = CFrame.new(Vector3.new(b.center[1], b.center[2] - D.level.ground, b.center[3]) * S)
		for _, turn in { 0, math.pi } do
			local p = (src :: MeshPart):Clone()
			p.Name = name
			setup(p)
			RoofSplit.mark(p, storyOf(name), Split)
			-- 크기는 임포트된 그대로 둔다 (Size를 다시 넣으면 임포터 경계 상자와 조금만 달라도 메시 전체가 늘어나 추녀마루가 어긋난다)
			p.CFrame = CFrame.Angles(0, turn, 0) * cf
			p.Parent = root
		end
	end
	deco(root)
	root.Parent = workspace
end
