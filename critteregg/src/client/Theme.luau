--!nonstrict
--[[
	Theme: peças de interface no estilo do jogo de referência (sem imagens enviadas: tudo com Frames).
	  Janela: barra de título colorida com faixas de brilho, título gordo com contorno preto, botão X vermelho,
	          corpo cinza-escuro com borda preta grossa.
	  Cartão: fundo na cor da raridade com degradê, prévia 3D do bichinho (ViewportFrame).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Builder = require(ReplicatedStorage.Shared:WaitForChild("CritterBuilder"))

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.Dark = Color3.fromRGB(12, 12, 20)
Theme.Body = Color3.fromRGB(52, 52, 62)
Theme.Inner = Color3.fromRGB(36, 36, 44)
Theme.White = Color3.new(1, 1, 1)
Theme.Green = Color3.fromRGB(80, 210, 60)
Theme.Blue = Color3.fromRGB(40, 170, 240)
Theme.Red = Color3.fromRGB(225, 40, 50)
Theme.Gray = Color3.fromRGB(110, 110, 125)
Theme.Gold = Color3.fromRGB(255, 200, 50)
Theme.Purple = Color3.fromRGB(150, 80, 240)
Theme.Pink = Color3.fromRGB(255, 80, 150)
Theme.Orange = Color3.fromRGB(250, 140, 40)
Theme.Cyan = Color3.fromRGB(60, 200, 240)

function Theme.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local object = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		(object :: any)[key] = value
	end
	for _, child in children or {} do
		child.Parent = object
	end
	if parent then
		object.Parent = parent
	end
	return object
end
local create = Theme.create

function Theme.corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Theme.stroke(thickness: number?, color: Color3?): UIStroke
	return create("UIStroke", { Thickness = thickness or 3, Color = color or Theme.Dark, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function Theme.text(props: { [string]: any }): TextLabel
	local thickness = props.Stroke
	props.Stroke = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Theme.Font
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	props.TextColor3 = props.TextColor3 or Theme.White
	local label = create("TextLabel", props)
	if thickness ~= 0 then
		create("UIStroke", { Thickness = thickness or 2.5, Color = Theme.Dark, Parent = label })
	end
	return label
end

-- brilho "plástico": claro em cima, escuro embaixo
function Theme.gloss(target: GuiObject, strength: number?)
	local s = strength or 0.25
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1 - s * 0.3, 1 - s * 0.3, 1 - s * 0.3)),
			ColorSequenceKeypoint.new(1, Color3.new(1 - s, 1 - s, 1 - s)),
		}),
		Rotation = 90,
		Parent = target,
	})
end

local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
local BOUNCE = TweenInfo.new(0.25, Enum.EasingStyle.Back)

function Theme.springy(button: GuiButton)
	local scale = create("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 0.92 }):Play()
	end)
	button.Activated:Connect(function()
		if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			TweenService:Create(scale, BOUNCE, { Scale = 1 }):Play()
		else
			TweenService:Create(scale, BOUNCE, { Scale = 1.06 }):Play()
		end
	end)
end

-- botão gordo colorido com contorno preto e texto com contorno
function Theme.button(props: { [string]: any }, text: string, onClick: () -> ()): (TextButton, TextLabel)
	props.Text = ""
	props.AutoButtonColor = false
	local button = create("TextButton", props, { Theme.corner(10), Theme.stroke(3.5) })
	Theme.gloss(button, 0.3)
	local label = Theme.text({ Name = "Label", Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = text, ZIndex = props.ZIndex, Parent = button })
	Theme.springy(button)
	button.Activated:Connect(function()
		if Theme.OnClick then
			Theme.OnClick()
		end
		onClick()
	end)
	return button, label
end

-- JANELA no estilo do jogo (barra colorida + corpo escuro). Devolve (janela, corpo)
function Theme.window(parent: Instance, name: string, title: string, color: Color3, size: Vector2): (Frame, Frame)
	local window = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.Body,
		Visible = false,
		ZIndex = 10,
		Active = true,
		Parent = parent,
	}, { Theme.corner(14), Theme.stroke(5) })
	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = color,
		ZIndex = 11,
		ClipsDescendants = true,
		Parent = window,
	}, { Theme.corner(14) })
	Theme.gloss(header, 0.2)
	-- cobre os cantos arredondados de baixo da barra
	create("Frame", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 11, Parent = header })
	-- faixas de brilho na diagonal
	for i, x in { 0.55, 0.63, 0.72 } do
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.new(0, if i == 2 then 14 else 34, 2, 0),
			Rotation = 35,
			BackgroundColor3 = Theme.White,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			ZIndex = 12,
			Parent = header,
		})
	end
	create("Frame", { Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -4), BackgroundColor3 = Theme.Dark, BorderSizePixel = 0, ZIndex = 13, Parent = header })
	Theme.text({ Name = "Title", Size = UDim2.new(1, -120, 0, 56), Position = UDim2.fromOffset(22, 7), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, ZIndex = 13, Parent = header })
	local close = Theme.button({ Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = Theme.Red, ZIndex = 14, Parent = window }, "X", function()
		window.Visible = false
	end)
	local _ = close
	local body = create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -24, 1, -92),
		Position = UDim2.fromOffset(12, 82),
		BackgroundColor3 = Theme.Inner,
		ZIndex = 11,
		Parent = window,
	}, { Theme.corner(10), Theme.stroke(3) })
	-- fundo do corpo: só um degradê leve (v66 perf). Antes eram 252 "pontinhos" (Frame + UICorner = 504 peças
	-- por janela, ~6000 no total) desenhados toda vez que a janela abria; no celular fraco isso pesava.
	Theme.gloss(body, 0.22)
	return window, body
end

-- v66: respeita o tamanho de "caber na tela" (atributo Fit, ver Theme.fit): no celular a janela grande abre menor
function Theme.popIn(object: GuiObject)
	local scale = object:FindFirstChild("PopScale") or create("UIScale", { Name = "PopScale", Parent = object })
	local fit = object:GetAttribute("Fit")
	local target = if type(fit) == "number" then fit else 1
	scale.Scale = target * 0.6
	TweenService:Create(scale, BOUNCE, { Scale = target }):Play()
end

-- v66: encolhe um objeto (ex.: janela maior que a tela do celular) para caber; o popIn usa o mesmo valor
function Theme.fit(object: GuiObject, scale: number)
	object:SetAttribute("Fit", scale)
	local pop = object:FindFirstChild("PopScale") or create("UIScale", { Name = "PopScale", Parent = object })
	pop.Scale = scale
end

-- v67: chama a atenção para um botão (balança e a borda pisca amarela) até chamar a função devolvida.
-- (não mexe no UIScale: ele é do springy, e o toque/hover cancelaria o efeito)
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
function Theme.pulse(object: GuiObject): () -> ()
	local edge = object:FindFirstChildOfClass("UIStroke")
	local oldColor = if edge then edge.Color else nil
	local oldThickness = if edge then edge.Thickness else nil
	object.Rotation = -4
	local tweens = { TweenService:Create(object, PULSE, { Rotation = 4 }) }
	if edge and oldThickness then
		table.insert(tweens, TweenService:Create(edge, PULSE, { Color = Color3.fromRGB(255, 230, 80), Thickness = oldThickness + 2 }))
	end
	for _, tween in tweens do
		tween:Play()
	end
	return function()
		for _, tween in tweens do
			tween:Cancel()
		end
		object.Rotation = 0
		if edge and oldColor and oldThickness then
			edge.Color = oldColor
			edge.Thickness = oldThickness
		end
	end
end

-- v66: selo vermelho no canto de cima à direita ("!" ou um número). Começa escondido.
function Theme.badge(parent: GuiObject, label: string?): (Frame, TextLabel)
	local layer = parent.ZIndex + 2
	local badge = create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Theme.Red,
		Visible = false,
		ZIndex = layer,
		Parent = parent,
	}, { Theme.corner(16), Theme.stroke(3, Theme.White) })
	local badgeText = Theme.text({ Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), Text = label or "!", ZIndex = layer, Parent = badge })
	return badge, badgeText
end

function Theme.rarityColor(rarity: string): Color3
	local info = Config.RarityByName[rarity]
	return if info then info.Color else Theme.Gray
end

-- cor de fundo do cartão por raridade (mais viva que a cor do texto)
local CARD = {
	Common = Color3.fromRGB(150, 150, 160),
	Uncommon = Color3.fromRGB(60, 200, 70),
	Rare = Color3.fromRGB(30, 110, 240),
	Epic = Color3.fromRGB(150, 50, 230),
	Legendary = Color3.fromRGB(245, 190, 20),
	Mythic = Color3.fromRGB(240, 40, 110),
	Secret = Color3.fromRGB(30, 30, 40),
	Divine = Color3.fromRGB(255, 230, 120),
	Celestial = Color3.fromRGB(40, 190, 230),
}
function Theme.cardColor(rarity: string): Color3
	return CARD[rarity] or Theme.Gray
end

-- prévia 3D do bichinho. silhouette = sombra preta (ainda não descoberto)
local modelCache = {}
function Theme.preview(parent: GuiObject, def, silhouette: boolean?, spin: boolean?): ViewportFrame
	local viewport = create("ViewportFrame", {
		Name = "Preview",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = if silhouette then Color3.new(0, 0, 0) else Color3.fromRGB(200, 200, 200),
		LightColor = if silhouette then Color3.new(0, 0, 0) else Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
		ZIndex = parent.ZIndex + 1,
		Parent = parent,
	})
	local ok, model = pcall(function()
		local template = modelCache[def.Id]
		if not template then
			template = Builder.Build(def)
			modelCache[def.Id] = template
		end
		return template:Clone()
	end)
	if not ok or not model then
		return viewport
	end
	if silhouette then
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.Color = Color3.new(0, 0, 0)
				item.Material = Enum.Material.SmoothPlastic
			elseif item:IsA("Decal") or item:IsA("ParticleEmitter") or item:IsA("PointLight") or item:IsA("BillboardGui") then
				item:Destroy()
			end
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.62
	local camera = create("Camera", { FieldOfView = 40, Parent = viewport })
	viewport.CurrentCamera = camera
	local angle = math.rad(25)
	local function place(a: number)
		local dir = Vector3.new(math.sin(a), 0.35, -math.cos(a)).Unit
		camera.CFrame = CFrame.lookAt(cf.Position + dir * radius * 3.1, cf.Position)
	end
	place(angle)
	if spin then
		task.spawn(function()
			while viewport.Parent do
				angle += 0.03
				place(angle)
				task.wait(1 / 30)
			end
		end)
	end
	return viewport
end

return Theme
