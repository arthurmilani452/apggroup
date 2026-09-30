--[[
	GiantEgg (ModuleScript em ServerScriptService > Game)
	Parte 21: OVO GIGANTE DO SERVIDOR na praça atrás das bases.
	  • Todo mundo ajuda tocando no ovo ("Help hatch!"). A meta cresce com o número de jogadores.
	  • Quando enche, ele choca e TODO MUNDO que ajudou pelo menos 5 vezes ganha um bichinho
	    (as chances aparecem na placa do ovo, sem segredo). O bichinho é do mundo mais alto que você liberou.
	  • Depois espera 5 minutos e aparece outro.
	Contra trapaça: o servidor confere a distância e aceita no máximo ~5 toques por segundo por jogador.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local GiantEgg = {}

local SETTINGS = Config.GiantEgg
local TAP_GAP = 0.18
local RANGE = 22

local stand: BasePart? = nil
local eggPart: BasePart? = nil
local barFill: Frame? = nil
local statusLabel: TextLabel? = nil
local taps: { [number]: number } = {}
local lastTap: { [Player]: number } = {}
local total = 0
local goal = SETTINGS.BaseGoal
local state = "waiting" -- "open" (dá para tocar) ou "waiting" (esperando o próximo)
local nextAt = 0

local function oddsText(): string
	local parts = {}
	for _, info in Config.Rarities do
		local chance = SETTINGS.Odds[info.Name]
		if chance then
			table.insert(parts, ("%s %s%%"):format(info.Name, tostring(chance)))
		end
	end
	return table.concat(parts, " · ")
end

local function currentGoal(): number
	local count = #Players:GetPlayers()
	return math.clamp(SETTINGS.BaseGoal + SETTINGS.GoalPerPlayer * math.max(count - 1, 0), SETTINGS.BaseGoal, SETTINGS.MaxGoal)
end

local function updateBoard()
	if barFill then
		barFill.Size = UDim2.fromScale(if state == "open" then math.clamp(total / goal, 0, 1) else 0, 1)
	end
	if statusLabel then
		if state == "open" then
			statusLabel.Text = ("%d / %d taps"):format(total, goal)
		else
			statusLabel.Text = "Next Giant Egg in " .. Format.Time(math.max(0, nextAt - os.clock()))
		end
	end
	if stand then
		stand:SetAttribute("GiantState", state)
		stand:SetAttribute("GiantTotal", total)
		stand:SetAttribute("GiantGoal", goal)
	end
end

local function buildBoard(anchor: BasePart)
	-- tamanho em STUDS: fica pequeno de longe (não cobre a tela do celular)
	local gui = Instance.new("BillboardGui")
	gui.Name = "GiantEggBoard"
	gui.Size = UDim2.fromScale(18, 8.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 15, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = anchor
	local function text(y: number, height: number, value: string, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = value
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(30, 20, 60)
		stroke.Parent = label
		label.Parent = gui
		return label
	end
	text(0, 0.23, "GIANT EGG", Color3.fromRGB(255, 230, 90))
	text(0.23, 0.15, "Tap to help! Everyone who helps 5+ times wins a critter", Color3.new(1, 1, 1))
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0.06, 0.41)
	bar.Size = UDim2.fromScale(0.88, 0.16)
	bar.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	fill.Parent = bar
	bar.Parent = gui
	barFill = fill
	statusLabel = text(0.6, 0.17, "", Color3.new(1, 1, 1))
	text(0.79, 0.19, "Odds: " .. oddsText(), Color3.fromRGB(200, 215, 240))
	gui.Parent = anchor
end

local function spawnEgg()
	if not stand then
		return
	end
	taps = {}
	total = 0
	goal = currentGoal()
	state = "open"
	local egg = Instance.new("Part")
	egg.Name = "GiantEgg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(10, 10, 10)
	egg.Anchored = true
	egg.CanCollide = true
	egg.Material = Enum.Material.SmoothPlastic
	egg.Color = Color3.fromRGB(255, 240, 200)
	egg.CFrame = CFrame.new(stand.Position + Vector3.new(0, stand.Size.Y / 2 + 6, 0))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.3, 1)
	mesh.Parent = egg
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
	sparkles.Parent = egg
	egg:AddTag("Bob")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GiantPrompt"
	prompt.ActionText = "Help hatch!"
	prompt.ObjectText = "Giant Egg"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Triggered:Connect(function(player)
		GiantEgg.Tap(player)
	end)
	prompt.Parent = egg
	egg.Parent = stand.Parent
	eggPart = egg
	Registry.Remotes.NotifyAll("A GIANT EGG appeared behind the bases! Tap it together to hatch it!", "rare")
	updateBoard()
end

local function hatch()
	state = "waiting"
	nextAt = os.clock() + SETTINGS.Cooldown
	local egg = eggPart
	eggPart = nil
	local position = if egg then egg.Position elseif stand then stand.Position else Vector3.zero
	if egg then
		egg:Destroy()
	end
	Registry.Remotes.EffectAll("HatchBurst", { Position = position, Rarity = "Mythic" })
	local winners = 0
	for _, player in Players:GetPlayers() do
		local count = taps[player.UserId] or 0
		if count >= SETTINGS.MinTaps and player:GetAttribute("Loaded") then
			local def, shiny = Registry.CritterService.RollFromOdds(player, SETTINGS.Odds)
			if def and Registry.CritterService.GrantCritter(player, def.Id, nil, os.time(), shiny) then
				winners += 1
				Registry.Economy.Discover(player, def.Id)
				Registry.Economy.SeasonXP(player, "GiantEgg")
				Registry.Remotes.Notify(player, ("The Giant Egg hatched! You got %s%s (%s)!"):format(if shiny then "SHINY " else "", def.Name, def.Rarity), "rare")
				if def.Rarity == "Secret" and Registry.Discoveries then
					task.spawn(Registry.Discoveries.Claim, player, def.Id)
				end
			end
		elseif count > 0 then
			Registry.Remotes.Notify(player, ("The Giant Egg hatched! Help %d+ times next time to win a critter."):format(SETTINGS.MinTaps), "info")
		end
	end
	Registry.Remotes.NotifyAll(("The GIANT EGG hatched! %d helper(s) got a critter!"):format(winners), "rare")
	taps = {}
	total = 0
	updateBoard()
end

function GiantEgg.Tap(player: Player)
	if state ~= "open" or not eggPart or not player:GetAttribute("Loaded") then
		return
	end
	local now = os.clock()
	if now - (lastTap[player] or 0) < TAP_GAP then
		return
	end
	lastTap[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - eggPart.Position).Magnitude > RANGE then
		return
	end
	taps[player.UserId] = (taps[player.UserId] or 0) + 1
	total += 1
	if taps[player.UserId] == SETTINGS.MinTaps then
		Registry.Remotes.Notify(player, "You're a helper! You'll get a critter when the Giant Egg hatches.", "success")
	end
	Registry.Remotes.Effect(player, "GiantTap", taps[player.UserId])
	if total >= goal then
		hatch()
	else
		updateBoard()
	end
end

-- Votação "Giant Egg Now": aparece um agora (se já tiver um, avisa)
function GiantEgg.SpawnNow()
	if state == "open" then
		Registry.Remotes.NotifyAll("A Giant Egg is already waiting behind the bases. Go tap it!", "info")
		return
	end
	spawnEgg()
end

-- Admin: enche o ovo (você ganha como ajudante)
function GiantEgg.AdminFill(player: Player)
	if state ~= "open" then
		nextAt = 0
		spawnEgg()
	end
	taps[player.UserId] = math.max(taps[player.UserId] or 0, SETTINGS.MinTaps)
	total = goal
	hatch()
end

function GiantEgg.Init()
	local map = workspace:WaitForChild("Map")
	local plaza = map:WaitForChild("LivingPlaza", 10)
	local found = plaza and plaza:FindFirstChild("GiantEggStand")
	if not found or not found:IsA("BasePart") then
		warn("[GiantEgg] Map.LivingPlaza.GiantEggStand not found: Giant Egg is off")
		return
	end
	stand = found
	buildBoard(found)
	Players.PlayerRemoving:Connect(function(player)
		lastTap[player] = nil
	end)
	nextAt = os.clock() + 20 -- o primeiro aparece logo
	updateBoard()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				if state == "waiting" and os.clock() >= nextAt then
					spawnEgg()
				elseif state == "waiting" then
					updateBoard()
				end
			end)
			if not ok then
				warn("[GiantEgg] loop error:", err)
			end
		end
	end)
end

return GiantEgg
