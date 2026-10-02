--[[
	Tutorial (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	Primeiros passos do prefeito novo. O passo atual fica salvo no servidor (Data.Tutorial).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scripts = script.Parent
local UI = require(Scripts.UI)
local State = require(Scripts.State)
local HUD = require(Scripts.HUD)

local T = UI.Theme

local Tutorial = {}

local function count(id: string): number
	local lot = State.Lot()
	if not lot then
		return 0
	end
	local total = 0
	for _, placed in State.Grid(lot).Buildings do
		if placed.Id == id then
			total += 1
		end
	end
	return total
end

local collected = false

local STEPS = {
	{
		Text = "Bem-vindo, prefeito! Aperte <b>Construir (B)</b> e faça uma <b>Rua</b> saindo da Avenida (clique e arraste).",
		Done = function()
			return count("rua") >= 1
		end,
	},
	{
		Text = "Agora construa <b>4 Casas</b> (aba Moradia) encostadas na rua ou na Avenida.",
		Done = function()
			return count("casa") >= 4
		end,
	},
	{
		Text = "Casa sem luz fica vazia. Construa um <b>Gerador a Diesel</b> (aba Energia) encostado numa rua e longe das casas: ele polui.",
		Done = function()
			return count("gerador") >= 1
		end,
	},
	{
		Text = "Os moradores querem comércio: construa uma <b>Padaria</b> perto das casas. Ela dá empregos e renda.",
		Done = function()
			return count("padaria") >= 1
		end,
	},
	{
		Text = "A renda cai no <b>Cofre da Prefeitura</b> (na frente do seu terreno). Vá até ele e aperte <b>Coletar</b>.",
		Done = function()
			return collected
		end,
	},
}

function Tutorial.Init()
	local gui = HUD.Gui()
	local card = UI.Panel(gui, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(290, 130),
		Visible = false,
	})
	UI.Stroke(card, T.Teal, 1.5, 0)
	UI.Padding(card, 12)
	local title = UI.Label(card, "", 13, { Font = UI.FontBold, TextColor3 = T.Teal })
	local text = UI.Label(card, "", 15, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 1, -22), TextYAlignment = Enum.TextYAlignment.Top })

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effect").OnClientEvent:Connect(function(kind)
		if kind == "collect" then
			collected = true
		end
	end)

	local step = -1
	task.spawn(function()
		while true do
			local stats = State.Stats
			if stats then
				if step < 0 then
					step = stats.Tutorial or 0
				end
				local current = STEPS[step + 1]
				if not current then
					card.Visible = false
					break
				end
				if current.Done() then
					step += 1
					State.Request("tutorial", { Step = step })
					UI.Sound("Upgrade")
					if not STEPS[step + 1] then
						UI.Toast("Tutorial concluído! Agora cresça até virar Cidade: mais casas, serviços e lazer. Abra o painel Cidade (C) para ver o que falta.", "ok")
					end
				else
					card.Visible = true
					title.Text = ("PRIMEIROS PASSOS  %d/%d"):format(step + 1, #STEPS)
					text.Text = current.Text
				end
			end
			task.wait(0.5)
		end
	end)
end

return Tutorial
