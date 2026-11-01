--!strict
-- 현판을 상층 남쪽 어칸 앞에 건다 (데이터 Shared.Hyeonpan). 정면 = +Z (ADR 0004: 건물 축으로 짓고 통째로 돌린다).
-- 판 좌표: 원점 = 아래 끝 가운데 뒷면, X = 가로, Y = 위(숙인 방향), 앞 = −Z(Roblox Front 면이 바깥을 보게).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local H = require(ReplicatedStorage.Shared.Hyeonpan)
local setup = require(script.Parent.Member)

local S = Units.studs(1)

return function()
	if workspace:FindFirstChild("Hyeonpan") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Hyeonpan"
	local t = math.rad(H.tiltDeg)
	local up = Vector3.new(0, math.cos(t), math.sin(t)) -- 위가 앞(+Z)으로 숙는다
	local back = Vector3.new(0, math.sin(t), -math.cos(t)) -- 판 뒤쪽 (= 로컬 +Z)
	local right = up:Cross(back)
	local top = Vector3.new(0, H.hang.top - D.level.ground, H.hang.back)
	local origin = CFrame.fromMatrix((top - up * H.height) * S, right, up, back)

	-- 블록 하나: 판 좌표 가로 x0..x1, 높이 y0..y1, 앞으로 깊이 d0..d1 (뒷면 0, 앞 +)
	local function block(name: string, color: Color3, x0: number, x1: number, y0: number, y1: number, d0: number, d1: number): Part
		local p = Instance.new("Part")
		p.Name = name
		setup(p)
		p.Color = color -- 현판 색은 Shared.Hyeonpan.colors
		p.Size = Vector3.new(x1 - x0, y1 - y0, d1 - d0) * S
		p.CFrame = origin * CFrame.new(Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, -(d0 + d1) / 2) * S)
		p.Parent = model
		return p
	end

	local C = H.colors
	local hb, hp = H.body / 2, H.panelWidth / 2
	local y1 = H.legs + H.bottomBand -- 판면 아래
	local y2 = y1 + H.panelHeight -- 판면 위
	local dp = H.depth - H.panelRecess -- 판면 앞면 깊이
	-- 판면 + 글씨
	local panel = block("Panel", C.panel, -hp, hp, y1, y2, 0, dp)
	if H.glyphs ~= "" then
		local decal = Instance.new("Decal")
		decal.Name = "Glyphs"
		decal.Face = Enum.NormalId.Front
		decal.Texture = H.glyphs
		decal.Parent = panel
	else
		warn("현판: Shared.Hyeonpan.glyphs 가 비어 있어 글씨 없이 놓음 (textures/hyeonpan_glyphs.png 업로드 필요)")
	end
	-- 테두리 (녹): 좌우 띠, 아래 띠, 위 띠(선대, 전체 가로)
	block("Frame", C.green, -hb, -hp, y1, y2, 0, H.depth)
	block("Frame", C.green, hp, hb, y1, y2, 0, H.depth)
	block("Frame", C.green, -hb, hb, H.legs, y1, 0, H.depth)
	block("Frame", C.green, -hb, hb, y2, H.height, 0, H.depth)
	-- 위 선대가 몸체 밖으로 나온 팔 (삼청)
	block("Seondae", C.samcheong, -H.width / 2, -hb, y2, H.height, 0, H.depth)
	block("Seondae", C.samcheong, hb, H.width / 2, y2, H.height, 0, H.depth)
	-- 색대: 판면 둘레 황, 몸체 바깥 가장자리 장단 (앞면에 얇게)
	local L, f0, f1 = H.line, H.depth, H.depth + 0.005
	block("Line", C.yellow, -hp - L, hp + L, y2, y2 + L, f0, f1)
	block("Line", C.yellow, -hp - L, hp + L, y1 - L, y1, f0, f1)
	block("Line", C.yellow, -hp - L, -hp, y1, y2, f0, f1)
	block("Line", C.yellow, hp, hp + L, y1, y2, f0, f1)
	block("Line", C.jangdan, -hb, -hb + L, H.legs, H.height, f0, f1)
	block("Line", C.jangdan, hb - L, hb, H.legs, H.height, f0, f1)
	-- 아래 다리 2개
	for _, s in { -1, 1 } do
		local x = s * (hb - H.leg.inset)
		block("Leg", C.green, x - H.leg.width / 2, x + H.leg.width / 2, 0, H.legs, 0, H.depth * 0.8)
	end
	model.Parent = workspace
end
