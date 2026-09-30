--[[
	Products (ModuleScript em ServerScriptService > Game)
	Dev Products (compras que podem repetir), processados do jeito certo:
	  • o Roblox chama ProcessReceipt; a gente entrega, SALVA, e só então confirma a compra
	  • cada recibo é guardado para nunca entregar duas vezes
	Produtos: Instant Lock, Cash Pack S/M/L/XL, critters escolhidos (sem nada aleatório) e, na v20,
	Starter Pack, 2x Cash Boost, Lucky Potion, Base Shield e Instant Hatch.
	v20: a tela pede ao SERVIDOR para abrir a compra ("PromptProduct"): o servidor confere antes
	(tem ovo chocando? já tem o Starter Pack? o país permite?) e só então mostra a janela do Roblox.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Products = {}

local handlers: { [number]: (Player) -> boolean } = {}

-- Quanto dinheiro cada pacote dá (o maior entre o mínimo e X minutos da renda atual)
function Products.CashPackAmount(player: Player, packName: string): number
	local pack = Config.CashPacks[packName]
	if not pack then
		return 0
	end
	local income = Registry.Economy.GetIncome(player)
	return math.floor(math.max(pack.Minimum, income * 60 * pack.Minutes))
end

local function register()
	local ids = Config.DevProducts
	if ids.InstantLock and ids.InstantLock > 0 then
		handlers[ids.InstantLock] = function(player)
			return Registry.Plots.ForceLock(player)
		end
	end
	if ids.SeasonPass and ids.SeasonPass > 0 then
		handlers[ids.SeasonPass] = function(player)
			return Registry.Season.GrantPass(player)
		end
	end
	for packName in Config.CashPacks do
		local id = ids[packName]
		if id and id > 0 then
			handlers[id] = function(player)
				local amount = Products.CashPackAmount(player, packName)
				Registry.Economy.AddCash(player, amount, false, "CashPack")
				Registry.Remotes.Notify(player, "+" .. Format.Money(amount) .. "! Thank you!", "rare")
				Registry.Remotes.Effect(player, "Collect", amount)
				return true
			end
		end
	end
	for critterId, id in Config.CritterProducts do
		if id and id > 0 and Critters.ById[critterId] then
			handlers[id] = function(player)
				return Registry.CritterService.GrantCritter(player, critterId, nil)
			end
		end
	end
	-- v20
	if ids.StarterPack and ids.StarterPack > 0 then
		handlers[ids.StarterPack] = Products.GrantStarterPack
	end
	if ids.Boost30 and ids.Boost30 > 0 then
		handlers[ids.Boost30] = function(player)
			Registry.Codes.AddBoost(player, Config.PaidBoostMinutes)
			Registry.Remotes.Notify(player, ("2x CASH for %d minutes! Thank you!"):format(Config.PaidBoostMinutes), "rare")
			Registry.Remotes.Effect(player, "Purchase", "Epic")
			return true
		end
	end
	if ids.LuckyPotion and ids.LuckyPotion > 0 then
		handlers[ids.LuckyPotion] = function(player)
			Registry.Events.StartLucky(Config.LuckyPotionSeconds, player.DisplayName)
			Registry.Remotes.Effect(player, "Purchase", "Legendary")
			return true
		end
	end
	if ids.BaseShield and ids.BaseShield > 0 then
		handlers[ids.BaseShield] = function(player)
			return Registry.Fairness.AddPaidShield(player, Config.PaidShieldSeconds)
		end
	end
	if ids.InstantHatch and ids.InstantHatch > 0 then
		handlers[ids.InstantHatch] = function(player)
			local count = Registry.CritterService.HatchAllNow(player)
			Registry.Remotes.Notify(player, if count > 0 then ("%d egg(s) hatching NOW!"):format(count) else "No eggs were hatching, so nothing to speed up.", "rare")
			Registry.Remotes.Effect(player, "Purchase", "Epic")
			return true
		end
	end
end

-- Starter Pack (1 vez): dinheiro + Royal Egg + 2x Cash. Comprado de novo por engano, entrega de novo
-- (o jogador pagou), mas a loja esconde o botão e o servidor não abre a compra pela 2ª vez.
function Products.GrantStarterPack(player: Player): boolean
	local profile = Registry.Data.Get(player)
	if not profile then
		return false
	end
	local pack = Config.StarterPack
	profile.Data.StarterPack = true
	player:SetAttribute("StarterPack", true)
	Registry.Economy.AddCash(player, pack.Cash, false, "StarterPack")
	Registry.CritterService.GrantEgg(player, pack.Egg)
	Registry.Codes.AddBoost(player, pack.BoostMinutes)
	Registry.Remotes.Popup(player, "STARTER PACK!", ("+%s cash, a %s and 2x Cash for %d min. Thank you!"):format(Format.Money(pack.Cash), (Config.EggById[pack.Egg] or { Name = "Royal Egg" }).Name, pack.BoostMinutes))
	Registry.Remotes.Effect(player, "Purchase", "Legendary")
	return true
end

-- Pode comprar? (o servidor decide; a tela só esconde botões). Devolve false + motivo.
function Products.CanBuy(player: Player, key: string): (boolean, string?)
	local profile = Registry.Data.Get(player)
	if not profile or not player:GetAttribute("Loaded") then
		return false, "Still loading, try again in a second!"
	end
	local policy = Registry.Policy
	if key == "StarterPack" then
		if profile.Data.StarterPack then
			return false, "You already have the Starter Pack!"
		end
		if policy and not policy.CanBuyRandom(player) then
			return false, "Not available where you live." -- tem um ovo aleatório dentro
		end
	elseif Config.CashPacks[key] then
		if policy and not policy.CanBuyRandom(player) then
			return false, "Not available where you live."
		end
	elseif key == "InstantHatch" then
		if Registry.CritterService.IncubatingCount(player) <= 0 then
			return false, "No eggs hatching right now! Buy an egg first."
		end
	elseif key == "BaseShield" then
		local left = Registry.Fairness.ShieldLeft(player)
		if left >= Config.PaidShieldMaxSeconds then
			return false, "Your shield is already at the max!"
		end
	elseif key == "LuckyPotion" or key == "Boost30" or key == "InstantLock" or key == "SeasonPass" then
		-- sempre pode
	elseif Config.CritterProducts[key] then
		-- sempre pode (vai para a fila se a base estiver cheia)
	else
		return false, "Unknown product."
	end
	return true
end

-- A tela pede e o servidor abre a janela de compra do Roblox (só se puder)
function Products.Prompt(player: Player, key: any)
	if typeof(key) ~= "string" then
		return
	end
	local id = Config.DevProducts[key] or Config.CritterProducts[key] or 0
	if id <= 0 then
		Registry.Remotes.Notify(player, "This item is not for sale yet.", "info")
		return
	end
	local ok, reason = Products.CanBuy(player, key)
	if not ok then
		Registry.Remotes.Notify(player, reason or "Not available.", "warning")
		return
	end
	pcall(function()
		MarketplaceService:PromptProductPurchase(player, id)
	end)
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- espera o jogador terminar de carregar (até 30 s)
	local started = os.clock()
	while player.Parent and not player:GetAttribute("Loaded") and os.clock() - started < 30 do
		task.wait(0.5)
	end
	local profile = Registry.Data.Get(player)
	if not profile or not player.Parent or not player:GetAttribute("Loaded") or player:GetAttribute("Leaving") or profile.Final then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- se os dados desta sessão não podem ser salvos, entrega na próxima vez que ele entrar
	if not profile.CanSave and not RunService:IsStudio() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if Registry.Data.HasReceipt(profile, receipt.PurchaseId) then
		-- já entregue antes, mas o save pode ter falhado: só confirma depois de um save que deu certo
		if profile.CanSave and not Registry.Data.Save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local handler = handlers[receipt.ProductId]
	if not handler then
		warn("[Products] Produto sem configuração:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(handler, player)
	if not ok or not granted then
		warn("[Products] Falha ao entregar produto", receipt.ProductId, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Registry.Data.AddReceipt(profile, receipt.PurchaseId)
	if profile.CanSave then
		-- só confirma a compra depois de salvar (se o save falhar, o Roblox tenta de novo depois)
		if not Registry.Data.Save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Para os testes automáticos
function Products.Handlers()
	return handlers
end

function Products.Init()
	register()
	pcall(function()
		MarketplaceService.ProcessReceipt = processReceipt
	end)
end

return Products
