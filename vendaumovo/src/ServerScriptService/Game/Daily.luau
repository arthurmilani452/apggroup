--[[
	Daily: missões diárias e presente por tempo de jogo.
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

function Daily.Init()
	Registry.Remotes.On("ClaimMission", claimMission)
	Registry.Remotes.On("ClaimGift", claimGift)

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
