--[[
	Travel (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	Janela "Viajar" (tecla V): as cidades do servidor, com prefeito, população, felicidade e estrelas.
	Visitar teleporta até a Prefeitura da cidade; Recomendar dá uma estrela (1 por cidade por dia)
	e dinheiro para os dois. Visitantes na sua cidade aumentam a sua renda.
	Também cria o botão "Minha cidade" (tecla H).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage:WaitForChild("Shared").Format)

local Scripts = script.Parent
local UI = require(Scripts.UI)
local State = require(Scripts.State)
local HUD = require(Scripts.HUD)

local player = Players.LocalPlayer
local T = UI.Theme

local Travel = {}

local modal: UI.Modal

local function refresh()
	if not modal.IsOpen() then
		return
	end
	for _, child in modal.Body:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local lots = workspace:FindFirstChild("Lots")
	if not lots then
		return
	end
	local entries = {}
	for _, lot in lots:GetChildren() do
		local owner = lot:GetAttribute("Owner")
		if type(owner) == "number" and owner ~= 0 then
			table.insert(entries, lot)
		end
	end
	table.sort(entries, function(a, b)
		return (a:GetAttribute("Population") or 0) > (b:GetAttribute("Population") or 0)
	end)
	for i, lot in entries do
		local index = lot:GetAttribute("Index")
		local mine = lot:GetAttribute("Owner") == player.UserId
		local row = UI.new("Frame", {
			BackgroundColor3 = if mine then T.CardHover else T.Card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -8, 0, 70),
			LayoutOrder = i,
			Parent = modal.Body,
		})
		UI.Corner(row, 8)
		UI.Padding(row, 10)
		UI.Label(row, ("%d. %s%s"):format(i, lot:GetAttribute("CityName") or "?", if mine then "  (sua)" else ""), 16, {
			Font = UI.FontBold,
			Size = UDim2.new(1, -230, 0, 22),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		UI.Label(row, ("Prefeito %s  ·  %s hab.  ·  %d%% feliz  ·  ★ %d"):format(
			lot:GetAttribute("OwnerName") or "?",
			Format.Short(lot:GetAttribute("Population") or 0),
			lot:GetAttribute("Happiness") or 0,
			lot:GetAttribute("Stars") or 0
		), 13, {
			TextColor3 = T.Muted,
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, -230, 0, 20),
		})
		if not mine then
			UI.Button(row, "Visitar", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -116, 0.5, 0),
				Size = UDim2.fromOffset(104, 40),
			}, function()
				State.Request("visit", { Lot = index })
				modal.Close()
			end)
			UI.Button(row, "★ Recomendar", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(110, 40),
				TextSize = 14,
				BackgroundColor3 = T.Accent:Lerp(T.Card, 0.55),
			}, function()
				State.Request("recommend", { Lot = index })
			end)
		end
	end
	if #entries <= 1 then
		UI.Label(UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 99, Parent = modal.Body }),
			"Nenhuma outra cidade neste servidor ainda. Chame os amigos: cidades vizinhas trocam moradores e estrelas!", 14, {
				TextColor3 = T.Muted,
				Size = UDim2.fromScale(1, 1),
			})
	end
end

function Travel.Init()
	modal = UI.Modal("Cidades do servidor", 620, 520)
	UI.List(modal.Body, nil, 8)
	modal.OnOpen.Event:Connect(refresh)
	HUD.AddButton("Viajar (V)", 3, nil, modal.Toggle)
	HUD.AddButton("Minha cidade (H)", 4, nil, function()
		State.Request("home")
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			refresh()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V then
			modal.Toggle()
		elseif input.KeyCode == Enum.KeyCode.H then
			State.Request("home")
		end
	end)
end

return Travel
