--[[
	Explore (ModuleScript em ServerScriptService > Game)
	Parte 22 (v13): EXPLORAÇÃO.
	  • ILHA SECRETA: abre no minuto 30 de cada hora (UTC, igual em todo servidor) por 5 minutos.
	    O portal brilha na praça do Ovo Gigante. Lá: baús grátis (1 vez por dia cada) e o santuário do Island Egg.
	  • CAÇA AOS OVOS: 10 ovos escondidos no Meadow por dia (os mesmos lugares para todo mundo no mesmo dia).
	    Cada um dá 1 min de renda; os 10 dão um ovo grande grátis.
	  • PESCA no laguinho (leste): toque na hora certa (3 vezes). Peixes = dinheiro; às vezes um tesouro.
	  • ESCAVAÇÃO: buracos de areia pelo mapa. Às vezes sai um FOSSIL EGG (grátis!).
	  • SUBMARINO no Coral Reef: desce até uma sala no fundo do mar com baús e o Deep Sea Egg.
	Tudo conferido aqui (distância, tempo, limite por dia); a tela só mostra.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Explore = {}

local SETTINGS = Config.Explore

local function now(): number
	return workspace:GetServerTimeNow()
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(player: Player, position: Vector3, range: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= range
end

local function grant(player: Player, reward): string
	local codes = Registry.Codes
	if not codes then
		return ""
	end
	local ok, parts = pcall(codes.Grant, player, reward)
	return if ok and type(parts) == "table" then table.concat(parts, " + ") else ""
end

local function event(player: Player, kind: string)
	if Registry.Progress then
		Registry.Progress.Event(player, kind)
	end
end

local function canExplore(player: Player): boolean
	if not player:GetAttribute("Loaded") then
		return false
	end
	if player:GetAttribute("InMinigame") then
		Registry.Remotes.Notify(player, "Finish your minigame first!", "info")
		return false
	end
	if Registry.CritterService.IsCarrying(player) then
		Registry.Remotes.Notify(player, "Put down what you're carrying first!", "warning")
		return false
	end
	return true
end

local function sendTo(player: Player, cframe: CFrame)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cframe.Position, 4)
		end)
		local character = player.Character
		if character and character.Parent then
			character:PivotTo(cframe + Vector3.new(0, 3, 0))
		end
	end)
end

local function sendHome(player: Player)
	local plot = Registry.Plots.Get(player)
	if plot then
		player:SetAttribute("World", "meadow")
		sendTo(player, Registry.Plots.SpawnCFrame(plot))
	end
end

local function makePrompt(parent: Instance, action: string, object: string, hold: number, onTrigger: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onTrigger)
	prompt.Parent = parent
	return prompt
end

local function pick(options: { any }): any
	local total = 0
	for _, option in options do
		total += option.Weight
	end
	local roll = math.random() * total
	for _, option in options do
		roll -= option.Weight
		if roll <= 0 then
			return option
		end
	end
	return options[1]
end

-- (definida lá embaixo, na parte da ilha)
local islandOpenNow: () -> boolean

---------------------------------------------------------------------
-- Baús (ilha e submarino): cada um 1 vez por dia por jogador
---------------------------------------------------------------------
-- Contra teleporte: a ilha tem que estar aberta; o submarino exige o Coral Reef liberado
local function placeAllowed(player: Player, key: string): boolean
	if string.sub(key, 1, 6) == "island" then
		return islandOpenNow()
	end
	return Registry.Worlds.IsUnlocked(player, "reef")
end

function Explore.OpenChest(player: Player, key: string, part: BasePart)
	local data = getData(player)
	if not data or not near(player, part.Position, 16) or not placeAllowed(player, key) then
		return
	end
	if type(data.Chests) ~= "table" or data.Chests.Day ~= today() then
		data.Chests = { Day = today(), Opened = {} }
	end
	if data.Chests.Opened[key] then
		Registry.Remotes.Notify(player, "You already opened this chest today. It refills tomorrow!", "info")
		return
	end
	data.Chests.Opened[key] = true
	local reward = pick(SETTINGS.ChestRewards)
	local text = grant(player, { Minutes = reward.Minutes, WorldEgg = reward.WorldEgg })
	Registry.Remotes.Notify(player, "TREASURE! +" .. text, "rare")
	Registry.Remotes.Effect(player, "Chest", part.Position)
end

-- Ovos especiais comprados com dinheiro do jogo (santuário da ilha / loja do submarino)
function Explore.BuyEgg(player: Player, eggId: string, part: BasePart)
	local egg = Config.EggById[eggId]
	if not egg or not near(player, part.Position, 16) or not placeAllowed(player, if eggId == "islandegg" then "island" else "sub") then
		return
	end
	if not Registry.CritterService.HasFreeSlot(player) then
		Registry.Remotes.Notify(player, "Your base is full! Make space first.", "warning")
		return
	end
	if not Registry.Economy.TrySpend(player, egg.Price, "Explore") then
		Registry.Remotes.Notify(player, "Not enough cash! You need " .. Format.Money(egg.Price), "error")
		return
	end
	Registry.CritterService.GrantEgg(player, eggId)
	Registry.Remotes.Notify(player, "You got a " .. egg.Name .. "! It flew to your base.", "rare")
	Registry.Remotes.Effect(player, "Purchase", "Rare")
end

---------------------------------------------------------------------
-- ILHA SECRETA
---------------------------------------------------------------------
local islandVisit: { [Player]: number } = {}
local portalTouch: { [Player]: number } = {}

local forcedUntil = 0

-- Admin/teste: abre a ilha agora por alguns minutos
function Explore.ForceIsland(seconds: number)
	forcedUntil = os.time() + seconds
end

local function islandOpen(time: number): boolean
	if time < forcedUntil then
		return true
	end
	local minute = math.floor((time % 3600) / 60)
	return minute >= SETTINGS.IslandMinute and minute < SETTINGS.IslandMinute + SETTINGS.IslandMinutes
end

islandOpenNow = function(): boolean
	return islandOpen(os.time())
end

local function islandFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("SecretIsland")
end

local function onIsland(player: Player): boolean
	local root = rootOf(player)
	return root ~= nil and math.abs(root.Position.Z - 1000) < 200 and math.abs(root.Position.X) < 250
end

local function setPortal(open: boolean)
	local map = workspace:FindFirstChild("Map")
	local portal = map and map:FindFirstChild("SecretPortal")
	local disc = portal and portal:FindFirstChild("Disc") :: BasePart?
	if disc then
		disc.Transparency = if open then 0.25 else 1
		disc.CanTouch = open
	end
end

local function refreshIsland()
	local time = os.time()
	local open = islandOpen(time)
	local offset = now() - time
	local hour = math.floor(time / 3600)
	local opensAt = hour * 3600 + SETTINGS.IslandMinute * 60
	if time >= opensAt + SETTINGS.IslandMinutes * 60 then
		opensAt += 3600
	end
	local closesAt = if time < forcedUntil then forcedUntil else opensAt + SETTINGS.IslandMinutes * 60
	-- arredondado: o valor só muda quando a ilha muda (não reenviamos o atributo a cada segundo)
	workspace:SetAttribute("IslandUntil", if open then math.floor(closesAt + offset + 0.5) else nil)
	workspace:SetAttribute("IslandNext", if open then nil else math.floor(opensAt + offset + 0.5))
	if open ~= (workspace:GetAttribute("IslandOpen") == true) then
		workspace:SetAttribute("IslandOpen", open)
		setPortal(open)
		if open then
			Registry.Remotes.NotifyAll("The SECRET ISLAND is open for 5 minutes! Find the glowing portal next to the Giant Egg.", "rare")
			Registry.Remotes.EffectAll("IslandOpen")
		else
			for _, player in Players:GetPlayers() do
				if onIsland(player) then
					Registry.Remotes.Notify(player, "The Secret Island is sinking into the sea... back home you go!", "info")
					sendHome(player)
				end
			end
		end
	end
end

local function enterIsland(player: Player)
	if not islandOpen(os.time()) or os.clock() - (portalTouch[player] or 0) < 3 then
		return
	end
	portalTouch[player] = os.clock() -- o Touched dispara várias vezes: 1 tentativa a cada 3 s
	if not canExplore(player) then
		return
	end
	local island = islandFolder()
	local spawnPart = island and island:FindFirstChild("Spawn") :: BasePart?
	if not spawnPart then
		return
	end
	sendTo(player, spawnPart.CFrame)
	local hour = math.floor(os.time() / 3600)
	if islandVisit[player] ~= hour then
		islandVisit[player] = hour
		event(player, "Island")
		Registry.Remotes.Notify(player, "Welcome to the SECRET ISLAND! Open the chests and visit the shrine.", "rare")
	end
end

---------------------------------------------------------------------
-- CAÇA AOS OVOS
---------------------------------------------------------------------
-- lugares possíveis (x, z) no Meadow; o jogo acha o chão sozinho
local HUNT_SPOTS = {
	{ -280, -100 }, { -280, 100 }, { -230, -40 }, { -230, 40 }, { -170, -110 }, { -170, 110 }, { -130, -150 }, { -130, 150 },
	{ -60, -125 }, { -60, 125 }, { 0, -120 }, { 60, -120 }, { 60, 125 }, { 130, -150 }, { 130, 150 }, { 170, -110 },
	{ 170, 110 }, { 200, -60 }, { 200, 60 }, { 280, -100 }, { 280, 100 }, { 250, -62 }, { 250, 62 }, { 0, 60 },
	{ 80, 60 }, { -80, 60 }, { -80, -60 }, { 0, -60 }, { 80, -60 }, { -70, 175 }, { 100, 175 }, { -200, -170 },
}
local huntDay = -1
local huntEggs: { BasePart } = {}
local HUNT_COLORS = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 220, 80), Color3.fromRGB(150, 255, 130), Color3.fromRGB(200, 140, 255) }

local function huntState(player: Player): any
	local data = getData(player)
	if not data then
		return nil
	end
	if type(data.Hunt) ~= "table" or data.Hunt.Day ~= today() then
		data.Hunt = { Day = today(), Found = {} }
	end
	return data.Hunt
end

local function publishHunt(player: Player)
	local hunt = huntState(player)
	if not hunt then
		return
	end
	local found = {}
	for key in hunt.Found do
		table.insert(found, key)
	end
	player:SetAttribute("HuntFound", table.concat(found, ","))
	player:SetAttribute("HuntDay", hunt.Day)
end

function Explore.Hunt(player: Player, index: number)
	local egg = huntEggs[index]
	local hunt = huntState(player)
	if not egg or not hunt or not player:GetAttribute("Loaded") or not near(player, egg.Position, 14) then
		return
	end
	local key = tostring(index)
	if hunt.Found[key] then
		return
	end
	hunt.Found[key] = true
	local count = 0
	for _ in hunt.Found do
		count += 1
	end
	local text = grant(player, SETTINGS.HuntReward)
	event(player, "Hunt")
	Registry.Remotes.Effect(player, "HuntFound", { Position = egg.Position, Count = count })
	if count >= #huntEggs then
		local bonus = grant(player, SETTINGS.HuntBonus)
		event(player, "HuntDone")
		Registry.Remotes.Notify(player, ("ALL %d HUNT EGGS FOUND! Bonus: %s. New eggs tomorrow!"):format(#huntEggs, bonus), "rare")
	else
		Registry.Remotes.Notify(player, ("Hunt Egg %d/%d found! +%s"):format(count, #huntEggs, text), "success")
	end
	publishHunt(player)
end

local function buildHunt()
	local day = today()
	if day == huntDay then
		return
	end
	huntDay = day
	for _, egg in huntEggs do
		egg:Destroy()
	end
	huntEggs = {}
	local folder = workspace:FindFirstChild("HuntEggs") or Instance.new("Folder")
	folder.Name = "HuntEggs"
	folder.Parent = workspace
	local map = workspace:FindFirstChild("Map")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	for _, name in { "Decor", "Plots", "Boundaries" } do
		local child = map and map:FindFirstChild(name)
		if child then
			table.insert(ignore, child)
		end
	end
	for _, name in { "ActiveCritters", "ClientPets", "Monsters" } do
		local child = workspace:FindFirstChild(name)
		if child then
			table.insert(ignore, child)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	-- sorteio do dia (o mesmo em todos os servidores)
	local random = Random.new(day * 7777 + 1)
	local spots = table.clone(HUNT_SPOTS)
	for i = #spots, 2, -1 do
		local j = random:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	for index = 1, math.min(SETTINGS.HuntEggs, #spots) do
		local spot = spots[index]
		local hit = workspace:Raycast(Vector3.new(spot[1], 120, spot[2]), Vector3.new(0, -160, 0), params)
		local y = if hit then hit.Position.Y else 0
		local egg = Instance.new("Part")
		egg.Name = "HuntEgg" .. index
		egg.Shape = Enum.PartType.Ball
		egg.Size = Vector3.new(2, 2, 2)
		egg.Anchored = true
		egg.CanCollide = false
		egg.Material = Enum.Material.SmoothPlastic
		egg.Color = HUNT_COLORS[random:NextInteger(1, #HUNT_COLORS)]
		egg.CFrame = CFrame.new(spot[1], y + 1.5, spot[2])
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.3, 1)
		mesh.Parent = egg
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = Color3.fromRGB(255, 255, 200)
		sparkle.Parent = egg
		egg:SetAttribute("HuntIndex", index)
		egg:AddTag("Bob")
		egg:SetAttribute("BobHeight", 0.5)
		local prompt = makePrompt(egg, "Collect", "Hunt Egg", 0, function(player)
			Explore.Hunt(player, index)
		end)
		prompt.Name = "HuntPrompt"
		egg.Parent = folder
		huntEggs[index] = egg
	end
	workspace:SetAttribute("HuntCount", #huntEggs)
	for _, player in Players:GetPlayers() do
		publishHunt(player)
	end
end

---------------------------------------------------------------------
-- PESCA
---------------------------------------------------------------------
type Cast = { Id: number, At: number }
local casts: { [Player]: Cast } = {}
local lastCast: { [Player]: number } = {}
local nextCastId = 0

function Explore.FishStart(player: Player, spot: BasePart)
	local data = getData(player)
	if not data or not near(player, spot.Position, 16) or not canExplore(player) then
		return
	end
	if os.clock() - (lastCast[player] or 0) < SETTINGS.FishCooldown then
		return
	end
	if type(data.Fishing) ~= "table" or data.Fishing.Day ~= today() then
		data.Fishing = { Day = today(), Count = 0 }
	end
	if data.Fishing.Count >= SETTINGS.FishPerDay then
		Registry.Remotes.Notify(player, "The fish are sleeping! Come back tomorrow for more fishing.", "info")
		return
	end
	lastCast[player] = os.clock()
	nextCastId += 1
	casts[player] = { Id = nextCastId, At = os.clock() }
	Registry.Remotes.Effect(player, "FishStart", { Token = nextCastId })
end

-- A tela manda quantos toques certos (0 a 3); o servidor confere o tempo e sorteia o peixe
function Explore.FishCatch(player: Player, answer: any)
	local cast = casts[player]
	casts[player] = nil
	local data = getData(player)
	if not cast or not data or type(answer) ~= "table" or answer.Token ~= cast.Id then
		return
	end
	local elapsed = os.clock() - cast.At
	if elapsed < 1 or elapsed > 25 then
		Registry.Remotes.Notify(player, "The fish got away! Try again.", "info")
		return -- rápido demais (trapaça) ou demorou demais
	end
	local rawScore = tonumber(answer.Score) or 0
	if rawScore ~= rawScore then
		rawScore = 0 -- NaN (número inválido mandado por trapaça)
	end
	local score = math.clamp(math.floor(rawScore), 0, 3)
	if score == 0 then
		Registry.Remotes.Notify(player, "It got away! Try again.", "info")
		return
	end
	data.Fishing.Count += 1
	event(player, "Fish")
	local roll = math.random()
	local text
	if score == 3 and roll < 0.1 then
		text = "a TREASURE CHEST! +" .. grant(player, { WorldEgg = 1 })
	elseif score >= 2 and roll < 0.35 then
		text = "a BIG fish! +" .. grant(player, { Minutes = 1 })
	else
		text = "a fish! +" .. grant(player, { Minutes = 0.3 })
	end
	Registry.Remotes.Notify(player, "You caught " .. text, "success")
	Registry.Remotes.Effect(player, "FishCaught", score)
end

---------------------------------------------------------------------
-- ESCAVAÇÃO
---------------------------------------------------------------------
local DIGS_PER_DAY = 30

function Explore.Dig(player: Player, spot: BasePart)
	local data = getData(player)
	if not data or not near(player, spot.Position, 14) or not canExplore(player) then
		return
	end
	if type(data.Digging) ~= "table" or data.Digging.Day ~= today() then
		data.Digging = { Day = today(), Fossils = 0, Count = 0, Spots = {} }
	end
	local digging = data.Digging
	digging.Spots = if type(digging.Spots) == "table" then digging.Spots else {}
	digging.Count = tonumber(digging.Count) or 0
	-- o tempo de cada buraco fica SALVO (sair e entrar de novo não zera)
	local left = (tonumber(digging.Spots[spot.Name]) or -math.huge) + SETTINGS.DigCooldown - os.time()
	if left > 0 then
		Registry.Remotes.Notify(player, "You already dug here. Try another sand patch, or come back in " .. Format.Time(left) .. ".", "info")
		return
	end
	if digging.Count >= DIGS_PER_DAY then
		Registry.Remotes.Notify(player, "You're tired of digging today! Come back tomorrow.", "info")
		return
	end
	digging.Spots[spot.Name] = os.time()
	digging.Count += 1
	event(player, "Dig")
	Registry.Remotes.Effect(player, "Dig", spot.Position)
	local fossilsLeft = SETTINGS.FossilsPerDay - (tonumber(digging.Fossils) or 0)
	local roll = math.random()
	if roll < SETTINGS.FossilChance and fossilsLeft > 0 then
		digging.Fossils = (tonumber(digging.Fossils) or 0) + 1
		Registry.CritterService.GrantEgg(player, "fossilegg")
		event(player, "Fossil")
		Registry.Remotes.Notify(player, "WOW! You dug up a FOSSIL EGG! It went to your base.", "rare")
	elseif roll < 0.6 then
		Registry.Remotes.Notify(player, "You dug up some coins! +" .. grant(player, { Minutes = 0.5 }), "success")
	else
		Registry.Remotes.Notify(player, "Just dirt... try another sand patch!", "info")
	end
end

---------------------------------------------------------------------
-- SUBMARINO (Coral Reef)
---------------------------------------------------------------------
local function subRoom(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Submarine")
end

local function dive(player: Player, dock: BasePart)
	if not near(player, dock.Position, 16) or not canExplore(player) then
		return
	end
	local room = subRoom()
	local spawnPart = room and room:FindFirstChild("Spawn") :: BasePart?
	if spawnPart then
		sendTo(player, spawnPart.CFrame)
		Registry.Remotes.Notify(player, "Welcome aboard! Open the chests and look for the Deep Sea Egg.", "rare")
	end
end

local function surface(player: Player)
	local target = Registry.Worlds.SpawnCFrame("reef")
	if target then
		sendTo(player, target)
	else
		sendHome(player)
	end
end

---------------------------------------------------------------------
function Explore.SetupPlayer(player: Player)
	publishHunt(player)
end

function Explore.RemovePlayer(player: Player)
	casts[player] = nil
	lastCast[player] = nil
	islandVisit[player] = nil
	portalTouch[player] = nil
end

function Explore.Init()
	Players.PlayerRemoving:Connect(Explore.RemovePlayer)
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		-- ilha secreta: portal, volta, santuário e baús
		local portal = map:WaitForChild("SecretPortal", 20)
		local disc = portal and portal:FindFirstChild("Disc")
		if disc and disc:IsA("BasePart") then
			disc.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					enterIsland(player)
				end
			end)
		end
		local island = map:FindFirstChild("SecretIsland")
		if island then
			local back = island:FindFirstChild("ReturnPortal")
			if back and back:IsA("BasePart") then
				makePrompt(back, "Go home", "Return portal", 0, sendHome)
			end
			local shrine = island:FindFirstChild("Shrine")
			if shrine and shrine:IsA("BasePart") then
				makePrompt(shrine, "Buy Island Egg", Format.Money(Config.EggById.islandegg.Price), 1, function(player)
					Explore.BuyEgg(player, "islandegg", shrine)
				end)
			end
			for _, child in island:GetChildren() do
				if child:IsA("BasePart") and string.match(child.Name, "^Chest%d+$") then
					makePrompt(child, "Open", "Treasure chest", 0.6, function(player)
						Explore.OpenChest(player, "island:" .. child.Name, child)
					end)
				end
			end
		end
		-- pesca
		local pond = map:FindFirstChild("FishingPond")
		local fishSpot = pond and pond:FindFirstChild("Spot")
		if fishSpot and fishSpot:IsA("BasePart") then
			makePrompt(fishSpot, "Fish", "Fishing pond", 0, function(player)
				Explore.FishStart(player, fishSpot)
			end)
		end
		-- escavação
		local digs = map:FindFirstChild("DigSpots")
		if digs then
			for _, spot in digs:GetChildren() do
				if spot:IsA("BasePart") then
					makePrompt(spot, "Dig", "Sand patch", 1.5, function(player)
						Explore.Dig(player, spot)
					end)
				end
			end
		end
		-- submarino
		local worlds = map:FindFirstChild("Worlds")
		local reef = worlds and worlds:FindFirstChild("reef")
		local dock = reef and reef:FindFirstChild("SubDock", true)
		if dock and dock:IsA("BasePart") then
			makePrompt(dock, "Dive", "Submarine", 0.5, function(player)
				dive(player, dock)
			end)
		end
		local room = map:FindFirstChild("Submarine")
		if room then
			local hatch = room:FindFirstChild("Hatch")
			if hatch and hatch:IsA("BasePart") then
				makePrompt(hatch, "Surface", "Hatch", 0, surface)
			end
			local shop = room:FindFirstChild("Shop")
			if shop and shop:IsA("BasePart") then
				makePrompt(shop, "Buy Deep Sea Egg", Format.Money(Config.EggById.deepegg.Price), 1, function(player)
					Explore.BuyEgg(player, "deepegg", shop)
				end)
			end
			for _, child in room:GetChildren() do
				if child:IsA("BasePart") and string.match(child.Name, "^Chest%d+$") then
					makePrompt(child, "Open", "Treasure chest", 0.6, function(player)
						Explore.OpenChest(player, "sub:" .. child.Name, child)
					end)
				end
			end
		end
		buildHunt()
		setPortal(false)
		refreshIsland()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				refreshIsland()
				if today() ~= huntDay and huntDay ~= -1 then
					buildHunt() -- virou o dia: ovos novos
				end
			end)
			if not ok then
				warn("[Explore] loop error:", err)
			end
		end
	end)
end

return Explore
