--[[
	Stands: as 8 barracas da feira. Dá uma barraca para cada jogador que entra, devolve quando ele sai
	e desenha tudo o que fica nela (galinhas, ovos no ninho, panela, vitrine, portão).

	Cada barraca (workspace.Stands.StandN) é montada pelo builder e tem peças com estes nomes:
	  Counter, Slot1..12, Nest, Stove, Pot, GatePost, Gate, Zone, OwnerSpawn, Sign, PriceBoard,
	  HenSpot1..10, Queue1..4, Deco1..3
	Os textos das placas são desenhados por cada jogador (no idioma dele) a partir dos atributos da barraca.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Registry = require(script.Parent.Registry)

local Stands = {}

export type Stand = {
	Index: number,
	Model: Model,
	Owner: Player?,
	Gate: number,
	Parts: { [string]: BasePart },
	Slots: { BasePart },
	HenSpots: { BasePart },
	Queue: { BasePart },
	Visuals: Folder,
	HenModels: { [string]: Model },
	GateUntil: number,
	GateReadyAt: number,
	Prompts: { [string]: ProximityPrompt },
}

local stands: { Stand } = {}
local byPlayer: { [Player]: Stand } = {}

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Prompt "inteligente": o texto vem de uma chave (cada jogador vê no seu idioma) e
-- "For" diz quem vê: owner (dono), others (os outros), all, notthief (todos menos quem está roubando).
function Stands.MakePrompt(parent: Instance, keyText: string, keyObject: string, forWho: string, hold: number?, distance: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = keyText
	prompt.ObjectText = keyObject
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = distance or 10
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt:SetAttribute("Key", keyText)
	prompt:SetAttribute("Obj", keyObject)
	prompt:SetAttribute("For", forWho)
	prompt:SetAttribute("Active", true)
	prompt.Parent = parent
	CollectionService:AddTag(prompt, "VSOPrompt")
	return prompt
end

local function setOwnerAttr(stand: Stand)
	local ownerId = if stand.Owner then stand.Owner.UserId else 0
	for _, prompt in stand.Prompts do
		prompt:SetAttribute("Owner", ownerId)
	end
	for _, hen in stand.HenModels do
		for _, d in hen:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				d:SetAttribute("Owner", ownerId)
			end
		end
	end
end

function Stands.All(): { Stand }
	return stands
end

function Stands.Of(player: Player): Stand?
	return byPlayer[player]
end

function Stands.IsInside(stand: Stand, position: Vector3): boolean
	local zone = stand.Parts.Zone
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

function Stands.IsGateClosed(stand: Stand): boolean
	return os.clock() < stand.GateUntil
end

-- ---------------------------------------------------------------------------
-- Desenho
-- ---------------------------------------------------------------------------
local function clearChildren(f: Instance)
	for _, child in f:GetChildren() do
		child:Destroy()
	end
end

function Stands.RefreshNest(stand: Stand)
	local f = stand.Visuals:FindFirstChild("Nest") :: Folder
	clearChildren(f)
	local owner = stand.Owner
	local data = owner and Registry.Economy.Data(owner)
	local total = 0
	if data then
		local nest = stand.Parts.Nest
		local top = nest.Position + Vector3.new(0, nest.Size.Y / 2 + 0.35, 0)
		local i = 0
		for _, hen in Config.Hens do
			for _ = 1, data.Nest[hen.Id] or 0 do
				i += 1
				if i > Config.NestCapacity then
					break
				end
				local angle = i * 2.4
				local radius = 0.4 + 0.18 * i
				local egg = Models.Egg(hen.Egg)
				egg.CFrame = CFrame.new(top + Vector3.new(math.cos(angle) * radius * 0.6, (i // 7) * 0.4, math.sin(angle) * radius * 0.6))
					* CFrame.Angles(0.3, angle, 0)
				egg.Parent = f
			end
		end
		total = Registry.Economy.NestCount(data)
	end
	local prompt = stand.Prompts.Nest
	prompt:SetAttribute("Count", total)
	prompt:SetAttribute("Active", total > 0)
end

function Stands.RefreshShowcase(stand: Stand)
	local f = stand.Visuals:FindFirstChild("Showcase") :: Folder
	clearChildren(f)
	local owner = stand.Owner
	local data = owner and Registry.Economy.Data(owner)
	if not data then
		stand.Prompts.Steal:SetAttribute("Active", false)
		return
	end
	for i, item in data.Showcase do
		local slot = stand.Slots[i]
		local hen = Config.HenById[item.E]
		if slot and hen then
			local model = Models.Item(hen.Egg, item.R)
			model:PivotTo(slot.CFrame * CFrame.new(0, -slot.Size.Y / 2, 0))
			model.Parent = f
		end
	end
	stand.Prompts.Steal:SetAttribute("Active", #data.Showcase > 0)
	stand.Model:SetAttribute("Stock", #data.Showcase)
end

function Stands.RefreshStove(stand: Stand)
	local f = stand.Visuals:FindFirstChild("Stove") :: Folder
	clearChildren(f)
	local owner = stand.Owner
	local data = owner and Registry.Economy.Data(owner)
	local pot = stand.Parts.Pot
	local steam = pot:FindFirstChildOfClass("ParticleEmitter")
	local prompt = stand.Prompts.Stove
	if not data then
		if steam then
			steam.Enabled = false
		end
		return
	end
	local slots = Registry.Economy.UpgradeValue(data, "Stove")
	pot.Transparency = if slots > 0 then 0 else 0.6
	local now = os.time()
	local cooking, ready = 0, 0
	for i, slot in data.Stove do
		local hen = Config.HenById[slot.E]
		if hen then
			local egg = Models.Egg(if now >= slot.T then Color3.fromRGB(250, 250, 245) else hen.Egg)
			local angle = i * (math.pi * 2 / math.max(#data.Stove, 1))
			egg.CFrame = CFrame.new(pot.Position + Vector3.new(math.cos(angle) * 0.5, pot.Size.Y / 2, math.sin(angle) * 0.5))
			egg.Parent = f
		end
		if now >= slot.T then
			ready += 1
		else
			cooking += 1
		end
	end
	if steam then
		steam.Enabled = cooking > 0
	end
	if slots <= 0 then
		prompt:SetAttribute("Key", "P_STOVE_LOCKED")
	elseif ready > 0 then
		prompt:SetAttribute("Key", "P_COOK_TAKE")
	else
		prompt:SetAttribute("Key", "P_COOK")
	end
	stand.Model:SetAttribute("Cooking", cooking)
end

function Stands.RefreshHens(stand: Stand)
	local f = stand.Visuals:FindFirstChild("Hens") :: Folder
	local owner = stand.Owner
	local data = owner and Registry.Economy.Data(owner)
	local wanted: { [string]: number } = {}
	if data then
		local spot = 0
		for _, hen in data.Hens do
			if not Registry.Steal.IsHenCarried(hen.U) then
				spot += 1
				wanted[hen.U] = spot
			end
		end
	end
	for uid, model in stand.HenModels do
		if not wanted[uid] then
			model:Destroy()
			stand.HenModels[uid] = nil
		end
	end
	if not data then
		return
	end
	local ownerId = if owner then owner.UserId else 0
	for _, hen in data.Hens do
		local spotIndex = wanted[hen.U]
		local henConfig = Config.HenById[hen.Id]
		if spotIndex and henConfig then
			local model = stand.HenModels[hen.U]
			if not model then
				local m = Models.Hen(henConfig)
				m:SetAttribute("Uid", hen.U)
				m:SetAttribute("HenId", hen.Id)
				local root = m.PrimaryPart :: BasePart
				local sell = Stands.MakePrompt(root, "P_SELL_HEN", "H_" .. hen.Id, "owner", 1, 8)
				sell.Name = "Sell"
				sell:SetAttribute("Price", math.floor(henConfig.Price * Config.SellHenFraction))
				sell:SetAttribute("Owner", ownerId)
				sell.KeyboardKeyCode = Enum.KeyCode.F
				local steal = Stands.MakePrompt(root, "P_STEAL_HEN", "H_" .. hen.Id, "others", Config.Steal.HoldHen, 8)
				steal.Name = "Steal"
				steal:SetAttribute("Owner", ownerId)
				local uid = hen.U
				sell.Triggered:Connect(function(player)
					Registry.Farm.SellHen(player, stand, uid)
				end)
				steal.Triggered:Connect(function(player)
					Registry.Steal.GrabHen(player, stand, uid)
				end)
				CollectionService:AddTag(m, "VSOHen")
				m.Parent = f
				stand.HenModels[hen.U] = m
				model = m
			end
			local spotPart = stand.HenSpots[math.min(spotIndex, #stand.HenSpots)]
			if spotPart and model then
				model:PivotTo(spotPart.CFrame * CFrame.new(0, -spotPart.Size.Y / 2 + model.PrimaryPart.Size.Y / 2, 0))
			end
		end
	end
end

function Stands.RefreshDeco(stand: Stand)
	local owner = stand.Owner
	local data = owner and Registry.Economy.Data(owner)
	local level = if data then Registry.Economy.UpgradeLevel(data, "Awning") else 0
	for i = 1, 3 do
		local deco = stand.Parts["Deco" .. i]
		if deco then
			deco.Transparency = if level >= i then 0 else 1
			for _, d in deco:GetChildren() do
				if d:IsA("PointLight") then
					d.Enabled = level >= i
				end
			end
		end
	end
end

-- Atributos que as placas usam (nome, preços, estrelas, proteção)
function Stands.RefreshInfo(stand: Stand)
	local owner = stand.Owner
	local data = owner and Registry.Economy.Data(owner)
	local model = stand.Model
	model:SetAttribute("OwnerId", if owner then owner.UserId else 0)
	model:SetAttribute("OwnerName", if owner then owner.DisplayName else "")
	if data then
		model:SetAttribute("MarkupRaw", data.Markup.raw)
		model:SetAttribute("MarkupBoiled", data.Markup.boiled)
		model:SetAttribute("Rep", math.floor(data.Rep * 10) / 10)
		model:SetAttribute("Shield", Registry.Economy.ShieldLeft(data) > 0)
	else
		model:SetAttribute("Rep", 0)
		model:SetAttribute("Shield", false)
	end
	model:SetAttribute("GateClosed", Stands.IsGateClosed(stand))
end

function Stands.RefreshAll(stand: Stand)
	Stands.RefreshInfo(stand)
	Stands.RefreshNest(stand)
	Stands.RefreshShowcase(stand)
	Stands.RefreshStove(stand)
	Stands.RefreshHens(stand)
	Stands.RefreshDeco(stand)
end

local function showGate(stand: Stand, closed: boolean)
	local gate = stand.Parts.Gate
	gate.Transparency = if closed then 0.55 else 1
	stand.Model:SetAttribute("GateClosed", closed)
end

-- Fecha o portão do quintal (ninguém rouba galinha enquanto estiver fechado)
function Stands.CloseGate(player: Player, stand: Stand)
	if stand.Owner ~= player then
		return
	end
	local now = os.clock()
	if now < stand.GateReadyAt then
		Registry.Remotes.NotifyPlayer(player, "GATE_COOLDOWN", { time = math.ceil(stand.GateReadyAt - now) .. "s" }, "error")
		return
	end
	stand.GateUntil = now + Config.Steal.GateTime
	stand.GateReadyAt = now + Config.Steal.GateCooldown
	showGate(stand, true)
	Registry.Remotes.NotifyPlayer(player, "GATE_CLOSED_OK", { s = Config.Steal.GateTime }, "success")
	local closedUntil = stand.GateUntil
	task.delay(Config.Steal.GateTime, function()
		if stand.GateUntil == closedUntil then
			showGate(stand, false)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Dono entra / sai
-- ---------------------------------------------------------------------------
function Stands.Assign(player: Player): Stand?
	if byPlayer[player] then
		return byPlayer[player]
	end
	for _, stand in stands do
		if not stand.Owner then
			stand.Owner = player
			byPlayer[player] = stand
			stand.GateUntil = 0
			stand.GateReadyAt = 0
			showGate(stand, false)
			setOwnerAttr(stand)
			Stands.RefreshAll(stand)
			return stand
		end
	end
	return nil
end

function Stands.Release(player: Player)
	local stand = byPlayer[player]
	if not stand then
		return
	end
	byPlayer[player] = nil
	stand.Owner = nil
	setOwnerAttr(stand)
	for uid, model in stand.HenModels do
		model:Destroy()
		stand.HenModels[uid] = nil
	end
	for _, name in { "Nest", "Showcase", "Stove", "Hens" } do
		clearChildren(stand.Visuals:FindFirstChild(name) :: Folder)
	end
	showGate(stand, false)
	Stands.RefreshInfo(stand)
	Stands.RefreshNest(stand)
	Stands.RefreshShowcase(stand)
	Stands.RefreshStove(stand)
	Stands.RefreshDeco(stand)
end

function Stands.SpawnCFrame(stand: Stand): CFrame
	return stand.Parts.OwnerSpawn.CFrame + Vector3.new(0, 3, 0)
end

-- ---------------------------------------------------------------------------
function Stands.Init()
	local root = workspace:WaitForChild("Stands")
	local models = root:GetChildren()
	table.sort(models, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	for _, model in models do
		if not model:IsA("Model") then
			continue
		end
		local parts: { [string]: BasePart } = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				parts[child.Name] = child
			end
		end
		local function list(prefix: string): { BasePart }
			local out = {}
			local i = 1
			while parts[prefix .. i] do
				table.insert(out, parts[prefix .. i])
				i += 1
			end
			return out
		end
		local visuals = folder(model, "Visuals")
		for _, name in { "Nest", "Showcase", "Stove", "Hens" } do
			folder(visuals, name)
		end
		local stand: Stand = {
			Index = model:GetAttribute("Index") or (#stands + 1),
			Model = model,
			Owner = nil,
			Gate = model:GetAttribute("Gate") or 1,
			Parts = parts,
			Slots = list("Slot"),
			HenSpots = list("HenSpot"),
			Queue = list("Queue"),
			Visuals = visuals,
			HenModels = {},
			GateUntil = 0,
			GateReadyAt = 0,
			Prompts = {},
		}
		stand.Prompts.Nest = Stands.MakePrompt(parts.Nest, "P_COLLECT", "P_NEST", "owner", 0, 10)
		stand.Prompts.Stock = Stands.MakePrompt(parts.Counter, "P_STOCK", "P_SHOWCASE", "owner", 0, 10)
		stand.Prompts.Steal = Stands.MakePrompt(parts.Counter, "P_STEAL_BASKET", "P_SHOWCASE", "others", Config.Steal.HoldBasket, 9)
		stand.Prompts.Steal.UIOffset = Vector2.new(0, 60)
		stand.Prompts.Stove = Stands.MakePrompt(parts.Stove, "P_COOK", "P_STOVE", "owner", 0, 10)
		stand.Prompts.Gate = Stands.MakePrompt(parts.GatePost, "P_GATE", "P_GATE_NAME", "owner", 0.5, 10)
		stand.Prompts.Stock.KeyboardKeyCode = Enum.KeyCode.E
		stand.Prompts.Steal.KeyboardKeyCode = Enum.KeyCode.R

		stand.Prompts.Nest.Triggered:Connect(function(player)
			Registry.Farm.Collect(player, stand)
		end)
		stand.Prompts.Stock.Triggered:Connect(function(player)
			Registry.Farm.Stock(player, stand)
		end)
		stand.Prompts.Stove.Triggered:Connect(function(player)
			Registry.Farm.Cook(player, stand)
		end)
		stand.Prompts.Gate.Triggered:Connect(function(player)
			Stands.CloseGate(player, stand)
		end)
		stand.Prompts.Steal.Triggered:Connect(function(player)
			Registry.Steal.GrabBasket(player, stand)
		end)
		table.insert(stands, stand)
		setOwnerAttr(stand)
		Stands.RefreshAll(stand)
	end
end

return Stands
