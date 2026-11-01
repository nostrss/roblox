--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local site = require(ReplicatedStorage.Shared.Site)

require(script.Greybox)()
require(script.Yukchuk)()
require(script.Chukbu)()
require(script.Munru)()
require(script.Gongpo)()
require(script.Cheoma)()
require(script.Jibung)() -- Cheoma 부재의 세계 좌표를 읽으므로 돌리기 전에 짓는다
require(script.Hyeonpan)()
require(script.Seonggwak)()
require(script.Plaza)() -- 광장·도로는 세계 좌표로 바로 놓는다 (아래 목록에 넣지 않는다)
require(script.Chaseon)() -- 차선 도색도 세계 좌표 그대로 (도로 차량과 같은 Shared.Lanes)
require(script.Silhouette)() -- 주변 건물 실루엣도 세계 좌표 그대로
require(script.Jomyeong)() -- 야간 조명 기구 (켜고 끄기는 클라이언트 core TimeOfDay)
require(script.Jogyeong)() -- 광장·길 조경: 나무, 생울타리, 의자, 길 조명, 가로등. 세계 좌표 그대로

-- 건물 자리(ADR 0004): 자기 축으로 지은 루트 Model을 통째로 돌려 놓는다 (Shared.Site).

-- ponytail: 루트 이름 목록. 새 루트 Model을 만들면 여기 추가, 두 번째 Place가 쓰면 core로 올린다
for _, name in { "SungnyemunGreybox", "Yukchuk", "Chukbu", "Munru", "Gongpo", "GongpoMohyeong", "Cheoma", "Jibung", "JibungWalk", "Hyeonpan", "Seonggwak", "Jomyeong" } do
	local m = workspace:FindFirstChild(name)
	if m and m:IsA("Model") and not m:GetAttribute("Sited") then -- Edit에 저장된 Gongpo가 이미 돌아 있으면 두 번 돌리지 않는다
		m:PivotTo(site * m:GetPivot())
		m:SetAttribute("Sited", true)
	end
end

-- 도로 차량 메시 원본 (차는 클라이언트가 짓는다, core Traffic). 받는 동안 Place 시작을 막지 않는다
task.spawn(function()
	local Traffic = require(ReplicatedStorage.Core.Traffic)
	require(ReplicatedStorage.Core.Meshes).serve(Traffic.meshes(require(ReplicatedStorage.Shared.Streets)))
end)

-- 화차: 지붕이 제자리에 돈 뒤에 착지점을 광선으로 찾으므로 맨 끝에 (core Launcher, 데이터 Shared.Hwacha)
require(ReplicatedStorage.Core.Launcher).serve(require(ReplicatedStorage.Shared.Hwacha))

-- 개폐의식: 재생 준비(serve)와 언제 시작하는가(startOnRequest, 당분간 버튼)를 나눠 부른다 (core Ceremony, 데이터 Shared.Gaepye)
local Ceremony = require(ReplicatedStorage.Core.Ceremony)
Ceremony.startOnRequest(Ceremony.serve(require(ReplicatedStorage.Shared.Gaepye)))
