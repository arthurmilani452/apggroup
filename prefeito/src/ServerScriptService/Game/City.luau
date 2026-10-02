--[[
	City (ModuleScript em ServerScriptService > Game)          Prefeito Tycoon
	A cidade de cada jogador enquanto ele joga: construir, demolir, simulação, cofre, expansões,
	migração de moradores entre cidades, turismo e reeleição.

	Tudo que o jogador pede chega em City.HandleRequest(player, ação, dados) e é conferido aqui
	(o cliente só desenha e pede). A conta da cidade é a mesma do painel: Shared/CityMath.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Buildings = require(Shared.Buildings)
local Grid = require(Shared.Grid)
local CityMath = require(Shared.CityMath)
local Format = require(Shared.Format)
local LotLayout = require(Shared.LotLayout)

local Game = script.Parent
local Data = require(Game.Data)
local Remotes = require(Game.Remotes)
local Lots = require(Game.Lots)
local Events = require(Game.Events)

local City = {}

type CityT = {
	Player: Player,
	Data: any,
	Lot: number,
	State: Grid.State,
	Population: number,
	Stats: CityMath.Stats,
	Visitors: number,
	Passes: { [string]: boolean },
	Cooldowns: { [string]: number },
	Notices: { [string]: number },
}

local cities: { [Player]: CityT } = {}

local function now(): number
	return os.clock()
end

local function today(): number
	return os.time() // 86400
end

local function cityName(data: any): string
	local a = Config.CityNameA[data.NameA] or Config.CityNameA[1]
	local b = Config.CityNameB[data.NameB] or Config.CityNameB[1]
	return a .. " " .. b
end

-- Avisos que não podem virar spam (cofre cheio, migração...): no máximo um a cada `every` segundos
local function noticeOnce(city: CityT, key: string, every: number, text: string, kind: string?)
	local t = now()
	if (city.Notices[key] or -math.huge) + every > t then
		return
	end
	city.Notices[key] = t
	Remotes.Notify(city.Player, text, kind)
end

local function cooldown(city: CityT, key: string, seconds: number): boolean
	local t = now()
	if (city.Cooldowns[key] or -math.huge) + seconds > t then
		return false
	end
	city.Cooldowns[key] = t
	return true
end

local function addCash(city: CityT, amount: number)
	local data = city.Data
	data.Cash = math.min(Config.MaxCash, data.Cash + amount)
	if amount > 0 then
		data.TotalEarned += amount
	end
end

local function compute(city: CityT): CityMath.Stats
	city.Stats = CityMath.Compute(city.State, {
		Population = city.Population,
		Reelections = city.Data.Reelections,
		DoubleIncome = city.Passes.DoubleIncome,
		Visitors = city.Visitors,
		Event = Events.Current(),
	})
	return city.Stats
end

local function vaultCapacity(city: CityT): number
	return CityMath.VaultCapacity(city.Data.VaultLevel, city.Stats.IncomePerSec)
end

local function refreshVaultText(city: CityT)
	if city.Passes.AutoCollect then
		Lots.SetVaultText(city.Lot, "COLETA AUTOMÁTICA")
		return
	end
	Lots.SetVaultText(city.Lot, Format.Money(city.Data.Vault) .. " / " .. Format.Money(vaultCapacity(city)))
end

function City.Sync(player: Player)
	local city = cities[player]
	if not city then
		return
	end
	local data = city.Data
	local stats = city.Stats
	local event = Events.Current()
	local nextExpansion = Config.Expansions[data.Expansion + 1]
	local nextVault = Config.Vault.Levels[data.VaultLevel + 1]
	Remotes.Stats:FireClient(player, {
		Lot = city.Lot,
		CityName = cityName(data),
		NameA = data.NameA,
		NameB = data.NameB,
		Cash = data.Cash,
		Vault = data.Vault,
		VaultCapacity = vaultCapacity(city),
		VaultLevel = data.VaultLevel,
		NextVaultCost = if nextVault then nextVault.Cost else nil,
		Expansion = data.Expansion,
		NextExpansionCost = if nextExpansion then nextExpansion.Cost else nil,
		Income = stats.IncomePerSec,
		Multiplier = stats.Multiplier,
		Population = city.Population,
		Target = stats.TargetPopulation,
		Housing = stats.Housing,
		Jobs = stats.Jobs,
		Workers = stats.Workers,
		Happiness = stats.Happiness,
		PowerSupply = stats.PowerSupply,
		PowerDemand = stats.PowerDemand,
		Coverage = stats.Coverage,
		NoRoad = stats.NoRoadCount,
		Tier = stats.Tier,
		TierReached = data.TierReached,
		Reelections = data.Reelections,
		Stars = data.Stars,
		Visitors = city.Visitors,
		Event = if event then event.Id else "",
		AutoCollect = city.Passes.AutoCollect == true,
		DoubleIncome = city.Passes.DoubleIncome == true,
		Tutorial = data.Tutorial,
	})
end

local function publish(city: CityT)
	local data = city.Data
	Lots.SetInfo(city.Lot, {
		CityName = cityName(data),
		Population = math.floor(city.Population),
		Stars = data.Stars,
		Happiness = math.floor(city.Stats.Happiness + 0.5),
	})
	local stats = city.Player:FindFirstChild("leaderstats")
	if stats then
		(stats :: any)["População"].Value = math.floor(city.Population);
		(stats :: any).Estrelas.Value = data.Stars
	end
	city.Player:SetAttribute("Population", math.floor(city.Population))
	city.Player:SetAttribute("PeakPopulation", data.PeakPopulation)
	city.Player:SetAttribute("Stars", data.Stars)
	refreshVaultText(city)
end

-- ======== Construção ========

local function placeOne(city: CityT, def: Buildings.Building, x: number, z: number, rot: number): (boolean, string?)
	local data = city.Data
	if def.Tier > data.TierReached then
		return false, def.Name .. " libera no nível " .. Config.Tiers[def.Tier].Name
	end
	local ok, reason = Grid.CanPlace(city.State, data.Expansion, def, x, z, rot)
	if not ok then
		return false, reason
	end
	if data.Cash < def.Cost then
		return false, "Falta dinheiro (" .. Format.Money(def.Cost) .. ")"
	end
	addCash(city, -def.Cost)
	local uid = Grid.Place(city.State, def, x, z, rot)
	Lots.Render(city.Lot, city.State.Buildings[uid])
	return true, nil
end

local function afterBuild(city: CityT)
	compute(city)
	Lots.SetWarnings(city.Lot, city.Stats.NoRoad)
	publish(city)
	City.Sync(city.Player)
end

local actions: { [string]: (CityT, any) -> () } = {}

actions.place = function(city, payload)
	if type(payload) ~= "table" or not cooldown(city, "build", Config.ActionCooldown) then
		return
	end
	local def = Buildings.ById[payload.Id]
	if not def then
		return
	end
	local ok, reason = placeOne(city, def, payload.X, payload.Z, payload.R)
	if ok then
		Remotes.Effect(city.Player, "placed", def.Id)
		afterBuild(city)
	else
		Remotes.Notify(city.Player, reason or "Não dá para construir aí", "erro")
	end
end

-- Arrastar ruas (e outros prédios 1x1): várias casas num pedido só
actions.line = function(city, payload)
	if type(payload) ~= "table" or type(payload.Cells) ~= "table" or not cooldown(city, "build", Config.ActionCooldown) then
		return
	end
	local def = Buildings.ById[payload.Id]
	if not def or def.W ~= 1 or def.D ~= 1 then
		return
	end
	local placedCount = 0
	local lastReason = nil
	for i, cell in payload.Cells do
		if i > 48 then
			break
		end
		if type(cell) == "table" then
			local ok, reason = placeOne(city, def, cell[1], cell[2], tonumber(payload.R) or 0)
			if ok then
				placedCount += 1
			else
				lastReason = reason
				if city.Data.Cash < def.Cost then
					break
				end
			end
		end
	end
	if placedCount > 0 then
		Remotes.Effect(city.Player, "placed", def.Id)
		afterBuild(city)
	elseif lastReason then
		Remotes.Notify(city.Player, lastReason, "erro")
	end
end

actions.remove = function(city, payload)
	if type(payload) ~= "table" or not cooldown(city, "build", Config.ActionCooldown) then
		return
	end
	local uids = if type(payload.Uids) == "table" then payload.Uids else { payload.Uid }
	local removed = 0
	for i, uid in uids do
		if i > 48 then
			break
		end
		local placed = type(uid) == "number" and city.State.Buildings[uid]
		if placed then
			local def = Buildings.ById[placed.Id]
			Grid.Remove(city.State, uid)
			Lots.Unrender(city.Lot, uid)
			if def then
				addCash(city, math.floor(def.Cost * Config.SellRefund))
			end
			removed += 1
		end
	end
	if removed > 0 then
		Remotes.Effect(city.Player, "removed", removed)
		afterBuild(city)
	end
end

actions.collect = function(city, _payload)
	local data = city.Data
	if data.Vault < 1 then
		return
	end
	local amount = math.floor(data.Vault)
	data.Vault -= amount
	addCash(city, amount)
	Remotes.Effect(city.Player, "collect", amount)
	refreshVaultText(city)
	City.Sync(city.Player)
end

actions.expand = function(city, _payload)
	local data = city.Data
	local nextInfo = Config.Expansions[data.Expansion + 1]
	if not nextInfo or not cooldown(city, "buy", 0.5) then
		return
	end
	if data.Cash < nextInfo.Cost then
		Remotes.Notify(city.Player, "Falta dinheiro para expandir (" .. Format.Money(nextInfo.Cost) .. ")", "erro")
		return
	end
	addCash(city, -nextInfo.Cost)
	data.Expansion += 1
	Lots.SetExpansion(city.Lot, data.Expansion)
	Remotes.Notify(city.Player, "Terreno expandido para " .. nextInfo.Size .. "x" .. nextInfo.Size .. "!", "ok")
	Remotes.Effect(city.Player, "upgrade")
	afterBuild(city)
end

actions.vault = function(city, _payload)
	local data = city.Data
	local nextInfo = Config.Vault.Levels[data.VaultLevel + 1]
	if not nextInfo or not cooldown(city, "buy", 0.5) then
		return
	end
	if data.Cash < nextInfo.Cost then
		Remotes.Notify(city.Player, "Falta dinheiro para o cofre (" .. Format.Money(nextInfo.Cost) .. ")", "erro")
		return
	end
	addCash(city, -nextInfo.Cost)
	data.VaultLevel += 1
	Remotes.Notify(city.Player, "Cofre maior: guarda " .. nextInfo.Minutes .. " min de renda.", "ok")
	Remotes.Effect(city.Player, "upgrade")
	refreshVaultText(city)
	City.Sync(city.Player)
end

actions.rename = function(city, payload)
	if type(payload) ~= "table" or not cooldown(city, "rename", 3) then
		return
	end
	local a, b = tonumber(payload.A), tonumber(payload.B)
	if not a or not b or not Config.CityNameA[a] or not Config.CityNameB[b] then
		return
	end
	city.Data.NameA, city.Data.NameB = a, b
	publish(city)
	City.Sync(city.Player)
end

actions.reelect = function(city, _payload)
	local data = city.Data
	if city.Population < Config.Reelection.Population or not cooldown(city, "reelect", 5) then
		Remotes.Notify(city.Player, "A reeleição pede " .. Format.Int(Config.Reelection.Population, ".") .. " moradores.", "erro")
		return
	end
	for uid in city.State.Buildings do
		Lots.Unrender(city.Lot, uid)
	end
	city.State = Grid.new()
	city.Population = 0
	data.Reelections += 1
	data.Cash = Config.StartCash
	data.Vault = 0
	data.VaultLevel = 1
	data.Expansion = 1
	data.TierReached = 1
	data.Population = 0
	data.Buildings = {}
	Lots.SetExpansion(city.Lot, 1)
	Remotes.NotifyAll(city.Player.DisplayName .. " foi reeleito prefeito de " .. cityName(data) .. "! (" .. data.Reelections .. "º mandato)", "evento")
	Remotes.Effect(city.Player, "reelected", data.Reelections)
	afterBuild(city)
end

local function teleport(player: Player, lot: number)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(LotLayout.SpawnCFrame(lot))
	end
end

actions.home = function(city, _payload)
	if cooldown(city, "teleport", 1.5) then
		teleport(city.Player, city.Lot)
	end
end

actions.visit = function(city, payload)
	local lot = type(payload) == "table" and tonumber(payload.Lot)
	if not lot or not Lots.OwnerOf(lot) or not cooldown(city, "teleport", 1.5) then
		return
	end
	teleport(city.Player, lot)
end

actions.recommend = function(city, payload)
	local lot = type(payload) == "table" and tonumber(payload.Lot)
	local owner = lot and Lots.OwnerOf(lot)
	local target = owner and cities[owner]
	if not target or target == city or not cooldown(city, "recommend", 1) then
		return
	end
	local data = city.Data
	if data.Recommended.Day ~= today() then
		data.Recommended = { Day = today(), Users = {} }
	end
	if table.find(data.Recommended.Users, owner.UserId) then
		Remotes.Notify(city.Player, "Você já recomendou essa cidade hoje.", "erro")
		return
	end
	table.insert(data.Recommended.Users, owner.UserId)
	target.Data.Stars += 1
	local T = Config.Tourism
	local mine = math.max(T.RecommendMinReward, math.floor(city.Stats.IncomePerSec * T.RecommendRewardSeconds))
	local theirs = math.max(T.RecommendMinReward, math.floor(target.Stats.IncomePerSec * T.OwnerRewardSeconds))
	addCash(city, mine)
	addCash(target, theirs)
	Remotes.Notify(city.Player, "Você recomendou " .. cityName(target.Data) .. " e ganhou " .. Format.Money(mine) .. "!", "ok")
	Remotes.Notify(owner, city.Player.DisplayName .. " recomendou a sua cidade! +1 estrela e " .. Format.Money(theirs), "ok")
	Remotes.Effect(owner, "star")
	publish(target)
	City.Sync(city.Player)
	City.Sync(owner)
end

actions.tutorial = function(city, payload)
	local step = type(payload) == "table" and tonumber(payload.Step)
	if step and step >= 0 and step <= 20 and step == math.floor(step) then
		city.Data.Tutorial = step
	end
end

function City.HandleRequest(player: Player, action: any, payload: any)
	local city = cities[player]
	if not city or type(action) ~= "string" then
		return
	end
	local handler = actions[action]
	if handler then
		handler(city, payload)
	end
end

-- ======== Simulação ========

local function countVisitors(city: CityT): number
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= city.Player then
			local character = other.Character
			local rootPart = character and character.PrimaryPart
			if rootPart and LotLayout.Contains(city.Lot, rootPart.Position) then
				count += 1
			end
		end
	end
	return count
end

local function migrate(from: CityT, leaving: number)
	local best: CityT? = nil
	local bestScore = Config.Happiness.Attractive
	for _, other in cities do
		if other ~= from then
			local room = other.Stats.TargetPopulation - other.Population
			if room > 0 and other.Stats.Happiness >= bestScore then
				best = other
				bestScore = other.Stats.Happiness
			end
		end
	end
	if not best then
		return
	end
	local moving = math.min(leaving, math.floor(best.Stats.TargetPopulation - best.Population))
	if moving <= 0 then
		return
	end
	best.Population += moving
	noticeOnce(from, "moveOut", 45, ("%d moradores infelizes se mudaram para %s (de %s)."):format(moving, cityName(best.Data), best.Player.DisplayName), "erro")
	noticeOnce(best, "moveIn", 45, ("%d moradores vieram de %s porque aqui é melhor!"):format(moving, cityName(from.Data)), "ok")
end

local function step(city: CityT, dt: number)
	local data = city.Data
	city.Visitors = countVisitors(city)
	local stats = compute(city)
	local event = Events.Current()
	local newPop, leaving = CityMath.StepPopulation(city.Population, stats.TargetPopulation, event and event.Growth or 1)
	city.Population = newPop
	if leaving > 0 and stats.Happiness < Config.Happiness.Unhappy then
		migrate(city, leaving)
		noticeOnce(city, "unhappy", 90, "Os moradores estão infelizes e indo embora. Veja as necessidades no painel da Cidade.", "erro")
	end
	stats = compute(city) -- a renda usa a população nova
	data.Population = city.Population
	if city.Population > data.PeakPopulation then
		data.PeakPopulation = city.Population
	end

	local tier = CityMath.TierFor(city.Population)
	if tier.Id > data.TierReached then
		data.TierReached = tier.Id
		Remotes.Notify(city.Player, "Sua cidade virou " .. tier.Name .. "! Prédios novos liberados.", "ok")
		Remotes.Effect(city.Player, "tier", tier.Id)
	end

	local earned = stats.IncomePerSec * dt
	if city.Passes.AutoCollect then
		addCash(city, earned)
	else
		local capacity = vaultCapacity(city)
		if data.Vault < capacity then
			data.Vault = math.min(capacity, data.Vault + earned)
		elseif earned > 0 then
			noticeOnce(city, "vaultFull", 120, "O cofre da Prefeitura está CHEIO! Vá coletar ou aumente o cofre.", "erro")
		end
	end

	Lots.SetWarnings(city.Lot, stats.NoRoad)
	publish(city)
	City.Sync(city.Player)
end

-- ======== Entrar e sair ========

function City.Start(player: Player, profile: any): boolean
	local lot = Lots.Claim(player)
	if not lot then
		player:Kick("Servidor cheio de prefeitos. Tente outro servidor!")
		return false
	end
	local data = profile.Data
	if data.NameA == 0 or data.NameB == 0 then
		data.NameA = math.random(1, #Config.CityNameA)
		data.NameB = math.random(1, #Config.CityNameB)
	end
	data.Expansion = math.clamp(math.floor(tonumber(data.Expansion) or 1), 1, #Config.Expansions)
	data.VaultLevel = math.clamp(math.floor(tonumber(data.VaultLevel) or 1), 1, #Config.Vault.Levels)

	local city: CityT = {
		Player = player,
		Data = data,
		Lot = lot,
		State = Grid.Deserialize(data.Buildings, data.Expansion),
		Population = math.max(0, math.floor(tonumber(data.Population) or 0)),
		Stats = nil :: any,
		Visitors = 0,
		Passes = {},
		Cooldowns = {},
		Notices = {},
	}
	cities[player] = city

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local popValue = Instance.new("IntValue")
	popValue.Name = "População"
	popValue.Parent = leaderstats
	local starValue = Instance.new("IntValue")
	starValue.Name = "Estrelas"
	starValue.Parent = leaderstats
	leaderstats.Parent = player

	Lots.SetExpansion(lot, data.Expansion)
	for _, placed in city.State.Buildings do
		Lots.Render(lot, placed)
	end
	compute(city)
	Lots.SetWarnings(lot, city.Stats.NoRoad)

	-- o cofre encheu enquanto o jogador estava fora
	local last = tonumber(data.LastOnline) or 0
	if last > 0 and city.Stats.IncomePerSec > 0 then
		local away = math.clamp(os.time() - last, 0, Config.Vault.OfflineMaxHours * 3600)
		local capacity = vaultCapacity(city)
		local before = data.Vault
		data.Vault = math.min(capacity, data.Vault + city.Stats.IncomePerSec * away * Config.Vault.OfflineRate)
		local gained = data.Vault - before
		if gained >= 1 then
			task.delay(4, function()
				if player.Parent then
					Remotes.Notify(player, "Enquanto você estava fora, o cofre juntou " .. Format.Money(gained) .. ". Vá coletar na Prefeitura!", "ok")
				end
			end)
		end
	end

	publish(city)
	player:SetAttribute("Lot", lot)
	player:SetAttribute("Loaded", true)
	City.Sync(player)
	if player.Character then
		task.defer(teleport, player, lot)
	end
	return true
end

function City.Stop(player: Player)
	local city = cities[player]
	if not city then
		return
	end
	cities[player] = nil
	Lots.Release(city.Lot)
end

function City.Get(player: Player): CityT?
	return cities[player]
end

function City.SetPass(player: Player, key: string, owned: boolean)
	local city = cities[player]
	if not city then
		return
	end
	city.Passes[key] = owned
	if key == "AutoCollect" and owned and city.Data.Vault > 0 then
		local amount = math.floor(city.Data.Vault)
		city.Data.Vault -= amount
		addCash(city, amount)
	end
	compute(city)
	publish(city)
	City.Sync(player)
end

-- Dinheiro de compras (Products): `minutes` minutos da renda atual, com um mínimo
function City.GrantIncomeMinutes(player: Player, minutes: number, minimum: number): number?
	local city = cities[player]
	if not city then
		return nil
	end
	local amount = math.max(minimum, math.floor(city.Stats.IncomePerSec * 60 * minutes))
	addCash(city, amount)
	Remotes.Effect(player, "collect", amount)
	City.Sync(player)
	return amount
end

function City.Init()
	Data.BeforeSave = function(player, data)
		local city = cities[player]
		if city and city.Data == data then
			data.Buildings = Grid.Serialize(city.State)
			data.Population = math.floor(city.Population)
		end
	end
	Lots.OnVault = function(player, index)
		local city = cities[player]
		if not city then
			return
		end
		if city.Lot ~= index then
			Remotes.Notify(player, "Esse cofre não é seu!", "erro")
			return
		end
		actions.collect(city, nil)
	end
	Remotes.Request.OnServerEvent:Connect(function(player, action, payload)
		local ok, err = pcall(City.HandleRequest, player, action, payload)
		if not ok then
			warn("[City] erro no pedido", action, err)
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.SimInterval)
			local t = os.clock()
			local dt = math.min(t - last, Config.SimInterval * 3)
			last = t
			for _, city in cities do
				local ok, err = pcall(step, city, dt)
				if not ok then
					warn("[City] erro na simulação de", city.Player.Name, err)
				end
			end
		end
	end)
end

return City
