--[[
	Season (ModuleScript em ServerScriptService > Game)
	Parte 16: passe da temporada no servidor.
	  • XP por ação (Seasons.XP) e por minuto jogado
	  • ao subir de nível, a recompensa é entregue NA HORA (não tem "resgatar" e nada se perde)
	  • Season Pass = Dev Product (Config.DevProducts.SeasonPass): vale só para a temporada em que foi comprado
	    e entrega na hora todas as recompensas pagas dos níveis que o jogador já passou
	  • quem não tem o passe ganha as recompensas pagas nos níveis bônus 31-60
	  • placar da temporada (OrderedDataStore "SeasonXP_<número>"), atualizado a cada 60 s
	Os números e prêmios ficam em ReplicatedStorage > Shared > Seasons.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Registry = require(script.Parent.Registry)

local Season = {}

local topList: { { Name: string, XP: number } } = {}
local pairLast: { [Player]: { [string]: number } } = {}
local lastSaved: { [Player]: number } = {}
local nameCache: { [number]: string } = {}

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function current()
	return Seasons.Current(os.time())
end

local function freshSeason(id: number)
	return { Id = id, XP = 0, Granted = 0, PaidGranted = 0, BonusGranted = 0, DailyDay = 0 }
end

function Season.HasPass(player: Player): boolean
	local data = getData(player)
	local id = current()
	return data ~= nil and type(data.SeasonPasses) == "table" and data.SeasonPasses[tostring(id)] == true
end

local function publish(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local level = Seasons.LevelFromXP(data.Season.XP)
	player:SetAttribute("SeasonId", data.Season.Id)
	player:SetAttribute("SeasonXP", data.Season.XP)
	player:SetAttribute("SeasonLevel", level)
	player:SetAttribute("SeasonPass", Season.HasPass(player))
end

-- Garante que os dados são da temporada atual (a temporada virou: começa do zero)
local function ensureSeason(player: Player): any
	local data = getData(player)
	if not data then
		return nil
	end
	local id = current()
	if type(data.Season) ~= "table" or data.Season.Id ~= id then
		data.Season = freshSeason(id)
	end
	for _, key in { "XP", "Granted", "PaidGranted", "BonusGranted" } do
		data.Season[key] = math.max(0, math.floor(tonumber(data.Season[key]) or 0))
	end
	if type(data.SeasonPasses) ~= "table" then
		data.SeasonPasses = {}
	end
	return data
end

-- Entrega com segurança: se algo der erro, o nível NÃO é marcado como entregue (tenta de novo depois)
local function give(player: Player, reward, label: string): boolean
	local ok, parts = pcall(Registry.Codes.Grant, player, reward)
	if not ok then
		warn("[Season] falha ao entregar", label, parts)
		return false
	end
	Registry.Remotes.Notify(player, label .. ": " .. table.concat(parts, " + "), "rare")
	return true
end

-- Entrega tudo o que o jogador já conquistou e ainda não recebeu
local function grantUpTo(player: Player)
	local data = ensureSeason(player)
	if not data then
		return
	end
	local season = data.Season
	local _, theme = current()
	local level = Seasons.LevelFromXP(season.XP)
	local main = math.min(level, Seasons.Levels)
	local gave = false
	while season.Granted < main do
		if not give(player, Seasons.Reward(theme, season.Granted + 1, "Free"), "Season level " .. (season.Granted + 1)) then
			return
		end
		season.Granted += 1
		gave = true
	end
	local bonus = math.max(0, level - Seasons.Levels)
	if Season.HasPass(player) then
		while season.PaidGranted < main do
			-- comprado com Robux: onde itens aleatórios pagos são proibidos, ovo vira dinheiro fixo (Policy)
			local reward = Registry.Policy.SafePaidReward(player, Seasons.Reward(theme, season.PaidGranted + 1, "Paid"))
			if not give(player, reward, "Pass reward " .. (season.PaidGranted + 1)) then
				return
			end
			season.PaidGranted += 1
			gave = true
		end
		-- com o passe, cada nível bônus dá 10 minutos de dinheiro
		while season.BonusGranted < bonus do
			if not give(player, { Minutes = 10 }, "Bonus level " .. (Seasons.Levels + season.BonusGranted + 1)) then
				return
			end
			season.BonusGranted += 1
			gave = true
		end
	else
		-- sem o passe: cada nível bônus libera uma recompensa paga (na ordem), de graça
		while season.BonusGranted < bonus and season.PaidGranted < Seasons.Levels do
			if not give(player, Seasons.Reward(theme, season.PaidGranted + 1, "Paid"), "FREE pass reward " .. (season.PaidGranted + 1)) then
				return
			end
			season.BonusGranted += 1
			season.PaidGranted += 1
			gave = true
		end
	end
	if gave then
		Registry.Remotes.Effect(player, "SeasonLevel", level)
	end
end

-- other = o outro jogador da ação (roubo/defesa): a mesma dupla só dá XP de 5 em 5 minutos
function Season.AddXP(player: Player, amount: number, reason: string?, other: Player?)
	local data = ensureSeason(player)
	if not data or not player:GetAttribute("Loaded") or amount <= 0 then
		return
	end
	if other and reason then
		local list = pairLast[player] or {}
		pairLast[player] = list
		local key = reason .. ":" .. other.UserId
		if os.clock() - (list[key] or -math.huge) < Seasons.PairCooldown then
			return
		end
		list[key] = os.clock()
	end
	if reason and Seasons.ActionXP[reason] then
		local today = math.floor(os.time() / 86400)
		if data.Season.ActionDay ~= today then
			data.Season.ActionDay = today
			data.Season.ActionXP = 0
		end
		local room = Seasons.DailyActionCap - (tonumber(data.Season.ActionXP) or 0)
		if room <= 0 then
			return
		end
		amount = math.min(amount, room)
		data.Season.ActionXP = (tonumber(data.Season.ActionXP) or 0) + amount
	end
	local progress = Registry.Progress
	if progress then
		progress.AddXP(player, amount) -- nível da conta (mesmo XP, mesmo limite diário)
	end
	local before = Seasons.LevelFromXP(data.Season.XP)
	data.Season.XP += math.floor(amount)
	local after = Seasons.LevelFromXP(data.Season.XP)
	if after > before then
		grantUpTo(player)
	end
	publish(player)
end

-- Dev Product "Season Pass" (Products chama isto; true = entregue)
function Season.GrantPass(player: Player): boolean
	local data = ensureSeason(player)
	if not data then
		return false
	end
	local id = current()
	local alreadyHad = data.SeasonPasses[tostring(id)] == true
	local before = data.Season.PaidGranted
	data.SeasonPasses[tostring(id)] = true
	-- o que ele já ganhou de graça nos níveis bônus não é entregue de novo
	grantUpTo(player)
	if alreadyHad or data.Season.PaidGranted == before and before >= Seasons.Levels then
		-- não tinha mais nada para entregar: nunca deixa a compra sem recompensa
		give(player, { Minutes = 60 }, "Thank you")
	end
	publish(player)
	Registry.Remotes.Notify(player, "SEASON PASS unlocked! Thank you!", "rare")
	Registry.Remotes.Effect(player, "SeasonLevel", Seasons.LevelFromXP(data.Season.XP))
	return true
end

function Season.Sync(player: Player)
	local data = ensureSeason(player)
	if not data then
		return
	end
	local id, theme, startsAt, endsAt = current()
	Registry.Remotes.SeasonEvent:FireClient(player, {
		Id = id,
		Theme = theme.Id,
		StartsAt = startsAt,
		EndsAt = endsAt,
		XP = data.Season.XP,
		Granted = data.Season.Granted,
		PaidGranted = data.Season.PaidGranted,
		BonusGranted = data.Season.BonusGranted,
		Pass = Season.HasPass(player),
		Top = topList,
	})
end

function Season.SetupPlayer(player: Player)
	local data = ensureSeason(player)
	if not data then
		return
	end
	-- XP da visita diária (1 vez por dia)
	local today = math.floor(os.time() / 86400)
	if data.Season.DailyDay ~= today then
		data.Season.DailyDay = today
		data.Season.XP += Seasons.XP.Daily
	end
	grantUpTo(player)
	publish(player)
end

function Season.RemovePlayer(player: Player)
	lastSaved[player] = nil
	pairLast[player] = nil
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok and type(name) == "string" then name else "Player"
	return nameCache[userId]
end

-- Placar: grava o XP de quem está online e lê o top 10 (1 vez por minuto, dentro do limite do Roblox)
local function refreshBoard()
	local id = current()
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("SeasonXP_" .. id)
	end)
	if not ok or not store then
		return
	end
	for _, player in Players:GetPlayers() do
		local data = getData(player)
		if data and data.Season and data.Season.Id == id and player:GetAttribute("Loaded") and lastSaved[player] ~= data.Season.XP and data.Season.XP > 0 then
			local xp = data.Season.XP
			local saved = pcall(function()
				store:SetAsync(tostring(player.UserId), xp)
			end)
			if saved then
				lastSaved[player] = xp
			end
		end
	end
	local okPage, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if okPage and pages then
		local list = {}
		for _, entry in pages:GetCurrentPage() do
			local userId = tonumber(entry.key)
			if userId then
				table.insert(list, { Name = nameOf(userId), XP = entry.value })
			end
		end
		topList = list
	end
end

function Season.Init()
	Players.PlayerRemoving:Connect(Season.RemovePlayer)
	task.spawn(function()
		local lastId = current()
		while true do
			task.wait(60)
			local id = current()
			local changed = id ~= lastId
			lastId = id
			-- cada jogador no seu próprio pcall: um erro não trava os outros nem repete o aviso
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					if player:GetAttribute("Loaded") then
						if changed then
							Registry.Remotes.Notify(player, "A NEW SEASON STARTED! New rewards in the PASS menu!", "rare")
						end
						Season.AddXP(player, Seasons.XP.Minute, "Minute")
						publish(player)
					end
				end)
				if not ok then
					warn("[Season] loop error:", err)
				end
			end
			task.spawn(refreshBoard)
		end
	end)
	task.defer(refreshBoard)
end

return Season
