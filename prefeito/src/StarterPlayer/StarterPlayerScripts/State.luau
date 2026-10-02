--[[
	State (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	O que o cliente sabe da própria cidade: o último painel mandado pelo servidor (Stats) e a grade
	de qualquer terreno, montada a partir dos prédios no Workspace (Lots > LotN > Buildings).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared.Buildings)
local Grid = require(Shared.Grid)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local State = {}

State.Stats = nil :: any
State.Changed = Instance.new("BindableEvent")

Remotes:WaitForChild("Stats").OnClientEvent:Connect(function(stats)
	State.Stats = stats
	State.Changed:Fire(stats)
end)

function State.Request(action: string, payload: any?)
	Remotes.Request:FireServer(action, payload)
end

function State.Lot(): number?
	local stats = State.Stats
	if stats then
		return stats.Lot
	end
	local lot = player:GetAttribute("Lot")
	return if type(lot) == "number" then lot else nil
end

function State.LotModel(index: number?): Model?
	local lots = workspace:FindFirstChild("Lots")
	if not lots or not index then
		return nil
	end
	return lots:FindFirstChild("Lot" .. index) :: Model?
end

-- Grade montada a partir dos modelos (cache por terreno; refaz quando um prédio entra ou sai)
local grids: { [number]: { State: Grid.State?, Dirty: boolean, Hooked: boolean } } = {}

function State.Grid(index: number): Grid.State
	local entry = grids[index]
	if not entry then
		entry = { State = nil, Dirty = true, Hooked = false }
		grids[index] = entry
	end
	local model = State.LotModel(index)
	local folder = model and model:FindFirstChild("Buildings")
	if folder and not entry.Hooked then
		entry.Hooked = true
		folder.ChildAdded:Connect(function()
			entry.Dirty = true
		end)
		folder.ChildRemoved:Connect(function()
			entry.Dirty = true
		end)
	end
	if entry.Dirty or not entry.State then
		local state = Grid.new()
		if folder then
			for _, child in folder:GetChildren() do
				local def = Buildings.ById[child:GetAttribute("Id")]
				local x, z, r = child:GetAttribute("X"), child:GetAttribute("Z"), child:GetAttribute("R")
				local uid = child:GetAttribute("Uid")
				if def and type(x) == "number" and type(z) == "number" and type(r) == "number" and type(uid) == "number" then
					state.NextUid = uid
					Grid.Place(state, def, x, z, r)
				end
			end
		end
		entry.State = state
		entry.Dirty = false
	end
	return entry.State :: Grid.State
end

function State.MarkDirty(index: number)
	local entry = grids[index]
	if entry then
		entry.Dirty = true
	end
end

return State
