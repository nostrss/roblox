--!strict
-- 업로드한 부재 메시(MemberMeshes 태그 Folder 안의 MeshPart)를 복제해 주간포를 조립한다.
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

-- 부재 메시 하나를 member-local 원점 기준 cf에 놓는다. center·size는 메시 경계 상자(m)
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

-- origin: 주두 밑면 중심, LookVector = 바깥(쇠서 쪽)
local function build(meshes: Instance, origin: CFrame, parent: Instance): Model
	local function mesh(name: string): MeshPart
		local m = meshes:FindFirstChild(name)
		assert(m and m:IsA("MeshPart"), `MemberMeshes에 {name} MeshPart가 없다`)
		return m
	end
	local model = Instance.new("Model")
	model.Name = "Gongpo"
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
		local kind, k, y0, h = row[1] :: string, row[2] :: number, row[3] :: number, row[4] :: number
		local L = (G.cheomcha.length :: any)[kind] :: number
		local src = mesh(kind == "small" and "SoCheomcha" or "DaeCheomcha")
		place(model, src, origin, CFrame.new(0, s(y0), s(out(k))), Vector3.new(0, h / 2, 0), Vector3.new(L, h, t))
	end
	for i, profile in G.jegong do
		local u0, u1, v0, v1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in profile do
			u0, u1, v0, v1 = math.min(u0, p[1]), math.max(u1, p[1]), math.min(v0, p[2]), math.max(v1, p[2])
		end
		-- 프로파일 u(바깥 +)를 로컬 -Z로: Y축 +90° 회전이면 메시 X가 -Z가 된다
		local center, size = Vector3.new((u0 + u1) / 2, (v0 + v1) / 2, 0), Vector3.new(u1 - u0, v1 - v0, t)
		place(model, mesh("Jegong" .. i), origin, CFrame.Angles(0, math.pi / 2, 0), center, size)
	end
	model.Parent = parent
	return model
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
	-- 시험 조각: 남측 어칸 동쪽 첫 주간포. 어칸 주간포 4구, 간격 = 어칸/5 (S4 011 하층앙시도)
	-- ponytail: 나머지 공포는 주상포·귀포 데이터를 넣은 뒤 배열로 늘린다.
	local frontZ = (D.lowerSideBays[1] + D.lowerSideBays[2]) / 2
	local base = D.level.lowerColumnTop - D.level.ground + D.lowerPyeongbangHeight
	local origin = Vector3.new(s(D.lowerBays[3] / 10), s(base), s(frontZ))
	build(folder, CFrame.lookAt(origin, origin + Vector3.zAxis), workspace)
end
