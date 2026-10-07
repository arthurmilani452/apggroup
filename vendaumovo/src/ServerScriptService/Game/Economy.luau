--[[
	Economy: moedas, leaderstats, velocidade, missões (progresso) e o "estado" que vai para a tela.
	Todo lugar que muda os dados de alguém chama Economy.Push(player) no final.
	Só o SERVIDOR mexe em moedas: o cliente nunca manda valores, só pede ações.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Registry = require(script.Parent.Registry)

local Economy = {}

local dirty: { [Player]: boolean } = {}
local owned: { [Player]: { [string]: boolean } } = {} -- game passes desta sessão

function Economy.Data(player: Player): any?
	if player:GetAttribute("Loaded") ~= true then
		return nil
	end
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

function Economy.Owned(player: Player): { [string]: boolean }
	local t = owned[player]
	if not t then
		t = {}
		owned[player] = t
	end
	return t
end

function Economy.HasPass(player: Player, key: string): boolean
	local data = Economy.Data(player)
	return data ~= nil and Formulas.HasPass(data, key, owned[player])
end

function Economy.Multiplier(player: Player): number
	local data = Economy.Data(player)
	return if data then Formulas.Multiplier(Config, data, owned[player], os.time()) else 1
end

function Economy.BasketCapacity(player: Player): number
	local data = Economy.Data(player)
	return if data then Formulas.BasketCapacity(Config, data, owned[player]) else 0
end

function Economy.SetupPlayer(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Moedas"
	coins.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player
end

-- Moedas ganhas (venda, missão, presente, compra). "earned" conta para o placar e a missão "ganhe moedas".
function Economy.AddCoins(player: Player, amount: number, earned: boolean)
	local data = Economy.Data(player)
	amount = math.floor(amount)
	if not data or amount <= 0 then
		return
	end
	data.Coins += amount
	if earned then
		data.TotalEarned += amount
		Economy.Mission(player, "earn", amount)
	end
	Economy.Push(player)
end

function Economy.Spend(player: Player, amount: number): boolean
	local data = Economy.Data(player)
	if not data or amount < 0 or amount ~= amount or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	Economy.Push(player)
	return true
end

-- Progresso de missão diária (troca de dia é feita em Daily)
function Economy.Mission(player: Player, missionId: string, amount: number)
	local data = Economy.Data(player)
	if not data or not data.Daily or not data.Daily.List then
		return
	end
	for _, mission in data.Daily.List do
		if mission.Id == missionId and not mission.Claimed and mission.Progress < mission.Target then
			mission.Progress = math.min(mission.Target, mission.Progress + amount)
			Economy.Push(player)
		end
	end
end

function Economy.ApplySpeed(player: Player)
	local data = Economy.Data(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = Formulas.UpgradeValue(Config, data, "Velocidade")
	end
end

function Economy.Push(player: Player)
	dirty[player] = true
end

local function snapshot(player: Player, data: any): any
	local now = os.time()
	local serverNow = workspace:GetServerTimeNow()
	local plot = Registry.Plots.Of(player)
	local boosts = {}
	for key, ends in data.Boosts do
		if ends > now then
			boosts[key] = serverNow + (ends - now)
		end
	end
	local passes = {}
	for _, pass in Config.GamePasses do
		passes[pass.Key] = Formulas.HasPass(data, pass.Key, owned[player])
	end
	return {
		Coins = data.Coins,
		Rebirths = data.Rebirths,
		Basket = data.Basket,
		BasketCount = Formulas.BasketCount(data),
		BasketCap = Formulas.BasketCapacity(Config, data, owned[player]),
		Mult = Formulas.Multiplier(Config, data, owned[player], now),
		Upgrades = data.Upgrades,
		Hens = data.Hens,
		NestCap = Formulas.UpgradeValue(Config, data, "Ninhos"),
		RebirthCost = Formulas.RebirthCost(Config, data),
		Daily = data.Daily.List,
		GiftLeft = math.max(0, Config.GiftInterval - data.GiftSeconds),
		GiftReward = Formulas.GiftReward(Config, data, owned[player], now),
		Passes = passes,
		Boosts = boosts,
		TotalEarned = data.TotalEarned,
		StreakDay = Formulas.StreakNext(data.Streak, Formulas.DayKey(now)), -- nil = já pegou hoje
		StreakLast = data.Streak.Day,
		StreakReward = Formulas.StreakReward(Config, data, Formulas.StreakNext(data.Streak, Formulas.DayKey(now)) or 1),
		Music = data.Settings.Music,
		Plot = if plot then plot.Index else 0,
	}
end

function Economy.Init()
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in dirty do
				dirty[player] = nil
				local data = Economy.Data(player)
				if data and player.Parent then
					local ok, err = pcall(function()
						local stats = player:FindFirstChild("leaderstats")
						if stats then
							local coins = stats:FindFirstChild("Moedas") :: IntValue
							local rebirths = stats:FindFirstChild("Rebirths") :: IntValue
							coins.Value = math.floor(data.Coins)
							rebirths.Value = data.Rebirths
						end
						Registry.Remotes.State:FireClient(player, snapshot(player, data))
					end)
					if not ok then
						warn("[Economy] push falhou:", err)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		owned[player] = nil
	end)
end

return Economy
