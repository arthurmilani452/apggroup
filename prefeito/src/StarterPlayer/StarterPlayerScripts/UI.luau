--[[
	UI (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	Kit da interface: cores, botões, painéis, janelas, barras, avisos e sons.
	Visual escuro e sóbrio (público mais velho): fundo grafite, destaque âmbar e verde-água.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local UI = {}

UI.Theme = {
	Bg = Color3.fromRGB(18, 21, 28),
	Panel = Color3.fromRGB(26, 30, 40),
	Card = Color3.fromRGB(36, 41, 54),
	CardHover = Color3.fromRGB(46, 52, 68),
	Line = Color3.fromRGB(70, 78, 98),
	Text = Color3.fromRGB(236, 240, 248),
	Muted = Color3.fromRGB(150, 158, 178),
	Accent = Color3.fromRGB(255, 196, 70), -- âmbar (dinheiro)
	Teal = Color3.fromRGB(70, 214, 190),
	Good = Color3.fromRGB(90, 210, 120),
	Bad = Color3.fromRGB(235, 80, 80),
	Warn = Color3.fromRGB(240, 160, 60),
	Event = Color3.fromRGB(170, 120, 255),
}
UI.Font = Enum.Font.Gotham
UI.FontBold = Enum.Font.GothamBold
UI.FontBlack = Enum.Font.GothamBlack

function UI.IsMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(target: Instance, radius: number?)
	UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = target })
end

function UI.Stroke(target: Instance, color: Color3?, thickness: number?, transparency: number?)
	UI.new("UIStroke", {
		Color = color or UI.Theme.Line,
		Thickness = thickness or 1,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = target,
	})
end

function UI.Padding(target: Instance, px: number)
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = target,
	})
end

function UI.List(target: Instance, direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?): UIListLayout
	return UI.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		Parent = target,
	})
end

local scales: { UIScale } = {}

local function updateScales()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	local scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.62, 1.15)
	for _, uiScale in scales do
		uiScale.Scale = scale
	end
end

function UI.Screen(name: string, order: number?): ScreenGui
	local gui = UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 1,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	table.insert(scales, UI.new("UIScale", { Parent = gui }))
	updateScales()
	return gui
end

task.defer(function()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	end
	updateScales()
end)

function UI.Panel(parent: Instance, props: { [string]: any }?): Frame
	local frame = UI.new("Frame", {
		BackgroundColor3 = UI.Theme.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	UI.Corner(frame, 12)
	UI.Stroke(frame)
	return frame
end

function UI.Label(parent: Instance, text: string, size: number?, props: { [string]: any }?): TextLabel
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = UI.Theme.Text,
		Font = UI.Font,
		TextSize = size or 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		Size = UDim2.new(1, 0, 0, (size or 16) + 6),
		Parent = parent,
	})
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

-- ===== Sons =====
local soundCache: { [string]: Sound } = {}

function UI.Sound(name: string)
	local info = Config.Sounds[name]
	if not info then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = UI.new("Sound", { SoundId = info.Id, Volume = info.Volume, PlaybackSpeed = info.Speed, Parent = SoundService })
		soundCache[name] = sound
	end
	(sound :: Sound):Play()
end

local buttonBase: { [Instance]: Color3 } = setmetatable({}, { __mode = "k" }) :: any

function UI.Button(parent: Instance, text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local base = (props and props.BackgroundColor3) or UI.Theme.Card
	local button = UI.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = base,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = UI.Theme.Text,
		Font = UI.FontBold,
		TextSize = 16,
		Size = UDim2.fromOffset(120, 40),
		Parent = parent,
	})
	if props then
		for key, value in props do
			(button :: any)[key] = value
		end
	end
	UI.Corner(button, 8)
	buttonBase[button] = base
	button.MouseEnter:Connect(function()
		local color = buttonBase[button] or base
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.12) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = buttonBase[button] or base }):Play()
	end)
	if onClick then
		button.Activated:Connect(function()
			UI.Sound("Click")
			onClick()
		end)
	end
	return button
end

-- Troca a cor de base de um botão criado por UI.Button (o hover passa a usar a nova)
function UI.SetButtonColor(button: TextButton, color: Color3)
	buttonBase[button] = color
	button.BackgroundColor3 = color
end

-- Barra de progresso: devolve a função set(0..1, cor?)
function UI.Bar(parent: Instance, props: { [string]: any }?): (number, Color3?) -> ()
	local back = UI.new("Frame", {
		BackgroundColor3 = UI.Theme.Bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
		Parent = parent,
	})
	if props then
		for key, value in props do
			(back :: any)[key] = value
		end
	end
	UI.Corner(back, 4)
	local fill = UI.new("Frame", { BackgroundColor3 = UI.Theme.Teal, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = back })
	UI.Corner(fill, 4)
	return function(value: number, color: Color3?)
		fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
		if color then
			fill.BackgroundColor3 = color
		end
	end
end

-- ===== Janelas (uma aberta por vez) =====
local modalGui: ScreenGui? = nil
local openModal: any = nil

export type Modal = { Frame: Frame, Body: ScrollingFrame, Open: () -> (), Close: () -> (), Toggle: () -> (), IsOpen: () -> boolean, OnOpen: BindableEvent }

function UI.Modal(title: string, width: number, height: number): Modal
	if not modalGui then
		modalGui = UI.Screen("Windows", 5)
	end
	local frame = UI.Panel(modalGui :: any, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		Visible = false,
		BackgroundColor3 = UI.Theme.Bg,
		BackgroundTransparency = 0.04,
	})
	UI.Label(frame, title, 22, {
		Font = UI.FontBlack,
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -80, 0, 30),
	})
	local body = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 52),
		Size = UDim2.new(1, -28, 1, -64),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = UI.Theme.Line,
		Parent = frame,
	})
	local modal: any = { Frame = frame, Body = body, OnOpen = Instance.new("BindableEvent") }
	function modal.IsOpen(): boolean
		return frame.Visible
	end
	function modal.Close()
		frame.Visible = false
		if openModal == modal then
			openModal = nil
		end
	end
	function modal.Open()
		if openModal and openModal ~= modal then
			openModal.Close()
		end
		openModal = modal
		frame.Visible = true
		modal.OnOpen:Fire()
	end
	function modal.Toggle()
		if frame.Visible then
			modal.Close()
		else
			modal.Open()
		end
	end
	UI.Button(frame, "✕", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(34, 34),
		TextSize = 18,
	}, modal.Close)
	return modal
end

function UI.CloseModals()
	if openModal then
		openModal.Close()
	end
end

-- ===== Avisos =====
local toastGui: ScreenGui? = nil
local toastHolder: Frame? = nil
local toasts: { Frame } = {}

function UI.Toast(text: string, kind: string?)
	if not toastGui then
		toastGui = UI.Screen("Toasts", 10)
		toastHolder = UI.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 190),
			Size = UDim2.fromOffset(520, 400),
			Parent = toastGui,
		})
		UI.List(toastHolder :: any, nil, 6, Enum.HorizontalAlignment.Center)
	end
	local color = ({
		ok = UI.Theme.Good,
		erro = UI.Theme.Bad,
		evento = UI.Theme.Event,
	})[kind or ""] or UI.Theme.Teal
	local card = UI.new("Frame", {
		BackgroundColor3 = UI.Theme.Panel,
		BackgroundTransparency = 0.05,
		Size = UDim2.fromOffset(500, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	UI.Corner(card, 10)
	UI.Stroke(card, color, 1.5, 0)
	UI.Padding(card, 10)
	UI.Label(card, text, 16, { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Center })
	if kind == "erro" then
		UI.Sound("Error")
	elseif kind == "evento" then
		UI.Sound("Alert")
	end
	table.insert(toasts, card)
	while #toasts > 4 do
		table.remove(toasts, 1):Destroy()
	end
	task.delay(if kind == "evento" then 7 else 4, function()
		local index = table.find(toasts, card)
		if index then
			table.remove(toasts, index)
		end
		card:Destroy()
	end)
end

return UI
