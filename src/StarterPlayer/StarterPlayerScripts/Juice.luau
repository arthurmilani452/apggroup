--[[
	Juice (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Efeitos que deixam o jogo "gostoso" (tudo só na tela do jogador, sem pesar o servidor):
	  • Juice.Shake(força, duração)  - tremor de câmera
	  • Juice.Confetti(gui, quantidade) - chuva de confete na tela
	  • Juice.MoneyPop(parte, texto, cor) - "+$120" pulando de cima de um bichinho
	As animações usam TweenService.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Juice = {}

---------------------------------------------------------------------
-- Tremor de câmera: a força cai até zero (tween) e somamos um deslocamento na câmera a cada quadro
---------------------------------------------------------------------
local shakePower = Instance.new("NumberValue")
shakePower.Value = 0
local shakeBound = false

function Juice.Shake(power: number?, duration: number?)
	if Players.LocalPlayer and Players.LocalPlayer:GetAttribute("CameraShake") == false then
		return -- desligado em SETTINGS
	end
	shakePower.Value = math.max(shakePower.Value, power or 0.6)
	TweenService:Create(shakePower, TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 0 }):Play()
	if shakeBound then
		return
	end
	shakeBound = true
	RunService:BindToRenderStep("JuiceShake", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local p = shakePower.Value
		if not camera then
			return
		end
		if p <= 0.001 then
			RunService:UnbindFromRenderStep("JuiceShake")
			shakeBound = false
			return
		end
		local t = os.clock() * 40
		local offset = Vector3.new(math.noise(t, 0, 1), math.noise(0, t, 2), 0) * p
		camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.noise(t, t, 3) * p * 0.03)
	end)
end

---------------------------------------------------------------------
-- Confete
---------------------------------------------------------------------
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 150, 60),
}

function Juice.Confetti(gui: Instance, count: number?, colors: { Color3 }?)
	local palette = colors or CONFETTI_COLORS
	local total = count or 70
	if Players.LocalPlayer and Players.LocalPlayer:GetAttribute("LowGfx") then
		total = math.floor(total / 3) -- gráficos leves: menos confete
	end
	for _ = 1, total do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = palette[math.random(1, #palette)]
		piece.Size = UDim2.fromOffset(math.random(7, 12), math.random(12, 20))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.new(math.random(), 0, 0, -20 - math.random(0, 200))
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 50
		piece.Parent = gui
		local duration = 1.6 + math.random() * 1.2
		local tween = TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.25, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-540, 540),
			BackgroundTransparency = 0.3,
		})
		tween.Completed:Connect(function()
			piece:Destroy()
		end)
		tween:Play()
	end
end

---------------------------------------------------------------------
-- Número de dinheiro saindo de cima de um bichinho
---------------------------------------------------------------------
function Juice.MoneyPop(adornee: BasePart, text: string, color: Color3?, height: number?)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(120, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height or 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(120, 255, 120)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(15, 60, 20)
	stroke.Parent = label
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	gui.Parent = adornee
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local rise = TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, (height or 3) + 3.5, 0),
	})
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.6), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.6), { Transparency = 1 }):Play()
	rise.Completed:Connect(function()
		gui:Destroy()
	end)
	rise:Play()
end

return Juice
