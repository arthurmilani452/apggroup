--[[
	Economy: dinheiro, estrelas (reputação), tutorial, métricas e o "estado" que vai para a tela do jogador.
	Todo lugar que muda os dados de alguém chama Economy.Push(player) no final.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Market = require(ReplicatedStorage.Shared.Market)
local Registry = require(script.Parent.Registry)

local Economy = {}

local dirty: { [Player]: boolean } = {}

local TUTORIAL_STEPS = { "CollectEggs", "StockShowcase", "FirstSale", "ChangePrice", "BuyHen" }

function Economy.Data(player: Player): any?
	if player:GetAttribute("Loaded") ~= true then
		return nil
	end
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

function Economy.UpgradeLevel(data: any, id: string): number
	return tonumber(data.Upgrades[id]) or 0
end

function Economy.UpgradeValue(data: any, id: string): number
	local upgrade = Config.UpgradeById[id]
	local level = math.clamp(Economy.UpgradeLevel(data, id) + 1, 1, #upgrade.Values)
	return upgrade.Values[level]
end

function Economy.EffectiveRep(data: any): number
	return data.Rep + Economy.UpgradeValue(data, "Awning")
end

function Economy.ShieldLeft(data: any): number
	if data.ShieldOff then
		return 0
	end
	return math.max(0, Config.Steal.NewbieShield - data.PlayTime)
end

function Economy.NestCount(data: any): number
	local total = 0
	for _, count in data.Nest do
		total += count
	end
	return total
end

function Economy.ItemValue(item: any): number
	local hen = Config.HenById[item.E]
	local recipe = Config.RecipeById[item.R]
	if not hen or not recipe then
		return 0
	end
	return hen.EggValue * recipe.Mult
end

local function updateLeaderstats(player: Player, data: any)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local money = stats:FindFirstChild("$") :: IntValue?
	local stars = stats:FindFirstChild("⭐") :: NumberValue?
	if money then
		money.Value = math.floor(data.Money)
	end
	if stars then
		stars.Value = math.floor(data.Rep * 10) / 10
	end
end

function Economy.SetupPlayer(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "$"
	money.Parent = stats
	local stars = Instance.new("NumberValue")
	stars.Name = "⭐"
	stars.Parent = stats
	stats.Parent = player
end

function Economy.AddMoney(player: Player, amount: number)
	local data = Economy.Data(player)
	if not data or amount <= 0 then
		return
	end
	data.Money += math.floor(amount)
	Economy.Push(player)
end

function Economy.Spend(player: Player, amount: number): boolean
	local data = Economy.Data(player)
	if not data or amount < 0 or data.Money < amount then
		return false
	end
	data.Money -= amount
	Economy.Push(player)
	return true
end

function Economy.AddRep(player: Player, delta: number, floor: number?)
	local data = Economy.Data(player)
	if not data then
		return
	end
	local new = Market.ClampRep(data.Rep + delta)
	if floor and delta < 0 then
		new = math.max(new, math.min(floor, data.Rep))
	end
	data.Rep = new
	Economy.Push(player)
end

-- Avança o tutorial se o jogador estiver exatamente no passo "step"
function Economy.Advance(player: Player, step: number)
	local data = Economy.Data(player)
	if not data or data.Tutorial ~= step then
		return
	end
	data.Tutorial = step + 1
	Economy.Funnel(player, step + 1)
	Economy.Push(player)
end

function Economy.Funnel(player: Player, step: number)
	local name = TUTORIAL_STEPS[step]
	if not name then
		return
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Economy.Log(player: Player, eventName: string, value: number?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1)
	end)
end

function Economy.Push(player: Player)
	dirty[player] = true
end

local function snapshot(player: Player, data: any): any
	local stand = Registry.Stands.Of(player)
	local shieldLeft = Economy.ShieldLeft(data)
	local serverNow = workspace:GetServerTimeNow()
	local stoveReady = 0
	local now = os.time()
	for _, slot in data.Stove do
		if now >= slot.T then
			stoveReady += 1
		end
	end
	return {
		Money = data.Money,
		Rep = data.Rep,
		Bonus = Economy.UpgradeValue(data, "Awning"),
		Basket = data.Basket,
		BasketMax = Economy.UpgradeValue(data, "Basket"),
		Showcase = data.Showcase,
		ShowcaseMax = Economy.UpgradeValue(data, "Showcase"),
		Hens = #data.Hens,
		HensMax = Economy.UpgradeValue(data, "Yard"),
		Nest = Economy.NestCount(data),
		Stove = #data.Stove,
		StoveReady = stoveReady,
		StoveMax = Economy.UpgradeValue(data, "Stove"),
		Markup = data.Markup,
		Upgrades = data.Upgrades,
		Tutorial = data.Tutorial,
		ShieldEnd = if shieldLeft > 0 then serverNow + shieldLeft else 0,
		Stand = if stand then stand.Index else 0,
		Sold = data.Stats.Sold,
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
						updateLeaderstats(player, data)
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
	end)
end

return Economy
