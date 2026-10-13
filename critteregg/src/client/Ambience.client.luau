--[[
	Ambience (cliente): clima de cada zona.
	  - cor do ar / neblina / tom da imagem mudam suave quando você entra numa zona
	  - partículas em volta da câmera: vaga-lumes na floresta, neve, brasas no vulcão,
	    estrelas no cosmos, bolhas no oceano, pétalas na cerejeira, brilho dourado no céu...
	Cada mundo tem "cara" própria.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rgb = Color3.fromRGB

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- Air = Atmosphere.Color, Decay, Density, Haze; Tint = ColorCorrection.TintColor
-- P = partículas: textura, cores, tamanho, taxa, velocidade (Y), espalhamento, brilho, vida
local PRESETS = {
	hub = { Air = rgb(200, 225, 255), Decay = rgb(120, 170, 230), Density = 0.22, Haze = 0.6, Tint = rgb(255, 255, 255) },
	forest = { Air = rgb(200, 235, 210), Decay = rgb(110, 170, 120), Density = 0.26, Haze = 0.9, Tint = rgb(250, 255, 245),
		P = { Tex = SPARK, Colors = { rgb(220, 255, 120), rgb(255, 240, 120) }, Size = 0.35, Rate = 14, Speed = 0.6, Spread = 60, Light = 1, Life = 6 } },
	lake = { Air = rgb(190, 225, 255), Decay = rgb(100, 160, 220), Density = 0.25, Haze = 0.8, Tint = rgb(245, 252, 255),
		P = { Tex = SPARK, Colors = { rgb(200, 240, 255), rgb(255, 255, 255) }, Size = 0.3, Rate = 10, Speed = 0.4, Spread = 60, Light = 1, Life = 5 } },
	desert = { Air = rgb(255, 225, 175), Decay = rgb(230, 170, 110), Density = 0.32, Haze = 1.6, Tint = rgb(255, 246, 228),
		P = { Tex = SMOKE, Colors = { rgb(240, 215, 160), rgb(225, 195, 140) }, Size = 3, Rate = 6, Speed = 0.2, Spread = 70, Light = 0, Life = 7, Wind = Vector3.new(9, 0, 2), Trans = 0.8 } },
	jungle = { Air = rgb(185, 230, 175), Decay = rgb(80, 140, 80), Density = 0.34, Haze = 1.4, Tint = rgb(240, 255, 238),
		P = { Tex = SPARK, Colors = { rgb(180, 255, 100), rgb(255, 255, 140) }, Size = 0.4, Rate = 18, Speed = 0.5, Spread = 60, Light = 1, Life = 6 } },
	snow = { Air = rgb(225, 238, 255), Decay = rgb(170, 200, 240), Density = 0.36, Haze = 1.8, Tint = rgb(240, 248, 255),
		P = { Tex = SPARK, Colors = { rgb(255, 255, 255), rgb(225, 240, 255) }, Size = 0.45, Rate = 45, Speed = -7, Spread = 70, Light = 0.4, Life = 8, Wind = Vector3.new(3, 0, 1) } },
	volcano = { Air = rgb(255, 160, 120), Decay = rgb(140, 50, 40), Density = 0.4, Haze = 2.2, Tint = rgb(255, 232, 215),
		P = { Tex = FIRE, Colors = { rgb(255, 170, 60), rgb(255, 90, 30) }, Size = 0.5, Rate = 30, Speed = 5, Spread = 60, Light = 1, Life = 5, Wind = Vector3.new(1, 0, 0) } },
	abyss = { Air = rgb(110, 175, 240), Decay = rgb(30, 70, 150), Density = 0.42, Haze = 2.4, Tint = rgb(215, 238, 255),
		P = { Tex = SPARK, Colors = { rgb(170, 230, 255), rgb(255, 255, 255) }, Size = 0.6, Rate = 22, Speed = 3, Spread = 60, Light = 0.6, Life = 7, Trans = 0.4 } },
	prehistoric = { Air = rgb(255, 220, 175), Decay = rgb(200, 140, 90), Density = 0.3, Haze = 1.3, Tint = rgb(255, 245, 230),
		P = { Tex = SMOKE, Colors = { rgb(230, 200, 150), rgb(210, 180, 130) }, Size = 2.5, Rate = 4, Speed = 0.3, Spread = 70, Light = 0, Life = 7, Wind = Vector3.new(4, 0, 0), Trans = 0.85 } },
	cosmic = { Air = rgb(140, 105, 220), Decay = rgb(60, 30, 120), Density = 0.38, Haze = 1.6, Tint = rgb(235, 225, 255),
		P = { Tex = SPARK, Colors = { rgb(255, 255, 255), rgb(200, 170, 255), rgb(255, 230, 140) }, Size = 0.5, Rate = 30, Speed = 0.3, Spread = 70, Light = 1, Life = 6 } },
	cherry = { Air = rgb(255, 210, 230), Decay = rgb(230, 150, 190), Density = 0.3, Haze = 1.2, Tint = rgb(255, 242, 248),
		P = { Tex = SPARK, Colors = { rgb(255, 170, 205), rgb(255, 225, 240) }, Size = 0.55, Rate = 35, Speed = -3, Spread = 70, Light = 0.3, Life = 8, Wind = Vector3.new(4, 0, 2), Spin = true } },
	titan = { Air = rgb(190, 215, 180), Decay = rgb(100, 130, 95), Density = 0.34, Haze = 1.5, Tint = rgb(245, 255, 240),
		P = { Tex = SMOKE, Colors = { rgb(200, 220, 190), rgb(180, 200, 170) }, Size = 4, Rate = 4, Speed = 0.2, Spread = 70, Light = 0, Life = 8, Trans = 0.85 } },
	heaven = { Air = rgb(255, 245, 215), Decay = rgb(255, 215, 140), Density = 0.3, Haze = 1.4, Tint = rgb(255, 250, 235),
		P = { Tex = SPARK, Colors = { rgb(255, 225, 120), rgb(255, 255, 255) }, Size = 0.5, Rate = 28, Speed = 2, Spread = 70, Light = 1, Life = 6 } },
}

local function ensure(className: string, name: string): any
	local item = Lighting:FindFirstChild(name)
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Parent = Lighting
	end
	return item
end

-- nuvem de partículas que acompanha a câmera
local holder = Instance.new("Part")
holder.Name = "AmbienceEmitter"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.Transparency = 1
holder.Size = Vector3.new(70, 1, 70)
holder.Parent = camera

local emitter = Instance.new("ParticleEmitter")
emitter.Enabled = false
emitter.EmissionDirection = Enum.NormalId.Bottom
emitter.Shape = Enum.ParticleEmitterShape.Box
emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
emitter.LightInfluence = 0
emitter.Parent = holder

local currentZone = -1
local currentPreset = PRESETS.hub

local function applyParticles(p)
	if not p then
		emitter.Enabled = false
		return
	end
	emitter.Texture = p.Tex
	local keys = {}
	for i, c in p.Colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#p.Colors - 1, 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, p.Colors[1]))
	end
	emitter.Color = ColorSequence.new(keys)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, p.Size),
		NumberSequenceKeypoint.new(0.85, p.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	local t = p.Trans or 0.1
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, t),
		NumberSequenceKeypoint.new(0.8, t),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = p.Rate
	emitter.Lifetime = NumberRange.new(p.Life * 0.7, p.Life)
	-- velocidade: positivo sobe, negativo cai (o emissor aponta pra baixo)
	emitter.EmissionDirection = if p.Speed >= 0 then Enum.NormalId.Top else Enum.NormalId.Bottom
	local speed = math.abs(p.Speed)
	emitter.Speed = NumberRange.new(speed * 0.6, speed * 1.2 + 0.3)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = p.Wind or Vector3.zero
	emitter.LightEmission = p.Light or 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = if p.Spin then NumberRange.new(-120, 120) else NumberRange.new(-20, 20)
	emitter.Drag = 0.3
	holder.Size = Vector3.new(p.Spread, 1, p.Spread)
	emitter.Enabled = true
end

local function applyZone(index: number)
	local id = if index == 0 then "hub" else Config.Zones[index].Id
	local preset = PRESETS[id] or PRESETS.hub
	currentPreset = preset
	local info = TweenInfo.new(2, Enum.EasingStyle.Sine)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Color = preset.Air, Decay = preset.Decay, Density = preset.Density, Haze = preset.Haze }):Play()
	end
	local cc = ensure("ColorCorrectionEffect", "ZoneTint")
	TweenService:Create(cc, info, { TintColor = preset.Tint }):Play()
	applyParticles(preset.P)
end

-- raios de sol suaves (fica bonito com a neblina)
local rays = ensure("SunRaysEffect", "ZoneSunRays")
rays.Intensity = 0.06
rays.Spread = 0.8

local accum = 0
RunService.RenderStepped:Connect(function(dt)
	local camCF = camera.CFrame
	-- emissor um pouco acima e à frente da câmera
	local p = currentPreset.P
	local lift = if p and p.Speed < 0 then 22 elseif p and p.Speed > 1 then -6 else 6
	local ahead = camCF.Position + Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z) * 18
	holder.CFrame = CFrame.new(ahead + Vector3.new(0, lift, 0))
	accum += dt
	if accum < 0.4 then
		return
	end
	accum = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local z = if root then root.Position.Z else camCF.Position.Z
	local zone = if z < 0 then 0 else math.clamp(math.floor(z / Config.Map.LaneLength) + 1, 1, #Config.Zones)
	if zone ~= currentZone then
		currentZone = zone
		applyZone(zone)
	end
end)
