--[[
	MinigameUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Parte 23 (v12): o que o hub de minigames mostra na tela.
	  • faixa "OBBY RACE starting in 23s!" com JOIN / LEAVE (fila automática, entrada grátis)
	  • durante a rodada: o tempo e as informações do jogo (checkpoint, placar do topo, moedas, quem foi achado)
	  • contagem 3, 2, 1, GO!
	  • janela da CRITTER BATTLE: os dois bichinhos, vida, e os botões ATTACK / DEFEND / SPECIAL
	Tudo vem do servidor (atributos do Workspace/jogador e o RemoteEvent "BattleSync").
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Critters = require(Shared:WaitForChild("Critters"))
local Format = require(Shared:WaitForChild("Format"))
local Builder = require(Shared:WaitForChild("CritterBuilder"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local MinigameUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

local ROLE_TEXT = {
	Cop = "You are a COP: BONK robbers to send them to jail!",
	Robber = "You are a ROBBER: grab the gold coins! The green button opens the jail.",
	Seeker = "You are the SEEKER: find and BONK the hiders!",
	Hider = "You are HIDING: don't let the seeker find you!",
}

function MinigameUI.Init(ctx)
	local player = Players.LocalPlayer

	---------------------------------------------------------------------
	-- Faixa (anúncio e rodada)
	---------------------------------------------------------------------
	-- v20: a faixa saiu do meio da tela; v21: ela é um item da coluna da esquerda (sem scaleNow)
	local bar = create("Frame", {
		Name = "MinigameBar",
		LayoutOrder = 60,
		Size = UDim2.fromOffset(ctx.stackWidth or 260, 46),
		BackgroundColor3 = Color3.fromRGB(40, 110, 170),
		Visible = false,
		ZIndex = 30, -- por cima da janela da batalha
		Parent = ctx.leftStack or ctx.gui,
	}, { corner(12), UI.border(C.White, 2) })
	local barText = label({ Position = UDim2.fromOffset(8, 3), Size = UDim2.new(0.7, -10, 1, -6), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = bar })
	local joinButton, joinText = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.new(0.3, -6, 0, 34),
		BackgroundColor3 = C.Green,
		ZIndex = 31,
		Parent = bar,
	}, "JOIN", function()
		ctx.play("Click")
		ctx.RequestEvent:FireServer("MinigameJoin")
	end)

	local lastCountdown = 0
	local function refresh()
		local t = workspace:GetServerTimeNow()
		local mgState = workspace:GetAttribute("MgState")
		local gameId = workspace:GetAttribute("MgGame")
		local info = if typeof(gameId) == "string" then Config.MinigameById[gameId] else nil
		local mine = player:GetAttribute("InMinigame")
		if mgState == "announce" and info then
			local left = math.max(0, math.ceil((tonumber(workspace:GetAttribute("MgStarts")) or t) - t))
			local queued = player:GetAttribute("MgQueued") == true
			bar.Visible = true
			bar.BackgroundColor3 = Color3.fromRGB(40, 110, 170)
			barText.Text = ("%s in %ds\n%s (%d joined)"):format(string.upper(info.Name), left, if queued then "You're in!" else "Free!", tonumber(workspace:GetAttribute("MgQueue")) or 0)
			joinButton.Visible = true
			joinText.Text = if queued then "LEAVE" else "JOIN"
			joinButton.BackgroundColor3 = if queued then C.Gray else C.Green
		elseif (mgState == "play" or mgState == "results") and mine and info then
			bar.Visible = true
			joinButton.Visible = false
			bar.BackgroundColor3 = Color3.fromRGB(120, 60, 170)
			local left = math.max(0, (tonumber(workspace:GetAttribute("MgEnds")) or t) - t)
			local extra = ""
			local raw = workspace:GetAttribute("MgInfo")
			local data: any = {}
			if typeof(raw) == "string" then
				pcall(function()
					data = HttpService:JSONDecode(raw)
				end)
			end
			if type(data) ~= "table" then
				data = {}
			end
			local role = player:GetAttribute("MgRole")
			if mine == "Race" then
				extra = ("Checkpoint %d/4"):format(tonumber(player:GetAttribute("MgProgress")) or 0)
			elseif mine == "King" and type(data.Top) == "table" then
				local parts = {}
				for i, entry in data.Top do
					if i <= 3 then
						table.insert(parts, ("%s %d"):format(tostring(entry.N), tonumber(entry.S) or 0))
					end
				end
				extra = "Top: " .. table.concat(parts, "  ")
			elseif mine == "Cops" then
				extra = ("%s  |  coins %d/%d"):format(if role == "Cop" then "COP" else "ROBBER", tonumber(data.Coins) or 0, tonumber(data.Goal) or 0)
			elseif mine == "Hide" then
				local seekerLeft = math.ceil((tonumber(workspace:GetAttribute("MgSeekerAt")) or 0) - t)
				extra = ("%s  |  found %d/%d%s"):format(
					if role == "Seeker" then "SEEKER" else "HIDER",
					tonumber(data.Found) or 0,
					tonumber(data.Hiders) or 0,
					if seekerLeft > 0 then ("  |  seeker out in %ds"):format(seekerLeft) else ""
				)
			elseif mine == "Battle" then
				extra = "Pick your move below!"
			end
			barText.Text = ("%s  %s\n%s"):format(string.upper(info.Name), if mgState == "results" then "DONE!" else Format.Time(left), extra)
		else
			bar.Visible = false
		end
		-- 3, 2, 1, GO!
		local countdownEnd = tonumber(workspace:GetAttribute("MgCountdown")) or 0
		if mine and countdownEnd > t - 1 then
			local secondsLeft = math.ceil(countdownEnd - t)
			if secondsLeft ~= lastCountdown then
				lastCountdown = secondsLeft
				if secondsLeft > 0 and secondsLeft <= 3 then
					ctx.play("Click")
					ctx.bigText(tostring(secondsLeft), C.White)
				elseif secondsLeft == 0 then
					ctx.play("Rare")
					ctx.bigText("GO!", C.Green)
				end
			end
		end
	end

	player:GetAttributeChangedSignal("MgRole"):Connect(function()
		local role = player:GetAttribute("MgRole")
		if typeof(role) == "string" and ROLE_TEXT[role] then
			ctx.toast(ROLE_TEXT[role], "rare")
		end
	end)

	---------------------------------------------------------------------
	-- CRITTER BATTLE
	---------------------------------------------------------------------
	local panel = create("Frame", {
		Name = "BattlePanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(600, 300),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = ctx.gui,
	}, { corner(18), UI.border(C.Purple, 4) })
	ctx.scaleNow(panel)
	local function side(x: number)
		local viewport = create("ViewportFrame", {
			Position = UDim2.new(x, 10, 0, 10),
			Size = UDim2.new(0.5, -20, 0, 120),
			BackgroundColor3 = Color3.fromRGB(30, 30, 50),
			Ambient = Color3.fromRGB(170, 170, 170),
			LightColor = C.White,
			LightDirection = Vector3.new(-0.4, -1, 0.6),
			ZIndex = 21,
			Parent = panel,
		}, { corner(12) })
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local name = label({ Position = UDim2.new(x, 10, 0, 132), Size = UDim2.new(0.5, -20, 0, 22), Text = "", ZIndex = 21, Parent = panel })
		local back = create("Frame", { Position = UDim2.new(x, 10, 0, 156), Size = UDim2.new(0.5, -20, 0, 22), BackgroundColor3 = C.Dark, ZIndex = 21, Parent = panel }, { corner(8) })
		local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Green, ZIndex = 21, Parent = back }, { corner(8) })
		local hp = label({ Size = UDim2.fromScale(1, 1), Text = "", StrokeThickness = 1.5, ZIndex = 22, Parent = back })
		return { Viewport = viewport, Camera = camera, Name = name, Fill = fill, HP = hp, Shown = "" }
	end
	local me = side(0)
	local foe = side(0.5)
	local log = label({ Position = UDim2.fromOffset(10, 182), Size = UDim2.new(1, -20, 0, 34), Text = "", TextWrapped = true, TextColor3 = Color3.fromRGB(230, 220, 255), ZIndex = 21, Parent = panel })
	local moveButtons = {}
	for i, move in { "Attack", "Defend", "Special" } do
		local color = if move == "Attack" then C.Red elseif move == "Defend" then C.Blue else C.Gold
		local btn, text = button({
			Position = UDim2.new((i - 1) / 3, 8, 1, -76),
			Size = UDim2.new(1 / 3, -16, 0, 64),
			BackgroundColor3 = color,
			ZIndex = 22,
			Parent = panel,
		}, string.upper(move), function()
			ctx.play("Click")
			ctx.RequestEvent:FireServer("BattleMove", move)
		end)
		moveButtons[move] = { Button = btn, Text = text, Color = color }
	end

	local function showCritter(slot, critterId: string, mutation: string?)
		local key = critterId .. ":" .. tostring(mutation)
		if slot.Shown == key then
			return
		end
		slot.Shown = key
		for _, child in slot.Viewport:GetChildren() do
			if child:IsA("Model") then
				child:Destroy()
			end
		end
		local def = Critters.ById[critterId]
		local model: Model
		if def then
			model = Builder.Build(def)
			if mutation then
				Builder.ApplyMutation(model, mutation)
			end
		else
			-- Grumblob (o monstro da invasão)
			model = Instance.new("Model")
			local body = Instance.new("Part")
			body.Shape = Enum.PartType.Ball
			body.Size = Vector3.new(4, 4, 4)
			body.Color = Color3.fromRGB(150, 70, 200)
			body.Parent = model
			model.PrimaryPart = body
		end
		local aura = model:FindFirstChild("Aura")
		if aura then
			aura:Destroy()
		end
		model:PivotTo(CFrame.identity)
		model.Parent = slot.Viewport
		local boxCFrame, boxSize = model:GetBoundingBox()
		local radius = boxSize.Magnitude / 2
		slot.Camera.CFrame = CFrame.lookAt(boxCFrame.Position + Vector3.new(radius * 0.8, radius * 0.5, -radius * 2.2), boxCFrame.Position)
	end

	local battle: any = nil
	local hideAt = 0
	ctx.RemotesFolder:WaitForChild("BattleSync").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Me) ~= "table" or type(payload.Foe) ~= "table" then
			return
		end
		local previous = battle
		battle = payload
		panel.Visible = true
		for pair, slot in { [payload.Me] = me, [payload.Foe] = foe } do
			showCritter(slot, tostring(pair.Critter or ""), pair.M)
			local def = Critters.ById[tostring(pair.Critter or "")]
			slot.Name.Text = ("%s (%s)"):format(tostring(pair.Name), if def then def.Name else "Grumblob")
			local fraction = math.clamp((tonumber(pair.HP) or 0) / math.max(tonumber(pair.Max) or 1, 1), 0, 1)
			slot.Fill.Size = UDim2.fromScale(fraction, 1)
			slot.Fill.BackgroundColor3 = if fraction > 0.5 then C.Green elseif fraction > 0.25 then C.Gold else C.Red
			slot.HP.Text = ("%d / %d"):format(tonumber(pair.HP) or 0, tonumber(pair.Max) or 0)
		end
		log.Text = tostring(payload.Log or "")
		if payload.Done then
			hideAt = os.clock() + 4
			ctx.bigText(if payload.Won then "YOU WIN!" else "GOOD FIGHT!", if payload.Won then C.Gold else C.White)
			if payload.Won then
				ctx.play("Rare")
				Juice.Confetti(ctx.gui, 70)
			end
		elseif previous and previous.Log ~= payload.Log then
			ctx.play("Bonk")
			Juice.Shake(0.25, 0.25)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if panel.Visible and battle then
			local t = workspace:GetServerTimeNow()
			local secondsLeft = math.max(0, math.ceil((tonumber(battle.Deadline) or t) - t))
			for move, entry in moveButtons do
				local chosen = battle.Chosen == move
				local waiting = move == "Special" and (tonumber(battle.Me.SpecialIn) or 0) > 0
				entry.Button.BackgroundColor3 = if battle.Done then C.Gray elseif chosen then C.White elseif waiting or battle.Chosen then C.Gray else entry.Color
				entry.Text.Text = if waiting then ("SPECIAL (%d)"):format(battle.Me.SpecialIn) elseif chosen then "OK!" else string.upper(move)
			end
			if not battle.Done and not battle.Chosen then
				log.Text = ("Turn %d  -  choose in %ds!   %s"):format(tonumber(battle.Turn) or 0, secondsLeft, tostring(battle.Log or ""))
			end
			if (hideAt > 0 and os.clock() > hideAt) or player:GetAttribute("InMinigame") ~= "Battle" then
				panel.Visible = false
				battle = nil
				hideAt = 0
			end
		end
	end)

	ctx.EffectEvent.OnClientEvent:Connect(function(kind)
		if kind == "MinigameAnnounce" then
			ctx.play("Rare")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(refresh) -- um erro aqui nunca pode travar a faixa para sempre
			if not ok then
				warn("[MinigameUI]", err)
			end
		end
	end)
end

return MinigameUI
