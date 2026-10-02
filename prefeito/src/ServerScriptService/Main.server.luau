--[[
	Main (Script em ServerScriptService)          Prefeito Tycoon
	Liga tudo: monta os terrenos, carrega e salva os jogadores, liga os eventos e a loja.
	Cada sistema começa dentro de um pcall: se um quebrar, o resto do jogo continua.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LotLayout = require(ReplicatedStorage.Shared.LotLayout)

local Game = script.Parent:WaitForChild("Game")
local Data = require(Game.Data)
local Remotes = require(Game.Remotes)
local Lots = require(Game.Lots)
local Events = require(Game.Events)
local City = require(Game.City)
local Products = require(Game.Products)
local Leaderboards = require(Game.Leaderboards)

Players.CharacterAutoLoads = true

for _, system in { { "Lots", Lots }, { "Events", Events }, { "City", City }, { "Products", Products }, { "Leaderboards", Leaderboards } } do
	local ok, err = pcall((system[2] :: any).Init)
	if not ok then
		warn("[Main] " .. system[1] .. " não iniciou:", err)
	end
end

local function onCharacter(player: Player, character: Model)
	local lot = player:GetAttribute("Lot")
	if type(lot) ~= "number" then
		return
	end
	local humanoidRoot = character:WaitForChild("HumanoidRootPart", 10)
	if humanoidRoot and character.Parent then
		task.wait() -- deixa o Roblox terminar de posicionar o spawn
		character:PivotTo(LotLayout.SpawnCFrame(lot))
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	local profile = Data.Load(player)
	if not player.Parent then
		-- saiu enquanto carregava: o Load já gravou a trava de sessão, então salva para soltar a trava
		Data.Save(player, true)
		Data.Remove(player)
		return
	end
	local ok, err = pcall(City.Start, player, profile)
	if not ok then
		warn("[Main] City.Start falhou para", player.Name, err)
		Remotes.Notify(player, "Erro ao abrir sua cidade. Entre de novo.", "erro")
		return
	end
	task.spawn(Products.CheckPasses, player)
end

local function onPlayerRemoving(player: Player)
	City.Stop(player) -- copia a cidade para os dados e libera o terreno antes do save (que pode demorar)
	Data.Save(player, true)
	Data.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- salva todo mundo de tempos em tempos
task.spawn(function()
	while true do
		task.wait(Config.AutosaveEvery)
		for _, player in Players:GetPlayers() do
			task.spawn(Data.Save, player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		task.spawn(Data.Save, player, true)
	end
	local waited = 0
	task.wait(0.5)
	while Data.ActiveSaves() > 0 and waited < 25 do
		waited += task.wait(0.25)
	end
end)
