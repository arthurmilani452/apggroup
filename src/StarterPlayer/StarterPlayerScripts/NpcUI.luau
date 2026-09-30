--[[
	NpcUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	v14: conversa com o mascote Sneaky e com os ajudantes do mapa.
	  • Chegue perto e aperte "Talk" (E no PC, toque no celular): aparece o balão de conversa embaixo.
	  • NEXT mostra a próxima dica; BYE fecha. Fecha sozinho se você se afastar.
	  • Os personagens balançam de leve e viram o rosto para você quando chega perto
	    (isso é só na sua tela: não pesa no servidor).
	A conversa é só texto (não dá prêmio), então não precisa falar com o servidor.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCs = require(Shared:WaitForChild("NPCs"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local NpcUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

local TALK_DISTANCE = 18 -- longe disso a conversa fecha
local ANIMATE_DISTANCE = 90 -- só anima quem está perto (economiza no celular)
local LOOK_DISTANCE = 20 -- vira para você quando está a menos disso

function NpcUI.Init(ctx)
	local player = Players.LocalPlayer

	---------------------------------------------------------------------
	-- Balão de conversa
	---------------------------------------------------------------------
	local panel = create("Frame", {
		Name = "NpcDialog",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(560, 170),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 30,
		Parent = ctx.gui,
	}, { corner(20), UI.border(C.Gold, 4) })
	ctx.scaleNow(panel)
	local nameLabel = label({
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(0.6, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		Text = "",
		ZIndex = 31,
		Parent = panel,
	})
	local lineLabel = label({
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(1, -36, 0, 66),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
		ZIndex = 31,
		Parent = panel,
	})
	local counter = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 12),
		Size = UDim2.fromOffset(80, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(200, 200, 220),
		Text = "",
		ZIndex = 31,
		Parent = panel,
	})

	local current: any = nil -- { Npc, Model, Index, Opened }
	local typing = 0
	-- cada NPC lembra onde a conversa parou (na próxima vez continua da dica seguinte)
	local lastIndex: { [string]: number } = {}

	local function close()
		current = nil
		panel.Visible = false
	end

	local nextButton, nextText
	local function showLine()
		if not current then
			return
		end
		local lines = current.Npc.Lines
		local index = current.Index
		lineLabel.Text = lines[index]
		lineLabel.MaxVisibleGraphemes = 0
		typing += 1
		local myTyping = typing
		counter.Text = ("%d/%d"):format(index, #lines)
		nextText.Text = if index >= #lines then "BYE" else "NEXT"
		nextButton.BackgroundColor3 = if index >= #lines then C.Gray else C.Green
		task.spawn(function()
			-- efeito de "digitando" (funciona com qualquer idioma: conta as letras do texto já traduzido)
			local total = utf8.len(lineLabel.ContentText) or #lineLabel.Text
			for shown = 1, total, 2 do
				if typing ~= myTyping then
					return
				end
				lineLabel.MaxVisibleGraphemes = shown
				task.wait(0.016)
			end
			if typing == myTyping then
				lineLabel.MaxVisibleGraphemes = -1
			end
		end)
	end

	nextButton, nextText = button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -12),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = C.Green,
		ZIndex = 32,
		Parent = panel,
	}, "NEXT", function()
		if not current then
			return
		end
		ctx.play("Click")
		if lineLabel.MaxVisibleGraphemes ~= -1 then
			-- primeiro toque só termina de mostrar a frase
			typing += 1
			lineLabel.MaxVisibleGraphemes = -1
			return
		end
		if current.Index >= #current.Npc.Lines then
			close()
			return
		end
		current.Index += 1
		lastIndex[current.Npc.Id] = current.Index
		showLine()
	end)
	button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -176, 1, -12),
		Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = C.Red,
		ZIndex = 32,
		Parent = panel,
	}, "BYE", function()
		ctx.play("Click")
		close()
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local id = prompt:GetAttribute("NpcId")
		local npc = typeof(id) == "string" and NPCs.ById[id]
		if not npc then
			return
		end
		if current and current.Npc == npc then
			close()
			return
		end
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		local start = ((lastIndex[npc.Id] or 0) % #npc.Lines) + 1
		lastIndex[npc.Id] = start
		current = { Npc = npc, Model = model, Index = start, Opened = os.clock() }
		nameLabel.Text = npc.Name
		panel.Visible = true
		UI.popIn(panel)
		ctx.play("Click")
		showLine()
	end)

	-- fecha sozinho se você se afastar ou se o personagem sumir (streaming)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if current then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local model = current.Model
				if not root or not model or not model.Parent then
					close()
				elseif (model:GetPivot().Position - root.Position).Magnitude > TALK_DISTANCE then
					close()
				end
			end
		end
	end)

	---------------------------------------------------------------------
	-- Animação leve: respira (sobe e desce) e vira para o jogador
	---------------------------------------------------------------------
	type Entry = { Model: Model, Base: CFrame, Yaw: number, Phase: number, Hop: number, IsMascot: boolean }
	local entries: { [Model]: Entry } = {}

	local function add(model: Instance)
		if not model:IsA("Model") or entries[model] then
			return
		end
		entries[model] = {
			Model = model,
			Base = model:GetPivot(),
			Yaw = 0,
			Phase = math.random() * math.pi * 2,
			Hop = 0,
			IsMascot = model:GetAttribute("NpcId") == "sneaky",
		}
	end
	for _, model in CollectionService:GetTagged("NPC") do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("NPC"):Connect(function(model)
		entries[model :: Model] = nil
	end)

	local nextHop = os.clock() + 5
	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now = os.clock()
		local focus = camera.Focus.Position
		local hopNow = now >= nextHop
		if hopNow then
			nextHop = now + 5 + math.random() * 4
		end
		for model, entry in entries do
			if not model.Parent then
				entries[model] = nil
				continue
			end
			local base = entry.Base
			if (base.Position - focus).Magnitude > ANIMATE_DISTANCE then
				continue
			end
			local talking = current ~= nil and current.Model == model
			local targetYaw = 0
			if root then
				local offset = base:PointToObjectSpace(root.Position)
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if flat.Magnitude < LOOK_DISTANCE and flat.Magnitude > 0.5 then
					-- ângulo entre a frente (-Z) e a direção do jogador
					targetYaw = math.clamp(math.atan2(-flat.X, -flat.Z), -1.3, 1.3)
				end
			end
			entry.Yaw += (targetYaw - entry.Yaw) * math.min(1, dt * 5)
			-- o Sneaky dá pulinhos de vez em quando (quando tem alguém perto)
			if entry.IsMascot and hopNow and math.abs(targetYaw) > 0 then
				entry.Hop = 1
			end
			local hopY = 0
			if entry.Hop > 0 then
				entry.Hop = math.max(0, entry.Hop - dt * 2.5)
				hopY = math.sin((1 - entry.Hop) * math.pi) * 0.9
			end
			local speed = if talking then 6 else 2
			local bob = math.sin(now * speed + entry.Phase) * (if talking then 0.12 else 0.07)
			model:PivotTo(base * CFrame.new(0, bob + hopY, 0) * CFrame.Angles(0, entry.Yaw, 0))
		end
	end)
end

return NpcUI
