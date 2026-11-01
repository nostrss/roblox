--!strict
-- 광장·길 조경 (데이터 Shared.Jogyeong). 자료 좌표(건물 축)를 Shared.Site로 세계 좌표에 바로 놓는다.
-- 나무는 공개 메시를 불러 짓는다: 받지 못하면 경고만 남기고 그 나무를 건너뛴다 (나머지 Place는 그대로 돈다).
-- 조명은 Tags.NIGHT_LIGHT — 켜고 끄기는 클라이언트 core TimeOfDay.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Core.Tags)
local Units = require(ReplicatedStorage.Core.Units)
local Plaza = require(ReplicatedStorage.Shared.Plaza)
local J = require(ReplicatedStorage.Shared.Jogyeong)
local site = require(ReplicatedStorage.Shared.Site)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local LAMP = Color3.fromRGB(255, 206, 150) -- 근사: 따뜻한 백색 등
local LAMP_NEON = Color3.fromRGB(230, 180, 118) -- Bloom에 하얗게 날리지 않게 낮춘 색

for _, t in J.plaza do
	assert(Plaza.onFloor(t[1] :: number, t[2] :: number, 1.5) and Plaza.onLawn(t[1] :: number, t[2] :: number), `나무 ({t[1]}, {t[2]})가 광장 잔디 밖이다`)
end
for _, z in J.path.benchZ do
	assert(not Plaza.onLawn(J.path.edge - 1, z), `의자 z {z}가 흙 마당 밖이다`)
end

local model: Model

-- 세계 CFrame: 건물 축 (x, h, z) m, 위로 세운 채
local function at(x: number, h: number, z: number): CFrame
	return site * CFrame.new(Vector3.new(x, h, z) * S)
end

local function part(name: string, size: Vector3, cf: CFrame, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	setup(p, collide)
	p.Size = size * S
	p.CFrame = cf
	p.Parent = model
	return p
end

-- 스스로 빛나는 등 머리 + (light면) 광원. 태그로 낮에는 꺼진다
local function lampHead(size: number, cf: CFrame, light: { brightness: number, range: number }?)
	local p = part("Cheol", Vector3.new(size, size, size), cf)
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = LAMP_NEON
	p.CastShadow = false
	if light then
		local l = Instance.new("PointLight")
		l.Color = LAMP
		l.Brightness = light.brightness
		l.Range = light.range
		l.Parent = p
	end
	CollectionService:AddTag(p, Tags.NIGHT_LIGHT)
end

-- 길 조명: 무릎 높이 기둥
local function bollard(x: number, z: number, g: number, light: boolean)
	part("Cheol", Vector3.new(0.12, 0.8, 0.12), at(x, g + 0.4, z))
	lampHead(0.18, at(x, g + 0.86, z), if light then { brightness = 1.6, range = 40 } else nil)
end

-- 가로등: 기둥과 길 쪽으로 뻗은 팔. dir = 건물 축 수평 단위 벡터
local function streetLamp(x: number, z: number, g: number, dir: Vector3, height: number, reach: number, light: boolean)
	part("Cheol", Vector3.new(0.18, height, 0.18), at(x, g + height / 2, z))
	local tip = Vector3.new(x + dir.X * reach, g + height, z + dir.Z * reach)
	local mid = Vector3.new(x + dir.X * reach / 2, g + height, z + dir.Z * reach / 2)
	part("Cheol", Vector3.new(0.09, 0.09, reach), site * CFrame.lookAt(mid * S, tip * S))
	lampHead(0.42, site * CFrame.new((tip - Vector3.new(0, 0.1, 0)) * S), if light then { brightness = 1.6, range = 60 } else nil)
end

-- 바닥 경사를 따라 눕힌 상자: x 중심, z0..z1, 윗면이 바닥 + top
local function floorBox(name: string, x: number, z0: number, z1: number, width: number, top: number, collide: boolean?)
	local h0, h1 = Plaza.floor(z0), Plaza.floor(z1)
	local len = math.sqrt((z1 - z0) ^ 2 + (h1 - h0) ^ 2)
	local depth = top + 0.25 -- 경사에서 뜨지 않게 묻는다
	part(
		name,
		Vector3.new(width, depth, len),
		site
			* CFrame.new(Vector3.new(x, (h0 + h1) / 2, (z0 + z1) / 2) * S)
			* CFrame.Angles(-math.atan2(h1 - h0, z1 - z0), 0, 0)
			* CFrame.new(0, (top - depth / 2) * S, 0),
		collide
	)
end

-- 나무: 메시 조각마다 CreateMeshPartAsync. 같은 메시는 한 번만 받아 복제한다
local meshes: { [number]: MeshPart | false } = {}
local function meshOf(id: number): MeshPart?
	local m = meshes[id]
	if m == nil then
		local ok, result = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromAssetId(id), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
		end)
		if not ok then
			warn(`조경 메시 {id}을 받지 못했다: {result}`)
		end
		m = if ok then result else false
		meshes[id] = m :: MeshPart | false
	end
	return if m then m else nil
end

local function tree(name: string, x: number, g: number, z: number, scale: number, turn: number, collide: boolean)
	local pieces = (J.trees :: any)[name]
	local root = at(x, g, z) * CFrame.Angles(0, turn, 0)
	local holder = Instance.new("Model")
	holder.Name = name
	for _, piece in pieces do
		local src = meshOf(piece.mesh)
		if not src then
			continue
		end
		local p = src:Clone()
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = true
		p.Size = Vector3.new(piece.size[1], piece.size[2], piece.size[3]) * scale
		local c = piece.cf :: CFrame
		p.CFrame = root * (c - c.Position + c.Position * scale)
		p.TextureContent = Content.fromAssetId(piece.texture)
		p.Parent = holder
	end
	if collide and #holder:GetChildren() > 0 then
		-- 줄기에 부딪히게 보이지 않는 기둥 하나
		local trunk = Instance.new("Part")
		trunk.Name = "Julgi"
		trunk.Anchored = true
		trunk.Transparency = 1
		trunk.CanTouch = false
		trunk.CanQuery = false
		trunk.CastShadow = false
		trunk.Size = Vector3.new(0.5, 3, 0.5) * S
		trunk.CFrame = root * CFrame.new(0, 1.5 * S, 0)
		trunk.Parent = holder
	end
	holder.Parent = model
end

return function()
	if workspace:FindFirstChild("Jogyeong") then
		return
	end
	model = Instance.new("Model")
	model.Name = "Jogyeong"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 멀리서도 나무·가로등이 보이게
	model.Parent = workspace

	local P = J.path
	-- 정면 흙 마당 양옆: 경계석·생울타리
	for _, sx in { 1, -1 } do
		local z = P.z0
		while z < P.z1 do
			local z1 = math.min(z + P.segment, P.z1)
			local mid = (z + z1) / 2
			if Plaza.onFloor(sx * P.edge, mid, 0.5) then
				floorBox("Gyeonggyeseok", sx * P.edge, z, z1, P.kerb.width, P.kerb.height)
				local gap = false
				for _, g in P.gaps do
					gap = gap or math.abs(mid - g) < P.segment
				end
				local hx = sx * (P.edge + P.hedge.offset)
				if not gap and Plaza.onFloor(hx, mid, 0.5) then
					floorBox("Saengul", hx, z + 0.1, z1 - 0.1, P.hedge.width, P.hedge.height, true)
				end
			end
			z = z1
		end
		-- 의자: 흙 마당 가장자리에서 가운데를 본다
		for _, bz in P.benchZ do
			local x = sx * (P.edge - 0.9)
			if Plaza.onFloor(x, bz, 0.5) then
				local g = Plaza.floor(bz)
				local face = at(x, g, bz) * CFrame.Angles(0, sx * math.pi / 2, 0)
				part("UijaPan", Vector3.new(1.9, 0.08, 0.5), face * CFrame.new(0, 0.44 * S, 0), true)
				part("UijaDari", Vector3.new(0.12, 0.42, 0.46), face * CFrame.new(-0.75 * S, 0.21 * S, 0))
				part("UijaDari", Vector3.new(0.12, 0.42, 0.46), face * CFrame.new(0.75 * S, 0.21 * S, 0))
			end
		end
		-- 길 조명
		for _, lz in P.lightZ do
			local x = sx * (P.edge + 0.05)
			if Plaza.onFloor(x, lz, 0.2) then
				bollard(x, lz, Plaza.floor(lz), true) -- 저녁에 흙 마당 가운데가 어둡지 않게 모두 켠다
			end
		end
	end
	for _, b in J.backLights do
		bollard(b[1], b[2], Plaza.floor(b[2]), true)
	end

	-- 가로등: 박석 광장과 연석 안쪽. 팔은 도로(바깥) 쪽으로
	for _, b in J.bakseokLamps do
		assert(Plaza.onFloor(b[1], b[2], 0.5), `박석 가로등 ({b[1]}, {b[2]})이 바닥 밖이다`)
		streetLamp(b[1], b[2], Plaza.floor(b[2]), Vector3.new(0, 0, 1), 6, 1.2, true)
	end
	for _, i in J.curbLamps do
		local x, z = Plaza.radial(i, -0.7)
		local o = Vector3.new(x, 0, z).Unit
		streetLamp(x, z, Plaza.sidewalk(z), o, 9, 2.6, true)
	end

	-- 나무는 받는 동안 양보한다 (Place 나머지를 막지 않는다)
	task.spawn(function()
		for i, t in J.plaza do
			tree(t[3] :: string, t[1] :: number, Plaza.floor(t[2] :: number) - 0.05, t[2] :: number, t[4] :: number, i * 2.399, true)
		end
		local st = J.street
		local n = 0
		for _, span in st.spans do
			for i = span[1], span[2] - 1 do
				local x0, z0 = Plaza.roadFar(i)
				local x1, z1 = Plaza.roadFar(i + 1)
				local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
				local steps = math.max(1, math.floor(len / st.interval))
				for k = 0, steps - 1 do
					local a = k / steps
					local x, z = x0 + (x1 - x0) * a, z0 + (z1 - z0) * a
					local l = math.sqrt(x * x + z * z)
					x, z = x * (l + st.out) / l, z * (l + st.out) / l
					n += 1
					tree(st.kinds[n % #st.kinds + 1], x, Plaza.sidewalk(z) - 0.05, z, st.scale, n * 1.7, false)
				end
			end
		end
	end)
end
