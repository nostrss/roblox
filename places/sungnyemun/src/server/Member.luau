--!strict
-- 장식 부재(공포·축부·처마) 공통 설정. 부재를 만드는 곳은 모두 이 함수를 거친다.
-- 부딪힘·조회를 끄고(CanTouch·CanQuery), 작은 부재는 그림자를 끈다. 나중에 클릭할 부재는 CanQuery만 다시 켠다
-- (CanQuery=false는 CanCollide=false일 때만 효력이 있다).
-- MeshPart의 CollisionFidelity는 스크립트로 못 바꾼다 → MemberMeshes 원본에 Studio 속성 창에서 Box로 두고 복제본이 물려받는다.

-- 그림자를 끄는 작은 부재 (메시·부재 이름)
local SMALL = {
	Soro = true, SoCheomcha = true, DaeCheomcha = true, Buyeon = true, SeonjaBuyeon = true,
	Chomaegi = true, Imaegi = true, BuyeonGaepan = true, Sungakpan = true,
}

return function(p: BasePart, color: Color3, collide: boolean?)
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = not SMALL[p.Name]
	p.Material = Enum.Material.Wood
	p.Color = color
end
