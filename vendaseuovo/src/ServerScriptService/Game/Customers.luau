--[[
	Customers: os clientes NPC da feira e o clima.
	Cada cliente entra por um portão do mercado, entra na fila de uma barraca, olha a vitrine e o preço,
	compra (ou recusa e vai embora bravo). As contas ficam em Shared/Market.

	O builder deixa em workspace.Market: Gate1, Gate1In, Gate2, Gate2In (entrada longe e entrada na praça).
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Market = require(ReplicatedStorage.Shared.Market)
local Registry = require(script.Parent.Registry)

local Customers = {}

local CFG = Config.Market
local CC = Config.Customers
local WALK_ANIM = "rbxassetid://180426354" -- caminhada R6 padrão do Roblox

type Customer = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Stand: any,
	Owner: Player,
	Vip: boolean,
	Alive: boolean,
	Walk: AnimationTrack?,
}

local queues: { [any]: { Customer } } = {}
local accumulators: { [any]: number } = {}
local alive = 0
local raining = false
local template: Model? = nil
local customersFolder: Folder

local SKIN = { Color3.fromRGB(255, 220, 185), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 134, 98), Color3.fromRGB(141, 85, 56), Color3.fromRGB(90, 56, 37) }
local SHIRTS = { Color3.fromRGB(230, 80, 80), Color3.fromRGB(80, 150, 230), Color3.fromRGB(90, 190, 110), Color3.fromRGB(240, 200, 60), Color3.fromRGB(170, 100, 210), Color3.fromRGB(250, 140, 60) }
local PANTS = { Color3.fromRGB(40, 50, 90), Color3.fromRGB(60, 60, 60), Color3.fromRGB(110, 80, 50), Color3.fromRGB(30, 90, 70) }

local function pick(list: { any }): any
	return list[math.random(1, #list)]
end

function Customers.IsRaining(): boolean
	return raining
end

-- ---------------------------------------------------------------------------
-- Modelo do cliente
-- ---------------------------------------------------------------------------
local function fallbackRig(): Model
	-- boneco simples feito de peças, caso o Roblox não monte o R6 (ex.: sem internet no Studio)
	local model = Instance.new("Model")
	model.Name = "Customer"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local function limb(name: string, size: Vector3, offset: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = root.CFrame * CFrame.new(offset)
		p.Massless = true
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	limb("Torso", Vector3.new(2, 2, 1), Vector3.zero)
	limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0))
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))
	limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
	limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildTemplate(): Model
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if ok and model then
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		model.Name = "Customer"
		return model
	end
	warn("[Customers] usando boneco simples:", model)
	return fallbackRig()
end

local function colorize(model: Model, vip: boolean)
	local skin = pick(SKIN)
	local shirt = if vip then Color3.fromRGB(255, 200, 40) else pick(SHIRTS)
	local pants = if vip then Color3.fromRGB(30, 30, 30) else pick(PANTS)
	local colors = {
		Head = skin,
		["Left Arm"] = skin,
		["Right Arm"] = skin,
		Torso = shirt,
		["Left Leg"] = pants,
		["Right Leg"] = pants,
	}
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = skin
		bodyColors.LeftArmColor3 = skin
		bodyColors.RightArmColor3 = skin
		bodyColors.TorsoColor3 = shirt
		bodyColors.LeftLegColor3 = pants
		bodyColors.RightLegColor3 = pants
	end
	for name, color in colors do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
	if vip then
		local head = model:FindFirstChild("Head") :: BasePart?
		if head then
			local crown = Instance.new("Part")
			crown.Name = "Crown"
			crown.Size = Vector3.new(1.2, 0.5, 1.2)
			crown.Color = Color3.fromRGB(255, 210, 40)
			crown.Material = Enum.Material.Neon
			crown.CanCollide = false
			crown.Massless = true
			crown.CFrame = head.CFrame * CFrame.new(0, 0.85, 0)
			crown.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = crown
			weld.Parent = crown
		end
	end
end

local function bubble(c: Customer, text: string, color: Color3)
	local head = c.Model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = head:FindFirstChild("Bubble") :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "Bubble"
		g.Size = UDim2.fromOffset(150, 46)
		g.StudsOffset = Vector3.new(0, 2.6, 0)
		g.AlwaysOnTop = false
		g.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = g
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.4, 0)
		corner.Parent = label
		g.Parent = head
		gui = g
	end
	local label = (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
	label.Text = text
	label.TextColor3 = color
end

-- ---------------------------------------------------------------------------
-- Andar
-- ---------------------------------------------------------------------------
local function playWalk(c: Customer, on: boolean)
	if c.Walk then
		if on and not c.Walk.IsPlaying then
			c.Walk:Play()
		elseif not on and c.Walk.IsPlaying then
			c.Walk:Stop(0.2)
		end
	end
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function walkTo(c: Customer, target: Vector3, timeout: number): boolean
	local started = os.clock()
	local issued = 0
	playWalk(c, true)
	while c.Alive and c.Model.Parent do
		if flatDistance(c.Root.Position, target) < 2 then
			return true
		end
		local now = os.clock()
		if now - started > timeout then
			return false
		end
		if now - issued > 3 then
			c.Humanoid:MoveTo(target)
			issued = now
		end
		task.wait(0.2)
	end
	return false
end

local function gateParts(stand: any): (BasePart?, BasePart?)
	local market = workspace:FindFirstChild("Market")
	if not market then
		return nil, nil
	end
	return market:FindFirstChild("Gate" .. stand.Gate) :: BasePart?, market:FindFirstChild("Gate" .. stand.Gate .. "In") :: BasePart?
end

local function leave(c: Customer)
	local queue = queues[c.Stand]
	if queue then
		local index = table.find(queue, c)
		if index then
			table.remove(queue, index)
		end
	end
	local gate, gateIn = gateParts(c.Stand)
	if gateIn then
		walkTo(c, gateIn.Position, 20)
	end
	if gate then
		walkTo(c, gate.Position, 20)
	end
	c.Alive = false
end

-- ---------------------------------------------------------------------------
-- Atender
-- ---------------------------------------------------------------------------
local function serve(c: Customer)
	local owner = c.Owner
	local stand = c.Stand
	if stand.Owner ~= owner then
		return
	end
	local data = Registry.Economy.Data(owner)
	if not data then
		return
	end
	if #data.Showcase == 0 then
		bubble(c, "😢 ?", Color3.fromRGB(90, 90, 90))
		Registry.Economy.AddRep(owner, CFG.RepEmpty, CFG.RepEmptyFloor)
		Registry.Stands.RefreshInfo(stand)
		return
	end
	local hasRaw, hasBoiled = false, false
	for _, item in data.Showcase do
		if item.R == "raw" then
			hasRaw = true
		elseif item.R == "boiled" then
			hasBoiled = true
		end
	end
	local recipeId = Market.PickRecipe(math.random(), hasRaw, hasBoiled, raining, CFG)
	if not recipeId then
		return
	end
	local options = {}
	for index, item in data.Showcase do
		if item.R == recipeId then
			table.insert(options, index)
		end
	end
	local index = options[math.random(1, #options)]
	local item = data.Showcase[index]
	local hen = Config.HenById[item.E]
	local recipe = Config.RecipeById[item.R]
	if not hen or not recipe then
		table.remove(data.Showcase, index)
		Registry.Stands.RefreshShowcase(stand)
		return
	end
	local suggested = hen.EggValue * recipe.Mult
	local mood = if raining and recipeId == "boiled" then CFG.RainBoiledBonus else 1
	-- o primeiro cliente de todo jogador novo sempre compra (o tutorial precisa da primeira venda)
	local roll = if data.Stats.Sold == 0 then 1 else math.random()
	local maxPrice = Market.MaxPrice(suggested, Registry.Economy.EffectiveRep(data), roll, mood, c.Vip, CFG)
	local markup = data.Markup[recipeId] or Config.Markup.Default
	local exact = Market.ExactPrice(hen.EggValue, recipe.Mult, markup)
	local bought = Market.Buys(exact, maxPrice)
	local repDelta = Market.RepChange(exact, maxPrice, bought, CFG)
	if bought then
		table.remove(data.Showcase, index)
		local paid = Market.Price(hen.EggValue, recipe.Mult, markup)
		data.Stats.Sold += 1
		data.Stats.Earned += paid
		Registry.Economy.AddMoney(owner, paid)
		Registry.Economy.AddRep(owner, repDelta)
		local happy = if repDelta > CFG.RepSale then "😍 " else "🙂 "
		bubble(c, happy .. "$" .. paid, Color3.fromRGB(30, 150, 60))
		Registry.Remotes.Fx:FireAllClients("money", stand.Parts.Counter.Position + Vector3.new(0, 3, 0), paid)
		Registry.Stands.RefreshShowcase(stand)
		Registry.Economy.Advance(owner, 2)
		if data.Stats.Sold == 1 or data.Stats.Sold % 50 == 0 then
			Registry.Economy.Log(owner, "Sales", data.Stats.Sold)
		end
		Registry.Economy.Log(owner, "SaleMarkup_" .. recipeId, markup)
	else
		data.Stats.Refused += 1
		Registry.Economy.AddRep(owner, repDelta)
		bubble(c, "😠 $$$!", Color3.fromRGB(200, 40, 40))
		Registry.Remotes.Fx:FireAllClients("refuse", stand.Parts.Counter.Position + Vector3.new(0, 3, 0), 0)
	end
	Registry.Stands.RefreshInfo(stand)
end

-- ---------------------------------------------------------------------------
-- Vida do cliente
-- ---------------------------------------------------------------------------
local function run(c: Customer)
	local stand = c.Stand
	local queue = queues[stand]
	local _, gateIn = gateParts(stand)
	if gateIn then
		walkTo(c, gateIn.Position, 20)
	end
	local joined = os.clock()
	local lastTarget: Vector3? = nil
	local issued = 0
	playWalk(c, true)
	while c.Alive and c.Model.Parent do
		if stand.Owner ~= c.Owner then
			leave(c)
			return
		end
		local index = table.find(queue, c) or #queue
		local spot = stand.Queue[math.clamp(index, 1, #stand.Queue)]
		if not spot then
			break
		end
		local target = spot.Position
		local now = os.clock()
		if lastTarget ~= target or now - issued > 3 then
			c.Humanoid:MoveTo(target)
			lastTarget = target
			issued = now
		end
		local arrived = flatDistance(c.Root.Position, target) < 2
		playWalk(c, not arrived)
		if index == 1 and arrived then
			c.Root.CFrame = CFrame.lookAt(c.Root.Position, Vector3.new(stand.Parts.Counter.Position.X, c.Root.Position.Y, stand.Parts.Counter.Position.Z))
			task.wait(CC.ServeTime)
			if c.Alive then
				local ok, err = pcall(serve, c)
				if not ok then
					warn("[Customers] serve:", err)
				end
				task.wait(0.8)
			end
			break
		end
		if now - joined > CC.Patience then
			bubble(c, "😴", Color3.fromRGB(90, 90, 90))
			break
		end
		task.wait(0.25)
	end
	leave(c)
end

local function spawnCustomer(stand: any, owner: Player)
	local gate = gateParts(stand)
	if not gate or not template then
		return
	end
	local vip = math.random() < CC.VipChance
	local model = template:Clone()
	colorize(model, vip)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		model:Destroy()
		return
	end
	humanoid.WalkSpeed = CC.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Customers"
		end
	end
	local offset = Vector3.new(math.random(-4, 4), 3, math.random(-4, 4))
	model:PivotTo(CFrame.new(gate.Position + offset))
	model.Parent = customersFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local c: Customer = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Stand = stand,
		Owner = owner,
		Vip = vip,
		Alive = true,
		Walk = nil,
	}
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		local animation = Instance.new("Animation")
		animation.AnimationId = WALK_ANIM
		c.Walk = animator:LoadAnimation(animation)
	end)
	table.insert(queues[stand], c)
	alive += 1
	if vip then
		Registry.Remotes.NotifyAll("VIP_ARRIVED", { name = owner.DisplayName }, "event")
	end
	task.spawn(function()
		local ok, err = pcall(run, c)
		if not ok then
			warn("[Customers] run:", err)
		end
		c.Alive = false
		local index = table.find(queues[stand], c)
		if index then
			table.remove(queues[stand], index)
		end
		model:Destroy()
		alive -= 1
	end)
	-- segurança: ninguém fica para sempre
	task.delay(CC.MaxLife, function()
		if model.Parent then
			c.Alive = false
		end
	end)
end

function Customers.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Customers")
		PhysicsService:RegisterCollisionGroup("Players")
		PhysicsService:CollisionGroupSetCollidable("Customers", "Customers", false)
		PhysicsService:CollisionGroupSetCollidable("Customers", "Players", false)
	end)
	customersFolder = Instance.new("Folder")
	customersFolder.Name = "Customers"
	customersFolder.Parent = workspace
	template = buildTemplate()
	for _, stand in Registry.Stands.All() do
		queues[stand] = {}
		accumulators[stand] = 0
	end
	workspace:SetAttribute("Weather", "sun")

	-- chegada de clientes
	task.spawn(function()
		local STEP = 0.5
		while true do
			task.wait(STEP)
			for _, stand in Registry.Stands.All() do
				local owner = stand.Owner
				local data = owner and Registry.Economy.Data(owner)
				if not owner or not data then
					accumulators[stand] = 0
					continue
				end
				local rate = Market.Rate(data.Rep, Registry.Economy.UpgradeValue(data, "Awning"), #data.Showcase > 0, raining, data.Stats.Sold, CFG)
				accumulators[stand] = math.min(accumulators[stand] + rate * STEP / 60, 2)
				if accumulators[stand] >= 1 and alive < CC.MaxAlive and #queues[stand] < CC.QueueSize then
					accumulators[stand] -= 1
					local ok, err = pcall(spawnCustomer, stand, owner)
					if not ok then
						warn("[Customers] spawn:", err)
					end
				end
			end
		end
	end)

	-- clima
	task.spawn(function()
		while true do
			task.wait(Config.Weather.Cycle)
			local nowRaining = math.random() < Config.Weather.RainChance
			if nowRaining ~= raining then
				raining = nowRaining
				local weather = if raining then "rain" else "sun"
				workspace:SetAttribute("Weather", weather)
				Registry.Remotes.NotifyAll("WEATHER_CHANGED_" .. weather, nil, "event")
			end
		end
	end)
end

return Customers
