--[[
	Customize (ModuleScript em ServerScriptService > Game)
	Parte 15: personalização (só visual, nada dá vantagem).
	  • Tema da base: troca cores/materiais da base inteira e coloca enfeites do tema nas paredes e torres
	  • Decoração: 8 vagas no chão da base; cada vaga recebe um enfeite que você já tem
	  • Trilha: rastro colorido atrás do avatar
	  • Título: texto em cima da cabeça (ganho com conquistas); VIP aparece aqui também
	  • Premium: +Config.PremiumBonus de dinheiro (fica no Economy) e o título "Premium"
	O catálogo (nomes, preços, requisitos) fica em ReplicatedStorage > Shared > Cosmetics.
	Todos veem a base e o avatar de todos, então os enfeites são criados aqui no servidor.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Customize = {}

-- Vagas de decoração: (lado, frente) dentro da base. + = lado esquerdo/entrada. Ficam longe dos pedestais,
-- do botão de trancar, do coletor e da esteira de treino.
local DECOR_SPOTS = { -- v20: base mais funda (frente = +44, fundo = -44)
	{ 12, 20 }, { -26, 21 }, -- a vaga 1 saiu do canto da direita (lá fica a rampa do 2º andar)
	{ 27, 5 }, { -27, 5 },
	{ 27, -11 }, { -27, -11 },
	{ 27, -25 }, { -27, -25 },
}
-- Enfeites do tema: em cima das paredes (y = 15.3) e das 4 torres (y = 25)
local WALL_PROPS = { { 31, -28 }, { 31, -4 }, { 31, 20 }, { -31, -28 }, { -31, -4 }, { -31, 20 }, { 16, -43 }, { -16, -43 } }
local TOWER_PROPS = { { 31, 43 }, { -31, 43 }, { 31, -43 }, { -31, -43 } }
local WALL_TOP = 15.3
local FLOOR2_WALL_TOP = 21.8 -- com o 2º andar, os enfeites de trás sobem para cima do vidro
local FLOOR2_FRONT = 18 -- o 2º andar cobre a base de lf = -44 até lf = 18
local TOWER_TOP = 25
local FLOOR_TOP = 0.55

local WALL_NAMES = { "WallBack", "WallLeft", "WallRight", "WallFrontA", "WallFrontB" }

local defaults: { [any]: { [BasePart]: { Color: Color3, Material: Enum.Material } } } = {}

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function isPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end
Customize.IsPremium = isPremium

---------------------------------------------------------------------
-- Peças
---------------------------------------------------------------------
local function newPart(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function ball(parent: Instance, cf: CFrame, d: number, color: Color3, material: Enum.Material?): Part
	return newPart(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * d, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic })
end

-- cilindro em pé (o cilindro do Roblox deita no eixo X, então giramos)
local function vcyl(parent: Instance, cf: CFrame, d: number, h: number, color: Color3, material: Enum.Material?): Part
	return newPart(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, d, d),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function block(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	return newPart(parent, { Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic })
end

-- ovo/elipse (esfera esticada)
local function ellipsoid(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = block(parent, cf, size, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function tagMover(model: Model, spin: number?, bob: number?)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- chega inteiro na tela (o centro do giro fica certo)
	if spin then
		model:SetAttribute("SpinSpeed", spin)
		model:AddTag("Spin")
	end
	if bob then
		model:SetAttribute("BobHeight", bob)
		model:AddTag("Bob")
	end
end

---------------------------------------------------------------------
-- Enfeites de decoração (cada um cabe num círculo de ~5 studs)
---------------------------------------------------------------------
local DECOR_BUILDERS: { [string]: (Model, CFrame) -> () } = {
	flowers = function(m, cf)
		vcyl(m, cf * CFrame.new(0, 1, 0), 2.4, 2, rgb(190, 110, 70))
		ball(m, cf * CFrame.new(0, 2.4, 0), 2.4, rgb(80, 170, 80), Enum.Material.Grass)
		ball(m, cf * CFrame.new(0.6, 3.4, 0.2), 1.1, rgb(255, 120, 160))
		ball(m, cf * CFrame.new(-0.6, 3.3, -0.3), 1.1, rgb(255, 220, 80))
		ball(m, cf * CFrame.new(0, 3.6, -0.6), 1.1, rgb(190, 120, 255))
	end,
	lamp = function(m, cf)
		vcyl(m, cf * CFrame.new(0, 0.3, 0), 1.8, 0.6, rgb(50, 50, 60), Enum.Material.Metal)
		vcyl(m, cf * CFrame.new(0, 4, 0), 0.5, 7, rgb(50, 50, 60), Enum.Material.Metal)
		ball(m, cf * CFrame.new(0, 7.9, 0), 1.7, rgb(255, 235, 150), Enum.Material.Neon)
		vcyl(m, cf * CFrame.new(0, 8.9, 0), 1.9, 0.4, rgb(50, 50, 60), Enum.Material.Metal)
	end,
	bush = function(m, cf)
		ball(m, cf * CFrame.new(0, 1.6, 0), 3.6, rgb(80, 180, 70), Enum.Material.Grass)
		ball(m, cf * CFrame.new(1.1, 2.4, 0.3), 2.6, rgb(100, 200, 85), Enum.Material.Grass)
		ball(m, cf * CFrame.new(-1, 2.2, -0.5), 2.4, rgb(70, 165, 65), Enum.Material.Grass)
	end,
	balloons = function(m, cf)
		block(m, cf * CFrame.new(0, 0.3, 0), Vector3.new(1.2, 0.6, 1.2), rgb(90, 90, 100))
		local colors = { rgb(255, 80, 90), rgb(80, 160, 255), rgb(255, 220, 70) }
		local offsets = { Vector3.new(0.9, 6.4, 0), Vector3.new(-0.9, 6, 0.4), Vector3.new(0, 7.4, -0.6) }
		for i, offset in offsets do
			local top = cf * CFrame.new(offset)
			local base = cf * CFrame.new(0, 0.6, 0)
			local mid = base.Position:Lerp(top.Position, 0.5)
			local length = (top.Position - base.Position).Magnitude
			newPart(m, { Size = Vector3.new(0.08, length, 0.08), CFrame = CFrame.lookAt(mid, top.Position) * CFrame.Angles(math.rad(90), 0, 0), Color = rgb(240, 240, 240) })
			ellipsoid(m, top * CFrame.new(0, 0.9, 0), Vector3.new(1.8, 2.2, 1.8), colors[i])
		end
		tagMover(m, nil, 0.4)
	end,
	fountain = function(m, cf)
		vcyl(m, cf * CFrame.new(0, 0.5, 0), 4.8, 1, rgb(200, 200, 210), Enum.Material.Marble)
		vcyl(m, cf * CFrame.new(0, 1.02, 0), 4.1, 0.1, rgb(110, 200, 255), Enum.Material.Glass).Transparency = 0.25
		vcyl(m, cf * CFrame.new(0, 2.2, 0), 0.8, 2.4, rgb(200, 200, 210), Enum.Material.Marble)
		vcyl(m, cf * CFrame.new(0, 3.5, 0), 2.2, 0.4, rgb(200, 200, 210), Enum.Material.Marble)
		ball(m, cf * CFrame.new(0, 4.1, 0), 0.9, rgb(150, 225, 255), Enum.Material.Neon)
	end,
	eggstatue = function(m, cf)
		block(m, cf * CFrame.new(0, 0.7, 0), Vector3.new(2.8, 1.4, 2.8), rgb(235, 235, 240), Enum.Material.Marble)
		local egg = Instance.new("Model")
		egg.Name = "Egg"
		ellipsoid(egg, cf * CFrame.new(0, 3.1, 0), Vector3.new(2.4, 3.2, 2.4), rgb(255, 200, 60), Enum.Material.Foil)
		egg.Parent = m
		tagMover(egg, 0.6, 0.25)
	end,
	trophy = function(m, cf)
		block(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(2.4, 1, 2.4), rgb(60, 40, 30), Enum.Material.Wood)
		vcyl(m, cf * CFrame.new(0, 1.8, 0), 0.6, 1.6, rgb(255, 205, 60), Enum.Material.Foil)
		vcyl(m, cf * CFrame.new(0, 3.3, 0), 2.2, 1.8, rgb(255, 205, 60), Enum.Material.Foil)
		ball(m, cf * CFrame.new(1.3, 3.5, 0), 0.8, rgb(255, 205, 60), Enum.Material.Foil)
		ball(m, cf * CFrame.new(-1.3, 3.5, 0), 0.8, rgb(255, 205, 60), Enum.Material.Foil)
		ball(m, cf * CFrame.new(0, 4.7, 0), 0.9, rgb(255, 255, 200), Enum.Material.Neon)
	end,
	lollipop = function(m, cf)
		vcyl(m, cf * CFrame.new(0, 3.5, 0), 0.4, 7, rgb(250, 250, 250))
		newPart(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3.8, 3.8), CFrame = cf * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(90), 0), Color = rgb(255, 110, 190) })
		newPart(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.56, 2.6, 2.6), CFrame = cf * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(90), 0), Color = rgb(255, 255, 255) })
		newPart(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.62, 1.4, 1.4), CFrame = cf * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(90), 0), Color = rgb(120, 220, 255) })
	end,
	snowman = function(m, cf)
		local white = rgb(245, 250, 255)
		ball(m, cf * CFrame.new(0, 1.5, 0), 3.2, white, Enum.Material.Snow)
		ball(m, cf * CFrame.new(0, 3.6, 0), 2.4, white, Enum.Material.Snow)
		ball(m, cf * CFrame.new(0, 5.2, 0), 1.8, white, Enum.Material.Snow)
		ball(m, cf * CFrame.new(0.35, 5.4, -0.8), 0.3, rgb(20, 20, 20))
		ball(m, cf * CFrame.new(-0.35, 5.4, -0.8), 0.3, rgb(20, 20, 20))
		newPart(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 0.25, 0.25), CFrame = cf * CFrame.new(0, 5.15, -1.1) * CFrame.Angles(0, math.rad(90), 0), Color = rgb(255, 140, 40) })
		vcyl(m, cf * CFrame.new(0, 6.1, 0), 1.9, 0.2, rgb(25, 25, 30))
		vcyl(m, cf * CFrame.new(0, 6.7, 0), 1.2, 1.1, rgb(25, 25, 30))
	end,
	lavalamp = function(m, cf)
		vcyl(m, cf * CFrame.new(0, 0.6, 0), 2, 1.2, rgb(60, 50, 60), Enum.Material.Metal)
		local glass = vcyl(m, cf * CFrame.new(0, 3.2, 0), 1.6, 4, rgb(255, 150, 60), Enum.Material.Glass)
		glass.Transparency = 0.45
		vcyl(m, cf * CFrame.new(0, 5.4, 0), 1.2, 0.5, rgb(60, 50, 60), Enum.Material.Metal)
		for i, y in { 2, 3.4, 4.3 } do
			local blob = Instance.new("Model")
			blob.Name = "Blob" .. i
			ball(blob, cf * CFrame.new(0, y, 0), 0.7 + i * 0.1, rgb(255, 100, 20), Enum.Material.Neon)
			blob.Parent = m
			tagMover(blob, nil, 0.5)
		end
	end,
	coral = function(m, cf)
		ball(m, cf * CFrame.new(0, 0.6, 0), 2.4, rgb(120, 110, 100), Enum.Material.Slate)
		local branches = { { 0, 0, rgb(255, 120, 120) }, { 35, 60, rgb(255, 170, 90) }, { -30, -70, rgb(255, 110, 200) } }
		for _, info in branches do
			local tilt, turn, color = info[1], info[2], info[3]
			local base = cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(turn), math.rad(tilt))
			vcyl(m, base * CFrame.new(0, 2, 0), 0.6, 4, color)
			ball(m, base * CFrame.new(0, 4.1, 0), 1, color)
		end
	end,
	seasontrophy = function(m, cf)
		block(m, cf * CFrame.new(0, 0.6, 0), Vector3.new(2.8, 1.2, 2.8), rgb(70, 50, 120), Enum.Material.Marble)
		vcyl(m, cf * CFrame.new(0, 1.8, 0), 0.7, 1.4, rgb(255, 205, 60), Enum.Material.Foil)
		local cup = Instance.new("Model")
		cup.Name = "Cup"
		vcyl(cup, cf * CFrame.new(0, 3.3, 0), 2, 1.6, rgb(255, 205, 60), Enum.Material.Foil)
		ball(cup, cf * CFrame.new(0, 4.6, 0), 1.2, rgb(255, 120, 220), Enum.Material.Neon)
		cup.Parent = m
		tagMover(cup, 0.7, nil)
	end,
	planet = function(m, cf)
		vcyl(m, cf * CFrame.new(0, 0.4, 0), 2.2, 0.8, rgb(60, 50, 110))
		local orb = Instance.new("Model")
		orb.Name = "Orb"
		ball(orb, cf * CFrame.new(0, 4, 0), 2.6, rgb(170, 110, 255))
		newPart(orb, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 4.4, 4.4),
			CFrame = cf * CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(25), 0, 0),
			Color = rgb(255, 220, 120),
			Material = Enum.Material.Neon,
		})
		orb.Parent = m
		tagMover(orb, 0.8, 0.5)
	end,
}

---------------------------------------------------------------------
-- Enfeites de cada tema (em cima das paredes e torres)
---------------------------------------------------------------------
local PROP_BUILDERS: { [string]: { Wall: (Model, CFrame) -> (), Tower: (Model, CFrame) -> () } } = {
	garden = {
		Wall = function(m, cf)
			ball(m, cf * CFrame.new(0, 1, 0), 2.6, rgb(80, 170, 70), Enum.Material.Grass)
			ball(m, cf * CFrame.new(0.6, 2.2, 0), 1.2, rgb(255, 120, 160))
			ball(m, cf * CFrame.new(-0.6, 2.1, 0.4), 1.2, rgb(255, 230, 90))
		end,
		Tower = function(m, cf)
			vcyl(m, cf * CFrame.new(0, 1, 0), 0.8, 2, rgb(125, 85, 55), Enum.Material.Wood)
			ball(m, cf * CFrame.new(0, 3, 0), 3.4, rgb(90, 180, 75), Enum.Material.Grass)
		end,
	},
	candy = {
		Wall = function(m, cf)
			local colors = { rgb(255, 90, 150), rgb(120, 220, 255), rgb(255, 230, 90), rgb(150, 230, 120) }
			ellipsoid(m, cf * CFrame.new(0, 0.9, 0), Vector3.new(2.8, 2.2, 2.8), colors[math.random(1, #colors)])
		end,
		Tower = function(m, cf)
			vcyl(m, cf * CFrame.new(0, 2, 0), 0.35, 4, rgb(250, 250, 250))
			newPart(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 3, 3), CFrame = cf * CFrame.new(0, 4.5, 0), Color = rgb(255, 100, 180) })
			newPart(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.46, 1.6, 1.6), CFrame = cf * CFrame.new(0, 4.5, 0), Color = rgb(255, 255, 255) })
		end,
	},
	frost = {
		Wall = function(m, cf)
			for i, angle in { -18, 0, 20 } do
				local crystal = block(m, cf * CFrame.new((i - 2) * 0.7, 1.5, 0) * CFrame.Angles(0, 0, math.rad(angle)), Vector3.new(0.8, 3 + i * 0.5, 0.8), rgb(170, 225, 255), Enum.Material.Glass)
				crystal.Transparency = 0.2
			end
		end,
		Tower = function(m, cf)
			ellipsoid(m, cf * CFrame.new(0, 0.2, 0), Vector3.new(5, 2, 5), rgb(250, 252, 255), Enum.Material.Snow)
		end,
	},
	lava = {
		Wall = function(m, cf)
			ball(m, cf * CFrame.new(0, 0.9, 0), 2.6, rgb(60, 45, 45), Enum.Material.Basalt)
			ball(m, cf * CFrame.new(0.4, 1.8, 0), 1.4, rgb(255, 110, 30), Enum.Material.Neon)
		end,
		Tower = function(m, cf)
			local flame = Instance.new("Model")
			flame.Name = "Flame"
			ball(flame, cf * CFrame.new(0, 1, 0), 2, rgb(255, 110, 30), Enum.Material.Neon)
			ball(flame, cf * CFrame.new(0, 2.2, 0), 1.3, rgb(255, 210, 60), Enum.Material.Neon)
			flame.Parent = m
			tagMover(flame, nil, 0.4)
		end,
	},
	reef = {
		Wall = function(m, cf)
			local colors = { rgb(255, 120, 120), rgb(255, 170, 90), rgb(255, 110, 200) }
			local color = colors[math.random(1, #colors)]
			vcyl(m, cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(15)), 0.8, 3, color)
			vcyl(m, cf * CFrame.new(0.5, 1.2, 0) * CFrame.Angles(0, 0, math.rad(-25)), 0.7, 2.4, color)
			ball(m, cf * CFrame.new(-0.4, 3, 0), 1.1, color)
		end,
		Tower = function(m, cf)
			ellipsoid(m, cf * CFrame.new(0, 0.7, 0), Vector3.new(3.2, 1.4, 2.6), rgb(255, 190, 200))
			ball(m, cf * CFrame.new(0, 1.5, 0), 1, rgb(255, 255, 250), Enum.Material.Glass)
		end,
	},
	galaxy = {
		Wall = function(m, cf)
			local star = Instance.new("Model")
			star.Name = "Star"
			ball(star, cf * CFrame.new(0, 1.6, 0), 1.4, rgb(255, 235, 140), Enum.Material.Neon)
			star.Parent = m
			tagMover(star, nil, 0.5)
		end,
		Tower = function(m, cf)
			local planet = Instance.new("Model")
			planet.Name = "Planet"
			ball(planet, cf * CFrame.new(0, 3.5, 0), 3, rgb(120, 80, 220))
			newPart(planet, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.12, 5, 5),
				CFrame = cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0),
				Color = rgb(255, 200, 120),
				Material = Enum.Material.Neon,
			})
			planet.Parent = m
			tagMover(planet, 0.5, 0.6)
		end,
	},
}

---------------------------------------------------------------------
-- Tema da base
---------------------------------------------------------------------
local function localCFrame(plot, lx: number, y: number, lf: number): CFrame
	local origin: CFrame = plot.Origin.CFrame
	local position = (origin * CFrame.new(lx, 0, -lf)).Position
	local center = origin.Position
	local world = Vector3.new(position.X, y, position.Z)
	local look = Vector3.new(center.X, y, center.Z)
	if (look - world).Magnitude < 0.1 then
		return CFrame.new(world)
	end
	return CFrame.lookAt(world, look)
end

local function themeParts(plot): { [string]: { BasePart } }
	local model: Model = plot.Model
	local groups = { Floor = {}, Stripe = {}, Band = {}, Top = {}, Trim = {}, Tower = {}, Cap = {}, Flag = {}, Gate = {}, Rug = {}, Sign = {} }
	local function add(group: string, instance: Instance?)
		if instance and instance:IsA("BasePart") then
			table.insert(groups[group], instance)
		end
	end
	add("Floor", model:FindFirstChild("Floor"))
	for i = 0, 4 do
		add("Stripe", model:FindFirstChild("Stripe" .. i))
		local tower = model:FindFirstChild("Tower" .. i)
		if tower then
			add("Tower", tower:FindFirstChild("Body"))
			add("Cap", tower:FindFirstChild("Cap"))
			add("Flag", tower:FindFirstChild("Flag"))
		end
	end
	for _, name in WALL_NAMES do
		add("Band", model:FindFirstChild(name))
		add("Top", model:FindFirstChild(name .. "Top"))
		add("Trim", model:FindFirstChild(name .. "Trim"))
	end
	for _, name in { "GateA", "GateB", "GateTop" } do
		add("Gate", model:FindFirstChild(name))
	end
	add("Rug", model:FindFirstChild("Rug"))
	add("Sign", model:FindFirstChild("Sign"))
	-- 2º andar (v19): fica guardado fora da base até o dono ter 19 vagas, por isso vem de plot.Floor2
	local floor2 = plot.Floor2 or model:FindFirstChild("Floor2")
	if floor2 then
		add("Floor", floor2:FindFirstChild("Deck"))
		for i = 0, 3 do
			add("Stripe", floor2:FindFirstChild("Stripe" .. i))
		end
		for _, name in { "GlassLeftTrim", "GlassRightTrim", "GlassBackTrim", "RailTrim", "RampRailTrim" } do
			add("Trim", floor2:FindFirstChild(name))
		end
		add("Top", floor2:FindFirstChild("Rail"))
		add("Top", floor2:FindFirstChild("RampRail"))
		add("Band", floor2:FindFirstChild("Ramp"))
		add("Sign", floor2:FindFirstChild("Sign2"))
	end
	return groups
end

local function clearFolder(plot, name: string): Folder
	local model: Model = plot.Model
	local old = model:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = model
	return folder
end

function Customize.ApplyTheme(plot, themeId: string)
	local theme = Cosmetics.ById.theme[themeId]
	local saved = defaults[plot]
	if not saved then
		return
	end
	-- volta tudo ao normal e depois pinta com o tema
	for part, look in saved do
		part.Color = look.Color
		part.Material = look.Material
	end
	local props = clearFolder(plot, "ThemeProps")
	plot.Model:SetAttribute("Theme", themeId)
	if not theme or themeId == "classic" then
		return
	end
	local groups = themeParts(plot)
	local function paint(group: string, spec)
		if not spec then
			return
		end
		local color = if typeof(spec) == "Color3" then spec else spec[1]
		local material = if typeof(spec) == "table" and spec[2] then (Enum.Material :: any)[spec[2]] else nil
		for _, part in groups[group] do
			part.Color = color
			if material then
				part.Material = material
			end
		end
	end
	paint("Floor", theme.Floor)
	paint("Stripe", theme.Stripe)
	paint("Band", theme.Band)
	paint("Top", theme.Top)
	paint("Trim", theme.Trim)
	paint("Tower", theme.Tower)
	paint("Cap", theme.Cap)
	paint("Flag", theme.Trim)
	paint("Gate", theme.Gate)
	paint("Rug", theme.Rug)
	if theme.Band then
		paint("Sign", (theme.Band :: any)[1]:Lerp(Color3.new(0, 0, 0), 0.35)) -- placa com o nome: um tom mais escuro
	end

	local builders = PROP_BUILDERS[theme.Props or ""]
	if builders then
		local floor2 = plot.Model:GetAttribute("Floor2") == true
		for i, spot in WALL_PROPS do
			local m = Instance.new("Model")
			m.Name = "Wall" .. i
			local y = if floor2 and spot[2] <= FLOOR2_FRONT then FLOOR2_WALL_TOP else WALL_TOP
			builders.Wall(m, localCFrame(plot, spot[1], y, spot[2]))
			m.Parent = props
		end
		for i, spot in TOWER_PROPS do
			local m = Instance.new("Model")
			m.Name = "Tower" .. i
			builders.Tower(m, localCFrame(plot, spot[1], TOWER_TOP, spot[2]))
			m.Parent = props
		end
	end
end

---------------------------------------------------------------------
-- Decoração
---------------------------------------------------------------------
local function buildDecor(plot, spot: number, decorId: string?)
	local folder = plot.Model:FindFirstChild("Decor")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Decor"
		folder.Parent = plot.Model
	end
	local old = folder:FindFirstChild("Spot" .. spot)
	if old then
		old:Destroy()
	end
	local builder = decorId and DECOR_BUILDERS[decorId]
	local position = DECOR_SPOTS[spot]
	if not builder or not position then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Spot" .. spot
	model:SetAttribute("DecorId", decorId)
	builder(model, localCFrame(plot, position[1], FLOOR_TOP, position[2]))
	model.Parent = folder
end

-- Volta a base ao normal (jogador saiu)
function Customize.ResetPlot(plot)
	Customize.ApplyTheme(plot, "classic")
	clearFolder(plot, "Decor")
	plot.Model:SetAttribute("Theme", nil)
end

---------------------------------------------------------------------
-- Trilha e título
---------------------------------------------------------------------
local function applyTrail(player: Player)
	local data = getData(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return
	end
	for _, name in { "StyleTrail", "TrailTop", "TrailBottom" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local trail = Cosmetics.ById.trail[data.Style.Trail]
	if not trail then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.9, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1.3, 0)
	bottom.Parent = root
	local keypoints = {}
	for i, color in trail.Colors do
		table.insert(keypoints, ColorSequenceKeypoint.new(if #trail.Colors == 1 then 0 else (i - 1) / (#trail.Colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, trail.Colors[1]))
	end
	local effect = Instance.new("Trail")
	effect.Name = "StyleTrail"
	effect.Attachment0 = top
	effect.Attachment1 = bottom
	effect.Color = ColorSequence.new(keypoints)
	effect.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	effect.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
	effect.Lifetime = 0.55
	effect.MinLength = 0.1
	effect.LightEmission = 0.5
	effect.FaceCamera = true
	effect.Parent = root
end

-- Plaquinha em cima da cabeça: título escolhido (VIP sem título escolhido mostra "VIP")
function Customize.RefreshTag(player: Player)
	local data = getData(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not data or not head then
		return
	end
	for _, name in { "NameTag", "VipTag" } do
		local old = head:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local titleId = data.Style.Title
	if titleId == "" and Registry.Economy.HasPass(player, "VIP") then
		titleId = "vip"
	end
	local title = Cosmetics.ById.title[titleId]
	local prestige = tonumber(data.Prestige) or 0
	local clanName = player:GetAttribute("ClanName") -- já filtrado pelo Roblox (Social)
	if typeof(clanName) == "string" then
		local clanGui = Instance.new("BillboardGui")
		clanGui.Name = "VipTag"
		clanGui.Size = UDim2.fromOffset(180, 22)
		clanGui.StudsOffset = Vector3.new(0, if title or prestige > 0 then 4.2 else 2.6, 0)
		clanGui.LightInfluence = 0
		clanGui.MaxDistance = 60
		local clanLabel = Instance.new("TextLabel")
		clanLabel.Size = UDim2.fromScale(1, 1)
		clanLabel.BackgroundTransparency = 1
		clanLabel.Font = Enum.Font.FredokaOne
		clanLabel.TextScaled = true
		clanLabel.Text = "[" .. clanName .. "]"
		clanLabel.TextColor3 = Color3.fromRGB(140, 230, 255)
		local clanStroke = Instance.new("UIStroke")
		clanStroke.Thickness = 2
		clanStroke.Color = Color3.fromRGB(25, 20, 35)
		clanStroke.Parent = clanLabel
		clanLabel.Parent = clanGui
		clanGui.Parent = head
	end
	if not title and prestige <= 0 then
		return
	end
	local stars = if prestige > 0 then ("\u{2B50}%d "):format(prestige) else "" -- estrela do prestígio
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(200, 30)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = stars .. (if title then title.Name else "PRESTIGE")
	label.TextColor3 = if title then title.Color else Color3.fromRGB(255, 215, 80)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(25, 20, 35)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = head
end

---------------------------------------------------------------------
-- Conquistas e situação de cada item
---------------------------------------------------------------------
local function stats(player: Player)
	local data = getData(player)
	local worldSet = {}
	local worlds = 0
	for _, world in Config.Worlds do
		if Registry.Worlds.IsUnlocked(player, world.Id) then
			worldSet[world.Id] = true
			worlds += 1
		end
	end
	local secret = 0
	for _, def in Critters.List do
		if def.Rarity == "Secret" and data.Index[def.Id] then
			secret = 1
			break
		end
	end
	return {
		Rebirths = math.max(data.Rebirths, tonumber(data.PeakRebirths) or 0), -- o prestígio não tira nada
		Steals = data.Steals,
		Hatched = data.Hatched,
		Defends = data.Defends,
		Index = data.Collected,
		Secret = secret,
		Worlds = worlds,
		VIP = if Registry.Economy.HasPass(player, "VIP") then 1 else 0,
		Premium = if isPremium(player) then 1 else 0,
		WorldSet = worldSet,
		Owned = data.Style.Owned,
	}
end

local KINDS = {
	theme = Cosmetics.Themes,
	decor = Cosmetics.Decor,
	trail = Cosmetics.Trails,
	title = Cosmetics.Titles,
}

function Customize.Status(player: Player, kind: string, id: string): string
	local item = Cosmetics.ById[kind] and Cosmetics.ById[kind][id]
	if not item or not getData(player) then
		return "locked"
	end
	return (Cosmetics.Status(kind, item, stats(player)))
end

-- Manda tudo para a tela "Style"
function Customize.Sync(player: Player)
	local data = getData(player)
	if not data or not player.Parent then
		return
	end
	local s = stats(player)
	local status = {}
	for kind, list in KINDS do
		status[kind] = {}
		for _, item in list do
			local state, text = Cosmetics.Status(kind, item, s)
			status[kind][item.Id] = { state, text }
		end
	end
	local decor = {}
	for spot = 1, Cosmetics.DecorSpots do
		decor[spot] = data.Style.Decor[tostring(spot)] or ""
	end
	Registry.Remotes.StyleEvent:FireClient(player, {
		Theme = data.Style.Theme,
		Decor = decor,
		Trail = data.Style.Trail,
		Title = data.Style.Title,
		Status = status,
	})
end

-- Tira o que o jogador não tem mais (ex.: o Premium acabou)
local function validate(player: Player)
	local data = getData(player)
	local style = data.Style
	local s = stats(player)
	local function ok(kind: string, id: string): boolean
		local item = Cosmetics.ById[kind][id]
		return item ~= nil and (Cosmetics.Status(kind, item, s)) == "owned"
	end
	if not ok("theme", style.Theme) then
		style.Theme = "classic"
	end
	if style.Trail ~= "" and not ok("trail", style.Trail) then
		style.Trail = ""
	end
	if style.Title ~= "" and not ok("title", style.Title) then
		style.Title = ""
	end
	for spot, id in style.Decor do
		if not ok("decor", id) then
			style.Decor[spot] = nil
		end
	end
end

function Customize.SetupPlayer(player: Player)
	local data = getData(player)
	local plot = Registry.Plots.Get(player)
	if not data then
		return
	end
	local style = if type(data.Style) == "table" then data.Style else {}
	style.Theme = if type(style.Theme) == "string" then style.Theme else "classic"
	style.Trail = if type(style.Trail) == "string" then style.Trail else ""
	style.Title = if type(style.Title) == "string" then style.Title else ""
	style.Owned = if type(style.Owned) == "table" then style.Owned else {}
	local decor = {}
	if type(style.Decor) == "table" then
		for spot, id in style.Decor do
			local n = tonumber(spot)
			if n and n >= 1 and n <= Cosmetics.DecorSpots and type(id) == "string" then
				decor[tostring(n)] = id
			end
		end
	end
	style.Decor = decor
	data.Style = style
	validate(player)
	if plot then
		Customize.ApplyTheme(plot, style.Theme)
		clearFolder(plot, "Decor")
		for spot, id in style.Decor do
			buildDecor(plot, tonumber(spot) :: number, id)
		end
	end
	player:SetAttribute("Premium", isPremium(player))
	Customize.LoadSettings(player)
end

---------------------------------------------------------------------
-- Configurações da tela (Parte 17): ficam salvas e valem em qualquer aparelho
---------------------------------------------------------------------
local SETTING_DEFAULTS = { LowGfx = false, OtherPets = true, MoneyPops = true, Sfx = 1, Shake = true, Music = true } -- v26: música

local function publishSettings(player: Player)
	local data = getData(player)
	if data then
		player:SetAttribute("Settings", HttpService:JSONEncode(data.Settings))
	end
end

function Customize.SaveSettings(player: Player, incoming: any)
	local data = getData(player)
	if not data or type(incoming) ~= "table" then
		return
	end
	local clean = {}
	for key, default in SETTING_DEFAULTS do
		local value = incoming[key]
		if type(default) == "boolean" then
			clean[key] = if type(value) == "boolean" then value else default
		else
			local number = tonumber(value)
			clean[key] = if number == 0 or number == 0.5 or number == 1 then number else default
		end
	end
	data.Settings = clean
	publishSettings(player)
end

function Customize.LoadSettings(player: Player)
	local data = getData(player)
	local saved = if type(data.Settings) == "table" then data.Settings else {}
	Customize.SaveSettings(player, saved)
end

function Customize.OnCharacter(player: Player)
	applyTrail(player)
	Customize.RefreshTag(player)
end

---------------------------------------------------------------------
-- Ações da tela "Style"
---------------------------------------------------------------------
function Customize.Handle(player: Player, action: string, argument: any)
	local data = getData(player)
	local Remotes = Registry.Remotes
	if not data then
		return
	end
	local style = data.Style
	if action == "StyleSync" then
		Customize.Sync(player)
		return
	elseif action == "SetTheme" and typeof(argument) == "string" then
		if Customize.Status(player, "theme", argument) ~= "owned" then
			Remotes.Notify(player, "This theme is locked. Unlock its world first!", "warning")
			return
		end
		style.Theme = argument
		local plot = Registry.Plots.Get(player)
		if plot then
			Customize.ApplyTheme(plot, argument)
		end
		Remotes.Notify(player, Cosmetics.ById.theme[argument].Name .. " theme applied to your base!", "success")
		Remotes.Effect(player, "Purchase", "Rare")
	elseif action == "BuyStyle" and type(argument) == "table" then
		local kind, id = argument.Kind, argument.Id
		if (kind ~= "decor" and kind ~= "trail") or type(id) ~= "string" then
			return
		end
		local item = Cosmetics.ById[kind][id]
		if not item or Customize.Status(player, kind, id) ~= "buy" then
			return
		end
		if not Registry.Economy.TrySpend(player, item.Price, "Style") then
			Remotes.Notify(player, "Not enough cash! You need " .. Format.Money(item.Price), "error")
			return
		end
		style.Owned[kind .. ":" .. id] = true
		if kind == "trail" then
			style.Trail = id
			applyTrail(player)
			Remotes.Notify(player, item.Name .. " trail bought and equipped!", "success")
		else
			Remotes.Notify(player, item.Name .. " bought! Pick a spot in your base for it.", "success")
		end
		Remotes.Effect(player, "Purchase", "Rare")
	elseif action == "PlaceDecor" and type(argument) == "table" then
		local spot = tonumber(argument.Spot)
		local id = argument.Id
		if not spot or spot % 1 ~= 0 or spot < 1 or spot > Cosmetics.DecorSpots or type(id) ~= "string" then
			return
		end
		if id ~= "" and Customize.Status(player, "decor", id) ~= "owned" then
			return
		end
		style.Decor[tostring(spot)] = if id == "" then nil else id
		local plot = Registry.Plots.Get(player)
		if plot then
			buildDecor(plot, spot, if id == "" then nil else id)
		end
	elseif action == "SetTrail" and typeof(argument) == "string" then
		if argument ~= "" and Customize.Status(player, "trail", argument) ~= "owned" then
			return
		end
		style.Trail = argument
		applyTrail(player)
	elseif action == "SetTitle" and typeof(argument) == "string" then
		if argument ~= "" and Customize.Status(player, "title", argument) ~= "owned" then
			return
		end
		style.Title = argument
		Customize.RefreshTag(player)
	else
		return
	end
	Customize.Sync(player)
end

-- (para os testes automáticos)
Customize.DecorBuilders = DECOR_BUILDERS
Customize.PropBuilders = PROP_BUILDERS
Customize.DecorSpots = DECOR_SPOTS

-- O 2º andar apareceu/sumiu: refaz os enfeites do tema no lugar certo
function Customize.RefreshProps(plot)
	Customize.ApplyTheme(plot, plot.Model:GetAttribute("Theme") or "classic")
end

-- Guarda as cores originais da base (para o tema "Classic" e para quando o dono sai)
function Customize.CaptureDefaults(plot)
	local saved = {}
	for _, list in themeParts(plot) do
		for _, part in list do
			saved[part] = { Color = part.Color, Material = part.Material }
		end
	end
	defaults[plot] = saved
end

function Customize.Init()
	for _, plot in Registry.Plots.All() do
		Customize.CaptureDefaults(plot)
	end
	-- Premium pode começar/acabar com o jogador dentro do jogo
	Players.PlayerMembershipChanged:Connect(function(player)
		if not getData(player) or not player:GetAttribute("Loaded") then
			return
		end
		player:SetAttribute("Premium", isPremium(player))
		validate(player)
		Registry.Economy.Sync(player)
		Customize.OnCharacter(player)
		Customize.Sync(player)
		if isPremium(player) and Config.PremiumBonus > 0 then
			Registry.Remotes.Notify(player, ("Thanks for being Premium! +%d%% cash."):format(math.floor(Config.PremiumBonus * 100)), "rare")
		end
	end)
end

return Customize
