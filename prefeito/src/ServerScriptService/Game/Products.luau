--[[
	Products (ModuleScript em ServerScriptService > Game)          Prefeito Tycoon
	Game passes (Renda x2, Cofre Automático) e produtos de dinheiro.
	Ids ficam em Shared/Config (0 = desligado). Nada aleatório é vendido.

	Passe comprado dentro do jogo: confiamos no evento PromptGamePassPurchaseFinished do SERVIDOR
	(logo depois da compra o UserOwnsGamePassAsync pode responder "não tem" por causa do cache).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Game = script.Parent
local Data = require(Game.Data)
local City = require(Game.City)
local Remotes = require(Game.Remotes)

local Products = {}

local function passKey(passId: number): string?
	if passId == 0 then
		return nil
	end
	for key, id in Config.GamePasses do
		if id == passId then
			return key
		end
	end
	return nil
end

function Products.CheckPasses(player: Player)
	for key, id in Config.GamePasses do
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				City.SetPass(player, key, true)
			end
		end
	end
end

local function productFor(productId: number): any
	for _, product in Config.DevProducts do
		if product.Id ~= 0 and product.Id == productId then
			return product
		end
	end
	return nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and Data.Get(player)
	if not player or not profile or profile.Final or not City.Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if Data.HasReceipt(profile, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productFor(info.ProductId)
	if not product then
		warn("[Products] produto desconhecido", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local amount = City.GrantIncomeMinutes(player, product.Minutes, product.Min)
	if not amount then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Data.AddReceipt(profile, info.PurchaseId)
	-- só confirma depois de salvar o recibo junto com o dinheiro. Se não salvou, o Roblox tenta de novo;
	-- no mesmo servidor o recibo já está na memória (não entrega duas vezes)
	if not Data.Save(player) then
		warn("[Products] não salvou o recibo agora; o Roblox vai tentar de novo")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Remotes.Notify(player, "Obrigado! +" .. Format.Money(amount), "ok")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Products.Init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = purchased and passKey(passId)
		if key then
			City.SetPass(player, key, true)
			Remotes.Notify(player, "Passe ativado! Obrigado pelo apoio.", "ok")
		end
	end)
	-- o cliente pede para abrir a compra (o Id vem da Config, nunca do cliente)
	Remotes.Request.OnServerEvent:Connect(function(player, action, payload)
		if action == "buyPass" and type(payload) == "string" then
			local id = Config.GamePasses[payload]
			if type(id) == "number" and id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				Remotes.Notify(player, "Loja ainda não aberta.", "info")
			end
		elseif action == "buyCash" and type(payload) == "number" then
			local product = Config.DevProducts[payload]
			if product and product.Id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.Id)
			else
				Remotes.Notify(player, "Loja ainda não aberta.", "info")
			end
		end
	end)
end

return Products
