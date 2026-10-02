--[[
	ZONA ZERO - script principal do servidor (Script "Main" em ServerScriptService).
	Liga os módulos da pasta "Game" e cuida da entrada/saída dos jogadores.
	Pra ajustar o jogo, mexa em ReplicatedStorage > Shared > Config.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameFolder = script.Parent:WaitForChild("Game")
local Registry = require(GameFolder.Registry)

Registry.Remotes = require(GameFolder.Remotes)
Registry.Data = require(GameFolder.Data)
Registry.Combat = require(GameFolder.Combat)
Registry.Loot = require(GameFolder.Loot)
Registry.Zone = require(GameFolder.Zone)
Registry.Bots = require(GameFolder.Bots)
Registry.Match = require(GameFolder.Match)

Players.CharacterAutoLoads = false -- o jogo decide quando cada um nasce (lobby / partida)

-- Cada sistema liga sozinho; se um der erro, os outros continuam
for _, name in { "Combat", "Loot", "Zone", "Bots", "Match" } do
	local ok, err = pcall(Registry[name].Init)
	if not ok then
		warn("[Main] " .. name .. ".Init falhou:", err)
	end
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Player.JumpPower
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.BreakJointsOnDeath = false
	character:SetAttribute("Shield", 0)
	-- morreu fora de uma partida (no lobby): renasce. Quem morreu NA partida espera ela acabar.
	humanoid.Died:Connect(function()
		task.wait(4)
		if player.Parent and player.Character == character and not Registry.Match.EntryFor(player) then
			player:LoadCharacter()
		end
	end)
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = stats
	stats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)

	local profile = Registry.Data.Load(player)
	if not player.Parent then
		if profile.CanSave then
			Registry.Data.Save(player, true)
		end
		Registry.Data.Remove(player)
		return
	end
	if not profile.CanSave and not RunService:IsStudio() then
		player:Kick("Couldn't load your save (Roblox servers are busy). Your progress is safe - please rejoin!")
		return
	end
	Registry.Match.PublishStats(player)
	Registry.Combat.ResetPlayer(player)
	player:SetAttribute("Loaded", true)
	player:LoadCharacter() -- nasce no lobby (SpawnLocation do lobby)
end

local function onPlayerRemoving(player: Player)
	pcall(Registry.Match.OnPlayerRemoving, player)
	Registry.Data.Save(player, true)
	Registry.Data.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Salva todo mundo de tempos em tempos
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			task.spawn(Registry.Data.Save, player)
		end
	end
end)

-- Salva quando o servidor fecha
game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			Registry.Data.Save(player, true)
			pending -= 1
		end)
	end
	local started = os.clock()
	while (pending > 0 or Registry.Data.ActiveSaves() > 0) and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)
