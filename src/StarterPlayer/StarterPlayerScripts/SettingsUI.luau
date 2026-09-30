--[[
	SettingsUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Parte 17: tela "SETTINGS" e controle de videogame.
	  • Gráficos leves: desliga brilho, raios de sol, sombras e partículas (celular antigo roda melhor)
	  • Pets dos outros, números de dinheiro, volume dos sons e tremor da câmera
	  • As escolhas ficam salvas no servidor (valem em qualquer aparelho)
	  • Se o jogo ficar lento (menos de 25 FPS por 20 s), sugere ligar os gráficos leves
	  • Controle (Xbox/PlayStation): SELECT navega nos menus, B fecha a janela aberta
	Os outros scripts leem os atributos do jogador local: LowGfx, ShowOtherPets, MoneyPops, CameraShake.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent:WaitForChild("UIKit"))

local SettingsUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

local settings = { LowGfx = false, OtherPets = true, MoneyPops = true, Sfx = 1, Shake = true, Music = true }

-- v26: MÚSICA DE FUNDO (sons oficiais da Roblox, grátis). Uma lista que vai passando; volume baixo.
local MUSIC_TRACKS = {
	"rbxassetid://15675069601", -- Roblox_UI_Loop_Calm_Music
	"rbxassetid://15930255433", -- Roblox_RetroFluteMusic_01
	"rbxassetid://17422163655", -- Generic - Cloud Blitz
	"rbxassetid://130053244401794", -- TutorialMusic_01
}
local MUSIC_VOLUME = 0.18
local musicSound: Sound? = nil
local musicIndex = 0

local function nextTrack()
	if not musicSound then
		return
	end
	musicIndex = (musicIndex % #MUSIC_TRACKS) + 1
	musicSound.SoundId = MUSIC_TRACKS[musicIndex]
	musicSound:Play()
end

local function applyMusic(on: boolean)
	if on and not musicSound then
		local sound = Instance.new("Sound")
		sound.Name = "Music"
		sound.Volume = MUSIC_VOLUME
		sound.Looped = false
		sound.Parent = SoundService
		sound.Ended:Connect(function()
			if settings.Music then
				task.wait(1.5)
				nextTrack()
			end
		end)
		musicSound = sound
		musicIndex = math.random(0, #MUSIC_TRACKS - 1)
		nextTrack()
	elseif musicSound then
		if on then
			if not musicSound.IsPlaying then
				nextTrack()
			end
		else
			musicSound:Stop()
		end
	end
end

---------------------------------------------------------------------
-- Gráficos leves
---------------------------------------------------------------------
-- (tabela "fraca": peças destruídas somem daqui sozinhas, sem gastar memória)
local original: { [Instance]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any
local appliedLow: boolean? = nil
local particleConnection: RBXScriptConnection? = nil

local function remember(instance: Instance, property: string)
	original[instance] = original[instance] or {}
	if original[instance][property] == nil then
		original[instance][property] = (instance :: any)[property]
	end
end

local function setParticles(enabled: boolean, root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Sparkles") then
			if not enabled then
				remember(descendant, "Enabled")
				descendant.Enabled = false
			elseif original[descendant] and original[descendant].Enabled ~= nil then
				descendant.Enabled = original[descendant].Enabled
			end
		end
	end
end

local function applyGraphics(low: boolean)
	if appliedLow == low then
		return -- só varre o mapa quando a opção muda de verdade
	end
	appliedLow = low
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") then
			remember(effect, "Enabled")
			effect.Enabled = if low then false else original[effect].Enabled
		elseif effect:IsA("Atmosphere") then
			remember(effect, "Density")
			effect.Density = if low then original[effect].Density * 0.5 else original[effect].Density
		end
	end
	remember(Lighting, "GlobalShadows")
	Lighting.GlobalShadows = if low then false else original[Lighting].GlobalShadows
	setParticles(not low, workspace)
	if particleConnection then
		particleConnection:Disconnect()
		particleConnection = nil
	end
	if low then
		particleConnection = workspace.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("ParticleEmitter") or descendant:IsA("Sparkles") then
				remember(descendant, "Enabled")
				descendant.Enabled = false
			end
		end)
	end
end

local function applyAll()
	local player = Players.LocalPlayer
	player:SetAttribute("LowGfx", settings.LowGfx)
	player:SetAttribute("ShowOtherPets", settings.OtherPets)
	player:SetAttribute("MoneyPops", settings.MoneyPops)
	player:SetAttribute("CameraShake", settings.Shake)
	applyGraphics(settings.LowGfx)
	-- todos os sons do jogo estão no grupo SFX (inclusive o taco, que vem do servidor)
	local group = SoundService:FindFirstChild("SFX")
	if group and group:IsA("SoundGroup") then
		group.Volume = settings.Sfx
	end
	applyMusic(settings.Music)
end

function SettingsUI.Init(ctx)
	local player = Players.LocalPlayer
	local frame, content = ctx.makePanel("Settings", "SETTINGS", C.Blue)
	create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })

	local saveToken = 0
	local function save()
		saveToken += 1
		local token = saveToken
		task.delay(0.6, function()
			if token ~= saveToken then
				return
			end
			ctx.RequestEvent:FireServer("SaveSettings", settings)
			-- confere depois de 2 s: se o servidor não recebeu (pedido descartado), manda de novo
			task.delay(2, function()
				if token ~= saveToken then
					return
				end
				local ok, saved = pcall(function()
					return HttpService:JSONDecode(player:GetAttribute("Settings") or "{}")
				end)
				if ok and type(saved) == "table" then
					for key, value in settings do
						if saved[key] ~= value then
							ctx.RequestEvent:FireServer("SaveSettings", settings)
							break
						end
					end
				end
			end)
		end)
	end

	local refreshers = {}
	local function toggleRow(order: number, title: string, key: string)
		local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -12, 0, 64), BackgroundColor3 = C.Row, ZIndex = 5, Parent = content }, { corner(14) })
		label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(0.62, -14, 1, -16), Text = title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = row })
		local btn, text = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.32, 0, 0, 48),
			BackgroundColor3 = C.Green,
			ZIndex = 5,
			Parent = row,
		}, "", function()
			ctx.play("Click")
			if key == "Sfx" then
				settings.Sfx = if settings.Sfx == 1 then 0.5 elseif settings.Sfx == 0.5 then 0 else 1
			else
				settings[key] = not settings[key]
			end
			applyAll()
			for _, refresh in refreshers do
				refresh()
			end
			save()
		end)
		table.insert(refreshers, function()
			local value = settings[key]
			if key == "Sfx" then
				text.Text = if value == 1 then "100%" elseif value == 0.5 then "50%" else "OFF"
				btn.BackgroundColor3 = if value == 0 then C.Gray else C.Green
			else
				text.Text = if value then "ON" else "OFF"
				btn.BackgroundColor3 = if value then C.Green else C.Gray
			end
		end)
	end
	toggleRow(1, "Low graphics (faster on old phones)", "LowGfx")
	toggleRow(2, "Other players' pets", "OtherPets")
	toggleRow(3, "Money numbers", "MoneyPops")
	toggleRow(4, "Sound effects", "Sfx")
	toggleRow(5, "Camera shake", "Shake")
	toggleRow(6, "Music", "Music")
	for order, text in { "Saved on every device you play on.", "Language: Roblox uses your account language by itself.", "Controller: press SELECT for the menus and B to close." } do
		label({
			LayoutOrder = 10 + order,
			Size = UDim2.new(1, -12, 0, 28),
			Text = text,
			TextColor3 = Color3.fromRGB(200, 215, 240),
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = content,
		})
	end
	local function refreshAll()
		for _, refresh in refreshers do
			refresh()
		end
	end

	-- configurações salvas (o servidor manda no atributo "Settings")
	local loadedOnce = false
	local function loadSaved()
		-- só a primeira vez: depois disso quem manda é o que o jogador escolhe nesta tela
		if loadedOnce then
			return
		end
		local raw = player:GetAttribute("Settings")
		if typeof(raw) ~= "string" then
			return
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(decoded) == "table" then
			loadedOnce = true
			for key, default in settings do
				local value = decoded[key]
				if type(value) == type(default) then
					settings[key] = value
				end
			end
			applyAll()
			refreshAll()
		end
	end
	loadSaved()
	player:GetAttributeChangedSignal("Settings"):Connect(loadSaved)
	applyAll()
	refreshAll()

	-- jogo lento: sugere os gráficos leves (1 vez por sessão)
	task.spawn(function()
		local frames, elapsed, slowFor, suggested = 0, 0, 0, false
		RunService.Heartbeat:Connect(function(dt)
			frames += 1
			elapsed += dt
			if elapsed >= 2 then
				local fps = frames / elapsed
				frames, elapsed = 0, 0
				slowFor = if fps < 25 then slowFor + 2 else 0
				if slowFor >= 20 and not suggested and not settings.LowGfx then
					suggested = true
					ctx.toast("Game running slow? Turn on LOW GRAPHICS in SETTINGS!", "warning")
				end
			end
		end)
	end)

	-- Controle: B fecha a janela aberta; dica "SELECT = menus"
	local hint = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -8), -- v21: canto de baixo (o menu subiu)
		Size = UDim2.fromOffset(200, 26),
		Text = "SELECT = menus",
		TextColor3 = C.Gold,
		Visible = UserInputService.GamepadEnabled,
		Parent = ctx.gui,
	})
	UserInputService.GamepadConnected:Connect(function()
		hint.Visible = true
	end)
	UserInputService.GamepadDisconnected:Connect(function()
		hint.Visible = UserInputService.GamepadEnabled
	end)
	ContextActionService:BindAction("CloseWindow", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local dialog = ctx.gui:FindFirstChild("ConfirmDialog")
		if dialog then
			dialog:Destroy() -- fecha primeiro a caixa "tem certeza?"
			GuiService.SelectedObject = nil
			return Enum.ContextActionResult.Sink
		end
		for _, panel in ctx.panels do
			if panel.Visible then
				panel.Visible = false
				GuiService.SelectedObject = nil
				ctx.play("Click")
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)

	ctx.panelOpened.Settings = refreshAll
	return frame
end

return SettingsUI
