--!strict
-- 차선 도색: 세종대로·소월로 중앙선(노란 겹선)·차로 사이 흰 점선·가장자리 흰 실선·버스전용차로 파란 선 (데이터 Shared.Lanes).
-- 도로 차량과 같은 단면·t에서 그리므로 차선과 차로가 늘 맞는다. 세계 좌표에 바로 놓는다 (건물 자리로 다시 돌리지 않는다).
-- 얇은 판을 차도 면(Plaza.road(z)) 1~2 cm 위에 눕힌다. 실선은 단면 사이 한 변에 판 하나, 점선은 칠한 칸마다 판 하나.
-- 횡단보도(Plaza.crosswalks)와 겹치는 곳은 끊는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Core.Units)
local Plaza = require(ReplicatedStorage.Shared.Plaza)
local Lanes = require(ReplicatedStorage.Shared.Lanes)
local site = require(ReplicatedStorage.Shared.Site)
local setup = require(script.Parent.Member)

local S = Units.studs(1)
local WIDTH = 0.15 -- 차선 폭 (근사: 국내 일반 도로 15 cm)
local THICK = 0.01
local LIFT = 0.015 -- 판 가운데 높이 (차도 면 위 1~2 cm)
local DASH, GAP = 3, 5 -- 근사: 시가지 점선 칠 3 m, 빈칸 5 m
local DOUBLE = 0.15 -- 겹선 두 줄 가운데가 선 가운데에서 떨어진 거리
local NAME = { Solid = "ChaseonWhite", Dashed = "ChaseonWhite", Yellow = "ChaseonYellow", Blue = "ChaseonBlue" }

local model: Model

-- 건물 축 점 p가 횡단보도 위인가 (줄무늬 폭 + 양옆 0.5 m)
local function onCrosswalk(p: Vector3): boolean
	for _, c in Plaza.crosswalks do
		local a, b = Vector3.new(c[1], 0, c[2]), Vector3.new(c[3], 0, c[4])
		local v = b - a
		local t = (p - a):Dot(v) / v:Dot(v)
		if t >= 0 and t <= 1 and (a + v * t - p).Magnitude < Plaza.crosswalkWidth / 2 + 0.5 then
			return true
		end
	end
	return false
end

-- 건물 축 a→b에 판 하나 (횡단보도와 겹치는 곳은 잘라 낸다)
local function stripe(name: string, a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	if len < 0.05 then
		return
	end
	-- 0.25 m마다 횡단보도 밖인 구간만 남긴다
	local runs, start = {}, nil :: number?
	local n = math.ceil(len / 0.25)
	for k = 0, n do
		local d = len * k / n
		local free = not onCrosswalk(a:Lerp(b, d / len))
		if free and not start then
			start = d
		elseif not free and start then
			table.insert(runs, { start, d })
			start = nil
		end
	end
	if start then
		table.insert(runs, { start, len })
	end
	for _, r in runs do
		local p, q = a:Lerp(b, r[1] / len), a:Lerp(b, r[2] / len)
		local wp = site:PointToWorldSpace(Vector3.new(p.X, Plaza.road(p.Z) + LIFT, p.Z) * S)
		local wq = site:PointToWorldSpace(Vector3.new(q.X, Plaza.road(q.Z) + LIFT, q.Z) * S)
		local part = Instance.new("Part")
		part.Name = name
		setup(part)
		part.CastShadow = false
		part.Size = Vector3.new(WIDTH * S, THICK * S, (wq - wp).Magnitude)
		part.CFrame = CFrame.lookAt((wp + wq) / 2, wq)
		part.Parent = model
	end
end

-- 선 하나를 단면 사이 변마다 그린다. 점선 박자는 선 처음부터 이어 센다
local function draw(road: Lanes.Road, line: Lanes.Line)
	local pts = Lanes.marking(road, line.t)
	local across = {} -- 단면마다 a→b 방향 (겹선을 옆으로 벌릴 때)
	for i = road.marked[1], road.marked[2] do
		local s = road.stations[i]
		table.insert(across, (s[2] - s[1]).Unit)
	end
	local s0 = 0
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local len = (b - a).Magnitude
		local kind = line.kind
		if line.busEnd and (a.Z + b.Z) / 2 > line.busEnd then
			kind = "Dashed"
		end
		local name = NAME[kind]
		if kind == "Yellow" then
			for _, side in { -1, 1 } do
				stripe(name, a + across[i - 1] * side * DOUBLE, b + across[i] * side * DOUBLE)
			end
		elseif kind == "Dashed" then
			-- 이 변 안에서 칠할 칸 [d0, d1]: 선 전체 거리 s0 + d가 (DASH + GAP) 주기의 앞 DASH 안
			local period = DASH + GAP
			local d = -(s0 % period)
			while d < len do
				local d0, d1 = math.max(d, 0), math.min(d + DASH, len)
				if d1 > d0 then
					stripe(name, a:Lerp(b, d0 / len), a:Lerp(b, d1 / len))
				end
				d += period
			end
		else
			stripe(name, a, b)
		end
		s0 += len
	end
end

return function()
	if workspace:FindFirstChild("Chaseon") then
		return
	end
	model = Instance.new("Model")
	model.Name = "Chaseon"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 차도(Gwangjang)와 같이 늘 보이게
	for _, road in { Lanes.sejong, Lanes.sowol } do
		for _, line in road.lines do
			draw(road, line)
		end
	end
	model.Parent = workspace
end
