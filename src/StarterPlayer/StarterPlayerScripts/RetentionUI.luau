--[[
	RetentionUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	v23: o que faz o jogador ficar e voltar.
	  • PRESENTE DE TEMPO DE JOGO: chip na coluna da esquerda com a contagem ("Gift in 2:31");
	    quando fica pronto vira um botão verde pulsando ("CLAIM: Spotted Egg!"). Clicou = pede ao servidor.
	  • ROLETA DIÁRIA: botão SPIN no menu (bolinha vermelha quando tem giro). A janela mostra uma "esteira"
	    de prêmios que corre e para no prêmio que o SERVIDOR sorteou (Effect "Spin" { Index }).
	    Embaixo, a chance (%) de cada prêmio. 1 giro grátis por dia; nunca custa Robux.
	A tela só pede; quem decide e entrega é o servidor (Retention.luau).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local RetentionUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

local CARD = 118
local GAP = 10
local LAPS = 4 -- quantas voltas a esteira dá antes de parar

function RetentionUI.Init(ctx)
	local player = Players.LocalPlayer
	local stack = ctx.leftStack or ctx.gui
	local W = ctx.stackWidth or 260

	---------------------------------------------------------------------
	-- Presente de tempo de jogo (chip / botão na coluna da esquerda)
	---------------------------------------------------------------------
	local giftButton, giftText = button({
		Name = "GiftChip",
		LayoutOrder = 22,
		Size = UDim2.fromOffset(W, 32),
		BackgroundColor3 = C.Dark,
		ZIndex = 31,
		Parent = stack,
	}, "", function()
		if (tonumber(player:GetAttribute("GiftReadyAt")) or math.huge) <= math.floor(workspace:GetServerTimeNow()) then -- v28: relógio do servidor, não o do aparelho
			ctx.play("Click")
			ctx.RequestEvent:FireServer("GiftClaim")
		end
	end)
	giftText.TextXAlignment = Enum.TextXAlignment.Left
	local giftReady = false
	local pulseT = 0

	local function refreshGift(dt: number)
		local readyAt = tonumber(player:GetAttribute("GiftReadyAt"))
		local name = tostring(player:GetAttribute("GiftName") or "Gift")
		if not readyAt then
			giftButton.Visible = false
			return
		end
		giftButton.Visible = true
		local left = readyAt - math.floor(workspace:GetServerTimeNow())
		if left > 0 then
			if giftReady then
				giftReady = false
				giftButton.BackgroundColor3 = C.Dark
			end
			giftText.Text = ("\u{1F381} Gift in %s: %s"):format(Format.Time(left), name)
		else
			if not giftReady then
				giftReady = true
				giftButton.BackgroundColor3 = C.Green
				UI.popIn(giftButton)
				ctx.play("Coin")
			end
			pulseT += dt
			giftText.Text = ("\u{1F381} CLAIM GIFT: %s!"):format(name)
			giftButton.BackgroundColor3 = C.Green:Lerp(Color3.fromRGB(150, 255, 160), (math.sin(pulseT * 5) + 1) / 2)
		end
	end

	---------------------------------------------------------------------
	-- Roleta diária
	---------------------------------------------------------------------
	local frame, content = ctx.makePanel("Spin", "DAILY SPIN - 1 FREE SPIN A DAY!", C.Gold)
	local menuButton = ctx.menuButton(-3, "\u{1F3B0}", "SPIN", C.Gold, function()
		ctx.openPanel("Spin")
	end)
	local dot = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 8,
		Parent = menuButton,
	}, { corner(9), UI.border(C.White, 2) })

	local prizes = Config.DailySpin
	local total = 0
	for _, prize in prizes do
		total += prize.Weight
	end

	-- esteira de prêmios
	local track = create("Frame", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, CARD + 20),
		BackgroundColor3 = C.Dark,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = content,
	}, { corner(14) })
	local strip = create("Frame", {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.fromOffset((CARD + GAP) * #prizes * (LAPS + 2), CARD),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = track,
	})
	local cards = {}
	for copy = 0, LAPS + 1 do
		for i, prize in prizes do
			local index = copy * #prizes + i
			local card = create("Frame", {
				Position = UDim2.fromOffset((index - 1) * (CARD + GAP), 0),
				Size = UDim2.fromOffset(CARD, CARD),
				BackgroundColor3 = prize.Color or C.Row,
				ZIndex = 6,
				Parent = strip,
			}, { corner(14), UI.border(C.Dark, 3) })
			label({ Size = UDim2.new(1, -10, 0.5, 0), Position = UDim2.fromOffset(5, 6), Text = if prize.Egg then "\u{1F95A}" elseif prize.Boost then "\u{26A1}" else "\u{1F4B0}", StrokeThickness = 0, ZIndex = 7, Parent = card })
			label({ Size = UDim2.new(1, -10, 0.36, 0), Position = UDim2.new(0, 5, 0.58, 0), Text = prize.Name, TextWrapped = true, StrokeThickness = 1.5, ZIndex = 7, Parent = card })
			cards[index] = card
		end
	end
	-- ponteiro no meio
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = track,
	}, { corner(3) })

	local spinButton, spinText = button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CARD + 36),
		Size = UDim2.fromOffset(260, 56),
		BackgroundColor3 = C.Green,
		ZIndex = 6,
		Parent = content,
	}, "SPIN!", function()
		if player:GetAttribute("SpinReady") == true then
			ctx.play("Click")
			ctx.RequestEvent:FireServer("SpinDaily")
		else
			ctx.toast("You already spun today! Come back tomorrow.", "info")
		end
	end)
	local resultLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CARD + 98),
		Size = UDim2.new(1, -20, 0, 30),
		Text = "",
		TextColor3 = C.Gold,
		ZIndex = 6,
		Parent = content,
	})
	-- chances de cada prêmio (transparência total: é grátis, mas a criança sabe o que pode sair)
	local odds = create("Frame", {
		Position = UDim2.new(0, 0, 0, CARD + 134),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = content,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 26),
			CellPadding = UDim2.fromOffset(6, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, prize in prizes do
		local row = create("Frame", { LayoutOrder = i, BackgroundColor3 = C.Row, ZIndex = 5, Parent = odds }, { corner(8) })
		create("Frame", { Size = UDim2.new(0, 10, 1, -8), Position = UDim2.fromOffset(6, 4), BackgroundColor3 = prize.Color or C.White, BorderSizePixel = 0, ZIndex = 6, Parent = row }, { corner(4) })
		label({ Size = UDim2.new(1, -60, 1, -6), Position = UDim2.fromOffset(22, 3), Text = prize.Name, TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 1, ZIndex = 6, Parent = row })
		label({ AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(52, 20), Position = UDim2.new(1, -6, 0, 3), Text = string.format("%.1f%%", prize.Weight / total * 100), TextColor3 = C.Gold, StrokeThickness = 1, ZIndex = 6, Parent = row })
	end

	local spinning = false
	local function trackWidth(): number
		return if track.AbsoluteSize.X > 50 then track.AbsoluteSize.X else 570
	end
	local function resetStrip()
		strip.Position = UDim2.fromOffset(trackWidth() / 2 - CARD / 2, 10)
	end

	local function refreshSpin()
		local ready = player:GetAttribute("SpinReady") == true
		dot.Visible = ready
		if spinning then
			return
		end
		if ready then
			spinText.Text = "SPIN!"
			spinButton.BackgroundColor3 = C.Green
		else
			local secondsLeft = 86400 - (math.floor(workspace:GetServerTimeNow()) % 86400)
			spinText.Text = "Next spin in " .. Format.Time(secondsLeft)
			spinButton.BackgroundColor3 = C.Gray
		end
	end

	local function animateTo(index: number)
		spinning = true
		resultLabel.Text = ""
		resetStrip()
		local targetIndex = LAPS * #prizes + index -- a cópia da volta LAPS
		local landX = (targetIndex - 1) * (CARD + GAP)
		local jitter = math.random(-CARD * 0.3, CARD * 0.3)
		local finalX = trackWidth() / 2 - CARD / 2 - landX + jitter
		spinText.Text = "..."
		ctx.play("Click")
		local tween = TweenService:Create(strip, TweenInfo.new(2.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(finalX, 10) })
		tween:Play()
		-- "tec tec" enquanto passa pelos cards
		task.spawn(function()
			local lastCard = -1
			local started = os.clock()
			while os.clock() - started < 2.5 do
				local center = trackWidth() / 2
				local passing = math.floor((center - strip.Position.X.Offset) / (CARD + GAP))
				if passing ~= lastCard then
					lastCard = passing
					ctx.play("Click")
				end
				RunService.RenderStepped:Wait()
			end
		end)
		tween.Completed:Wait()
		local prize = prizes[index]
		local card = cards[targetIndex]
		if card then
			UI.pulse(card, 0.2)
		end
		resultLabel.Text = "YOU WON: " .. string.upper(prize.Name) .. "!"
		ctx.play("Rare")
		Juice.Confetti(ctx.gui, if index >= #prizes - 1 then 120 else 50, { prize.Color or C.Gold, C.White })
		if index >= #prizes - 1 then
			ctx.bigText("JACKPOT!", C.Gold)
			Juice.Shake(0.8, 0.6)
		end
		spinning = false
		refreshSpin()
	end

	ctx.panelOpened.Spin = function()
		resetStrip()
		refreshSpin()
	end
	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "Spin" and type(data) == "table" and type(data.Index) == "number" then
			if not frame.Visible then
				ctx.openPanel("Spin")
			end
			task.spawn(animateTo, data.Index)
		end
	end)
	player:GetAttributeChangedSignal("SpinReady"):Connect(refreshSpin)

	-- primeira vez que a roleta fica pronta na sessão: avisa
	local toldSpin = false
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		refreshGift(dt)
		if elapsed >= 1 then
			elapsed = 0
			refreshSpin()
			if not toldSpin and player:GetAttribute("SpinReady") == true and player:GetAttribute("Loaded") then
				toldSpin = true
				task.delay(20, function()
					if player:GetAttribute("SpinReady") == true then
						ctx.toast("\u{1F3B0} Your FREE daily spin is ready! Tap SPIN.", "rare")
					end
				end)
			end
		end
	end)
	refreshSpin()
	return frame
end

return RetentionUI
