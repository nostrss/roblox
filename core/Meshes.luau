--!strict
-- 공개·생성 메시 원본: 서버가 에셋 ID로 받아 ReplicatedStorage에 두고, 클라이언트는 복제해 쓴다.
-- CreateMeshPartAsync는 서버에서만 된다. Studio에 모델을 저장하지 않아도 코드만으로 지어진다 (ADR 0011).
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Spec = { mesh: number?, texture: number? }

local FOLDER = "GeneratedMeshes"

local Meshes = {}

-- 서버에서 부른다. 메시 하나를 받지 못하면 경고만 남긴다 (쓰는 쪽은 상자로 짓는다). 받는 동안 양보한다
function Meshes.serve(specs: { Spec })
	assert(RunService:IsServer(), "메시 원본은 서버에서 받는다")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = ReplicatedStorage
	end
	for _, spec in specs do
		local id = spec.mesh
		if id and not (folder :: Instance):FindFirstChild(tostring(id)) then
			local ok, result = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromAssetId(id), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Automatic,
				})
			end)
			if ok then
				local m = result :: MeshPart
				m.Name = tostring(id)
				m.Anchored = true
				m.CanCollide = false
				m.CanQuery = false
				m.CanTouch = false
				if spec.texture then
					m.TextureContent = Content.fromAssetId(spec.texture)
				end
				m.Parent = folder
			else
				warn(`메시 {id}을 받지 못했다: {result}`)
			end
		end
	end
end

-- 복제본. wait초까지 기다리고, 없으면 nil
function Meshes.clone(id: number, wait: number?): MeshPart?
	local folder = ReplicatedStorage:FindFirstChild(FOLDER)
	if not folder and wait then
		folder = ReplicatedStorage:WaitForChild(FOLDER, wait)
	end
	if not folder then
		return nil
	end
	local src = if wait then folder:WaitForChild(tostring(id), wait) else folder:FindFirstChild(tostring(id))
	return if src then (src :: MeshPart):Clone() else nil
end

return Meshes
