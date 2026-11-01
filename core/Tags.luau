--!strict
-- CollectionService 태그 이름. 새 태그는 여기에만 추가한다.
return {
	GREYBOX = "Greybox", -- 실측 회색 박스. Studio 모델로 대체되면 숨기거나 지운다.
	MEMBER_MESHES = "MemberMeshes", -- 업로드한 부재 메시(MeshPart)를 모은 Folder. 자식 이름 = 부재 종류
	-- 야간 조명: 해 질 녘 켜고 새벽에 끈다(core TimeOfDay, 클라이언트). 붙인 인스턴스와 그 자손 중
	-- Light는 Brightness를, Neon 파트는 Transparency를 바꾼다. Studio에 둔 값이 "켜진" 상태 = 밤의 밝기다.
	-- 조명 하나(Light)·기구 파트·묶은 Model 어디에 붙여도 된다.
	NIGHT_LIGHT = "NightLight",
	-- 지붕 분해 표식: 다가가 누르면 내 화면에서만 문루가 겹별로 떠오른다(core RoofSplit, 클라이언트). Part 하나에 붙인다
	ROOF_SPLIT_MARKER = "RoofSplitMarker",
}
