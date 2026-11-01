--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local site = require(ReplicatedStorage.Shared.Site)

require(script.Greybox)()
require(script.Chukbu)()
require(script.Gongpo)()
require(script.Cheoma)()
require(script.Jibung)() -- Cheoma 부재의 세계 좌표를 읽으므로 돌리기 전에 짓는다
require(script.Hyeonpan)()
require(script.Seonggwak)()
require(script.Plaza)() -- 광장·도로는 세계 좌표로 바로 놓는다 (아래 목록에 넣지 않는다)

-- 건물 자리(ADR 0004): 자기 축으로 지은 루트 Model을 통째로 돌려 놓는다 (Shared.Site).

-- ponytail: 루트 이름 목록. 새 루트 Model을 만들면 여기 추가, 두 번째 Place가 쓰면 core로 올린다
for _, name in { "SungnyemunGreybox", "Chukbu", "Gongpo", "Cheoma", "Jibung", "Hyeonpan", "Seonggwak" } do
	local m = workspace:FindFirstChild(name)
	if m and m:IsA("Model") and not m:GetAttribute("Sited") then -- Edit에 저장된 Gongpo가 이미 돌아 있으면 두 번 돌리지 않는다
		m:PivotTo(site * m:GetPivot())
		m:SetAttribute("Sited", true)
	end
end
