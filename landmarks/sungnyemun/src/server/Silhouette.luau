--!strict
-- 주변 건물 (자리·크기 데이터 Shared.Silhouette, 입면 Shared.Facades). 세계 좌표에 바로 놓는다 — 건물 자리로 돌리지 않는다.
-- 건물 하나 = 몸체 + 1층 상점 띠 + 옥상 처마 + (높으면) 옥탑·위층 들여쌓기. 입면은 Texture, 밤 창 불빛은 SurfaceGui(태그 WINDOW_LIGHT)다.
-- 입면은 높이로 고른 근사다: 실제 건물을 사진으로 옮긴 것이 아니다.
-- 걸어 갈 수 없는 배경이라 부딪힘·조회를 끈다. 그림자도 끈다: 낮은 노을 해에 빌딩 그림자가 광장을 통째로 덮어 문루의 빛이 사라지고, 모바일 부담도 줄인다.
-- 바닥은 둘레 보도 면(Plaza.sidewalk)에 1 m 묻는다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Core.Tags)
local Units = require(ReplicatedStorage.Core.Units)
local Plaza = require(ReplicatedStorage.Shared.Plaza)
local Facades = require(ReplicatedStorage.Shared.Facades)
local boxes = require(ReplicatedStorage.Shared.Silhouette)
local site = require(ReplicatedStorage.Shared.Site)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local SINK = 1 -- 상자 바닥을 보도 면 아래로 묻는 깊이 (기운 면에서 뜨지 않게)
local LIT_PPM = 6 -- 창 불빛 SurfaceGui 해상도 (픽셀/m). 타일 경계가 흐려지면 올린다
local LIT_DISTANCE = 300 * S
local TONES = { "SilhouetteA", "SilhouetteB", "SilhouetteC" }
local NEAR = 170 -- 이 거리(m) 안 건물만 상점 띠·옥탑을 짓는다 (파트 수)
local PODIUM_MIN = 30 -- 이 높이(m) 이상이면 저층부를 넓게 낸다

type Style = { day: number, lit: number, base: Color3, reflect: number }

-- 면 이름, 면 법선(파트 축), 그 면 가로 길이가 어느 축인가
local FACES = {
	{ Enum.NormalId.Right, Vector3.xAxis, "Z" },
	{ Enum.NormalId.Left, -Vector3.xAxis, "Z" },
	{ Enum.NormalId.Back, Vector3.zAxis, "X" },
	{ Enum.NormalId.Front, -Vector3.zAxis, "X" },
}

-- 높이와 번호로 입면을 고른다 (같은 번호는 늘 같은 입면)
local function styleOf(i: number, h: number): Style
	local k = (i * 2654435761) % 97
	local s = Facades.styles
	if h >= 60 then
		return if k < 45 then s.glass elseif k < 70 then s.darkglass else s.stone
	elseif h >= 30 then
		return if k < 35 then s.stone elseif k < 60 then s.tile elseif k < 80 then s.glass else s.concrete
	end
	return if k < 45 then s.market elseif k < 75 then s.concrete else s.tile
end

-- 파트 네 옆면에 입면과 밤 불빛을 입힌다. lit 면은 문루 쪽을 보는 면만 (SurfaceGui 수)
local function dress(p: BasePart, style: Style, tileU: number, tileV: number, shiftU: number, shiftV: number, litFrom: Vector3?)
	for _, f in FACES do
		local face, normal, axis = f[1] :: Enum.NormalId, f[2] :: Vector3, f[3] :: string
		local t = Instance.new("Texture")
		t.Face = face
		t.Texture = `rbxassetid://{style.day}`
		t.StudsPerTileU = tileU * S
		t.StudsPerTileV = tileV * S
		t.OffsetStudsU = shiftU * S
		t.OffsetStudsV = shiftV * S
		t.Parent = p
		if litFrom then
			local world = p.CFrame:VectorToWorldSpace(normal)
			if world:Dot((litFrom - p.Position).Unit) > 0.05 then
				local w = (if axis == "Z" then p.Size.Z else p.Size.X) / S
				local h = p.Size.Y / S
				local g = Instance.new("SurfaceGui")
				g.Name = "Lit"
				g.Face = face
				g.LightInfluence = 0
				g.Brightness = 1.15
				g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
				g.CanvasSize = Vector2.new(math.ceil(w * LIT_PPM), math.ceil(h * LIT_PPM))
				g.Enabled = false
				g.MaxDistance = LIT_DISTANCE -- SurfaceGui는 대기(안개)를 안 받아 멀면 창만 떠 보인다
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Image = `rbxassetid://{style.lit}`
				img.ScaleType = Enum.ScaleType.Tile
				local tw, th = tileU * LIT_PPM, tileV * LIT_PPM
				img.TileSize = UDim2.fromOffset(tw, th)
				-- 낮 텍스처와 창이 겹치게 같은 만큼 민다 (타일 한 장 왼쪽·위에서 시작)
				img.Position = UDim2.fromOffset((shiftU % tileU) * LIT_PPM - tw, (shiftV % tileV) * LIT_PPM - th)
				img.Size = UDim2.new(1, tw, 1, th)
				img.Parent = g
				g.Parent = p
				CollectionService:AddTag(g, Tags.WINDOW_LIGHT)
			end
		end
	end
end

-- 무늬 없는 상자 (처마·옥탑)
local function plain(model: Model, name: string, frame: CFrame, size: Vector3, center: Vector3, color: Color3?): Part
	local p = Instance.new("Part")
	p.Name = name
	setup(p)
	p.CastShadow = false
	p.Material = Enum.Material.Concrete
	if color then
		p.Color = color
	end
	p.Size = size * S
	p.CFrame = frame * CFrame.new(center * S)
	p.Parent = model
	return p
end

-- 건물 축 (x, z) 점이 다각형 안인가
local function inside(x: number, z: number, poly: { { number } }): boolean
	local c = false
	for i, p in poly do
		local q = poly[i % #poly + 1]
		if (p[2] > z) ~= (q[2] > z) and x < p[1] + (q[1] - p[1]) * (z - p[2]) / (q[2] - p[2]) then
			c = not c
		end
	end
	return c
end

-- 보행 경계 안(광장·도로·맞은편 보도)과 세종대로 남쪽 연장 — 상자가 들어가면 안 되는 곳 (건물 축)
local keepOut: { { { number } } } = { {} }
for i = 1, #Plaza.curb do
	table.insert(keepOut[1], { Plaza.boundary(i) })
end
do
	local w1, w1far = { Plaza.curb[1][1], Plaza.curb[1][2] }, { Plaza.roadFar(1) }
	table.insert(keepOut, { w1, w1far, { Plaza.toEdge(w1far[1], w1far[2]) }, { Plaza.toEdge(w1[1], w1[2]) } })
end

return function()
	if workspace:FindFirstChild("Silhouette") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Silhouette"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 스트리밍 반경(모바일은 더 좁다) 밖 먼 상자도 늘 보이게. 상자 수가 적어 부담 없음
	for i, b in boxes do
		local x, z, u, v, deg, h = b[1], b[2], b[3], b[4], b[5], b[6]
		local rot = CFrame.Angles(0, -math.rad(deg), 0) -- 상자 +X(u축)를 세계 (cos, 0, sin)으로
		local frame = CFrame.new(site.Position + Vector3.new(x, 0, z) * S) * rot
		-- 네 귀와 변 위 2 m 간격 점이 도로·광장에 들어가지 않는지, 그 점들의 보도 높이 범위
		local lo, hi = math.huge, -math.huge
		for _, e in { { 1, 1, -1, 1 }, { -1, 1, -1, -1 }, { -1, -1, 1, -1 }, { 1, -1, 1, 1 } } do
			local steps = math.ceil(math.max(u, v) / 2)
			for k = 0, steps do
				local t = k / steps
				local du, dv = (e[1] + (e[3] - e[1]) * t) * u / 2, (e[2] + (e[4] - e[2]) * t) * v / 2
				local p = site:PointToObjectSpace(frame:PointToWorldSpace(Vector3.new(du, 0, dv) * S)) / S
				for _, poly in keepOut do
					assert(not inside(p.X, p.Z, poly), `실루엣 상자 {i}이 보행 경계 안이나 도로에 걸린다 ({x}, {z})`)
				end
				local g = Plaza.sidewalk(p.Z)
				lo, hi = math.min(lo, g), math.max(hi, g)
			end
		end
		local bottom, top = lo - SINK, (lo + hi) / 2 + h
		local style = styleOf(i, h)
		local shiftU = (i % 8) * 3 -- 건물마다 타일을 칸·층 단위로 밀어 같은 무늬가 나란히 서지 않게
		local shiftV = ((i * 3) % 8) * 3.5
		local near = frame.Position.Magnitude / S < NEAR
		local centerAt = site.Position -- 불 켜는 면 판단 기준: 문루 쪽

		local podium = h >= PODIUM_MIN and near
		local inset = if podium then 1.2 else 0
		local setback = h >= 70 and (i % 2 == 0)
		local bodyTop = if setback then lo + h * 0.82 else top
		local p = Instance.new("Part")
		p.Name = TONES[i % #TONES + 1]
		setup(p)
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = style.base
		p.Reflectance = style.reflect
		p.Size = Vector3.new(u - inset * 2, bodyTop - bottom, v - inset * 2) * S
		p.CFrame = frame * CFrame.new(0, (bottom + bodyTop) / 2 * S, 0)
		p.Parent = model
		dress(p, style, Facades.tileU, Facades.tileV, shiftU, shiftV, centerAt)

		if setback then -- 위층 들여쌓기
			local q = p:Clone()
			for _, c in q:GetChildren() do
				c:Destroy()
			end
			local d = math.min(u, v) * 0.14
			q.Size = Vector3.new(u - inset * 2 - d * 2, top - bodyTop, v - inset * 2 - d * 2) * S
			q.CFrame = frame * CFrame.new(0, (bodyTop + top) / 2 * S, 0)
			q.Parent = model
			dress(q, style, Facades.tileU, Facades.tileV, shiftU, shiftV, centerAt)
			plain(model, "GeonmulCheoma", frame, Vector3.new(u - inset * 2 + 0.3, 0.5, v - inset * 2 + 0.3), Vector3.new(0, bodyTop + 0.1, 0), style.base)
		end

		-- 옥상 처마 (난간 위 띠)
		local capU, capV = if setback then u - inset * 2 - math.min(u, v) * 0.28 else u - inset * 2, if setback then v - inset * 2 - math.min(u, v) * 0.28 else v - inset * 2
		plain(model, "GeonmulCheoma", frame, Vector3.new(capU + 0.3, 0.7, capV + 0.3), Vector3.new(0, top + 0.2, 0))

		if near then
			-- 1층 상점 띠: 몸체보다 조금 내민다
			local sh = Facades.shop
			local shop = Instance.new("Part")
			shop.Name = "GeonmulSangga"
			setup(shop)
			shop.CastShadow = false
			shop.Material = Enum.Material.SmoothPlastic
			shop.Color = sh.base
			shop.Reflectance = sh.reflect
			shop.Size = Vector3.new(u + 0.3, sh.height + SINK, v + 0.3) * S
			shop.CFrame = frame * CFrame.new(0, (bottom + bottom + sh.height + SINK) / 2 * S, 0)
			shop.Parent = model
			dress(shop, sh :: any, sh.tileU, sh.height + SINK, shiftU, 0, centerAt)
			if podium then -- 저층부: 상점 위 두 층을 넓게
				local base = p:Clone()
				for _, c in base:GetChildren() do
					c:Destroy()
				end
				base.Size = Vector3.new(u, 7, v) * S
				base.CFrame = frame * CFrame.new(0, (lo + sh.height + 3.5) * S, 0)
				base.Parent = model
				dress(base, Facades.styles.stone, Facades.tileU, Facades.tileV, shiftU, shiftV, centerAt)
			end
			-- 옥탑(기계실)·옥상 설비 (높이 12 m 이상)
			if h >= 12 then
				local k = (i * 31) % 10 / 10
				local pu, pv = math.max(capU * (0.3 + k * 0.2), 4), math.max(capV * (0.3 + (1 - k) * 0.2), 4)
				plain(model, "GeonmulOktap", frame, Vector3.new(pu, 3.5, pv), Vector3.new((k - 0.5) * capU * 0.3, top + 2.2, (0.5 - k) * capV * 0.3), Color3.fromRGB(150, 148, 142))
				plain(model, "GeonmulSeolbi", frame, Vector3.new(2.5, 1.6, 2.5), Vector3.new((0.5 - k) * capU * 0.32, top + 1.2, (k - 0.5) * capV * 0.32), Color3.fromRGB(120, 124, 128))
			end
		end
	end
	model.Parent = workspace
end
