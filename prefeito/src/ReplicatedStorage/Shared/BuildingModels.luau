--[[
	BuildingModels (ModuleScript em ReplicatedStorage > Shared)          Prefeito Tycoon
	Desenha cada prédio com Parts (nada de malha ou imagem: o lugar inteiro é gerado por código).
	Usado pelo servidor (prédios de verdade) e pelo cliente (fantasma do modo construção).

	API:
	  BuildingModels.Build(def) -> Model
	      Modelo sem girar, centrado em (0, 0, 0) com o chão em Y = 0. A "frente" olha para -Z
	      (para a avenida quando a rotação é 0). Quem chama faz PivotTo(cframe do centro * giro).
	  BuildingModels.MakeGhost(model, ok)   deixa transparente e pinta de verde/vermelho
]]

local Shared = script.Parent
local Config = require(Shared.Config)

local BuildingModels = {}

local CELL = Config.CellSize

local function rgb(c: { number }?, fallback: Color3?): Color3
	if not c then
		return fallback or Color3.new(1, 1, 1)
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = size.Y > 3
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local CONCRETE = Color3.fromRGB(150, 150, 150)
local ASPHALT = Color3.fromRGB(42, 44, 50)
local GRASS = Color3.fromRGB(70, 120, 60)

-- Torre com janelas: núcleo de neon + lajes e pilares por fora (as frestas viram as janelas acesas)
local function tower(m: Model, fw: number, fd: number, h: number, body: Color3, window: Color3, glass: boolean?)
	local w, d = fw - 1.4, fd - 1.4
	part(m, Vector3.new(w - 0.6, h - 1, d - 0.6), at(0, h / 2, 0), window, Enum.Material.Neon)
	if glass then
		local shell = part(m, Vector3.new(w, h, d), at(0, h / 2, 0), body, Enum.Material.Glass)
		shell.Transparency = 0.35
		shell.Reflectance = 0.15
	end
	local floorH = if glass then 10 else 5
	local y = 0
	while y < h do
		part(m, Vector3.new(w + 0.2, if glass then 0.8 else 2.2, d + 0.2), at(0, y + 0.6, 0), body, Enum.Material.Concrete)
		y += floorH
	end
	part(m, Vector3.new(w + 0.4, 1.2, d + 0.4), at(0, h + 0.6, 0), body, Enum.Material.Concrete)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, Vector3.new(1.2, h, 1.2), at(sx * (w / 2), h / 2, sz * (d / 2)), body, Enum.Material.Concrete)
		end
	end
	return h + 1.2
end

local builders: { [string]: (Model, any, number, number) -> () } = {}

builders.road = function(m, _def, fw, fd)
	part(m, Vector3.new(fw, 0.3, fd), at(0, 0.15, 0), ASPHALT, Enum.Material.Asphalt)
	local dash = part(m, Vector3.new(0.35, 0.05, fd * 0.4), at(0, 0.32, 0), Color3.fromRGB(230, 200, 80), Enum.Material.Neon)
	dash.CastShadow = false
end

builders.house = function(m, def, fw, fd)
	local s = def.Model
	local h = s.Height
	local w, d = fw - 2, fd - 2.5
	part(m, Vector3.new(w, h, d), at(0, h / 2, 0.5), rgb(s.Color), Enum.Material.Plaster)
	local roof = part(m, Vector3.new(w + 0.8, 1.2, d + 0.8), at(0, h + 0.6, 0.5), rgb(s.Roof), Enum.Material.Slate)
	roof.CastShadow = true
	-- janelas acesas na frente
	for floor = 0, math.floor(h / 6.5) - 1 do
		for _, sx in { -1, 1 } do
			part(m, Vector3.new(1.4, 1.6, 0.2), at(sx * w / 4, 3.6 + floor * 6, 0.5 - d / 2 - 0.05), Color3.fromRGB(255, 210, 130), Enum.Material.Neon)
		end
	end
	part(m, Vector3.new(1.4, 3, 0.2), at(0, 1.5, 0.5 - d / 2 - 0.05), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
end

builders.tower = function(m, def, fw, fd)
	local s = def.Model
	local top = tower(m, fw, fd, s.Height, rgb(s.Color), rgb(s.Window), s.Glass)
	if s.Spire then
		part(m, Vector3.new(0.8, 18, 0.8), at(0, top + 9, 0), CONCRETE, Enum.Material.Metal)
		part(m, Vector3.new(1.2, 1.2, 1.2), at(0, top + 18, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Ball)
	end
end

builders.shop = function(m, def, fw, fd)
	local s = def.Model
	local h = s.Height
	local w, d = fw - 1.6, fd - 1.6
	part(m, Vector3.new(w, h, d), at(0, h / 2, 0), rgb(s.Color), Enum.Material.Concrete)
	part(m, Vector3.new(w - 1, 3.5, 0.2), at(0, 2.2, -d / 2 - 0.05), Color3.fromRGB(255, 236, 180), Enum.Material.Neon)
	local awning = part(m, Vector3.new(w, 0.5, 2.2), at(0, 4.6, -d / 2 - 1), rgb(s.Awning), Enum.Material.Fabric)
	awning.CastShadow = false
	if s.Sign then
		part(m, Vector3.new(w * 0.6, 3, 0.4), at(0, h + 2, -d / 2 + 1), rgb(s.Awning), Enum.Material.Neon)
	end
	part(m, Vector3.new(w + 0.4, 0.8, d + 0.4), at(0, h + 0.4, 0), CONCRETE, Enum.Material.Concrete)
end

builders.factory = function(m, def, fw, fd)
	local s = def.Model
	local h = s.Height
	local w, d = fw - 1.6, fd - 1.6
	part(m, Vector3.new(w, h, d), at(0, h / 2, 0), rgb(s.Color), Enum.Material.CorrodedMetal)
	for i = 0, 2 do
		local roof = part(m, Vector3.new(w, 2, d / 3), at(0, h + 1, -d / 3 + i * d / 3) * CFrame.Angles(math.rad(-18), 0, 0), rgb(s.Color):Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Metal)
		roof.CastShadow = true
	end
	part(m, Vector3.new(w - 2, 1.2, 0.2), at(0, h * 0.6, -d / 2 - 0.05), Color3.fromRGB(255, 170, 70), Enum.Material.Neon)
	for i = 1, s.Chimneys or 1 do
		local x = w / 2 - 2 - (i - 1) * 4
		part(m, Vector3.new(h + 10, 2.4, 2.4), at(x, (h + 10) / 2, d / 2 - 2.5), Color3.fromRGB(110, 70, 60), Enum.Material.Brick, Enum.PartType.Cylinder).CFrame =
			at(x, (h + 10) / 2, d / 2 - 2.5) * CFrame.Angles(0, 0, math.rad(90))
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(120, 120, 120)
		smoke.Opacity = 0.15
		smoke.RiseVelocity = 4
		smoke.Size = 3
		local tip = part(m, Vector3.new(0.5, 0.5, 0.5), at(x, h + 10.5, d / 2 - 2.5), CONCRETE)
		tip.Transparency = 1
		tip.CanCollide = false
		smoke.Parent = tip
	end
end

builders.campus = function(m, def, fw, fd)
	local s = def.Model
	tower(m, fw * 0.55, fd * 0.8, s.Height, rgb(s.Color), rgb(s.Window), true)
	local wing = part(m, Vector3.new(fw * 0.4, 8, fd * 0.6), at(fw * 0.27, 4, 0), rgb(s.Color), Enum.Material.Glass)
	wing.Transparency = 0.2
	part(m, Vector3.new(fw * 0.38, 6.5, fd * 0.58), at(fw * 0.27, 3.5, 0), rgb(s.Window), Enum.Material.Neon)
end

builders.civic = function(m, def, fw, fd)
	local s = def.Model
	local h = s.Height
	local w, d = fw - 1.6, fd - 1.6
	part(m, Vector3.new(w, h, d), at(0, h / 2, 0), rgb(s.Color), Enum.Material.Concrete)
	part(m, Vector3.new(w + 0.4, 1, d + 0.4), at(0, h + 0.5, 0), rgb(s.Accent), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(w - 2, 1.4, 0.2), at(0, h * 0.55, -d / 2 - 0.05), Color3.fromRGB(240, 240, 210), Enum.Material.Neon)
	part(m, Vector3.new(3, 4, 0.3), at(0, 2, -d / 2 - 0.1), Color3.fromRGB(60, 70, 80), Enum.Material.Glass)
	-- placa com o símbolo
	local sign = part(m, Vector3.new(4, 4, 0.4), at(0, h + 3, -d / 2 + 0.5), rgb(s.Accent), Enum.Material.Neon)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = s.Icon or ""
	label.Parent = gui
	gui.Parent = sign
end

builders.tree = function(m, _def, _fw, _fd)
	part(m, Vector3.new(1, 5, 1), at(0, 2.5, 0), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
	part(m, Vector3.new(5.5, 5.5, 5.5), at(0, 6.5, 0), Color3.fromRGB(50, 110, 55), Enum.Material.Grass, Enum.PartType.Ball)
end

builders.plaza = function(m, _def, fw, fd)
	part(m, Vector3.new(fw - 0.4, 0.4, fd - 0.4), at(0, 0.2, 0), Color3.fromRGB(190, 180, 165), Enum.Material.Cobblestone)
	part(m, Vector3.new(1, 3.2, 3.2), at(0, 0.9, 0), CONCRETE, Enum.Material.Marble, Enum.PartType.Cylinder).CFrame =
		at(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	part(m, Vector3.new(0.6, 2.4, 2.6), at(0, 1.2, 0), Color3.fromRGB(80, 160, 230), Enum.Material.Neon, Enum.PartType.Cylinder).CFrame =
		at(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	part(m, Vector3.new(0.4, 6, 0.4), at(fw / 2 - 1, 3, fd / 2 - 1), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	part(m, Vector3.new(0.9, 0.9, 0.9), at(fw / 2 - 1, 6.2, fd / 2 - 1), Color3.fromRGB(255, 220, 160), Enum.Material.Neon, Enum.PartType.Ball)
end

builders.park = function(m, _def, fw, fd)
	part(m, Vector3.new(fw - 0.4, 0.4, fd - 0.4), at(0, 0.2, 0), GRASS, Enum.Material.Grass)
	part(m, Vector3.new(fw - 0.4, 0.45, 1.6), at(0, 0.22, 0), Color3.fromRGB(200, 180, 140), Enum.Material.Sand)
	for _, p in { { -0.3, -0.3 }, { 0.28, 0.25 }, { -0.25, 0.3 }, { 0.3, -0.28 } } do
		local x, z = p[1] * fw, p[2] * fd
		part(m, Vector3.new(1, 5, 1), at(x, 2.5, z), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
		part(m, Vector3.new(5, 5, 5), at(x, 6.5, z), Color3.fromRGB(60, 125, 60), Enum.Material.Grass, Enum.PartType.Ball)
	end
	part(m, Vector3.new(4, 0.5, 2.5), at(0, 0.5, fd * 0.25), Color3.fromRGB(70, 140, 210), Enum.Material.Glass)
end

builders.stadium = function(m, def, fw, fd)
	local color = rgb(def.Model.Color)
	part(m, Vector3.new(fw - 1, 0.5, fd - 1), at(0, 0.25, 0), color, Enum.Material.Concrete)
	part(m, Vector3.new(fw - 8, 0.6, fd - 8), at(0, 0.4, 0), Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
	for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local alongX = side[2] ~= 0
		local size = if alongX then Vector3.new(fw - 1, 7, 3.5) else Vector3.new(3.5, 7, fd - 1)
		local stand = part(m, size, at(side[1] * (fw / 2 - 2.25), 3.5, side[2] * (fd / 2 - 2.25)), color, Enum.Material.Concrete)
		stand.CastShadow = true
	end
	for _, c in { { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } } do
		part(m, Vector3.new(0.8, 16, 0.8), at(c[1] * (fw / 2 - 1), 8, c[2] * (fd / 2 - 1)), CONCRETE, Enum.Material.Metal)
		part(m, Vector3.new(3, 1.5, 1), at(c[1] * (fw / 2 - 1), 16.5, c[2] * (fd / 2 - 1)), Color3.fromRGB(255, 255, 230), Enum.Material.Neon)
	end
end

builders.spire = function(m, def, fw, fd)
	local h = def.Model.Height
	part(m, Vector3.new(fw - 2, 4, fd - 2), at(0, 2, 0), CONCRETE, Enum.Material.Concrete)
	local shaft = part(m, Vector3.new(h, 3.5, 3.5), at(0, h / 2, 0), Color3.fromRGB(225, 225, 230), Enum.Material.Concrete, Enum.PartType.Cylinder)
	shaft.CFrame = at(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	local pod = part(m, Vector3.new(11, 11, 11), at(0, h * 0.72, 0), rgb(def.Model.Color), Enum.Material.Glass, Enum.PartType.Ball)
	pod.Transparency = 0.2
	part(m, Vector3.new(9, 9, 9), at(0, h * 0.72, 0), Color3.fromRGB(255, 120, 120), Enum.Material.Neon, Enum.PartType.Ball)
	part(m, Vector3.new(1.4, 1.4, 1.4), at(0, h + 1, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Ball)
end

builders.generator = function(m, def, fw, fd)
	part(m, Vector3.new(fw - 1, 0.4, fd - 1), at(0, 0.2, 0), CONCRETE, Enum.Material.Concrete)
	part(m, Vector3.new(fw - 2.5, 3.6, fd - 3.5), at(0, 2.2, 0), rgb(def.Model.Color), Enum.Material.Metal)
	part(m, Vector3.new(0.8, 3, 0.8), at(1.5, 5, 1), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
	part(m, Vector3.new(0.6, 0.6, 0.2), at(-1, 2.6, -(fd - 3.5) / 2 - 0.1), Color3.fromRGB(80, 255, 80), Enum.Material.Neon)
end

builders.solar = function(m, _def, fw, fd)
	part(m, Vector3.new(fw - 0.6, 0.3, fd - 0.6), at(0, 0.15, 0), Color3.fromRGB(120, 115, 100), Enum.Material.Ground)
	local rows = math.max(2, math.floor(fd / 4))
	for i = 1, rows do
		local z = -fd / 2 + (i - 0.5) * fd / rows
		local panel = part(m, Vector3.new(fw - 2, 0.2, fd / rows - 1), at(0, 1.6, z) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(30, 50, 110), Enum.Material.Glass)
		panel.Reflectance = 0.3
	end
end

builders.wind = function(m, _def, fw, fd)
	part(m, Vector3.new(fw - 1, 0.4, fd - 1), at(0, 0.2, 0), GRASS, Enum.Material.Grass)
	local h = 34
	part(m, Vector3.new(1.4, h, 1.4), at(0, h / 2, 0), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	local hub = part(m, Vector3.new(2, 2, 2.6), at(0, h, -0.4), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	hub.Name = "Rotor"
	for i = 0, 2 do
		local blade = part(m, Vector3.new(0.6, 13, 0.3), at(0, h, -1.8) * CFrame.Angles(0, 0, math.rad(i * 120)) * CFrame.new(0, 6.5, 0), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
		blade.Name = "Blade"
	end
	part(m, Vector3.new(0.5, 0.5, 0.5), at(0, h + 1.2, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Ball)
end

builders.plant = function(m, def, fw, fd)
	local color = rgb(def.Model.Color)
	part(m, Vector3.new(fw - 1, 10, fd * 0.45), at(0, 5, -fd * 0.2), color, Enum.Material.Concrete)
	part(m, Vector3.new(fw - 3, 1.2, 0.2), at(0, 7, -fd * 0.2 - fd * 0.225 - 0.05), Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
	for _, x in { -fw / 4, fw / 4 } do
		local cool = part(m, Vector3.new(16, 8, 8), at(x, 8, fd * 0.22), Color3.fromRGB(200, 200, 200), Enum.Material.Concrete, Enum.PartType.Cylinder)
		cool.CFrame = at(x, 8, fd * 0.22) * CFrame.Angles(0, 0, math.rad(90))
		local steam = Instance.new("Smoke")
		steam.Color = Color3.fromRGB(235, 235, 235)
		steam.Opacity = 0.2
		steam.RiseVelocity = 6
		steam.Size = 5
		local tip = part(m, Vector3.new(0.5, 0.5, 0.5), at(x, 16.5, fd * 0.22), color)
		tip.Transparency = 1
		tip.CanCollide = false
		steam.Parent = tip
	end
end

function BuildingModels.Build(def: any): Model
	local model = Instance.new("Model")
	model.Name = def.Id
	local fw, fd = def.W * CELL, def.D * CELL
	-- base invisível do tamanho do terreno ocupado (serve de PrimaryPart e de alvo de clique)
	local base = part(model, Vector3.new(fw, 0.2, fd), at(0, 0.1, 0), CONCRETE)
	base.Name = "Base"
	base.Transparency = 1
	base.CanCollide = false
	base.CastShadow = false
	model.PrimaryPart = base
	if def.Category ~= "road" and def.Model.Kind ~= "plaza" and def.Model.Kind ~= "park" then
		-- calçada
		local walk = part(model, Vector3.new(fw - 0.2, 0.3, fd - 0.2), at(0, 0.15, 0), Color3.fromRGB(120, 120, 124), Enum.Material.Concrete)
		walk.CastShadow = false
	end
	local builder = builders[def.Model.Kind]
	if builder then
		builder(model, def, fw, fd)
	end
	return model
end

function BuildingModels.MakeGhost(model: Model, ok: boolean)
	local color = if ok then Color3.fromRGB(80, 230, 120) else Color3.fromRGB(240, 70, 70)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			if item.Name ~= "Base" then
				item.Transparency = 0.55
				item.Color = color
				item.Material = Enum.Material.ForceField
			else
				item.Transparency = 0.5
				item.Color = color
				item.Material = Enum.Material.Neon
			end
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
		elseif item:IsA("Smoke") or item:IsA("SurfaceGui") then
			item:Destroy()
		end
	end
end

return BuildingModels
