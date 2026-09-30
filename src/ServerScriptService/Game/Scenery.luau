--[[
	Scenery (ModuleScript em ServerScriptService > Game)
	Deixa o mapa bonito quando o jogo começa:
	  • TERRENO de verdade: morros de grama e lago com cachoeira no Meadow, morros de doce no Candy,
	    montanhas de neve no Frost, vulcão gigante no Lava, mar no Reef e asteroides no Galaxy
	  • PARTÍCULAS nas peças com a Tag "FX" (fumaça, fogo, neve, bolhas, brasas, névoa, fonte, brilho)
	  • TEXTO nas placas com a Tag "Sign"
	  • nuvens e cores do terreno
	Obs.: o terreno só aparece quando você aperta Play (ele é criado por este script).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Scenery = {}

local Terrain = workspace.Terrain
local M = Enum.Material

---------------------------------------------------------------------
-- Placas com texto
---------------------------------------------------------------------
local FACES = {
	Front = Enum.NormalId.Front,
	Back = Enum.NormalId.Back,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
	Top = Enum.NormalId.Top,
}

local function setupSign(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("SignGui") then
		return
	end
	local text = tostring(part:GetAttribute("Text") or "")
	local hex = part:GetAttribute("TextColor")
	local color = if typeof(hex) == "string" then Color3.fromHex(hex) else Color3.new(1, 1, 1)
	local faces = tostring(part:GetAttribute("Faces") or "Back")
	for _, faceName in string.split(faces, ",") do
		local face = FACES[faceName]
		if face then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "SignGui"
			gui.Face = face
			gui.LightInfluence = 0
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 30
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, -16, 1, -10)
			label.Position = UDim2.fromOffset(8, 5)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = color
			label.Text = text
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Color = Color3.fromRGB(20, 20, 35)
			stroke.Parent = label
			label.Parent = gui
			gui.Parent = part
		end
	end
end

---------------------------------------------------------------------
-- Partículas
---------------------------------------------------------------------
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function setupFx(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("SceneryFx") then
		return
	end
	local marker = Instance.new("Folder")
	marker.Name = "SceneryFx"
	marker.Parent = part
	local effect = part:GetAttribute("Effect")
	local big = part:GetAttribute("Big") == true
	local hex = part:GetAttribute("Color")
	local tint = if typeof(hex) == "string" then Color3.fromHex(hex) else Color3.fromRGB(255, 240, 180)
	local area = part.Size.X * part.Size.Z

	if effect == "Smoke" then
		emitter(part, {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(120, 120, 125), Color3.fromRGB(70, 70, 75)),
			Size = if big then seq(10, 30) else seq(3, 10),
			Transparency = seq(0.35, 1),
			Lifetime = NumberRange.new(4, 7),
			Rate = if big then 10 else 5,
			Speed = if big then NumberRange.new(10, 14) else NumberRange.new(4, 7),
			SpreadAngle = Vector2.new(12, 12),
			RotSpeed = NumberRange.new(-20, 20),
			EmissionDirection = Enum.NormalId.Top,
		})
	elseif effect == "Fire" then
		local fire = Instance.new("Fire")
		fire.Size = math.clamp(math.min(part.Size.X, part.Size.Z), 3, 25)
		fire.Heat = 14
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		fire.Parent = part
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 50)
		light.Range = math.clamp(fire.Size * 2, 10, 50)
		light.Brightness = 2
		light.Parent = part
	elseif effect == "Snow" then
		emitter(part, {
			Texture = SPARK,
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			LightEmission = 0.3,
			Size = seq(0.5, 0.35),
			Transparency = seq(0.1, 0.4),
			Lifetime = NumberRange.new(10, 13),
			Rate = math.clamp(area / 400, 20, 120),
			Speed = NumberRange.new(5, 8),
			SpreadAngle = Vector2.new(15, 15),
			EmissionDirection = Enum.NormalId.Bottom,
		})
	elseif effect == "Bubbles" then
		emitter(part, {
			Texture = SPARK,
			Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)),
			LightEmission = 0.4,
			Size = seq(0.4, 0.9),
			Transparency = seq(0.3, 0.9),
			Lifetime = NumberRange.new(4, 6),
			Rate = math.clamp(area / 1500, 10, 40),
			Speed = NumberRange.new(2, 4),
			EmissionDirection = Enum.NormalId.Top,
		})
	elseif effect == "Embers" then
		emitter(part, {
			Texture = SPARK,
			Color = ColorSequence.new(Color3.fromRGB(255, 180, 60), Color3.fromRGB(255, 80, 20)),
			LightEmission = 1,
			Size = seq(0.45, 0),
			Lifetime = NumberRange.new(1.5, 3),
			Rate = math.clamp(area / 60, 10, 40),
			Speed = NumberRange.new(3, 7),
			SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Top,
		})
	elseif effect == "Mist" then
		emitter(part, {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Size = seq(6, 14),
			Transparency = seq(0.55, 1),
			Lifetime = NumberRange.new(2.5, 4),
			Rate = 8,
			Speed = NumberRange.new(1, 3),
			EmissionDirection = Enum.NormalId.Top,
		})
	elseif effect == "Fountain" then
		emitter(part, {
			Texture = SPARK,
			Color = ColorSequence.new(Color3.fromRGB(150, 215, 255)),
			LightEmission = 0.3,
			Size = seq(0.7, 0.4),
			Transparency = seq(0.1, 0.6),
			Lifetime = NumberRange.new(1.2, 1.6),
			Rate = 60,
			Speed = NumberRange.new(18, 22),
			SpreadAngle = Vector2.new(10, 10),
			Acceleration = Vector3.new(0, -45, 0),
			EmissionDirection = Enum.NormalId.Top,
		})
	elseif effect == "Sparkles" then
		emitter(part, {
			Texture = SPARK,
			Color = ColorSequence.new(tint),
			LightEmission = 1,
			Size = seq(0.5, 0),
			Lifetime = NumberRange.new(1.5, 2.5),
			Rate = math.clamp(area / 20, 6, 25),
			Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(180, 180),
		})
	end
end

---------------------------------------------------------------------
-- Terreno
---------------------------------------------------------------------
local function block(center: Vector3, size: Vector3, material: Enum.Material)
	Terrain:FillBlock(CFrame.new(center), size, material)
end

local function ballAt(center: Vector3, radius: number, material: Enum.Material)
	Terrain:FillBall(center, radius, material)
end

-- Morros em volta de um retângulo (x0..x1, z0..z1): ficam do lado de fora, sem invadir a área de jogo
local function hillRing(x0: number, x1: number, z0: number, z1: number, rng: Random, materials: { Enum.Material }, rMin: number, rMax: number, step: number, skip: ((number, number) -> boolean)?)
	local tops = {}
	local function hill(cx: number, cz: number, r: number)
		if skip and skip(cx, cz) then
			return
		end
		local cy = -r * 0.4
		ballAt(Vector3.new(cx, cy, cz), r, materials[rng:NextInteger(1, #materials)])
		table.insert(tops, Vector3.new(cx, cy + r, cz))
	end
	local x = x0
	while x <= x1 do
		local r = rng:NextNumber(rMin, rMax)
		hill(x, z0 - r, r)
		r = rng:NextNumber(rMin, rMax)
		hill(x, z1 + r, r)
		x += step
	end
	local z = z0
	while z <= z1 do
		local r = rng:NextNumber(rMin, rMax)
		hill(x0 - r, z, r)
		r = rng:NextNumber(rMin, rMax)
		hill(x1 + r, z, r)
		z += step
	end
	return tops
end

local function makeTree(position: Vector3, scale: number, parent: Instance)
	local tree = Instance.new("Model")
	tree.Name = "HillTree"
	local function add(shape: Enum.PartType, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Shape = shape
		p.Size = size
		p.CFrame = CFrame.new(position + offset)
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = tree
	end
	add(Enum.PartType.Block, Vector3.new(2, 10, 2) * scale, Vector3.new(0, 4 * scale, 0), Color3.fromRGB(125, 85, 55), M.Wood)
	add(Enum.PartType.Ball, Vector3.one * 11 * scale, Vector3.new(0, 11 * scale, 0), Color3.fromRGB(80, 175, 75), M.Grass)
	add(Enum.PartType.Ball, Vector3.one * 7 * scale, Vector3.new(1, 15 * scale, 0), Color3.fromRGB(105, 195, 85), M.Grass)
	tree.Parent = parent
end

local function buildMeadow(rng: Random, decor: Instance)
	-- chão de grama em volta do mapa (fora da área de jogo, um pouco mais baixo)
	block(Vector3.new(0, -4.5, -360), Vector3.new(1400, 8, 300), M.Grass)
	block(Vector3.new(0, -4.5, 360), Vector3.new(1400, 8, 300), M.Grass)
	block(Vector3.new(-500, -4.5, 0), Vector3.new(400, 8, 420), M.Grass)
	block(Vector3.new(500, -4.5, 0), Vector3.new(400, 8, 420), M.Grass)
	-- penhasco com cachoeira e lago (atrás das bases de cima, à esquerda)
	block(Vector3.new(-200, 20, -296), Vector3.new(80, 52, 48), M.Rock)
	ballAt(Vector3.new(-250, 10, -300), 30, M.Rock)
	ballAt(Vector3.new(-150, 8, -300), 28, M.Rock)
	block(Vector3.new(-200, -3.5, -246), Vector3.new(80, 7, 40), M.Water)
	-- morros de grama em volta de tudo
	local tops = hillRing(-300, 300, -210, 210, rng, { M.Grass, M.Grass, M.LeafyGrass }, 45, 80, 70, function(x, z)
		return z < -210 and ((x > -280 and x < -120) or (x > 190 and x < 290))
	end)
	for i, top in tops do
		if i % 2 == 0 then
			makeTree(top, rng:NextNumber(1, 1.5), decor)
		end
	end
end

local function buildWorldTerrain(worldId: string, X0: number, rng: Random)
	-- v27: o chão de terreno ficava 0,5 acima do piso e escondia a esteira, os caminhos e os rios dos mundos.
	-- Agora o topo fica em -2,5 (embaixo do chão da ilha, que vai de -2 a 0).
	local minX, maxX = X0 - 160, X0 + 160
	if worldId == "candy" then
		block(Vector3.new(X0, -6.5, 0), Vector3.new(820, 8, 680), M.Salt)
		hillRing(minX, maxX, -90, 90, rng, { M.Salt, M.Limestone, M.Mud }, 28, 55, 55)
	elseif worldId == "frost" then
		block(Vector3.new(X0, -6.5, 0), Vector3.new(820, 8, 680), M.Snow)
		-- montanhas nevadas atrás (norte), com topo de gelo
		for _, spec in { { -120, 85 }, { 10, 100 }, { 135, 80 } } do
			local cx, r = X0 + spec[1], spec[2]
			local center = Vector3.new(cx, -r * 0.25, -90 - r)
			ballAt(center, r, M.Snow)
			ballAt(center + Vector3.new(0, r * 0.62, 0), r * 0.42, M.Glacier)
		end
		hillRing(minX, maxX, -90, 90, rng, { M.Snow, M.Snow, M.Ice }, 22, 42, 60, function(_, z)
			return z < -90
		end)
	elseif worldId == "lava" then
		block(Vector3.new(X0, -6.5, 0), Vector3.new(820, 8, 680), M.Basalt)
		-- vulcão gigante (norte)
		local vz = -190
		for level = 0, 8 do
			local radius = 95 - level * 8.75
			Terrain:FillCylinder(CFrame.new(X0, 4 + level * 8, vz), 8, radius, if level >= 7 then M.CrackedLava else M.Basalt)
		end
		Terrain:FillCylinder(CFrame.new(X0, 71, vz), 6, 13, M.Air)
		hillRing(minX, maxX, -90, 90, rng, { M.Basalt, M.CrackedLava, M.Basalt }, 20, 38, 60, function(_, z)
			return z < -90
		end)
	elseif worldId == "reef" then
		-- mar em volta da ilha
		block(Vector3.new(X0, -16, 0), Vector3.new(900, 8, 700), M.Sand)
		block(Vector3.new(X0, -7, 0), Vector3.new(900, 10, 700), M.Water)
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			ballAt(Vector3.new(X0 + math.cos(angle) * 300, -12, math.sin(angle) * 220), rng:NextNumber(25, 40), M.Sand)
		end
	elseif worldId == "galaxy" then
		-- asteroides flutuando no espaço
		for _ = 1, 16 do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local center = Vector3.new(X0 + rng:NextNumber(-260, 260), rng:NextNumber(-30, 60), side * rng:NextNumber(120, 220))
			ballAt(center, rng:NextNumber(8, 22), M.Asphalt)
		end
	end
end

local function buildTerrain()
	pcall(function()
		(Terrain :: any).Decoration = true
	end)
	Terrain.WaterColor = Color3.fromRGB(45, 175, 210)
	Terrain.WaterTransparency = 0.45
	Terrain.WaterReflectance = 0.6
	Terrain.WaterWaveSize = 0.12
	Terrain.WaterWaveSpeed = 8
	Terrain:SetMaterialColor(M.Grass, Color3.fromRGB(110, 196, 80))
	Terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(95, 175, 70))
	Terrain:SetMaterialColor(M.Salt, Color3.fromRGB(255, 180, 215))
	Terrain:SetMaterialColor(M.Limestone, Color3.fromRGB(170, 240, 210))
	Terrain:SetMaterialColor(M.Mud, Color3.fromRGB(115, 68, 40))
	Terrain:SetMaterialColor(M.Asphalt, Color3.fromRGB(80, 65, 110))
	Terrain:SetMaterialColor(M.Sand, Color3.fromRGB(240, 222, 170))

	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.new(1, 1, 1)
	clouds.Parent = Terrain

	local decor = Instance.new("Folder")
	decor.Name = "SceneryDecor"
	decor.Parent = workspace:WaitForChild("Map")
	local rng = Random.new(2026)
	buildMeadow(rng, decor)
	for index, world in Config.Worlds do
		if world.Id ~= "meadow" then
			buildWorldTerrain(world.Id, 1000 * (index - 1), rng)
			task.wait() -- não trava o servidor enquanto cria o terreno
		end
	end
end

---------------------------------------------------------------------
-- v23: ENFEITES 3D (modelos do Higgsfield): a peça invisível com Tag "Prop3D" vira o modelo
--   Atributos: Model (id em Models3DJobs), Size (lado maior, studs), Turn (graus), Collide,
--   SpinSpeed / BobHeight (a tela anima). Sem o modelo importado: não aparece nada (e avisa no Output).
---------------------------------------------------------------------
local Models3D = require(ReplicatedStorage.Shared.Models3D)
local propsFolder: Folder? = nil
local missingProps: { [string]: boolean } = {}

local function setupProp(marker: Instance)
	if not marker:IsA("BasePart") or marker:GetAttribute("PropDone") then
		return
	end
	marker:SetAttribute("PropDone", true)
	local id = marker:GetAttribute("Model")
	if typeof(id) ~= "string" then
		return
	end
	local size = tonumber(marker:GetAttribute("Size")) or 10
	local model = Models3D.Get(id, { Size = size, Fit = "Max", Anchored = true })
	if not model then
		if not missingProps[id] then
			missingProps[id] = true
			print(("[Scenery] enfeite 3D '%s' ainda não importado (File > Import 3D, jogue em ReplicatedStorage > Models3D)"):format(id))
		end
		return
	end
	local turn = tonumber(marker:GetAttribute("Turn")) or 0
	local collide = marker:GetAttribute("Collide") ~= false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
			d.CanQuery = collide
			d.CanTouch = false
		end
	end
	model.Name = "Prop_" .. id
	model:PivotTo(marker.CFrame * CFrame.Angles(0, math.rad(turn), 0))
	local spin = tonumber(marker:GetAttribute("SpinSpeed"))
	local bob = tonumber(marker:GetAttribute("BobHeight"))
	if spin or bob then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		if spin then
			model:SetAttribute("SpinSpeed", spin)
			model:AddTag("Spin")
		end
		if bob then
			model:SetAttribute("BobHeight", bob)
			model:AddTag("Bob")
		end
	end
	if not propsFolder or not propsFolder.Parent then
		propsFolder = Instance.new("Folder")
		propsFolder.Name = "Props3D"
		propsFolder.Parent = workspace:WaitForChild("Map")
	end
	model.Parent = propsFolder
end

function Scenery.Init()
	for _, part in CollectionService:GetTagged("Prop3D") do
		task.spawn(setupProp, part)
	end
	CollectionService:GetInstanceAddedSignal("Prop3D"):Connect(setupProp)
	for _, part in CollectionService:GetTagged("Sign") do
		setupSign(part)
	end
	CollectionService:GetInstanceAddedSignal("Sign"):Connect(setupSign)
	for _, part in CollectionService:GetTagged("FX") do
		setupFx(part)
	end
	CollectionService:GetInstanceAddedSignal("FX"):Connect(setupFx)
	task.spawn(function()
		local ok, err = pcall(buildTerrain)
		if not ok then
			warn("[Scenery] terreno:", err)
		end
	end)
end

return Scenery
