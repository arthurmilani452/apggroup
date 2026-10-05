--[[
	Farm: o ciclo da granja.
	  ave bota no ninho → jogador coleta (cesta) → leva até a banca → vende
	Também a coleta automática e a esteira (leva os ovos até a banca e vende sozinha).
	Tudo é conferido aqui no servidor: dono, distância, espaço na cesta, intervalo entre ações.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLib = require(ReplicatedStorage.Shared.AssetLib)
local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Registry = require(script.Parent.Registry)

local Farm = {}

local timers: { [any]: { number } } = {} -- [plot][ninho] = segundos acumulados
local lastAction: { [Player]: { [string]: number } } = {}
local beltCount: { [any]: number } = {}

local MAX_BELT_EGGS = 8

local function cooldown(player: Player, action: string, seconds: number): boolean
	local t = lastAction[player]
	if not t then
		t = {}
		lastAction[player] = t
	end
	local now = os.clock()
	if now - (t[action] or 0) < seconds then
		return false
	end
	t[action] = now
	return true
end

local function notify(player: Player, text: string, kind: string?)
	Registry.Remotes.NotifyPlayer(player, text, nil, kind)
end

-- Move ovos de um ninho para a cesta. Devolve quantos foram.
local function takeFromNest(player: Player, plot: any, index: number, data: any): number
	local eggs = plot.NestEggs[index]
	if not eggs or #eggs == 0 then
		return 0
	end
	local space = Registry.Economy.BasketCapacity(player) - Formulas.BasketCount(data)
	local moved, rares = 0, 0
	while space > 0 and #eggs > 0 do
		local entry = table.remove(eggs, 1)
		local key = Formulas.EggKey(entry.Egg, entry.Rare)
		data.Basket[key] = (data.Basket[key] or 0) + 1
		space -= 1
		moved += 1
		if entry.Rare then
			rares += 1
		end
	end
	if moved > 0 then
		data.Stats.Collected += moved
		Registry.Economy.Mission(player, "collect", moved)
		if rares > 0 then
			data.Stats.Rare += rares
			Registry.Economy.Mission(player, "rare", rares)
		end
		Registry.Plots.RefreshNest(plot, index)
	end
	return moved
end

function Farm.Collect(player: Player, plot: any, index: number)
	if plot.Owner ~= player or type(index) ~= "number" then
		return
	end
	local data = Registry.Economy.Data(player)
	local nest = plot.Nests[index]
	if not data or not nest or not Registry.Plots.Near(player, nest, Config.CollectDistance) then
		return
	end
	if not cooldown(player, "collect" .. index, 0.3) then
		return
	end
	if Formulas.BasketCount(data) >= Registry.Economy.BasketCapacity(player) then
		if cooldown(player, "fullMsg", 3) then
			notify(player, "Cesta cheia. Leva pra banca!", "error")
		end
		return
	end
	local moved = takeFromNest(player, plot, index, data)
	if moved > 0 then
		Registry.Remotes.Fx:FireClient(player, "collect", nest.Position, moved)
		Registry.Economy.Push(player)
	end
end

function Farm.Sell(player: Player, plot: any)
	if plot.Owner ~= player then
		return
	end
	local data = Registry.Economy.Data(player)
	local point = plot.Parts.SellPoint
	if not data or not Registry.Plots.Near(player, point, Config.SellDistance) then
		return
	end
	if not cooldown(player, "sell", 0.75) then
		return
	end
	local value, count = Formulas.BasketValue(Config, data, Registry.Economy.Owned(player), os.time())
	if count <= 0 then
		if cooldown(player, "emptyMsg", 4) then
			notify(player, "Cesta vazia. Pega ovo nos ninhos primeiro.", "info")
		end
		return
	end
	data.Basket = {}
	data.Stats.Sold += count
	data.Stats.SellTrips += 1
	Registry.Economy.AddCoins(player, value, true)
	Registry.Economy.Mission(player, "sell", count)
	Registry.Economy.Mission(player, "sellTrips", 1)
	Registry.Remotes.Fx:FireAllClients("money", point.Position + Vector3.new(0, 4, 0), value)
	Registry.Remotes.Fx:FireClient(player, "sold", point.Position, count)
	Registry.Economy.Push(player)
end

-- Ovo na esteira: anda pelos pontos ConvPath até a banca e vende sozinho
local function sendOnBelt(player: Player, plot: any, eggId: string, rare: boolean)
	local data = Registry.Economy.Data(player)
	if not data then
		return
	end
	local function credit()
		if plot.Owner ~= player then
			return
		end
		local value = math.floor(Formulas.EggValue(Config, eggId, rare) * Registry.Economy.Multiplier(player) + 0.5)
		data.Stats.Sold += 1
		Registry.Economy.AddCoins(player, value, true)
		Registry.Economy.Mission(player, "sell", 1)
	end
	local path = plot.Path
	if #path < 2 or (beltCount[plot] or 0) >= MAX_BELT_EGGS then
		credit() -- esteira lotada: vende direto (sem o ovo andando)
		return
	end
	local model = Registry.Plots.MakeEgg(eggId, rare)
	if not model then
		credit()
		return
	end
	beltCount[plot] = (beltCount[plot] or 0) + 1
	local beltFolder = plot.Visuals:FindFirstChild("Belt")
	model.Parent = beltFolder
	task.spawn(function()
		local total = 0
		for i = 1, #path - 1 do
			total += (path[i + 1].Position - path[i].Position).Magnitude
		end
		local speed = math.max(total / Config.ConveyorTravelTime, 1)
		for i = 1, #path - 1 do
			local a, b = path[i].Position, path[i + 1].Position
			local length = (b - a).Magnitude
			local t = 0
			while t < length and model.Parent do
				t = math.min(length, t + speed * 0.1)
				local p = a:Lerp(b, if length > 0 then t / length else 1)
				AssetLib.PlaceAt(model, p, 0)
				task.wait(0.1)
			end
		end
		model:Destroy()
		beltCount[plot] = math.max(0, (beltCount[plot] or 1) - 1)
		credit()
	end)
end

function Farm.Init()
	-- aves botam
	task.spawn(function()
		local STEP = 0.5
		while true do
			task.wait(STEP)
			for _, plot in Registry.Plots.All() do
				local owner = plot.Owner
				if not owner then
					timers[plot] = nil
					continue
				end
				local ok, err = pcall(function()
					local data = Registry.Economy.Data(owner)
					if not data then
						return
					end
					local t = timers[plot]
					if not t then
						t = {}
						timers[plot] = t
					end
					local now = os.time()
					local conveyor = Formulas.UpgradeValue(Config, data, "Esteira") > 0
					for i, henId in data.Hens do
						local hen = Config.HenById[henId]
						if not hen or not plot.Nests[i] then
							continue
						end
						local layTime = Formulas.LayTime(Config, data, henId)
						t[i] = (t[i] or math.random() * layTime * 0.5) + STEP
						if t[i] < layTime then
							continue
						end
						local rare = math.random() < Formulas.RareChance(Config, data, now)
						if conveyor then
							t[i] = 0
							sendOnBelt(owner, plot, hen.Egg, rare)
						elseif #plot.NestEggs[i] < Config.EggsPerNest then
							t[i] = 0
							table.insert(plot.NestEggs[i], { Egg = hen.Egg, Rare = rare })
							Registry.Plots.RefreshNest(plot, i)
						else
							t[i] = layTime -- ninho cheio: espera coletar
							continue
						end
						if rare then
							local egg = Config.EggById[hen.Egg]
							Registry.Remotes.Fx:FireClient(owner, "rare", plot.Nests[i].Position, egg and egg.Name or "")
							if egg and egg.Legendary then
								Registry.Remotes.NotifyAll(owner.DisplayName .. " tirou um " .. egg.Name .. " raro!", nil, "event")
							end
						end
					end
				end)
				if not ok then
					warn("[Farm] erro:", err)
				end
			end
		end
	end)

	-- coleta automática (melhoria ou game pass): pega os ovos de todos os ninhos sozinha
	task.spawn(function()
		while true do
			task.wait(Config.AutoCollectInterval)
			for _, plot in Registry.Plots.All() do
				local owner = plot.Owner
				local data = owner and Registry.Economy.Data(owner)
				if not owner or not data then
					continue
				end
				local auto = Formulas.UpgradeValue(Config, data, "ColetaAuto") > 0 or Registry.Economy.HasPass(owner, "ColetaAuto")
				if not auto then
					continue
				end
				local moved = 0
				for i = 1, #plot.Nests do
					moved += takeFromNest(owner, plot, i, data)
				end
				if moved > 0 then
					Registry.Economy.Push(owner)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return Farm
