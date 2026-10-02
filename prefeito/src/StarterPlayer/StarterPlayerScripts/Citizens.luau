--[[
	Citizens (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	Moradores andando pelas ruas (só enfeite, só no seu computador: o servidor não sabe deles).
	Quanto mais gente na cidade, mais pedestres (até um limite). Só desenha cidades perto da câmera.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Buildings = require(Shared.Buildings)
local LotLayout = require(Shared.LotLayout)

local Scripts = script.Parent
local State = require(Scripts.State)

local Citizens = {}

local MAX_PER_LOT = 14
local PER_WALKER = 30 -- 1 pedestre a cada 30 moradores
local VIEW_DISTANCE = 520
local N = Config.GridSize

local SHIRTS = {
	Color3.fromRGB(60, 90, 160), Color3.fromRGB(170, 60, 60), Color3.fromRGB(60, 140, 90),
	Color3.fromRGB(200, 170, 60), Color3.fromRGB(90, 90, 100), Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(120, 70, 150), Color3.fromRGB(40, 40, 46),
}
local SKINS = { Color3.fromRGB(240, 205, 170), Color3.fromRGB(200, 150, 110), Color3.fromRGB(140, 95, 65), Color3.fromRGB(90, 60, 45) }

type Walker = { Body: Part, Head: Part, X: number, Z: number, Alive: boolean }

local folder: Folder
local walkers: { [number]: { Walker } } = {}

local function roadSet(lot: number): ({ [number]: boolean }, { { number } })
	local state = State.Grid(lot)
	local set, list = {}, {}
	for x = 1, N do
		set[Grid.Index(x, Config.AvenueRow)] = true
		table.insert(list, { x, Config.AvenueRow })
	end
	for _, placed in state.Buildings do
		local def = Buildings.ById[placed.Id]
		if def and def.Category == "road" then
			set[Grid.Index(placed.X, placed.Z)] = true
			table.insert(list, { placed.X, placed.Z })
		end
	end
	return set, list
end

local function makeWalker(lot: number, start: { number }): Walker
	local body = Instance.new("Part")
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.Size = Vector3.new(1.1, 2.4, 0.7)
	body.Color = SHIRTS[math.random(1, #SHIRTS)]
	body.Material = Enum.Material.SmoothPlastic
	local head = body:Clone()
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(0.9, 0.9, 0.9)
	head.Color = SKINS[math.random(1, #SKINS)]
	local walker: Walker = { Body = body, Head = head, X = start[1], Z = start[2], Alive = true }
	local side = if math.random() < 0.5 then -2.8 else 2.8
	local cf = LotLayout.CellCFrame(lot, walker.X, walker.Z) * CFrame.new(side, 1.5, 0)
	body.CFrame = cf
	head.CFrame = cf * CFrame.new(0, 1.65, 0)
	body.Parent = folder
	head.Parent = folder

	task.spawn(function()
		while walker.Alive do
			local set = roadSet(lot)
			local options = {}
			for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local nx, nz = walker.X + step[1], walker.Z + step[2]
				if nx >= 1 and nx <= N and nz >= 1 and nz <= N and set[Grid.Index(nx, nz)] then
					table.insert(options, { nx, nz })
				end
			end
			if #options == 0 then
				task.wait(2)
			else
				local nextCell = options[math.random(1, #options)]
				local from = LotLayout.CellCFrame(lot, walker.X, walker.Z)
				local to = LotLayout.CellCFrame(lot, nextCell[1], nextCell[2])
				walker.X, walker.Z = nextCell[1], nextCell[2]
				local look = CFrame.lookAt(from.Position, to.Position)
				local goal = (look - look.Position + to.Position) * CFrame.new(side, 1.5, 0)
				local time = (to.Position - from.Position).Magnitude / 4.5
				TweenService:Create(body, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = goal }):Play()
				TweenService:Create(head, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = goal * CFrame.new(0, 1.65, 0) }):Play()
				task.wait(time + math.random() * 0.6)
			end
		end
		body:Destroy()
		head:Destroy()
	end)
	return walker
end

local function update()
	local camera = workspace.CurrentCamera
	local lots = workspace:FindFirstChild("Lots")
	if not camera or not lots then
		return
	end
	for _, lotModel in lots:GetChildren() do
		local index = lotModel:GetAttribute("Index")
		if type(index) == "number" then
			local list = walkers[index] or {}
			walkers[index] = list
			local near = (LotLayout.CFrame(index).Position - camera.CFrame.Position).Magnitude < VIEW_DISTANCE
			local population = lotModel:GetAttribute("Population") or 0
			local want = if near then math.clamp(population // PER_WALKER, 0, MAX_PER_LOT) else 0
			while #list > want do
				table.remove(list).Alive = false
			end
			if #list < want then
				local _, roads = roadSet(index)
				while #list < want and #roads > 0 do
					table.insert(list, makeWalker(index, roads[math.random(1, #roads)]))
				end
			end
		end
	end
end

function Citizens.Init()
	folder = Instance.new("Folder")
	folder.Name = "Citizens"
	folder.Parent = workspace
	task.spawn(function()
		while true do
			pcall(update)
			task.wait(2)
		end
	end)
end

return Citizens
