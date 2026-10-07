--[[
	VENDA UM OVO - tela do jogador (LocalScript em StarterPlayerScripts). Versão 4: tycoon de 8 negócios.
	Só MOSTRA as coisas e PEDE ações ao servidor. Nenhum valor de moeda sai daqui.
	Módulos filhos: UI (peças de interface) e World (efeitos no mapa: botões, banca, tapetes, pets, seta, eventos).

	Tela enxuta (filhos do quadro raiz "Root"):
	  em cima     Top (pílulas pequenas: estrelas, cesta de ovos raros, chaves secretas), Giant (Mega Ovo) e
	              Weather (chip do clima) LADO A LADO (um embaixo do outro só em tela estreita), Banner, Toasts
	  esquerda    Side: 5 botões (Biz = Negócios, Pets, Rebirth, Prizes, Shop); cada um abre um painel (com abas)
	  direita     Right: Home, Plaza, Settings;   Sell: o botão redondo VENDER (aparece perto da banca);
	              Powers: os 3 poderes, em fila, à esquerda do VENDER (e PowerHint, a explicação de um poder)
	  embaixo     no meio, de baixo para cima: Coins (o CONTADOR DE MOEDAS: a peça principal de baixo, colada no
	              fundo, com a renda por segundo), BuyNext (comprar de longe, quando existe), Tip (uma dica
	              por vez), Work (barra do ciclo feito na mão)
	No celular a coluna da esquerda sobe (o joystick fica embaixo) e o VENDER fica logo acima do botão de pulo.
	Quem arruma o que depende do tamanho da tela é a tabela Hud (Hud.Top e Hud.Bottom).
	Versão 5 (clima, chaves/Baú Secreto, poderes): tudo que é dela na tela mora na tabela V5 (função V5.Build).
]]

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Lang = require(Shared:WaitForChild("Lang"))
local Sim = require(Shared:WaitForChild("Sim"))
local UI = require(script:WaitForChild("UI"))
local World: any = require(script:WaitForChild("World"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = UI.C
local new = UI.New
local T = Lang.T
local short = Format.Short

local state: any = nil
local langChosen = false
-- Loja em Robux: funções e memória das ofertas (preenchido mais abaixo, junto do painel da Loja).
-- Uma tabela só, e não vários "local": este script já está perto do limite de 200 locais do Luau.
local Loja: any = { NoMoney = {}, Hinted = false }
-- Versão 5 (clima, chaves secretas, poderes): a mesma ideia, uma tabela só (montada em V5.Build, mais abaixo).
local V5: any = {}
-- Arrumação da tela (o que fica em cima e o que fica embaixo, em cada tamanho de tela): idem (ver Hud.Top / Hud.Bottom).
local Hud: any = {}

-- idioma: português para quem usa o Roblox em português; inglês para o resto
do
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	Lang.Set(if ok and type(locale) == "string" and string.sub(string.lower(locale), 1, 2) == "pt" then "pt" else "en")
end

local function request(action: string, a: any?, b: any?)
	Remotes.Request:FireServer(action, a, b)
end

-- ---------------------------------------------------------------------------
-- Leitura segura do estado. O servidor novo pode demorar a mandar um campo (ou mandar nil):
-- a tela nunca pode travar por isso, então todo campo passa por num()/tbl().
-- ---------------------------------------------------------------------------
local EMPTY: any = {}

local function num(value: any, default: number?): number
	local n = tonumber(value)
	if n == nil or n ~= n then
		return default or 0
	end
	return n
end

local function tbl(value: any): any
	return if type(value) == "table" then value else EMPTY
end

-- Negócio i como o servidor mandou em state.Biz. Se ainda não veio, faz a mesma conta do Sim com o que
-- a tela já tem (botões comprados e multiplicadores gerais): é só para MOSTRAR, nunca para pagar.
local function bizOf(index: number): any
	local sent = tbl(state and state.Biz)[index]
	if type(sent) == "table" then
		return sent
	end
	local def = Config.Businesses[index]
	local info = Sim.BizInfo(Config, { Owned = tbl(state and state.Owned) }, index)
	if def and info.Unlocked then
		info.Payout = def.Payout * info.Cash * num(state.Cash, 1)
		info.Cycle = def.Cycle / math.max(info.Speed * num(state.Speed, 1), 0.001)
		info.Income = info.Payout / info.Cycle
	end
	return info
end

-- Moedas no chão do negócio i. O Tick manda a lista Ground (mais nova que o Ground de cada state.Biz).
local function groundOf(index: number): number
	local list = state and state.Ground
	if type(list) == "table" then
		return num(list[index] or list[tostring(index)])
	end
	return num(bizOf(index).Ground)
end

local function groundTotal(): number
	local total = 0
	for index in Config.Businesses do
		total += groundOf(index)
	end
	return total
end

-- O próximo botão a comprar (o servidor manda o id; sem ele, a mesma regra do Sim)
local function nextButtonOf(): any?
	if not state then
		return nil
	end
	local button = if state.Next ~= nil then Config.ButtonById[state.Next] else nil
	if button == nil and state.Next == nil and state.Owned ~= nil then
		button = Sim.NextButton(Config, { Owned = tbl(state.Owned) })
	end
	return button
end

-- string.upper não conhece acento ("mítico" virava "MíTICO"): sobe também as letras acentuadas (UTF-8 C3 A0..BE)
local function upper(text: string): string
	return (string.gsub(string.upper(text), "\195([\160-\190])", function(c: string)
		return "\195" .. string.char(string.byte(c) - 32)
	end))
end

-- segundos de um ciclo: "0.4s", "3.0s", "0:12"
local function secs(seconds: number): string
	if seconds < 0.1 then
		return "<0.1s" -- ciclo tão rápido que "0.0s" pareceria erro
	end
	return if seconds < 10 then string.format("%.1fs", seconds) else Format.Time(seconds)
end

local screenGui = new("ScreenGui", { Name = "VendaUmOvo", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false, Parent = playerGui })
local gui = UI.InitScale(screenGui) -- quadro raiz (escala para celular); tudo vai dentro dele
UI.InitToasts(gui)

UI.InitSounds() -- os 13 sons começam a carregar já (o 1º clique sai com som)

-- ---------------------------------------------------------------------------
-- EM CIMA, no meio: pílulas pequenas (estrelas, cesta de ovos raros e, na versão 5, chaves), a barra do Mega
-- Ovo e o chip do clima. O contador de moedas NÃO mora mais aqui (ficava "no meio do caminho"): desceu para a
-- parte de baixo da tela. Posições e tamanhos de tudo isto saem de Hud.Top (dependem da largura da tela).
-- ---------------------------------------------------------------------------
local top = new("Frame", {
	Name = "Top",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(420, 40),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
}, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- pílula pequena (40 de altura): ícone + número. A largura é fixa: aparecer ou sumir uma não mexe nas outras.
local function pill(name: string, color: Color3, width: number, order: number, iconName: string): (Frame, TextLabel)
	local f = new("Frame", { Name = name, Size = UDim2.fromOffset(width, 40), BackgroundColor3 = color, LayoutOrder = order, Parent = top }, { UI.Corner(0.5), UI.Stroke(C.DarkBrown, 3) })
	UI.Icon(iconName, { Name = "Icon", Position = UDim2.fromOffset(7, 4), Size = UDim2.fromOffset(32, 32), ZIndex = 2, Parent = f })
	local text = UI.Label({ Name = "Text", Position = UDim2.fromOffset(43, 5), Size = UDim2.new(1, -54, 1, -10), TextXAlignment = Enum.TextXAlignment.Left, Text = "0", MaxText = 26, ZIndex = 2, Parent = f })
	return f, text
end

local starPill, starText = pill("Stars", C.Purple, 124, 2, "Estrela")
local basketPill, basketText = pill("Basket", C.Orange, 132, 3, "Cesta")
local basketFill = new("Frame", { Name = "Fill", BackgroundColor3 = C.Green, BackgroundTransparency = 0.35, Size = UDim2.new(0, 0, 1, 0), ZIndex = 1, Parent = basketPill }, { UI.Corner(0.5) })
-- jogador novo não vê nenhuma: estrelas e cesta aparecem quando passam a existir no jogo dele
starPill.Visible = false
basketPill.Visible = false

-- barra do Ovo Gigante (o servidor inteiro enche junto): um cartão do tamanho do chip do clima, ao lado dele
local giantBar = new("Frame", { Name = "Giant", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(238, 50), BackgroundColor3 = C.DarkBrown, BackgroundTransparency = 0.25, Parent = gui }, { UI.Corner(0.3), UI.Stroke(C.DarkBrown, 3) })
local giantFill = new("Frame", { Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Yellow, Parent = giantBar }, { UI.Corner(0.3) })
UI.Icon("Ovo_Dourado", { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.new(0, 38, 0.8, 0), ZIndex = 2, Parent = giantBar }, "🥚")
local giantText = UI.Label({ Name = "Text", Position = UDim2.new(0, 46, 0, 0), Size = UDim2.new(1, -54, 1, 0), Text = "", MaxText = 22, ZIndex = 2, Parent = giantBar })

-- faixa de evento / boosts (embaixo da fila do Mega Ovo e do clima)
local banner = UI.Label({ Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.new(0.7, 0, 0, 26), Text = "", TextColor3 = C.Yellow, MaxText = 24, Parent = gui })

-- ---------------------------------------------------------------------------
-- EMBAIXO, no meio. De baixo para cima: Coins (o contador de moedas, colado no fundo: nunca sai do lugar) ->
-- BuyNext (comprar de longe, só para quem tem o talento) -> Tip (a dica) -> Work (a barra de trabalho).
-- Quem põe cada um no lugar é Hud.Bottom (as larguras dependem da tela; no celular o analógico e o botão de
-- pulo do Roblox moram nos cantos de baixo).
-- CONTADOR DE MOEDAS: placa escura arredondada com borda dourada; moeda grande à esquerda, saindo um pouco da
-- placa; número grande e grosso com contorno; renda por segundo em verde, ao lado. Quando o dinheiro sobe o
-- número dá um pulinho e a placa brilha de leve (Hud.Gain); quando falta dinheiro para uma compra ela treme e
-- pisca vermelho (Hud.NoMoney).
-- ---------------------------------------------------------------------------
local coinPill = new("Frame", { Name = "Coins", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(380, 64), BackgroundColor3 = Color3.fromRGB(46, 28, 16), BackgroundTransparency = 0.06, Parent = gui }, {
	UI.Corner(0.5),
	UI.Stroke(Color3.fromRGB(255, 196, 46), 4),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 150, 140)) }),
})
-- (a moeda tem 84 px numa placa de 64: sobra 10 para cima, 10 para baixo e 12 para a esquerda)
Hud.CoinIcon = UI.Icon("Moeda", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 30, 0.5, 0), Size = UDim2.fromOffset(84, 84), ZIndex = 3, Parent = coinPill })
-- (âncora no meio: o número "pula" em volta do próprio centro)
local coinText = UI.Label({ Name = "Text", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 222, 0.5, 0), Size = UDim2.fromOffset(284, 54), Text = "0", MaxText = 48, ZIndex = 2, Parent = coinPill })
do
	local stroke = coinText:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 3.5 -- número grosso: lê de longe em cima de qualquer cenário
	end
end
local rateText = UI.Label({ Name = "Rate", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(112, 34), BackgroundColor3 = Color3.fromRGB(20, 92, 40), BackgroundTransparency = 0.15, Text = "", TextColor3 = Color3.fromRGB(150, 255, 150), MaxText = 22, Visible = false, ZIndex = 2, Parent = coinPill })
UI.Corner(0.5).Parent = rateText
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = rateText })
do
	local GOLD = Color3.fromRGB(255, 196, 46)
	local NO_RED = Color3.fromRGB(255, 70, 60)
	local stroke: UIStroke = coinPill:FindFirstChildOfClass("UIStroke")
	-- O dinheiro subiu: o número dá um pulinho e a placa brilha de leve (a borda e o número clareiam e voltam).
	-- strong = subiu de uma vez (moedas do chão, prêmio, saco de dinheiro): pulo e brilho maiores.
	function Hud.Gain(strong: boolean)
		UI.Pop(coinText, if strong then 1.22 else 1.07)
		if os.clock() < num(Hud.NoUntil) then
			return -- (o vermelho de "falta dinheiro" está na tela: ele tem a vez)
		end
		stroke.Color = if strong then Color3.fromRGB(255, 250, 205) else Color3.fromRGB(255, 226, 120)
		coinText.TextColor3 = if strong then Color3.fromRGB(255, 240, 150) else Color3.fromRGB(255, 250, 215)
		local back = TweenInfo.new(if strong then 0.45 else 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(stroke, back, { Color = GOLD }):Play()
		TweenService:Create(coinText, back, { TextColor3 = C.White }):Play()
	end
	-- Faltou dinheiro para uma compra (Fx "nomoney"): o contador treme para os lados e pisca vermelho (a borda
	-- e o número) por um instante, e volta ao normal. É para o olho ir até ele: "é ISTO que está faltando".
	function Hud.NoMoney()
		local turn = num(Hud.NoTurn) + 1
		Hud.NoTurn = turn
		Hud.NoUntil = os.clock() + 0.4
		local rest: UDim2 = Hud.CoinAt or coinPill.Position
		stroke.Color = NO_RED
		coinText.TextColor3 = Color3.fromRGB(255, 120, 110)
		-- tremor: 3 idas e voltas de 9 px em 0,3 s (o 4º número do TweenInfo = repetições; o 5º = vai e volta)
		coinPill.Position = rest + UDim2.fromOffset(-9, 0)
		TweenService:Create(coinPill, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), { Position = rest + UDim2.fromOffset(9, 0) }):Play()
		task.delay(0.34, function()
			if Hud.NoTurn ~= turn then
				return -- (faltou dinheiro de novo no meio do tremor: o último é que arruma)
			end
			TweenService:Create(coinPill, TweenInfo.new(0.06), { Position = Hud.CoinAt or rest }):Play()
			local back = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(stroke, back, { Color = GOLD }):Play()
			TweenService:Create(coinText, back, { TextColor3 = C.White }):Play()
		end)
	end
end

-- dica do começo: fundo escuro para dar leitura em cima de qualquer chão
local tip = UI.Label({ Name = "Tip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -92), Size = UDim2.fromOffset(660, 42), BackgroundColor3 = C.DarkBrown, BackgroundTransparency = 0.45, Text = "", MaxText = 28, Visible = false, Parent = gui })
UI.Corner(0.5).Parent = tip
new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = tip })

-- barra de trabalho: o ciclo que o jogador está fazendo na mão (em cima do tapete azul)
local workBar = new("Frame", { Name = "Work", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -142), Size = UDim2.fromOffset(360, 36), BackgroundColor3 = C.DarkBrown, BackgroundTransparency = 0.2, Visible = false, Parent = gui }, { UI.Corner(0.5), UI.Stroke(C.DarkBrown, 3) })
local workFill = new("Frame", { Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Blue, Parent = workBar }, { UI.Corner(0.5) })
local workText = UI.Label({ Name = "Text", Size = UDim2.new(1, 0, 1, 0), Text = "", MaxText = 22, ZIndex = 2, Parent = workBar })

-- ---------------------------------------------------------------------------
-- Botões da esquerda (painéis) e da direita (teleporte, configurações)
-- ---------------------------------------------------------------------------
local side = new("Frame", { Name = "Side", Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(0, 86, 1, -208), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0.02, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

local right = new("Frame", { Name = "Right", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(62, 200), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0.035, 0), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

local labelKeys: { [TextLabel]: string } = {} -- rótulos que mudam com o idioma
local panelTitles: { [string]: { Label: TextLabel, Key: string } } = {}

local function iconButton(parent: Instance, name: string, iconName: string, emoji: string?, textKey: string, color: Color3, order: number, heightScale: number, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, heightScale, 0),
		BackgroundColor3 = color,
		Text = "",
		LayoutOrder = order,
		AutoButtonColor = true,
		Parent = parent,
	}, { UI.Corner(0.25), UI.Stroke(C.DarkBrown, 3), UI.Shine(), new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local icon = UI.Icon(iconName, { Name = "Icon", Position = UDim2.new(0.18, 0, 0.06, 0), Size = UDim2.new(0.64, 0, 0.58, 0), Parent = b }, emoji)
	local l = UI.Label({ Name = "Label", Position = UDim2.new(0, 0, 0.64, 0), Size = UDim2.new(1, 0, 0.32, 0), Text = T(textKey), MaxText = 18, Parent = b })
	labelKeys[l] = textKey
	b.Activated:Connect(function()
		UI.Sound("Clique", 0.4, 0.95)
		UI.Pop(icon, 0.8) -- só o desenho pula: mexer no botão inteiro empurraria os vizinhos da coluna
		onClick()
	end)
	return b
end

-- Cada botão da esquerda abre um GRUPO de painéis (abas). Lembra a última aba aberta.
local GROUPS = {
	Biz = { "Biz" },
	Pets = { "Pets", "Album" },
	Rebirth = { "Rebirth", "Talents" },
	Prizes = { "Wheel", "Missions", "Gifts" },
	Shop = { "Shop" },
}
local lastTab: { [string]: string } = {}

local function openGroup(group: string, tab: string?)
	local tabs = GROUPS[group]
	local current = UI.OpenPanel
	if not tab and current and table.find(tabs, current) then
		UI.Show(nil)
		return
	end
	local name = tab or lastTab[group] or tabs[1]
	lastTab[group] = name
	UI.Show(name)
	request("Refresh")
end

-- 5 botões na coluna: altura = (1 - 4 espaços de 2%) / 5
local function groupButton(group: string, iconName: string, emoji: string?, textKey: string, color: Color3, order: number): TextButton
	return iconButton(side, group, iconName, emoji, textKey, color, order, 0.184, function()
		openGroup(group)
	end)
end

groupButton("Biz", "Negocios", "🏪", "hud.biz", C.Orange, 1)
local petsButton = groupButton("Pets", "Pet", "🐣", "hud.pets", C.Pink, 2)
local rebirthButton = groupButton("Rebirth", "Renascer", "⭐", "hud.rebirth", C.Blue, 3)
local prizesButton = groupButton("Prizes", "Premios", "🎁", "hud.prizes", C.Red, 4)
groupButton("Shop", "Sacola", "🛒", "hud.shop", C.Yellow, 5)

iconButton(right, "Home", "Casa", "🏠", "hud.home", C.Green, 1, 0.31, function()
	request("Teleport", "home")
end)
iconButton(right, "Plaza", "Praca", "⛲", "hud.plaza", C.Purple, 2, 0.31, function()
	request("Teleport", "plaza")
end)
iconButton(right, "Settings", "Config", "⚙️", "hud.settings", C.Gray, 3, 0.31, function()
	UI.Toggle("Settings")
end)

-- selo de "tem coisa para pegar" nos botões
local function badge(button: Instance): Frame
	return new("Frame", { Name = "Badge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.new(0.3, 0, 0.3, 0), BackgroundColor3 = C.Red, Visible = false, ZIndex = 3, Parent = button }, { UI.Corner(1), UI.Stroke(C.White, 2) })
end
local petsBadge = badge(petsButton)
local prizesBadge = badge(prizesButton)
local rebirthBadge = badge(rebirthButton)

-- comprar de longe (talento/passe): logo acima do contador de moedas (quem põe no lugar é Hud.Bottom)
local buyNext = UI.Button({ Name = "BuyNext", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(460, 60), Text = "", BackgroundColor3 = C.Green, Visible = false, MaxText = 24, Parent = gui }, function()
	request("BuyNext")
end)

-- ---------------------------------------------------------------------------
-- Botão VENDER: o coração do começo do jogo. Redondo, grande, no polegar direito.
-- "Sell" é o botão (transparente); "Base" é a sombra parada e "Face" a tampa que afunda a cada toque.
-- ---------------------------------------------------------------------------
local SELL_SIZE = 150
local sell = new("TextButton", { Name = "Sell", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -212), Size = UDim2.fromOffset(SELL_SIZE, SELL_SIZE + 8), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 2, Parent = gui })
new("Frame", { Name = "Base", Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(SELL_SIZE, SELL_SIZE), BackgroundColor3 = C.DarkGreen, ZIndex = 2, Parent = sell }, { UI.Corner(1), UI.Stroke(C.DarkBrown, 4) })
local sellFace = new("Frame", { Name = "Face", Size = UDim2.fromOffset(SELL_SIZE, SELL_SIZE), BackgroundColor3 = C.Green, ZIndex = 3, Parent = sell }, { UI.Corner(1), UI.Stroke(C.DarkBrown, 4), UI.Shine() })
UI.Icon("Ovo_Branco", { Name = "Icon", Position = UDim2.new(0.3, 0, 0.07, 0), Size = UDim2.new(0.4, 0, 0.36, 0), ZIndex = 4, Parent = sellFace }, "🥚")
local sellLabel = UI.Label({ Name = "Label", Position = UDim2.new(0.08, 0, 0.43, 0), Size = UDim2.new(0.84, 0, 0.27, 0), Text = T("hud.sell"), MaxText = 36, ZIndex = 4, Parent = sellFace })
labelKeys[sellLabel] = "hud.sell"
local sellValue = UI.Label({ Name = "Value", Position = UDim2.new(0.14, 0, 0.69, 0), Size = UDim2.new(0.72, 0, 0.21, 0), Text = "", TextColor3 = C.Yellow, MaxText = 26, ZIndex = 4, Parent = sellFace })

-- O servidor aceita Config.ClickMaxPerSecond cliques por segundo. A tela manda no máximo um a menos
-- (espaço mínimo entre dois pedidos): um soluço da rede não junta dois pedidos e estoura o limite.
local CLICK_GAP = 1 / math.max(1, Config.ClickMaxPerSecond - 1)
local HOLD_EVERY = math.max(0.2, CLICK_GAP) -- dedo parado no botão: uns 5 toques por segundo, sem martelar a tela
local SELL_KEYS = { E = true, ButtonX = true, ButtonR2 = true } -- teclado: E; controle: X ou o gatilho direito
local FACE_UP, FACE_DOWN = UDim2.fromOffset(0, 0), UDim2.fromOffset(0, 7)
local faceBack = TweenService:Create(sellFace, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = FACE_UP })

local lastClick = 0 -- os.clock() do último pedido "Click"
local lastRelease = 0 -- os.clock() em que o dedo/mouse saiu do botão
local holdInput: InputObject? = nil -- dedo (ou botão do mouse) que está segurando o VENDER
local holdKeys: { [string]: boolean } = {} -- teclas e botões do controle segurados (pelo nome da tecla)

local function sellTap()
	if not sell.Visible then
		return
	end
	-- resposta na hora para o dedo: a tampa afunda e volta (mesmo quando o pedido não vai por causa do limite)
	faceBack:Cancel()
	sellFace.Position = FACE_DOWN
	faceBack:Play()
	local now = os.clock()
	if now - lastClick < CLICK_GAP then
		return
	end
	lastClick = now
	request("Click")
	UI.Sound("Clique", 0.3, 1.1, 0.08) -- (a altura varia um pouco: 5 toques por segundo iguais enjoam)
end

local function releaseHold()
	if holdInput then
		holdInput = nil
		lastRelease = os.clock()
	end
end

-- O toque conta quando o dedo ENCOSTA (não quando solta): parece mais rápido e permite segurar.
sell.InputBegan:Connect(function(input: InputObject)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
		holdInput = input
		sellTap()
	end
end)
-- Activated chega ao SOLTAR um toque que já contou acima (ignora). Só vale para quem aperta o botão sem
-- dedo nem mouse (controle com seleção de botões da tela).
sell.Activated:Connect(function()
	if holdInput == nil and os.clock() - lastRelease > 0.3 then
		sellTap()
	end
end)

-- ---------------------------------------------------------------------------
-- Arrumação que depende do aparelho. No celular: a coluna da esquerda sobe (o joystick do Roblox mora
-- embaixo à esquerda), a da direita vai para o canto de cima e o VENDER fica logo acima do botão de pulo.
-- No PC o canto de cima tem o chat (esquerda) e a lista de jogadores (direita): as colunas descem.
-- ---------------------------------------------------------------------------
local touchKnown, touchOn = pcall(function()
	return UserInputService.TouchEnabled
end)
local isTouch = not touchKnown or touchOn == true

-- Tamanho da tela VIRTUAL (a que o quadro raiz usa: px de verdade divididos pela escala) e se é "tela pequena"
-- para o Roblox (menor lado até 500 px de verdade: os controles de toque são menores). O ScreenGui não ignora a
-- barra de cima nem os entalhes do aparelho (IgnoreGuiInset = false): o tamanho dele já é a área segura, e
-- tudo aqui é medido dentro dela.
function Hud.Screen(): (number, number, boolean)
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local ok, inner = pcall(function()
		return screenGui.AbsoluteSize
	end)
	if ok and inner.X > 50 and inner.Y > 50 then
		size = inner
	end
	return size.X / UI.Scale, size.Y / UI.Scale, math.min(size.X, size.Y) <= 500
end

-- ---------------------------------------------------------------------------
-- EM CIMA (px da tela virtual; o meio da tela é o eixo). De cima para baixo:
--   y = 8     Top: as pílulas pequenas (40 de altura). Se nenhuma aparece, a fila some e o resto sobe.
--   depois    Giant (Mega Ovo) e Weather (chip do clima) LADO A LADO numa fila de 50 de altura e até 700 de
--             largura (34% para o Mega Ovo). Só um dos dois na tela: ele fica sozinho, no meio. Em tela
--             estreita (em pé), um embaixo do outro.
--   depois    Banner (evento / boosts, 26) e, embaixo dele, os avisos (Toasts).
-- Com tudo à mostra a parte fixa termina em y = 134 (18% de uma tela de 720): antes eram três faixas largas
-- empilhadas até 184. A fila cabe entre as colunas dos lados (110 px de cada lado no celular) e fora do
-- chat e da lista de jogadores do PC (700 no meio).
-- ---------------------------------------------------------------------------
function Hud.Top()
	local W = Hud.Screen()
	local chip: any = Hud.Chip -- (criado em V5.Build)
	local keys: any = Hud.Keys
	local pills = starPill.Visible or basketPill.Visible or (keys ~= nil and keys.Visible == true)
	local g, c = giantBar.Visible, chip ~= nil and chip.Visible == true
	local key = ("%d %s %s %s"):format(math.floor(W), tostring(pills), tostring(g), tostring(c))
	if key == Hud.TopKey then
		return
	end
	Hud.TopKey = key
	local rowW = math.max(260, math.min(700, W - 220))
	local y = 8
	top.Visible = pills
	if pills then
		y += 40 + 6
	end
	if rowW >= 600 then
		-- lado a lado (quem não está na tela fica guardado no lugar que teria)
		local gw = math.floor(rowW * 0.34)
		local cw = rowW - gw - 8
		if g and c or not (g or c) then
			giantBar.Position = UDim2.new(0.5, -(rowW - gw) / 2, 0, y)
			giantBar.Size = UDim2.fromOffset(gw, 50)
			if chip then
				chip.Position = UDim2.new(0.5, (rowW - cw) / 2, 0, y)
				chip.Size = UDim2.fromOffset(cw, 50)
			end
		else
			giantBar.Position = UDim2.new(0.5, 0, 0, y)
			giantBar.Size = UDim2.fromOffset(math.min(rowW, 380), 50)
			if chip then
				chip.Position = UDim2.new(0.5, 0, 0, y)
				chip.Size = UDim2.fromOffset(math.min(rowW, 560), 50)
			end
		end
		if g or c then
			y += 50 + 4
		end
	else
		-- tela estreita: um embaixo do outro
		giantBar.Position = UDim2.new(0.5, 0, 0, y)
		giantBar.Size = UDim2.fromOffset(rowW, 34)
		if g then
			y += 34 + 6
		end
		if chip then
			chip.Position = UDim2.new(0.5, 0, 0, y)
			chip.Size = UDim2.fromOffset(rowW, 50)
		end
		if c then
			y += 50 + 4
		end
	end
	banner.Position = UDim2.new(0.5, 0, 0, y)
	local toasts = gui:FindFirstChild("Toasts")
	if toasts and toasts:IsA("GuiObject") then
		toasts.Position = UDim2.new(0.5, 0, 0, y + 30)
	end
end

-- ---------------------------------------------------------------------------
-- EMBAIXO, no meio (px da tela virtual, medidos a partir do fundo). A pilha, de baixo para cima:
--   Coins (64; a moeda passa 10 para cima e 10 para baixo) -> BuyNext (60, só quando existe) -> Tip (42) ->
--   Work (36), com 8 px entre um e outro (4 em volta da moeda). O CONTADOR É A BASE e nunca sai do lugar: a
--   placa fica a 14 px do fundo (a moeda, a 4), com ou sem o botão de comprar de longe; quem sobe um degrau
--   quando esse botão aparece são a dica e a barra de trabalho. (É para o contador que o olho e as moedas
--   voando vão o tempo todo: ele não pode pular de lugar.) A barra de trabalho desce para o lugar da dica
--   quando não há dica.
-- Largura: cada peça tem a sua (380 / 460 / até 820 / 360), mas nenhuma passa do espaço livre entre o que mora
-- nos cantos de baixo: no PC o VENDER (direita); no celular o analógico (esquerda: 110 px de verdade na tela
-- pequena, 215 na grande) e o botão de pulo (direita: 95 / 170), com 12 de folga. Numa tela em pé esse
-- espaço não dá: aí a pilha inteira sobe para cima dos controles (100 / 215 px de verdade) e só precisa
-- desviar do VENDER.
-- A barra de poderes (V5) fica logo acima do topo que a pilha pode ter (Hud.BarBottom), e os painéis
-- (janelas do meio) encolhem para nunca cobrir o contador nem o botão de comprar de longe: de y = 54 (abaixo
-- das pílulas) até 4 px acima da moeda (ou do botão). Com um painel aberto a dica e a barra de trabalho
-- somem (ficariam por baixo dele).
-- ---------------------------------------------------------------------------
function Hud.Bottom()
	local W, H, small = Hud.Screen()
	local s = UI.Scale
	local panelOpen = UI.OpenPanel ~= nil
	local key = ("%d %d %.3f %s %s %s %s"):format(math.floor(W), math.floor(H), s, tostring(buyNext.Visible), tostring(tip.Visible), tostring(rateText.Visible), tostring(panelOpen))
	if key == Hud.BottomKey then
		return
	end
	Hud.BottomKey = key
	local side, base = 182, 10 -- PC: só o VENDER (24 de margem + 150 + 8 de folga), dos dois lados para ficar no meio
	if isTouch then
		local corner = math.max(if small then 110 else 215, if small then 95 else 170) / s + 12
		if W - 2 * corner >= 420 then
			side = math.max(corner, 182)
		else
			base = (if small then 100 else 215) / s + 8 -- tela em pé: acima do analógico e do pulo
		end
	end
	local free = math.max(200, W - 2 * side)
	-- contador de moedas: a base da pilha, sempre no mesmo lugar (a moeda passa 10 px para baixo da placa: fica
	-- a 4 px da borda; e sai 12 px para a esquerda: a placa cede esse espaço dos dois lados)
	local y = base + 4
	local cw = math.min(380, free - 24)
	coinPill.Size = UDim2.fromOffset(cw, 64)
	Hud.CoinAt = UDim2.new(0.5, 0, 1, -y) -- (o lugar de descanso: o tremor de "falta dinheiro" volta para cá)
	coinPill.Position = Hud.CoinAt
	local left = 78 -- onde o número começa (depois da moeda)
	local right = if rateText.Visible then 12 + 112 + 8 else 16
	coinText.Size = UDim2.fromOffset(math.max(60, cw - left - right), 54)
	coinText.Position = UDim2.new(0, left + math.max(60, cw - left - right) / 2, 0.5, 0)
	y += 64 + 14 -- (a moeda passa 10 px do topo da placa; mais 4 de folga)
	-- comprar de longe: logo acima do contador (sem ele, a dica fica com este lugar)
	buyNext.Size = UDim2.fromOffset(math.min(460, free), 60)
	buyNext.Position = UDim2.new(0.5, 0, 1, -y)
	if buyNext.Visible then
		y += 60 + 8
	end
	tip.Size = UDim2.fromOffset(math.min(820, W * 0.6, free), 42)
	tip.Position = UDim2.new(0.5, 0, 1, -y)
	workBar.Size = UDim2.fromOffset(math.min(360, free), 36)
	workBar.Position = UDim2.new(0.5, 0, 1, -(if tip.Visible then y + 42 + 8 else y))
	-- o topo mais alto que a pilha pode ter (com dica e barra de trabalho): a barra de poderes mora acima dele
	local barBottom = y + 42 + 8 + 36 + 2
	if barBottom ~= Hud.BarBottom then
		Hud.BarBottom = barBottom
		if V5.Layout then
			V5.Layout()
		end
	end
	-- painéis: entre as pílulas de cima e o contador
	local band = H - 54 - y
	local height = math.max(math.min(H * 0.8, 600, band), math.min(250, band), 120)
	for _, panel in UI.Panels do
		panel.Position = UDim2.new(0.5, 0, 0, 54 + band / 2)
		-- no celular o painel usa a largura entre as colunas de botões (com 0.66 sobrava meia tela vazia)
		panel.Size = if isTouch then UDim2.new(0, math.clamp(W - 200, 300, 1000), 0, height) else UDim2.new(0.66, 0, 0, height)
	end
end

local function applyLayout()
	if isTouch then
		-- Botão de pulo do Roblox (px de verdade): tela pequena (menor lado até 500) = 70 px a 20 do fundo;
		-- tela grande = 120 px a 90 do fundo. O Roblox mede a tela já sem a barra de cima, igual a este ScreenGui.
		local _w, _h, small = Hud.Screen()
		local jumpTop = if small then 90 else 210
		-- (o botão de pulo vai até 95 px da borda direita na tela pequena e até 170 na grande)
		V5.JumpLeft = (if small then 95 else 170) / UI.Scale
		side.Position = UDim2.new(0, 10, 0, 8)
		side.Size = UDim2.new(0, 86, 1, -208)
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.new(1, -10, 0, 8)
		sell.Position = UDim2.new(1, -16, 1, -math.ceil((jumpTop + 10) / UI.Scale))
	else
		side.Position = UDim2.new(0, 10, 0.27, 0)
		side.Size = UDim2.new(0, 86, 0.73, -12)
		right.AnchorPoint = Vector2.new(1, 0.5)
		right.Position = UDim2.new(1, -10, 0.4, 0)
		sell.Position = UDim2.new(1, -24, 1, -100)
	end
	Hud.TopKey, Hud.BottomKey = nil, nil
	Hud.Top()
	Hud.Bottom() -- (chama V5.Layout quando a altura da pilha muda)
	if V5.Layout then
		V5.Layout() -- a barra de poderes fica ao lado do VENDER e do botão de pulo
	end
end
UI.OnScale = applyLayout
applyLayout()
-- Para conferir a arrumação de celular num PC (e a de PC num celular) sem trocar de aparelho: o atributo
-- ForceTouch (true / false) no ScreenGui "VendaUmOvo" manda no lugar do que o aparelho diz; apagar o atributo
-- volta ao normal. Serve no Studio (janela Propriedades) e nos testes automáticos.
Hud.TouchDetected = isTouch
screenGui:GetAttributeChangedSignal("ForceTouch"):Connect(function()
	local forced = screenGui:GetAttribute("ForceTouch")
	isTouch = if type(forced) == "boolean" then forced else Hud.TouchDetected
	applyLayout()
end)

-- ---------------------------------------------------------------------------
-- VERSÃO 5 NA TELA: chip do clima, contador de chaves e barra de poderes.
-- Onde fica cada coisa (px da tela virtual, que tem pelo menos 1100 x 720) e por quê:
--   Weather  chip do clima: em cima, ao lado da barra do Mega Ovo (quem põe no lugar é Hud.Top). Cabe em
--            qualquer tela sem encostar nas pílulas nem nas colunas dos lados (que mudam de lugar entre
--            celular e PC). A faixa de evento (Banner) e os avisos (Toasts) ficam logo abaixo dele.
--   Top.Keys contador de chaves: 3ª pílula pequena da fila de cima (largura fixa: não mexe nas outras).
--   Powers   barra de poderes: fila de 3 botões redondos embaixo à direita (polegar direito), com a base logo
--            acima do topo que a pilha do meio pode ter (Hud.BarBottom: 180 px do fundo; 248 com o botão de
--            comprar de longe na tela), e abaixo dos avisos. Fica à ESQUERDA do botão VENDER (12 px de
--            folga) e do botão de pulo do celular (20 px), longe do analógico (que usa os 40% da
--            esquerda), e some enquanto um painel está aberto (os painéis ficam no meio da tela e
--            passariam por cima dela).
-- ---------------------------------------------------------------------------
function V5.Build()
	local KEYS: any = tbl(Config.Keys)
	local POWERS: { any } = tbl(Config.Powers)
	local WEATHER: { [string]: any } = tbl(Config.WeatherById)

	-- ===== chip do clima =====
	local WEATHER_BG: { [string]: Color3 } = {
		limpo = Color3.fromRGB(78, 132, 190),
		sol = Color3.fromRGB(240, 150, 40),
		chuva = Color3.fromRGB(60, 104, 186),
		vento = Color3.fromRGB(56, 158, 132),
		noite = Color3.fromRGB(62, 58, 136),
		arcoiris = Color3.fromRGB(206, 84, 186),
	}
	-- (posição e largura: Hud.Top; ao lado do Mega Ovo tem uns 450 px, sozinho até 560; altura 50)
	local chip = new("Frame", { Name = "Weather", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(454, 50), BackgroundColor3 = WEATHER_BG.limpo, Visible = false, Parent = gui }, { UI.Corner(0.3), UI.Stroke(C.DarkBrown, 3) })
	Hud.Chip = chip
	local chipIcon = UI.Icon("", { Name = "Icon", Position = UDim2.fromOffset(7, 5), Size = UDim2.fromOffset(40, 40), ZIndex = 2, Parent = chip }, "⛅") :: TextLabel
	local chipName = UI.Label({ Name = "Title", Position = UDim2.fromOffset(54, 2), Size = UDim2.new(1, -142, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Text = "", MaxText = 25, ZIndex = 2, Parent = chip })
	local chipClock = UI.Label({ Name = "Clock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 2), Size = UDim2.fromOffset(76, 26), TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = C.Yellow, MaxText = 25, ZIndex = 2, Parent = chip })
	local chipFx = UI.Label({ Name = "Fx", Position = UDim2.fromOffset(54, 28), Size = UDim2.new(0.64, -54, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = C.Yellow, Font = UI.Font2, MaxText = 17, ZIndex = 2, Parent = chip })
	local chipNext = UI.Label({ Name = "Next", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 30), Size = UDim2.new(0.36, -14, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = C.Cream, Font = UI.Font2, MaxText = 14, ZIndex = 2, Parent = chip })
	local chipShown: any = { Id = false, Next = false, Left = -1 }

	-- o que o clima faz, numa frase: "Tudo normal" / "Banca e Omeleteria +50%" / "TUDO +50% e ovos raros 2x mais rápido"
	local function weatherFx(def: any): string
		local p = math.floor((num(def.Mult, 1) - 1) * 100 + 0.5)
		if p <= 0 then
			return T("weather.fx.none")
		elseif def.All then
			return T("weather.fx.all", { p = p, n = num(def.Rare, 1) })
		end
		local list = tbl(def.Biz)
		local a, b = Config.Businesses[list[1]], Config.Businesses[list[2]]
		if a and b then
			return T("weather.fx.two", { a = T("biz." .. a.Id), b = T("biz." .. b.Id), p = p })
		elseif a then
			return T("weather.boost", { e = T("biz." .. a.Id), p = p })
		end
		return T("weather.fx.none")
	end

	-- o chip apareceu ou sumiu: a fila de cima se arruma (o Mega Ovo dá lugar; a faixa de evento e os avisos descem)
	local function shiftTop()
		Hud.Top()
	end

	-- O clima de agora: quem sabe é o World (atributos do workspace + Fx). Devolve (definição, hora em que acaba, id do próximo).
	local function weatherNow(): (any, number, any)
		if World.Weather then
			local ok, id, untilAt, nextId = pcall(World.Weather)
			if ok and id ~= nil and WEATHER[id] then
				return WEATHER[id], num(untilAt), nextId
			end
		end
		return nil, 0, nil
	end

	-- Escreve o chip (só mexe no que mudou; chamado algumas vezes por segundo por causa do relógio)
	function V5.Chip()
		local def, untilAt, nextId = weatherNow()
		if not def then
			if chip.Visible then
				chip.Visible = false
				shiftTop()
			end
			return
		end
		if chipShown.Id ~= def.Id then
			chipShown.Id = def.Id
			chipIcon.Text = tostring(def.Emoji or "")
			chipName.Text = T("weather." .. def.Id)
			chipFx.Text = weatherFx(def)
			chipFx.TextColor3 = if num(def.Mult, 1) > 1 then C.Yellow else C.Cream
			chip.BackgroundColor3 = WEATHER_BG[def.Id] or WEATHER_BG.limpo
		end
		local nextDef = if nextId ~= nil then WEATHER[nextId] else nil
		local nextShown = if nextDef then nextDef.Id else ""
		if chipShown.Next ~= nextShown then
			chipShown.Next = nextShown
			chipNext.Text = if nextDef then T("weather.next", { e = tostring(nextDef.Emoji or ""), name = T("weather." .. nextDef.Id) }) else ""
		end
		local left = if untilAt > 0 then math.max(0, math.ceil(untilAt - workspace:GetServerTimeNow())) else -2
		if left ~= chipShown.Left then
			chipShown.Left = left
			chipClock.Text = if left >= 0 then Format.Time(left) else ""
		end
		if not chip.Visible then
			chip.Visible = true
			shiftTop()
		end
	end

	-- O clima mudou (o World avisa; first = é o que já estava quando eu entrei). Aviso a cada troca, menos no
	-- "limpo" e menos no que já estava; a dica do clima aparece uma vez (ver V5.Tip).
	V5.WeatherTip = { Until = 0, Seen = false, Done = false }
	V5.WeatherTone = { sol = 1.18, chuva = 0.86, vento = 1.05, noite = 0.76, arcoiris = 1.34 }
	function V5.OnWeather(id: string, first: boolean)
		V5.Chip()
		local def = WEATHER[id]
		if not def or not chip.Visible then
			return
		end
		UI.Pop(chip, 1.12)
		if id == "limpo" then
			return
		end
		if not first then
			UI.Toast(T("weather.toast", { e = tostring(def.Emoji or ""), name = T("weather." .. id), fx = weatherFx(def) }), "event")
			-- cada clima chega num tom (o mesmo som, mais grave à noite e na chuva, mais agudo no sol e no arco-íris)
			UI.Sound("Evento", 0.45, V5.WeatherTone[id] or 1)
		end
		-- (se a dica já apareceu, esta troca não a traz de volta nem a estica: é uma vez só)
		if not V5.WeatherTip.Done and not V5.WeatherTip.Seen then
			V5.WeatherTip.Until = os.clock() + 12
		end
	end

	-- ===== contador de chaves (3ª pílula pequena da fila de cima) =====
	local keysPill = new("Frame", { Name = "Keys", Size = UDim2.fromOffset(112, 40), BackgroundColor3 = C.Blue, LayoutOrder = 4, Visible = false, Parent = top }, { UI.Corner(0.5), UI.Stroke(C.DarkBrown, 3) })
	Hud.Keys = keysPill
	local keysText = UI.Label({ Name = "Text", Position = UDim2.new(0.07, 0, 0.14, 0), Size = UDim2.new(0.86, 0, 0.72, 0), Text = "", MaxText = 26, ZIndex = 2, Parent = keysPill })
	local keysShown = -1

	local function bizCount(): number
		if type(state.BizCount) == "number" then
			return state.BizCount
		end
		local n = 0
		for index in Config.Businesses do
			if bizOf(index).Unlocked == true then
				n += 1
			end
		end
		return n
	end

	-- tem as chaves todas? (o Baú Secreto já pode ser aberto)
	function V5.ChestReady(): boolean
		if not state then
			return false
		end
		local need = num(state.KeyNeed)
		return need > 0 and num(state.Keys) >= need
	end

	local function keysHud()
		local need, have = num(state.KeyNeed), num(state.Keys)
		-- só depois de liberar (a Granja aberta); quem já tem chave na mão ou escondida também vê
		local show = state.KeyNeed ~= nil and state.Keys ~= nil and need > 0 and (bizCount() >= num(KEYS.MinBiz) or have > 0 or state.Key == true)
		if show ~= keysPill.Visible then
			keysPill.Visible = show
			Hud.Top() -- (se era a única pílula, a fila de cima aparece ou some)
		end
		if show then
			keysText.Text = T("hud.keys", { n = have, m = need })
			keysPill.BackgroundColor3 = if have >= need then C.Green else C.Blue
			if have > keysShown and keysShown >= 0 then
				UI.Pop(keysPill)
			end
			keysShown = have
		end
	end

	-- ===== barra de poderes =====
	local CELL = 104 -- largura de cada casa (botão + nome embaixo)
	local BUTTON = if isTouch then 84 else 72 -- no celular o botão é maior (uns 44 px de verdade numa tela de 375 de altura)
	local BAR_H = BUTTON + 36
	local BAR_BOTTOM = 180 -- do fundo da tela até a base da barra (o valor de verdade vem de Hud.BarBottom: ver V5.Layout)
	local bar = new("Frame", { Name = "Powers", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -190, 1, -BAR_BOTTOM), Size = UDim2.fromOffset(CELL * #POWERS, BAR_H), BackgroundTransparency = 1, Visible = false, Parent = gui })
	-- explicação de um poder (segurar o dedo no botão, ou passar o mouse): aparece em cima da barra
	local hint = UI.Label({ Name = "PowerHint", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -190, 1, -(BAR_BOTTOM + BAR_H + 8)), Size = UDim2.fromOffset(340, 56), BackgroundColor3 = C.DarkBrown, BackgroundTransparency = 0.2, Text = "", Font = UI.Font2, TextWrapped = true, MaxText = 20, Visible = false, ZIndex = 3, Parent = gui })
	UI.Corner(0.25).Parent = hint
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), Parent = hint })
	local cells: { any } = {}
	local hintFor: string? = nil -- id do poder explicado agora
	local hintAt = 0 -- os.clock() em que a explicação apareceu (some sozinha: no celular o "saiu de cima" nem sempre chega)
	local press: any = nil -- toque em andamento num botão de poder: { Id, Long }
	local lastUse = 0 -- os.clock() do último pedido "Power"
	local known = false -- já recebi a lista de poderes uma vez? (para o aviso de poder NOVO não tocar ao entrar)
	local was: { [string]: boolean } = {} -- [id] = estava liberado no último estado
	V5.PowerTip = { Until = 0, Next = 0, Count = 0 }
	V5.ReadySince = nil :: number? -- os.clock() desde quando há um poder pronto sem usar

	-- Como está o poder agora: ("locked" | "wait" | "active" | "ready", segundos que aparecem no botão, segundos
	-- até ficar pronto). ReadyAt e Until vêm na hora do servidor (workspace:GetServerTimeNow), como os Boosts.
	local function powerState(power: any): (string, number, number)
		local sent: any = nil
		for _, item in tbl(state and state.Powers) do
			if type(item) == "table" and item.Id == power.Id then
				sent = item
			end
		end
		if not sent or sent.Unlocked ~= true then
			return "locked", 0, 0
		end
		local now = workspace:GetServerTimeNow()
		local wait = math.max(0, num(sent.ReadyAt) - now)
		local active = num(sent.Until) - now
		if active > 0 then
			return "active", active, wait
		elseif wait > 0 then
			return "wait", wait, wait
		end
		return "ready", 0, 0
	end

	local function clockText(seconds: number): string
		seconds = math.ceil(seconds)
		return if seconds < 60 then seconds .. "s" else Format.Time(seconds)
	end

	local function powerDesc(power: any): string
		local kind = powerState(power)
		local name = T("power." .. power.Id)
		if kind == "locked" then
			return ("🔒 %s\n%s"):format(name, T("power.locked", { n = num(power.MinBiz) }))
		end
		return ("%s\n%s"):format(name, T("power." .. power.Id .. ".d", { n = power.Speed, s = power.Duration or power.Seconds }))
	end

	local function showHint(power: any?)
		hintFor = if power then power.Id else nil
		hintAt = os.clock()
		hint.Visible = power ~= nil and bar.Visible
		if power then
			hint.Text = powerDesc(power)
		end
	end

	-- esconde a explicação daqui a pouco, se ainda for a deste poder e ninguém estiver segurando o botão
	local function hideHintSoon(power: any, seconds: number)
		task.delay(seconds, function()
			if hintFor == power.Id and press == nil then
				showHint(nil)
			end
		end)
	end

	-- Toque num poder: pronto = pede ao servidor; trancado ou em recarga = só o aviso (nada é mandado)
	local function usePower(cell: any)
		local power = cell.Power
		local kind, _shown, wait = powerState(power)
		if kind == "ready" then
			local now = os.clock()
			if now - lastUse < 0.6 then
				return -- toque duplo: um pedido só
			end
			lastUse = now
			UI.Sound("Clique", 0.45, 1.2)
			UI.Pop(cell.Button, 0.88)
			request("Power", power.Id)
			return
		end
		UI.Sound("Erro", 0.35, 1.1)
		if kind == "locked" then
			UI.Toast(T("n.powerLocked"), "info")
			showHint(power) -- (a explicação diz quantos negócios faltam)
			hideHintSoon(power, 2.5)
		elseif wait > 0 then
			UI.Toast(T("n.powerWait", { s = math.ceil(wait) }), "info")
		end
	end

	for index, power in POWERS do
		local color: Color3 = if typeof(power.Color) == "Color3" then power.Color else C.Orange
		local cell: any = { Power = power, Color = color, Shown = "" }
		local frame = new("Frame", { Name = tostring(power.Id), Position = UDim2.fromOffset((index - 1) * CELL, 0), Size = UDim2.fromOffset(CELL, BAR_H), BackgroundTransparency = 1, Parent = bar })
		cell.Stroke = UI.Stroke(C.DarkBrown, 3)
		local button = new("TextButton", { Name = "Button", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(BUTTON, BUTTON), BackgroundColor3 = C.Gray, Text = "", AutoButtonColor = false, Parent = frame }, { UI.Corner(1), cell.Stroke, UI.Shine() })
		cell.Button = button
		-- (âncora no meio: o desenho pulsa em volta do próprio centro)
		cell.Icon = UI.Icon("", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.37), Size = UDim2.fromScale(0.66, 0.6), ZIndex = 2, Parent = button }, tostring(power.Emoji or "⚡"))
		cell.Scale = new("UIScale", { Name = "Pulse", Parent = cell.Icon })
		cell.Status = UI.Label({ Name = "Status", Position = UDim2.fromScale(0.06, 0.66), Size = UDim2.fromScale(0.88, 0.25), Text = "", MaxText = 17, ZIndex = 3, Parent = button })
		cell.Clock = UI.Label({ Name = "Clock", Position = UDim2.fromScale(0.08, 0.22), Size = UDim2.fromScale(0.84, 0.56), Text = "", MaxText = 34, Visible = false, ZIndex = 3, Parent = button })
		cell.Caption = UI.Label({ Name = "Caption", Position = UDim2.fromOffset(2, BUTTON + 3), Size = UDim2.new(1, -4, 0, 32), Text = "", TextWrapped = true, MaxText = 15, ZIndex = 2, Parent = frame })
		cells[index] = cell
		-- segurar o dedo (ou o botão do mouse) por meio segundo mostra a explicação e NÃO usa o poder
		button.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
				local mine = { Id = power.Id, Long = false }
				press = mine
				task.delay(0.45, function()
					if press == mine then
						mine.Long = true
						showHint(power)
					end
				end)
			end
		end)
		button.InputEnded:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if press and press.Id == power.Id and (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) then
				local mine = press
				-- (o Activated do mesmo toque chega logo depois e ainda precisa saber se foi um toque longo)
				task.delay(0.15, function()
					if press == mine then
						press = nil
					end
				end)
				if mine.Long then
					hideHintSoon(power, 1.2)
				end
			end
		end)
		button.MouseEnter:Connect(function()
			if not isTouch then -- no celular o toque também dispara MouseEnter: a dica já aparece pelo toque longo
				showHint(power)
			end
		end)
		button.MouseLeave:Connect(function()
			if hintFor == power.Id and not (press and press.Long) then
				showHint(nil)
			end
		end)
		button.Activated:Connect(function()
			local mine = press
			press = nil
			if mine and mine.Id == power.Id and mine.Long then
				hideHintSoon(power, 1.2)
				return -- foi um toque longo: só mostrou a explicação
			end
			usePower(cell)
		end)
	end

	-- Recarga em Robux: sem pop-up e sem botão piscando. Só um "⚡" pequeno e parado, à esquerda da barra, que
	-- ABRE a loja; e só existe se o produto Recarga estiver à venda (Id diferente de 0 no Config).
	local refill: TextButton? = nil
	local refillProduct: any = nil
	for _, product in tbl(Config.Products) do
		if product.Key == "Recarga" and num(product.Id) > 0 then
			refillProduct = product
			refill = UI.Button({ Name = "Refill", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(-6, (BUTTON - 40) / 2), Size = UDim2.fromOffset(40, 40), Text = "⚡", BackgroundColor3 = C.Gray, MaxText = 22, Visible = false, Parent = bar }, function()
				openGroup("Shop")
			end)
		end
	end

	-- Pinta um botão conforme o estado (só quando muda o estado ou o número de segundos escrito)
	local PULSE = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local function paint(cell: any, kind: string, seconds: number)
		local power = cell.Power
		local shown = if kind == "wait" or kind == "active" then kind .. math.ceil(seconds) else kind
		if shown == cell.Shown then
			return
		end
		local changed = string.sub(cell.Shown, 1, #kind) ~= kind or kind == "locked" or kind == "ready"
		-- a recarga acabou agora (estava contando e ficou pronto): um "plim" baixinho e o botão pula
		if kind == "ready" and string.sub(cell.Shown, 1, 4) == "wait" and bar.Visible then
			UI.Sound("Premio", 0.3, 1.5)
			UI.Pop(cell.Button, 1.2)
		end
		cell.Shown = shown
		if kind == "wait" or kind == "active" then
			cell.Clock.Text = clockText(seconds)
		end
		if not changed then
			return
		end
		local color: Color3 = cell.Color
		local icon: any = cell.Icon
		local ready, locked = kind == "ready", kind == "locked"
		cell.Button.BackgroundColor3 = if locked then C.Gray elseif kind == "wait" then color:Lerp(C.Black, 0.62) elseif kind == "active" then color:Lerp(C.White, 0.3) else color
		cell.Stroke.Color = if kind == "active" then C.Yellow else C.DarkBrown
		icon.Text = if locked then "🔒" else tostring(power.Emoji or "⚡")
		icon.TextTransparency = if kind == "wait" then 0.65 elseif kind == "active" then 0.45 else 0
		cell.Clock.Visible = kind == "wait" or kind == "active"
		cell.Clock.TextColor3 = if kind == "active" then C.Yellow else C.White
		cell.Status.Text = if ready then T("power.ready") else ""
		cell.Caption.Text = if locked then T("power.locked", { n = num(power.MinBiz) }) else T("power." .. power.Id)
		cell.Caption.TextColor3 = if locked then C.Cream else C.White
		-- pronto: o desenho do botão pulsa de leve (o motor anima sozinho; nada roda por quadro aqui)
		if cell.Pulse then
			cell.Pulse:Cancel()
			cell.Pulse = nil
		end
		cell.Scale.Scale = 1
		if ready then
			cell.Pulse = TweenService:Create(cell.Scale, PULSE, { Scale = 1.12 })
			cell.Pulse:Play()
		end
	end

	-- A barra aparece depois que a banca abre (antes disso a tela do jogador novo só tem o essencial), se o
	-- servidor mandou os poderes, e some enquanto um painel está aberto.
	local function barVisible()
		local show = state ~= nil and type(state.Powers) == "table" and #state.Powers > 0 and UI.OpenPanel == nil and bizOf(1).Unlocked == true
		if show ~= bar.Visible then
			bar.Visible = show
			if not show then
				showHint(nil)
				press = nil
			end
		end
	end

	-- algumas vezes por segundo: estado e relógio de cada botão
	local function paintPowers()
		barVisible()
		if not state or type(state.Powers) ~= "table" then
			return
		end
		local anyReady, anyOpen = false, false
		for _, cell in cells do
			local kind, seconds = powerState(cell.Power)
			paint(cell, kind, seconds)
			anyReady = anyReady or kind == "ready"
			anyOpen = anyOpen or kind ~= "locked"
		end
		if not anyReady then
			V5.ReadySince = nil
		elseif not V5.ReadySince then
			V5.ReadySince = os.clock()
		end
		local button = refill
		if button then
			button.Visible = anyOpen and Loja.ProductOnSale(refillProduct) == true
		end
		if hintFor and hint.Visible then
			if press == nil and os.clock() - hintAt > 4 then
				showHint(nil) -- ficou na tela sem ninguém segurando: some
			else
				for _, cell in cells do
					if cell.Power.Id == hintFor then
						hint.Text = powerDesc(cell.Power)
					end
				end
			end
		end
	end

	-- estado novo: algum poder passou de trancado para liberado? (aviso + o botão pula)
	local function powersHud()
		if type(state.Powers) ~= "table" then
			return
		end
		for _, cell in cells do
			local id = cell.Power.Id
			local open = powerState(cell.Power) ~= "locked"
			if known and open and was[id] == false then
				UI.Toast(T("power.new", { name = T("power." .. id) }), "success")
				UI.Sound("Premio", 0.55, 1.25)
				UI.Pop(cell.Button, 1.35)
			end
			was[id] = open
		end
		known = true
		paintPowers()
	end

	-- Fx "power" meu: o aviso de que o poder foi usado (o desenho no mundo é do World.PowerFx)
	V5.Rare = nil :: { any }? -- { posição, os.clock() } do último ovo raro que apareceu no meu terreno
	V5.LuckAt = nil :: number? -- os.clock() em que usei o Ovo da Sorte e o ovo ainda não tinha aparecido
	function V5.PowerUsed(id: string, coins: number, seconds: number, atNest: boolean?)
		local power = tbl(Config.PowerById)[id]
		local color: Color3 = if power and typeof(power.Color) == "Color3" then power.Color else C.Yellow
		for _, cell in cells do
			if cell.Power.Id == id then
				UI.Pop(cell.Button, 1.3)
			end
		end
		if id == "galo" then
			UI.BigPopup(gui, T("power.use.galo", { n = if power then power.Speed else 2, s = math.floor((if seconds > 0 then seconds else num(power and power.Duration)) + 0.5) }), color, 2.4)
			UI.Sound("Evento", 0.65, 1.3) -- o canto do galo: o som de evento, agudo
		elseif id == "moedas" then
			if coins <= 0 and power then
				-- o servidor não disse quanto pagou: a mesma conta por alto que a loja faz
				coins = math.max(num(power.Min), math.floor(num(state and state.All) * num(power.Seconds)))
			end
			UI.BigPopup(gui, T("power.use.moedas", { n = short(coins) }), color, 2.4)
			Hud.Fly(10)
			UI.Sound("Premio", 0.65, 1.1)
			task.delay(0.35, UI.Sound, "Coletar", 0.5, 1.15) -- as moedas chegando no contador
		else
			-- (sorte: o letreiro grande fica para o ovo raro que aparece, pelo Fx "rare" de sempre)
			UI.Toast(T("power.use." .. id), "success")
			UI.Sound("Mutante", 0.65, 1.15)
			local rare = V5.Rare
			if id == "sorte" and not atNest then
				if rare and os.clock() - rare[2] < 1.5 then
					World.Puff(rare[1], color) -- o ovo já apareceu: faísca verde no ninho dele
				else
					V5.LuckAt = os.clock() -- ainda não: a faísca sai quando o Fx "rare" chegar
				end
			end
		end
	end

	-- ===== dicas da versão 5 (só quando o tutorial não tem nada mais importante para dizer) =====
	function V5.Tip(): string
		local clock = os.clock()
		-- chave escondida no meu terreno, para quem ainda achou poucas: menos de 3 na vida (KeysFound, se o
		-- servidor mandar) ou nenhum baú aberto ainda. Depois disso o aviso de que ela apareceu basta.
		local beginner = if state.KeysFound ~= nil then num(state.KeysFound) < 3 else num(state.Chests) < 1
		if state.Key == true and beginner and not V5.ChestReady() then
			return "tip.key"
		end
		-- poder pronto há muito tempo sem usar: só para quem ainda está aprendendo o jogo, por 10 s, e no
		-- máximo 3 vezes (com 5 minutos entre uma e outra). Quem já sabe tem o botão pulsando.
		local p = V5.PowerTip
		if V5.ReadySince and num(state.Buttons) < 45 then
			if clock < p.Until then
				return "tip.power"
			elseif p.Count < 3 and clock >= p.Next and clock - V5.ReadySince >= 90 then
				p.Count += 1
				p.Until = clock + 10
				p.Next = clock + 300
				return "tip.power"
			end
		end
		-- clima: uma vez, nos 12 s depois da primeira troca que ajuda em alguma coisa
		local w = V5.WeatherTip
		if not w.Done then
			if clock < w.Until then
				w.Seen = true
				return "tip.weather"
			elseif w.Seen then
				w.Done = true
			end
		end
		return ""
	end

	-- ===== ligações =====
	function V5.Layout()
		-- logo acima do topo que a pilha do meio pode ter (contador de moedas, dica e barra de trabalho; mais o
		-- botão de comprar de longe, quando existe) e à esquerda de tudo que mora no canto de baixo à direita:
		-- o VENDER (12 px de folga) e, no celular, o botão de pulo do Roblox (20 px)
		local bottom = num(Hud.BarBottom, BAR_BOTTOM)
		local right = -sell.Position.X.Offset + SELL_SIZE + 12
		if isTouch then
			right = math.max(right, num(V5.JumpLeft) + 20)
		end
		bar.Position = UDim2.new(1, -right, 1, -bottom)
		hint.Position = UDim2.new(1, -right, 1, -(bottom + BAR_H + 8))
	end

	-- estado novo do servidor (State ou Tick)
	function V5.Hud()
		if World.WeatherState then
			World.WeatherState(state.Weather)
		end
		keysHud()
		powersHud()
	end

	-- algumas vezes por segundo: relógios
	function V5.Slow()
		V5.Chip()
		paintPowers()
	end

	-- idioma mudou: tudo escrito de novo
	function V5.Relabel()
		chipShown.Id, chipShown.Next, chipShown.Left = false, false, -1
		for _, cell in cells do
			cell.Shown = ""
		end
		V5.Chip()
		if state then
			keysHud()
			paintPowers()
		end
	end

	-- abriu ou fechou um painel: a barra some ou volta na hora (e a dica e a barra de trabalho também: Hud.PanelChanged)
	UI.OnShow = function()
		barVisible()
		if Hud.PanelChanged then
			Hud.PanelChanged()
		end
	end
	V5.Layout()
	Hud.TopKey = nil
	Hud.Top()
end
V5.Build()

-- ---------------------------------------------------------------------------
-- Painéis (com abas quando o grupo tem mais de um)
-- ---------------------------------------------------------------------------
local TAB_KEYS = { Pets = "tab.pets", Album = "tab.album", Rebirth = "tab.rebirth", Talents = "tab.talents", Wheel = "tab.wheel", Missions = "tab.missions", Gifts = "tab.gifts" }
local tabButtons: { { Button: TextButton, Key: string } } = {}

local function groupOf(name: string): (string?, { string }?)
	for group, tabs in GROUPS do
		if table.find(tabs, name) then
			return group, tabs
		end
	end
	return nil, nil
end

local function makePanel(name: string, titleKey: string, color: Color3): ScrollingFrame
	local list, title = UI.MakePanel(gui, name, color)
	title.Text = T(titleKey)
	panelTitles[name] = { Label = title, Key = titleKey }
	local group, tabs = groupOf(name)
	if group and tabs and #tabs > 1 then
		-- abas: uma fileira de 60 px logo abaixo do título (posição fixa, sem UIListLayout: o pulinho do
		-- botão ao tocar não empurra as abas vizinhas)
		local panel = UI.Panels[name]
		list.Position = UDim2.new(0, 14, 0, 144)
		list.Size = UDim2.new(1, -28, 1, -156)
		local row = new("Frame", { Name = "Tabs", Position = UDim2.new(0, 14, 0, 76), Size = UDim2.new(1, -28, 0, 60), BackgroundTransparency = 1, ZIndex = 6, Parent = panel })
		for i, tab in tabs do
			local b = UI.Button({ Name = tab, Position = UDim2.new((i - 1) / #tabs, 3, 0, 0), Size = UDim2.new(1 / #tabs, -6, 1, 0), Text = T(TAB_KEYS[tab]), BackgroundColor3 = if tab == name then color else C.Gray, MaxText = 22, ZIndex = 6, Parent = row }, function()
				openGroup(group, tab)
			end)
			table.insert(tabButtons, { Button = b, Key = TAB_KEYS[tab] })
		end
	end
	return list
end

local function petName(key: string): string
	return Lang.Pet(Config, key)
end

local function petIcon(key: string): string
	local lineId = Sim.ParseKey(key)
	local line = Config.LineById[lineId]
	if line then
		return "R_" .. line.Asset
	end
	return Config.PetIcon[lineId] or "Ovo_Dourado"
end

-- NEGÓCIOS: os 8 negócios, o que cada um rende e o que falta abrir
local BIZ_EMOJI = { banca = "🥚", granja = "🐔", entrega = "🚚", fabrica = "🏭", deposito = "📦", omeleteria = "🍳", lab = "🧪", foguete = "🚀" }
local bizList = makePanel("Biz", "bizpanel.title", C.Orange)
UI.Refreshers.Biz = function()
	UI.Clear(bizList)
	if not state then
		return
	end
	local coins = num(state.Coins)
	-- topo: renda total (sozinho = só com gerente) e a próxima compra
	local head = new("Frame", { Name = "Total", Size = UDim2.new(1, -10, 0, 72), BackgroundColor3 = C.Cream, LayoutOrder = 0, ZIndex = 6, Parent = bizList }, { UI.Corner(0.2), UI.Stroke(C.Brown, 2) })
	UI.Label({ Position = UDim2.new(0.03, 0, 0.08, 0), Size = UDim2.new(0.94, 0, 0.46, 0), Text = "💰 " .. T("bizpanel.total", { auto = short(num(state.Auto)), all = short(num(state.All)) }), Dark = true, MaxText = 26, ZIndex = 7, Parent = head })
	local nextButton = nextButtonOf()
	UI.Label({
		Position = UDim2.new(0.03, 0, 0.56, 0),
		Size = UDim2.new(0.94, 0, 0.36, 0),
		Text = if nextButton then T("bizpanel.next", { name = (Lang.Button(Config, nextButton, short)), cost = short(nextButton.Cost) }) else T("bizpanel.maxed"),
		Dark = true,
		TextColor3 = if nextButton and coins >= nextButton.Cost then C.DarkGreen else C.Brown,
		Font = UI.Font2,
		MaxText = 18,
		ZIndex = 7,
		Parent = head,
	})
	for i, def in Config.Businesses do
		local b = bizOf(i)
		local open = b.Unlocked == true
		local managed = open and b.Manager == true
		-- negócio fechado aparece apagado, com o preço do botão que abre
		local row = new("Frame", { Name = def.Id, Size = UDim2.new(1, -10, 0, 98), BackgroundColor3 = C.Cream, BackgroundTransparency = if open then 0 else 0.5, LayoutOrder = i, ZIndex = 6, Parent = bizList }, { UI.Corner(0.18), UI.Stroke(if open then C.Brown else C.Gray, 2) })
		local chip = new("Frame", { Position = UDim2.new(0, 8, 0.5, -39), Size = UDim2.fromOffset(78, 78), BackgroundColor3 = def.Color, BackgroundTransparency = if open then 0 else 0.6, ZIndex = 7, Parent = row }, { UI.Corner(0.3), UI.Stroke(if open then C.DarkBrown else C.Gray, 3) })
		UI.Icon("Biz_" .. def.Id, { Position = UDim2.fromScale(0.12, 0.12), Size = UDim2.fromScale(0.76, 0.76), ImageTransparency = if open then 0 else 0.5, ZIndex = 8, Parent = chip }, BIZ_EMOJI[def.Id])
		UI.Label({ Position = UDim2.new(0, 98, 0.06, 0), Size = UDim2.new(0.62, -98, 0.34, 0), Text = ("%d. %s"):format(i, T("biz." .. def.Id)), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = if open then C.DarkBrown else C.Brown, MaxText = 26, ZIndex = 7, Parent = row })
		local status, statusColor = T("biz.closed"), C.Brown
		if managed then
			status, statusColor = T("biz.managed"), C.DarkGreen
		elseif open then
			status, statusColor = T("biz.manual"), C.Orange
		end
		UI.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0.07, 0), Size = UDim2.new(0.34, 0, 0.3, 0), Text = status, TextXAlignment = Enum.TextXAlignment.Right, Dark = true, TextColor3 = statusColor, MaxText = 20, ZIndex = 7, Parent = row })
		local line2, line3
		if open then
			-- sem gerente o ciclo é feito na mão e vale mais (state.Hand)
			local each = num(b.Payout) * (if managed then 1 else num(state.Hand, 1))
			line2 = ("%s   %s   ⏱ %s"):format(T("biz.income", { n = short(num(b.Income)) }), T("biz.percycle", { n = short(each) }), secs(num(b.Cycle)))
			line3 = T("bizpanel.detail", { cash = Format.Mult(num(b.Cash, 1)), speed = Format.Mult(num(b.Speed, 1)) })
		else
			local unlock = Config.ButtonById[def.Id .. "_unlock"]
			local cost = if unlock then unlock.Cost else 0
			line2 = T("biz." .. def.Id .. ".d")
			line3 = if cost > 0 then "💰 " .. short(cost) else T("btn.free")
			statusColor = if coins >= cost then C.DarkGreen else C.Red
		end
		UI.Label({ Position = UDim2.new(0, 98, 0.42, 0), Size = UDim2.new(1, -108, 0.26, 0), Text = line2, TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = C.Brown, Font = UI.Font2, MaxText = 18, ZIndex = 7, Parent = row })
		UI.Label({ Position = UDim2.new(0, 98, 0.69, 0), Size = UDim2.new(1, -108, 0.25, 0), Text = line3, TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = if open then C.Purple else statusColor, Font = UI.Font2, MaxText = if open then 17 else 20, ZIndex = 7, Parent = row })
	end
	-- Loja: UMA linha pequena no fim da lista, só para quem não tem o passe Dinheiro2x (e só se ele está à
	-- venda). Tocar abre a Loja, onde estão o efeito e o preço; nada é comprado direto daqui.
	local x2 = Loja.PassOnSale("Dinheiro2x")
	if x2 then
		UI.Button({ Name = "X2", Size = UDim2.new(1, -10, 0, 44), Text = ("%s   %s  ›"):format(T("bizpanel.x2"), Loja.Price(x2)), Font = UI.Font2, BackgroundColor3 = C.Blue, MaxText = 18, LayoutOrder = 99, ZIndex = 6, Parent = bizList }, function()
			openGroup("Shop")
		end)
	end
end

-- PETS: chocadeiras, pets equipados e a coleção
local petsList = makePanel("Pets", "pets.title", C.Pink)
UI.Refreshers.Pets = function()
	UI.Clear(petsList)
	if not state then
		return
	end
	local now = workspace:GetServerTimeNow()
	local order = 0
	-- chocadeiras
	local hatchSlots = num(state.HatchSlots)
	local hatching = tbl(state.Hatch)
	if hatchSlots <= 0 then
		UI.Note(petsList, 0, T("pets.noIncubator"), 46)
	end
	for slot = 1, hatchSlots do
		local hatch = hatching[tostring(slot)]
		order += 1
		if type(hatch) == "table" and hatch.Key ~= nil then
			local key = tostring(hatch.Key)
			local left = num(hatch.ReadyAt) - now
			local ready = left <= 0
			local _, hatchButton = UI.Card(petsList, order, UI.Icon(petIcon(key), {}), T("pets.incubator", { n = slot }), if ready then T("pets.ready") else T("pets.hatching", { pet = petName(key) }), if ready then T("pets.goGet") else Format.Time(left), if ready then C.Green else C.Gray, nil)
			if not ready then
				UI.LiveText(hatchButton, num(hatch.ReadyAt), function(remaining)
					return Format.Time(remaining)
				end)
			end
		else
			UI.Card(petsList, order, UI.Icon("Ovo_Branco", {}, "🥚"), T("pets.incubator", { n = slot }), T("pets.empty"), "...", C.Gray, nil)
		end
	end
	-- v6: "Chocar já" (produto). Aparece só com ovo chocando e o produto criado no Roblox (Id no Config).
	local hatchProduct = nil
	for _, product in Config.Products do
		if product.Kind == "hatch" and (Loja.ProductOnSale(product) or Loja.Preview) then
			hatchProduct = product
		end
	end
	local anyHatching = false
	for _, hatch in hatching do
		if type(hatch) == "table" and num(hatch.ReadyAt) > now then
			anyHatching = true
		end
	end
	if hatchProduct and anyHatching then
		order += 1
		UI.Card(petsList, order, UI.Icon(hatchProduct.Icon, {}, hatchProduct.Emoji), T("prod." .. hatchProduct.Key), T("prod." .. hatchProduct.Key .. ".d"), Loja.Price(hatchProduct), C.Green, function()
			request("BuyProduct", hatchProduct.Key)
		end)
	end
	-- resumo
	local list = {}
	for key, count in tbl(state.Pets) do
		local level = math.min(num(count, 1), Config.Pets.MaxLevel)
		table.insert(list, { Key = tostring(key), Level = level, Bonus = Sim.PetBonus(Config, tostring(key), level) })
	end
	table.sort(list, function(a, b)
		if a.Bonus ~= b.Bonus then
			return a.Bonus > b.Bonus
		end
		return a.Key < b.Key
	end)
	local equip = tbl(state.Equip)
	local petSlots = num(state.PetSlots)
	local equipped = math.min(#equip, petSlots)
	local head = new("Frame", { Size = UDim2.new(1, -10, 0, 76), BackgroundColor3 = C.Cream, LayoutOrder = 10, ZIndex = 6, Parent = petsList }, { UI.Corner(0.2), UI.Stroke(C.Brown, 2) })
	UI.Label({ Position = UDim2.new(0.03, 0, 0.08, 0), Size = UDim2.new(0.6, 0, 0.44, 0), Text = T("pets.equipped", { a = equipped, b = petSlots, mult = Format.Mult(num(tbl(state.CashParts).Pets, 1)) }), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, MaxText = 22, ZIndex = 7, Parent = head })
	UI.Label({ Position = UDim2.new(0.03, 0, 0.54, 0), Size = UDim2.new(0.6, 0, 0.38, 0), Text = if state.NextPetSlotAt then T("pets.nextSlot", { n = state.NextPetSlotAt, have = #list }) else T("pets.maxSlots"), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = C.Brown, Font = UI.Font2, MaxText = 16, ZIndex = 7, Parent = head })
	UI.Button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.33, 0, 0, 60), Text = T("pets.best"), BackgroundColor3 = C.Blue, MaxText = 22, ZIndex = 7, Parent = head }, function()
		request("EquipBest")
	end)
	if #list == 0 then
		UI.Note(petsList, 11, T("pets.none"), 60)
	end
	for i, pet in list do
		local on = table.find(equip, pet.Key) ~= nil
		local desc = T("pets.bonus", { n = math.floor(pet.Bonus * 100 + 0.5), level = pet.Level, max = Config.Pets.MaxLevel })
		local card = UI.Card(petsList, 20 + i, UI.Icon(petIcon(pet.Key), {}), petName(pet.Key), desc, if on then T("pets.unequip") else T("pets.equip"), if on then C.Orange elseif equipped < petSlots then C.Green else C.Gray, function()
			request(if on then "UnequipPet" else "EquipPet", pet.Key)
		end)
		if on then
			card.BackgroundColor3 = Color3.fromRGB(214, 245, 214)
		end
	end
end

-- ÁLBUM: 9 ovos x (normal + 3 raridades). A figurinha normal vem ao liberar a ave; as raras, ao vender o ovo raro.
local albumList = makePanel("Album", "album.title", C.Pink)
UI.Refreshers.Album = function()
	UI.Clear(albumList)
	if not state then
		return
	end
	local album = tbl(state.Album)
	local total = #Config.Lines * (#Config.Mutations + 1)
	local have = 0
	for _ in album do
		have += 1
	end
	UI.Note(albumList, 0, T("album.info", { n = have, total = total, bonus = Format.Mult(1 + Config.AlbumBonus * have) }), 44)
	for i, line in Config.Lines do
		local row = new("Frame", { Size = UDim2.new(1, -10, 0, 86), BackgroundColor3 = C.Cream, LayoutOrder = i, ZIndex = 6, Parent = albumList }, { UI.Corner(0.18), UI.Stroke(C.Brown, 2) })
		UI.Label({ Position = UDim2.new(0.02, 0, 0.04, 0), Size = UDim2.new(0.96, 0, 0.24, 0), Text = T("egg." .. line.Id), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, MaxText = 20, ZIndex = 7, Parent = row })
		local variants = { { Id = "", Key = "normal", Color = C.White } }
		for _, m in Config.Mutations do
			table.insert(variants, m)
		end
		for v, variant in variants do
			local key = if variant.Id == "" then line.Id else line.Id .. ":" .. variant.Id
			local count = album[key]
			local cell = new("Frame", { Position = UDim2.new(0.02 + (v - 1) * 0.245, 0, 0.3, 0), Size = UDim2.new(0.225, 0, 0.64, 0), BackgroundColor3 = if count then variant.Color else C.Gray, BackgroundTransparency = if count then 0.35 else 0.6, ZIndex = 7, Parent = row }, { UI.Corner(0.25), UI.Stroke(C.Brown, 2) })
			UI.Icon(line.EggAsset, { Position = UDim2.new(0.04, 0, 0.06, 0), Size = UDim2.new(0.36, 0, 0.88, 0), ImageTransparency = if count then 0 else 0.75, ZIndex = 8, Parent = cell })
			UI.Label({ Position = UDim2.new(0.42, 0, 0.06, 0), Size = UDim2.new(0.56, 0, 0.44, 0), Text = if count then T("mut." .. variant.Key) else "???", Dark = true, MaxText = 16, ZIndex = 8, Parent = cell })
			UI.Label({ Position = UDim2.new(0.42, 0, 0.5, 0), Size = UDim2.new(0.56, 0, 0.44, 0), Text = if count then "x" .. short(num(count, 1)) else "", Dark = true, TextColor3 = C.Brown, MaxText = 16, Font = UI.Font2, ZIndex = 8, Parent = cell })
		end
	end
	UI.Note(albumList, 50, T("album.hint"), 44)
end

-- RENASCER e SELO
local rebirthList = makePanel("Rebirth", "rebirth.title", C.Blue)
local rebirthArmed = 0
UI.Refreshers.Rebirth = function()
	UI.Clear(rebirthList)
	if not state then
		return
	end
	local info = new("Frame", { Size = UDim2.new(1, -10, 0, 236), BackgroundColor3 = C.Cream, LayoutOrder = 1, ZIndex = 6, Parent = rebirthList }, { UI.Corner(0.1), UI.Stroke(C.Brown, 2) })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.04, 0), Size = UDim2.new(0.9, 0, 0.17, 0), Text = T("rebirth.gain", { n = short(num(state.StarsGain)) }), Dark = true, ZIndex = 7, Parent = info })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.22, 0), Size = UDim2.new(0.9, 0, 0.12, 0), Text = if num(state.StarsGain) > 0
		then T("rebirth.preview", { from = Format.Mult(num(tbl(state.CashParts).Stars, 1)), to = Format.Mult(1 + Config.StarBonus * (num(state.StarsTotal) + num(state.StarsGain))) })
		else T("rebirth.now", { mult = Format.Mult(num(tbl(state.CashParts).Stars, 1)) }), Dark = true, TextColor3 = C.Purple, MaxText = 22, ZIndex = 7, Parent = info })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.36, 0), Size = UDim2.new(0.9, 0, 0.3, 0), Text = T("rebirth.info"), Dark = true, TextColor3 = C.Brown, Font = UI.Font2, TextWrapped = true, MaxText = 18, ZIndex = 7, Parent = info })
	local armed = os.clock() - rebirthArmed < 6
	UI.Button({ Position = UDim2.new(0.25, 0, 1, -72), Size = UDim2.new(0.5, 0, 0, 62), Text = if armed then T("rebirth.confirm") else T("rebirth.do"), BackgroundColor3 = if not state.CanRebirth then C.Gray elseif armed then C.Red else C.Blue, ZIndex = 7, Parent = info }, function()
		if not state or not state.CanRebirth then
			return
		end
		if os.clock() - rebirthArmed < 6 then
			rebirthArmed = 0
			request("Rebirth")
			UI.Show(nil)
		else
			rebirthArmed = os.clock()
			UI.Refreshers.Rebirth()
			task.delay(6.1, function()
				if UI.OpenPanel == "Rebirth" then
					UI.Refreshers.Rebirth()
				end
			end)
		end
	end)
	-- selo
	local sealIndex = num(state.Seal)
	local starsTotal = num(state.StarsTotal)
	local seal = Config.Seals[sealIndex]
	local nextSeal = Config.Seals[sealIndex + 1]
	local box = new("Frame", { Size = UDim2.new(1, -10, 0, 236), BackgroundColor3 = C.Cream, LayoutOrder = 2, ZIndex = 6, Parent = rebirthList }, { UI.Corner(0.1), UI.Stroke(C.Brown, 2) })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.04, 0), Size = UDim2.new(0.9, 0, 0.16, 0), Text = ("%s: %s"):format(T("seal.title"), if seal then T("seal." .. seal.Id) else T("seal.none")), Dark = true, TextColor3 = if seal then seal.Color else C.DarkBrown, ZIndex = 7, Parent = box })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.21, 0), Size = UDim2.new(0.9, 0, 0.26, 0), Text = T("seal.info", { n = Config.SealMult }), Dark = true, TextColor3 = C.Brown, Font = UI.Font2, TextWrapped = true, MaxText = 18, ZIndex = 7, Parent = box })
	if nextSeal then
		UI.Bar(box, starsTotal / nextSeal.Stars, nextSeal.Color, T("seal.progress", { have = short(starsTotal), need = short(nextSeal.Stars) }), { Position = UDim2.new(0.05, 0, 0.5, 0), Size = UDim2.new(0.9, 0, 0.14, 0) })
		UI.Button({ Position = UDim2.new(0.2, 0, 1, -72), Size = UDim2.new(0.6, 0, 0, 62), Text = ("%s: %s"):format(T("seal.do"), T("seal." .. nextSeal.Id)), BackgroundColor3 = if state.CanEvolve then nextSeal.Color else C.Gray, ZIndex = 7, Parent = box }, function()
			if state and state.CanEvolve then
				request("Evolve")
				UI.Show(nil)
			end
		end)
	else
		UI.Label({ Position = UDim2.new(0.05, 0, 0.55, 0), Size = UDim2.new(0.9, 0, 0.3, 0), Text = T("seal.maxed"), Dark = true, ZIndex = 7, Parent = box })
	end
end

-- TALENTOS
local talentsList = makePanel("Talents", "talents.title", C.Blue)
UI.Refreshers.Talents = function()
	UI.Clear(talentsList)
	if not state then
		return
	end
	local stars = num(state.Stars)
	local levels, boughtList = tbl(state.Talents), tbl(state.TalentsBought)
	UI.Note(talentsList, 0, T("talents.info", { n = short(stars) }), 30)
	for i, talent in Config.Talents do
		local level = num(levels[talent.Id])
		local bought = num(boughtList[talent.Id])
		local cost = talent.Costs[bought + 1]
		local nextValue = talent.Values[math.clamp(level + 1, 1, #talent.Values)]
		local title = ("%s  (%s)"):format(T("talent." .. talent.Id), T("talent.level", { n = level, max = #talent.Values }))
		local desc = T("talent." .. talent.Id .. ".d", { v = nextValue })
		if cost and level < #talent.Values then
			UI.Card(talentsList, i, UI.Icon(talent.Icon, {}), title, desc, "⭐ " .. short(cost), if stars >= cost then C.Green else C.Gray, function()
				request("BuyTalent", talent.Id)
			end)
		else
			UI.Card(talentsList, i, UI.Icon(talent.Icon, {}), title, desc, T("talent.max"), C.Purple, nil)
		end
	end
end

-- ROLETA
local wheelList = makePanel("Wheel", "wheel.title", C.Red)
local wheelSpinning = false
local wheelAngle = 0
local wheelDisk: Frame? = nil
local PRIZE_ICON = { coins1 = "Moeda", coins2 = "Moeda", coins3 = "Moeda", stars1 = "Estrela", stars2 = "Estrela", turbo = "Raio", luck = "Trofeu", egg = "Ovo_ArcoIris" }

local function prizeText(index: number, shown: any): string
	local prize = Config.Wheel.Prizes[index]
	if not prize then
		return ""
	end
	if prize.Seconds then
		return "💰 " .. short(num(shown))
	elseif prize.Stars then
		return "⭐ +" .. tostring(prize.Stars)
	elseif prize.Boost then
		return T("wheel.boost", { name = T("boost." .. prize.Boost), t = Format.Time(prize.BoostSeconds) })
	elseif prize.Egg then
		return T("wheel.egg", { egg = Lang.Egg(Config, tostring(shown)) })
	end
	return ""
end

UI.Refreshers.Wheel = function()
	if wheelSpinning then
		return
	end
	UI.Clear(wheelList)
	wheelDisk = nil
	if not state then
		return
	end
	local box = new("Frame", { Size = UDim2.new(1, -10, 0, 330), BackgroundColor3 = C.Cream, LayoutOrder = 1, ZIndex = 6, Parent = wheelList }, { UI.Corner(0.08), UI.Stroke(C.Brown, 2) })
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.3, 0, 0.06, 0), Size = UDim2.new(0, 280, 0, 280), BackgroundTransparency = 1, ZIndex = 7, Parent = box })
	local disk = new("Frame", { Name = "Disk", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.Yellow, Rotation = wheelAngle, ZIndex = 7, Parent = holder }, { UI.Corner(1), UI.Stroke(C.DarkBrown, 5) })
	wheelDisk = disk
	local n = #Config.Wheel.Prizes
	for i, prize in Config.Wheel.Prizes do
		local a = math.rad((i - 1) * 360 / n)
		local cell = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5 + math.sin(a) * 0.36, 0, 0.5 - math.cos(a) * 0.36, 0), Size = UDim2.new(0.24, 0, 0.24, 0), BackgroundColor3 = prize.Color, Rotation = (i - 1) * 360 / n, ZIndex = 8, Parent = disk }, { UI.Corner(1), UI.Stroke(C.DarkBrown, 3) })
		UI.Icon(PRIZE_ICON[prize.Id] or "Moeda", { Position = UDim2.new(0.14, 0, 0.06, 0), Size = UDim2.new(0.72, 0, 0.58, 0), ZIndex = 9, Parent = cell })
		local text = if prize.Seconds then Format.Time(prize.Seconds) elseif prize.Stars then "+" .. prize.Stars elseif prize.Boost then "x" .. (if prize.Boost == "Turbo" then Config.TurboBoostMult else Config.LuckBoostMult) else "?"
		UI.Label({ Position = UDim2.new(0, 0, 0.6, 0), Size = UDim2.new(1, 0, 0.36, 0), Text = text, MaxText = 16, ZIndex = 9, Parent = cell })
	end
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.2, 0, 0.2, 0), BackgroundColor3 = C.Orange, ZIndex = 9, Parent = disk }, { UI.Corner(1), UI.Stroke(C.DarkBrown, 3) })
	-- ponteiro (fica parado em cima)
	UI.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, -0.07, 0), Size = UDim2.new(0.16, 0, 0.16, 0), Text = "▼", TextColor3 = C.Red, MaxText = 44, ZIndex = 10, Parent = holder })
	-- lado direito: botão e explicação
	local wait = num(state.SpinFreeAt) - workspace:GetServerTimeNow()
	local spins = num(state.Spins)
	UI.Label({ Position = UDim2.new(0.6, 0, 0.08, 0), Size = UDim2.new(0.37, 0, 0.16, 0), Text = T("wheel.spins", { n = spins }), Dark = true, MaxText = 26, ZIndex = 7, Parent = box })
	local freeLabel = UI.Label({ Position = UDim2.new(0.6, 0, 0.26, 0), Size = UDim2.new(0.37, 0, 0.2, 0), Text = if wait > 0 then T("wheel.freeIn", { t = Format.Time(wait) }) else T("wheel.freeNow"), Dark = true, TextColor3 = C.Brown, Font = UI.Font2, TextWrapped = true, MaxText = 18, ZIndex = 7, Parent = box })
	if wait > 0 then
		UI.LiveText(freeLabel, num(state.SpinFreeAt), function(remaining)
			return T("wheel.freeIn", { t = Format.Time(remaining) })
		end)
	end
	UI.Button({ Position = UDim2.new(0.61, 0, 0.5, 0), Size = UDim2.new(0.35, 0, 0.2, 0), Text = T("wheel.spin"), BackgroundColor3 = if spins > 0 then C.Green else C.Gray, MaxText = 30, ZIndex = 7, Parent = box }, function()
		if state and num(state.Spins) > 0 and not wheelSpinning then
			request("Spin")
		end
	end)
	UI.Label({ Position = UDim2.new(0.6, 0, 0.73, 0), Size = UDim2.new(0.37, 0, 0.22, 0), Text = T("wheel.how"), Dark = true, TextColor3 = C.Brown, Font = UI.Font2, TextWrapped = true, MaxText = 16, ZIndex = 7, Parent = box })
	-- chances de cada prêmio, à vista de todos (o passe VIP dá um giro por dia: quem compra sabe o que pode sair)
	local total, odds = 0, {}
	for _, prize in Config.Wheel.Prizes do
		total += prize.Weight
	end
	for _, prize in Config.Wheel.Prizes do
		local name = if prize.Seconds then "💰" .. Format.Time(prize.Seconds) elseif prize.Stars then "⭐+" .. prize.Stars elseif prize.Boost then T("boost." .. prize.Boost) else "🥚 " .. T("wheel.oddsEgg")
		table.insert(odds, ("%s %s%%"):format(name, tostring(math.floor(prize.Weight / math.max(total, 1) * 1000 + 0.5) / 10)))
	end
	UI.Note(wheelList, 2, T("wheel.odds", { list = table.concat(odds, "  ·  ") }), 54)
end

local function playSpin(index: number, shown: any)
	local text = prizeText(index, shown)
	local disk = wheelDisk
	if UI.OpenPanel ~= "Wheel" or not disk or not disk.Parent then
		UI.BigPopup(gui, text, C.Yellow, 2.4)
		UI.Sound("Roleta", 0.4)
		task.delay(0.2, UI.Sound, "Premio", 0.75)
		return
	end
	wheelSpinning = true
	local n = #Config.Wheel.Prizes
	local target = 360 * 5 - (index - 1) * 360 / n
	local start = wheelAngle % 360
	disk.Rotation = start
	local tween = TweenService:Create(disk, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target })
	tween:Play()
	-- o "tec-tec" da roleta: começa rápido e agudo e vai ficando lento e grave, como a roda parando
	task.spawn(function()
		local wait = 0.12
		local elapsed = 0
		while elapsed < 3.8 do
			UI.Sound("Roleta", 0.35, 1.35 - 0.5 * elapsed / 3.8)
			task.wait(wait)
			elapsed += wait
			wait = math.min(0.5, wait * 1.14)
		end
	end)
	task.delay(4.1, function()
		wheelAngle = target % 360
		wheelSpinning = false
		UI.BigPopup(gui, text, C.Yellow, 2.6)
		UI.Sound("Premio", 0.8, 1.05)
		World.CoinBurst(nil, 14)
		if UI.OpenPanel == "Wheel" then
			UI.Refreshers.Wheel()
		end
	end)
end

-- MISSÕES (ids da v4: work, tips, mutant, sell, buy, hatch, earn, bags; o texto é mission.<id>)
local missionsList = makePanel("Missions", "missions.title", C.Red)
UI.Refreshers.Missions = function()
	UI.Clear(missionsList)
	if not state then
		return
	end
	for i, mission in tbl(state.Daily) do
		if type(mission) == "table" then
			local target, progress = num(mission.Target), num(mission.Progress)
			local text = T("mission." .. tostring(mission.Id), { n = short(target) })
			local desc = T("mission.progress", { a = short(progress), b = short(target), reward = short(num(state.MissionReward)) })
			local buttonText, color, action = T("mission.going"), C.Gray, nil
			if mission.Claimed then
				buttonText, color = T("mission.claimed"), C.DarkGreen
			elseif progress >= target then
				buttonText, color = T("mission.claim"), C.Green
				action = function()
					request("ClaimMission", i)
				end
			end
			local f = UI.Card(missionsList, i, UI.Icon("Trofeu", {}), text, desc, buttonText, color, action)
			local bar = new("Frame", { Position = UDim2.new(0, 84, 0.9, 0), Size = UDim2.new(0.64, -84, 0.06, 0), BackgroundColor3 = C.Gray, BorderSizePixel = 0, ZIndex = 7, Parent = f })
			new("Frame", { Size = UDim2.new(math.clamp(progress / math.max(target, 1), 0, 1), 0, 1, 0), BackgroundColor3 = C.Green, BorderSizePixel = 0, ZIndex = 7, Parent = bar })
		end
	end
	UI.Note(missionsList, 50, T("missions.tomorrow"), 26)
end

-- PRESENTES: presente por tempo, sequência de dias e códigos
local giftsList = makePanel("Gifts", "gifts.title", C.Red)
local codeText = ""
-- caixa do código: criada uma vez (refazer a cada segundo fechava o teclado do celular no meio da digitação)
local function makeCodeRow()
	local f = new("Frame", { Name = "CodeRow", Size = UDim2.new(1, -10, 0, 88), BackgroundColor3 = C.Cream, LayoutOrder = 3, ZIndex = 6, Parent = giftsList }, { UI.Corner(0.2), UI.Stroke(C.Brown, 2) })
	f:SetAttribute("Keep", true)
	local title = UI.Label({ Name = "Title", Position = UDim2.new(0.03, 0, 0.06, 0), Size = UDim2.new(0.6, 0, 0.34, 0), Text = T("code.title"), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, MaxText = 22, ZIndex = 7, Parent = f })
	local box = new("TextBox", {
		Name = "Box",
		Position = UDim2.new(0.03, 0, 0.44, 0),
		Size = UDim2.new(0.6, 0, 0.48, 0),
		BackgroundColor3 = C.White,
		Font = UI.Font2,
		TextScaled = true,
		TextColor3 = C.DarkBrown,
		PlaceholderText = T("code.hint"),
		Text = codeText,
		ClearTextOnFocus = false,
		ZIndex = 7,
		Parent = f,
	}, { UI.Corner(0.3), UI.Stroke(C.Brown, 2), new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = UI.MinText }) })
	box:GetPropertyChangedSignal("Text"):Connect(function()
		codeText = box.Text
	end)
	local button = UI.Button({ Name = "Redeem", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.3, 0, 0, 64), Text = T("code.redeem"), BackgroundColor3 = C.Blue, MaxText = 24, ZIndex = 7, Parent = f }, function()
		if #codeText > 0 then
			request("RedeemCode", codeText)
			codeText = ""
			box.Text = ""
		end
	end)
	f:SetAttribute("Lang", Lang.Current)
	return f, title, box, button
end

UI.Refreshers.Gifts = function()
	UI.Clear(giftsList)
	if not state then
		return
	end
	local giftLeft = num(state.GiftLeft)
	local ready = giftLeft <= 0
	local _, giftButton, giftDesc = UI.Card(giftsList, 1, UI.Icon("Presente", {}), T("gift.play"), if ready then T("gift.ready", { n = short(num(state.GiftReward)) }) else T("gift.wait", { t = Format.Time(giftLeft) }), if ready then T("gift.open") else Format.Time(giftLeft), if ready then C.Green else C.Gray, if ready
		then function()
			request("ClaimGift")
		end
		else nil)
	if not ready then
		local ends = workspace:GetServerTimeNow() + giftLeft
		UI.LiveText(giftButton, ends, function(left)
			return Format.Time(left)
		end)
		UI.LiveText(giftDesc, ends, function(left)
			return T("gift.wait", { t = Format.Time(left) })
		end)
	end
	UI.Card(giftsList, 2, UI.Icon("Estrela", {}), T("streak.title", { n = num(state.StreakDay, 1) }), T("streak.info"), if state.StreakCan then T("streak.claim") else T("streak.done"), if state.StreakCan then C.Green else C.Gray, if state.StreakCan
		then function()
			request("ClaimStreak")
		end
		else nil)
	-- v6: prêmio por tempo jogado (escada). O servidor confere o tempo; aqui só a contagem.
	local playStart = player:GetAttribute("PlayStart")
	local playClaimed = num(player:GetAttribute("PlayClaimed"))
	local step = Config.PlayRewards and Config.PlayRewards[playClaimed + 1]
	if type(playStart) == "number" then
		local title = T("play.title", { a = math.min(playClaimed + 1, #Config.PlayRewards), b = #Config.PlayRewards })
		if step then
			local ends = playStart + step.Minutes * 60
			local left = ends - workspace:GetServerTimeNow()
			local desc = if step.Turbo then T("play.descTurbo", { m = step.Minutes }) else T("play.desc", { m = step.Minutes })
			local _, playButton = UI.Card(giftsList, 4, UI.Icon("Relogio", {}, "⏰"), title, desc, if left <= 0 then T("play.claim") else Format.Time(left), if left <= 0 then C.Green else C.Gray, function()
				if ends - workspace:GetServerTimeNow() <= 0 then
					request("ClaimPlay")
				end
			end)
			if left > 0 then
				UI.LiveText(playButton, ends, function(remaining)
					return Format.Time(remaining)
				end)
			end
		else
			UI.Card(giftsList, 4, UI.Icon("Relogio", {}, "⏰"), T("play.titleDone"), T("play.done"), "✓", C.Gray, nil)
		end
	end
	-- v6: Baú do Grupo (de graça para quem está no grupo; quem não está vê o convite)
	if Config.GroupId > 0 then
		if state.InGroup then
			local ends = num(state.GroupChestAt)
			local left = ends - workspace:GetServerTimeNow()
			local _, chestButton = UI.Card(giftsList, 6, UI.Icon("Presente", {}, "🎁"), T("group.title"), T("group.desc"), if left <= 0 then T("group.open") else Format.Time(left), if left <= 0 then C.Green else C.Gray, function()
				if num(state.GroupChestAt) - workspace:GetServerTimeNow() <= 0 then
					request("ClaimGroupChest")
				end
			end)
			if left > 0 then
				UI.LiveText(chestButton, ends, function(remaining)
					return Format.Time(remaining)
				end)
			end
		else
			UI.Card(giftsList, 6, UI.Icon("Presente", {}, "🎁"), T("group.title"), T("group.join", { n = math.floor(Config.GroupBonus * 100 + 0.5) }), "", C.Gray, nil)
		end
	end
	-- v6: convidar amigos (cada amigo no servidor já dá bônus de renda)
	UI.Card(giftsList, 5, UI.Icon("Coracao", {}, "👋"), T("invite.title"), T("invite.desc", { n = math.floor(Config.FriendBonus * 100 + 0.5) }), T("invite.button"), C.Blue, function()
		task.spawn(function()
			local SocialService = game:GetService("SocialService")
			local okCan, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if okCan and can then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			else
				UI.Toast(T("invite.cant"), "info")
			end
		end)
	end)
	-- código (a mesma caixa fica; só refaz se o idioma mudou)
	local row = giftsList:FindFirstChild("CodeRow")
	if row and row:GetAttribute("Lang") ~= Lang.Current then
		row:Destroy()
		row = nil
	end
	if not row then
		makeCodeRow()
	end
end

-- LOJA (Robux) + lista dos bônus do jogador.
-- Regras da loja (combinadas com o dono do jogo): cada cartão diz em UMA frase o que o item faz e mostra
-- o preço. Nada de contagem regressiva, "última chance", desconto riscado nem janela que abre sozinha.
-- Itens com Id 0 no Config ficam escondidos. Quem entrega tudo é o servidor (Store): aqui é só o pedido.
local BONUS_PARTS = { "Stars", "Seal", "Birds", "Pets", "Album", "Decor", "Pass", "Social", "Hunt" }
Loja.Robux = utf8.char(0xE002) -- símbolo do Robux nas fontes do Roblox
-- No Studio a loja aparece inteira mesmo sem os IDs (para o dono ver como vai ficar); no jogo publicado,
-- item sem ID continua escondido.
Loja.Preview = game:GetService("RunService"):IsStudio()
local shopList = makePanel("Shop", "shop.title", C.Yellow)

-- preço na tela: símbolo do Robux + o número do Config (o preço de verdade aparece na janela do Roblox)
function Loja.Price(item: any): string
	return Loja.Robux .. " " .. tostring(item.Robux or "?")
end

-- O passe está à venda para este jogador? (existe, tem Id e ele ainda não tem). Devolve o passe ou nil.
function Loja.PassOnSale(key: string): any?
	if not state or tbl(state.Passes)[key] then
		return nil
	end
	for _, pass in Config.GamePasses do
		if pass.Key == key and num(pass.Id) > 0 then
			return pass
		end
	end
	return nil
end

-- Produto à venda para este jogador? (tem Id; compra única já feita some da loja)
function Loja.ProductOnSale(product: any): boolean
	return state ~= nil and num(product.Id) > 0 and not (product.Once and tbl(state.Bought)[product.Key] == true)
end

function Loja.HasItems(): boolean
	for _, pass in Config.GamePasses do
		if Loja.PassOnSale(pass.Key) then
			return true
		end
	end
	for _, product in Config.Products do
		if Loja.ProductOnSale(product) then
			return true
		end
	end
	return false
end

-- A frase do efeito, com os números tirados do Config (mudou o número lá, a loja acompanha)
function Loja.PassDesc(pass: any): string
	local key = pass.Key
	if key == "VIP" then
		local vip = Config.VIP
		local spins = if state and state.NoRandom then 0 else num(vip.DailySpins)
		return T(if spins > 0 then "pass.VIP.d" else "pass.VIP.d2", { n = math.floor(vip.CashBonus * 100 + 0.5), s = spins })
	elseif key == "SuperClique" then
		return T("pass.SuperClique.d", { n = Config.SuperClick.PerSecond, a = Config.HandBonus + Config.SuperClick.HandBonus, b = Config.HandBonus })
	elseif key == "MaisPets" then
		return T("pass.MaisPets.d", { n = Config.PassPetSlots })
	end
	return T("pass." .. key .. ".d")
end

function Loja.ProductDesc(product: any): string
	local args: any = { m = math.floor(num(product.BoostSeconds or product.Seconds) / 60) }
	if product.Kind == "boost" then
		args.n = if product.Boost == "Turbo" then Config.TurboBoostMult else Config.LuckBoostMult
	else
		-- moedas que ele recebe AGORA: o servidor manda o número exato; sem ele, a mesma conta por alto
		local coins = tbl(state and state.ProductCoins)[product.Key]
		if coins == nil then
			coins = math.max(num(product.Min), math.floor(num(state and state.All) * num(product.Seconds)))
		end
		args.n = short(num(coins))
	end
	return T("prod." .. product.Key .. ".d", args)
end

function Loja.Header(order: number, key: string)
	UI.Label({ Size = UDim2.new(1, -10, 0, 34), Text = T(key), TextXAlignment = Enum.TextXAlignment.Left, Dark = true, MaxText = 26, LayoutOrder = order, ZIndex = 6, Parent = shopList })
end

-- Cartão da loja: ícone | nome + frase do efeito | preço (ou "Você já tem ✔")
function Loja.Card(order: number, item: any, title: string, desc: string, owned: boolean, onClick: () -> ())
	local f = new("Frame", { Name = item.Key, Size = UDim2.new(1, -10, 0, 104), BackgroundColor3 = if owned then Color3.fromRGB(214, 245, 214) else C.Cream, LayoutOrder = order, ZIndex = 6, Parent = shopList }, { UI.Corner(0.18), UI.Stroke(C.Brown, 2) })
	UI.Icon(item.Icon or "", { Name = "Icon", Position = UDim2.new(0, 8, 0.5, -36), Size = UDim2.fromOffset(72, 72), ZIndex = 7, Parent = f }, item.Emoji)
	UI.Label({ Name = "Title", Position = UDim2.new(0, 90, 0.06, 0), Size = UDim2.new(0.69, -90, 0.34, 0), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Dark = true, MaxText = 26, ZIndex = 7, Parent = f })
	UI.Label({ Name = "Desc", Position = UDim2.new(0, 90, 0.42, 0), Size = UDim2.new(0.69, -90, 0.52, 0), Text = desc, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Dark = true, TextColor3 = C.Brown, Font = UI.Font2, TextWrapped = true, MaxText = 17, ZIndex = 7, Parent = f })
	if owned then
		UI.Label({ Name = "Have", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.28, 0, 0, 60), Text = T("shop.have"), Dark = true, TextColor3 = C.DarkGreen, MaxText = 22, ZIndex = 7, Parent = f })
	else
		UI.Button({ Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.28, 0, 0, 64), Text = Loja.Price(item), Font = UI.Font2, BackgroundColor3 = C.Green, MaxText = 26, ZIndex = 7, Parent = f }, onClick)
	end
end

UI.Refreshers.Shop = function()
	UI.Clear(shopList)
	if not state then
		return
	end
	local passes = tbl(state.Passes)
	local order = 0
	-- PASSES (para sempre): os que ele já tem continuam na lista, marcados
	local header = false
	for _, pass in Config.GamePasses do
		if num(pass.Id) > 0 or Loja.Preview then
			if not header then
				header = true
				order += 1
				Loja.Header(order, "shop.passes")
			end
			order += 1
			Loja.Card(order, pass, T("pass." .. pass.Key), Loja.PassDesc(pass), passes[pass.Key] == true, function()
				if num(pass.Id) > 0 then
					request("BuyPass", pass.Key)
				else
					UI.Toast(T("shop.preview"), "info")
				end
			end)
		end
	end
	-- IMPULSOS (na hora): produtos que dá para comprar de novo; o Pacote Inicial some depois de comprado
	header = false
	for _, product in Config.Products do
		if Loja.ProductOnSale(product) or (Loja.Preview and num(product.Id) <= 0) then
			if not header then
				header = true
				order += 1
				Loja.Header(order, "shop.boosts")
			end
			order += 1
			Loja.Card(order, product, T("prod." .. product.Key), Loja.ProductDesc(product), false, function()
				if num(product.Id) > 0 then
					request("BuyProduct", product.Key)
				else
					UI.Toast(T("shop.preview"), "info")
				end
			end)
		end
	end
	if order == 0 then
		UI.Note(shopList, 1, T("shop.closed"), 40)
	else
		UI.Note(shopList, 90, T("shop.fair"), 40)
	end
	-- bônus: as partes do multiplicador de dinheiro (Sim.CashMult) que já passam de x1
	UI.Note(shopList, 100, ("%s: %s"):format(T("shop.bonus"), Format.Mult(num(state.Cash, 1))), 30)
	local parts = tbl(state.CashParts)
	local i = 100
	for _, key in BONUS_PARTS do
		local value = num(parts[key], 1)
		if value > 1.0001 then
			i += 1
			UI.Note(shopList, i, ("%s  %s"):format(T("bonus." .. key), Format.Mult(value)), 24)
		end
	end
end

-- CONFIGURAÇÕES
local settingsList = makePanel("Settings", "settings.title", C.Gray)
local applyLanguage: () -> ()
local musicOn = true

-- A música mora no UI (com os outros sons): lá ela é pré-carregada e tocada de novo se não pegou de primeira.
local function applyMusic()
	UI.SetMusic(musicOn)
end
-- A música começa quando chega o 1º estado (que diz se o jogador tinha desligado). Se o estado demorar, ela
-- começa assim mesmo: jogo mudo parece jogo quebrado.
task.delay(6, function()
	if state == nil and musicOn then
		applyMusic()
	end
end)

UI.Refreshers.Settings = function()
	UI.Clear(settingsList)
	UI.Card(settingsList, 1, UI.Icon("", {}, "🌎"), T("settings.lang"), "Português / English", if Lang.Current == "pt" then "Português" else "English", C.Blue, function()
		Lang.Set(if Lang.Current == "pt" then "en" else "pt")
		langChosen = true
		request("Setting", "Lang", Lang.Current)
		applyLanguage()
	end)
	UI.Card(settingsList, 2, UI.Icon("", {}, "🔊"), T("settings.sfx"), "", if UI.SfxOn then T("on") else T("off"), if UI.SfxOn then C.Green else C.Gray, function()
		UI.SfxOn = not UI.SfxOn
		request("Setting", "Sfx", UI.SfxOn)
		UI.Refreshers.Settings()
	end)
	UI.Card(settingsList, 3, UI.Icon("", {}, "🎵"), T("settings.music"), "", if musicOn then T("on") else T("off"), if musicOn then C.Green else C.Gray, function()
		musicOn = not musicOn
		request("Setting", "Music", musicOn)
		applyMusic()
		UI.Refreshers.Settings()
	end)
	UI.Card(settingsList, 4, UI.Icon("", {}, "➡️"), T("settings.arrow"), "", if World.ArrowOn then T("on") else T("off"), if World.ArrowOn then C.Green else C.Gray, function()
		World.ArrowOn = not World.ArrowOn
		request("Setting", "Arrow", World.ArrowOn)
		UI.Refreshers.Settings()
	end)
	if tbl(state and state.Owned).G_tractor then
		UI.Card(settingsList, 5, UI.Icon("", {}, "🚜"), T("settings.tractor"), T("settings.tractor.d"), T("settings.tractor.go"), C.Orange, function()
			request("TractorHome")
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Janelas que aparecem sozinhas: renda offline, encomenda, corrida, pet novo.
-- Tamanho em px virtuais (a tela virtual tem pelo menos 1100 x 570): os botões ficam com 60+ de altura.
-- ---------------------------------------------------------------------------
local function popup(name: string, color: Color3, width: number, height: number): Frame
	local old = gui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.47, 0),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = C.Panel,
		ZIndex = 40,
		Parent = gui,
	}, { UI.Corner(0.08), UI.Stroke(color, 5) })
	-- v6: no celular a janela fica menor (o meio da tela é onde a pessoa vê o personagem e gira a câmera)
	if isTouch then
		new("UIScale", { Scale = 0.78, Parent = f })
	end
	UI.Pop(f, 0.8)
	return f
end

-- v6: janela que aparece SOZINHA no meio do jogo (encomenda, corrida): no celular vai para o alto da tela,
-- fora do caminho do personagem, do controle e do botão de pular
local function popupOutOfTheWay(f: Frame)
	if isTouch then
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.Position = UDim2.new(0.5, 0, 0, 96)
	end
end

local offlineShown = false
local function showOffline()
	if offlineShown or not state or num(state.OfflinePending) <= 0 then
		return
	end
	offlineShown = true
	-- Oferta discreta (só para quem não tem o passe Offline2x e ele está à venda): um botão SECUNDÁRIO,
	-- menor e embaixo do "Pegar". Quem compra ali dobra também o valor que está esperando (o servidor faz).
	local offer = Loja.PassOnSale("Offline2x")
	local height = if offer then 372 else 310
	local f = popup("Offline", C.Green, 520, height)
	UI.Label({ Position = UDim2.fromOffset(26, 16), Size = UDim2.new(1, -52, 0, 56), Text = T("offline.title"), Dark = true, ZIndex = 41, Parent = f })
	UI.Label({ Position = UDim2.fromOffset(26, 78), Size = UDim2.new(1, -52, 0, 56), Text = T("offline.body", { t = Format.Time(num(state.OfflineSeconds)) }), Dark = true, TextColor3 = C.Brown, Font = UI.Font2, TextWrapped = true, MaxText = 20, ZIndex = 41, Parent = f })
	local amount = UI.Label({ Name = "Amount", Position = UDim2.fromOffset(26, 140), Size = UDim2.new(1, -52, 0, 68), Text = "💰 " .. short(num(state.OfflinePending)), TextColor3 = C.Yellow, MaxText = 44, ZIndex = 41, Parent = f })
	UI.Button({ Name = "Claim", Position = UDim2.new(0.25, 0, 0, 230), Size = UDim2.new(0.5, 0, 0, 66), Text = T("offline.claim"), ZIndex = 41, Parent = f }, function()
		request("ClaimOffline")
		Loja.OfflineRefresh = nil
		f:Destroy()
	end)
	if offer then
		local double = UI.Button({ Name = "Double", Position = UDim2.new(0.19, 0, 0, 308), Size = UDim2.new(0.62, 0, 0, 48), Text = ("%s   %s"):format(T("offline.double"), Loja.Price(offer)), Font = UI.Font2, BackgroundColor3 = C.Blue, MaxText = 20, ZIndex = 41, Parent = f }, function()
			request("BuyPass", "Offline2x")
		end)
		-- comprou com a janela aberta: o valor na tela acompanha o servidor e o botão da oferta some
		Loja.OfflineRefresh = function()
			if not f.Parent then
				Loja.OfflineRefresh = nil
				return
			end
			amount.Text = "💰 " .. short(num(state.OfflinePending))
			if tbl(state.Passes).Offline2x and double.Parent then
				double:Destroy()
			end
		end
	end
end

local function showOrder(value: number, timeout: number, who: number)
	local f = popup("Order", C.Orange, 560, 320)
	popupOutOfTheWay(f)
	UI.Label({ Position = UDim2.new(0.05, 0, 0.04, 0), Size = UDim2.new(0.9, 0, 0.18, 0), Text = "📞 " .. T("order.title"), Dark = true, ZIndex = 41, Parent = f })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.23, 0), Size = UDim2.new(0.9, 0, 0.17, 0), Text = T("order.body", { who = T("order.who" .. who) }), Dark = true, TextColor3 = C.Brown, Font = UI.Font2, TextWrapped = true, MaxText = 20, ZIndex = 41, Parent = f })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.4, 0), Size = UDim2.new(0.9, 0, 0.2, 0), Text = "💰 " .. short(value), TextColor3 = C.Yellow, MaxText = 44, ZIndex = 41, Parent = f })
	local function answer(text: string)
		request("Order", text)
		f:Destroy()
	end
	UI.Button({ Position = UDim2.new(0.04, 0, 1, -94), Size = UDim2.new(0.29, 0, 0, 64), Text = T("order.accept"), BackgroundColor3 = C.Green, MaxText = 22, ZIndex = 41, Parent = f }, function()
		answer("accept")
	end)
	UI.Button({ Position = UDim2.new(0.355, 0, 1, -94), Size = UDim2.new(0.29, 0, 0, 64), Text = T("order.haggle"), BackgroundColor3 = C.Orange, MaxText = 22, ZIndex = 41, Parent = f }, function()
		answer("haggle")
	end)
	UI.Button({ Position = UDim2.new(0.67, 0, 1, -94), Size = UDim2.new(0.29, 0, 0, 64), Text = T("order.decline"), BackgroundColor3 = C.Red, MaxText = 22, ZIndex = 41, Parent = f }, function()
		answer("decline")
	end)
	local bar = new("Frame", { Position = UDim2.new(0.04, 0, 1, -22), Size = UDim2.new(0.92, 0, 0, 12), BackgroundColor3 = C.Orange, BorderSizePixel = 0, ZIndex = 41, Parent = f })
	TweenService:Create(bar, TweenInfo.new(timeout, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 12) }):Play()
	task.delay(timeout, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

local RACER_COLORS = { C.White, C.Orange, C.Cream, C.Yellow }
local function showRacePick(seconds: number)
	local f = popup("RacePick", C.Blue, 560, 220)
	f.Position = UDim2.new(0.5, 0, 0.38, 0)
	popupOutOfTheWay(f)
	UI.Label({ Position = UDim2.new(0.04, 0, 0.06, 0), Size = UDim2.new(0.92, 0, 0.3, 0), Text = T("race.pick", { t = math.floor(seconds) }), Dark = true, ZIndex = 41, Parent = f })
	for lane = 1, 4 do
		local line = Config.Lines[lane]
		local b = UI.Button({ Position = UDim2.new(0.04 + (lane - 1) * 0.235, 0, 0.42, 0), Size = UDim2.new(0.215, 0, 0.5, 0), Text = tostring(lane), BackgroundColor3 = RACER_COLORS[lane], TextColor3 = C.DarkBrown, MaxText = 36, ZIndex = 41, Parent = f }, function()
			request("RacePick", lane)
			UI.Toast(T("race.picked", { n = lane }), "info")
			f:Destroy()
		end)
		UI.Icon("R_" .. line.Asset, { Position = UDim2.new(0.5, 0, 0.05, 0), Size = UDim2.new(0.48, 0, 0.5, 0), ZIndex = 42, Parent = b })
	end
	task.delay(seconds, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

-- Pet nasceu: janela com o retrato, o nome e o bônus
local function showPet(key: string, fresh: boolean, level: number)
	local f = popup("NewPet", C.Pink, 480, 390)
	UI.Label({ Position = UDim2.new(0.05, 0, 0.03, 0), Size = UDim2.new(0.9, 0, 0.15, 0), Text = if fresh then T("pet.new") else T("pet.levelUp", { n = level }), Dark = true, TextColor3 = C.Purple, ZIndex = 41, Parent = f })
	UI.Icon(petIcon(key), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.19, 0), Size = UDim2.new(0.34, 0, 0.33, 0), ZIndex = 41, Parent = f })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.53, 0), Size = UDim2.new(0.9, 0, 0.14, 0), Text = petName(key), Dark = true, ZIndex = 41, Parent = f })
	UI.Label({ Position = UDim2.new(0.05, 0, 0.67, 0), Size = UDim2.new(0.9, 0, 0.09, 0), Text = T("pets.bonus", { n = math.floor(Sim.PetBonus(Config, key, level) * 100 + 0.5), level = level, max = Config.Pets.MaxLevel }), Dark = true, TextColor3 = C.Brown, Font = UI.Font2, MaxText = 18, ZIndex = 41, Parent = f })
	UI.Button({ Position = UDim2.new(0.28, 0, 1, -76), Size = UDim2.new(0.44, 0, 0, 64), Text = T("pet.ok"), MaxText = 26, ZIndex = 41, Parent = f }, function()
		f:Destroy()
	end)
	task.delay(8, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- HUD
-- ---------------------------------------------------------------------------
local eventBanner: { Text: string, Ends: number }? = nil
local lastCoins = 0
local isNear = false -- perto da banca (o World responde; conferido algumas vezes por segundo)
local lastWorkAt = -100 -- os.clock() da última vez em que havia um ciclo na mão em andamento
local workFx: { Biz: number, Start: number, Len: number }? = nil -- último Fx "work" (reserva se o World não souber)
local workShown: number? = nil -- negócio escrito na barra de trabalho (para não refazer o texto todo quadro)

local function hatchReady(): boolean
	if not state then
		return false
	end
	local now = workspace:GetServerTimeNow()
	for _, hatch in tbl(state.Hatch) do
		if type(hatch) == "table" and num(hatch.ReadyAt, math.huge) <= now then
			return true
		end
	end
	return false
end

-- Ciclo na mão em andamento: (índice do negócio, fração 0..1). Quem sabe é o World (tapete azul);
-- se ele ainda não tiver a função, vale o último Fx "work" (o servidor manda a duração).
local function workInfo(): (number?, number)
	if World.WorkInfo then
		local ok, index, fraction = pcall(World.WorkInfo)
		if ok then
			return tonumber(index), math.clamp(num(fraction), 0, 1)
		end
	end
	local w = workFx
	if w then
		local elapsed = os.clock() - w.Start
		if elapsed <= w.Len + 0.3 then
			return w.Biz, math.clamp(elapsed / w.Len, 0, 1)
		end
		workFx = nil
	end
	return nil, 0
end

-- Tutorial: uma frase por vez, a mais importante primeiro. Só no começo (os primeiros TIP_BUTTONS botões
-- da vida); as dicas de pet valem até o jogador ter chocado alguns.
local TIP_BUTTONS = 20
local function pickTip(): string
	if not state then
		return ""
	end
	local early = num(state.Buttons) < TIP_BUTTONS
	local banca = bizOf(1)
	if not banca.Unlocked then
		return if early then "tip.first" else ""
	end
	-- saco de dinheiro no meu terreno (state.Bag vem no Tick): tem hora para sumir, então passa na frente das
	-- outras dicas. Só até ele ter pegado alguns: depois o aviso, o facho de luz e a seta já bastam.
	local bag = state.Bag
	if type(bag) == "table" and num(state.Bags) < 3 and num(bag.Until) > workspace:GetServerTimeNow() then
		return "tip.bag"
	end
	-- Baú Secreto com as chaves todas na mão: a seta de ajuda já aponta para ele; a dica diz o que fazer
	if V5.ChestReady() then
		return "tip.chest"
	end
	local hatched = num(state.Hatched)
	if hatched < 3 and hatchReady() then
		return "tip.hatchReady"
	end
	local coins = num(state.Coins)
	local nextButton = nextButtonOf()
	local working = os.clock() - lastWorkAt < 2.5 -- com folga: entre um ciclo e outro o jogador continua no tapete
	local clicking = isNear and not banca.Manager
	if early then
		-- 1) gastar: o gerente da banca é a compra que muda o jogo (começa a render sozinho)
		local manager = Config.ButtonById.banca_gerente
		if manager and not banca.Manager and coins >= manager.Cost then
			return "tip.manager"
		end
		if nextButton and coins >= nextButton.Cost then
			return "tip.buy"
		end
		-- 2) moedas no chão: quando elas já pagam o próximo botão, quando o jogador está à toa, ou gorjetas juntando
		local ground = groundTotal()
		local enough = nextButton ~= nil and coins + ground >= nextButton.Cost
		if (ground > 0 and (enough or not (working or clicking))) or num(state.Tips) >= math.ceil(Config.TipMax / 2) then
			return "tip.coins"
		end
	end
	-- 3) ovos raros: cesta -> chocadeira (ou balcão); ninho -> cesta
	if state.Mutant and state.HatchFree and hatched < 3 then
		return "tip.hatch"
	elseif state.Mutant and num(state.HatchSlots) <= 0 and hatched < 1 then
		return "tip.rare"
	end
	if not early then
		return ""
	end
	-- state.Rare é a LISTA dos ovos raros que estão nos ninhos ({ Line, Slot, Mut }), como vem no State e no Tick
	if #tbl(state.Rare) > 0 and num(state.BasketCount) < num(state.BasketCap, 1) then
		return "tip.rareNest"
	end
	-- 4) produzir: clicar na banca (sem gerente) ou ficar no tapete azul de um negócio sem gerente
	if clicking then
		return "tip.click"
	end
	if not working then
		for index = 2, #Config.Businesses do
			local b = bizOf(index)
			if b.Unlocked and not b.Manager then
				return "tip.work"
			end
		end
		if not banca.Manager and num(state.Auto) <= 0 then
			return "tip.banca" -- sem renda nenhuma e longe da banca: volta para lá
		end
	end
	return ""
end

local tipKey = ""
local lastPulse = 0
local function updateTip()
	local key = pickTip()
	if key == "" and state then
		key = V5.Tip() -- dicas da versão 5 (chave, poder, clima): só quando o tutorial não tem nada a dizer
	end
	local fresh = key ~= tipKey
	if fresh then
		tipKey = key
		tip.Text = if key == "" then "" else T(key)
	end
	-- com um painel aberto a dica não aparece (ficaria por baixo dele); volta quando ele fecha
	local show = key ~= "" and UI.OpenPanel == nil
	if show ~= tip.Visible then
		tip.Visible = show
		Hud.Bottom() -- (a barra de trabalho sobe ou desce conforme a dica)
	end
	if fresh and show then
		UI.Pop(tip, 1.08)
	end
	-- enquanto a dica manda tocar em VENDER, o botão pulsa de leve para a criança achar
	if key == "tip.click" and sell.Visible and holdInput == nil and os.clock() - lastPulse > 1.8 and os.clock() - lastClick > 1.2 then
		lastPulse = os.clock()
		UI.Pop(sell, 1.1)
	end
end
Hud.PanelChanged = function()
	updateTip()
	if UI.OpenPanel ~= nil then
		workBar.Visible = false -- (a barra de trabalho volta sozinha no próximo quadro depois que o painel fecha)
	end
	Hud.Bottom() -- os painéis ficam entre as pílulas de cima e o contador de moedas
end

-- Moedas voando do meio da tela até a moeda grande do contador (embaixo, no meio); o NÚMERO dá o pulinho
function Hud.Fly(amount: number)
	UI.FlyCoins(gui, Hud.CoinIcon, amount, nil, coinText)
end

-- v6: o próximo degrau do prêmio por tempo jogado (ou o Baú do Grupo) já pode ser pego?
local function playReadyNow(): boolean
	local now = workspace:GetServerTimeNow()
	if state and state.InGroup and Config.GroupId > 0 and num(state.GroupChestAt) <= now then
		return true
	end
	local step = Config.PlayRewards[num(player:GetAttribute("PlayClaimed")) + 1]
	local start = player:GetAttribute("PlayStart")
	return step ~= nil and type(start) == "number" and now >= start + step.Minutes * 60
end

local function updateHud()
	if not state then
		return
	end
	local coins = num(state.Coins)
	-- v6: ganho grande "conta" até o número novo (0,6 s); renda pingando e gasto mudam na hora
	if coins > lastCoins * 1.02 + 5 and lastCoins > 0 then
		Hud.RollFrom, Hud.RollTo, Hud.RollAt = Hud.RollShown or lastCoins, coins, os.clock()
	else
		Hud.RollTo, Hud.RollShown = nil, nil
		coinText.Text = short(coins)
	end
	-- o número "pula" quando o dinheiro sobe: forte quando sobe de uma vez (moedas do chão, prêmio), bem de
	-- leve e no máximo uma vez por segundo quando é a renda dos gerentes pingando
	if coins > lastCoins and lastCoins > 0 then
		local clock = os.clock()
		if coins > lastCoins * 1.02 + 5 then
			Hud.PopAt = clock
			Hud.Gain(true)
		elseif clock - num(Hud.PopAt) >= 1 then
			Hud.PopAt = clock
			Hud.Gain(false)
		end
	end
	lastCoins = coins
	local auto = num(state.Auto)
	rateText.Text = if auto > 0 then T("hud.perSec", { n = short(auto) }) else ""
	if rateText.Visible ~= (auto > 0) then
		rateText.Visible = auto > 0
		Hud.Bottom() -- (sem a renda ao lado, o número ocupa a placa toda)
	end
	local stars = num(state.Stars)
	starText.Text = short(stars)
	starPill.Visible = stars > 0 or num(state.StarsTotal) > 0 or num(state.StarsGain) > 0
	-- cesta de OVOS RAROS: só existe depois que a Granja abre (ou se sobrou ovo de antes de renascer)
	local count, cap = num(state.BasketCount), num(state.BasketCap)
	basketPill.Visible = bizOf(2).Unlocked == true or count > 0
	basketText.Text = ("%d/%d"):format(count, cap)
	local fill = math.clamp(count / math.max(cap, 1), 0, 1)
	basketFill.Size = UDim2.new(fill, 0, 1, 0)
	basketFill.BackgroundColor3 = if fill >= 1 then C.Red else C.Green
	-- valor de um toque no VENDER: um ciclo da banca feito na mão (quem paga é o servidor; aqui é só o letreiro)
	sellValue.Text = T("pop.reward", { n = short(num(bizOf(1).Payout) * num(state.Hand, 1)) })
	petsBadge.Visible = hatchReady()
	prizesBadge.Visible = num(state.GiftLeft) <= 0 or state.StreakCan == true or num(state.Spins) > 0 or playReadyNow()
	rebirthBadge.Visible = state.CanRebirth == true or state.CanEvolve == true
	-- comprar de longe
	local nextButton = nextButtonOf()
	if nextButton and num(tbl(state.Talents).remote) > 0 then
		buyNext.Visible = true
		buyNext.Text = T("hud.buyNext", { name = (Lang.Button(Config, nextButton, short)), cost = short(nextButton.Cost) })
		buyNext.BackgroundColor3 = if coins >= nextButton.Cost then C.Green else C.Gray
	else
		buyNext.Visible = false
	end
	V5.Hud()
	Hud.Top() -- (as pílulas aparecem e somem; só mexe na tela quando algo mudou)
	Hud.Bottom() -- (com o botão de comprar de longe o contador sobe um degrau)
	updateTip()
end

applyLanguage = function()
	for l, key in labelKeys do
		if l.Parent then
			l.Text = T(key)
		end
	end
	for _, info in panelTitles do
		info.Label.Text = T(info.Key)
	end
	for _, tab in tabButtons do
		if tab.Button.Parent then
			tab.Button.Text = T(tab.Key)
		end
	end
	tipKey = "" -- a dica e a barra de trabalho são refeitas no idioma novo
	workShown = nil
	V5.Relabel()
	updateHud()
	World.Relabel()
	UI.RefreshOpen()
end

local function mergeTick(t: any)
	if not state or type(t) ~= "table" then
		return
	end
	state.Mutant = nil -- campo nil não viaja: sem isso o "tem ovo raro na cesta" nunca apagava
	for key, value in t do
		state[key] = value
	end
	updateHud()
	World.SetState(state)
end

Remotes:WaitForChild("State").OnClientEvent:Connect(function(newState: any)
	if type(newState) ~= "table" then
		return
	end
	local first = state == nil
	state = newState
	if first or not langChosen then
		local settings = tbl(state.Settings)
		local saved = settings.Lang
		if (saved == "pt" or saved == "en") and saved ~= Lang.Current then
			Lang.Set(saved)
			applyLanguage()
		end
		langChosen = true
		if settings.Sfx == false then
			UI.SfxOn = false
		end
		if settings.Arrow == false then
			World.ArrowOn = false
		end
		if settings.Music == false then
			musicOn = false
		end
		applyMusic()
	end
	updateHud()
	World.SetState(state)
	UI.RefreshOpen()
	showOffline()
	if Loja.OfflineRefresh then
		Loja.OfflineRefresh()
	end
end)

Remotes:WaitForChild("Tick").OnClientEvent:Connect(mergeTick)

Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, args: any, kind: string?)
	args = if type(args) == "table" then args else {}
	-- nomes que vêm como id (negócio, ave, selo, pet) viram texto no idioma do jogador
	if args.biz ~= nil then
		local def = Config.Businesses[args.biz] -- aceita índice...
		args.biz = T("biz." .. (if def then def.Id else tostring(args.biz))) -- ...ou id
	end
	if args.line ~= nil then
		local line = Config.Lines[args.line]
		local id = if line then line.Id else tostring(args.line)
		-- quem acha um mítico acha um OVO; nos outros avisos o assunto é a ave
		args.line = if key == "n.mythic" then T("egg." .. id) else T("bird." .. id)
	end
	if args.seal ~= nil then
		args.seal = T("seal." .. tostring(args.seal))
	end
	if args.pet ~= nil then
		args.pet = petName(tostring(args.pet))
	end
	if args.pass ~= nil then
		args.pass = T("pass." .. tostring(args.pass)) -- nome do passe comprado
	end
	UI.Toast(T(tostring(key), args), kind)
	if kind == "error" then
		UI.Sound("Erro", 0.5)
	end
end)

-- relógios na tela (evento, boosts, presente, Ovo Gigante) contados no cliente
local function everySecond()
	if state then
		local now = workspace:GetServerTimeNow()
		local parts = {}
		if eventBanner then
			local left = eventBanner.Ends - os.clock()
			if left > 0 then
				table.insert(parts, ("%s  %s"):format(eventBanner.Text, Format.Time(left)))
			else
				eventBanner = nil
			end
		end
		for key, ends in tbl(state.Boosts) do
			local left = num(ends) - now
			if left > 0 then
				table.insert(parts, ("%s %s"):format(T("boost." .. tostring(key)), Format.Time(left)))
			end
		end
		banner.Text = table.concat(parts, "   ")
		local giftLeft = num(state.GiftLeft)
		if giftLeft > 0 then
			state.GiftLeft = giftLeft - 1
		end
		-- contagens regressivas dos painéis: só o texto muda; quando uma chega a zero, o painel é refeito 1 vez
		if UI.TickLive() and UI.OpenPanel and not (UI.OpenPanel == "Wheel" and wheelSpinning) then
			UI.RefreshOpen()
		end
		petsBadge.Visible = hatchReady()
		if not prizesBadge.Visible and playReadyNow() then
			prizesBadge.Visible = true
		end
	end
	-- Ovo Gigante
	local progress, giantState, crackAt = World.GiantInfo()
	if (progress ~= nil) ~= giantBar.Visible then
		giantBar.Visible = progress ~= nil
		Hud.Top() -- (o chip do clima dá lugar ao Mega Ovo, ou fica com a fila toda)
	end
	if progress then
		giantFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
		if giantState == "crack" then
			local left = math.max(0, (crackAt or 0) - workspace:GetServerTimeNow())
			giantText.Text = T("giant.cracking", { t = math.ceil(left) })
			giantFill.BackgroundColor3 = C.Red
		else
			giantText.Text = T("giant.bar", { n = math.floor(progress * 100) })
			giantFill.BackgroundColor3 = C.Yellow
		end
	end
end

-- v6: o contador de moedas rolando até o valor novo (ver updateHud)
RunService.RenderStepped:Connect(function()
	local target = Hud.RollTo
	if not target then
		return
	end
	local t = math.clamp((os.clock() - Hud.RollAt) / 0.6, 0, 1)
	local eased = 1 - (1 - t) ^ 3
	local shown = Hud.RollFrom + (target - Hud.RollFrom) * eased
	Hud.RollShown = shown
	coinText.Text = short(math.floor(shown))
	if t >= 1 then
		Hud.RollTo, Hud.RollShown = nil, nil
	end
end)

player:GetAttributeChangedSignal("PlayClaimed"):Connect(function()
	if UI.OpenPanel == "Gifts" then
		UI.RefreshOpen()
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		-- um erro aqui (campo estranho no estado, World em obras) não pode parar os relógios para sempre
		local ok, err = pcall(everySecond)
		if not ok then
			warn("[VendaUmOvo] relógio da tela: " .. tostring(err))
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Todo quadro: dedo parado no VENDER e barra de trabalho. Algumas vezes por segundo: o botão VENDER
-- aparece/some (perto da banca) e a dica muda (ela depende de onde o jogador está, não só do servidor).
-- Uma conexão só, para a vida toda da tela.
-- ---------------------------------------------------------------------------
local function nearBanca(): boolean
	if not state or bizOf(1).Unlocked ~= true then
		return false
	end
	if World.NearBanca then
		local ok, near = pcall(World.NearBanca)
		if ok then
			return near == true
		end
	end
	-- o World ainda não sabe responder: o botão fica à mostra (o servidor confere a distância de qualquer jeito)
	return true
end

local slowAt = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	-- segurar o dedo (ou a tecla) repete o toque sozinho
	local held = holdInput
	if held and (held.UserInputState == Enum.UserInputState.End or held.UserInputState == Enum.UserInputState.Cancel) then
		releaseHold()
	end
	if holdInput ~= nil or next(holdKeys) ~= nil then
		if not sell.Visible then
			releaseHold()
			table.clear(holdKeys)
		elseif now - lastClick >= HOLD_EVERY then
			sellTap()
		end
	end
	-- barra de trabalho
	local index, fraction = workInfo()
	local def = index and Config.Businesses[index]
	if def then
		lastWorkAt = now
		if workShown ~= index then
			workShown = index
			workText.Text = ("%s  %s"):format(T("biz." .. def.Id), T("work.busy"))
			workFill.BackgroundColor3 = def.Color
		end
		workFill.Size = UDim2.new(fraction, 0, 1, 0)
		workBar.Visible = UI.OpenPanel == nil -- (com um painel aberto ela ficaria por baixo dele)
	elseif workBar.Visible and now - lastWorkAt > 0.4 then
		-- 0,4 s de folga: entre um ciclo e o seguinte a barra não pisca
		workBar.Visible = false
		workShown = nil
	end
	if now >= slowAt then
		slowAt = now + 0.2
		local near = nearBanca()
		isNear = near
		if sell.Visible ~= near then
			sell.Visible = near
			if near then
				UI.Pop(sell, 0.6) -- chega "pulando": é o botão mais importante do começo
			end
		end
		V5.Slow() -- relógio do clima e dos poderes
		updateTip()
	end
end)

-- ---------------------------------------------------------------------------
-- Efeitos pedidos pelo servidor: Fx(tipo, posição?, valor, extra). Um tratador por tipo.
-- ---------------------------------------------------------------------------
local FX: { [string]: (position: Vector3?, value: any, extra: any) -> () } = {}

-- v6: prêmio do dia a dia (missão, presente, curtida, tempo jogado...) vira um aviso pequeno no canto;
-- o texto grande fica só para compra, renda offline e VIP
local BIG_REWARDS = { robux = true, offline = true, vip = true }
local function rewardPopup(value: number, source: any)
	if BIG_REWARDS[source] then
		UI.BigPopup(gui, T("pop.reward", { n = short(value) }), C.Yellow, 1.8)
	else
		UI.Toast(T("pop.reward", { n = short(value) }), "success")
	end
	World.CoinBurst(nil, 12)
	Hud.Fly(8)
	UI.Sound("Premio", 0.7, 1, 0.05)
	if source == "offline" then
		offlineShown = true
	end
end

-- clique na banca: muitos por segundo, então texto e som têm limite (senão vira barulho e chuva de números)
local lastClickPop = 0
local lastClickSound = 0
FX.click = function(position, value)
	if World.BancaSale then
		pcall(World.BancaSale)
	end
	local now = os.clock()
	if now - lastClickPop >= 0.18 then
		lastClickPop = now
		local text = "+" .. short(num(value))
		if sell.Visible then
			UI.Rise(sell, text, C.Yellow)
		elseif position then
			World.FloatText(position, text, C.Yellow) -- clicou direto na banca, de longe do botão
		end
	end
	if now - lastClickSound >= 0.4 then
		lastClickSound = now
		UI.Sound("Vender", 0.22, 0.95 + math.random() * 0.2)
	end
end

-- começou um ciclo na mão: guarda para a barra de trabalho (o World, quando sabe, tem prioridade)
FX.work = function(_position, value, extra)
	local index = tonumber(value)
	if index and Config.Businesses[index] then
		workFx = { Biz = index, Start = os.clock(), Len = math.max(num(extra, 1), 0.05) }
	end
end

local lastWorkSound = 0
FX.workDone = function(position, value, extra)
	if position then
		World.FloatText(position, "+" .. short(num(value)), C.Yellow)
	end
	if workFx and workFx.Biz == tonumber(extra) then
		workFx = nil
	end
	-- ciclos melhorados chegam a 3 por segundo: o som toca no máximo 2 vezes por segundo
	if os.clock() - lastWorkSound >= 0.5 then
		lastWorkSound = os.clock()
		UI.Sound("Vender", 0.35, 0.85, 0.05) -- ciclo feito na mão: a "caixa registradora", mais grave que a da banca
	end
end

-- alguém pegou dinheiro (moedas do chão, gorjetas, venda de ovo raro): todos veem o texto; o dono vê as moedas voando.
-- Quem clica parado em cima das moedas recebe um "money" a cada passada do servidor (5 por segundo), e os
-- vizinhos também mandam os deles: texto, moedas voando e som têm limite.
local lastMoneyText = { [true] = 0, [false] = 0 } -- [é meu?] = os.clock() do último texto
local lastMoneyFly = 0
FX.money = function(position, value, extra)
	local now = os.clock()
	local mine = extra == player.UserId
	if position and now - lastMoneyText[mine] >= 0.2 then
		lastMoneyText[mine] = now
		World.FloatText(position, "+" .. short(num(value)), C.Yellow)
	end
	if mine and now - lastMoneyFly >= 0.6 then
		lastMoneyFly = now
		if position then
			World.CoinBurst(position, 10)
		end
		Hud.Fly(6)
		UI.Sound("Coletar", 0.5, 1.05, 0.1)
	end
end

FX.tips = function(position, value)
	if position then
		World.FloatText(position + Vector3.new(0, 3, 0), T("pop.tips", { n = short(num(value)) }), C.Green)
	end
	UI.Sound("Coletar", 0.45, 1.3) -- gorjetas: o mesmo "plim" das moedas, mais agudo
end

FX.tipDrop = function(position)
	if position then
		World.Puff(position) -- brilho discreto onde a gorjeta caiu (sem som: cai uma a cada poucos segundos)
	end
end

-- SACO DE DINHEIRO. O saco, o facho de luz, o relógio e a seta são do World (tag VUOBag); aqui só o aviso,
-- o som e as moedas. O servidor manda (Farm.lua):
--   bagDrop  só para o dono:  posição, dourado?, segundos que fica no chão
--   bagTake  para todos:      posição, moedas, { userId de quem pegou, dourado? }
--   bagGone  para todos:      posição, dourado?, userId do dono (sumiu sem ninguém pegar)
FX.bagDrop = function(position, value)
	local golden = value == true
	if golden then
		UI.BigPopup(gui, T("bag.dropGold", { n = num(tbl(Config.MoneyBag).GoldenMult, 1) }), C.Yellow, 2.8)
	else
		UI.Toast(T("bag.drop"), "event")
	end
	UI.Sound("Evento", if golden then 0.7 else 0.45, if golden then 1.25 else 1)
	if position then
		World.Ping(position, C.Yellow)
	end
end

FX.bagTake = function(position, value, extra)
	local info = tbl(extra)
	local golden = info[2] == true
	local amount = num(value)
	-- o "+valor" e o brilho aparecem para todo mundo que está olhando; a festa é só de quem pegou
	if position then
		World.FloatText(position, "+" .. short(amount), C.Yellow)
		World.Puff(position)
	end
	if info[1] ~= player.UserId then
		return
	end
	if golden then
		UI.BigPopup(gui, T("bag.takeGold", { n = short(amount) }), C.Yellow, 2.6)
	else
		UI.Toast(T("bag.take", { n = short(amount) }), "success")
	end
	World.CoinBurst(position, if golden then 16 else 12)
	Hud.Fly(if golden then 12 else 8)
	UI.Sound("Premio", if golden then 0.8 else 0.55, if golden then 1.2 else 1)
	task.delay(0.3, UI.Sound, "Coletar", 0.5, 1.1) -- as moedas chegando no contador
end

FX.bagGone = function(position, _value, extra)
	if position then
		World.Poof(position) -- "puf" de fumaça onde o saco estava
	end
	if extra == player.UserId then
		UI.Toast(T("bag.gone"), "info")
		UI.Sound("Erro", 0.25, 0.8) -- perdeu o saco: um "ah..." baixinho
	end
end

-- apareceu um ovo raro no ninho. Letreiro grande: sempre para o mítico; os comuns só de vez em quando e
-- nunca por cima de um painel (com Sorte alta eles aparecem toda hora).
local RARE_SOUND = { s = 0.7, g = 0.85, m = 1 }
local RARE_TONE = { s = 1.15, g = 1, m = 0.85 } -- quanto mais raro, mais grave e mais alto
local RARE_GAP = { s = 20, g = 8, m = 0 } -- segundos entre letreiros grandes de cada raridade
local lastRarePopup: { [string]: number } = {}
FX.rare = function(position, value)
	local mutation = Config.MutationById[tostring(value)]
	if not mutation then
		return
	end
	local now = os.clock()
	local gap = RARE_GAP[mutation.Id] or 0
	local text = T("pop.mutant", { mut = upper(T("mut." .. mutation.Key)) })
	if now - (lastRarePopup[mutation.Id] or -100) >= gap and (gap == 0 or UI.OpenPanel == nil) then
		lastRarePopup[mutation.Id] = now
		UI.BigPopup(gui, text, mutation.Color, 1.8)
		UI.Sound("Mutante", RARE_SOUND[mutation.Id], RARE_TONE[mutation.Id])
	elseif position then
		World.FloatText(position, text, mutation.Color)
		-- sem letreiro (eles aparecem toda hora com Sorte alta): só um brilho baixinho, no máximo a cada 3 s
		if now - num(V5.RareSoundAt) >= 3 then
			V5.RareSoundAt = now
			UI.Sound("Mutante", 0.25, 1.4)
		end
	end
	if position then
		World.Ping(position, mutation.Color)
		-- Ovo da Sorte (poder): faísca verde no ninho em que o ovo apareceu (o Fx "power" pode vir antes ou depois)
		if V5.LuckAt and now - V5.LuckAt < 3 then
			V5.LuckAt = nil
			World.Puff(position, tbl(tbl(Config.PowerById).sorte).Color)
		else
			V5.Rare = { position, now }
		end
	end
end

FX.pickRare = function(_position, value)
	UI.Toast(T("pop.pickRare", { egg = Lang.Egg(Config, tostring(value)) }), "success")
	UI.Sound("Coletar", 0.6, 1.25)
	UI.Pop(basketPill)
end

FX.sold = function()
	UI.Sound("Vender", 0.75, 0.92) -- venda de ovo raro: a caixa registradora cheia
	UI.Pop(basketPill)
end

FX.album = function(_position, value)
	UI.Toast(T("pop.album", { egg = Lang.Egg(Config, tostring(value)) }), "success")
	task.delay(0.25, UI.Sound, "Premio", 0.4, 1.35) -- figurinha nova (um instante depois do som da venda)
end

-- Comprou um botão do chão: no lugar dele a tampa afunda, sai um anel e confete (o World desenha: o botão de
-- verdade o servidor já apagou). Todo mundo vê; o som é só de quem comprou.
FX.buy = function(position, value, extra)
	local mine = extra == player.UserId
	if position then
		if World.PadBought then
			World.PadBought(position, value, mine)
		else
			World.Puff(position)
		end
	end
	if mine then
		UI.Sound("Comprar", 0.75, 1, 0.05)
	end
end

-- v6: comemoração das conquistas grandes: a câmera "respira" (campo de visão abre e volta) e o celular vibra
local punching = false
local function celebrate(strength: number)
	local camera = workspace.CurrentCamera
	if camera and not punching then
		punching = true
		local base = camera.FieldOfView
		local out = TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base + 6 * strength })
		out:Play()
		out.Completed:Once(function()
			local back = TweenService:Create(camera, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = base })
			back:Play()
			back.Completed:Once(function()
				punching = false
			end)
		end)
	end
	if isTouch then
		task.spawn(function()
			local HapticService = game:GetService("HapticService")
			local motor = Enum.VibrationMotor.Large
			local ok, supported = pcall(HapticService.IsMotorSupported, HapticService, Enum.UserInputType.Gamepad1, motor)
			if ok and supported then
				pcall(HapticService.SetMotor, HapticService, Enum.UserInputType.Gamepad1, motor, 0.6 * strength)
				task.wait(0.15)
				pcall(HapticService.SetMotor, HapticService, Enum.UserInputType.Gamepad1, motor, 0)
			end
		end)
	end
end

FX.newbiz = function(position, value)
	local def = Config.Businesses[tonumber(value) or 0]
	if def then
		celebrate(1)
		UI.BigPopup(gui, T("pop.newbiz", { biz = T("biz." .. def.Id) }), def.Color, 3.2)
		-- som de festa, um instante depois do som da compra (os dois chegam juntos do servidor)
		task.delay(0.18, UI.Sound, "Premio", 0.85, 0.95)
		if position then
			World.Ping(position, def.Color)
		end
		-- poeira de obra onde estava o lote trancado (o servidor já apagou o canteiro e pôs o prédio)
		World.LotOpened(tonumber(value) or 0)
	end
end

FX.manager = function(_position, value)
	local def = Config.Businesses[tonumber(value) or 0]
	if def then
		UI.BigPopup(gui, T("pop.manager", { name = T("mgr." .. def.Id) }), C.Green, 2.4)
		task.delay(0.18, UI.Sound, "Premio", 0.65, 1.2) -- gerente contratado: o som de prêmio, mais agudo que o de negócio novo
	end
end

FX.newline = function(_position, value)
	local line = Config.Lines[tonumber(value) or 0]
	if line then
		UI.BigPopup(gui, T("pop.newline") .. "\n" .. T("bird." .. line.Id), line.Color, 2.6)
		task.delay(0.18, UI.Sound, "Mutante", 0.7, 1.08) -- ave nova
	end
end

FX.nomoney = function(_position, value)
	World.FloatText(nil, T("pop.nomoney", { n = short(num(value)) }), C.Red)
	Hud.NoMoney() -- o contador de moedas treme e pisca vermelho
	UI.Sound("Erro", 0.4, 1, 0.04)
	-- Faltou dinheiro 3 vezes no mesmo minuto: UM aviso pequeno lembrando que a Loja existe, uma vez por
	-- sessão. É só o aviso (some sozinho); nenhuma janela abre e nada é oferecido se a loja está vazia.
	if not Loja.Hinted then
		local now = os.clock()
		local times = Loja.NoMoney
		table.insert(times, now)
		while times[1] and now - times[1] > 60 do
			table.remove(times, 1)
		end
		if #times >= 3 and Loja.HasItems() then
			Loja.Hinted = true
			UI.Toast(T("shop.hint"), "info")
		end
	end
end

FX.apples = function(position, value)
	if position then
		World.FloatText(position, T("pop.apples", { n = short(num(value)) }), C.Red)
	end
	UI.Sound("Coletar", 0.6, 0.85) -- maçãs: o "plim" das moedas, mais grave
end

FX.reward = function(_position, value, extra)
	rewardPopup(num(value), extra)
end

FX.rebirth = function(_position, value)
	UI.BigPopup(gui, T("pop.rebirth", { n = short(num(value)) }), C.Purple, 3)
	UI.Sound("Renascer", 0.85)
	celebrate(1.6)
	World.CoinBurst(nil, 30)
	Hud.Fly(14)
end

FX.seal = function(_position, _value, extra)
	UI.BigPopup(gui, T("pop.seal", { seal = upper(T("seal." .. tostring(extra))) }), C.Yellow, 3.5)
	UI.Sound("Renascer", 0.95, 0.85) -- selo: o som de renascer, mais grave e solene
	task.delay(0.6, UI.Sound, "Premio", 0.6, 1.1)
end

FX.hunt = function(_position, value, extra)
	UI.BigPopup(gui, T("pop.hunt", { a = value, b = extra }), C.Yellow, 2.2)
	UI.Sound("Mutante", 0.6, 1.25)
end

FX.event = function(position, value, extra)
	local duration = num(extra, 30)
	local text = T("event." .. tostring(value), { n = Config.EventById.rain.Speed })
	eventBanner = { Text = text, Ends = os.clock() + duration }
	UI.Toast(text, "event")
	UI.Sound("Evento", 0.7)
	World.EventStart(tostring(value), position, duration)
	if value == "race" then
		showRacePick(duration)
	end
end

FX.eventEnd = function(_position, value)
	eventBanner = nil
	World.EventEnd(tostring(value))
end

FX.order = function(_position, value, extra)
	local info = tbl(extra)
	showOrder(num(value), num(info[1], Config.OrderTimeout), num(info[2], 1))
	UI.Sound("Evento", 0.5, 1.2) -- o telefone da encomenda
end

FX.raceGo = function(_position, value)
	World.RaceGo(value)
	UI.Sound("Evento", 0.5, 1.4) -- largada da corrida
end

FX.raceResult = function(_position, value, extra)
	UI.BigPopup(gui, T("race.result", { place = extra, n = short(num(value)) }), C.Yellow, 2.5)
	UI.Sound("Premio", 0.55, if num(extra, 4) <= 1 then 1.2 else 0.95)
end

FX.hatchStart = function(position, value, extra)
	UI.Toast(T("pop.hatchStart", { pet = petName(tostring(value)), t = Format.Time(num(extra)) }), "info")
	UI.Sound("Coletar", 0.6, 0.9) -- o ovo entrou na chocadeira (o som de chocar fica para quando o pet nasce)
	if position then
		World.Ping(position, C.Pink)
	end
end

FX.hatched = function(position, value, extra)
	local info = tbl(extra)
	showPet(tostring(value), info[1] == true, num(info[2], 1))
	UI.Sound("Chocar", 0.85, if info[1] == true then 1 else 1.12) -- (pet repetido que subiu de nível: um tom acima)
	if position then
		World.Puff(position)
		World.Ping(position, C.Pink)
	end
end

FX.spin = function(_position, value, extra)
	World.WheelSpin()
	playSpin(num(value, 1), extra)
end

FX.giantSoon = function()
	UI.BigPopup(gui, T("giant.soon"), C.Yellow, 3.2)
	UI.Sound("Evento", 0.8, 0.82) -- aviso grave: o Mega Ovo vai rachar
end

FX.giantCrack = function(position)
	World.GiantCrack(position)
	UI.Sound("Gigante", 0.9)
end

FX.giantReward = function(_position, value, extra)
	local info = tbl(extra)
	local near, pet = info[1] == true, info[2]
	UI.BigPopup(gui, T(if near then "giant.rewardNear" else "giant.reward", { n = short(num(value)) }), C.Yellow, 3)
	Hud.Fly(10)
	UI.Sound("Premio", if near then 0.8 else 0.6, if near then 1.1 else 1)
	if pet then
		task.delay(1.4, function()
			local level = math.clamp(num(tbl(state and state.Pets)[pet], 1), 1, Config.Pets.MaxLevel)
			showPet(tostring(pet), level <= 1, level)
			UI.Sound("Chocar", 0.85)
		end)
	end
end

FX.obby = function(position, value)
	UI.BigPopup(gui, T("pop.obby", { n = short(num(value)) }), C.Yellow, 3)
	UI.Sound("Premio", 0.8, 1.1)
	World.CoinBurst(position, 16)
	Hud.Fly(10)
end

FX.sound = function(_position, value)
	UI.Sound(tostring(value))
end

-- VERSÃO 5. O servidor manda:
--   weather    para todos:    sem posição, id do clima, segundos que dura
--   keyDrop    só para o dono: sem posição (a chave está ESCONDIDA: nada de apontar o lugar)
--   keyTake    só para o dono: posição, chaves que tem agora, quantas precisa
--   chestOpen  para todos:    posição do baú, moedas, { userId de quem abriu, dourado?, giros }
--   power      para todos:    banca do dono, id do poder, { userId, coins?, seconds? } (lista ou com nomes)
-- O desenho no mundo (céu, chave, baú, onda do poder) é do World; aqui, os avisos, o som e as moedas voando.
FX.weather = function(_position, value, extra)
	if World.SetWeather then
		World.SetWeather(value, extra) -- (o chip, o aviso e a dica saem do World.OnWeather: vale também para os atributos)
	end
end

FX.keyDrop = function()
	UI.Toast(T("key.drop"), "event")
	UI.Sound("Evento", 0.4, 1.45) -- chave escondida: um toque agudo e discreto
end

FX.keyTake = function(position, value, extra)
	local have = num(value)
	local need = num(extra, num(tbl(Config.Keys).Need))
	UI.Toast(T("key.take", { n = have, m = need }), "success")
	UI.Sound("Coletar", 0.65, 1.4) -- chave pega: o "plim" bem agudo
	if need > 0 and have >= need then
		UI.Toast(T("key.full", { m = need }), "event")
		task.delay(0.3, UI.Sound, "Premio", 0.55, 1.3) -- todas as chaves: o baú já pode ser aberto
	end
	if position then
		World.Puff(position) -- brilho onde a chave estava
	end
end

FX.chestOpen = function(position, value, extra)
	-- (a lista { userId, dourado?, giros } pode chegar cortada se "dourado" vier vazio; aceita também com nomes)
	local info = tbl(extra)
	local who = info[1] or info.userId or info.UserId
	local golden = info[2] == true or info.golden == true or info.Golden == true
	World.ChestOpen(position, golden) -- pulo do baú, clarão e moedas: todo mundo vê
	if who ~= player.UserId then
		return
	end
	local spins = num(info[3] or info.spins or info.Spins, num(tbl(tbl(Config.Keys).Chest).Spins))
	local text = T(if golden then "chest.openGold" else "chest.open", { n = short(num(value)), s = spins })
	if golden then
		UI.BigPopup(gui, text, C.Yellow, 3)
	else
		UI.Toast(text, "success")
	end
	Hud.Fly(if golden then 12 else 8)
	UI.Sound("Premio", if golden then 0.85 else 0.65, if golden then 1.2 else 0.95)
	task.delay(0.35, UI.Sound, "Coletar", 0.5, 1.1) -- as moedas chegando no contador
end

FX.power = function(position, value, extra)
	local info = tbl(extra)
	local who = info[1] or info.userId or info.UserId
	-- (o servidor pode mandar também a ave e o ninho do ovo da sorte: aí a faísca verde sai do ninho para todos)
	local atNest = World.PowerFx(value, position, who, info[4], info[5])
	if who == player.UserId then
		V5.PowerUsed(tostring(value), num(info.coins or info.Coins or info[2]), num(info.seconds or info.Seconds or info[3]), atNest == true)
	end
end

Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind: string, position: Vector3?, value: any, extra: any)
	local handler = FX[kind]
	if handler then
		handler(position, value, extra)
	end
end)

-- ---------------------------------------------------------------------------
-- Teclado e controle: ESC/B fecham painéis; E, X ou o gatilho direito vendem (segurar repete)
-- ---------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return -- o jogador está digitando (código de presente, chat) ou o Roblox já usou a tecla
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Escape or key == Enum.KeyCode.B or key == Enum.KeyCode.ButtonB then
		UI.Show(nil)
	elseif SELL_KEYS[key.Name] and sell.Visible then
		holdKeys[key.Name] = true
		sellTap()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	holdKeys[input.KeyCode.Name] = nil
	local held = holdInput
	-- o dedo é o mesmo objeto do começo ao fim do toque; o mouse pode vir como outro objeto do mesmo tipo
	if held and (input == held or (input.UserInputType == Enum.UserInputType.MouseButton1 and held.UserInputType == Enum.UserInputType.MouseButton1)) then
		releaseHold()
	end
end)

-- trocou de janela com a tecla apertada: o "soltou" nunca chega, então solta tudo aqui
UserInputService.WindowFocusReleased:Connect(function()
	table.clear(holdKeys)
	releaseHold()
end)

-- Roleta da praça: apertar o botão perto dela abre a aba da roleta
World.OnWheel = function()
	openGroup("Prizes", "Wheel")
end

-- Versão 5: o clima mudou (chip, aviso e dica) e a MINHA chave escondida começou a brilhar forte (um aviso por chave)
World.OnWeather = V5.OnWeather
V5.Hinted = {}
World.OnKeyHint = function(keyId: any)
	local id = tostring(keyId)
	if not V5.Hinted[id] then
		V5.Hinted[id] = true
		UI.Toast(T("key.hint"), "info")
		UI.Sound("Mutante", 0.3, 1.45) -- a chave começou a brilhar forte
	end
end

-- (os painéis foram criados depois da 1ª arrumação: agora ganham o lugar deles, entre as pílulas e o contador)
Hud.BottomKey = nil
Hud.Bottom()

World.Start(gui)
request("Refresh")
