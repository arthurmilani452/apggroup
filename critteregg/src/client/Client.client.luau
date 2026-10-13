--!nonstrict
--[[
	Tela do jogador (só MOSTRA e PEDE; quem decide é o servidor).
	  HUD (v66, "menos coisa na tela"): velocidade (rosa) e dinheiro (verde) embaixo à esquerda (celular: embaixo no meio);
	       5 botões à esquerda (Loja, Índice, Ovos, Pets, Presentes); 1 botão Menu à direita com o resto dentro
	       (Diário, Missões, Rebirth, Boosts, Códigos, Doces, Convidar, Som, Modo Lento, Admin);
	       2 relógios (noite + o evento mais importante) embaixo à direita (celular: em cima à direita);
	       painel da esteira com AUTO CORRER; faixa e avisos no topo. Textos em PT-BR se o Roblox estiver em português.
	  Janelas: Shop (melhorias, trilhas, boosts), Index (cartões 3D por zona + prêmios), Eggs, Pets/Sell,
	           Trails, Fuse, Boosts. As lojinhas do mapa abrem a janela delas quando você entra.
	  Mundo: placas das zonas verdes/vermelhas, seta guia, pose de carregar, bichinhos passeando, listras da esteira.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Critters = require(ReplicatedStorage.Shared:WaitForChild("Critters"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local net = ReplicatedStorage:WaitForChild("Net") :: RemoteEvent

local player = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TOUCH = UserInputService.TouchEnabled

---------------------------------------------------------------------
-- TEXTOS EM PORTUGUÊS (v66): Roblox em português = botões, Menu, Admin, esteira e dicas em PT-BR.
-- (os avisos que vêm do servidor continuam em inglês). Textos curtos para caber nos botões.
---------------------------------------------------------------------
local PT_BR = false
pcall(function()
	PT_BR = string.lower(string.sub(game:GetService("LocalizationService").RobloxLocaleId, 1, 2)) == "pt"
end)
local TEXTS: { [string]: { string } } = {
	Shop = { "Shop", "Loja" },
	Index = { "Index", "Índice" },
	Eggs = { "Eggs", "Ovos" },
	Pets = { "Pets", "Pets" },
	Gifts = { "Gifts", "Presentes" },
	Menu = { "Menu", "Menu" },
	Daily = { "Daily", "Diário" },
	Quests = { "Quests", "Missões" },
	Rebirth = { "Rebirth", "Renascer" },
	Boosts = { "Boosts", "Boosts" },
	Codes = { "Codes", "Códigos" },
	Candy = { "Candy", "Doces" },
	Invite = { "Invite", "Convidar" },
	InviteSub = { "+%d%% cash per friend playing", "+%d%% $ por amigo jogando" },
	Sound = { "Sound", "Som" },
	SlowMode = { "Slow Mode", "Modo Lento" },
	On = { "ON", "LIGADO" },
	Off = { "OFF", "DESLIGADO" },
	Admin = { "Admin", "Admin" },
	Ready = { "READY!", "PRONTO!" },
	AdminInfo = { "Runs in ALL servers - great for live streams!", "Vale em TODOS os servidores - ótimo para lives!" },
	AdminLuck = { "LUCK x%d (%d min)", "SORTE x%d (%d min)" },
	AdminGolden = { "GOLDEN RAIN", "CHUVA DOURADA" },
	AdminParty = { "UPDATE PARTY NOW", "FESTÃO AGORA" },
	AdminMoney = { "2x MONEY (%d min)", "2x DINHEIRO (%d min)" },
	AdminPumpkin = { "PUMPKIN RAIN", "CHUVA DE ABÓBORAS" },
	TapConfirm = { "TAP AGAIN TO CONFIRM", "TOQUE DE NOVO PARA CONFIRMAR" },
	AutoRun = { "AUTO RUN", "AUTO CORRER" },
	AutoRunOn = { "AUTO RUN: ON", "AUTO: LIGADO" },
	PerStep = { "+%s/step", "+%s/passo" },
	Streak = { "STREAK x%.2f", "SEQUÊNCIA x%.2f" },
	ToGo = { "%s: %s to go", "%s: faltam %s" },
	MaxZone = { "MAX SPEED ZONE!", "ZONA MÁXIMA!" },
	ZoneUnlocked = { "NEW ZONE UNLOCKED: %s!", "ZONA NOVA LIBERADA: %s!" },
	CarryRun = { "\u{1F3C3} RUN BACK TO THE SAFE ZONE!", "\u{1F3C3} VOLTE PARA A ZONA SEGURA!" },
	HintCarry = { "\u{1F3C3} Run back to the SAFE ZONE with the egg!", "\u{1F3C3} Volte para a ZONA SEGURA com o ovo!" },
	HintSteal = { "\u{1F95A} Go into %s and %s on an egg to STEAL it!", "\u{1F95A} Vá até %s e %s num ovo para ROUBAR!" },
	HoldButton = { "hold the button", "segure o botão" },
	HoldE = { "hold E", "segure E" },
	HintHatch = { "\u{1F423} Your egg is READY! Walk to it (or open Eggs) and HATCH it!", "\u{1F423} Seu ovo está PRONTO! Vá até ele (ou abra Ovos) e CHOQUE!" },
	HintGrowing = { "\u{23F3} Your egg is growing... steal MORE eggs while you wait!", "\u{23F3} Seu ovo está crescendo... roube MAIS ovos enquanto espera!" },
	HintIndex = { "\u{1F4D6} NEW CRITTER! Open the INDEX (left) and CLAIM your free cash!", "\u{1F4D6} BICHINHO NOVO! Abra o ÍNDICE (esquerda) e PEGUE o dinheiro grátis!" },
	HintBuyPen = { "\u{1F3E1} Buy PEN LEVEL 1 at the yellow board to unlock your TREADMILL!", "\u{1F3E1} Compre o CERCADO NÍVEL 1 na placa amarela para liberar a ESTEIRA!" },
	HintSavePen = { "\u{1F4B5} Your pets make money! Save %s to unlock the treadmill.", "\u{1F4B5} Seus pets dão dinheiro! Junte %s para liberar a esteira." },
	HintTread = { "\u{1F45F} Stand on your TREADMILL and tap AUTO RUN to get FASTER!", "\u{1F45F} Suba na sua ESTEIRA e toque em AUTO CORRER para ficar MAIS RÁPIDO!" },
	HintBat = { "\u{2694}\u{FE0F} Use your BAT to make egg thieves drop their egg! Traps catch them too.", "\u{2694}\u{FE0F} Use o TACO para o ladrão soltar o ovo! As armadilhas também pegam." },
}
local function L(key: string): string
	local entry = TEXTS[key]
	if not entry then
		return key
	end
	return if PT_BR then entry[2] else entry[1]
end

-- etiqueta [VIP] no chat
pcall(function()
	local TextChatService = game:GetService("TextChatService")
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local who = source and Players:GetPlayerByUserId(source.UserId)
		if who and table.find(string.split(who:GetAttribute("Passes") or "", ","), "VIP") then
			props.PrefixText = '<font color="#FFD23C">[VIP]</font> ' .. message.PrefixText
		end
		return props
	end
end)
local SoundService = game:GetService("SoundService")

---------------------------------------------------------------------
-- SONS (ids em Config.Sounds)
---------------------------------------------------------------------
local soundCache: { [string]: Sound } = {}
local function sfx(name: string, pitch: number?)
	local info = Config.Sounds[name]
	if not info or player:GetAttribute("Muted") then
		return
	end
	local template = soundCache[name]
	if not template then
		template = Instance.new("Sound")
		template.Name = "Sfx_" .. name
		template.SoundId = "rbxassetid://" .. tostring(info.Id)
		template.Volume = info.Volume or 0.6
		template.Parent = SoundService
		soundCache[name] = template
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(12, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end
-- som no mundo (os outros ouvem perto de onde aconteceu)
local function sfxAt(name: string, position: Vector3)
	local info = Config.Sounds[name]
	if not info or player:GetAttribute("Muted") then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(info.Id)
	sound.Volume = (info.Volume or 0.6) * 1.4
	sound.RollOffMaxDistance = 140
	sound.Parent = holder
	sound:Play()
	task.delay(6, function()
		holder:Destroy()
	end)
end
-- música de fundo
task.spawn(function()
	local info = Config.Sounds.Music
	if info then
		local music = Instance.new("Sound")
		music.Name = "Music"
		music.SoundId = "rbxassetid://" .. tostring(info.Id)
		music.Volume = info.Volume or 0.2
		music.Looped = true
		music.Parent = SoundService
		music:Play()
	end
end)

-- câmera atrás do personagem, olhando para onde ele está virado (spawn olha para as zonas)
local function faceCameraForward()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return
	end
	local look = root.CFrame.LookVector
	camera.CFrame = CFrame.lookAt(root.Position - look * 18 + Vector3.new(0, 8, 0), root.Position + look * 6)
end
player.CharacterAdded:Connect(function()
	-- o servidor teleporta para o cercado logo depois de nascer
	task.delay(0.6, faceCameraForward)
	task.delay(1.2, faceCameraForward)
end)
local create, text, button, corner, stroke = Theme.create, Theme.text, Theme.button, Theme.corner, Theme.stroke
Theme.OnClick = function()
	sfx("Click")
end
local GREEN_TEXT = Color3.fromRGB(110, 255, 90)
local PINK_TEXT = Color3.fromRGB(255, 70, 140)

local function decode(attribute: string, default)
	local raw = player:GetAttribute(attribute)
	if type(raw) ~= "string" or raw == "" then
		return default
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then value else default
end

-- PREÇO DE VERDADE (v65): com o Regional Pricing a Roblox pode cobrar outro preço em cada país.
-- Pergunta à Roblox uma vez por item e guarda; até responder, mostra o Price do Config.
local MarketplaceService = game:GetService("MarketplaceService")
local livePrice: { [number]: number } = {}
local askedPrice: { [number]: boolean } = {}
local function robuxPrice(info): number
	local id = info.Id
	if type(id) ~= "number" or id <= 0 then
		return info.Price or 0
	end
	if livePrice[id] then
		return livePrice[id]
	end
	if not askedPrice[id] then
		askedPrice[id] = true
		local isPass = Config.PassByKey[info.Key] == info
		task.spawn(function()
			local ok, result = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
			end)
			if ok and type(result) == "table" and type(result.PriceInRobux) == "number" then
				livePrice[id] = result.PriceInRobux
			end
		end)
	end
	return info.Price or 0
end
task.defer(function()
	for _, info in Config.Passes do
		robuxPrice(info)
	end
	for _, info in Config.Products do
		robuxPrice(info)
	end
end)

local gui = create("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local uiScale = create("UIScale", { Parent = gui })
local fitWindows: (() -> ())? = nil -- (definida depois que as janelas existem)
local function rescale()
	local size = workspace.CurrentCamera.ViewportSize
	-- arredonda (no celular o tamanho da tela muda um pouquinho toda hora e o texto ficava piscando)
	local scale = math.clamp(math.min(size.X / 1366, size.Y / 768), 0.4, 1.15)
	if TOUCH then
		-- celular: um pouco menor, mas NO MÍNIMO 0.6 (v66: antes caía para 0.40 e ficava tudo minúsculo).
		-- Janela que não cabe nesse tamanho encolhe sozinha (fitWindows).
		scale = math.max(scale * 0.85, 0.6)
	end
	scale = math.floor(scale * 20 + 0.5) / 20
	if math.abs(uiScale.Scale - scale) > 0.001 then
		uiScale.Scale = scale
	end
	if fitWindows then
		fitWindows()
	end
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

---------------------------------------------------------------------
-- HUD: velocidade e dinheiro (embaixo, à esquerda)
---------------------------------------------------------------------
local stats = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(330, 136), BackgroundTransparency = 1, Parent = gui })
text({ Size = UDim2.fromOffset(56, 52), Text = "\u{1F45F}", Stroke = 0, Parent = stats })
local speedText = text({ Size = UDim2.new(1, -64, 0, 56), Position = UDim2.fromOffset(62, -2), Text = "10", TextColor3 = PINK_TEXT, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4.5, Parent = stats })
text({ Size = UDim2.fromOffset(56, 52), Position = UDim2.fromOffset(0, 58), Text = "\u{1F4B5}", Stroke = 0, Parent = stats })
local moneyText = text({ Size = UDim2.new(1, -64, 0, 56), Position = UDim2.fromOffset(62, 56), Text = "$0", TextColor3 = GREEN_TEXT, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4.5, Parent = stats })
local incomeText = text({ Size = UDim2.new(1, -64, 0, 22), Position = UDim2.fromOffset(64, 112), Text = "+$0/s", TextColor3 = Color3.fromRGB(255, 230, 120), TextXAlignment = Enum.TextXAlignment.Left, Parent = stats })

-- relógios (embaixo, à direita): boosts ativos e noite
local clocks = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -108, 1, -14), Size = UDim2.fromOffset(300, 120), BackgroundTransparency = 1, Parent = gui })
-- celular: tira dinheiro/velocidade de baixo do joystick e os relógios de baixo do botão de pular
if game:GetService("UserInputService").TouchEnabled then
	stats.AnchorPoint = Vector2.new(1, 1)
	stats.Position = UDim2.new(0.5, -70, 1, -10)
	clocks.Position = UDim2.new(1, -108, 1, -125)
end
local boostIcon = text({ Size = UDim2.fromOffset(52, 50), Text = "\u{1F9EA}", Stroke = 0, Visible = false, Parent = clocks })
local boostText = text({ Size = UDim2.new(1, -60, 0, 50), Position = UDim2.fromOffset(58, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, Visible = false, Parent = clocks })
local nightIcon = text({ Size = UDim2.fromOffset(52, 50), Position = UDim2.fromOffset(0, 62), Text = "\u{1F319}", Stroke = 0, Parent = clocks })
local nightText = text({ Size = UDim2.new(1, -60, 0, 50), Position = UDim2.fromOffset(58, 62), Text = "in 5m 0s", TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, Parent = clocks })
-- BICHO DA SEMANA (em cima do contador da sorte)
do
	text({ Size = UDim2.fromOffset(52, 50), Position = UDim2.fromOffset(0, -124), Text = "\u{2B50}", Stroke = 0, Parent = clocks })
	local weeklyText = text({ Size = UDim2.new(1, -60, 0, 50), Position = UDim2.fromOffset(58, -124), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, TextColor3 = Color3.fromRGB(255, 220, 90), Parent = clocks })
	task.spawn(function()
		while true do
			local t = workspace:GetServerTimeNow()
			local def = Critters.ById[Config.WeeklyCritter(math.floor(t))]
			local left = Config.WeeklyEnds(math.floor(t)) - t
			if def then
				weeklyText.Text = ("%s x%d! %dd %dh"):format(def.Name, Config.WeeklyMult, math.floor(left / 86400), math.floor(left % 86400 / 3600))
			end
			task.wait(30)
		end
	end)
end
-- FESTÃO / ATUALIZAÇÃO DA SEMANA (v65): "UPDATE in 2d 5h" e, na hora, "PARTY x5! 23:10"
do
	text({ Size = UDim2.fromOffset(52, 50), Position = UDim2.fromOffset(0, -186), Text = "\u{1F389}", Stroke = 0, Parent = clocks })
	local partyText = text({ Size = UDim2.new(1, -60, 0, 50), Position = UDim2.fromOffset(58, -186), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, Parent = clocks })
	task.spawn(function()
		while true do
			local t = workspace:GetServerTimeNow()
			local start, finish = Config.PartyWindow(math.floor(t))
			if t >= start then
				local left = math.max(0, finish - t)
				partyText.Text = ("PARTY x%d! %d:%02d"):format(Config.Update.PartyLuck, math.floor(left / 60), math.floor(left % 60))
				partyText.TextColor3 = Color3.fromRGB(255, 200, 80)
			else
				local left = start - t
				partyText.Text = if left >= 86400 then ("UPDATE in %dd %dh"):format(math.floor(left / 86400), math.floor(left % 86400 / 3600))
					elseif left >= 3600 then ("UPDATE in %dh %dm"):format(math.floor(left / 3600), math.floor(left % 3600 / 60))
					else ("UPDATE in %d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
				partyText.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
			task.wait(1)
		end
	end)
end
-- evento da sorte (raros x3): contador sempre visível, para a criança esperar por ele
do
text({ Size = UDim2.fromOffset(52, 50), Position = UDim2.fromOffset(0, -62), Text = "\u{1F340}", Stroke = 0, Parent = clocks })
local luckyText = text({ Size = UDim2.new(1, -60, 0, 50), Position = UDim2.fromOffset(58, -62), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, Parent = clocks })
task.spawn(function()
	while true do
		local t = workspace:GetServerTimeNow()
		local start = t - t % Config.LuckyEvery
		local activeLeft = start + Config.LuckyLength - t
		if activeLeft > 0 then
			luckyText.Text = ("LUCKY x%d! %d:%02d"):format(Config.LuckyMult, math.floor(activeLeft / 60), math.floor(activeLeft % 60))
			luckyText.TextColor3 = Color3.fromRGB(120, 255, 120)
		else
			local left = start + Config.LuckyEvery - t
			luckyText.Text = ("Lucky in %d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
			luckyText.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		task.wait(1)
	end
end)
end

---------------------------------------------------------------------
-- Janelas
---------------------------------------------------------------------
local windows: { [string]: Frame } = {}
local onOpen: { [string]: () -> () } = {}
local function open(name: string, toggle: boolean?)
	for key, window in windows do
		if key ~= name then
			window.Visible = false
		end
	end
	local window = windows[name]
	if not window then
		return
	end
	if toggle and window.Visible then
		window.Visible = false
		return
	end
	window.Visible = true
	Theme.popIn(window)
	if onOpen[name] then
		onOpen[name]()
	end
end

local function scroller(parent: Instance, props: { [string]: any }?, grid: Vector2?): ScrollingFrame
	local frame = create("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(200, 200, 210),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 12,
		Parent = parent,
	})
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	if grid then
		create("UIGridLayout", { CellSize = UDim2.fromOffset(grid.X, grid.Y), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	else
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	end
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = frame })
	return frame
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- linha de loja: ícone, título, subtítulo, botão
local function shopRow(parent: Instance, order: number, icon: string, title: string, sub: string, buttonText: string, buttonColor: Color3, onClick, accent: Color3?)
	local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 96), BackgroundColor3 = Color3.fromRGB(62, 62, 74), ZIndex = 12, Parent = parent }, { corner(12), stroke(3) })
	local iconBox = create("Frame", { Size = UDim2.fromOffset(78, 78), Position = UDim2.fromOffset(9, 9), BackgroundColor3 = accent or Color3.fromRGB(90, 90, 110), ZIndex = 13, Parent = row }, { corner(10), stroke(3) })
	Theme.gloss(iconBox, 0.3)
	text({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = icon, Stroke = 0, ZIndex = 14, Parent = iconBox })
	text({ Size = UDim2.new(1, -310, 0, 40), Position = UDim2.fromOffset(100, 10), Text = title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = row })
	text({ Size = UDim2.new(1, -310, 0, 30), Position = UDim2.fromOffset(100, 54), Text = sub, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 215, 255), Stroke = 2, ZIndex = 13, Parent = row })
	local btn = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(190, 66), BackgroundColor3 = buttonColor, ZIndex = 13, Parent = row }, buttonText, onClick)
	return row, btn
end

---------------------------------------------------------------------
-- SHOP: abas Upgrades / Trails / Boosts
---------------------------------------------------------------------
local shopWindow, shopBody = Theme.window(gui, "Shop", "Shop", Theme.Green, Vector2.new(820, 560))
windows.Shop = shopWindow
local shopTab = "Upgrades"
local shopList = scroller(shopBody, { Size = UDim2.new(1, -16, 1, -76), Position = UDim2.fromOffset(8, 68) })
local tabBar = create("Frame", { Size = UDim2.new(1, -16, 0, 54), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1, ZIndex = 12, Parent = shopBody }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local refreshShop
local tabButtons = {}
for order, info in { { "Upgrades", "\u{2B06} Upgrades", Theme.Green }, { "Trails", "\u{2728} Trails", Theme.Purple }, { "Boosts", "\u{1F9EA} Boosts", Theme.Pink }, { "Robux", "\u{1F48E} Robux", Theme.Cyan }, { "Rebirth", "\u{1F504} Rebirth", Theme.Orange } } do
	local btn = button({ LayoutOrder = order, Size = UDim2.fromOffset(148, 52), BackgroundColor3 = info[3], ZIndex = 13, Parent = tabBar }, info[2], function()
		shopTab = info[1]
		refreshShop()
	end)
	tabButtons[info[1]] = btn
end

refreshShop = function()
	for key, btn in tabButtons do
		btn.BackgroundTransparency = if key == shopTab then 0 else 0.45
	end
	clear(shopList)
	local money = player:GetAttribute("Money") or 0
	if shopTab == "Upgrades" then
		local pen = player:GetAttribute("PenLevel") or 0
		local nextPen = Config.PenLevels[pen + 1]
		shopRow(shopList, 1, "\u{1F3E1}", if pen == 0 then "Unlock Pen Level 1" else ("Upgrade Pen  (Level %d)"):format(pen),
			("%d slots%s"):format(Config.SlotCount(pen), if nextPen then ("  \u{2192}  %d slots%s"):format(Config.SlotCount(pen + 1), if pen == 0 then " + TREADMILL" else "") else "  (MAX)"),
			if nextPen then Format.Money(nextPen.Cost) else "MAX", if nextPen and money >= nextPen.Cost then Theme.Green else Theme.Gray, function()
				net:FireServer("Upgrade", "Pen")
			end, Color3.fromRGB(150, 100, 60))
		local tread = player:GetAttribute("TreadLevel") or 1
		local current = Config.Treadmills[tread]
		local nextTread = Config.Treadmills[tread + 1]
		shopRow(shopList, 2, "\u{1F3C3}", ("%s Treadmill  (Level %d)"):format(current.Name, tread),
			("+%s/step%s"):format(Format.Short(current.Gain), if nextTread then ("  \u{2192}  %s +%s/step"):format(nextTread.Name, Format.Short(nextTread.Gain)) else "  (MAX)"),
			if nextTread then Format.Money(nextTread.Cost) else "MAX", if nextTread and money >= nextTread.Cost and pen >= 1 then Theme.Green else Theme.Gray, function()
				net:FireServer("Upgrade", "Treadmill")
			end, current.Color)
		shopRow(shopList, 3, "\u{1F381}", "FREE Chest", "Join our community and open the chest every 15 min!", "Go!", Theme.Blue, function()
			shopWindow.Visible = false
		end, Color3.fromRGB(220, 50, 60))
	elseif shopTab == "Trails" then
		local owned = string.split(player:GetAttribute("Trails") or "", ",")
		local equipped = player:GetAttribute("Trail") or ""
		for order, trail in Config.Trails do
			local has = table.find(owned, trail.Id) ~= nil
			local label = if equipped == trail.Id then "EQUIPPED" elseif has then "Equip" else Format.Money(trail.Cost)
			local color = if equipped == trail.Id then Theme.Gray elseif has then Theme.Blue elseif money >= trail.Cost then Theme.Green else Theme.Red
			shopRow(shopList, order, "\u{2728}", trail.Name, ("x%s treadmill speed"):format(tostring(trail.Mult)), label, color, function()
				net:FireServer("Trail", trail.Id)
			end, trail.Color)
		end
	elseif shopTab == "Robux" then
		local passes = string.split(player:GetAttribute("Passes") or "", ",")
		local order = 0
		for _, info in Config.Passes do
			if not info.Id or info.Id <= 0 then
				continue -- ainda não criado no Creator Hub: não aparece
			end
			order += 1
			local owned = table.find(passes, info.Key) ~= nil
			shopRow(shopList, order, info.Icon, info.Name .. "  (GAMEPASS)", info.Desc, if owned then "OWNED" else ("R$ %d"):format(robuxPrice(info)), if owned then Theme.Gray else Theme.Green, function()
				if not owned then
					net:FireServer("Buy", info.Key)
				end
			end, info.Color)
		end
		for _, info in Config.Products do
			if not info.Id or info.Id <= 0 then
				continue
			end
			order += 1
			shopRow(shopList, order, info.Icon, info.Name, info.Desc or "Instant!", ("R$ %d"):format(robuxPrice(info)), Theme.Green, function()
				net:FireServer("Buy", info.Key)
			end, info.Color)
		end
	elseif shopTab == "Rebirth" then
		local rebirths = player:GetAttribute("Rebirths") or 0
		local cost = Config.RebirthCost(rebirths)
		local row = create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 360), BackgroundColor3 = Color3.fromRGB(62, 62, 74), ZIndex = 12, Parent = shopList }, { corner(12), stroke(3) })
		text({ Size = UDim2.new(1, -20, 0, 60), Position = UDim2.fromOffset(10, 10), Text = ("\u{1F504} REBIRTH %d \u{2192} %d"):format(rebirths, rebirths + 1), TextColor3 = Color3.fromRGB(255, 130, 255), ZIndex = 13, Parent = row })
		text({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 80), Text = ("Money: +%d%%  \u{2192}  +%d%%"):format(math.floor(Config.RebirthMoney * rebirths * 100), math.floor(Config.RebirthMoney * (rebirths + 1) * 100)), TextColor3 = GREEN_TEXT, ZIndex = 13, Parent = row })
		text({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 124), Text = ("Treadmill speed: +%d%%  \u{2192}  +%d%%"):format(math.floor(Config.RebirthTread * rebirths * 100), math.floor(Config.RebirthTread * (rebirths + 1) * 100)), TextColor3 = PINK_TEXT, ZIndex = 13, Parent = row })
		text({ Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 172), Text = "You KEEP your pen and Index (+ a free Rare egg!).\nYou LOSE money, speed, treadmill, trails AND ALL YOUR PETS.", TextColor3 = Color3.fromRGB(200, 210, 230), Stroke = 2, ZIndex = 13, Parent = row })
		-- rebirth leva os bichinhos: precisa tocar 2 vezes para confirmar
		local confirmUntil = 0
		local rebirthLabel
		_, rebirthLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(420, 80), BackgroundColor3 = if money >= cost then Theme.Purple else Theme.Gray, ZIndex = 13, Parent = row }, "REBIRTH  " .. Format.Money(cost), function()
			-- v65: lê o dinheiro de AGORA (antes usava o valor de quando abriu a aba e pulava a confirmação)
			if (player:GetAttribute("Money") or 0) < cost then
				net:FireServer("Rebirth") -- o servidor avisa quanto falta
			elseif os.clock() < confirmUntil then
				net:FireServer("Rebirth")
			else
				confirmUntil = os.clock() + 4
				rebirthLabel.Text = "TAP AGAIN! (pets will be lost)"
				task.delay(4, function()
					if rebirthLabel.Parent then
						rebirthLabel.Text = "REBIRTH  " .. Format.Money(cost)
					end
				end)
			end
		end)
	else
		local boosts = decode("Boosts", {})
		local income = player:GetAttribute("Income") or 0
		for order, boost in Config.Boosts do
			local price = math.max(boost.MinPrice, math.floor(income * 60 * boost.Price))
			local left = (boosts[boost.Id] or 0) - workspace:GetServerTimeNow()
			shopRow(shopList, order, boost.Icon, boost.Name, if left > 0 then ("ACTIVE: %dm %ds left"):format(left // 60, left % 60) else ("%d minutes"):format(boost.Minutes),
				Format.Money(price), if money >= price then Theme.Green else Theme.Red, function()
					net:FireServer("Boost", boost.Id)
				end, boost.Color)
		end
	end
end
onOpen.Shop = refreshShop

---------------------------------------------------------------------
-- INDEX: zonas à esquerda, cartões no meio, detalhes e prêmios à direita
---------------------------------------------------------------------
local indexWindow, indexBody = Theme.window(gui, "Index", "Pet Index", Theme.Blue, Vector2.new(1000, 580))
windows.Index = indexWindow
local indexZone = 1
local indexSelected = nil
local zoneList = scroller(indexBody, { Size = UDim2.new(0, 190, 1, -16) })
local cardArea = create("Frame", { Size = UDim2.new(1, -530, 1, -96), Position = UDim2.fromOffset(206, 8), BackgroundTransparency = 1, ZIndex = 12, Parent = indexBody })
local cardGrid = scroller(cardArea, { Size = UDim2.fromScale(1, 1), Position = UDim2.new() }, Vector2.new(128, 140))
local progressBack = create("Frame", { Size = UDim2.new(1, -730, 0, 66), Position = UDim2.new(0, 206, 1, -80), BackgroundColor3 = Color3.fromRGB(20, 20, 26), ZIndex = 12, Parent = indexBody }, { corner(10), stroke(3) })
local progressFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = progressBack }, { corner(10) })
Theme.gloss(progressFill, 0.3)
local progressText = text({ Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), Text = "0/0", ZIndex = 14, Stroke = 4, Parent = progressBack })
local batButton, batLabel = button({ Size = UDim2.fromOffset(188, 66), Position = UDim2.new(1, -512, 1, -80), BackgroundColor3 = Theme.Gray, ZIndex = 13, Parent = indexBody }, "\u{1F3CF} Bat", function()
	net:FireServer("EquipBat", indexZone)
end)
local detail = create("Frame", { Size = UDim2.new(0, 300, 1, -16), Position = UDim2.new(1, -308, 0, 8), BackgroundColor3 = Color3.fromRGB(60, 60, 72), ZIndex = 12, Parent = indexBody }, { corner(12), stroke(3) })
local detailView = create("Frame", { Size = UDim2.new(1, -20, 0, 200), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(80, 80, 95), ZIndex = 13, Parent = detail }, { corner(10) })
Theme.gloss(detailView, 0.4)
local detailName = text({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 214), Text = "", ZIndex = 13, Parent = detail })
local detailRarity = text({ Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 254), Text = "", ZIndex = 13, Parent = detail })
local detailIncome = text({ Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 288), Text = "", TextColor3 = GREEN_TEXT, ZIndex = 13, Parent = detail })
local detailReward = text({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 330), Text = "", TextColor3 = Color3.fromRGB(255, 230, 120), Stroke = 2, ZIndex = 13, Parent = detail })
local claimButton, claimLabel = button({ Size = UDim2.new(1, -40, 0, 56), Position = UDim2.new(0, 20, 1, -132), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = detail }, "CLAIM", function()
	if indexSelected then
		net:FireServer("ClaimIndex", indexSelected)
	end
end)
local claimAllButton, claimAllLabel = button({ Size = UDim2.new(1, -40, 0, 56), Position = UDim2.new(0, 20, 1, -68), BackgroundColor3 = Theme.Blue, ZIndex = 13, Parent = detail }, "CLAIM ALL", function()
	net:FireServer("ClaimIndex")
end)

local function zoneDefs(zoneIndex: number)
	local zone = Config.Zones[zoneIndex]
	local list, seen = {}, {}
	for _, rarity in zone.Rarities do
		for _, world in zone.Pool do
			local byRarity = Critters.ByWorld[world]
			for _, def in (byRarity and byRarity[rarity]) or {} do
				if not seen[def.Id] then
					seen[def.Id] = true
					table.insert(list, def)
				end
			end
		end
	end
	return list
end

local refreshIndex
local function selectPet(def, found: number?)
	indexSelected = if found then def.Id else nil
	clear(detailView)
	Theme.preview(detailView, def, not found, true)
	detailName.Text = if found then def.Name else "???"
	detailRarity.Text = def.Rarity
	detailRarity.TextColor3 = Theme.rarityColor(def.Rarity)
	local income = Config.BaseIncome(def, indexZone)
	detailIncome.Text = if found then Format.Money(income) .. "/s" else "Steal it to find out!"
	local cash, speed = Config.IndexReward(def, indexZone)
	detailReward.Text = ("Reward: %s  +%s Speed"):format(Format.Money(cash), Format.Short(speed))
	claimButton.Visible = found == 1
	claimLabel.Text = "CLAIM"
end

refreshIndex = function()
	local index = decode("Index", {})
	local unclaimed = 0
	for _, value in index do
		if value == 1 then
			unclaimed += 1
		end
	end
	claimAllLabel.Text = ("CLAIM ALL (%d)!"):format(unclaimed)
	claimAllButton.BackgroundColor3 = if unclaimed > 0 then Theme.Blue else Theme.Gray
	clear(zoneList)
	for order, zone in Config.Zones do
		local defs = zoneDefs(order)
		local count = 0
		for _, def in defs do
			if index[def.Id] then
				count += 1
			end
		end
		local btn = button({ LayoutOrder = order, Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = zone.Floor[1], ZIndex = 13, Parent = zoneList }, ("%s %s\n%d/%d"):format(zone.Emoji or "", zone.Name, count, #defs), function()
			indexZone = order
			refreshIndex()
		end)
		btn.BackgroundTransparency = if order == indexZone then 0 else 0.35
		local s = btn:FindFirstChildOfClass("UIStroke")
		if s and order == indexZone then
			s.Color = Color3.new(1, 1, 1)
		end
	end
	clear(cardGrid)
	local defs = zoneDefs(indexZone)
	local count = 0
	local first = nil
	for order, def in defs do
		local found = index[def.Id]
		if found then
			count += 1
		end
		local card = create("TextButton", { LayoutOrder = order, Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.cardColor(def.Rarity), ZIndex = 13, Parent = cardGrid }, { corner(10), stroke(3, if found == 1 then Color3.fromRGB(255, 230, 80) else Theme.Dark) })
		Theme.gloss(card, 0.35)
		Theme.preview(card, def, not found, false)
		text({ Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 4), Text = if found then def.Name else "???", ZIndex = 15, Parent = card })
		if found == 1 then
			text({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(60, 22), Text = "CLAIM!", TextColor3 = Color3.fromRGB(255, 230, 80), ZIndex = 15, Parent = card })
		end
		Theme.springy(card)
		card.Activated:Connect(function()
			selectPet(def, found)
		end)
		first = first or { def, found }
	end
	progressFill.Size = UDim2.fromScale(if #defs > 0 then count / #defs else 0, 1)
	-- o taco da zona não pede Divine/Celestial (igual ao servidor)
	local needed, have = 0, 0
	for _, def in defs do
		if (Config.RarityIndex[def.Rarity] or 1) < Config.RarityIndex.Divine then
			needed += 1
			if index[def.Id] then
				have += 1
			end
		end
	end
	local complete = needed > 0 and have == needed
	local equipped = (player:GetAttribute("Bat") or 0) == indexZone
	batLabel.Text = if equipped then "EQUIPPED" elseif complete then "EQUIP BAT!" else "\u{1F512} Zone Bat"
	batButton.BackgroundColor3 = if equipped then Theme.Gray elseif complete then Theme.Orange else Color3.fromRGB(80, 80, 90)
	progressText.Text = ("%d/%d"):format(count, #defs)
	if first then
		local keep = false
		for _, def in defs do
			if def.Id == indexSelected then
				keep = true
				selectPet(def, index[def.Id])
			end
		end
		if not keep then
			selectPet(first[1], first[2])
		end
	end
end
onOpen.Index = refreshIndex

---------------------------------------------------------------------
-- EGGS (ovos crescendo) e PETS / SELL
---------------------------------------------------------------------
local eggsWindow, eggsBody = Theme.window(gui, "Eggs", "Growing Eggs", Theme.Orange, Vector2.new(760, 520))
windows.Eggs = eggsWindow
local eggsList = scroller(eggsBody, { Size = UDim2.new(1, -16, 1, -84) })
local hatchAll = button({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.new(0, 8, 1, -68), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = eggsBody }, "\u{1F423} HATCH ALL READY", function()
	net:FireServer("HatchAll")
end)
local _ = hatchAll

local function timeText(left: number): string
	if left <= 0 then
		return "READY!"
	elseif left >= 3600 then
		return ("%dh %dm %ds"):format(left // 3600, (left % 3600) // 60, left % 60)
	elseif left >= 60 then
		return ("%dm %ds"):format(left // 60, left % 60)
	end
	return ("%ds"):format(left)
end

local function refreshEggs()
	clear(eggsList)
	local slots = decode("Slots", {})
	local any = false
	for _, slot in slots do
		local def = Critters.ById[slot.id]
		if slot.k == "Egg" and def then
			any = true
			local row = create("Frame", { LayoutOrder = slot.l or 0, Size = UDim2.new(1, -8, 0, 86), BackgroundColor3 = Color3.fromRGB(62, 62, 74), ZIndex = 12, Parent = eggsList }, { corner(12), stroke(3) })
			local box = create("Frame", { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.cardColor(def.Rarity), ZIndex = 13, Parent = row }, { corner(10), stroke(3) })
			text({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = "\u{1F95A}", Stroke = 0, ZIndex = 14, Parent = box })
			local label = Config.SizeLabel(slot.s or 1)
			text({ Size = UDim2.new(1, -330, 0, 38), Position = UDim2.fromOffset(90, 6), Text = ("%s%s Egg"):format(if label then label .. " " else "", def.Name), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = row })
			text({ Size = UDim2.new(1, -330, 0, 28), Position = UDim2.fromOffset(90, 48), Text = ("%s  \u{2022}  %s/s"):format(def.Rarity, Format.Money(slot.inc or 0)), TextColor3 = Theme.rarityColor(def.Rarity), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2, ZIndex = 13, Parent = row })
			local ready = (slot.l or 0) <= 0
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(220, 62), BackgroundColor3 = if ready then Theme.Green else Theme.Gray, ZIndex = 13, Parent = row }, if ready then "HATCH!" else timeText(slot.l or 0), function()
				net:FireServer("Hatch", slot.i)
			end)
		end
	end
	if not any then
		text({ Size = UDim2.new(1, -20, 0, 60), Text = "No eggs growing. Go STEAL some eggs!", TextColor3 = Color3.fromRGB(200, 210, 230), ZIndex = 13, Parent = eggsList })
	end
end
onOpen.Eggs = refreshEggs

local petsWindow, petsBody = Theme.window(gui, "Pets", "My Pets", Theme.Orange, Vector2.new(860, 560))
windows.Pets = petsWindow
local petsTitle = petsWindow.Header.Title
local petsGrid = scroller(petsBody, { Size = UDim2.new(1, -16, 1, -84) }, Vector2.new(150, 196))
button({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.new(0, 8, 1, -68), BackgroundColor3 = Theme.Red, ZIndex = 13, Parent = petsBody }, "\u{1F4B0} SELL ALL  (keeps Legendary+ and mutated)", function()
	net:FireServer("SellAll")
end)

local function petCard(parent: Instance, slot, def, order: number, extra: (Frame) -> ())
	local card = create("Frame", { LayoutOrder = order, BackgroundColor3 = Theme.cardColor(def.Rarity), ZIndex = 13, Parent = parent }, { corner(10), stroke(3) })
	Theme.gloss(card, 0.35)
	local view = create("Frame", { Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1, ZIndex = 13, Parent = card })
	Theme.preview(view, def, false, false)
	local label = Config.SizeLabel(slot.s or 1)
	text({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 4), Text = (if slot.m then slot.m .. " " else "") .. def.Name, ZIndex = 15, Parent = card })
	if label then
		text({ Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 82), Text = label, TextColor3 = Color3.fromRGB(255, 230, 90), ZIndex = 15, Parent = card })
	end
	text({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 102), Text = Format.Money(slot.inc or 0) .. "/s", TextColor3 = GREEN_TEXT, ZIndex = 15, Parent = card })
	extra(card)
	return card
end

local function refreshPets()
	clear(petsGrid)
	local slots = decode("Slots", {})
	local order = 0
	table.sort(slots, function(a, b)
		return (a.inc or 0) > (b.inc or 0)
	end)
	for _, slot in slots do
		local def = Critters.ById[slot.id]
		if slot.k == "Pet" and def then
			order += 1
			petCard(petsGrid, slot, def, order, function(card)
				local value = math.floor((slot.inc or 0) * 100)
				-- v65: bichinho Raro+ ou com mutação: toca 2 vezes para vender (criança vendia sem querer)
				local precious = slot.m ~= nil or (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Rare
				local confirmUntil = 0
				local sellLabel
				_, sellLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -14, 0, 52), BackgroundColor3 = Theme.Red, ZIndex = 15, Parent = card }, "Sell " .. Format.Money(value), function()
					if precious and os.clock() > confirmUntil then
						confirmUntil = os.clock() + 3
						sellLabel.Text = "Sure? Tap again!"
						task.delay(3, function()
							if sellLabel.Parent and os.clock() >= confirmUntil then
								sellLabel.Text = "Sell " .. Format.Money(value)
							end
						end)
						return
					end
					net:FireServer("Sell", { slot.i, slot.id })
					-- some na hora (a lista é refeita quando chega a resposta)
					card.Visible = false
				end)
			end)
		end
	end
	if order == 0 then
		text({ Size = UDim2.fromOffset(500, 60), Text = "No pets yet. Hatch your eggs!", TextColor3 = Color3.fromRGB(200, 210, 230), ZIndex = 13, Parent = petsGrid })
	end
end
onOpen.Pets = function()
	petsTitle.Text = "My Pets"
	refreshPets()
end
-- a barraquinha SELL abre a mesma janela com outro título
windows.Sell = petsWindow
onOpen.Sell = function()
	petsTitle.Text = "\u{1F4B0} Sell Pets"
	refreshPets()
end

---------------------------------------------------------------------
-- FUSE
---------------------------------------------------------------------
local fuseWindow, fuseBody = Theme.window(gui, "Fuse", "Fuse Machine", Theme.Cyan, Vector2.new(860, 560))
windows.Fuse = fuseWindow
local fuseGrid = scroller(fuseBody, { Size = UDim2.new(1, -16, 1, -84) }, Vector2.new(150, 160))
local fuseSelected: { number } = {}
local fuseButton, fuseLabel
local refreshFuse
fuseButton, fuseLabel = button({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.new(0, 8, 1, -68), BackgroundColor3 = Theme.Gray, ZIndex = 13, Parent = fuseBody }, "Pick 3 pets of the SAME rarity", function()
	if #fuseSelected == Config.FuseCount then
		net:FireServer("Fuse", fuseSelected)
		fuseSelected = {}
		task.delay(0.4, refreshFuse)
	end
end)
refreshFuse = function()
	clear(fuseGrid)
	local slots = decode("Slots", {})
	local rarity = nil
	for _, i in fuseSelected do
		for _, slot in slots do
			if slot.i == i then
				local def = Critters.ById[slot.id]
				rarity = def and def.Rarity
			end
		end
	end
	local order = 0
	for _, slot in slots do
		local def = Critters.ById[slot.id]
		if slot.k == "Pet" and def then
			order += 1
			local chosen = table.find(fuseSelected, slot.i) ~= nil
			local card = petCard(fuseGrid, slot, def, order, function(card)
				local pick = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 16, Parent = card })
				pick.Activated:Connect(function()
					local at = table.find(fuseSelected, slot.i)
					if at then
						table.remove(fuseSelected, at)
					elseif #fuseSelected < Config.FuseCount and (rarity == nil or rarity == def.Rarity) then
						table.insert(fuseSelected, slot.i)
					end
					refreshFuse()
				end)
			end)
			local s = card:FindFirstChildOfClass("UIStroke")
			if s and chosen then
				s.Color = Color3.fromRGB(80, 255, 255)
				s.Thickness = 5
			end
			if rarity and def.Rarity ~= rarity and not chosen then
				card.BackgroundTransparency = 0.6
			end
		end
	end
	local nextRarity = rarity and Config.Rarities[(Config.RarityIndex[rarity] or 1) + 1]
	fuseLabel.Text = if #fuseSelected == Config.FuseCount and nextRarity then ("\u{2728} FUSE \u{2192} %s EGG!"):format(string.upper(nextRarity.Name)) else ("Pick 3 pets of the SAME rarity (%d/3)"):format(#fuseSelected)
	fuseButton.BackgroundColor3 = if #fuseSelected == Config.FuseCount then Theme.Green else Theme.Gray
end
onOpen.Fuse = function()
	fuseSelected = {}
	refreshFuse()
end

-- TRAILS e BOOSTS abrem o Shop na aba certa
windows.Trails = shopWindow
onOpen.Trails = function()
	shopTab = "Trails"
	refreshShop()
end
windows.Boosts = shopWindow
onOpen.Boosts = function()
	shopTab = "Boosts"
	refreshShop()
end

---------------------------------------------------------------------
-- PRÊMIO DIÁRIO (7 dias seguidos)
---------------------------------------------------------------------
local dailyWindow, dailyBody = Theme.window(gui, "Daily", "\u{1F381} Daily Rewards", Theme.Purple, Vector2.new(900, 430))
windows.Daily = dailyWindow
local dailyRow = create("Frame", { Size = UDim2.new(1, -16, 0, 230), Position = UDim2.fromOffset(8, 10), BackgroundTransparency = 1, ZIndex = 12, Parent = dailyBody }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local dailyClaim, dailyClaimLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(420, 74), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = dailyBody }, "CLAIM!", function()
	net:FireServer("Daily")
end)
local function refreshDaily()
	clear(dailyRow)
	local streak = player:GetAttribute("DailyStreak") or 0
	local ready = player:GetAttribute("DailyReady") == true
	local nextDay = if ready then streak % #Config.Daily + 1 else streak
	for day, reward in Config.Daily do
		local done = day < nextDay or (not ready and day == nextDay)
		local current = ready and day == nextDay
		local card = create("Frame", { LayoutOrder = day, Size = UDim2.fromOffset(112, 220), BackgroundColor3 = if current then Theme.Gold elseif done then Theme.Green else Color3.fromRGB(70, 70, 86), ZIndex = 13, Parent = dailyRow }, { corner(12), stroke(if current then 5 else 3, if current then Color3.new(1, 1, 1) else Theme.Dark) })
		Theme.gloss(card, 0.35)
		text({ Size = UDim2.new(1, -8, 0, 34), Position = UDim2.fromOffset(4, 6), Text = "Day " .. day, ZIndex = 14, Parent = card })
		text({ Size = UDim2.new(1, -8, 0, 64), Position = UDim2.fromOffset(4, 44), Text = if reward.Egg then "\u{1F95A}" elseif done then "\u{2705}" else "\u{1F381}", Stroke = 0, ZIndex = 14, Parent = card })
		text({ Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 116), Text = reward.Minutes .. " min $", TextColor3 = GREEN_TEXT, ZIndex = 14, Parent = card })
		text({ Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 146), Text = "+" .. Format.Short(reward.Speed) .. " \u{1F45F}", TextColor3 = PINK_TEXT, ZIndex = 14, Parent = card })
		if reward.Egg then
			text({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 180), Text = "+ Rare Egg!", TextColor3 = Color3.fromRGB(255, 230, 90), ZIndex = 14, Parent = card })
		end
	end
	dailyClaimLabel.Text = if ready then ("CLAIM DAY %d!"):format(nextDay) else "Come back tomorrow!"
	dailyClaim.BackgroundColor3 = if ready then Theme.Green else Theme.Gray
end
onOpen.Daily = refreshDaily

---------------------------------------------------------------------
-- MISSÕES DO DIA
---------------------------------------------------------------------
local questWindow, questBody = Theme.window(gui, "Quests", "\u{1F4DC} Daily Quests", Theme.Blue, Vector2.new(820, 520))
windows.Quests = questWindow
local questList = scroller(questBody)
local function refreshQuests()
	clear(questList)
	local q = decode("Quests", { p = {}, c = {} })
	local income = player:GetAttribute("Income") or 0
	for order, info in Config.Quests do
		local progress = math.min((q.p and q.p[info.Key]) or 0, info.Goal)
		local claimed = q.c and q.c[info.Key]
		local done = progress >= info.Goal
		local cash = math.max(info.MinCash, math.floor(income * 60 * info.Minutes))
		local row = shopRow(questList, order, info.Icon, info.Name, ("%d/%d  \u{2022}  %s + %s Speed"):format(progress, info.Goal, Format.Money(cash), Format.Short(info.Speed)),
			if claimed then "CLAIMED" elseif done then "CLAIM!" else ("%d%%"):format(math.floor(progress / info.Goal * 100)),
			if claimed then Theme.Gray elseif done then Theme.Green else Color3.fromRGB(80, 80, 95), function()
				if done and not claimed then
					net:FireServer("ClaimQuest", info.Key)
				end
			end, Theme.Blue)
		-- barrinha de progresso
		local bar = create("Frame", { Size = UDim2.new(1, -310, 0, 8), Position = UDim2.new(0, 100, 1, -14), BackgroundColor3 = Color3.fromRGB(25, 25, 32), BorderSizePixel = 0, ZIndex = 13, Parent = row }, { corner(4) })
		create("Frame", { Size = UDim2.fromScale(progress / info.Goal, 1), BackgroundColor3 = if done then Theme.Green else Theme.Cyan, BorderSizePixel = 0, ZIndex = 14, Parent = bar }, { corner(4) })
	end
end
onOpen.Quests = refreshQuests
player:GetAttributeChangedSignal("Quests"):Connect(function()
	if questWindow.Visible then
		refreshQuests()
	end
end)

---------------------------------------------------------------------
-- Botões da tela
---------------------------------------------------------------------
local function wideButton(y: number, icon: string, label: string, color: Color3, onClick): TextButton
	local btn, txt = button({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, y), Size = UDim2.fromOffset(196, 66), BackgroundColor3 = color, Parent = gui }, label, onClick)
	txt.Size = UDim2.new(1, -72, 1, -10)
	txt.Position = UDim2.fromOffset(66, 5)
	txt.TextXAlignment = Enum.TextXAlignment.Left
	text({ Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(8, 7), Text = icon, Stroke = 0, Parent = btn })
	return btn
end
wideButton(-90, "\u{1F6D2}", "Shop", Theme.Green, function()
	shopTab = "Upgrades"
	open("Shop", true)
end)
local indexButton = wideButton(-14, "\u{1F4D6}", "Index", Theme.Blue, function()
	open("Index", true)
end)
-- PAINEL DE RENASCIMENTO: botão fixo com barra de progresso até o próximo rebirth
do
	local rebirthButton = wideButton(-182, "\u{1F504}", "Rebirth", Theme.Purple, function()
		shopTab = "Rebirth"
		open("Shop", true)
	end)
	local barBack = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = Color3.fromRGB(40, 30, 60), Parent = rebirthButton }, { corner(9), stroke(2) })
	local barFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 120, 255), Parent = barBack }, { corner(9) })
	local barText = text({ Size = UDim2.fromScale(1, 1), Text = "", Stroke = 2, ZIndex = 3, Parent = barBack })
	local rebirthBadge = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Theme.Red, Visible = false, Parent = rebirthButton }, { corner(15), stroke(3, Color3.new(1, 1, 1)) })
	text({ Size = UDim2.fromScale(1, 1), Text = "!", Parent = rebirthBadge })
	task.spawn(function()
		while true do
			local rebirths = player:GetAttribute("Rebirths") or 0
			local cost = Config.RebirthCost(rebirths)
			local money = player:GetAttribute("Money") or 0
			local p = math.clamp(money / cost, 0, 1)
			barFill.Size = UDim2.fromScale(p, 1)
			barText.Text = if p >= 1 then "READY! \u{1F504} " .. (rebirths + 1) else ("%d%%  (x%d)"):format(math.floor(p * 100), rebirths)
			rebirthBadge.Visible = p >= 1
			task.wait(0.5)
		end
	end)
end

local indexBadge = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Theme.Red, Visible = false, Parent = indexButton }, { corner(16), stroke(3, Color3.new(1, 1, 1)) })
local indexBadgeText = text({ Size = UDim2.fromScale(1, 1), Text = "0", Parent = indexBadge })

-- Slow Mode (botão liga/desliga)
local slowOn = false
local slowFrame = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 52), Size = UDim2.fromOffset(196, 40), BackgroundTransparency = 1, Parent = gui })
local switch = create("TextButton", { Size = UDim2.fromOffset(80, 36), Text = "", BackgroundColor3 = Color3.fromRGB(60, 45, 45), AutoButtonColor = false, Parent = slowFrame }, { corner(8), stroke(3) })
local knob = create("Frame", { Size = UDim2.fromOffset(32, 28), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = Theme.Green, Parent = switch }, { corner(6) })
text({ Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(90, 0), Text = "Slow Mode", TextXAlignment = Enum.TextXAlignment.Left, Parent = slowFrame })
switch.Activated:Connect(function()
	slowOn = not slowOn
	net:FireServer("SlowMode", slowOn)
	TweenService:Create(knob, TweenInfo.new(0.15), { Position = UDim2.fromOffset(if slowOn then 44 else 4, 4) }):Play()
	switch.BackgroundColor3 = if slowOn then Color3.fromRGB(40, 110, 50) else Color3.fromRGB(60, 45, 45)
end)

local function squareButton(y: number, icon: string, color: Color3, label: string, onClick)
	local btn = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, y), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = color, Parent = gui }, "", onClick)
	text({ Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.14, 0.06), Text = icon, Stroke = 0, Parent = btn })
	text({ Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0, 3, 1, -24), Text = label, Parent = btn })
	return btn
end
squareButton(-104, "\u{1F95A}", Theme.Red, "Eggs", function()
	open("Eggs", true)
end)
squareButton(-8, "\u{1F43E}", Theme.Orange, "Pets", function()
	open("Pets", true)
end)
squareButton(88, "\u{1F9EA}", Theme.Green, "Boosts", function()
	shopTab = "Boosts"
	open("Shop", true)
end)
local dailyButton = squareButton(184, "\u{1F381}", Theme.Purple, "Daily", function()
	open("Daily", true)
end)
local dailyBadge = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 6, 0, 6), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Theme.Red, Visible = false, Parent = dailyButton }, { corner(15), stroke(3, Color3.new(1, 1, 1)) })
text({ Size = UDim2.fromScale(1, 1), Text = "!", Parent = dailyBadge })
local questButton = squareButton(280, "\u{1F4DC}", Theme.Blue, "Quests", function()
	open("Quests", true)
end)
local questBadge = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 6, 0, 6), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Theme.Red, Visible = false, Parent = questButton }, { corner(15), stroke(3, Color3.new(1, 1, 1)) })
text({ Size = UDim2.fromScale(1, 1), Text = "!", Parent = questBadge })
local function updateQuestBadge()
	local q = decode("Quests", { p = {}, c = {} })
	local ready = false
	for _, info in Config.Quests do
		if ((q.p and q.p[info.Key]) or 0) >= info.Goal and not (q.c and q.c[info.Key]) then
			ready = true
		end
	end
	questBadge.Visible = ready
end
player:GetAttributeChangedSignal("Quests"):Connect(updateQuestBadge)
task.defer(updateQuestBadge)

---------------------------------------------------------------------
-- PRESENTES POR TEMPO JOGADO (botão "Gifts" com contador)
---------------------------------------------------------------------
do
	local giftWindow, giftBody = Theme.window(gui, "Gifts", "\u{1F381} Free Gifts", Theme.Pink, Vector2.new(820, 560))
	windows.Gifts = giftWindow
	local giftList = scroller(giftBody)
	local function playedSeconds(): number
		local start = player:GetAttribute("SessionStart")
		return if typeof(start) == "number" then workspace:GetServerTimeNow() - start else 0
	end
	local function giftClaimed(index: number): boolean
		return table.find(string.split(player:GetAttribute("GiftsClaimed") or "", ","), tostring(index)) ~= nil
	end
	local function refreshGifts()
		clear(giftList)
		local played = playedSeconds()
		local income = player:GetAttribute("Income") or 0
		for index, info in Config.Gifts do
			local left = info.Minutes * 60 - played
			local claimed = giftClaimed(index)
			local cash = math.max(info.MinCash, math.floor(income * 60 * info.Cash))
			local label = if claimed then "CLAIMED" elseif left <= 0 then "CLAIM!" else ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
			local color = if claimed then Theme.Gray elseif left <= 0 then Theme.Green else Color3.fromRGB(90, 90, 110)
			shopRow(giftList, index, if info.Egg then "\u{1F95A}" else "\u{1F381}", ("Gift %d%s"):format(index, if info.Egg then "  - RARE EGG!" else ""),
				("+%s  +%s Speed"):format(Format.Money(cash), Format.Short(info.Speed)), label, color, function()
					if not claimed and left <= 0 then
						net:FireServer("Gift", index)
					end
				end, Color3.fromRGB(255, 110, 190))
		end
	end
	onOpen.Gifts = refreshGifts
	local giftButton = squareButton(-212, "\u{1F381}", Theme.Pink, "Gifts", function()
		open("Gifts", true)
	end)
	local giftBadge = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 6, 0, 6), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Theme.Red, Visible = false, Parent = giftButton }, { corner(15), stroke(3, Color3.new(1, 1, 1)) })
	text({ Size = UDim2.fromScale(1, 1), Text = "!", Parent = giftBadge })
	local giftTimer = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(110, 24), Text = "", TextColor3 = Color3.fromRGB(255, 200, 235), Parent = giftButton })
	task.spawn(function()
		while true do
			task.wait(1)
			local played = playedSeconds()
			local ready, nextLeft = false, nil
			for index, info in Config.Gifts do
				if not giftClaimed(index) then
					local left = info.Minutes * 60 - played
					if left <= 0 then
						ready = true
					elseif not nextLeft or left < nextLeft then
						nextLeft = left
					end
				end
			end
			giftBadge.Visible = ready
			giftTimer.Text = if ready then "READY!" elseif nextLeft then ("%d:%02d"):format(math.floor(nextLeft / 60), math.floor(nextLeft % 60)) else ""
			if giftWindow.Visible then
				refreshGifts()
			end
		end
	end)
	
end

---------------------------------------------------------------------
-- CÓDIGOS (v65): botão à esquerda (em cima do Rebirth) + janela para digitar
---------------------------------------------------------------------
do
	local codeWindow, codeBody = Theme.window(gui, "Codes", "\u{1F39F} Codes", Theme.Cyan, Vector2.new(640, 330))
	windows.Codes = codeWindow
	text({ Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 12), Text = "New codes every Saturday update - check our group!", TextColor3 = Color3.fromRGB(190, 215, 255), Stroke = 2, ZIndex = 13, Parent = codeBody })
	local box = create("TextBox", {
		Size = UDim2.new(1, -24, 0, 72),
		Position = UDim2.fromOffset(12, 56),
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
		Text = "",
		PlaceholderText = "Type a code here",
		PlaceholderColor3 = Color3.fromRGB(140, 140, 155),
		TextColor3 = Color3.fromRGB(30, 30, 40),
		Font = Theme.Font,
		TextScaled = true,
		ClearTextOnFocus = false,
		ZIndex = 13,
		Parent = codeBody,
	}, { corner(10), stroke(3) })
	create("UITextSizeConstraint", { MaxTextSize = 44, Parent = box })
	button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 142), Size = UDim2.fromOffset(260, 66), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = codeBody }, "REDEEM", function()
		if box.Text ~= "" then
			net:FireServer("Redeem", string.sub(box.Text, 1, 30))
		end
	end)
	wideButton(-258, "\u{1F39F}", "Codes", Theme.Cyan, function()
		open("Codes", true)
	end)
	net.OnClientEvent:Connect(function(kind)
		if kind == "CodeOk" then
			box.Text = ""
			codeWindow.Visible = false
		end
	end)
end

---------------------------------------------------------------------
-- HALLOWEEN (v65): botão com os doces + Loja de Doces (só aparece durante o evento)
---------------------------------------------------------------------
do
	local candyWindow, candyBody = Theme.window(gui, "Halloween", "\u{1F383} Candy Shop", Theme.Orange, Vector2.new(820, 560))
	windows.Halloween = candyWindow
	local header = text({ Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 10), Text = "", TextColor3 = Color3.fromRGB(255, 200, 120), ZIndex = 13, Parent = candyBody })
	local candyList = scroller(candyBody, { Size = UDim2.new(1, -16, 1, -64), Position = UDim2.fromOffset(8, 56) })
	local ICONS = { pumpkinopinguino = "\u{1F427}", pumpkat = "\u{1F431}", batwing = "\u{1F987}", vampiropepperoni = "\u{1F9DB}" }
	local function refreshCandy()
		local candy = player:GetAttribute("Candy") or 0
		header.Text = ("\u{1F36C} %d candy  -  steal eggs: +%d  |  Pumpkin Eggs: +%d"):format(candy, Config.Halloween.CandyPerEgg, Config.Halloween.CandyPerPumpkin)
		clear(candyList)
		for index, item in Config.Halloween.Shop do
			local def = Critters.ById[item.Critter]
			if def then
				shopRow(candyList, index, ICONS[item.Critter] or "\u{1F383}", ("%s%s"):format(if item.Mut then item.Mut .. " " else "", def.Name),
					("%s  -  ready to hatch!"):format(string.upper(def.Rarity)), ("\u{1F36C} %d"):format(item.Cost),
					if candy >= item.Cost then Theme.Green else Theme.Gray, function()
						net:FireServer("CandyBuy", index)
					end, Theme.rarityColor(def.Rarity))
			end
		end
	end
	onOpen.Halloween = refreshCandy
	local candyButton = wideButton(-334, "\u{1F383}", "Candy", Theme.Orange, function()
		open("Halloween", true)
	end)
	local candyLabel = candyButton:FindFirstChild("Label") :: TextLabel
	local function update()
		local on = workspace:GetAttribute("Halloween") == true
		candyButton.Visible = on
		candyLabel.Text = ("Candy %d"):format(player:GetAttribute("Candy") or 0)
		if not on then
			candyWindow.Visible = false
		elseif candyWindow.Visible then
			refreshCandy()
		end
	end
	workspace:GetAttributeChangedSignal("Halloween"):Connect(update)
	player:GetAttributeChangedSignal("Candy"):Connect(update)
	task.defer(update)
end

---------------------------------------------------------------------
-- OFERTA NA HORA CERTA (cartão pequeno à direita; some sozinho)
---------------------------------------------------------------------
local showOffer
do
	local offerCard = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, -40), Size = UDim2.fromOffset(340, 210), BackgroundColor3 = Color3.fromRGB(255, 140, 50), Visible = false, ZIndex = 25, Parent = gui }, { corner(16), stroke(4) })
	Theme.gloss(offerCard, 0.3)
	local offerIcon = text({ Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 10), Text = "\u{1F381}", Stroke = 0, ZIndex = 26, Parent = offerCard })
	local offerTitle = text({ Size = UDim2.new(1, -100, 0, 40), Position = UDim2.fromOffset(86, 12), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 26, Parent = offerCard })
	local offerDesc = text({ Size = UDim2.new(1, -100, 0, 28), Position = UDim2.fromOffset(86, 52), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 245, 220), Stroke = 2, ZIndex = 26, Parent = offerCard })
	local offerReason = text({ Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 88), Text = "", Stroke = 2, ZIndex = 26, Parent = offerCard })
	local offerKey = nil
	local _, offerBuyLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(220, 62), BackgroundColor3 = Theme.Green, ZIndex = 26, Parent = offerCard }, "R$ 0", function()
		if offerKey then
			net:FireServer("Buy", offerKey)
		end
		offerCard.Visible = false
	end)
	button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = Theme.Red, ZIndex = 27, Parent = offerCard }, "X", function()
		offerCard.Visible = false
	end)
	local offerSerial = 0
	showOffer = function(key: string, reason: string?)
		local info = Config.ProductByKey[key] or Config.PassByKey[key]
		if not info then
			return
		end
		offerKey = key
		offerIcon.Text = info.Icon or "\u{1F381}"
		offerTitle.Text = info.Name
		offerDesc.Text = info.Desc or ""
		offerReason.Text = reason or ""
		offerBuyLabel.Text = ("R$ %d"):format(robuxPrice(info))
		offerCard.BackgroundColor3 = info.Color or Color3.fromRGB(255, 140, 50)
		offerCard.Visible = true
		Theme.popIn(offerCard)
		sfx("Pop")
		offerSerial += 1
		local mine = offerSerial
		task.delay(14, function()
			if offerSerial == mine then
				offerCard.Visible = false
			end
		end)
	end
end

-- som ligado/desligado e convidar amigos (embaixo do Slow Mode)
local soundOn = true
local soundButton = button({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 108), Size = UDim2.fromOffset(92, 48), BackgroundColor3 = Theme.Purple, Parent = gui }, "\u{1F50A}", function()
	soundOn = not soundOn
	player:SetAttribute("Muted", not soundOn)
	local music = SoundService:FindFirstChild("Music")
	if music then
		music.Volume = if soundOn then (Config.Sounds.Music.Volume or 0.2) else 0
	end
end)
local _ = soundButton
-- (v65: o botão dizia "+25%", mas o bônus é por AMIGO JOGANDO junto, não por convite enviado)
button({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 114, 0.5, 108), Size = UDim2.fromOffset(96, 48), BackgroundColor3 = Theme.Orange, Parent = gui }, "\u{1F465} Invite", function()
	pcall(function()
		game:GetService("SocialService"):PromptGameInvite(player)
	end)
end)

task.delay(6, function()
	if player:GetAttribute("DailyReady") == true then
		open("Daily")
	end
end)

---------------------------------------------------------------------
-- Faixa grande e avisos
---------------------------------------------------------------------
local bannerText = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(900, 86), Text = "", Stroke = 6, Visible = false, ZIndex = 30, Parent = gui })
local bannerToken = 0
local function showBanner(message: string, color: Color3?)
	bannerToken += 1
	local token = bannerToken
	bannerText.Text = message
	bannerText.TextColor3 = color or Color3.new(1, 1, 1)
	bannerText.Visible = true
	Theme.popIn(bannerText)
	task.delay(3.2, function()
		if bannerToken == token then
			bannerText.Visible = false
		end
	end)
end

local toastHolder = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(640, 230), BackgroundTransparency = 1, ZIndex = 30, Parent = gui }, {
	create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toastColors = { info = Color3.fromRGB(50, 120, 230), success = Color3.fromRGB(40, 170, 70), warning = Color3.fromRGB(235, 150, 30), error = Color3.fromRGB(215, 45, 60), rare = Color3.fromRGB(165, 70, 240) }
local toastOrder = 0
local function showToast(message: string, kind: string?)
	toastOrder += 1
	local frame = create("Frame", { LayoutOrder = toastOrder, Size = UDim2.fromOffset(620, 42), BackgroundColor3 = toastColors[kind or "info"] or toastColors.info, ZIndex = 30, Parent = toastHolder }, { corner(10), stroke(3) })
	Theme.gloss(frame, 0.3)
	text({ Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Text = message, ZIndex = 31, Parent = frame })
	local items = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(items, child)
		end
	end
	if #items > 4 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(4.5, function()
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

-- chuva de moedas na tela (roubar / vender / presente)
local function coinBurst(count: number?, color: Color3?)
	for _ = 1, count or 18 do
		local coin = text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(44, 44),
			Text = if color then "\u{2B50}" else "\u{1FA99}",
			Stroke = 0,
			ZIndex = 35,
			Parent = gui,
		})
		local target = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.7, 0.55 + (math.random() - 0.6) * 0.6)
		TweenService:Create(coin, TweenInfo.new(0.5 + math.random() * 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target, Rotation = math.random(-90, 90) }):Play()
		task.delay(0.8, function()
			-- as moedas voam para o dinheiro (canto de baixo à esquerda)
			TweenService:Create(coin, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, 120, 1, -60), TextTransparency = 1 }):Play()
		end)
		task.delay(1.4, function()
			coin:Destroy()
		end)
	end
end

-- MOMENTO ÉPICO (servidor inteiro): faixa gigante no meio da tela, tela treme, som e estrelas
local epicLabel = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(1000, 80), Text = "", Stroke = 6, Visible = false, ZIndex = 50, Parent = gui })
local epicSerial = 0
function showEpic(message: string, color: Color3?)
	epicSerial += 1
	local mine = epicSerial
	epicLabel.Text = message
	epicLabel.TextColor3 = if typeof(color) == "Color3" then color else Color3.fromRGB(255, 220, 60)
	epicLabel.Visible = true
	epicLabel.Rotation = -4
	epicLabel.Size = UDim2.fromOffset(500, 40)
	TweenService:Create(epicLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(1000, 80), Rotation = 0 }):Play()
	sfx("Alarm", 1.2)
	sfx("Delivered")
	coinBurst(20, epicLabel.TextColor3)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		task.spawn(function()
			for k = 1, 14 do
				humanoid.CameraOffset = Vector3.new(math.random(-10, 10) / 18, math.random(-10, 10) / 18, 0) * (1 - k / 14)
				task.wait(0.03)
			end
			humanoid.CameraOffset = Vector3.zero
		end)
	end
	task.delay(4, function()
		if epicSerial == mine then
			epicLabel.Visible = false
		end
	end)
end

local function floatText(message: string, color: Color3)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local board = create("BillboardGui", { Size = UDim2.fromScale(6, 2), StudsOffsetWorldSpace = Vector3.new(math.random(-15, 15) / 10, 2, 0), Adornee = head, AlwaysOnTop = true, Parent = gui })
	local label = text({ Size = UDim2.fromScale(1, 1), Text = message, TextColor3 = color, Parent = board })
	local labelStroke = label:FindFirstChildOfClass("UIStroke")
	TweenService:Create(board, TweenInfo.new(1.2), { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
	if labelStroke then
		TweenService:Create(labelStroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	end
	task.delay(1.3, function()
		board:Destroy()
	end)
end


---------------------------------------------------------------------
-- ANIMAÇÃO DE CHOCAR: ovo treme, racha, flash e o bichinho aparece com confete
---------------------------------------------------------------------
local hatchQueue = {}
local hatchBusy = false
local hatchLayer = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 40, Active = false, Parent = gui })

local function confetti(color: Color3)
	for _ = 1, 40 do
		local piece = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = if math.random() < 0.5 then color else Color3.fromHSV(math.random(), 0.8, 1),
			BorderSizePixel = 0,
			ZIndex = 45,
			Parent = hatchLayer,
		})
		local target = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.9, 0.45 + (math.random() - 0.3) * 0.9)
		TweenService:Create(piece, TweenInfo.new(1.4 + math.random() * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target, Rotation = piece.Rotation + math.random(-360, 360), BackgroundTransparency = 1 }):Play()
		task.delay(2.2, function()
			piece:Destroy()
		end)
	end
end

local function playHatch(entry)
	local def = Critters.ById[entry[1]]
	if not def then
		return
	end
	local mutation, scale = entry[2], entry[3] or 1
	local rarityColor = Theme.rarityColor(def.Rarity)
	hatchLayer.Visible = true
	TweenService:Create(hatchLayer, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
	local rays = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1, ZIndex = 41, Parent = hatchLayer })
	for k = 0, 7 do
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 40, 1, 0), Rotation = k * 22.5, BackgroundColor3 = rarityColor, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 41, Parent = rays })
	end
	local spinning = true
	task.spawn(function()
		while spinning and rays.Parent do
			rays.Rotation += 1
			task.wait(1 / 60)
		end
	end)
	-- ovo 3D de verdade (o estilo da zona de onde ele veio) dentro de uma janelinha 3D
	local egg = create("ViewportFrame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, Ambient = Color3.fromRGB(210, 210, 210), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 43, Parent = hatchLayer })
	local eggModel
	pcall(function()
		local zone = Config.Zones[entry[4] or 1] or Config.Zones[1]
		eggModel = require(ReplicatedStorage.Shared.CritterBuilder).BuildEgg({ Name = def.Name .. " Egg", Size = 3.4, Style = zone.Egg.Style, Color = zone.Egg.Color, Accent = zone.Egg.Accent })
		eggModel:PivotTo(CFrame.new())
		eggModel.Parent = egg
		local cf, size = eggModel:GetBoundingBox()
		local cam = create("Camera", { FieldOfView = 40, CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.15, size.Y * 2.6), cf.Position), Parent = egg })
		egg.CurrentCamera = cam
	end)
	-- o ovo já tremeu e rachou NA BASE (todo mundo vê); aqui é só uma tremidinha antes de revelar
	for shake = 3, 3 do
		sfx("Crack", 0.9 + shake * 0.12)
		for _ = 1, 6 do
			local angle = math.rad(math.random(-14, 14) * shake / 2)
			if eggModel then
				eggModel:PivotTo(CFrame.Angles(0, 0, angle))
			end
			egg.Rotation = math.deg(angle) * 0.3
			task.wait(0.04)
		end
		if eggModel then
			eggModel:PivotTo(CFrame.new())
		end
		egg.Rotation = 0
		egg.Size = UDim2.fromOffset(300 + shake * 24, 300 + shake * 24)
		task.wait(0.28)
	end
	local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 46, Parent = hatchLayer })
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.55, function()
		flash:Destroy()
	end)
	egg:Destroy()
	sfx("Pop")
	if (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Legendary then
		sfx("Delivered")
	end
	local card = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 1, ZIndex = 43, Parent = hatchLayer })
	Theme.preview(card, def, false, true).ZIndex = 44
	local label = Config.SizeLabel(scale)
	local title = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 170), Size = UDim2.fromOffset(700, 64), Text = ("%s%s%s"):format(if mutation then mutation .. " " else "", if label then label .. " " else "", def.Name), Stroke = 5, ZIndex = 44, Parent = hatchLayer })
	local sub = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 236), Size = UDim2.fromOffset(500, 44), Text = string.upper(def.Rarity), TextColor3 = rarityColor, Stroke = 4, ZIndex = 44, Parent = hatchLayer })
	Theme.popIn(card)
	Theme.popIn(title)
	confetti(rarityColor)
	task.wait(2.2)
	spinning = false
	for _, item in { card, title, sub, rays } do
		item:Destroy()
	end
end

local function queueHatch(list)
	table.sort(list, function(a, b)
		local da, db = Critters.ById[a[1]], Critters.ById[b[1]]
		return (da and Config.RarityIndex[da.Rarity] or 0) > (db and Config.RarityIndex[db.Rarity] or 0)
	end)
	for index, entry in list do
		if index <= 3 then
			table.insert(hatchQueue, entry)
		end
	end
	if hatchBusy then
		return
	end
	hatchBusy = true
	task.spawn(function()
		while #hatchQueue > 0 do
			local ok, err = pcall(playHatch, table.remove(hatchQueue, 1))
			if not ok then
				warn("[Hatch] animação falhou:", err)
			end
		end
		TweenService:Create(hatchLayer, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		task.wait(0.3)
		hatchLayer.Visible = false
		hatchBusy = false
	end)
end

-- taco: animação do braço (todo mundo vê) e aviso de atordoado
local swinging: { [Model]: number } = {}
local stunText = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(500, 70), Text = "\u{1F4AB} STUNNED!", TextColor3 = Color3.fromRGB(255, 220, 90), Stroke = 5, Visible = false, ZIndex = 30, Parent = gui })

local carryText = text({ AnchorPoint = if game:GetService("UserInputService").TouchEnabled then Vector2.new(0.5, 0) else Vector2.new(0.5, 1), Position = if game:GetService("UserInputService").TouchEnabled then UDim2.new(0.5, 0, 0, 70) else UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(760, 54), Text = "\u{1F3C3} RUN BACK TO THE SAFE ZONE!", TextColor3 = Color3.fromRGB(255, 225, 80), Stroke = 5, Visible = false, Parent = gui })

-- tela escura da noite (o muro e o céu fazem o resto)
local nightShade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 15, 50), BackgroundTransparency = 1, ZIndex = 0, Parent = gui })

net.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Toast" then
		showToast(a, b)
		if b == "error" then
			sfx("Error")
		end
	elseif kind == "Banner" then
		showBanner(a, b)
	elseif kind == "Step" then
		floatText("+" .. Format.Short(a), PINK_TEXT)
		sfx("Step", 0.9 + math.random() * 0.3)
	elseif kind == "Grabbed" then
		showBanner("RUN!!", Color3.fromRGB(255, 70, 70))
		sfx("Grab")
		sfx("Alarm")
	elseif kind == "Caught" then
		showBanner("CAUGHT!", Color3.fromRGB(255, 70, 70))
		sfx("Caught")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and typeof(b) == "Vector3" then
			root.AssemblyLinearVelocity = b -- o personagem é do jogador: o empurrão tem que ser aplicado aqui
		end
	elseif kind == "Stole" then
		sfx("Delivered")
		sfx("Coin")
		coinBurst(14, Color3.fromRGB(255, 220, 80))
	elseif kind == "Sold" and type(a) == "number" then
		floatText("+" .. Format.Money(a), GREEN_TEXT)
		coinBurst(math.clamp(math.floor(math.log10(math.max(a, 10)) * 5), 8, 30))
		for k = 0, 2 do
			task.delay(k * 0.12, function()
				sfx("Coin", 1 + k * 0.15)
			end)
		end
	elseif kind == "Epic" and type(a) == "string" then
		showEpic(a, b)
	elseif kind == "Offer" and type(a) == "string" then
		showOffer(a, b)
	elseif kind == "Purchased" then
		sfx("Coin")
	elseif kind == "Hatched" and type(a) == "table" then
		windows.Eggs.Visible = false
		-- espera o ovo rachar e explodir na base antes de mostrar o card do bichinho
		task.delay(1.15, function()
			queueHatch(a)
		end)
	elseif kind == "Sfx" then
		sfx(a)
	elseif kind == "SfxAt" and typeof(b) == "Vector3" then
		sfxAt(a, b)
	elseif kind == "Swing" and typeof(a) == "Instance" and a:IsA("Player") and a.Character then
		swinging[a.Character] = os.clock()
	elseif kind == "Pushed" and typeof(a) == "Vector3" then
		-- v65: empurrãozinho do taco (quem não carrega ovo não fica atordoado)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = a
		end
	elseif kind == "Stunned" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and typeof(b) == "Vector3" then
			root.AssemblyLinearVelocity = b
		end
		stunText.Visible = true
		Theme.popIn(stunText)
		task.delay(a or 1, function()
			stunText.Visible = false
		end)
	elseif kind == "GuardianAwake" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if typeof(b) == "Vector3" then
			-- onda de choque vermelha saindo do chefão
			local wave = Instance.new("Part")
			wave.Anchored = true
			wave.CanCollide = false
			wave.CanQuery = false
			wave.CanTouch = false
			wave.Shape = Enum.PartType.Cylinder
			wave.Material = Enum.Material.Neon
			wave.Color = Color3.fromRGB(255, 60, 60)
			wave.Transparency = 0.2
			wave.Size = Vector3.new(0.4, 4, 4)
			wave.CFrame = CFrame.new(b.X, 0.3, b.Z) * CFrame.Angles(0, 0, math.rad(90))
			wave.Parent = workspace
			TweenService:Create(wave, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = Vector3.new(0.4, 90, 90), Transparency = 1 }):Play()
			task.delay(1, function()
				wave:Destroy()
			end)
		end
		if root and a and root.Position.Z > 0 and math.floor(root.Position.Z / Config.Map.LaneLength) + 1 == a then
			sfx("Alarm", 0.8)
			sfx("Night", 0.6)
			-- tremida na câmera
			task.spawn(function()
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					return
				end
				for k = 1, 12 do
					humanoid.CameraOffset = Vector3.new(math.random(-10, 10) / 25, math.random(-10, 10) / 25, 0) * (1 - k / 12)
					task.wait(0.03)
				end
				humanoid.CameraOffset = Vector3.zero
			end)
		end
	elseif kind == "Open" then
		open(a)
		sfx("Pop")
	elseif kind == "JoinCommunity" and type(a) == "number" and a > 0 then
		-- abre o convite oficial da Roblox para entrar na comunidade; entrou = abre o baú na hora
		task.spawn(function()
			local ok, status = pcall(function()
				return game:GetService("GroupService"):PromptJoinAsync(a)
			end)
			if ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember) then
				task.wait(0.5)
				net:FireServer("Chest")
			end
		end)
	elseif kind == "ChestOpened" then
		-- pedir o like só depois de ganhar algo (não dá prêmio pelo like: a Roblox não deixa)
		task.delay(2.5, function()
			showToast("\u{1F44D} Enjoying the game? Leave a LIKE - it helps a lot!", "info")
		end)
	elseif kind == "NightTeleport" then
		task.delay(0.1, faceCameraForward)
		nightShade.BackgroundTransparency = 0
		TweenService:Create(nightShade, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
	end
	-- qualquer mudança: atualiza a janela aberta
	if kind == "Purchased" or kind == "Stole" or kind == "Hatched" or kind == "Sold" or kind == "Refresh" then
		task.delay(0.2, function()
			for name, window in windows do
				if window.Visible and onOpen[name] and windows[name] == window then
					if name == "Shop" then
						refreshShop()
					elseif name == "Index" then
						refreshIndex()
					elseif name == "Eggs" then
						refreshEggs()
					elseif name == "Fuse" then
						refreshFuse()
					elseif name == "Pets" or name == "Sell" then
						refreshPets()
					elseif name == "Daily" then
						refreshDaily()
					elseif name == "Quests" then
						refreshQuests()
					end
					break
				end
			end
		end)
	end
end)


---------------------------------------------------------------------
-- Ferramentas (taco e armadilha) e tutorial
---------------------------------------------------------------------
local hookedTools: { [Tool]: boolean } = {}
local function hookTool(item: Instance)
	if not item:IsA("Tool") or hookedTools[item] then
		return
	end
	local kind = item:GetAttribute("GameTool")
	if not kind then
		return
	end
	hookedTools[item] = true
	item.Activated:Connect(function()
		if kind == "Bat" then
			net:FireServer("Swing")
		elseif kind == "Trap" then
			net:FireServer("PlaceTrap")
		end
	end)
	item.Destroying:Connect(function()
		hookedTools[item] = nil
	end)
end
local function watchHolder(holder: Instance)
	for _, item in holder:GetChildren() do
		hookTool(item)
	end
	holder.ChildAdded:Connect(function(item)
		task.wait()
		hookTool(item)
	end)
end
task.spawn(function()
	watchHolder(player:WaitForChild("Backpack"))
end)
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watchHolder(child)
	end
end)
player.CharacterAdded:Connect(watchHolder)
if player.Character then
	watchHolder(player.Character)
end

workspace:GetAttributeChangedSignal("Night"):Connect(function()
	if workspace:GetAttribute("Night") then
		sfx("Night")
	end
end)

local tutorialText = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if game:GetService("UserInputService").TouchEnabled then -160 else -96), Size = UDim2.fromOffset(820, 46), Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), Stroke = 4, Visible = false, Parent = gui })
local tutorialStep = ""

-- devolve (alvo da seta, texto) conforme o progresso do jogador
local function tutorial(root: BasePart): (Vector3?, string?)
	local slots = decode("Slots", {})
	local eggs, ready, pets = 0, 0, 0
	for _, slot in slots do
		if slot.k == "Egg" then
			eggs += 1
			if (slot.l or 0) <= 0 then
				ready += 1
			end
		else
			pets += 1
		end
	end
	local x, front = player:GetAttribute("PlotX"), player:GetAttribute("PlotFront")
	local stolen = player:GetAttribute("Stolen") or 0
	local pen = player:GetAttribute("PenLevel") or 0
	local money = player:GetAttribute("Money") or 0
	local speed = player:GetAttribute("Speed") or 0
	local function nearestForestEgg(): Vector3?
		local best, target = math.huge, nil
		for _, egg in CollectionService:GetTagged("NestEgg") do
			if egg:GetAttribute("Zone") == 1 and egg.PrimaryPart then
				local d = (egg.PrimaryPart.Position - root.Position).Magnitude
				if d < best then
					best = d
					target = egg.PrimaryPart.Position + Vector3.new(0, 3, 0)
				end
			end
		end
		return target
	end
	if player:GetAttribute("Carrying") then
		return Vector3.new(root.Position.X, 2, -8), "\u{1F3C3} Run back to the SAFE ZONE with the egg!"
	end
	if stolen == 0 then
		return nearestForestEgg(), ("\u{1F95A} Go into %s and %s on an egg to STEAL it!"):format(string.upper(Config.Zones[1].Name), if game:GetService("UserInputService").TouchEnabled then "hold the button" else "hold E")
	end
	if typeof(x) ~= "number" or typeof(front) ~= "number" then
		return nil, nil
	end
	if ready > 0 then
		return Vector3.new(x, 3, front - 12), "\u{1F423} Your egg is READY! Walk to it (or open Eggs) and HATCH it!"
	end
	if pets == 0 and eggs > 0 then
		return nearestForestEgg(), "\u{23F3} Your egg is growing... steal MORE eggs while you wait!"
	end
	local unclaimedIndex = 0
	for _, value in decode("Index", {}) do
		if value == 1 then
			unclaimedIndex += 1
		end
	end
	if pen == 0 and unclaimedIndex > 0 then
		return nil, "\u{1F4D6} NEW CRITTER! Open the INDEX (left) and CLAIM your free cash!"
	end
	if pen == 0 and pets > 0 then
		if money >= (Config.PenLevels[1] and Config.PenLevels[1].Cost or 1000) then
			return Vector3.new(x - 12, 4, front + 6), "\u{1F3E1} Buy PEN LEVEL 1 at the yellow board to unlock your TREADMILL!"
		end
		return nil, "\u{1F4B5} Your pets make money! Save " .. Format.Money(Config.PenLevels[1] and Config.PenLevels[1].Cost or 1000) .. " to unlock the treadmill."
	end
	if pen >= 1 and speed < 300 then
		return Vector3.new(x + 13, 3, front + 22), "\u{1F45F} Run on your TREADMILL to get FASTER!"
	end
	if speed >= 300 and speed < 1000 and stolen < 6 then
		return nil, "\u{2694}\u{FE0F} Use your BAT to make egg thieves drop their egg! Traps catch them too."
	end
	return nil, nil
end

---------------------------------------------------------------------
-- Seta guia (primeiro ovo; carregando = volta para a SAFE ZONE)
---------------------------------------------------------------------
local arrow0 = Instance.new("Attachment")
local targetPart = create("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, Parent = workspace })
local arrow1 = create("Attachment", { Parent = targetPart })
local beam = create("Beam", {
	Attachment0 = arrow0, Attachment1 = arrow1, Color = ColorSequence.new(Color3.fromRGB(255, 230, 80)), Width0 = 1.4, Width1 = 1.4, FaceCamera = true, LightEmission = 0.7,
	Texture = "rbxasset://textures/particles/sparkles_main.dds", TextureMode = Enum.TextureMode.Wrap, TextureSpeed = 2, Enabled = false, Parent = targetPart,
})

---------------------------------------------------------------------
-- Bichinhos passeando no cercado (só na tela)
---------------------------------------------------------------------
local wanderers: { [Model]: any } = {}
local function track(model: Instance)
	if model:IsA("Model") and model:GetAttribute("Wander") and not wanderers[model] then
		local base = model:GetAttribute("Base")
		if typeof(base) == "Vector3" then
			wanderers[model] = { Base = base, Height = model:GetAttribute("Height") or 2, Next = os.clock() + math.random() * 3, Busy = false, Popup = os.clock() + math.random() * 3 }
		end
	end
end
task.spawn(function()
	local live = workspace:WaitForChild("Live", 60)
	if not live then
		return
	end
	for _, model in live:GetChildren() do
		track(model)
	end
	live.ChildAdded:Connect(function(model)
		task.wait()
		track(model)
	end)
	live.ChildRemoved:Connect(function(model)
		wanderers[model] = nil
	end)
end)

-- "+$" saindo dos bichinhos do SEU cercado
local function moneyPop(model: Model)
	local root = model.PrimaryPart
	local income = model:GetAttribute("Income")
	if not root or type(income) ~= "number" then
		return
	end
	local board = create("BillboardGui", { Size = UDim2.fromScale(5, 1.6), StudsOffsetWorldSpace = Vector3.new(0, 3, 0), Adornee = root, MaxDistance = 70, Parent = gui })
	local label = text({ Size = UDim2.fromScale(1, 1), Text = "+" .. Format.Money(income * 3), TextColor3 = GREEN_TEXT, Parent = board })
	TweenService:Create(board, TweenInfo.new(1.4), { StudsOffsetWorldSpace = Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.4), { TextTransparency = 1 }):Play()
	task.delay(1.5, function()
		board:Destroy()
	end)
end

---------------------------------------------------------------------
-- ANIMAÇÃO DOS BICHOS (só na tela, 60 fps): corpo inteiro amassa/estica, pula, balança e inclina.
-- Serve para os guardiões (seguem o "Goal" que o servidor manda) e para os pets do cercado.
---------------------------------------------------------------------
local Rig = {}
Rig.__index = Rig

-- guarda o tamanho e a posição de cada peça em relação ao "chão" do modelo
function Rig.new(model: Model)
	local pivot = model:GetPivot()
	local box, size = model:GetBoundingBox()
	local bottomY = box.Position.Y - size.Y / 2
	local base = CFrame.new(pivot.Position.X, bottomY, pivot.Position.Z) * (pivot - pivot.Position)
	local parts = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local mesh = item:FindFirstChildOfClass("SpecialMesh")
			table.insert(parts, { Part = item, Offset = base:ToObjectSpace(item.CFrame), Size = item.Size, Mesh = mesh, MeshScale = mesh and mesh.Scale })
		end
	end
	return setmetatable({ Model = model, Parts = parts, Lift = pivot.Position.Y - bottomY, Height = size.Y }, Rig)
end

-- ground = CFrame no chão (posição + direção); sx/sy/sz = amassar/esticar
function Rig:Pose(ground: CFrame, sx: number, sy: number, sz: number)
	local scale = Vector3.new(sx, sy, sz)
	for _, info in self.Parts do
		local part = info.Part
		if part.Parent and part.Anchored then
			local offset = info.Offset
			part.CFrame = ground * (CFrame.new(offset.Position * scale) * (offset - offset.Position))
			if sx ~= 1 or sy ~= 1 or sz ~= 1 then
				-- aproxima: escala no eixo do próprio pedaço
				local rel = (offset - offset.Position)
				local lx = math.abs(rel.RightVector.X) * sx + math.abs(rel.RightVector.Y) * sy + math.abs(rel.RightVector.Z) * sz
				local ly = math.abs(rel.UpVector.X) * sx + math.abs(rel.UpVector.Y) * sy + math.abs(rel.UpVector.Z) * sz
				local lz = math.abs(rel.LookVector.X) * sx + math.abs(rel.LookVector.Y) * sy + math.abs(rel.LookVector.Z) * sz
				local k = Vector3.new(lx, ly, lz)
				if info.Mesh then
					info.Mesh.Scale = info.MeshScale * k
				else
					part.Size = info.Size * k
				end
			end
		end
	end
end

local function damp(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

-- GUARDIÕES ----------------------------------------------------------
local guardianState: { [Model]: any } = {}
local function guardianInfo(model: Model)
	local info = guardianState[model]
	if not info then
		local ok, rig = pcall(Rig.new, model)
		if not ok then
			return nil
		end
		local goal = model:GetAttribute("Goal")
		local start = if typeof(goal) == "CFrame" then goal else model:GetPivot()
		info = { Rig = rig, Pos = start.Position - Vector3.new(0, rig.Lift, 0), Look = start.LookVector, Phase = 0, Lean = 0, Sleeping = model:GetAttribute("Sleeping"), Jump = 0, Speed = 0 }
		guardianState[model] = info
	end
	return info
end

local function animateGuardian(model: Model, info, dt: number, t: number)
	local rig = info.Rig
	local goal = model:GetAttribute("Goal")
	if typeof(goal) ~= "CFrame" then
		return
	end
	local target = goal.Position - Vector3.new(0, rig.Lift, 0)
	local before = info.Pos
	info.Pos = info.Pos:Lerp(target, damp(10, dt))
	local moved = (info.Pos - before) * Vector3.new(1, 0, 1)
	local speed = moved.Magnitude / math.max(dt, 1e-3)
	info.Speed += (speed - info.Speed) * damp(8, dt)
	local look = goal.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.01 then
		local newLook = info.Look:Lerp(look.Unit, damp(8, dt))
		info.Look = if newLook.Magnitude > 0.01 then newLook.Unit else info.Look
	end
	local sleeping = model:GetAttribute("Sleeping")
	if sleeping ~= info.Sleeping then
		info.Sleeping = sleeping
		if not sleeping then
			info.Jump = 1 -- pulo de susto ao acordar
		end
	end
	local h = rig.Height
	local y, sx, sy, roll, pitch, yawWiggle = 0, 1, 1, 0, 0, 0
	local running = info.Speed > 2
	if running then
		-- corrida: passos pesados (pula e amassa ao tocar o chão), balança de um lado pro outro, inclina pra frente
		info.Phase += dt * (5 + math.min(info.Speed, 120) * 0.09)
		local s = math.sin(info.Phase)
		local bounce = math.abs(s)
		y = bounce * math.clamp(h * 0.09, 0.4, 3)
		local squash = 1 - bounce
		sy = 1 - squash * 0.14 + bounce * 0.05
		sx = 1 + squash * 0.09
		roll = math.sin(info.Phase) * 7
		pitch = -math.min(info.Speed, 60) * 0.18
	elseif sleeping then
		-- dormindo: respira devagar e balança a cabeça
		local breath = math.sin(t * 1.7 + model:GetAttribute("Zone") or 0)
		sy = 1 + breath * 0.035
		sx = 1 - breath * 0.018
		roll = math.sin(t * 0.8) * 2.5
		pitch = 4
	else
		-- acordado parado: procura o ladrão (vira pros lados) e fica "pronto"
		local breath = math.sin(t * 5)
		sy = 1 + breath * 0.025
		sx = 1 - breath * 0.012
		yawWiggle = math.sin(t * 2.2) * 18
	end
	if info.Jump > 0 then
		info.Jump = math.max(0, info.Jump - dt * 1.8)
		local p = 1 - info.Jump
		y += math.sin(math.clamp(p, 0, 1) * math.pi) * h * 0.35
		sy *= 1 + math.sin(p * math.pi) * 0.12
	end
	info.Lean += (pitch - info.Lean) * damp(6, dt)
	local ground = CFrame.lookAt(info.Pos, info.Pos + info.Look)
		* CFrame.Angles(0, math.rad(yawWiggle), 0)
		* CFrame.new(0, y, 0)
		* CFrame.Angles(math.rad(info.Lean), 0, math.rad(roll))
	rig:Pose(ground, sx, sy, sx)
end

-- PETS DO CERCADO ----------------------------------------------------
local petState: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any -- (v65: chave fraca: não vaza memória)
local function petInfo(model: Model)
	local info = petState[model]
	if not info then
		local base = model:GetAttribute("Base")
		if typeof(base) ~= "Vector3" then
			return nil
		end
		local ok, rig = pcall(Rig.new, model)
		if not ok then
			return nil
		end
		local pivot = model:GetPivot()
		info = { Rig = rig, Base = base, Pos = Vector3.new(pivot.Position.X, base.Y, pivot.Position.Z), Look = pivot.LookVector * Vector3.new(1, 0, 1), Target = nil, Phase = math.random() * 6, Next = os.clock() + math.random() * 2, Jump = 0, Spin = 0, Seed = math.random() * 10 }
		if info.Look.Magnitude < 0.01 then
			info.Look = Vector3.new(0, 0, 1)
		end
		info.Look = info.Look.Unit
		petState[model] = info
	end
	return info
end

local function animatePet(model: Model, info, dt: number, t: number, root: BasePart?)
	local rig = info.Rig
	local clock = os.clock()
	if not info.Target and clock >= info.Next then
		local roll = math.random()
		if roll < 0.18 then
			info.Jump = 1 -- pulinho de alegria
			info.Spin = if math.random() < 0.5 then 1 else 0
			info.Next = clock + 1.5 + math.random() * 2
		else
			local range = model:GetAttribute("WanderRange") or 4.5
			info.Target = info.Base + Vector3.new((math.random() * 2 - 1) * range, 0, (math.random() * 2 - 1) * range)
		end
	end
	local y, sx, sy, roll, pitch = 0, 1, 1, 0, 0
	if info.Target then
		local delta = (info.Target - info.Pos) * Vector3.new(1, 0, 1)
		if delta.Magnitude < 0.15 then
			info.Target = nil
			info.Next = clock + 1.5 + math.random() * 3.5
		else
			local step = math.min(delta.Magnitude, dt * (3.5 + rig.Height * 0.3))
			info.Pos += delta.Unit * step
			info.Look = info.Look:Lerp(delta.Unit, damp(10, dt)).Unit
			-- anda pulando (hop hop) com amassadinha
			info.Phase += dt * 11
			local bounce = math.abs(math.sin(info.Phase))
			y = bounce * math.clamp(rig.Height * 0.18, 0.25, 1.2)
			local squash = 1 - bounce
			sy = 1 - squash * 0.16 + bounce * 0.06
			sx = 1 + squash * 0.1
			roll = math.sin(info.Phase) * 8
			pitch = -6
		end
	else
		-- parado: respira, olha para você se estiver perto
		local breath = math.sin(t * 2.4 + info.Seed)
		sy = 1 + breath * 0.04
		sx = 1 - breath * 0.02
		if root then
			local toPlayer = (root.Position - info.Pos) * Vector3.new(1, 0, 1)
			if toPlayer.Magnitude < 22 and toPlayer.Magnitude > 0.1 then
				info.Look = info.Look:Lerp(toPlayer.Unit, damp(4, dt)).Unit
			end
		end
	end
	local spin = 0
	if info.Jump > 0 then
		info.Jump = math.max(0, info.Jump - dt * 1.6)
		local p = 1 - info.Jump
		y += math.sin(p * math.pi) * math.clamp(rig.Height * 0.6, 1, 3.5)
		sy *= 1 + math.sin(p * math.pi) * 0.15
		if info.Spin > 0 then
			spin = p * 360
		end
		if p < 0.12 then
			sy *= 0.85 -- agacha antes de pular
			sx *= 1.08
		end
	end
	-- acabou de chocar: o bichinho "pula" para fora do ovo (cresce com elástico + gira)
	local popAt = model:GetAttribute("PopIn")
	if typeof(popAt) == "number" then
		local p = (workspace:GetServerTimeNow() - popAt) / 0.7
		if p >= 0 and p < 1 then
			local k = 1 - math.exp(-6 * p) * math.cos(p * 14) -- elástico: 0 -> passa de 1 -> volta para 1
			k = math.max(k, 0.05)
			sx *= k
			sy *= k
			y += math.sin(p * math.pi) * math.clamp(rig.Height * 0.8, 1.5, 5)
			spin += (1 - p) * 360
		end
	end
	local ground = CFrame.lookAt(info.Pos, info.Pos + info.Look)
		* CFrame.Angles(0, math.rad(spin), 0)
		* CFrame.new(0, y, 0)
		* CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
	rig:Pose(ground, sx, sy, sx)
end

-- OVOS NOS NINHOS: balançam de vez em quando (os prontos no cercado balançam mais)
local eggWobble: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any
local function animateEgg(model: Model, dt: number, t: number)
	local root = model.PrimaryPart
	if not root or not root.Anchored then
		eggWobble[model] = nil
		return
	end
	local info = eggWobble[model]
	if not info then
		info = { Next = os.clock() + math.random() * 4, Until = 0, Base = nil }
		eggWobble[model] = info
	end
	local clock = os.clock()
	if clock >= info.Next and clock > info.Until then
		info.Base = model:GetPivot()
		info.Until = clock + 0.7
		info.Next = clock + 2.5 + math.random() * 4
	end
	if info.Base then
		if clock < info.Until then
			local p = 1 - (info.Until - clock) / 0.7
			local angle = math.sin(p * math.pi * 4) * (1 - p) * 14
			model:PivotTo(info.Base * CFrame.Angles(0, 0, math.rad(angle)))
		else
			model:PivotTo(info.Base)
			info.Base = nil
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, model in CollectionService:GetTagged("Guardian") do
		if model.Parent then
			local info = guardianInfo(model)
			if info then
				local far = (info.Pos - camPos).Magnitude > 450
				if not far then
					animateGuardian(model, info, dt, t)
				else
					-- longe: só acompanha a posição (sem animação)
					local goal = model:GetAttribute("Goal")
					if typeof(goal) == "CFrame" then
						info.Pos = goal.Position - Vector3.new(0, info.Rig.Lift, 0)
					end
				end
			end
		end
	end
	for model in guardianState do
		if not model.Parent then
			guardianState[model] = nil
		end
	end
	for model in wanderers do
		if model.Parent then
			local info = petInfo(model)
			if info and (info.Pos - camPos).Magnitude < 120 then
				animatePet(model, info, dt, t, root)
			end
		else
			petState[model] = nil
		end
	end
	-- ovo carregado: balança no ritmo da corrida (pesado = balança mais devagar e mais forte)
	for _, other in Players:GetPlayers() do
		local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local weld = otherRoot and otherRoot:FindFirstChild("CarryWeld")
		local baseC0 = weld and weld:GetAttribute("BaseC0")
		if weld and typeof(baseC0) == "CFrame" then
			local heavy = math.clamp(weld:GetAttribute("Heavy") or 1, 0.6, 6)
			local moving = math.clamp((otherRoot.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude / 20, 0, 1)
			local speedT = t * (12 / math.sqrt(heavy))
			local bob = (math.abs(math.sin(speedT)) * 0.35 * moving) + math.sin(t * 2.5) * 0.08
			local tilt = math.sin(speedT) * 6 * moving + math.sin(t * 1.7) * 2
			local target = baseC0 * CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(-4 * moving), 0, math.rad(tilt))
			local from = weld:GetAttribute("From")
			local grabAt = weld:GetAttribute("GrabAt")
			local p = if typeof(grabAt) == "number" then (workspace:GetServerTimeNow() - grabAt) / 0.35 else 1
			if typeof(from) == "CFrame" and p < 1 then
				-- arco: o ovo sobe do ninho e cai nas mãos
				local e = 1 - (1 - math.clamp(p, 0, 1)) ^ 3
				local arc = math.sin(e * math.pi) * 2.5
				weld.C0 = from:Lerp(target, e) * CFrame.new(0, arc, 0)
			else
				weld.C0 = target
			end
		end
	end
	for _, model in CollectionService:GetTagged("NestEgg") do
		if model.Parent and not model:GetAttribute("Loose") and (model:GetPivot().Position - camPos).Magnitude < 140 then
			animateEgg(model, dt, t)
		end
	end
end)

RunService.Stepped:Connect(function()
	local now = os.clock()
	for model, start in swinging do
		local t = (now - start) / 0.32
		local shoulder = model.Parent and model:FindFirstChild("RightShoulder", true)
		if t >= 1 or not shoulder then
			swinging[model] = nil
		elseif shoulder:IsA("Motor6D") then
			local angle = if t < 0.35 then 150 * (t / 0.35) else 150 - 230 * ((t - 0.35) / 0.65)
			shoulder.Transform = CFrame.Angles(math.rad(angle), 0, math.rad(-20))
		end
	end
	-- quem está carregando ovo: braços para frente segurando o ovo (todo mundo vê)
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character and other:GetAttribute("Carrying") then
			local moving = 0
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				moving = math.clamp((root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude / 20, 0, 1)
			end
			local sway = math.sin(now * 12) * 6 * moving
			for _, side in { "Right", "Left" } do
				local sign = if side == "Right" then 1 else -1
				local shoulder = character:FindFirstChild(side .. "Shoulder", true) -- R15
				if shoulder and shoulder:IsA("Motor6D") then
					shoulder.Transform = CFrame.Angles(math.rad(78 + sway), 0, math.rad(18 * sign))
				else
					local r6 = character:FindFirstChild(side .. " Shoulder", true) -- R6
					if r6 and r6:IsA("Motor6D") then
						r6.Transform = CFrame.Angles(0, 0, math.rad((80 + sway) * sign)) * CFrame.Angles(math.rad(-15 * sign), 0, 0)
					end
				end
				local elbow = character:FindFirstChild(side .. "Elbow", true)
				if elbow and elbow:IsA("Motor6D") then
					elbow.Transform = CFrame.Angles(math.rad(25), 0, 0)
				end
			end
		end
	end
end)

local lastSlow = 0
local eggsTick = 0
local stripeOffset = 0
local currentZone = 0
local myBelt: BasePart? = nil
local beltPin: Vector3? = nil
RunService.Heartbeat:Connect(function(dt)
	local clock = os.clock()
	local character = player.Character
	local carrying = player:GetAttribute("Carrying")
	carryText.Visible = carrying ~= nil
	-- bichinhos passeando + "+$"
	for model, info in wanderers do
		if model.Parent and model:GetAttribute("Owner") == player.UserId and clock >= info.Popup then
			info.Popup = clock + 3
			moneyPop(model)
		end
	end
	-- listras da esteira andando (só visual)
	stripeOffset = (stripeOffset + dt * 8) % 3.2
	-- ESTEIRA: correndo para a frente em cima da SUA esteira = corre no lugar (não é mais arremessado).
	-- Andando para o lado ou para trás você sai normalmente.
	pcall(function()
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local onBelt = false
		if root and humanoid and not carrying then
			local map = workspace:FindFirstChild("Map")
			if map and not myBelt then
				for _, item in map:GetDescendants() do
					if item:IsA("BasePart") and item.Name == "Belt" and item:GetAttribute("OwnerId") == player.UserId then
						myBelt = item
						break
					end
				end
			end
			if myBelt and (myBelt:GetAttribute("OwnerId") ~= player.UserId) then
				myBelt = nil
			end
			if myBelt and myBelt:GetAttribute("Unlocked") then
				local rel = myBelt.CFrame:PointToObjectSpace(root.Position)
				local inside = math.abs(rel.X) < myBelt.Size.X / 2 + 0.5 and math.abs(rel.Z) < myBelt.Size.Z / 2 + 0.5 and rel.Y > -1 and rel.Y < 7
				local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
				local forward = move.Magnitude > 0.1 and move.Unit:Dot(Vector3.new(0, 0, -1)) > 0.4
				if inside and forward then
					onBelt = true
					if not beltPin then
						local center = myBelt.Position
						beltPin = Vector3.new(center.X, 0, center.Z + 2)
					end
					local pinned = Vector3.new(beltPin.X, root.Position.Y, beltPin.Z)
					root.CFrame = CFrame.lookAt(pinned, pinned + Vector3.new(0, 0, -1))
					stripeOffset = (stripeOffset + dt * math.clamp(humanoid.WalkSpeed, 8, 60) * 0.5) % 3.2
				end
			end
		end
		if not onBelt then
			beltPin = nil
		end
	end)
	if clock - lastSlow < 0.25 then
		return
	end
	lastSlow = clock
	local speed = player:GetAttribute("Speed") or 0
	speedText.Text = Format.Short(speed)
	moneyText.Text = Format.Money(player:GetAttribute("Money") or 0)
	incomeText.Text = "+" .. Format.Money(player:GetAttribute("Income") or 0) .. "/s"
	-- Index: quantos prêmios esperando
	local index = decode("Index", {})
	local unclaimed = 0
	for _, value in index do
		if value == 1 then
			unclaimed += 1
		end
	end
	indexBadge.Visible = unclaimed > 0
	dailyBadge.Visible = player:GetAttribute("DailyReady") == true
	indexBadgeText.Text = tostring(unclaimed)
	-- relógio da noite
	local finish = workspace:GetAttribute("CycleEnd")
	if typeof(finish) == "number" then
		local left = math.max(0, math.floor(finish - workspace:GetServerTimeNow()))
		local isNight = workspace:GetAttribute("Night") == true
		nightIcon.Text = if isNight then "\u{2600}\u{FE0F}" else "\u{1F319}"
		nightText.Text = ("in %d:%02d"):format(left // 60, left % 60)
		nightText.TextColor3 = if isNight then Color3.fromRGB(255, 220, 90) else Color3.new(1, 1, 1)
	end
	-- boost mais longo ativo
	local boosts = decode("Boosts", {})
	local bestLeft, bestIcon = 0, nil
	for _, boost in Config.Boosts do
		local left = (boosts[boost.Id] or 0) - workspace:GetServerTimeNow()
		if left > bestLeft then
			bestLeft, bestIcon = left, boost.Icon
		end
	end
	boostIcon.Visible = bestLeft > 0
	boostText.Visible = bestLeft > 0
	if bestLeft > 0 then
		boostIcon.Text = bestIcon or "\u{1F9EA}"
		boostText.Text = ("in %d:%02d"):format(bestLeft // 60, math.floor(bestLeft % 60))
	end
	-- placas das zonas: verde se você já tem a velocidade recomendada
	for _, board in CollectionService:GetTagged("ZoneSign") do
		local need = board:GetAttribute("Need")
		local signGui = board:FindFirstChild("SignGui")
		local line = signGui and signGui:FindFirstChild("Line2")
		if line and typeof(need) == "number" then
			line.TextColor3 = if speed >= need then Color3.fromRGB(110, 255, 110) else Color3.fromRGB(255, 70, 80)
		end
	end
	for _, anchor in CollectionService:GetTagged("ZoneSpeedTag") do
		local need = anchor:GetAttribute("Need")
		local bb = anchor:FindFirstChild("Billboard")
		local line = bb and bb:FindFirstChild("Line2")
		if line and typeof(need) == "number" and need > 0 then
			line.TextColor3 = if speed >= need then Color3.fromRGB(110, 255, 110) else Color3.fromRGB(255, 70, 80)
		end
	end
	-- ovos dos ninhos: mostra se você consegue fugir com ele (verde) ou se é pesado demais (vermelho)
	for _, egg in CollectionService:GetTagged("NestEgg") do
		local need = egg:GetAttribute("Need")
		local eggRoot = egg.PrimaryPart
		local tagOld = eggRoot and eggRoot:FindFirstChild("SpeedTag")
		if tagOld then
			tagOld.Enabled = eggRoot.Anchored and not player:GetAttribute("PhotoMode")
		end
		if typeof(need) == "number" and eggRoot then
			local tag = eggRoot:FindFirstChild("SpeedTag")
			if not tag then
				tag = create("BillboardGui", { Name = "SpeedTag", Size = UDim2.fromScale(8, 1.3), StudsOffsetWorldSpace = Vector3.new(0, -egg:GetExtentsSize().Y / 2 - 0.4, 0), AlwaysOnTop = true, MaxDistance = 45, LightInfluence = 0, Parent = eggRoot })
				text({ Name = "Label", Size = UDim2.fromScale(1, 1), Text = "", Parent = tag })
				tag.Adornee = eggRoot
			end
			local label = tag:FindFirstChild("Label")
			if label then
				local ok = speed >= need
				label.Text = if ok then "\u{2705} You can escape!" else ("\u{26A0} HEAVY! Need %s \u{1F45F}"):format(Format.Short(math.ceil(need)))
				label.TextColor3 = if ok then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 90, 90)
			end
		end
	end
	-- Z z Z balançando
	for _, guardian in CollectionService:GetTagged("Guardian") do
		local info = guardian:FindFirstChild("Info", true)
		if info and info:IsA("BillboardGui") then
			info.StudsOffset = if guardian:GetAttribute("Sleeping") then Vector3.new(0, math.sin(clock * 2) * 0.8, 0) else Vector3.zero
		end
	end
	-- céu de cada zona (cor do ar muda conforme a zona em que você está)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local zoneIndex = if root.Position.Z < 0 then 0 else math.clamp(math.floor(root.Position.Z / Config.Map.LaneLength) + 1, 1, #Config.Zones)
		if zoneIndex ~= currentZone then
			currentZone = zoneIndex
			-- (a cor do ar de cada zona agora é do Ambience.client)
			if zoneIndex > 0 then
				showBanner(("%s %s"):format(Config.Zones[zoneIndex].Emoji or "", Config.Zones[zoneIndex].Name), Color3.new(1, 1, 1))
			end
		end
	end
	-- seta guia + dica do tutorial
	local target: Vector3? = nil
	local hint: string? = nil
	if root then
		target, hint = tutorial(root)
	end
	tutorialText.Visible = hint ~= nil and not carrying
	if hint and hint ~= tutorialStep then
		tutorialStep = hint
		tutorialText.Text = hint
		Theme.popIn(tutorialText)
	end
	if target and root then
		arrow0.Parent = root
		targetPart.Position = target
		beam.Enabled = true
	else
		beam.Enabled = false
	end
	-- janela aberta com timers: atualiza 1x por segundo
	eggsTick += 1
	if windows.Eggs.Visible and eggsTick % 4 == 0 then
		refreshEggs()
	end
end)

-- listras da esteira (só visual)
local stripes = {}
task.delay(5, function()
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, item in map:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("BeltStripe") then
				table.insert(stripes, { Part = item, Start = item.Position })
			end
		end
	end
end)
RunService.RenderStepped:Connect(function()
	for _, info in stripes do
		local z = info.Start.Z + stripeOffset
		info.Part.Position = Vector3.new(info.Start.X, info.Start.Y, if z > info.Start.Z + 1.6 then z - 3.2 else z)
	end
end)


---------------------------------------------------------------------
-- MODO FOTO (só no Studio): P = esconde a tela, Z/X = troca de cena, V = voo de câmera, C = volta ao normal
---------------------------------------------------------------------
if RunService:IsStudio() then
	local UserInputService = game:GetService("UserInputService")
	local StarterGui = game:GetService("StarterGui")
	local L = Config.Map.LaneLength
	local function zoneShot(index: number, side: number?)
		local z0 = L * (index - 1)
		local s = side or 1
		return CFrame.lookAt(Vector3.new(38 * s, 34, z0 + 125), Vector3.new(0, 12, z0 + L * 0.75))
	end
	local shots = {
		CFrame.lookAt(Vector3.new(0, 70, 60), Vector3.new(0, 4, -120)),
		CFrame.lookAt(Vector3.new(-112, 20, -4), Vector3.new(-112, 6, -36)),
		CFrame.lookAt(Vector3.new(118, 22, -2), Vector3.new(118, 6, -36)),
		CFrame.lookAt(Vector3.new(0, 7, -22), Vector3.new(0, 22, 60)),
		zoneShot(1),
		zoneShot(2, -1),
		zoneShot(3),
		zoneShot(4, -1),
		zoneShot(5),
		zoneShot(6, -1),
		zoneShot(7),
		zoneShot(8, -1),
		zoneShot(9),
		zoneShot(10, -1),
		zoneShot(11),
		zoneShot(12, -1),
	}
	-- closes dos chefões (para ícone e thumbnails)
	for _, index in { 1, 6, 9, 10, 4, 11 } do
		local zone = Config.Zones[index]
		local z = L * (index - 1) + L * 0.75
		local h = zone.Height or 20
		table.insert(shots, CFrame.lookAt(Vector3.new(h * 0.45, h * 0.62, z - h * 1.35), Vector3.new(0, h * 0.5, z)))
	end
	local shotIndex = 0
	local hidden = false
	local function setHidden(on: boolean)
		hidden = on
		player:SetAttribute("PhotoMode", on)
		for _, item in player.PlayerGui:GetChildren() do
			if item:IsA("ScreenGui") then
				item.Enabled = not on
			end
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, not on)
		-- placas flutuantes do mundo também somem (foto limpa)
		for _, item in workspace:GetDescendants() do
			if item:IsA("BillboardGui") then
				item.Enabled = not on
			end
		end
		local character = player.Character
		if character then
			for _, item in character:GetDescendants() do
				if item:IsA("BasePart") or item:IsA("Decal") then
					item.LocalTransparencyModifier = if on then 1 else 0
				end
			end
		end
	end
	local flying = false
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local camera = workspace.CurrentCamera
		if input.KeyCode == Enum.KeyCode.P then
			setHidden(not hidden)
		elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Z then
			shotIndex = (shotIndex + (if input.KeyCode == Enum.KeyCode.X then 1 else -1) - 1) % #shots + 1
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = shots[shotIndex]
		elseif input.KeyCode == Enum.KeyCode.C then
			flying = false
			camera.CameraType = Enum.CameraType.Custom
		elseif input.KeyCode == Enum.KeyCode.V and not flying then
			-- voo: hub -> lojas -> portão -> zonas, devagar
			flying = true
			camera.CameraType = Enum.CameraType.Scriptable
			task.spawn(function()
				local path = { shots[1], shots[2], shots[3], shots[4], zoneShot(1), zoneShot(3), zoneShot(5, -1), zoneShot(6), zoneShot(9, -1), zoneShot(10), zoneShot(12, -1) }
				camera.CFrame = path[1]
				for k = 2, #path do
					if not flying then
						break
					end
					local tween = TweenService:Create(camera, TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = path[k] })
					tween:Play()
					tween.Completed:Wait()
					task.wait(0.4)
				end
				flying = false
			end)
		end
	end)
end
