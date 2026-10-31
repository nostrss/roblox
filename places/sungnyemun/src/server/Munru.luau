--!strict
-- 문루 마감(데이터 Shared.Munru): 하층·상층 장마루와 귀틀·장선·동바리.
-- 건물 축(정면 +Z, 동 +X)으로 짓고 init.server가 건물 자리로 돌린다(ADR 0004). Part만 쓴다.
-- 부딪힘: 걷는 면(마루널)만 켜고 받침 부재는 끈다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local D = require(ReplicatedStorage.Shared.Dimensions)
local K = require(ReplicatedStorage.Shared.Chukbu)
local M = require(ReplicatedStorage.Shared.Munru)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local L = D.level
local F, U = L.pavilionFloor, L.upperFloor -- 하층·상층 마루 윗면
local B = M.board

local model: Model
local rng = Random.new(2)

local function y(level: number): number
	return level - L.ground
end

local function positions(bays: { number }): { number }
	local total = 0
	for _, b in bays do
		total += b
	end
	local out = { -total / 2 }
	for _, b in bays do
		table.insert(out, out[#out] + b)
	end
	return out
end

-- cf·size는 m (cf의 Y는 지면 위 높이)
local function part(name: string, cf: CFrame, size: Vector3, collide: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	setup(p, collide)
	p.Size = size * S
	p.CFrame = CFrame.new(cf.Position * S) * cf.Rotation
	p.Parent = model
	return p
end

-- 두 꼭짓점 상자. 높이는 level
local function block(name: string, x0: number, l0: number, z0: number, x1: number, l1: number, z1: number, collide: boolean?): BasePart?
	if x1 - x0 < 1e-3 or l1 - l0 < 1e-3 or z1 - z0 < 1e-3 then
		return nil
	end
	return part(name, CFrame.new((x0 + x1) / 2, (y(l0) + y(l1)) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, l1 - l0, z1 - z0), collide)
end

-- 평면 사각형 r에서 구멍 h를 뺀 나머지 (최대 4개)
type Rect = { x0: number, x1: number, z0: number, z1: number }
local function minus(r: Rect, h: Rect?): { Rect }
	if not h or h.x0 >= r.x1 or h.x1 <= r.x0 or h.z0 >= r.z1 or h.z1 <= r.z0 then
		return { r }
	end
	local out = {}
	local ax0, ax1 = math.max(r.x0, h.x0), math.min(r.x1, h.x1)
	if r.x0 < h.x0 then
		table.insert(out, { x0 = r.x0, x1 = h.x0, z0 = r.z0, z1 = r.z1 })
	end
	if h.x1 < r.x1 then
		table.insert(out, { x0 = h.x1, x1 = r.x1, z0 = r.z0, z1 = r.z1 })
	end
	if r.z0 < h.z0 then
		table.insert(out, { x0 = ax0, x1 = ax1, z0 = r.z0, z1 = h.z0 })
	end
	if h.z1 < r.z1 then
		table.insert(out, { x0 = ax0, x1 = ax1, z0 = h.z1, z1 = r.z1 })
	end
	return out
end

-- 마루널: 동서로 긴 널을 남북으로 줄지어 깐다. 마루 가운데(x 0)에서 잇는다 (S7 p.262). 줄 사이 3 mm 틈으로 널 줄이 보이게
local function boards(r: Rect, top: number, hole: Rect?)
	local n = math.max(1, math.round((r.z1 - r.z0) / B.width))
	local w = (r.z1 - r.z0) / n
	for i = 0, n - 1 do
		for _, half in { { r.x0, 0 }, { 0, r.x1 } } do
			local row = { x0 = half[1], x1 = half[2], z0 = r.z0 + i * w + 0.0015, z1 = r.z0 + (i + 1) * w - 0.0015 }
			for _, q in minus(row, hole) do
				local p = block("Maruneol", q.x0, top - B.thickness, q.z0, q.x1, top, q.z1, true)
				if p then
					p.Color = p.Color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12)) -- 널마다 명도를 조금 흔든다
				end
			end
		end
	end
end

-- 칸마다 같은 간격으로 나눈 부재 x 좌표
local function spaced(cols: { number }, spacing: number): { number }
	local out = {}
	for i = 1, #cols - 1 do
		local bay = cols[i + 1] - cols[i]
		local n = math.max(1, math.round(bay / spacing))
		for k = 1, n do
			table.insert(out, cols[i] + (k - 0.5) * bay / n)
		end
	end
	return out
end

-- 상층 마루 계단 구멍 (계단 옆판 바깥 + 난간지방 폭)
local St = M.stair
local holeHalf = St.tread.length / 2 + St.stringer.thickness + M.railing.base.width
local hole: Rect = { x0 = St.top, x1 = St.opening, z0 = St.z - holeHalf, z1 = St.z + holeHalf }

local xs, zs = positions(D.lowerBays), positions(D.lowerSideBays)
local ux, uz = positions(D.upperBays), positions(D.upperSideBays)
local lx, lz, px, pz = xs[#xs], zs[#zs], ux[#ux], uz[#uz]

-- 17. 하층 장마루: 앞뒤 기둥열 장귀틀 → 장선(남북) → 마루널. 장선 가운데는 동바리가 받친다
local function lowerFloor()
	local G, J, Db = M.lower.jangGwiteul, M.lower.jangseon, M.lower.dongbari
	local jTop = F - B.thickness -- 장선 윗면
	local gTop = jTop - J.height -- 장귀틀 윗면
	for _, z in { -lz, lz } do
		for i = 1, #xs - 1 do
			local r = K.column.lowerDia / 2
			block("JangGwiteul", xs[i] + r, gTop - G.height, z - G.width / 2, xs[i + 1] - r, gTop, z + G.width / 2)
		end
	end
	for _, x in spaced(xs, J.spacing) do
		block("Jangseon", x - J.width / 2, gTop, -J.length / 2, x + J.width / 2, jTop, J.length / 2)
		block("Dongbari", x - Db.width / 2, 0, -Db.width / 2, x + Db.width / 2, gTop, Db.width / 2)
	end
	boards({ x0 = -lx, x1 = lx, z0 = -lz, z1 = lz }, F)
end

-- 17. 상층 장마루: 고주열 장귀틀(동서) → 동귀틀(남북, 장귀틀 ~ 하인방) → 마루널. 계단 구멍은 비운다
local function upperFloor()
	local G, Dg = M.upper.jangGwiteul, M.upper.dongGwiteul
	local top = U - B.thickness
	for i = 1, #ux - 1 do
		block("JangGwiteul", ux[i], top - G.height, -G.width / 2, ux[i + 1], top, G.width / 2)
	end
	local edge = pz - 0.054 -- 하인방 안쪽 면 (하인방 폭 108의 절반)
	for _, x in spaced(ux, Dg.spacing) do
		for _, sz in { -1, 1 } do
			local za, zb = sz * G.width / 2, sz * edge
			local r = { x0 = x - Dg.width / 2, x1 = x + Dg.width / 2, z0 = math.min(za, zb), z1 = math.max(za, zb) }
			for _, q in minus(r, hole) do
				block("DongGwiteul", q.x0, top - Dg.height, q.z0, q.x1, top, q.z1)
			end
		end
	end
	boards({ x0 = -px, x1 = px, z0 = -pz, z1 = pz }, U, hole)
end

return function()
	if workspace:FindFirstChild("Munru") then
		return
	end
	model = Instance.new("Model")
	model.Name = "Munru"
	lowerFloor()
	upperFloor()
	model.Parent = workspace
end
