--[[
	Store: vendas em Robux.
	  • Game passes (compra uma vez): Dinheiro x2, Cesta VIP, Coleta Automática.
	    Entrega pelo evento PromptGamePassPurchaseFinished NO SERVIDOR (não depende do cache do
	    UserOwnsGamePassAsync, que pode dizer "não tem" logo depois da compra) e guarda nos dados.
	  • Produtos (compra várias vezes): pacotes de moedas e boosts por tempo.
	    Entrega pelo ProcessReceipt: cada compra (PurchaseId) é entregue UMA vez só, e só confirma
	    para o Roblox depois de salvar. Se o save falhar, o Roblox tenta de novo e nada é dado em dobro.
	IDs ficam em Config.GamePasses e Config.Products (0 = desligado).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Registry = require(script.Parent.Registry)

local Store = {}

local MAX_RECEIPTS = 50

local passById: { [number]: any } = {}
local passByKey: { [string]: any } = {}
local productById: { [number]: any } = {}
local productByKey: { [string]: any } = {}

for _, pass in Config.GamePasses do
	passByKey[pass.Key] = pass
	if pass.Id and pass.Id > 0 then
		passById[pass.Id] = pass
	end
end
for _, product in Config.Products do
	productByKey[product.Key] = product
	if product.Id and product.Id > 0 then
		productById[product.Id] = product
	end
end

local function grantPass(player: Player, pass: any)
	local data = Registry.Economy.Data(player)
	Registry.Economy.Owned(player)[pass.Key] = true
	if data then
		data.Passes[pass.Key] = true
	end
	Registry.Remotes.NotifyPlayer(player, ("Valeu! %s ligado."):format(pass.Name), nil, "success")
	Registry.Remotes.Fx:FireClient(player, "sound", nil, "Comprar")
	Registry.Economy.Push(player)
end

-- Confere os game passes de quem entrou (o que já estava salvo também vale)
function Store.CheckPasses(player: Player)
	for _, pass in Config.GamePasses do
		if pass.Id and pass.Id > 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				Registry.Economy.Owned(player)[pass.Key] = true
				local data = Registry.Economy.Data(player)
				if data then
					data.Passes[pass.Key] = true
				end
			end
		end
	end
	Registry.Economy.Push(player)
end

local function buyPass(player: Player, key: any)
	local pass = type(key) == "string" and passByKey[key]
	if not pass or not pass.Id or pass.Id <= 0 then
		return
	end
	if Registry.Economy.HasPass(player, pass.Key) then
		Registry.Remotes.NotifyPlayer(player, "Você já tem esse.", nil, "info")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

local function buyProduct(player: Player, key: any)
	local product = type(key) == "string" and productByKey[key]
	if not product or not product.Id or product.Id <= 0 then
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

local function deliverProduct(player: Player, data: any, product: any)
	if product.Kind == "coins" then
		local coins = Formulas.ProductCoins(Config, product, data)
		Registry.Economy.AddCoins(player, coins, false)
		Registry.Remotes.NotifyPlayer(player, ("Valeu! +%d moedas."):format(coins), nil, "success")
		Registry.Remotes.Fx:FireClient(player, "gift", nil, coins)
	elseif product.Kind == "boost" then
		local now = os.time()
		local current = math.max(now, tonumber(data.Boosts[product.Boost]) or 0)
		data.Boosts[product.Boost] = current + product.Seconds
		Registry.Remotes.NotifyPlayer(player, ("Valeu! %s ligado."):format(product.Name), nil, "success")
	end
	Registry.Remotes.Fx:FireClient(player, "sound", nil, "Comprar")
	Registry.Economy.Push(player)
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = productById[receipt.ProductId]
	if not player or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Registry.Economy.Data(player)
	local profile = Registry.Data.Get(player)
	if not data or not profile or not profile.CanSave then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(data.Receipts, purchaseId) then
		-- já entregue nesta sessão: só confirma ao Roblox depois que estiver salvo
		return if Registry.Data.Save(player) then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	deliverProduct(player, data, product)
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	if Registry.Data.Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- não salvou agora: o Roblox chama de novo; como o PurchaseId já está nos dados, não entrega em dobro
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function Store.Init()
	Registry.Remotes.On("BuyPass", buyPass)
	Registry.Remotes.On("BuyProduct", buyProduct)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local pass = passById[passId]
		if purchased and pass then
			grantPass(player, pass)
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return Store
