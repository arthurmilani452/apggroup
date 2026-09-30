--[[
	Monta cada bichinho usando peças simples (bolas, blocos), sem precisar de modelos 3D.
	Os Lendários e Míticos têm montagens especiais (campo "Special" na lista de Critters):
	  phoenix, frostmammoth, lavabeast, stormram, voiddragon, celestial, kraken

	Build(def) devolve: model, root, groundOffset, topOffset
	  root         = peça invisível no centro do corpo (é ela que a gente move)
	  groundOffset = distância do centro até o chão (pés/tentáculos)
	  topOffset    = distância do centro até o ponto mais alto (asas, chifres...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Models3D = require(ReplicatedStorage.Shared.Models3D)

local Builder = {}

local rgb = Color3.fromRGB
local V = Vector3.new

local WHITE = rgb(255, 255, 255)
local DARK = rgb(25, 25, 35)
local BLUSH = rgb(255, 140, 170)
local GOLD = rgb(255, 200, 50)
local RAINBOW = {
	rgb(255, 80, 80),
	rgb(255, 170, 60),
	rgb(255, 240, 80),
	rgb(90, 220, 110),
	rgb(80, 170, 255),
	rgb(180, 110, 255),
}

local BODY_SHAPES = {
	blob = { wx = 1, wy = 1, wz = 1 },
	bunny = { wx = 1, wy = 1, wz = 1 },
	cat = { wx = 1, wy = 0.95, wz = 1 },
	bird = { wx = 0.95, wy = 1.05, wz = 0.95 },
	toad = { wx = 1.2, wy = 0.72, wz = 1.05 },
	dino = { wx = 1, wy = 0.95, wz = 1.1 },
	dragon = { wx = 1, wy = 0.95, wz = 1.1 },
	unicorn = { wx = 1, wy = 1, wz = 1.05 },
}

-- Padrões de cada montagem especial
local SPECIAL_DEFAULTS = {
	phoenix = { Shape = { wx = 0.95, wy = 1.05, wz = 0.95 }, Face = "fierce", NoMouth = true },
	frostmammoth = { Shape = { wx = 1.15, wy = 0.95, wz = 1.15 }, Face = "fierce", NoMouth = true, Legs = true },
	lavabeast = { Face = "fierce" },
	stormram = { Face = "fierce" },
	voiddragon = { Shape = { wx = 1, wy = 0.95, wz = 1.1 }, Face = "fierce", NoMouth = true, EyeY = 0.16 },
	celestial = {},
	kraken = { Shape = { wx = 1, wy = 1.18, wz = 1 }, Face = "fierce", Float = true },
	sun = { Face = "fierce", Float = true },
}

local Specials = {}

local function getMaterial(name: string?): Enum.Material
	if name then
		local ok, material = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		if ok and material then
			return material
		end
	end
	return Enum.Material.SmoothPlastic
end

---------------------------------------------------------------------
-- MONTAGENS ESPECIAIS (Lendários e Míticos)
---------------------------------------------------------------------

-- Fênix de fogo
function Specials.phoenix(c)
	local s, rx, ry, rz = c.s, c.rx, c.ry, c.rz
	local flame = c.def.Palette or { rgb(255, 240, 120), rgb(255, 190, 50), rgb(255, 130, 30), rgb(255, 70, 40) }
	local neon = { material = Enum.Material.Neon }

	local by = c.eyeY - 0.13 * s
	c.add("Beak", V(0.16 * s, 0.17 * s, 0.17 * s), CFrame.new(0, by, c.surfaceZ(0, by) - 0.03 * s) * CFrame.Angles(math.rad(45), 0, 0), rgb(255, 160, 40))

	for _, side in { -1, 1 } do
		local root = V(side * rx * 0.8, 0.05 * s, 0.12 * s)
		for i = 1, 4 do
			local a = math.rad(-8 + i * 22)
			local length = (1.2 - i * 0.13) * s
			local dir = V(side * math.cos(a), math.sin(a), 0.35).Unit
			c.blade("Feather", root, root + dir * length, 0.2 * s, 0.05 * s, flame[i], neon)
		end
	end
	for j = -2, 2 do
		local base = V(0, -0.12 * s, rz * 0.8)
		local dir = V(j * 0.35, 0.3 - math.abs(j) * 0.12, 1).Unit
		c.seg("Plume", base, base + dir * 0.95 * s, 0.15 * s, flame[math.abs(j) + 2], neon)
	end
	for k = 1, 3 do
		local base = V((k - 2) * 0.07 * s, ry * 0.85, -0.02 * s)
		c.seg("Crest", base, base + V((k - 2) * 0.1 * s, 0.42 * s, 0.28 * s), 0.1 * s, flame[k], neon)
	end
	if not c.def.Palette then
		c.fire(c.body, rgb(255, 120, 20), rgb(255, 230, 90), s * 0.9)
	end
end

-- Mamute de gelo
function Specials.frostmammoth(c)
	local s, rx, ry = c.s, c.rx, c.ry
	local bodyColor = c.def.Color
	local ice = rgb(130, 230, 255)
	local ivory = rgb(250, 248, 235)
	local bodyOptions = { ellipsoid = true, material = c.bodyMaterial }

	for _, lx in { -1, 1 } do
		for _, lz in { -1, 1 } do
			c.add("Leg", V(0.3 * s, 0.5 * s, 0.3 * s), CFrame.new(lx * 0.3 * s, -ry * 0.8, lz * 0.28 * s), bodyColor, bodyOptions)
		end
	end

	local p0 = V(0, c.eyeY - 0.17 * s, c.surfaceZ(0, c.eyeY - 0.17 * s) + 0.04 * s)
	local p1 = p0 + V(0, -0.16 * s, -0.1 * s)
	local p2 = p1 + V(0, -0.16 * s, -0.03 * s)
	local p3 = p2 + V(0, -0.1 * s, 0.07 * s)
	c.chain("Trunk", { p0, p1, p2, p3 }, 0.22 * s, 0.11 * s, bodyColor, { material = c.bodyMaterial })

	for _, side in { -1, 1 } do
		local ty = c.eyeY - 0.27 * s
		local t0 = V(side * 0.17 * s, ty, c.surfaceZ(side * 0.17 * s, ty) + 0.03 * s)
		local t1 = t0 + V(side * 0.07 * s, -0.12 * s, -0.17 * s)
		local t2 = t1 + V(side * 0.05 * s, 0, -0.16 * s)
		local t3 = t2 + V(side * 0.02 * s, 0.14 * s, -0.08 * s)
		c.chain("Tusk", { t0, t1, t2, t3 }, 0.1 * s, 0.05 * s, ivory)
		c.add("Ear", V(0.07 * s, 0.52 * s, 0.44 * s), CFrame.new(side * (rx - 0.03 * s), 0.08 * s, 0.02 * s) * CFrame.Angles(0, math.rad(-20 * side), math.rad(-8 * side)), bodyColor, bodyOptions)
	end

	local crystals = {
		{ -0.22, 0.02, 0.5, -20 },
		{ 0.22, 0.05, 0.45, 20 },
		{ 0, 0.22, 0.62, 0 },
		{ -0.16, 0.4, 0.42, -15 },
		{ 0.16, 0.4, 0.42, 15 },
		{ 0, -0.12, 0.38, 0 },
	}
	for _, spec in crystals do
		local x, z = spec[1] * s, spec[2] * s
		local base = V(x, c.surfaceY(x, z) - 0.05 * s, z)
		local tilt = math.rad(spec[4])
		local dir = V(math.sin(tilt), math.cos(tilt), 0.2).Unit
		local top = base + dir * spec[3] * s
		c.seg("Crystal", base, top, 0.16 * s, ice, { block = true, material = Enum.Material.Neon, transparency = 0.05 })
		c.seg("Crystal", top, top + dir * 0.12 * s, 0.08 * s, WHITE, { block = true, material = Enum.Material.Neon })
	end

	c.particles("Snow", {
		Color = ColorSequence.new(WHITE, ice),
		Rate = 8,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = V(0, -3, 0),
		Size = NumberSequence.new(0.3, 0),
	})
end

-- Monstro de lava
function Specials.lavabeast(c)
	local s, rx, ry = c.s, c.rx, c.ry
	local hornColor = rgb(45, 35, 35)
	local hot = rgb(255, 130, 30)
	for _, side in { -1, 1 } do
		local base = V(side * 0.22 * s, ry * 0.78, -0.02 * s)
		local p1 = base + V(side * 0.18 * s, 0.14 * s, 0.05 * s)
		local p2 = p1 + V(side * 0.13 * s, 0.2 * s, 0.07 * s)
		local p3 = p2 + V(-side * 0.03 * s, 0.2 * s, 0.02 * s)
		local parts = c.chain("Horn", { base, p1, p2, p3 }, 0.17 * s, 0.06 * s, function(i, n)
			return if i == n then hot else hornColor
		end, function(i, n)
			return { material = if i == n then Enum.Material.Neon else Enum.Material.Slate }
		end)
		c.fire(parts[#parts], rgb(255, 100, 20), rgb(255, 220, 80), s * 0.35)

		local shoulder = V(side * rx * 0.85, -0.05 * s, -0.02 * s)
		local fist = V(side * (rx + 0.18 * s), -0.22 * s, -0.16 * s)
		c.seg("Arm", shoulder, fist, 0.2 * s, c.def.Color, { material = c.bodyMaterial })
		c.add("Fist", V(0.36 * s, 0.36 * s, 0.36 * s), CFrame.new(fist), c.def.Color, { ball = true, material = c.bodyMaterial })
		for k = -1, 1 do
			c.add("Knuckle", V(0.08 * s, 0.08 * s, 0.06 * s), CFrame.new(fist + V(k * 0.09 * s, 0.06 * s, -0.17 * s)) * CFrame.Angles(0, 0, math.rad(45)), hot, {
				material = Enum.Material.Neon,
			})
		end
	end
	c.fire(c.body, rgb(255, 90, 20), rgb(255, 200, 60), s * 0.7)
end

-- Carneiro do trovão
function Specials.stormram(c)
	local s, ry = c.s, c.ry
	local hornColor = rgb(235, 225, 195)
	local ridge = rgb(205, 190, 150)
	local bolt = c.accent
	for _, side in { -1, 1 } do
		local center = V(side * 0.43 * s, 0.16 * s, 0.06 * s)
		local points = { V(side * 0.24 * s, ry * 0.82, -0.02 * s) }
		for k = 0, 6 do
			local r = (0.27 - k * 0.028) * s
			local phi = k * 0.92
			table.insert(points, center + V(side * 0.025 * s * k, r * math.cos(phi), r * math.sin(phi)))
		end
		c.chain("Horn", points, 0.19 * s, 0.06 * s, function(i)
			return if i % 2 == 0 then ridge else hornColor
		end)

		local top = V(side * 0.42 * s, ry + 0.62 * s, 0.12 * s)
		local b1 = top + V(-side * 0.1 * s, -0.16 * s, 0)
		local b2 = b1 + V(side * 0.12 * s, -0.02 * s, 0)
		local b3 = b2 + V(-side * 0.1 * s, -0.2 * s, 0)
		c.chain("Bolt", { top, b1, b2, b3 }, 0.08 * s, 0.06 * s, bolt, { block = true, material = Enum.Material.Neon })
	end
	for _, spec in { { 0, 0.03, 0.26 }, { -0.14, 0, 0.2 }, { 0.14, 0, 0.2 }, { 0, 0.06, 0.18, 0.12 } } do
		local d = spec[3] * s
		c.add("Cloud", V(d, d, d), CFrame.new(spec[1] * s, ry + spec[2] * s, (spec[4] or 0.04) * s), rgb(240, 245, 255), { ball = true })
	end
end

-- Dragão do vazio
function Specials.voiddragon(c)
	local s, rx, ry, rz = c.s, c.rx, c.ry, c.rz
	local neon = c.accent
	local dark = c.def.Color
	local horn = rgb(55, 45, 70)
	local membrane = neon:Lerp(rgb(0, 0, 0), 0.55)
	local neonOptions = { material = Enum.Material.Neon }

	local sy = -0.1 * s
	local sz = c.surfaceZ(0, sy)
	c.add("Snout", V(0.44 * s, 0.3 * s, 0.42 * s), CFrame.new(0, sy, sz + 0.02 * s), dark, { ellipsoid = true, material = c.bodyMaterial })
	for _, side in { -1, 1 } do
		local nd = 0.05 * s
		c.add("Nostril", V(nd, nd, nd), CFrame.new(side * 0.07 * s, sy + 0.05 * s, sz - 0.18 * s), neon, { ball = true, material = Enum.Material.Neon })
		c.add("Fang", V(0.06 * s, 0.06 * s, 0.04 * s), CFrame.new(side * 0.1 * s, sy - 0.13 * s, sz - 0.1 * s) * CFrame.Angles(0, 0, math.rad(45)), WHITE)

		local base = V(side * 0.2 * s, ry * 0.82, 0.02 * s)
		local p1 = base + V(side * 0.1 * s, 0.2 * s, 0.16 * s)
		local p2 = p1 + V(side * 0.06 * s, 0.1 * s, 0.26 * s)
		local p3 = p2 + V(0, 0.02 * s, 0.2 * s)
		c.chain("Horn", { base, p1, p2, p3 }, 0.14 * s, 0.04 * s, function(i, n)
			return if i == n then neon else horn
		end, function(i, n)
			return { material = if i == n then Enum.Material.Neon else Enum.Material.SmoothPlastic }
		end)
		c.seg("Horn", V(side * 0.36 * s, 0.22 * s, 0.02 * s), V(side * 0.5 * s, 0.34 * s, 0.12 * s), 0.08 * s, horn)

		local shoulder = V(side * rx * 0.65, 0.22 * s, 0.18 * s)
		local elbow = shoulder + V(side * 0.55 * s, 0.5 * s, 0.28 * s)
		local tips = {
			elbow + V(side * 0.6 * s, 0.18 * s, 0.3 * s),
			elbow + V(side * 0.5 * s, -0.28 * s, 0.4 * s),
			elbow + V(side * 0.15 * s, -0.6 * s, 0.4 * s),
		}
		c.seg("WingBone", shoulder, elbow, 0.09 * s, neon, neonOptions)
		for _, tip in tips do
			c.seg("WingBone", elbow, tip, 0.06 * s, neon, neonOptions)
		end
		c.panel("Membrane", elbow, tips[1], tips[2], 0.03 * s, membrane, { transparency = 0.15 })
		c.panel("Membrane", elbow, tips[2], tips[3], 0.03 * s, membrane, { transparency = 0.15 })
		c.panel("Membrane", elbow, tips[3], shoulder + V(0, -0.1 * s, 0.05 * s), 0.03 * s, membrane, { transparency = 0.15 })
	end

	for _, zf in { -0.2, 0.05, 0.3, 0.48 } do
		local z = zf * s
		c.add("Spike", V(0.05 * s, 0.22 * s, 0.22 * s), CFrame.new(0, c.surfaceY(0, z) - 0.02 * s, z) * CFrame.Angles(math.rad(45), 0, 0), neon, neonOptions)
	end

	local tail = {
		V(0, -0.15 * s, rz * 0.85),
		V(0, -0.25 * s, rz + 0.3 * s),
		V(0.1 * s, -0.28 * s, rz + 0.65 * s),
		V(0.25 * s, -0.18 * s, rz + 0.95 * s),
		V(0.3 * s, -0.05 * s, rz + 1.15 * s),
	}
	c.chain("Tail", tail, 0.3 * s, 0.1 * s, dark, { material = c.bodyMaterial })
	c.add("TailBlade", V(0.05 * s, 0.3 * s, 0.3 * s), CFrame.new(tail[#tail]) * CFrame.Angles(math.rad(45), 0, 0), neon, neonOptions)
	c.aura(neon, 1.9)
end

-- Unicórnio celestial com asas
function Specials.celestial(c)
	local s, rx, ry, rz = c.s, c.rx, c.ry, c.rz

	local base = V(0, ry * 0.9, -rz * 0.38)
	local dir = V(0, 0.9, -0.42).Unit
	for k = 0, 3 do
		local a = base + dir * (k * 0.13 * s)
		c.seg("Horn", a, a + dir * 0.15 * s, (0.12 - k * 0.022) * s, if k % 2 == 0 then GOLD else WHITE, {
			material = if k == 3 then Enum.Material.Neon else Enum.Material.Foil,
		})
	end
	c.seg("HornTip", base + dir * 0.52 * s, base + dir * 0.66 * s, 0.035 * s, GOLD, { material = Enum.Material.Neon })

	for i, color in RAINBOW do
		local z = (-0.12 + (i - 1) * 0.11) * s
		local d = 0.2 * s
		c.add("Mane", V(d, d, d), CFrame.new(0, c.surfaceY(0, z) + 0.02 * s, z), color, { ball = true, material = Enum.Material.Neon })
	end

	local tail = {}
	for i = 0, 6 do
		table.insert(tail, V(0, -0.1 * s + (i ^ 1.5) * 0.03 * s, rz * 0.9 + i * 0.13 * s))
	end
	for i = 1, 6 do
		c.seg("Tail", tail[i], tail[i + 1], (0.2 - i * 0.015) * s, RAINBOW[i], { material = Enum.Material.Neon })
	end

	local feathers = { WHITE, rgb(235, 240, 255), rgb(225, 215, 255), rgb(255, 225, 245) }
	for _, side in { -1, 1 } do
		local root = V(side * rx * 0.8, 0.12 * s, 0.1 * s)
		for i = 1, 4 do
			local a = math.rad(-5 + i * 21)
			local length = (1.05 - i * 0.12) * s
			local featherDir = V(side * math.cos(a), math.sin(a), 0.3).Unit
			c.blade("Feather", root, root + featherDir * length, 0.2 * s, 0.05 * s, feathers[i])
		end
	end

	local center = V(0, ry + 0.45 * s, 0.16 * s)
	for k = 0, 11 do
		local angle = k / 12 * math.pi * 2
		local d = 0.07 * s
		c.add("Halo", V(d, d, d), CFrame.new(center + V(math.cos(angle) * 0.26 * s, 0, math.sin(angle) * 0.26 * s)), GOLD, {
			ball = true,
			material = Enum.Material.Neon,
		})
	end
	c.aura(rgb(255, 230, 255), 1.8)
end

-- Kraken cósmico
function Specials.kraken(c)
	local s, rx, ry, rz = c.s, c.rx, c.ry, c.rz
	local bodyColor = c.def.Color
	local tipColor = c.accent
	for k = 0, 7 do
		local angle = (k + 0.5) * math.pi / 4
		local ox, oz = math.sin(angle), math.cos(angle)
		local base = V(ox * 0.3 * s, -ry * 0.72, oz * 0.3 * s)
		local p1 = base + V(ox * 0.18 * s, -0.26 * s, oz * 0.18 * s)
		local p2 = p1 + V(ox * 0.26 * s, -0.12 * s, oz * 0.26 * s)
		local p3 = p2 + V(ox * 0.2 * s, 0.1 * s, oz * 0.2 * s)
		local p4 = p3 + V(ox * 0.04 * s, 0.18 * s, oz * 0.04 * s)
		c.chain("Tentacle", { base, p1, p2, p3, p4 }, 0.22 * s, 0.08 * s, function(i, n)
			return if i >= n - 1 then tipColor else bodyColor
		end, function(i, n)
			return { material = if i >= n - 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic }
		end)
	end
	for k = 1, 14 do
		local phi = k * 2.39996
		local yn = 0.15 + 0.8 * (k / 14)
		local r = math.sqrt(1 - yn * yn)
		local x, y, z = math.cos(phi) * r * rx * 0.99, yn * ry * 0.99, math.sin(phi) * r * rz * 0.99
		if not (z < 0 and y < ry * 0.6) then
			local d = 0.05 * s
			c.add("Star", V(d, d, d), CFrame.new(x, y, z), WHITE, { ball = true, material = Enum.Material.Neon })
		end
	end
	for k = 0, 4 do
		local angle = k / 5 * math.pi * 2
		local position = V(math.sin(angle) * 0.3 * s, ry + 0.28 * s, math.cos(angle) * 0.3 * s)
		c.add("CrownStar", V(0.12 * s, 0.12 * s, 0.04 * s), CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.rad(45)), GOLD, {
			material = Enum.Material.Neon,
		})
	end
	c.aura(tipColor, 1.9)
end

-- Sol com raios
function Specials.sun(c)
	local s, ry = c.s, c.ry
	local rayColor = c.accent
	for k = 0, 11 do
		local angle = k / 12 * math.pi * 2
		local dir = V(math.cos(angle), math.sin(angle), 0)
		local inner = dir * (0.5 * s) + V(0, 0, 0.12 * s)
		local length = if k % 2 == 0 then 0.42 else 0.28
		c.seg("Ray", inner, inner + dir * length * s, 0.12 * s, rayColor, { block = true, material = Enum.Material.Neon })
	end
	c.fire(c.body, rgb(255, 150, 30), rgb(255, 240, 120), s * 0.6)
	c.aura(rgb(255, 200, 80), 2)
	local _ = ry
end

---------------------------------------------------------------------
-- MONTAGEM PRINCIPAL
---------------------------------------------------------------------
function Builder.Build(def: any)
	local special = def.Special and SPECIAL_DEFAULTS[def.Special] or {}
	local function opt(key: string)
		if def[key] ~= nil then
			return def[key]
		end
		return special[key]
	end

	local rarity = Config.RarityByName[def.Rarity] or Config.Rarities[1]
	local s: number = def.Size or rarity.Size
	local shape = opt("Shape") or BODY_SHAPES[def.Body] or BODY_SHAPES.blob

	local rx = 0.5 * s * shape.wx
	local ry = 0.46 * s * shape.wy
	local rz = 0.5 * s * shape.wz

	local model = Instance.new("Model")
	model.Name = def.Name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(s * 0.7, s * 0.7, s * 0.7)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local bodyMaterial = getMaterial(def.Material)
	local accent: Color3 = def.Accent or def.Color

	local function add(name: string, size: Vector3, cframe: CFrame, color: Color3, options: any?): BasePart
		options = options or {}
		local part = Instance.new("Part")
		part.Name = name
		if options.ball then
			part.Shape = Enum.PartType.Ball
			local d = math.min(size.X, size.Y, size.Z)
			part.Size = V(d, d, d)
		elseif options.cylinder then
			part.Shape = Enum.PartType.Cylinder
			part.Size = size
		else
			part.Size = size
		end
		if options.ellipsoid then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		part.CFrame = cframe
		part.Color = color
		part.Material = options.material or Enum.Material.SmoothPlastic
		part.Transparency = options.transparency or 0
		part.Reflectance = options.reflectance or 0
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = options.material ~= Enum.Material.ForceField
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if color == def.Color and options.material ~= Enum.Material.ForceField then
			part:SetAttribute("Skin", true) -- usado pelas mutações (Gold, Diamond, Rainbow)
		end
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	local c: any = {
		s = s,
		rx = rx,
		ry = ry,
		rz = rz,
		def = def,
		accent = accent,
		bodyMaterial = bodyMaterial,
		add = add,
	}

	function c.surfaceZ(x: number, y: number): number
		local t = 1 - (x / rx) ^ 2 - (y / ry) ^ 2
		return -rz * math.sqrt(math.max(t, 0))
	end

	function c.surfaceY(x: number, z: number): number
		local t = 1 - (x / rx) ^ 2 - (z / rz) ^ 2
		return ry * math.sqrt(math.max(t, 0))
	end

	-- Peça esticada entre dois pontos (osso, chifre, tentáculo...)
	function c.seg(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, options: any?): BasePart
		local delta = b - a
		local length = delta.Magnitude
		local direction = if length > 1e-4 then delta.Unit else Vector3.yAxis
		local mid = (a + b) / 2
		local up = if math.abs(direction.Y) > 0.98 then Vector3.zAxis else Vector3.yAxis
		local cframe = CFrame.lookAt(mid, mid + direction, up)
		local partOptions = if options then table.clone(options) else {}
		if partOptions.block then
			cframe *= CFrame.Angles(0, 0, math.rad(45))
		else
			partOptions.ellipsoid = true
		end
		return add(name, V(thickness, thickness, math.max(length, 1e-3) + thickness * 0.35), cframe, color, partOptions)
	end

	-- Várias peças seguidas afinando (color/options podem ser funções (i, n))
	function c.chain(name: string, points: { Vector3 }, t0: number, t1: number, color: any, options: any?): { BasePart }
		local parts = {}
		local n = #points - 1
		for i = 1, n do
			local t = if n > 1 then (i - 1) / (n - 1) else 0
			local thickness = t0 + (t1 - t0) * t
			local partColor = if type(color) == "function" then color(i, n) else color
			local partOptions = if type(options) == "function" then options(i, n) else options
			table.insert(parts, c.seg(name, points[i], points[i + 1], thickness, partColor, partOptions))
		end
		return parts
	end

	-- Lâmina achatada (pena, asa)
	function c.blade(name: string, a: Vector3, b: Vector3, width: number, thickness: number, color: Color3, options: any?): BasePart
		local delta = b - a
		local direction = delta.Unit
		local hint = Vector3.zAxis
		if math.abs(direction:Dot(hint)) > 0.98 then
			hint = Vector3.yAxis
		end
		local mid = (a + b) / 2
		return add(name, V(width, thickness, delta.Magnitude), CFrame.lookAt(mid, mid + direction, hint), color, options)
	end

	-- Membrana (aproxima um triângulo a -> borda b-d com duas placas)
	function c.panel(name: string, a: Vector3, b: Vector3, d: Vector3, thickness: number, color: Color3, options: any?)
		local m = (b + d) / 2
		local along = m - a
		local length = along.Magnitude
		if length < 1e-3 then
			return
		end
		local unit = along.Unit
		local edge = d - b
		local across = edge - unit * edge:Dot(unit)
		if across.Magnitude < 1e-3 then
			return
		end
		across = across.Unit
		local normal = unit:Cross(across)
		local width = edge.Magnitude
		local near = CFrame.fromMatrix(a + along * 0.28, across, normal)
		local far = CFrame.fromMatrix(a + along * 0.74, across, normal)
		add(name, V(width * 0.38, thickness, length * 0.56), near, color, options)
		add(name, V(width * 0.82, thickness, length * 0.52), far, color, options)
	end

	function c.fire(parent: Instance, color: Color3, secondary: Color3, size: number)
		local fire = Instance.new("Fire")
		fire.Color = color
		fire.SecondaryColor = secondary
		fire.Size = math.clamp(size, 2, 30)
		fire.Heat = 9
		fire.Parent = parent
	end

	function c.aura(color: Color3, scale: number)
		local d = s * scale
		add("Aura", V(d, d, d), CFrame.identity, color, { ball = true, material = Enum.Material.ForceField })
	end

	function c.particles(name: string, props: { [string]: any })
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = name
		emitter.LightEmission = 0.6
		emitter.SpreadAngle = Vector2.new(180, 180)
		for key, value in props do
			(emitter :: any)[key] = value
		end
		emitter.Parent = root
	end

	-- MODELO 3D (Higgsfield → Studio): se existir em ReplicatedStorage.Models3D, usa ele no lugar das peças
	local mesh3D, meshHeight = Models3D.Get(def.Id, { Size = s * 1.25, Fit = "Max", Anchored = false })
	if mesh3D then
		mesh3D:PivotTo(CFrame.new(0, -meshHeight / 2, 0))
		for _, d in mesh3D:GetDescendants() do
			if d:IsA("BasePart") then
				d.Parent = model
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
				d:SetAttribute("Skin", true) -- mutações pintam o modelo 3D inteiro
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
			end
		end
		mesh3D:Destroy()
		model:SetAttribute("Is3D", true)
	else
		-- CORPO
		local isGlass = def.Material == "Glass"
		c.body = add("Body", V(rx * 2, ry * 2, rz * 2), CFrame.identity, def.Color, {
			ellipsoid = true,
			material = bodyMaterial,
			transparency = if isGlass then 0.25 else 0,
			reflectance = if def.Material == "Foil" then 0.25 else 0,
		})

		-- ROSTO
		local eyeX = 0.2 * s * shape.wx
		local eyeY = (opt("EyeY") or (if def.Body == "toad" then 0.2 else 0.1)) * s
		c.eyeY = eyeY
		if opt("Face") == "fierce" then
			local iris: Color3 = def.EyeColor or accent
			for _, side in { -1, 1 } do
				local x = eyeX * side
				local ez = c.surfaceZ(x, eyeY) + 0.035 * s
				local eyeD = 0.24 * s
				add("Eye", V(eyeD, eyeD, eyeD), CFrame.new(x, eyeY, ez), WHITE, { ball = true })
				local irisD = 0.16 * s
				add("Iris", V(irisD, irisD, irisD), CFrame.new(x, eyeY, ez - 0.065 * s), iris, { ball = true, material = Enum.Material.Neon })
				add("Pupil", V(0.035 * s, 0.12 * s, 0.03 * s), CFrame.new(x, eyeY, ez - 0.14 * s), DARK)
				local browY = eyeY + 0.14 * s
				add("Brow", V(0.3 * s, 0.075 * s, 0.1 * s), CFrame.new(x, browY, c.surfaceZ(x, browY) - 0.03 * s) * CFrame.Angles(0, 0, math.rad(22 * side)), def.BrowColor or DARK)
			end
			if not opt("NoMouth") then
				local my = eyeY - 0.21 * s
				add("Mouth", V(0.26 * s, 0.07 * s, 0.06 * s), CFrame.new(0, my, c.surfaceZ(0, my) + 0.005 * s), DARK, { ellipsoid = true })
				for _, side in { -1, 1 } do
					local fy = my - 0.04 * s
					add("Fang", V(0.06 * s, 0.06 * s, 0.04 * s), CFrame.new(side * 0.07 * s, fy, c.surfaceZ(side * 0.07 * s, fy) - 0.005 * s) * CFrame.Angles(0, 0, math.rad(45)), WHITE)
				end
			end
		else
			local eyeD = 0.26 * s
			for _, side in { -1, 1 } do
				local x = eyeX * side
				local ez = c.surfaceZ(x, eyeY) + 0.035 * s
				add("Eye", V(eyeD, eyeD, eyeD), CFrame.new(x, eyeY, ez), WHITE, { ball = true })
				local pupilD = 0.15 * s
				add("Pupil", V(pupilD, pupilD, pupilD), CFrame.new(x, eyeY - 0.01 * s, ez - 0.08 * s), DARK, { ball = true })
				local shineD = 0.05 * s
				add("Shine", V(shineD, shineD, shineD), CFrame.new(x + 0.03 * s, eyeY + 0.03 * s, ez - 0.145 * s), WHITE, {
					ball = true,
					material = Enum.Material.Neon,
				})
				if def.Body ~= "bird" then
					local bx = (eyeX + 0.14 * s) * side
					local by = eyeY - 0.13 * s
					add("Blush", V(0.13 * s, 0.07 * s, 0.06 * s), CFrame.new(bx, by, c.surfaceZ(bx, by) + 0.01 * s), BLUSH, {
						ellipsoid = true,
						transparency = 0.2,
					})
				end
			end
			if def.Body ~= "bird" and not opt("NoMouth") then
				local my = eyeY - 0.19 * s
				add("Mouth", V(0.14 * s, 0.06 * s, 0.05 * s), CFrame.new(0, my, c.surfaceZ(0, my) + 0.005 * s), DARK, { ellipsoid = true })
			end
		end

		-- PÉS
		if not opt("Float") and not opt("Legs") then
			local footD = 0.28 * s
			for _, side in { -1, 1 } do
				add("Foot", V(footD, footD, footD), CFrame.new(0.22 * s * shape.wx * side, -ry + 0.02 * s, -0.12 * s), accent, { ball = true })
			end
		end

		-- TIPOS DE CORPO
		local body = def.Body
		if body == "bunny" then
			for _, side in { -1, 1 } do
				local earCF = CFrame.new(0.17 * s * side, ry + 0.2 * s, 0) * CFrame.Angles(0, 0, math.rad(-12 * side))
				add("Ear", V(0.2 * s, 0.6 * s, 0.12 * s), earCF, def.Color, { ellipsoid = true, material = bodyMaterial })
				add("EarInner", V(0.1 * s, 0.42 * s, 0.03 * s), earCF * CFrame.new(0, 0.02 * s, -0.05 * s), accent, { ellipsoid = true })
			end
		elseif body == "cat" or body == "unicorn" then
			for _, side in { -1, 1 } do
				local earCF = CFrame.new(0.24 * s * side, ry * 0.85, 0) * CFrame.Angles(0, 0, math.rad(-15 * side)) * CFrame.Angles(0, 0, math.rad(45))
				add("Ear", V(0.28 * s, 0.28 * s, 0.1 * s), earCF, def.Color, { material = bodyMaterial })
				add("EarInner", V(0.16 * s, 0.16 * s, 0.04 * s), earCF * CFrame.new(0, 0, -0.05 * s), accent)
			end
			if body == "cat" then
				add("Tail", V(0.13 * s, 0.13 * s, 0.6 * s), CFrame.new(0, 0.1 * s, rz + 0.1 * s) * CFrame.Angles(math.rad(-35), 0, 0), accent, {
					ellipsoid = true,
					material = if def.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				})
			end
		elseif body == "bird" then
			local by = eyeY - 0.12 * s
			add("Beak", V(0.14 * s, 0.15 * s, 0.15 * s), CFrame.new(0, by, c.surfaceZ(0, by) - 0.02 * s) * CFrame.Angles(math.rad(45), 0, 0), rgb(255, 150, 40))
			for _, side in { -1, 1 } do
				add("Wing", V(0.1 * s, 0.4 * s, 0.45 * s), CFrame.new((rx + 0.01 * s) * side, -0.05 * s, 0.05 * s) * CFrame.Angles(0, 0, math.rad(20 * side)), accent, {
					ellipsoid = true,
					material = if def.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				})
			end
			for i = -1, 1 do
				local d = 0.12 * s
				add("Tuft", V(d, d, d), CFrame.new(i * 0.06 * s, ry + 0.03 * s, -0.05 * s + math.abs(i) * 0.04 * s), accent, { ball = true })
			end
		elseif body == "toad" then
			for i, pos in { Vector2.new(-0.25, 0.15), Vector2.new(0.2, 0.25), Vector2.new(0.05, 0.35) } do
				local x, z = pos.X * s, pos.Y * s
				local d = (0.1 + i * 0.02) * s
				add("Spot", V(d, d * 0.4, d), CFrame.new(x, c.surfaceY(x, z) - 0.01 * s, z), accent, { ellipsoid = true })
			end
		end

		if body == "dino" or body == "dragon" then
			for _, zf in { -0.15, 0.1, 0.33 } do
				local z = zf * s
				add("Spike", V(0.06 * s, 0.2 * s, 0.2 * s), CFrame.new(0, c.surfaceY(0, z) - 0.02 * s, z) * CFrame.Angles(math.rad(45), 0, 0), accent, {
					material = if def.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				})
			end
			add("Tail", V(0.3 * s, 0.28 * s, 0.75 * s), CFrame.new(0, -ry * 0.45, rz + 0.1 * s) * CFrame.Angles(math.rad(12), 0, 0), def.Color, {
				ellipsoid = true,
				material = bodyMaterial,
			})
		end

		if body == "dragon" then
			for _, side in { -1, 1 } do
				add("Wing", V(0.75 * s, 0.05 * s, 0.42 * s), CFrame.new((rx + 0.22 * s) * side, 0.25 * s, 0.15 * s) * CFrame.Angles(0, 0, math.rad(28 * side)), accent, {
					material = if def.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
					transparency = 0.1,
				})
				add("Horn", V(0.08 * s, 0.3 * s, 0.08 * s), CFrame.new(0.16 * s * side, ry + 0.06 * s, -0.08 * s) * CFrame.Angles(math.rad(-20), 0, math.rad(-15 * side)), WHITE)
			end
		end

		if body == "unicorn" and not def.Special then
			add("Horn", V(0.09 * s, 0.45 * s, 0.09 * s), CFrame.new(0, ry + 0.12 * s, -rz * 0.4) * CFrame.Angles(math.rad(-25), 0, 0), GOLD, {
				material = Enum.Material.Neon,
			})
			for i, color in RAINBOW do
				local z = (-0.1 + (i - 1) * 0.1) * s
				local d = 0.17 * s
				add("Mane", V(d, d, d), CFrame.new(0, c.surfaceY(0, z) + 0.02 * s, z), color, { ball = true, material = Enum.Material.Neon })
			end
		end

		-- MONTAGEM ESPECIAL
		local specialBuild = def.Special and Specials[def.Special]
		if specialBuild then
			specialBuild(c)
		end
	end

	-- ACESSÓRIOS
	if def.Fire and c.body then
		c.fire(c.body, accent, rgb(255, 230, 90), s * 0.7)
	end
	if def.Aura and not model:FindFirstChild("Aura") then
		c.aura(accent, 1.8)
	end
	if def.Crown and not mesh3D then
		local crownY = ry + 0.02 * s
		add("CrownBand", V(0.18 * s, 0.55 * s, 0.55 * s), CFrame.new(0, crownY, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, {
			cylinder = true,
			material = Enum.Material.Foil,
			reflectance = 0.2,
		})
		for i = 1, 5 do
			local angle = (i - 1) / 5 * math.pi * 2
			local px, pz = math.sin(angle) * 0.24 * s, math.cos(angle) * 0.24 * s
			add("CrownPoint", V(0.13 * s, 0.13 * s, 0.05 * s), CFrame.new(px, crownY + 0.12 * s, pz) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.rad(45)), GOLD, {
				material = Enum.Material.Foil,
			})
			local gemD = 0.06 * s
			add("Gem", V(gemD, gemD, gemD), CFrame.new(px * 1.05, crownY + 0.02 * s, pz * 1.05), rgb(255, 60, 90), {
				ball = true,
				material = Enum.Material.Neon,
			})
		end
	end

	if def.Glow then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 10 + s
		light.Brightness = 1.5
		light.Shadows = false
		light.Parent = root
	end

	if def.Sparkles then
		local colors = if def.SparkleColors == "rainbow"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, RAINBOW[1]),
				ColorSequenceKeypoint.new(0.25, RAINBOW[3]),
				ColorSequenceKeypoint.new(0.5, RAINBOW[4]),
				ColorSequenceKeypoint.new(0.75, RAINBOW[5]),
				ColorSequenceKeypoint.new(1, RAINBOW[6]),
			})
			else ColorSequence.new(accent, WHITE)
		c.particles("Sparkles", {
			Color = colors,
			LightEmission = 1,
			Rate = if rarity.Name == "Mythic" or rarity.Name == "Secret" then 12 else 6,
			Lifetime = NumberRange.new(0.8, 1.6),
			Speed = NumberRange.new(1, 2.5),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			}),
		})
	end

	-- Calcula chão e topo a partir das peças (ignora a aura)
	local minY, maxY = math.huge, -math.huge
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= root and part.Name ~= "Aura" and part.Transparency < 1 then
			local cframe = part.CFrame
			local size = part.Size
			local extent = math.abs(cframe.RightVector.Y) * size.X / 2 + math.abs(cframe.UpVector.Y) * size.Y / 2 + math.abs(cframe.LookVector.Y) * size.Z / 2
			minY = math.min(minY, cframe.Position.Y - extent)
			maxY = math.max(maxY, cframe.Position.Y + extent)
		end
	end
	local groundOffset = -minY
	if opt("Float") then
		groundOffset += 0.3 * s
	end
	return model, root, groundOffset, maxY
end

---------------------------------------------------------------------
-- OVOS: monta o ovo de cada tipo (grass, spotted, crystal, royal, cosmic)
-- Devolve: model, root, groundOffset, topOffset (igual ao Build)
---------------------------------------------------------------------
function Builder.BuildEgg(egg: any)
	local s: number = egg.Size or 3
	local rx, ry, rz = s * 0.4, s * 0.5, s * 0.4

	local model = Instance.new("Model")
	model.Name = egg.Name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(s * 0.6, s * 0.6, s * 0.6)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local function add(name: string, size: Vector3, cframe: CFrame, color: Color3, options: any?): BasePart
		options = options or {}
		local part = Instance.new("Part")
		part.Name = name
		if options.ball then
			part.Shape = Enum.PartType.Ball
			local d = math.min(size.X, size.Y, size.Z)
			part.Size = V(d, d, d)
		elseif options.cylinder then
			part.Shape = Enum.PartType.Cylinder
			part.Size = size
		else
			part.Size = size
		end
		if options.ellipsoid then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		part.CFrame = cframe
		part.Color = color
		part.Material = options.material or Enum.Material.SmoothPlastic
		part.Transparency = options.transparency or 0
		part.Reflectance = options.reflectance or 0
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = options.material ~= Enum.Material.ForceField
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	-- ponto na casca do ovo (ângulos em graus) e a direção "para fora"
	local function shellPoint(yaw: number, pitch: number, lift: number?): (Vector3, Vector3)
		local a, b = math.rad(yaw), math.rad(pitch)
		local normal = V(math.cos(b) * math.sin(a), math.sin(b), math.cos(b) * math.cos(a))
		local point = V(normal.X * rx, normal.Y * ry, normal.Z * rz) * (1 + (lift or 0))
		return point, normal
	end

	-- MODELO 3D (Higgsfield → Studio): se existir em ReplicatedStorage.Models3D, usa ele no lugar das peças
	local mesh3D, meshHeight = Models3D.Get(egg.Id, { Size = s * 1.05, Fit = "Height", Anchored = false })
	if mesh3D then
		mesh3D:PivotTo(CFrame.new(0, -meshHeight / 2, 0))
		for _, d in mesh3D:GetDescendants() do
			if d:IsA("BasePart") then
				d.Parent = model
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
			end
		end
		mesh3D:Destroy()
		model:SetAttribute("Is3D", true)
		ry = meshHeight / 2
	end

	local style = if mesh3D then "mesh3D" else egg.Style
	local material = Enum.Material.SmoothPlastic
	local transparency = 0
	if style == "crystal" then
		material = Enum.Material.Glass
		transparency = 0.15
	elseif style == "royal" then
		material = Enum.Material.Foil
	elseif style == "cosmic" then
		material = Enum.Material.Neon
	end
	if not mesh3D then
		add("Shell", V(rx * 2, ry * 2, rz * 2), CFrame.identity, egg.Color, {
			ellipsoid = true,
			material = material,
			transparency = transparency,
			reflectance = if style == "royal" then 0.2 else 0,
		})
	end

	if style == "grass" then
		for i, spot in { { 20, 10 }, { 140, 30 }, { 250, -15 }, { 320, 40 }, { 80, -40 } } do
			local point, normal = shellPoint(spot[1], spot[2], -0.02)
			local d = s * (0.22 + (i % 2) * 0.08)
			add("Leaf", V(d, d * 0.6, d * 0.25), CFrame.lookAt(point, point + normal), egg.Accent, { ellipsoid = true })
		end
	elseif style == "spotted" then
		for i = 0, 8 do
			local point, normal = shellPoint(i * 40 + 15, ((i * 37) % 100) - 45, -0.02)
			local d = s * (0.18 + (i % 3) * 0.05)
			add("Spot", V(d, d, d * 0.25), CFrame.lookAt(point, point + normal), egg.Accent, { ellipsoid = true })
		end
	elseif style == "crystal" then
		for i = 0, 5 do
			local yaw = i * 60
			local point = select(1, shellPoint(yaw, -35, -0.1))
			local tip = point + V(math.sin(math.rad(yaw)) * 0.35 * s, -0.05 * s, math.cos(math.rad(yaw)) * 0.35 * s)
			local mid = (point + tip) / 2
			local shard = add("Shard", V(0.16 * s, 0.16 * s, (tip - point).Magnitude + 0.1 * s), CFrame.lookAt(mid, tip) * CFrame.Angles(0, 0, math.rad(45)), egg.Accent, {
				material = Enum.Material.Neon,
				transparency = 0.1,
			})
			shard.Name = "Shard"
		end
	elseif style == "royal" then
		for _, y in { -0.15, 0.25 } do
			local width = math.sqrt(math.max(0, 1 - y * y)) * 2.06
			add("Band", V(0.12 * s, rx * width, rz * width), CFrame.new(0, y * ry, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 240, 200), {
				cylinder = true,
				material = Enum.Material.Foil,
			})
		end
		for i = 0, 5 do
			local point, normal = shellPoint(i * 60, 5, 0.01)
			local d = 0.12 * s
			add("Gem", V(d, d, d), CFrame.lookAt(point, point + normal), egg.Accent, { ball = true, material = Enum.Material.Neon })
		end
		-- coroinha no topo
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			local position = V(math.sin(angle) * 0.13 * s, ry * 0.98, math.cos(angle) * 0.13 * s)
			add("CrownPoint", V(0.12 * s, 0.12 * s, 0.04 * s), CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.rad(45)), GOLD, {
				material = Enum.Material.Foil,
			})
		end
	elseif style == "cosmic" then
		for i = 1, 16 do
			local point, normal = shellPoint(i * 137.5, math.deg(math.asin((i / 8.5) - 1)), 0.005)
			local d = (if i % 4 == 0 then 0.1 else 0.06) * s
			add("Star", V(d, d, d), CFrame.lookAt(point, point + normal), if i % 3 == 0 then egg.Accent else WHITE, {
				ball = true,
				material = Enum.Material.Neon,
			})
		end
		add("Ring", V(0.08 * s, s * 1.25, s * 1.25), CFrame.Angles(math.rad(20), 0, math.rad(90)), egg.Accent, {
			cylinder = true,
			material = Enum.Material.Neon,
			transparency = 0.45,
		})
	end

	if egg.Tier and egg.Tier >= 3 then
		local light = Instance.new("PointLight")
		light.Color = egg.Accent
		light.Range = 8 + s
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = root
	end
	if egg.Tier and egg.Tier >= 4 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Color = ColorSequence.new(egg.Accent, WHITE)
		sparkles.LightEmission = 1
		sparkles.Rate = 8
		sparkles.Lifetime = NumberRange.new(0.8, 1.5)
		sparkles.Speed = NumberRange.new(1, 2.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Parent = root
	end

	return model, root, ry, ry
end

---------------------------------------------------------------------
-- MUTAÇÕES: muda a cor do "corpo" (peças marcadas como Skin) e adiciona brilho
---------------------------------------------------------------------
Builder.RainbowColors = RAINBOW

function Builder.ApplyMutation(model: Model, mutation: string?)
	local info = mutation and Config.MutationByName[mutation]
	if not info then
		return
	end
	model:SetAttribute("Mutation", mutation)
	local index = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Skin") then
			index += 1
			-- modelo 3D: Gold/Diamond viram "estátua" (tira a textura para a cor aparecer); Rainbow mantém a textura
			if part:IsA("MeshPart") and mutation ~= "Rainbow" then
				pcall(function()
					part.TextureID = ""
				end)
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
			end
			if part:IsA("MeshPart") and mutation == "Rainbow" then
				continue
			end
			if mutation == "Gold" then
				part.Color = info.Color
				part.Material = Enum.Material.Foil
				part.Reflectance = 0.15
			elseif mutation == "Diamond" then
				part.Color = info.Color
				part.Material = Enum.Material.Glass
				part.Reflectance = 0.3
				part.Transparency = math.max(part.Transparency, 0.1)
			elseif mutation == "Rainbow" then
				part.Color = RAINBOW[(index - 1) % #RAINBOW + 1]
				part.Material = Enum.Material.Neon
			end
		end
	end
	local root = model.PrimaryPart
	if root then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "MutationSparkles"
		sparkles.Color = if mutation == "Rainbow"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, RAINBOW[1]),
				ColorSequenceKeypoint.new(0.5, RAINBOW[4]),
				ColorSequenceKeypoint.new(1, RAINBOW[6]),
			})
			else ColorSequence.new(info.Color, WHITE)
		sparkles.LightEmission = 1
		sparkles.Rate = if mutation == "Gold" then 5 elseif model:GetAttribute("Is3D") and mutation == "Rainbow" then 22 else 10
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Speed = NumberRange.new(1.5, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Parent = root
	end
end

return Builder
