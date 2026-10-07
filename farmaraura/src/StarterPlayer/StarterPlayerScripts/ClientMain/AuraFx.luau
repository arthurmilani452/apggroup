--[[
	AuraFx (Farmar Aura): desenha a aura em volta do boneco de TODO mundo, com o que o servidor publica
	nos atributos do jogador:
	  AuraColor (Color3)   cor da evolução (branca, azul, ... do vazio)
	  AuraRainbow / AuraVoid  evoluções especiais (arco-íris muda de cor; vazio é escura com brilho roxo)
	  AuraEquip (id)       aura da coleção equipada (Config.Auras): um 2º efeito, com o estilo dela
	Leve no celular: longe (> 140 studs) apaga; dos outros jogadores sai menos partícula; no Modo leve
	só a do próprio jogador, bem fraca. Texturas são as que já vêm no Roblox (rbxasset://).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AuraFx = {}
AuraFx.Light = false -- Modo leve (a tela liga)

local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
})

local me = Players.LocalPlayer
local tracked: { [Player]: { Base: ParticleEmitter?, Extra: ParticleEmitter?, Light: PointLight?, Rate: number, ExtraRate: number } } = {}

local function clear(player: Player)
	local t = tracked[player]
	if t then
		for _, key in { "Base", "Extra", "Light" } do
			local object = (t :: any)[key]
			if object then
				object:Destroy()
			end
		end
		tracked[player] = nil
	end
end

local function emitter(root: BasePart, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.EmissionDirection = Enum.NormalId.Top
	e.LightInfluence = 0
	e.LockedToPart = false
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = root
	return e
end

local function build(player: Player)
	clear(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local mine = player == me
	if AuraFx.Light and not mine then
		return
	end
	local color = player:GetAttribute("AuraColor")
	if typeof(color) ~= "Color3" then
		color = Config.AuraBaseColor
	end
	local void = player:GetAttribute("AuraVoid") == true
	local rainbow = player:GetAttribute("AuraRainbow") == true
	local scale = if AuraFx.Light then 0.35 elseif mine then 1 else 0.45
	-- base: chamas suaves subindo pelo corpo, na cor da evolução
	local baseRate = 26 * scale
	local base = emitter(root, "AuraBase", {
		Texture = TEX.fire,
		Color = if rainbow then RAINBOW elseif void then ColorSequence.new(Color3.fromRGB(20, 10, 40), color) else ColorSequence.new(color),
		LightEmission = if void then 0.2 else 0.85,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.7, 1.2),
		Speed = NumberRange.new(2.5, 4.5),
		SpreadAngle = Vector2.new(18, 18),
		Acceleration = Vector3.new(0, 4, 0),
		Rate = baseRate,
		ZOffset = -0.5,
	})
	local light = nil
	if mine and not AuraFx.Light then
		light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = if void then Color3.fromRGB(150, 80, 255) else color
		light.Brightness = 1.2
		light.Range = 9
		light.Shadows = false
		light.Parent = root
	end
	-- 2º efeito: a aura equipada da coleção
	local extra = nil
	local extraRate = 0
	local aura = Config.AuraById[player:GetAttribute("AuraEquip") or ""]
	if aura then
		local style = aura.Style
		local props: { [string]: any } = {
			Color = if style == "rainbow" then RAINBOW else ColorSequence.new(aura.Color),
			Lifetime = NumberRange.new(0.8, 1.6),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(60, 60),
			Rate = 14 * scale,
		}
		if style == "flame" then
			props.Texture = TEX.fire
			props.LightEmission = 1
			props.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.4) })
			props.Transparency = NumberSequence.new(0.4, 1)
			props.Acceleration = Vector3.new(0, 6, 0)
			props.Rate = 20 * scale
		elseif style == "smoke" then
			props.Texture = TEX.smoke
			props.LightEmission = 0
			props.Size = NumberSequence.new(1.2, 3)
			props.Transparency = NumberSequence.new(0.6, 1)
			props.Acceleration = Vector3.new(0, 2, 0)
		elseif style == "void" then
			props.Texture = TEX.smoke
			props.LightEmission = 0
			props.Color = ColorSequence.new(Color3.fromRGB(10, 5, 20), aura.Color)
			props.Size = NumberSequence.new(2.5, 0.5)
			props.Transparency = NumberSequence.new(0.2, 1)
			props.Speed = NumberRange.new(0.5, 1.5)
			props.RotSpeed = NumberRange.new(-90, 90)
		else -- spark, wisp, rainbow
			props.Texture = TEX.spark
			props.LightEmission = 1
			props.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0) })
			props.Transparency = NumberSequence.new(0, 1)
			props.Acceleration = Vector3.new(0, if style == "wisp" then 1 else 3, 0)
			props.Rate = (if style == "spark" then 22 else 12) * scale
		end
		extraRate = props.Rate
		extra = emitter(root, "AuraExtra", props)
	end
	tracked[player] = { Base = base, Extra = extra, Light = light, Rate = baseRate, ExtraRate = extraRate }
end

-- uma rajada forte (renascer, evoluir, aura rara nova)
function AuraFx.Burst(player: Player, amount: number?)
	local t = tracked[player]
	if t and t.Base then
		t.Base:Emit(amount or 40)
	end
	if t and t.Extra then
		t.Extra:Emit(math.floor((amount or 40) / 2))
	end
end

function AuraFx.SetLight(on: boolean)
	AuraFx.Light = on
	for _, player in Players:GetPlayers() do
		build(player)
	end
end

local function watch(player: Player)
	local function rebuild()
		task.defer(build, player)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		rebuild()
	end)
	for _, attribute in { "AuraColor", "AuraEquip", "AuraVoid", "AuraRainbow" } do
		player:GetAttributeChangedSignal(attribute):Connect(rebuild)
	end
	if player.Character then
		rebuild()
	end
end

function AuraFx.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	-- longe da câmera, apaga (celular agradece)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local camera = workspace.CurrentCamera
			local eye = camera and camera.CFrame.Position
			for player, t in tracked do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local near = eye ~= nil and root ~= nil and (root.Position - eye).Magnitude < 140
				if t.Base then
					t.Base.Rate = if near then t.Rate else 0
				end
				if t.Extra then
					t.Extra.Rate = if near then t.ExtraRate else 0
				end
			end
		end
	end)
end

return AuraFx
