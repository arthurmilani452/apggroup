--[[
	PassUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Tela "PASS": temporada atual, nível, barra de XP, os 30 níveis (trilha grátis e paga),
	níveis bônus e o placar da temporada. Recompensas chegam sozinhas ao subir de nível.
	O preço do passe aparece em Robux (lido do Roblox), sem pressão: o tempo que falta é o de verdade.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local PassUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

local function themeById(id: string?)
	for _, theme in Seasons.Themes do
		if theme.Id == id then
			return theme
		end
	end
	return Seasons.Themes[1]
end

local function timeLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	if days > 0 then
		return ("%dd %dh"):format(days, hours)
	end
	return ("%dh %dm"):format(hours, (seconds % 3600) // 60)
end

function PassUI.Init(ctx)
	local player = Players.LocalPlayer
	local frame, content = ctx.makePanel("Pass", "SEASON PASS", C.Gold)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })

	local state: any = nil
	local priceText = "SET ID"
	local productId = Config.DevProducts.SeasonPass or 0
	if productId > 0 then
		priceText = "GET PASS"
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				priceText = "R$ " .. info.PriceInRobux
			end
		end)
	end

	local xpFill: Frame? = nil
	local xpText: TextLabel? = nil
	local levelText: TextLabel? = nil

	local function clear()
		for _, child in content:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		xpFill, xpText, levelText = nil, nil, nil
	end

	local function refreshXP()
		if not state or not xpFill or not xpText or not levelText then
			return
		end
		local xp = tonumber(player:GetAttribute("SeasonXP")) or state.XP
		local level, into, need = Seasons.LevelFromXP(xp)
		levelText.Text = if level > Seasons.Levels then ("LEVEL 30 + BONUS %d"):format(level - Seasons.Levels) else ("LEVEL %d / %d"):format(level, Seasons.Levels)
		if need > 0 then
			xpFill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
			xpText.Text = ("%d / %d XP"):format(into, need)
		else
			xpFill.Size = UDim2.fromScale(1, 1)
			xpText.Text = "MAX!"
		end
	end

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function render()
		clear()
		order = 0
		if not state then
			label({ LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 40), Text = "Loading...", ZIndex = 5, Parent = content })
			return
		end
		local theme = themeById(state.Theme)
		local serverNow = workspace:GetServerTimeNow()
		label({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 36),
			Text = ("SEASON %d: %s"):format(state.Id, string.upper(theme.Name)),
			TextColor3 = theme.Color,
			ZIndex = 5,
			Parent = content,
		})
		label({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 26),
			Text = "Season ends in " .. timeLeft(state.EndsAt - serverNow),
			TextColor3 = Color3.fromRGB(210, 210, 230),
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = content,
		})
		label({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 26),
			Text = "Rewards arrive by themselves when you level up!",
			TextColor3 = Color3.fromRGB(210, 210, 230),
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = content,
		})
		levelText = label({ LayoutOrder = nextOrder(), Size = UDim2.new(1, -12, 0, 30), Text = "", TextColor3 = C.Gold, ZIndex = 5, Parent = content })
		local bar = create("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -40, 0, 30),
			BackgroundColor3 = Color3.fromRGB(25, 25, 40),
			ZIndex = 5,
			Parent = content,
		}, { corner(10), UI.border(C.Dark, 2) })
		xpFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = theme.Color, ZIndex = 5, Parent = bar }, { corner(10) })
		xpText = label({ Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Text = "", ZIndex = 6, Parent = bar })
		refreshXP()

		-- passe
		local hasPass = state.Pass or player:GetAttribute("SeasonPass") == true
		local left = Seasons.Levels - state.PaidGranted
		local passRow = create("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -12, 0, 90), BackgroundColor3 = C.Row, ZIndex = 5, Parent = content }, { corner(14) })
		label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.62, -12, 0, 30),
			Text = if hasPass then "SEASON PASS ACTIVE!" elseif left <= 0 then "ALL PASS REWARDS UNLOCKED FOR FREE!" else ("SEASON PASS: +%d rewards left"):format(left),
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			Parent = passRow,
		})
		label({
			Position = UDim2.fromOffset(12, 40),
			Size = UDim2.new(0.62, -12, 0, 42),
			TextWrapped = true,
			Text = if hasPass then "Every PASS reward is yours. Bonus levels give extra cash." else "No pass? PASS rewards unlock for FREE at bonus levels 31-60!",
			TextColor3 = Color3.fromRGB(210, 210, 230),
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = passRow,
		})
		if not hasPass and left > 0 then
			button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0.34, 0, 0, 52),
				BackgroundColor3 = if productId > 0 then C.Gold else C.Gray,
				ZIndex = 5,
				Parent = passRow,
			}, priceText, function()
				ctx.play("Click")
				if productId > 0 then
					MarketplaceService:PromptProductPurchase(player, productId)
				else
					ctx.toast("Studio: put the Season Pass product ID in Config.DevProducts.SeasonPass", "warning")
				end
			end)
		end

		label({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 56),
			Text = ("XP: Hatch +%d | Steal +%d | BONK +%d | Fuse +%d\nRebirth +%d | New world +%d | Daily +%d | Playing +%d/min"):format(
				Seasons.XP.Hatch,
				Seasons.XP.Steal,
				Seasons.XP.Defend,
				Seasons.XP.Fuse,
				Seasons.XP.Rebirth,
				Seasons.XP.World,
				Seasons.XP.Daily,
				Seasons.XP.Minute
			),
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(200, 230, 255),
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = content,
		})

		-- os 30 níveis
		for level = 1, Seasons.Levels do
			local row = create("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -12, 0, 54), BackgroundColor3 = C.Row, ZIndex = 5, Parent = content }, { corner(12) })
			label({ Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(62, 38), Text = "Lv " .. level, TextColor3 = C.Gold, ZIndex = 5, Parent = row })
			local freeDone = state.Granted >= level
			local paidDone = state.PaidGranted >= level
			local free = create("Frame", {
				Position = UDim2.new(0, 76, 0, 5),
				Size = UDim2.new(0.5, -44, 1, -10),
				BackgroundColor3 = if freeDone then Color3.fromRGB(45, 120, 70) else Color3.fromRGB(45, 45, 70),
				ZIndex = 5,
				Parent = row,
			}, { corner(10) })
			label({
				Size = UDim2.new(1, -10, 1, -6),
				Position = UDim2.fromOffset(5, 3),
				Text = (if freeDone then "\u{2714} " else "") .. Seasons.RewardText(theme, Seasons.Reward(theme, level, "Free")),
				TextWrapped = true,
				StrokeThickness = 1,
				ZIndex = 5,
				Parent = free,
			})
			local paid = create("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 5),
				Size = UDim2.new(0.5, -44, 1, -10),
				BackgroundColor3 = if paidDone then Color3.fromRGB(150, 110, 30) else Color3.fromRGB(70, 55, 35),
				ZIndex = 5,
				Parent = row,
			}, { corner(10), UI.border(C.Gold, 2) })
			label({
				Size = UDim2.new(1, -10, 1, -6),
				Position = UDim2.fromOffset(5, 3),
				-- onde itens aleatórios pagos são proibidos (PolicyService), os ovos do passe viram dinheiro fixo
				Text = (if paidDone then "\u{2714} " else "PASS: ")
					.. Seasons.RewardText(theme, if player:GetAttribute("PolicyRandomRestricted") ~= false then Seasons.NoRandom(Seasons.Reward(theme, level, "Paid")) else Seasons.Reward(theme, level, "Paid")),
				TextWrapped = true,
				TextColor3 = if paidDone then C.White else Color3.fromRGB(255, 225, 150),
				StrokeThickness = 1,
				ZIndex = 5,
				Parent = paid,
			})
		end

		label({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 44),
			Text = ("BONUS LEVELS 31-60 (%d XP each): %d/%d done. %s"):format(
				Seasons.BonusCost,
				state.BonusGranted,
				Seasons.BonusLevels,
				if state.Pass then "Each gives 10 min of cash." else "Each unlocks the next PASS reward for free!"
			),
			TextWrapped = true,
			TextColor3 = C.Gold,
			StrokeThickness = 1.5,
			ZIndex = 5,
			Parent = content,
		})

		-- placar
		label({ LayoutOrder = nextOrder(), Size = UDim2.new(1, -12, 0, 32), Text = "SEASON TOP 10", TextColor3 = theme.Color, ZIndex = 5, Parent = content })
		if type(state.Top) ~= "table" or #state.Top == 0 then
			label({
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, -12, 0, 26),
				Text = "The leaderboard updates every minute (only in the published game).",
				TextColor3 = Color3.fromRGB(200, 200, 220),
				StrokeThickness = 1,
				ZIndex = 5,
				Parent = content,
			})
		else
			for rank, entry in state.Top do
				label({
					LayoutOrder = nextOrder(),
					Size = UDim2.new(1, -40, 0, 26),
					Text = ("%d. %s  -  %s XP"):format(rank, tostring(entry.Name), Format.Short(tonumber(entry.XP) or 0)),
					TextColor3 = if rank == 1 then C.Gold else C.White,
					TextXAlignment = Enum.TextXAlignment.Left,
					StrokeThickness = 1.5,
					ZIndex = 5,
					Parent = content,
				})
			end
		end
	end

	ctx.SeasonEvent.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		state = payload
		state.Granted = tonumber(state.Granted) or 0
		state.PaidGranted = tonumber(state.PaidGranted) or 0
		state.BonusGranted = tonumber(state.BonusGranted) or 0
		if frame.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("SeasonXP"):Connect(refreshXP)
	player:GetAttributeChangedSignal("SeasonPass"):Connect(function()
		if frame.Visible then
			ctx.RequestEvent:FireServer("SeasonSync")
		end
	end)

	-- subiu de nível: festa (e atualiza a tela se estiver aberta)
	ctx.EffectEvent.OnClientEvent:Connect(function(kind, level)
		if kind ~= "SeasonLevel" then
			return
		end
		ctx.play("Rare")
		Juice.Confetti(ctx.gui, 60)
		ctx.toast("SEASON LEVEL " .. tostring(level) .. "!", "rare")
		if frame.Visible then
			ctx.RequestEvent:FireServer("SeasonSync")
		end
	end)

	ctx.panelOpened.Pass = function()
		ctx.RequestEvent:FireServer("SeasonSync")
		render()
	end
end

return PassUI
