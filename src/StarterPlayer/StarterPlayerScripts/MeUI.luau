--[[
	MeUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Parte 26 (v10): botão "QUESTS" no menu, com 3 abas:
	  • QUESTS: as 3 missões do dia (1 troca grátis) + bônus por completar as 3
	  • SKILLS: nível, pontos, árvore de habilidades (reset grátis 1x por dia) e a classe
	  • PROFILE: prestígio, recordes pessoais e conquistas
	A tela só PEDE; o servidor (Progress.luau) confere tudo e manda a lista nova ("ProgressSync").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Progression = require(Shared:WaitForChild("Progression"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local MeUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

local TABS = { "QUESTS", "SKILLS", "PROFILE" }

local function hoursText(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return ("%dh %02dm"):format(hours, minutes)
	end
	return ("%dm"):format(math.max(minutes, 1))
end

function MeUI.Init(ctx)
	local frame, content = ctx.makePanel("Me", "QUESTS", C.Orange)
	content.Position = UDim2.fromOffset(16, 116)
	content.Size = UDim2.new(1, -32, 1, -128)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })

	local state: any = nil
	local receivedAt = os.clock()
	local tab = "QUESTS"
	local render: () -> ()

	-- abas
	local tabBar = create("Frame", {
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 0, 44),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = frame,
	}, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local tabButtons = {}
	for order, name in TABS do
		local btn = button({ LayoutOrder = order, Size = UDim2.new(1 / 3, -6, 1, 0), BackgroundColor3 = C.Row, ZIndex = 6, Parent = tabBar }, name, function()
			ctx.play("Click")
			tab = name
			render()
		end)
		tabButtons[name] = btn
	end

	-- botão no menu (com bolinha vermelha quando tem ponto de habilidade para gastar)
	local menuButton = ctx.menuButton(-1, "\u{1F4DC}", "QUESTS", C.Orange, function()
		ctx.openPanel("Me")
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

	local function clear()
		for _, child in content:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function row(order: number, height: number, color: Color3?): Frame
		return create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, height),
			BackgroundColor3 = color or C.Row,
			ZIndex = 5,
			Parent = content,
		}, { corner(12) })
	end

	local function text(parent: Instance, props: { [string]: any }): TextLabel
		props.ZIndex = props.ZIndex or 5
		props.Parent = parent
		props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		return label(props)
	end

	local function bar(parent: Instance, position: UDim2, size: UDim2, fraction: number, color: Color3, caption: string)
		local back = create("Frame", { Position = position, Size = size, BackgroundColor3 = C.Dark, ZIndex = 5, Parent = parent }, { corner(8) })
		create("Frame", { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color, ZIndex = 5, Parent = back }, { corner(8) })
		label({ Size = UDim2.fromScale(1, 1), Text = caption, StrokeThickness = 1.5, ZIndex = 6, Parent = back })
	end

	---------------------------------------------------------------------
	-- QUESTS
	---------------------------------------------------------------------
	local timerLabel: TextLabel? = nil
	local function renderQuests()
		local header = row(0, 40, C.Panel)
		timerLabel = text(header, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 1, -8),
			Text = "",
			TextColor3 = Color3.fromRGB(200, 215, 240),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		for index, mission in state.Missions do
			local box = row(index, 84, if mission.Done then Color3.fromRGB(45, 95, 60) else C.Row)
			text(box, {
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(0.7, -12, 0, 30),
				Text = Progression.MissionText(mission.Kind, mission.Need),
			})
			bar(box, UDim2.fromOffset(12, 42), UDim2.new(0.7, -12, 0, 26), mission.Have / math.max(mission.Need, 1), C.Gold, ("%d / %d"):format(mission.Have, mission.Need))
			if mission.Done then
				text(box, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.new(0.28, -12, 0, 40),
					Text = "DONE \u{2714}",
					TextColor3 = Color3.fromRGB(140, 255, 150),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			elseif not state.Swapped then
				button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.new(0.28, -12, 0, 48),
					BackgroundColor3 = C.Blue,
					ZIndex = 6,
					Parent = box,
				}, "SWAP (free)", function()
					ctx.play("Click")
					UI.confirm(ctx.gui, "SWAP QUEST?", "Get a different quest instead of this one?\nYou can swap 1 quest per day.", "SWAP", C.Blue, function()
						ctx.RequestEvent:FireServer("QuestSwap", index)
					end, ctx.scaleNow)
				end)
			else
				text(box, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.new(0.28, -12, 0, 40),
					Text = "Reward: 5 min of cash",
					TextColor3 = Color3.fromRGB(255, 230, 120),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end
		end
		-- caça aos ovos do dia (v13)
		local huntFound = 0
		for _, key in string.split(tostring(Players.LocalPlayer:GetAttribute("HuntFound") or ""), ",") do
			if key ~= "" then
				huntFound += 1
			end
		end
		local huntTotal = tonumber(workspace:GetAttribute("HuntCount")) or 10
		local hunt = row(9, 44, if huntFound >= huntTotal then Color3.fromRGB(45, 95, 60) else C.Panel)
		text(hunt, {
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -24, 1, -8),
			Text = ("EGG HUNT: %d/%d hidden eggs found in Meadow today (all 10 = FREE big egg!)"):format(huntFound, huntTotal),
			TextColor3 = Color3.fromRGB(255, 170, 210),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local bonus = row(10, 60, if state.Bonus then Color3.fromRGB(45, 95, 60) else C.Panel)
		text(bonus, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 1, -12),
			Text = if state.Bonus
				then "ALL 3 DONE! You got a FREE egg. Come back tomorrow for new quests!"
				else "Finish all 3: a FREE egg from your best world + 60 pass XP. Each quest: 5 minutes of your cash.",
			TextColor3 = C.Gold,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end

	---------------------------------------------------------------------
	-- SKILLS
	---------------------------------------------------------------------
	local function renderSkills()
		local top = row(0, 70, C.Panel)
		text(top, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.5, -12, 0, 30), Text = ("LEVEL %d"):format(state.Level), TextColor3 = C.Gold })
		text(top, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 4),
			Size = UDim2.new(0.5, -12, 0, 30),
			Text = ("Skill points: %d"):format(state.Points),
			TextColor3 = if state.Points > 0 then Color3.fromRGB(140, 255, 150) else C.White,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		bar(top, UDim2.fromOffset(12, 38), UDim2.new(1, -24, 0, 24), state.XPInto / math.max(state.XPNeed, 1), C.Purple, ("XP %d / %d  (play, hatch, steal...)"):format(state.XPInto, state.XPNeed))
		for order, name in Progression.SkillOrder do
			local info = Progression.Skills[name]
			local value = state.Skills[name] or 0
			local box = row(order, 72)
			text(box, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.62, -12, 0, 28), Text = ("%s  %s"):format(info.Name, string.rep("\u{25A0}", value) .. string.rep("\u{25A1}", info.Max - value)) })
			text(box, {
				Position = UDim2.fromOffset(12, 32),
				Size = UDim2.new(0.66, -12, 0, 34),
				Text = info.Desc,
				TextColor3 = Color3.fromRGB(200, 215, 240),
				TextWrapped = true,
				StrokeThickness = 1,
			})
			local can = value < info.Max and state.Points > 0
			button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.new(0.28, -12, 0, 46),
				BackgroundColor3 = if can then C.Green else C.Gray,
				ZIndex = 6,
				Parent = box,
			}, if value >= info.Max then "MAX" else "+1", function()
				if not can then
					ctx.toast(if value >= info.Max then info.Name .. " is MAX!" else "No skill points. Level up to get more!", "info")
					return
				end
				ctx.play("Click")
				ctx.RequestEvent:FireServer("SkillUp", name)
			end)
		end
		local reset = row(5, 54, C.Panel)
		button({
			Position = UDim2.fromOffset(8, 5),
			Size = UDim2.new(1, -16, 1, -10),
			BackgroundColor3 = if state.ResetReady then C.Blue else C.Gray,
			ZIndex = 6,
			Parent = reset,
		}, if state.ResetReady then "RESET SKILLS (free, 1 per day)" else "Free reset used today", function()
			if not state.ResetReady then
				ctx.toast("You can reset your skills for free again tomorrow.", "info")
				return
			end
			UI.confirm(ctx.gui, "RESET SKILLS?", "Get all your skill points back to spend again?\nFree once per day.", "RESET", C.Blue, function()
				ctx.RequestEvent:FireServer("SkillReset")
			end, ctx.scaleNow)
		end)
		-- classe
		local classTitle = row(6, 34, C.Panel)
		text(classTitle, {
			Position = UDim2.fromOffset(12, 2),
			Size = UDim2.new(1, -24, 1, -4),
			Text = if state.ClassWait > 0 then ("CLASS (change again in %s)"):format(Format.Time(state.ClassWait)) else "CLASS (free to change)",
			TextColor3 = C.Gold,
		})
		for order, name in Progression.ClassOrder do
			local info = Progression.Classes[name]
			local chosen = state.Class == name
			local box = row(6 + order, 64, if chosen then Color3.fromRGB(70, 60, 30) else C.Row)
			if chosen then
				UI.border(C.Gold, 3).Parent = box
			end
			text(box, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.62, -12, 0, 28), Text = info.Name, TextColor3 = info.Color })
			text(box, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(0.66, -12, 0, 26), Text = info.Desc, TextColor3 = Color3.fromRGB(200, 215, 240), StrokeThickness = 1 })
			button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.new(0.28, -12, 0, 46),
				BackgroundColor3 = if chosen then C.Gold else C.Blue,
				ZIndex = 6,
				Parent = box,
			}, if chosen then "YOURS" else "CHOOSE", function()
				if chosen then
					return
				end
				ctx.play("Click")
				ctx.RequestEvent:FireServer("SetClass", name)
			end)
		end
	end

	---------------------------------------------------------------------
	-- PROFILE
	---------------------------------------------------------------------
	local function renderProfile()
		local records = state.Records or {}
		local prestigeBox = row(0, 110, C.Panel)
		local need = tonumber(state.PrestigeNeed) or Progression.PrestigeRebirths
		local ready = (state.Rebirths or 0) >= need
		text(prestigeBox, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.62, -12, 0, 30),
			Text = if state.Prestige > 0 then ("\u{2B50} PRESTIGE %d  (x%g cash)"):format(state.Prestige, 1 + state.Prestige * Progression.PrestigeBonus) else "PRESTIGE",
			TextColor3 = C.Gold,
		})
		text(prestigeBox, {
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(0.66, -12, 0, 66),
			Text = ("Needs %d rebirths (you have %d).\n+100%% cash forever, an aura and a star!"):format(need, state.Rebirths or 0),
			TextColor3 = Color3.fromRGB(200, 215, 240),
			TextWrapped = true,
			StrokeThickness = 1,
		})
		button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0.28, -12, 0, 52),
			BackgroundColor3 = if ready then C.Purple else C.Gray,
			ZIndex = 6,
			Parent = prestigeBox,
		}, "PRESTIGE", function()
			if not ready then
				ctx.toast(("You need %d rebirths to Prestige."):format(need), "info")
				return
			end
			UI.confirm(
				ctx.gui,
				"PRESTIGE?",
				"Your cash and rebirths go back to 0.\nYou KEEP critters, worlds, slots, pets and styles.\nYou GET +100% cash forever, an aura and a star.",
				"PRESTIGE!",
				C.Purple,
				function()
					ctx.RequestEvent:FireServer("Prestige")
				end,
				ctx.scaleNow
			)
		end)

		local lines = {
			{ "Level", tostring(state.Level) },
			{ "Eggs hatched", Format.Short(records.Hatched or 0) },
			{ "Critters stolen", Format.Short(records.Steals or 0) },
			{ "Thieves BONKed", Format.Short(records.Defends or 0) },
			{ "Critters found", tostring(records.Collected or 0) },
			{ "Shiny critters", tostring(records.Shinies or 0) },
			{ "Hybrids made", tostring(records.Mixes or 0) },
			{ "Giant Eggs helped", tostring(records.GiantEggs or 0) },
			{ "Monsters defeated", tostring(records.Monsters or 0) },
			{ "Minigames played", tostring(records.Minigames or 0) },
			{ "Minigames won", tostring(records.MinigameWins or 0) },
			{ "Quest days", tostring(records.MissionDays or 0) },
			{ "Highest rebirth", tostring(records.PeakRebirths or 0) },
			{ "Best income", Format.Money(records.BestIncome or 0) .. "/s" },
			{ "Most cash", Format.Money(records.BestCash or 0) },
			{ "Total earned", Format.Money(records.TotalEarned or 0) },
			{ "Time played", hoursText(records.PlayTime or 0) },
		}
		local grid = create("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = content,
		}, {
			create("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 36), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for order, line in lines do
			local cell = create("Frame", { LayoutOrder = order, BackgroundColor3 = C.Row, ZIndex = 5, Parent = grid }, { corner(10) })
			text(cell, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.6, -10, 1, -8), Text = line[1], TextColor3 = Color3.fromRGB(200, 215, 240), StrokeThickness = 1 })
			text(cell, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 4),
				Size = UDim2.new(0.4, -10, 1, -8),
				Text = line[2],
				TextColor3 = C.Gold,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end

		local earned = {}
		for _, id in state.Achievements or {} do
			earned[id] = true
		end
		local count = 0
		for _ in earned do
			count += 1
		end
		local title = row(2, 34, C.Panel)
		text(title, {
			Position = UDim2.fromOffset(12, 2),
			Size = UDim2.new(1, -24, 1, -4),
			Text = ("ACHIEVEMENTS %d / %d"):format(count, #Progression.Achievements),
			TextColor3 = C.Gold,
		})
		local list = create("Frame", {
			LayoutOrder = 3,
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = content,
		}, {
			create("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 66), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for order, achievement in Progression.Achievements do
			local got = earned[achievement.Id] == true
			local cell = create("Frame", { LayoutOrder = order, BackgroundColor3 = if got then Color3.fromRGB(45, 95, 60) else C.Row, ZIndex = 5, Parent = list }, { corner(10) })
			text(cell, { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 26), Text = (if got then "\u{2714} " else "\u{1F512} ") .. achievement.Name, TextColor3 = if got then C.Gold else C.White })
			text(cell, {
				Position = UDim2.fromOffset(10, 30),
				Size = UDim2.new(1, -20, 0, 32),
				Text = achievement.Desc,
				TextColor3 = Color3.fromRGB(200, 215, 240),
				TextWrapped = true,
				StrokeThickness = 1,
			})
		end
	end

	render = function()
		for name, btn in tabButtons do
			btn.BackgroundColor3 = if name == tab then C.Orange else C.Row
		end
		dot.Visible = state ~= nil and (state.Points or 0) > 0
		if not frame.Visible or not state then
			return
		end
		clear()
		timerLabel = nil
		if tab == "QUESTS" then
			renderQuests()
		elseif tab == "SKILLS" then
			renderSkills()
		else
			renderProfile()
		end
	end

	ctx.RemotesFolder:WaitForChild("ProgressSync").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Missions) ~= "table" then
			return
		end
		payload.Skills = if type(payload.Skills) == "table" then payload.Skills else {}
		payload.Level = tonumber(payload.Level) or 1
		payload.Points = tonumber(payload.Points) or 0
		payload.XPInto = tonumber(payload.XPInto) or 0
		payload.XPNeed = tonumber(payload.XPNeed) or 1
		payload.Prestige = tonumber(payload.Prestige) or 0
		payload.ClassWait = tonumber(payload.ClassWait) or 0
		state = payload
		receivedAt = os.clock()
		render()
	end)

	-- relógio de verdade das missões (troca à meia-noite UTC, igual para todo mundo)
	task.spawn(function()
		while true do
			task.wait(1)
			if frame.Visible and state and timerLabel then
				local left = (tonumber(state.DayEndsIn) or 0) - (os.clock() - receivedAt)
				timerLabel.Text = "New quests in " .. hoursText(left)
				if left <= 0 then
					ctx.RequestEvent:FireServer("ProgressSync")
					receivedAt = os.clock() + 86400 -- não pede de novo até a resposta chegar
				end
			end
		end
	end)

	-- festas
	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "LevelUp" then
			ctx.play("Rare")
			ctx.bigText("LEVEL " .. tostring(data) .. "!", C.Purple)
			Juice.Confetti(ctx.gui, 60, { C.Purple, C.Gold, C.White })
		elseif kind == "Quest" then
			ctx.play("Coin")
		elseif kind == "QuestsAll" then
			ctx.play("Rare")
			ctx.bigText("ALL QUESTS DONE!", C.Gold)
			Juice.Confetti(ctx.gui, 90)
		elseif kind == "Achievement" then
			ctx.play("Rare")
			ctx.bigText("ACHIEVEMENT!", C.Gold)
			Juice.Confetti(ctx.gui, 50, { C.Gold, C.White })
		elseif kind == "SkillUp" then
			ctx.play("Buy")
		elseif kind == "Prestige" then
			ctx.play("Shiny")
			ctx.flash(C.Gold, 0.9)
			ctx.bigText("PRESTIGE " .. tostring(data) .. "!", C.Gold)
			Juice.Confetti(ctx.gui, 150, { C.Gold, C.Purple, C.White })
			Juice.Shake(1, 0.8)
		end
	end)

	ctx.panelOpened.Me = function()
		ctx.RequestEvent:FireServer("ProgressSync")
		render()
	end
	return frame
end

return MeUI
