--[[
	EventsUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Parte 25 (v11): o que os eventos ao vivo mostram na tela.
	  • faixa da comunidade (meta de ovos de todos os servidores) + festa do calendário
	  • votação (aparece só enquanto está aberta): 3 botões com os votos ao vivo
	  • invasão de monstros: quantos faltam e o tempo que sobra
	  • janela do MERCADOR (abre na barraca): ofertas da hora, preços claros e relógio de verdade
	Tudo vem dos atributos do Workspace (o servidor manda).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Critters = require(Shared:WaitForChild("Critters"))
local Format = require(Shared:WaitForChild("Format"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local EventsUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function EventsUI.Init(ctx)
	local player = Players.LocalPlayer

	---------------------------------------------------------------------
	-- Faixa da comunidade e da festa (embaixo da contagem dos eventos)
	---------------------------------------------------------------------
	-- v21: tudo na coluna da esquerda (ctx.leftStack), sem scaleNow (a coluna já tem a escala)
	local stack = ctx.leftStack or ctx.gui
	local W = ctx.stackWidth or 300
	local strip = create("Frame", {
		Name = "CommunityStrip",
		LayoutOrder = 10,
		Size = UDim2.fromOffset(W, 26),
		BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.3,
		ZIndex = 30,
		Parent = stack,
	}, { corner(9) })
	local stripFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(70, 150, 90), BackgroundTransparency = 0.3, ZIndex = 30, Parent = strip }, { corner(9) })
	local stripText = label({ Size = UDim2.new(1, -12, 1, -4), Position = UDim2.fromOffset(6, 2), Text = "", StrokeThickness = 1.5, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = strip })

	-- Votação
	local vote = create("Frame", {
		Name = "VoteBar",
		LayoutOrder = 40,
		Size = UDim2.fromOffset(W, 60),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 30,
		Parent = stack,
	}, { corner(12), UI.border(C.Gold, 2) })
	local voteTitle = label({ Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 20), Text = "VOTE THE NEXT EVENT!", TextColor3 = C.Gold, ZIndex = 31, Parent = vote })
	local voteButtons: { any } = {}
	for i = 1, 3 do
		local btn, text = button({
			Position = UDim2.new((i - 1) / 3, 4, 0, 24),
			Size = UDim2.new(1 / 3, -8, 0, 32),
			BackgroundColor3 = C.Blue,
			ZIndex = 31,
			Parent = vote,
		}, "", function()
			ctx.play("Click")
			ctx.RequestEvent:FireServer("Vote", i)
		end)
		voteButtons[i] = { Button = btn, Text = text }
	end

	-- Invasão
	local invasion = create("Frame", {
		Name = "InvasionBar",
		LayoutOrder = 45,
		Size = UDim2.fromOffset(W, 30),
		BackgroundColor3 = Color3.fromRGB(120, 40, 150),
		Visible = false,
		ZIndex = 30,
		Parent = stack,
	}, { corner(10), UI.border(C.White, 2) })
	local invasionText = label({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = invasion })

	local function refreshTop()
		local t = serverNow()
		-- comunidade
		local count = tonumber(workspace:GetAttribute("GlobalCount")) or 0
		local tier = tonumber(workspace:GetAttribute("GlobalTier")) or 0
		local goal = Config.GlobalGoals[tier + 1]
		local holidayId = workspace:GetAttribute("Holiday")
		local holiday = if typeof(holidayId) == "string" then Config.HolidayById[holidayId] else nil
		if goal then
			stripFill.Size = UDim2.fromScale(math.clamp(count / goal.Goal, 0, 1), 1)
			stripText.Text = ("Community: %s/%s eggs \u{2192} %s"):format(Format.Short(count), Format.Short(goal.Goal), goal.Name)
		else
			stripFill.Size = UDim2.fromScale(1, 1)
			stripText.Text = "Community: all goals reached!"
		end
		if holiday then
			stripText.Text = string.upper(holiday.Name) .. "! " .. stripText.Text
			stripFill.BackgroundColor3 = holiday.Color
		end
		-- votação
		local options = workspace:GetAttribute("VoteOptions")
		local voteUntil = workspace:GetAttribute("VoteUntil")
		vote.Visible = typeof(options) == "string" and typeof(voteUntil) == "number" and voteUntil > t
		if vote.Visible then
			local names = string.split(options, ",")
			local counts = string.split(tostring(workspace:GetAttribute("VoteCounts") or ""), ",")
			voteTitle.Text = ("VOTE THE NEXT EVENT!  %ds"):format(math.max(0, math.ceil(voteUntil - t)))
			for i, entry in voteButtons do
				local name = names[i]
				entry.Button.Visible = name ~= nil
				if name then
					entry.Text.Text = ("%s (%s)"):format(Config.VoteNames[name] or name, counts[i] or "0")
				end
			end
		end
		-- invasão
		local invasionUntil = workspace:GetAttribute("InvasionUntil")
		invasion.Visible = typeof(invasionUntil) == "number" and invasionUntil > t
		-- (v21: a coluna da esquerda empilha as faixas sozinha, pelo LayoutOrder)
		if invasion.Visible then
			local folder = workspace:FindFirstChild("Monsters")
			local left = if folder then #folder:GetChildren() else 0
			invasionText.Text = ("MONSTER INVASION! %d Grumblobs left - BONK them! %s"):format(left, Format.Time(math.max(0, invasionUntil - t)))
		end
	end

	---------------------------------------------------------------------
	-- MERCADOR
	---------------------------------------------------------------------
	local frame, content = ctx.makePanel("Merchant", "TRAVELING MERCHANT", C.Gold)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })
	local status = label({ LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 40), Text = "", TextColor3 = C.Gold, TextWrapped = true, ZIndex = 5, Parent = content })
	local rows: { any } = {}
	local shownStock = ""

	local function offerText(offer): (string, string)
		if offer.Kind == "Egg" then
			local egg = Config.EggById[offer.Id]
			return (if egg then egg.Name else "Egg") .. " (25% OFF)", Format.Money(offer.Price)
		elseif offer.Kind == "Critter" then
			local def = Critters.ById[offer.Id]
			return ("%s %s (%s)"):format(offer.Mutation or "", if def then def.Name else "Critter", if def then def.Rarity else ""), Format.Money(offer.Price)
		end
		local price = tonumber(player:GetAttribute("MerchantBoostPrice")) or 1000
		return ("2x Cash for %d minutes"):format(offer.Minutes or 10), Format.Money(price)
	end

	local function buildRows(stock: { any })
		for _, entry in rows do
			entry.Frame:Destroy()
		end
		rows = {}
		for index, offer in stock do
			local box = create("Frame", { LayoutOrder = index, Size = UDim2.new(1, -12, 0, 64), BackgroundColor3 = C.Row, ZIndex = 5, Parent = content }, { corner(12) })
			local title = label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.62, -12, 0, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = box })
			local price = label({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(0.62, -12, 0, 24), Text = "", TextColor3 = Color3.fromRGB(255, 230, 120), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = box })
			local buy, buyText = button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0.34, -10, 0, 48),
				BackgroundColor3 = C.Green,
				ZIndex = 6,
				Parent = box,
			}, "BUY", function()
				local entry = rows[index]
				if not entry or not entry.Available then
					ctx.toast(if workspace:GetAttribute("MerchantHere") == true then "You already bought this! New offers next hour." else "The merchant is away right now.", "info")
					return
				end
				local name, cost = offerText(offer)
				UI.confirm(ctx.gui, "BUY?", ("Buy %s for %s?"):format(name, cost), "BUY", C.Green, function()
					ctx.RequestEvent:FireServer("MerchantBuy", index)
				end, ctx.scaleNow)
			end)
			rows[index] = { Frame = box, Title = title, Price = price, Buy = buy, BuyText = buyText, Offer = offer }
		end
	end

	local function refreshMerchant()
		local raw = workspace:GetAttribute("MerchantStock")
		if typeof(raw) == "string" and raw ~= shownStock then
			shownStock = raw
			local ok, stock = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(stock) == "table" then
				buildRows(stock)
			end
		end
		local here = workspace:GetAttribute("MerchantHere") == true
		local t = serverNow()
		if here then
			local leaves = tonumber(workspace:GetAttribute("MerchantLeaves")) or t
			status.Text = ("The merchant is here for %s more! New offers every hour."):format(Format.Time(math.max(0, leaves - t)))
		else
			local arrives = tonumber(workspace:GetAttribute("MerchantArrives")) or t
			status.Text = ("The merchant is traveling. Back in %s (at the start of every hour, for 15 min)."):format(Format.Time(math.max(0, arrives - t)))
		end
		local bought = {}
		for _, key in string.split(tostring(player:GetAttribute("MerchantBought") or ""), ",") do
			if tonumber(key) then
				bought[tonumber(key)] = true
			end
		end
		for index, entry in rows do
			local name, cost = offerText(entry.Offer)
			entry.Title.Text = name
			entry.Price.Text = cost
			local done = bought[index] == true
			entry.BuyText.Text = if done then "BOUGHT" elseif here then "BUY" else "AWAY"
			entry.Buy.BackgroundColor3 = if done or not here then C.Gray else C.Green
			entry.Available = here and not done
		end
	end

	ctx.panelOpened.Merchant = refreshMerchant

	-- 2x por segundo
	task.spawn(function()
		while true do
			task.wait(0.5)
			refreshTop()
			if frame.Visible then
				refreshMerchant()
			end
		end
	end)

	ctx.EffectEvent.OnClientEvent:Connect(function(kind)
		if kind == "Invasion" then
			ctx.play("Alarm")
			ctx.bigText("MONSTER INVASION!", Color3.fromRGB(200, 120, 255))
			Juice.Shake(0.6, 0.5)
		elseif kind == "InvasionWon" then
			ctx.play("Rare")
			ctx.bigText("MONSTERS DEFEATED!", C.Gold)
			Juice.Confetti(ctx.gui, 80)
		elseif kind == "GoalReached" then
			ctx.play("Shiny")
			ctx.bigText("COMMUNITY GOAL!", C.Gold)
			Juice.Confetti(ctx.gui, 120, { C.Gold, C.Green, C.White })
		end
	end)
	return frame
end

return EventsUI
