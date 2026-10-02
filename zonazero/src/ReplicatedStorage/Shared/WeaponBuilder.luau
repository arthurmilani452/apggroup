--[[
	WeaponBuilder (ModuleScript em ReplicatedStorage > Shared)
	Monta armas, curas e caixas de munição em 3D com peças.

	MODELOS 3D DE VERDADE: coloque um Model (ou MeshPart) dentro de ReplicatedStorage > Models3D
	com o MESMO nome da coisa (Pistol, SMG, Rifle, Shotgun, Sniper, Bandage, Medkit, ShieldCell, Ammo).
	O jogo usa esse modelo no lugar das peças: ajusta o tamanho sozinho e encaixa na mão.
	Dica: deixe o cano da arma apontando para a frente (-Z, o "Front" do Studio).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local WeaponBuilder = {}

local DARK = Color3.fromRGB(30, 32, 36)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

-- cilindro deitado ao longo do eixo Z (o Cylinder do Roblox fica no eixo X)
local function tube(parent: Instance, name: string, length: number, diameter: number, center: CFrame, color: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(length, diameter, diameter), center * CFrame.Angles(0, math.rad(90), 0), color, material, Enum.PartType.Cylinder)
end

local function weldAll(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

-- Usa um modelo 3D importado (Models3D) no lugar das peças, se existir
local function try3D(id: string, holder: Model, root: BasePart, length: number, center: CFrame): boolean
	local folder = ReplicatedStorage:FindFirstChild("Models3D")
	local source = folder and folder:FindFirstChild(id)
	if not source then
		return false
	end
	local clone = source:Clone()
	local model: Model
	if clone:IsA("Model") then
		model = clone
	elseif clone:IsA("BasePart") then
		model = Instance.new("Model")
		clone.Parent = model
	else
		clone:Destroy()
		return false
	end
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then
		model:ScaleTo(length / longest)
	end
	model:PivotTo(center)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- nada de scripts vindos de modelos importados
		end
	end
	model.Name = "Model3D"
	model.Parent = holder
	-- esconde as peças feitas por código (o modelo 3D toma o lugar delas)
	for _, d in holder:GetChildren() do
		if d:IsA("BasePart") and d ~= root and d.Name ~= "Glow" then
			d.Transparency = 1
		end
	end
	return true
end

local function rarityColor(rarity: string?): Color3
	for _, r in Config.Rarities do
		if r.Id == rarity then
			return r.Color
		end
	end
	return Config.Rarities[1].Color
end
WeaponBuilder.RarityColor = rarityColor

--[[ Monta a arma. Devolve (model, handle, muzzleAttachment).
	O Handle fica no lugar da mão; o cano aponta para -Z. ]]
function WeaponBuilder.Weapon(id: string, rarity: string?): (Model, BasePart, Attachment)
	local def = Config.Weapons[id] or Config.Weapons.Pistol
	local L = def.Length
	local accent = rarityColor(rarity)
	local model = Instance.new("Model")
	model.Name = id

	local handle = part(model, "Handle", Vector3.new(0.35, 0.8, 0.45), CFrame.new(0, -0.15, 0), DARK, Enum.Material.SmoothPlastic)
	local bodyLen = math.max(L * 0.45, 0.9)
	local bodyCenter = CFrame.new(0, 0.32, -bodyLen * 0.35)
	local body = part(model, "Body", Vector3.new(0.4, 0.42, bodyLen), bodyCenter, def.Color, Enum.Material.Metal)
	local barrelLen = math.max(L - bodyLen * 0.85 - (if id == "Pistol" then 0 else 0.6), 0.5)
	local barrelZ = body.Position.Z - bodyLen / 2 - barrelLen / 2 + 0.05
	tube(model, "Barrel", barrelLen, if id == "Shotgun" then 0.32 else 0.2, CFrame.new(0, 0.38, barrelZ), DARK, Enum.Material.Metal)
	-- faixa colorida da raridade
	part(model, "Glow", Vector3.new(0.42, 0.08, bodyLen * 0.7), bodyCenter * CFrame.new(0, 0.12, 0), accent, Enum.Material.Neon)

	if id ~= "Pistol" then
		-- coronha
		part(model, "Stock", Vector3.new(0.3, 0.45, 0.9), CFrame.new(0, 0.18, 0.55), def.Color, Enum.Material.Metal)
		-- pente
		local magH = if id == "Shotgun" then 0.25 else 0.75
		part(model, "Mag", Vector3.new(0.26, magH, 0.34), CFrame.new(0, 0.32 - 0.2 - magH / 2, body.Position.Z - bodyLen * 0.15) * CFrame.Angles(math.rad(10), 0, 0), DARK)
		-- guarda-mão
		part(model, "Handguard", Vector3.new(0.34, 0.3, math.min(barrelLen * 0.6, 1.4)), CFrame.new(0, 0.33, barrelZ + barrelLen * 0.15), def.Color, Enum.Material.Metal)
	end
	if id == "Rifle" or id == "Sniper" then
		-- luneta
		tube(model, "Scope", if id == "Sniper" then 1.4 else 0.8, if id == "Sniper" then 0.3 else 0.24, CFrame.new(0, 0.72, body.Position.Z), DARK, Enum.Material.Metal)
		part(model, "Lens", Vector3.new(0.2, 0.2, 0.04), CFrame.new(0, 0.72, body.Position.Z - (if id == "Sniper" then 0.71 else 0.41)), Color3.fromRGB(80, 180, 255), Enum.Material.Glass)
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = handle.CFrame:PointToObjectSpace(Vector3.new(0, 0.38, barrelZ - barrelLen / 2 - 0.1))
	muzzle.Parent = handle

	try3D(id, model, handle, L, CFrame.new(0, 0.3, -L * 0.3))
	weldAll(model, handle)
	model.PrimaryPart = handle
	return model, handle, muzzle
end

-- Curas e munição (para segurar na mão ou para o loot no chão)
function WeaponBuilder.Item(id: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = id
	local handle: BasePart
	if id == "Bandage" then
		handle = part(model, "Handle", Vector3.new(0.6, 0.6, 0.6), CFrame.new(), Color3.fromRGB(235, 230, 215), Enum.Material.Fabric, Enum.PartType.Cylinder)
		part(model, "Stripe", Vector3.new(0.62, 0.62, 0.15), CFrame.new(), Color3.fromRGB(200, 60, 60), Enum.Material.Fabric, Enum.PartType.Cylinder)
	elseif id == "Medkit" then
		handle = part(model, "Handle", Vector3.new(1.2, 0.8, 0.45), CFrame.new(), Color3.fromRGB(220, 50, 55), Enum.Material.SmoothPlastic)
		part(model, "CrossA", Vector3.new(0.5, 0.14, 0.47), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		part(model, "CrossB", Vector3.new(0.14, 0.5, 0.47), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		part(model, "Grip", Vector3.new(0.5, 0.15, 0.15), CFrame.new(0, 0.47, 0), DARK)
	elseif id == "ShieldCell" then
		handle = part(model, "Handle", Vector3.new(0.9, 0.5, 0.5), CFrame.new(), Color3.fromRGB(40, 45, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(model, "Glow", Vector3.new(0.6, 0.42, 0.42), CFrame.new(), Color3.fromRGB(70, 160, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
		model:PivotTo(CFrame.Angles(0, 0, math.rad(90)))
	else
		-- caixa de munição (id = tipo de munição)
		local ammo = Config.AmmoTypes[id]
		handle = part(model, "Handle", Vector3.new(0.9, 0.6, 0.6), CFrame.new(), Color3.fromRGB(70, 75, 60), Enum.Material.Metal)
		part(model, "Glow", Vector3.new(0.92, 0.15, 0.62), CFrame.new(0, 0.15, 0), if ammo then ammo.Color else Color3.new(1, 1, 1), Enum.Material.Neon)
		try3D("Ammo", model, handle, 0.9, CFrame.new())
		weldAll(model, handle)
		model.PrimaryPart = handle
		return model, handle
	end
	try3D(id, model, handle, 1.2, CFrame.new())
	weldAll(model, handle)
	model.PrimaryPart = handle
	return model, handle
end

return WeaponBuilder
