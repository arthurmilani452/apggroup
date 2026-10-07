--[[
	Events: o que acontece "sozinho" no servidor.
	  • Chuva de Milho: por um tempo, todos os negócios rodam mais rápido (Game.EventSpeed).
	  • Ovo Surpresa: um ovo gigante cai na praça; quem encostar ganha um prêmio (cada um ganha o seu).
	  • Corrida de Galinhas: todo mundo escolhe uma galinha; o prêmio depende da colocação dela.
	  • Encomenda: de tempos em tempos um freguês faz uma oferta (aceitar, pedir mais ou recusar).
	  • Caça aos Ovos: ovos dourados escondidos pelo mapa.
	  • OVO GIGANTE da praça: enche com o jogo de todo mundo; quando enche, racha e dá prêmio a todos.
	  • Obby: chegar ao baú dá prêmio e um giro na roleta.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLib = require(ReplicatedStorage.Shared.AssetLib)
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Sim = require(ReplicatedStorage.Shared.Sim)
local Registry = require(script.Parent.Registry)

local Events = {}

Events.Current = nil :: string? -- evento em andamento

local folder: Folder

local function randomBetween(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function pushAll()
	for _, player in Players:GetPlayers() do
		Registry.Game.Push(player)
	end
end

-- ---------------------------------------------------------------------------
-- Chuva de Milho
-- ---------------------------------------------------------------------------
local function runRain(event: any)
	Registry.Game.EventSpeed = event.Speed
	Registry.Remotes.Fx:FireAllClients("event", nil, "rain", event.Duration)
	pushAll()
	task.wait(event.Duration)
	Registry.Game.EventSpeed = 1
	Registry.Remotes.Fx:FireAllClients("eventEnd", nil, "rain")
	pushAll()
end

-- ---------------------------------------------------------------------------
-- Ovo Surpresa
-- ---------------------------------------------------------------------------
local function runGift(event: any)
	local spots = Layout.GiftSpots
	local spot = spots[math.random(1, #spots)]
	local model = AssetLib.Get("Ovo_ArcoIris", 5)
	if not model then
		return
	end
	AssetLib.SetCollide(model, false)
	model.Name = "OvoSurpresa"
	model:PivotTo(CFrame.new(spot[1], 0.3, spot[2]))
	CollectionService:AddTag(model, "VUOGift")
	model.Parent = folder
	local position = Vector3.new(spot[1], 4, spot[2])
	Registry.Remotes.Fx:FireAllClients("event", position, "gift", event.Duration)
	local claimed: { [Player]: boolean } = {}
	local elapsed = 0
	while elapsed < event.Duration do
		elapsed += task.wait(0.3)
		for _, player in Players:GetPlayers() do
			if not claimed[player] then
				local root = Registry.Plots.RootOf(player)
				if root and Registry.Game.Data(player) and (root.CFrame.Position - position).Magnitude <= 11 then
					claimed[player] = true
					local reward = Registry.Game.Reward(player, randomBetween(event.Seconds), 25, false)
					Registry.Remotes.Fx:FireClient(player, "reward", nil, reward, "giftEgg")
				end
			end
		end
	end
	model:Destroy()
	Registry.Remotes.Fx:FireAllClients("eventEnd", nil, "gift")
end

-- ---------------------------------------------------------------------------
-- Corrida de Galinhas
-- ---------------------------------------------------------------------------
local RACERS = { "Galinha_Comum", "Galinha_Caipira", "Pata", "Codorna" }
local picks: { [Player]: number } = {}
local raceOpen = false

local function runRace(event: any)
	local race = Layout.Race
	local base = CFrame.new(race.X, 0, race.Z) * CFrame.Angles(0, math.rad(race.Yaw), 0)
	local racers = {}
	for lane, asset in RACERS do
		local model = AssetLib.Get(asset, 1.6)
		if model then
			AssetLib.SetCollide(model, false)
			model.Name = "Racer" .. lane
			model:SetAttribute("Lane", lane)
			model:PivotTo(base * CFrame.new(race.StartX, 0.2, race.Lanes[lane]) * CFrame.Angles(0, math.rad(-90), 0))
			CollectionService:AddTag(model, "VUORacer")
			model.Parent = folder
			racers[lane] = model
		end
	end
	picks = {}
	raceOpen = true
	Registry.Remotes.Fx:FireAllClients("event", (base * CFrame.new(0, 6, 0)).Position, "race", event.Pick)
	task.wait(event.Pick)
	raceOpen = false
	-- sorteia a ordem de chegada e o tempo de cada galinha
	local order = { 1, 2, 3, 4 }
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local times = {}
	local place = {}
	for position, lane in order do
		times[lane] = event.Run * (0.62 + 0.1 * position) + math.random() * 0.4
		place[lane] = position
	end
	Registry.Remotes.Fx:FireAllClients("raceGo", nil, times, order)
	task.wait(event.Run + 1.5)
	for player, lane in picks do
		if player.Parent and Registry.Game.Data(player) then
			local position = place[lane] or 4
			local reward = Registry.Game.Reward(player, event.Seconds[position] or 0, 10, false)
			Registry.Remotes.Fx:FireClient(player, "raceResult", nil, reward, position)
		end
	end
	Registry.Remotes.NotifyAll("n.raceWinner", { lane = order[1] }, "event")
	picks = {}
	task.wait(4)
	for _, model in racers do
		model:Destroy()
	end
	Registry.Remotes.Fx:FireAllClients("eventEnd", nil, "race")
end

local RUNNERS = { rain = runRain, gift = runGift, race = runRace }

-- ---------------------------------------------------------------------------
-- Encomendas
-- ---------------------------------------------------------------------------
local orders: { [Player]: { Value: number, Expires: number } } = {}
local nextOrder: { [Player]: number } = {}

local function offerOrder(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local _, all = Sim.Income(Config, data, Registry.Game.Ctx(player))
	if all <= 0 or Sim.Count(data.Owned) < Config.OrderMinButtons then
		return -- nos primeiros minutos a janela da encomenda atrapalharia o tutorial
	end
	local value = Sim.Reward(Config, data, Registry.Game.Ctx(player), randomBetween(Config.OrderSeconds), 20)
	orders[player] = { Value = value, Expires = os.clock() + Config.OrderTimeout }
	Registry.Remotes.Fx:FireClient(player, "order", nil, value, { Config.OrderTimeout, math.random(1, 6) })
end

local function answerOrder(player: Player, answer: any)
	local order = orders[player]
	local data = Registry.Game.Data(player)
	if not order or not data then
		return
	end
	orders[player] = nil
	if os.clock() > order.Expires + 2 or answer == "decline" then
		return
	end
	local value = order.Value
	if answer == "haggle" then
		if math.random() < Config.OrderHaggleChance then
			value = math.floor(value * (1 + randomBetween(Config.OrderHaggleBonus)))
			Registry.Remotes.NotifyPlayer(player, "n.haggleWin", nil, "success")
		else
			Registry.Remotes.NotifyPlayer(player, "n.haggleLose", nil, "error")
			return
		end
	elseif answer ~= "accept" then
		return
	end
	data.Stats.Orders += 1
	Sim.AddCoins(data, value, true)
	Registry.Remotes.Fx:FireClient(player, "reward", nil, value, "order")
	Registry.Game.Push(player)
end

-- ---------------------------------------------------------------------------
-- Caça aos Ovos
-- ---------------------------------------------------------------------------
local function pollHunt()
	local spots = Layout.Hunt
	for _, player in Players:GetPlayers() do
		local data = Registry.Game.Data(player)
		local root = Registry.Plots.RootOf(player)
		if data and root then
			for index, spot in spots do
				if not data.Hunt[tostring(index)] then
					local d = root.CFrame.Position - Vector3.new(spot[1], spot[2] + 2, spot[3])
					if d.Magnitude <= 6.5 then
						local fresh, found = Sim.FindHunt(Config, data, index, #spots)
						if fresh then
							Registry.Remotes.Fx:FireClient(player, "hunt", root.CFrame.Position, found, #spots)
							if found >= #spots then
								Registry.Remotes.NotifyAll("n.huntAll", { player = player.DisplayName }, "event")
							end
							Registry.Game.Push(player)
						end
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- OVO GIGANTE
-- O modelo fica em workspace.Events.GiantEgg com os atributos que o cliente usa para desenhar:
--   Progress (0..1), Variant ("ouro"...), State ("fill" | "crack"), CrackAt (hora do servidor)
-- ---------------------------------------------------------------------------
local GIANT_EGG = { ouro = "Ovo_Dourado", cristal = "Ovo_Cristal", arcoiris = "Ovo_ArcoIris", lunar = "Ovo_Lunar", dragao = "Ovo_Dragao" }
local giant = { Points = 0, Target = Config.Giant.Target, Model = nil :: Model?, Busy = false, Variant = "ouro", Shown = -1 }

local function giantTarget(): number
	local n = math.max(1, #Players:GetPlayers())
	return Config.Giant.Target * n ^ 0.85
end

local function spawnGiant()
	if giant.Model then
		giant.Model:Destroy()
		giant.Model = nil
	end
	local spot = Layout.Giant
	giant.Variant = Sim.GiantVariant(Config, os.time())
	local model = AssetLib.Get(GIANT_EGG[giant.Variant] or "Ovo_Dourado", spot[4])
	if not model then
		return
	end
	AssetLib.SetCollide(model, true)
	model.Name = "GiantEgg"
	model:PivotTo(CFrame.new(spot[1], spot[2], spot[3]))
	model:SetAttribute("Progress", 0)
	model:SetAttribute("Variant", giant.Variant)
	model:SetAttribute("State", "fill")
	model:SetAttribute("CrackAt", 0)
	CollectionService:AddTag(model, "VUOGiant")
	model.Parent = folder
	giant.Model = model
	giant.Points = 0
	giant.Shown = -1
end

local function crackGiant()
	local model = giant.Model
	if giant.Busy or not model then
		return
	end
	giant.Busy = true
	local G = Config.Giant
	local spot = Layout.Giant
	local center = Vector3.new(spot[1], spot[2] + 6, spot[3])
	model:SetAttribute("Progress", 1)
	model:SetAttribute("State", "crack")
	model:SetAttribute("CrackAt", workspace:GetServerTimeNow() + G.Countdown)
	Registry.Remotes.Fx:FireAllClients("giantSoon", center, giant.Variant, G.Countdown)
	Registry.Remotes.NotifyAll("n.giantSoon", { n = G.Countdown }, "event")
	task.wait(G.Countdown)
	local winners = {}
	for _, player in Players:GetPlayers() do
		local data = Registry.Game.Data(player)
		if data then
			local root = Registry.Plots.RootOf(player)
			local near = root ~= nil and (root.CFrame.Position - center).Magnitude <= G.NearRadius
			local coins, pet = Sim.GiantReward(Config, data, Registry.Game.Ctx(player), near, giant.Variant, math.random)
			Registry.Remotes.Fx:FireClient(player, "giantReward", nil, coins, { near, pet })
			if pet then
				table.insert(winners, player.DisplayName)
			end
			Registry.Game.Push(player)
		end
	end
	Registry.Remotes.Fx:FireAllClients("giantCrack", center, giant.Variant)
	for _, name in winners do
		Registry.Remotes.NotifyAll("n.giantPet", { player = name }, "event")
	end
	model:Destroy()
	giant.Model = nil
	task.wait(8)
	spawnGiant()
	giant.Busy = false
end

-- Soma pontos ao Ovo Gigante (qualquer jogador; chamado pelo Farm: tempo de jogo, cliques e ciclos na
-- mão, compras, ovos raros vendidos e pets chocados)
function Events.GiantAdd(points: number)
	if giant.Busy or not giant.Model or points ~= points or points <= 0 then
		return
	end
	giant.Points += points
end

function Events.GiantProgress(): number
	return math.clamp(giant.Points / math.max(giant.Target, 1), 0, 1)
end

local function stepGiant()
	if giant.Busy then
		return
	end
	if not giant.Model then
		spawnGiant()
		return
	end
	giant.Target = giantTarget()
	local progress = Events.GiantProgress()
	local shown = math.floor(progress * 200) / 200
	if shown ~= giant.Shown then
		giant.Shown = shown
		giant.Model:SetAttribute("Progress", shown)
	end
	if progress >= 1 and #Players:GetPlayers() > 0 then
		task.spawn(function()
			local ok, err = pcall(crackGiant)
			if not ok then
				warn("[Events] ovo gigante:", err)
				giant.Busy = false
				spawnGiant()
			end
		end)
	end
end

-- Só para teste no Studio: enche o ovo na hora
function Events.GiantFill(fraction: number)
	giant.Points = giantTarget() * math.clamp(fraction, 0, 1)
end

-- ---------------------------------------------------------------------------
-- Obby: quem chega ao baú ganha o prêmio (com tempo de espera)
-- ---------------------------------------------------------------------------
local obbyTold: { [Player]: number } = {}

local function pollObby()
	local obby = Layout.Obby
	if not obby then
		return
	end
	local chest = Vector3.new(obby.Chest[1], obby.Chest[2], obby.Chest[3])
	for _, player in Players:GetPlayers() do
		local data = Registry.Game.Data(player)
		local root = Registry.Plots.RootOf(player)
		if data and root and (root.CFrame.Position - chest).Magnitude <= Config.Obby.Radius then
			local now = os.time()
			local coins = Sim.ClaimObby(Config, data, Registry.Game.Ctx(player), now)
			if coins > 0 then
				Registry.Remotes.Fx:FireClient(player, "obby", chest, coins, Config.Obby.Spins)
				Registry.Remotes.NotifyAll("n.obbyDone", { player = player.DisplayName }, "event")
				Registry.Game.Push(player)
			elseif os.clock() - (obbyTold[player] or 0) > 6 then
				obbyTold[player] = os.clock()
				Registry.Remotes.NotifyPlayer(player, "n.obbyWait", { t = math.ceil((data.ObbyAt - now) / 60) }, "info")
			end
		end
	end
end

-- Só para teste no Studio (ServerStorage.VUODebug): começa um evento agora
function Events.Force(id: string): boolean
	local event = Config.EventById[id]
	local runner = RUNNERS[id]
	if not event or not runner or Events.Current then
		return false
	end
	Events.Current = id
	task.spawn(function()
		local ok, err = pcall(runner, event)
		if not ok then
			warn("[Events] " .. id .. ":", err)
			Registry.Game.EventSpeed = 1
		end
		Events.Current = nil
	end)
	return true
end

function Events.ForceOrder(player: Player)
	offerOrder(player)
end

function Events.Init()
	folder = Instance.new("Folder")
	folder.Name = "Events"
	folder.Parent = workspace
	Registry.Game.HuntTotal = #Layout.Hunt

	Registry.Remotes.On("Order", answerOrder)
	Registry.Remotes.On("RacePick", function(player: Player, lane: any)
		if raceOpen and type(lane) == "number" and lane >= 1 and lane <= #RACERS and lane % 1 == 0 then
			picks[player] = lane
		end
	end)

	-- rodízio de eventos
	task.spawn(function()
		task.wait(Config.EventFirst)
		local index = 0
		while true do
			index = index % #Config.Events + 1
			local event = Config.Events[index]
			local runner = RUNNERS[event.Id]
			-- (not Events.Current: um evento começado pelo VUODebug ainda está rodando; dois ao mesmo tempo
			-- se atropelam: duas corridas apagam os palpites uma da outra e deixam galinhas em dobro na pista)
			if runner and not Events.Current and #Players:GetPlayers() > 0 then
				Events.Current = event.Id
				local ok, err = pcall(runner, event)
				if not ok then
					warn("[Events] " .. event.Id .. ":", err)
					Registry.Game.EventSpeed = 1
				end
				Events.Current = nil
			end
			task.wait(Config.EventEvery)
		end
	end)

	-- encomendas e caça aos ovos
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if Registry.Game.Data(player) then
					local due = nextOrder[player]
					if not due then
						nextOrder[player] = now + randomBetween(Config.OrderEvery) * 0.5
					elseif now >= due then
						nextOrder[player] = now + randomBetween(Config.OrderEvery)
						pcall(offerOrder, player)
					end
				end
			end
			pcall(pollHunt)
			pcall(pollObby)
		end
	end)

	-- Ovo Gigante
	task.spawn(function()
		while true do
			local ok, err = pcall(stepGiant)
			if not ok then
				warn("[Events] ovo gigante:", err)
			end
			task.wait(1)
		end
	end)

	-- Roleta da praça: chegar perto e apertar abre a roleta (a tela abre no cliente)
	for _, wheel in CollectionService:GetTagged("VUOWheel") do
		local disk = wheel:FindFirstChild("Disco", true)
		if disk and disk:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Spin"
			prompt.ActionText = "🎡"
			prompt.ObjectText = ""
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 16
			prompt.RequiresLineOfSight = false
			prompt.Parent = disk
			CollectionService:AddTag(prompt, "VUOWheelPrompt")
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		orders[player] = nil
		nextOrder[player] = nil
		picks[player] = nil
		obbyTold[player] = nil
	end)
end

return Events
