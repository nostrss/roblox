--!strict
-- 실측(m) ↔ 스터드 환산. R15 캐릭터 약 5스터드 = 170cm 기준. 모든 Place 공통.
local Units = {}

Units.METERS_PER_STUD = 0.34

function Units.studs(meters: number): number
	return meters / Units.METERS_PER_STUD
end

return Units
