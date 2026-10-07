--[[
	VENDA UM OVO - tela do jogador (LocalScript em StarterPlayerScripts).
	Só MOSTRA as coisas e PEDE ações ao servidor. Nenhum valor de moeda sai daqui.
	Feita para celular: botões grandes, tudo em escala, painéis com rolagem.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state: any = nil

-- ---------------------------------------------------------------------------
-- Cores e peças de interface
-- ---------------------------------------------------------------------------
local C = {
	Cream = Color3.fromRGB(255, 248, 230),
	Panel = Color3.fromRGB(255, 241, 205),
	Brown = Color3.fromRGB(110, 62, 28),
	DarkBrown = Color3.fromRGB(70, 38, 15),
	Yellow = Color3.fromRGB(255, 205, 50),
	Orange = Color3.fromRGB(255, 140, 40),
	Green = Color3.fromRGB(80, 200, 90),
	DarkGreen = Color3.fromRGB(40, 140, 55),
	Red = Color3.fromRGB(235, 70, 60),
	Blue = Color3.fromRGB(70, 160, 255),
	Purple = Color3.fromRGB(170, 90, 230),
	Gray = Color3.fromRGB(170, 160, 150),
	White = Color3.new(1, 1, 1),
}
local FONT = Enum.Font.FredokaOne

local EMOJI = {
	Moeda = "🪙",
	Cesta = "🧺",
	Raio = "⚡",
	Estrela = "⭐",
	Presente = "🎁",
	Trofeu = "🏆",
}

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(radius or 0.25, 0) })
end

local function stroke(color: Color3?, thickness: number?): UIStroke
	return new("UIStroke", { Color = color or C.DarkBrown, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function textStroke(): UIStroke
	return new("UIStroke", { Color = C.DarkBrown, Thickness = 2 })
end

local function label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = C.White,
	}
	for k, v in props do
		if k ~= "MaxText" then -- MaxText é nosso, não é propriedade do TextLabel
			base[k] = v
		end
	end
	local l = new("TextLabel", base)
	if props.TextColor3 == nil or props.TextColor3 == C.White then
		textStroke().Parent = l
	end
	new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 40, Parent = l })
	return l
end

-- Ícone: imagem do Config.Images se tiver ID, senão o emoji
local function icon(name: string, emoji: string?, props: { [string]: any }): GuiObject
	local id = Config.Images[name]
	if id and id ~= "" then
		local base = { BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit }
		for k, v in props do
			base[k] = v
		end
		return new("ImageLabel", base)
	end
	local base = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, Text = emoji or EMOJI[name] or "🥚" }
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base)
end

local function eggIcon(eggId: string, props: { [string]: any }): GuiObject
	local egg = Config.EggById[eggId]
	return icon(if egg then egg.Asset else "", "🥚", props)
end

local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	local base = {
		AutoButtonColor = true,
		Font = FONT,
		TextScaled = true,
		TextColor3 = C.White,
		BackgroundColor3 = C.Green,
	}
	for k, v in props do
		if k ~= "MaxText" then
			base[k] = v
		end
	end
	local b = new("TextButton", base, { corner(0.3), stroke(C.DarkBrown, 3), textStroke() })
	new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 32, Parent = b })
	b.Activated:Connect(onClick)
	return b
end

local function request(action: string, a: any?, b: any?)
	Remotes.Request:FireServer(action, a, b)
end

local function playSound(name: string)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local s = new("Sound", { SoundId = id, Volume = 0.7, Parent = SoundService })
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Tela principal
-- ---------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "VendaUmOvo", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })

-- Barra de cima: moedas, multiplicador e cesta
local top = new("Frame", {
	Name = "Top",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.62, 0, 0, 56),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }),
	new("UISizeConstraint", { MaxSize = Vector2.new(640, 56) }),
})

local function pill(name: string, color: Color3, widthScale: number, order: number): (Frame, TextLabel)
	local f = new("Frame", { Name = name, Size = UDim2.new(widthScale, 0, 1, 0), BackgroundColor3 = color, LayoutOrder = order, Parent = top }, { corner(0.5), stroke(C.DarkBrown, 3) })
	local text = label({ Name = "Text", Position = UDim2.new(0.3, 0, 0.12, 0), Size = UDim2.new(0.66, 0, 0.76, 0), TextXAlignment = Enum.TextXAlignment.Left, Text = "0", Parent = f })
	return f, text
end

local coinPill, coinText = pill("Coins", C.Yellow, 0.42, 1)
icon("Moeda", nil, { Position = UDim2.new(0.03, 0, 0.08, 0), Size = UDim2.new(0.24, 0, 0.84, 0), Parent = coinPill })
local multPill, multText = pill("Mult", C.Purple, 0.22, 2)
icon("Estrela", nil, { Position = UDim2.new(0.04, 0, 0.12, 0), Size = UDim2.new(0.26, 0, 0.76, 0), Parent = multPill })
local basketPill, basketText = pill("Basket", C.Orange, 0.32, 3)
icon("Cesta", nil, { Position = UDim2.new(0.03, 0, 0.08, 0), Size = UDim2.new(0.24, 0, 0.84, 0), Parent = basketPill })
local basketFill = new("Frame", { Name = "Fill", BackgroundColor3 = C.Red, BackgroundTransparency = 0.35, Size = UDim2.new(0, 0, 1, 0), ZIndex = 0, Parent = basketPill }, { corner(0.5) })

-- Boosts ativos (embaixo da barra)
local boostBar = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 68),
	Size = UDim2.new(0.5, 0, 0, 24),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = C.Yellow,
	Text = "",
	Parent = gui,
}, { textStroke() })

-- Botões da esquerda
local side = new("Frame", {
	Name = "Side",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.52, 0),
	Size = UDim2.new(0, 84, 0.66, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { Padding = UDim.new(0.015, 0), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

local panels: { [string]: Frame } = {}
local openPanel: string? = nil
local refreshers: { [string]: () -> () } = {}

local function showPanel(name: string?)
	for key, panel in panels do
		panel.Visible = key == name
	end
	openPanel = name
	if name and refreshers[name] then
		refreshers[name]()
	end
end

local function sideButton(name: string, iconName: string, text: string, color: Color3, order: number): TextButton
	local b = new("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0.15, 0),
		BackgroundColor3 = color,
		Text = "",
		LayoutOrder = order,
		AutoButtonColor = true,
		Parent = side,
	}, { corner(0.25), stroke(C.DarkBrown, 3), new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	icon(iconName, nil, { Position = UDim2.new(0.18, 0, 0.06, 0), Size = UDim2.new(0.64, 0, 0.58, 0), Parent = b })
	label({ Name = "Label", Position = UDim2.new(0, 0, 0.64, 0), Size = UDim2.new(1, 0, 0.32, 0), Text = text, MaxText = 18, Parent = b })
	b.Activated:Connect(function()
		showPanel(if openPanel == name then nil else name)
	end)
	return b
end

sideButton("Hens", "Ovo_Caipira", "Aves", C.Orange, 1)
sideButton("Upgrades", "Raio", "Melhorias", C.Blue, 2)
sideButton("Rebirth", "Estrela", "Rebirth", C.Purple, 3)
sideButton("Missions", "Trofeu", "Missões", C.Green, 4)
local giftButton = sideButton("Gift", "Presente", "Presente", C.Red, 5)
sideButton("Robux", "Moeda", "Loja", C.Yellow, 6)

-- ---------------------------------------------------------------------------
-- Painéis
-- ---------------------------------------------------------------------------
local function makePanel(name: string, title: string, color: Color3): ScrollingFrame
	local panel = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.54, 0),
		Size = UDim2.new(0.62, 0, 0.72, 0),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = gui,
	}, { corner(0.06), stroke(C.DarkBrown, 4), new("UISizeConstraint", { MaxSize = Vector2.new(720, 560), MinSize = Vector2.new(300, 260) }) })
	local header = new("Frame", { Size = UDim2.new(1, 0, 0.14, 0), BackgroundColor3 = color, Parent = panel }, { corner(0.3), stroke(C.DarkBrown, 3) })
	label({ Position = UDim2.new(0.04, 0, 0.12, 0), Size = UDim2.new(0.75, 0, 0.76, 0), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.98, 0, 0.5, 0), Size = UDim2.new(0.12, 0, 0.8, 0), Text = "X", BackgroundColor3 = C.Red, Parent = header }, function()
		showPanel(nil)
	end)
	local list = new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.new(0.03, 0, 0.17, 0),
		Size = UDim2.new(0.94, 0, 0.8, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Brown,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = panel,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	panels[name] = panel
	return list
end

local function clearList(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") and not child:GetAttribute("Keep") then
			child:Destroy()
		end
	end
end

-- Cartão padrão: ícone | título + descrição | botão
local function card(list: ScrollingFrame, order: number, iconObj: GuiObject, title: string, desc: string, buttonText: string, buttonColor: Color3, onClick: (() -> ())?): Frame
	local f = new("Frame", { Size = UDim2.new(1, -10, 0, 78), BackgroundColor3 = C.Cream, LayoutOrder = order, Parent = list }, { corner(0.2), stroke(C.Brown, 2) })
	iconObj.Position = UDim2.new(0, 8, 0.1, 0)
	iconObj.Size = UDim2.new(0, 62, 0.8, 0)
	iconObj.Parent = f
	label({ Position = UDim2.new(0, 80, 0.08, 0), Size = UDim2.new(0.6, -80, 0.44, 0), Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.DarkBrown, MaxText = 26, Parent = f })
	label({ Position = UDim2.new(0, 80, 0.52, 0), Size = UDim2.new(0.6, -80, 0.38, 0), Text = desc, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Brown, MaxText = 18, Font = Enum.Font.GothamBold, Parent = f })
	local b = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.36, 0, 0.7, 0), Text = buttonText, BackgroundColor3 = buttonColor, MaxText = 24, Parent = f }, function()
		if onClick then
			onClick()
		end
	end)
	b.Active = onClick ~= nil
	b.AutoButtonColor = onClick ~= nil
	return f
end

-- AVES
local hensList = makePanel("Hens", "Galinheiro do Seu Zé", C.Orange)
refreshers.Hens = function()
	clearList(hensList)
	if not state then
		return
	end
	local counts = {}
	for _, id in state.Hens do
		counts[id] = (counts[id] or 0) + 1
	end
	new("TextLabel", {
		Size = UDim2.new(1, -10, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = C.Brown,
		Text = ("Ninhos usados: %d de %d. Pra comprar, vá no balcão do Seu Zé, na praça."):format(#state.Hens, state.NestCap),
		LayoutOrder = 0,
		Parent = hensList,
	})
	for i, hen in Config.Hens do
		local egg = Config.EggById[hen.Egg]
		local canPay = state.Coins >= hen.Price
		local owned = counts[hen.Id] or 0
		card(
			hensList,
			i,
			eggIcon(hen.Egg, {}),
			hen.Name .. (if owned > 0 then ("  (x%d)"):format(owned) else ""),
			("%s, vale %s. Bota a cada %ds"):format(egg.Name, Format.Short(egg.Value), hen.LayTime),
			"🪙 " .. Format.Short(hen.Price),
			if canPay then C.Green else C.Gray,
			function()
				request("BuyHen", hen.Id)
			end
		)
	end
end

-- MELHORIAS
local upgradesList = makePanel("Upgrades", "Melhorias", C.Blue)
refreshers.Upgrades = function()
	clearList(upgradesList)
	if not state then
		return
	end
	for i, upgrade in Config.Upgrades do
		local level = state.Upgrades[upgrade.Id] or 0
		local cost = upgrade.Costs[level + 1]
		local nextValue = upgrade.Values[math.min(level + 2, #upgrade.Values)]
		local desc = string.gsub(upgrade.Format, "{v}", tostring(nextValue))
		desc = string.gsub(desc, "{p}", tostring(math.floor((1 - nextValue) * 100 + 0.5)))
		local title = ("%s  (nível %d/%d)"):format(upgrade.Name, level, #upgrade.Costs)
		if cost then
			card(upgradesList, i, icon(upgrade.Icon, nil, {}), title, "Próximo: " .. desc, "🪙 " .. Format.Short(cost), if state.Coins >= cost then C.Green else C.Gray, function()
				request("BuyUpgrade", upgrade.Id)
			end)
		else
			card(upgradesList, i, icon(upgrade.Icon, nil, {}), title, "Já tá no máximo.", "MÁXIMO", C.Purple, nil)
		end
	end
	new("TextLabel", {
		Size = UDim2.new(1, -10, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = C.Brown,
		Text = "Compra no balcão da oficina, na praça.",
		LayoutOrder = 100,
		Parent = upgradesList,
	})
end

-- REBIRTH
local rebirthList = makePanel("Rebirth", "Rebirth", C.Purple)
refreshers.Rebirth = function()
	clearList(rebirthList)
	if not state then
		return
	end
	local current = 1 + Config.RebirthBonus * state.Rebirths
	local after = 1 + Config.RebirthBonus * (state.Rebirths + 1)
	local progress = math.clamp(state.Coins / state.RebirthCost, 0, 1)
	local info = new("Frame", { Size = UDim2.new(1, -10, 0, 170), BackgroundColor3 = C.Cream, LayoutOrder = 1, Parent = rebirthList }, { corner(0.1), stroke(C.Brown, 2) })
	label({ Position = UDim2.new(0.05, 0, 0.04, 0), Size = UDim2.new(0.9, 0, 0.22, 0), Text = ("Rebirths: %d. Bônus x%.1f, depois x%.1f"):format(state.Rebirths, current, after), TextColor3 = C.DarkBrown, Parent = info })
	label({ Position = UDim2.new(0.05, 0, 0.28, 0), Size = UDim2.new(0.9, 0, 0.2, 0), Text = "Você perde moedas, aves e melhorias, mas toda venda passa a render mais. Pra sempre.", TextColor3 = C.Brown, Font = Enum.Font.GothamBold, MaxText = 18, Parent = info })
	local bar = new("Frame", { Position = UDim2.new(0.05, 0, 0.54, 0), Size = UDim2.new(0.9, 0, 0.18, 0), BackgroundColor3 = C.Gray, Parent = info }, { corner(0.5), stroke(C.DarkBrown, 2) })
	new("Frame", { Size = UDim2.new(progress, 0, 1, 0), BackgroundColor3 = C.Purple, Parent = bar }, { corner(0.5) })
	label({ Size = UDim2.new(1, 0, 1, 0), Text = ("🪙 %s / %s"):format(Format.Short(state.Coins), Format.Short(state.RebirthCost)), MaxText = 20, Parent = bar })
	button({ Position = UDim2.new(0.25, 0, 0.77, 0), Size = UDim2.new(0.5, 0, 0.2, 0), Text = "Fazer rebirth", BackgroundColor3 = if progress >= 1 then C.Purple else C.Gray, Parent = info }, function()
		request("Rebirth")
	end)
end

-- MISSÕES
local missionsList = makePanel("Missions", "Missões de hoje", C.Green)
local MISSION_TEXT = {}
for _, m in Config.Missions do
	MISSION_TEXT[m.Id] = m.Text
end
local function makeCodeRow()
	local codeRow = new("Frame", { Name = "Codes", Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = C.Cream, LayoutOrder = 60, Parent = missionsList }, { corner(0.2), stroke(C.Brown, 2) })
	codeRow:SetAttribute("Keep", true)
	local box = new("TextBox", {
		Position = UDim2.new(0, 10, 0.15, 0),
		Size = UDim2.new(0.6, -10, 0.7, 0),
		BackgroundColor3 = C.White,
		PlaceholderText = "Digite um código",
		Text = "",
		ClearTextOnFocus = false,
		Font = FONT,
		TextScaled = true,
		TextColor3 = C.DarkBrown,
		Parent = codeRow,
	}, { corner(0.3), stroke(C.Brown, 2), new("UITextSizeConstraint", { MaxTextSize = 26 }) })
	button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.36, 0, 0.7, 0), Text = "Usar código", BackgroundColor3 = C.Blue, MaxText = 24, Parent = codeRow }, function()
		if box.Text ~= "" then
			request("RedeemCode", box.Text)
			box.Text = ""
		end
	end)
end

refreshers.Missions = function()
	clearList(missionsList)
	if not state then
		return
	end
	-- sequência de dias
	local streakTitle, streakDesc, streakButton, streakColor, streakAction
	if state.StreakDay then
		streakTitle = ("Sequência: dia %d de 7"):format(state.StreakDay)
		streakDesc = ("Hoje vale %s moedas%s"):format(Format.Short(state.StreakReward), if state.StreakDay == 7 then " + Sorte x3" else "")
		streakButton, streakColor = "Pegar", C.Green
		streakAction = function()
			request("ClaimStreak")
		end
	else
		streakTitle = ("Sequência: dia %d de 7"):format(math.max(state.StreakLast or 1, 1))
		streakDesc = "Volta amanhã pra continuar (pulou um dia, recomeça)"
		streakButton, streakColor = "Amanhã", C.Gray
	end
	card(missionsList, 0, icon("Presente", nil, {}), streakTitle, streakDesc, streakButton, streakColor, streakAction)
	for i, mission in state.Daily do
		local text = string.gsub(MISSION_TEXT[mission.Id] or mission.Id, "{n}", Format.Short(mission.Target))
		local done = mission.Progress >= mission.Target
		local desc = ("%s de %s. Prêmio: %s moedas"):format(Format.Short(mission.Progress), Format.Short(mission.Target), Format.Short(mission.Reward))
		local buttonText, color, action = "Em andamento", C.Gray, nil
		if mission.Claimed then
			buttonText, color = "Pego", C.DarkGreen
		elseif done then
			buttonText, color = "Pegar", C.Green
			action = function()
				request("ClaimMission", i)
			end
		end
		local f = card(missionsList, i, icon("Trofeu", nil, {}), text, desc, buttonText, color, action)
		local bar = new("Frame", { Position = UDim2.new(0, 80, 0.9, 0), Size = UDim2.new(0.6, -80, 0.06, 0), BackgroundColor3 = C.Gray, BorderSizePixel = 0, Parent = f })
		new("Frame", { Size = UDim2.new(math.clamp(mission.Progress / math.max(mission.Target, 1), 0, 1), 0, 1, 0), BackgroundColor3 = C.Green, BorderSizePixel = 0, Parent = bar })
	end
	new("TextLabel", {
		Size = UDim2.new(1, -10, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = C.Brown,
		Text = "Amanhã tem missão nova.",
		LayoutOrder = 50,
		Parent = missionsList,
	})
	-- códigos (a caixa é criada uma vez só: a tela atualiza o tempo todo e não pode apagar o que você digita)
	if not missionsList:FindFirstChild("Codes") then
		makeCodeRow()
	end
end

-- PRESENTE
local giftList = makePanel("Gift", "Presente", C.Red)
refreshers.Gift = function()
	clearList(giftList)
	if not state then
		return
	end
	local ready = state.GiftLeft <= 0
	card(
		giftList,
		1,
		icon("Presente", nil, {}),
		if ready then "Presente liberado" else "Presente de quem fica jogando",
		if ready then ("Vale %s moedas"):format(Format.Short(state.GiftReward)) else ("Libera em %s"):format(Format.Time(state.GiftLeft)),
		if ready then "Abrir" else Format.Time(state.GiftLeft),
		if ready then C.Green else C.Gray,
		if ready
			then function()
				request("ClaimGift")
			end
			else nil
	)
end

-- LOJA (ROBUX)
local robuxList = makePanel("Robux", "Loja", C.Yellow)
refreshers.Robux = function()
	clearList(robuxList)
	if not state then
		return
	end
	local order = 0
	for _, pass in Config.GamePasses do
		if pass.Id and pass.Id > 0 then
			order += 1
			local has = state.Passes[pass.Key]
			card(robuxList, order, icon(pass.Icon, nil, {}), pass.Name, pass.Desc, if has then "Já é seu" else "Comprar", if has then C.DarkGreen else C.Blue, if has
				then nil
				else function()
					request("BuyPass", pass.Key)
				end)
		end
	end
	for _, product in Config.Products do
		if product.Id and product.Id > 0 then
			order += 1
			local desc = product.Desc
			if product.Kind == "coins" and state then
				desc = "Quanto maior sua granja, mais moedas vêm"
			end
			card(robuxList, order, icon(product.Icon, nil, {}), product.Name, desc or "", ("R$ %d"):format(product.Robux or 0), C.Green, function()
				request("BuyProduct", product.Key)
			end)
		end
	end
	if order == 0 then
		new("TextLabel", {
			Size = UDim2.new(1, -10, 0, 60),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = C.Brown,
			Text = "Loja fechada por enquanto.",
			Parent = robuxList,
		})
	end
end

-- ---------------------------------------------------------------------------
-- Avisos
-- ---------------------------------------------------------------------------
local toastHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.new(0.6, 0, 0.3, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }), new("UISizeConstraint", { MaxSize = Vector2.new(560, 400) }) })

local KIND_COLOR = { success = C.Green, error = C.Red, event = C.Purple, info = C.Blue }

local function toast(text: string, kind: string?)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = KIND_COLOR[kind or "info"] or C.Blue, Parent = toastHolder }, { corner(0.4), stroke(C.DarkBrown, 3) })
	label({ Position = UDim2.new(0.03, 0, 0.1, 0), Size = UDim2.new(0.94, 0, 0.8, 0), Text = text, MaxText = 24, Parent = f })
	task.delay(3.5, function()
		local tween = TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		f:Destroy()
	end)
	while #toastHolder:GetChildren() > 5 do
		for _, child in toastHolder:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
end

Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text: string, _args: any, kind: string?)
	toast(text, kind)
end)

-- ---------------------------------------------------------------------------
-- Efeitos
-- ---------------------------------------------------------------------------
local function floatText(position: Vector3, text: string, color: Color3)
	local anchor = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Parent = workspace })
	local bb = new("BillboardGui", { Size = UDim2.new(0, 200, 0, 56), AlwaysOnTop = true, Adornee = anchor, Parent = anchor })
	local l = label({ Size = UDim2.new(1, 0, 1, 0), Text = text, TextColor3 = color, Parent = bb })
	textStroke().Parent = l
	local tween = TweenService:Create(anchor, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = position + Vector3.new(0, 6, 0) })
	tween:Play()
	TweenService:Create(l, TweenInfo.new(1.4), { TextTransparency = 1 }):Play()
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

local function bigPopup(text: string, color: Color3)
	local l = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.35, 0), Size = UDim2.new(0.6, 0, 0.12, 0), Text = text, TextColor3 = color, MaxText = 64, Parent = gui })
	textStroke().Parent = l
	l.Size = UDim2.new(0.1, 0, 0.02, 0)
	TweenService:Create(l, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(0.6, 0, 0.12, 0) }):Play()
	task.delay(2.2, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		l:Destroy()
	end)
end

Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind: string, position: Vector3?, value: any)
	if kind == "money" and position then
		floatText(position, "+" .. Format.Short(value), C.Yellow)
	elseif kind == "sold" then
		playSound("Vender")
	elseif kind == "collect" and position then
		floatText(position + Vector3.new(0, 2, 0), "+" .. tostring(value) .. " 🥚", C.White)
		playSound("Coletar")
	elseif kind == "rare" then
		bigPopup("OVO RARO!\n" .. tostring(value), C.Yellow)
		playSound("OvoRaro")
	elseif kind == "rebirth" then
		bigPopup("REBIRTH " .. tostring(value), C.Purple)
	elseif kind == "gift" then
		bigPopup("+" .. Format.Short(value) .. " moedas", C.Green)
	elseif kind == "sound" then
		playSound(tostring(value))
	elseif kind == "customer" then
		playSound("Cliente")
	elseif kind == "offline" and type(value) == "table" then
		local minutes = math.floor((value.Seconds or 0) / 60)
		bigPopup(("Enquanto você estava fora (%d min)\nsuas aves botaram %s ovos: +%s moedas"):format(minutes, Format.Short(value.Eggs or 0), Format.Short(value.Coins or 0)), C.Yellow)
		playSound("Vender")
	end
end)

-- ---------------------------------------------------------------------------
-- Estado vindo do servidor
-- ---------------------------------------------------------------------------
local function updateHud()
	if not state then
		return
	end
	coinText.Text = Format.Short(state.Coins)
	multText.Text = if state.Mult >= 100 then "x" .. Format.Short(state.Mult) else string.gsub(string.format("x%.1f", state.Mult), "%.0$", "")
	basketText.Text = ("%d/%d"):format(state.BasketCount, state.BasketCap)
	local fill = math.clamp(state.BasketCount / math.max(state.BasketCap, 1), 0, 1)
	TweenService:Create(basketFill, TweenInfo.new(0.25), { Size = UDim2.new(fill, 0, 1, 0) }):Play()
	basketFill.BackgroundColor3 = if fill >= 1 then C.Red else C.Green
	local giftLabel = giftButton:FindFirstChild("Label") :: TextLabel
	giftLabel.Text = if state.GiftLeft <= 0 then "Abrir" else "Presente"
	if openPanel and refreshers[openPanel] then
		refreshers[openPanel]()
	end
end

Remotes:WaitForChild("State").OnClientEvent:Connect(function(newState: any)
	state = newState
	updateHud()
end)

-- relógios na tela (boosts e presente) contados no cliente a partir do horário do servidor
task.spawn(function()
	while true do
		task.wait(1)
		if state then
			local now = workspace:GetServerTimeNow()
			local parts = {}
			for key, ends in state.Boosts do
				local left = ends - now
				if left > 0 then
					table.insert(parts, (if key == "Sorte" then "Sorte x3  " else "Venda x2  ") .. Format.Time(left))
				end
			end
			local rainEnd = workspace:GetAttribute("GoldenRainEnd")
			if type(rainEnd) == "number" and rainEnd > now then
				table.insert(parts, 1, "Chuva dourada " .. Format.Time(rainEnd - now))
			end
			boostBar.Text = table.concat(parts, "    ")
			if state.GiftLeft > 0 then
				state.GiftLeft -= 1
				if openPanel == "Gift" then
					refreshers.Gift()
				end
			end
			local giftLabel = giftButton:FindFirstChild("Label") :: TextLabel
			giftLabel.Text = if state.GiftLeft <= 0 then "Abrir" else Format.Time(state.GiftLeft)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Prompts: cada jogador só vê os da própria granja; balcões das lojas abrem o painel
-- ---------------------------------------------------------------------------
local function promptAllowed(prompt: ProximityPrompt): boolean
	if prompt:GetAttribute("Active") == false then
		return false
	end
	local forWho = prompt:GetAttribute("For")
	if forWho == "owner" then
		return prompt:GetAttribute("Owner") == player.UserId
	end
	return true
end

task.spawn(function()
	while true do
		for _, prompt in CollectionService:GetTagged("VUOPrompt") do
			if prompt:IsA("ProximityPrompt") then
				local allowed = promptAllowed(prompt)
				if prompt.Enabled ~= allowed then
					prompt.Enabled = allowed
				end
			end
		end
		task.wait(0.3)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	local opens = prompt:GetAttribute("Opens")
	if type(opens) == "string" and panels[opens] then
		showPanel(opens)
	end
end)

-- ---------------------------------------------------------------------------
-- Seta de ajuda no começo: aponta o ninho com ovos ou a banca
-- ---------------------------------------------------------------------------
local arrowAttachA: Attachment? = nil
local arrowPart = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Parent = workspace })
local arrowAttachB = new("Attachment", { Parent = arrowPart })
local beam = new("Beam", {
	Attachment1 = arrowAttachB,
	Width0 = 1.2,
	Width1 = 1.2,
	FaceCamera = true,
	Color = ColorSequence.new(C.Yellow),
	LightEmission = 0.6,
	Enabled = false,
	Parent = arrowPart,
})

local function myPlot(): Model?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not state or state.TotalEarned >= 2000 then
		beam.Enabled = false
		return
	end
	if not arrowAttachA or arrowAttachA.Parent ~= root then
		arrowAttachA = new("Attachment", { Parent = root })
		beam.Attachment0 = arrowAttachA
	end
	local plot = myPlot()
	if not plot then
		beam.Enabled = false
		return
	end
	local target: Vector3? = nil
	if state.BasketCount > 0 and (state.BasketCount >= state.BasketCap or state.BasketCount >= 5) then
		local point = plot:FindFirstChild("SellPoint")
		target = point and point.Position
	else
		local visuals = plot:FindFirstChild("Visuals")
		local eggs = visuals and visuals:FindFirstChild("Eggs")
		local best, bestDist = nil, math.huge
		if eggs then
			for _, nestFolder in eggs:GetChildren() do
				local nest = plot:FindFirstChild(nestFolder.Name)
				if nest and #nestFolder:GetChildren() > 0 then
					local d = (nest.Position - root.Position).Magnitude
					if d < bestDist then
						best, bestDist = nest.Position, d
					end
				end
			end
		end
		target = best
		if not target and state.BasketCount > 0 then
			local point = plot:FindFirstChild("SellPoint")
			target = point and point.Position
		end
	end
	if target then
		arrowPart.Position = target + Vector3.new(0, 2, 0)
		beam.Enabled = (target - root.Position).Magnitude > 6
	else
		beam.Enabled = false
	end
end)

-- ---------------------------------------------------------------------------
-- Aves balançando (só visual, no cliente)
-- ---------------------------------------------------------------------------
local bases: { [Model]: CFrame } = {}
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, hen in CollectionService:GetTagged("VUOHen") do
		if hen:IsA("Model") and hen.Parent then
			local base = bases[hen]
			if not base then
				base = hen:GetPivot()
				bases[hen] = base
			end
			local phase = (hen:GetAttribute("Phase") or (#hen.Name * 0.7)) :: number
			local hop = math.max(0, math.sin(t * 3 + phase)) * 0.25
			local tilt = math.sin(t * 1.5 + phase) * 0.08
			hen:PivotTo(base * CFrame.new(0, hop, 0) * CFrame.Angles(0, tilt, 0))
		end
	end
	for hen in bases do
		if not hen.Parent then
			bases[hen] = nil
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Música (liga/desliga fica salvo no seu progresso) e cacarejos perto das aves
-- ---------------------------------------------------------------------------
local music: Sound? = nil
if Config.Sounds.Musica ~= "" then
	music = new("Sound", { Name = "Musica", SoundId = Config.Sounds.Musica, Looped = true, Volume = Config.MusicVolume, Parent = SoundService })
end
local musicButton = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 8),
	Size = UDim2.new(0, 56, 0, 56),
	Text = "♪",
	BackgroundColor3 = C.Purple,
	MaxText = 30,
	Parent = gui,
}, function()
	if state then
		request("SetMusic", not state.Music)
	end
end)
musicButton.Visible = music ~= nil

task.spawn(function()
	while true do
		task.wait(1)
		if music and state then
			if state.Music and not music.IsPlaying then
				music:Play()
			elseif not state.Music and music.IsPlaying then
				music:Pause()
			end
			musicButton.BackgroundColor3 = if state.Music then C.Purple else C.Gray
		end
	end
end)

task.spawn(function()
	if Config.Sounds.Cacarejo == "" then
		return
	end
	while true do
		task.wait(6 + math.random() * 8)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local near = {}
			for _, hen in CollectionService:GetTagged("VUOHen") do
				if hen:IsA("Model") and (hen:GetPivot().Position - root.Position).Magnitude < 60 then
					table.insert(near, hen)
				end
			end
			if #near > 0 then
				local hen = near[math.random(1, #near)]
				local anchor = hen:FindFirstChildWhichIsA("BasePart")
				if anchor then
					local s = new("Sound", { SoundId = Config.Sounds.Cacarejo, Volume = 0.5, RollOffMaxDistance = 60, PlaybackSpeed = 0.9 + math.random() * 0.3, Parent = anchor })
					s:Play()
					s.Ended:Connect(function()
						s:Destroy()
					end)
				end
			end
		end
	end
end)

-- Fecha painéis com ESC/B no PC
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.B) then
		showPanel(nil)
	end
end)
