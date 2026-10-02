--[[
	Loot: armas, munição e curas no chão.
	O mapa tem peças invisíveis "LootSpot" (Workspace > Map > LootSpots); no começo da partida
	cada uma pode receber um item. Quem morre deixa tudo cair no chão.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local WeaponBuilder = require(ReplicatedStorage.Shared.WeaponBuilder)
local Registry = require(script.Parent.Registry)

local Loot = {}

local rng = Random.new()
local folder: Folder

local function pickWeighted(list: { any }, weightKey: string): any
	local total = 0
	for _, item in list do
		total += item[weightKey]
	end
	local roll = rng:NextNumber() * total
	for _, item in list do
		roll -= item[weightKey]
		if roll <= 0 then
			return item
		end
	end
	return list[#list]
end

function Loot.RandomRarity(): string
	return pickWeighted(Config.Rarities, "Weight").Id
end

local function anchorAll(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
end

--[[ Cria um item no chão.
	info = { Kind = "Weapon"|"Ammo"|"Item", Id, Rarity?, Amount?, Mag? } ]]
function Loot.Spawn(info: any, position: Vector3): Model
	local model: Model
	local label: string
	if info.Kind == "Weapon" then
		info.Rarity = info.Rarity or Loot.RandomRarity()
		model = WeaponBuilder.Weapon(info.Id, info.Rarity)
		label = "W_" .. info.Id
	elseif info.Kind == "Ammo" then
		info.Amount = info.Amount or Config.AmmoTypes[info.Id].Pickup
		model = WeaponBuilder.Item(info.Id)
		label = "A_" .. info.Id
	else
		info.Amount = info.Amount or 1
		model = WeaponBuilder.Item(info.Id)
		label = "I_" .. info.Id
	end
	anchorAll(model)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0))
	model:SetAttribute("Kind", info.Kind)
	model:SetAttribute("Id", info.Id)
	model:SetAttribute("Rarity", info.Rarity)
	model:SetAttribute("Amount", info.Amount)
	model:SetAttribute("Mag", info.Mag)
	model:SetAttribute("Label", label) -- chave do texto (a tela traduz)

	local root = model.PrimaryPart :: BasePart
	-- brilho no chão com a cor da raridade (ajuda a achar no escuro)
	local light = Instance.new("PointLight")
	light.Range = 6
	light.Brightness = 0.8
	light.Color = if info.Kind == "Weapon" then WeaponBuilder.RarityColor(info.Rarity) else Color3.fromRGB(255, 240, 200)
	light.Shadows = false
	light.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = info.Id
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Loot.PickupRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		Loot.Take(player, model)
	end)

	CollectionService:AddTag(model, "Loot")
	model.Parent = folder
	return model
end

-- O jogador pegou um item do chão
function Loot.Take(player: Player, model: Model)
	if not model.Parent then
		return
	end
	local entry = Registry.Match.EntryFor(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not entry or not entry.Alive or not root or not model.PrimaryPart then
		return
	end
	if (root.Position - model.PrimaryPart.Position).Magnitude > Config.Loot.PickupRange + 4 then
		return
	end
	local Combat = Registry.Combat
	local kind, id = model:GetAttribute("Kind"), model:GetAttribute("Id")
	if kind == "Weapon" then
		local def = Config.Weapons[id]
		if not def then
			return
		end
		if Combat.WeaponCount(player) >= Config.Match.MaxWeapons then
			-- mochila cheia: troca pela arma que está na mão
			local held = character:FindFirstChildOfClass("Tool")
			if not held or not held:GetAttribute("WeaponId") then
				Registry.Remotes.NotifyPlayer(player, "BACKPACK_FULL", nil, "warning")
				return
			end
			Loot.Spawn({ Kind = "Weapon", Id = held:GetAttribute("WeaponId"), Rarity = held:GetAttribute("Rarity"), Mag = held:GetAttribute("Mag") }, root.Position + root.CFrame.LookVector * 2)
			held:Destroy()
		end
		local tool = Combat.MakeWeaponTool(id, model:GetAttribute("Rarity") or "Common", model:GetAttribute("Mag"))
		local backpack = player:FindFirstChildOfClass("Backpack")
		tool.Parent = backpack
		-- arma nova vai direto para a mão se a mão estiver vazia
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and not character:FindFirstChildOfClass("Tool") then
			humanoid:EquipTool(tool)
		end
		-- arma nova (nunca usada) vem com um pouco de munição de brinde; arma largada por alguém não
		if model:GetAttribute("Mag") == nil then
			Combat.AddAmmo(player, def.Ammo, math.floor(def.Mag / 2))
		end
	elseif kind == "Ammo" then
		local amount = model:GetAttribute("Amount") or 0
		local added = Combat.AddAmmo(player, id, amount)
		if added <= 0 then
			Registry.Remotes.NotifyPlayer(player, "AMMO_FULL")
			return
		end
		if added < amount then
			model:SetAttribute("Amount", amount - added) -- o que não coube fica no chão
			return
		end
	elseif kind == "Item" then
		Combat.GiveItem(player, id, model:GetAttribute("Amount") or 1)
	else
		return
	end
	Registry.Remotes.Event:FireClient(player, "Pickup", { Label = model:GetAttribute("Label") })
	model:Destroy()
end

-- Espalha o loot inicial nos LootSpots do mapa
function Loot.SpawnAll()
	Loot.Clear()
	local map = workspace:FindFirstChild("Map")
	local spots = map and map:FindFirstChild("LootSpots")
	if not spots then
		warn("[Loot] Workspace.Map.LootSpots não existe")
		return
	end
	for _, spot in spots:GetChildren() do
		if spot:IsA("BasePart") and rng:NextNumber() <= Config.Loot.SpotChance then
			local pick = pickWeighted(Config.Loot.Table, "Weight")
			Loot.Spawn({ Kind = pick.Kind, Id = pick.Id }, spot.Position)
			-- arma sempre vem com uma caixa da munição dela ao lado
			if pick.Kind == "Weapon" then
				local ammo = Config.Weapons[pick.Id].Ammo
				Loot.Spawn({ Kind = "Ammo", Id = ammo }, spot.Position + Vector3.new(2, 0, 1))
			end
			task.wait() -- não trava o servidor criando tudo de uma vez
		end
	end
end

function Loot.Clear()
	for _, child in folder:GetChildren() do
		child:Destroy()
	end
end

-- Tudo que o jogador tinha cai no chão em volta do corpo
function Loot.DropAll(player: Player, position: Vector3)
	local Combat = Registry.Combat
	local items = {}
	for _, tool in Combat.PlayerTools(player) do
		if tool:GetAttribute("WeaponId") then
			table.insert(items, { Kind = "Weapon", Id = tool:GetAttribute("WeaponId"), Rarity = tool:GetAttribute("Rarity"), Mag = tool:GetAttribute("Mag") })
		elseif tool:GetAttribute("ItemId") then
			table.insert(items, { Kind = "Item", Id = tool:GetAttribute("ItemId"), Amount = tool:GetAttribute("Count") })
		end
		tool:Destroy()
	end
	for ammoType in Config.AmmoTypes do
		local amount = player:GetAttribute("Ammo_" .. ammoType) or 0
		if amount > 0 then
			table.insert(items, { Kind = "Ammo", Id = ammoType, Amount = amount })
		end
	end
	Loot.DropList(items, position)
end

function Loot.DropList(items: { any }, position: Vector3)
	for i, info in items do
		local angle = (i / math.max(#items, 1)) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (2 + #items * 0.25)
		-- acha o chão embaixo
		local origin = position + offset + Vector3.new(0, 4, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local map = workspace:FindFirstChild("Map")
		params.FilterDescendantsInstances = if map then { map } else {}
		local hit = workspace:Raycast(origin, Vector3.new(0, -60, 0), params)
		Loot.Spawn(info, if hit then hit.Position else position + offset)
	end
end

function Loot.Init()
	folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = workspace
end

return Loot
