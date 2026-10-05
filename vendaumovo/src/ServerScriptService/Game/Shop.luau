--[[
	Shop: Loja de Galinhas, Loja de Upgrades e Rebirth.
	O cliente só PEDE ("quero a Pata"); o servidor confere distância da loja, saldo e preço do Config.
	O builder deixa em workspace.Plaza: HenShopPoint e UpgradeShopPoint (onde fica o balcão de cada loja).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Registry = require(script.Parent.Registry)

local Shop = {}

local function point(name: string): BasePart?
	local plaza = workspace:FindFirstChild("Plaza")
	return plaza and plaza:FindFirstChild(name, true) :: BasePart?
end

local function nearShop(player: Player, name: string): boolean
	local part = point(name)
	if not part then
		return true -- sem o ponto no mapa, não trava o jogo
	end
	if Registry.Plots.Near(player, part, Config.ShopDistance) then
		return true
	end
	Registry.Remotes.NotifyPlayer(player, "Chega mais perto do balcão.", nil, "error")
	return false
end

local function sound(player: Player, name: string)
	Registry.Remotes.Fx:FireClient(player, "sound", nil, name)
end

local function buyHen(player: Player, henId: any)
	local data = Registry.Economy.Data(player)
	local hen = type(henId) == "string" and Config.HenById[henId]
	if not data or not hen or not nearShop(player, "HenShopPoint") then
		return
	end
	local cap = Formulas.UpgradeValue(Config, data, "Ninhos")
	local replaceIndex = nil
	if #data.Hens >= cap then
		-- ninhos cheios: troca a ave mais fraca, se a nova for melhor
		local weakest, weakestTier = nil, math.huge
		for i, id in data.Hens do
			local h = Config.HenById[id]
			local tier = if h then h.Tier else 0
			if tier < weakestTier then
				weakest, weakestTier = i, tier
			end
		end
		if not weakest or weakestTier >= hen.Tier then
			Registry.Remotes.NotifyPlayer(player, "Sem ninho livre. Compra Mais Ninhos ou uma ave melhor.", nil, "error")
			return
		end
		replaceIndex = weakest
	end
	if not Registry.Economy.Spend(player, hen.Price) then
		Registry.Remotes.NotifyPlayer(player, "Falta moeda.", nil, "error")
		return
	end
	if replaceIndex then
		local old = Config.HenById[data.Hens[replaceIndex]]
		data.Hens[replaceIndex] = hen.Id
		if old then
			Registry.Economy.AddCoins(player, math.floor(old.Price * Config.ReplaceRefund), false)
			Registry.Remotes.NotifyPlayer(player, ("%s saiu, %s entrou."):format(old.Name, hen.Name), nil, "success")
		end
		local plot = Registry.Plots.Of(player)
		if plot then
			plot.NestEggs[replaceIndex] = {}
			Registry.Plots.RefreshNest(plot, replaceIndex)
		end
	else
		table.insert(data.Hens, hen.Id)
		Registry.Remotes.NotifyPlayer(player, ("%s chegou na granja."):format(hen.Name), nil, "success")
	end
	data.Stats.HensBought += 1
	Registry.Economy.Mission(player, "buyHen", 1)
	local plot = Registry.Plots.Of(player)
	if plot then
		Registry.Plots.RefreshHens(plot)
	end
	sound(player, "Comprar")
	Registry.Economy.Push(player)
end

local function buyUpgrade(player: Player, upgradeId: any)
	local data = Registry.Economy.Data(player)
	local upgrade = type(upgradeId) == "string" and Config.UpgradeById[upgradeId]
	if not data or not upgrade or not nearShop(player, "UpgradeShopPoint") then
		return
	end
	local cost = Formulas.UpgradeCost(Config, data, upgrade.Id)
	if not cost then
		Registry.Remotes.NotifyPlayer(player, "Essa já tá no máximo.", nil, "info")
		return
	end
	if not Registry.Economy.Spend(player, cost) then
		Registry.Remotes.NotifyPlayer(player, "Falta moeda.", nil, "error")
		return
	end
	data.Upgrades[upgrade.Id] = Formulas.UpgradeLevel(data, upgrade.Id) + 1
	Registry.Remotes.NotifyPlayer(player, ("%s nível %d"):format(upgrade.Name, data.Upgrades[upgrade.Id]), nil, "success")
	local plot = Registry.Plots.Of(player)
	if plot then
		Registry.Plots.RefreshUpgrades(plot)
	end
	Registry.Economy.ApplySpeed(player)
	sound(player, "Comprar")
	Registry.Economy.Push(player)
end

local function rebirth(player: Player)
	local data = Registry.Economy.Data(player)
	if not data then
		return
	end
	local cost = Formulas.RebirthCost(Config, data)
	if data.Coins < cost then
		Registry.Remotes.NotifyPlayer(player, "Ainda falta moeda pro rebirth.", nil, "error")
		return
	end
	data.Rebirths += 1
	data.Coins = Config.StartCoins
	data.Hens = table.clone(Config.StartHens)
	data.Basket = {}
	for _, upgrade in Config.Upgrades do
		data.Upgrades[upgrade.Id] = 0
	end
	local plot = Registry.Plots.Of(player)
	if plot then
		for i = 1, #plot.Nests do
			plot.NestEggs[i] = {}
		end
		Registry.Plots.RefreshAll(plot)
	end
	Registry.Economy.ApplySpeed(player)
	Registry.Remotes.NotifyAll(("%s fez o rebirth %d"):format(player.DisplayName, data.Rebirths), nil, "event")
	Registry.Remotes.Fx:FireClient(player, "rebirth", nil, data.Rebirths)
	sound(player, "Rebirth")
	Registry.Economy.Push(player)
	task.spawn(Registry.Data.Save, player) -- rebirth é importante: salva já
end

function Shop.Init()
	-- balcões da praça: chegar perto e apertar E abre o painel certo na tela
	for pointName, info in { HenShopPoint = { "Hens", "Ver aves", "Galinheiro do Seu Zé" }, UpgradeShopPoint = { "Upgrades", "Ver melhorias", "Oficina" }, RebirthPoint = { "Rebirth", "Rebirth", "Altar" }, MissionPoint = { "Missions", "Ver missões", "Quadro" } } do
		local part = point(pointName)
		if part then
			local prompt = Registry.Plots.MakePrompt(part, info[2], info[3], "all", 0, 14)
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt:SetAttribute("Opens", info[1])
		end
	end
	Registry.Remotes.On("BuyHen", buyHen)
	Registry.Remotes.On("BuyUpgrade", buyUpgrade)
	Registry.Remotes.On("Rebirth", rebirth)
end

return Shop
