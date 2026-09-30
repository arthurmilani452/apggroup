--[[
	WorldFX (ModuleScript em StarterPlayer > StarterPlayerScripts)
	v21: EFEITOS 3D do mundo, só na tela de cada jogador (o servidor não gasta nada com isso):
	  • pedestal com disco de luz na cor da raridade (pulsando); Épico+ solta brilhinhos;
	    Lendário+ ganha feixes girando e uma luz de verdade
	  • ovos na esteira soltam faíscas na cor da raridade
	  • ovo chocando: onda de choque + clarão no pedestal
	  • poeirinha nos pés de quem corre
	  • "pólen" flutuando de dia e vagalumes de noite, em volta da câmera
	  • coletar dinheiro = chuva de moedas 3D; compra/level up/rebirth = explosão de brilho no personagem
	"Low graphics" (SETTINGS) desliga as partículas e as luzes; os discos continuam (são só uma peça).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldFX = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local PAD_RANGE = 120 -- studs: discos e brilhinhos
local LIGHT_RANGE = 70 -- studs: luzes de verdade (Lendário+)
local MAX_LIGHTS = 10
local RUN_RANGE = 80

local player = Players.LocalPlayer
local folder: Folder? = nil

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "WorldFX"
	f.Parent = workspace
	folder = f
	return f
end

local function lowGfx(): boolean
	return player:GetAttribute("LowGfx") == true
end

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

local function ghostPart(size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function rarityOf(model: Instance)
	local name = model:GetAttribute("Rarity")
	local rarity = if typeof(name) == "string" then Config.RarityByName[name] else nil
	return rarity or Config.Rarities[1], Config.RarityIndex[if rarity then rarity.Name else "Common"] or 1
end

---------------------------------------------------------------------
-- 1) PEDESTAIS: disco de luz + brilhinhos + feixes
---------------------------------------------------------------------
type Pad = { Model: Instance, Disc: Part, Beams: { Part }?, Light: PointLight?, Center: Vector3, Phase: number, Index: number, Color: Color3, Tween: Tween }
local pads: { [Instance]: Pad } = {}
local startHatchGlow: (Model) -> () -- definida mais abaixo (seção 3); a varredura dos pedestais chama
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function pedestalTop(model: Model, home: CFrame): number
	local exclude = { model }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local active = workspace:FindFirstChild("ActiveCritters")
	if active then
		table.insert(exclude, active)
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(home.Position, Vector3.new(0, -12, 0), rayParams)
	if hit then
		return hit.Position.Y
	end
	local box, size = model:GetBoundingBox()
	return box.Position.Y - size.Y / 2
end

local function makePad(model: Model, home: CFrame)
	local rarity, index = rarityOf(model)
	local top = pedestalTop(model, home)
	local center = Vector3.new(home.Position.X, top + 0.08, home.Position.Z)
	local isEgg = model:GetAttribute("Kind") == "Egg"
	local color = rarity.Color
	local disc = Instance.new("Part")
	disc.Name = "GlowPad"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.12, if isEgg then 4.6 else 6.2, if isEgg then 4.6 else 6.2)
	disc.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = 0.55
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Parent = getFolder()
	local tween = TweenService:Create(disc, TweenInfo.new(0.9 + math.random() * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.82 })
	tween:Play()
	local pad: Pad = { Model = model, Disc = disc, Beams = nil, Light = nil, Center = center, Phase = math.random() * 6, Index = index, Color = color, Tween = tween }
	if index >= 4 and not lowGfx() then
		emitter(disc, {
			Name = "PadSparkles",
			Texture = SPARK,
			Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
			LightEmission = 1,
			Size = seq(0.4, 0),
			Transparency = seq(0.1, 1),
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(1.5, 3),
			SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Right, -- "para cima" do cilindro deitado (eixo X virou Y)
			Rate = if index >= 6 then 9 elseif index >= 5 then 6 else 3,
		})
	end
	if index >= 5 then
		-- dois feixes cruzados girando em volta do bichinho
		local beams = {}
		for i = 1, 2 do
			local beam = Instance.new("Part")
			beam.Name = "Beam"
			beam.Size = Vector3.new(0.22, 5.5, 0.22)
			beam.Material = Enum.Material.Neon
			beam.Color = color
			beam.Transparency = 0.45
			beam.Anchored = true
			beam.CanCollide = false
			beam.CanQuery = false
			beam.CanTouch = false
			beam.CastShadow = false
			beam.CFrame = CFrame.new(center)
			beam.Parent = disc
			beams[i] = beam
		end
		pad.Beams = beams
	end
	pads[model] = pad
end

local function removePad(model: Instance)
	local pad = pads[model]
	if pad then
		pads[model] = nil
		pad.Tween:Cancel()
		pad.Disc:Destroy()
	end
end

local function refreshPads(cameraPosition: Vector3)
	local active = workspace:FindFirstChild("ActiveCritters")
	if not active then
		return
	end
	local low = lowGfx()
	local wanted: { [Instance]: boolean } = {}
	local lightCandidates: { { Pad: Pad, Dist: number } } = {}
	for _, model in active:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local state = model:GetAttribute("State")
		local home = model:GetAttribute("Home")
		if (state == "Placed" or state == "Incubating" or state == "Hatching") and typeof(home) == "CFrame" then
			local dist = (home.Position - cameraPosition).Magnitude
			if state == "Hatching" and dist < 150 then
				startHatchGlow(model :: Model)
			end
			if dist < PAD_RANGE then
				wanted[model] = true
				local pad = pads[model]
				if not pad then
					makePad(model, home)
					pad = pads[model]
				elseif (pad.Center - Vector3.new(home.Position.X, pad.Center.Y, home.Position.Z)).Magnitude > 0.5 then
					-- mudou de pedestal (arrastou na base): refaz
					removePad(model)
					makePad(model, home)
					pad = pads[model]
				end
				if pad and pad.Index >= 5 and dist < LIGHT_RANGE and not low then
					table.insert(lightCandidates, { Pad = pad, Dist = dist })
				end
			end
		end
	end
	for model in pads do
		if not wanted[model] then
			removePad(model)
		end
	end
	-- luzes de verdade só nos Lendário+ mais perto (o celular agradece)
	table.sort(lightCandidates, function(a, b)
		return a.Dist < b.Dist
	end)
	local lit: { [Pad]: boolean } = {}
	for i, entry in lightCandidates do
		if i > MAX_LIGHTS then
			break
		end
		lit[entry.Pad] = true
		if not entry.Pad.Light then
			local light = Instance.new("PointLight")
			light.Color = entry.Pad.Color
			light.Range = 11
			light.Brightness = 0.9
			light.Shadows = false
			light.Parent = entry.Pad.Disc
			entry.Pad.Light = light
		end
	end
	for _, pad in pads do
		if pad.Light and not lit[pad] then
			pad.Light:Destroy()
			pad.Light = nil
		end
	end
end

local function stepBeams(now: number)
	for _, pad in pads do
		local beams = pad.Beams
		if beams then
			local spin = now * 0.9 + pad.Phase
			local lift = 2.9 + math.sin(now * 1.4 + pad.Phase) * 0.3
			for i, beam in beams do
				local angle = spin + (i - 1) * math.pi / 2
				beam.CFrame = CFrame.new(pad.Center + Vector3.new(0, lift, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(3.4, 0, 0) * CFrame.Angles(0, 0, math.rad(12))
			end
		end
	end
end

---------------------------------------------------------------------
-- 2) OVOS NA ESTEIRA: faíscas na cor da raridade
---------------------------------------------------------------------
local sparkled: { [Instance]: boolean } = {}

local function refreshConveyorEggs(cameraPosition: Vector3)
	if lowGfx() then
		return
	end
	local active = workspace:FindFirstChild("ActiveCritters")
	if not active then
		return
	end
	for _, model in active:GetChildren() do
		if model:IsA("Model") and not sparkled[model] and model:GetAttribute("State") == "Conveyor" then
			local root = model:FindFirstChild("Root") :: BasePart?
			if root and (root.Position - cameraPosition).Magnitude < PAD_RANGE then
				sparkled[model] = true
				local rarity, index = rarityOf(model)
				emitter(root, {
					Name = "EggSparkles",
					Texture = SPARK,
					Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1)),
					LightEmission = 1,
					Size = seq(0.35, 0),
					Transparency = seq(0.1, 1),
					Lifetime = NumberRange.new(0.6, 1.1),
					Speed = NumberRange.new(1, 2.5),
					SpreadAngle = Vector2.new(180, 180),
					Rate = 2 + index * 1.5,
				})
				model.Destroying:Connect(function()
					sparkled[model] = nil
				end)
			end
		end
	end
end

---------------------------------------------------------------------
-- 3) CHOCANDO / CHOCOU (v22: animação completa)
--   enquanto choca: o ovo ganha uma luz e faíscas subindo, cada vez mais fortes
--   chocou: cascas voam (peças 3D nas cores do ovo), feixe de luz sobe, onda de choque, clarão,
--           e o bichinho "pula" para fora (escala 0.2 → 1.15 → 1)
---------------------------------------------------------------------
type HatchGlow = { Light: PointLight, Emitter: ParticleEmitter, Root: BasePart, Start: number, Colors: { Color3 } }
local hatchGlows: { [Instance]: HatchGlow } = {}
local shellColors: { { Position: Vector3, Colors: { Color3 }, At: number } } = {} -- cores do ovo que acabou de sumir

local function eggColors(model: Model): { Color3 }
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.9 then
			table.insert(parts, part)
		end
	end
	table.sort(parts, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	local colors = {}
	for i = 1, math.min(3, #parts) do
		table.insert(colors, parts[i].Color)
	end
	if #colors == 0 then
		colors[1] = Color3.new(1, 1, 1)
	end
	return colors
end

function startHatchGlow(model: Model)
	local root = model:FindFirstChild("Root") :: BasePart?
	if not root or hatchGlows[model] then
		return
	end
	local rarity = rarityOf(model)
	local colors = eggColors(model)
	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = 10
	light.Brightness = 0.6
	light.Shadows = false
	light.Parent = root
	local e = emitter(root, {
		Name = "HatchSparks",
		Texture = SPARK,
		Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Size = seq(0.45, 0),
		Transparency = seq(0, 1),
		Lifetime = NumberRange.new(0.7, 1.2),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, 6, 0),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 12,
		Enabled = not lowGfx(),
	})
	hatchGlows[model] = { Light = light, Emitter = e, Root = root, Start = os.clock(), Colors = colors }
	model.Destroying:Connect(function()
		hatchGlows[model] = nil
		table.insert(shellColors, { Position = root.Position, Colors = colors, At = os.clock() })
	end)
end

local function stepHatchGlows(now: number)
	for model, glow in hatchGlows do
		if not model.Parent then
			hatchGlows[model] = nil
			continue
		end
		local t = math.clamp((now - glow.Start) / Config.HatchRevealTime, 0, 1)
		glow.Light.Brightness = 0.6 + t * 3 + math.sin(now * (10 + t * 30)) * 0.4 * t
		glow.Light.Range = 10 + t * 8
		glow.Emitter.Rate = 12 + t * 50
	end
end

local function nearestShellColors(position: Vector3): { Color3 }?
	local now = os.clock()
	local best, bestDist = nil, 6
	for i = #shellColors, 1, -1 do
		local entry = shellColors[i]
		if now - entry.At > 4 then
			table.remove(shellColors, i)
		else
			local d = (entry.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = entry.Colors, d
			end
		end
	end
	return best
end

-- Cascas do ovo voando (peças 3D ancoradas, animadas na mão) e feixe de luz subindo
local function hatchShells(position: Vector3, colors: { Color3 }, rarity)
	local holder = getFolder()
	local pieces = {}
	for i = 1, 12 do
		local piece = Instance.new("Part")
		piece.Name = "Shell"
		piece.Size = Vector3.new(0.5 + math.random() * 0.5, 0.35 + math.random() * 0.35, 0.12)
		piece.Color = colors[1 + (i % #colors)]
		piece.Material = Enum.Material.SmoothPlastic
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		local angle = (i / 12) * math.pi * 2 + math.random() * 0.4
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		piece.CFrame = CFrame.new(position + dir * 0.6 + Vector3.new(0, 0.8, 0))
		piece.Parent = holder
		pieces[i] = {
			Part = piece,
			Vel = dir * (7 + math.random() * 6) + Vector3.new(0, 12 + math.random() * 9, 0),
			Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14,
			Rot = CFrame.identity,
		}
	end
	local beam = Instance.new("Part")
	beam.Name = "HatchBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(14, 2.6, 2.6)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Material = Enum.Material.Neon
	beam.Color = rarity.Color
	beam.Transparency = 0.25
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Parent = holder
	TweenService:Create(beam, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(26, 0.4, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 1,
	}):Play()
	task.delay(0.9, function()
		beam:Destroy()
	end)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.05)
		local age = os.clock() - started
		for _, p in pieces do
			p.Vel -= Vector3.new(0, 55 * dt, 0)
			p.Rot = p.Rot * CFrame.Angles(p.Spin.X * dt, p.Spin.Y * dt, p.Spin.Z * dt)
			p.Part.CFrame = CFrame.new(p.Part.Position + p.Vel * dt) * p.Rot
			if age > 0.7 then
				p.Part.Transparency = math.clamp((age - 0.7) / 0.5, 0, 1)
			end
		end
		if age > 1.25 then
			connection:Disconnect()
			for _, p in pieces do
				p.Part:Destroy()
			end
		end
	end)
end

-- O bichinho novo "pula" para fora do ovo (escala 0.2 → 1.15 → 1)
local function popCritter(position: Vector3)
	task.spawn(function()
		local active = workspace:FindFirstChild("ActiveCritters")
		if not active then
			return
		end
		local model: Model? = nil
		for _ = 1, 12 do -- o modelo novo pode chegar um instante depois do aviso
			for _, candidate in active:GetChildren() do
				local root = candidate:FindFirstChild("Root") :: BasePart?
				if root and candidate:GetAttribute("Kind") == "Critter" and candidate:GetAttribute("State") == "Placed" and (root.Position - position).Magnitude < 3 then
					model = candidate :: Model
					break
				end
			end
			if model then
				break
			end
			task.wait(0.08)
		end
		if not model then
			return
		end
		local ok, base = pcall(function()
			return (model :: Model):GetScale()
		end)
		if not ok or typeof(base) ~= "number" then
			return
		end
		local started = os.clock()
		local duration = 0.65
		while model.Parent and os.clock() - started < duration do
			local t = (os.clock() - started) / duration
			-- cresce com "pulo": passa de 1.15 e volta para 1
			local f = if t < 0.45 then 0.2 + (t / 0.45) * 0.95 elseif t < 0.75 then 1.15 - ((t - 0.45) / 0.3) * 0.22 else 0.93 + ((t - 0.75) / 0.25) * 0.07
			pcall(function()
				(model :: Model):ScaleTo(base * f)
			end)
			RunService.RenderStepped:Wait()
		end
		if model.Parent then
			pcall(function()
				(model :: Model):ScaleTo(base)
			end)
		end
	end)
end

local function hatchWave(position: Vector3, rarityName: string)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - position).Magnitude > 150 then
		return
	end
	local rarity = Config.RarityByName[rarityName] or Config.Rarities[1]
	if not lowGfx() then
		hatchShells(position, nearestShellColors(position) or { rarity.Color, Color3.new(1, 1, 1) }, rarity)
	end
	popCritter(position)
	local ring = Instance.new("Part")
	ring.Name = "HatchWave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(position - Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = rarity.Color
	ring.Transparency = 0.15
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = getFolder()
	TweenService:Create(ring, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 16, 16), Transparency = 1 }):Play()
	if not lowGfx() then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 18
		light.Brightness = 4
		light.Parent = ring
		TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	end
	task.delay(0.8, function()
		ring:Destroy()
	end)
end

---------------------------------------------------------------------
-- 4) POEIRA NOS PÉS DE QUEM CORRE
---------------------------------------------------------------------
local dust: { [Model]: { Emitter: ParticleEmitter, Root: BasePart, Humanoid: Humanoid } } = {}

local function ensureDust(character: Model)
	if dust[character] then
		return dust[character]
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "RunDust"
	attachment.Position = Vector3.new(0, -2.7, 0)
	attachment.Parent = root
	local e = emitter(attachment, {
		Name = "Dust",
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(230, 220, 195)),
		Size = seq(0.6, 1.6),
		Transparency = seq(0.6, 1),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(60, 60),
		Rate = 0,
	})
	local entry = { Emitter = e, Root = root, Humanoid = humanoid }
	dust[character] = entry
	character.Destroying:Connect(function()
		dust[character] = nil
	end)
	return entry
end

local function refreshDust(cameraPosition: Vector3)
	local low = lowGfx()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if not character or not character.Parent then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local near = (root.Position - cameraPosition).Magnitude < RUN_RANGE
		local entry = dust[character]
		if near and not low then
			entry = entry or ensureDust(character)
			if entry then
				local vel = root.AssemblyLinearVelocity
				local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
				local grounded = entry.Humanoid.FloorMaterial ~= Enum.Material.Air
				entry.Emitter.Rate = if grounded and speed > 12 then 8 + speed * 0.35 else 0
			end
		elseif entry then
			entry.Emitter.Rate = 0
		end
	end
end

---------------------------------------------------------------------
-- 5) PÓLEN DE DIA, VAGALUMES DE NOITE (em volta da câmera)
---------------------------------------------------------------------
local ambient: Part? = nil
local ambientEmitter: ParticleEmitter? = nil
local ambientNight: boolean? = nil

local function stepAmbient(camera: Camera)
	if lowGfx() then
		if ambientEmitter then
			ambientEmitter.Enabled = false
		end
		return
	end
	if not ambient then
		ambient = ghostPart(Vector3.new(60, 18, 60), camera.CFrame, getFolder())
		ambient.Name = "Ambient"
		ambientEmitter = emitter(ambient, {
			Name = "Pollen",
			Texture = SPARK,
			LightEmission = 1,
			Size = seq(0.22, 0.12),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(0.4, 1.2),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0.3, 0.15, 0.1),
			Rate = 7,
			Enabled = true,
		})
	end
	local a = ambient :: Part
	local e = ambientEmitter :: ParticleEmitter
	e.Enabled = true
	local look = camera.CFrame.LookVector
	a.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(look.X, 0, look.Z) * 20 + Vector3.new(0, 4, 0))
	local clock = Lighting.ClockTime
	local night = clock >= 18.5 or clock < 5.5
	if night ~= ambientNight then
		ambientNight = night
		e.Color = if night
			then ColorSequence.new(Color3.fromRGB(230, 255, 120), Color3.fromRGB(255, 240, 150))
			else ColorSequence.new(Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 220, 240))
		e.Rate = if night then 5 else 7
	end
end

---------------------------------------------------------------------
-- 6) EFEITOS NO PERSONAGEM: moedas ao coletar, brilho ao comprar, explosão no level up
---------------------------------------------------------------------
local playerFx: { Attachment: Attachment, Coins: ParticleEmitter, Sparkle: ParticleEmitter, Confetti: ParticleEmitter }? = nil

local function ensurePlayerFx()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	if playerFx and playerFx.Attachment.Parent == root then
		return playerFx
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PlayerFX"
	attachment.Parent = root
	local coins = emitter(attachment, {
		Name = "Coins",
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 240, 150)),
		LightEmission = 0.8,
		Size = seq(0.55, 0.3),
		Transparency = seq(0, 0.6),
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(14, 20),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -42, 0),
		Rate = 0,
	})
	local sparkle = emitter(attachment, {
		Name = "Sparkle",
		Texture = SPARK,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(180, 230, 255)),
		LightEmission = 1,
		Size = seq(0.5, 0),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Rate = 0,
	})
	local confetti = emitter(attachment, {
		Name = "Confetti",
		Texture = SPARK,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 200, 255)),
		}),
		LightEmission = 0.9,
		Size = seq(0.6, 0.2),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(16, 26),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -30, 0),
		RotSpeed = NumberRange.new(-200, 200),
		Rate = 0,
	})
	playerFx = { Attachment = attachment, Coins = coins, Sparkle = sparkle, Confetti = confetti }
	return playerFx
end

function WorldFX.Init(ctx)
	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if lowGfx() then
			return
		end
		if kind == "HatchBurst" then
			if type(data) == "table" and typeof(data.Position) == "Vector3" then
				hatchWave(data.Position, tostring(data.Rarity))
			end
		elseif kind == "Collect" then
			local fx = ensurePlayerFx()
			if fx then
				local amount = if typeof(data) == "number" then data else 0
				fx.Coins:Emit(math.clamp(10 + math.floor(math.log10(math.max(amount, 1)) * 5), 10, 45))
			end
		elseif kind == "Purchase" or kind == "Lock" or kind == "Fused" or kind == "Mixed" then
			local fx = ensurePlayerFx()
			if fx then
				fx.Sparkle:Emit(if kind == "Purchase" and data == "Legendary" then 60 else 28)
			end
		elseif kind == "LevelUp" or kind == "Rebirth" or kind == "QuestsAll" or kind == "Prestige" or kind == "WorldFirst" then
			local fx = ensurePlayerFx()
			if fx then
				fx.Confetti:Emit(if kind == "Rebirth" then 110 else 70)
				fx.Sparkle:Emit(30)
			end
		end
	end)

	-- varredura leve (4x por segundo): discos, ovos da esteira, poeira
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local ok, err = pcall(function()
			refreshPads(cameraPosition)
			refreshConveyorEggs(cameraPosition)
			refreshDust(cameraPosition)
		end)
		if not ok then
			warn("[WorldFX]", err)
		end
	end)

	-- todo frame: feixes girando e o pólen seguindo a câmera
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock()
		stepBeams(now)
		stepHatchGlows(now)
		stepAmbient(camera)
	end)

	-- Low graphics ligado depois: tira brilhinhos e luzes dos discos
	player:GetAttributeChangedSignal("LowGfx"):Connect(function()
		if lowGfx() then
			for _, pad in pads do
				local e = pad.Disc:FindFirstChild("PadSparkles")
				if e then
					e:Destroy()
				end
				if pad.Light then
					pad.Light:Destroy()
					pad.Light = nil
				end
			end
		end
	end)
end

return WorldFX
