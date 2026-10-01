--[[
	ClientMain (LocalScript em StarterPlayer > StarterPlayerScripts)
	Tudo o que aparece na tela do jogador: dinheiro, loja, índice, rebirth, códigos, convite,
	eventos, tutorial, ovo chocando (com suspense), esteira de treino, avisos, sons e efeitos.
	A tela só PEDE coisas ao servidor; quem decide é sempre o servidor.
	Textos em inglês; o Roblox traduz sozinho para quem joga em português.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local IS_STUDIO = RunService:IsStudio()

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Critters = require(Shared:WaitForChild("Critters"))
local Format = require(Shared:WaitForChild("Format"))
local Builder = require(Shared:WaitForChild("CritterBuilder"))

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local NotifyEvent = RemotesFolder:WaitForChild("Notify") :: RemoteEvent
local PopupEvent = RemotesFolder:WaitForChild("Popup") :: RemoteEvent
local KnockbackEvent = RemotesFolder:WaitForChild("Knockback") :: RemoteEvent
local EffectEvent = RemotesFolder:WaitForChild("Effect") :: RemoteEvent
local IndexEvent = RemotesFolder:WaitForChild("IndexSync") :: RemoteEvent
local RequestEvent = RemotesFolder:WaitForChild("Request") :: RemoteEvent

---------------------------------------------------------------------
-- Estilo: tudo vem do kit de UI (UIKit) e dos efeitos (Juice), ao lado deste script
---------------------------------------------------------------------
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))
local FONT = UI.Font
local COLORS = UI.Colors
local WHITE, DARK, PANEL, ROW = COLORS.White, COLORS.Dark, COLORS.Panel, COLORS.Row
local GREEN, BLUE, PURPLE, RED = COLORS.Green, COLORS.Blue, COLORS.Purple, COLORS.Red
local GOLD, ORANGE, GRAY = COLORS.Gold, COLORS.Orange, COLORS.Gray

local KIND_COLORS = {
	success = Color3.fromRGB(50, 175, 80),
	error = Color3.fromRGB(215, 55, 60),
	warning = Color3.fromRGB(235, 140, 30),
	rare = Color3.fromRGB(150, 70, 240),
	info = Color3.fromRGB(55, 120, 220),
}

local create, corner, border, shine, label, button = UI.create, UI.corner, UI.border, UI.shine, UI.label, UI.button

---------------------------------------------------------------------
-- Escala para celular / PC
---------------------------------------------------------------------
local scales: { UIScale } = {}
local function autoScale(guiObject: GuiObject, multiplier: number?)
	local scale = Instance.new("UIScale")
	scale:SetAttribute("Mul", multiplier or 1) -- v22: a coluna da esquerda é um pouco menor que o resto
	scale.Parent = guiObject
	table.insert(scales, scale)
end

local function updateScales()
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local value = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.25)
	for _, scale in scales do
		local final = value * (tonumber(scale:GetAttribute("Mul")) or 1)
		scale.Scale = final
		scale:SetAttribute("Base", final) -- UIKit.popIn anima a partir deste tamanho
	end
end

---------------------------------------------------------------------
-- Sons (troque os IDs em Config.Sounds)
---------------------------------------------------------------------
local sounds: { [string]: Sound } = {}
for name, info in Config.Sounds do
	sounds[name] = create("Sound", {
		Name = name,
		SoundId = info.Id,
		Volume = info.Volume,
		PlaybackSpeed = info.Speed,
		SoundGroup = SoundService:FindFirstChild("SFX") :: SoundGroup?, -- volume controlado em SETTINGS
		Parent = SoundService,
	})
end

local function play(name: string)
	local sound = sounds[name]
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

---------------------------------------------------------------------
-- Tela principal
---------------------------------------------------------------------
-- v21: a tela ignora a barra do Roblox (IgnoreGuiInset): o dinheiro fica coladinho no topo, no meio
-- da barra (que é transparente ali); o resto da tela desce a altura da barra (TOP_INSET) para não
-- ficar embaixo dos botões do Roblox (menu/chat, à esquerda).
local gui = create("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})
-- a barra nova do Roblox tem ~58 px (o GetGuiInset às vezes ainda diz 36): usa o maior
local TOP_INSET = math.max(58, game:GetService("GuiService"):GetGuiInset().Y)

-- (o chat do Roblox fica no canto de BAIXO, à esquerda: configurado no lugar e no servidor, v21)

-- Dinheiro (topo, bem pequeno: só o valor e a renda)
local cashPanel = create("Frame", {
	Name = "CashPanel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 3),
	Size = UDim2.fromOffset(236, 52),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
	Parent = gui,
}, { corner(16), border(GOLD, 2.5) })
autoScale(cashPanel)

local cashLabel = label({
	Size = UDim2.new(1, -16, 0.58, 0),
	Position = UDim2.new(0, 8, 0, 2),
	Text = "$0",
	TextColor3 = Color3.fromRGB(120, 255, 120),
	StrokeThickness = 2.5,
	Parent = cashPanel,
})
local incomeLabel = label({
	Size = UDim2.new(1, -16, 0.34, 0),
	Position = UDim2.new(0, 8, 0.6, 0),
	Text = "+$0/s",
	TextColor3 = Color3.fromRGB(255, 230, 120),
	Parent = cashPanel,
})

---------------------------------------------------------------------
-- v21: COLUNA DA ESQUERDA. Todos os avisos, faixas e contagens ficam empilhados no canto de cima,
-- à esquerda (nada grande no meio da tela). Cada item entra aqui com um LayoutOrder:
--   0 shout (avisos grandes)  5 clima  10 comunidade  15 contagem de eventos  20 RIDE  25 objetivo
--   30 evento acontecendo  35 carregando  40 votação  45 invasão  50 ilha  55 vingança
--   60 minigame  70 toasts
-- A coluna inteira tem UM UIScale (os itens NÃO devem ter o seu, senão encolhem duas vezes).
---------------------------------------------------------------------
local STACK_W = 260 -- largura padrão dos itens da coluna (v22: menor)
-- (a janela do chat do Roblox foi para o canto de BAIXO, à esquerda — TextChatService, v21 —
-- então o canto de cima é todo da coluna)
local STACK_Y = TOP_INSET + 4
local leftStack = create("Frame", {
	Name = "LeftStack",
	Position = UDim2.new(0, 8, 0, STACK_Y),
	Size = UDim2.fromOffset(STACK_W + 10, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	ZIndex = 30, -- por cima das janelas (ex.: batalha)
	Parent = gui,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 5),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
autoScale(leftStack, 0.9) -- v22: a coluna toda fica 10% menor que o resto da tela

-- Contagem dos eventos (chip pequeno)
local eventStrip = create("Frame", {
	Name = "EventStrip",
	LayoutOrder = 15,
	Size = UDim2.fromOffset(STACK_W, 24),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.35,
	ZIndex = 30,
	Parent = leftStack,
}, { corner(9) })
local eventText = label({ Size = UDim2.new(1, -12, 1, -4), Position = UDim2.fromOffset(6, 2), Text = "", TextColor3 = Color3.fromRGB(200, 230, 255), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = eventStrip })

-- Faixas (evento acontecendo / carregando bichinho): pequenas, na coluna da esquerda
local function banner(order: number, color: Color3): (Frame, TextLabel)
	local frame = create("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(STACK_W, 30),
		BackgroundColor3 = color,
		Visible = false,
		ZIndex = 30,
		Parent = leftStack,
	}, { corner(10), border(DARK, 2), shine() })
	local text = label({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = frame })
	return frame, text
end

local eventBanner, eventBannerText = banner(30, Color3.fromRGB(40, 170, 90))
local carryBanner, carryText = banner(35, ORANGE)
-- v23: trava da base com contagem (segundos trancada / recarga), com barrinha que esvazia
local lockBar = create("Frame", {
	Name = "LockBar",
	LayoutOrder = 28,
	Size = UDim2.fromOffset(STACK_W, 30),
	BackgroundColor3 = Color3.fromRGB(215, 60, 70),
	Visible = false,
	ZIndex = 30,
	Parent = leftStack,
}, { corner(10), border(DARK, 2) })
local lockFill = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.75,
	BorderSizePixel = 0,
	ZIndex = 30,
	Parent = lockBar,
}, { corner(10) })
local lockText = label({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = lockBar })

-- Avisos (toasts): cards pequenos no fim da coluna
local toastHolder = create("Frame", {
	Name = "ToastHolder",
	LayoutOrder = 70,
	Size = UDim2.fromOffset(STACK_W, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	ZIndex = 30,
	Parent = leftStack,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 5),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local MAX_TOASTS = 3
local toastCount = 0
local function toast(text: string, kind: string?)
	toastCount += 1
	local color = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	local frame = create("Frame", {
		LayoutOrder = toastCount,
		Size = UDim2.fromOffset(STACK_W, 30),
		BackgroundColor3 = color,
		ZIndex = 30,
		Parent = toastHolder,
	}, { corner(9), border(DARK, 2) })
	local textLabel = label({ Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = frame })
	UI.popIn(frame)

	local frames = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > MAX_TOASTS then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #frames - MAX_TOASTS do
			frames[i]:Destroy()
		end
	end

	task.delay(3.5, function()
		if not frame.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(textLabel, info, { TextTransparency = 1 }):Play()
		task.wait(0.45)
		frame:Destroy()
	end)
end

---------------------------------------------------------------------
-- Janelas (loja, índice, rebirth, admin)
---------------------------------------------------------------------
local panels: { [string]: Frame } = {}
local panelOpened: { [string]: () -> () } = {}

local function openPanel(name: string)
	play("Click")
	for panelName, frame in panels do
		if panelName == name then
			frame.Visible = not frame.Visible
			if frame.Visible then
				UI.popIn(frame)
				if panelOpened[panelName] then
					panelOpened[panelName]()
				end
				-- controle de videogame: já seleciona o primeiro botão da janela
				if UserInputService:GetLastInputType().Name:find("Gamepad") then
					task.defer(function()
						for _, descendant in frame:GetDescendants() do
							if descendant:IsA("GuiButton") and descendant.Visible then
								game:GetService("GuiService").SelectedObject = descendant
								break
							end
						end
					end)
				end
			end
		else
			frame.Visible = false
		end
	end
end

local function makePanel(name: string, title: string, color: Color3): (Frame, ScrollingFrame)
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(640, 460),
		BackgroundColor3 = PANEL,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}, { corner(20), border(color, 4) })
	autoScale(frame)
	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = color,
		ZIndex = 5,
		Parent = frame,
	}, { corner(18), shine() })
	label({ Size = UDim2.new(1, -120, 1, -12), Position = UDim2.fromOffset(20, 6), Text = title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = header })
	button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 7),
		Size = UDim2.fromOffset(46, 44),
		BackgroundColor3 = RED,
		ZIndex = 6,
		Parent = header,
	}, "X", function()
		frame.Visible = false
		play("Click")
	end)
	local content = create("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 1, -84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 5,
		Parent = frame,
	})
	panels[name] = frame
	return frame, content
end

-- Botões do lado direito (longe do joystick do celular), em grade de 2 colunas
-- v20: botões ~20% menores e mais encostados na borda, para cobrir menos o jogo
-- v22: colados no CANTO de cima, à direita, em 2 colunas INTERCALADAS (a coluna de dentro fica meio
-- degrau abaixo, tipo favo de mel) e um pouco menores. A lista de jogadores do Roblox fica escondida
-- para não cobrir os botões (dá para ligar de novo em StarterGui:SetCoreGuiEnabled).
local MENU_CELL = Vector2.new(76, 50)
local MENU_GAP = 5
local menu = create("Frame", {
	Name = "Menu",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -4, 0, TOP_INSET + 4),
	Size = UDim2.fromOffset(MENU_CELL.X * 2 + MENU_GAP, 400),
	BackgroundTransparency = 1,
	Parent = gui,
})
autoScale(menu)
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- Arruma os botões visíveis em zigue-zague (menuColumns = 2 no PC, 3 no celular deitado)
local menuColumns = 2
local function layoutMenu()
	local buttons = {}
	for _, child in menu:GetChildren() do
		if child:IsA("GuiButton") and child.Visible then
			table.insert(buttons, child)
		end
	end
	table.sort(buttons, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	local stepX = MENU_CELL.X + MENU_GAP
	local stepY = MENU_CELL.Y + MENU_GAP
	local rows = 0
	for i, btn in buttons do
		local col = (i - 1) % menuColumns
		local row = math.floor((i - 1) / menuColumns)
		rows = math.max(rows, row + 1)
		btn.AnchorPoint = Vector2.new(1, 0)
		btn.Position = UDim2.new(1, -col * stepX, 0, row * stepY + (if col % 2 == 1 then stepY / 2 else 0))
	end
	menu.Size = UDim2.fromOffset(stepX * menuColumns - MENU_GAP, rows * stepY + stepY / 2)
end

-- Botões com ícone grande (emoji) em cima e o nome embaixo
local function menuButton(order: number, icon: string, text: string, color: Color3, onClick: () -> ()): TextButton
	local btn = UI.iconButton({
		LayoutOrder = order,
		Size = UDim2.fromOffset(MENU_CELL.X, MENU_CELL.Y),
		BackgroundColor3 = color,
		Parent = menu,
	}, icon, text, onClick)
	btn:GetPropertyChangedSignal("Visible"):Connect(layoutMenu)
	layoutMenu()
	return btn
end

menuButton(0, "\u{1F3C6}", "PASS", GOLD, function()
	openPanel("Pass")
end)
menuButton(1, "\u{1F6D2}", "SHOP", GREEN, function()
	openPanel("Shop")
end)
menuButton(2, "\u{1F43E}", "CRITTERS", COLORS.Teal, function()
	openPanel("Critters")
end)
menuButton(3, "\u{1F4D6}", "INDEX", BLUE, function()
	openPanel("Index")
end)
menuButton(4, "\u{1F3A8}", "STYLE", COLORS.Pink, function()
	openPanel("Style")
end)
menuButton(5, "\u{1F501}", "REBIRTH", PURPLE, function()
	openPanel("Rebirth")
end)
menuButton(6, "\u{1F30D}", "WORLDS", Color3.fromRGB(255, 150, 60), function()
	openPanel("Worlds")
end)
menuButton(7, "\u{1F381}", "CODES", Color3.fromRGB(255, 110, 140), function()
	openPanel("Codes")
end)

-- Convidar amigos (amigo no servidor = +10% de dinheiro)
local function inviteFriends()
	play("Click")
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and canInvite then
		pcall(function()
			-- quem entrar pelo convite leva o seu UserId: amigo NOVO = ovo grátis para você (v11)
			local options = Instance.new("ExperienceInviteOptions")
			options.LaunchData = "inv:" .. player.UserId
			options.PromptMessage = "Invite friends: you get a FREE egg for each new friend who joins!"
			SocialService:PromptGameInvite(player, options)
		end)
	else
		toast(if IS_STUDIO then "Invites only work in the published game." else "Invites are not available right now.", "warning")
	end
end
menuButton(8, "\u{1F44B}", "INVITE", Color3.fromRGB(60, 170, 230), inviteFriends)

-- Voltar para a base (só aparece quando você está em outro mundo)
local homeButton = menuButton(9, "\u{1F3E0}", "HOME", Color3.fromRGB(90, 200, 110), function()
	play("Click")
	RequestEvent:FireServer("TravelWorld", "meadow")
end)
homeButton.Visible = false

menuButton(12, "\u{2699}", "SETTINGS", COLORS.Gray, function()
	openPanel("Settings")
end)
local adminButton = menuButton(10, "\u{1F6E0}", "ADMIN", RED, function()
	openPanel("Admin")
end)
adminButton.Visible = false
local instantLockButton = menuButton(11, "\u{1F512}", "INSTANT LOCK", ORANGE, function()
	local id = Config.DevProducts.InstantLock
	if id and id > 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	else
		toast("Put the Instant Lock product ID in Config.DevProducts", "warning")
	end
end)
instantLockButton.Visible = false

---------------------------------------------------------------------
-- LOJA
---------------------------------------------------------------------
local shopFrame, shopContent = makePanel("Shop", "SHOP", GREEN)
create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = shopContent })

local shopOrder = 0
local function nextOrder(): number
	shopOrder += 1
	return shopOrder
end

local function sectionTitle(text: string, color: Color3)
	label({ LayoutOrder = nextOrder(), Size = UDim2.new(1, -12, 0, 34), Text = text, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = shopContent })
end

-- v23: foto 3D do bichinho/ovo na linha da loja (ViewportFrame girando devagar enquanto a loja está aberta)
-- (bloco "do" para não estourar o limite de 200 locals do script)
local shopRow
do
local shopPictures: { { Camera: Camera, Center: Vector3, Radius: number, Angle: number } } = {}
local function rowPicture(row: Frame, model: Model, tint: Color3?)
	local viewport = create("ViewportFrame", {
		Size = UDim2.fromOffset(66, 66),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = (tint or WHITE):Lerp(Color3.fromRGB(20, 20, 35), 0.75),
		BackgroundTransparency = 0.1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = WHITE,
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		ZIndex = 6,
		Parent = row,
	}, { corner(12) })
	local aura = model:FindFirstChild("Aura")
	if aura then
		aura:Destroy()
	end
	model:PivotTo(CFrame.identity)
	model.Parent = viewport
	local boxCFrame, boxSize = model:GetBoundingBox()
	local radius = boxSize.Magnitude / 2
	local center = boxCFrame.Position
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(center + Vector3.new(radius * 0.7, radius * 0.5, -radius * 1.75), center)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	table.insert(shopPictures, { Camera = camera, Center = center, Radius = radius, Angle = math.random() * math.pi * 2 })
end

RunService.Heartbeat:Connect(function(dt)
	if not shopFrame.Visible or #shopPictures == 0 then
		return
	end
	for _, pic in shopPictures do
		pic.Angle += dt * 0.8
		local offset = CFrame.Angles(0, pic.Angle, 0) * Vector3.new(0, pic.Radius * 0.5, -pic.Radius * 1.75)
		pic.Camera.CFrame = CFrame.lookAt(pic.Center + offset, pic.Center)
	end
end)

function shopRow(title: string, subtitle: string, buttonText: string, color: Color3, onClick: () -> (), titleColor: Color3?, picture: Model?)
	local row = create("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -12, 0, 78),
		BackgroundColor3 = ROW,
		ZIndex = 5,
		Parent = shopContent,
	}, { corner(14) })
	local textX = 14
	if picture then
		rowPicture(row, picture, titleColor)
		textX = 80
	end
	local titleLabel = label({ Size = UDim2.new(0.62, -textX - 2, 0, 36), Position = UDim2.fromOffset(textX, 6), Text = title, TextColor3 = titleColor or WHITE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = row })
	local subLabel = label({
		Size = UDim2.new(0.62, -textX - 2, 0, 26),
		Position = UDim2.fromOffset(textX, 44),
		Text = subtitle,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 220),
		StrokeThickness = 1,
		ZIndex = 5,
		Parent = row,
	})
	local btn, btnText = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0.36, 0, 0, 54),
		BackgroundColor3 = color,
		ZIndex = 5,
		Parent = row,
	}, buttonText, onClick)
	return { Frame = row, Title = titleLabel, Sub = subLabel, Button = btn, ButtonText = btnText, Color = color }
end
end

local function robuxPrice(row, id: number, infoType: Enum.InfoType)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info and info.PriceInRobux and row.ButtonText.Text ~= "OWNED" then
			row.ButtonText.Text = "R$ " .. info.PriceInRobux
		end
	end)
end

-- Upgrades
sectionTitle("UPGRADES", GREEN)
local speedRow = shopRow("Speed", "+" .. Config.SpeedPerLevel .. " walk speed", "$0", GREEN, function()
	RequestEvent:FireServer("BuySpeed")
end)
local slotRow = shopRow("Base Slots", "+1 pedestal for your base", "$0", GREEN, function()
	RequestEvent:FireServer("BuySlot")
end)
shopRow("Treadmill", "Run on the treadmill in your base: FREE speed!", "HOW?", BLUE, function()
	toast("Go to the back of YOUR base and run on the treadmill!", "info")
end)

-- Game Passes
local passRows = {}
local anyPass = false
for _, name in Config.GamePassOrder do
	local id = Config.GamePasses[name] or 0
	if id > 0 or IS_STUDIO then
		if not anyPass then
			sectionTitle("GAME PASSES (forever)", GOLD)
			anyPass = true
		end
		local info = Config.GamePassInfo[name] or { Name = name, Description = "" }
		local row = shopRow(info.Name, info.Description, if id > 0 then "BUY" else "SET ID", if id > 0 then GOLD else GRAY, function()
			if player:GetAttribute("Pass_" .. name) then
				return
			end
			if name == "MoreSlots" and (player:GetAttribute("Slots") or 0) >= Config.MaxSlots then
				toast("Your base already has the MAX slots!", "info")
				return
			end
			if id > 0 then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				toast("Studio: put this Game Pass ID in Config.GamePasses." .. name, "warning")
			end
		end, GOLD)
		passRows[name] = row
		if id > 0 then
			robuxPrice(row, id, Enum.InfoType.GamePass)
		end
	end
end

-- Dev Products
local function productButton(id: number, fallbackText: string): (string, Color3)
	if id > 0 then
		return fallbackText, ORANGE
	end
	return "SET ID", GRAY
end

local function promptProduct(id: number, configName: string)
	if id > 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	else
		toast("Studio: put this product ID in Config (" .. configName .. ")", "warning")
	end
end

local cashRows = {}
local anyProduct = false
local function productSection()
	if not anyProduct then
		sectionTitle("SPECIAL OFFERS", ORANGE)
		anyProduct = true
	end
end

do
	local id = Config.DevProducts.InstantLock or 0
	if id > 0 or IS_STUDIO then
		productSection()
		local text, color = productButton(id, "BUY")
		local row = shopRow("Instant Lock", "Lock your base NOW, even while it recharges!", text, color, function()
			promptProduct(id, "DevProducts.InstantLock")
		end)
		if id > 0 then
			robuxPrice(row, id, Enum.InfoType.Product)
		end
	end
	for _, packName in Config.CashPackOrder do
		local pack = Config.CashPacks[packName]
		local packId = Config.DevProducts[packName] or 0
		if pack and (packId > 0 or IS_STUDIO) then
			productSection()
			local text, color = productButton(packId, "BUY")
			local row = shopRow(pack.Name, "", text, color, function()
				-- o servidor confere as regras do país e abre a compra
				RequestEvent:FireServer("PromptProduct", packName)
			end, Color3.fromRGB(120, 255, 120))
			cashRows[packName] = row
			if packId > 0 then
				robuxPrice(row, packId, Enum.InfoType.Product)
			end
		end
	end
end

-- v20: mais ofertas (o servidor confere se pode comprar e abre a janela do Roblox)
local starterRow
do
	local extras = {
		{ "StarterPack", Color3.fromRGB(255, 215, 90) },
		{ "Boost30", Color3.fromRGB(120, 255, 120) },
		{ "LuckyPotion", Color3.fromRGB(120, 255, 200) },
		{ "BaseShield", Color3.fromRGB(150, 210, 255) },
		{ "InstantHatch", Color3.fromRGB(255, 200, 120) },
	}
	for _, entry in extras do
		local key, titleColor = entry[1], entry[2]
		local id = Config.DevProducts[key] or 0
		local info = Config.ProductInfo[key]
		if info and (id > 0 or IS_STUDIO) then
			productSection()
			local text, color = productButton(id, "BUY")
			-- v23: foto do ovo nas ofertas que dão/chocam ovos
			local picture: Model? = nil
			local eggId = if key == "StarterPack" then Config.StarterPack.Egg elseif key == "InstantHatch" then "grass" else nil
			local eggDef = eggId and Config.EggById[eggId]
			if eggDef then
				picture = (Builder.BuildEgg(eggDef))
			end
			local row = shopRow(info.Name, info.Description, text, color, function()
				if id > 0 then
					RequestEvent:FireServer("PromptProduct", key)
				else
					toast("Studio: put this product ID in Config (DevProducts." .. key .. ")", "warning")
				end
			end, titleColor, picture)
			if key == "StarterPack" then
				starterRow = row
			end
			if id > 0 then
				robuxPrice(row, id, Enum.InfoType.Product)
			end
		end
	end
end

-- Critters por Robux (o jogador escolhe)
local anyCritter = false
for _, def in Critters.List do
	local id = Config.CritterProducts[def.Id]
	if id ~= nil and (id > 0 or IS_STUDIO) then
		if not anyCritter then
			sectionTitle("GET A CRITTER (you choose!)", Color3.fromRGB(255, 120, 200))
			anyCritter = true
		end
		local rarity = Config.RarityByName[def.Rarity]
		local text, color = productButton(id, "BUY")
		-- v23: o bichinho aparece em 3D na linha (era só texto e o pessoal não sabia o que estava comprando)
		local picture = (Builder.Build(def))
		local row = shopRow(def.Name .. " (" .. def.Rarity .. ")", Format.Money(def.Income) .. "/s in your base", text, color, function()
			if (player:GetAttribute("FreeSlots") or 1) <= 0 then
				toast("Your base is full! It will wait until you make space.", "warning")
			end
			promptProduct(id, "CritterProducts." .. def.Id)
		end, rarity.Color, picture)
		if id > 0 then
			robuxPrice(row, id, Enum.InfoType.Product)
		end
	end
end

-- Grupo do jogo: entrar é GRÁTIS e dá +10% de dinheiro (Config.GroupId = 0 desliga)
-- O botão abre o convite do Roblox; depois o SERVIDOR confere e liga o bônus.
local groupRow = if Config.GroupId > 0
	then shopRow("Join our Group - FREE!", ("+%d%% cash forever (Critter Club Studios)"):format(math.floor(Config.GroupBonus * 100)), "JOIN", BLUE, function()
		if player:GetAttribute("GroupBonus") then
			toast("You are in the group. Thank you!", "success")
			return
		end
		local ok, status = pcall(function()
			return game:GetService("GroupService"):PromptJoinAsync(Config.GroupId)
		end)
		if ok and status == Enum.GroupMembershipStatus.JoinRequestPending then
			toast("Join request sent!", "info")
		elseif not ok then
			toast("Search \"Critter Club Studios\" in Communities and join!", "info")
		end
		RequestEvent:FireServer("CheckGroup")
	end, Color3.fromRGB(150, 210, 255))
	else nil

-- Roblox Premium: +10% de dinheiro e o título "Premium" (Config.PremiumBonus = 0 desliga)
local premiumRow = if Config.PremiumBonus > 0
	then shopRow("Roblox Premium", ("+%d%% cash and the Premium title"):format(math.floor(Config.PremiumBonus * 100)), "GET", Color3.fromRGB(95, 95, 120), function()
		if player.MembershipType == Enum.MembershipType.Premium then
			toast("Your Premium bonus is active. Thank you!", "success")
			return
		end
		pcall(function()
			MarketplaceService:PromptPremiumPurchase(player)
		end)
	end, Color3.fromRGB(235, 235, 255))
	else nil

local bonusLabel = label({
	LayoutOrder = 1000,
	Size = UDim2.new(1, -12, 0, 60),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 230, 140),
	ZIndex = 5,
	Parent = shopContent,
})

local function currentSpeed(): number
	local level = player:GetAttribute("SpeedLevel") or 0
	local trained = math.min(player:GetAttribute("TrainedSpeed") or 0, player:GetAttribute("TrainCap") or 0)
	local speed = Config.BaseWalkSpeed + level * Config.SpeedPerLevel + trained
	if player:GetAttribute("Pass_SpeedCoil") then
		speed += Config.SpeedCoilBonus
	end
	return speed
end

local function refreshShop()
	local level = player:GetAttribute("SpeedLevel") or 0
	speedRow.Title.Text = "Speed: " .. currentSpeed()
	speedRow.Sub.Text = ("+%d walk speed  (treadmill: +%d/%d)"):format(
		Config.SpeedPerLevel,
		player:GetAttribute("TrainedSpeed") or 0,
		player:GetAttribute("TrainCap") or Config.TreadmillBaseCap
	)
	local slots = player:GetAttribute("Slots") or Config.StartSlots
	local bought = player:GetAttribute("SlotUpgrades") or 0
	local slotCost = Config.SlotUpgradeCosts[bought + 1]
	slotRow.Title.Text = ("Base Slots: %d/%d"):format(slots, Config.MaxSlots)
	if not slotCost or slots >= Config.MaxSlots then
		slotRow.ButtonText.Text = "MAX"
		slotRow.Button.BackgroundColor3 = GRAY
		slotRow.Sub.Text = if slots >= Config.MaxSlots then "Your base is FULL size!" else "Rebirth for more slots!"
	else
		slotRow.ButtonText.Text = Format.Money(slotCost)
		slotRow.Button.BackgroundColor3 = if (player:GetAttribute("Cash") or 0) >= slotCost then GREEN else GRAY
		slotRow.Sub.Text = if slots == Config.FloorSlots
			then "+1 pedestal: unlocks the 2ND FLOOR!"
			else ("+1 pedestal (%d/%d upgrades)"):format(bought, #Config.SlotUpgradeCosts)
	end
	if level >= Config.MaxSpeedLevel then
		speedRow.ButtonText.Text = "MAX"
		speedRow.Button.BackgroundColor3 = GRAY
	else
		speedRow.ButtonText.Text = Format.Money(Config.SpeedCost(level))
		local cash = player:GetAttribute("Cash") or 0
		speedRow.Button.BackgroundColor3 = if cash >= Config.SpeedCost(level) then GREEN else GRAY
	end
	for name, row in passRows do
		if player:GetAttribute("Pass_" .. name) then
			row.ButtonText.Text = "OWNED"
			row.Button.BackgroundColor3 = GRAY
		elseif name == "MoreSlots" then
			-- o pass nunca passa do máximo de vagas: mostra quanto ele dá AGORA
			local gain = math.max(0, math.min(Config.PassSlots, Config.MaxSlots - slots))
			if gain <= 0 then
				row.ButtonText.Text = "MAXED"
				row.Button.BackgroundColor3 = GRAY
				row.Sub.Text = "Your base already has the MAX slots!"
			else
				row.Sub.Text = ("+%d pedestals in your base right now!"):format(gain)
			end
		end
	end
	local income = player:GetAttribute("Income") or 0
	-- regras do país (PolicyService): onde itens aleatórios pagos são proibidos, não vende Cash Pack
	-- (dinheiro comprado com Robux viraria ovos aleatórios)
	local randomRestricted = player:GetAttribute("PolicyRandomRestricted") ~= false
	for packName, row in cashRows do
		local pack = Config.CashPacks[packName]
		row.Frame.Visible = not randomRestricted -- (v20: antes mexia numa tabela, não no quadro)
		row.Sub.Text = "Get " .. Format.Money(math.max(pack.Minimum, income * 60 * pack.Minutes)) .. " right now!"
	end
	if starterRow then
		-- tem um ovo aleatório dentro: some onde isso é proibido; e some depois de comprado
		starterRow.Frame.Visible = not randomRestricted and player:GetAttribute("StarterPack") ~= true
	end
	local rebirths = player:GetAttribute("Rebirths") or 0
	local indexCount = player:GetAttribute("IndexCount") or 0
	local friends = player:GetAttribute("FriendBonus") or 0
	local parts = {
		("Rebirth x%g"):format(1 + rebirths * Config.RebirthIncomeBonus),
		("Index +%d%%"):format(math.floor(indexCount * Config.IndexBonusPerCritter * 100 + 0.5)),
		("Friends +%d%%"):format(math.floor(friends * 100 + 0.5)),
	}
	local prestige = tonumber(player:GetAttribute("Prestige")) or 0
	if prestige > 0 then
		table.insert(parts, 2, ("Prestige x%g"):format(1 + prestige))
	end
	if Config.GroupId > 0 then
		if player:GetAttribute("GroupBonus") then
			table.insert(parts, ("Group +%d%%"):format(math.floor(Config.GroupBonus * 100)))
		else
			table.insert(parts, ("Join our group: +%d%%!"):format(math.floor(Config.GroupBonus * 100)))
		end
	end
	if player:GetAttribute("Pass_VIP") then
		table.insert(parts, ("VIP +%d%%"):format(math.floor(Config.VipIncomeBonus * 100)))
	end
	if player:GetAttribute("Pass_DoubleCash") then
		table.insert(parts, "2x Cash")
	end
	if player:GetAttribute("Underdog") then
		table.insert(parts, ("Underdog +%d%%"):format(math.floor(Config.UnderdogBonus * 100)))
	end
	local petBonus = tonumber(player:GetAttribute("PetBonus")) or 0
	if petBonus > 0 then
		table.insert(parts, ("Pets +%d%%"):format(math.floor(petBonus * 100 + 0.5)))
	end
	if player.MembershipType == Enum.MembershipType.Premium and Config.PremiumBonus > 0 then
		table.insert(parts, ("Premium +%d%%"):format(math.floor(Config.PremiumBonus * 100)))
	end
	local boostLeft = math.floor((tonumber(player:GetAttribute("BoostUntil")) or 0) - workspace:GetServerTimeNow())
	if boostLeft > 0 then
		table.insert(parts, "2x Boost " .. Format.Time(boostLeft))
	end
	if groupRow then
		local joined = player:GetAttribute("GroupBonus") == true
		groupRow.ButtonText.Text = if joined then "JOINED" else "JOIN"
		groupRow.Button.BackgroundColor3 = if joined then GREEN else BLUE
	end
	if premiumRow then
		local active = player.MembershipType == Enum.MembershipType.Premium
		premiumRow.ButtonText.Text = if active then "ACTIVE" else "GET"
		premiumRow.Button.BackgroundColor3 = if active then GREEN else Color3.fromRGB(95, 95, 120)
	end
	bonusLabel.Text = "Your bonuses: " .. table.concat(parts, "  |  ") .. "\nPlay with friends for more cash!"
end
panelOpened.Shop = refreshShop
player:GetAttributeChangedSignal("PolicyRandomRestricted"):Connect(refreshShop)
player:GetAttributeChangedSignal("StarterPack"):Connect(refreshShop)

---------------------------------------------------------------------
-- ÍNDICE (coleção)
---------------------------------------------------------------------
local _, indexContent = makePanel("Index", "INDEX", BLUE)
local discovered: { [string]: boolean } = {}
local indexCards = {}
local eggRows: { { Frame: Frame, World: string } } = {}
local builtWorlds: { [string]: boolean } = {}
local indexWorld = "meadow"
local indexBuilt = false

local indexTitle = label({
	LayoutOrder = -1,
	Size = UDim2.new(1, -12, 0, 30),
	Text = "",
	TextColor3 = Color3.fromRGB(180, 220, 255),
	ZIndex = 5,
	Parent = indexContent,
})
-- Abas: um botão por mundo
local indexTabs = create("Frame", {
	LayoutOrder = 0,
	Size = UDim2.new(1, -12, 0, 40),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = indexContent,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local tabButtons: { [string]: TextButton } = {}
local grid = create("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, -12, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = indexContent,
}, {
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(128, 164),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = indexContent })

local function refreshIndex()
	local count, worldCount, worldTotal = 0, 0, 0
	for _, def in Critters.List do
		if discovered[def.Id] then
			count += 1
		end
		if Config.IndexTabOf(def.World) == indexWorld then
			worldTotal += 1
			if discovered[def.Id] then
				worldCount += 1
			end
		end
	end
	local world = Config.WorldById[indexWorld]
	-- "Descoberto por": primeiro jogador do mundo a achar cada Secret (o servidor manda em JSON)
	local firsts = {}
	pcall(function()
		firsts = game:GetService("HttpService"):JSONDecode(ReplicatedStorage:GetAttribute("Discoveries") or "{}")
	end)
	indexTitle.Text = ("Found %d/%d (+%d%% cash)  -  %s: %d/%d  -  tap a card for hints & fun facts"):format(
		count,
		#Critters.List,
		math.floor(count * Config.IndexBonusPerCritter * 100 + 0.5),
		if world then world.Name else "Weather, Night & Mix",
		worldCount,
		worldTotal
	)
	for id, card in indexCards do
		local def = Critters.ById[id]
		local found = discovered[id] == true
		card.Frame.Visible = Config.IndexTabOf(def.World) == indexWorld
		card.Viewport.ImageColor3 = if found then WHITE else Color3.new(0, 0, 0)
		card.Name.Text = if found then def.Name else "???"
		local first = type(firsts) == "table" and firsts[id]
		if type(first) == "table" and type(first.N) == "string" then
			card.Income.Text = "1st: " .. first.N -- o primeiro do mundo a chocar
		elseif found then
			card.Income.Text = Format.Money(def.Income) .. "/s"
		elseif def.RebirthRequired then
			card.Income.Text = "Rebirth " .. def.RebirthRequired
		elseif def.Hint then
			card.Income.Text = "TAP FOR HINT"
		else
			card.Income.Text = ""
		end
	end
	for _, row in eggRows do
		row.Frame.Visible = row.World == indexWorld
	end
	for id, tab in tabButtons do
		local color = if Config.WorldById[id] then Config.WorldById[id].Color else GOLD
		tab.BackgroundColor3 = if id == indexWorld then color else ROW
	end
end

-- Enciclopédia (v10): janela com a curiosidade do animal de verdade (a janela é criada mais abaixo)
local showFact: ((string, string) -> ())? = nil

-- Dica dos bichinhos secretos / de rebirth (mostra ao tocar no card)
local function showHint(def)
	play("Click")
	if discovered[def.Id] then
		local fact = require(Shared:WaitForChild("Encyclopedia")).ById[def.Id]
		if fact and showFact then
			showFact(def.Name, ("%s  -  %s/s\n\nInspired by a real animal: %s\n\nFUN FACT: %s"):format(def.Rarity, Format.Money(def.Income), fact.Animal, fact.Fact))
		else
			toast(("%s (%s): %s/s"):format(def.Name, def.Rarity, Format.Money(def.Income)), "info")
		end
		return
	end
	local parts = {}
	if def.RebirthRequired then
		table.insert(parts, ("Needs Rebirth %d."):format(def.RebirthRequired))
	end
	if def.Hint then
		table.insert(parts, "HINT: " .. def.Hint)
	end
	local recipe = require(Shared:WaitForChild("Hybrids")).ByResult[def.Id]
	if recipe and #parts == 0 then
		table.insert(parts, "Made at the MIX LAB. HINT: " .. recipe.Hint)
	end
	if #parts == 0 then
		local eggs = {}
		for _, egg in Config.Eggs do
			if egg.Pool ~= def.World then
				continue
			end
			if (egg.Odds[def.Rarity] or 0) > 0 then
				table.insert(eggs, egg.Name)
			end
		end
		table.insert(parts, "Hatches from: " .. table.concat(eggs, ", "))
	end
	toast(table.concat(parts, " "), "rare")
end

-- Chances de cada ovo (transparência: o jogador sabe o que pode sair ANTES de comprar)
local function buildEggOdds()
	label({ LayoutOrder = 2, Size = UDim2.new(1, -12, 0, 34), Text = "EGG ODDS", TextColor3 = GOLD, ZIndex = 5, Parent = indexContent })
	for order, egg in Config.Eggs do
		local row = create("Frame", {
			LayoutOrder = 2 + order,
			Size = UDim2.new(1, -12, 0, 58),
			BackgroundColor3 = ROW,
			ZIndex = 5,
			Parent = indexContent,
		}, { corner(12), border(egg.Accent, 2) })
		table.insert(eggRows, { Frame = row, World = Config.IndexTabOf(egg.Pool) })
		label({
			Size = UDim2.new(0.3, -8, 0, 26),
			Position = UDim2.fromOffset(10, 4),
			Text = egg.Name,
			TextColor3 = egg.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			Parent = row,
		})
		label({
			Size = UDim2.new(0.3, -8, 0, 22),
			Position = UDim2.fromOffset(10, 31),
			Text = Format.Money(egg.Price) .. "  |  " .. egg.HatchTime .. "s" .. (if egg.Condition == "Weekly" then "  |  CRITTER OF THE WEEK" elseif egg.Condition then "  |  only in " .. string.upper(egg.Condition) elseif egg.Holiday and Config.HolidayById[egg.Holiday] then "  |  only at " .. string.upper(Config.HolidayById[egg.Holiday].Name) elseif egg.Where then "  |  from " .. egg.Where else ""),
			TextColor3 = Color3.fromRGB(255, 230, 120),
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = row,
		})
		local odds = {}
		for _, rarity in Config.Rarities do
			local chance = egg.Odds[rarity.Name]
			if chance and chance > 0 then
				table.insert(odds, ('<font color="#%s">%s %g%%</font>'):format(rarity.Color:ToHex(), rarity.Name, chance))
			end
		end
		label({
			Size = UDim2.new(0.7, -12, 1, -10),
			Position = UDim2.new(0.3, 4, 0, 5),
			Text = table.concat(odds, "  "),
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = row,
		})
	end
	label({
		LayoutOrder = 100,
		Size = UDim2.new(1, -12, 0, 44),
		Text = ("Mutations when hatching: Gold %g%% (x2)  Diamond %g%% (x4)  Rainbow %g%% (x10)"):format(
			Config.MutationByName.Gold.Chance,
			Config.MutationByName.Diamond.Chance,
			Config.MutationByName.Rainbow.Chance
		),
		TextColor3 = Color3.fromRGB(230, 230, 255),
		TextWrapped = true,
		ZIndex = 5,
		Parent = indexContent,
	})
end

-- Os cards (com o bichinho em 3D) só são criados quando a aba abre (mais leve no celular)
local function buildWorldCards(worldId: string)
	if builtWorlds[worldId] then
		return
	end
	builtWorlds[worldId] = true
	for order, def in Critters.List do
		if Config.IndexTabOf(def.World) == worldId then
			local rarity = Config.RarityByName[def.Rarity]
			local card = create("Frame", {
				LayoutOrder = order,
				BackgroundColor3 = ROW,
				ZIndex = 5,
				Parent = grid,
			}, { corner(12), border(rarity.Color, 3) })
			local viewport = create("ViewportFrame", {
				Size = UDim2.new(1, -8, 0, 96),
				Position = UDim2.fromOffset(4, 4),
				BackgroundTransparency = 1,
				Ambient = Color3.fromRGB(170, 170, 170),
				LightColor = WHITE,
				LightDirection = Vector3.new(-0.4, -1, 0.6),
				ZIndex = 5,
				Parent = card,
			})
			local model = Builder.Build(def)
			local aura = model:FindFirstChild("Aura")
			if aura then
				aura:Destroy()
			end
			model.Parent = viewport
			local boxCFrame, boxSize = model:GetBoundingBox()
			local radius = boxSize.Magnitude / 2
			local center = boxCFrame.Position
			local camera = Instance.new("Camera")
			camera.FieldOfView = 40
			camera.CFrame = CFrame.lookAt(center + Vector3.new(radius * 0.8, radius * 0.6, -radius * 2.2), center)
			camera.Parent = viewport
			viewport.CurrentCamera = camera

			local nameLabel = label({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 100), Text = def.Name, ZIndex = 5, Parent = card })
			label({ Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 122), Text = string.upper(def.Rarity), TextColor3 = rarity.Color, ZIndex = 5, Parent = card })
			local incomeText = label({ Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 142), Text = "", TextColor3 = Color3.fromRGB(140, 255, 140), StrokeThickness = 1, ZIndex = 5, Parent = card })
			local tap = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = card })
			tap.Activated:Connect(function()
				showHint(def)
			end)
			indexCards[def.Id] = { Frame = card, Viewport = viewport, Name = nameLabel, Income = incomeText }
		end
	end
end

local function showIndexWorld(worldId: string)
	indexWorld = worldId
	buildWorldCards(worldId)
	refreshIndex()
end

local function buildIndex()
	if indexBuilt then
		return
	end
	indexBuilt = true
	local tabs = table.clone(Config.Worlds)
	table.insert(tabs, { Id = "special", Name = "Special" }) -- clima, noite e híbridos (v9)
	for order, world in tabs do
		local shortName = string.split(world.Name, " ")[1]
		local tab = button({
			LayoutOrder = order,
			Size = UDim2.fromOffset(80, 38),
			BackgroundColor3 = ROW,
			ZIndex = 6,
			Parent = indexTabs,
		}, shortName, function()
			play("Click")
			showIndexWorld(world.Id)
		end)
		tabButtons[world.Id] = tab
	end
	buildEggOdds()
end
panelOpened.Index = function()
	buildIndex()
	-- abre na aba do mundo onde o jogador está
	local here = player:GetAttribute("World")
	showIndexWorld(if typeof(here) == "string" and Config.WorldById[here] then here else indexWorld)
end

ReplicatedStorage:GetAttributeChangedSignal("Discoveries"):Connect(function()
	if indexBuilt then
		refreshIndex()
	end
end)

IndexEvent.OnClientEvent:Connect(function(index)
	if type(index) ~= "table" then
		return
	end
	discovered = {}
	for id, value in index do
		if value then
			discovered[id] = true
		end
	end
	if indexBuilt then
		refreshIndex()
	end
end)

---------------------------------------------------------------------
-- REBIRTH
---------------------------------------------------------------------
local _, rebirthContent = makePanel("Rebirth", "REBIRTH", PURPLE)
create("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Parent = rebirthContent,
})
local rebirthTitle = label({ LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 44), Text = "", ZIndex = 5, Parent = rebirthContent })
local progressBack = create("Frame", {
	LayoutOrder = 2,
	Size = UDim2.new(1, -40, 0, 36),
	BackgroundColor3 = Color3.fromRGB(25, 25, 40),
	ZIndex = 5,
	Parent = rebirthContent,
}, { corner(12), border(DARK, 2) })
local progressFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = PURPLE, ZIndex = 5, Parent = progressBack }, { corner(12) })
local progressText = label({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", ZIndex = 6, Parent = progressBack })
local rewardsLabel = label({
	LayoutOrder = 3,
	Size = UDim2.new(1, -12, 0, 150),
	Text = "",
	TextColor3 = Color3.fromRGB(230, 210, 255),
	ZIndex = 5,
	Parent = rebirthContent,
})

local confirmUntil = 0
local rebirthButton, rebirthButtonText
rebirthButton, rebirthButtonText = button({
	LayoutOrder = 4,
	Size = UDim2.fromOffset(300, 64),
	BackgroundColor3 = PURPLE,
	ZIndex = 5,
	Parent = rebirthContent,
}, "REBIRTH!", function()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local cash = player:GetAttribute("Cash") or 0
	if cash < Config.RebirthCost(rebirths) then
		toast("You need " .. Format.Money(Config.RebirthCost(rebirths)) .. " to rebirth!", "error")
		play("Error")
		return
	end
	if os.clock() < confirmUntil then
		confirmUntil = 0
		RequestEvent:FireServer("Rebirth")
		rebirthButtonText.Text = "REBIRTH!"
	else
		confirmUntil = os.clock() + 3
		rebirthButtonText.Text = "SURE? CLICK AGAIN"
		task.delay(3, function()
			if os.clock() >= confirmUntil then
				rebirthButtonText.Text = "REBIRTH!"
			end
		end)
	end
end)

local function refreshRebirth()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local cash = player:GetAttribute("Cash") or 0
	local cost = Config.RebirthCost(rebirths)
	local hasSlots = player:GetAttribute("Pass_MoreSlots") == true
	local bought = player:GetAttribute("SlotUpgrades") or 0
	rebirthTitle.Text = ("Rebirth %d  >>  %d"):format(rebirths, rebirths + 1)
	progressFill.Size = UDim2.fromScale(math.clamp(cash / cost, 0, 1), 1)
	progressText.Text = Format.Money(cash) .. " / " .. Format.Money(cost)
	local lines = { ("x%g cash forever"):format(1 + (rebirths + 1) * Config.RebirthIncomeBonus) }
	local peak = math.max(rebirths, tonumber(player:GetAttribute("PeakRebirths")) or 0) -- prestígio não tira vagas
	local slotsNow = Config.SlotCount(peak, bought, hasSlots)
	if Config.SlotCount(math.max(rebirths + 1, peak), bought, hasSlots) > slotsNow then
		table.insert(lines, if slotsNow == Config.FloorSlots then "+1 base slot: 2ND FLOOR!" else "+1 base slot")
	end
	if rebirths + 1 > peak then
		table.insert(lines, ("Treadmill max speed +%d"):format(Config.TreadmillCapPerRebirth))
	end
	local unlocks = {}
	for _, def in Critters.List do
		if def.RebirthRequired == rebirths + 1 then
			table.insert(unlocks, def.Name)
		end
	end
	if #unlocks > 0 then
		table.insert(lines, "Eggs can now hatch: " .. table.concat(unlocks, ", "))
	end
	rewardsLabel.Text = "REWARDS:\n" .. table.concat(lines, "\n") .. "\n\nResets your cash only. Your critters and eggs STAY!"
	rebirthButton.BackgroundColor3 = if cash >= cost then PURPLE else GRAY
end
panelOpened.Rebirth = refreshRebirth

local refreshWorlds: () -> ()
local applyWorldSky: () -> ()
do
	---------------------------------------------------------------------
	-- MUNDOS
	---------------------------------------------------------------------
	local _, worldsContent = makePanel("Worlds", "WORLDS", Color3.fromRGB(255, 150, 60))
	create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = worldsContent })
	local worldRows = {}

	local function isWorldUnlocked(worldId: string): boolean
		if worldId == "meadow" then
			return true
		end
		local list = player:GetAttribute("WorldsUnlocked")
		if typeof(list) ~= "string" then
			return false
		end
		return table.find(string.split(list, ","), worldId) ~= nil
	end

	local function requirementText(world): string
		local parts = {}
		if world.Rebirths > 0 then
			table.insert(parts, "Rebirth " .. world.Rebirths)
		end
		if world.Cash > 0 then
			table.insert(parts, Format.Money(world.Cash))
		end
		return if #parts > 0 then table.concat(parts, " + ") else "FREE"
	end

	for order, world in Config.Worlds do
		local row = create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 86),
			BackgroundColor3 = ROW,
			ZIndex = 5,
			Parent = worldsContent,
		}, { corner(14), border(world.Color, 3) })
		label({
			Size = UDim2.new(0.62, -16, 0, 34),
			Position = UDim2.fromOffset(14, 6),
			Text = order .. ". " .. world.Name,
			TextColor3 = world.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			Parent = row,
		})
		local sub = label({
			Size = UDim2.new(0.62, -16, 0, 38),
			Position = UDim2.fromOffset(14, 42),
			Text = world.Description,
			TextColor3 = Color3.fromRGB(210, 210, 230),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = row,
		})
		local btn, btnText = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0.36, 0, 0, 58),
			BackgroundColor3 = GREEN,
			ZIndex = 5,
			Parent = row,
		}, "GO", function()
			play("Click")
			if isWorldUnlocked(world.Id) then
				RequestEvent:FireServer("TravelWorld", world.Id)
				panels.Worlds.Visible = false
			else
				RequestEvent:FireServer("UnlockWorld", world.Id)
			end
		end)
		worldRows[world.Id] = { Button = btn, ButtonText = btnText, Sub = sub, World = world }
	end
	label({
		LayoutOrder = 100,
		Size = UDim2.new(1, -12, 0, 50),
		Text = "Each world has its own eggs and critters. Eggs you buy there fly to your base!\nUnlocked worlds stay unlocked after Rebirth.",
		TextColor3 = Color3.fromRGB(255, 230, 190),
		TextWrapped = true,
		ZIndex = 5,
		Parent = worldsContent,
	})

	function refreshWorlds()
		local here = player:GetAttribute("World")
		-- o prestígio não tranca mundos: vale o maior rebirth que você já teve
		local rebirths = math.max(player:GetAttribute("Rebirths") or 0, tonumber(player:GetAttribute("PeakRebirths")) or 0)
		local cash = player:GetAttribute("Cash") or 0
		for index, world in Config.Worlds do
			local row = worldRows[world.Id]
			local previous = Config.Worlds[index - 1]
			if isWorldUnlocked(world.Id) then
				row.ButtonText.Text = if here == world.Id then "YOU ARE HERE" else "GO"
				row.Button.BackgroundColor3 = if here == world.Id then GRAY else GREEN
				row.Sub.Text = world.Description
			elseif previous and not isWorldUnlocked(previous.Id) then
				row.ButtonText.Text = "LOCKED"
				row.Button.BackgroundColor3 = GRAY
				row.Sub.Text = "Unlock " .. previous.Name .. " first. Needs " .. requirementText(world)
			else
				local ready = rebirths >= world.Rebirths and cash >= world.Cash
				row.ButtonText.Text = "UNLOCK " .. Format.Money(world.Cash)
				row.Button.BackgroundColor3 = if ready then ORANGE else GRAY
				row.Sub.Text = if rebirths < world.Rebirths then ("Needs Rebirth %d (you have %d)"):format(world.Rebirths, rebirths) else world.Description
			end
		end
	end
	panelOpened.Worlds = refreshWorlds

	-- Luz e cor do céu de cada mundo (noite na Galaxy, pôr do sol na Lava...)
	function applyWorldSky()
		local here = player:GetAttribute("World")
		local world = Config.WorldById[if typeof(here) == "string" then here else "meadow"] or Config.Worlds[1]
		local sky = world.Sky or {}
		local info = TweenInfo.new(1.2)
		local tint = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if sky.ClockTime and world.Id ~= "meadow" then -- no Meadow quem manda é o dia/noite (Atmos)
			TweenService:Create(Lighting, info, { ClockTime = sky.ClockTime }):Play()
		end
		if tint and sky.Tint then
			TweenService:Create(tint, info, { TintColor = sky.Tint }):Play()
		end
		homeButton.Visible = world.Id ~= "meadow"
	end

	player:GetAttributeChangedSignal("World"):Connect(function()
		applyWorldSky()
		if panels.Worlds.Visible then
			refreshWorlds()
		end
	end)
	player:GetAttributeChangedSignal("WorldsUnlocked"):Connect(function()
		if panels.Worlds.Visible then
			refreshWorlds()
		end
	end)
end

do
	---------------------------------------------------------------------
	-- CÓDIGOS
	---------------------------------------------------------------------
	local _, codesContent = makePanel("Codes", "CODES", Color3.fromRGB(240, 110, 180))
	create("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = codesContent,
	})
	label({
		LayoutOrder = 1,
		Size = UDim2.new(1, -12, 0, 60),
		Text = "Got a code? Type it here to get FREE cash and eggs!",
		TextColor3 = Color3.fromRGB(255, 220, 240),
		ZIndex = 5,
		Parent = codesContent,
	})
	local codeBox = create("TextBox", {
		LayoutOrder = 2,
		Size = UDim2.new(1, -60, 0, 64),
		BackgroundColor3 = WHITE,
		TextColor3 = DARK,
		PlaceholderText = "Enter code here",
		PlaceholderColor3 = GRAY,
		Font = FONT,
		TextScaled = true,
		ClearTextOnFocus = false,
		Text = "",
		ZIndex = 5,
		Parent = codesContent,
	}, { corner(14), border(DARK, 3), create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
	local function redeem()
		local code = codeBox.Text
		if #code == 0 then
			toast("Type a code first!", "warning")
			return
		end
		play("Click")
		RequestEvent:FireServer("RedeemCode", string.sub(code, 1, 30))
		codeBox.Text = ""
	end
	button({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(260, 64),
		BackgroundColor3 = GREEN,
		ZIndex = 5,
		Parent = codesContent,
	}, "REDEEM", redeem)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
	button({
		LayoutOrder = 4,
		Size = UDim2.fromOffset(320, 56),
		BackgroundColor3 = Color3.fromRGB(40, 190, 200),
		ZIndex = 5,
		Parent = codesContent,
	}, "INVITE FRIENDS (+10% cash each)", inviteFriends)
end

do
	---------------------------------------------------------------------
	-- ADMIN (só aparece para você)
	---------------------------------------------------------------------
	local _, adminContent = makePanel("Admin", "ADMIN", RED)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(180, 60),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = adminContent,
	})
	local adminCommands = {
		{ "+$1M", "Cash1M", GREEN },
		{ "+$1B", "Cash1B", GREEN },
		{ "+$1T", "Cash1T", GREEN },
		{ "Unlock Worlds", "UnlockWorlds", Color3.fromRGB(255, 150, 60) },
		{ "Cash to Rebirth", "Rebirth", PURPLE },
		{ "+1 Slot (free)", "SlotUp", GREEN },
		{ "HATCH NOW", "HatchNow", ORANGE },
		{ "Egg Rain", "Rain", BLUE },
		{ "Lucky Event", "Lucky", Color3.fromRGB(40, 170, 90) },
		{ "Give Legendary", "Legendary", GOLD },
		{ "Give Mythic", "Mythic", Color3.fromRGB(255, 60, 110) },
		{ "Give Secret", "Secret", Color3.fromRGB(60, 60, 60) },
		{ "Gold critter", "Gold", GOLD },
		{ "Diamond critter", "Diamond", Color3.fromRGB(120, 210, 240) },
		{ "Rainbow critter", "Rainbow", Color3.fromRGB(255, 100, 200) },
		{ "Reset Codes", "ResetCodes", GRAY },
		{ "Reset Tutorial", "ResetTutorial", GRAY },
		{ "5 same (fuse)", "Give5Same", COLORS.Teal },
		{ "5 Gold (fuse)", "Give5Gold", GOLD },
		{ "2x Cash 5 min", "Boost5", GREEN },
		{ "Shields OFF (all)", "ShieldOff", BLUE },
		{ "My shield ON", "ShieldMe", BLUE },
		{ "ADMIN ABUSE!", "AdminAbuse", RED },
		{ "Weather: RAIN", "WeatherRain", BLUE },
		{ "Weather: SNOW", "WeatherSnow", BLUE },
		{ "Weather: SUN", "WeatherSun", GOLD },
		{ "Night now (3 min)", "NightNow", PURPLE },
		{ "Next hatch SHINY", "ShinyNext", GOLD },
		{ "Giant Egg: fill", "GiantEggFill", GREEN },
		{ "Monster invasion", "Invasion", PURPLE },
		{ "Bandit visit (v24)", "Bandit", PURPLE },
		{ "Vote now", "VoteNow", BLUE },
		{ "Halloween ON", "Halloween", ORANGE },
		{ "Winter ON", "Winter", BLUE },
		{ "Holiday OFF", "HolidayOff", GRAY },
		{ "Creator visit", "CreatorVisit", GOLD },
		{ "Community +10K", "Goal10K", GREEN },
		{ "Minigame: Race", "MgRace", BLUE },
		{ "Minigame: King", "MgKing", GOLD },
		{ "Minigame: Battle", "MgBattle", PURPLE },
		{ "Minigame: Cops", "MgCops", RED },
		{ "Minigame: Hide", "MgHide", GREEN },
		{ "Secret Island open", "IslandOpen", COLORS.Teal },
		{ "Give 3D critters", "Give3D", COLORS.Purple },
	}
	for index, egg in Config.EggsOfWorld("meadow") do
		table.insert(adminCommands, 5 + index, { egg.Name, egg.Id, egg.Accent })
	end
	for order, entry in adminCommands do
		button({ LayoutOrder = order, BackgroundColor3 = entry[3], ZIndex = 5, Parent = adminContent }, entry[1], function()
			RequestEvent:FireServer("Admin", entry[2])
		end)
	end
end

do
	---------------------------------------------------------------------
	-- POPUP (boas-vindas, recompensa diária...)
	---------------------------------------------------------------------
	-- v21: card pequeno no canto de baixo, à direita (em cima do botão de pular do celular), nada no meio
	local popup = create("Frame", {
		Name = "PopupCard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -150),
		Size = UDim2.fromOffset(340, 190),
		BackgroundColor3 = PANEL,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { corner(16), border(GOLD, 3) })
	autoScale(popup)
	local popupTitle = label({ Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 8), Text = "", TextColor3 = GOLD, ZIndex = 11, Parent = popup })
	local popupBody = label({
		Size = UDim2.new(1, -24, 1, -104),
		Position = UDim2.fromOffset(12, 46),
		Text = "",
		TextWrapped = true,
		ZIndex = 11,
		StrokeThickness = 1.5,
		Parent = popup,
	})
	local popupQueue = {}
	local function showNextPopup()
		if popup.Visible or #popupQueue == 0 then
			return
		end
		local item = table.remove(popupQueue, 1)
		popupTitle.Text = item[1]
		popupBody.Text = item[2]
		popup.Visible = true
		UI.popIn(popup)
		play("Rare")
	end
	button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = GREEN,
		ZIndex = 12,
		Parent = popup,
	}, "OK!", function()
		popup.Visible = false
		play("Click")
		task.delay(0.2, showNextPopup)
	end)

	PopupEvent.OnClientEvent:Connect(function(title, body)
		table.insert(popupQueue, { tostring(title), tostring(body) })
		showNextPopup()
	end)
	showFact = function(title: string, body: string)
		table.insert(popupQueue, { title, body })
		showNextPopup()
	end

	NotifyEvent.OnClientEvent:Connect(function(text, kind)
		toast(tostring(text), kind)
		if kind == "error" then
			play("Error")
			if string.find(string.lower(tostring(text)), "cash", 1, true) then
				UI.shake(cashPanel)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Dinheiro na tela
---------------------------------------------------------------------
local shownCash = 0
local function refreshCash()
	local cash = player:GetAttribute("Cash") or 0
	cashLabel.Text = Format.Money(cash)
	if cash > shownCash then
		UI.pulse(cashLabel, 0.1)
	end
	shownCash = cash
	if panels.Shop.Visible then
		refreshShop()
	end
	if panels.Worlds.Visible then
		refreshWorlds()
	end
	if panels.Rebirth.Visible then
		refreshRebirth()
	end
end

local function refreshIncome()
	local income = player:GetAttribute("Income") or 0
	local multiplier = player:GetAttribute("Multiplier") or 1
	local multiplierText = string.gsub(string.format("%.2f", multiplier), "%.?0+$", "")
	incomeLabel.Text = ("+%s/s   (x%s)"):format(Format.Money(income), multiplierText)
end

player:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
player:GetAttributeChangedSignal("Income"):Connect(refreshIncome)
player:GetAttributeChangedSignal("Multiplier"):Connect(function()
	refreshIncome()
	if panels.Shop.Visible then
		refreshShop()
	end
end)
for _, attribute in { "SpeedLevel", "Rebirths", "IndexCount", "FriendBonus", "GroupBonus", "Slots", "SlotUpgrades", "TrainedSpeed", "TrainCap" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if panels.Shop.Visible then
			refreshShop()
		end
		if panels.Rebirth.Visible then
			refreshRebirth()
		end
	end)
end
player.AttributeChanged:Connect(function(attribute)
	if string.sub(attribute, 1, 5) == "Pass_" and panels.Shop.Visible then
		refreshShop()
	end
end)

local function refreshAdmin()
	adminButton.Visible = player:GetAttribute("IsAdmin") == true
end
player:GetAttributeChangedSignal("IsAdmin"):Connect(refreshAdmin)

local function refreshCarry()
	local carrying = player:GetAttribute("Carrying")
	if carrying then
		carryText.Text = "Carrying " .. tostring(carrying) .. "! RUN to YOUR BASE!"
		carryBanner.Visible = true
	else
		carryBanner.Visible = false
	end
end
player:GetAttributeChangedSignal("Carrying"):Connect(refreshCarry)

-- Tag [VIP] no chat
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	if source then
		local sender = Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("Pass_VIP") then
			properties.PrefixText = "<font color='#FFD23C'>[VIP]</font> " .. message.PrefixText
		end
	end
	return properties
end

---------------------------------------------------------------------
-- Esconde "Steal" nos seus bichinhos e "Sell" nos dos outros
---------------------------------------------------------------------
-- Escudo de novato e "sem covardia" (o servidor confere de novo; aqui só esconde o botão)
local function canStealFrom(ownerUserId: any): boolean
	if typeof(ownerUserId) ~= "number" then
		return true
	end
	-- v28: vingança passa por cima das outras regras (igual ao servidor em Fairness.CanSteal)
	local revengeUntil = player:GetAttribute("RevengeUntil")
	if player:GetAttribute("RevengeTarget") == ownerUserId and typeof(revengeUntil) == "number" and revengeUntil > workspace:GetServerTimeNow() then
		return true
	end
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("OwnerUserId") == ownerUserId then
				local shield = plot:GetAttribute("ShieldUntil")
				if typeof(shield) == "number" and shield > workspace:GetServerTimeNow() then
					return false
				end
			end
		end
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local mine = tonumber(player:GetAttribute("Power")) or 0
	local theirs = owner and tonumber(owner:GetAttribute("Power")) or 0
	return not (mine > 0 and theirs * Config.BullyIncomeRatio < mine)
end

local function evaluatePrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end
	local owner = model:GetAttribute("OwnerUserId")
	if prompt.Name == "StealPrompt" then
		prompt.Enabled = owner ~= player.UserId and canStealFrom(owner)
	elseif prompt.Name == "SellPrompt" or prompt.Name == "PickUpPrompt" or prompt.Name == "PetPrompt" then
		prompt.Enabled = owner == player.UserId
	end
end

local activeCritters = workspace:WaitForChild("ActiveCritters")
activeCritters.DescendantAdded:Connect(evaluatePrompt)
for _, descendant in activeCritters:GetDescendants() do
	evaluatePrompt(descendant)
end
activeCritters.ChildAdded:Connect(function(model)
	model:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		for _, descendant in model:GetDescendants() do
			evaluatePrompt(descendant)
		end
	end)
end)

---------------------------------------------------------------------
-- Bichinhos "respirando" no pedestal + mutação Rainbow mudando de cor
---------------------------------------------------------------------
local IDLE_STYLE = { -- { altura do pulinho, velocidade, balanço em graus }
	Common = { 0.12, 2.2, 5 },
	Uncommon = { 0.15, 2.2, 6 },
	Rare = { 0.2, 2, 7 },
	Epic = { 0.25, 1.8, 8 },
	Legendary = { 0.4, 1.5, 10 },
	Mythic = { 0.6, 1.2, 12 },
	Secret = { 0.7, 1.1, 14 },
}
local animated: { [Instance]: { Phase: number, Skin: { BasePart }?, SkinCheck: number } } = {}

local function trackCritter(model: Instance)
	if model:IsA("Model") then
		animated[model] = { Phase = math.random() * 10, Skin = nil, SkinCheck = 0 }
	end
end
activeCritters.ChildAdded:Connect(trackCritter)
activeCritters.ChildRemoved:Connect(function(model)
	animated[model] = nil
end)
for _, model in activeCritters:GetChildren() do
	trackCritter(model)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for model, info in animated do
		local root = model:FindFirstChild("Root") :: BasePart?
		if root and (root.Position - cameraPosition).Magnitude < 80 then
			local state = model:GetAttribute("State")
			if (state == "Incubating" or state == "Hatching") and root.Anchored then
				-- ovo chocando: balança cada vez mais perto de chocar
				local home = model:GetAttribute("Home")
				local hatchAt = model:GetAttribute("HatchAt")
				if typeof(home) == "CFrame" then
					local left = if typeof(hatchAt) == "number" then hatchAt - workspace:GetServerTimeNow() else 10
					local power = if state == "Hatching" then 1 else math.clamp(1 - left / 12, 0.12, 0.8)
					local speed = 6 + power * 22
					local tilt = math.sin(now * speed + info.Phase) * power * 0.28
					root.CFrame = home * CFrame.new(0, math.abs(tilt) * 0.6, 0) * CFrame.Angles(tilt * 0.4, 0, tilt)
				end
			elseif state == "Placed" then
				local home = model:GetAttribute("Home")
				if root.Anchored and typeof(home) == "CFrame" then
					local style = IDLE_STYLE[model:GetAttribute("Rarity") or "Common"] or IDLE_STYLE.Common
					local t = now * style[2] + info.Phase
					local lift = (math.sin(t) + 1) * 0.5 * style[1]
					root.CFrame = home * CFrame.new(0, lift, 0) * CFrame.Angles(0, math.rad(math.sin(t * 0.5) * style[3]), 0)
				end
			end
			if model:GetAttribute("Mutation") == "Rainbow" then
				if not info.Skin or (#info.Skin == 0 and now - info.SkinCheck > 2) then
					info.SkinCheck = now
					local list = {}
					for _, part in model:GetDescendants() do
						-- modelo 3D (MeshPart) mantém a textura no Rainbow: pintar a cor dele não aparece
						if part:IsA("BasePart") and part:GetAttribute("Skin") and not part:IsA("MeshPart") then
							table.insert(list, part)
						end
					end
					info.Skin = list
				end
				for i, part in info.Skin :: { BasePart } do
					part.Color = Color3.fromHSV((now * 0.25 + i * 0.07) % 1, 0.75, 1)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- Levou um BONK
---------------------------------------------------------------------
KnockbackEvent.OnClientEvent:Connect(function(velocity)
	if typeof(velocity) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	play("Bonk")
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
	task.delay(0.8, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end)

---------------------------------------------------------------------
-- Efeitos
---------------------------------------------------------------------
local function floatingText(position: Vector3, text: string, color: Color3)
	local anchor = create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Parent = workspace,
	})
	local billboard = create("BillboardGui", {
		Size = UDim2.fromOffset(200, 60),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = anchor,
		Parent = anchor,
	})
	local textLabel = label({ Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color, StrokeThickness = 3, Parent = billboard })
	TweenService:Create(anchor, TweenInfo.new(0.9), { CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) }):Play()
	TweenService:Create(textLabel, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
end

local function flash(color: Color3, strength: number?)
	local frame = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - (strength or 0.6),
		ZIndex = 40,
		Parent = gui,
	})
	TweenService:Create(frame, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	task.delay(0.85, function()
		frame:Destroy()
	end)
end

-- v21: o aviso grande ("MONSTER INVASION!", "LEVEL 5!") não cobre mais o meio da tela:
-- vira um card colorido no topo da coluna da esquerda, que pula ao aparecer e some sozinho
local shoutCard: Frame? = nil
local function bigText(text: string, color: Color3)
	if shoutCard then
		shoutCard:Destroy()
		shoutCard = nil
	end
	local frame = create("Frame", {
		Name = "Shout",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(STACK_W, 42),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		ZIndex = 32,
		Parent = leftStack,
	}, { corner(12), border(color, 3) })
	shoutCard = frame
	local textLabel = label({
		Size = UDim2.new(1, -14, 1, -8),
		Position = UDim2.fromOffset(7, 4),
		Text = text,
		TextColor3 = color,
		StrokeThickness = 3,
		ZIndex = 33,
		Parent = frame,
	})
	UI.popIn(frame)
	task.delay(2.2, function()
		if frame.Parent then
			local info = TweenInfo.new(0.4)
			TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(textLabel, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, info, { Transparency = 1 }):Play()
			end
			task.wait(0.45)
			frame:Destroy()
		end
		if shoutCard == frame then
			shoutCard = nil
		end
	end)
end

do
	---------------------------------------------------------------------
	-- OVO CHOCANDO: tela de suspense -> revela o bichinho
	---------------------------------------------------------------------
	local hatchScreen = create("TextButton", {
		Name = "HatchScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 10, 25),
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	local hatchHolder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(420, 470),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = hatchScreen,
	})
	autoScale(hatchHolder)
	-- v22: raios de sol girando atrás do ovo (na cor do ovo; na cor da raridade ao revelar)
	local hatchRays = create("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(210, 170),
		Size = UDim2.fromOffset(560, 560),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = hatchHolder,
	})
	local rayFrames = {}
	for i = 1, 12 do
		local ray = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(if i % 2 == 0 then 30 else 18, 280),
			Rotation = i * 30,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 30,
			Parent = hatchRays,
		}, {
			create("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.3), NumberSequenceKeypoint.new(1, 0) }),
				Rotation = 90,
			}),
		})
		rayFrames[i] = ray
	end
	local function setRays(color: Color3, transparency: number)
		for _, ray in rayFrames do
			ray.BackgroundColor3 = color
			ray.BackgroundTransparency = transparency
		end
	end
	-- v22: cascas do ovo voando na tela (pedacinhos nas cores do ovo)
	local function burstShells2D(colors: { Color3 }, count: number)
		local pieces = {}
		for i = 1, count do
			local angle = math.random() * math.pi * 2
			local speed = 260 + math.random() * 320
			local piece = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(210, 170),
				Size = UDim2.fromOffset(10 + math.random(0, 14), 8 + math.random(0, 10)),
				Rotation = math.random(0, 360),
				BackgroundColor3 = colors[1 + (i % #colors)],
				BorderSizePixel = 0,
				ZIndex = 34,
				Parent = hatchHolder,
			}, { corner(3) })
			pieces[i] = { Frame = piece, X = 210, Y = 170, VX = math.cos(angle) * speed, VY = math.sin(angle) * speed - 220, Spin = (math.random() - 0.5) * 900 }
		end
		local started = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			dt = math.min(dt, 0.05)
			local age = os.clock() - started
			for _, p in pieces do
				p.VY += 900 * dt
				p.X += p.VX * dt
				p.Y += p.VY * dt
				p.Frame.Position = UDim2.fromOffset(p.X, p.Y)
				p.Frame.Rotation += p.Spin * dt
				if age > 0.5 then
					p.Frame.BackgroundTransparency = math.clamp((age - 0.5) / 0.4, 0, 1)
				end
			end
			if age > 0.95 then
				connection:Disconnect()
				for _, p in pieces do
					p.Frame:Destroy()
				end
			end
		end)
	end
	local hatchGlow = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(210, 170),
		Size = UDim2.fromOffset(330, 330),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.6,
		ZIndex = 30,
		Parent = hatchHolder,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	create("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Parent = hatchGlow,
	})
	local hatchViewport = create("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(210, 170),
		Size = UDim2.fromOffset(320, 320),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(180, 180, 180),
		LightColor = WHITE,
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		ZIndex = 31,
		Parent = hatchHolder,
	})
	local hatchCamera = create("Camera", { FieldOfView = 40, Parent = hatchViewport })
	local hatchCracks = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(210, 170),
		Size = UDim2.fromOffset(200, 220),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 32,
		Parent = hatchHolder,
	})
	hatchViewport.CurrentCamera = hatchCamera
	local hatchNew = label({ Position = UDim2.fromOffset(250, 10), Size = UDim2.fromOffset(150, 50), Text = "NEW!", TextColor3 = Color3.fromRGB(255, 240, 90), StrokeThickness = 3, Rotation = 12, ZIndex = 33, Visible = false, Parent = hatchHolder })
	local hatchMutation = label({ Position = UDim2.fromOffset(10, 320), Size = UDim2.new(1, -20, 0, 34), Text = "", ZIndex = 32, Visible = false, Parent = hatchHolder })
	local hatchName = label({ Position = UDim2.fromOffset(10, 352), Size = UDim2.new(1, -20, 0, 56), Text = "", StrokeThickness = 3, ZIndex = 32, Parent = hatchHolder })
	local hatchRarity = label({ Position = UDim2.fromOffset(10, 406), Size = UDim2.new(1, -20, 0, 36), Text = "", ZIndex = 32, Parent = hatchHolder })
	local hatchTap = label({ Position = UDim2.fromOffset(10, 444), Size = UDim2.new(1, -20, 0, 24), Text = "", TextColor3 = Color3.fromRGB(200, 200, 220), StrokeThickness = 1, ZIndex = 32, Parent = hatchHolder })
	local rainbowKeys = {}
	for i, color in Builder.RainbowColors do
		table.insert(rainbowKeys, ColorSequenceKeypoint.new((i - 1) / (#Builder.RainbowColors - 1), color))
	end
	local hatchRainbow = create("UIGradient", { Color = ColorSequence.new(rainbowKeys), Enabled = false, Parent = hatchRarity })

	local hatchQueue = {}
	local hatchBusy = false
	local hatchClosable = false
	local hatchModel: Model? = nil

	local frameRadius: number? = nil -- v22: raio fixo (o pulo de escala do bichinho aparece de verdade)
	local function frameModel(model: Model, spin: number)
		local boxCFrame, boxSize = model:GetBoundingBox()
		local radius = frameRadius or boxSize.Magnitude / 2
		local center = boxCFrame.Position
		local offset = CFrame.Angles(0, spin, 0) * Vector3.new(0, radius * 0.45, -radius * 2.35)
		hatchCamera.CFrame = CFrame.lookAt(center + offset, center)
	end

	local function setHatchModel(model: Model?)
		if hatchModel then
			hatchModel:Destroy()
		end
		hatchModel = model
		if model then
			local aura = model:FindFirstChild("Aura")
			if aura then
				aura:Destroy()
			end
			model:PivotTo(CFrame.identity)
			model.Parent = hatchViewport
			frameRadius = nil
			local _, boxSize = model:GetBoundingBox()
			frameRadius = boxSize.Magnitude / 2
			frameModel(model, 0)
		else
			frameRadius = nil
		end
	end

	local function closeHatch()
		hatchScreen.Visible = false
		setHatchModel(nil)
		hatchBusy = false
		hatchClosable = false
	end

	local function runHatch(info)
		hatchBusy = true
		hatchClosable = false
		local egg = Config.EggById[info.Egg]
		local def = Critters.ById[info.Critter]
		if not egg or not def then
			hatchBusy = false
			return
		end
		local rarity = Config.RarityByName[def.Rarity]
		local fast = #hatchQueue > 0 -- vários ovos ao mesmo tempo: mostra mais rápido

		-- 1) Suspense: o ovo treme cada vez mais
		hatchScreen.Visible = true
		hatchNew.Visible = false
		hatchMutation.Visible = false
		hatchRainbow.Enabled = false
		hatchGlow.BackgroundColor3 = egg.Accent
		setRays(egg.Accent, 0.6)
		hatchRays.Size = UDim2.fromOffset(560, 560)
		hatchName.Text = egg.Name
		hatchName.TextColor3 = egg.Color
		hatchRarity.Text = "..."
		hatchRarity.TextColor3 = WHITE
		hatchTap.Text = ""
		local eggModel = Builder.BuildEgg(egg)
		setHatchModel(eggModel)
		local suspense = if fast then 0.9 else math.max(0.8, Config.HatchRevealTime - 0.4)
		-- câmera aproxima devagar (zoom) enquanto o ovo treme
		hatchCamera.FieldOfView = 40
		TweenService:Create(hatchCamera, TweenInfo.new(suspense, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FieldOfView = 24 }):Play()
		-- rachaduras aparecendo no ovo
		for _, crack in hatchCracks:GetChildren() do
			crack:Destroy()
		end
		for i = 1, 4 do
			task.delay(suspense * (0.25 + i * 0.16), function()
				if hatchModel ~= eggModel then
					return
				end
				local line = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, math.random(-40, 40), 0.5, math.random(-60, 10)),
					Size = UDim2.fromOffset(5, 0),
					Rotation = math.random(-70, 70),
					BackgroundColor3 = WHITE,
					BorderSizePixel = 0,
					ZIndex = 32,
					Parent = hatchCracks,
				}, { create("UIStroke", { Color = DARK, Thickness = 1.5 }) })
				TweenService:Create(line, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(5, math.random(40, 80)) }):Play()
				play("Click")
			end)
		end
		local started = os.clock()
		local nextTick = 0
		while os.clock() - started < suspense do
			local t = (os.clock() - started) / suspense
			if hatchModel == eggModel then
				local shake = math.sin(os.clock() * (18 + t * 30)) * (0.08 + t * 0.35)
				eggModel:PivotTo(CFrame.Angles(0, 0, shake) * CFrame.new(0, math.abs(shake) * 0.4, 0))
			end
			if os.clock() - started >= nextTick then
				nextTick += 0.45 - t * 0.3
				local sound = sounds.Hatch
				if sound then
					sound.PlaybackSpeed = 1.2 + t * 1.3
					SoundService:PlayLocalSound(sound)
				end
			end
			hatchGlow.Rotation += 2 + t * 8
			hatchRays.Rotation += 0.4 + t * 1.6 -- os raios giram cada vez mais rápido
			RunService.RenderStepped:Wait()
		end

		-- 2) Revela!
		if sounds.Hatch then
			sounds.Hatch.PlaybackSpeed = Config.Sounds.Hatch.Speed
		end
		for _, crack in hatchCracks:GetChildren() do
			crack:Destroy()
		end
		flash(rarity.Color, 0.9) -- flash na cor da raridade
		play("Rare")
		-- v22: cascas voando nas cores do ovo, raios na cor da raridade (pulso) e o bichinho pula para fora
		burstShells2D({ egg.Color, egg.Accent, WHITE }, 18)
		setRays(rarity.Color, 0.35)
		hatchRays.Size = UDim2.fromOffset(420, 420)
		TweenService:Create(hatchRays, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(640, 640) }):Play()
		TweenService:Create(hatchCamera, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = 40 }):Play()
		local critterModel = Builder.Build(def)
		if info.Mutation then
			Builder.ApplyMutation(critterModel, info.Mutation)
		end
		setHatchModel(critterModel)
		task.spawn(function()
			-- pulo de escala: 0.25 → 1.15 → 1 (só na tela; o modelo de verdade fica na base)
			local started = os.clock()
			while hatchModel == critterModel and os.clock() - started < 0.55 do
				local t = (os.clock() - started) / 0.55
				local f = if t < 0.5 then 0.25 + (t / 0.5) * 0.9 elseif t < 0.8 then 1.15 - ((t - 0.5) / 0.3) * 0.2 else 0.95 + ((t - 0.8) / 0.2) * 0.05
				pcall(function()
					critterModel:ScaleTo(f)
				end)
				RunService.RenderStepped:Wait()
			end
			if hatchModel == critterModel then
				pcall(function()
					critterModel:ScaleTo(1)
				end)
			end
		end)
		hatchGlow.BackgroundColor3 = if info.Mutation and Config.MutationByName[info.Mutation] then Config.MutationByName[info.Mutation].Color else rarity.Color
		hatchName.Text = def.Name
		hatchName.TextColor3 = WHITE
		local fullIncome = def.Income * Config.IncomeMultiplier(info.Mutation) * (if info.Shiny then Config.ShinyIncome else 1)
		hatchRarity.Text = string.upper(def.Rarity) .. "  -  " .. Format.Money(fullIncome) .. "/s grown"
		hatchRarity.TextColor3 = rarity.Color
		hatchRainbow.Enabled = Config.RarityIndex[def.Rarity] >= 6
		if info.Mutation then
			local mutation = Config.MutationByName[info.Mutation]
			hatchMutation.Text = string.upper(info.Mutation) .. " x" .. (if mutation then mutation.Income else 1)
			hatchMutation.TextColor3 = if mutation then mutation.Color else WHITE
			hatchMutation.Visible = true
		end
		if info.Shiny then
			-- SHINY (1 em 1000): texto dourado, som especial e confete
			hatchMutation.Text = "SHINY! x" .. Config.ShinyIncome .. (if info.Mutation then "  +  " .. hatchMutation.Text else "")
			hatchMutation.TextColor3 = GOLD
			hatchMutation.Visible = true
			play("Shiny")
			bigText("SHINY!", GOLD)
			Juice.Confetti(gui, 90, { GOLD, WHITE })
		end
		hatchNew.Visible = info.New == true
		hatchTap.Text = "Tap to continue"
		-- o nome aparece GRANDE, com pulo
		UI.popIn(hatchName)
		UI.pulse(hatchRarity, 0.25)
		local rank = Config.RarityIndex[def.Rarity] or 1
		if rank >= Config.AnnounceFromRarity then
			bigText(string.upper(def.Rarity) .. "!", rarity.Color)
			Juice.Confetti(gui, if rank >= 6 then 120 else 80)
			Juice.Shake(if rank >= 6 then 1.2 else 0.8, 0.7)
		elseif rank >= 4 or info.Mutation then
			Juice.Confetti(gui, 35)
			Juice.Shake(0.35, 0.35)
		end
		hatchHolder.Size = UDim2.fromOffset(380, 425)
		TweenService:Create(hatchHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(420, 470) }):Play()

		-- 3) Gira o bichinho e fecha sozinho (ou tocando na tela)
		hatchClosable = true
		local showTime = if fast then 1.4 else 3.2
		local revealStart = os.clock()
		while hatchBusy and hatchModel == critterModel and os.clock() - revealStart < showTime do
			frameModel(critterModel, (os.clock() - revealStart) * 1.2)
			hatchGlow.Rotation += 1.5
			hatchRays.Rotation += 0.7
			RunService.RenderStepped:Wait()
		end
		if hatchModel == critterModel then
			closeHatch()
		end
	end

	hatchScreen.Activated:Connect(function()
		if hatchClosable then
			-- muitos ovos de uma vez (ex.: admin "Hatch Now"): tocar pula todos
			if #hatchQueue > 2 then
				local count = #hatchQueue
				table.clear(hatchQueue)
				toast(("+%d more critters hatched! Check your base."):format(count), "rare")
			end
			closeHatch()
		end
	end)

	task.spawn(function()
		while true do
			if not hatchBusy and #hatchQueue > 0 then
				local info = table.remove(hatchQueue, 1)
				local ok, err = pcall(runHatch, info)
				if not ok then
					warn("[Hatch]", err)
					closeHatch()
				end
			end
			task.wait(0.1)
		end
	end)

	-- Explosão de brilho quando alguém choca um ovo perto de você
	local function hatchBurst(position: Vector3, rarityName: string)
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - position).Magnitude > 150 then
			return
		end
		local rarity = Config.RarityByName[rarityName] or Config.Rarities[1]
		local index = Config.RarityIndex[rarity.Name] or 1
		local anchor = create("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = CFrame.new(position),
			Parent = workspace,
		})
		local emitter = create("ParticleEmitter", {
			Color = ColorSequence.new(rarity.Color, WHITE),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Speed = NumberRange.new(10, 22),
			SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(0.5, 1),
			Drag = 3,
			Rate = 0,
			Parent = anchor,
		})
		emitter:Emit(12 + index * 6)
		task.delay(1.5, function()
			anchor:Destroy()
		end)
	end

	EffectEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "Hatch" then
			if type(data) == "table" and type(data.Critter) == "string" and type(data.Egg) == "string" then
				table.insert(hatchQueue, data)
			end
		elseif kind == "HatchBurst" then
			if type(data) == "table" and typeof(data.Position) == "Vector3" then
				hatchBurst(data.Position, tostring(data.Rarity))
			end
		elseif kind == "Travel" then
			local world = Config.WorldById[tostring(data)]
			if world then
				play("Rare")
				flash(world.Color, 0.7)
				bigText(string.upper(world.Name), world.Color)
			end
		elseif kind == "WorldUnlocked" then
			local world = Config.WorldById[tostring(data)]
			if world then
				play("Rare")
				flash(world.Color, 0.8)
				bigText(string.upper(world.Name) .. " UNLOCKED!", world.Color)
				Juice.Confetti(gui, 100, { world.Color, WHITE, GOLD })
				Juice.Shake(0.9, 0.7)
			end
		elseif kind == "OpenWorlds" then
			if not panels.Worlds.Visible then
				openPanel("Worlds")
			end
		elseif kind == "Train" then
			play("Train")
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				floatingText(root.Position + Vector3.new(0, 3, 0), "+1 SPEED!", Color3.fromRGB(120, 220, 255))
			end
		elseif kind == "Purchase" then
			play("Buy")
		elseif kind == "Collect" then
			play("Coin")
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and typeof(data) == "number" then
				floatingText(root.Position + Vector3.new(0, 3, 0), "+" .. Format.Money(data), Color3.fromRGB(120, 255, 120))
			end
		elseif kind == "Bonk" then
			if typeof(data) == "Vector3" then
				floatingText(data, "BONK!", Color3.fromRGB(255, 220, 60))
			end
		elseif kind == "Alarm" then
			flash(RED, 0.5)
			Juice.Shake(0.3, 0.3)
			bigText("INTRUDER!", Color3.fromRGB(255, 90, 90))
			task.spawn(function()
				for _ = 1, 3 do
					play("Alarm")
					task.wait(0.25)
				end
			end)
		elseif kind == "Stolen" then
			play("Rare")
			flash(GREEN)
			Juice.Shake(0.4, 0.3)
		elseif kind == "Rebirth" then
			play("Rare")
			flash(PURPLE)
			bigText("REBIRTH!", Color3.fromRGB(220, 170, 255))
			Juice.Confetti(gui, 110)
			Juice.Shake(1, 0.8)
		elseif kind == "Rain" then
			play("Rare")
			bigText("EGG RAIN!", Color3.fromRGB(140, 220, 255))
		elseif kind == "Lucky" then
			play("Rare")
			bigText("LUCKY EVENT!", Color3.fromRGB(140, 255, 160))
		elseif kind == "RareSpawn" then
			play("Rare")
		elseif kind == "Lock" then
			play("Buy")
		end
	end)
end


---------------------------------------------------------------------
-- Minha base: marcador "YOUR BASE" e botão de Instant Lock
---------------------------------------------------------------------
local plotsFolder = workspace:WaitForChild("Map"):WaitForChild("Plots")
local baseMarker: BillboardGui? = nil
local myPlot: Instance? = nil

local function refreshMarker()
	myPlot = nil
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			myPlot = plot
		end
	end
	if baseMarker then
		baseMarker:Destroy()
		baseMarker = nil
	end
	local sign = myPlot and myPlot:FindFirstChild("Sign") :: BasePart?
	if sign then
		local marker = create("BillboardGui", {
			Name = "YourBaseMarker",
			ResetOnSpawn = false,
			Adornee = sign,
			Size = UDim2.fromOffset(190, 46),
			StudsOffsetWorldSpace = Vector3.new(0, 7, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			Parent = playerGui,
		})
		label({ Size = UDim2.fromScale(1, 1), Text = "YOUR BASE", TextColor3 = Color3.fromRGB(120, 255, 120), StrokeThickness = 3, Parent = marker })
		baseMarker = marker
	end
end

-- Com streaming as bases podem chegar um pouco depois do script começar
local function watchPlot(plot: Instance)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshMarker)
end
for _, plot in plotsFolder:GetChildren() do
	watchPlot(plot)
end
plotsFolder.ChildAdded:Connect(function(plot)
	watchPlot(plot)
	refreshMarker()
end)
refreshMarker()

---------------------------------------------------------------------
-- TUTORIAL (primeiros 60 segundos)
---------------------------------------------------------------------
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local TUTORIAL_STEPS = 6
local TUTORIAL_TEXT = {
	[1] = if isTouch then "Walk to the conveyor and tap BUY on an EGG!" else "Walk to the conveyor and press E to BUY an EGG!",
	[2] = "Your egg is going to your base. Follow it!",
	[3] = "Your egg is HATCHING... what will it be?!",
	[4] = "Your critter makes cash! Step on the GREEN pad to collect it!",
	[5] = "Step on the RED button to lock your base!",
	[6] = if isTouch then "Sneak into other bases and hold STEAL! Tap your bat to BONK thieves!" else "Sneak into other bases and hold E to STEAL! Click with your bat to BONK thieves!",
}

-- v21: faixa do tutorial menor (embaixo, no meio, mas baixinha)
local tutorialFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -96),
	Size = UDim2.fromOffset(480, 54),
	BackgroundColor3 = Color3.fromRGB(30, 110, 220),
	Visible = false,
	ZIndex = 8,
	Parent = gui,
}, { corner(14), border(WHITE, 2.5), shine() })
autoScale(tutorialFrame)
local tutorialStepLabel = label({ Size = UDim2.new(0, 54, 1, -10), Position = UDim2.fromOffset(8, 5), Text = "1/" .. TUTORIAL_STEPS, TextColor3 = GOLD, ZIndex = 9, Parent = tutorialFrame })
local tutorialLabel = label({ Size = UDim2.new(1, -150, 1, -10), Position = UDim2.fromOffset(64, 5), Text = "", TextWrapped = true, ZIndex = 9, Parent = tutorialFrame })
button({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.fromOffset(74, 38),
	BackgroundColor3 = GRAY,
	ZIndex = 9,
	Parent = tutorialFrame,
}, "SKIP", function()
	RequestEvent:FireServer("SkipTutorial")
end)

local targetAttachment = create("Attachment", { Name = "TutorialTarget", Parent = workspace.Terrain })
local tutorialBeam = create("Beam", {
	Attachment1 = targetAttachment,
	Color = ColorSequence.new(Color3.fromRGB(255, 240, 90)),
	Width0 = 0.8,
	Width1 = 0.8,
	FaceCamera = true,
	LightEmission = 1,
	Transparency = NumberSequence.new(0.15),
	Enabled = false,
	Parent = workspace.Terrain,
})
local tutorialArrow = create("BillboardGui", {
	Adornee = targetAttachment,
	Size = UDim2.fromOffset(80, 80),
	AlwaysOnTop = true,
	LightInfluence = 0,
	Enabled = false,
	ResetOnSpawn = false,
	Parent = playerGui,
})
label({ Size = UDim2.fromScale(1, 1), Text = "V", TextColor3 = Color3.fromRGB(255, 240, 90), StrokeThickness = 4, Parent = tutorialArrow })
local tutorialHighlight: Highlight? = nil

-- O primeiro ovo do jogador (para a seta do passo "chocar")
local function myEgg(): Model?
	for _, model in activeCritters:GetChildren() do
		if model:GetAttribute("Kind") == "Egg" and model:GetAttribute("OwnerUserId") == player.UserId then
			return model :: Model
		end
	end
	return nil
end

local function tutorialTarget(step: number): (Vector3?, Instance?)
	if not myPlot then
		return nil, nil
	end
	local origin = myPlot:FindFirstChild("Origin") :: BasePart?
	if not origin then
		return nil, nil
	end
	if step == 1 then
		return (origin.CFrame * CFrame.new(0, 2, -60)).Position, nil
	elseif step == 2 then
		return origin.Position + Vector3.new(0, 4, 0), nil
	elseif step == 3 then
		local egg = myEgg()
		local root = egg and egg:FindFirstChild("Root") :: BasePart?
		if egg and root then
			return root.Position + Vector3.new(0, 3, 0), egg
		end
		return origin.Position + Vector3.new(0, 4, 0), nil
	elseif step == 4 then
		local pad = myPlot:FindFirstChild("CollectPad") :: BasePart?
		return if pad then pad.Position + Vector3.new(0, 2, 0) else nil, pad
	elseif step == 5 then
		local lockButton = myPlot:FindFirstChild("LockButton") :: BasePart?
		return if lockButton then lockButton.Position + Vector3.new(0, 2, 0) else nil, lockButton
	end
	return nil, nil
end

local function refreshTutorial()
	local step = player:GetAttribute("TutorialStep")
	if tutorialHighlight then
		tutorialHighlight:Destroy()
		tutorialHighlight = nil
	end
	if typeof(step) ~= "number" then
		tutorialFrame.Visible = false
		tutorialBeam.Enabled = false
		tutorialArrow.Enabled = false
		return
	end
	tutorialFrame.Visible = true
	tutorialStepLabel.Text = step .. "/" .. TUTORIAL_STEPS
	tutorialLabel.Text = TUTORIAL_TEXT[step] or ""
	play("Rare")
	local _, part = tutorialTarget(step)
	if part then
		tutorialHighlight = create("Highlight", {
			FillColor = Color3.fromRGB(255, 240, 90),
			OutlineColor = WHITE,
			FillTransparency = 0.5,
			Parent = part,
		})
	end
end
player:GetAttributeChangedSignal("TutorialStep"):Connect(refreshTutorial)

local refreshTraining: () -> ()
do
	---------------------------------------------------------------------
	-- Esteira de treino: barra de progresso enquanto corre
	---------------------------------------------------------------------
	local trainFrame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -190),
		Size = UDim2.fromOffset(360, 46),
		BackgroundColor3 = Color3.fromRGB(25, 25, 40),
		Visible = false,
		ZIndex = 7,
		Parent = gui,
	}, { corner(12), border(Color3.fromRGB(120, 220, 255), 3) })
	autoScale(trainFrame)
	local trainFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(60, 170, 240), ZIndex = 7, Parent = trainFrame }, { corner(12) })
	local trainText = label({ Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = "", ZIndex = 8, Parent = trainFrame })

	function refreshTraining()
		local training = player:GetAttribute("Training") == true
		trainFrame.Visible = training
		if not training then
			return
		end
		local trained = player:GetAttribute("TrainedSpeed") or 0
		local cap = player:GetAttribute("TrainCap") or Config.TreadmillBaseCap
		if trained >= cap then
			trainFill.Size = UDim2.fromScale(1, 1)
			trainText.Text = ("TREADMILL MAX +%d! Rebirth to train more"):format(cap)
		else
			local progress = math.clamp(player:GetAttribute("TrainProgress") or 0, 0, 1)
			trainFill.Size = UDim2.fromScale(progress, 1)
			trainText.Text = ("KEEP RUNNING!  Speed +%d/%d"):format(trained, cap)
		end
	end
	for _, attribute in { "Training", "TrainProgress", "TrainedSpeed", "TrainCap" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshTraining)
	end
end

-- Contagem regressiva em cima dos ovos chocando (cada tela calcula a sua)
local function refreshEggTimers(serverNow: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for _, model in activeCritters:GetChildren() do
		if model:GetAttribute("Kind") == "Egg" and model:GetAttribute("State") == "Incubating" then
			local root = model:FindFirstChild("Root") :: BasePart?
			local hatchAt = model:GetAttribute("HatchAt")
			if root and typeof(hatchAt) == "number" and (root.Position - cameraPosition).Magnitude < 90 then
				local info = root:FindFirstChild("Info")
				local line = info and info:FindFirstChild("ValueLine") :: TextLabel?
				if line then
					local left = math.max(0, math.ceil(hatchAt - serverNow))
					local waitFor = model:GetAttribute("WaitFor") -- ovo de clima esperando chuva/neve/noite
					if typeof(waitFor) == "string" then
						line.Text = "Waiting for " .. string.upper(waitFor) .. " (" .. Format.Time(left) .. ")"
					else
						line.Text = if left > 0 then "Hatch in " .. Format.Time(left) else "HATCHING!"
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Atualizações contínuas (4x por segundo)
---------------------------------------------------------------------
local function timerText(name: string, attribute: string): string?
	local value = workspace:GetAttribute(attribute)
	if typeof(value) ~= "number" then
		return nil
	end
	return name .. " in " .. Format.Time(value - workspace:GetServerTimeNow())
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	local serverNow = workspace:GetServerTimeNow()
	refreshEggTimers(serverNow)

	-- Eventos
	local rainUntil = workspace:GetAttribute("RainUntil")
	local luckyUntil = workspace:GetAttribute("LuckyUntil")
	local rainLeft = if typeof(rainUntil) == "number" then rainUntil - serverNow else 0
	local luckyLeft = if typeof(luckyUntil) == "number" then luckyUntil - serverNow else 0
	if rainLeft > 0 then
		eventBanner.Visible = true
		eventBanner.BackgroundColor3 = Color3.fromRGB(40, 130, 230)
		eventBannerText.Text = "EGG RAIN! Catch free eggs!  " .. Format.Time(rainLeft)
	elseif luckyLeft > 0 then
		eventBanner.Visible = true
		eventBanner.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
		eventBannerText.Text = ("LUCKY EVENT! x%d rare eggs  %s"):format(Config.LuckyEggMultiplier, Format.Time(luckyLeft))
	else
		eventBanner.Visible = false
	end
	local texts = {}
	local rainText = timerText("Egg Rain", "NextRain")
	local luckyText = timerText("Lucky", "NextLucky")
	if rainText then
		table.insert(texts, rainText)
	end
	if luckyText then
		table.insert(texts, luckyText)
	end
	-- v26: critter da semana (o servidor publica nos atributos do Workspace)
	local weeklyName = workspace:GetAttribute("WeeklyName")
	local weeklyEnds = workspace:GetAttribute("WeeklyEnds")
	if typeof(weeklyName) == "string" and typeof(weeklyEnds) == "number" then
		local left = math.max(0, weeklyEnds - math.floor(workspace:GetServerTimeNow()))
		local days = math.floor(left / 86400)
		local hours = math.floor((left % 86400) / 3600)
		local leftText = if days > 0 then ("%dd %dh"):format(days, hours) elseif hours > 0 then ("%dh"):format(hours) else ("%dm"):format(math.max(1, math.floor(left / 60)))
		table.insert(texts, ("\u{2B50} Week: %s (%s left)"):format(weeklyName, leftText))
	end
	eventText.Text = table.concat(texts, "  |  ")
	eventStrip.Visible = #texts > 0 -- v21: sem evento marcado, o chip some

	-- Marcador e botão de Instant Lock
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if baseMarker and myPlot then
		local sign = myPlot:FindFirstChild("Sign") :: BasePart?
		if root and sign then
			local inMeadow = (player:GetAttribute("World") or "meadow") == "meadow"
			baseMarker.Enabled = inMeadow and (root.Position - sign.Position).Magnitude > 50
		end
	end
	local showInstant = false
	if myPlot then
		local lockedUntil = myPlot:GetAttribute("LockedUntil") or 0
		local cooldownUntil = myPlot:GetAttribute("CooldownUntil") or 0
		local productId = Config.DevProducts.InstantLock or 0
		showInstant = lockedUntil <= serverNow and cooldownUntil > serverNow and (productId > 0 or IS_STUDIO)
		-- v23: o dono vê os segundos da trava (e da recarga) na coluna da esquerda
		if lockedUntil > serverNow then
			lockBar.Visible = true
			lockBar.BackgroundColor3 = Color3.fromRGB(215, 60, 70)
			lockText.Text = ("\u{1F512} BASE LOCKED  %s"):format(Format.Time(lockedUntil - serverNow))
			lockFill.Size = UDim2.fromScale(math.clamp((lockedUntil - serverNow) / math.max(Config.LockDurationPass, 1), 0, 1), 1)
		elseif cooldownUntil > serverNow then
			lockBar.Visible = true
			lockBar.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
			lockText.Text = ("\u{1F513} Lock ready in %s"):format(Format.Time(cooldownUntil - serverNow))
			lockFill.Size = UDim2.fromScale(1 - math.clamp((cooldownUntil - serverNow) / math.max(Config.LockCooldown, 1), 0, 1), 1)
		else
			lockBar.Visible = false
		end
	else
		lockBar.Visible = false
	end
	instantLockButton.Visible = showInstant

	-- Seta do tutorial: do jogador até o objetivo
	local step = player:GetAttribute("TutorialStep")
	local position = if typeof(step) == "number" then tutorialTarget(step) else nil
	if position and root then
		local attachment = root:FindFirstChild("TutorialAttachment") :: Attachment?
		if not attachment then
			attachment = create("Attachment", { Name = "TutorialAttachment", Parent = root })
		end
		tutorialBeam.Attachment0 = attachment
		targetAttachment.WorldPosition = position
		tutorialBeam.Enabled = true
		tutorialArrow.Enabled = true
		tutorialArrow.StudsOffsetWorldSpace = Vector3.new(0, 2 + math.abs(math.sin(os.clock() * 3)) * 1.5, 0)
	else
		tutorialBeam.Enabled = false
		tutorialArrow.Enabled = false
	end
end)

local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
end
updateScales()

refreshCash()
refreshIncome()
refreshAdmin()
---------------------------------------------------------------------
-- JOGADORES NOVOS: escudo, vingança e "próximo objetivo"
---------------------------------------------------------------------
do
	local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")
	local domes: { [Instance]: { Dome: BasePart, Label: TextLabel } } = {}

	-- Faixa "próximo objetivo" (v21: na coluna da esquerda)
	local goalFrame = create("Frame", {
		Name = "GoalBar",
		LayoutOrder = 25,
		Size = UDim2.fromOffset(STACK_W, 36),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 30,
		Parent = leftStack,
	}, { corner(10), border(GOLD, 2) })
	local goalFill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(90, 70, 160),
		BorderSizePixel = 0,
		ZIndex = 30,
		Parent = goalFrame,
	}, { corner(10) })
	local goalText = label({ Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = goalFrame })

	-- Faixa da vingança (v21: na coluna da esquerda)
	local revengeFrame = create("Frame", {
		Name = "RevengeBar",
		LayoutOrder = 55,
		Size = UDim2.fromOffset(STACK_W, 30),
		BackgroundColor3 = Color3.fromRGB(200, 40, 50),
		Visible = false,
		ZIndex = 30,
		Parent = leftStack,
	}, { corner(10), border(WHITE, 2), shine() })
	local revengeText = label({ Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = revengeFrame })
	local revengeHighlight: Highlight? = nil

	local function setGoal(text: string, progress: number?)
		goalFrame.Visible = true
		goalText.Text = text
		goalFill.Size = UDim2.fromScale(math.clamp(progress or 0, 0, 1), 1)
	end

	local function isUnlocked(worldId: string): boolean
		local list = player:GetAttribute("WorldsUnlocked")
		return worldId == "meadow" or (typeof(list) == "string" and table.find(string.split(list, ","), worldId) ~= nil)
	end

	local function refreshGoal(serverNow: number, myShield: number)
		if myShield > serverNow then
			setGoal(("\u{1F6E1} New player shield: %s - nobody can steal from you!"):format(Format.Time(myShield - serverNow)), (myShield - serverNow) / Config.NewbieShieldSeconds)
			return
		end
		if typeof(player:GetAttribute("TutorialStep")) == "number" then
			goalFrame.Visible = false
			return
		end
		local cash = player:GetAttribute("Cash") or 0
		local income = player:GetAttribute("Income") or 0
		local free = player:GetAttribute("FreeSlots") or 0
		local slots = player:GetAttribute("Slots") or Config.StartSlots
		local bought = player:GetAttribute("SlotUpgrades") or 0
		local rebirths = player:GetAttribute("Rebirths") or 0
		if free > 0 and income < 200 then
			setGoal(("Goal: buy eggs to fill your base (%d free)"):format(free), 1 - free / slots)
			return
		end
		local slotCost = Config.SlotUpgradeCosts[bought + 1]
		if slotCost and slots < Config.MaxSlots and cash * 3 >= slotCost then
			setGoal(("Goal: +1 base slot in SHOP (%s)"):format(Format.Money(slotCost)), cash / slotCost)
			return
		end
		for index, world in Config.Worlds do
			if not isUnlocked(world.Id) then
				if rebirths < world.Rebirths then
					local cost = Config.RebirthCost(rebirths)
					setGoal(("Goal: REBIRTH %d (%s) to reach %s"):format(rebirths + 1, Format.Money(cost), world.Name), cash / cost)
				else
					setGoal(("Goal: unlock %s (%s)"):format(world.Name, Format.Money(world.Cash)), cash / math.max(world.Cash, 1))
				end
				return
			end
			if index == #Config.Worlds then
				local cost = Config.RebirthCost(rebirths)
				setGoal(("Goal: REBIRTH %d (%s) - x%g cash"):format(rebirths + 1, Format.Money(cost), 1 + (rebirths + 1) * Config.RebirthIncomeBonus), cash / cost)
			end
		end
	end

	local function refreshShields(serverNow: number): number
		local myShield = 0
		for _, plot in plots:GetChildren() do
			local shield = plot:GetAttribute("ShieldUntil")
			local active = typeof(shield) == "number" and shield > serverNow and plot:GetAttribute("OwnerUserId") ~= nil
			local entry = domes[plot]
			if active then
				if plot:GetAttribute("OwnerUserId") == player.UserId then
					myShield = shield
				end
				local origin = plot:FindFirstChild("Origin") :: BasePart?
				if not entry and origin then
					local dome = create("Part", {
						Name = "NewbieShield",
						Anchored = true,
						CanCollide = false,
						CanQuery = false,
						CanTouch = false,
						CastShadow = false,
						Material = Enum.Material.ForceField,
						Color = Color3.fromRGB(90, 220, 255),
						Size = Vector3.new(70, 40, 78),
						CFrame = CFrame.new(origin.Position),
						Parent = workspace,
					}, { create("SpecialMesh", { MeshType = Enum.MeshType.Sphere }) })
					local board = create("BillboardGui", {
						Size = UDim2.fromOffset(260, 60),
						StudsOffsetWorldSpace = Vector3.new(0, 24, 0),
						LightInfluence = 0,
						MaxDistance = 160,
						Parent = dome,
					})
					local text = label({ Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.fromRGB(150, 235, 255), StrokeThickness = 3, Parent = board })
					entry = { Dome = dome, Label = text }
					domes[plot] = entry
				end
				if entry then
					entry.Label.Text = "\u{1F6E1} NEW PLAYER SHIELD " .. Format.Time(shield - serverNow)
				end
			elseif entry then
				entry.Dome:Destroy()
				domes[plot] = nil
			end
		end
		return myShield
	end

	local function refreshRevenge(serverNow: number)
		local untilTime = player:GetAttribute("RevengeUntil")
		local targetId = player:GetAttribute("RevengeTarget")
		local active = typeof(untilTime) == "number" and untilTime > serverNow
		revengeFrame.Visible = active
		local target = if active and typeof(targetId) == "number" then Players:GetPlayerByUserId(targetId) else nil
		if active then
			revengeText.Text = ("REVENGE! +%d speed %ds - chase %s!"):format(Config.RevengeSpeedBonus, math.ceil(untilTime - serverNow), if target then target.DisplayName else "the thief")
		end
		local character = target and target.Character
		if character then
			if not revengeHighlight or revengeHighlight.Parent ~= character then
				if revengeHighlight then
					revengeHighlight:Destroy()
				end
				revengeHighlight = create("Highlight", {
					FillColor = Color3.fromRGB(255, 60, 60),
					OutlineColor = WHITE,
					FillTransparency = 0.45,
					DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
					Parent = character,
				})
			end
		elseif revengeHighlight then
			revengeHighlight:Destroy()
			revengeHighlight = nil
		end
	end

	-- dinheiro "pulando" dos seus bichinhos (só na sua tela)
	local function moneyPops()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local multiplier = tonumber(player:GetAttribute("Multiplier")) or 1
		local count = 0
		for _, model in activeCritters:GetChildren() do
			if count >= 18 then
				break
			end
			if model:GetAttribute("OwnerUserId") == player.UserId and model:GetAttribute("State") == "Placed" then
				local root = model:FindFirstChild("Root") :: BasePart?
				local def = Critters.ById[model:GetAttribute("CritterId") or ""]
				if root and def and (root.Position - camera.CFrame.Position).Magnitude < 70 then
					count += 1
					local amount = def.Income * Config.IncomeMultiplier(model:GetAttribute("Mutation")) * multiplier * 2
					task.delay(count * 0.07, Juice.MoneyPop, root, "+" .. Format.Money(amount), nil, root.Size.Y + 2)
				end
			end
		end
	end

	local elapsedFair, elapsedPops = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsedFair += dt
		elapsedPops += dt
		if elapsedFair >= 0.5 then
			elapsedFair = 0
			local serverNow = workspace:GetServerTimeNow()
			local myShield = refreshShields(serverNow)
			refreshGoal(serverNow, myShield)
			refreshRevenge(serverNow)
		end
		if elapsedPops >= 2 then
			elapsedPops = 0
			if player:GetAttribute("MoneyPops") ~= false then -- dá para desligar em SETTINGS
				moneyPops()
			end
		end
	end)

	-- de vez em quando confere de novo quem pode ser roubado (escudo acabou, renda mudou...)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, model in activeCritters:GetChildren() do
				local root = model:FindFirstChild("Root")
				local prompt = root and root:FindFirstChild("StealPrompt")
				if prompt then
					evaluatePrompt(prompt)
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- Mapa vivo: peças com Tag "Spin"/"Bob" giram e balançam (só na sua tela, sem pesar o servidor)
---------------------------------------------------------------------
do
	type Mover = { Base: CFrame, Center: CFrame, Speed: number, Axis: Vector3, Bob: number, Phase: number, Spin: boolean }
	local movers: { [Instance]: Mover } = {}
	local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

	local function track(instance: Instance)
		if movers[instance] then
			return
		end
		-- enfeite criado na hora pode chegar antes das peças: espera a primeira peça para achar o centro
		if instance:IsA("Model") and not instance:FindFirstChildWhichIsA("BasePart", true) then
			local connection
			connection = instance.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") then
					connection:Disconnect()
					task.defer(track, instance)
				end
			end)
			return
		end
		local base: CFrame
		if instance:IsA("Model") then
			base = instance:GetPivot()
		elseif instance:IsA("BasePart") then
			base = instance.CFrame
		else
			return
		end
		local center = base
		local pivot = instance:FindFirstChild("Pivot")
		if pivot and pivot:IsA("BasePart") then
			center = pivot.CFrame
		elseif instance:IsA("Model") then
			center = CFrame.new((instance :: Model):GetBoundingBox().Position)
		end
		local axis = AXES[tostring(instance:GetAttribute("SpinAxis") or "Y")] or Vector3.yAxis
		movers[instance] = {
			Base = base,
			Center = CFrame.new(center.Position),
			Speed = tonumber(instance:GetAttribute("SpinSpeed")) or 1,
			Axis = axis,
			Bob = if CollectionService:HasTag(instance, "Bob") then tonumber(instance:GetAttribute("BobHeight")) or 1 else 0,
			Phase = math.random() * 6,
			Spin = CollectionService:HasTag(instance, "Spin"),
		}
	end
	local function untrack(instance: Instance)
		movers[instance] = nil
	end
	for _, tag in { "Spin", "Bob" } do
		for _, instance in CollectionService:GetTagged(tag) do
			track(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	end

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local t = os.clock()
		for instance, mover in movers do
			if not instance.Parent then
				movers[instance] = nil
				continue
			end
			if (mover.Center.Position - cameraPosition).Magnitude > (if player:GetAttribute("LowGfx") then 120 else 350) then
				continue
			end
			local offset = CFrame.identity
			if mover.Spin then
				offset = CFrame.fromAxisAngle(mover.Axis, (t * mover.Speed + mover.Phase) % (math.pi * 2))
			end
			local lift = Vector3.new(0, math.sin(t * 1.6 + mover.Phase) * mover.Bob, 0)
			local target = (mover.Center + lift) * offset * mover.Center:Inverse() * mover.Base
			if instance:IsA("Model") then
				instance:PivotTo(target)
			elseif instance:IsA("BasePart") then
				instance.CFrame = target
			end
		end
	end)
end

-- Barraquinhas do mapa (SHOP, INDEX, REBIRTH, CODES) abrem as janelas
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player or not CollectionService:HasTag(prompt, "OpenPanel") then
		return
	end
	local panelName = prompt:GetAttribute("Panel")
	if typeof(panelName) == "string" and panels[panelName] and not panels[panelName].Visible then
		openPanel(panelName)
	end
end)

---------------------------------------------------------------------
-- Telas novas da v7 (ficam em módulos separados, ao lado deste script)
---------------------------------------------------------------------
do
	local function scaleNow(guiObject: GuiObject)
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local value = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.25)
		local scale = Instance.new("UIScale")
		scale.Scale = value
		scale:SetAttribute("Base", value)
		scale.Parent = guiObject
	end
	local ctx = {
		gui = gui,
		leftStack = leftStack, -- v21: coluna de avisos da esquerda (itens com LayoutOrder; sem scaleNow!)
		stackWidth = STACK_W,
		topInset = TOP_INSET,
		makePanel = makePanel,
		panelOpened = panelOpened,
		toast = toast,
		play = play,
		scaleNow = scaleNow,
		RequestEvent = RequestEvent,
		EffectEvent = EffectEvent,
		InventoryEvent = RemotesFolder:WaitForChild("InventorySync") :: RemoteEvent,
		StyleEvent = RemotesFolder:WaitForChild("StyleSync") :: RemoteEvent,
		SeasonEvent = RemotesFolder:WaitForChild("SeasonSync") :: RemoteEvent,
		panels = panels,
		flash = flash,
		bigText = bigText,
		floatingText = floatingText,
		openPanel = openPanel,
		menuButton = menuButton,
		RemotesFolder = RemotesFolder,
	}
	require(script.Parent:WaitForChild("InventoryUI")).Init(ctx)
	require(script.Parent:WaitForChild("LabUI")).Init(ctx)
	require(script.Parent:WaitForChild("Atmos")).Init(ctx)
	require(script.Parent:WaitForChild("MeUI")).Init(ctx)
	require(script.Parent:WaitForChild("SocialUI")).Init(ctx)
	require(script.Parent:WaitForChild("MinigameUI")).Init(ctx)
	require(script.Parent:WaitForChild("ExploreUI")).Init(ctx)
	require(script.Parent:WaitForChild("NpcUI")).Init(ctx)
	require(script.Parent:WaitForChild("EventsUI")).Init(ctx)
	require(script.Parent:WaitForChild("StyleUI")).Init(ctx)
	require(script.Parent:WaitForChild("PassUI")).Init(ctx)
	require(script.Parent:WaitForChild("SettingsUI")).Init(ctx)
	require(script.Parent:WaitForChild("RetentionUI")).Init(ctx) -- v23: presentes de tempo + roleta diária
	require(script.Parent:WaitForChild("PetFollow")).Init()
	-- v21: montarias animadas e efeitos 3D do mundo (se algo der errado neles, o resto da tela continua)
	for _, name in { "MountFX", "WorldFX", "WorldLife" } do -- v27: WorldLife = mundos vivos + brincadeiras
		local ok, err = pcall(function()
			require(script.Parent:WaitForChild(name)).Init(ctx)
		end)
		if not ok then
			warn("[" .. name .. "]", err)
		end
	end
	updateScales() -- as janelas novas também ficam do tamanho certo no celular

	-- Celular deitado (tela baixa): menu em 3 colunas para não cobrir o botão de pular
	local function fitMenu()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local visible = 0
		for _, child in menu:GetChildren() do
			if child:IsA("GuiButton") and child.Visible then
				visible += 1
			end
		end
		local small = size.Y < 500 or visible > 14 -- muitos botões: 3 colunas para não descer demais
		menuColumns = if small then 3 else 2
		layoutMenu()
	end
	fitMenu()
	for _, child in menu:GetChildren() do
		if child:IsA("GuiButton") then
			child:GetPropertyChangedSignal("Visible"):Connect(fitMenu)
		end
	end
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitMenu)
	end
end

refreshCarry()
refreshTraining()
applyWorldSky()
refreshTutorial()
RequestEvent:FireServer("GetIndex")
