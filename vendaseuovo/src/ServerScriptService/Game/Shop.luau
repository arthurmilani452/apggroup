--[[
	Shop: Granja do Seu Zé (galinhas sempre à venda), Carroça do Granjeiro (aparece de tempos em tempos
	com galinhas raras mais baratas), melhorias da barraca e a placa de preços.

	O builder deixa:
	  workspace.Market.Shop.Shop_<raça>  (pedestal de cada galinha da granja)
	  workspace.Market.CartSpot          (onde a carroça para)
	  ServerStorage.Cart                 (modelo da carroça, com CartSlot1..3)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Market = require(ReplicatedStorage.Shared.Market)
local Models = require(ReplicatedStorage.Shared.Models)
local Registry = require(script.Parent.Registry)

local Shop = {}

local function nearby(player: Player, part: BasePart, distance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= distance
end

local function buyHen(player: Player, henId: string, price: number): boolean
	local data = Registry.Economy.Data(player)
	if not data then
		return false
	end
	if Registry.Steal.IsCarrying(player) then
		Registry.Remotes.NotifyPlayer(player, "CANT_WHILE_CARRYING", nil, "error")
		return false
	end
	if #data.Hens >= Registry.Economy.UpgradeValue(data, "Yard") then
		Registry.Remotes.NotifyPlayer(player, "YARD_FULL", nil, "error")
		return false
	end
	if not Registry.Economy.Spend(player, price) then
		Registry.Remotes.NotifyPlayer(player, "NO_MONEY", nil, "error")
		return false
	end
	Registry.Farm.GiveHen(player, henId)
	Registry.Remotes.NotifyPlayer(player, "HEN_BOUGHT", { hen = "#H_" .. henId }, "success")
	Registry.Economy.Advance(player, 4)
	Registry.Economy.Log(player, "HenBought_" .. henId)
	return true
end

local function placeHen(henId: string, pedestal: BasePart, parent: Instance): Model
	local model = Models.Hen(Config.HenById[henId])
	model:PivotTo(pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2 + model.PrimaryPart.Size.Y / 2, 0))
	model.Parent = parent
	return model
end

-- ---------------------------------------------------------------------------
-- Carroça
-- ---------------------------------------------------------------------------
local cartModel: Model? = nil

local function cartRoll(): string?
	local list = {}
	for _, hen in Config.Hens do
		if hen.CartWeight > 0 then
			table.insert(list, { Id = hen.Id, Weight = hen.CartWeight })
		end
	end
	local pick = Market.Weighted(list, math.random())
	return pick and pick.Id
end

local function openCart()
	local template = ServerStorage:FindFirstChild("Cart")
	local spot = workspace:FindFirstChild("Market") and workspace.Market:FindFirstChild("CartSpot")
	if not template or not spot then
		return
	end
	local cart = template:Clone() :: Model
	cart:PivotTo(spot.CFrame)
	cart.Parent = workspace.Market
	cartModel = cart
	for i = 1, Config.Cart.Slots do
		local slot = cart:FindFirstChild("CartSlot" .. i) :: BasePart?
		local henId = cartRoll()
		if slot and henId then
			local hen = placeHen(henId, slot, cart)
			local price = math.floor(Config.HenById[henId].Price * Config.Cart.Discount)
			local prompt = Registry.Stands.MakePrompt(hen.PrimaryPart, "P_BUY", "H_" .. henId, "all", 0.5, 10)
			prompt:SetAttribute("Price", price)
			local sold = false
			prompt.Triggered:Connect(function(player)
				if sold then
					Registry.Remotes.NotifyPlayer(player, "CART_SOLD_OUT", nil, "error")
					return
				end
				if not nearby(player, slot, 16) then
					return
				end
				if buyHen(player, henId, price) then
					sold = true
					hen:Destroy()
				end
			end)
		end
	end
	Registry.Remotes.NotifyAll("CART_ARRIVED", nil, "event")
end

local function closeCart()
	if cartModel then
		cartModel:Destroy()
		cartModel = nil
		Registry.Remotes.NotifyAll("CART_LEFT", nil, "info")
	end
end

-- ---------------------------------------------------------------------------
-- Pedidos da tela
-- ---------------------------------------------------------------------------
local function setMarkup(player: Player, recipeId: any, value: any)
	local data = Registry.Economy.Data(player)
	if not data or type(recipeId) ~= "string" or not Config.RecipeById[recipeId] or type(value) ~= "number" or value ~= value then
		return
	end
	local m = Config.Markup
	value = math.clamp(math.floor(value / m.Step + 0.5) * m.Step, m.Min, m.Max)
	if data.Markup[recipeId] == value then
		return
	end
	data.Markup[recipeId] = value
	local stand = Registry.Stands.Of(player)
	if stand then
		Registry.Stands.RefreshInfo(stand)
	end
	Registry.Economy.Advance(player, 3)
	Registry.Economy.Push(player)
end

local function buyUpgrade(player: Player, upgradeId: any)
	local data = Registry.Economy.Data(player)
	local upgrade = type(upgradeId) == "string" and Config.UpgradeById[upgradeId]
	if not data or not upgrade then
		return
	end
	local level = Registry.Economy.UpgradeLevel(data, upgrade.Id)
	local cost = upgrade.Costs[level + 1]
	if not cost then
		return
	end
	if not Registry.Economy.Spend(player, cost) then
		Registry.Remotes.NotifyPlayer(player, "NO_MONEY", nil, "error")
		return
	end
	data.Upgrades[upgrade.Id] = level + 1
	Registry.Remotes.NotifyPlayer(player, "UPGRADED", { name = "#U_" .. upgrade.Id, level = level + 1 }, "success")
	Registry.Economy.Log(player, "Upgrade_" .. upgrade.Id, level + 1)
	local stand = Registry.Stands.Of(player)
	if stand then
		Registry.Stands.RefreshAll(stand)
	end
	Registry.Economy.Push(player)
end

function Shop.Init()
	local market = workspace:WaitForChild("Market")
	local shop = market:WaitForChild("Shop")
	for _, hen in Config.Hens do
		local pedestal = shop:FindFirstChild("Shop_" .. hen.Id) :: BasePart?
		if hen.InShop and pedestal then
			local model = placeHen(hen.Id, pedestal, shop)
			local prompt = Registry.Stands.MakePrompt(model.PrimaryPart, "P_BUY", "H_" .. hen.Id, "all", 0, 10)
			prompt:SetAttribute("Price", hen.Price)
			local henId, price = hen.Id, hen.Price
			prompt.Triggered:Connect(function(player)
				if nearby(player, pedestal, 16) then
					buyHen(player, henId, price)
				end
			end)
		end
	end

	Registry.Remotes.On("SetMarkup", setMarkup)
	Registry.Remotes.On("BuyUpgrade", buyUpgrade)

	task.spawn(function()
		while true do
			task.wait(Config.Cart.Interval)
			local ok, err = pcall(openCart)
			if not ok then
				warn("[Shop] carroça:", err)
			end
			task.wait(Config.Cart.Duration)
			pcall(closeCart)
		end
	end)
end

return Shop
