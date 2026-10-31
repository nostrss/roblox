--!strict
-- 지붕 곡면(기와골 포함) 메시를 놓는다. 메시는 tools/jibung_obj.luau 로 굽고, 경계 상자는 Shared.JibungMeshes (생성 파일).
-- 앞면(남)·옆면(동) 메시를 하나씩 올리고 뒷면·서쪽 면은 Y축 180°로 돌려 쓴다. 원점 = 문루 중심 지면.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Tags = require(ReplicatedStorage.Core.Tags)
local D = require(ReplicatedStorage.Shared.Dimensions)
local M = require(ReplicatedStorage.Shared.JibungMeshes)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local TILE = Color3.fromRGB(72, 74, 78) -- 기와 회흑색 근사 (재질은 F 단계)

return function()
	if workspace:FindFirstChild("Jibung") then
		return
	end
	local folder = CollectionService:GetTagged(Tags.MEMBER_MESHES)[1]
	local root = Instance.new("Model")
	root.Name = "Jibung"
	for name, b in M :: { [string]: any } do
		local src = folder and folder:FindFirstChild(name)
		if not (src and src:IsA("MeshPart")) then
			warn(`지붕: MemberMeshes에 {name}이 없어 건너뜀 (places/sungnyemun/meshes/{name}.obj 업로드 필요)`)
			continue
		end
		local cf = CFrame.new(Vector3.new(b.center[1], b.center[2] - D.level.ground, b.center[3]) * S)
		for _, turn in { 0, math.pi } do
			local p = (src :: MeshPart):Clone()
			p.Name = name
			setup(p, TILE)
			p.Material = Enum.Material.Slate
			-- 크기는 임포트된 그대로 둔다 (Size를 다시 넣으면 임포터 경계 상자와 조금만 달라도 메시 전체가 늘어나 추녀마루가 어긋난다)
			p.CFrame = CFrame.Angles(0, turn, 0) * cf
			p.Parent = root
		end
	end
	root.Parent = workspace
end
