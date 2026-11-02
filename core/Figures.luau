--!strict
-- 인물: 상자로 지은 사람들이 시간표(열쇠 자리)를 따라 걷고 선다. 클라이언트 전용, Place가 복식·자리·시간만 넘긴다.
-- 모든 자세는 흐른 시간 t 하나로 정해진다 → 도중 접속해도 같은 장면이고, 저장할 상태가 없다.
-- Humanoid·Animator를 쓰지 않는다: 앵커 파트를 BulkMoveTo로 옮기면 물리·상태 기계 비용이 없다(비교 측정은 PR 본문). 서 있는 인물은 옮기지 않는다.
-- 사람과 부딪히지 않는다: 부딪힘·조회·닿기를 모두 끈다.
local RunService = game:GetService("RunService")

local Meshes = require(script.Parent.Meshes)
local Units = require(script.Parent.Units)

export type Joint = "root" | "upper" | "legL" | "legR" | "armL" | "armR"

-- 상자 하나 (m). at = 발바닥 가운데 기준 자리(앞 = +Z, 왼쪽 = +X, 팔다리를 내린 자세). 그 관절과 함께 움직인다
export type Box = {
	joint: Joint,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	shadow: boolean?,
	mesh: number?, -- 메시 에셋 ID. 있으면 상자 대신 이 메시로 짓는다 (serveMeshes가 서버에서 미리 받아 둔다)
	texture: number?, -- 메시 그림 에셋 ID
	tint: boolean?, -- 그림을 빼고 color로 칠한다 (같은 메시를 다른 색으로 쓸 때)
}

-- 열쇠 자리: at초에 (x, z) m(건물 축). 다음 열쇠까지 pose 자세로 걷거나 서 있는다.
-- face = 바라보는 쪽(rad, 0 = 정면 +Z). 없으면 걷는 쪽을 보고, 서 있으면 앞서 보던 쪽 그대로
export type Key = { at: number, x: number, z: number, pose: string?, face: number?, silent: boolean? } -- silent: 이 구간 이동은 걷기로 치지 않는다 (발소리 없음)

export type Figure = {
	boxes: { Box },
	keys: { Key },
	duty: boolean?, -- 회차 밖에도 서 있다 (마지막 열쇠 자리). 아니면 첫 열쇠 전과 마지막 열쇠 뒤에는 보이지 않고, 그 앞뒤로 서서히 나타나고 사라진다
	rest: string?, -- pose가 없을 때의 자세. 없으면 "stand"
	carry: { armL: boolean?, armR: boolean? }?, -- 걸을 때 흔들지 않는 팔 (물건을 든 쪽)
}

export type Config = {
	site: CFrame, -- 건물 축 → 세계 (스터드)
	ground: (x: number, z: number) -> number, -- 지면 높이 m
	figures: { Figure },
	props: { Box }?, -- 움직이지 않는 기물. at은 건물 축 m (joint 무시)
}

-- 자세: 팔 { 앞뒤(X), 안팎(Z) } rad, lean = 허리 위 앞으로 기울기. 차분하게 잡았다 (근사: 눈으로 정함)
type Pose = { armL: { number }, armR: { number }, lean: number }
local POSES: { [string]: Pose } = {
	stand = { armL = { 0, 0.07 }, armR = { 0, -0.07 }, lean = 0 }, -- 팔을 몸에서 살짝 뗀다 (붙이면 차렷 인형처럼 보인다)
	push = { armL = { -1.35, -0.12 }, armR = { -1.35, 0.12 }, lean = 0.12 }, -- 문 밀기·당기기
	hold = { armL = { -1.05, -0.4 }, armR = { -1.05, 0.4 }, lean = 0 }, -- 두 손을 가슴 앞에 (표신)
	carrybox = { armL = { -1, -0.28 }, armR = { -1, 0.28 }, lean = 0 }, -- 두 손으로 상자를 받쳐 든다
	grip = { armL = { -0.6, 0 }, armR = { -0.5, 0 }, lean = 0 }, -- 두 손으로 등채를 허리 앞에 가로로 든다 (왼손이 조금 높다)
	command = { armL = { -0.95, 0 }, armR = { -0.85, 0 }, lean = 0 }, -- 등채를 든 채 두 손을 올린 지휘. grip과 두 팔 차이가 같아 등채가 손에서 떨어지지 않는다
	pole = { armL = { 0, 0.07 }, armR = { -0.3, -0.3 }, lean = 0 }, -- 땅을 짚은 장대를 팔을 벌려 쥔다
	gong = { armL = { -0.4, 0 }, armR = { -0.15, -0.05 }, lean = 0 }, -- 왼손에 징을 늘어뜨리고 선 자세
	strike = { armL = { -0.4, 0 }, armR = { -0.75, 0.6 }, lean = 0 }, -- 징 치기: 왼손은 그대로, 오른손 채가 징에 닿는다
	blow = { armL = { -0.1, 0.07 }, armR = { -1.85, 0.12 }, lean = -0.04 }, -- 나각: 오른손으로 입에서 나온 나각을 받치고 왼팔은 내린다 (들면 가슴을 가로질렀다)
	nagakRest = { armL = { 0, 0.07 }, armR = { -1.15, 0.45 }, lean = 0 }, -- 나각을 가슴 앞에 받쳐 들고 선 자세
	horn = { armL = { 0, 0 }, armR = { -0.55, 0.05 }, lean = 0 }, -- 나발을 들고 선 자세
	longblow = { armL = { -0.1, 0.07 }, armR = { -1.65, 0.4 }, lean = -0.04 }, -- 나발 불기: 오른손으로 받치고 왼팔은 내린다
}

local BLEND = 0.5 -- 자세가 바뀌는 시간(초)
local FADE = 1.5 -- 첫·마지막 열쇠에서 나타나고 사라지는 시간(초). 회차 밖에 없는 인물만
local TURN = 0.6 -- 방향이 바뀌는 시간(초)
local EASE = 0.3 -- 걸음이 시작·끝나는 시간(초)
local STRIDE = 1.5 -- 걸음 한 주기 거리(m)
local GAIT_LEG = 0.38 -- 다리 흔들림(rad). 행진이라 작게
local GAIT_ARM = 0.22 -- 팔 흔들림(rad)
local GAIT_BOB = 0.025 -- 걸을 때 몸이 오르내리는 높이(m)
local GAIT_TWIST = 0.07 -- 걸을 때 상체가 다리와 반대로 도는 각(rad)

local HIP = { x = 0.1, y = 0.82 } -- 엉덩이 관절 (m)
local SHOULDER = { x = 0.27, y = 1.36 } -- 어깨 관절 (m)
local S = Units.studs(1)

local Figures = {}

-- 자세의 팔 변환 (m). 든 물건을 그 자세에서 놓일 자리에 맞출 때 Place 데이터가 쓴다
function Figures.armFrame(side: "armL" | "armR", pose: string): CFrame
	local a = (POSES[pose] :: any)[side] :: { number }
	local pv = CFrame.new(if side == "armL" then SHOULDER.x else -SHOULDER.x, SHOULDER.y, 0)
	return pv * CFrame.Angles(a[1], 0, a[2]) * pv:Inverse()
end

type Seg = {
	at: number, t1: number, x: number, z: number, nx: number, nz: number,
	silent: boolean?, len: number, s0: number, yaw: number, prevYaw: number, pose: Pose, prevPose: Pose, moving: boolean, prevMoving: boolean, nextMoving: boolean,
}

local function angleLerp(a: number, b: number, k: number): number
	return a + ((b - a + math.pi) % (2 * math.pi) - math.pi) * k
end

-- 열쇠 → 구간. 마지막 열쇠는 끝없는 서 있기 구간이 된다
local function segments(figure: Figure): { Seg }
	local keys = figure.keys
	local out: { Seg } = {}
	local yaw = keys[1].face or 0
	local s = 0
	local prevPose = POSES[figure.rest or "stand"]
	local prevMoving = false
	for i, k in keys do
		local n = keys[i + 1]
		local nx, nz = if n then n.x else k.x, if n then n.z else k.z
		local dx, dz = nx - k.x, nz - k.z
		local len = math.sqrt(dx * dx + dz * dz)
		local moving = len > 1e-3
		local target = k.face or (if moving then math.atan2(dx, dz) else yaw)
		local pose = POSES[k.pose or figure.rest or "stand"]
		assert(pose, `없는 자세: {k.pose}`)
		assert(not n or n.at >= k.at, "열쇠 시각이 거꾸로다")
		local seg: Seg = {
			at = k.at, t1 = if n then n.at else math.huge, x = k.x, z = k.z, nx = nx, nz = nz,
			silent = k.silent,
			len = len, s0 = s, yaw = target, prevYaw = yaw, pose = pose, prevPose = prevPose,
			moving = moving, prevMoving = prevMoving, nextMoving = false,
		}
		if out[i - 1] then
			out[i - 1].nextMoving = moving
		end
		out[i] = seg
		s += len
		yaw = target
		prevPose = pose
		prevMoving = moving
	end
	return out
end

-- 흐른 시간 t의 상태: x, z, yaw, 자세 앞뒤 섞임 값들, 걸음(위상 라디안, 세기), 움직이는 중인가
export type State = { seg: any, x: number, z: number, yaw: number, from: Pose, to: Pose, mix: number, phase: number, gait: number, still: boolean }
local function stateAt(segs: { Seg }, t: number): State
	local seg = segs[1]
	for _, s in segs do
		if t >= s.at then
			seg = s
		else
			break
		end
	end
	local dt = t - seg.at
	local u = if seg.moving then math.clamp(dt / (seg.t1 - seg.at), 0, 1) else 0
	local gait = 0
	if seg.moving then
		gait = 1
		if not seg.prevMoving then
			gait = math.min(gait, dt / EASE)
		end
		if not seg.nextMoving then
			gait = math.min(gait, (seg.t1 - t) / EASE)
		end
		gait = math.clamp(gait, 0, 1)
	end
	local mix = math.clamp(dt / BLEND, 0, 1)
	local turn = math.clamp(dt / TURN, 0, 1)
	return {
		seg = seg,
		x = seg.x + (seg.nx - seg.x) * u,
		z = seg.z + (seg.nz - seg.z) * u,
		yaw = angleLerp(seg.prevYaw, seg.yaw, turn),
		from = seg.prevPose,
		to = seg.pose,
		mix = mix,
		phase = 2 * math.pi * (seg.s0 + seg.len * u) / STRIDE,
		gait = gait,
		still = not seg.moving and mix >= 1 and turn >= 1,
	}
end

do -- 검산: 걷는 중간과 끝, 도중 접속한 시각의 자리
	local segs = segments({ boxes = {}, keys = { { at = 0, x = 0, z = 0 }, { at = 10, x = 10, z = 0 }, { at = 20, x = 10, z = 0, face = 0 } } })
	local a, b, c = stateAt(segs, 5), stateAt(segs, 15), stateAt(segs, 100)
	assert(a.x == 5 and not a.still and math.abs(a.yaw - math.pi / 2) < 1e-6, "걷는 중 자리·방향이 틀렸다")
	assert(b.x == 10 and b.still, "멈춘 자리가 틀렸다")
	assert(c.x == 10 and c.still and c.gait == 0 and c.yaw == 0, "끝난 뒤 자리가 틀렸다")
	assert(a.gait > 0 and b.gait == 0 and c.gait == 0, "걷는 중 판단이 틀렸다")
end

local MESH_WAIT = 30 -- 메시 원본을 기다리는 시간(초). 넘으면 그 조각은 상자로 짓는다

-- 서버에서 한 번 부른다: 인물이 쓰는 메시 원본을 받아 둔다
function Figures.serveMeshes(config: Config)
	local specs: { Meshes.Spec } = {}
	for _, figure in config.figures do
		for _, box in figure.boxes do
			if box.mesh then
				table.insert(specs, box)
			end
		end
	end
	Meshes.serve(specs)
end

local function makePart(name: string, box: Box, parent: Instance): BasePart
	local p: BasePart
	if box.mesh then
		p = Meshes.clone(box.mesh, MESH_WAIT) :: any
	end
	if not p then
		local block = Instance.new("Part")
		block.Shape = box.shape or Enum.PartType.Block
		block.Color = box.color
		block.Material = box.material or Enum.Material.Fabric
		block.TopSurface = Enum.SurfaceType.Smooth
		block.BottomSurface = Enum.SurfaceType.Smooth
		p = block
	end
	if box.tint and p:IsA("MeshPart") then
		p.TextureID = ""
		p.Color = box.color
		p.Material = box.material or Enum.Material.Fabric
	end
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = box.shadow == true
	p.Size = box.size * S
	p.Parent = parent
	return p
end

local function pivot(x: number, y: number): CFrame
	return CFrame.new(x * S, y * S, 0)
end

local PIVOTS = {
	legL = pivot(HIP.x, HIP.y),
	legR = pivot(-HIP.x, HIP.y),
	armL = pivot(SHOULDER.x, SHOULDER.y),
	armR = pivot(-SHOULDER.x, SHOULDER.y),
	upper = pivot(0, HIP.y),
}

-- 클라이언트에서 한 번 부른다. 돌려주는 set(t)이 인물을 그 시각 자리에 놓고, 지금 걷는 인물들의 가운데 세계 좌표를 돌려준다 (아무도 안 걸으면 nil). 회차 밖은 math.huge
function Figures.start(config: Config): (t: number) -> Vector3?
	assert(RunService:IsClient(), "인물은 클라이언트에서만 만든다")
	local folder = Instance.new("Folder")
	folder.Name = "Figures"

	for _, box in config.props or {} do
		local p = makePart("Prop", box, folder)
		local at = box.at
		local g = config.ground(at.Position.X, at.Position.Z)
		p.CFrame = config.site * (at.Rotation + Vector3.new(at.Position.X, at.Position.Y + g, at.Position.Z) * S)
	end

	type Live = {
		figure: Figure, segs: { Seg }, holder: Folder, parts: { BasePart }, joints: { Joint }, rel: { CFrame },
		first: number, last: number, shown: boolean, restingOn: any, alpha: number, -- restingOn: 이 구간의 멈춘 자세로 이미 놓였다. alpha: 지금 보이는 정도
	}
	local live: { Live } = {}
	for n, figure in config.figures do
		local holder = Instance.new("Folder")
		holder.Name = `Figure{n}`
		local parts: { BasePart } = {}
		local joints: { Joint } = {}
		local rel: { CFrame } = {}
		for i, box in figure.boxes do
			parts[i] = makePart(box.joint, box, holder)
			joints[i] = box.joint
			rel[i] = box.at.Rotation + box.at.Position * S
		end
		live[n] = {
			figure = figure, segs = segments(figure), holder = holder, parts = parts, joints = joints, rel = rel,
			first = figure.keys[1].at, last = figure.keys[#figure.keys].at, shown = false, restingOn = nil, alpha = 1,
		}
	end
	folder.Parent = workspace

	local T: { [Joint]: CFrame } = {}
	local moveParts: { BasePart } = {}
	local moveCFrames: { CFrame } = {}

	local function place(l: Live, st: State)
		local g = config.ground(st.x, st.z)
		local bob = math.abs(math.sin(st.phase)) * GAIT_BOB * st.gait
		local root = config.site * CFrame.new(st.x * S, (g + bob) * S, st.z * S) * CFrame.Angles(0, st.yaw, 0)
		local m = st.mix
		local from, to = st.from, st.to
		local function arm(side: "armL" | "armR", swing: number): CFrame
			local a, b = (from :: any)[side] :: { number }, (to :: any)[side] :: { number }
			local carry = l.figure.carry
			local x = a[1] + (b[1] - a[1]) * m + (if carry and (carry :: any)[side] then 0 else swing)
			local z = a[2] + (b[2] - a[2]) * m
			local pv = (PIVOTS :: any)[side] :: CFrame
			return pv * CFrame.Angles(x, 0, z) * pv:Inverse()
		end
		local lean = from.lean + (to.lean - from.lean) * m
		local sin = math.sin(st.phase) * st.gait
		local up = PIVOTS.upper * CFrame.Angles(lean, sin * GAIT_TWIST, 0) * PIVOTS.upper:Inverse()
		T.root = root
		T.upper = root * up
		T.legL = root * PIVOTS.legL * CFrame.Angles(sin * GAIT_LEG, 0, 0) * PIVOTS.legL:Inverse()
		T.legR = root * PIVOTS.legR * CFrame.Angles(-sin * GAIT_LEG, 0, 0) * PIVOTS.legR:Inverse()
		T.armL = T.upper * arm("armL", -sin * GAIT_ARM)
		T.armR = T.upper * arm("armR", sin * GAIT_ARM)
		local n = #moveParts
		for i, p in l.parts do
			moveParts[n + i] = p
			moveCFrames[n + i] = T[l.joints[i]] * l.rel[i]
		end
	end

	local function set(t: number)
		table.clear(moveParts)
		table.clear(moveCFrames)
		local walkSum, walkers = Vector3.zero, 0
		for _, l in live do
			local visible = l.figure.duty == true or (t >= l.first and t <= l.last)
			if visible ~= l.shown then
				l.shown = visible
				l.holder.Parent = if visible then folder else nil
				l.restingOn = nil
			end
			if visible then
				if not l.figure.duty then
					local a = math.clamp(math.min(t - l.first, l.last - t) / FADE, 0, 1)
					if a ~= l.alpha then
						l.alpha = a
						for _, p in l.parts do
							p.Transparency = 1 - a
						end
					end
				end
				local st = stateAt(l.segs, t)
				if st.gait > 0 and not st.seg.silent then
					walkSum += config.site:PointToWorldSpace(Vector3.new(st.x, config.ground(st.x, st.z), st.z) * S)
					walkers += 1
				end
				-- 멈춰 있어도 구간이 바뀌었으면 놓는다 (도중 접속은 멈춘 자세에서 멈춘 자세로 건너뛴다)
				if not st.still or l.restingOn ~= st.seg then
					place(l, st)
				end
				l.restingOn = if st.still then st.seg else nil
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		return if walkers > 0 then walkSum / walkers else nil
	end
	set(math.huge)
	return set
end

return Figures
