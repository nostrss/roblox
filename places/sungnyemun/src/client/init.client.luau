--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local buildGongpo = require(script.GongpoBuilder)

local s = Units.studs

-- 시험 조각: 남측 어칸 동쪽 첫 주간포 한 세트만 제자리에 놓는다.
-- 어칸 주간포 4구 가정(S3 p.270 하층 주두 46개 = 주상포 10 + 귀포 4 + 주간포 32에서 역산) → 간격 = 어칸/5.
-- ponytail: 나머지 공포는 이 조각을 확인한 뒤 배열 데이터로 늘린다.
local frontZ = (D.lowerSideBays[1] + D.lowerSideBays[2]) / 2
local base = D.level.lowerColumnTop - D.level.ground + D.lowerPyeongbangHeight
local origin = Vector3.new(s(D.lowerBays[3] / 10), s(base), s(frontZ))
buildGongpo(CFrame.lookAt(origin, origin + Vector3.zAxis), workspace)
