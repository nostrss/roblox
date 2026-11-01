--!strict
-- 시간대(하늘·빛·야간 조명)·환경음·도로 차량·지붕 분해를 켜고, 스폰 직후 카메라를 문루 가운데 높이로 한 번 올려다보게 한다. 이후 조작은 기본 카메라 그대로.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local TimeOfDay = require(ReplicatedStorage.Core.TimeOfDay)

TimeOfDay.start(require(ReplicatedStorage.Shared.Looks)) -- 실제 서울 시각 + 지금/노을/밤 고르기, 야간 조명
require(ReplicatedStorage.Core.Ambience).start(require(ReplicatedStorage.Shared.Soundscape)) -- 바람·차 소리·새·풀벌레, 홍예 울림
require(ReplicatedStorage.Core.Traffic).start(require(ReplicatedStorage.Shared.Streets)) -- 세종대로·소월로 도로 차량 (엔진 소리가 위 Ambience 소리 묶음을 쓴다)
require(ReplicatedStorage.Core.RoofSplit).start(require(ReplicatedStorage.Shared.RoofSplit)) -- 광장 표식에서 문루 지붕 분해 (내 화면에서만)

local target = Units.studs(1) * (D.site.position + Vector3.new(0, (D.level.ridgeTop - D.level.ground) / 2, 0))

local function onCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid")
	local camera = workspace.CurrentCamera
	-- 기본 카메라가 캐릭터를 잡고 첫 자리를 잡은 뒤에 돌려야 덮어쓰이지 않는다
	while camera.CameraSubject ~= humanoid do
		camera:GetPropertyChangedSignal("CameraSubject"):Wait()
	end
	RunService.RenderStepped:Wait()
	local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	local dir = (target - root.Position).Unit
	camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 2, 0) - dir * distance, target)
end

Players.LocalPlayer.CharacterAdded:Connect(onCharacter)
if Players.LocalPlayer.Character then
	onCharacter(Players.LocalPlayer.Character)
end
