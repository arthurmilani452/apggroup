--[[
	HUD (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	Tela fixa: nome e nível da cidade, dinheiro e renda, cofre, números da cidade, evento ativo,
	botões principais e os avisos do servidor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Scripts = script.Parent
local UI = require(Scripts.UI)
local State = require(Scripts.State)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local T = UI.Theme

local HUD = {}

-- Os outros módulos registram os botões principais aqui (Construir, Cidade, Viajar...)
local buttonBar: Frame
local gui: ScreenGui

function HUD.AddButton(text: string, order: number, color: Color3?, onClick: () -> ()): TextButton
	return UI.Button(buttonBar, text, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(150, 46),
		BackgroundColor3 = color or T.Card,
		TextSize = 17,
	}, onClick)
end

function HUD.Gui(): ScreenGui
	return gui
end

local function floatText(text: string, color: Color3)
	local label = UI.Label(gui, text, 26, {
		Font = UI.FontBlack,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(300, 34),
	})
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, 0, 0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.3, function()
		label:Destroy()
	end)
end

local function banner(title: string, subtitle: string)
	local frame = UI.Panel(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(520, 110),
		BackgroundColor3 = T.Bg,
	})
	UI.Stroke(frame, T.Accent, 2, 0)
	UI.Label(frame, title, 34, {
		Font = UI.FontBlack,
		TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 40),
	})
	UI.Label(frame, subtitle, 17, {
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(10, 62),
		Size = UDim2.new(1, -20, 0, 40),
	})
	task.delay(4, function()
		frame:Destroy()
	end)
end

function HUD.Init()
	gui = UI.Screen("HUD", 2)

	-- ===== Cidade (canto superior esquerdo) =====
	local cityCard = UI.Panel(gui, { Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(290, 106) })
	UI.Padding(cityCard, 12)
	local cityName = UI.Label(cityCard, "Carregando...", 20, { Font = UI.FontBlack, Size = UDim2.new(1, 0, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd })
	local tierLabel = UI.Label(cityCard, "", 14, { TextColor3 = T.Muted, Position = UDim2.fromOffset(0, 28) })
	local setTier = UI.Bar(cityCard, { Position = UDim2.fromOffset(0, 52) })
	local tierNext = UI.Label(cityCard, "", 13, { TextColor3 = T.Muted, Position = UDim2.fromOffset(0, 62) })

	-- ===== Dinheiro (topo, centro) =====
	local moneyCard = UI.Panel(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(300, 70) })
	local cash = UI.Label(moneyCard, "$0", 30, {
		Font = UI.FontBlack,
		TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 34),
	})
	local income = UI.Label(moneyCard, "", 14, {
		TextColor3 = T.Good,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 18),
	})
	local vaultCard = UI.Panel(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(300, 30) })
	local vaultText = UI.Label(vaultCard, "", 13, {
		Font = UI.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 2,
	})
	local setVault = UI.Bar(vaultCard, { Position = UDim2.new(0, 10, 1, -9), Size = UDim2.new(1, -20, 0, 5) })

	-- ===== Números (canto superior direito) =====
	local statsCard = UI.Panel(gui, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(230, 132) })
	UI.Padding(statsCard, 10)
	UI.List(statsCard, nil, 4)
	local rows: { [string]: TextLabel } = {}
	for i, key in { "Pop", "Happy", "Power", "Jobs" } do
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, Parent = statsCard })
		UI.Label(row, ({ Pop = "População", Happy = "Felicidade", Power = "Energia", Jobs = "Empregos" })[key], 14, {
			TextColor3 = T.Muted,
			Size = UDim2.fromScale(0.5, 1),
		})
		rows[key] = UI.Label(row, "-", 15, {
			Font = UI.FontBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.4, 0),
			Size = UDim2.fromScale(0.6, 1),
		})
	end
	local warning = UI.Label(gui, "", 14, {
		Font = UI.FontBold,
		TextColor3 = T.Bad,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 150),
		Size = UDim2.fromOffset(300, 40),
	})

	-- ===== Evento =====
	local eventCard = UI.Panel(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(420, 52),
		Visible = false,
	})
	UI.Stroke(eventCard, T.Event, 1.5, 0)
	local eventText = UI.Label(eventCard, "", 14, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 1, -8),
	})

	-- ===== Botões =====
	buttonBar = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		-- no celular o botão de pular fica no canto de baixo à direita: sobe a coluna
		Position = if UI.IsMobile() then UDim2.new(1, -14, 1, -170) else UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(150, 230),
		Parent = gui,
	})
	local layout = UI.List(buttonBar, nil, 8, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	-- ===== Atualização =====
	local function refresh(s: any)
		cityName.Text = s.CityName
		local tiers = Config.Tiers
		local tier = tiers[s.Tier] or tiers[1]
		local term = if s.Reelections > 0 then ("  ·  %dº mandato"):format(s.Reelections + 1) else ""
		tierLabel.Text = tier.Name .. term .. ("  ·  ★ %d"):format(s.Stars)
		local nextTier = tiers[s.Tier + 1]
		if nextTier then
			local span = nextTier.Population - tier.Population
			setTier((s.Population - tier.Population) / span, T.Teal)
			tierNext.Text = ("%s / %s hab. até %s"):format(Format.Int(s.Population, "."), Format.Int(nextTier.Population, "."), nextTier.Name)
		else
			setTier(1, T.Accent)
			tierNext.Text = "Nível máximo!"
		end

		cash.Text = Format.Money(s.Cash)
		local mult = if s.Multiplier > 1.001 then ("  (x%s)"):format(Format.Number(s.Multiplier, 2, ".", ",")) else ""
		income.Text = "+" .. Format.Money(s.Income) .. "/s" .. mult
		if s.AutoCollect then
			vaultText.Text = "Cofre: coleta automática"
			setVault(1, T.Good)
		else
			local fill = if s.VaultCapacity > 0 then s.Vault / s.VaultCapacity else 0
			vaultText.Text = ("Cofre da Prefeitura: %s / %s"):format(Format.Money(s.Vault), Format.Money(s.VaultCapacity))
			setVault(fill, if fill >= 1 then T.Bad elseif fill > 0.8 then T.Warn else T.Accent)
		end

		rows.Pop.Text = ("%s / %s"):format(Format.Short(s.Population), Format.Short(s.Housing))
		local happy = s.Happiness
		rows.Happy.Text = Format.Percent(happy)
		rows.Happy.TextColor3 = if happy >= Config.Happiness.Attractive
			then T.Good
			elseif happy >= Config.Happiness.Unhappy then T.Warn
			else T.Bad
		rows.Power.Text = ("%s / %s"):format(Format.Short(s.PowerSupply), Format.Short(s.PowerDemand))
		rows.Power.TextColor3 = if s.PowerSupply >= s.PowerDemand then T.Good else T.Bad
		rows.Jobs.Text = ("%s / %s"):format(Format.Short(math.min(s.Workers, s.Jobs)), Format.Short(s.Jobs))

		local warnings = {}
		if s.NoRoad > 0 then
			table.insert(warnings, ("⚠ %d prédio(s) sem rua ligada à Avenida"):format(s.NoRoad))
		end
		if s.PowerSupply < s.PowerDemand then
			table.insert(warnings, "⚠ Falta energia: construa usinas")
		end
		warning.Text = table.concat(warnings, "\n")
	end
	State.Changed.Event:Connect(refresh)
	if State.Stats then
		refresh(State.Stats)
	end

	task.spawn(function()
		while true do
			local id = ReplicatedStorage:GetAttribute("Event")
			if type(id) == "string" and id ~= "" then
				local left = (ReplicatedStorage:GetAttribute("EventEnds") or 0) - os.time()
				eventCard.Visible = true
				eventText.Text = ("<b>%s</b> (%s)\n%s"):format(
					ReplicatedStorage:GetAttribute("EventName") or "",
					Format.Time(left),
					ReplicatedStorage:GetAttribute("EventText") or ""
				)
			else
				eventCard.Visible = false
			end
			task.wait(1)
		end
	end)

	-- ===== Servidor -> tela =====
	Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, kind)
		UI.Toast(text, kind)
	end)
	Remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind, data)
		if kind == "placed" then
			UI.Sound("Place")
		elseif kind == "removed" then
			UI.Sound("Remove")
		elseif kind == "collect" then
			UI.Sound("Coin")
			floatText("+" .. Format.Money(tonumber(data) or 0), T.Accent)
		elseif kind == "upgrade" or kind == "star" then
			UI.Sound("Upgrade")
		elseif kind == "tier" then
			UI.Sound("Fanfare")
			local tier = Config.Tiers[tonumber(data) or 1]
			banner(string.upper(tier and tier.Name or ""), "Sua cidade cresceu! Prédios novos no menu Construir.")
		elseif kind == "reelected" then
			UI.Sound("Fanfare")
			banner("REELEITO!", ("Mandato %d: toda renda com bônus permanente."):format((tonumber(data) or 0) + 1))
		end
	end)
end

return HUD
