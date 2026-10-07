--[[
	UI: peças de interface (cores, botões, painéis, avisos) usadas pela tela do jogo.
	Feito para celular: tudo em escala, botões grandes (alvo de toque de 60 px virtuais ou mais), painéis com rolagem.
	Jogo infantil: botão tem cara de botão (brilho em cima, contorno grosso) e sempre responde ao toque (pulinho + som).
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local UI = {}

UI.C = {
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
	Pink = Color3.fromRGB(255, 110, 190),
	Gray = Color3.fromRGB(170, 160, 150),
	White = Color3.new(1, 1, 1),
	Black = Color3.new(0, 0, 0),
}
UI.Font = Enum.Font.FredokaOne
UI.Font2 = Enum.Font.GothamBold

local C = UI.C

local EMOJI = {
	Moeda = "💰",
	Cesta = "🧺",
	Raio = "⚡",
	Estrela = "⭐",
	Presente = "🎁",
	Trofeu = "🏆",
	R_Galinha_Comum = "🐔",
	R_Galinha_Caipira = "🐔",
	R_Pata = "🦆",
	R_Codorna = "🐦",
	R_Galinha_Dourada = "🐔",
	R_Galinha_Cristal = "🐔",
	R_Galinha_ArcoIris = "🐔",
	R_Galinha_Lunar = "🐔",
	R_Filhote_Dragao = "🐉",
}

UI.SfxOn = true

function UI.New(className: string, props: { [string]: any }, children: { Instance }?): any
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

local new = UI.New

function UI.Corner(radius: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(radius or 0.25, 0) })
end

function UI.Stroke(color: Color3?, thickness: number?): UIStroke
	return new("UIStroke", { Color = color or C.DarkBrown, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UI.TextStroke(thickness: number?): UIStroke
	return new("UIStroke", { Color = C.DarkBrown, Thickness = thickness or 2 })
end

-- Brilho de botão: claro em cima, um pouco mais escuro embaixo (dá volume sem precisar de imagem)
function UI.Shine(): UIGradient
	return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.White, Color3.fromRGB(200, 200, 200)) })
end

-- Texto. MaxText = tamanho máximo da letra (o texto encolhe para caber). Dark = letra marrom sem contorno.
function UI.Label(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = C.White,
	}
	local maxText = props.MaxText or 40
	local dark = props.Dark
	for k, v in props do
		if k ~= "MaxText" and k ~= "Dark" then
			base[k] = v
		end
	end
	if dark then
		base.TextColor3 = props.TextColor3 or C.DarkBrown
	end
	local l = new("TextLabel", base)
	if not dark then
		UI.TextStroke().Parent = l
	end
	new("UITextSizeConstraint", { MaxTextSize = maxText, MinTextSize = 6, Parent = l })
	return l
end

-- Ícone: imagem do Config.Images se tiver ID, senão um emoji
function UI.Icon(name: string, props: { [string]: any }, emoji: string?): GuiObject
	local id = Config.Images[name]
	if id and id ~= "" then
		local base: { [string]: any } = { BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit }
		for k, v in props do
			base[k] = v
		end
		return new("ImageLabel", base)
	end
	local text = emoji or EMOJI[name] or (if string.sub(name, 1, 3) == "Ovo" or string.sub(name, 1, 5) == "R_Ovo" then "🥚" else "⭐")
	local base: { [string]: any } = { BackgroundTransparency = 1, Font = UI.Font2, TextScaled = true, Text = text, TextColor3 = C.White }
	for k, v in props do
		if k ~= "ImageColor3" and k ~= "ImageTransparency" then
			base[k] = v
		end
	end
	if props.ImageTransparency then
		base.TextTransparency = props.ImageTransparency
	end
	return new("TextLabel", base)
end

-- "Pulo" rápido de um elemento. from > 1 = cresce e volta (chama a atenção); from < 1 = afunda e volta (toque).
function UI.Pop(object: Instance, from: number?)
	local scale: any = object:FindFirstChild("PopScale")
	if not scale then
		scale = new("UIScale", { Name = "PopScale", Parent = object })
	end
	scale.Scale = from or 1.16
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Some encolhendo (fundo, texto e contorno juntos) e destrói. Mudar só a transparência do texto deixava o contorno para trás.
function UI.Vanish(object: Instance)
	if not object.Parent then
		return
	end
	local scale: any = object:FindFirstChild("PopScale")
	if not scale then
		scale = new("UIScale", { Name = "PopScale", Parent = object })
	end
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.01 }):Play()
	task.delay(0.26, function()
		object:Destroy()
	end)
end

function UI.Button(props: { [string]: any }, onClick: () -> ()): TextButton
	local base: { [string]: any } = {
		AutoButtonColor = true,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = C.White,
		BackgroundColor3 = C.Green,
	}
	local maxText = props.MaxText or 30
	for k, v in props do
		if k ~= "MaxText" then
			base[k] = v
		end
	end
	local b = new("TextButton", base, { UI.Corner(0.3), UI.Stroke(C.DarkBrown, 3), UI.TextStroke(), UI.Shine() })
	new("UITextSizeConstraint", { MaxTextSize = maxText, MinTextSize = 6, Parent = b })
	b.Activated:Connect(function()
		UI.Sound("Clique", 0.35)
		UI.Pop(b, 0.92)
		onClick()
	end)
	return b
end

-- ---------------------------------------------------------------------------
-- SONS. Um Sound por nome (os 13 do Config.Sounds), criado UMA vez no SoundService e tocado de novo a cada vez.
-- (Criar e destruir um Sound por clique enchia o SoundService: 5 cliques por segundo no botão VENDER.)
-- O dono do jogo não ouviu som nenhum no jogo publicado, então aqui nada fica por conta da sorte:
--   * UI.InitSounds cria todos logo que a tela liga e manda carregar (ContentProvider:PreloadAsync): o 1º
--     clique já sai com som, em vez de tocar atrasado ou nem tocar;
--   * som que FALHA ao carregar (ID apagado, áudio sem permissão para este jogo) ou que não carrega em
--     SOUND_WAIT segundos ganha um warn claro no Output, uma vez por som, com o nome e o ID;
--   * a música toca de novo quando termina de carregar (Loaded) e no 1º toque/clique/tecla do jogador, se a
--     essa altura ainda não estiver tocando;
--   * se alguém apagar um Sound do SoundService no meio do jogo, ele é criado de novo na próxima vez.
-- UI.SfxOn / UI.MusicOn são as opções do jogador (Configurações); a tela aplica o que veio salvo do servidor.
-- ---------------------------------------------------------------------------
local SOUND_WAIT = 10 -- segundos para um som carregar antes do aviso
local sounds: { [string]: Sound } = {}
local soundWarned: { [string]: boolean } = {}
local soundsStarted = false
local musicAsked = false -- a tela já mandou ligar a música (UI.SetMusic)? Antes disso ninguém toca nada sozinho
UI.MusicOn = true
UI.Sounds = sounds -- (à mostra para o teste e para quem for investigar no Studio)

local function soundWarn(name: string, why: string)
	if soundWarned[name] then
		return
	end
	soundWarned[name] = true
	warn(("[VendaUmOvo] SOM '%s' (%s) %s. Confira no Studio se esse áudio existe e se está liberado para este jogo (Creator Hub > áudio > Permissões > adicionar a experiência)."):format(name, tostring(Config.Sounds[name]), why))
end

-- (propriedades que dependem do motor: lidas com cuidado, para um erro de leitura nunca calar o resto)
local function soundFlag(s: Sound, property: string): boolean
	local ok, value = pcall(function()
		return (s :: any)[property]
	end)
	return ok and value == true
end

local function musicKick()
	local m = sounds.Musica
	if not musicAsked or not UI.MusicOn or not m or not m.Parent then
		return
	end
	-- "tocando" mas parada no zero = o Play saiu antes de o áudio chegar e não pegou: toca de novo
	local stuck = false
	pcall(function()
		stuck = m.TimePosition < 0.05
	end)
	if not soundFlag(m, "IsPlaying") or stuck then
		m:Play()
	end
end

local function getSound(name: string): Sound?
	local id = Config.Sounds[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local s = sounds[name]
	if s and s.Parent then
		return s
	end
	local music = name == "Musica"
	local made: Sound = new("Sound", { Name = if music then "VUOMusic" else "VUO_" .. name, SoundId = id, Volume = if music then Config.MusicVolume else 0.7, Looped = music, Parent = SoundService })
	sounds[name] = made
	if music then
		made.Loaded:Connect(musicKick)
	end
	-- não carregou em SOUND_WAIT segundos: avisa (uma vez por som). No jogo de verdade o motivo de sempre é o
	-- áudio não estar liberado para a experiência; o Output do Studio mostra também o erro do próprio Roblox.
	task.delay(SOUND_WAIT, function()
		if made.Parent and not soundFlag(made, "IsLoaded") then
			soundWarn(name, ("não carregou em %d s"):format(SOUND_WAIT))
		end
	end)
	return made
end

-- Cria e pré-carrega os 13 sons (chamado uma vez, quando a tela liga). Não trava nada: roda à parte.
function UI.InitSounds()
	if soundsStarted then
		return
	end
	soundsStarted = true
	local list: { Instance } = {}
	local byId: { [string]: string } = {}
	for name, id in Config.Sounds do
		local s = getSound(name)
		if s then
			table.insert(list, s)
			byId[tostring(id)] = name
			byId[string.match(tostring(id), "%d+$") or tostring(id)] = name
		end
	end
	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(list, function(assetId: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut then
					local name = byId[tostring(assetId)] or byId[string.match(tostring(assetId), "%d+$") or ""]
					soundWarn(name or tostring(assetId), "FALHOU ao carregar (" .. status.Name .. ")")
				end
			end)
		end)
		if not ok then
			warn("[VendaUmOvo] pré-carga dos sons não rodou: " .. tostring(err))
		end
		musicKick()
		-- no Studio, uma linha de resumo no Output para quem está conferindo os sons
		if RunService:IsStudio() then
			local loaded, missing = 0, {}
			for name, s in sounds do
				if soundFlag(s, "IsLoaded") then
					loaded += 1
				else
					table.insert(missing, name)
				end
			end
			table.sort(missing)
			print(("[VendaUmOvo] sons carregados: %d de %d%s"):format(loaded, #list, if #missing > 0 then " (ainda faltam: " .. table.concat(missing, ", ") .. ")" else ""))
		end
	end)
	-- 1º toque, clique ou tecla do jogador: se a música já devia estar tocando e não está, toca agora
	local first: RBXScriptConnection? = nil
	first = UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Focus then
			return
		end
		if musicAsked then
			if first then
				first:Disconnect()
				first = nil
			end
			musicKick()
		end
	end)
end

-- Toca um som. volume 0..1 (padrão 0,7); speed = altura (1 = normal; mais alto = mais agudo); jitter = quanto
-- a altura varia ao acaso para cima e para baixo (0,06 = 6%), para o mesmo som repetido não enjoar.
function UI.Sound(name: string, volume: number?, speed: number?, jitter: number?)
	if not UI.SfxOn or name == "Musica" then
		return
	end
	local s = getSound(name)
	if not s then
		return
	end
	local pitch = speed or 1
	if jitter then
		pitch *= 1 + (math.random() * 2 - 1) * jitter
	end
	s.Volume = math.clamp(volume or 0.7, 0, 1)
	s.PlaybackSpeed = math.clamp(pitch, 0.4, 2.5)
	s:Play()
end

-- Liga ou desliga a música de fundo (a opção do jogador). Pode ser chamada quantas vezes for.
function UI.SetMusic(on: boolean)
	UI.MusicOn = on
	musicAsked = true
	local m = getSound("Musica")
	if not m then
		return
	end
	m.Looped = true
	m.Volume = Config.MusicVolume
	if on then
		if not soundFlag(m, "IsPlaying") then
			m:Play()
		end
	else
		m:Stop()
	end
end

-- ---------------------------------------------------------------------------
-- Escala: a tela é desenhada numa "tela virtual" de ~720 de altura e encolhida/esticada para caber.
-- No celular tudo fica do mesmo jeito que no PC, só menor (os botões continuam grandes para o dedo).
-- Devolve o quadro raiz: TUDO da interface vai dentro dele.
-- UI.OnScale (opcional) é chamado sempre que a escala muda: a tela reposiciona o que depende do tamanho real.
-- ---------------------------------------------------------------------------
UI.Scale = 1
UI.Root = nil :: Frame?
UI.OnScale = nil :: (() -> ())?

function UI.InitScale(gui: ScreenGui): Frame
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local scale = new("UIScale", { Parent = root })
	local function apply()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		if size.X < 50 or size.Y < 50 then
			return
		end
		local s = math.clamp(math.min(size.Y / 720, size.X / 1100), 0.5, 1.25)
		UI.Scale = s
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		if UI.OnScale then
			UI.OnScale()
		end
	end
	apply()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
	UI.Root = root
	return root
end

-- Moedas voando do meio da tela até o contador. target = para onde elas vão (a moeda grande do contador, que
-- hoje fica embaixo, no meio); at = ponto dentro do alvo, de 0 a 1 (padrão: o meio dele); pop = o que dá o
-- pulinho quando a primeira moeda chega (padrão: o próprio alvo).
function UI.FlyCoins(gui: Instance, target: GuiObject, amount: number, at: Vector2?, pop: GuiObject?)
	local root = UI.Root
	if not root or not target.Parent then
		return
	end
	local s = UI.Scale
	local origin = root.AbsolutePosition
	local goal = (target.AbsolutePosition + target.AbsoluteSize * (at or Vector2.new(0.5, 0.5)) - origin) / s
	local size = root.AbsoluteSize / s
	for i = 1, math.min(amount, 12) do
		-- nascem espalhadas no meio da tela, um pouco acima do centro (o contador fica embaixo: o caminho é para baixo)
		local start = Vector2.new(size.X * (0.38 + math.random() * 0.24), size.Y * (0.38 + math.random() * 0.14))
		local coin = UI.Icon("Moeda", { Name = "FlyCoin", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(start.X, start.Y), Size = UDim2.fromOffset(38, 38), ZIndex = 30, Parent = gui }) -- abaixo das janelas (40+): moeda voando não tampa texto de janela
		task.delay(0.04 * i, function()
			local tween = TweenService:Create(coin, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(goal.X, goal.Y), Size = UDim2.fromOffset(22, 22) })
			tween:Play()
			task.wait(0.58)
			coin:Destroy()
			if i == 1 then
				UI.Pop(pop or target)
			end
		end)
	end
end

-- Texto curto que sobe e some a partir de um elemento (o "+2" em cima do botão VENDER)
function UI.Rise(from: GuiObject, text: string, color: Color3)
	local x = 0.5 + (math.random() - 0.5) * 0.3
	local l = UI.Label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(x, 0, 0, 4), Size = UDim2.new(1.2, 0, 0, 40), Text = text, TextColor3 = color, MaxText = 34, ZIndex = from.ZIndex + 5, Parent = from })
	TweenService:Create(l, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(x, 0, 0, -64) }):Play()
	task.delay(0.5, UI.Vanish, l)
end

-- ---------------------------------------------------------------------------
-- Painéis (janelas com título, X e lista com rolagem)
-- ---------------------------------------------------------------------------
UI.Panels = {} :: { [string]: Frame }
UI.Refreshers = {} :: { [string]: () -> () }
UI.OpenPanel = nil :: string?
UI.OnShow = nil :: ((name: string?) -> ())? -- (opcional) chamado sempre que um painel abre ou fecha: a tela esconde o que ficaria por baixo

function UI.Show(name: string?)
	local wasClosed = UI.OpenPanel == nil
	for key, panel in UI.Panels do
		panel.Visible = key == name
	end
	UI.OpenPanel = name
	if name and UI.Refreshers[name] then
		UI.Refreshers[name]()
	end
	-- o painel "salta" ao abrir (trocar de aba não repete o salto: ficaria tremendo)
	local panel = name and UI.Panels[name]
	if panel and wasClosed then
		UI.Pop(panel, 0.86)
		UI.Sound("Clique", 0.35, 1.3) -- abrir: clique mais agudo
	elseif not name and not wasClosed then
		UI.Sound("Clique", 0.3, 0.8) -- fechar: clique mais grave
	end
	if UI.OnShow then
		UI.OnShow(name)
	end
end

function UI.Toggle(name: string)
	UI.Show(if UI.OpenPanel == name then nil else name)
end

function UI.RefreshOpen()
	local name = UI.OpenPanel
	if name and UI.Refreshers[name] then
		UI.Refreshers[name]()
	end
end

-- Cria o painel e devolve (lista com rolagem, rótulo do título).
-- Cabeçalho e X têm altura fixa (o X precisa de 60 px para o dedo mesmo quando o painel encolhe no celular).
function UI.MakePanel(gui: Instance, name: string, color: Color3): (ScrollingFrame, TextLabel)
	local panel = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.53, 0),
		Size = UDim2.new(0.66, 0, 0.8, 0),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}, { UI.Corner(0.06), UI.Stroke(C.DarkBrown, 4), new("UISizeConstraint", { MaxSize = Vector2.new(760, 600), MinSize = Vector2.new(300, 250) }) })
	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = color, ZIndex = 5, Parent = panel }, { UI.Corner(0.3), UI.Stroke(C.DarkBrown, 3), UI.Shine() })
	local title = UI.Label({ Name = "Title", Position = UDim2.new(0, 22, 0.12, 0), Size = UDim2.new(1, -110, 0.76, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = header })
	UI.Button({ Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(66, 60), Text = "X", BackgroundColor3 = C.Red, ZIndex = 6, Parent = header }, function()
		UI.Show(nil)
	end)
	local list = new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.new(0, 14, 0, 78),
		Size = UDim2.new(1, -28, 1, -90),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Brown,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 5,
		Parent = panel,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.Panels[name] = panel
	return list, title
end

function UI.Clear(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Linha de texto simples dentro de uma lista
function UI.Note(list: Instance, order: number, text: string, height: number?): TextLabel
	return UI.Label({
		Size = UDim2.new(1, -10, 0, height or 30),
		Text = text,
		Dark = true,
		TextColor3 = C.Brown,
		Font = UI.Font2,
		TextWrapped = true,
		MaxText = 20,
		LayoutOrder = order,
		ZIndex = 6,
		Parent = list,
	})
end

-- Cartão padrão: ícone | título + descrição | botão (onClick nil = botão apagado)
function UI.Card(list: Instance, order: number, iconObj: GuiObject, title: string, desc: string, buttonText: string, buttonColor: Color3, onClick: (() -> ())?): Frame
	local f = new("Frame", { Size = UDim2.new(1, -10, 0, 88), BackgroundColor3 = C.Cream, LayoutOrder = order, ZIndex = 6, Parent = list }, { UI.Corner(0.2), UI.Stroke(C.Brown, 2) })
	iconObj.Position = UDim2.new(0, 8, 0.1, 0)
	iconObj.Size = UDim2.new(0, 66, 0.8, 0)
	iconObj.ZIndex = 7
	iconObj.Parent = f
	UI.Label({ Position = UDim2.new(0, 84, 0.08, 0), Size = UDim2.new(0.64, -84, 0.44, 0), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Dark = true, MaxText = 26, ZIndex = 7, Parent = f })
	UI.Label({ Position = UDim2.new(0, 84, 0.52, 0), Size = UDim2.new(0.64, -84, 0.38, 0), Text = desc, TextXAlignment = Enum.TextXAlignment.Left, Dark = true, TextColor3 = C.Brown, MaxText = 18, Font = UI.Font2, ZIndex = 7, Parent = f })
	local b = UI.Button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.33, 0, 0, 64), Text = buttonText, BackgroundColor3 = buttonColor, MaxText = 24, ZIndex = 7, Parent = f }, function()
		if onClick then
			onClick()
		end
	end)
	b.Active = onClick ~= nil
	b.AutoButtonColor = onClick ~= nil
	return f
end

-- Barra de progresso
function UI.Bar(parent: Instance, fraction: number, color: Color3, text: string?, props: { [string]: any }?): Frame
	local base: { [string]: any } = { BackgroundColor3 = C.Gray, ZIndex = 7, Parent = parent }
	for k, v in props or {} do
		base[k] = v
	end
	local bar = new("Frame", base, { UI.Corner(0.5), UI.Stroke(C.DarkBrown, 2) })
	new("Frame", { Name = "Fill", Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0), BackgroundColor3 = color, ZIndex = base.ZIndex, Parent = bar }, { UI.Corner(0.5) })
	if text then
		UI.Label({ Name = "Text", Size = UDim2.new(1, 0, 1, 0), Text = text, MaxText = 20, ZIndex = base.ZIndex + 1, Parent = bar })
	end
	return bar
end

-- ---------------------------------------------------------------------------
-- Avisos (toasts) e textos grandes no meio da tela
-- ---------------------------------------------------------------------------
local toastHolder: Frame? = nil
local KIND_COLOR = { success = C.Green, error = C.Red, event = C.Purple, info = C.Blue }

function UI.InitToasts(gui: Instance)
	toastHolder = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.new(0.6, 0, 0.3, 0),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }), new("UISizeConstraint", { MaxSize = Vector2.new(560, 400) }) })
end

function UI.Toast(text: string, kind: string?)
	local holder = toastHolder
	if not holder then
		return
	end
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = KIND_COLOR[kind or "info"] or C.Blue, ZIndex = 20, Parent = holder }, { UI.Corner(0.4), UI.Stroke(C.DarkBrown, 3) })
	UI.Label({ Position = UDim2.new(0.03, 0, 0.1, 0), Size = UDim2.new(0.94, 0, 0.8, 0), Text = text, MaxText = 24, ZIndex = 21, Parent = f })
	UI.Pop(f, 0.7)
	task.delay(3.5, UI.Vanish, f)
	-- no máximo 4 avisos na tela: os mais antigos saem
	local frames = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	for i = 1, #frames - 4 do
		frames[i]:Destroy()
	end
end

local bigPopup: TextLabel? = nil

function UI.BigPopup(gui: Instance, text: string, color: Color3, seconds: number?)
	-- um de cada vez: o novo entra no lugar do antigo (senão os textos ficam um por cima do outro)
	if bigPopup and bigPopup.Parent then
		bigPopup:Destroy()
	end
	local l = UI.Label({ Name = "BigPopup", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.33, 0), Size = UDim2.new(0.1, 0, 0.02, 0), Text = text, TextColor3 = color, MaxText = 70, ZIndex = 30, Parent = gui })
	bigPopup = l
	TweenService:Create(l, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(0.7, 0, 0.16, 0) }):Play()
	task.delay(seconds or 2.2, UI.Vanish, l)
end

return UI
