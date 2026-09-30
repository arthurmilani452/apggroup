--[[
	CritterService (ModuleScript em ServerScriptService > Game)
	Tudo sobre OVOS e BICHINHOS:
	  • cada mundo tem a sua esteira de ovos (as esteiras dos mundos vazios ficam paradas, para economizar)
	  • comprar -> o ovo vai para a base (de outro mundo ele é teletransportado) -> choca com suspense -> vira bichinho
	  • o resultado do ovo é sorteado NA COMPRA e fica guardado (sair do jogo não troca o resultado)
	  • roubar (ovo chocando ou bichinho) carregando nas costas, vender, devolver
	  • Chuva de Ovos grátis, ovos/bichinhos ganhos por código ou comprados com Robux
	Tudo é decidido aqui no servidor; o jogador só aperta os botões.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Builder = require(ReplicatedStorage.Shared.CritterBuilder)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local CritterService = {}
CritterService.ShinyNext = false -- admin: o próximo sorteio sai shiny

local folder: Folder
-- Uma "lane" por mundo: { World, StartX, EndX, Y, Z, List = ovos na esteira, Filled, Active }
local lanes: { [string]: any } = {}
local fillLaneFn: ((any) -> ())? = nil
local rainList = {}
local incubating: { [any]: boolean } = {}
local carrying: { [Player]: any } = {}
local nextUid = 0


local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 90)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 230, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255)),
})

local onBuy, onSteal, onSell, onCatch, onPickUp, onPet

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function track(name: string, ...)
	local analytics = Registry.Analytics
	if analytics and analytics[name] then
		pcall(analytics[name], ...)
	end
end

-- Avisa a mochila (tela "Critters") que a base desse jogador mudou
local function markDirty(player: Player?)
	local pets = Registry.Pets
	if pets and player then
		pets.MarkDirty(player)
	end
end

---------------------------------------------------------------------
-- Números de cada ovo / bichinho
---------------------------------------------------------------------
local function rarityIndex(def): number
	return Config.RarityIndex[def.Rarity] or 1
end

local function isEgg(rec): boolean
	return rec.Kind == "Egg"
end

-- Estágio de crescimento (bebê, adulto, gigante) pela idade do bichinho
local function stageOf(rec)
	return Config.GrowthStage(os.time() - (rec.Born or 0))
end

-- Carinho e comida: só bônus (nunca castigo)
local function careMultiplier(rec): number
	local now = os.clock()
	local multiplier = 1
	if (rec.HappyUntil or 0) > now then
		multiplier += Config.PetHappyBonus
	end
	if (rec.FedUntil or 0) > now then
		multiplier += Config.FeedBonus
	end
	return multiplier
end

local function recIncome(rec): number
	if isEgg(rec) then
		return 0
	end
	local _, stage = stageOf(rec)
	return rec.Def.Income * Config.IncomeMultiplier(rec.Mutation) * stage.Income * (if rec.Shiny then Config.ShinyIncome else 1) * careMultiplier(rec)
end

local function recPrice(rec): number
	if isEgg(rec) then
		return rec.EggDef.Price
	end
	return math.floor(rec.Def.Price * Config.PriceMultiplier(rec.Mutation) * (if rec.Shiny then Config.ShinyIncome else 1))
end

-- Valor médio de venda do que sai de um ovo (sem revelar o resultado)
local eggSellCache: { [string]: number } = {}
local function eggAverageSell(egg): number
	local cached = eggSellCache[egg.Id]
	if cached then
		return cached
	end
	local mutationPrice = 1
	for _, mutation in Config.Mutations do
		mutationPrice += mutation.Chance / 100 * (mutation.Price - 1)
	end
	local total, value = 0, 0
	for _, chance in egg.Odds do
		total += chance
	end
	for rarity, chance in egg.Odds do
		local pool = (Critters.ByWorld[egg.Pool or egg.World] or {})[rarity] or {}
		if #pool > 0 then
			local sum = 0
			for _, def in pool do
				sum += def.Price
			end
			value += chance / total * sum / #pool
		end
	end
	local result = math.floor(value * mutationPrice * Config.CritterSellRefund)
	eggSellCache[egg.Id] = result
	return result
end

local function sellPrice(rec): number
	if isEgg(rec) then
		-- quem comprou o ovo recebe metade do preço de volta; ovo roubado ou grátis vale o
		-- bichinho médio daquele ovo (senão dava para roubar ovo caro e vender)
		local average = eggAverageSell(rec.EggDef)
		if rec.Buyer ~= nil and rec.Buyer == rec.Owner then
			return math.max(math.floor(rec.EggDef.Price * Config.SellRefund), average)
		end
		return math.min(average, math.floor(rec.EggDef.Price * Config.SellRefund))
	end
	return math.floor(recPrice(rec) * Config.CritterSellRefund)
end

local function displayName(rec): string
	if isEgg(rec) then
		return rec.EggDef.Name
	end
	return (if rec.Shiny then "Shiny " else "") .. (if rec.Mutation then rec.Mutation .. " " else "") .. rec.Def.Name
end

local function isSpecial(rec): boolean
	if isEgg(rec) then
		return rec.EggDef.Announce == true
	end
	return rarityIndex(rec.Def) >= Config.AnnounceFromRarity or rec.Mutation == "Diamond" or rec.Mutation == "Rainbow" or rec.Shiny == true
end

-- Clima/noite do servidor (Environment); sem ele (testes) nada especial acontece
local function conditionActive(condition: string?): boolean
	if not condition then
		return true
	end
	local environment = Registry.Environment
	return environment ~= nil and environment.IsActive(condition)
end

local function closeEnough(player: Player, position: Vector3, range: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - position).Magnitude <= range
end

---------------------------------------------------------------------
-- Sorteios
---------------------------------------------------------------------
local function isLucky(): boolean
	local luckyUntil = workspace:GetAttribute("LuckyUntil")
	return typeof(luckyUntil) == "number" and luckyUntil > serverNow()
end

function CritterService.RollMutation(boost: number?): string?
	local roll = math.random() * 100
	local accumulated = 0
	for _, mutation in Config.Mutations do
		accumulated += mutation.Chance * (boost or 1)
		if roll < accumulated then
			return mutation.Name
		end
	end
	return nil
end

local function rollEggRarity(egg): string
	local total = 0
	for _, chance in egg.Odds do
		total += chance
	end
	local roll = math.random() * total
	local last = nil
	for _, rarity in Config.Rarities do
		local chance = egg.Odds[rarity.Name]
		if chance and chance > 0 then
			last = rarity.Name
			roll -= chance
			if roll <= 0 then
				return rarity.Name
			end
		end
	end
	return last or Config.Rarities[1].Name
end

-- O que vai sair do ovo (decidido na hora da compra; fica guardado até chocar)
function CritterService.RollResult(egg, player: Player?, boost: number?)
	local rarity = rollEggRarity(egg)
	local rebirths = if player then Registry.Economy.GetPeakRebirths(player) else 0
	local world = Critters.ByWorld[egg.Pool or egg.World or "meadow"] or {}
	local options = {}
	for _, def in world[rarity] or {} do
		if not def.RebirthRequired or def.RebirthRequired <= rebirths then
			table.insert(options, def)
		end
	end
	if egg.Pool == "weekly" then
		-- v26: o Weekly Egg choca SÓ o critter desta semana (a raridade é a dele)
		local weeklyDef = require(ReplicatedStorage.Shared.Weekly).Current()
		if weeklyDef then
			options = { weeklyDef }
		end
	end
	if #options == 0 then
		options = Critters.ByWorld.meadow[Config.Rarities[1].Name]
	end
	local def = options[math.random(1, #options)]
	local mutationBoost = (boost or 1) * (if isLucky() then Config.LuckyMutationMultiplier else 1)
	local progress = Registry.Progress
	if player and progress then
		mutationBoost *= progress.LuckMultiplier(player) -- habilidade Luck
	end
	local shiny = CritterService.ShinyNext or math.random() < Config.ShinyChance
	CritterService.ShinyNext = false
	return { Id = def.Id, Mutation = CritterService.RollMutation(mutationBoost), Shiny = if shiny then true else nil }
end

-- Bichinho de uma raridade do mundo mais alto que o jogador já liberou (Ovo Gigante)
function CritterService.RollFromOdds(player: Player, odds: { [string]: number })
	local total = 0
	for _, weight in odds do
		total += weight
	end
	local roll = math.random() * total
	local rarity = Config.Rarities[1].Name
	for _, info in Config.Rarities do
		local weight = odds[info.Name]
		if weight then
			roll -= weight
			rarity = info.Name
			if roll <= 0 then
				break
			end
		end
	end
	local worlds = Registry.Worlds
	local rebirths = Registry.Economy.GetPeakRebirths(player)
	local worldId = "meadow"
	for _, world in Config.Worlds do
		if worlds and worlds.IsUnlocked(player, world.Id) then
			worldId = world.Id
		end
	end
	-- se o mundo não tem essa raridade, desce uma raridade por vez
	local index = Config.RarityIndex[rarity] or 1
	for tier = index, 1, -1 do
		local options = {}
		for _, def in (Critters.ByWorld[worldId] or {})[Config.Rarities[tier].Name] or {} do
			if not def.RebirthRequired or def.RebirthRequired <= rebirths then
				table.insert(options, def)
			end
		end
		if #options > 0 then
			local shiny = CritterService.ShinyNext or math.random() < Config.ShinyChance
			CritterService.ShinyNext = false
			return options[math.random(1, #options)], shiny
		end
	end
	return CritterService.RandomDef(Config.Rarities[1].Name), false
end

-- Sorteia o próximo ovo da esteira de um mundo (Evento da Sorte: ovos raros 3x mais)
function CritterService.RandomEgg(worldId: string?)
	local world = worldId or "meadow"
	local eggs = Config.EggsOfWorld(world)
	local lucky = isLucky()
	local luckyTier = if world == "meadow" then 3 else 4
	local total = 0
	local weights = {}
	for index, egg in eggs do
		local weight = egg.Weight
		if lucky and egg.Tier >= luckyTier then
			weight *= Config.LuckyEggMultiplier
		end
		if egg.Condition and not conditionActive(egg.Condition) then
			weight = 0 -- ovo de chuva/neve/noite só aparece nesse clima
		end
		if egg.Holiday and workspace:GetAttribute("Holiday") ~= egg.Holiday then
			weight = 0 -- ovo de festa só na época da festa (LiveEvents)
		end
		weights[index] = weight
		total += weight
	end
	local roll = math.random() * total
	for index, egg in eggs do
		roll -= weights[index]
		if roll <= 0 then
			return egg
		end
	end
	return eggs[1] or Config.Eggs[1]
end

-- Bichinho aleatório do Meadow (admin/testes)
function CritterService.RandomDef(rarityName: string)
	local bucket = {}
	for _, def in Critters.ByWorld.meadow[rarityName] or {} do
		if not def.RebirthRequired then
			table.insert(bucket, def)
		end
	end
	if #bucket == 0 then
		bucket = Critters.ByWorld.meadow[Config.Rarities[1].Name]
	end
	return bucket[math.random(1, #bucket)]
end

local function validResult(result: any)
	if type(result) == "table" and type(result.Id) == "string" and Critters.ById[result.Id] then
		local mutation = if type(result.Mutation) == "string" and Config.MutationByName[result.Mutation] then result.Mutation else nil
		return { Id = result.Id, Mutation = mutation, Shiny = if result.Shiny == true then true else nil }
	end
	return nil
end

---------------------------------------------------------------------
-- Placa em cima (mutação, nome, raridade/chance, preço/renda/contagem)
---------------------------------------------------------------------
local function makeInfo(rec)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Adornee = rec.Root
	local hasMutation = not isEgg(rec) and (rec.Mutation ~= nil or rec.Shiny == true)
	gui.Size = UDim2.new(7, 0, if hasMutation then 3.4 else 2.7, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, rec.Top * (rec.Scale or 1) + 2.1, 0)
	rec.Info = gui
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Parent = rec.Root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local total = if hasMutation then 1.26 else 1
	local function line(name: string, order: number, height: number, color: Color3, text: string): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.LayoutOrder = order
		label.Size = UDim2.fromScale(1, height / total)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(15, 15, 25)
		stroke.Parent = label
		label.Parent = gui
		return label
	end

	if isEgg(rec) then
		local bestName, bestChance = Config.EggBest(rec.EggDef)
		rec.NameLabel = line("NameLine", 1, 0.36, Color3.fromRGB(255, 255, 255), rec.EggDef.Name)
		rec.RarityLabel = line("RarityLine", 2, 0.3, Config.RarityByName[bestName].Color, ("Best: %s %g%%"):format(string.upper(bestName), bestChance))
		if Config.RarityIndex[bestName] >= 6 then
			local gradient = Instance.new("UIGradient")
			gradient.Color = RAINBOW
			gradient.Parent = rec.RarityLabel
		end
	else
		local def = rec.Def
		local rarity = Config.RarityByName[def.Rarity]
		if hasMutation then
			local info = rec.Mutation and Config.MutationByName[rec.Mutation]
			local text = if info then string.upper(rec.Mutation) .. " x" .. info.Income else ""
			if rec.Shiny then
				text = "SHINY" .. (if text ~= "" then " " .. text else " x" .. Config.ShinyIncome)
			end
			local mutationLabel = line("MutationLine", 0, 0.26, if info then info.Color else Color3.fromRGB(255, 250, 200), text)
			if rec.Mutation == "Rainbow" or rec.Shiny then
				local gradient = Instance.new("UIGradient")
				gradient.Color = if rec.Shiny and rec.Mutation ~= "Rainbow"
					then ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 90))
					else RAINBOW
				gradient.Parent = mutationLabel
			end
		end
		rec.NameLabel = line("NameLine", 1, 0.36, Color3.fromRGB(255, 255, 255), def.Name)
		rec.RarityLabel = line("RarityLine", 2, 0.3, rarity.Color, string.upper(def.Rarity))
		if rarityIndex(def) >= 6 then
			local gradient = Instance.new("UIGradient")
			gradient.Color = RAINBOW
			gradient.Parent = rec.RarityLabel
		end
	end
	rec.ValueLabel = line("ValueLine", 3, 0.34, Color3.fromRGB(255, 230, 90), "")
end

local function updateInfo(rec)
	local state = rec.State
	local label = rec.ValueLabel
	if not isEgg(rec) and rec.NameLabel then
		-- nome com o estágio: "Baby Zapkit", "Zapkit", "GIANT Zapkit"
		local _, stage = stageOf(rec)
		rec.NameLabel.Text = (if stage.Name == "Baby" then "Baby " elseif stage.Name == "Giant" then "GIANT " else "") .. rec.Def.Name
	end
	if state == "Conveyor" then
		label.Text = Format.Money(recPrice(rec))
		label.TextColor3 = Color3.fromRGB(255, 230, 90)
	elseif state == "Rain" then
		label.Text = "FREE! Catch it!"
		label.TextColor3 = Color3.fromRGB(120, 255, 255)
	elseif state == "Carried" then
		label.Text = "STOLEN!"
		label.TextColor3 = Color3.fromRGB(255, 90, 90)
	elseif state == "Walking" and isEgg(rec) then
		label.Text = "Going home..."
		label.TextColor3 = Color3.fromRGB(200, 220, 255)
	elseif state == "Incubating" then
		label.Text = "Hatching..." -- a tela de cada jogador mostra a contagem
		label.TextColor3 = Color3.fromRGB(200, 220, 255)
	elseif state == "Hatching" then
		label.Text = "HATCHING!"
		label.TextColor3 = Color3.fromRGB(255, 240, 120)
	else
		local care = ""
		local now = os.clock()
		if (rec.HappyUntil or 0) > now then
			care ..= " \u{2665}" -- carinho
		end
		if (rec.FedUntil or 0) > now then
			care ..= " +food"
		end
		label.Text = Format.Money(recIncome(rec)) .. "/s" .. care
		label.TextColor3 = Color3.fromRGB(120, 255, 120)
	end
end

---------------------------------------------------------------------
-- Prompts (botões "E" / toque no celular)
---------------------------------------------------------------------
local function clearPrompts(rec)
	for _, child in rec.Root:GetChildren() do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
end

-- v20: cada botão do seu bichinho fica numa altura diferente na tela (antes os três apareciam
-- um em cima do outro e parecia bugado). O ladrão só vê o "Steal", então ele fica no meio.
local PROMPT_OFFSET: { [string]: number } = { PickUpPrompt = -76, PetPrompt = 0, SellPrompt = 76 }

local function addPrompt(rec, name: string, action: string, objectText: string, hold: number, key: Enum.KeyCode, gamepadKey: Enum.KeyCode, callback)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.KeyboardKeyCode = key
	prompt.GamepadKeyCode = gamepadKey
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 11
	prompt.UIOffset = Vector2.new(0, PROMPT_OFFSET[name] or 0)
	-- o servidor confere o tempo segurando (contra hack que pula o "segurar")
	local holdStart: { [Player]: number } = {}
	prompt.PromptButtonHoldBegan:Connect(function(player)
		holdStart[player] = os.clock()
	end)
	prompt.Triggered:Connect(function(player)
		if hold > 0 then
			local held = os.clock() - (holdStart[player] or -math.huge)
			if held < hold * 0.8 or held > hold + 15 then
				return
			end
		end
		holdStart[player] = nil
		callback(rec, player)
	end)
	prompt.Parent = rec.Root
	return prompt
end

---------------------------------------------------------------------
-- Brilho no chão e coluna de luz nos ovos raros (some quando alguém compra)
---------------------------------------------------------------------
local function addBeacons(rec)
	local color: Color3
	local size: number
	local pillar = isSpecial(rec)
	if isEgg(rec) then
		if rec.EggDef.Tier < 3 then
			return
		end
		color = rec.EggDef.Accent
		size = rec.EggDef.Size * 1.3
	else
		if not pillar and rarityIndex(rec.Def) < 4 then
			return
		end
		color = if rec.Mutation then Config.MutationByName[rec.Mutation].Color else Config.RarityByName[rec.Def.Rarity].Color
		size = (rec.Def.Size or Config.RarityByName[rec.Def.Rarity].Size) * 1.4
	end
	local function part(partSize: Vector3, offset: CFrame, transparency: number)
		local p = Instance.new("Part")
		p.Name = "Beacon"
		p.Shape = Enum.PartType.Cylinder
		p.Size = partSize
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = transparency
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		p.Anchored = false
		p.CFrame = rec.Root.CFrame * offset * CFrame.Angles(0, 0, math.rad(90))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rec.Root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = rec.Model
	end
	part(Vector3.new(0.2, size, size), CFrame.new(0, -rec.Ground + 0.15, 0), 0.35)
	if pillar then
		part(Vector3.new(60, 1.4, 1.4), CFrame.new(0, 30 - rec.Ground, 0), 0.55)
	end
end

local function removeBeacons(rec)
	for _, child in rec.Model:GetChildren() do
		if child.Name == "Beacon" then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------
-- Criar / destruir / colocar no pedestal
---------------------------------------------------------------------
local function baseRecord(model: Model, root: BasePart, ground: number, top: number)
	nextUid += 1
	model:SetAttribute("Uid", nextUid)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return {
		Uid = nextUid,
		Kind = "Critter",
		Def = nil :: any,
		EggDef = nil :: any,
		Result = nil :: any,
		Mutation = nil :: string?,
		Model = model,
		Root = root,
		Ground = ground,
		Top = top,
		BodyRadius = 1,
		State = "New",
		Owner = nil :: Player?,
		Plot = nil :: any,
		Slot = nil :: number?,
		Thief = nil :: Player?,
		CarryWeld = nil :: WeldConstraint?,
		DiedConn = nil :: RBXScriptConnection?,
		CarryStart = 0,
		CarryFrom = nil :: Vector3?,
		Scaled = false,
		StolenLock = 0, -- os.clock() até quando não pode ir para mochila/fusão (acabou de ser roubado)
		Born = os.time(), -- quando nasceu (o crescimento conta até offline)
		Shiny = false,
		Scale = 1, -- tamanho atual (estágio de crescimento)
		Stage = 0,
		HappyUntil = 0, -- carinho (os.clock)
		FedUntil = 0, -- comida (os.clock)
		Info = nil :: BillboardGui?,
		Waiting = false, -- ovo de clima esperando a chuva/neve/noite
		LastSync = 0,
		HatchLeft = 0,
		HatchAt = 0,
		X = 0,
		Lane = nil :: any,
		Buyer = nil :: Player?,
		Phase = math.random() * 10,
		Expire = 0,
		Dead = false,
	}
end

-- Shiny: brilho dourado e branco exclusivo
local function addShinyEffect(root: BasePart)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "ShinySparkles"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 225, 90))
	sparkles.LightEmission = 1
	sparkles.Rate = 14
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Parent = root
end

-- Coraçõezinhos enquanto está feliz (carinho)
local function setHearts(rec, on: boolean)
	local hearts = rec.Root:FindFirstChild("Hearts") :: ParticleEmitter?
	if on and not hearts then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Hearts"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 110, 170))
		emitter.LightEmission = 0.6
		emitter.Rate = 2
		emitter.Lifetime = NumberRange.new(1.2, 1.8)
		emitter.Speed = NumberRange.new(1.5, 2.5)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) })
		emitter.Parent = rec.Root
	elseif not on and hearts then
		hearts:Destroy()
	end
end

local function createRecord(def, mutation: string?, born: number?, shiny: boolean?)
	local model, root, ground, top = Builder.Build(def)
	if mutation then
		Builder.ApplyMutation(model, mutation)
	end
	model:SetAttribute("Kind", "Critter")
	model:SetAttribute("CritterId", def.Id)
	model:AddTag("BaseCritter") -- v27: o cliente anima (dormir à noite, festa, susto)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Mutation", mutation)
	local rec = baseRecord(model, root, ground, top)
	rec.Kind = "Critter"
	rec.Def = def
	rec.Mutation = mutation
	rec.Born = if typeof(born) == "number" then born else os.time()
	rec.Shiny = shiny == true
	model:SetAttribute("Born", rec.Born)
	model:SetAttribute("Shiny", rec.Shiny)
	if rec.Shiny then
		addShinyEffect(root)
	end
	local rarity = Config.RarityByName[def.Rarity] or Config.Rarities[1]
	rec.BodyRadius = (def.Size or rarity.Size) * 0.5
	-- tamanho do estágio (bebê menor, gigante maior)
	local index, stage = stageOf(rec)
	rec.Stage = index
	rec.Scale = Config.StageScale(stage, def.Size or rarity.Size)
	model:SetAttribute("Stage", stage.Name)
	if rec.Scale ~= 1 then
		pcall(function()
			model:ScaleTo(rec.Scale)
		end)
	end
	makeInfo(rec)
	return rec
end

local function createEggRecord(egg, result)
	local model, root, ground, top = Builder.BuildEgg(egg)
	model:SetAttribute("Kind", "Egg")
	model:SetAttribute("EggId", egg.Id)
	model:SetAttribute("Rarity", Config.EggBest(egg))
	local rec = baseRecord(model, root, ground, top)
	rec.Kind = "Egg"
	rec.EggDef = egg
	rec.Result = result
	rec.HatchLeft = egg.HatchTime
	rec.BodyRadius = egg.Size * 0.4
	makeInfo(rec)
	return rec
end

local function setState(rec, state: string)
	if rec.State == "Incubating" and state ~= "Incubating" then
		rec.HatchLeft = math.max(0, rec.HatchAt - serverNow())
		incubating[rec] = nil
	end
	rec.State = state
	rec.Model:SetAttribute("State", state)
end

local function destroyRecord(rec)
	if rec.Dead then
		return
	end
	incubating[rec] = nil
	rec.Dead = true
	rec.State = "Dead"
	markDirty(rec.Owner)
	local thief = rec.Thief
	if thief then
		if carrying[thief] == rec then
			carrying[thief] = nil
		end
		if thief.Parent then
			thief:SetAttribute("Carrying", nil)
			Registry.Economy.ApplySpeed(thief)
		end
		rec.Thief = nil
	end
	if rec.DiedConn then
		rec.DiedConn:Disconnect()
		rec.DiedConn = nil
	end
	rec.Model:Destroy()
end

local function restoreScale(rec)
	if rec.Scaled then
		pcall(function()
			rec.Model:ScaleTo(rec.Scale or 1)
		end)
		rec.Scaled = false
	end
end

local function placeRecord(rec)
	rec.Root.Anchored = true
	restoreScale(rec)
	removeBeacons(rec)
	local home = Registry.Plots.SlotCFrame(rec.Plot, rec.Slot, rec.Ground * (rec.Scale or 1))
	rec.Root.CFrame = home
	rec.Model:SetAttribute("Home", home)
	clearPrompts(rec)
	if isEgg(rec) then
		rec.HatchAt = serverNow() + rec.HatchLeft
		rec.Model:SetAttribute("HatchAt", rec.HatchAt)
		setState(rec, "Incubating")
		incubating[rec] = true
		addPrompt(rec, "StealPrompt", "Steal Egg", displayName(rec), Config.StealHoldDuration, Enum.KeyCode.E, Enum.KeyCode.ButtonX, onSteal)
	else
		setState(rec, "Placed")
		addPrompt(rec, "StealPrompt", "Steal", displayName(rec), Config.StealHoldDuration, Enum.KeyCode.E, Enum.KeyCode.ButtonX, onSteal)
		addPrompt(rec, "PickUpPrompt", "Pick Up", displayName(rec), 0.4, Enum.KeyCode.R, Enum.KeyCode.ButtonB, onPickUp)
		addPrompt(rec, "PetPrompt", "Pet", displayName(rec), 0.3, Enum.KeyCode.T, Enum.KeyCode.ButtonL1, onPet)
	end
	addPrompt(rec, "SellPrompt", "Sell " .. Format.Money(sellPrice(rec)), displayName(rec), 1, Enum.KeyCode.F, Enum.KeyCode.ButtonY, onSell)
	updateInfo(rec)
end

-- Coloca direto num pedestal (salvo, ganho, pendente)
local function spawnPlaced(player: Player, plot, slot: number, rec)
	rec.Owner = player
	rec.Plot = plot
	rec.Slot = slot
	plot.Slots[slot] = rec
	rec.Model:SetAttribute("OwnerUserId", player.UserId)
	rec.Model:PivotTo(Registry.Plots.SlotCFrame(plot, slot, rec.Ground * (rec.Scale or 1)))
	rec.Model.Parent = folder
	placeRecord(rec)
	markDirty(player)
	return rec
end

-- Cresceu? Troca o tamanho, o nome e a renda (chamado de tempos em tempos)
local function applyStage(rec)
	if isEgg(rec) or rec.Dead then
		return
	end
	local index, stage = stageOf(rec)
	if index == rec.Stage then
		return
	end
	rec.Stage = index
	local rarity = Config.RarityByName[rec.Def.Rarity] or Config.Rarities[1]
	rec.Scale = Config.StageScale(stage, rec.Def.Size or rarity.Size)
	rec.Model:SetAttribute("Stage", stage.Name)
	if not rec.Scaled then -- sendo carregado: o tamanho volta certo quando for colocado
		pcall(function()
			rec.Model:ScaleTo(rec.Scale)
		end)
	end
	if rec.Info then
		rec.Info.StudsOffsetWorldSpace = Vector3.new(0, rec.Top * rec.Scale + 2.1, 0)
	end
	if rec.State == "Placed" and rec.Plot and rec.Slot then
		local home = Registry.Plots.SlotCFrame(rec.Plot, rec.Slot, rec.Ground * rec.Scale)
		rec.Root.CFrame = home
		rec.Model:SetAttribute("Home", home)
	end
	updateInfo(rec)
	if stage.Name == "Giant" and rec.Owner and rec.Owner.Parent then
		Registry.Remotes.Notify(rec.Owner, ("%s grew into a GIANT! It earns full money now."):format(rec.Def.Name), "success")
	end
end

---------------------------------------------------------------------
-- Esteira (ovos)
---------------------------------------------------------------------
function CritterService.SpawnEggOnConveyor(egg, startX: number?, silent: boolean?)
	local lane = lanes[egg.World] or lanes.meadow
	if not lane then
		return nil
	end
	local rec = createEggRecord(egg, nil)
	setState(rec, "Conveyor")
	rec.Lane = lane
	rec.X = startX or lane.StartX
	local position = Vector3.new(rec.X, lane.Y + rec.Ground, lane.Z)
	rec.Model:PivotTo(CFrame.lookAt(position, position + Vector3.xAxis))
	addBeacons(rec)
	updateInfo(rec)
	addPrompt(rec, "BuyPrompt", "Buy " .. Format.Money(egg.Price), egg.Name, 0, Enum.KeyCode.E, Enum.KeyCode.ButtonX, onBuy)
	rec.Model.Parent = folder
	table.insert(lane.List, rec)

	if not silent and isSpecial(rec) then
		Registry.Remotes.NotifyAll(("A %s is on the conveyor! GO GO GO!"):format(string.upper(egg.Name)), "rare")
		Registry.Remotes.EffectAll("RareSpawn", "Legendary")
	end
	return rec
end

---------------------------------------------------------------------
-- Ir até a base
---------------------------------------------------------------------
local function tweenTo(rec, target: Vector3): boolean
	local from = rec.Root.Position
	local distance = (target - from).Magnitude
	if distance < 0.05 then
		return not rec.Dead and rec.State == "Walking"
	end
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local goal: CFrame
	if flat.Magnitude > 0.05 then
		rec.Root.CFrame = CFrame.lookAt(from, from + flat.Unit)
		goal = CFrame.lookAt(target, target + flat.Unit)
	else
		goal = rec.Root.CFrame.Rotation + target
	end
	local duration = distance / Config.CritterWalkSpeed
	TweenService:Create(rec.Root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goal }):Play()
	task.wait(duration)
	return not rec.Dead and rec.State == "Walking"
end

local function walkToBase(rec)
	local plot = rec.Plot
	local outside, inside = Registry.Plots.PathPoints(plot)
	local lift = Vector3.new(0, rec.Ground, 0)
	local lane = rec.Lane
	if lane and lane.World ~= "meadow" then
		-- comprado em outro mundo: some num brilho e aparece na frente da sua base
		task.wait(0.4)
		if rec.Dead or rec.State ~= "Walking" then
			return
		end
		rec.Root.CFrame = CFrame.lookAt(outside + lift, inside + lift)
	elseif not tweenTo(rec, outside + lift) then
		return
	end
	if not tweenTo(rec, inside + lift) then
		return
	end
	-- vaga no 2º andar: sobe pela rampa
	for _, point in Registry.Plots.SlotRoute(plot, rec.Slot) do
		if not tweenTo(rec, point + lift) then
			return
		end
	end
	local final = Registry.Plots.SlotCFrame(plot, rec.Slot, rec.Ground)
	if not tweenTo(rec, final.Position) then
		return
	end
	placeRecord(rec)
	if Registry.Tutorial and rec.Owner then
		Registry.Tutorial.Event(rec.Owner, "Placed")
	end
end

local function startWalking(rec, player: Player, plot, slot: number)
	setState(rec, "Walking")
	rec.Owner = player
	rec.Plot = plot
	rec.Slot = slot
	plot.Slots[slot] = rec
	rec.Model:SetAttribute("OwnerUserId", player.UserId)
	clearPrompts(rec)
	removeBeacons(rec)
	updateInfo(rec)
	if not isEgg(rec) then
		Registry.Economy.Discover(player, rec.Def.Id)
	end
	task.spawn(walkToBase, rec)
end

---------------------------------------------------------------------
-- Comprar ovo (esteira)
---------------------------------------------------------------------
onBuy = function(rec, player: Player)
	if rec.State ~= "Conveyor" or rec.Dead then
		return
	end
	local Plots = Registry.Plots
	local Economy = Registry.Economy
	local Remotes = Registry.Remotes
	local plot = Plots.Get(player)
	if not plot or not player:GetAttribute("Loaded") or not closeEnough(player, rec.Root.Position, 18) then
		return
	end
	-- só compra no mundo que já destravou (contra hack de teleporte)
	local world = rec.Lane and rec.Lane.World
	if world and world ~= "meadow" and not Registry.Worlds.IsUnlocked(player, world) then
		return
	end
	local slot = Plots.FreeSlot(plot, Economy.GetSlotCount(player))
	if not slot then
		Remotes.Notify(player, "Your base is full! Sell something or buy more slots in the SHOP.", "error")
		return
	end
	local price = recPrice(rec)
	if not Economy.TrySpend(player, price) then
		Remotes.Notify(player, "Not enough cash! You need " .. Format.Money(price), "error")
		return
	end

	local lane = rec.Lane
	local index = if lane then table.find(lane.List, rec) else nil
	if lane and index then
		table.remove(lane.List, index)
	end
	rec.Result = if isEgg(rec) then CritterService.RollResult(rec.EggDef, player, 1) else rec.Result
	rec.Buyer = player
	local progress = Registry.Progress
	if isEgg(rec) and progress then
		rec.HatchLeft *= progress.HatchMultiplier(player) -- classe Creator: choca mais rápido
	end
	startWalking(rec, player, plot, slot)
	if isEgg(rec) and progress then
		progress.Event(player, "Buy") -- depois de ocupar a vaga (o prêmio da missão pode ser um ovo)
	end

	Remotes.Notify(player, "You bought a " .. displayName(rec) .. "! It's going to your base.", "success")
	Remotes.Effect(player, "Purchase", "Common")
	if isSpecial(rec) then
		Remotes.NotifyAll(("%s bought a %s!"):format(player.DisplayName, string.upper(displayName(rec))), "rare")
	end
	track("EggBought", player, rec.EggDef, price)
	if Registry.Tutorial then
		Registry.Tutorial.Event(player, "Bought")
	end
end

---------------------------------------------------------------------
-- Chocar (com suspense na tela do dono)
---------------------------------------------------------------------
local function hatchEgg(rec)
	if rec.Dead or rec.State ~= "Incubating" then
		return
	end
	local owner: Player = rec.Owner
	local plot = rec.Plot
	local slot = rec.Slot
	setState(rec, "Hatching")
	clearPrompts(rec)
	updateInfo(rec)

	local result = validResult(rec.Result) or CritterService.RollResult(rec.EggDef, owner, 1)
	rec.Result = result
	local def = Critters.ById[result.Id]
	local Economy = Registry.Economy
	Registry.Remotes.Effect(owner, "Hatch", {
		Critter = def.Id,
		Mutation = result.Mutation,
		Egg = rec.EggDef.Id,
		New = not Economy.HasDiscovered(owner, def.Id),
		Shiny = result.Shiny == true,
	})

	task.wait(Config.HatchRevealTime)
	if rec.Dead or (rec.State :: string) ~= "Hatching" or plot.Slots[slot] ~= rec or plot.Owner ~= owner then
		return
	end
	-- troca o ovo pelo bichinho no mesmo pedestal
	rec.Dead = true
	rec.State = "Dead"
	rec.Model:Destroy()
	local critter = spawnPlaced(owner, plot, slot, createRecord(def, result.Mutation, os.time(), result.Shiny))

	Economy.Discover(owner, def.Id)
	Economy.AddHatch(owner)
	Economy.SeasonXP(owner, "Hatch")
	Registry.Remotes.EffectAll("HatchBurst", { Position = critter.Root.Position, Rarity = def.Rarity })
	if isSpecial(critter) then
		local tag = if result.Shiny then "SHINY " .. string.upper(result.Mutation or def.Rarity) else string.upper(result.Mutation or def.Rarity)
		Registry.Remotes.NotifyAll(("%s hatched a %s %s!"):format(owner.DisplayName, tag, def.Name), "rare")
		Registry.Remotes.EffectAll("RareSpawn", if result.Shiny then "Secret" else def.Rarity)
	end
	if result.Shiny and Registry.Progress then
		Registry.Progress.Event(owner, "Shiny")
	end
	-- "Descoberto por": o primeiro do MUNDO a chocar cada Secret fica no álbum para sempre
	local discoveries = Registry.Discoveries
	if def.Rarity == "Secret" and discoveries then
		task.spawn(discoveries.Claim, owner, def.Id)
	end
	track("Hatched", owner, def, result.Mutation, rec.EggDef)
	if Registry.Tutorial then
		Registry.Tutorial.Event(owner, "Hatched")
	end
end

---------------------------------------------------------------------
-- Chuva de Ovos (grátis!)
---------------------------------------------------------------------
function CritterService.SpawnRainEgg(egg, position: Vector3)
	local rec = createEggRecord(egg, nil)
	setState(rec, "Rain")
	local landing = CFrame.new(position + Vector3.new(0, rec.Ground, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	rec.Model:PivotTo(landing + Vector3.new(0, 70, 0))
	rec.Expire = os.clock() + Config.RainLifetime
	updateInfo(rec)
	addPrompt(rec, "CatchPrompt", "Catch (FREE)", displayName(rec), 0.3, Enum.KeyCode.E, Enum.KeyCode.ButtonX, onCatch)
	rec.Model.Parent = folder
	TweenService:Create(rec.Root, TweenInfo.new(2.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = landing }):Play()
	table.insert(rainList, rec)
	return rec
end

onCatch = function(rec, player: Player)
	if rec.State ~= "Rain" or rec.Dead then
		return
	end
	local Plots = Registry.Plots
	local Economy = Registry.Economy
	local plot = Plots.Get(player)
	if not plot or not player:GetAttribute("Loaded") or not closeEnough(player, rec.Root.Position, 18) then
		return
	end
	local slot = Plots.FreeSlot(plot, Economy.GetSlotCount(player))
	if not slot then
		Registry.Remotes.Notify(player, "Your base is full! Make space to catch eggs.", "error")
		return
	end
	local index = table.find(rainList, rec)
	if index then
		table.remove(rainList, index)
	end
	-- ovos da chuva têm o dobro de chance de mutação
	rec.Result = CritterService.RollResult(rec.EggDef, player, 2)
	local progress = Registry.Progress
	if progress then
		rec.HatchLeft *= progress.HatchMultiplier(player)
	end
	startWalking(rec, player, plot, slot)
	if progress then
		progress.Event(player, "Rain")
	end
	Registry.Remotes.Notify(player, "You caught a FREE " .. displayName(rec) .. "!", "success")
	Registry.Remotes.Effect(player, "Purchase", "Common")
	if Registry.Tutorial then
		Registry.Tutorial.Event(player, "Bought")
	end
end

---------------------------------------------------------------------
-- Vender
---------------------------------------------------------------------
onSell = function(rec, player: Player)
	if (rec.State ~= "Placed" and rec.State ~= "Incubating") or rec.Owner ~= player or rec.Dead then
		return
	end
	if not closeEnough(player, rec.Root.Position, 18) then
		return
	end
	local plot = rec.Plot
	if plot.Slots[rec.Slot] == rec then
		plot.Slots[rec.Slot] = nil
	end
	local amount = sellPrice(rec)
	Registry.Economy.AddCash(player, amount, false, "Sell")
	Registry.Remotes.Notify(player, ("Sold %s for %s"):format(displayName(rec), Format.Money(amount)), "info")
	destroyRecord(rec)
	CritterService.PlacePending(player)
end

-- Guardar na mochila (botão "Pick Up" em cima do seu bichinho)
onPickUp = function(rec, player: Player)
	if rec.State ~= "Placed" or rec.Owner ~= player or rec.Dead or isEgg(rec) then
		return
	end
	if not closeEnough(player, rec.Root.Position, 18) then
		return
	end
	Registry.Pets.Store(player, rec.Uid)
end

-- Carinho: +10% por 10 minutos (e coraçõezinhos). Nunca tem castigo se o jogador sumir.
onPet = function(rec, player: Player)
	if rec.State ~= "Placed" or rec.Owner ~= player or rec.Dead or isEgg(rec) then
		return
	end
	if not closeEnough(player, rec.Root.Position, 18) then
		return
	end
	local now = os.clock()
	if rec.HappyUntil > now then
		Registry.Remotes.Notify(player, rec.Def.Name .. " is already happy!", "info")
		return
	end
	rec.HappyUntil = now + Config.CareSeconds
	setHearts(rec, true)
	updateInfo(rec)
	Registry.Remotes.Effect(player, "Pet", rec.Root.Position)
	if Registry.Progress then
		Registry.Progress.Event(player, "Pet")
	end
	Registry.Remotes.Notify(player, ("%s loves you! +%d%% cash for 10 min"):format(rec.Def.Name, math.floor(Config.PetHappyBonus * 100)), "success")
end

-- Comida para todos os bichinhos da base: +15% por 10 minutos (custa 1 minuto da sua renda)
function CritterService.FeedAll(player: Player, shownCost: any)
	local plot = Registry.Plots.Get(player)
	if not plot then
		return
	end
	local now = os.clock()
	local hungry = {}
	for _, rec in plot.Slots do
		if not isEgg(rec) and rec.Owner == player and rec.State == "Placed" and not rec.Dead and rec.FedUntil < now + 60 then
			table.insert(hungry, rec)
		end
	end
	if #hungry == 0 then
		Registry.Remotes.Notify(player, "Your critters are already full!", "info")
		return
	end
	local cost = CritterService.FeedCost(player)
	-- preço claro: se a renda subiu depois da tela mostrar o preço, avisa e não cobra
	if type(shownCost) == "number" and cost > shownCost * 1.05 + 1 then
		Registry.Remotes.Notify(player, "Food price is now " .. Format.Money(cost) .. ". Tap FEED again!", "info")
		if Registry.Pets then
			Registry.Pets.Sync(player)
		end
		return
	end
	if not Registry.Economy.TrySpend(player, cost, "Food") then
		Registry.Remotes.Notify(player, "Not enough cash! Food costs " .. Format.Money(cost), "error")
		return
	end
	for _, rec in hungry do
		rec.FedUntil = now + Config.CareSeconds
		updateInfo(rec)
	end
	Registry.Remotes.Effect(player, "Purchase", "Rare")
	Registry.Remotes.Notify(player, ("Yum! %d critters get +%d%% cash for 10 min"):format(#hungry, math.floor(Config.FeedBonus * 100)), "success")
	if Registry.Progress then
		Registry.Progress.Event(player, "Feed")
	end
end

-- Preço da comida agora (para a tela)
function CritterService.FeedCost(player: Player): number
	return math.floor(math.max(100, Registry.Economy.GetIncome(player) * 60 * Config.FeedCostMinutes))
end

---------------------------------------------------------------------
-- Roubar (carregar nas costas)
---------------------------------------------------------------------
local function returnToOwner(rec, reason: string?)
	local thief = rec.Thief
	if thief then
		if carrying[thief] == rec then
			carrying[thief] = nil
		end
		if thief.Parent then
			thief:SetAttribute("Carrying", nil)
			Registry.Economy.ApplySpeed(thief)
		end
	end
	rec.Thief = nil
	if rec.CarryWeld then
		rec.CarryWeld:Destroy()
		rec.CarryWeld = nil
	end
	if rec.DiedConn then
		rec.DiedConn:Disconnect()
		rec.DiedConn = nil
	end
	if rec.Dead then
		return
	end
	local plot = rec.Plot
	local owner = rec.Owner
	markDirty(owner)
	if owner and plot and plot.Owner == owner and plot.Slots[rec.Slot] == rec then
		placeRecord(rec)
		if reason and owner.Parent then
			Registry.Remotes.Notify(owner, displayName(rec) .. " is back home!", "success")
			-- só conta defesa se o ladrão estava mesmo fugindo (não vale combinar com um amigo)
			if reason == "slapped" and rec.Root then
				Registry.Remotes.Effect(owner, "Saved", rec.Root.Position) -- v27: explosão SAVED!
			end
			if reason == "slapped" and os.clock() - (rec.CarryStart or 0) >= 2 then
				Registry.Economy.AddDefense(owner, thief)
			end
		end
	else
		destroyRecord(rec)
	end
end

local function completeSteal(rec)
	local thief: Player = rec.Thief
	local victim: Player? = rec.Owner
	local Plots = Registry.Plots
	local Economy = Registry.Economy
	local Remotes = Registry.Remotes
	if victim and (victim.Parent == nil or victim:GetAttribute("Leaving")) then
		returnToOwner(rec)
		return
	end
	local newPlot = Plots.Get(thief)
	local slot = newPlot and Plots.FreeSlot(newPlot, Economy.GetSlotCount(thief))
	if not newPlot or not slot then
		Remotes.Notify(thief, "Your base is full! It ran back home.", "error")
		returnToOwner(rec, "full")
		return
	end

	carrying[thief] = nil
	thief:SetAttribute("Carrying", nil)
	if rec.CarryWeld then
		rec.CarryWeld:Destroy()
		rec.CarryWeld = nil
	end
	if rec.DiedConn then
		rec.DiedConn:Disconnect()
		rec.DiedConn = nil
	end
	local oldPlot = rec.Plot
	if oldPlot and oldPlot.Slots[rec.Slot] == rec then
		oldPlot.Slots[rec.Slot] = nil
	end

	rec.Thief = nil
	rec.Owner = thief
	rec.Plot = newPlot
	rec.Slot = slot
	newPlot.Slots[slot] = rec
	rec.Model:SetAttribute("OwnerUserId", thief.UserId)
	rec.StolenLock = os.clock() + Config.StolenLockSeconds
	placeRecord(rec)
	markDirty(thief)
	markDirty(victim)

	Economy.ApplySpeed(thief)
	if not isEgg(rec) then
		Economy.Discover(thief, rec.Def.Id)
	end
	Economy.AddSteal(thief)
	Economy.SeasonXP(thief, "Steal", victim)
	Remotes.Notify(thief, "You stole " .. displayName(rec) .. "! It's yours now!", "success")
	Remotes.Effect(thief, "Stolen", if isEgg(rec) then "Rare" else rec.Def.Rarity)
	if victim and victim.Parent then
		Remotes.Notify(victim, thief.DisplayName .. " stole your " .. displayName(rec) .. "! Get revenge!", "error")
		CritterService.PlacePending(victim)
		Registry.Fairness.OnStolen(victim, thief)
	end
	if isSpecial(rec) then
		Remotes.NotifyAll(("%s stole the %s!"):format(thief.DisplayName, string.upper(displayName(rec))), "rare")
	end
	track("Stole", thief, rec)
end

onSteal = function(rec, thief: Player)
	if (rec.State ~= "Placed" and rec.State ~= "Incubating") or rec.Dead then
		return
	end
	local owner = rec.Owner
	if owner == thief or not owner or owner.Parent == nil or owner:GetAttribute("Leaving") then
		return
	end
	if not thief:GetAttribute("Loaded") then
		return
	end
	local Plots = Registry.Plots
	local Economy = Registry.Economy
	local Remotes = Registry.Remotes
	if Plots.IsLocked(rec.Plot) then
		Remotes.Notify(thief, "This base is locked!", "error")
		return
	end
	local allowed, reason = Registry.Fairness.CanSteal(thief, owner)
	if not allowed then
		Remotes.Notify(thief, reason or "You can't steal from this player.", "warning")
		return
	end
	if carrying[thief] then
		Remotes.Notify(thief, "You're already carrying something!", "error")
		return
	end
	local thiefPlot = Plots.Get(thief)
	if not thiefPlot then
		return
	end
	if not Plots.FreeSlot(thiefPlot, Economy.GetSlotCount(thief)) then
		Remotes.Notify(thief, "Your base is full! Make space before stealing.", "error")
		return
	end
	local character = thief.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if (root.Position - rec.Root.Position).Magnitude > 18 then
		return
	end
	if not Plots.IsInside(rec.Plot, root.Position) then
		Remotes.Notify(thief, "Go INSIDE the base to steal!", "error")
		return
	end

	setState(rec, "Carried") -- se era um ovo chocando, o tempo que falta fica guardado
	rec.Thief = thief
	rec.CarryStart = os.clock()
	rec.CarryFrom = root.Position
	carrying[thief] = rec
	clearPrompts(rec)
	updateInfo(rec)

	-- Diminui e coloca nas costas
	local scale = 1
	local targetScale = if isEgg(rec) then 0.8 else Config.CarryScale
	if targetScale ~= 1 then
		local ok = pcall(function()
			rec.Model:ScaleTo(targetScale)
		end)
		rec.Scaled = ok
		if ok then
			scale = targetScale
		end
	end
	rec.Root.Anchored = false
	rec.Root.CFrame = root.CFrame * CFrame.new(0, 0.6, 0.9 + rec.BodyRadius * scale) * CFrame.Angles(0, math.pi, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = rec.Root
	weld.Parent = rec.Root
	rec.CarryWeld = weld
	rec.DiedConn = humanoid.Died:Connect(function()
		if rec.Thief == thief then
			returnToOwner(rec, "died")
		end
	end)

	thief:SetAttribute("Carrying", displayName(rec))
	markDirty(owner)
	Economy.ApplySpeed(thief)
	Remotes.Notify(thief, "You grabbed " .. displayName(rec) .. "! RUN to your base!", "warning")
	Remotes.Notify(owner, thief.DisplayName .. " is stealing your " .. displayName(rec) .. "! BONK them!", "error")
	Remotes.Effect(owner, "Alarm")
	if rec.Plot and rec.Plot.Model then
		rec.Plot.Model:SetAttribute("AlarmUntil", os.time() + 8) -- v27: sirene girando na base (todo mundo vê)
	end
	Registry.Fairness.OnGrab(owner, thief)
end

---------------------------------------------------------------------
-- API usada pelos outros módulos
---------------------------------------------------------------------
-- Liga a esteira de um mundo na hora que alguém chega (sem esperar o próximo ovo)
function CritterService.ActivateLane(worldId: string)
	local lane = lanes[worldId]
	if not lane then
		return
	end
	lane.Active = true
	if not lane.Filled and fillLaneFn then
		fillLaneFn(lane)
	end
end

function CritterService.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function CritterService.OnSlapped(target: Player, attacker: Player?)
	local rec = carrying[target]
	if not rec then
		return
	end
	Registry.Remotes.Notify(target, "BONK! You dropped " .. displayName(rec) .. "!", "error")
	if attacker then
		Registry.Remotes.Notify(attacker, "You made " .. target.DisplayName .. " drop " .. displayName(rec) .. "!", "success")
	end
	returnToOwner(rec, "slapped")
end

function CritterService.GetBaseIncome(player: Player): number
	local plot = Registry.Plots.Get(player)
	if not plot then
		return 0
	end
	local total = 0
	for _, rec in plot.Slots do
		if rec.State == "Placed" and rec.Owner == player then
			total += recIncome(rec)
		end
	end
	return total
end

-- Listas para salvar. Devolvem nil se o jogador não tem base (aí o save mantém a lista antiga).
function CritterService.GetSaveList(player: Player)
	local plot = Registry.Plots.Get(player)
	if not plot then
		return nil
	end
	local list = {}
	for slot, rec in plot.Slots do
		if not isEgg(rec) and rec.Owner == player and not rec.Dead then
			table.insert(list, { Id = rec.Def.Id, Slot = slot, Mutation = rec.Mutation, B = rec.Born, S = if rec.Shiny then true else nil })
		end
	end
	return list
end

function CritterService.GetEggSaveList(player: Player)
	local plot = Registry.Plots.Get(player)
	if not plot then
		return nil
	end
	local list = {}
	for slot, rec in plot.Slots do
		if isEgg(rec) and rec.Owner == player and not rec.Dead then
			local left = if rec.State == "Incubating" then math.max(0, rec.HatchAt - serverNow()) elseif rec.State == "Hatching" then 0 else rec.HatchLeft
			local result = validResult(rec.Result)
			table.insert(list, { Id = rec.EggDef.Id, Slot = slot, Left = math.floor(left), Result = result })
		end
	end
	return list
end

-- Bichinhos na base (para a tela "Critters"): { U = uid, Id, M = mutação, S = vaga }
function CritterService.GetBaseList(player: Player)
	local plot = Registry.Plots.Get(player)
	local list = {}
	if not plot then
		return list
	end
	for slot, rec in plot.Slots do
		if not isEgg(rec) and rec.Owner == player and not rec.Dead and rec.State == "Placed" then
			table.insert(list, {
				U = rec.Uid,
				Id = rec.Def.Id,
				M = rec.Mutation,
				Slot = slot,
				B = rec.Born,
				Sh = if rec.Shiny then true else nil,
				L = if rec.StolenLock > os.clock() then true else nil,
			})
		end
	end
	return list
end

-- Uids dos bichinhos iguais na base (para a fusão)
function CritterService.FindBaseUids(player: Player, critterId: string, mutation: string?): { number }
	local list = {}
	for _, item in CritterService.GetBaseList(player) do
		if item.Id == critterId and item.M == mutation and not item.L and not item.Sh then
			table.insert(list, item.U)
		end
	end
	return list
end

-- Segundos que faltam para um bichinho recém-roubado poder ir para a mochila (0 = já pode)
function CritterService.StolenLockLeft(player: Player, uid: number): number
	local plot = Registry.Plots.Get(player)
	if plot then
		for _, rec in plot.Slots do
			if rec.Uid == uid then
				return math.max(0, rec.StolenLock - os.clock())
			end
		end
	end
	return 0
end

-- Tira um bichinho da base (mochila/fusão). Só funciona se ele estiver parado no pedestal
-- (não dá para guardar enquanto alguém está carregando ele). Quem chama coloca o pendente depois.
-- Devolve (id, mutação, nascimento, shiny) do bichinho que saiu da base
function CritterService.TakeFromBase(player: Player, uid: number): (string?, string?, number?, boolean?)
	local plot = Registry.Plots.Get(player)
	if not plot then
		return nil, nil, nil, nil
	end
	for slot, rec in plot.Slots do
		if rec.Uid == uid then
			if isEgg(rec) or rec.Owner ~= player or rec.Dead or rec.State ~= "Placed" or rec.StolenLock > os.clock() then
				return nil, nil, nil, nil
			end
			local critterId, mutation, born, shiny = rec.Def.Id, rec.Mutation, rec.Born, rec.Shiny
			plot.Slots[slot] = nil
			destroyRecord(rec)
			return critterId, mutation, born, shiny
		end
	end
	return nil, nil, nil, nil
end

function CritterService.HasFreeSlot(player: Player): boolean
	local plot = Registry.Plots.Get(player)
	return plot ~= nil and Registry.Plots.FreeSlot(plot, Registry.Economy.GetSlotCount(player)) ~= nil
end

-- Mochila -> pedestal livre
function CritterService.PlaceFromInventory(player: Player, critterId: string, mutation: string?, born: number?, shiny: boolean?): boolean
	local def = Critters.ById[critterId]
	local plot = Registry.Plots.Get(player)
	if not def or not plot then
		return false
	end
	local slot = Registry.Plots.FreeSlot(plot, Registry.Economy.GetSlotCount(player))
	if not slot then
		return false
	end
	spawnPlaced(player, plot, slot, createRecord(def, mutation, born, shiny))
	return true
end

-- Coloca na base o que estava esperando vaga (ovos ou bichinhos)
function CritterService.PlacePending(player: Player)
	local profile = Registry.Data.Get(player)
	local plot = Registry.Plots.Get(player)
	if not profile or not plot then
		return
	end
	local pending = profile.Data.Pending
	local count = Registry.Economy.GetSlotCount(player)
	while #pending > 0 do
		local slot = Registry.Plots.FreeSlot(plot, count)
		if not slot then
			break
		end
		local entry = table.remove(pending, 1)
		local egg = type(entry) == "table" and entry.Egg and Config.EggById[entry.Egg]
		local def = type(entry) == "table" and entry.Id and Critters.ById[entry.Id]
		if egg then
			local rec = createEggRecord(egg, validResult(entry.Result) or CritterService.RollResult(egg, player, 1))
			rec.HatchLeft = math.clamp(tonumber(entry.Left) or egg.HatchTime, 0, egg.HatchTime)
			spawnPlaced(player, plot, slot, rec)
			Registry.Remotes.Notify(player, "A " .. egg.Name .. " arrived at your base!", "success")
		elseif def then
			local mutation = if type(entry.Mutation) == "string" and Config.MutationByName[entry.Mutation] then entry.Mutation else nil
			spawnPlaced(player, plot, slot, createRecord(def, mutation, tonumber(entry.B) or (os.time() - 86400), entry.S == true))
			Registry.Economy.Discover(player, def.Id)
			Registry.Remotes.Notify(player, def.Name .. " arrived at your base!", "success")
		end
	end
end

-- Dá um bichinho (compra com Robux): vai para o pedestal ou fica esperando vaga
function CritterService.GrantCritter(player: Player, critterId: string, mutation: string?, born: number?, shiny: boolean?): boolean
	-- sem data de nascimento (compra com Robux, códigos): já chega GIGANTE, rendendo o que a loja mostra
	born = born or (os.time() - Config.Growth[#Config.Growth].Age)
	local def = Critters.ById[critterId]
	local profile = Registry.Data.Get(player)
	if not def or not profile then
		return false
	end
	local pets = Registry.Pets
	if not CritterService.HasFreeSlot(player) and pets and pets.Add(player, critterId, mutation, born or os.time(), shiny) then
		-- base cheia: vai para a mochila (dá para colocar na base depois)
		Registry.Remotes.Notify(player, "Your base is full! " .. def.Name .. " went to your BACKPACK.", "warning")
	else
		table.insert(profile.Data.Pending, { Id = critterId, Mutation = mutation, B = born or os.time(), S = if shiny then true else nil })
		CritterService.PlacePending(player)
		if #profile.Data.Pending > 0 then
			Registry.Remotes.Notify(player, "Your base is full! " .. def.Name .. " is waiting: sell something to make space.", "warning")
		end
	end
	Registry.Remotes.Effect(player, "Stolen", def.Rarity)
	return true
end

-- Dá um ovo (códigos, recompensas)
function CritterService.GrantEgg(player: Player, eggId: string): boolean
	local egg = Config.EggById[eggId]
	local profile = Registry.Data.Get(player)
	if not egg or not profile then
		return false
	end
	table.insert(profile.Data.Pending, { Egg = eggId, Result = CritterService.RollResult(egg, player, 1) })
	CritterService.PlacePending(player)
	if #profile.Data.Pending > 0 then
		Registry.Remotes.Notify(player, "Your base is full! Your " .. egg.Name .. " is waiting: sell something to make space.", "warning")
	end
	return true
end

-- Quantos ovos do jogador estão chocando agora (Instant Hatch só é vendido se for > 0)
function CritterService.IncubatingCount(player: Player): number
	local plot = Registry.Plots.Get(player)
	if not plot then
		return 0
	end
	local count = 0
	for _, rec in plot.Slots do
		if isEgg(rec) and rec.State == "Incubating" then
			count += 1
		end
	end
	return count
end

-- Admin/teste e Instant Hatch (v20): choca todos os ovos do jogador agora. Devolve quantos.
function CritterService.HatchAllNow(player: Player): number
	local plot = Registry.Plots.Get(player)
	if not plot then
		return 0
	end
	local count = 0
	for _, rec in plot.Slots do
		if isEgg(rec) and rec.State == "Incubating" then
			rec.HatchAt = serverNow()
			rec.Model:SetAttribute("HatchAt", rec.HatchAt)
			count += 1
		end
	end
	return count
end

function CritterService.LoadForPlayer(player: Player, critters: any, eggs: any)
	local Plots = Registry.Plots
	local plot = Plots.Get(player)
	if not plot then
		return
	end
	local count = Registry.Economy.GetSlotCount(player)
	Plots.RefreshSlots(plot, count)
	local profile = Registry.Data.Get(player)

	local function slotFor(wanted: any): number?
		if type(wanted) == "number" and wanted >= 1 and wanted <= count and plot.Slots[wanted] == nil then
			return wanted
		end
		return Plots.FreeSlot(plot, count)
	end

	if type(critters) == "table" then
		for _, entry in critters do
			local def = if type(entry) == "table" then Critters.ById[entry.Id] else nil
			if def then
				local mutation = if type(entry.Mutation) == "string" and Config.MutationByName[entry.Mutation] then entry.Mutation else nil
				-- save antigo (antes da v9) não tem nascimento: já conta como gigante (renda cheia, como antes)
				local born = tonumber(entry.B) or (os.time() - 86400)
				local shiny = entry.S == true
				local slot = slotFor(entry.Slot)
				if slot then
					spawnPlaced(player, plot, slot, createRecord(def, mutation, born, shiny))
				elseif profile then
					table.insert(profile.Data.Pending, { Id = def.Id, Mutation = mutation, B = born, S = if shiny then true else nil })
				end
			end
		end
	end
	if type(eggs) == "table" then
		-- os ovos continuam chocando enquanto o jogador estava fora do jogo
		local lastOnline = if profile then tonumber(profile.Data.LastOnline) or 0 else 0
		local away = if lastOnline > 0 then math.max(0, os.time() - lastOnline) else 0
		local hatchedAway = {}
		for _, entry in eggs do
			local egg = if type(entry) == "table" then Config.EggById[entry.Id] else nil
			if egg then
				local result = validResult(entry.Result) or CritterService.RollResult(egg, player, 1)
				local savedLeft = math.clamp(tonumber(entry.Left) or egg.HatchTime, 0, egg.HatchTime)
				-- ovo de clima/noite não choca offline (só no clima certo)
				local left = if egg.Condition then savedLeft else math.max(0, savedLeft - away)
				local slot = slotFor(entry.Slot)
				if slot and left <= 0 then
					-- chocou enquanto estava fora: vira bichinho direto (sem tela de suspense para cada um)
					local def = Critters.ById[result.Id]
					local bornAt = if lastOnline > 0 then lastOnline + savedLeft else os.time()
					spawnPlaced(player, plot, slot, createRecord(def, result.Mutation, math.min(bornAt, os.time()), result.Shiny))
					Registry.Economy.Discover(player, def.Id)
					Registry.Economy.AddHatch(player)
					table.insert(hatchedAway, (if result.Shiny then "SHINY " else "") .. (if result.Mutation then result.Mutation .. " " else "") .. def.Name)
					local discoveries = Registry.Discoveries
					if def.Rarity == "Secret" and discoveries then
						task.spawn(discoveries.Claim, player, def.Id)
					end
				elseif slot then
					local rec = createEggRecord(egg, result)
					rec.HatchLeft = left
					spawnPlaced(player, plot, slot, rec)
				elseif profile then
					table.insert(profile.Data.Pending, { Egg = egg.Id, Result = result, Left = left })
				end
			end
		end
		if #hatchedAway > 0 then
			Registry.Remotes.Popup(player, "Your eggs hatched!", "While you were away you got:\n" .. table.concat(hatchedAway, ", "))
		end
	end
	CritterService.PlacePending(player)
end

-- Remove tudo do jogador (quando ele sai do jogo)
function CritterService.ClearOwnerCritters(player: Player)
	local plot = Registry.Plots.Get(player)
	if not plot then
		return
	end
	for _, rec in plot.Slots do
		local thief = rec.Thief
		destroyRecord(rec)
		if thief and thief.Parent then
			Registry.Remotes.Notify(thief, "What you were carrying vanished!", "warning")
		end
	end
	table.clear(plot.Slots)
end

-- Se o jogador estava carregando algo roubado, volta para o dono
function CritterService.DropCarried(player: Player)
	local carried = carrying[player]
	if carried then
		returnToOwner(carried, "left")
	end
end

function CritterService.Init()
	folder = Instance.new("Folder")
	folder.Name = "ActiveCritters"
	folder.Parent = workspace

	-- Uma esteira por mundo (Meadow = Map.Conveyor; os outros = Map.Worlds.<id>.Conveyor)
	local map = workspace:WaitForChild("Map")
	local worldsFolder = map:FindFirstChild("Worlds")
	for _, world in Config.Worlds do
		local belt: BasePart? = nil
		if world.Id == "meadow" then
			belt = map:FindFirstChild("Conveyor") :: BasePart?
		elseif worldsFolder then
			local area = worldsFolder:FindFirstChild(world.Id)
			belt = area and area:FindFirstChild("Conveyor") :: BasePart?
		end
		if belt and #Config.EggsOfWorld(world.Id) > 0 then
			lanes[world.Id] = {
				World = world.Id,
				StartX = belt.Position.X - belt.Size.X / 2 + 6,
				EndX = belt.Position.X + belt.Size.X / 2 - 6,
				Y = belt.Position.Y + belt.Size.Y / 2,
				Z = belt.Position.Z,
				List = {},
				Filled = false,
				Active = world.Id == "meadow",
			}
		end
	end

	local function fillLane(lane)
		if lane.Filled then
			return
		end
		lane.Filled = true
		local spacing = Config.ConveyorSpeed * Config.ConveyorSpawnInterval
		local x = lane.StartX + spacing
		while x < lane.EndX - 10 do
			CritterService.SpawnEggOnConveyor(CritterService.RandomEgg(lane.World), x, true)
			x += spacing
		end
	end

	-- Esteiras andando
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, lane in lanes do
			if not lane.Active then
				continue -- mundo sem ninguém: a esteira fica parada
			end
			local list = lane.List
			for i = #list, 1, -1 do
				local rec = list[i]
				if rec.Dead or rec.State ~= "Conveyor" then
					table.remove(list, i)
				else
					rec.X += Config.ConveyorSpeed * dt
					if rec.X >= lane.EndX then
						table.remove(list, i)
						destroyRecord(rec)
					else
						local hop = math.abs(math.sin((now + rec.Phase) * 5)) * 0.25
						local position = Vector3.new(rec.X, lane.Y + rec.Ground + hop, lane.Z)
						rec.Root.CFrame = CFrame.lookAt(position, position + Vector3.xAxis) * CFrame.Angles(0, 0, math.sin((now + rec.Phase) * 5) * 0.15)
					end
				end
			end
		end
	end)

	fillLaneFn = fillLane
	-- Enche a esteira do Meadow no começo (as outras enchem quando alguém chega no mundo)
	if lanes.meadow then
		fillLane(lanes.meadow)
	end

	-- Ovos novos (só nas esteiras de mundos com jogadores)
	task.spawn(function()
		while true do
			task.wait(Config.ConveyorSpawnInterval)
			local ok, err = pcall(function()
				local present = {}
				for _, player in Players:GetPlayers() do
					local world = player:GetAttribute("World")
					if typeof(world) == "string" then
						present[world] = true
					end
				end
				for id, lane in lanes do
					lane.Active = id == "meadow" or present[id] == true
					if lane.Active then
						if not lane.Filled then
							fillLane(lane)
						end
						CritterService.SpawnEggOnConveyor(CritterService.RandomEgg(id))
					end
				end
			end)
			if not ok then
				warn("[CritterService] loop error:", err)
			end
		end
	end)

	-- Chocar quando o tempo acaba (ovo de clima/noite: o tempo só corre no clima certo)
	task.spawn(function()
		local last = serverNow()
		while true do
			task.wait(0.25)
			local ok, err = pcall(function()
				local now = serverNow()
				local dt = now - last
				last = now
				for rec in incubating do
					if rec.Dead or rec.State ~= "Incubating" then
						incubating[rec] = nil
					elseif rec.EggDef.Condition and not conditionActive(rec.EggDef.Condition) then
						rec.HatchAt += dt -- esperando o clima: o relógio do ovo para
						if not rec.Waiting then
							rec.Waiting = true
							rec.Model:SetAttribute("WaitFor", rec.EggDef.Condition)
						end
						if now - rec.LastSync > 2 then
							rec.LastSync = now
							rec.Model:SetAttribute("HatchAt", rec.HatchAt)
						end
					else
						if rec.Waiting then
							rec.Waiting = false
							rec.Model:SetAttribute("WaitFor", nil)
							rec.Model:SetAttribute("HatchAt", rec.HatchAt)
						end
						if now >= rec.HatchAt then
							incubating[rec] = nil
							task.spawn(hatchEgg, rec)
						end
					end
				end
			end)
			if not ok then
				warn("[CritterService] loop error:", err)
			end
		end
	end)

	-- Crescimento e fim do carinho (a cada 10 s)
	task.spawn(function()
		while true do
			task.wait(10)
			local ok, err = pcall(function()
				local now = os.clock()
				for _, plot in Registry.Plots.All() do
					for _, rec in plot.Slots do
						if not isEgg(rec) and not rec.Dead then
							applyStage(rec)
							if rec.HappyUntil > 0 and rec.HappyUntil <= now then
								rec.HappyUntil = 0
								setHearts(rec, false)
								updateInfo(rec)
							elseif rec.FedUntil > 0 and rec.FedUntil <= now then
								rec.FedUntil = 0
								updateInfo(rec)
							end
						end
					end
				end
			end)
			if not ok then
				warn("[CritterService] loop error:", err)
			end
		end
	end)

	-- Some com os ovos da chuva que ninguém pegou
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				local now = os.clock()
				for i = #rainList, 1, -1 do
					local rec = rainList[i]
					if rec.Dead or rec.State ~= "Rain" then
						table.remove(rainList, i)
					elseif now >= rec.Expire then
						table.remove(rainList, i)
						destroyRecord(rec)
					end
				end
			end)
			if not ok then
				warn("[CritterService] loop error:", err)
			end
		end
	end)

	-- Confere quem está carregando algo roubado
	task.spawn(function()
		while true do
			task.wait(0.15)
			for thief, rec in carrying do
				-- cada roubo no seu próprio pcall: se um der erro, ele é descartado e os outros seguem
				local ok, err = pcall(function()
					if rec.Dead then
						carrying[thief] = nil
						return
					end
					local character = thief.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					local weld = rec.CarryWeld
					if not root or not humanoid or humanoid.Health <= 0 or not weld or weld.Part0 ~= root then
						returnToOwner(rec, "dropped")
					else
						local home = Registry.Plots.Get(thief)
						if home and Registry.Plots.IsInside(home, root.Position) then
							-- anti-teleporte: precisa ter levado um tempo mínimo para correr até a base
							local distance = (root.Position - (rec.CarryFrom or root.Position)).Magnitude
							local minimumTime = distance / (humanoid.WalkSpeed * 1.5 + 6)
							if os.clock() - (rec.CarryStart or 0) >= minimumTime then
								completeSteal(rec)
							else
								returnToOwner(rec, "invalid")
							end
						end
					end
				end)
				if not ok then
					warn("[CritterService] carry error:", err)
					pcall(returnToOwner, rec, "dropped") -- tenta devolver o bichinho ao dono
					carrying[thief] = nil
				end
			end
		end
	end)
end

return CritterService
