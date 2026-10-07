--[[
	Farm: o coração do tycoon.
	  • Produção (a cada Config.TickSeconds): os negócios COM gerente rodam sozinhos (Sim.Tick); caem
	    gorjetas na banca e aparecem ovos raros nos ninhos.
	  • Posição do jogador (a cada Config.PollSeconds): pisou num botão = compra; ficou no tapete azul =
	    trabalha (um ciclo do negócio sem gerente); chegou perto das moedas do chão / gorjetas / ovo raro
	    = pega; atrás do balcão = vende os ovos raros; chocadeira; macieira.
	  • Clique na banca: pelo pedido "Click" (botão VENDER da tela) ou pelo ClickDetector do prédio.
	  • Saco de dinheiro: cai de tempos em tempos num canto do terreno (Sim.BagTick); o dono pega encostando.
	  • Chave secreta (versão 5): nasce escondida num canto (Sim.KeyTick); o dono pega chegando perto e, com
	    as chaves na mão, abre o Baú Secreto chegando ao baú. Nada disso tem pedido do cliente.
	  • Poderes (versão 5): pedido "Power" (botões da tela); o servidor confere tudo (Sim.UsePower).
	Nada depende de Touched, e o cliente nunca manda valores: só a AÇÃO. O servidor olha onde o
	personagem está e faz a conta.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Sim = require(ReplicatedStorage.Shared.Sim)
local Registry = require(script.Parent.Registry)

local Farm = {}

local lastMsg: { [Player]: { [string]: number } } = {}
local clicks: { [Player]: { number } } = {} -- horas (os.clock) dos últimos cliques aceitos de cada jogador

local function throttle(player: Player, key: string, seconds: number): boolean
	local t = lastMsg[player]
	if not t then
		t = {}
		lastMsg[player] = t
	end
	local now = os.clock()
	local last = t[key]
	if last and now - last < seconds then
		return false
	end
	t[key] = now
	return true
end

local function fx(player: Player, kind: string, position: Vector3?, value: any, extra: any)
	Registry.Remotes.Fx:FireClient(player, kind, position, value, extra)
end

-- (definidas mais abaixo, na parte do trabalho na mão)
local startWork: (Player, any, number) -> ()
local finishWork: (Player, any, any, number, number) -> ()

local function flat(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- ponto {x, z} do Layout -> posição no mundo, y acima do piso
local function at(plot: any, point: { number }, y: number): Vector3
	return Registry.Plots.CF(plot, point[1], point[2], 0, y).Position
end

-- Onde o personagem está, em coordenadas do terreno (nil = sem personagem ou fora da altura da granja)
local function localPosition(player: Player, plot: any): Vector3?
	local root = Registry.Plots.RootOf(player)
	if not root then
		return nil
	end
	local p = Registry.Plots.Local(plot, root.CFrame.Position)
	if math.abs(p.Y) > 14 then
		return nil
	end
	return p
end

-- Depois de qualquer compra/renascer: redesenha a granja, ajusta a velocidade e manda o estado
function Farm.Changed(player: Player, plot: any)
	Registry.Plots.Sync(plot)
	Registry.Game.ApplySpeed(player)
	Registry.Game.Push(player)
end

function Farm.TryBuy(player: Player, plot: any, button: any): boolean
	local data = Registry.Game.Data(player)
	if not data then
		return false
	end
	local ok, reason = Sim.Buy(Config, data, button.Id)
	if not ok then
		if reason == "coins" and throttle(player, "coins", 2.5) then
			fx(player, "nomoney", nil, button.Cost - data.Coins, button.Id)
		end
		return false
	end
	plot.LastBuy = os.clock()
	Registry.Events.GiantAdd(Config.Giant.BuyPoints)
	local position = at(plot, Registry.Plots.ButtonPoint(button), 2)
	Farm.Changed(player, plot)
	Registry.Remotes.Fx:FireAllClients("buy", position, button.Id, player.UserId)
	if button.Kind == "unlock" then
		fx(player, "newbiz", position, button.Biz)
		-- os primeiros negócios todo mundo abre em minutos: só avisa o servidor a partir do 4º
		if button.Biz >= 4 then
			Registry.Remotes.NotifyAll("n.unlocked", { player = player.DisplayName, biz = Config.Businesses[button.Biz].Id }, "event")
		end
	elseif button.Kind == "manager" then
		fx(player, "manager", position, button.Biz)
		-- contratou no meio de um ciclo feito na mão: o ciclo termina agora e paga (o tapete some com o
		-- gerente; não fica um trabalho "fantasma" correndo). A espera antiga perde a senha e não paga de novo.
		local token = plot.Run.Work[button.Biz]
		if token then
			finishWork(player, plot, plot.Run, button.Biz, token)
		end
	elseif button.Kind == "bird" then
		fx(player, "newline", position, button.Line)
		if button.Line >= 5 then
			Registry.Remotes.NotifyAll("n.newbird", { player = player.DisplayName, line = Config.Lines[button.Line].Id }, "event")
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Clique na banca
-- ---------------------------------------------------------------------------
-- Janela deslizante de 1 segundo: no máximo Config.ClickMaxPerSecond cliques em qualquer 1 s.
-- (Um intervalo fixo entre cliques comeria cliques honestos que chegam juntos por atraso da rede.)
local function clickAllowed(player: Player): boolean
	local list = clicks[player]
	if not list then
		list = {}
		clicks[player] = list
	end
	local now = os.clock()
	while list[1] and now - list[1] >= 1 do
		table.remove(list, 1)
	end
	if #list >= Config.ClickMaxPerSecond then
		return false
	end
	table.insert(list, now)
	return true
end

-- Um clique na banca. clickedPlot = terreno do ClickDetector (nil quando vem do botão da tela).
-- Vale para o dono, com a banca aberta, perto dela e dentro do limite de cliques por segundo.
function Farm.Click(player: Player, clickedPlot: any?): boolean
	local plot = Registry.Plots.Of(player)
	local data = Registry.Game.Data(player)
	if not plot or not data or (clickedPlot ~= nil and clickedPlot ~= plot) then
		return false
	end
	if not clickAllowed(player) then
		return false
	end
	local p = localPosition(player, plot)
	local stand = Layout.Stand
	if not p or flat(p.X, p.Z, stand[1], stand[2]) > Config.ClickRadius then
		return false
	end
	local amount = Sim.Click(Config, data, plot.Run, Registry.Game.Ctx(player))
	if amount <= 0 then
		return false
	end
	Registry.Plots.SetGround(plot, 1, plot.Run.Ground[1])
	fx(player, "click", at(plot, Layout.Biz[1].Cash, 1), amount)
	Registry.Events.GiantAdd(Config.Giant.WorkPoints)
	Registry.Game.PushTick(player)
	Registry.Game.PushSoon(player) -- missões e contadores: estado completo, mas sem pressa
	return true
end

-- ---------------------------------------------------------------------------
-- Trabalho na mão (tapete azul dos negócios sem gerente)
-- ---------------------------------------------------------------------------
local function onWorkPad(p: Vector3, index: number): boolean
	local pad = Layout.Biz[index].U
	return flat(p.X, p.Z, pad[1], pad[2]) <= Config.WorkRadius
end

-- O ciclo terminou (chamado pelo task.delay). run/token são os do começo: se o jogador saiu, o terreno
-- mudou de dono ou ele renasceu no meio, a senha não vale mais e nada é pago.
function finishWork(player: Player, plot: any, run: any, index: number, token: number)
	if plot.Owner ~= player or plot.Run ~= run or run.Work[index] ~= token then
		return
	end
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local amount = Sim.FinishWork(Config, data, run, Registry.Game.Ctx(player), index, token)
	Registry.Plots.SetWork(plot, index, 0, 0)
	if amount > 0 then
		Registry.Plots.SetGround(plot, index, run.Ground[index])
		fx(player, "workDone", at(plot, Layout.Biz[index].Cash, 1), amount, index)
		Registry.Events.GiantAdd(Config.Giant.WorkPoints)
		Registry.Game.PushTick(player)
		Registry.Game.PushSoon(player)
	end
	-- continua trabalhando sozinho enquanto estiver em cima do tapete
	local p = localPosition(player, plot)
	if p and onWorkPad(p, index) then
		startWork(player, plot, index)
	end
end

function startWork(player: Player, plot: any, index: number)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local run = plot.Run
	local seconds, token = Sim.StartWork(Config, data, run, Registry.Game.Ctx(player), index)
	if not seconds or not token then
		return
	end
	Registry.Plots.SetWork(plot, index, workspace:GetServerTimeNow() + seconds, seconds)
	fx(player, "work", at(plot, Layout.Biz[index].U, 1), index, seconds)
	task.delay(seconds, function()
		local ok, err = pcall(finishWork, player, plot, run, index, token)
		if not ok then
			warn("[Farm] trabalho:", err)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Saco de dinheiro (regras em Sim.BagTick / Sim.DropBag / Sim.TakeBag; desenho em Plots.SyncBag)
-- ---------------------------------------------------------------------------
-- Onde o saco pode cair AGORA: os lugares do Layout a uma distância boa do dono (nem em cima dele, nem do
-- outro lado do terreno: com o terreno vazio do começo seria uma viagem). Sem personagem, longe do terreno
-- ou sem nenhum lugar nessa faixa: vale qualquer um (devolve só a quantidade).
local function bagSpots(player: Player, plot: any): any
	local spots = Layout.BagSpots or {}
	local p = localPosition(player, plot)
	if not p then
		return #spots
	end
	local near = Config.MoneyBag.Near
	local list = {}
	for index, spot in spots do
		local d = flat(p.X, p.Z, spot[1], spot[2])
		if d >= near[1] and d <= near[2] then
			table.insert(list, index)
		end
	end
	return if #list > 0 then list else #spots
end

-- Um saco acabou de cair (já está em plot.Run.Bag): desenha e avisa o dono (facho de luz, aviso e seta
-- são do cliente; os visitantes veem o saco pelo Model que o servidor criou).
local function bagDropped(owner: Player, plot: any, bag: any)
	Registry.Plots.SyncBag(plot)
	local spot = Layout.BagSpots[bag.Spot]
	fx(owner, "bagDrop", at(plot, spot, 2), bag.Golden == true, Config.MoneyBag.Life)
	Registry.Game.PushTick(owner)
end

-- Faz cair um saco agora (ferramenta de teste do Studio: VUODebug "bag"). golden nil = sorteia.
-- false se não deu (banca fechada, já tem um saco no chão ou o Layout não tem lugares).
function Farm.DropBag(player: Player, plot: any, golden: boolean?): boolean
	local data = Registry.Game.Data(player)
	if not data or not Config.MoneyBag then
		return false
	end
	local bag = Sim.DropBag(Config, data, plot.Run, math.random, bagSpots(player, plot), golden)
	if not bag then
		return false
	end
	bagDropped(player, plot, bag)
	return true
end

-- Um passo do relógio do saco (junto com a produção). Caiu = desenha e avisa o dono; passou do tempo sem
-- ninguém pegar = some, com um "puf" que todos veem (extra = dono, para só a tela DELE dar o aviso).
local function tickBag(owner: Player, plot: any, data: any, dt: number)
	local run = plot.Run
	local kind, bag = Sim.BagTick(Config, data, run, dt, math.random, if run.Bag then 0 else bagSpots(owner, plot))
	if kind == "drop" then
		bagDropped(owner, plot, bag)
	elseif kind == "gone" then
		Registry.Plots.SyncBag(plot)
		local spot = Layout.BagSpots and Layout.BagSpots[bag.Spot]
		if spot then
			Registry.Remotes.Fx:FireAllClients("bagGone", at(plot, spot, 2), bag.Golden == true, owner.UserId)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Chave secreta e Baú Secreto (regras em Sim.KeyTick / Sim.TakeKey / Sim.OpenChest; desenho em
-- Plots.SyncKey / Plots.SyncChest). Mesma arquitetura do saco de dinheiro.
-- ---------------------------------------------------------------------------
-- Onde a chave pode nascer AGORA: qualquer lugar do Layout que não esteja colado no dono (uma chave que
-- nasce aos pés dele seria pega na hora, sem procurar nada). Sem personagem no terreno, ou se todos os
-- lugares estiverem perto (não acontece: são espalhados), vale qualquer um (devolve só a quantidade).
local function keySpots(player: Player, plot: any): any
	local spots = Layout.KeySpots or {}
	local p = localPosition(player, plot)
	if not p then
		return #spots
	end
	local far = 3 * Config.Keys.Radius
	local list = {}
	for index, spot in spots do
		if flat(p.X, p.Z, spot[1], spot[2]) >= far then
			table.insert(list, index)
		end
	end
	return if #list > 0 then list else #spots
end

-- Uma chave acabou de nascer (já está em plot.Run.Key): desenha e avisa SÓ o dono, sem dizer onde
-- (o efeito "keyDrop" vai sem posição de propósito: a graça é procurar).
local function keyDropped(owner: Player, plot: any)
	Registry.Plots.SyncKey(plot)
	fx(owner, "keyDrop")
	Registry.Game.PushTick(owner)
end

-- Faz nascer uma chave agora (ferramenta de teste do Studio: VUODebug "key"). false se não deu (ainda
-- não abriu a Granja, já tem uma chave escondida, já está com todas as chaves na mão ou o Layout não tem lugares).
function Farm.DropKey(player: Player, plot: any): boolean
	local data = Registry.Game.Data(player)
	if not data or not Config.Keys then
		return false
	end
	local key = Sim.DropKey(Config, data, plot.Run, math.random, keySpots(player, plot))
	if not key then
		return false
	end
	keyDropped(player, plot)
	return true
end

-- Um passo do relógio da chave (junto com a produção).
local function tickKey(owner: Player, plot: any, data: any, dt: number)
	local run = plot.Run
	-- (com chave no chão ou as mãos cheias o relógio está parado: nem precisa montar a lista de lugares)
	local waiting = run.Key == nil and Sim.KeyCount(Config, data) < Config.Keys.Need
	local kind = Sim.KeyTick(Config, data, run, dt, math.random, if waiting then keySpots(owner, plot) else 0)
	if kind == "drop" then
		keyDropped(owner, plot)
	elseif kind == "gone" then
		Registry.Plots.SyncKey(plot)
		Registry.Game.PushTick(owner)
	end
end

-- ---------------------------------------------------------------------------
-- Poderes (regras em Sim.UsePower). O cliente só manda QUAL poder; se está liberado e pronto quem diz é
-- o servidor, com a hora do servidor.
-- ---------------------------------------------------------------------------
local POWER_ERRORS = { locked = "n.powerLocked", nonest = "n.powerNoNest" }

-- Usa o poder "id" do jogador. Devolve (true) ou (false, motivo). quiet = não avisa o erro na tela.
function Farm.UsePower(player: Player, id: any, quiet: boolean?): (boolean, string?)
	-- nunca confia no que veio do cliente: precisa ser o id (texto) de um poder que existe
	if type(id) ~= "string" or not Config.PowerById or not Config.PowerById[id] then
		return false, "unknown"
	end
	local data = Registry.Game.Data(player)
	local plot = Registry.Plots.Of(player)
	if not data or not plot then
		return false, "unknown"
	end
	local ctx = Registry.Game.Ctx(player)
	local out, reason = Sim.UsePower(Config, data, plot.Run, ctx, id, math.random)
	if not out then
		if not quiet then
			if reason == "wait" then
				local info = Sim.PowerInfo(Config, data, ctx, id)
				Registry.Remotes.NotifyPlayer(player, "n.powerWait", { s = math.max(1, math.ceil(info.ReadyAt - ctx.Now)) }, "error")
			elseif reason and POWER_ERRORS[reason] then
				Registry.Remotes.NotifyPlayer(player, POWER_ERRORS[reason], nil, "error")
			end
		end
		return false, reason
	end
	-- o efeito de cada poder no mundo (o ovo raro aparece no ninho como qualquer outro)
	if out.Rare then
		Farm.RareSpawned(player, plot, { out.Rare })
	end
	if out.Seconds then
		-- os negócios aceleraram: o ritmo (atributos Rate<i>) muda já, e de novo quando o efeito acabar
		Registry.Plots.SyncRates(plot)
		local run = plot.Run
		task.delay(out.Seconds + 0.6, function()
			if player.Parent and plot.Owner == player and plot.Run == run then
				pcall(Registry.Plots.SyncRates, plot)
				Registry.Game.Push(player)
			end
		end)
	end
	-- todos veem (na banca do dono). extra = { quem usou, moedas pagas (0 = este poder não paga), segundos do
	-- efeito (0 = sem duração), ave e ninho do ovo raro (0 = não é o poder do ovo) }: sempre números, sem
	-- buracos (lista com nil no meio não atravessa o RemoteEvent inteira)
	local stand = Layout.Stand
	Registry.Remotes.Fx:FireAllClients("power", at(plot, stand, 4), id, {
		player.UserId,
		out.Coins or 0,
		out.Seconds or 0,
		if out.Rare then out.Rare.Line else 0,
		if out.Rare then out.Rare.Slot else 0,
	})
	Registry.Game.Push(player)
	return true, nil
end

-- ---------------------------------------------------------------------------
-- Posição do jogador
-- ---------------------------------------------------------------------------
local function pollPlayer(player: Player, plot: any, dt: number)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local p = localPosition(player, plot)
	if not p then
		return
	end
	local ctx = Registry.Game.Ctx(player)
	local run = plot.Run

	-- botões
	local now = os.clock()
	local standing: { [string]: boolean } = {}
	for _, button in plot.Available do
		local point = Registry.Plots.ButtonPoint(button)
		if flat(p.X, p.Z, point[1], point[2]) <= Config.ButtonRadius then
			standing[button.Id] = true
			local held = (plot.Hold[button.Id] or 0) + dt
			plot.Hold[button.Id] = held
			if held >= Config.ButtonHold and now - plot.LastBuy >= Config.BuyCooldown then
				if Farm.TryBuy(player, plot, button) then
					return -- a lista de botões mudou; continua na próxima volta
				end
			end
		end
	end
	for id in plot.Hold do
		if not standing[id] then
			plot.Hold[id] = nil
		end
	end

	-- trabalhar: em cima do tapete azul de um negócio aberto e sem gerente
	for index = 2, #Config.Businesses do
		if onWorkPad(p, index) and Sim.CanWork(Config, data, run, index) then
			startWork(player, plot, index)
		end
	end

	-- moedas do chão (de cada negócio) e gorjetas (junto das moedas da banca)
	local radius = Sim.CollectRadius(Config, data, ctx)
	local changed = false
	for index in Config.Businesses do
		local cash = Layout.Biz[index].Cash
		if flat(p.X, p.Z, cash[1], cash[2]) <= radius then
			local amount = Sim.CollectGround(Config, data, run, index)
			if amount > 0 then
				Registry.Plots.SetGround(plot, index, 0)
			end
			if index == 1 and (run.Tips or 0) > 0 then
				local tips, n = Sim.CollectTips(Config, data, run, ctx)
				if n > 0 then
					Registry.Plots.SetTips(plot, 0)
					fx(player, "tips", at(plot, cash, 1), tips, n)
					amount += tips
				end
			end
			if amount > 0 then
				Registry.Remotes.Fx:FireAllClients("money", at(plot, cash, 3), amount, player.UserId)
				changed = true
			end
		end
	end

	-- saco de dinheiro: encostou, levou. Só o dono (este laço só olha cada jogador no terreno DELE) e com
	-- raio fixo (o Ímã não puxa o saco: a brincadeira é correr até o facho de luz antes que ele suma).
	local bag = run.Bag
	if bag and Config.MoneyBag then
		local spot = Layout.BagSpots and Layout.BagSpots[bag.Spot]
		if spot and flat(p.X, p.Z, spot[1], spot[2]) <= Config.MoneyBag.Radius then
			local amount, taken = Sim.TakeBag(Config, data, run, ctx)
			if taken then
				Registry.Plots.SyncBag(plot)
				Registry.Remotes.Fx:FireAllClients("bagTake", at(plot, spot, 3), amount, { player.UserId, taken.Golden == true })
				changed = true
			end
		end
	end

	-- chave secreta: o dono chegou perto do esconderijo, pegou (raio fixo, como o saco: o Ímã não puxa)
	local key = run.Key
	if key and Config.Keys then
		local spot = Layout.KeySpots and Layout.KeySpots[key.Spot]
		if spot and flat(p.X, p.Z, spot[1], spot[2]) <= Config.Keys.Radius then
			local count, taken = Sim.TakeKey(Config, data, run)
			if taken then
				Registry.Plots.SyncKey(plot)
				Registry.Plots.SyncChest(plot) -- (o baú mostra quantas chaves o dono tem)
				fx(player, "keyTake", at(plot, spot, 3), count, Config.Keys.Need)
				changed = true
			end
		end
	end

	-- Baú Secreto: o dono chegou ao baú com todas as chaves, abriu (gasta as chaves, paga moedas e giros)
	local chest = Layout.KeyChest
	if chest and Config.Keys and Sim.CanOpenChest(Config, data) and flat(p.X, p.Z, chest[1], chest[2]) <= Config.Keys.ChestRadius then
		local out = Sim.OpenChest(Config, data, ctx, math.random)
		if out then
			Registry.Plots.SyncChest(plot)
			Registry.Remotes.Fx:FireAllClients("chestOpen", at(plot, chest, 3), out.Coins, { player.UserId, out.Golden == true, out.Spins })
			changed = true
		end
	end

	-- ovos raros nos ninhos (de trás para frente: PickRare tira o item da lista)
	local full = false
	local picked = false
	for i = #run.Rare, 1, -1 do
		local egg = run.Rare[i]
		local nest = Layout.Lines[egg.Line].Nests[egg.Slot]
		if flat(p.X, p.Z, nest[1], nest[2]) <= radius then
			local key = Sim.PickRare(Config, data, run, ctx, i)
			if key then
				picked = true
				fx(player, "pickRare", at(plot, nest, 2), key)
			else
				full = true
			end
		end
	end
	if picked then
		Registry.Plots.SyncRare(plot)
		changed = true
	end
	if full and throttle(player, "full", 4) then
		Registry.Remotes.NotifyPlayer(player, "n.basketFull", nil, "error")
	end

	-- vender os ovos raros (tapete verde atrás do balcão)
	local sell = Layout.Sell
	if flat(p.X, p.Z, sell[1], sell[2]) <= Config.SellRadius and Sim.BasketCount(data) > 0 and throttle(player, "sell", 0.6) then
		local value, count, fresh = Sim.Sell(Config, data, ctx)
		if count > 0 then
			local position = at(plot, sell, 4)
			Registry.Remotes.Fx:FireAllClients("money", position, value, player.UserId)
			fx(player, "sold", position, value, count)
			for _, key in fresh do
				fx(player, "album", position, key)
			end
			Registry.Events.GiantAdd(math.min(Config.Giant.SellMax, count * Config.Giant.SellPoints))
			changed = true
		end
	end

	-- chocadeiras: primeiro pega o pet que já nasceu; senão põe o melhor ovo raro da cesta para chocar
	local slots = Sim.HatchSlots(Config, data)
	if slots > 0 then
		local near = false
		for slot = 1, slots do
			local point = Layout.Incubators[slot]
			if flat(p.X, p.Z, point[1], point[2]) <= Config.IncubatorRadius then
				near = true
				break
			end
		end
		if near and throttle(player, "hatch", 0.5) then
			local today = os.time()
			local slot, key, fresh, level = Sim.ClaimHatch(Config, data, ctx, today)
			if slot and key then
				fx(player, "hatched", at(plot, Layout.Incubators[tonumber(slot) :: number], 5), key, { fresh, level })
				Registry.Events.GiantAdd(Config.Giant.HatchPoints)
				local _, mut = Sim.ParseKey(key)
				local mutation = Config.MutationById[mut]
				if mutation and mutation.Index >= 2 then
					Registry.Remotes.NotifyAll("n.petAll", { player = player.DisplayName, pet = key }, "event")
				end
				Registry.Plots.SyncHatch(plot)
				changed = true
			else
				local startSlot, startKey, seconds = Sim.StartHatch(Config, data, today)
				if startSlot and startKey then
					fx(player, "hatchStart", at(plot, Layout.Incubators[tonumber(startSlot) :: number], 5), startKey, seconds)
					Registry.Plots.SyncHatch(plot)
					changed = true
				end
			end
		end
	end

	-- macieira
	if data.Owned.G_tree and run.Apples > 0 then
		local tree = Layout.Global.tree.Model
		if flat(p.X, p.Z, tree[1], tree[2]) <= 9 then
			local total, apples, golden = Sim.PickApples(Config, data, run, ctx)
			if total > 0 then
				fx(player, "apples", at(plot, tree, 6), total, { apples, golden })
				Registry.Plots.SyncRates(plot)
				changed = true
			end
		end
	end

	if changed then
		Registry.Game.Push(player)
	end
end

-- ---------------------------------------------------------------------------
-- Passes de conveniência (loja em Robux). Tudo acontece AQUI, no laço do servidor, pela posição do
-- personagem: o cliente não manda nada, então não há o que falsificar.
-- ---------------------------------------------------------------------------
-- Dentro do próprio terreno? (Layout.Size = { largura, z da frente, z do fundo })
local function onPlot(p: Vector3): boolean
	local size = Layout.Size
	if not size then
		return true
	end
	return math.abs(p.X) <= size[1] / 2 and p.Z >= size[2] and p.Z <= size[3]
end

local function passPerks(player: Player, plot: any, dt: number)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local ctx = Registry.Game.Ctx(player)
	local run = plot.Run
	local p = localPosition(player, plot)

	-- SuperClique: perto da banca o servidor vende sozinho (Config.SuperClick.PerSecond por segundo).
	-- Cada venda passa pelo Farm.Click de sempre: mesma distância e o MESMO limite de cliques por segundo
	-- de quem clica na mão (clique automático + dedo nunca passam do teto).
	local stand = Layout.Stand
	if p and flat(p.X, p.Z, stand[1], stand[2]) <= Config.ClickRadius then
		for _ = 1, Sim.AutoClicks(Config, data, run, ctx, dt) do
			Farm.Click(player, nil)
		end
	else
		run.AutoAcc = 0
	end

	-- Coletor Automático (passe Ima): de tempos em tempos recolhe o terreno inteiro, de onde ele estiver
	-- na granja: moedas do chão, gorjetas e ovos raros dos ninhos (enquanto couber na cesta).
	if p and onPlot(p) and Sim.HasPass(data, ctx, "Ima") and throttle(player, "autoCollect", Config.AutoCollectEvery) then
		local got = Sim.AutoCollect(Config, data, run, ctx)
		if got then
			for index in got.Ground do
				Registry.Plots.SetGround(plot, index, 0)
			end
			local root = Registry.Plots.RootOf(player)
			local where = if root then root.CFrame.Position else at(plot, Layout.Biz[1].Cash, 3)
			if got.Tips > 0 then
				Registry.Plots.SetTips(plot, 0)
				fx(player, "tips", where, got.TipCoins, got.Tips)
			end
			if got.Coins > 0 then
				Registry.Remotes.Fx:FireAllClients("money", where, got.Coins, player.UserId)
			end
			if #got.Eggs > 0 then
				for _, egg in got.Eggs do
					fx(player, "pickRare", at(plot, Layout.Lines[egg.Line].Nests[egg.Slot], 2), egg.Key)
				end
				Registry.Plots.SyncRare(plot)
			end
			Registry.Game.Push(player)
		end
	end
end

-- Junta tudo que está no chão (moedas e gorjetas) sem o jogador andar: antes de sair do jogo, de
-- renascer e de conquistar selo, para o que ele já ganhou não se perder. Devolve o total.
function Farm.Sweep(player: Player): number
	local data = Registry.Game.Data(player)
	local plot = Registry.Plots.Of(player)
	if not data or not plot then
		return 0
	end
	local total = Sim.CollectAllGround(Config, data, plot.Run, Registry.Game.Ctx(player))
	if total > 0 then
		for index in Config.Businesses do
			Registry.Plots.SetGround(plot, index, 0)
		end
		Registry.Plots.SetTips(plot, 0)
	end
	return total
end

-- ---------------------------------------------------------------------------
-- Produção
-- ---------------------------------------------------------------------------
-- Ovos raros acabaram de aparecer nos ninhos (já estão em plot.Run.Rare): desenha e avisa o dono.
function Farm.RareSpawned(owner: Player, plot: any, eggs: { any })
	Registry.Plots.SyncRare(plot)
	for _, egg in eggs do
		fx(owner, "rare", at(plot, Layout.Lines[egg.Line].Nests[egg.Slot], 2), egg.Mut, egg.Line)
		local mutation = Config.MutationById[egg.Mut]
		-- ovo mítico é raro de verdade: conta para o servidor todo (com intervalo, para não virar spam)
		if mutation and mutation.Index >= 3 and throttle(owner, "mythicAll", 90) then
			Registry.Remotes.NotifyAll("n.mythic", { player = owner.DisplayName, line = Config.Lines[egg.Line].Id }, "event")
		end
	end
	Registry.Game.PushTick(owner)
end

local function tickPlot(plot: any, dt: number)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	if not owner or not data then
		return
	end
	local ctx = Registry.Game.Ctx(owner)
	local out = Sim.Tick(Config, data, plot.Run, ctx, dt, math.random)
	if out.Tip then
		Registry.Plots.SetTips(plot, plot.Run.Tips)
		fx(owner, "tipDrop", at(plot, Layout.Biz[1].Cash, 1))
	end
	if #out.Rare > 0 then
		Farm.RareSpawned(owner, plot, out.Rare)
	end
	if out.Apples then
		Registry.Plots.SyncRates(plot)
	end
	-- saco de dinheiro (protegido: um erro no saco não pode parar a produção nem o Tick de quem está jogando)
	if Config.MoneyBag then
		local ok, err = pcall(tickBag, owner, plot, data, dt)
		if not ok then
			warn("[Farm] saco de dinheiro:", err)
		end
	end
	-- chave secreta (protegido pelo mesmo motivo)
	if Config.Keys then
		local ok, err = pcall(tickKey, owner, plot, data, dt)
		if not ok then
			warn("[Farm] chave secreta:", err)
		end
	end
	data.Stats.PlayTime += dt
	Registry.Events.GiantAdd(dt)
	Registry.Game.PushTick(owner)
end

function Farm.Init()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.TickSeconds)
			local now = os.clock()
			local dt = math.clamp(now - last, 0, 2)
			last = now
			for _, plot in Registry.Plots.All() do
				local ok, err = pcall(tickPlot, plot, dt)
				if not ok then
					warn("[Farm] produção:", err)
				end
			end
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.PollSeconds)
			local now = os.clock()
			local dt = math.clamp(now - last, 0, 1)
			last = now
			for _, player in Players:GetPlayers() do
				local plot = Registry.Plots.Of(player)
				if plot then
					local ok, err = pcall(pollPlayer, player, plot, dt)
					if not ok then
						warn("[Farm] posição:", err)
					end
					ok, err = pcall(passPerks, player, plot, dt)
					if not ok then
						warn("[Farm] passes:", err)
					end
				end
			end
		end
	end)

	-- os atributos de ritmo (Rate<i>) acompanham eventos e boosts, que mudam sem compra nenhuma
	task.spawn(function()
		while true do
			task.wait(3)
			for _, plot in Registry.Plots.All() do
				if plot.Owner then
					pcall(Registry.Plots.SyncRates, plot)
				end
			end
		end
	end)

	-- avisa quando um pet nasceu (uma vez por ovo)
	task.spawn(function()
		local told: { [Player]: { [string]: number } } = {}
		while true do
			task.wait(1)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = Registry.Game.Data(player)
				if data then
					local mine = told[player]
					if not mine then
						mine = {}
						told[player] = mine
					end
					for slot, hatch in data.Hatch do
						if now >= hatch.Ready and mine[slot] ~= hatch.Ready then
							mine[slot] = hatch.Ready
							Registry.Remotes.NotifyPlayer(player, "n.hatchReady", nil, "success")
							Registry.Remotes.Fx:FireClient(player, "sound", nil, "Chocar")
							Registry.Game.Push(player)
						end
					end
				end
			end
			for player in told do
				if not player.Parent then
					told[player] = nil
				end
			end
		end
	end)

	-- clique na banca pelo botão da tela. Intervalo 0: quem limita é a janela de cliques por segundo
	-- (o RequestCooldown geral de 0,25 s deixaria só 4 cliques por segundo)
	Registry.Remotes.On("Click", function(player: Player)
		Farm.Click(player, nil)
	end, 0)

	-- poderes: o cliente manda só o id; o servidor confere tipo, se está liberado e a recarga
	Registry.Remotes.On("Power", function(player: Player, id: any)
		Farm.UsePower(player, id)
	end)

	-- comprar de longe (talento/passe): compra o botão mais barato disponível
	Registry.Remotes.On("BuyNext", function(player: Player)
		local data = Registry.Game.Data(player)
		local plot = Registry.Plots.Of(player)
		if not data or not plot then
			return
		end
		if Sim.TalentLevel(Config, data, Registry.Game.Ctx(player), "remote") <= 0 then
			return
		end
		local button = Sim.NextButton(Config, data)
		if button then
			Farm.TryBuy(player, plot, button)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastMsg[player] = nil
		clicks[player] = nil
	end)
end

return Farm
