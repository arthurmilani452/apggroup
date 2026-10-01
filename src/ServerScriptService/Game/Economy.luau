--[[
	Economy (ModuleScript em ServerScriptService > Game)
	Dinheiro, renda por segundo, loja de velocidade, vagas, esteira de treino, rebirth,
	bônus (índice, amigos, grupo, VIP), recompensa diária, dinheiro offline, códigos,
	game passes e pedidos que vêm da tela do jogador.
	Todo dinheiro muda SÓ aqui no servidor.
]]

local GroupService = game:GetService("GroupService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Economy = {}

local passes: { [Player]: { [string]: boolean } } = {}
local friendBonus: { [Player]: number } = {}
local groupMember: { [Player]: boolean } = {}
local indexCount: { [Player]: number } = {}
local friendCache: { [string]: boolean } = {}
local lastRequest: { [Player]: { [string]: number } } = {}
local trainTime: { [Player]: number } = {}
local lastGroupCheck: { [Player]: number } = {}
local GROUP_RECHECK_COOLDOWN = 6 -- segundos entre uma conferência do grupo e outra (botão JOIN)
local ALLOWED_BEFORE_LOAD: { [string]: boolean } = { GetIndex = true }

local function track(name: string, ...)
	local analytics = Registry.Analytics
	if analytics and analytics[name] then
		pcall(analytics[name], ...)
	end
end

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

function Economy.HasPass(player: Player, name: string): boolean
	local owned = passes[player]
	return owned ~= nil and owned[name] == true
end

function Economy.GetRebirths(player: Player): number
	local data = getData(player)
	return if data then data.Rebirths else 0
end

-- Rebirths que contam para vagas e esteira: o prestígio zera os rebirths mas não tira vagas
function Economy.GetPeakRebirths(player: Player): number
	local data = getData(player)
	if not data then
		return 0
	end
	return math.max(data.Rebirths, tonumber(data.PeakRebirths) or 0)
end

function Economy.GetSlotCount(player: Player): number
	local data = getData(player)
	local bought = if data then data.SlotUpgrades else 0
	return Config.SlotCount(Economy.GetPeakRebirths(player), bought, Economy.HasPass(player, "MoreSlots"))
end

function Economy.GetMultiplier(player: Player): number
	local data = getData(player)
	if not data then
		return 1
	end
	local multiplier = 1 + data.Rebirths * Config.RebirthIncomeBonus
	local progress = Registry.Progress
	if progress then
		multiplier *= progress.PrestigeMultiplier(player) -- prestígio: +100% cada, para sempre
	end
	local social = Registry.Social
	if social then
		multiplier *= 1 + social.ClanBonus(player) -- colegas de clã no servidor (máx. +10%)
	end
	multiplier *= 1 + (indexCount[player] or 0) * Config.IndexBonusPerCritter
	multiplier *= 1 + (friendBonus[player] or 0) + (if groupMember[player] then Config.GroupBonus else 0)
	if Economy.HasPass(player, "VIP") then
		multiplier *= 1 + Config.VipIncomeBonus
	end
	if Economy.HasPass(player, "DoubleCash") then
		multiplier *= 2
	end
	local fairness = Registry.Fairness
	if fairness then
		multiplier *= fairness.IncomeMultiplier(player)
	end
	-- pets equipados (+até 30%), Roblox Premium (+10%) e 2x Cash dos códigos
	local pets = Registry.Pets
	if pets then
		multiplier *= 1 + pets.Bonus(player)
	end
	if Config.PremiumBonus > 0 and player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= 1 + Config.PremiumBonus
	end
	if (tonumber(data.BoostUntil) or 0) > os.time() then
		multiplier *= 2
	end
	return multiplier
end

function Economy.GetIncome(player: Player): number
	return Registry.CritterService.GetBaseIncome(player) * Economy.GetMultiplier(player)
end

-- "Força" do jogador: renda da base + o que está guardado na mochila.
-- A regra "sem covardia" e o bônus de azarão usam isto (guardar tudo na mochila não engana ninguém).
function Economy.GetPower(player: Player): number
	local pets = Registry.Pets
	local bag = if pets then pets.BagIncome(player) else 0
	return (Registry.CritterService.GetBaseIncome(player) + bag) * Economy.GetMultiplier(player)
end

function Economy.Sync(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("SpeedLevel", data.SpeedLevel)
	player:SetAttribute("Slots", Economy.GetSlotCount(player))
	player:SetAttribute("Multiplier", Economy.GetMultiplier(player))
	player:SetAttribute("IndexCount", indexCount[player] or 0)
	player:SetAttribute("FriendBonus", friendBonus[player] or 0)
	player:SetAttribute("GroupBonus", groupMember[player] == true)
	player:SetAttribute("Steals", data.Steals)
	player:SetAttribute("SlotUpgrades", data.SlotUpgrades)
	player:SetAttribute("TrainedSpeed", data.TrainedSpeed)
	player:SetAttribute("TrainCap", Config.TreadmillCap(Economy.GetPeakRebirths(player)))
	player:SetAttribute("PeakRebirths", Economy.GetPeakRebirths(player))
	player:SetAttribute("Prestige", tonumber(data.Prestige) or 0)
	player:SetAttribute("Hatched", data.Hatched)
	player:SetAttribute("Defends", data.Defends)
	player:SetAttribute("BoostUntil", data.BoostUntil)
	player:SetAttribute("StarterPack", data.StarterPack == true)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local cash = stats:FindFirstChild("Cash") :: StringValue?
		local steals = stats:FindFirstChild("Steals") :: IntValue?
		local rebirths = stats:FindFirstChild("Rebirths") :: IntValue?
		if cash then
			cash.Value = Format.Money(data.Cash)
		end
		if steals then
			steals.Value = data.Steals
		end
		if rebirths then
			rebirths.Value = data.Rebirths
		end
	end
end

-- earned = true quando é dinheiro "ganho" (conta para o leaderboard Top Earners)
-- kind = de onde veio (vai para o Analytics: "Collect", "Sell", "Daily"...)
function Economy.AddCash(player: Player, amount: number, earned: boolean?, kind: string?)
	local data = getData(player)
	if not data or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	data.Cash += amount
	if earned then
		data.TotalEarned += amount
	end
	Economy.Sync(player)
	if kind then
		track("CashSource", player, amount, kind)
	end
end

function Economy.TrySpend(player: Player, amount: number, kind: string?): boolean
	local data = getData(player)
	if not data or amount ~= amount or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	Economy.Sync(player)
	if kind then
		track("CashSink", player, amount, kind)
	end
	return true
end

function Economy.AddHatch(player: Player)
	local data = getData(player)
	if data then
		data.Hatched += 1
		player:SetAttribute("Hatched", data.Hatched)
	end
end

-- Você derrubou um ladrão com o taco e seu bichinho voltou
function Economy.AddDefense(player: Player, thief: Player?)
	local data = getData(player)
	if data then
		data.Defends += 1
		Economy.SeasonXP(player, "Defend", thief)
	end
end

-- XP da temporada (o Season pode não existir nos testes)
function Economy.SeasonXP(player: Player, reason: string, other: Player?)
	local progress = Registry.Progress
	if progress then
		progress.Event(player, reason) -- missões diárias e recordes
	end
	if reason == "Hatch" and Registry.LiveEvents then
		Registry.LiveEvents.AddHatch(1) -- meta da comunidade
	end
	local season = Registry.Season
	if season then
		local Seasons = require(ReplicatedStorage.Shared.Seasons)
		season.AddXP(player, Seasons.XP[reason] or 0, reason, other)
	end
end

function Economy.AddSteal(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	data.Steals += 1
	Economy.Sync(player)
end

function Economy.ApplySpeed(player: Player)
	local data = getData(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	local minigameSpeed = player:GetAttribute("MgSpeed")
	if player:GetAttribute("InMinigame") and typeof(minigameSpeed) == "number" then
		humanoid.WalkSpeed = minigameSpeed -- minigame: todo mundo igual (nada comprado ajuda)
		return
	end
	local trained = math.min(data.TrainedSpeed, Config.TreadmillCap(Economy.GetPeakRebirths(player)))
	local speed = Config.BaseWalkSpeed + data.SpeedLevel * Config.SpeedPerLevel + trained
	local progress = Registry.Progress
	if Economy.HasPass(player, "SpeedCoil") then
		speed += Config.SpeedCoilBonus
	end
	local fairness = Registry.Fairness
	if fairness then
		speed += fairness.SpeedBonus(player) -- vingança
	end
	if progress then
		speed *= progress.SpeedMultiplier(player) -- habilidade Speed
	end
	local mounts = Registry.Mounts
	if mounts and not Registry.CritterService.IsCarrying(player) then
		speed *= mounts.SpeedMultiplier(player) -- skate, kart ou montaria
	end
	if Registry.CritterService.IsCarrying(player) then
		-- habilidade Steal e classe Thief deixam carregar um pouco mais rápido (no máximo 95%)
		speed *= if progress then progress.CarryMultiplier(player, Config.CarrySpeedMultiplier) else Config.CarrySpeedMultiplier
	end
	humanoid.WalkSpeed = speed
end

-- Plaquinha em cima da cabeça (título e VIP): quem desenha é o Customize
function Economy.ApplyVipTag(player: Player)
	local customize = Registry.Customize
	if customize then
		customize.RefreshTag(player)
	end
end

function Economy.HasDiscovered(player: Player, critterId: string): boolean
	local data = getData(player)
	return data ~= nil and data.Index[critterId] == true
end

-- Índice (coleção): +2% de dinheiro por bichinho descoberto
function Economy.Discover(player: Player, critterId: string)
	local data = getData(player)
	if not data or data.Index[critterId] then
		return
	end
	data.Index[critterId] = true
	indexCount[player] = (indexCount[player] or 0) + 1
	data.Collected = indexCount[player]
	Economy.Sync(player)
	Registry.Remotes.IndexEvent:FireClient(player, data.Index)
	local def = Critters.ById[critterId]
	if def then
		Registry.Remotes.Notify(player, ("NEW! %s added to your Index (+%d%% cash)"):format(def.Name, math.floor(Config.IndexBonusPerCritter * 100)), "rare")
	end
end

---------------------------------------------------------------------
-- Amigos e grupo
---------------------------------------------------------------------
local function areFriends(a: Player, b: Player): boolean
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	local key = low .. ":" .. high
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWithAsync(b.UserId)
		end)
		friendCache[key] = ok and result == true
	end
	return friendCache[key]
end

local function recalcFriends()
	local list = Players:GetPlayers()
	for _, player in list do
		local count = 0
		for _, other in list do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end
		if player.Parent then
			friendBonus[player] = math.min(count * Config.FriendBonus, Config.MaxFriendBonus)
		end
		if getData(player) then
			Economy.Sync(player)
		end
	end
end

---------------------------------------------------------------------
-- Game passes
---------------------------------------------------------------------
local function onPassOwned(player: Player, name: string)
	passes[player] = passes[player] or {}
	passes[player][name] = true
	player:SetAttribute("Pass_" .. name, true)
	Economy.Sync(player)
	Economy.ApplySpeed(player)
	Economy.ApplyVipTag(player)
	if name == "MoreSlots" then
		local plot = Registry.Plots.Get(player)
		if plot then
			Registry.Plots.RefreshSlots(plot, Economy.GetSlotCount(player))
			Registry.CritterService.PlacePending(player)
		end
	end
end

---------------------------------------------------------------------
-- Entrada do jogador
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Grupo "Critter Club Studios": quem está no grupo ganha +10% de dinheiro (Config.GroupBonus)
---------------------------------------------------------------------
-- Está no grupo? true/false (nil = o Roblox não respondeu agora)
-- GetGroupsAsync pergunta na hora (o IsInGroup guarda a resposta antiga), então quem entra
-- no grupo pelo botão JOIN da loja ganha o bônus sem precisar sair do jogo.
Economy.FetchInGroup = function(player: Player): boolean?
	if Config.GroupId <= 0 then
		return false
	end
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if ok and type(groups) == "table" then
		for _, info in groups do
			if type(info) == "table" and info.Id == Config.GroupId then
				return true
			end
		end
		return false
	end
	local ok2, inGroup = pcall(function()
		return player:IsInGroupAsync(Config.GroupId)
	end)
	if ok2 then
		return inGroup == true
	end
	return nil
end

function Economy.IsGroupMember(player: Player): boolean
	return groupMember[player] == true
end

-- O jogador tocou em JOIN na loja: confere de novo (no máximo 1 vez a cada 6 segundos).
-- Devolve true se mudou alguma coisa.
function Economy.RecheckGroup(player: Player): boolean
	if Config.GroupId <= 0 or not getData(player) then
		return false
	end
	local now = os.clock()
	if lastGroupCheck[player] and now - lastGroupCheck[player] < GROUP_RECHECK_COOLDOWN then
		return false
	end
	lastGroupCheck[player] = now
	local inGroup = Economy.FetchInGroup(player)
	if inGroup == nil or not player.Parent then
		return false
	end
	local changed = (groupMember[player] == true) ~= inGroup
	groupMember[player] = inGroup
	if changed then
		Economy.Sync(player)
		if inGroup then
			Registry.Remotes.Notify(player, ("Welcome to the group! +%d%% cash is ON!"):format(math.floor(Config.GroupBonus * 100)), "success")
		end
	end
	return changed
end

function Economy.SetupPlayer(player: Player, profile)
	local data = profile.Data

	local count = 0
	for id in data.Index do
		if Critters.ById[id] then
			count += 1
		end
	end
	indexCount[player] = count
	data.Collected = count

	local owned = {}
	passes[player] = owned
	for name, id in Config.GamePasses do
		if id and id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				owned[name] = true
				player:SetAttribute("Pass_" .. name, true)
			end
		end
	end

	local inGroupResult = Economy.FetchInGroup(player) == true
	if not player.Parent then
		Economy.RemovePlayer(player)
		return
	end
	groupMember[player] = inGroupResult

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = stats
	local steals = Instance.new("IntValue")
	steals.Name = "Steals"
	steals.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player

	Economy.Sync(player)
	Registry.Remotes.IndexEvent:FireClient(player, data.Index)

	task.spawn(function()
		recalcFriends()
		for _, other in Players:GetPlayers() do
			if other ~= player and areFriends(player, other) then
				Registry.Remotes.Notify(other, ("Your friend %s joined! +%d%% cash"):format(player.DisplayName, math.floor(Config.FriendBonus * 100)), "success")
			end
		end
	end)
end

-- Depois que os bichinhos salvos já estão na base
function Economy.AfterLoad(player: Player, profile)
	local data = profile.Data
	local Remotes = Registry.Remotes

	if not profile.IsNew and data.LastOnline > 0 then
		local elapsed = math.clamp(os.time() - data.LastOnline, 0, Config.OfflineMaxSeconds)
		local amount = math.floor(Economy.GetIncome(player) * elapsed * Config.OfflineRate)
		if amount > 0 then
			Economy.AddCash(player, amount, true, "Offline")
			Remotes.Popup(player, "Welcome back!", "Your critters made " .. Format.Money(amount) .. " while you were away!")
		end
	end

	local today = math.floor(os.time() / 86400)
	if data.DailyDay ~= today then
		if data.DailyDay == today - 1 then
			data.Streak = (data.Streak % #Config.DailyRewards) + 1
		else
			data.Streak = 1
		end
		data.DailyDay = today
		local reward = math.max(
			Config.DailyRewards[data.Streak] * (1 + Economy.GetPeakRebirths(player)),
			math.floor(Economy.GetIncome(player) * 60 * (Config.DailyIncomeMinutes[data.Streak] or 0))
		)
		if Economy.HasPass(player, "VIP") then
			reward *= 2
		end
		Economy.AddCash(player, reward, false, "Daily")
		-- Jogador novo vê o tutorial primeiro; o popup da recompensa só aparece para quem já jogou
		if not profile.IsNew then
			Remotes.Popup(player, "Daily Reward - Day " .. data.Streak .. "!", "+" .. Format.Money(reward) .. "\nCome back tomorrow for an even BIGGER reward!")
		end
	end
end

function Economy.RemovePlayer(player: Player)
	passes[player] = nil
	friendBonus[player] = nil
	groupMember[player] = nil
	lastGroupCheck[player] = nil
	indexCount[player] = nil
	lastRequest[player] = nil
	trainTime[player] = nil
	task.spawn(recalcFriends)
end

---------------------------------------------------------------------
-- Loja
---------------------------------------------------------------------
function Economy.BuySpeed(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	if data.SpeedLevel >= Config.MaxSpeedLevel then
		Registry.Remotes.Notify(player, "Your speed is already MAX!", "info")
		return
	end
	local cost = Config.SpeedCost(data.SpeedLevel)
	if not Economy.TrySpend(player, cost, "Speed") then
		Registry.Remotes.Notify(player, "Not enough cash! You need " .. Format.Money(cost), "error")
		return
	end
	data.SpeedLevel += 1
	Economy.Sync(player)
	Economy.ApplySpeed(player)
	Registry.Remotes.Notify(player, "Speed upgraded!", "success")
	Registry.Remotes.Effect(player, "Purchase", "Common")
end

-- Rebirth: zera o dinheiro, mantém os bichinhos, dá bônus para sempre e libera critters novos
function Economy.Rebirth(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Cash < cost then
		Registry.Remotes.Notify(player, "You need " .. Format.Money(cost) .. " to rebirth!", "error")
		return
	end

	track("CashSink", player, data.Cash, "Rebirth")
	data.Cash = 0
	data.Rebirths += 1
	local firstTime = data.Rebirths > (tonumber(data.PeakRebirths) or 0) -- depois do prestígio, refazer não conta de novo
	data.PeakRebirths = math.max(tonumber(data.PeakRebirths) or 0, data.Rebirths)
	track("Event", player, "Rebirth", data.Rebirths)
	local plot = Registry.Plots.Get(player)
	if plot then
		plot.Vault = 0
		Registry.Plots.RefreshSlots(plot, Economy.GetSlotCount(player))
	end
	Economy.Sync(player)
	Registry.CritterService.PlacePending(player)

	local unlocked = {}
	for _, def in Critters.List do
		if def.RebirthRequired == data.Rebirths then
			table.insert(unlocked, def.Name)
		end
	end
	Economy.ApplySpeed(player)
	local body = ("Rebirth bonus: x%g cash forever. Base slots: %d. Treadmill max: +%d speed."):format(
		1 + data.Rebirths * Config.RebirthIncomeBonus,
		Economy.GetSlotCount(player),
		Config.TreadmillCap(Economy.GetPeakRebirths(player))
	)
	if #unlocked > 0 then
		body ..= "\nUNLOCKED: " .. table.concat(unlocked, ", ") .. "!"
	end
	Registry.Remotes.Effect(player, "Rebirth")
	Registry.Remotes.Popup(player, "REBIRTH " .. data.Rebirths .. "!", body)
	if firstTime then
		Registry.Remotes.NotifyAll(("%s just REBIRTHED! (Rebirth %d)"):format(player.DisplayName, data.Rebirths), "rare")
		Economy.SeasonXP(player, "Rebirth")
	end
	task.spawn(Registry.Data.Save, player)
end

-- Comprar +1 vaga com dinheiro do jogo
function Economy.BuySlot(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local Remotes = Registry.Remotes
	local cost = Config.SlotUpgradeCosts[data.SlotUpgrades + 1]
	if not cost then
		Remotes.Notify(player, "You bought all slot upgrades! Rebirth for even more slots.", "info")
		return
	end
	if Economy.GetSlotCount(player) >= Config.MaxSlots then
		Remotes.Notify(player, "Your base already has the MAX slots!", "info")
		return
	end
	if not Economy.TrySpend(player, cost, "Slot") then
		Remotes.Notify(player, "Not enough cash! You need " .. Format.Money(cost), "error")
		return
	end
	Economy.GrantSlotUpgrade(player)
end

-- +1 vaga (comprada, ou de graça pelo painel de admin para testar o 2º andar)
function Economy.GrantSlotUpgrade(player: Player): boolean
	local data = getData(player)
	if not data or data.SlotUpgrades >= #Config.SlotUpgradeCosts then
		return false
	end
	data.SlotUpgrades += 1
	local plot = Registry.Plots.Get(player)
	if plot then
		Registry.Plots.RefreshSlots(plot, Economy.GetSlotCount(player))
	end
	Economy.Sync(player)
	Registry.CritterService.PlacePending(player)
	Registry.Remotes.Notify(player, ("+1 SLOT! Your base now has %d slots."):format(Economy.GetSlotCount(player)), "success")
	Registry.Remotes.Effect(player, "Purchase", "Rare")
	return true
end

-- Esteira de treino: chamado pelo Plots enquanto o jogador corre na esteira da própria base
function Economy.Train(player: Player, dt: number)
	local data = getData(player)
	if not data then
		return
	end
	local cap = Config.TreadmillCap(Economy.GetPeakRebirths(player))
	if data.TrainedSpeed >= cap then
		player:SetAttribute("TrainProgress", 1)
		return
	end
	local total = (trainTime[player] or 0) + dt
	if total >= Config.TreadmillSeconds then
		total -= Config.TreadmillSeconds
		data.TrainedSpeed += 1
		Economy.Sync(player)
		Economy.ApplySpeed(player)
		Registry.Remotes.Effect(player, "Train", data.TrainedSpeed)
		if data.TrainedSpeed >= cap then
			Registry.Remotes.Notify(player, ("Treadmill MAX (+%d speed)! Rebirth to train more."):format(cap), "rare")
		end
	end
	trainTime[player] = total
	player:SetAttribute("TrainProgress", total / Config.TreadmillSeconds)
end

function Economy.Init()
	-- Renda a cada segundo vai para o coletor da base
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				for _, player in Players:GetPlayers() do
					local plot = Registry.Plots.Get(player)
					if plot and getData(player) then
						local income = Economy.GetIncome(player)
						plot.Vault += income
						player:SetAttribute("Income", income)
						player:SetAttribute("Power", Economy.GetPower(player))
						player:SetAttribute("FreeSlots", Registry.Plots.FreeSlotCount(plot, Economy.GetSlotCount(player)))
					end
				end
			end)
			if not ok then
				warn("[Economy] loop error:", err)
			end
		end
	end)

	Registry.Remotes.RequestEvent.OnServerEvent:Connect(function(player: Player, action: any, argument: any)
		if typeof(action) ~= "string" then
			return
		end
		-- v28: o limite é por ação, para pedidos diferentes em sequência (ex.: abrir o painel social) não se perderem
		local t = os.clock()
		local perAction = lastRequest[player]
		if not perAction then
			perAction = {}
			lastRequest[player] = perAction
		end
		if t - (perAction[action] or 0) < 0.15 then
			return
		end
		perAction[action] = t
		-- nada de compras/códigos antes da base e dos dados terminarem de carregar
		if not player:GetAttribute("Loaded") and not ALLOWED_BEFORE_LOAD[action] then
			return
		end

		if action == "BuySpeed" then
			Economy.BuySpeed(player)
		elseif action == "Rebirth" then
			Economy.Rebirth(player)
		elseif action == "BuySlot" then
			Economy.BuySlot(player)
		elseif action == "UnlockWorld" and typeof(argument) == "string" then
			Registry.Worlds.Unlock(player, argument)
		elseif action == "TravelWorld" and typeof(argument) == "string" then
			Registry.Worlds.Travel(player, argument)
		elseif action == "CheckGroup" then
			Economy.RecheckGroup(player)
		elseif action == "PromptProduct" then
			Registry.Products.Prompt(player, argument)
		elseif action == "RedeemCode" then
			Registry.Codes.Redeem(player, argument)
		elseif action == "PetStore" then
			Registry.Pets.Store(player, argument)
		elseif action == "PetPlace" then
			Registry.Pets.Place(player, argument)
		elseif action == "PetEquip" then
			Registry.Pets.Equip(player, argument)
		elseif action == "PetUnequip" then
			Registry.Pets.Unequip(player, argument)
		elseif action == "PetEquipBest" then
			Registry.Pets.EquipBest(player)
		elseif action == "PetFuse" then
			Registry.Pets.Fuse(player, argument)
		elseif action == "PetSell" then
			Registry.Pets.Sell(player, argument)
		elseif action == "Mix" then
			Registry.Pets.Mix(player, argument)
		elseif action == "FeedAll" then
			Registry.CritterService.FeedAll(player, argument)
		elseif action == "Ride" then
			Registry.Mounts.Ride(player, argument)
		elseif action == "GiftClaim" then
			Registry.Retention.ClaimGift(player)
		elseif action == "SpinDaily" then
			Registry.Retention.Spin(player)
		elseif action == "FishCatch" then
			Registry.Explore.FishCatch(player, argument)
		elseif action == "MinigameJoin" then
			Registry.Minigames.Join(player)
		elseif action == "BattleMove" then
			Registry.Battle.Move(player, argument)
		elseif action == "Like" then
			Registry.Social.Like(player, argument)
		elseif action == "Visit" then
			Registry.Social.Visit(player, argument)
		elseif action == "Gift" then
			Registry.Social.GiftOffer(player, argument)
		elseif action == "GiftAnswer" then
			Registry.Social.GiftAnswer(player, argument)
		elseif action == "ClanCreate" then
			task.spawn(Registry.Social.ClanCreate, player, argument) -- o filtro de texto demora um pouco
		elseif action == "ClanInvite" then
			Registry.Social.ClanInvite(player, argument)
		elseif action == "ClanAnswer" then
			task.spawn(Registry.Social.ClanAnswer, player, argument)
		elseif action == "ClanLeave" then
			task.spawn(Registry.Social.ClanLeave, player)
		elseif action == "SocialSync" then
			Registry.Social.Sync(player)
		elseif action == "MerchantBuy" then
			Registry.LiveEvents.MerchantBuy(player, argument)
		elseif action == "Vote" then
			Registry.LiveEvents.Vote(player, argument)
		elseif action == "SkillUp" then
			Registry.Progress.SkillUp(player, argument)
		elseif action == "SkillReset" then
			Registry.Progress.SkillReset(player)
		elseif action == "SetClass" then
			Registry.Progress.SetClass(player, argument)
		elseif action == "Prestige" then
			Registry.Progress.Prestige(player)
		elseif action == "QuestSwap" then
			Registry.Progress.Swap(player, argument)
		elseif action == "ProgressSync" then
			Registry.Progress.Sync(player)
		elseif action == "SaveSettings" then
			Registry.Customize.SaveSettings(player, argument)
		elseif action == "SeasonSync" then
			Registry.Season.Sync(player)
		elseif action == "InventorySync" then
			Registry.Pets.Sync(player)
		elseif action == "StyleSync" or action == "SetTheme" or action == "BuyStyle" or action == "PlaceDecor" or action == "SetTrail" or action == "SetTitle" then
			Registry.Customize.Handle(player, action, argument)
		elseif action == "GetIndex" then
			local data = getData(player)
			if data then
				Registry.Remotes.IndexEvent:FireClient(player, data.Index)
			end
		elseif action == "SkipTutorial" then
			Registry.Tutorial.Finish(player, true)
		elseif action == "Admin" then
			Registry.Admin.Handle(player, argument)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then
			return
		end
		for name, id in Config.GamePasses do
			if id and id > 0 and id == passId then
				-- confere com o Roblox antes de liberar (se o Roblox estiver fora do ar, confia no evento do servidor)
				task.spawn(function()
					local owns = true
					for attempt = 1, 2 do
						local ok, result = pcall(function()
							return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
						end)
						owns = not ok or result == true
						if owns then
							break
						end
						task.wait(2)
					end
					if owns and player.Parent then
						onPassOwned(player, name)
						local info = Config.GamePassInfo[name]
						Registry.Remotes.Notify(player, "Thank you! " .. (if info then info.Name else name) .. " unlocked!", "rare")
					end
				end)
			end
		end
	end)
end

return Economy
