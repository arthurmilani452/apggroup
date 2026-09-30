--[[
	Mounts (ModuleScript em ServerScriptService > Game)
	Parte 22 (v13): MONTARIAS. Todas grátis, destravam pelo nível da conta (Config.Mounts):
	  • Skateboard (nível 1, +15% velocidade)  • Go-Kart (nível 5, +25%)  • Critter Ride (nível 12, +30%: você anda
	    em cima do seu melhor pet equipado)
	Regras: desce sozinho ao carregar um bichinho roubado ou entrar num minigame (não dá vantagem no roubo).
	O modelo é só visual (preso no personagem, sem colisão); a velocidade é do servidor (Economy.ApplySpeed).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Builder = require(ReplicatedStorage.Shared.CritterBuilder)
local Models3D = require(ReplicatedStorage.Shared.Models3D)
local Registry = require(script.Parent.Registry)

local Mounts = {}

local LIFT = { skate = 0.5, cart = 1.4, critter = 2.6 } -- quanto o personagem sobe (HipHeight)

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	return p
end

-- Monta o modelo com o centro em (0,0,0), frente para -Z
local function buildModel(id: string, player: Player): Model?
	-- modelo 3D (ReplicatedStorage > Models3D > skate / cart), se existir
	if id == "skate" or id == "cart" then
		local mesh, height = Models3D.Get(id, { Size = if id == "skate" then 4.4 else 5.4, Fit = "Max", Anchored = false })
		if mesh then
			-- pés em cima do skate (topo) ou sentado no meio do kart
			local topY = if id == "skate" then height - 0.1 else height * 0.55
			mesh:PivotTo(CFrame.new(0, -topY + 0.125, 0))
			mesh.WorldPivot = CFrame.identity
			mesh.Name = "Mount"
			return mesh
		end
	end
	local model = Instance.new("Model")
	model.Name = "Mount"
	if id == "skate" then
		local deck = part("Deck", Vector3.new(1.8, 0.25, 4.2), Color3.fromRGB(255, 120, 60), Enum.Material.WoodPlanks)
		deck.CFrame = CFrame.new()
		deck.Parent = model
		for _, x in { -0.65, 0.65 } do
			for _, z in { -1.5, 1.5 } do
				local wheel = part("Wheel", Vector3.new(0.4, 0.55, 0.55), Color3.fromRGB(40, 40, 50), nil, Enum.PartType.Cylinder)
				wheel.CFrame = CFrame.new(x, -0.3, z)
				wheel.Parent = model
			end
		end
		model.PrimaryPart = deck
	elseif id == "cart" then
		local body = part("Body", Vector3.new(3.4, 1.2, 5.2), Color3.fromRGB(230, 50, 60))
		body.CFrame = CFrame.new(0, 0, 0)
		body.Parent = model
		local seat = part("Seat", Vector3.new(2.2, 0.5, 2), Color3.fromRGB(30, 30, 40))
		seat.CFrame = CFrame.new(0, 0.8, 0.6)
		seat.Parent = model
		local nose = part("Nose", Vector3.new(3, 0.8, 1), Color3.fromRGB(255, 220, 60))
		nose.CFrame = CFrame.new(0, 0.1, -2.8)
		nose.Parent = model
		for _, x in { -1.9, 1.9 } do
			for _, z in { -1.8, 1.8 } do
				local wheel = part("Wheel", Vector3.new(0.7, 1.3, 1.3), Color3.fromRGB(30, 30, 35), nil, Enum.PartType.Cylinder)
				wheel.CFrame = CFrame.new(x, -0.4, z)
				wheel.Parent = model
			end
		end
		model.PrimaryPart = body
	elseif id == "critter" then
		-- o melhor pet equipado (ou o bichinho mais raro da base)
		local attribute = player:GetAttribute("Pets")
		local first = if typeof(attribute) == "string" then string.split(attribute, ",")[1] else nil
		local critterId, mutation = nil, nil
		if first and first ~= "" then
			critterId, mutation = string.match(first, "^([^:]+):?(.*)$")
		end
		local def = critterId and Critters.ById[critterId] or Critters.ById.fluffo
		local critter = Builder.Build(def)
		if mutation and mutation ~= "" then
			Builder.ApplyMutation(critter, mutation)
		end
		local aura = critter:FindFirstChild("Aura")
		if aura then
			aura:Destroy()
		end
		local _, size = critter:GetBoundingBox()
		pcall(function()
			critter:ScaleTo(math.clamp(3.2 / math.max(size.Y, 0.1), 0.3, 2.5))
		end)
		for _, descendant in critter:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
				descendant.Anchored = false
			end
		end
		critter:PivotTo(CFrame.new())
		return critter
	else
		model:Destroy()
		return nil
	end
	return model
end

local function insideAnyBase(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, plot in Registry.Plots.All() do
		if Registry.Plots.IsInside(plot, root.Position) then
			return true
		end
	end
	return false
end

function Mounts.Dismount(player: Player)
	local current = player:GetAttribute("Mounted")
	player:SetAttribute("Mounted", nil)
	local character = player.Character
	if character then
		local old = character:FindFirstChild("Mount")
		if old then
			old:Destroy()
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local baseHip = character:GetAttribute("BaseHip")
		if humanoid and typeof(baseHip) == "number" then
			humanoid.HipHeight = baseHip
		end
	end
	if current then
		Registry.Economy.ApplySpeed(player)
	end
end

function Mounts.Ride(player: Player, id: any)
	if id == "off" or id == nil then
		Mounts.Dismount(player)
		return
	end
	local mount = typeof(id) == "string" and Config.MountById[id]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not mount or not root or not humanoid or not player:GetAttribute("Loaded") then
		return
	end
	local level = if Registry.Progress then Registry.Progress.Level(player) else 1
	if level < mount.Level then
		Registry.Remotes.Notify(player, ("%s unlocks at level %d (you are level %d)."):format(mount.Name, mount.Level, level), "info")
		return
	end
	if player:GetAttribute("InMinigame") or Registry.CritterService.IsCarrying(player) or insideAnyBase(player) then
		Registry.Remotes.Notify(player, "You can't ride right now! (not inside bases, minigames or while carrying)", "info")
		return
	end
	Mounts.Dismount(player)
	local model = buildModel(mount.Id, player)
	if not model then
		return
	end
	if typeof(character:GetAttribute("BaseHip")) ~= "number" then
		character:SetAttribute("BaseHip", humanoid.HipHeight)
	end
	local baseHip = character:GetAttribute("BaseHip") :: number
	humanoid.HipHeight = baseHip + (LIFT[mount.Id] or 0)
	-- embaixo dos pés: a raiz fica HipHeight + metade dela acima do chão
	local below = humanoid.HipHeight + root.Size.Y / 2 - (LIFT[mount.Id] or 0) * 0.55
	model:PivotTo(root.CFrame * CFrame.new(0, -below, 0))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.Name = "Mount"
	model.Parent = character
	player:SetAttribute("Mounted", mount.Id)
	Registry.Economy.ApplySpeed(player)
end

-- Velocidade extra (Economy.ApplySpeed pergunta)
function Mounts.SpeedMultiplier(player: Player): number
	local id = player:GetAttribute("Mounted")
	local mount = typeof(id) == "string" and Config.MountById[id]
	return if mount then mount.Speed else 1
end

function Mounts.Init()
	local function watch(player: Player)
		-- personagem novo começa a pé (limpa ANTES de o novo nascer, senão a velocidade da montaria sobrava)
		player.CharacterRemoving:Connect(function()
			player:SetAttribute("Mounted", nil)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- desce sozinho: carregando bichinho roubado, em minigame ou dentro de uma base
	-- (dentro da base os pés precisam tocar no COLLECT e no LOCK BASE)
	task.spawn(function()
		while true do
			task.wait(0.4)
			local ok, err = pcall(function()
				for _, player in Players:GetPlayers() do
					if player:GetAttribute("Mounted") then
						if player:GetAttribute("InMinigame") or Registry.CritterService.IsCarrying(player) then
							Mounts.Dismount(player)
						elseif insideAnyBase(player) then
							Mounts.Dismount(player)
							Registry.Remotes.Notify(player, "No riding inside bases! You hopped off.", "info")
						end
					end
				end
			end)
			if not ok then
				warn("[Mounts] loop error:", err)
			end
		end
	end)
end

return Mounts
