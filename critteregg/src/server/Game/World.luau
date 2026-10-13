--!nonstrict
--[[
	World: monta o MAPA INTEIRO por código (seguindo o §2 do prompt: tudo numa linha reta, +Z = mais fundo).
	  HUB murado (440 x 230) com as 7 bases, as lojinhas e os placares  ->  SAFE ZONE (z = 0)  ->  12 pistas.
	Estilo: plástico com "studs", cores fortes, paredes de xadrez laranja com grama em cima.
	Devolve: World.Plots, World.Zones, World.Shops (áreas que abrem janelas), World.Boards (placares), World.NightWall.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}
World.Plots = {}
World.Zones = {}
World.Shops = {}
World.Boards = {}

local M = Config.Map
local WHITE = Color3.fromRGB(255, 255, 255)
local DARK = Color3.fromRGB(20, 15, 30)
local STUDS = Enum.SurfaceType.Studs
local rgb = Color3.fromRGB

local mapFolder: Folder

---------------------------------------------------------------------
-- Peças
---------------------------------------------------------------------
local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function deco(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = part(parent, name, size, cframe, color, material, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	if shape then
		p.Shape = shape
	end
	return p
end

-- bloco sólido "de brinquedo" (com studs em cima)
local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, collide: boolean?): Part
	local p = part(parent, name, size, cframe, color, Enum.Material.Plastic, { TopSurface = STUDS, CanCollide = collide == true, CastShadow = true })
	return p
end

local function makeLabel(parent: Instance, text: string, color: Color3, sizeY: number, order: number?, italic: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Line" .. tostring(order or 1)
	label.LayoutOrder = order or 1
	label.Size = UDim2.fromScale(0.96, sizeY)
	label.BackgroundTransparency = 1
	label.Font = if italic then Enum.Font.FredokaOne else Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = DARK
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function surface(parent: BasePart, face: Enum.NormalId, lines: { any }, ppu: number?, background: Color3?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.LightInfluence = 0
	pcall(function()
		(gui :: any).ZOffset = 0.05 -- afasta um pouquinho da parede (evita piscar no celular)
	end)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 20
	if background then
		local bg = Instance.new("Frame")
		bg.Name = "Background"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = background
		bg.BorderSizePixel = 0
		bg.ZIndex = 0
		bg.AnchorPoint = Vector2.new(0.5, 0.5)
		bg.Position = UDim2.fromScale(0.5, 0.5)
		bg.Size = UDim2.new(1, -16, 1, -16)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = bg
		local edge = Instance.new("UIStroke")
		edge.Thickness = 5
		edge.Color = DARK
		edge.Parent = bg
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.6, 0.6, 0.6))
		grad.Parent = bg
		-- brilho diagonal
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.Position = UDim2.fromScale(0.72, 0.5)
		shine.Size = UDim2.new(0.08, 0, 2, 0)
		shine.Rotation = 30
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.BackgroundTransparency = 0.85
		shine.BorderSizePixel = 0
		shine.ZIndex = 0
		shine.Parent = bg
		bg.ClipsDescendants = true
		bg.Parent = gui
	end
	-- CORREÇÃO: antes um UIListLayout empurrava as linhas para fora da placa (o fundo "Background" também
	-- entrava na lista e ocupava a placa inteira), por isso o preço e o texto não apareciam.
	-- Agora cada linha é posicionada na mão, centralizada, por cima do fundo.
	local total = 0
	for _, line in lines do
		total += line[3] or 0.4
	end
	local y = math.max(0, (1 - total) / 2)
	for index, line in lines do
		local sizeY = line[3] or 0.4
		local label = makeLabel(gui, line[1], line[2] or WHITE, sizeY, index)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, y)
		label.ZIndex = 2
		y += sizeY
	end
	gui.Parent = parent
	return gui
end

local function billboard(adornee: BasePart, offset: Vector3, size: UDim2, lines: { any }, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Billboard"
	gui.Size = size
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = math.min(maxDistance or 160, 110)
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	for index, line in lines do
		makeLabel(gui, line[1], line[2] or WHITE, line[3] or 0.5, index)
	end
	gui.Parent = adornee
	return gui
end

-- parede de xadrez com studs, faixa de grama em cima e barreira invisível alta
local function checkerWall(parent: Instance, from: Vector3, to: Vector3, height: number, colors: { Color3 }, top: Color3?, square: number?)
	local dir = to - from
	local length = dir.Magnitude
	local unit = dir.Unit
	local size = square or 10
	local columns = math.max(1, math.floor(length / size + 0.5))
	local step = length / columns
	local rows = math.max(1, math.floor(height / size + 0.5))
	local rowH = height / rows
	local alongX = math.abs(unit.X) > 0.5
	for c = 1, columns do
		local center = from + unit * (step * (c - 0.5))
		for r = 1, rows do
			local sz = if alongX then Vector3.new(step, rowH, 3) else Vector3.new(3, rowH, step)
			part(parent, "Wall", sz, CFrame.new(center.X, rowH * (r - 0.5), center.Z), colors[((c + r) % 2) + 1], Enum.Material.Plastic,
				{ FrontSurface = STUDS, BackSurface = STUDS, LeftSurface = STUDS, RightSurface = STUDS, CastShadow = false })
		end
	end
	local mid = (from + to) / 2
	if top then
		local sz = if alongX then Vector3.new(length, 3, 5) else Vector3.new(5, 3, length)
		part(parent, "WallTop", sz, CFrame.new(mid.X, height + 1.5, mid.Z), top, Enum.Material.Plastic, { TopSurface = STUDS })
	end
	local sz = if alongX then Vector3.new(length, 300, 3) else Vector3.new(3, 300, length)
	part(parent, "Barrier", sz, CFrame.new(mid.X, height + 150, mid.Z), WHITE, nil, { Transparency = 1, CanQuery = false })
end

local function checkerFloor(parent: Instance, x0: number, x1: number, z0: number, z1: number, colors: { Color3 }, square: number)
	local nx = math.max(1, math.floor((x1 - x0) / square + 0.5))
	local nz = math.max(1, math.floor((z1 - z0) / square + 0.5))
	local sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
	for i = 1, nx do
		for j = 1, nz do
			part(parent, "Floor", Vector3.new(sx, 2, sz), CFrame.new(x0 + sx * (i - 0.5), -1, z0 + sz * (j - 0.5)), colors[((i + j) % 2) + 1], Enum.Material.Plastic, { TopSurface = STUDS })
		end
	end
end


---------------------------------------------------------------------
-- BIOMAS de terreno (chão de verdade + paredões de pedra em vez do xadrez)
-- Inspirado em Steal an Egg / Grow a Garden: cada zona tem chão e cânion próprios.
---------------------------------------------------------------------
local T = Enum.Material
local BIOMES = {
	forest = { Floor = T.Grass, Cliff = T.Rock, Cap = T.Grass },
	lake = { Floor = T.Grass, Cliff = T.Rock, Cap = T.Grass, Water = true },
	desert = { Floor = T.Sand, Cliff = T.Sandstone, Cap = T.Sand },
	jungle = { Floor = T.LeafyGrass, Cliff = T.Slate, Cap = T.LeafyGrass },
	snow = { Floor = T.Snow, Cliff = T.Glacier, Cap = T.Snow },
	volcano = { Floor = T.Basalt, Cliff = T.Basalt, Cap = T.CrackedLava, Patch = T.CrackedLava },
	abyss = { Floor = T.Pavement, Cliff = T.Ice, Cap = T.Pavement },
	prehistoric = { Floor = T.Mud, Cliff = T.Ground, Cap = T.Grass },
	cosmic = { Floor = T.Asphalt, Cliff = T.Cobblestone, Cap = T.Asphalt },
	cherry = { Floor = T.Salt, Cliff = T.Limestone, Cap = T.Salt },
	titan = { Floor = T.Slate, Cliff = T.Brick, Cap = T.LeafyGrass },
	heaven = { Floor = T.Snow, Cliff = T.Concrete, Cap = T.Snow },
}
local MATERIAL_COLORS = {
	[T.Grass] = rgb(98, 196, 62), [T.LeafyGrass] = rgb(62, 150, 48), [T.Sand] = rgb(238, 208, 135),
	[T.Sandstone] = rgb(214, 150, 90), [T.Snow] = rgb(242, 247, 255), [T.Glacier] = rgb(170, 210, 245),
	[T.Basalt] = rgb(52, 44, 56), [T.CrackedLava] = rgb(255, 120, 35), [T.Pavement] = rgb(45, 95, 175),
	[T.Ice] = rgb(40, 70, 150), [T.Mud] = rgb(205, 168, 108), [T.Ground] = rgb(140, 100, 62),
	[T.Asphalt] = rgb(52, 30, 92), [T.Cobblestone] = rgb(88, 52, 140), [T.Salt] = rgb(255, 200, 225),
	[T.Limestone] = rgb(240, 165, 200), [T.Slate] = rgb(98, 118, 88), [T.Brick] = rgb(128, 132, 115),
	[T.Concrete] = rgb(250, 228, 170), [T.Rock] = rgb(140, 132, 125),
}

local function setupTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()
	for material, color in MATERIAL_COLORS do
		pcall(function()
			terrain:SetMaterialColor(material, color)
		end)
	end
	pcall(function()
		(terrain :: any).Decoration = true
	end)
	terrain.WaterColor = rgb(60, 160, 230)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.08
	terrain.WaterReflectance = 0.4
end

-- chão + cânion de uma zona. A pista do meio continua de bloquinho (o "tapete" até os ninhos).
local function terrainZone(def, z0: number, z1: number, rng: Random)
	local biome = BIOMES[def.Id]
	if not biome then
		return false
	end
	local terrain = workspace.Terrain
	local half = M.LaneWidth / 2
	local len = z1 - z0
	-- chão (topo exatamente em y = 0)
	terrain:FillBlock(CFrame.new(0, -6, z0 + len / 2), Vector3.new(M.LaneWidth + 120, 12, len), biome.Floor)
	-- manchas (lava rachada no vulcão, lagos no lago)
	if biome.Patch then
		for _ = 1, 10 do
			local x = rng:NextNumber(24, half - 10) * (if rng:NextNumber() < 0.5 then -1 else 1)
			terrain:FillCylinder(CFrame.new(x, -1.5, rng:NextNumber(z0 + 20, z1 - 20)), 3, rng:NextNumber(6, 12), biome.Patch)
		end
	end
	if biome.Water then
		for k = 1, 3 do
			local side = if k % 2 == 0 then 1 else -1
			terrain:FillBlock(CFrame.new(side * (half - 22), -2, z0 + k * len / 4), Vector3.new(24, 4, 30), T.Water)
		end
	end
	-- paredões em 3 degraus de cada lado + pedras redondas em cima (parece cânion de verdade)
	for _, side in { -1, 1 } do
		local z = z0
		while z < z1 do
			local seg = math.min(rng:NextNumber(10, 16), z1 - z)
			local cz = z + seg / 2
			local tiers = {
				{ 2, 14, rng:NextNumber(22, 38) },
				{ 10, 26, rng:NextNumber(42, 62) },
				{ 20, 52, rng:NextNumber(64, 92) },
			}
			for _, t in tiers do
				local xa, xb, h = half + t[1], half + t[2], t[3]
				local cx = side * (xa + xb) / 2
				terrain:FillBlock(CFrame.new(cx, h / 2 - 1, cz), Vector3.new(xb - xa, h + 2, seg + 2), biome.Cliff)
				terrain:FillBlock(CFrame.new(cx, h + 1, cz), Vector3.new(xb - xa, 4, seg + 2), biome.Cap)
			end
			if rng:NextNumber() < 0.55 then
				local r = rng:NextNumber(5, 10)
				terrain:FillBall(Vector3.new(side * (half + rng:NextNumber(4, 12)), rng:NextNumber(16, 30), cz), r, biome.Cliff)
			end
			if rng:NextNumber() < 0.35 then
				terrain:FillBall(Vector3.new(side * (half + rng:NextNumber(-1, 4)), 1, cz), rng:NextNumber(3, 6), biome.Cliff)
			end
			z += seg
		end
	end
	return true
end

---------------------------------------------------------------------
-- Enfeites (todos "de bloquinho")
---------------------------------------------------------------------
local function tree(parent: Instance, position: Vector3, scale: number, leaf: Color3?, trunk: Color3?)
	local h = 10 * scale
	block(parent, "Trunk", Vector3.new(3, h, 3) * Vector3.new(scale, 1, scale), CFrame.new(position + Vector3.new(0, h / 2, 0)), trunk or rgb(125, 85, 50), true)
	local leaves = leaf or rgb(70, 175, 60)
	block(parent, "Leaves", Vector3.new(12, 6, 12) * scale, CFrame.new(position + Vector3.new(0, h + 2 * scale, 0)), leaves)
	block(parent, "Leaves", Vector3.new(8, 5, 8) * scale, CFrame.new(position + Vector3.new(0, h + 7 * scale, 0)), leaves:Lerp(WHITE, 0.08))
end

local function bush(parent: Instance, position: Vector3, size: number, color: Color3?)
	local c = color or rgb(55, 150, 50)
	block(parent, "Bush", Vector3.new(size * 1.6, size, size), CFrame.new(position + Vector3.new(0, size / 2, 0)), c)
	block(parent, "Bush", Vector3.new(size, size * 0.8, size * 0.9), CFrame.new(position + Vector3.new(size * 0.7, size * 0.4, size * 0.4)), c:Lerp(WHITE, 0.06))
end

local function flowers(parent: Instance, position: Vector3, rng: Random)
	local palette = { rgb(255, 90, 120), rgb(255, 220, 70), rgb(255, 255, 255), rgb(160, 110, 255), rgb(255, 150, 60) }
	for _ = 1, 5 do
		local p = position + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		deco(parent, "Stem", Vector3.new(0.3, 1.4, 0.3), CFrame.new(p + Vector3.new(0, 0.7, 0)), rgb(60, 150, 50))
		deco(parent, "Flower", Vector3.new(0.9, 0.5, 0.9), CFrame.new(p + Vector3.new(0, 1.5, 0)), palette[rng:NextInteger(1, #palette)], Enum.Material.SmoothPlastic)
	end
end

local function lamp(parent: Instance, position: Vector3)
	block(parent, "LampPost", Vector3.new(1, 12, 1), CFrame.new(position + Vector3.new(0, 6, 0)), rgb(60, 60, 70), true)
	local bulb = deco(parent, "Lamp", Vector3.new(2.4, 2.4, 2.4), CFrame.new(position + Vector3.new(0, 12.5, 0)), rgb(255, 235, 170), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = rgb(255, 225, 160)
	light.Parent = bulb
end

---------------------------------------------------------------------
-- Modelos 3D do Toolbox (ServerStorage > ToolboxAssets). Se faltar algum, usa os enfeites de bloquinho.
---------------------------------------------------------------------
local toolbox = game:GetService("ServerStorage"):FindFirstChild("ToolboxAssets")

local function placeAsset(parent: Instance, name: string, position: Vector3, height: number, rotation: number?, collide: boolean?, resetRotation: boolean?): Model?
	local source = toolbox and toolbox:FindFirstChild(name)
	if not source then
		return nil
	end
	local model = source:Clone()
	if not model:IsA("Model") then
		return nil
	end
	local _, size = model:GetBoundingBox()
	if size.Y > 0.05 then
		pcall(function()
			model:ScaleTo(model:GetScale() * height / size.Y)
		end)
	end
	-- (voltou a ser como antes: o mapa ficava mais bonito assim)
	model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, rotation or 0, 0))
	local box, newSize = model:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, newSize.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (position - bottom))
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = collide == true
			item.CanTouch = false
			item.CanQuery = collide == true
			item.CastShadow = true
		elseif item:IsA("Sound") then
			item:Destroy()
		end
	end
	model.Parent = parent
	return model
end

-- modelos 3D NOSSOS (ReplicatedStorage > Models3D, prop_*): marcos grandes de cada zona
local Models3D = require(ReplicatedStorage.Shared.Models3D)
local function placeProp3D(parent: Instance, id: string, position: Vector3, height: number, rotation: number?, collide: boolean?): Model?
	local ok, model = pcall(Models3D.Get, id, { Size = height, Fit = "Height" })
	if not ok or not model then
		return nil
	end
	model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, rotation or 0, 0))
	local box, size = model:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (position - bottom))
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = collide == true
			item.CanTouch = false
			item.CanQuery = collide == true
		end
	end
	model.Parent = parent
	return model
end
local ZONE_LANDMARKS = {
	forest = { { "prop_treehouse", 34 }, { "prop_mushroomhouse", 18 } },
	lake = { { "prop_lighthouse", 42 }, { "prop_fountain", 12 } },
	desert = { { "prop_pirateship", 26 }, { "prop_well", 11 } },
	jungle = { { "prop_treehouse", 30 }, { "prop_babydragon", 14 } },
	snow = { { "prop_igloo", 16 }, { "prop_snowman", 15 } },
	volcano = { { "prop_volcano", 44 }, { "prop_cauldron", 10 } },
	abyss = { { "prop_coral", 18 }, { "prop_pirateship", 22 } },
	prehistoric = { { "prop_cupcake", 20 }, { "prop_lollipop", 24 }, { "prop_gingerbread", 20 }, { "prop_icecream", 16 } },
	cosmic = { { "prop_rocket", 34 }, { "prop_ufo", 16 } },
	cherry = { { "prop_carousel", 22 }, { "prop_balloon", 18 } },
	titan = { { "prop_statue", 30 }, { "prop_well", 12 } },
	heaven = { { "prop_statue", 26 }, { "prop_balloon", 20 } },
}
local function landmarks(parent: Instance, theme: string, z0: number, z1: number, rng: Random)
	local list = ZONE_LANDMARKS[theme]
	if not list then
		return
	end
	local half = M.LaneWidth / 2
	for k, entry in list do
		local side = if k % 2 == 1 then -1 else 1
		local z = z0 + (z1 - z0) * (0.28 + 0.42 * ((k - 1) % 2)) + rng:NextNumber(-10, 10) + (if k > 2 then 30 else 0)
		local x = side * (half - entry[2] * 0.5 - 6)
		local rot = if side < 0 then math.pi / 2 else -math.pi / 2
		placeProp3D(parent, entry[1], Vector3.new(x, 0, z), entry[2], rot + rng:NextNumber(-0.4, 0.4), false)
	end
end

-- o que aparece em cada zona: { nome do modelo, altura mínima, altura máxima, peso, bate? }
local ZONE_ASSETS = {
	forest = { { "TreeA", 22, 30, 3 }, { "TreeB", 22, 30, 3 }, { "TreeC", 20, 26, 2 }, { "PineTree", 24, 32, 2 }, { "Bush", 5, 8, 3 }, { "Mushroom", 4, 7, 2 }, { "Mushrooms", 3, 5, 2 }, { "FlowerBush", 4, 6, 2 }, { "Flower", 3, 4, 2 }, { "Rocks", 3, 5, 1 } },
	lake = { { "TreeC", 20, 26, 2 }, { "LilyFlowers", 3, 4, 3 }, { "Rock", 4, 7, 2, true }, { "Bush", 5, 7, 2 }, { "Flower", 3, 4, 2 }, { "TreeA", 22, 28, 1 } },
	desert = { { "Cactus", 9, 14, 4 }, { "CactusBloom", 9, 14, 3 }, { "PalmB", 18, 26, 2 }, { "Rock", 4, 8, 2, true }, { "RockPile", 4, 6, 1 } },
	jungle = { { "Palm", 22, 32, 3 }, { "TreeB", 26, 34, 3 }, { "Bush", 6, 9, 3 }, { "Mushrooms", 4, 6, 2 }, { "FlowerBush", 5, 7, 2 }, { "TallGrass", 6, 9, 1 } },
	snow = { { "SnowTree", 20, 30, 3 }, { "SnowPine", 22, 32, 3 }, { "IceCrystal", 8, 14, 3 }, { "Rock", 4, 7, 1, true } },
	volcano = { { "LavaRock", 6, 12, 4, true }, { "DarkRock", 8, 14, 3, true }, { "Volcano", 34, 46, 1, true } },
	abyss = { { "Coral", 6, 10, 3 }, { "CoralReef", 8, 12, 3 }, { "Seaweed", 10, 16, 3 }, { "Rocks", 4, 6, 1 } },
	prehistoric = { { "DinoSkeleton", 10, 16, 2 }, { "PalmB", 20, 28, 3 }, { "RockPile", 5, 8, 2 }, { "Bush", 6, 9, 2 }, { "Volcano", 36, 46, 1, true } },
	cosmic = { { "Crystals", 6, 10, 3 }, { "CrystalBlue", 8, 12, 3 }, { "Crystal", 8, 14, 2 } },
	cherry = { { "CherryTree", 22, 34, 4 }, { "Flower", 3, 4, 2 }, { "Bench", 3.5, 4, 1 } },
	titan = { { "Pillar", 20, 28, 3, true }, { "PillarB", 16, 22, 3, true }, { "Rock", 5, 8, 2, true }, { "Bush", 5, 8, 2 } },
	heaven = { { "CrystalBlue", 8, 12, 3 }, { "Crystals", 6, 9, 2 }, { "FlowerBush", 4, 6, 2 }, { "Flower", 3, 4, 2 } },
}

local function pickAsset(list, rng: Random)
	local total = 0
	for _, entry in list do
		total += entry[4]
	end
	local roll = rng:NextNumber() * total
	for _, entry in list do
		roll -= entry[4]
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

-- espalha modelos dos dois lados da pista (o meio fica livre para correr e o ninho fica livre)
local function assetProps(parent: Instance, theme: string, z0: number, z1: number, rng: Random): boolean
	local list = ZONE_ASSETS[theme]
	if not toolbox or not list then
		return false
	end
	local half = M.LaneWidth / 2
	local placed = 0
	for i = 1, 26 do
		local entry = pickAsset(list, rng)
		local z = z0 + 16 + (z1 - z0 - 24) * (i - 0.5) / 26 + rng:NextNumber(-4, 4)
		local side = if i % 2 == 0 then 1 else -1
		local big = entry[3] >= 18
		local x = side * (if big then rng:NextNumber(half - 18, half - 9) else rng:NextNumber(half - 34, half - 8))
		local model = placeAsset(parent, entry[1], Vector3.new(x, 0, z), rng:NextNumber(entry[2], entry[3]), rng:NextNumber(0, math.pi * 2), entry[5])
		if model then
			placed += 1
		end
	end
	-- planetas e nuvens flutuando
	if theme == "cosmic" then
		for k = 1, 5 do
			placeAsset(parent, "Planet", Vector3.new(rng:NextNumber(-half + 10, half - 10), rng:NextNumber(30, 55), z0 + k * (z1 - z0) / 6), rng:NextNumber(10, 18), rng:NextNumber(0, 6))
		end
	elseif theme == "heaven" then
		for k = 1, 8 do
			placeAsset(parent, "Cloud", Vector3.new(rng:NextNumber(-half, half), rng:NextNumber(26, 50), z0 + k * (z1 - z0) / 9), rng:NextNumber(8, 14), rng:NextNumber(0, 6))
		end
	elseif theme == "lake" then
		for k = 1, 6 do
			local side = if k % 2 == 0 then 1 else -1
			local p = Vector3.new(side * rng:NextNumber(half - 30, half - 16), 0, z0 + k * (z1 - z0) / 7)
			deco(parent, "Pond", Vector3.new(0.4, 22, 22), CFrame.new(p + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 150, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
			for _ = 1, 3 do
				placeAsset(parent, "LilyPad", p + Vector3.new(rng:NextNumber(-6, 6), 0.3, rng:NextNumber(-6, 6)), 0.3, rng:NextNumber(0, 6))
			end
		end
	elseif theme == "volcano" then
		for k = 1, 5 do
			local p = Vector3.new(rng:NextNumber(-half + 20, half - 20), 0, z0 + k * (z1 - z0) / 6)
			if math.abs(p.X) > 22 then
				deco(parent, "LavaPool", Vector3.new(0.3, 12, 12), CFrame.new(p + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 110, 20), Enum.Material.Neon, Enum.PartType.Cylinder)
			end
		end
	elseif theme == "abyss" then
		for k = 1, 4 do
			local bubble = deco(parent, "AirBubble", Vector3.new(14, 14, 14), CFrame.new(rng:NextNumber(-half + 12, half - 12), rng:NextNumber(12, 30), z0 + k * (z1 - z0) / 5), rgb(150, 220, 255), Enum.Material.Glass, Enum.PartType.Ball)
			bubble.Transparency = 0.7
		end
	elseif theme == "desert" then
		for step = 0, 5 do
			local s = 34 - step * 6
			block(parent, "Pyramid", Vector3.new(s, 4, s), CFrame.new(Vector3.new(half - 26, 2 + step * 4, z0 + (z1 - z0) * 0.35)), rgb(225, 190, 110), true)
		end
	end
	return placed > 0
end

local function props(parent: Instance, theme: string, z0: number, z1: number, rng: Random)
	pcall(landmarks, parent, theme, z0, z1, rng)
	if assetProps(parent, theme, z0, z1, rng) then
		return
	end
	local half = M.LaneWidth / 2
	local count = 14
	for i = 1, count do
		local z = z0 + (z1 - z0) * (i - 0.5) / count + rng:NextNumber(-6, 6)
		local side = if i % 2 == 0 then 1 else -1
		local x = side * rng:NextNumber(half - 32, half - 8)
		local p = Vector3.new(x, 0, z)
		if theme == "forest" then
			if i % 3 == 0 then
				tree(parent, p, rng:NextNumber(1, 1.4))
			else
				bush(parent, p, rng:NextNumber(4, 7))
				deco(parent, "Tuft", Vector3.new(0.6, 3, 0.6), CFrame.new(p + Vector3.new(6, 1.5, 3)), rgb(60, 170, 60))
			end
		elseif theme == "lake" then
			if i % 2 == 0 then
				deco(parent, "Pond", Vector3.new(0.4, 22, 22), CFrame.new(p + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 150, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
				deco(parent, "LilyPad", Vector3.new(0.3, 3, 3), CFrame.new(p + Vector3.new(3, 0.3, 2)) * CFrame.Angles(0, 0, math.rad(90)), rgb(60, 170, 70), nil, Enum.PartType.Cylinder)
			else
				for k = 1, 4 do
					block(parent, "Reed", Vector3.new(0.6, rng:NextNumber(4, 7), 0.6), CFrame.new(p + Vector3.new(k, 2.5, rng:NextNumber(-2, 2))), rgb(100, 150, 60))
				end
				block(parent, "Rock", Vector3.new(4, 2.5, 3), CFrame.new(p + Vector3.new(-5, 1.25, 0)), rgb(150, 150, 155))
			end
		elseif theme == "desert" then
			if i == 4 then
				for step = 0, 5 do
					local s = 34 - step * 6
					block(parent, "Pyramid", Vector3.new(s, 4, s), CFrame.new(Vector3.new(-side * (half - 26), 2 + step * 4, z)), rgb(225, 190, 110), true)
				end
			else
				local h = rng:NextNumber(6, 11)
				block(parent, "Cactus", Vector3.new(2, h, 2), CFrame.new(p + Vector3.new(0, h / 2, 0)), rgb(70, 160, 70), true)
				block(parent, "CactusArm", Vector3.new(4, 1.6, 1.6), CFrame.new(p + Vector3.new(1.5, h * 0.6, 0)), rgb(70, 160, 70))
				block(parent, "CactusArmUp", Vector3.new(1.6, 3, 1.6), CFrame.new(p + Vector3.new(3, h * 0.6 + 1.5, 0)), rgb(70, 160, 70))
				deco(parent, "Bone", Vector3.new(5, 0.8, 0.8), CFrame.new(p + Vector3.new(-6, 0.4, 4)) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0), rgb(245, 240, 220))
			end
		elseif theme == "jungle" then
			tree(parent, p, rng:NextNumber(1.3, 1.8), rgb(40, 140, 45), rgb(95, 65, 40))
			block(parent, "BigLeaf", Vector3.new(7, 0.6, 3), CFrame.new(p + Vector3.new(6, 1.5, 2)) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), math.rad(20)), rgb(50, 170, 60))
			deco(parent, "Mud", Vector3.new(0.3, 9, 9), CFrame.new(p + Vector3.new(-8, 0.05, -4)) * CFrame.Angles(0, 0, math.rad(90)), rgb(110, 75, 45), nil, Enum.PartType.Cylinder)
		elseif theme == "snow" then
			local h = rng:NextNumber(10, 22)
			local crystal = deco(parent, "IceCrystal", Vector3.new(5, h, 5), CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.rad(45), math.rad(rng:NextNumber(-10, 10))), rgb(130, 220, 255), Enum.Material.Glass)
			crystal.Transparency = 0.15
			block(parent, "SnowPile", Vector3.new(9, 3, 7), CFrame.new(p + Vector3.new(7, 1.5, 3)), WHITE)
			tree(parent, p + Vector3.new(-9, 0, 0), 1, rgb(235, 245, 255), rgb(110, 80, 60))
		elseif theme == "volcano" then
			block(parent, "Rock", Vector3.new(8, 6, 7), CFrame.new(p + Vector3.new(0, 3, 0)), rgb(40, 38, 45), true)
			deco(parent, "LavaPool", Vector3.new(0.3, 12, 12), CFrame.new(p + Vector3.new(side * -14, 0.06, 4)) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 110, 20), Enum.Material.Neon, Enum.PartType.Cylinder)
			deco(parent, "LavaCrack", Vector3.new(18, 0.2, 1.2), CFrame.new(rng:NextNumber(-50, 50), 0.11, z) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0), rgb(255, 130, 30), Enum.Material.Neon)
			block(parent, "BurntTree", Vector3.new(1.6, 9, 1.6), CFrame.new(p + Vector3.new(7, 4.5, -3)), rgb(30, 25, 25))
		elseif theme == "abyss" then
			local bubble = deco(parent, "AirBubble", Vector3.new(20, 20, 20), CFrame.new(p + Vector3.new(0, 4, 0)), rgb(150, 220, 255), Enum.Material.Glass, Enum.PartType.Ball)
			bubble.Transparency = 0.65
			for k = 1, 3 do
				local h = rng:NextNumber(5, 12)
				block(parent, "Coral", Vector3.new(1.6, h, 1.6), CFrame.new(p + Vector3.new(k * 3 - 6, h / 2, 9)), Color3.fromHSV(rng:NextNumber(0.85, 1), 0.65, 1))
			end
			block(parent, "Kelp", Vector3.new(0.8, 14, 0.8), CFrame.new(p + Vector3.new(-8, 7, -5)), rgb(40, 160, 90))
		elseif theme == "prehistoric" then
			if i % 4 == 1 then
				for step = 0, 4 do
					local s = 28 - step * 5
					block(parent, "VolcanoBack", Vector3.new(s, 6, s), CFrame.new(Vector3.new(-side * (half - 22), 3 + step * 6, z)), rgb(110, 85, 70), true)
				end
				deco(parent, "Smoke", Vector3.new(4, 4, 4), CFrame.new(Vector3.new(-side * (half - 22), 34, z)), rgb(255, 120, 40), Enum.Material.Neon, Enum.PartType.Ball)
			else
				bush(parent, p, rng:NextNumber(4, 6), rgb(70, 140, 50))
				deco(parent, "BigBone", Vector3.new(10, 1.6, 1.6), CFrame.new(p + Vector3.new(-7, 0.8, 4)) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0), rgb(245, 240, 220))
			end
		elseif theme == "cosmic" then
			local planet = deco(parent, "Planet", Vector3.new(12, 12, 12), CFrame.new(p + Vector3.new(0, rng:NextNumber(18, 40), 0)), Color3.fromHSV(rng:NextNumber(), 0.55, 0.95), nil, Enum.PartType.Ball)
			local ring = deco(parent, "Ring", Vector3.new(0.4, 20, 20), planet.CFrame * CFrame.Angles(math.rad(20), 0, math.rad(80)), rgb(255, 230, 140), Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.Transparency = 0.35
			block(parent, "Crystal", Vector3.new(3, 8, 3), CFrame.new(p + Vector3.new(6, 4, 4)) * CFrame.Angles(0, math.rad(45), 0), rgb(180, 120, 255))
			deco(parent, "Star", Vector3.new(1, 1, 1), CFrame.new(rng:NextNumber(-60, 60), 0.6, z), rgb(255, 255, 200), Enum.Material.Neon)
		elseif theme == "cherry" then
			tree(parent, p, rng:NextNumber(1.1, 1.5), rgb(255, 170, 205), rgb(110, 70, 60))
			for k = 1, 4 do
				deco(parent, "Petal", Vector3.new(0.8, 0.1, 0.8), CFrame.new(p + Vector3.new(rng:NextNumber(-8, 8), 0.1, rng:NextNumber(-8, 8))), rgb(255, 190, 215), Enum.Material.SmoothPlastic)
				local _ = k
			end
		elseif theme == "titan" then
			if i % 3 == 0 then
				block(parent, "Ruin", Vector3.new(6, 16, 6), CFrame.new(p + Vector3.new(0, 8, 0)), rgb(120, 125, 110), true)
				block(parent, "RuinTop", Vector3.new(14, 3, 6), CFrame.new(p + Vector3.new(0, 17.5, 0)), rgb(105, 110, 98))
			else
				block(parent, "Stone", Vector3.new(7, 4, 5), CFrame.new(p + Vector3.new(0, 2, 0)), rgb(110, 115, 100), true)
				block(parent, "Vine", Vector3.new(0.6, 8, 0.6), CFrame.new(p + Vector3.new(2, 4, 2.6)), rgb(50, 140, 50))
				lamp(parent, p + Vector3.new(-6, 0, 3))
			end
		elseif theme == "heaven" then
			block(parent, "GoldPillar", Vector3.new(4, 22, 4), CFrame.new(p + Vector3.new(0, 11, 0)), rgb(255, 215, 90), true)
			deco(parent, "Cloud", Vector3.new(14, 4, 9), CFrame.new(p + Vector3.new(side * -10, rng:NextNumber(20, 34), 0)), WHITE, Enum.Material.SmoothPlastic)
			deco(parent, "CloudB", Vector3.new(9, 5, 7), CFrame.new(p + Vector3.new(side * -14, rng:NextNumber(22, 30), 3)), WHITE, Enum.Material.SmoothPlastic)
		end
	end
end

---------------------------------------------------------------------
-- Bases (as 7 do hub)
---------------------------------------------------------------------
local function buildPlot(index: number, x: number)
	local folder = Instance.new("Model")
	folder.Name = "Plot" .. index
	folder.Parent = mapFolder
	local front = M.PlotZ + 24 -- portão do cercado (virado para a SAFE ZONE)
	local plot = {
		Index = index,
		Model = folder,
		X = x,
		Front = front,
		Owner = nil,
		Spawn = CFrame.lookAt(Vector3.new(x - 4, 4, front + 18), Vector3.new(x - 4, 4, front + 70)),
	}
	-- caminho de areia do portão até a avenida
	deco(folder, "Path", Vector3.new(10, 0.2, 48), CFrame.new(x, 0.08, front + 24), rgb(235, 215, 160), Enum.Material.SmoothPlastic)
	-- ESTEIRA na frente do portão. Quem corre olha para -Z (para o hub, como no jogo de referência):
	-- o chão anda para +Z na velocidade do dono, então ele corre parado.
	local tz = front + 22
	local tread = Instance.new("Model")
	tread.Name = "Treadmill"
	tread.Parent = folder
	block(tread, "Base", Vector3.new(12, 1.2, 22), CFrame.new(x + 13, 0.6, tz), rgb(45, 45, 55), true)
	local belt = part(tread, "Belt", Vector3.new(8, 0.4, 20), CFrame.new(x + 13, 1.4, tz), rgb(30, 30, 36), Enum.Material.Rubber)
	for _, side in { -1, 1 } do
		part(tread, "Rail", Vector3.new(1, 4, 20), CFrame.new(x + 13 + side * 5, 3.2, tz), rgb(200, 200, 210), Enum.Material.Metal)
	end
	-- listras do chão da esteira (a tela anima andando)
	for k = 1, 6 do
		local stripe = deco(tread, "Stripe", Vector3.new(7.6, 0.05, 0.6), CFrame.new(x + 13, 1.62, tz - 10 + k * 3.2), rgb(70, 70, 80), Enum.Material.SmoothPlastic)
		stripe:SetAttribute("BeltStripe", true)
	end
	local screen = part(tread, "Screen", Vector3.new(10, 5, 1), CFrame.new(x + 13, 7, tz - 11.5), rgb(200, 200, 215))
	part(tread, "ScreenLegA", Vector3.new(0.8, 5, 0.8), CFrame.new(x + 8.6, 2.5, tz - 11.5), rgb(200, 200, 210), Enum.Material.Metal)
	part(tread, "ScreenLegB", Vector3.new(0.8, 5, 0.8), CFrame.new(x + 17.4, 2.5, tz - 11.5), rgb(200, 200, 210), Enum.Material.Metal)
	surface(screen, Enum.NormalId.Back, { { "BASIC TREADMILL", rgb(255, 225, 80), 0.35 }, { "+2/step", rgb(120, 255, 120), 0.5 } }, 30, rgb(35, 70, 160))
	-- holograma "trancado" (some quando destrava)
	local lock = part(folder, "TreadLock", Vector3.new(12.4, 6, 22.4), CFrame.new(x + 13, 3, tz), rgb(160, 160, 175), Enum.Material.ForceField, { CanCollide = true, Transparency = 0.2 })
	billboard(lock, Vector3.new(0, 5, 0), UDim2.fromScale(10, 3), { { "\u{1F512} Unlock Pen Level 1", WHITE, 0.55 }, { "to use the treadmill", rgb(255, 225, 120), 0.45 } }, 90)
	-- ESTEIRA 3D do Toolbox por cima (as peças de bloquinho ficam invisíveis, mas o chão que anda continua)
	local fancy = placeAsset(tread, "Treadmill", Vector3.new(x + 13, 0, tz), 13.2, math.pi / 2, nil, true)
	if fancy then
		fancy.Name = "TreadmillModel"
		local deckTop = 1.6
		local bestArea = 0
		for _, item in fancy:GetDescendants() do
			if item:IsA("BasePart") and item.Name == "ThreadPart" then
				local area = item.Size.X * item.Size.Z
				if area > bestArea then
					bestArea = area
					deckTop = item.Position.Y + item.Size.Y / 2
				end
			end
		end
		for _, item in tread:GetChildren() do
			if item:IsA("BasePart") and item.Name ~= "Screen" then
				item.Transparency = 1
			end
		end
		belt.CFrame = CFrame.new(x + 13, deckTop - 0.15, tz)
		belt.Size = Vector3.new(8, 0.4, 20)
		-- faixas neon nas laterais com a cor do nível da esteira
		for _, side in { -1, 1 } do
			local glow = deco(tread, "LevelGlow", Vector3.new(0.5, 0.5, 20), CFrame.new(x + 13 + side * 5.6, deckTop + 0.3, tz), rgb(120, 200, 255), Enum.Material.Neon)
			glow.Transparency = 0
		end
		screen.CFrame = CFrame.new(x + 13, 15.5, tz - 10)
		for _, name in { "ScreenLegA", "ScreenLegB" } do
			local leg = tread:FindFirstChild(name)
			if leg then
				leg.Transparency = 1
			end
		end
	end
	plot.Belt = belt
	plot.Screen = screen
	plot.TreadLock = lock
	plot.TreadModel = tread

	-- placa "Upgrade Pen" (preta, em dois pés, canto esquerdo da frente)
	local penBoard = part(folder, "PenBoard", Vector3.new(10, 6, 1), CFrame.new(x - 12, 5.5, front + 5), rgb(255, 205, 40))
	part(folder, "PenLegA", Vector3.new(1, 2.5, 1), CFrame.new(x - 15.5, 1.25, front + 5), rgb(120, 80, 45))
	part(folder, "PenLegB", Vector3.new(1, 2.5, 1), CFrame.new(x - 8.5, 1.25, front + 5), rgb(120, 80, 45))
	surface(penBoard, Enum.NormalId.Back, { { "Upgrade Pen", WHITE, 0.3 }, { "Unlock Pen Level 1", rgb(120, 255, 120), 0.25 }, { "$1K", WHITE, 0.32 } }, 30, rgb(70, 170, 60))
	plot.PenBoard = penBoard
	-- placa da esteira (do lado de fora da esteira)
	local treadBoard = part(folder, "TreadBoard", Vector3.new(10, 6, 1), CFrame.new(x + 13, 5.5, tz + 13), rgb(255, 205, 40))
	part(folder, "TreadLegA", Vector3.new(1, 2.5, 1), CFrame.new(x + 9.5, 1.25, tz + 13), rgb(25, 30, 50))
	part(folder, "TreadLegB", Vector3.new(1, 2.5, 1), CFrame.new(x + 16.5, 1.25, tz + 13), rgb(25, 30, 50))
	surface(treadBoard, Enum.NormalId.Back, { { "Upgrade Treadmill", WHITE, 0.3 }, { "Level 1 > Level 2", rgb(120, 255, 120), 0.25 }, { "$2.5K", WHITE, 0.32 } }, 30, rgb(40, 130, 230))
	plot.TreadBoard = treadBoard
	-- placa do dono em cima do cercado
	local anchor = part(folder, "OwnerAnchor", Vector3.one, CFrame.new(x, 15, front - 18), WHITE, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	local owner = billboard(anchor, Vector3.zero, UDim2.fromScale(22, 3.2), { { "Empty Pen", WHITE, 1 } }, 220)
	plot.OwnerLabel = owner:FindFirstChild("Line1")
	plot.OwnerAnchor = anchor
	plot.FenceFolder = Instance.new("Folder")
	plot.FenceFolder.Name = "Fence"
	plot.FenceFolder.Parent = folder
	table.insert(World.Plots, plot)
end

-- vaga n do cercado: 3 colunas, fileiras indo para o fundo
function World.SlotPosition(plot, slot: number): Vector3
	local column = (slot - 1) % 3
	local row = math.floor((slot - 1) / 3)
	return Vector3.new(plot.X + (column - 1) * 11, 0, plot.Front - 8 - row * 11)
end

function World.PenDepth(slots: number): number
	return 8 + 11 * math.ceil(slots / 3)
end

-- (re)desenha o cercado para o nível dele: madeira, ferro, ouro, diamante (fica mais fundo a cada nível)
function World.BuildPen(plot, penLevel: number)
	plot.FenceFolder:ClearAllChildren()
	local slots = Config.SlotCount(penLevel)
	local depth = World.PenDepth(slots)
	local width = M.PenWidth
	local color = Config.FenceColor(penLevel)
	local post = color:Lerp(Color3.new(0, 0, 0), 0.5)
	local material = if penLevel >= 4 then Enum.Material.Metal else Enum.Material.WoodPlanks
	local x, front = plot.X, plot.Front
	local back = front - depth
	part(plot.FenceFolder, "PenFloor", Vector3.new(width, 0.4, depth), CFrame.new(x, 0.2, front - depth / 2), rgb(125, 210, 85), Enum.Material.Plastic, { CanCollide = false, TopSurface = STUDS })
	local function fence(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local alongX = math.abs((b - a).X) > 0.5
		local steps = math.max(1, math.floor(length / 7 + 0.5))
		for i = 0, steps do
			local p = a + (b - a) * (i / steps)
			block(plot.FenceFolder, "Post", Vector3.new(1.6, 5, 1.6), CFrame.new(p.X, 2.5, p.Z), post, true)
			if i < steps then
				local q = a + (b - a) * ((i + 1) / steps)
				local mid = (p + q) / 2
				local segment = (q - p).Magnitude
				for _, h in { 1.4, 3.8 } do
					part(plot.FenceFolder, "Rail", if alongX then Vector3.new(segment, 0.7, 0.7) else Vector3.new(0.7, 0.7, segment), CFrame.new(mid.X, h, mid.Z), color, material, { CanCollide = true })
				end
				-- X entre os postes
				local angle = math.atan2(3.4, segment)
				local cross = if alongX then CFrame.Angles(0, 0, angle) else CFrame.Angles(angle, 0, 0)
				local cross2 = if alongX then CFrame.Angles(0, 0, -angle) else CFrame.Angles(-angle, 0, 0)
				local len = math.sqrt(segment * segment + 3.4 * 3.4)
				local sz = if alongX then Vector3.new(len, 0.5, 0.5) else Vector3.new(0.5, 0.5, len)
				deco(plot.FenceFolder, "Cross", sz, CFrame.new(mid.X, 2.6, mid.Z) * cross, color, material)
				deco(plot.FenceFolder, "Cross", sz, CFrame.new(mid.X, 2.6, mid.Z) * cross2, color, material)
			end
		end
	end
	local hw = width / 2
	fence(Vector3.new(x - hw, 0, back), Vector3.new(x + hw, 0, back))
	fence(Vector3.new(x - hw, 0, back), Vector3.new(x - hw, 0, front))
	fence(Vector3.new(x + hw, 0, back), Vector3.new(x + hw, 0, front))
	fence(Vector3.new(x - hw, 0, front), Vector3.new(x - 5, 0, front))
	fence(Vector3.new(x + 5, 0, front), Vector3.new(x + hw, 0, front))
	-- arco do portão
	block(plot.FenceFolder, "GatePost", Vector3.new(1.8, 9, 1.8), CFrame.new(x - 5, 4.5, front), post, true)
	block(plot.FenceFolder, "GatePost", Vector3.new(1.8, 9, 1.8), CFrame.new(x + 5, 4.5, front), post, true)
	block(plot.FenceFolder, "GateTop", Vector3.new(12, 1.6, 2), CFrame.new(x, 9.4, front), color)
end

function World.SetTreadmillLocked(plot, locked: boolean)
	plot.TreadLock.Transparency = if locked then 0.2 else 1
	plot.TreadLock.CanCollide = locked
	local board = plot.TreadLock:FindFirstChild("Billboard")
	if board then
		board.Enabled = locked
	end
end

---------------------------------------------------------------------
-- Lojinhas do hub (perto da SAFE ZONE, no caminho de todo mundo)
---------------------------------------------------------------------
local function shopArea(name: string, center: Vector3, radius: number)
	table.insert(World.Shops, { Name = name, Center = center, Radius = radius })
end

-- brilhinhos subindo de um ponto (pads das lojas)
local function sparkles(target: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = target
end

-- pad de chão em frente da loja: anel neon + miolo + texto "STEP HERE"
local function shopPad(model: Instance, center: Vector3, color: Color3, label: string)
	local ring = deco(model, "PadRing", Vector3.new(0.3, 13, 13), CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.15
	deco(model, "PadInner", Vector3.new(0.34, 10.6, 10.6), CFrame.new(center + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, 0, math.rad(90)), color:Lerp(Color3.new(1, 1, 1), 0.55), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local text = part(model, "PadText", Vector3.new(3, 0.05, 9), CFrame.new(center + Vector3.new(0, 0.33, 0)) * CFrame.Angles(0, math.rad(-90), 0), WHITE, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	local gui = surface(text, Enum.NormalId.Top, { { label, rgb(255, 255, 255), 0.9 } }, 40)
	gui.Name = "PadGui"
	sparkles(ring, color)
end

-- barraquinha: piso de madeira, paredes coloridas, telhado listrado inclinado com babado,
-- balcão, placa grande, lanternas e um bichinho vendedor atrás do balcão
local function stall(model: Instance, x: number, z: number, o: { [string]: any })
	local wall, roofA, roofB = o.Wall, o.RoofA, o.RoofB or WHITE
	block(model, "Floor", Vector3.new(22, 1, 15), CFrame.new(x, 0.5, z - 3), rgb(196, 146, 92), true)
	for k = 0, 6 do
		deco(model, "Plank", Vector3.new(22, 0.06, 0.25), CFrame.new(x, 1.02, z - 10 + k * 2.2), rgb(150, 105, 62), Enum.Material.SmoothPlastic)
	end
	block(model, "BackWall", Vector3.new(22, 12, 1.2), CFrame.new(x, 7, z - 10.4), wall, true)
	for _, side in { -1, 1 } do
		block(model, "SideWall", Vector3.new(1.2, 12, 8), CFrame.new(x + side * 10.4, 7, z - 6.5), wall:Lerp(Color3.new(0, 0, 0), 0.12), true)
		block(model, "Post", Vector3.new(1.4, 12, 1.4), CFrame.new(x + side * 10.4, 7, z + 3.8), rgb(120, 80, 45), true)
		local lantern = deco(model, "Lantern", Vector3.new(1.6, 1.6, 1.6), CFrame.new(x + side * 10.4, 10.4, z + 5), rgb(255, 220, 120), Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 210, 140)
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = lantern
	end
	-- telhado: listras inclinadas para a frente + babado redondo na borda
	for k = 0, 10 do
		deco(model, "Roof", Vector3.new(2.1, 0.7, 17), CFrame.new(x - 11 + k * 2.1 + 1.05, 14.2, z - 2.5) * CFrame.Angles(math.rad(14), 0, 0), if k % 2 == 0 then roofA else roofB, Enum.Material.SmoothPlastic)
		deco(model, "Scallop", Vector3.new(0.6, 2.1, 2.1), CFrame.new(x - 11 + k * 2.1 + 1.05, 11.9, z + 5.7) * CFrame.Angles(0, 0, math.rad(90)), if k % 2 == 0 then roofA else roofB, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	-- balcão
	block(model, "Counter", Vector3.new(18, 3.6, 3), CFrame.new(x, 2.8, z + 2), rgb(150, 95, 55), true)
	block(model, "CounterTop", Vector3.new(18.8, 0.6, 3.6), CFrame.new(x, 4.9, z + 2), rgb(235, 225, 210), true)
	local front = part(model, "CounterFront", Vector3.new(16, 2.6, 0.2), CFrame.new(x, 2.8, z + 3.6), o.Panel or roofA, Enum.Material.SmoothPlastic, { CanCollide = false })
	surface(front, Enum.NormalId.Back, { { o.Panel_Text or "", WHITE, 0.8 } }, 20)
	-- placa grande em cima
	local sign = part(model, "SignBoard", Vector3.new(18, 5, 1), CFrame.new(x, 18.6, z + 4) * CFrame.Angles(math.rad(-8), 0, 0), rgb(255, 210, 60), Enum.Material.SmoothPlastic, { CanCollide = false })
	surface(sign, Enum.NormalId.Back, { { o.Title, o.TitleColor or WHITE, 0.62 }, { o.Sub or "", WHITE, 0.3 } }, 24, o.SignColor or roofA)
	surface(sign, Enum.NormalId.Front, { { o.Title, o.TitleColor or WHITE, 0.62 } }, 24, o.SignColor or roofA)
	-- prateleira com itens na parede do fundo
	block(model, "Shelf", Vector3.new(16, 0.6, 2), CFrame.new(x, 8.5, z - 9.2), rgb(150, 105, 62), true)
	for k = -3, 3 do
		local c = (o.Goods or { rgb(255, 210, 60) })[(k + 3) % #(o.Goods or { 1 }) + 1]
		deco(model, "Good", Vector3.new(1.6, 1.6, 1.6), CFrame.new(x + k * 2.2, 9.6, z - 9.2), c, if o.GoodsNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	-- vendedor: um bichinho do jogo atrás do balcão
	if o.Keeper then
		pcall(function()
			local def = require(ReplicatedStorage.Shared.Critters).ById[o.Keeper]
			local critter = require(ReplicatedStorage.Shared.CritterBuilder).Build(def)
			critter.Name = "Shopkeeper"
			for _, item in critter:GetDescendants() do
				if item:IsA("BasePart") then
					item.Anchored = true
					item.CanCollide = false
				end
			end
			critter:ScaleTo(o.KeeperScale or 2.2)
			local _, size = critter:GetBoundingBox()
			local pivotOffset = critter:GetPivot().Position.Y - critter:GetBoundingBox().Position.Y
			critter:PivotTo(CFrame.lookAt(Vector3.new(x, 1 + size.Y / 2 + pivotOffset, z - 3), Vector3.new(x, 1 + size.Y / 2 + pivotOffset, z + 10)))
			critter.Parent = model
		end)
	end
end

local function buildShops(hub: Instance)
	local z = -34
	-- SELL: barraquinha vermelha e branca
	do
		local x = -150
		local model = Instance.new("Model")
		model.Name = "SellBooth"
		model.Parent = hub
		stall(model, x, z, {
			Wall = rgb(255, 225, 150), RoofA = rgb(230, 50, 60), RoofB = WHITE, SignColor = rgb(225, 45, 55),
			Title = "\u{1F4B0} SELL", Sub = "Sell your pets for cash!", Panel = rgb(70, 190, 70), Panel_Text = "$ $ $",
			Goods = { rgb(255, 210, 60), rgb(90, 220, 90) }, Keeper = "nibbles",
		})
		shopPad(model, Vector3.new(x, 0, z + 11), rgb(255, 70, 70), "SELL")
		shopArea("Sell", Vector3.new(x, 0, z + 11), 7)
	end
	-- FUSE MACHINE: máquina azul de bloquinhos, 3 chaminés, tela com "?" e painel de corações
	do
		local x = -75
		local model = Instance.new("Model")
		model.Name = "FuseMachine"
		model.Parent = hub
		block(model, "Floor", Vector3.new(22, 1, 15), CFrame.new(x, 0.5, z - 3), rgb(70, 75, 95), true)
		block(model, "Body", Vector3.new(16, 12, 10), CFrame.new(x, 7, z - 4), rgb(50, 120, 230), true)
		block(model, "Top", Vector3.new(17, 2, 11), CFrame.new(x, 14, z - 4), rgb(40, 95, 190), true)
		for _, side in { -1, 1 } do
			block(model, "Pipe", Vector3.new(2, 10, 2), CFrame.new(x + side * 9.5, 6, z - 4), rgb(200, 200, 215), true)
			deco(model, "Bulb", Vector3.new(2.4, 2.4, 2.4), CFrame.new(x + side * 9.5, 12, z - 4), rgb(120, 255, 200), Enum.Material.Neon, Enum.PartType.Ball)
		end
		for k = -1, 1 do
			block(model, "Chimney", Vector3.new(2.4, 6, 2.4), CFrame.new(x + k * 5, 18, z - 6), rgb(70, 140, 240), true)
			local smoke = deco(model, "Smoke", Vector3.new(2.6, 2.6, 2.6), CFrame.new(x + k * 5, 22, z - 6), rgb(220, 230, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			smoke.Transparency = 0.3
			local puff = Instance.new("ParticleEmitter")
			puff.Color = ColorSequence.new(rgb(230, 240, 255))
			puff.Size = NumberSequence.new(1.5, 3)
			puff.Transparency = NumberSequence.new(0.3, 1)
			puff.Lifetime = NumberRange.new(1.5, 2.5)
			puff.Rate = 3
			puff.Speed = NumberRange.new(2, 3)
			puff.EmissionDirection = Enum.NormalId.Top
			puff.Parent = smoke
		end
		local screen = part(model, "Screen", Vector3.new(8, 5, 0.4), CFrame.new(x - 2, 8.5, z + 1.2), rgb(240, 250, 255), Enum.Material.Neon)
		surface(screen, Enum.NormalId.Back, { { "?", rgb(60, 110, 220), 0.95 } }, 20)
		local hearts = part(model, "HeartPanel", Vector3.new(3.4, 5, 0.4), CFrame.new(x + 5, 8.5, z + 1.2), rgb(255, 120, 170), Enum.Material.Neon)
		surface(hearts, Enum.NormalId.Back, { { "\u{2764}", WHITE, 0.3 }, { "\u{2764}", WHITE, 0.3 }, { "\u{2764}", WHITE, 0.3 } }, 20)
		local sign = part(model, "SignBoard", Vector3.new(18, 4, 1), CFrame.new(x, 4.2, z + 3.5), rgb(40, 95, 190), Enum.Material.SmoothPlastic, { CanCollide = false })
		surface(sign, Enum.NormalId.Back, { { "\u{1F9EC} FUSE MACHINE", WHITE, 0.6 }, { "3 pets = 1 better pet", rgb(150, 230, 255), 0.3 } }, 24, rgb(40, 110, 220))
		local anchor = part(model, "SignAnchor", Vector3.one, CFrame.new(x, 27, z), WHITE, nil, { Transparency = 1, CanCollide = false })
		local bb = billboard(anchor, Vector3.zero, UDim2.fromScale(14, 5), { { "Fuse Machine", rgb(90, 220, 255), 0.6 }, { "0/3", WHITE, 0.4 } }, 220)
		World.FuseSign = bb:FindFirstChild("Line2")
		shopPad(model, Vector3.new(x, 0, z + 11), rgb(90, 200, 255), "FUSE")
		shopArea("Fuse", Vector3.new(x, 0, z + 11), 7)
	end
	-- TRAILS SHOP: arco arco-íris (passou por baixo = abre a loja de trilhas)
	do
		local x = 75
		local model = Instance.new("Model")
		model.Name = "TrailsShop"
		model.Parent = hub
		local colors = { rgb(255, 90, 110), rgb(255, 160, 60), rgb(255, 220, 60), rgb(90, 230, 90), rgb(60, 150, 255), rgb(170, 90, 255) }
		for _, dx in { -9, 9 } do
			block(model, "Pillar", Vector3.new(3, 16, 3), CFrame.new(x + dx, 8, z), rgb(150, 90, 230), true)
			block(model, "PillarBase", Vector3.new(4.4, 2, 4.4), CFrame.new(x + dx, 1, z), rgb(110, 60, 190), true)
			deco(model, "PillarGlow", Vector3.new(3.2, 1, 3.2), CFrame.new(x + dx, 14, z), rgb(255, 230, 120), Enum.Material.Neon)
			deco(model, "Orb", Vector3.new(3, 3, 3), CFrame.new(x + dx, 17.5, z), rgb(255, 240, 160), Enum.Material.Neon, Enum.PartType.Ball)
		end
		-- arco-íris por cima
		for k, c in colors do
			local r = 12 - (k - 1) * 0.9
			for step = 0, 12 do
				local a = math.rad(step * 15)
				deco(model, "Rainbow", Vector3.new(0.9, 3.2, 1.6), CFrame.new(x + math.cos(a) * r, 16 + math.sin(a) * r * 0.55, z - 1) * CFrame.Angles(0, 0, a), c, Enum.Material.Neon)
			end
		end
		local sign = block(model, "Sign", Vector3.new(22, 5, 2), CFrame.new(x, 18.5, z + 0.5), rgb(120, 60, 200), true)
		surface(sign, Enum.NormalId.Back, { { "\u{2728} TRAILS SHOP", WHITE, 0.85 } }, 20, rgb(140, 70, 220))
		surface(sign, Enum.NormalId.Front, { { "\u{2728} TRAILS SHOP", WHITE, 0.85 } }, 20, rgb(140, 70, 220))
		for k, c in colors do
			deco(model, "TrailStripe", Vector3.new(2.4, 0.12, 16), CFrame.new(x - 7.2 + (k - 1) * 2.9, 0.08, z), c, Enum.Material.Neon).Transparency = 0.3
		end
		sparkles(sign, rgb(255, 240, 160))
		shopArea("Trails", Vector3.new(x, 0, z), 7)
	end
	-- BAÚ GRÁTIS: pedestal dourado com baú vermelho e dourado, "FREE!"
	do
		local x = 118
		local model = Instance.new("Model")
		model.Name = "FreeChest"
		model.Parent = hub
		deco(model, "Pedestal", Vector3.new(2, 12, 12), CFrame.new(x, 1, z) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 205, 60), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		deco(model, "PedestalTop", Vector3.new(0.4, 10, 10), CFrame.new(x, 2.1, z) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 235, 140), Enum.Material.Neon, Enum.PartType.Cylinder)
		block(model, "ChestBody", Vector3.new(7, 4, 5), CFrame.new(x, 4.2, z), rgb(200, 40, 50), true)
		block(model, "ChestLid", Vector3.new(7.2, 2, 5.2), CFrame.new(x, 7.2, z), rgb(220, 50, 60), true)
		for _, dx in { -2.6, 2.6 } do
			deco(model, "GoldBand", Vector3.new(0.8, 6.2, 5.4), CFrame.new(x + dx, 5.3, z), rgb(255, 205, 50), Enum.Material.SmoothPlastic)
		end
		local lockPart = deco(model, "GoldLock", Vector3.new(1.4, 1.6, 0.4), CFrame.new(x, 6, z + 2.7), rgb(255, 215, 60), Enum.Material.Neon)
		sparkles(lockPart, rgb(255, 230, 120))
		-- BAÚ DO TOOLBOX: se existir ServerStorage > ToolboxAssets > "Chest", ele entra no lugar do baú de bloquinhos
		local fancyChest = placeAsset(model, "Chest", Vector3.new(x, 2.2, z), 8, math.pi, true)
		if fancyChest then
			fancyChest.Name = "ChestModel"
			for _, name in { "ChestBody", "ChestLid", "GoldBand" } do
				for _, item in model:GetChildren() do
					if item.Name == name and item:IsA("BasePart") then
						item.Transparency = 1
						item.CanCollide = false
					end
				end
			end
			lockPart.Transparency = 1
			lockPart.CFrame = CFrame.new(x, 5, z)
		end
		local anchor = part(model, "SignAnchor", Vector3.one, CFrame.new(x, 13, z), WHITE, nil, { Transparency = 1, CanCollide = false })
		local sign = billboard(anchor, Vector3.zero, UDim2.fromScale(11, 4.5), { { "\u{1F381} FREE CHEST!", rgb(90, 255, 90), 0.55 }, { "Join our community to open", WHITE, 0.3 } }, 200)
		World.ChestSign = sign
		World.ChestPrompt = lockPart
		shopPad(model, Vector3.new(x, 0, z + 11), rgb(255, 200, 50), "FREE")
		shopArea("Chest", Vector3.new(x, 0, z + 11), 6)
	end
	-- BOOSTS: barraquinha roxa de poções
	do
		local x = 160
		local model = Instance.new("Model")
		model.Name = "BoostStand"
		model.Parent = hub
		stall(model, x, z, {
			Wall = rgb(210, 190, 255), RoofA = rgb(150, 90, 230), RoofB = WHITE, SignColor = rgb(140, 70, 220),
			Title = "\u{1F9EA} BOOSTS", Sub = "2x Money - 2x Speed", Panel = rgb(255, 120, 200), Panel_Text = "\u{26A1} POWER \u{26A1}",
			Goods = { rgb(255, 80, 140), rgb(90, 220, 80), rgb(255, 200, 60), rgb(80, 180, 255) }, GoodsNeon = true, Keeper = "squeak",
		})
		for k = -1, 1 do
			local bottle = deco(model, "Potion", Vector3.new(2, 2.4, 2), CFrame.new(x + k * 4, 6.4, z + 2), ({ rgb(255, 80, 140), rgb(90, 220, 80), rgb(255, 200, 60) })[k + 2], Enum.Material.Neon, Enum.PartType.Ball)
			bottle.Transparency = 0.1
		end
		shopPad(model, Vector3.new(x, 0, z + 11), rgb(200, 110, 255), "BOOSTS")
		shopArea("Boosts", Vector3.new(x, 0, z + 11), 7)
	end
end

-- placares grandes (moldura azul) nos fundos do hub
local function buildBoards(hub: Instance)
	for index, info in { { "MOST MONEY/s", rgb(90, 255, 90), -150 }, { "MOST SPEED", rgb(255, 90, 150), 150 } } do
		local x = info[3]
		local frame = block(hub, "BoardFrame", Vector3.new(30, 40, 2), CFrame.new(x, 24, -212), rgb(40, 110, 220), true)
		block(hub, "BoardLegA", Vector3.new(2, 6, 2), CFrame.new(x - 12, 3, -212), rgb(40, 110, 220), true)
		block(hub, "BoardLegB", Vector3.new(2, 6, 2), CFrame.new(x + 12, 3, -212), rgb(40, 110, 220), true)
		local screen = part(hub, "Board" .. index, Vector3.new(27, 37, 0.4), CFrame.new(x, 24, -210.9), rgb(20, 25, 45), Enum.Material.SmoothPlastic)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		local title = makeLabel(gui, info[1], info[2], 0.09)
		title.Position = UDim2.fromScale(0.02, 0.01)
		local rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.BackgroundTransparency = 1
		rows.Position = UDim2.fromScale(0.04, 0.11)
		rows.Size = UDim2.fromScale(0.92, 0.87)
		rows.Parent = gui
		for r = 1, 10 do
			local row = makeLabel(rows, "", WHITE, 0.095, r)
			row.Name = "Row" .. r
			row.Position = UDim2.fromScale(0, (r - 1) * 0.1)
			row.TextXAlignment = Enum.TextXAlignment.Left
		end
		gui.Parent = screen
		local _ = frame
		table.insert(World.Boards, { Kind = if index == 1 then "Income" else "Speed", Gui = gui })
	end
end

---------------------------------------------------------------------
-- Zonas
---------------------------------------------------------------------
local function buildZone(index: number, def, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = ("Zone%02d_%s"):format(index, def.Id)
	folder.Parent = mapFolder
	local L, W, H = M.LaneLength, M.LaneWidth, M.WallHeight
	local z0 = L * (index - 1)
	local z1 = z0 + L
	local half = W / 2
	-- Config.Map.NaturalTerrain = false -> volta o mapa de bloquinhos com pininhos (o Arthur preferiu esse)
	local ok, natural = true, false
	if Config.Map.NaturalTerrain then
		ok, natural = pcall(terrainZone, def, z0, z1, rng)
	end
	if ok and natural then
		-- pista central de bloquinho (o "tapete" que leva até os ninhos) + bordas claras
		local path = M.PathWidth or 40
		checkerFloor(folder, -path / 2, path / 2, z0, z1, def.Floor, 10)
		for _, side in { -1, 1 } do
			deco(folder, "PathEdge", Vector3.new(1.6, 0.5, L), CFrame.new(side * (path / 2 + 0.8), 0.1, z0 + L / 2), def.Floor[1]:Lerp(WHITE, 0.55), Enum.Material.SmoothPlastic)
			-- parede invisível (ninguém escala o cânion)
			part(folder, "Barrier", Vector3.new(3, 400, L), CFrame.new(side * (half + 1.5), 200, z0 + L / 2), WHITE, nil, { Transparency = 1, CanQuery = false })
		end
	else
		if not ok then
			warn("terrainZone falhou:", natural)
		end
		checkerFloor(folder, -half, half, z0, z1, def.Floor, 20)
		checkerWall(folder, Vector3.new(-half - 1.5, 0, z0), Vector3.new(-half - 1.5, 0, z1), H, def.Wall, def.Top)
		checkerWall(folder, Vector3.new(half + 1.5, 0, z0), Vector3.new(half + 1.5, 0, z1), H, def.Wall, def.Top)
	end
	-- faixa clara na divisa com a zona anterior
	deco(folder, "Boundary", Vector3.new(W, 0.25, 2), CFrame.new(0, 0.12, z0 + 1), def.Floor[1]:Lerp(WHITE, 0.6), Enum.Material.SmoothPlastic)
	-- placa de madeira na entrada (lado esquerdo de quem chega do hub), olhando para o hub
	block(folder, "SignPost", Vector3.new(1.6, 9, 1.6), CFrame.new(-half + 18, 4.5, z0 + 8), rgb(120, 75, 40), true)
	local board = block(folder, "Sign", Vector3.new(24, 9, 1.4), CFrame.new(-half + 18, 12.5, z0 + 8), rgb(165, 105, 60), true)
	board:AddTag("ZoneSign")
	board:SetAttribute("Need", def.Speed)
	surface(board, Enum.NormalId.Front, {
		{ ("%s %s"):format(def.Emoji or "", string.upper(def.Name)), WHITE, 0.45 },
		{ if def.Speed > 0 then "Recommended Speed: " .. (function()
			local n = def.Speed
			if n >= 1e9 then
				return (n / 1e9) .. "B"
			elseif n >= 1e6 then
				return (n / 1e6) .. "M"
			elseif n >= 1e3 then
				return (n / 1e3) .. "K"
			end
			return tostring(n)
		end)() else "SPEED: DEFAULT", rgb(120, 255, 120), 0.4 },
	}, 25, rgb(150, 95, 55))
	-- PORTAL de entrada da zona (arco com as cores do tema, nome e velocidade recomendada)
	if index > 1 then
		local pillarColor = def.Wall[1]
		local glow = def.Top or def.Floor[1]
		for _, side in { -1, 1 } do
			local px = side * (half - 6)
			block(folder, "PortalPillar", Vector3.new(7, 36, 7), CFrame.new(px, 18, z0 + 3), pillarColor, true)
			block(folder, "PortalBase", Vector3.new(10, 3, 10), CFrame.new(px, 1.5, z0 + 3), pillarColor:Lerp(Color3.new(0, 0, 0), 0.25), true)
			deco(folder, "PortalOrb", Vector3.new(6, 6, 6), CFrame.new(px, 39, z0 + 3), glow, Enum.Material.Neon, Enum.PartType.Ball)
			for k = 1, 3 do
				deco(folder, "PortalRing", Vector3.new(7.6, 1, 7.6), CFrame.new(px, 8 * k, z0 + 3), glow, Enum.Material.Neon)
			end
		end
		local beam = block(folder, "PortalBeam", Vector3.new(W - 6, 8, 4), CFrame.new(0, 32, z0 + 3), pillarColor, true)
		local label = ("%s %s"):format(def.Emoji or "", string.upper(def.Name))
		surface(beam, Enum.NormalId.Front, { { label, WHITE, 0.9 } }, 5, glow:Lerp(Color3.new(0, 0, 0), 0.25))
		surface(beam, Enum.NormalId.Back, { { "\u{2B05} BACK TO SAFE ZONE", WHITE, 0.8 } }, 5, glow:Lerp(Color3.new(0, 0, 0), 0.25))
		deco(folder, "PortalGlowLine", Vector3.new(W - 10, 0.6, 0.6), CFrame.new(0, 27.7, z0 + 1), glow, Enum.Material.Neon)
	end
	-- área do ninho: chão de terra em volta do guardião (a 75% da zona)
	local center = Vector3.new(0, 0, z0 + L * 0.75)
	local radius = math.max(12, 3 + def.Height * 0.55 + 4)
	deco(folder, "NestGround", Vector3.new(0.3, radius * 2 + 12, radius * 2 + 12), CFrame.new(center + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), def.Floor[1]:Lerp(rgb(150, 110, 70), 0.45), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local nests = {}
	for n = 1, Config.NestsPerZone do
		local angle = math.rad(-90 + (n - 1) * 360 / Config.NestsPerZone)
		local spot = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		for k = 1, 10 do
			local a = math.rad(k * 36)
			deco(folder, "Straw", Vector3.new(2.6, 1, 1), CFrame.new(spot + Vector3.new(math.cos(a) * 3, 0.5, math.sin(a) * 3)) * CFrame.Angles(0, -a + math.pi / 2, math.rad(rng:NextNumber(-20, 20))), if k % 2 == 0 then rgb(222, 182, 100) else rgb(176, 130, 68), Enum.Material.Fabric)
		end
		deco(folder, "NestBed", Vector3.new(0.5, 5.4, 5.4), CFrame.new(spot + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(176, 130, 68), Enum.Material.Fabric, Enum.PartType.Cylinder)
		table.insert(nests, CFrame.lookAt(spot + Vector3.new(0, 0.6, 0), Vector3.new(spot.X, 0.6, z0 - 50)))
	end
	props(folder, def.Props, z0 + 22, z1 - 8, rng)
	table.insert(World.Zones, {
		Index = index,
		Def = def,
		Z0 = z0,
		Z1 = z1,
		Center = center,
		Nests = nests,
		Folder = folder,
	})
end

---------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = rgb(120, 120, 130)
	Lighting.OutdoorAmbient = rgb(160, 160, 170)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("ColorCorrectionEffect") or child:IsA("BloomEffect") or child:IsA("Sky") or child:IsA("DepthOfFieldEffect") or child:IsA("SunRaysEffect") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = rgb(200, 225, 255)
	atmosphere.Decay = rgb(120, 170, 230)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.05
	color.Brightness = 0.02
	color.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.Parent = Lighting
end

function World.Build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace
	local rng = Random.new(2026)
	setupLighting()
	pcall(setupTerrain)

	local hw, hd = M.HubWidth / 2, M.HubDepth
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = mapFolder
	checkerFloor(hub, -hw, hw, -hd, 0, { rgb(96, 200, 60), rgb(84, 180, 52) }, 16)
	local wallColors = { rgb(214, 120, 64), rgb(190, 100, 52) }
	local grass = rgb(80, 200, 60)
	checkerWall(hub, Vector3.new(-hw, 0, -hd - 1.5), Vector3.new(hw, 0, -hd - 1.5), M.WallHeight, wallColors, grass)
	checkerWall(hub, Vector3.new(-hw - 1.5, 0, -hd), Vector3.new(-hw - 1.5, 0, 0), M.WallHeight, wallColors, grass)
	checkerWall(hub, Vector3.new(hw + 1.5, 0, -hd), Vector3.new(hw + 1.5, 0, 0), M.WallHeight, wallColors, grass)
	local lane = M.LaneWidth / 2
	checkerWall(hub, Vector3.new(-hw, 0, 1.5), Vector3.new(-lane - 3, 0, 1.5), M.WallHeight, wallColors, grass)
	checkerWall(hub, Vector3.new(lane + 3, 0, 1.5), Vector3.new(hw, 0, 1.5), M.WallHeight, wallColors, grass)

	-- avenida de areia em frente às bases até a pista
	deco(hub, "Avenue", Vector3.new(M.HubWidth - 20, 0.2, 16), CFrame.new(0, 0.07, -55), rgb(235, 215, 160), Enum.Material.SmoothPlastic)
	deco(hub, "MainPath", Vector3.new(24, 0.2, 55), CFrame.new(0, 0.07, -27), rgb(235, 215, 160), Enum.Material.SmoothPlastic)

	-- SAFE ZONE: letras pretas em itálico, contorno branco, com pílulas azul/branco nas pontas
	local safe = part(hub, "SafeZone", Vector3.new(M.LaneWidth - 12, 0.2, 5), CFrame.new(0, 0.11, -2.5), WHITE, nil, { CanCollide = false, CanQuery = false, Transparency = 1 })
	local safeGui = Instance.new("SurfaceGui")
	safeGui.Face = Enum.NormalId.Top
	safeGui.LightInfluence = 0
	safeGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	safeGui.PixelsPerStud = 14
	local safeText = Instance.new("TextLabel")
	safeText.Size = UDim2.fromScale(1, 1)
	safeText.BackgroundTransparency = 1
	safeText.Font = Enum.Font.FredokaOne
	safeText.TextScaled = true
	safeText.Text = "<i>SAFE ZONE     SAFE ZONE     SAFE ZONE</i>"
	safeText.RichText = true
	safeText.TextColor3 = rgb(15, 15, 20)
	local safeStroke = Instance.new("UIStroke")
	safeStroke.Thickness = 3
	safeStroke.Color = WHITE
	safeStroke.Parent = safeText
	safeText.Parent = safeGui
	safeGui.Parent = safe
	for _, side in { -1, 1 } do
		local x = side * (lane - 4)
		deco(hub, "SafeCapBlue", Vector3.new(5, 0.5, 2.6), CFrame.new(x - side * 1.2, 0.25, -2.5), rgb(40, 120, 255), Enum.Material.SmoothPlastic)
		deco(hub, "SafeCapWhite", Vector3.new(2.6, 0.55, 2.6), CFrame.new(x + side * 1.6, 0.27, -2.5), WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder).CFrame = CFrame.new(x + side * 1.6, 0.27, -2.5) * CFrame.Angles(0, 0, math.rad(90))
	end
	-- arco da entrada das zonas
	for _, side in { -1, 1 } do
		block(hub, "GatePillar", Vector3.new(6, 30, 6), CFrame.new(side * (lane - 2), 15, 3), rgb(150, 95, 55), true)
	end
	local gate = block(hub, "GateSign", Vector3.new(M.LaneWidth + 4, 8, 3), CFrame.new(0, 33, 3), rgb(165, 105, 60), true)
	surface(gate, Enum.NormalId.Front, { { "\u{1F95A} STEAL THE EGGS! \u{1F95A}", rgb(255, 230, 90), 0.8 } }, 6)
	surface(gate, Enum.NormalId.Back, { { "\u{2B05} BACK TO SAFE ZONE", WHITE, 0.8 } }, 6)

	-- muro da noite (embaixo do chão; sobe quando escurece). Contagem gigante do lado das zonas.
	local nightWall = part(mapFolder, "NightWall", Vector3.new(M.LaneWidth + 6, 90, 3), CFrame.new(0, -46, 6), WHITE, Enum.Material.SmoothPlastic, { CanCollide = false })
	local nightGui = surface(nightWall, Enum.NormalId.Back, { { "", rgb(255, 235, 140), 0.9 } }, 3, rgb(25, 30, 80))
	World.NightCountdown = nightGui:FindFirstChild("Line1")
	nightWall.Color = rgb(30, 35, 85)
	-- lado do hub: céu estrelado com lua
	local starGui = surface(nightWall, Enum.NormalId.Front, {
		{ "\u{1F319}", WHITE, 0.3 },
		{ "NIGHT TIME", rgb(255, 235, 140), 0.16 },
		{ ("Eggs are growing x%d!"):format(Config.NightGrowth), rgb(170, 200, 255), 0.09 },
	}, 3, rgb(25, 30, 80))
	local starRng = Random.new(7)
	for _ = 1, 60 do
		local star = Instance.new("Frame")
		star.Name = "Star"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(starRng:NextNumber(0.03, 0.97), starRng:NextNumber(0.03, 0.97))
		local size = starRng:NextInteger(2, 5)
		star.Size = UDim2.fromOffset(size, size)
		star.Rotation = 45
		star.BackgroundColor3 = rgb(255, 250, 200)
		star.BackgroundTransparency = starRng:NextNumber(0, 0.4)
		star.BorderSizePixel = 0
		star.ZIndex = 0
		star.Parent = starGui:FindFirstChild("Background")
	end
	World.NightWall = nightWall
	for _, item in nightWall:GetChildren() do
		if item:IsA("SurfaceGui") then
			item.Enabled = false
		end
	end

	-- nome do jogo no fundo do hub
	local title = block(hub, "TitleSign", Vector3.new(130, 22, 3), CFrame.new(0, 50, -hd + 2), rgb(255, 200, 60), true)
	surface(title, Enum.NormalId.Back, { { string.upper(Config.GameName), WHITE, 0.9 } }, 6, rgb(255, 170, 40))

	-- enfeites do hub: árvores e flores nos cantos, postes de luz na avenida
	local treeNames = { "TreeA", "TreeB", "TreeC", "PineTree" }
	for k = 0, 9 do
		local x = -hw + 14 + k * ((M.HubWidth - 28) / 9)
		if not placeAsset(hub, treeNames[k % 4 + 1], Vector3.new(x, 0, -hd + 10), rng:NextNumber(22, 30), rng:NextNumber(0, 6)) then
			tree(hub, Vector3.new(x, 0, -hd + 10), rng:NextNumber(1.1, 1.5))
		end
	end
	for _, side in { -1, 1 } do
		for k = 0, 4 do
			if not placeAsset(hub, treeNames[(k + 1) % 4 + 1], Vector3.new(side * (hw - 10), 0, -hd + 40 + k * 40), rng:NextNumber(20, 28), rng:NextNumber(0, 6)) then
				tree(hub, Vector3.new(side * (hw - 10), 0, -hd + 40 + k * 40), rng:NextNumber(1, 1.3))
			end
		end
		for k = 0, 2 do
			local p = Vector3.new(side * (lane + 18 + k * 16), 0, -10 - (k % 2) * 4)
			if not placeAsset(hub, if k == 1 then "FlowerBush" else "Flower", p, rng:NextNumber(3.5, 5), rng:NextNumber(0, 6)) then
				flowers(hub, p, rng)
			end
		end
		placeAsset(hub, "Bush", Vector3.new(side * (hw - 24), 0, -12), 6, rng:NextNumber(0, 6))
		placeAsset(hub, "Bench", Vector3.new(side * 112, 0, -8), 3.8, if side < 0 then math.pi else 0)
	end
	for k = -3, 3 do
		if not placeAsset(hub, "Lamp", Vector3.new(k * 58 + 29, 0, -64), 14, 0) then
			lamp(hub, Vector3.new(k * 58 + 29, 0, -64))
		else
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 1.3
			light.Color = rgb(255, 225, 160)
			local anchorPart = part(hub, "LampLight", Vector3.one, CFrame.new(k * 58 + 29, 13, -64), WHITE, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
			light.Parent = anchorPart
		end
	end
	-- nuvens grandes no céu (o mapa todo)
	for k = 1, 18 do
		placeAsset(hub, "Cloud", Vector3.new(rng:NextNumber(-280, 280), rng:NextNumber(110, 160), rng:NextNumber(-260, 3000)), rng:NextNumber(18, 34), rng:NextNumber(0, 6))
	end

	for i = 1, M.Plots do
		buildPlot(i, (i - (M.Plots + 1) / 2) * M.PlotSpacing)
	end
	for _, plot in World.Plots do
		World.BuildPen(plot, 0)
	end
	buildShops(hub)
	buildBoards(hub)
	for index, def in Config.Zones do
		buildZone(index, def, rng)
		task.wait()
	end
	local lastZ = M.LaneLength * #Config.Zones
	local endBiome = BIOMES[Config.Zones[#Config.Zones].Id]
	local okEnd = Config.Map.NaturalTerrain and endBiome and pcall(function()
		workspace.Terrain:FillBlock(CFrame.new(0, 44, lastZ + 18), Vector3.new(M.LaneWidth + 110, 92, 32), endBiome.Cliff)
		workspace.Terrain:FillBlock(CFrame.new(0, 92, lastZ + 18), Vector3.new(M.LaneWidth + 110, 4, 32), endBiome.Cap)
		part(mapFolder, "EndBarrier", Vector3.new(M.LaneWidth + 10, 400, 3), CFrame.new(0, 200, lastZ + 1.5), WHITE, nil, { Transparency = 1, CanQuery = false })
	end)
	if not okEnd then
		checkerWall(mapFolder, Vector3.new(-lane - 1.5, 0, lastZ + 1.5), Vector3.new(lane + 1.5, 0, lastZ + 1.5), M.WallHeight, Config.Zones[#Config.Zones].Wall, Config.Zones[#Config.Zones].Top)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, -45)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = mapFolder
end

return World
