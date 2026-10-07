--[[
	Daily: missões diárias, presente por tempo de jogo, sequência de dias, ganho offline,
	códigos e a preferência de música.
	Usa SÓ o relógio do servidor (os.time no servidor): mudar a hora do celular não adianta.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Registry = require(script.Parent.Registry)

local Daily = {}

-- Dia novo (UTC do servidor) = missões novas
function Daily.Check(player: Player)
	local data = Registry.Economy.Data(player)
	if not data then
		return
	end
	local today = Formulas.DayKey(os.time())
	if data.Daily.Day ~= today then
		data.Daily = { Day = today, List = Formulas.MakeMissions(Config, data, today) }
		Registry.Economy.Push(player)
	end
end

local function claimMission(player: Player, index: any)
	local data = Registry.Economy.Data(player)
	if not data or type(index) ~= "number" then
		return
	end
	Daily.Check(player)
	local mission = data.Daily.List[index]
	if not mission or mission.Claimed or mission.Progress < mission.Target then
		return
	end
	mission.Claimed = true
	Registry.Economy.AddCoins(player, mission.Reward, false)
	Registry.Remotes.NotifyPlayer(player, ("Missão feita. +%d moedas"):format(mission.Reward), nil, "success")
	Registry.Remotes.Fx:FireClient(player, "sound", nil, "Comprar")
	Registry.Economy.Push(player)
end

local function claimGift(player: Player)
	local data = Registry.Economy.Data(player)
	if not data or data.GiftSeconds < Config.GiftInterval then
		return
	end
	local reward = Formulas.GiftReward(Config, data, Registry.Economy.Owned(player), os.time())
	data.GiftSeconds = 0
	Registry.Economy.AddCoins(player, reward, false)
	Registry.Remotes.NotifyPlayer(player, ("+%d moedas do presente"):format(reward), nil, "success")
	Registry.Remotes.Fx:FireClient(player, "gift", nil, reward)
	Registry.Economy.Push(player)
end

-- Sequência: um prêmio por dia; dia seguido soma, pulou um dia volta para o 1
local function claimStreak(player: Player)
	local data = Registry.Economy.Data(player)
	if not data then
		return
	end
	local today = Formulas.DayKey(os.time())
	local day = Formulas.StreakNext(data.Streak, today)
	if not day then
		return
	end
	local reward = Formulas.StreakReward(Config, data, day)
	data.Streak = { Day = day, Last = today }
	Registry.Economy.AddCoins(player, reward, false)
	if day == 7 then
		local now = os.time()
		data.Boosts[Config.Streak.Day7Boost] = math.max(now, tonumber(data.Boosts[Config.Streak.Day7Boost]) or 0) + Config.Streak.Day7Seconds
		Registry.Remotes.NotifyPlayer(player, ("Dia 7! +%d moedas e Sorte x3 por 15 min"):format(reward), nil, "success")
	else
		Registry.Remotes.NotifyPlayer(player, ("Dia %d da sequência. +%d moedas"):format(day, reward), nil, "success")
	end
	Registry.Remotes.Fx:FireClient(player, "gift", nil, reward)
	Registry.Economy.Push(player)
end

-- Códigos: cada conta usa uma vez; tentativas erradas têm limite (ninguém fica chutando).
-- Guardado por UserId e por hora do servidor: sair e voltar não zera as tentativas.
local attempts: { [number]: { number } } = {}

local function redeemCode(player: Player, text: any)
	local data = Registry.Economy.Data(player)
	if not data or type(text) ~= "string" or #text > 40 then
		return
	end
	local now = os.time()
	local list = attempts[player.UserId] or {}
	local recent = {}
	for _, t in list do
		if now - t < Config.CodeWindow then
			table.insert(recent, t)
		end
	end
	attempts[player.UserId] = recent
	if #recent >= Config.CodeAttempts then
		Registry.Remotes.NotifyPlayer(player, "Muitas tentativas. Espera um minuto.", nil, "error")
		return
	end
	local entry = Formulas.FindCode(Config, text)
	if not entry or (entry.Expires > 0 and os.time() > entry.Expires) then
		table.insert(recent, now)
		Registry.Remotes.NotifyPlayer(player, "Código inválido ou vencido.", nil, "error")
		return
	end
	if data.Codes[entry.Code] then
		Registry.Remotes.NotifyPlayer(player, "Você já usou esse código.", nil, "info")
		return
	end
	data.Codes[entry.Code] = true
	local reward = Formulas.CodeReward(Config, data, entry)
	Registry.Economy.AddCoins(player, reward, false)
	Registry.Remotes.NotifyPlayer(player, ("Código %s: +%d moedas"):format(entry.Code, reward), nil, "success")
	Registry.Remotes.Fx:FireClient(player, "gift", nil, reward)
	Registry.Economy.Push(player)
end

local function setMusic(player: Player, on: any)
	local data = Registry.Economy.Data(player)
	if data and type(on) == "boolean" then
		data.Settings.Music = on
		Registry.Economy.Push(player)
	end
end

-- Chamado logo depois de carregar os dados: paga o que as aves botaram enquanto a pessoa estava fora
function Daily.Offline(player: Player)
	local data = Registry.Economy.Data(player)
	if not data then
		return
	end
	local now = os.time()
	local last = tonumber(data.LastSeen) or 0
	data.LastSeen = now
	if last <= 0 or last > now then
		return
	end
	local eggs, coins = Formulas.OfflineEarnings(Config, data, Registry.Economy.Owned(player), now - last, now)
	if coins <= 0 then
		return
	end
	data.Stats.Sold += eggs
	Registry.Economy.AddCoins(player, coins, true)
	task.delay(2, function()
		if player.Parent then
			Registry.Remotes.Fx:FireClient(player, "offline", nil, { Eggs = eggs, Coins = coins, Seconds = math.min(now - last, Config.Offline.MaxSeconds) })
		end
	end)
end

-- Marca a hora (do servidor) em que a pessoa foi vista pela última vez
function Daily.Touch(player: Player)
	local data = Registry.Economy.Data(player)
	if data then
		data.LastSeen = os.time()
	end
end

function Daily.Init()
	Registry.Remotes.On("ClaimMission", claimMission)
	Registry.Remotes.On("ClaimGift", claimGift)
	Registry.Remotes.On("ClaimStreak", claimStreak)
	Registry.Remotes.On("RedeemCode", redeemCode)
	Registry.Remotes.On("SetMusic", setMusic)

	-- conta o tempo de jogo (no servidor) e troca as missões na virada do dia
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(1)
			ticks += 1
			for _, player in Players:GetPlayers() do
				local data = Registry.Economy.Data(player)
				if data then
					local before = data.GiftSeconds
					data.GiftSeconds = math.min(Config.GiftInterval, data.GiftSeconds + 1)
					if before < Config.GiftInterval and data.GiftSeconds >= Config.GiftInterval then
						Registry.Remotes.NotifyPlayer(player, "Tem presente pra abrir", nil, "event")
						Registry.Economy.Push(player)
					end
					if ticks % 30 == 0 then
						Daily.Check(player)
					end
				end
			end
		end
	end)
end

return Daily
