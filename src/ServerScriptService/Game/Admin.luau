-- Painel de admin (só aparece para você): dinheiro, ovos na esteira, bichinhos, chocar agora,
-- eventos, resetar códigos/tutorial e "Admin Abuse". (ModuleScript em ServerScriptService > Game)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Admin = {}

local admins: { [Player]: boolean } = {}

local function checkAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if Config.Admins[player.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	-- Jogo de grupo: coloque os UserIds dos admins em Config.Admins
	return false
end

function Admin.SetupPlayer(player: Player)
	local isAdmin = checkAdmin(player)
	admins[player] = isAdmin
	player:SetAttribute("IsAdmin", isAdmin)
end

function Admin.RemovePlayer(player: Player)
	admins[player] = nil
end

local abuseRunning = false

function Admin.Handle(player: Player, command: any)
	if not admins[player] or typeof(command) ~= "string" then
		return
	end
	local Remotes = Registry.Remotes
	local CritterService = Registry.CritterService

	if command == "Cash1M" then
		Registry.Economy.AddCash(player, 1_000_000)
	elseif command == "Cash1B" then
		Registry.Economy.AddCash(player, 1_000_000_000)
	elseif command == "Cash1T" then
		Registry.Economy.AddCash(player, 1_000_000_000_000)
	elseif command == "UnlockWorlds" then
		Registry.Worlds.UnlockAll(player)
	elseif command == "Lucky" then
		Registry.Events.StartLucky()
	elseif command == "Rain" then
		Registry.Events.StartRain()
	elseif command == "SlotUp" then
		-- +1 vaga de graça (para testar o 2º andar rápido)
		Registry.Economy.GrantSlotUpgrade(player)
	elseif command == "Rebirth" then
		-- testar rebirth rápido: dá o dinheiro exato do próximo rebirth
		Registry.Economy.AddCash(player, Config.RebirthCost(Registry.Economy.GetRebirths(player)))
	elseif Config.EggById[command] then
		-- ovo escolhido aparece na esteira
		CritterService.SpawnEggOnConveyor(Config.EggById[command])
	elseif Config.RarityByName[command] then
		-- bichinho da raridade escolhida direto na sua base
		CritterService.GrantCritter(player, CritterService.RandomDef(command).Id, nil)
	elseif Config.MutationByName[command] then
		-- bichinho Épico ou melhor já com a mutação escolhida
		local rarity = ({ "Epic", "Legendary", "Mythic" })[math.random(1, 3)]
		CritterService.GrantCritter(player, CritterService.RandomDef(rarity).Id, command)
	elseif command == "HatchNow" then
		CritterService.HatchAllNow(player)
	elseif command == "ResetCodes" then
		local profile = Registry.Data.Get(player)
		if profile then
			profile.Data.Codes = {}
		end
	elseif command == "ResetTutorial" then
		local profile = Registry.Data.Get(player)
		if profile then
			profile.Data.TutorialDone = false
			player:SetAttribute("TutorialStep", nil)
			Registry.Tutorial.Start(player)
		end
	elseif command == "Give5Same" then
		-- 5 bichinhos iguais na mochila (para testar a fusão)
		Registry.Pets.AdminGive(player, CritterService.RandomDef("Rare").Id, nil, 5)
	elseif command == "Give3D" then
		-- v14: os 6 bichinhos que têm modelo 3D (mais um Gold para ver a "estátua") na mochila
		for _, id in { "coconutcrab", "islandtortoise", "tinyrex", "amberraptor", "glowsquid", "isopodking" } do
			Registry.Pets.AdminGive(player, id, nil, 1)
		end
		Registry.Pets.AdminGive(player, "tinyrex", "Gold", 1)
	elseif command == "Give5Gold" then
		-- 5 Gold iguais (fusão em Rainbow)
		Registry.Pets.AdminGive(player, CritterService.RandomDef("Epic").Id, "Gold", 5)
	elseif command == "PassOn" then
		Registry.Season.GrantPass(player)
	elseif command == "XP500" then
		Registry.Season.AddXP(player, 500, "Admin")
	elseif command == "Boost5" then
		Registry.Codes.AddBoost(player, 5)
	elseif command == "ShieldOff" then
		-- acaba o escudo de novato de TODOS no servidor (para testar roubo sem esperar 10 min)
		for _, other in Players:GetPlayers() do
			Registry.Fairness.EndShield(other)
		end
	elseif command == "ShieldMe" then
		-- você volta a ter 10 min de escudo
		Registry.Fairness.RestartShield(player)
	elseif command == "WeatherRain" or command == "WeatherSnow" or command == "WeatherSun" then
		Registry.Environment.SetWeather(string.sub(command, 8))
	elseif command == "NightNow" then
		Registry.Environment.ForceNight(180)
	elseif command == "ShinyNext" then
		-- o próximo ovo comprado (ou o próximo prêmio do Ovo Gigante) sai SHINY
		CritterService.ShinyNext = true
	elseif command == "GiantEggFill" then
		Registry.GiantEgg.AdminFill(player)
	elseif command == "Invasion" then
		Registry.LiveEvents.StartInvasion()
	elseif command == "Bandit" then
		if not Config.Bandits or not Config.Bandits.Enabled then
			Registry.Remotes.Notify(player, "Bandit is OFF (Config.Bandits.Enabled = false).", "warning")
		elseif not Registry.Bandits.ForceVisit(player) then
			Registry.Remotes.Notify(player, "Bandit already on the way (or no base).", "warning")
		end
	elseif command == "VoteNow" then
		Registry.LiveEvents.StartVote()
	elseif command == "Halloween" or command == "Winter" or command == "Valentine" or command == "Summer" then
		Registry.LiveEvents.ForceHoliday(string.lower(command))
	elseif command == "HolidayOff" then
		Registry.LiveEvents.ForceHoliday(nil)
	elseif command == "CreatorVisit" then
		Registry.LiveEvents.CreatorArrived(nil)
	elseif command == "Goal10K" then
		Registry.LiveEvents.AdminAddLocal(10000) -- só neste servidor (não muda a meta de verdade)
	elseif string.sub(command, 1, 2) == "Mg" and Config.MinigameById[string.sub(command, 3)] then
		-- anuncia esse minigame agora (admin: começa mesmo com pouca gente)
		Registry.Minigames.Announce(string.sub(command, 3), true)
	elseif command == "IslandOpen" then
		Registry.Explore.ForceIsland(300) -- ilha secreta aberta agora por 5 min
	elseif command == "AdminAbuse" then
		if abuseRunning then
			return
		end
		abuseRunning = true
		Remotes.NotifyAll("ADMIN ABUSE! Royal and COSMIC eggs incoming!", "rare")
		Remotes.EffectAll("Lucky")
		task.spawn(function()
			for i = 1, 12 do
				local egg = Config.EggById[if i % 3 == 0 then "cosmic" else "royal"]
				CritterService.SpawnEggOnConveyor(egg, nil, true)
				task.wait(1.5)
			end
			abuseRunning = false
		end)
	else
		return
	end
	Remotes.Notify(player, "Admin: " .. command, "info")
end

function Admin.Init()
	Players.PlayerRemoving:Connect(Admin.RemovePlayer)
end

return Admin
