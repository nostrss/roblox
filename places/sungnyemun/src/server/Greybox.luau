--!strict
-- 숭례문 회색 박스: Dimensions 실측값으로 덩어리 형태를 세운다. 지붕은 처마·지붕 곡면 단계(Cheoma)에서 부재로 짓는다.
-- 원점 = 문루 중심의 지면, 건물 축(정면 = +Z). 실제 방위로는 init.server가 건물 자리로 돌린다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Plaza = require(ReplicatedStorage.Shared.Plaza)

local s = Units.studs
local L = D.level


-- 실측 가정값(도면에 없음). ponytail: 회색 박스용 근사, 실제 형태는 Studio 모델로 대체
local BASE_MARGIN = 0.6 -- 문루 기단이 하층 기둥 중심 밖으로 나간 거리

local function y(level: number): number -- T.B.M. 기준 높이 → 지면 기준 높이
	return level - L.ground
end

local function positions(bays: { number }): { number } -- 주칸 → 중심 기준 기둥 좌표
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
	if workspace:FindFirstChild("SungnyemunGreybox") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "SungnyemunGreybox"

	local function part(name: string, cf: CFrame, size: Vector3, class: string?): BasePart
		local p = Instance.new((class or "Part") :: any) :: BasePart
		p.Name = name
		p.Anchored = true
		local c = Palette.of(name)
		p.Material = c.material
		p.Color = c.color
		p.Size = size
		p.CFrame = cf
		p.Parent = model
		return p
	end

	-- 두 꼭짓점(m)으로 블록
	local function block(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): BasePart
		return part(
			name,
			CFrame.new(s((x0 + x1) / 2), s((y0 + y1) / 2), s((z0 + z1) / 2)),
			Vector3.new(s(x1 - x0), s(y1 - y0), s(z1 - z0))
		)
	end

	-- 석축(육축)은 Yukchuk이 짓는다. 여기서는 그 윗면 높이만 쓴다
	local H = y(0)

	-- 문루 기단 (기둥·창방·평방은 Chukbu)
	local xs, zs = positions(D.lowerBays), positions(D.lowerSideBays)
	local ux, uz = positions(D.upperBays), positions(D.upperSideBays)
	local lx, lz = xs[#xs], zs[#zs] -- 하층 기둥열 반폭
	local m = BASE_MARGIN
	block("PavilionBase", -lx - m, H, -lz - m, lx + m, y(L.pavilionFloor), lz + m)

	-- 상층 벽: 마루~기둥 상을 기둥열 크기 덩어리로 채운다. ponytail: 창호·판벽은 D 단계에서 부재로 교체
	local px, pz = ux[#ux], uz[#uz]
	block("UpperWall", -px, y(L.upperFloor), -pz, px, y(L.upperColumnTop), pz)

	-- 정면 광장 시작 위치: 석축 남측면에서 35 m, 문루를 바라본다(-Z). 건물 자리로 함께 돌아 남서 광장에 놓인다
	local spawnPoint = Instance.new("SpawnLocation")
	spawnPoint.Anchored = true
	spawnPoint.Size = Vector3.new(12, 1, 12)
	local spawnZ = D.wall.south + 35
	spawnPoint.CFrame = CFrame.new(0, s(Plaza.floor(spawnZ)) + 0.5, s(spawnZ)) -- 광장 바닥은 문에서 멀수록 높다 (ADR 0006)
	spawnPoint.Parent = model

	CollectionService:AddTag(model, Tags.GREYBOX)
	model.Parent = workspace
end
