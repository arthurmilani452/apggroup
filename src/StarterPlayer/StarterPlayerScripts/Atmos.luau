--[[
	Atmos (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Parte 21: DIA/NOITE e CLIMA na tela do jogador (só no Meadow, onde ficam as bases).
	  • O relógio vem do servidor (atributos do Workspace), então todo mundo vê a mesma hora
	  • Chuva e neve: partículas só em volta da câmera (leve no celular; menos partículas com "Low graphics")
	  • Plaquinha ao lado do dinheiro: clima + hora (os ovos de clima só chocam no clima certo)
	O servidor manda: Workspace "Weather" (Sun/Rain/Snow), "DayLength", "DayFraction", "ForcedNight".
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local Atmos = {}

local C = UI.Colors
local NIGHT_AMBIENT = Color3.fromRGB(105, 110, 150) -- noite clarinha (criança precisa enxergar!)
local ICONS = { Sun = "\u{2600}\u{FE0F}", Rain = "\u{1F327}\u{FE0F}", Snow = "\u{2744}\u{FE0F}", Night = "\u{1F319}" }

-- Mesma conta do servidor (Environment.ClockAt)
local function clockAt(serverTime: number): number
	local length = tonumber(workspace:GetAttribute("DayLength")) or Config.DayLength
	local day = tonumber(workspace:GetAttribute("DayFraction")) or Config.DayFraction
	local forced = workspace:GetAttribute("ForcedNight")
	if typeof(forced) == "number" and serverTime < forced then
		return 0
	end
	local phase = (serverTime % length) / length
	if phase < day then
		return 6.5 + phase / day * 11
	end
	return (17.5 + (phase - day) / (1 - day) * 13) % 24
end

local function isNightClock(clock: number): boolean
	return clock >= 18.5 or clock < 5.5
end

local function makeEmitter(kind: string, parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = kind
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Enabled = false
	emitter.LockedToPart = false
	if kind == "Rain" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(170, 200, 255))
		emitter.Size = NumberSequence.new(0.18)
		emitter.Squash = NumberSequence.new(2.5) -- gotas compridas
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Transparency = NumberSequence.new(0.35)
		emitter.LightEmission = 0.2
		emitter.Speed = NumberRange.new(70, 85)
		emitter.Lifetime = NumberRange.new(0.8, 1)
		emitter.Rate = 450
		emitter.SpreadAngle = Vector2.new(4, 4)
	else
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		emitter.Size = NumberSequence.new(0.35, 0.5)
		emitter.Transparency = NumberSequence.new(0.1)
		emitter.LightEmission = 0.3
		emitter.Speed = NumberRange.new(6, 10)
		emitter.Lifetime = NumberRange.new(5, 7)
		emitter.Rate = 160
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.RotSpeed = NumberRange.new(-60, 60)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.Acceleration = Vector3.new(1.5, 0, 0.5) -- ventinho
	end
	emitter.Parent = parent
	return emitter
end

function Atmos.Init(ctx)
	local player = Players.LocalPlayer

	-- nuvem invisível em cima da câmera (as gotas nascem dela)
	local cloud = Instance.new("Part")
	cloud.Name = "WeatherCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.CastShadow = false
	cloud.Transparency = 1
	cloud.Size = Vector3.new(110, 1, 110)
	cloud.Parent = workspace
	local rain = makeEmitter("Rain", cloud)
	local snow = makeEmitter("Snow", cloud)

	-- plaquinha do clima (v21: primeiro item da coluna da esquerda)
	local chip = UI.create("Frame", {
		Name = "WeatherChip",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(100, 28),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		ZIndex = 30,
		Parent = ctx.leftStack or ctx.gui,
	}, { UI.corner(10), UI.border(C.Blue, 2) })
	local chipText = UI.label({ Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Text = "", ZIndex = 31, Parent = chip })
	local chipButton = UI.create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 32, Parent = chip })
	chipButton.Activated:Connect(function()
		ctx.play("Click")
		ctx.toast("Weather changes every few minutes. Storm Eggs hatch in RAIN, Snowflake Eggs in SNOW, Moon Eggs at NIGHT!", "info")
	end)

	-- efeitos das criaturas vivas
	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "Pet" and typeof(data) == "Vector3" then
			ctx.play("Coin")
			ctx.floatingText(data + Vector3.new(0, 3, 0), "\u{2665} +10%", Color3.fromRGB(255, 120, 170))
		elseif kind == "GiantTap" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				ctx.floatingText(root.Position + Vector3.new(0, 3, 0), "+1", C.Gold)
			end
			ctx.play("Click")
		elseif kind == "WorldFirst" then
			ctx.play("Shiny")
			ctx.flash(C.Gold, 0.8)
			ctx.bigText("WORLD FIRST!", C.Gold)
			Juice.Confetti(ctx.gui, 140, { C.Gold, C.White, C.Pink })
			Juice.Shake(0.8, 0.6)
		end
	end)

	local originalAmbient = Lighting.OutdoorAmbient
	local lastWeather = ""
	local lastLow: boolean? = nil
	local nextUpdate = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextUpdate then
			return
		end
		nextUpdate = now + 0.1
		local here = player:GetAttribute("World")
		local inMeadow = here == nil or here == "meadow"
		local serverTime = workspace:GetServerTimeNow()
		local clock = clockAt(serverTime)
		local night = isNightClock(clock)
		local weather = tostring(workspace:GetAttribute("Weather") or "Sun")

		if inMeadow then
			Lighting.ClockTime = clock
			-- de noite o céu fica escuro, mas o chão continua visível
			local dark = if night then 1 elseif clock > 17.5 then clock - 17.5 elseif clock < 6.5 then 6.5 - clock else 0
			Lighting.OutdoorAmbient = originalAmbient:Lerp(NIGHT_AMBIENT, math.clamp(dark, 0, 1))
		elseif Lighting.OutdoorAmbient ~= originalAmbient then
			Lighting.OutdoorAmbient = originalAmbient
		end

		-- partículas só no Meadow
		local low = player:GetAttribute("LowGfx") == true
		local camera = workspace.CurrentCamera
		if camera then
			local position = camera.CFrame.Position
			cloud.CFrame = CFrame.new(position.X, position.Y + 38, position.Z)
		end
		local key = weather .. tostring(inMeadow)
		if key ~= lastWeather or low ~= lastLow then
			lastWeather = key
			lastLow = low
			rain.Enabled = inMeadow and weather == "Rain"
			snow.Enabled = inMeadow and weather == "Snow"
			rain.Rate = if low then 140 else 450
			snow.Rate = if low then 50 else 160
		end

		-- plaquinha: ícone + hora
		local hours = math.floor(clock)
		local minutes = math.floor((clock - hours) * 60 / 10) * 10
		local icon = if weather ~= "Sun" then ICONS[weather] elseif night then ICONS.Night else ICONS.Sun
		chipText.Text = ("%s %02d:%02d"):format(icon or "", hours, minutes)
	end)
end

return Atmos
