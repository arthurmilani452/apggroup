--[[
	LiveEvents (ModuleScript em ServerScriptService > Game)
	Parte 25 (v11): eventos ao vivo. Nada é punição: quem participa só ganha.
	  • INVASÃO DE MONSTROS a cada 45 min: Grumblobs aparecem no Meadow; BONK neles com o taco
	    (3 pancadas). Quem ajudou a derrubar ganha 2 min da sua renda. Se ninguém derrubar, eles vão embora.
	  • MERCADOR VIAJANTE: chega no começo de cada hora (UTC) e fica 15 min. As ofertas são as mesmas
	    em todos os servidores naquela hora (sorteio pela hora). Cada oferta: 1 compra por jogador por hora.
	  • VOTAÇÃO a cada 20 min: 3 opções, 1 voto por jogador, resultado ao vivo; a vencedora acontece na hora.
	  • META DA COMUNIDADE: todos os servidores somam os ovos chocados (MemoryStore a cada 60 s).
	    Cada meta batida dá um presente para TODO MUNDO (quem entrar depois também ganha).
	  • FESTAS DO CALENDÁRIO (Config.Holidays): ovos de festa na esteira na época certa.
	  • RECORDE DE JOGADORES no servidor (4 ou mais): chuva de ovos!
	  • CRIADOR NO SERVIDOR: aviso para todos e o bichinho exclusivo Crowny de presente (1 vez por jogador).
	O estado fica em atributos do Workspace para as telas lerem.
]]

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Format = require(ReplicatedStorage.Shared.Format)
local Models3D = require(ReplicatedStorage.Shared.Models3D)
local Registry = require(script.Parent.Registry)

local LiveEvents = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function grant(player: Player, reward): string
	local codes = Registry.Codes
	if not codes then
		return ""
	end
	local ok, parts = pcall(codes.Grant, player, reward)
	return if ok and type(parts) == "table" then table.concat(parts, " + ") else ""
end

---------------------------------------------------------------------
-- FESTAS
---------------------------------------------------------------------
local forcedHoliday: string? = nil

local function refreshHoliday()
	local holiday = if forcedHoliday then Config.HolidayById[forcedHoliday] else Config.HolidayAt(os.time())
	local id = if holiday then holiday.Id else nil
	if workspace:GetAttribute("Holiday") ~= id then
		workspace:SetAttribute("Holiday", id)
		if holiday then
			local eggName = "holiday eggs"
			for _, egg in Config.Eggs do
				if egg.Holiday == holiday.Id then
					eggName = egg.Name .. "s"
				end
			end
			Registry.Remotes.NotifyAll(("%s EVENT! %s are on the conveyor!"):format(string.upper(holiday.Name), eggName), "rare")
		end
	end
end

-- Admin: liga uma festa agora (nil = volta ao calendário)
function LiveEvents.ForceHoliday(id: string?)
	forcedHoliday = if id and Config.HolidayById[id] then id else nil
	refreshHoliday()
end

---------------------------------------------------------------------
-- INVASÃO DE MONSTROS
---------------------------------------------------------------------
type Monster = { Model: Model, Root: BasePart, Humanoid: Humanoid, HP: number, MaxHP: number, Hitters: { [Player]: boolean }, Hearts: TextLabel, NextMove: number }
local monsters: { [Model]: Monster } = {}
local invasionFolder: Folder? = nil
local invading = false
local invasionId = 0

local function part(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	if shape then
		p.Shape = shape
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function heartsText(hp: number, max: number): string
	return string.rep("\u{2764}", hp) .. string.rep("\u{2661}", math.max(0, max - hp))
end

local function buildMonster(position: Vector3, hp: number): Monster
	local model = Instance.new("Model")
	model.Name = "Grumblob"
	local root = part("HumanoidRootPart", Vector3.new(3, 3, 3), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.Massless = false
	root.CFrame = CFrame.new(position)
	root.Parent = model
	model.PrimaryPart = root
	local purple = Color3.fromRGB(120 + math.random(0, 60), 60, 170 + math.random(0, 60))
	-- modelo 3D (ReplicatedStorage > Models3D > grumblob), se existir; senão, monta com peças
	local mesh = Models3D.Get("grumblob", { Size = 5.4, Fit = "Height", Anchored = false })
	if mesh then
		mesh:PivotTo(root.CFrame * CFrame.new(0, -3.7, 0)) -- pés no chão (HipHeight 2.2 + meia raiz 1.5)
		for _, d in mesh:GetDescendants() do
			if d:IsA("BasePart") then
				d.Parent = model
				weld(root, d)
			end
		end
		mesh:Destroy()
	end
	local body = part("Body", Vector3.new(4.6, 4, 4.6), purple, Enum.PartType.Ball)
	body.CFrame = root.CFrame
	body.Parent = model
	weld(root, body)
	if mesh then
		body.Transparency = 1 -- fica só como "corpo" invisível
	end
	for side = -1, 1, 2 do
		if mesh then
			break
		end
		local horn = part("Horn", Vector3.new(0.6, 1.6, 0.6), Color3.fromRGB(255, 230, 150))
		horn.CFrame = root.CFrame * CFrame.new(side * 1.2, 2.2, 0) * CFrame.Angles(0, 0, -side * 0.35)
		horn.Parent = model
		weld(root, horn)
		local eye = part("Eye", Vector3.new(1.1, 1.1, 1.1), Color3.new(1, 1, 1), Enum.PartType.Ball)
		eye.CFrame = root.CFrame * CFrame.new(side * 0.8, 0.6, -2)
		eye.Parent = model
		weld(root, eye)
		local pupil = part("Pupil", Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(30, 20, 40), Enum.PartType.Ball)
		pupil.CFrame = root.CFrame * CFrame.new(side * 0.8, 0.55, -2.45)
		pupil.Parent = model
		weld(root, pupil)
	end
	if not mesh then
		local mouth = part("Mouth", Vector3.new(1.8, 0.3, 0.3), Color3.fromRGB(40, 20, 50))
		mouth.CFrame = root.CFrame * CFrame.new(0, -0.6, -2.2)
		mouth.Parent = model
		weld(root, mouth)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- sem pernas: fica de pé pela HipHeight
	humanoid.HipHeight = 2.2
	humanoid.WalkSpeed = 9
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 1.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	local hearts = Instance.new("TextLabel")
	hearts.Size = UDim2.fromScale(1, 1)
	hearts.BackgroundTransparency = 1
	hearts.Font = Enum.Font.FredokaOne
	hearts.TextScaled = true
	hearts.TextColor3 = Color3.fromRGB(255, 90, 120)
	hearts.Text = heartsText(hp, hp)
	hearts.Parent = gui
	gui.Parent = root
	model:AddTag("Monster")
	model.Parent = invasionFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return { Model = model, Root = root, Humanoid = humanoid, HP = hp, MaxHP = hp, Hitters = {}, Hearts = hearts, NextMove = 0 }
end

-- Um lugar para o monstro andar: o tapete dos ovos e os caminhos
local function wanderPoint(): Vector3
	return Vector3.new(math.random(-160, 160), 2, math.random(-22, 22))
end

local function endInvasion(defeated: boolean)
	if not invading then
		return
	end
	invading = false
	workspace:SetAttribute("InvasionUntil", nil)
	for model in monsters do
		model:Destroy()
	end
	table.clear(monsters)
	if defeated then
		Registry.Remotes.NotifyAll("ALL MONSTERS DEFEATED! Great teamwork!", "rare")
		Registry.Remotes.EffectAll("InvasionWon")
	else
		Registry.Remotes.NotifyAll("The Grumblobs ran away... Get them next time!", "info")
	end
end

function LiveEvents.StartInvasion()
	if invading then
		return
	end
	invading = true
	invasionId += 1
	local myId = invasionId
	local settings = Config.Invasion
	local count = math.min(settings.Max, settings.Base + #Players:GetPlayers())
	local hp = settings.Hits + math.floor(#Players:GetPlayers() / 4)
	workspace:SetAttribute("InvasionUntil", now() + settings.Duration)
	Registry.Remotes.NotifyAll("MONSTER INVASION! Grumblobs are in Meadow Valley. BONK them with your bat!", "rare")
	Registry.Remotes.EffectAll("Invasion")
	for _ = 1, count do
		local monster = buildMonster(wanderPoint() + Vector3.new(0, 3, 0), hp)
		monsters[monster.Model] = monster
	end
	task.delay(settings.Duration, function()
		if invasionId == myId then -- uma invasão nova não é encerrada pelo relógio da antiga
			endInvasion(next(monsters) == nil)
		end
	end)
end

-- Chamado pelo Combat quando um taco acerta um monstro
function LiveEvents.HitMonster(model: Model, player: Player)
	local monster = monsters[model]
	if not monster or monster.HP <= 0 then
		return
	end
	monster.HP -= 1
	monster.Hitters[player] = true
	monster.Hearts.Text = heartsText(monster.HP, monster.MaxHP)
	Registry.Remotes.EffectAll("Bonk", monster.Root.Position + Vector3.new(0, 3, 0))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local away = monster.Root.Position - root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		if flat.Magnitude > 0.1 then
			monster.Root.AssemblyLinearVelocity = flat.Unit * 45 + Vector3.new(0, 25, 0)
		end
	end
	if monster.HP > 0 then
		return
	end
	-- derrubado: todo mundo que bateu nele ganha
	local position = monster.Root.Position
	monsters[model] = nil
	model:Destroy()
	Registry.Remotes.EffectAll("HatchBurst", { Position = position, Rarity = "Epic" })
	for hitter in monster.Hitters do
		if hitter.Parent and hitter:GetAttribute("Loaded") then
			local text = grant(hitter, { Minutes = Config.Invasion.RewardMinutes })
			Registry.Remotes.Notify(hitter, "You defeated a Grumblob! +" .. text, "success")
			if Registry.Progress then
				Registry.Progress.Event(hitter, "Monster")
			end
		end
	end
	if next(monsters) == nil then
		endInvasion(true)
	end
end

---------------------------------------------------------------------
-- MERCADOR VIAJANTE
---------------------------------------------------------------------
local stockHour = -1
local stock: { any } = {}

local function merchantHere(time: number): boolean
	return time % 3600 < Config.Merchant.StayMinutes * 60
end

-- Ofertas da hora (mesmas em todo servidor)
function LiveEvents.StockFor(hour: number): { any }
	local random = Random.new(hour * 7919 + 17)
	local offers = {}
	-- 1) um ovo do Meadow e 2) um ovo de outro mundo, com desconto
	local meadow, others = {}, {}
	for _, egg in Config.Eggs do
		if not egg.Condition and not egg.Holiday and not egg.Where and egg.Weight > 0 then
			if egg.World == "meadow" and egg.Tier >= 2 then
				table.insert(meadow, egg)
			elseif egg.World ~= "meadow" then
				table.insert(others, egg)
			end
		end
	end
	for _, list in { meadow, others } do
		if #list > 0 then
			local egg = list[random:NextInteger(1, #list)]
			table.insert(offers, { Kind = "Egg", Id = egg.Id, Price = math.floor(egg.Price * Config.Merchant.Discount) })
		end
	end
	-- 3) um bichinho Gold (Raro ou Épico do Meadow)
	local pool = {}
	for _, def in Critters.List do
		if def.World == "meadow" and not def.RebirthRequired and (def.Rarity == "Rare" or def.Rarity == "Epic") then
			table.insert(pool, def)
		end
	end
	if #pool > 0 then
		local def = pool[random:NextInteger(1, #pool)]
		table.insert(offers, { Kind = "Critter", Id = def.Id, Mutation = "Gold", Price = math.floor(def.Price * Config.PriceMultiplier("Gold") * 1.2) })
	end
	-- 4) 2x Cash por 10 min (custa 5 min da sua renda)
	table.insert(offers, { Kind = "Boost", Minutes = 10, IncomeMinutes = 5 })
	return offers
end

local function refreshMerchant()
	local time = os.time()
	local hour = math.floor(time / 3600)
	local here = merchantHere(time)
	if hour ~= stockHour then
		stockHour = hour
		stock = LiveEvents.StockFor(hour)
		workspace:SetAttribute("MerchantStock", HttpService:JSONEncode(stock))
	end
	local serverOffset = now() - time -- relógio do jogo (GetServerTimeNow) x os.time
	workspace:SetAttribute("MerchantHour", hour)
	workspace:SetAttribute("MerchantLeaves", if here then math.floor(hour * 3600 + Config.Merchant.StayMinutes * 60 + serverOffset + 0.5) else nil)
	workspace:SetAttribute("MerchantArrives", if here then nil else math.floor((hour + 1) * 3600 + serverOffset + 0.5))
	if here ~= workspace:GetAttribute("MerchantHere") then
		workspace:SetAttribute("MerchantHere", here)
		if here then
			Registry.Remotes.NotifyAll("The TRAVELING MERCHANT is here for 15 minutes! Find the stall next to the Hatchery.", "rare")
		end
	end
end

local function nearMerchant(player: Player): boolean
	local map = workspace:FindFirstChild("Map")
	local stall = map and map:FindFirstChild("MerchantStall")
	local counter = stall and stall:FindFirstChild("Counter") :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return counter ~= nil and root ~= nil and (counter.CFrame.Position - root.Position).Magnitude <= 40
end

function LiveEvents.MerchantBuy(player: Player, index: any)
	local data = getData(player)
	if not data or typeof(index) ~= "number" then
		return
	end
	local offer = stock[math.floor(index)]
	if not offer then
		return
	end
	if not merchantHere(os.time()) then
		Registry.Remotes.Notify(player, "The merchant is away. Come back when the stall is open!", "info")
		return
	end
	if not nearMerchant(player) then
		Registry.Remotes.Notify(player, "Go to the merchant's stall next to the Hatchery to buy!", "info")
		return
	end
	if type(data.MerchantBuys) ~= "table" or data.MerchantBuys.Hour ~= stockHour then
		data.MerchantBuys = { Hour = stockHour, Bought = {} }
	end
	local key = tostring(math.floor(index))
	if data.MerchantBuys.Bought[key] then
		Registry.Remotes.Notify(player, "You already bought this! New offers next hour.", "info")
		return
	end
	local Economy = Registry.Economy
	local price = offer.Price
	if offer.Kind == "Boost" then
		price = math.floor(math.max(1000, Economy.GetIncome(player) * 60 * offer.IncomeMinutes))
	end
	if (offer.Kind == "Egg" or offer.Kind == "Critter") and not Registry.CritterService.HasFreeSlot(player) and not Registry.Pets.HasSpace(player, 1) then
		Registry.Remotes.Notify(player, "Your base and backpack are full! Make space first.", "warning")
		return
	end
	if not Economy.TrySpend(player, price, "Merchant") then
		Registry.Remotes.Notify(player, "Not enough cash! You need " .. Format.Money(price), "error")
		return
	end
	data.MerchantBuys.Bought[key] = true
	if offer.Kind == "Egg" then
		Registry.CritterService.GrantEgg(player, offer.Id)
	elseif offer.Kind == "Critter" then
		Registry.CritterService.GrantCritter(player, offer.Id, offer.Mutation)
	elseif offer.Kind == "Boost" then
		Registry.Codes.AddBoost(player, offer.Minutes)
	end
	Registry.Remotes.Notify(player, "Thanks for shopping with the Traveling Merchant!", "success")
	Registry.Remotes.Effect(player, "Purchase", "Rare")
	LiveEvents.SyncMerchant(player)
end

function LiveEvents.SyncMerchant(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local bought = {}
	if type(data.MerchantBuys) == "table" and data.MerchantBuys.Hour == stockHour then
		for key in data.MerchantBuys.Bought do
			table.insert(bought, tonumber(key))
		end
	end
	player:SetAttribute("MerchantBought", table.concat(bought, ","))
	player:SetAttribute("MerchantBoostPrice", math.floor(math.max(1000, Registry.Economy.GetIncome(player) * 60 * 5)))
end

---------------------------------------------------------------------
-- VOTAÇÃO
---------------------------------------------------------------------
local voteOptions: { string } = {}
local votes: { [Player]: number } = {}
local voting = false

local function publishVotes()
	local counts = {}
	for i = 1, #voteOptions do
		counts[i] = 0
	end
	for player, choice in votes do
		if player.Parent and counts[choice] then
			counts[choice] += 1
		end
	end
	workspace:SetAttribute("VoteCounts", table.concat(counts, ","))
	return counts
end

local function runWinner(option: string)
	if option == "Rain" then
		Registry.Events.StartRain()
	elseif option == "Lucky" then
		Registry.Events.StartLucky()
	elseif option == "GiantEgg" and Registry.GiantEgg then
		Registry.GiantEgg.SpawnNow()
	elseif option == "Night" and Registry.Environment then
		Registry.Environment.ForceNight(180)
		Registry.Remotes.NotifyAll("Night falls early... Moon Eggs are on the conveyor!", "rare")
	end
end

function LiveEvents.StartVote()
	if voting then
		return
	end
	voting = true
	table.clear(votes)
	local pool = table.clone(Config.Vote.Options)
	voteOptions = {}
	while #voteOptions < 3 and #pool > 0 do
		table.insert(voteOptions, table.remove(pool, math.random(1, #pool)) :: string)
	end
	workspace:SetAttribute("VoteOptions", table.concat(voteOptions, ","))
	workspace:SetAttribute("VoteUntil", now() + Config.Vote.Duration)
	publishVotes()
	Registry.Remotes.NotifyAll("VOTE for the next event! Tap your choice at the top of the screen.", "info")
	task.delay(Config.Vote.Duration, function()
		voting = false
		local counts = publishVotes()
		local best, bestCount = {}, -1
		for i, count in counts do
			if count > bestCount then
				best, bestCount = { i }, count
			elseif count == bestCount then
				table.insert(best, i)
			end
		end
		local winner = voteOptions[best[math.random(1, #best)]]
		workspace:SetAttribute("VoteUntil", nil)
		workspace:SetAttribute("VoteOptions", nil)
		table.clear(votes)
		if winner then
			Registry.Remotes.NotifyAll(("Vote result: %s! (%d votes)"):format(Config.VoteNames[winner] or winner, math.max(bestCount, 0)), "rare")
			runWinner(winner)
		end
	end)
end

function LiveEvents.Vote(player: Player, choice: any)
	if not voting or typeof(choice) ~= "number" or not voteOptions[math.floor(choice)] then
		return
	end
	if votes[player] then
		Registry.Remotes.Notify(player, "You already voted! 1 vote per player.", "info")
		return
	end
	votes[player] = math.floor(choice)
	publishVotes()
	Registry.Remotes.Notify(player, "Vote counted: " .. (Config.VoteNames[voteOptions[math.floor(choice)]] or ""), "success")
end

---------------------------------------------------------------------
-- META DA COMUNIDADE (todos os servidores)
---------------------------------------------------------------------
local pendingHatches = 0
local globalCount = 0
local goalMap: any? = nil
local goalBackup: DataStore? = nil
local MEMORY_TTL = 40 * 24 * 3600 -- a MemoryStore guarda até 45 dias; o DataStore guarda para sempre

function LiveEvents.AddHatch(amount: number?)
	pendingHatches += amount or 1
end

local function tiersReached(count: number): number
	local reached = 0
	for index, goal in Config.GlobalGoals do
		if count >= goal.Goal then
			reached = index
		end
	end
	return reached
end

local function giveGoalRewards(player: Player)
	local data = getData(player)
	if not data or not player:GetAttribute("Loaded") then
		return
	end
	if type(data.GlobalClaimed) ~= "table" then
		data.GlobalClaimed = {}
	end
	for index = 1, tiersReached(globalCount) do
		local key = tostring(index)
		if not data.GlobalClaimed[key] then
			data.GlobalClaimed[key] = true
			local goal = Config.GlobalGoals[index]
			if goal.Critter then
				Registry.CritterService.GrantCritter(player, goal.Critter, nil)
			end
			if goal.BigEgg then
				grant(player, { BigEgg = goal.BigEgg })
			end
			Registry.Remotes.Notify(player, "COMMUNITY GOAL reward: " .. goal.Name, "rare")
		end
	end
end

-- Admin/teste: soma SÓ neste servidor (não mexe na meta de verdade dos outros servidores)
function LiveEvents.AdminAddLocal(amount: number)
	globalCount += amount
	workspace:SetAttribute("GlobalCount", globalCount)
	workspace:SetAttribute("GlobalTier", tiersReached(globalCount))
	for _, player in Players:GetPlayers() do
		giveGoalRewards(player)
	end
end

local function syncGlobal()
	local delta = pendingHatches
	pendingHatches = 0
	local newCount: number? = nil
	if goalMap then
		local ok, result = pcall(function()
			return (goalMap :: any):UpdateAsync("hatches", function(old)
				return (tonumber(old) or 0) + delta
			end, MEMORY_TTL)
		end)
		if ok and type(result) == "number" then
			newCount = result
		else
			pendingHatches += delta -- não perde: tenta de novo no próximo minuto
		end
	end
	if not newCount then
		newCount = globalCount + (if goalMap then 0 else delta)
	end
	local before = tiersReached(globalCount)
	globalCount = math.max(globalCount, newCount :: number)
	workspace:SetAttribute("GlobalCount", globalCount + pendingHatches) -- mostra também o que ainda não subiu
	local after = tiersReached(globalCount)
	workspace:SetAttribute("GlobalTier", after)
	if after > before then
		for index = before + 1, after do
			Registry.Remotes.NotifyAll("COMMUNITY GOAL REACHED: " .. Config.GlobalGoals[index].Name, "rare")
		end
		Registry.Remotes.EffectAll("GoalReached")
	end
	for _, player in Players:GetPlayers() do
		giveGoalRewards(player) -- não dá duas vezes (GlobalClaimed)
	end
end

local function loadGlobal()
	-- começa pelo que está salvo para sempre; a MemoryStore pode ter "esquecido" (45 dias)
	if goalBackup then
		local ok, saved = pcall(function()
			return (goalBackup :: DataStore):GetAsync("hatches")
		end)
		if ok and type(saved) == "number" then
			globalCount = saved
		end
	end
	if goalMap then
		pcall(function()
			(goalMap :: any):UpdateAsync("hatches", function(old)
				return math.max(tonumber(old) or 0, globalCount)
			end, MEMORY_TTL)
		end)
	end
	workspace:SetAttribute("GlobalCount", globalCount)
	workspace:SetAttribute("GlobalTier", tiersReached(globalCount))
	for _, player in Players:GetPlayers() do
		giveGoalRewards(player) -- quem já estava aqui também recebe metas antigas
	end
end

local function backupGlobal()
	if not goalBackup or RunService:IsStudio() or math.random() > 0.3 then
		return -- poucos servidores salvam por vez (limite do DataStore por chave)
	end
	local value = globalCount
	pcall(function()
		(goalBackup :: DataStore):UpdateAsync("hatches", function(old)
			return math.max(tonumber(old) or 0, value)
		end)
	end)
end

---------------------------------------------------------------------
-- RECORDE DE JOGADORES E VISITA DO CRIADOR
---------------------------------------------------------------------
local serverRecord = 0
local lastRecordRain = -math.huge
local creatorHere = false

local function isCreator(player: Player): boolean
	if Config.CreatorUserIds and Config.CreatorUserIds[player.UserId] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId ~= 0 and player.UserId == game.CreatorId
end

local function giveCreatorGift(player: Player)
	local data = getData(player)
	if not data or data.CreatorGift or not player:GetAttribute("Loaded") then
		return
	end
	data.CreatorGift = true
	Registry.CritterService.GrantCritter(player, "crowny", nil)
	Registry.Remotes.Notify(player, "The creator is here! You got the exclusive critter CROWNY!", "rare")
end

function LiveEvents.CreatorArrived(player: Player?)
	creatorHere = true
	workspace:SetAttribute("CreatorHere", true)
	Registry.Remotes.NotifyAll(("\u{1F451} The CREATOR of Steal a Critter%s is in this server! Everyone gets a gift!"):format(if player then " (" .. player.DisplayName .. ")" else ""), "rare")
	Registry.Remotes.EffectAll("GoalReached")
	for _, other in Players:GetPlayers() do
		giveCreatorGift(other)
	end
end

local function checkRecord()
	local count = #Players:GetPlayers()
	if count > serverRecord then
		serverRecord = count
		if count >= Config.RecordRainMin and os.clock() - lastRecordRain > 600 then
			lastRecordRain = os.clock()
			Registry.Remotes.NotifyAll(("SERVER RECORD: %d players! Here comes an EGG RAIN!"):format(count), "rare")
			Registry.Events.StartRain()
		end
	end
end

---------------------------------------------------------------------
function LiveEvents.SetupPlayer(player: Player)
	giveGoalRewards(player)
	if creatorHere then
		giveCreatorGift(player)
	end
	if isCreator(player) then
		LiveEvents.CreatorArrived(player)
	end
	LiveEvents.SyncMerchant(player)
	checkRecord()
end

function LiveEvents.RemovePlayer(player: Player)
	votes[player] = nil
	if isCreator(player) then
		local still = false
		for _, other in Players:GetPlayers() do
			if other ~= player and isCreator(other) then
				still = true
			end
		end
		creatorHere = still
		workspace:SetAttribute("CreatorHere", if still then true else nil)
	end
end

function LiveEvents.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace
	invasionFolder = folder
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap("GlobalGoal_v1")
	end)
	goalMap = if ok then map else nil
	local ok2, store = pcall(function()
		return DataStoreService:GetDataStore("GlobalGoal_v1")
	end)
	goalBackup = if ok2 then store else nil
	Players.PlayerRemoving:Connect(LiveEvents.RemovePlayer)

	local start = now()
	if Config.Invasion.Enabled ~= false then -- v25: sem relógio = sem invasão automática
		workspace:SetAttribute("NextInvasion", start + Config.Invasion.FirstAfter)
	end
	workspace:SetAttribute("NextVote", start + Config.Vote.FirstAfter)
	refreshHoliday()
	refreshMerchant()
	task.spawn(loadGlobal)

	-- relógio dos eventos (1 vez por segundo)
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				ticks += 1
				local t = now()
				local nextInvasion = workspace:GetAttribute("NextInvasion")
				if typeof(nextInvasion) == "number" and t >= nextInvasion then
					workspace:SetAttribute("NextInvasion", nextInvasion + Config.Invasion.Every)
					LiveEvents.StartInvasion()
				end
				local nextVote = workspace:GetAttribute("NextVote")
				if typeof(nextVote) == "number" and t >= nextVote then
					workspace:SetAttribute("NextVote", nextVote + Config.Vote.Every)
					LiveEvents.StartVote()
				end
				refreshMerchant()
				if ticks % 60 == 0 then
					refreshHoliday()
					task.spawn(syncGlobal)
					for _, player in Players:GetPlayers() do
						LiveEvents.SyncMerchant(player)
					end
				end
				if ticks % 600 == 0 then
					task.spawn(backupGlobal)
				end
			end)
			if not ok then
				warn("[LiveEvents] loop error:", err)
			end
		end
	end)

	-- monstros andando por aí
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(function()
				local clock = os.clock()
				for model, monster in monsters do
					if not model.Parent then
						monsters[model] = nil
					elseif clock >= monster.NextMove then
						monster.NextMove = clock + 2 + math.random() * 2
						monster.Humanoid:MoveTo(wanderPoint())
					end
				end
			end)
			if not ok then
				warn("[LiveEvents] loop error:", err)
			end
		end
	end)
	CollectionService:GetInstanceRemovedSignal("Monster"):Connect(function(instance)
		monsters[instance :: Model] = nil
	end)
end

return LiveEvents
