--[[
	Game: acesso aos dados do jogador, o "contexto" das contas (passes, evento, amigos) e o estado
	que vai para a tela. Todo lugar que muda os dados de alguém chama Game.Push(player) no final.
	Só o SERVIDOR mexe em moedas: o cliente nunca manda valores, só pede ações.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Sim = require(ReplicatedStorage.Shared.Sim)
local Registry = require(script.Parent.Registry)

local Game = {}

local dirtyFull: { [Player]: boolean } = {}
local dirtyTick: { [Player]: boolean } = {}
local dirtySoon: { [Player]: boolean } = {} -- estado completo "sem pressa" (vai junto no próximo segundo)
local owned: { [Player]: { [string]: boolean } } = {} -- game passes desta sessão
local friends: { [Player]: number } = {} -- bônus de amigos (0..1)
local inGroup: { [Player]: boolean } = {}
local policy: { [Player]: any } = {} -- regras do Roblox para o jogador (PolicyService; quem preenche é o Store)

Game.EventSpeed = 1 -- Chuva de Milho muda isto (todos os negócios mais rápidos)
Game.HuntTotal = 0

function Game.Data(player: Player): any?
	if player:GetAttribute("Loaded") ~= true then
		return nil
	end
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

function Game.Owned(player: Player): { [string]: boolean }
	local t = owned[player]
	if not t then
		t = {}
		owned[player] = t
	end
	return t
end

function Game.Ctx(player: Player): any
	return {
		Now = os.time(),
		Owned = owned[player],
		EventSpeed = Game.EventSpeed,
		-- clima do servidor (id): entra no pagamento dos negócios (Sim.Payout) e no relógio dos ovos raros.
		-- O contexto neutro (Sim.BaseCtx) não leva este campo: prêmios e renda offline ignoram o clima.
		Weather = if Registry.Weather then Registry.Weather.Current else nil,
		Friends = friends[player] or 0,
		Group = inGroup[player] == true,
		Premium = player.MembershipType == Enum.MembershipType.Premium, -- v6: +10% (Config.PremiumBonus)
		NoRandom = policy[player] ~= nil and policy[player].NoRandom == true, -- sem prêmio sorteado ligado a compra
	}
end

-- Regras do Roblox para este jogador (o Store consulta o PolicyService ao entrar). info = { NoRandom = boolean }
function Game.SetPolicy(player: Player, info: any)
	policy[player] = info
	Game.Push(player)
end

function Game.HasPass(player: Player, key: string): boolean
	local data = Game.Data(player)
	return data ~= nil and Sim.HasPass(data, Game.Ctx(player), key)
end

function Game.SetupPlayer(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Moedas"
	coins.Value = "0"
	coins.Parent = stats
	local stars = Instance.new("NumberValue")
	stars.Name = "Estrelas"
	stars.Parent = stats
	stats.Parent = player
end

-- Prêmio em "segundos de renda" entregue na hora (missão, evento, encomenda...). Devolve o valor.
function Game.Reward(player: Player, seconds: number, minimum: number?, earned: boolean?): number
	local data = Game.Data(player)
	if not data then
		return 0
	end
	local amount = Sim.Reward(Config, data, Game.Ctx(player), seconds, minimum)
	Sim.AddCoins(data, amount, earned == true)
	Game.Push(player)
	return amount
end

function Game.ApplySpeed(player: Player)
	local data = Game.Data(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = Sim.WalkSpeed(Config, data, Game.Ctx(player))
	end
end

-- Amigos e grupo (chamadas de internet: sempre com pcall, fora do caminho principal)
function Game.RefreshSocial(player: Player)
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and isFriend then
				count += 1
			end
		end
	end
	if not player.Parent then
		return
	end
	local bonus = math.min(Config.FriendBonusMax, count * Config.FriendBonus)
	if friends[player] ~= bonus then
		friends[player] = bonus
		Game.Push(player)
	end
	if Config.GroupId > 0 and inGroup[player] == nil then
		local ok, member = pcall(function()
			return player:IsInGroup(Config.GroupId)
		end)
		inGroup[player] = ok and member == true
		Game.Push(player)
	end
end

function Game.Push(player: Player)
	dirtyFull[player] = true
end

function Game.PushTick(player: Player)
	dirtyTick[player] = true
end

-- Estado completo sem pressa: para o que muda a cada clique/ciclo mas só aparece em painel (missões,
-- contadores). Junta tudo e manda no máximo uma vez por segundo, em vez de um estado inteiro por clique.
function Game.PushSoon(player: Player)
	dirtySoon[player] = true
end

-- Moedas no chão de cada negócio: sempre uma lista cheia (1..8), 0 onde não tem nada
local function groundList(plot: any): { number }
	local list = {}
	for index in Config.Businesses do
		list[index] = (plot and plot.Run.Ground[index]) or 0
	end
	return list
end

-- Ovos raros esperando nos ninhos (cópia: a lista do run muda enquanto o estado viaja)
local function rareList(plot: any): { any }
	local list = {}
	if plot then
		for i, egg in plot.Run.Rare do
			list[i] = { Line = egg.Line, Slot = egg.Slot, Mut = egg.Mut }
		end
	end
	return list
end

-- Saco de dinheiro no chão do terreno: { Until = hora do servidor em que some, Golden, Spot } ou false
-- (false, não nil: campo nil não viaja, e a tela precisa saber quando o saco saiu)
local function bagInfo(plot: any): any
	local bag = plot and plot.Run.Bag
	if not bag then
		return false
	end
	return { Until = bag.Until or 0, Golden = bag.Golden == true, Spot = bag.Spot }
end

-- Poderes (versão 5): lista na ordem do Config de { Id, Unlocked, ReadyAt, Until }. ReadyAt / Until na
-- hora do servidor (a mesma base dos Boosts: o cliente compara com workspace:GetServerTimeNow());
-- 0 = pronto agora / sem efeito ligado.
local function powerList(data: any, ctx: any, now: number, serverNow: number): { any }
	local list = {}
	for index, def in Config.Powers or {} do
		local info = Sim.PowerInfo(Config, data, ctx, def.Id)
		list[index] = {
			Id = def.Id,
			Unlocked = info.Unlocked,
			ReadyAt = if info.ReadyAt > now then serverNow + (info.ReadyAt - now) else 0,
			Until = if info.Until > now then serverNow + (info.Until - now) else 0,
		}
	end
	return list
end

-- Só o que muda o tempo todo (vai em Remotes.Tick a cada produção)
local function tickSnapshot(player: Player, data: any): any
	local plot = Registry.Plots.Of(player)
	local ctx = Game.Ctx(player)
	local auto, all = Sim.Income(Config, data, ctx)
	return {
		Coins = data.Coins,
		RunEarned = data.RunEarned,
		Auto = auto,
		All = all,
		BasketCount = Sim.BasketCount(data),
		Apples = if plot then plot.Run.Apples else 0,
		GiftLeft = math.max(0, Config.GiftInterval - data.GiftSeconds),
		Mutant = Sim.BestMutantInBasket(Config, data),
		Ground = groundList(plot),
		Tips = if plot then plot.Run.Tips or 0 else 0,
		Rare = rareList(plot),
		Bag = bagInfo(plot),
		-- chaves secretas e Baú Secreto: chaves na mão, quantas abrem o baú, se há uma chave escondida no
		-- terreno agora (true/false, nunca nil: campo nil não viaja) e baús abertos na vida
		Keys = Sim.KeyCount(Config, data),
		KeyNeed = if Config.Keys then Config.Keys.Need else 0,
		Key = plot ~= nil and plot.Run.Key ~= nil,
		Chests = data.Stats.Chests or 0,
	}
end

local function snapshot(player: Player, data: any): any
	local now = os.time()
	local serverNow = workspace:GetServerTimeNow()
	local ctx = Game.Ctx(player)
	local plot = Registry.Plots.Of(player)
	local state = tickSnapshot(player, data)
	local cash, parts = Sim.CashMult(Config, data, ctx)
	local speed = Sim.SpeedMult(Config, data, ctx)
	-- negócios: o que o jogador tem de cada um e quanto rende (Payout = um ciclo com gerente)
	local biz = {}
	for index in Config.Businesses do
		local info = Sim.BizInfo(Config, data, index)
		biz[index] = {
			Unlocked = info.Unlocked,
			Manager = info.Manager,
			Cash = info.Cash,
			Speed = info.Speed,
			Payout = Sim.Payout(Config, data, ctx, index, info, cash),
			Cycle = Sim.CycleTime(Config, data, ctx, index, info, speed),
			Income = Sim.BizIncome(Config, data, ctx, index, info, cash, speed),
			Weather = Sim.WeatherMult(Config, ctx, index), -- o que o clima multiplica aqui agora (1 = nada); Payout e Income já vêm com ele
			Ground = state.Ground[index],
		}
	end
	state.Biz = biz
	state.BizCount = Sim.BizCount(Config, data)
	state.Birds = Sim.BirdCount(Config, data)
	state.Worked = data.Stats.Worked or 0
	state.Bags = data.Stats.Bags or 0 -- sacos de dinheiro pegos na vida
	-- clima do servidor: { Id, Until = hora do servidor em que acaba, Next = id do próximo }
	state.Weather = if Registry.Weather then Registry.Weather.Info() else { Id = "limpo", Until = 0, Next = "limpo" }
	state.Powers = powerList(data, ctx, now, serverNow)
	state.KeysFound = data.Stats.Keys or 0 -- chaves achadas na vida (a dica "procure a chave" some depois de algumas)
	local boosts = {}
	for key, ends in data.Boosts do
		if ends > now then
			boosts[key] = serverNow + (ends - now)
		end
	end
	local passes = {}
	for _, pass in Config.GamePasses do
		passes[pass.Key] = Sim.HasPass(data, ctx, pass.Key)
	end
	local talents = {}
	for _, talent in Config.Talents do
		talents[talent.Id] = Sim.TalentLevel(Config, data, ctx, talent.Id)
	end
	local canStreak, streakDay = Sim.StreakState(data, now)
	local nextSeal = Sim.NextSeal(Config, data)
	local nextButton = Sim.NextButton(Config, data)
	state.Owned = data.Owned
	state.Basket = data.Basket
	state.BasketCap = Sim.BasketCap(Config, data, ctx)
	state.Stars = data.Stars
	state.StarsTotal = data.StarsTotal
	state.StarsGain = Sim.StarsFor(Config, data)
	state.CanRebirth = Sim.CanRebirth(Config, data)
	state.Rebirths = data.Rebirths
	state.Seal = data.Seal
	state.CanEvolve = Sim.CanEvolve(Config, data)
	state.NextSealStars = if nextSeal then nextSeal.Stars else 0
	state.Talents = talents
	state.TalentsBought = data.Talents
	state.Album = data.Album
	state.Cash = cash
	state.CashParts = parts
	state.Speed = speed
	state.Hand = Sim.HandMult(Config, data, ctx)
	state.Luck = Sim.MutationChanceMult(Config, data, ctx)
	state.Passes = passes
	state.Boosts = boosts
	-- loja: compras únicas já feitas, quanto cada produto de moedas daria AGORA (a loja mostra o número
	-- exato antes da compra) e se o giro diário do VIP vira presente fixo para este jogador
	local productCoins = {}
	for _, product in Config.Products do
		if product.Kind ~= "boost" and (product.Seconds or 0) > 0 then
			productCoins[product.Key] = Sim.Reward(Config, data, ctx, product.Seconds, product.Min)
		end
	end
	state.Bought = data.Bought or {}
	state.ProductCoins = productCoins
	state.NoRandom = ctx.NoRandom == true
	state.Daily = data.Daily.List
	state.MissionReward = Sim.Reward(Config, data, ctx, Config.MissionSeconds, Config.MissionMin)
	state.GiftReward = Sim.Reward(Config, data, ctx, Config.GiftSeconds, Config.GiftMin)
	state.StreakCan = canStreak
	state.StreakDay = streakDay
	state.Hunt = Sim.HuntCount(data)
	state.HuntFound = data.Hunt
	state.HuntTotal = Game.HuntTotal
	state.Likes = data.Likes
	state.TotalEarned = data.TotalEarned
	state.OfflinePending = data.OfflinePending
	state.OfflineSeconds = data.OfflineSeconds
	state.Next = if nextButton then nextButton.Id else nil
	state.Plot = if plot then plot.Index else 0
	state.Friends = friends[player] or 0
	state.EventSpeed = Game.EventSpeed
	state.Settings = data.Settings
	state.Buttons = data.Stats.Buttons
	-- pets e chocadeiras
	local hatch = {}
	for slot, item in data.Hatch do
		hatch[slot] = { Key = item.Key, ReadyAt = serverNow + (item.Ready - now), Ready = now >= item.Ready }
	end
	state.Pets = data.Pets
	state.Equip = data.Equip
	state.PetSlots = Sim.PetSlots(Config, data, ctx)
	state.NextPetSlotAt = Sim.NextPetSlotAt(Config, data)
	state.Hatch = hatch
	state.HatchSlots = Sim.HatchSlots(Config, data)
	state.HatchFree = Sim.FreeHatchSlot(Config, data) ~= nil
	state.Hatched = data.Stats.Hatched or 0
	-- roleta, obby e Ovo Gigante
	local spins, spinWait = Sim.SpinState(Config, data, now)
	state.Spins = spins
	state.SpinFreeAt = serverNow + spinWait
	state.ObbyAt = serverNow + math.max(0, (tonumber(data.ObbyAt) or 0) - now)
	state.GiantPity = data.GiantPity or 0
	-- os pets equipados aparecem para todo mundo (o cliente de cada um desenha)
	local equipped = {}
	for i, key in data.Equip do
		if i <= state.PetSlots then
			table.insert(equipped, key .. "=" .. Sim.PetLevel(Config, data, key))
		end
	end
	local petText = table.concat(equipped, ",")
	if player:GetAttribute("Pets") ~= petText then
		player:SetAttribute("Pets", petText)
	end
	return state
end

function Game.Init()
	task.spawn(function()
		local rounds = 0
		while true do
			task.wait(0.2)
			rounds += 1
			if rounds % 5 == 0 then
				for player in dirtySoon do
					dirtySoon[player] = nil
					dirtyFull[player] = true
				end
			end
			for player in dirtyFull do
				dirtyFull[player] = nil
				dirtyTick[player] = nil
				local data = Game.Data(player)
				if data and player.Parent then
					local ok, err = pcall(function()
						local stats = player:FindFirstChild("leaderstats")
						if stats then
							local coins = stats:FindFirstChild("Moedas") :: StringValue
							local stars = stats:FindFirstChild("Estrelas") :: NumberValue
							coins.Value = Format.Short(data.Coins)
							stars.Value = math.floor(data.StarsTotal)
						end
						Registry.Remotes.State:FireClient(player, snapshot(player, data))
					end)
					if not ok then
						warn("[Game] push falhou:", err)
					end
				end
			end
			for player in dirtyTick do
				dirtyTick[player] = nil
				local data = Game.Data(player)
				if data and player.Parent then
					local ok, err = pcall(function()
						local stats = player:FindFirstChild("leaderstats")
						local coins = stats and stats:FindFirstChild("Moedas") :: StringValue
						if coins then
							coins.Value = Format.Short(data.Coins)
						end
						Registry.Remotes.Tick:FireClient(player, tickSnapshot(player, data))
					end)
					if not ok then
						warn("[Game] tick falhou:", err)
					end
				end
			end
		end
	end)
	-- amigos: confere quando alguém entra/sai e de tempos em tempos
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if Game.Data(player) then
					Game.RefreshSocial(player)
				end
			end
			task.wait(45)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirtyFull[player] = nil
		dirtyTick[player] = nil
		dirtySoon[player] = nil
		owned[player] = nil
		friends[player] = nil
		inGroup[player] = nil
		policy[player] = nil
	end)
end

return Game
