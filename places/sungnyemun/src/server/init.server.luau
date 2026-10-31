--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)

require(script.Greybox)()
require(script.Chukbu)()
require(script.Gongpo)()
require(script.Cheoma)()
require(script.Jibung)() -- Cheoma 부재의 세계 좌표를 읽으므로 돌리기 전에 짓는다
require(script.Hyeonpan)()

-- 건물 자리(ADR 0004): 자기 축으로 지은 루트 Model을 통째로 돌려 놓는다.
-- 방위각 h(북에서 시계 방향)의 세계 방향 = (sin h, 0, -cos h). CFrame.Angles(0, θ, 0)은 +Z를 (sin θ, 0, cos θ)로 보내므로 θ = 180° − h.
local site = CFrame.new(D.site.position / Units.METERS_PER_STUD) * CFrame.Angles(0, math.rad(180 - D.site.heading), 0)
local front = site:VectorToWorldSpace(Vector3.zAxis)
assert(front.X < 0 and front.Z > 0, `정면이 남서(x<0, z>0)가 아니다: {front}`) -- 222°: 서 = -X, 남 = +Z

-- ponytail: 루트 이름 목록. 새 루트 Model을 만들면 여기 추가, 두 번째 Place가 쓰면 core로 올린다
for _, name in { "SungnyemunGreybox", "Chukbu", "Gongpo", "Cheoma", "Jibung", "Hyeonpan" } do
	local m = workspace:FindFirstChild(name)
	if m and m:IsA("Model") and not m:GetAttribute("Sited") then -- Edit에 저장된 Gongpo가 이미 돌아 있으면 두 번 돌리지 않는다
		m:PivotTo(site * m:GetPivot())
		m:SetAttribute("Sited", true)
	end
end
