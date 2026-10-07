--[[
	Store: vendas em Robux (a lista do que se vende e os preços sugeridos ficam em Config.GamePasses e
	Config.Products; Id 0 = desligado). O que cada item FAZ está nas regras puras do Sim (Sim.GrantPass,
	Sim.DeliverProduct, Sim.VipDaily...); aqui é só a conversa com o Roblox e os avisos na tela.

	  • Game passes (compra uma vez, vale para sempre):
	      - comprou dentro do jogo: PromptGamePassPurchaseFinished NO SERVIDOR entrega na hora (não depende
	        do cache do UserOwnsGamePassAsync, que pode dizer "não tem" logo depois da compra);
	      - ao entrar: UserOwnsGamePassAsync com pcall e novas tentativas (comprou pelo site, ou em outro
	        servidor). O que já estava salvo em data.Passes vale mesmo se o Roblox estiver fora do ar.
	  • Produtos (pode comprar várias vezes): ProcessReceipt. Cada compra (PurchaseId) é entregue UMA vez
	    só e o servidor só responde PurchaseGranted DEPOIS de salvar. Se o save falhar, o Roblox chama de
	    novo mais tarde; como o PurchaseId já está em data.Receipts, nada é entregue em dobro.
	  • Produto de compra única (Once, ex.: Pacote Inicial): o pedido é recusado se o jogador já comprou.
	    Se mesmo assim o Roblox cobrar (duas janelas abertas, outro servidor), ele ganha moedas no lugar:
	    a compra nunca é perdida.
	  • PolicyService: onde o Roblox restringe prêmio sorteado ligado a compra, o giro diário do VIP vira
	    um presente fixo. Se a consulta falhar, a loja funciona normal. (O Roblox não tem um aviso de
	    "este jogador não pode comprar": quem barra a compra, nesses casos, é a própria janela do Roblox.)
	  • VIP aparece para os OUTROS jogadores: etiqueta em cima da cabeça (aqui), nome na placa e brilho
	    na banca (Plots.RefreshSign / Plots.RefreshVip) e o atributo "VIP" no jogador e no terreno.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sim = require(ReplicatedStorage.Shared.Sim)
local Registry = require(script.Parent.Registry)

-- o serviço pode não existir fora do Roblox de verdade (testes): sem ele a loja segue normal
local okPolicy, PolicyService = pcall(function()
	return game:GetService("PolicyService")
end)

local Store = {}

local MAX_RECEIPTS = 50 -- últimas compras lembradas no save (o Roblox reenvia recibo por poucos dias)
local OWN_TRIES = 3 -- tentativas de perguntar ao Roblox se o jogador tem um passe
local LOOP_SECONDS = 30 -- giro/presente diário do VIP e nova conferência de passes que falhou

local passById: { [number]: any } = {}
local passByKey: { [string]: any } = {}
local productById: { [number]: any } = {}
local productByKey: { [string]: any } = {}
local recheck: { [Player]: boolean } = {} -- a conferência de passes falhou: tenta de novo no laço
local unknownWarned: { [number]: boolean } = {}

for _, pass in Config.GamePasses do
	passByKey[pass.Key] = pass
	if (tonumber(pass.Id) or 0) > 0 then
		passById[pass.Id] = pass
	end
end
for _, product in Config.Products do
	productByKey[product.Key] = product
	if (tonumber(product.Id) or 0) > 0 then
		productById[product.Id] = product
	end
end

local function notify(player: Player, key: string, args: any?, kind: string?)
	Registry.Remotes.NotifyPlayer(player, key, args, kind)
end

-- ---------------------------------------------------------------------------
-- VIP: o que os outros jogadores veem
-- ---------------------------------------------------------------------------
-- Etiqueta "👑 VIP" em cima da cabeça. Criada no servidor: aparece para todo mundo sem código no cliente.
local function vipTag(player: Player)
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not head then
		return
	end
	local old = head:FindFirstChild("VIPTag")
	if not Registry.Game.HasPass(player, "VIP") then
		if old then
			old:Destroy()
		end
		return
	end
	if old then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VIPTag"
	gui.Size = UDim2.fromScale(3.4, 0.95)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0) -- acima do nome do jogador
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Config.VIP.Color
	label.TextStrokeColor3 = Color3.fromRGB(70, 38, 15)
	label.TextStrokeTransparency = 0
	label.Text = "👑 VIP"
	label.Parent = gui
	gui.Parent = head
end

-- Atualiza tudo que mostra o VIP: atributo no jogador, etiqueta, placa e brilho da granja
function Store.RefreshVip(player: Player)
	local vip = Registry.Game.HasPass(player, "VIP")
	if player:GetAttribute("VIP") ~= vip then
		player:SetAttribute("VIP", vip)
	end
	vipTag(player)
	local plot = Registry.Plots.Of(player)
	if plot then
		Registry.Plots.RefreshSign(plot)
	end
end

local function vipNotice(player: Player, kind: string?, amount: number)
	if kind == "spins" then
		notify(player, "n.vipSpin", nil, "event")
	elseif kind == "coins" then
		notify(player, "n.vipGift", nil, "event")
		Registry.Remotes.Fx:FireClient(player, "reward", nil, amount, "vip")
	end
	if kind then
		Registry.Game.Push(player)
	end
end

-- Giro (ou presente fixo) do dia para quem tem VIP. Pode chamar à vontade: o Sim só dá uma vez por dia.
local function vipDaily(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local kind, amount = Sim.VipDaily(Config, data, Registry.Game.Ctx(player), os.time())
	vipNotice(player, kind, amount)
end

-- ---------------------------------------------------------------------------
-- Game passes
-- ---------------------------------------------------------------------------
-- bought = comprou agora dentro do jogo (agradece e salva já); false = o Roblox disse ao entrar que ele tem
local function grantPass(player: Player, pass: any, bought: boolean)
	Registry.Game.Owned(player)[pass.Key] = true
	local data = Registry.Game.Data(player)
	if not data then
		return -- ainda carregando: o passe já vale na sessão e o CheckPasses guarda no save depois
	end
	local out = Sim.GrantPass(Config, data, Registry.Game.Ctx(player), pass.Key, os.time())
	if bought then
		notify(player, "n.passOn", { pass = pass.Key }, "success")
		Registry.Remotes.Fx:FireClient(player, "sound", nil, "Comprar")
	end
	if out.OfflineDoubled then
		notify(player, "n.offlineDouble", nil, "success")
	end
	vipNotice(player, out.Vip, out.VipAmount or 0)
	if pass.Key == "VIP" then
		Store.RefreshVip(player)
	end
	Registry.Game.ApplySpeed(player)
	Registry.Game.Push(player)
	if bought and out.New then
		task.spawn(Registry.Data.Save, player) -- compra é importante: salva já
	end
end

-- Pergunta ao Roblox se o jogador tem o passe. Devolve (tem?, deuParaPerguntar?).
local function ownsPass(player: Player, pass: any): (boolean, boolean)
	for attempt = 1, OWN_TRIES do
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
		end)
		if ok then
			return has == true, true
		end
		if attempt < OWN_TRIES and player.Parent then
			task.wait(2 * attempt)
		end
	end
	return false, false
end

-- Regras do Roblox para o país/idade deste jogador. Falhou = segue normal (ver o cabeçalho).
local function checkPolicy(player: Player)
	if not okPolicy or not PolicyService then
		return
	end
	for attempt = 1, 2 do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			Registry.Game.SetPolicy(player, { NoRandom = info.ArePaidRandomItemsRestricted == true })
			return
		end
		if attempt == 1 and player.Parent then
			task.wait(2)
		end
	end
end

-- Confere os game passes de quem entrou (o que já estava salvo também vale). Chamado pelo Main em
-- task.spawn: pode esperar a internet à vontade sem atrasar a entrada do jogador.
function Store.CheckPasses(player: Player)
	checkPolicy(player)
	local failed = false
	for _, pass in Config.GamePasses do
		if not player.Parent then
			return
		end
		-- passe já guardado no save (ou já entregue nesta sessão) não precisa perguntar de novo ao Roblox
		if (tonumber(pass.Id) or 0) > 0 and not Registry.Game.Owned(player)[pass.Key] and not Registry.Game.HasPass(player, pass.Key) then
			local has, asked = ownsPass(player, pass)
			if has then
				grantPass(player, pass, false)
			elseif not asked then
				failed = true
			end
		end
	end
	if not player.Parent then
		return
	end
	recheck[player] = if failed then true else nil
	Store.RefreshVip(player)
	vipDaily(player)
	Registry.Game.Push(player)
end

local function buyPass(player: Player, key: any)
	local pass = type(key) == "string" and passByKey[key]
	if not pass or (tonumber(pass.Id) or 0) <= 0 then
		return
	end
	if Registry.Game.HasPass(player, pass.Key) then
		notify(player, "n.passHave", nil, "info")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

-- ---------------------------------------------------------------------------
-- Produtos
-- ---------------------------------------------------------------------------
local function buyProduct(player: Player, key: any)
	local product = type(key) == "string" and productByKey[key]
	local data = Registry.Game.Data(player)
	if not product or not data or (tonumber(product.Id) or 0) <= 0 then
		return
	end
	-- compra única já feita: nem abre a janela de compra
	if not Sim.CanOfferProduct(data, product) then
		notify(player, "n.onceHave", nil, "info")
		return
	end
	-- Recarga de poderes: só abre a janela se houver poder recarregando (senão seriam Robux jogados fora)
	if product.Kind == "refill" then
		local refill = Sim.RefillState(Config, data, Registry.Game.Ctx(player))
		if refill ~= "ok" then
			notify(player, if refill == "locked" then "n.powerLocked" else "n.refill", nil, "info")
			return
		end
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

-- Mostra na tela o que o produto entregou (out = resultado do Sim.DeliverProduct)
local function announceProduct(player: Player, product: any, out: any)
	if out.Coins > 0 then
		Registry.Remotes.Fx:FireClient(player, "reward", nil, out.Coins, "robux")
	end
	if out.Again then
		notify(player, "n.onceAgain", nil, "info")
	elseif product.Kind == "refill" then
		notify(player, "n.refill", nil, "success")
	elseif product.Kind == "pack" then
		notify(player, "n.packOn", nil, "success")
	elseif out.Boost then
		notify(player, "n.boostOn", { boost = out.Boost }, "success")
	end
	Registry.Remotes.Fx:FireClient(player, "sound", nil, "Comprar")
	Registry.Game.Push(player)
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return NOT_YET -- saiu no meio da compra: o Roblox chama de novo quando ele voltar
	end
	local product = productById[receipt.ProductId]
	if not product then
		-- ID que este servidor não conhece (número errado no Config?): não confirma; sem confirmação o
		-- Roblox devolve os Robux ao jogador depois de alguns dias
		if not unknownWarned[receipt.ProductId] then
			unknownWarned[receipt.ProductId] = true
			warn("[Store] recibo de produto desconhecido: " .. tostring(receipt.ProductId) .. " (confira os Ids em Config.Products)")
		end
		return NOT_YET
	end
	local data = Registry.Game.Data(player)
	local profile = Registry.Data.Get(player)
	if not data or not profile or not profile.CanSave then
		return NOT_YET
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if not table.find(data.Receipts, purchaseId) then
		-- entrega e recibo entram nos dados juntos, sem esperar nada no meio: se o save abaixo falhar e o
		-- Roblox chamar de novo, cai no "já entregue" e só tenta salvar outra vez (nunca entrega em dobro)
		local out = Sim.DeliverProduct(Config, data, Registry.Game.Ctx(player), product, os.time())
		table.insert(data.Receipts, purchaseId)
		while #data.Receipts > MAX_RECEIPTS do
			table.remove(data.Receipts, 1)
		end
		local ok, err = pcall(announceProduct, player, product, out)
		if not ok then
			warn("[Store] aviso da compra:", err)
		end
	end
	-- só confirma ao Roblox depois de salvar (entrega + recibo vão juntos no mesmo save)
	if Registry.Data.Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return NOT_YET
end

-- Ferramenta de teste, SÓ chamada pelo VUODebug do Main (que só existe no Studio): liga passes e entrega
-- produtos sem compra nenhuma, para ver o efeito de cada item antes mesmo de criar os Ids.
--   "pass", "VIP" (ou "todos")   liga o passe      "nopass"   tira todos os passes e compras únicas
--   "product", "PacoteInicial"   entrega o produto como se o recibo tivesse chegado
function Store.Debug(player: Player, command: string, value: any): string
	local data = Registry.Game.Data(player)
	if not data then
		return "sem jogador carregado"
	end
	if command == "pass" then
		local done = {}
		for _, pass in Config.GamePasses do
			if value == "todos" or value == pass.Key then
				grantPass(player, pass, true)
				table.insert(done, pass.Key)
			end
		end
		return if #done > 0 then "passe ligado: " .. table.concat(done, ", ") else "passe desconhecido: " .. tostring(value)
	elseif command == "nopass" then
		data.Passes = {}
		data.Bought = {}
		data.VipDay = 0
		table.clear(Registry.Game.Owned(player))
		Store.RefreshVip(player)
		Registry.Game.ApplySpeed(player)
		Registry.Game.Push(player)
		return "passes e compras únicas apagados"
	elseif command == "product" then
		local product = productByKey[value]
		if not product then
			return "produto desconhecido: " .. tostring(value)
		end
		local out = Sim.DeliverProduct(Config, data, Registry.Game.Ctx(player), product, os.time())
		announceProduct(player, product, out)
		return ("produto %s: moedas %s%s%s%s%s"):format(product.Key, tostring(out.Coins), if out.Egg then ", ovo " .. out.Egg else "", if out.Boost then ", efeito " .. out.Boost else "", if out.Again then " (já tinha: só moedas)" else "", if out.Refill then (", %d poderes recarregados"):format(out.Refill) else "")
	end
	return "comando desconhecido"
end

function Store.Init()
	Registry.Remotes.On("BuyPass", buyPass)
	Registry.Remotes.On("BuyProduct", buyProduct)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local pass = passById[passId]
		if purchased and pass and player and player.Parent then
			local ok, err = pcall(grantPass, player, pass, true)
			if not ok then
				warn("[Store] passe:", err)
			end
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt: any): Enum.ProductPurchaseDecision
		-- um erro aqui não pode virar "compra perdida": responde "ainda não" e o Roblox tenta de novo
		local ok, result = pcall(processReceipt, receipt)
		if ok then
			return result
		end
		warn("[Store] recibo:", result)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- VIP: a etiqueta volta toda vez que o personagem nasce
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			-- espera a cabeça existir (uns segundos no máximo); sem ela a etiqueta vai no tronco
			local tries = 0
			while not character:FindFirstChild("Head") and character.Parent and tries < 12 do
				tries += 1
				task.wait(0.25)
			end
			if player.Character == character then
				pcall(vipTag, player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		recheck[player] = nil
	end)

	-- de tempos em tempos: giro/presente do VIP quando o dia vira e passes que não deu para conferir
	task.spawn(function()
		while true do
			task.wait(LOOP_SECONDS)
			for _, player in Players:GetPlayers() do
				if Registry.Game.Data(player) then
					if recheck[player] then
						recheck[player] = nil
						task.spawn(Store.CheckPasses, player)
					else
						local ok, err = pcall(vipDaily, player)
						if not ok then
							warn("[Store] VIP:", err)
						end
					end
				end
			end
		end
	end)
end

return Store
