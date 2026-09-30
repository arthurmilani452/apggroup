--[[
	UIKit (ModuleScript em StarterPlayer > StarterPlayerScripts)
	O "kit" de interface do jogo: use em TODOS os menus para tudo ficar com a mesma cara.
	  • Paleta de cores (UIKit.Colors) e fonte
	  • create()  - cria qualquer objeto com propriedades e filhos
	  • label()   - texto com contorno
	  • button()  - botão arredondado que CRESCE quando o dedo/mouse passa e "aperta" ao tocar
	  • iconButton() - botão com ícone grande em cima e texto embaixo (menus)
	  • popIn() / pulse() / shake() - animações prontas (todas com TweenService)
	Exemplo:
		local UI = require(script.Parent.UIKit)
		UI.button({ Size = UDim2.fromOffset(200, 60), BackgroundColor3 = UI.Colors.Green, Parent = frame }, "PLAY", function() end)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne

-- Paleta: cores vivas e alegres, fundo escuro azulado para o texto branco aparecer bem
UIKit.Colors = {
	White = Color3.fromRGB(255, 255, 255),
	Dark = Color3.fromRGB(20, 20, 32),
	Panel = Color3.fromRGB(38, 38, 60),
	Row = Color3.fromRGB(55, 55, 82),
	Green = Color3.fromRGB(70, 200, 90),
	Blue = Color3.fromRGB(60, 140, 240),
	Purple = Color3.fromRGB(160, 80, 250),
	Red = Color3.fromRGB(230, 60, 70),
	Gold = Color3.fromRGB(255, 200, 60),
	Orange = Color3.fromRGB(245, 140, 40),
	Pink = Color3.fromRGB(240, 110, 180),
	Teal = Color3.fromRGB(40, 190, 200),
	Gray = Color3.fromRGB(120, 120, 130),
}

UIKit.Radius = 12

local C = UIKit.Colors

function UIKit.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local create = UIKit.create

function UIKit.corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius or UIKit.Radius) })
end

function UIKit.border(color: Color3?, thickness: number?): UIStroke
	return create("UIStroke", {
		Color = color or C.Dark,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.shine(): UIGradient
	return create("UIGradient", {
		Color = ColorSequence.new(C.White, Color3.fromRGB(200, 200, 200)),
		Rotation = 90,
	})
end

function UIKit.textStroke(thickness: number?): UIStroke
	return create("UIStroke", { Color = C.Dark, Thickness = thickness or 2 })
end

function UIKit.label(props: { [string]: any }): TextLabel
	local thickness = props.StrokeThickness
	props.StrokeThickness = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or UIKit.Font
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	props.TextColor3 = props.TextColor3 or C.White
	return create("TextLabel", props, { UIKit.textStroke(thickness) })
end

-- Animação de "mola": cresce ao passar o mouse/dedo, aperta ao tocar, volta ao soltar
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function UIKit.springy(target: GuiButton)
	local scale = target:FindFirstChild("SpringScale") :: UIScale?
	if not scale then
		scale = create("UIScale", { Name = "SpringScale", Parent = target })
	end
	local s = scale :: UIScale
	local hovering = false
	target.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(s, HOVER, { Scale = 1.07 }):Play()
	end)
	target.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(s, HOVER, { Scale = 1 }):Play()
	end)
	target.MouseButton1Down:Connect(function()
		TweenService:Create(s, PRESS, { Scale = 0.92 }):Play()
	end)
	target.MouseButton1Up:Connect(function()
		TweenService:Create(s, RELEASE, { Scale = if hovering then 1.07 else 1 }):Play()
	end)
	target.Activated:Connect(function()
		-- no celular o "mouse" não sai do botão depois do toque: volta ao tamanho normal
		if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			hovering = false
		end
		s.Scale = 0.94
		TweenService:Create(s, RELEASE, { Scale = if hovering then 1.07 else 1 }):Play()
	end)
end

function UIKit.button(props: { [string]: any }, text: string, onClick: () -> ()): (TextButton, TextLabel)
	props.Text = ""
	props.AutoButtonColor = true
	local btn = create("TextButton", props, { UIKit.corner(), UIKit.border(C.Dark, 3), UIKit.shine() })
	local txt = UIKit.label({
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		Text = text,
		ZIndex = props.ZIndex,
		Parent = btn,
	})
	UIKit.springy(btn)
	btn.Activated:Connect(onClick)
	return btn, txt
end

-- Botão de menu: ícone grande em cima, texto embaixo
function UIKit.iconButton(props: { [string]: any }, icon: string, text: string, onClick: () -> ()): (TextButton, TextLabel)
	local btn, txt = UIKit.button(props, "", onClick)
	txt.Size = UDim2.new(1, -8, 0.34, 0)
	txt.Position = UDim2.new(0, 4, 0.62, -2)
	txt.Text = text
	UIKit.label({
		Name = "Icon",
		Size = UDim2.new(1, -8, 0.6, 0),
		Position = UDim2.fromOffset(4, 3),
		Text = icon,
		ZIndex = props.ZIndex,
		StrokeThickness = 0,
		Parent = btn,
	})
	return btn, txt
end

-- Caixa de confirmação ("Tem certeza?") por cima de tudo. scaleWith = função que aplica a escala do celular.
function UIKit.confirm(parent: Instance, title: string, body: string, yesText: string, yesColor: Color3, onYes: () -> (), scaleWith: ((GuiObject) -> ())?)
	local old = parent:FindFirstChild("ConfirmDialog")
	if old then
		old:Destroy()
	end
	local shade = create("TextButton", {
		Name = "ConfirmDialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 40,
		Parent = parent,
	})
	local box = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 250),
		BackgroundColor3 = C.Panel,
		Active = true, -- tocar dentro da caixa não fecha
		ZIndex = 41,
		Parent = shade,
	}, { UIKit.corner(20), UIKit.border(yesColor, 4) })
	if scaleWith then
		scaleWith(box)
	end
	UIKit.label({ Size = UDim2.new(1, -30, 0, 44), Position = UDim2.fromOffset(15, 12), Text = title, TextColor3 = yesColor, ZIndex = 42, Parent = box })
	UIKit.label({
		Size = UDim2.new(1, -40, 0, 96),
		Position = UDim2.fromOffset(20, 60),
		Text = body,
		TextWrapped = true,
		StrokeThickness = 1.5,
		ZIndex = 42,
		Parent = box,
	})
	local function close()
		shade:Destroy()
	end
	UIKit.button({
		Position = UDim2.new(0, 20, 1, -76),
		Size = UDim2.new(0.5, -30, 0, 58),
		BackgroundColor3 = C.Gray,
		ZIndex = 42,
		Parent = box,
	}, "CANCEL", close)
	UIKit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 1, -76),
		Size = UDim2.new(0.5, -30, 0, 58),
		BackgroundColor3 = yesColor,
		ZIndex = 42,
		Parent = box,
	}, yesText, function()
		close()
		onYes()
	end)
	shade.Activated:Connect(close)
	UIKit.popIn(box)
	-- controle de videogame: começa no CANCELAR (mais seguro)
	if UserInputService:GetLastInputType().Name:find("Gamepad") then
		local cancel = box:FindFirstChildOfClass("TextButton")
		if cancel then
			game:GetService("GuiService").SelectedObject = cancel
		end
	end
	return shade
end

-- Janela aparece "pulando" (use ao abrir menus)
-- (reaproveita o UIScale que já existe: o Roblox só usa UM UIScale por objeto)
function UIKit.popIn(frame: GuiObject)
	local scale = frame:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = create("UIScale", { Name = "PopScale", Parent = frame })
	end
	local s = scale :: UIScale
	local base = s:GetAttribute("Base")
	local target = if typeof(base) == "number" then base else 1
	s.Scale = target * 0.75
	TweenService:Create(s, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
end

-- Pulinho rápido (ex.: dinheiro aumentou)
function UIKit.pulse(object: GuiObject, amount: number?)
	local scale = object:FindFirstChild("PulseScale") :: UIScale?
	if not scale then
		scale = create("UIScale", { Name = "PulseScale", Parent = object })
	end
	local s = scale :: UIScale
	s.Scale = 1 + (amount or 0.12)
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Tremidinha (ex.: erro, sem dinheiro): vai e volta 3 vezes
function UIKit.shake(object: GuiObject)
	local start = object:GetAttribute("ShakeHome")
	if typeof(start) ~= "UDim2" then
		start = object.Position
		object:SetAttribute("ShakeHome", start)
	end
	object.Position = start :: UDim2
	local tween = TweenService:Create(object, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {
		Position = (start :: UDim2) + UDim2.fromOffset(7, 0),
	})
	tween:Play()
end

return UIKit
