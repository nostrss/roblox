--!strict
-- 건물 자리(ADR 0004) CFrame: 건물 축 좌표(정면 +Z, 스터드) → 세계 좌표(진북 −Z, 동 +X).
-- 방위각 h(북에서 시계 방향)의 세계 방향 = (sin h, 0, -cos h). CFrame.Angles(0, θ, 0)은 +Z를 (sin θ, 0, cos θ)로 보내므로 θ = 180° − h.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Core.Units)
local D = require(script.Parent.Dimensions)

local site = CFrame.new(Units.studs(1) * D.site.position) * CFrame.Angles(0, math.rad(180 - D.site.heading), 0)

local front = site:VectorToWorldSpace(Vector3.zAxis)
assert(front.X < 0 and front.Z > 0, `정면이 남서(x<0, z>0)가 아니다: {front}`) -- 222°: 서 = -X, 남 = +Z
-- 검산: 광장 연석 W9 건물 축 (−25.5, 5) m → 진북 (−22.3, −13.3) m (refs/plaza-notes.md 1-1 두 표)
local w9 = site:PointToWorldSpace(Vector3.new(-25.5, 0, 5)) - site.Position
assert(math.abs(w9.X + 22.3) < 0.1 and math.abs(w9.Z + 13.3) < 0.1, `건물 자리 변환이 자료와 다르다: {w9}`)

return site
