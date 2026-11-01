--!strict
-- 업로드한 부재 메시(MemberMeshes 태그 Folder 안의 MeshPart)를 복제해 하층 46구·상층 38구 공포를 조립한다.
-- 메시 원본은 tools/gongpo_obj.luau 가 Gongpo 데이터로 구운 OBJ. 크기·위치는 여기서 데이터로 다시 정한다.
-- Edit 모드 명령창에서 require(game.ServerScriptService.Server.Gongpo)() 로 미리 지어 저장하면 실행 시엔 짓지 않고 칠만 다시 한다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local G = require(ReplicatedStorage.Shared.Gongpo)
local setup = require(script.Parent.Member)
local RoofSplit = require(ReplicatedStorage.Core.RoofSplit)
local Split = require(ReplicatedStorage.Shared.RoofSplit)

local s = Units.studs
local GWIHANDAE_THICKNESS = 0.151 -- S3 p.283 귀한대 초제공 151×224

local meshes: Instance

local function mesh(name: string): MeshPart
	local m = meshes:FindFirstChild(name)
	assert(m and m:IsA("MeshPart"), `MemberMeshes에 {name} MeshPart가 없다`)
	return m
end

-- 부재 메시 하나를 frame 기준 cf에 놓는다. center·size는 메시 경계 상자(m)
local function place(model: Model, src: MeshPart, frame: CFrame, cf: CFrame, center: Vector3, size: Vector3)
	local p = src:Clone()
	setup(p)
	p.Size = Vector3.new(s(size.X), s(size.Y), s(size.Z))
	p.CFrame = frame * cf * CFrame.new(s(center.X), s(center.Y), s(center.Z))
	p.Parent = model
end

-- 제공 항목 → 메시 이름과 상자 (Gongpo.luau 머리말의 두 형식)
local function jegongBox(entry: any): (string, number, number, number, number)
	if type(entry) == "table" then
		return entry[1], entry[2], entry[3], entry[4], entry[5]
	end
	local u0, u1, v0, v1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in G.jegong[entry] do
		u0, u1, v0, v1 = math.min(u0, p[1]), math.max(u1, p[1]), math.min(v0, p[2]), math.max(v1, p[2])
	end
	return entry, u0, u1, v0, v1
end

-- 제공형 부재: frame(바깥 = LookVector) 위에 u(바깥 +)·v 상자로. 프로파일 u를 로컬 -Z로 보내려 Y축 +90° 돌린다
local function jegongAt(model: Model, entry: any, frame: CFrame, thick: number)
	local name, u0, u1, v0, v1 = jegongBox(entry)
	local center, size = Vector3.new((u0 + u1) / 2, (v0 + v1) / 2, 0), Vector3.new(u1 - u0, v1 - v0, thick)
	place(model, mesh(name), frame, CFrame.Angles(0, math.pi / 2, 0), center, size)
end

local function judu(model: Model, F: any, frame: CFrame)
	local J = F.judu
	place(model, mesh("Judu"), frame, CFrame.identity, Vector3.new(0, J.height / 2, 0), Vector3.new(J.top, J.height, J.top))
end

local function soroAt(model: Model, frame: CFrame, x: number, y: number, z: number)
	local S = G.soro
	place(model, mesh("Soro"), frame, CFrame.new(s(x), s(y), s(z)), Vector3.new(0, S.height / 2, 0), Vector3.new(S.top, S.height, S.top))
end

-- 주간포·주상포 한 세트. origin: 주두 밑면 중심, LookVector = 바깥(쇠서 쪽)
local function build(F: any, kind: string, origin: CFrame, parent: Instance)
	local spec = F.kinds[kind]
	local model = Instance.new("Model")
	model.Name = kind
	local t = G.thickness
	-- 데이터는 +Z가 바깥, CFrame은 -Z(LookVector)가 앞이므로 출목 방향을 뒤집는다
	local function out(k: number): number
		return -k * G.outset
	end
	judu(model, F, origin)
	for _, row in F.soros do
		soroAt(model, origin, row[1], row[3], out(row[2]))
	end
	for _, row in F.cheomchas do
		local size, k, y0, h = row[1] :: string, row[2] :: number, row[3] :: number, row[4] :: number
		local L = G.cheomcha.length[size] :: number
		local src = mesh(size == "small" and "SoCheomcha" or "DaeCheomcha")
		place(model, src, origin, CFrame.new(0, s(y0), s(out(k))), Vector3.new(0, h / 2, 0), Vector3.new(L, h, t))
	end
	for _, entry in spec.jegong do
		jegongAt(model, entry, origin, t)
	end
	assert(#model:GetChildren() == spec.b40, `{kind} 부재 수 {#model:GetChildren()} ≠ 도면 B40 {spec.b40}`)
	model.Parent = parent
end

-- 귀포 한 세트. origin: 모서리 주두 밑면 중심, LookVector = 대각선 바깥. outA·outB = 두 면의 바깥 방향
local function buildCorner(F: any, origin: CFrame, outA: Vector3, outB: Vector3, parent: Instance)
	local C = F.gwipo
	local model = Instance.new("Model")
	model.Name = "gwi"
	local t = G.thickness
	judu(model, F, origin)
	local soros: { Vector3 } = {}
	local function soro(frame: CFrame, x: number, y: number, z: number)
		local p = (frame * CFrame.new(s(x), s(y), s(z))).Position
		for _, q in soros do
			if (p - q).Magnitude < s(0.05) then
				return -- 두 면 첨차 끝이 겹치는 자리엔 하나만
			end
		end
		table.insert(soros, p)
		soroAt(model, CFrame.new(p) * (origin - origin.Position), 0, 0, 0)
	end
	for _, pair in { { outA, outB }, { outB, outA } } do
		local frame = CFrame.lookAt(origin.Position, origin.Position + pair[1])
		local d = frame.RightVector:Dot(pair[2]) -- 다른 면 바깥 쪽이 로컬 X의 어느 부호인지
		for _, entry in C.jegong do -- 좌·우대
			jegongAt(model, entry, frame, t)
		end
		for _, row in C.cheomchas do
			local name, k, c, y0, h, L = row[1] :: string, row[2] :: number, row[3] :: number, row[4] :: number, row[5] :: number, row[6] :: number
			local z = -k * G.outset
			place(model, mesh(name), frame, CFrame.new(s(-c * d), s(y0), s(z)), Vector3.new(0, h / 2, 0), Vector3.new(L, h, t))
			for _, e in { c - (L / 2 - 0.055), c + (L / 2 - 0.055) } do
				soro(frame, -e * d, y0 + h, z)
			end
		end
	end
	for _, g in C.gwihandae do
		jegongAt(model, g, origin, GWIHANDAE_THICKNESS)
	end
	model.Parent = parent
end

-- 기둥 좌표(주칸 → 중심 기준)
local function columns(bays: { number }): { number }
	local total = 0
	for _, b in bays do
		total += b
	end
	local out = { -total / 2 }
	for _, b in bays do
		table.insert(out, out[#out] + b)
	end
	return out
end

-- 한 층 둘레: 모서리 아닌 기둥마다 주상포, 칸마다 주간포, 모서리마다 귀포
local function floor(F: any, root: Instance, base: number, bays: { number }, sideBays: { number }, per: any): { [string]: number }
	local count: { [string]: number } = { jugan = 0, jusang = 0, gwi = 0 }
	local y = s(base)
	local xs, zs = columns(bays), columns(sideBays)
	local function face(cols: { number }, perBay: { number }, outward: Vector3, at: (number) -> Vector3)
		local function put(kind: string, a: number)
			local p = at(a)
			build(F, kind, CFrame.lookAt(p, p + outward), root)
			count[kind] += 1
		end
		for i = 2, #cols - 1 do
			put("jusang", cols[i])
		end
		for i, n in perBay do
			local a, b = cols[i], cols[i + 1]
			for k = 1, n do
				put("jugan", a + (b - a) * k / (n + 1))
			end
		end
	end
	local zN, zS, xW, xE = s(zs[1]), s(zs[#zs]), s(xs[1]), s(xs[#xs])
	face(xs, per.front, Vector3.zAxis, function(a: number): Vector3 return Vector3.new(s(a), y, zS) end) -- 남(정면)
	face(xs, per.front, -Vector3.zAxis, function(a: number): Vector3 return Vector3.new(s(a), y, zN) end) -- 북
	face(zs, per.side, Vector3.xAxis, function(a: number): Vector3 return Vector3.new(xE, y, s(a)) end) -- 동
	face(zs, per.side, -Vector3.xAxis, function(a: number): Vector3 return Vector3.new(xW, y, s(a)) end) -- 서
	for _, c in { { xW, zN, -Vector3.xAxis, -Vector3.zAxis }, { xE, zN, Vector3.xAxis, -Vector3.zAxis }, { xE, zS, Vector3.xAxis, Vector3.zAxis }, { xW, zS, -Vector3.xAxis, Vector3.zAxis } } do
		local p, a, b = Vector3.new(c[1] :: number, y, c[2] :: number), c[3] :: Vector3, c[4] :: Vector3
		buildCorner(F, CFrame.lookAt(p, p + (a + b).Unit), a, b, root)
		count.gwi += 1
	end
	return count
end

return function()
	local saved = workspace:FindFirstChild("Gongpo")
	if saved then -- Edit에 저장된 공포: 다시 짓지 않고 Palette로 다시 칠만 한다 (저장 뒤 칠이 바뀌어도 맞게)
		for _, p in saved:GetDescendants() do
			if p:IsA("BasePart") then
				setup(p)
			end
		end
		(saved :: Model).ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 지붕 분해가 클라이언트에서 부재 전체를 옮기므로 스트리밍으로 빠지지 않게
		RoofSplit.mark(saved:FindFirstChild("Lower") :: Instance, "lower", Split, "gongpo")
		RoofSplit.mark(saved:FindFirstChild("Upper") :: Instance, "upper", Split, "gongpo")
		return
	end
	local folder = CollectionService:GetTagged(Tags.MEMBER_MESHES)[1]
	if not folder then
		warn("공포: MemberMeshes 태그 Folder가 없어 건너뜀 (landmarks/sungnyemun/meshes/*.obj 업로드 필요)")
		return
	end
	meshes = folder
	local L = D.level
	local root = Instance.new("Model")
	root.Name = "Gongpo"
	root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 지붕 분해가 클라이언트에서 부재 전체를 옮기므로 스트리밍으로 빠지지 않게

	local lower = Instance.new("Model")
	lower.Name = "Lower"
	lower.Parent = root
	local n = floor(G.lower, lower, L.lowerColumnTop - L.ground + D.lowerPyeongbangHeight, D.lowerBays, D.lowerSideBays, D.lowerIntercolumnar)
	-- S4 011: 하층 주두 46 = 주간포 32 + 주상포 10 + 귀포 4
	assert(n.jugan == 32 and n.jusang == 10 and n.gwi == 4, `하층 공포 수 {n.jugan}/{n.jusang}/{n.gwi}`)

	local upper = Instance.new("Model")
	upper.Name = "Upper"
	upper.Parent = root
	n = floor(G.upper, upper, L.upperColumnTop - L.ground + D.upperPyeongbangHeight, D.upperBays, D.upperSideBays, D.upperIntercolumnar)
	-- S4 012: 상층 주간포 24 (정면 1·2·4·2·1, 측면 1·1) + 주상포 10 + 귀포 4
	assert(n.jugan == 24 and n.jusang == 10 and n.gwi == 4, `상층 공포 수 {n.jugan}/{n.jusang}/{n.gwi}`)
	RoofSplit.mark(lower, "lower", Split, "gongpo")
	RoofSplit.mark(upper, "upper", Split, "gongpo")

	root.Parent = workspace
end
