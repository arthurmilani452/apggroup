--[[
	ExploreUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Parte 22 (v13): o que a exploração mostra na tela.
	  • faixa da ILHA SECRETA (quando está aberta: tempo que sobra e onde fica o portal)
	  • ovos da caça que VOCÊ já achou somem só na sua tela
	  • minigame de PESCA: a setinha anda; toque quando ela estiver no verde (3 vezes)
	  • botão RIDE (esquerda): Skateboard, Go-Kart e Critter Ride (destravam pelo nível)
	A tela só pede; o servidor (Explore.luau / Mounts.luau) confere tudo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local ExploreUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

function ExploreUI.Init(ctx)
	local player = Players.LocalPlayer

	---------------------------------------------------------------------
	-- Faixa da ilha secreta (fica na pilha de faixas do EventsUI)
	---------------------------------------------------------------------
	-- v21: na coluna da esquerda (sem scaleNow: a coluna já tem a escala)
	local stack = ctx.leftStack or ctx.gui
	local W = ctx.stackWidth or 300
	local islandBar = create("Frame", {
		Name = "IslandBar",
		LayoutOrder = 50,
		Size = UDim2.fromOffset(W, 30),
		BackgroundColor3 = Color3.fromRGB(30, 140, 120),
		Visible = false,
		ZIndex = 30,
		Parent = stack,
	}, { corner(10), UI.border(C.White, 2) })
	local islandText = label({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = islandBar })

	---------------------------------------------------------------------
	-- Caça aos ovos: esconde os que você já achou (só na sua tela)
	---------------------------------------------------------------------
	local function refreshHunt()
		local folder = workspace:FindFirstChild("HuntEggs")
		if not folder then
			return
		end
		local found = {}
		for _, key in string.split(tostring(player:GetAttribute("HuntFound") or ""), ",") do
			if key ~= "" then
				found[key] = true
			end
		end
		for _, egg in folder:GetChildren() do
			if egg:IsA("BasePart") then
				local done = found[tostring(egg:GetAttribute("HuntIndex"))] == true
				egg.LocalTransparencyModifier = if done then 1 else 0
				for _, child in egg:GetChildren() do
					if child:IsA("ProximityPrompt") then
						child.Enabled = not done
					elseif child:IsA("Sparkles") then
						child.Enabled = not done
					end
				end
			end
		end
	end
	player:GetAttributeChangedSignal("HuntFound"):Connect(refreshHunt)
	task.spawn(function()
		local folder = workspace:WaitForChild("HuntEggs", 60)
		if folder then
			folder.ChildAdded:Connect(function()
				task.defer(refreshHunt)
			end)
			refreshHunt()
		end
	end)

	---------------------------------------------------------------------
	-- Pesca
	---------------------------------------------------------------------
	local fishing = create("Frame", {
		Name = "FishingPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(420, 190),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = ctx.gui,
	}, { corner(18), UI.border(C.Blue, 4) })
	ctx.scaleNow(fishing)
	local fishTitle = label({ Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), Text = "TAP when the hook is in the GREEN!", TextColor3 = C.Gold, ZIndex = 21, Parent = fishing })
	local track = create("Frame", { Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 34), BackgroundColor3 = C.Dark, ZIndex = 21, Parent = fishing }, { corner(10) })
	local zone = create("Frame", { Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = C.Green, ZIndex = 22, Parent = track }, { corner(10) })
	local hook = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 8, 1, 10), BackgroundColor3 = C.White, ZIndex = 23, Parent = track }, { corner(4) })
	local fishScore = label({ Position = UDim2.fromOffset(10, 90), Size = UDim2.new(1, -20, 0, 24), Text = "", ZIndex = 21, Parent = fishing })
	local cast: any = nil
	local function finishCast()
		if not cast then
			return
		end
		local done = cast
		cast = nil
		fishing.Visible = false
		ctx.RequestEvent:FireServer("FishCatch", { Token = done.Token, Score = done.Hits })
	end
	local function newZone()
		if cast then
			cast.ZoneStart = 0.1 + math.random() * 0.65
			cast.Speed = 0.7 + math.random() * 0.5 + cast.Round * 0.15
			zone.Position = UDim2.fromScale(cast.ZoneStart, 0)
		end
	end
	local function tap()
		if not cast or os.clock() - cast.LastTap < 0.25 then
			return
		end
		cast.LastTap = os.clock()
		local x = cast.X
		if x >= cast.ZoneStart and x <= cast.ZoneStart + 0.2 then
			cast.Hits += 1
			ctx.play("Coin")
		else
			ctx.play("Error")
		end
		cast.Round += 1
		fishScore.Text = ("Catches: %d / 3"):format(cast.Hits)
		if cast.Round >= 3 then
			task.delay(0.3, finishCast)
		else
			newZone()
		end
	end
	button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0.6, 0, 0, 56),
		BackgroundColor3 = C.Blue,
		ZIndex = 22,
		Parent = fishing,
	}, "TAP!", tap)
	UserInputService.InputBegan:Connect(function(input, processed)
		if cast and not processed and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
			tap()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not cast then
			return
		end
		cast.T += dt * cast.Speed
		cast.X = (math.sin(cast.T * math.pi) + 1) / 2
		hook.Position = UDim2.fromScale(cast.X, 0.5)
		if os.clock() - cast.Started > 15 then
			finishCast() -- demorou demais: manda o que tem
		end
	end)

	---------------------------------------------------------------------
	-- Montarias
	---------------------------------------------------------------------
	-- v21: o botão RIDE fica na coluna da esquerda; a lista de montarias abre à direita dele
	local rideButton = button({
		Name = "RideButton",
		LayoutOrder = 20,
		Size = UDim2.fromOffset(74, 38),
		BackgroundColor3 = C.Orange,
		ZIndex = 32,
		Parent = stack,
	}, "\u{1F6F9} RIDE", function() end)
	local picker = create("Frame", {
		Name = "RidePicker",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(1, 8, 0, 0),
		Size = UDim2.fromOffset(4 * 114, 38),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 32,
		Parent = rideButton,
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local options = {}
	for order, mount in Config.Mounts do
		local btn, text = button({ LayoutOrder = order, Size = UDim2.fromOffset(108, 38), BackgroundColor3 = C.Blue, ZIndex = 33, Parent = picker }, mount.Name, function()
			ctx.play("Click")
			picker.Visible = false
			ctx.RequestEvent:FireServer("Ride", mount.Id)
		end)
		options[mount.Id] = { Button = btn, Text = text, Mount = mount }
	end
	button({ LayoutOrder = 10, Size = UDim2.fromOffset(108, 38), BackgroundColor3 = C.Gray, ZIndex = 33, Parent = picker }, "WALK", function()
		ctx.play("Click")
		picker.Visible = false
		ctx.RequestEvent:FireServer("Ride", "off")
	end)
	rideButton.Activated:Connect(function()
		ctx.play("Click")
		picker.Visible = not picker.Visible
		local level = tonumber(player:GetAttribute("Level")) or 1
		for _, entry in options do
			local open = level >= entry.Mount.Level
			entry.Button.BackgroundColor3 = if open then C.Blue else C.Gray
			entry.Text.Text = if open then ("%s +%d%%"):format(entry.Mount.Name, math.floor((entry.Mount.Speed - 1) * 100 + 0.5)) else ("%s (Lv %d)"):format(entry.Mount.Name, entry.Mount.Level)
		end
	end)

	---------------------------------------------------------------------
	local function refreshIsland()
		local t = workspace:GetServerTimeNow()
		local open = workspace:GetAttribute("IslandOpen") == true
		islandBar.Visible = open and not player:GetAttribute("InMinigame")
		if open then
			local left = math.max(0, (tonumber(workspace:GetAttribute("IslandUntil")) or t) - t)
			islandText.Text = ("SECRET ISLAND OPEN! %s left - portal next to the Giant Egg"):format(Format.Time(left))
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			refreshIsland()
		end
	end)

	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "FishStart" and type(data) == "table" then
			cast = { Token = data.Token, Hits = 0, Round = 0, T = math.random() * 2, X = 0, Speed = 1, ZoneStart = 0.4, LastTap = 0, Started = os.clock() }
			newZone()
			fishScore.Text = "Catches: 0 / 3"
			fishTitle.Text = "TAP when the hook is in the GREEN!"
			fishing.Visible = true
			ctx.play("Click")
		elseif kind == "FishCaught" then
			ctx.play("Rare")
			Juice.Confetti(ctx.gui, 20 + (tonumber(data) or 1) * 15, { C.Blue, C.White, C.Gold })
		elseif kind == "Chest" then
			ctx.play("Rare")
			Juice.Confetti(ctx.gui, 60, { C.Gold, C.White })
			if typeof(data) == "Vector3" then
				ctx.floatingText(data + Vector3.new(0, 4, 0), "TREASURE!", C.Gold)
			end
		elseif kind == "HuntFound" and type(data) == "table" then
			ctx.play("Coin")
			ctx.bigText(("HUNT EGG %d/%d"):format(tonumber(data.Count) or 0, tonumber(workspace:GetAttribute("HuntCount")) or 10), Color3.fromRGB(255, 150, 200))
		elseif kind == "Dig" and typeof(data) == "Vector3" then
			ctx.play("Bonk")
			ctx.floatingText(data + Vector3.new(0, 2, 0), "DIG!", Color3.fromRGB(220, 190, 130))
		elseif kind == "IslandOpen" then
			ctx.play("Rare")
			ctx.bigText("SECRET ISLAND!", Color3.fromRGB(90, 255, 210))
		end
	end)
end

return ExploreUI
