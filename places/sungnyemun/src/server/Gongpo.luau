--!strict
-- 업로드한 부재 메시(MemberMeshes 태그 Folder 안의 MeshPart)를 복제해 하층 공포 46구를 조립한다.
-- 메시 원본은 tools/gongpo_obj.luau 가 Gongpo 데이터로 구운 OBJ. 크기·위치는 여기서 데이터로 다시 정한다.
-- Edit 모드 명령창에서 require(game.ServerScriptService.Server.Gongpo)() 로 미리 지어 저장하면 실행 시엔 건너뛴다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local G = require(ReplicatedStorage.Shared.Gongpo)

local s = Units.studs
local WOOD = Color3.fromRGB(150, 95, 60)

-- 부재 메시 하나를 공포 원점 기준 cf에 놓는다. center·size는 메시 경계 상자(m)
local function place(model: Model, src: MeshPart, origin: CFrame, cf: CFrame, center: Vector3, size: Vector3)
	local p = src:Clone()
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Wood
	p.Color = WOOD
	p.Size = Vector3.new(s(size.X), s(size.Y), s(size.Z))
	p.CFrame = origin * cf * CFrame.new(s(center.X), s(center.Y), s(center.Z))
	p.Parent = model
end

-- 공포 한 세트. origin: 주두 밑면 중심, LookVector = 바깥(쇠서 쪽)
local function build(meshes: Instance, kind: string, origin: CFrame, parent: Instance)
	local function mesh(name: string): MeshPart
		local m = meshes:FindFirstChild(name)
		assert(m and m:IsA("MeshPart"), `MemberMeshes에 {name} MeshPart가 없다`)
		return m
	end
	local spec = (G.kinds :: any)[kind]
	local model = Instance.new("Model")
	model.Name = kind
	local t = G.thickness
	-- 데이터는 +Z가 바깥, CFrame은 -Z(LookVector)가 앞이므로 출목 방향을 뒤집는다
	local function out(k: number): number
		return -k * G.outset
	end

	local J, S = G.judu, G.soro
	place(model, mesh("Judu"), origin, CFrame.identity, Vector3.new(0, J.height / 2, 0), Vector3.new(J.top, J.height, J.top))
	for _, row in G.soros do
		local cf = CFrame.new(s(row[1]), s(row[3]), s(out(row[2])))
		place(model, mesh("Soro"), origin, cf, Vector3.new(0, S.height / 2, 0), Vector3.new(S.top, S.height, S.top))
	end
	for _, row in G.cheomchas do
		local size, k, y0, h = row[1] :: string, row[2] :: number, row[3] :: number, row[4] :: number
		local L = (G.cheomcha.length :: any)[size] :: number
		local src = mesh(size == "small" and "SoCheomcha" or "DaeCheomcha")
		place(model, src, origin, CFrame.new(0, s(y0), s(out(k))), Vector3.new(0, h / 2, 0), Vector3.new(L, h, t))
	end
	for _, name in spec.jegong do
		local u0, u1, v0, v1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in (G.jegong :: any)[name] do
			u0, u1, v0, v1 = math.min(u0, p[1]), math.max(u1, p[1]), math.min(v0, p[2]), math.max(v1, p[2])
		end
		-- 프로파일 u(바깥 +)를 로컬 -Z로: Y축 +90° 회전이면 메시 X가 -Z가 된다
		local center, size = Vector3.new((u0 + u1) / 2, (v0 + v1) / 2, 0), Vector3.new(u1 - u0, v1 - v0, t)
		place(model, mesh(name), origin, CFrame.Angles(0, math.pi / 2, 0), center, size)
	end
	assert(#model:GetChildren() == spec.b40, `{kind} 부재 수 {#model:GetChildren()} ≠ 도면 B40 {spec.b40}`)
	model.Parent = parent
end

local GWIHANDAE_THICKNESS = 0.151 -- S3 p.283 귀한대 초제공 151×224

-- 귀포 한 세트. origin: 모서리 주두 밑면 중심, LookVector = 대각선 바깥. outA·outB = 두 면의 바깥 방향
local function buildCorner(meshes: Instance, origin: CFrame, outA: Vector3, outB: Vector3, parent: Instance)
	local function mesh(name: string): MeshPart
		local m = meshes:FindFirstChild(name)
		assert(m and m:IsA("MeshPart"), `MemberMeshes에 {name} MeshPart가 없다`)
		return m
	end
	local C = G.gwipo
	local model = Instance.new("Model")
	model.Name = "gwi"
	local t = G.thickness
	local J, S = G.judu, G.soro
	place(model, mesh("Judu"), origin, CFrame.identity, Vector3.new(0, J.height / 2, 0), Vector3.new(J.top, J.height, J.top))

	-- 제공형 부재: frame(바깥 = LookVector) 위에 u(바깥 +)·v 상자로 놓는다
	local function jegongAt(name: string, frame: CFrame, u0: number, u1: number, v0: number, v1: number, thick: number)
		local center, size = Vector3.new((u0 + u1) / 2, (v0 + v1) / 2, 0), Vector3.new(u1 - u0, v1 - v0, thick)
		place(model, mesh(name), frame, CFrame.Angles(0, math.pi / 2, 0), center, size)
	end
	local soros: { Vector3 } = {}
	local function soro(frame: CFrame, x: number, y: number, z: number)
		local p = (frame * CFrame.new(s(x), s(y), s(z))).Position
		for _, q in soros do
			if (p - q).Magnitude < s(0.05) then
				return -- 두 면 첨차 끝이 겹치는 자리엔 하나만
			end
		end
		table.insert(soros, p)
		place(model, mesh("Soro"), CFrame.new(p) * (origin - origin.Position), CFrame.identity, Vector3.new(0, S.height / 2, 0), Vector3.new(S.top, S.height, S.top))
	end

	for _, pair in { { outA, outB }, { outB, outA } } do
		local frame = CFrame.lookAt(origin.Position, origin.Position + pair[1])
		local d = frame.RightVector:Dot(pair[2]) -- 다른 면 바깥 쪽이 로컬 X의 어느 부호인지
		for _, name in C.jegong do -- 좌·우대
			local u0, u1, v0, v1 = math.huge, -math.huge, math.huge, -math.huge
			for _, p in (G.jegong :: any)[name] do
				u0, u1, v0, v1 = math.min(u0, p[1]), math.max(u1, p[1]), math.min(v0, p[2]), math.max(v1, p[2])
			end
			jegongAt(name, frame, u0, u1, v0, v1, t)
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
		jegongAt(g[1] :: string, origin, g[2] :: number, g[3] :: number, g[4] :: number, g[5] :: number, GWIHANDAE_THICKNESS)
	end
	model.Parent = parent
	return #soros
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

return function()
	if workspace:FindFirstChild("Gongpo") then
		return
	end
	local folder = CollectionService:GetTagged(Tags.MEMBER_MESHES)[1]
	if not folder then
		warn("공포: MemberMeshes 태그 Folder가 없어 건너뜀 (places/sungnyemun/meshes/*.obj 업로드 필요)")
		return
	end
	local root = Instance.new("Model")
	root.Name = "Gongpo"
	local y = s(D.level.lowerColumnTop - D.level.ground + D.lowerPyeongbangHeight)
	local xs, zs = columns(D.lowerBays), columns(D.lowerSideBays)
	local count: { [string]: number } = { jugan = 0, jusang = 0 }

	-- 한 면: 기둥열 cols 위로 칸마다 주간포, 모서리 아닌 기둥마다 주상포. at(a) = 면 위 a 지점의 주두 원점
	local function face(cols: { number }, perBay: { number }, outward: Vector3, at: (number) -> Vector3)
		local function put(kind: string, a: number)
			local p = at(a)
			build(folder, kind, CFrame.lookAt(p, p + outward), root)
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
	local front, side = D.lowerIntercolumnar.front, D.lowerIntercolumnar.side
	local zN, zS, xW, xE = s(zs[1]), s(zs[#zs]), s(xs[1]), s(xs[#xs])
	face(xs, front, Vector3.zAxis, function(a: number): Vector3 return Vector3.new(s(a), y, zS) end) -- 남(정면)
	face(xs, front, -Vector3.zAxis, function(a: number): Vector3 return Vector3.new(s(a), y, zN) end) -- 북
	face(zs, side, Vector3.xAxis, function(a: number): Vector3 return Vector3.new(xE, y, s(a)) end) -- 동
	face(zs, side, -Vector3.xAxis, function(a: number): Vector3 return Vector3.new(xW, y, s(a)) end) -- 서
	for _, c in { { xW, zN, -Vector3.xAxis, -Vector3.zAxis }, { xE, zN, Vector3.xAxis, -Vector3.zAxis }, { xE, zS, Vector3.xAxis, Vector3.zAxis }, { xW, zS, -Vector3.xAxis, Vector3.zAxis } } do
		local p, a, b = Vector3.new(c[1] :: number, y, c[2] :: number), c[3] :: Vector3, c[4] :: Vector3
		buildCorner(folder, CFrame.lookAt(p, p + (a + b).Unit), a, b, root)
		count.gwi = (count.gwi or 0) + 1
	end
	-- S4 011: 하층 주두 46 = 주간포 32 + 주상포 10 + 귀포 4
	assert(count.jugan == 32 and count.jusang == 10 and count.gwi == 4, `공포 수 주간포 {count.jugan}, 주상포 {count.jusang}, 귀포 {count.gwi}`)
	root.Parent = workspace
end
