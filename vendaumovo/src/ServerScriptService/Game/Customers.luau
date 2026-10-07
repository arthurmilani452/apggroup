--[[
	Customers: clientes NPC que andam pela estrada asfaltada e param nas bancas das granjas.
	Cada um entra na fila (até Config.Customers.QueueSize), chega no balcão e leva de 1 a 3 ovos
	da cesta do dono da granja. O dinheiro cai na hora para o dono (mesmo se ele estiver longe).
	Tudo acontece no servidor; o cliente do jogador só vê os bonecos andando.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Registry = require(script.Parent.Registry)

local Customers = {}

local CC = Config.Customers
local ROAD_RADIUS = 232 -- meio da estrada asfaltada (igual ao builder: OUTER_R)
local WALK_ANIM = "rbxassetid://180426354" -- caminhada R6 padrão do Roblox

type Customer = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Plot: any,
	Owner: Player,
	Alive: boolean,
	Walk: AnimationTrack?,
	Start: number, -- ângulo na estrada onde nasceu
}

local queues: { [any]: { Customer } } = {}
local accumulators: { [any]: number } = {}
local alive = 0
local template: Model? = nil
local folder: Folder

local SKIN = { Color3.fromRGB(255, 220, 185), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 134, 98), Color3.fromRGB(141, 85, 56), Color3.fromRGB(90, 56, 37) }
local SHIRTS = { Color3.fromRGB(230, 80, 80), Color3.fromRGB(80, 150, 230), Color3.fromRGB(90, 190, 110), Color3.fromRGB(240, 200, 60), Color3.fromRGB(170, 100, 210), Color3.fromRGB(250, 140, 60) }
local PANTS = { Color3.fromRGB(40, 50, 90), Color3.fromRGB(60, 60, 60), Color3.fromRGB(110, 80, 50), Color3.fromRGB(30, 90, 70) }

local function pick(list: { any }): any
	return list[math.random(1, #list)]
end

-- ---------------------------------------------------------------------------
-- Boneco
-- ---------------------------------------------------------------------------
local function fallbackRig(): Model
	-- boneco simples de peças, caso o Roblox não monte o R6 (ex.: Studio sem internet)
	local model = Instance.new("Model")
	model.Name = "Cliente"
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
	humanoid.RequiresNeck = false -- sem junta de pescoço; sem isso o Roblox acha que o boneco morreu
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildTemplate(): Model
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if ok and model then
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		model.Name = "Cliente"
		return model
	end
	warn("[Customers] usando boneco simples:", model)
	return fallbackRig()
end

local function colorize(model: Model)
	local skin, shirt, pants = pick(SKIN), pick(SHIRTS), pick(PANTS)
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = skin
		bodyColors.LeftArmColor3 = skin
		bodyColors.RightArmColor3 = skin
		bodyColors.TorsoColor3 = shirt
		bodyColors.LeftLegColor3 = pants
		bodyColors.RightLegColor3 = pants
	end
	for name, color in { Head = skin, ["Left Arm"] = skin, ["Right Arm"] = skin, Torso = shirt, ["Left Leg"] = pants, ["Right Leg"] = pants } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
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
		g.Size = UDim2.fromOffset(120, 44)
		g.StudsOffset = Vector3.new(0, 2.6, 0)
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
-- Caminho: pela estrada em anel até a frente da granja, depois a fila
-- ---------------------------------------------------------------------------
local function plotAngle(plot: any): number
	local p = plot.Parts.Zone.Position
	return math.atan2(p.Z, p.X)
end

local function roadPoint(angle: number): Vector3
	return Vector3.new(math.cos(angle) * ROAD_RADIUS, 3, math.sin(angle) * ROAD_RADIUS)
end

-- Lugar k da fila: na calçada, em frente ao balcão e indo para o lado do portão
local function queueSpot(plot: any, k: number): Vector3
	local cf = plot.Parts.SellPoint.CFrame * CFrame.new(-5.5 * (k - 1), 0, -5)
	return Vector3.new(cf.Position.X, 3, cf.Position.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function playWalk(c: Customer, on: boolean)
	if not c.Walk then
		return
	end
	if on and not c.Walk.IsPlaying then
		c.Walk:Play()
	elseif not on and c.Walk.IsPlaying then
		c.Walk:Stop(0.2)
	end
end

local function walkTo(c: Customer, target: Vector3, timeout: number): boolean
	local started = os.clock()
	local issued = 0
	playWalk(c, true)
	while c.Alive and c.Model.Parent do
		if flatDistance(c.Root.Position, target) < 2.5 then
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

-- Anda pela estrada de "from" até "to" (ângulos), passando por pontos a cada ~8°
local function walkRoad(c: Customer, from: number, to: number)
	local diff = (to - from + math.pi) % (2 * math.pi) - math.pi
	local steps = math.max(1, math.floor(math.abs(diff) / math.rad(8)))
	for i = 1, steps do
		if not c.Alive then
			return
		end
		walkTo(c, roadPoint(from + diff * i / steps), 10)
	end
end

local function leaveQueue(c: Customer)
	local queue = queues[c.Plot]
	local index = queue and table.find(queue, c)
	if index then
		table.remove(queue, index)
	end
end

-- ---------------------------------------------------------------------------
-- Compra: leva ovos da cesta do dono
-- ---------------------------------------------------------------------------
local function serve(c: Customer)
	local owner = c.Owner
	local plot = c.Plot
	if plot.Owner ~= owner then
		return
	end
	local data = Registry.Economy.Data(owner)
	if not data then
		return
	end
	local want = math.random(CC.BuyMin, CC.BuyMax)
	local keys = {}
	for key, n in data.Basket do
		if n > 0 then
			table.insert(keys, key)
		end
	end
	if #keys == 0 then
		bubble(c, "😢", Color3.fromRGB(90, 90, 90))
		return
	end
	local value, taken = 0, 0
	while taken < want and #keys > 0 do
		local i = math.random(1, #keys)
		local key = keys[i]
		local eggId, rare = Formulas.ParseKey(key)
		data.Basket[key] -= 1
		if data.Basket[key] <= 0 then
			data.Basket[key] = nil
			table.remove(keys, i)
		end
		value += Formulas.EggValue(Config, eggId, rare)
		taken += 1
	end
	local paid = math.floor(value * Registry.Economy.Multiplier(owner) + 0.5)
	data.Stats.Sold += taken
	data.Stats.Customers += 1
	Registry.Economy.AddCoins(owner, paid, true)
	Registry.Economy.Mission(owner, "sell", taken)
	bubble(c, "😋 +" .. paid, Color3.fromRGB(30, 150, 60))
	Registry.Remotes.Fx:FireAllClients("money", plot.Parts.SellPoint.Position + Vector3.new(0, 4, 0), paid)
	Registry.Remotes.Fx:FireClient(owner, "customer", nil, paid)
	Registry.Economy.Push(owner)
end

local function run(c: Customer)
	local plot = c.Plot
	local angle = plotAngle(plot)
	local queue = queues[plot]
	walkRoad(c, c.Start, angle)
	local joined = os.clock()
	local lastTarget: Vector3? = nil
	local issued = 0
	while c.Alive and c.Model.Parent do
		if plot.Owner ~= c.Owner then
			break
		end
		local index = table.find(queue, c) or #queue
		local target = queueSpot(plot, math.clamp(index, 1, CC.QueueSize))
		local now = os.clock()
		if lastTarget ~= target or now - issued > 3 then
			c.Humanoid:MoveTo(target)
			lastTarget = target
			issued = now
		end
		local arrived = flatDistance(c.Root.Position, target) < 2.5
		playWalk(c, not arrived)
		if index == 1 and arrived then
			local counter = plot.Parts.SellPoint.Position
			c.Root.CFrame = CFrame.lookAt(c.Root.Position, Vector3.new(counter.X, c.Root.Position.Y, counter.Z))
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
	leaveQueue(c)
	-- volta para a estrada e segue em frente até sumir
	walkTo(c, roadPoint(angle), 12)
	walkRoad(c, angle, angle + (if math.random() < 0.5 then -1 else 1) * math.rad(30))
end

local function spawnCustomer(plot: any, owner: Player)
	if not template then
		return
	end
	local model = template:Clone()
	colorize(model)
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
	local side = if math.random() < 0.5 then -1 else 1
	local startAngle = plotAngle(plot) + side * math.rad(math.random(14, 28))
	model:PivotTo(CFrame.new(roadPoint(startAngle)))
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local c: Customer = { Model = model, Humanoid = humanoid, Root = root, Plot = plot, Owner = owner, Alive = true, Walk = nil, Start = startAngle }
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		local animation = Instance.new("Animation")
		animation.AnimationId = WALK_ANIM
		c.Walk = (animator :: Animator):LoadAnimation(animation)
	end)
	table.insert(queues[plot], c)
	alive += 1
	task.spawn(function()
		local ok, err = pcall(run, c)
		if not ok then
			warn("[Customers] run:", err)
		end
		c.Alive = false
		leaveQueue(c)
		model:Destroy()
		alive -= 1
	end)
	task.delay(CC.MaxLife, function()
		c.Alive = false -- ninguém fica para sempre
	end)
end

function Customers.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Customers")
		PhysicsService:RegisterCollisionGroup("Players")
		PhysicsService:CollisionGroupSetCollidable("Customers", "Customers", false)
		PhysicsService:CollisionGroupSetCollidable("Customers", "Players", false)
	end)
	folder = Instance.new("Folder")
	folder.Name = "Clientes"
	folder.Parent = workspace
	template = buildTemplate()
	for _, plot in Registry.Plots.All() do
		queues[plot] = {}
		accumulators[plot] = 0
	end

	task.spawn(function()
		local STEP = 0.5
		while true do
			task.wait(STEP)
			for _, plot in Registry.Plots.All() do
				local owner = plot.Owner
				local data = owner and Registry.Economy.Data(owner)
				if not owner or not data then
					accumulators[plot] = 0
					continue
				end
				local rate = Formulas.CustomerRate(Config, data, Formulas.BasketCount(data))
				accumulators[plot] = math.min(accumulators[plot] + rate * STEP / 60, 2)
				if accumulators[plot] >= 1 and alive < CC.MaxAlive and #queues[plot] < CC.QueueSize then
					accumulators[plot] -= 1
					local ok, err = pcall(spawnCustomer, plot, owner)
					if not ok then
						warn("[Customers] spawn:", err)
					end
				end
			end
		end
	end)
end

return Customers
