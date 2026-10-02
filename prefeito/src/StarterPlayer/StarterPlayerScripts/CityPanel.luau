--[[
	CityPanel (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	Janela "Cidade" (tecla C): números, necessidades dos moradores, expandir terreno, aumentar o
	cofre, nome da cidade, reeleição e loja.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Scripts = script.Parent
local UI = require(Scripts.UI)
local State = require(Scripts.State)
local HUD = require(Scripts.HUD)

local T = UI.Theme

local CityPanel = {}

local modal: UI.Modal
local section: { [string]: any } = {}
local nameA, nameB = 1, 1
local nameDirty = false

local NEED_TIPS = {
	comercio = "Padaria, Mercado, Shopping",
	saude = "Posto de Saúde, Hospital",
	seguranca = "Delegacia, Bombeiros",
	educacao = "Escola, Universidade",
}

local function header(text: string, order: number)
	UI.Label(modal.Body, text, 17, { Font = UI.FontBlack, TextColor3 = T.Accent, LayoutOrder = order })
end

local function card(order: number, height: number): Frame
	local frame = UI.new("Frame", {
		BackgroundColor3 = T.Card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, height),
		LayoutOrder = order,
		Parent = modal.Body,
	})
	UI.Corner(frame, 8)
	UI.Padding(frame, 10)
	return frame
end

local function build()
	modal = UI.Modal("Sua Cidade", 560, 600)
	UI.List(modal.Body, nil, 8)

	-- números
	header("Números", 1)
	local numbers = card(2, 150)
	section.Numbers = UI.Label(numbers, "", 15, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Top })

	-- necessidades
	header("O que os moradores querem", 3)
	local needs = card(4, 30 * #Config.Needs + 34)
	UI.List(needs, nil, 6)
	section.Needs = {}
	for i, need in Config.Needs do
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, Parent = needs })
		local label = UI.Label(row, need.Name, 14, { Size = UDim2.new(0.55, 0, 1, 0) })
		local set = UI.Bar(row, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.55, 0, 0.5, 0), Size = UDim2.new(0.45, 0, 0, 8) })
		section.Needs[need.Id] = { Label = label, Set = set, Need = need }
	end
	UI.Label(needs, "Cada casa precisa estar no alcance de um prédio que atende a necessidade.", 12, {
		TextColor3 = T.Muted,
		LayoutOrder = 99,
		Size = UDim2.new(1, 0, 0, 28),
	})

	-- melhorias
	header("Melhorias", 5)
	local upgrades = card(6, 104)
	section.ExpandText = UI.Label(upgrades, "", 14, { Size = UDim2.new(1, -170, 0, 40) })
	section.Expand = UI.Button(upgrades, "Expandir", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(160, 38),
		BackgroundColor3 = T.Teal:Lerp(T.Card, 0.5),
	}, function()
		State.Request("expand")
	end)
	section.VaultText = UI.Label(upgrades, "", 14, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, -170, 0, 40) })
	section.Vault = UI.Button(upgrades, "Cofre maior", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 46),
		Size = UDim2.fromOffset(160, 38),
		BackgroundColor3 = T.Accent:Lerp(T.Card, 0.5),
	}, function()
		State.Request("vault")
	end)

	-- nome
	header("Nome da cidade", 7)
	local nameCard = card(8, 58)
	local function cycler(x: number, getter: () -> number, setter: (number) -> (), list: { string }): TextLabel
		UI.Button(nameCard, "◀", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(30, 38) }, function()
			setter((getter() - 2) % #list + 1)
			nameDirty = true
			CityPanel.RefreshName()
		end)
		local label = UI.Label(nameCard, "", 15, {
			Font = UI.FontBold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(x + 32, 8),
			Size = UDim2.fromOffset(110, 22),
		})
		UI.Button(nameCard, "▶", { Position = UDim2.fromOffset(x + 144, 0), Size = UDim2.fromOffset(30, 38) }, function()
			setter(getter() % #list + 1)
			nameDirty = true
			CityPanel.RefreshName()
		end)
		return label
	end
	section.NameA = cycler(0, function()
		return nameA
	end, function(v)
		nameA = v
	end, Config.CityNameA)
	section.NameB = cycler(180, function()
		return nameB
	end, function(v)
		nameB = v
	end, Config.CityNameB)
	UI.Button(nameCard, "Salvar", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(110, 38),
	}, function()
		State.Request("rename", { A = nameA, B = nameB })
		nameDirty = false
	end)

	-- reeleição
	header("Reeleição", 9)
	local reelect = card(10, 96)
	section.ReelectText = UI.Label(reelect, "", 14, { Size = UDim2.new(1, -170, 1, 0), TextYAlignment = Enum.TextYAlignment.Top })
	local confirming = false
	section.Reelect = UI.Button(reelect, "Reeleição", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(160, 38),
		BackgroundColor3 = T.Event:Lerp(T.Card, 0.5),
	}, function()
		if not confirming then
			confirming = true
			section.Reelect.Text = "Confirmar?"
			task.delay(4, function()
				confirming = false
				section.Reelect.Text = "Reeleição"
			end)
			return
		end
		confirming = false
		section.Reelect.Text = "Reeleição"
		State.Request("reelect")
		modal.Close()
	end)

	-- loja
	header("Loja", 11)
	local shop = card(12, 96)
	UI.List(shop, Enum.FillDirection.Horizontal, 8)
	UI.Button(shop, "Renda x2\n(passe)", { LayoutOrder = 1, Size = UDim2.fromOffset(120, 70), TextSize = 14 }, function()
		State.Request("buyPass", "DoubleIncome")
	end)
	UI.Button(shop, "Cofre\nautomático", { LayoutOrder = 2, Size = UDim2.fromOffset(120, 70), TextSize = 14 }, function()
		State.Request("buyPass", "AutoCollect")
	end)
	for i, product in Config.DevProducts do
		UI.Button(shop, ("+%d min\nde renda"):format(product.Minutes), { LayoutOrder = 2 + i, Size = UDim2.fromOffset(120, 70), TextSize = 14 }, function()
			State.Request("buyCash", i)
		end)
	end
end

function CityPanel.RefreshName()
	section.NameA.Text = Config.CityNameA[nameA] or "?"
	section.NameB.Text = Config.CityNameB[nameB] or "?"
end

local function refresh(s: any)
	if not modal.IsOpen() then
		return
	end
	section.Numbers.Text = table.concat({
		("População: <b>%s</b> (meta %s, vagas %s)"):format(Format.Int(s.Population, "."), Format.Int(s.Target, "."), Format.Int(s.Housing, ".")),
		("Felicidade: <b>%s</b>   ·   Visitantes agora: <b>%d</b>"):format(Format.Percent(s.Happiness), s.Visitors),
		("Empregos: <b>%s</b> ocupados de %s"):format(Format.Int(math.min(s.Workers, s.Jobs), "."), Format.Int(s.Jobs, ".")),
		("Energia: <b>%s</b> produzida, %s usada"):format(Format.Int(s.PowerSupply, "."), Format.Int(s.PowerDemand, ".")),
		("Renda: <b>%s/s</b>   ·   bônus x%s"):format(Format.Money(s.Income), Format.Number(s.Multiplier, 2, ".", ",")),
		("Prédios sem rua: <b>%d</b>"):format(s.NoRoad),
	}, "\n")

	for id, row in section.Needs do
		local active = s.Tier >= row.Need.Tier
		local value = s.Coverage[id] or 0
		if active then
			row.Label.Text = ("%s <font color=\"#969EB2\">(%s)</font>"):format(row.Need.Name, NEED_TIPS[id] or "")
			row.Set(value, if value >= 0.8 then T.Good elseif value >= 0.4 then T.Warn else T.Bad)
		else
			row.Label.Text = ("%s <font color=\"#969EB2\">(a partir de %s)</font>"):format(row.Need.Name, Config.Tiers[row.Need.Tier].Name)
			row.Set(value, T.Line)
		end
	end

	local nextExpansion = Config.Expansions[s.Expansion + 1]
	if nextExpansion then
		section.ExpandText.Text = ("Terreno %dx%d → <b>%dx%d</b>"):format(Config.Expansions[s.Expansion].Size, Config.Expansions[s.Expansion].Size, nextExpansion.Size, nextExpansion.Size)
		section.Expand.Text = "Expandir " .. Format.Money(nextExpansion.Cost)
		section.Expand.Visible = true
	else
		section.ExpandText.Text = "Terreno no tamanho máximo."
		section.Expand.Visible = false
	end
	local levels = Config.Vault.Levels
	local nextVault = levels[s.VaultLevel + 1]
	if nextVault then
		section.VaultText.Text = ("Cofre guarda %d min de renda → <b>%d min</b>"):format(levels[s.VaultLevel].Minutes, nextVault.Minutes)
		section.Vault.Text = "Cofre " .. Format.Money(nextVault.Cost)
		section.Vault.Visible = true
	else
		section.VaultText.Text = "Cofre no tamanho máximo."
		section.Vault.Visible = false
	end

	if not nameDirty then
		nameA, nameB = s.NameA, s.NameB
		CityPanel.RefreshName()
	end

	local need = Config.Reelection.Population
	section.ReelectText.Text = ("Com %s moradores você pode se reeleger: a cidade recomeça do zero, mas toda renda ganha <b>+%d%%</b> para sempre. Agora: +%d%%."):format(
		Format.Int(need, "."),
		math.floor(Config.Reelection.BonusPerTerm * 100),
		math.floor(s.Reelections * Config.Reelection.BonusPerTerm * 100)
	)
	section.Reelect.Visible = s.Population >= need
end

function CityPanel.Init()
	build()
	HUD.AddButton("Cidade (C)", 2, nil, modal.Toggle)
	modal.OnOpen.Event:Connect(function()
		nameDirty = false
		if State.Stats then
			refresh(State.Stats)
		end
	end)
	State.Changed.Event:Connect(refresh)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.C then
			modal.Toggle()
		end
	end)
end

return CityPanel
