--!nonstrict
--[[
	Game: toda a jogabilidade do servidor (o servidor decide tudo; a tela só mostra e pede).
	  Bases ........ cada jogador ganha 1 das 7 bases (cercado + esteira + placas)
	  Ninhos ....... 5 ovos por zona; o bichinho sorteado é igual em todos os servidores no mesmo ciclo
	  Roubar ....... segura E no ovo -> carrega na cabeça -> o guardião acorda e persegue
	                 cruzou a SAFE ZONE = o ovo vai para o cercado; o guardião pegou = o ovo volta para o ninho
	  Cercado ...... o ovo cresce (timer), "Hatch" choca, o bichinho passeia e rende $/s
	  Esteira ...... correr nela dá Speed (destrava com o cercado nível 1); Speed vira WalkSpeed
	  Lojinhas ..... SELL (vender), FUSE (3 iguais -> 1 melhor), TRAILS (multiplicam a esteira),
	                 BOOSTS (2x por 10 min), BAÚ GRÁTIS (a cada 15 min)
	  Index ........ cada bichinho novo dá prêmio (dinheiro + velocidade) para resgatar
	  Ciclo ........ 5 min (relógio UTC); nos últimos 10 s é NOITE: muro sobe, todos voltam, ovos x30
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(ReplicatedStorage.Shared.CritterBuilder)
local Data = require(script.Parent.Data)
local World = require(script.Parent.World)

local Game = {}

local net: RemoteEvent
local states: { [Player]: any } = {}
local zones = {}
local cycleId = -1
local night = false
local contentsFolder: Folder

---------------------------------------------------------------------
-- Ajudantes
---------------------------------------------------------------------
local function toast(player: Player, text: string, kind: string?)
	net:FireClient(player, "Toast", text, kind or "info")
end

local function toastAll(text: string, kind: string?)
	net:FireAllClients("Toast", text, kind or "info")
end

local function banner(player: Player?, text: string, color: Color3?)
	if player then
		net:FireClient(player, "Banner", text, color)
	else
		net:FireAllClients("Banner", text, color)
	end
end

-- OFERTA NA HORA CERTA: mostra um cartão pequeno com um produto de Robux (só se o produto já tiver Id)
local function offer(player: Player, key: string, reason: string)
	local state = states[player]
	local info = Config.ProductByKey[key] or Config.PassByKey[key]
	if not state or not info or not info.Id or info.Id <= 0 then
		return
	end
	if info.OneTime and state.Data.StarterBought then
		return
	end
	if Config.PassByKey[key] and state.Passes and state.Passes[key] then
		return
	end
	local clock = os.clock()
	if clock - (state.LastOffer or -1e9) < Config.OfferCooldown then
		return
	end
	state.LastOffer = clock
	net:FireClient(player, "Offer", key, reason)
end

-- MOMENTO ÉPICO: aviso gigante + tela tremendo + som para o SERVIDOR INTEIRO (é o que as crianças gravam)
local function epic(text: string, color: Color3?)
	net:FireAllClients("Epic", text, color or Color3.fromRGB(255, 220, 60))
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function billboard(adornee: BasePart, offset: number, width: number, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromScale(width, height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 60 -- menos textos ao mesmo tempo = celular não pisca
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 15, 30)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = adornee
	return label
end

local function hex(color: Color3): string
	return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
end

local function rarityColor(def): Color3
	local rarity = Config.RarityByName[def.Rarity]
	return if rarity then rarity.Color else Color3.new(1, 1, 1)
end

local function eggVisual(zoneDef, def, s: number)
	return {
		Name = def.Name .. " Egg",
		Size = 3.4 * math.clamp(s, 0.7, 6.4) ^ 0.85,
		Style = zoneDef.Egg.Style,
		Color = zoneDef.Egg.Color,
		Accent = zoneDef.Egg.Accent,
	}
end

local function setModelAnchored(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
		end
	end
end

local function pivotHeight(model: Model): number
	local cf, size = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
end

local function now(): number
	return os.time()
end

local function boostOn(state, id: string): boolean
	local untilTime = state.Data.Boosts[id]
	return typeof(untilTime) == "number" and untilTime > now()
end

-- de qual zona é este bichinho (o Index guarda a zona para calcular o prêmio)
local zoneOfDef: { [string]: number } = {}
for index, zone in Config.Zones do
	for _, world in zone.Pool do
		for _, list in Critters.ByWorld[world] or {} do
			for _, def in list do
				if not zoneOfDef[def.Id] then
					local okRarity = table.find(zone.Rarities, def.Rarity) ~= nil
					if okRarity then
						zoneOfDef[def.Id] = index
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Estado mandado para a tela
---------------------------------------------------------------------
local function slotsJson(state): string
	local list = {}
	for index, slot in state.Data.Slots do
		local def = Critters.ById[slot.Id]
		if def then
			table.insert(list, {
				i = index,
				k = slot.Kind,
				id = slot.Id,
				s = math.floor((slot.Scale or 1) * 100) / 100,
				m = slot.Mut,
				z = slot.Zone or 1,
				l = if slot.Kind == "Egg" then math.ceil(slot.Left or 0) else nil,
				inc = Config.PetIncome(def, slot.Scale or 1, slot.Mut, slot.Zone),
			})
		end
	end
	return HttpService:JSONEncode(list)
end

local function indexJson(state): string
	local list = {}
	for id, zoneIndex in state.Data.Index do
		list[id] = if state.Data.Claimed[id] then 2 else 1
		local _ = zoneIndex
	end
	return HttpService:JSONEncode(list)
end

local function refreshBoards(state)
	local data, plot = state.Data, state.Plot
	if not plot then
		return
	end
	local pen = data.PenLevel
	local nextPen = Config.PenLevels[pen + 1]
	local penGui = plot.PenBoard:FindFirstChild("SignGui")
	if penGui then
		penGui.Line2.Text = if pen == 0 then "Unlock Pen Level 1" elseif nextPen then ("Level %d > Level %d"):format(pen, pen + 1) else "Level MAX"
		penGui.Line3.Text = if nextPen then Format.Money(nextPen.Cost) else "MAX"
		penGui.Background.BackgroundColor3 = if nextPen and data.Money >= nextPen.Cost then Color3.fromRGB(60, 190, 60) else Color3.fromRGB(205, 60, 60)
	end
	local tread = data.TreadLevel
	local nextTread = Config.Treadmills[tread + 1]
	local treadGui = plot.TreadBoard:FindFirstChild("SignGui")
	if treadGui then
		treadGui.Line2.Text = if nextTread then ("Level %d > Level %d"):format(tread, tread + 1) else "Level MAX"
		treadGui.Line3.Text = if nextTread then Format.Money(nextTread.Cost) else "MAX"
		treadGui.Background.BackgroundColor3 = if nextTread and data.Money >= nextTread.Cost then Color3.fromRGB(60, 190, 60) else Color3.fromRGB(40, 130, 230)
	end
	local info = Config.Treadmills[tread]
	local screenGui = plot.Screen:FindFirstChild("SignGui")
	if screenGui then
		screenGui.Line1.Text = string.upper(info.Name) .. " TREADMILL"
		screenGui.Line1.TextColor3 = info.Color
		screenGui.Line2.Text = ("+%s/step"):format(Format.Short(state.Gain or info.Gain))
	end
	local belt = plot.TreadModel:FindFirstChild("Base")
	if belt then
		belt.Color = info.Color:Lerp(Color3.new(0, 0, 0), 0.35)
	end
	for _, glow in plot.TreadModel:GetChildren() do
		if glow.Name == "LevelGlow" and glow:IsA("BasePart") then
			glow.Color = info.Color
		end
	end
	World.SetTreadmillLocked(plot, data.PenLevel < Config.TreadmillUnlockPen)
end

local function computeGain(state): number
	local data = state.Data
	local trail = data.Trail and Config.TrailById[data.Trail]
	local gain = Config.Treadmills[data.TreadLevel].Gain * (if trail then trail.Mult else 1)
	if boostOn(state, "Tread2") then
		gain *= 2
	end
	if state.Passes and state.Passes.VIP then
		gain *= 1.2
	end
	gain *= 1 + Config.RebirthTread * (data.Rebirths or 0)
	state.Gain = math.floor(gain)
	return state.Gain
end

local function computeIncome(state)
	local total = 0
	for _, slot in state.Data.Slots do
		if slot.Kind == "Pet" then
			local def = Critters.ById[slot.Id]
			if def then
				total += Config.PetIncome(def, slot.Scale or 1, slot.Mut, slot.Zone)
			end
		end
	end
	if boostOn(state, "Money2") then
		total *= 2
	end
	if state.Passes and state.Passes.Money2 then
		total *= 2
	end
	if state.Passes and state.Passes.VIP then
		total *= 1 + Config.VIPCash
	end
	total *= 1 + Config.RebirthMoney * (state.Data.Rebirths or 0)
	total *= 1 + (state.FriendBoost or 0)
	if workspace:GetAttribute("Weekend") then
		total *= 2
	end
	state.Income = total
end

local function publish(player: Player, full: boolean?)
	local state = states[player]
	if not state then
		return
	end
	local data = state.Data
	computeGain(state)
	player:SetAttribute("Money", data.Money)
	player:SetAttribute("Speed", data.Speed)
	player:SetAttribute("Income", state.Income or 0)
	player:SetAttribute("Gain", state.Gain or 0)
	player:SetAttribute("PenLevel", data.PenLevel)
	player:SetAttribute("TreadLevel", data.TreadLevel)
	player:SetAttribute("Stolen", data.Stolen)
	player:SetAttribute("Trail", data.Trail or "")
	player:SetAttribute("ChestAt", (data.ChestAt or 0) + Config.ChestEvery)
	player:SetAttribute("Slots", slotsJson(state))
	player:SetAttribute("Rebirths", data.Rebirths or 0)
	player:SetAttribute("Bat", data.Bat or 0)
	player:SetAttribute("TrapsOut", state.TrapCount or 0)
	player:SetAttribute("FriendBoost", state.FriendBoost or 0)
	player:SetAttribute("DailyStreak", data.DailyStreak or 0)
	player:SetAttribute("DailyReady", (data.DailyDay or 0) < os.time() // 86400)
	if full then
		local passes = {}
		for key in state.Passes or {} do
			table.insert(passes, key)
		end
		player:SetAttribute("Passes", table.concat(passes, ","))
		player:SetAttribute("Index", indexJson(state))
		player:SetAttribute("Trails", table.concat(data.Trails, ","))
		player:SetAttribute("Boosts", HttpService:JSONEncode(data.Boosts))
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats["Money/s"].Value = Format.Money(state.Income or 0) .. "/s"
		stats.Speed.Value = Format.Short(data.Speed)
	end
	refreshBoards(state)
end

local function applySpeed(player: Player)
	local state = states[player]
	local humanoid = humanoidOf(player)
	if not state or not humanoid then
		return
	end
	local walk = Config.WalkSpeed(state.Data.Speed)
	if (state.StunUntil or 0) > os.clock() then
		humanoid.WalkSpeed = 0
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 0
		state.Walk = 0
		return
	end
	if state.Carry then
		walk *= Config.CarryFactor(state.Carry.Scale)
	elseif player:GetAttribute("SlowMode") then
		walk = 16
	end
	humanoid.WalkSpeed = walk
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 50 * (if state.Carry then Config.CarryFactor(state.Carry.Scale) else 1)
	state.Walk = walk
end

-- rastro colorido atrás do jogador (trilha equipada)
local function applyTrail(player: Player)
	local state = states[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not root then
		return
	end
	local old = root:FindFirstChild("CritterTrail")
	if old then
		old:Destroy()
	end
	for _, name in { "TrailA0", "TrailA1" } do
		local a = root:FindFirstChild(name)
		if a then
			a:Destroy()
		end
	end
	local trail = state.Data.Trail and Config.TrailById[state.Data.Trail]
	if not trail then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -1.6, 0)
	a1.Parent = root
	local effect = Instance.new("Trail")
	effect.Name = "CritterTrail"
	effect.Attachment0 = a0
	effect.Attachment1 = a1
	effect.Lifetime = 0.6
	effect.LightEmission = 0.6
	effect.Color = if trail.Id == "rainbow" then ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
	}) else ColorSequence.new(trail.Color)
	effect.Transparency = NumberSequence.new(0.1, 1)
	effect.Parent = root
end

---------------------------------------------------------------------
-- Cercado: ovos crescendo e bichinhos
---------------------------------------------------------------------
local renderSlot

local function clearSlotModel(state, index: number)
	local model = state.SlotModels[index]
	if model then
		model:Destroy()
		state.SlotModels[index] = nil
	end
	local extra = state.SlotExtras and state.SlotExtras[index]
	if extra then
		extra:Destroy()
		state.SlotExtras[index] = nil
	end
end

local function redrawPen(player: Player)
	local state = states[player]
	for index in state.SlotModels do
		clearSlotModel(state, index)
	end
	for index = 1, #state.Data.Slots do
		renderSlot(player, index)
	end
end

local function discover(player: Player, def)
	local state = states[player]
	if state.Data.Index[def.Id] then
		return false
	end
	state.Data.Index[def.Id] = zoneOfDef[def.Id] or 1
	toast(player, ("\u{1F4D6} NEW in your Index: %s! Claim the reward in the Index."):format(def.Name), "success")
	return true
end

---------------------------------------------------------------------
-- Missões do dia
---------------------------------------------------------------------
local function questData(state)
	local data = state.Data
	local today = os.time() // 86400
	if type(data.Quests) ~= "table" or data.Quests.Day ~= today then
		data.Quests = { Day = today, Progress = {}, Claimed = {} }
	end
	return data.Quests
end

local function questJson(state): string
	local q = questData(state)
	return HttpService:JSONEncode({ p = q.Progress, c = q.Claimed })
end

-- FUNIL DOS PRIMEIROS MINUTOS (Creator Hub > Analytics > Funnels > Onboarding): mostra em qual passo
-- as crianças desistem. Cada passo é registrado só uma vez por jogador.
local FUNNEL = { Joined = 1, Steal = 2, Hatch = 3, Pen = 4, Steps = 5, Treadmill = 6, Zone2 = 7, Hit = 8 }
local FUNNEL_NAMES = { "Joined", "First egg stolen", "First hatch", "First pen upgrade", "First treadmill step", "First treadmill upgrade", "Stole from zone 2+", "First bat hit" }
local function funnel(player: Player, key: string)
	local state = states[player]
	local step = FUNNEL[key]
	if not state or not step then
		return
	end
	state.Data.Funnel = state.Data.Funnel or {}
	local done = state.Data.Funnel
	if done[tostring(step)] then
		return
	end
	done[tostring(step)] = true
	pcall(function()
		game:GetService("AnalyticsService"):LogOnboardingFunnelStepEvent(player, step, FUNNEL_NAMES[step])
	end)
end

local function questAdd(player: Player, key: string, amount: number?)
	local state = states[player]
	if not state then
		return
	end
	funnel(player, key)
	local q = questData(state)
	local before = q.Progress[key] or 0
	q.Progress[key] = before + (amount or 1)
	for _, info in Config.Quests do
		if info.Key == key and before < info.Goal and q.Progress[key] >= info.Goal and not q.Claimed[key] then
			net:FireClient(player, "Toast", ("\u{2705} Quest done: %s! Claim it in Quests."):format(info.Name), "success")
		end
	end
	player:SetAttribute("Quests", questJson(state))
end

local function hatch(player: Player, index: number, silent: boolean?): boolean
	local state = states[player]
	local slot = state and state.Data.Slots[index]
	if not slot or slot.Kind ~= "Egg" or (slot.Left or 0) > 0 then
		return false
	end
	local def = Critters.ById[slot.Id]
	if not def then
		return false
	end
	slot.Kind = "Pet"
	slot.Left = nil
	discover(player, def)
	questAdd(player, "Hatch")
	computeIncome(state)
	-- ANIMAÇÃO NO MUNDO (todo mundo vê): o ovo treme, racha, brilha e explode; o bichinho "pula" para fora
	local eggModel = state.SlotModels[index]
	state.SlotModels[index] = nil
	if eggModel then
		task.spawn(function()
			local ok = pcall(function()
				local prompt = eggModel:FindFirstChild("HatchPrompt", true)
				if prompt then
					prompt.Enabled = false
				end
				local info = eggModel:FindFirstChild("Info", true)
				if info then
					info.Enabled = false
				end
				local startPivot = eggModel:GetPivot()
				local root = eggModel.PrimaryPart
				local glow
				if root then
					glow = Instance.new("PointLight")
					glow.Color = rarityColor(def)
					glow.Range = 4
					glow.Brightness = 0
					glow.Parent = root
				end
				local duration = 1.1
				local started = os.clock()
				local lastCrack = 0
				while os.clock() - started < duration and eggModel.Parent do
					local p = (os.clock() - started) / duration
					local power = 4 + p * 22 -- treme cada vez mais forte
					local angle = math.sin(p * 60) * power
					local grow = 1 + p * 0.25
					eggModel:PivotTo(startPivot * CFrame.new(0, math.abs(math.sin(p * 30)) * 0.4 * p, 0) * CFrame.Angles(math.rad(angle * 0.4), 0, math.rad(angle)))
					pcall(function()
						eggModel:ScaleTo(grow)
					end)
					if glow then
						glow.Range = 4 + p * 14
						glow.Brightness = p * 4
					end
					if p - lastCrack > 0.33 then
						lastCrack = p
						net:FireAllClients("SfxAt", "Crack", startPivot.Position)
					end
					task.wait()
				end
				local position = startPivot.Position
				-- explosão de luz + pedaços de casca
				local burst = Instance.new("Part")
				burst.Name = "HatchBurst"
				burst.Shape = Enum.PartType.Ball
				burst.Size = Vector3.new(2, 2, 2)
				burst.CFrame = CFrame.new(position)
				burst.Color = rarityColor(def)
				burst.Material = Enum.Material.Neon
				burst.Transparency = 0.2
				burst.Anchored = true
				burst.CanCollide = false
				burst.CanQuery = false
				burst.CanTouch = false
				burst.Parent = contentsFolder
				local emitter = Instance.new("ParticleEmitter")
				emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				emitter.Color = ColorSequence.new(rarityColor(def), Color3.new(1, 1, 1))
				emitter.LightEmission = 1
				emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
				emitter.Lifetime = NumberRange.new(0.6, 1.2)
				emitter.Speed = NumberRange.new(14, 26)
				emitter.SpreadAngle = Vector2.new(180, 180)
				emitter.Acceleration = Vector3.new(0, -25, 0)
				emitter.Rate = 0
				emitter.Parent = burst
				emitter:Emit(if (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Legendary then 90 else 45)
				local shellColor = Color3.new(1, 1, 1)
				for _, item in eggModel:GetDescendants() do
					if item:IsA("BasePart") and item.Transparency < 1 then
						shellColor = item.Color
						break
					end
				end
				for k = 1, 8 do
					local shell = Instance.new("Part")
					shell.Name = "Shell"
					shell.Size = Vector3.new(0.9, 0.25, 0.9)
					shell.Color = shellColor
					shell.Material = Enum.Material.SmoothPlastic
					shell.CanCollide = false
					shell.CanQuery = false
					shell.CanTouch = false
					shell.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
					shell.Parent = contentsFolder
					local a = (k / 8) * math.pi * 2
					shell.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 14, 22 + math.random() * 8, math.sin(a) * 14)
					shell.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
					game:GetService("Debris"):AddItem(shell, 1.6)
				end
				net:FireAllClients("SfxAt", "Pop", position)
				if (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Legendary then
					net:FireAllClients("SfxAt", "Delivered", position)
				end
				eggModel:Destroy()
				TweenService:Create(burst, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
				game:GetService("Debris"):AddItem(burst, 1.5)
			end)
			if eggModel.Parent then
				eggModel:Destroy()
			end
			if not ok then
				warn("[Game] animação de chocar falhou")
			end
			-- o bichinho aparece (com "pulo" para fora do ovo)
			if states[player] == state then
				local i = table.find(state.Data.Slots, slot)
				if i and not state.SlotModels[i] then
					renderSlot(player, i, true)
				end
			end
		end)
	else
		renderSlot(player, index, true)
	end
	if not silent then
		local label = Config.SizeLabel(slot.Scale or 1)
		banner(player, ("%s%s%s!"):format(if label then label .. " " else "", if slot.Mut then slot.Mut .. " " else "", def.Name), rarityColor(def))
		net:FireClient(player, "Hatched", { { def.Id, slot.Mut, slot.Scale or 1, slot.Zone or 1 } })
	end
	local rarity = Config.RarityByName[def.Rarity]
	if (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Mythic then
		epic(("\u{2728} %s HATCHED A %s %s!"):format(player.DisplayName, string.upper(def.Rarity), def.Name), rarityColor(def))
	elseif rarity and rarity.Announce then
		toastAll(("\u{2B50} %s hatched a %s %s!"):format(player.DisplayName, string.upper(def.Rarity), def.Name), "rare")
	end
	if not state.Data.StarterBought and not state.StarterOffered then
		state.StarterOffered = true
		task.delay(5, function()
			offer(player, "Starter", "Welcome gift! A big boost for new players")
		end)
	end
	return true
end

local function sellAt(player: Player, index: number): number
	local state = states[player]
	local slot = state and state.Data.Slots[index]
	if not slot or slot.Kind ~= "Pet" then
		return 0
	end
	local def = Critters.ById[slot.Id]
	local value = if def then Config.SellValue(def, slot.Scale or 1, slot.Mut, slot.Zone) else 0
	table.remove(state.Data.Slots, index)
	state.Data.Money += value
	return value
end

renderSlot = function(player: Player, index: number, popIn: boolean?)
	local state = states[player]
	if not state or not state.Plot then
		return
	end
	clearSlotModel(state, index)
	local slot = state.Data.Slots[index]
	local def = slot and Critters.ById[slot.Id]
	if not slot or not def then
		return
	end
	local zoneDef = Config.Zones[slot.Zone or 1] or Config.Zones[1]
	local base = World.SlotPosition(state.Plot, index)
	local s = slot.Scale or 1
	local model, root
	if slot.Kind == "Egg" then
		model, root = Builder.BuildEgg(eggVisual(zoneDef, def, s))
		setModelAnchored(model)
		model:PivotTo(CFrame.new(base + Vector3.new(0, pivotHeight(model) + 0.4, 0)))
		billboard(root, 2.5 + s * 1.5, 9, 3.2)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HatchPrompt"
		prompt.ActionText = "Hatch"
		prompt.ObjectText = def.Name .. " Egg"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(who)
			if who == player then
				local i = table.find(state.Data.Slots, slot)
				if i and hatch(player, i) then
					publish(player, true)
				end
			end
		end)
	else
		model, root = Builder.Build(def)
		if slot.Mut then
			pcall(Builder.ApplyMutation, model, slot.Mut)
		end
		pcall(function()
			-- tamanho do ovo (BIG/HUGE/GIANT) aumenta o bicho, mas sem passar de Config.MaxPetSize
			local extents = model:GetExtentsSize()
			local biggest = math.max(extents.X, extents.Y, extents.Z, 0.5)
			local scale = math.clamp(s, 0.75, 2.6)
			scale = math.min(scale, Config.MaxPetSize / biggest)
			model:ScaleTo(scale)
		end)
		setModelAnchored(model)
		local height = pivotHeight(model)
		model:PivotTo(CFrame.new(base + Vector3.new(0, height, 0)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
		model:SetAttribute("Wander", true)
		local rarityIndex = Config.RarityIndex[def.Rarity] or 1
		-- bichos grandes (Lendário+) ficam no pedestal em vez de passear e esbarrar nos vizinhos
		model:SetAttribute("WanderRange", if rarityIndex >= Config.RarityIndex.Legendary then 0.8 elseif rarityIndex >= Config.RarityIndex.Epic then 2.5 else 4.5)
		if popIn then
			model:SetAttribute("PopIn", workspace:GetServerTimeNow())
		end
		-- PEDESTAL brilhante na cor da raridade (Raro ou melhor), igual às bases do Steal an Egg
		if rarityIndex >= Config.RarityIndex.Rare then
			local color = rarityColor(def)
			local ext = model:GetExtentsSize()
			local radius = math.clamp(math.max(ext.X, ext.Z) * 0.75, 4, 10.5)
			local pedestal = Instance.new("Model")
			pedestal.Name = ("Pedestal%d"):format(index)
			local disc = Instance.new("Part")
			disc.Name = "Disc"
			disc.Shape = Enum.PartType.Cylinder
			disc.Size = Vector3.new(0.6, radius, radius)
			disc.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
			disc.Color = Color3.fromRGB(245, 245, 250)
			disc.Material = Enum.Material.SmoothPlastic
			disc.Parent = pedestal
			local ring = Instance.new("Part")
			ring.Name = "Ring"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.35, radius + 0.8, radius + 0.8)
			ring.CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			ring.Color = color
			ring.Material = Enum.Material.Neon
			ring.Parent = pedestal
			if rarityIndex >= Config.RarityIndex.Legendary then
				-- coluna de luz subindo do pedestal
				local beamPart = Instance.new("Part")
				beamPart.Name = "LightColumn"
				beamPart.Shape = Enum.PartType.Cylinder
				beamPart.Size = Vector3.new(18, radius * 0.9, radius * 0.9)
				beamPart.CFrame = CFrame.new(base + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90))
				beamPart.Color = color
				beamPart.Material = Enum.Material.Neon
				beamPart.Transparency = 0.85
				beamPart.CastShadow = false
				beamPart.Parent = pedestal
			end
			for _, item in pedestal:GetChildren() do
				item.Anchored = true
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
			end
			pedestal.Parent = contentsFolder
			state.SlotExtras = state.SlotExtras or {}
			state.SlotExtras[index] = pedestal
		end
		if (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Legendary and root then
			local light = Instance.new("PointLight")
			light.Color = rarityColor(def)
			light.Range = 10
			light.Brightness = 1.5
			light.Parent = root
			local glitter = Instance.new("ParticleEmitter")
			glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			glitter.Color = ColorSequence.new(rarityColor(def))
			glitter.LightEmission = 1
			glitter.Size = NumberSequence.new(0.5, 0)
			glitter.Rate = 5
			glitter.Lifetime = NumberRange.new(0.8, 1.4)
			glitter.Speed = NumberRange.new(1, 2)
			glitter.SpreadAngle = Vector2.new(180, 180)
			glitter.Parent = root
		end
		model:SetAttribute("Height", height)
		model:SetAttribute("Income", Config.PetIncome(def, s, slot.Mut, slot.Zone))
		local label = Config.SizeLabel(s)
		local info = billboard(root, 3 + s * 2, 10, 4)
		info.Text = ('<font color="%s">%s</font>\n%s%s%s\n<font color="#78FF78">%s/s</font>'):format(
			hex(rarityColor(def)), def.Rarity, if slot.Mut then slot.Mut .. " " else "", if label then label .. " " else "", def.Name,
			Format.Money(Config.PetIncome(def, s, slot.Mut, slot.Zone)))
	end
	model.Name = ("Slot%d"):format(index)
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Base", base)
	model.Parent = contentsFolder
	state.SlotModels[index] = model
end

local function updateEggLabels(state)
	for index, slot in state.Data.Slots do
		if slot.Kind == "Egg" then
			local model = state.SlotModels[index]
			local root = model and model.PrimaryPart
			local gui = root and root:FindFirstChild("Info")
			local label = gui and gui:FindFirstChild("Text")
			local def = Critters.ById[slot.Id]
			if label and def then
				local left = math.max(0, math.ceil(slot.Left or 0))
				local timeText
				if left <= 0 then
					timeText = '<font color="#78FF78">READY! Hatch it!</font>'
				elseif left >= 3600 then
					timeText = ("%d:%02d:%02d"):format(left // 3600, (left % 3600) // 60, left % 60)
				elseif left >= 60 then
					timeText = ("%d:%02d"):format(left // 60, left % 60)
				else
					timeText = ("0:%02d"):format(left)
				end
				label.Text = ('<font color="%s">%s</font>\n%s Egg\n%s'):format(hex(rarityColor(def)), def.Rarity, def.Name, timeText)
				local prompt = root:FindFirstChild("HatchPrompt")
				if prompt then
					prompt.Enabled = left <= 0
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Ninhos, roubo e guardiões
---------------------------------------------------------------------
local poolCache = {}
local function poolFor(zoneDef, rarity: string)
	local key = zoneDef.Id .. ":" .. rarity
	if poolCache[key] then
		return poolCache[key]
	end
	local list = {}
	for _, world in zoneDef.Pool do
		local byRarity = Critters.ByWorld[world]
		for _, def in (byRarity and byRarity[rarity]) or {} do
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	poolCache[key] = list
	return list
end

local function rollMutation(rng: Random): string?
	local m = rng:NextNumber() * 100
	for _, info in Config.Mutations do
		if m < info.Chance then
			return info.Name
		end
		m -= info.Chance
	end
	return nil
end

-- sorteia o bichinho (mesma semente = mesmo resultado em todos os servidores)
local function luckyNow(): boolean
	return (workspace:GetAttribute("LuckyEnd") or 0) > os.time()
end

local function rollEgg(zoneDef, rng: Random, minRarity: number?)
	local options, total = {}, 0
	local lucky = luckyNow()
	for _, rarity in zoneDef.Rarities do
		if #poolFor(zoneDef, rarity) > 0 and (Config.RarityIndex[rarity] or 1) >= (minRarity or 1) then
			local weight = Config.RarityByName[rarity].Weight
			if lucky and (Config.RarityIndex[rarity] or 1) >= Config.RarityIndex.Legendary then
				weight *= Config.LuckyMult
			end
			table.insert(options, { rarity, weight })
			total += weight
		end
	end
	local roll = rng:NextNumber() * total
	local chosen = options[#options][1]
	for _, option in options do
		roll -= option[2]
		if roll <= 0 then
			chosen = option[1]
			break
		end
	end
	local list = poolFor(zoneDef, chosen)
	-- bicho da semana sai mais vezes dentro da raridade dele
	local weekly = Config.WeeklyCritter(os.time())
	local total, weights = 0, {}
	for i, def in list do
		weights[i] = if def.Id == weekly then Config.WeeklyMult else 1
		total += weights[i]
	end
	local pick = rng:NextNumber() * total
	for i, def in list do
		pick -= weights[i]
		if pick <= 0 then
			return def, rollMutation(rng)
		end
	end
	return list[#list], rollMutation(rng)
end

local function removeNestEgg(nest)
	if nest.Egg and nest.Egg.Model then
		nest.Egg.Model:Destroy()
	end
	nest.Egg = nil
end

local beginCarry

local function placeNestEgg(zone, nest, def, mutation: string?, s: number): boolean
	removeNestEgg(nest)
	local model, root = Builder.BuildEgg(eggVisual(zone.Def, def, s))
	setModelAnchored(model)
	model:PivotTo(nest.CFrame + Vector3.new(0, pivotHeight(model), 0))
	model:AddTag("NestEgg")
	model:SetAttribute("Zone", zone.Index)
	model:SetAttribute("Need", Config.EscapeSpeed(zone.Def, s))
	local label = Config.SizeLabel(s)
	local info = billboard(root, 2.5 + s * 1.6, 10, 3.6)
	info.Text = ('<font color="%s">%s</font>\n%s%s%s Egg\n<font color="#78FF78">%s/s</font>  %skg'):format(
		hex(rarityColor(def)), def.Rarity, if mutation then mutation .. " " else "", if label then label .. " " else "", def.Name,
		Format.Money(Config.PetIncome(def, s, mutation, zone.Index)), Format.Short(Config.WeightKg(def, s)))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = def.Name .. " Egg"
	prompt.HoldDuration = Config.StealHold
	prompt.MaxActivationDistance = 10 + s * 1.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	local egg = { Def = def, Mut = mutation, Scale = s, Model = model, Root = root, Prompt = prompt, Thief = nil }
	nest.Egg = egg
	prompt.Triggered:Connect(function(player)
		beginCarry(player, zone, nest, egg)
	end)
	model.Parent = contentsFolder
	local rarity = Config.RarityByName[def.Rarity]
	return rarity ~= nil and rarity.Announce == true
end

local function setSleeping(zone, sleeping: boolean)
	if zone.Awake == sleeping and not sleeping and net then
		net:FireAllClients("GuardianAwake", zone.Index, zone.Pos)
	end
	zone.Awake = not sleeping
	if zone.Zzz then
		zone.Zzz.Text = if sleeping then "Z z Z" else "!!!"
		zone.Zzz.TextColor3 = if sleeping then Color3.fromRGB(140, 190, 255) else Color3.fromRGB(255, 70, 70)
	end
	if zone.Guardian then
		zone.Guardian:SetAttribute("Sleeping", sleeping)
	end
	if zone.Outline then
		zone.Outline.OutlineColor = if sleeping then zone.ZoneColor else Color3.fromRGB(255, 40, 40)
		zone.Outline.FillColor = Color3.fromRGB(255, 40, 40)
		zone.Outline.FillTransparency = if sleeping then 1 else 0.8
	end
	if zone.Ring then
		zone.Ring.Color = if sleeping then zone.ZoneColor else Color3.fromRGB(255, 50, 50)
		zone.Ring.Transparency = if sleeping then 0.75 else 0.45
	end
end

local function buildGuardian(zone)
	local def = Critters.ById[zone.Def.Guardian]
	if not def then
		warn("[Game] guardião não existe:", zone.Def.Guardian)
		return
	end
	local ok, model, root = pcall(Builder.Build, def)
	if not ok or not model then
		warn("[Game] guardião:", model)
		return
	end
	model.Name = "Guardian_" .. zone.Def.Id
	local extents = model:GetExtentsSize()
	pcall(function()
		model:ScaleTo(zone.Def.Height / math.max(extents.Y, 0.5))
	end)
	setModelAnchored(model)
	local position = Vector3.new(zone.Center.X, pivotHeight(model), zone.Center.Z)
	local home = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
	model:PivotTo(home)
	model:AddTag("Guardian")
	model:SetAttribute("Zone", zone.Index)
	model:SetAttribute("Goal", home)
	model:SetAttribute("Speed", 0)
	model:SetAttribute("Height", zone.Def.Height)
	local size = model:GetExtentsSize()
	-- CHEFÃO: coroa, aura, contorno, círculo de território e placa com o nome
	local zoneColor = (zone.Def.Top or zone.Def.Floor[1]):Lerp(Color3.new(1, 1, 1), 0.15)
	local box = model:GetBoundingBox()
	local top = box.Position + Vector3.new(0, size.Y / 2, 0)
	local crown = Instance.new("Model")
	crown.Name = "Crown"
	local crownSize = math.clamp(size.X * 0.35, 2.5, 9)
	local band = Instance.new("Part")
	band.Name = "CrownBand"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(crownSize * 0.35, crownSize, crownSize)
	band.CFrame = CFrame.new(top + Vector3.new(0, crownSize * 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90))
	band.Color = Color3.fromRGB(255, 200, 40)
	band.Material = Enum.Material.Metal
	band.Reflectance = 0.25
	band.Parent = crown
	for k = 0, 4 do
		local a = math.rad(k * 72)
		local spike = Instance.new("Part")
		spike.Name = "CrownSpike"
		spike.Size = Vector3.new(crownSize * 0.18, crownSize * 0.45, crownSize * 0.18)
		spike.CFrame = CFrame.new(top + Vector3.new(math.cos(a) * crownSize * 0.4, crownSize * 0.5, math.sin(a) * crownSize * 0.4)) * CFrame.Angles(0, -a, math.rad(10))
		spike.Color = Color3.fromRGB(255, 205, 45)
		spike.Material = Enum.Material.Metal
		spike.Reflectance = 0.25
		spike.Parent = crown
		local gem = Instance.new("Part")
		gem.Name = "CrownGem"
		gem.Shape = Enum.PartType.Ball
		gem.Size = Vector3.one * crownSize * 0.16
		gem.CFrame = CFrame.new(top + Vector3.new(math.cos(a) * crownSize * 0.4, crownSize * 0.78, math.sin(a) * crownSize * 0.4))
		gem.Color = zoneColor
		gem.Material = Enum.Material.Neon
		gem.Parent = crown
	end
	for _, item in crown:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	crown.Parent = model
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "BossAura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(zoneColor)
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size.Y * 0.08), NumberSequenceKeypoint.new(1, 0) })
	aura.Lifetime = NumberRange.new(1, 2)
	aura.Rate = 12
	aura.Speed = NumberRange.new(2, 5)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = root
	local glow = Instance.new("PointLight")
	glow.Name = "BossGlow"
	glow.Color = zoneColor
	glow.Range = math.clamp(size.Y * 1.2, 12, 40)
	glow.Brightness = 1.2
	glow.Parent = root
	local outline = Instance.new("Highlight")
	outline.Name = "BossOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = zoneColor
	outline.OutlineTransparency = 0.2
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	-- círculo do território no chão
	local ring = Instance.new("Part")
	ring.Name = "TerritoryRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.25, math.max(size.X, size.Z) * 1.6 + 8, math.max(size.X, size.Z) * 1.6 + 8)
	ring.CFrame = CFrame.new(zone.Center.X, 0.14, zone.Center.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = zoneColor
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.75
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = zone.Folder
	zone.Ring = ring
	zone.Outline = outline
	zone.ZoneColor = zoneColor
	-- placa do chefão
	local plate = billboard(root, size.Y * 0.6 + crownSize + 7, 14, 3)
	plate.Parent.Name = "BossName"
	plate.Parent.MaxDistance = 140
	plate.Text = ('<font color="#%s">\u{1F451} %s GUARDIAN</font>\n%s'):format(zoneColor:ToHex(), string.upper(zone.Def.Name), def.Name)
	local zzz = billboard(root, size.Y * 0.6 + 4, 9, 3.2)
	zzz.Parent.MaxDistance = 140
	model.Parent = zone.Folder
	zone.Guardian = model
	zone.Home = home
	zone.Pos = position
	zone.Zzz = zzz
	zone.CatchRange = math.max(4, math.max(size.X, size.Z) * 0.32)
	setSleeping(zone, true)
end

local function moveGuardian(zone, target: Vector3, speed: number, dt: number)
	local pos = zone.Pos
	local offset = Vector3.new(target.X, pos.Y, target.Z) - pos
	local distance = offset.Magnitude
	if distance < 0.05 then
		return
	end
	local nextPos = pos + offset.Unit * math.min(distance, speed * dt)
	local half = Config.Map.LaneWidth / 2 - 6
	nextPos = Vector3.new(math.clamp(nextPos.X, -half, half), nextPos.Y, math.max(nextPos.Z, 6))
	zone.Pos = nextPos
	-- o servidor só diz para onde ir; a tela de cada jogador anima suave (corrida com pulos, inclinação)
	zone.Guardian:SetAttribute("Goal", CFrame.lookAt(nextPos, nextPos + offset.Unit))
	zone.Guardian:SetAttribute("Speed", speed)
end

local function endCarry(player: Player, delivered: boolean, drop: boolean?)
	local state = states[player]
	local carry = state and state.Carry
	if not carry then
		return
	end
	state.Carry = nil
	player:SetAttribute("Carrying", nil)
	if carry.Weld then
		carry.Weld:Destroy()
	end
	local egg, nest = carry.Egg, carry.Nest
	egg.Thief = nil
	if delivered then
		removeNestEgg(nest)
		nest.RefillAt = os.clock() + Config.NestRefill
	elseif nest.Egg == egg and egg.Model.Parent then
		setModelAnchored(egg.Model)
		local root = rootOf(player)
		if drop and root then
			-- OVO SOLTO: cai no chão onde a pessoa estava; qualquer um pode pegar (some depois de um tempo)
			local half = Config.Map.LaneWidth / 2 - 4
			local spot = Vector3.new(math.clamp(root.Position.X, -half, half), 0, math.max(root.Position.Z, 4))
			egg.Model:PivotTo(CFrame.new(spot + Vector3.new(0, pivotHeight(egg.Model), 0)))
			egg.LooseUntil = os.clock() + Config.LooseEggSeconds
			egg.DroppedBy = player
			egg.Prompt.ActionText = "Pick up"
			egg.Model:SetAttribute("Loose", true)
		else
			egg.Model:PivotTo(nest.CFrame + Vector3.new(0, pivotHeight(egg.Model), 0))
			egg.LooseUntil = nil
			egg.Prompt.ActionText = "Steal"
			egg.Model:SetAttribute("Loose", nil)
		end
		egg.Prompt.Enabled = true
		local carriedInfo = egg.Model:FindFirstChild("Info", true)
		if carriedInfo and carriedInfo:IsA("BillboardGui") then
			carriedInfo.Enabled = true
		end
	end
	applySpeed(player)
end

beginCarry = function(player: Player, zone, nest, egg)
	local state = states[player]
	if not state or state.Carry or egg.Thief or nest.Egg ~= egg or night or (state.StunUntil or 0) > os.clock() then
		return
	end
	egg.LooseUntil = nil
	egg.Model:SetAttribute("Loose", nil)
	local root = rootOf(player)
	if not root or (root.Position - egg.Root.Position).Magnitude > 16 + egg.Scale * 2 then
		return
	end
	egg.Thief = player
	egg.Prompt.Enabled = false
	-- esconde a plaquinha do ovo enquanto carrega (ela ficava por cima dos textos da tela na volta para a base)
	local carriedInfo = egg.Model:FindFirstChild("Info", true)
	if carriedInfo and carriedInfo:IsA("BillboardGui") then
		carriedInfo.Enabled = false
	end
	-- pegou o ovo que OUTRO jogador derrubou: todo mundo fica sabendo
	local victim = egg.DroppedBy
	egg.DroppedBy = nil
	if victim and victim ~= player and victim.Parent then
		local vRarity = Config.RarityIndex[egg.Def.Rarity] or 1
		local msg = ("\u{1F608} %s STOLE %s's %s EGG!"):format(player.DisplayName, victim.DisplayName, string.upper(egg.Def.Rarity))
		if vRarity >= Config.RarityIndex.Rare then
			epic(msg, Config.RarityByName[egg.Def.Rarity].Color)
		else
			toastAll(msg, "rare")
		end
	end
	for _, item in egg.Model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.Massless = true
		end
	end
	local size = egg.Model:GetExtentsSize()
	-- segura o ovo na frente do peito com as duas mãos (ovo grande fica mais longe e mais baixo)
	local holdOffset = CFrame.new(0, -0.2 + size.Y * 0.18, -(0.9 + size.Z / 2))
	local fromOffset = root.CFrame:ToObjectSpace(egg.Root.CFrame)
	egg.Model:PivotTo(root.CFrame * holdOffset)
	-- Weld com C0 (a tela de cada jogador anima o ovo balançando em cima da cabeça)
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = egg.Root
	weld.C0 = holdOffset
	weld.C1 = CFrame.new()
	weld:SetAttribute("BaseC0", holdOffset)
	weld:SetAttribute("Heavy", egg.Scale)
	weld:SetAttribute("From", fromOffset) -- a tela anima o ovo saindo do ninho até as mãos
	weld:SetAttribute("GrabAt", workspace:GetServerTimeNow())
	weld.Parent = root
	state.Carry = { Egg = egg, Nest = nest, Zone = zone, Weld = weld, Scale = egg.Scale }
	player:SetAttribute("Carrying", egg.Def.Name .. " Egg")
	applySpeed(player)
	if not zone.Awake then
		zone.WakeAt = os.clock() + 1.5 -- espreguiça (vantagem de quem pegou)
		setSleeping(zone, false)
	end
	net:FireClient(player, "Grabbed", zone.Index)
end

local function deliver(player: Player)
	local state = states[player]
	local carry = state and state.Carry
	if not carry then
		return
	end
	local data = state.Data
	if #data.Slots >= Config.SlotCount(data.PenLevel) then
		toast(player, "Your pen is FULL! Upgrade your pen or sell a pet.", "warning")
		endCarry(player, false)
		return
	end
	local egg = carry.Egg
	local slot = { Kind = "Egg", Id = egg.Def.Id, Scale = egg.Scale, Mut = egg.Mut, Zone = carry.Zone.Index, Left = Config.GrowSeconds(egg.Def, egg.Scale) }
	endCarry(player, true)
	if (data.Stolen or 0) == 0 then
		slot.Left = math.min(slot.Left, Config.FirstEggSeconds) -- o primeiro ovo choca na hora
	end
	table.insert(data.Slots, slot)
	data.Stolen += 1
	if slot.Left >= 120 then
		task.delay(2, function()
			offer(player, "GrowAll", "Don't want to wait? Hatch ALL your eggs NOW!")
		end)
	end
	questAdd(player, "Steal")
	do
		local rIndex = Config.RarityIndex[egg.Def.Rarity] or 1
		local label = Config.SizeLabel(egg.Scale or 1)
		if rIndex >= Config.RarityIndex.Legendary or label == "HUGE" or label == "GIANT" or egg.Mut then
			epic(("\u{1F525} %s ESCAPED WITH A %s%s%s %s EGG!"):format(player.DisplayName, if label then label .. " " else "", if egg.Mut then string.upper(egg.Mut) .. " " else "",
				string.upper(egg.Def.Rarity), egg.Def.Name), Config.RarityByName[egg.Def.Rarity].Color)
		end
	end
	if (carry.Zone.Index or 1) >= 2 then
		funnel(player, "Zone2")
	end
	renderSlot(player, #data.Slots)
	banner(player, "You stole an EGG!", Color3.fromRGB(255, 225, 80))
	net:FireClient(player, "Stole")
	publish(player)
end

local function catchCarrier(zone, player: Player)
	local root = rootOf(player)
	endCarry(player, false)
	if root then
		local away = (root.Position - zone.Pos) * Vector3.new(1, 0, 1)
		local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, -1)
		root.AssemblyLinearVelocity = dir * 75 + Vector3.new(0, 50, 0)
		net:FireClient(player, "Caught", zone.Index, dir * 75 + Vector3.new(0, 50, 0))
	else
		net:FireClient(player, "Caught", zone.Index)
	end
	toast(player, ("The %s guardian caught you! Get FASTER on your treadmill."):format(zone.Def.Name), "warning")
	task.delay(1.5, function()
		local need = Config.EscapeSpeed(zone.Def, 1)
		offer(player, if need > 100_000 then "Speed2" else "Speed1", "Too slow? Get a SPEED boost and escape the guardian!")
	end)
end

local function tickZone(zone, dt: number, clock: number)
	for _, nest in zone.Nests do
		if not nest.Egg and nest.RefillAt and clock >= nest.RefillAt and not night then
			nest.RefillAt = nil
			local def, mutation = rollEgg(zone.Def, Random.new())
			placeNestEgg(zone, nest, def, mutation, Config.RollScale(Random.new()))
		end
	end
	if not zone.Guardian then
		return
	end
	local target, targetRoot, best = nil, nil, math.huge
	for player, state in states do
		local carry = state.Carry
		if carry and carry.Zone == zone then
			local root = rootOf(player)
			if root then
				local d = (root.Position - zone.Pos).Magnitude
				if d < best then
					target, targetRoot, best = player, root, d
				end
			end
		end
	end
	if target and targetRoot then
		if not zone.Awake then
			zone.WakeAt = clock + 1.5
			setSleeping(zone, false)
		end
		if clock >= (zone.WakeAt or 0) then
			local state = states[target]
			local factor = Config.GuardianFactor(zone.Def, state.Data.Speed, state.Carry.Scale)
			moveGuardian(zone, targetRoot.Position, (state.Walk or 16) * factor, dt)
			local flat = (Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z) - Vector3.new(zone.Pos.X, 0, zone.Pos.Z)).Magnitude
			if flat <= zone.CatchRange then
				catchCarrier(zone, target)
			end
		end
		return
	end
	local home = zone.Home.Position
	if (zone.Pos - home).Magnitude > 0.5 then
		moveGuardian(zone, home, 18, dt)
	elseif zone.Awake then
		zone.Pos = home
		zone.Guardian:SetAttribute("Goal", zone.Home)
		zone.Guardian:SetAttribute("Speed", 0)
		setSleeping(zone, true)
	end
end

---------------------------------------------------------------------
-- OVO DOURADO: a cada 8 minutos aparece um ovo especial (Lendário ou melhor, mutação Gold/Rainbow)
-- num ninho brilhante de uma zona aleatória. Quem roubar primeiro leva!
---------------------------------------------------------------------
local goldNests = {}
local function spawnGoldenEgg()
	if night or #zones == 0 then
		return
	end
	local best = 1
	for _, state in states do
		for index, zone in Config.Zones do
			if state.Data.Speed >= zone.Speed then
				best = math.max(best, index)
			end
		end
	end
	local zoneIndex = math.random(1, math.min(#zones, best + 1))
	local zone = zones[zoneIndex]
	local spot = zone.Center + Vector3.new(math.random(-1, 1) * 26, 0, 30)
	local nest = { CFrame = CFrame.lookAt(spot + Vector3.new(0, 0.6, 0), spot + Vector3.new(0, 0.6, -50)), Egg = nil, Golden = true, Until = os.clock() + 180, Zone = zone }
	local def, mutation = rollEgg(zone.Def, Random.new(), Config.RarityIndex.Legendary)
	if not def then
		return
	end
	mutation = if math.random() < 0.15 then "Rainbow" else "Gold"
	placeNestEgg(zone, nest, def, mutation, Config.RollScale(Random.new()))
	local egg = nest.Egg
	if egg then
		local glow = Instance.new("Highlight")
		glow.FillColor = Color3.fromRGB(255, 215, 60)
		glow.FillTransparency = 0.6
		glow.OutlineColor = Color3.fromRGB(255, 240, 150)
		glow.Parent = egg.Model
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(1.2, 0)
		sparkle.Rate = 25
		sparkle.Lifetime = NumberRange.new(1, 2)
		sparkle.Speed = NumberRange.new(3, 6)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = egg.Root
		local beam = Instance.new("Part")
		beam.Name = "GoldenBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 215, 60)
		beam.Transparency = 0.6
		beam.Size = Vector3.new(3, 160, 3)
		beam.CFrame = CFrame.new(spot + Vector3.new(0, 80, 0))
		beam.Parent = egg.Model
		egg.Model:SetAttribute("Golden", true)
	end
	table.insert(goldNests, nest)
	banner(nil, ("\u{2B50} GOLDEN EGG in %s! Steal it first!"):format(zone.Def.Name), Color3.fromRGB(255, 215, 60))
	toastAll(("\u{2B50} A GOLDEN %s %s Egg spawned in %s!"):format(def.Rarity, def.Name, zone.Def.Name), "rare")
	net:FireAllClients("Sfx", "Alarm")
end

local function tickGoldNests(clock: number)
	for index = #goldNests, 1, -1 do
		local nest = goldNests[index]
		local egg = nest.Egg
		if not egg then
			table.remove(goldNests, index) -- foi roubado e entregue
		elseif not egg.Thief and (clock >= nest.Until or night) then
			removeNestEgg(nest)
			table.remove(goldNests, index)
		elseif egg.LooseUntil and not egg.Thief and clock >= egg.LooseUntil then
			egg.LooseUntil = nil
			egg.Prompt.ActionText = "Steal"
			egg.Model:SetAttribute("Loose", nil)
			egg.Model:PivotTo(nest.CFrame + Vector3.new(0, pivotHeight(egg.Model), 0))
		end
	end
end

local function resetNests(id: number)
	local rare = {}
	local serverRng = Random.new()
	for _, zone in zones do
		for n, nest in zone.Nests do
			if not (nest.Egg and nest.Egg.Thief) then
				local rng = Random.new(id * 1000 + zone.Index * 10 + n)
				local def, mutation = rollEgg(zone.Def, rng)
				if placeNestEgg(zone, nest, def, mutation, Config.RollScale(serverRng)) then
					table.insert(rare, ("A %s %s Egg spawned in %s %s!"):format(def.Rarity, def.Name, zone.Def.Name, zone.Def.Emoji or ""))
				end
				nest.RefillAt = nil
			end
		end
	end
	banner(nil, if #rare > 0 then "ALL NESTS REFILLED!" else "ALL NESTS REFILLED!\nNothing rare spawned.", Color3.fromRGB(255, 255, 255))
	for _, text in rare do
		toastAll("\u{1F95A} " .. text, "rare")
	end
end

---------------------------------------------------------------------
-- Noite e dia
---------------------------------------------------------------------
local function setNight(on: boolean)
	night = on
	workspace:SetAttribute("Night", on)
	local wall = World.NightWall
	TweenService:Create(wall, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { CFrame = CFrame.new(0, if on then 45 else -46, 6) }):Play()
	wall.CanCollide = on
	-- as telas do muro só aparecem com ele em pé (senão aparecem através do chão)
	for _, item in wall:GetChildren() do
		if item:IsA("SurfaceGui") then
			if on then
				item.Enabled = true
			else
				task.delay(1.2, function()
					if not night then
						item.Enabled = false
					end
				end)
			end
		end
	end
	TweenService:Create(Lighting, TweenInfo.new(1.5), { ClockTime = if on then 0 else 14 }):Play()
	if on then
		for player, state in states do
			if state.Carry then
				endCarry(player, false)
			end
			local root = rootOf(player)
			if root and root.Position.Z > 0 and state.Plot then
				player.Character:PivotTo(state.Plot.Spawn)
				net:FireClient(player, "NightTeleport")
			end
		end
		for _, zone in zones do
			for _, nest in zone.Nests do
				removeNestEgg(nest)
				nest.RefillAt = nil
			end
		end
		banner(nil, "Night has fallen! Eggs grow x30!", Color3.fromRGB(150, 170, 255))
	end
end

---------------------------------------------------------------------
-- Lojinhas, Index, Fuse, baú
---------------------------------------------------------------------
local function upgrade(player: Player, what: string)
	local state = states[player]
	local data = state.Data
	if what == "Pen" then
		local info = Config.PenLevels[data.PenLevel + 1]
		if not info then
			return toast(player, "Your pen is at MAX level!", "info")
		end
		if data.Money < info.Cost then
			return toast(player, "Not enough money! You need " .. Format.Money(info.Cost), "error")
		end
		data.Money -= info.Cost
		data.PenLevel += 1
		funnel(player, "Pen")
		if state.Plot then
			World.BuildPen(state.Plot, data.PenLevel)
		end
		toast(player, if data.PenLevel == Config.TreadmillUnlockPen then "Pen Level 1! Your TREADMILL is unlocked - run on it to get faster!" else ("Pen upgraded! Now %d slots."):format(Config.SlotCount(data.PenLevel)), "success")
		net:FireClient(player, "Purchased")
	elseif what == "Treadmill" then
		if data.PenLevel < Config.TreadmillUnlockPen then
			return toast(player, "Unlock Pen Level 1 first!", "warning")
		end
		local info = Config.Treadmills[data.TreadLevel + 1]
		if not info then
			return toast(player, "Your treadmill is at MAX level!", "info")
		end
		if data.Money < info.Cost then
			return toast(player, "Not enough money! You need " .. Format.Money(info.Cost), "error")
		end
		data.Money -= info.Cost
		data.TreadLevel += 1
		funnel(player, "Treadmill")
		toast(player, ("%s Treadmill! +%s speed per step."):format(info.Name, Format.Short(info.Gain)), "success")
		net:FireClient(player, "Purchased")
	end
	publish(player)
end

local function buyTrail(player: Player, id: string)
	local state = states[player]
	local data = state.Data
	local trail = Config.TrailById[id]
	if not trail then
		return
	end
	if not table.find(data.Trails, id) then
		if data.Money < trail.Cost then
			return toast(player, "Not enough money! You need " .. Format.Money(trail.Cost), "error")
		end
		data.Money -= trail.Cost
		table.insert(data.Trails, id)
		toast(player, ("You bought the %s! (x%s treadmill speed)"):format(trail.Name, tostring(trail.Mult)), "success")
		net:FireClient(player, "Purchased")
	end
	data.Trail = id
	applyTrail(player)
	publish(player, true)
end

local function boostPrice(state, boost): number
	return math.max(boost.MinPrice, math.floor((state.Income or 0) * 60 * boost.Price))
end

local function buyBoost(player: Player, id: string)
	local state = states[player]
	local data = state.Data
	local boost
	for _, info in Config.Boosts do
		if info.Id == id then
			boost = info
		end
	end
	if not boost then
		return
	end
	local price = boostPrice(state, boost)
	if data.Money < price then
		return toast(player, "Not enough money! You need " .. Format.Money(price), "error")
	end
	data.Money -= price
	local start = math.max(now(), data.Boosts[id] or 0)
	data.Boosts[id] = start + boost.Minutes * 60
	toast(player, ("%s %s active! (+%d minutes)"):format(boost.Icon, boost.Name, boost.Minutes), "success")
	net:FireClient(player, "Purchased")
	computeIncome(state)
	publish(player, true)
end

-- id da nossa comunidade (grupo). Config.CommunityId tem prioridade; se for 0 e o jogo for de um grupo, usa o grupo dono do jogo.
local function communityId(): number
	if (Config.CommunityId or 0) > 0 then
		return Config.CommunityId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		return game.CreatorId
	end
	return 0
end

-- confere se está na comunidade agora (GetGroupsAsync não usa cache, então quem acabou de entrar já conta)
local function inCommunity(player: Player): boolean
	local groupId = communityId()
	if groupId == 0 then
		return true -- sem comunidade configurada: o baú fica liberado para todo mundo
	end
	local ok, groups = pcall(function()
		return game:GetService("GroupService"):GetGroupsAsync(player.UserId)
	end)
	if ok and type(groups) == "table" then
		for _, info in groups do
			if info.Id == groupId then
				return true
			end
		end
		return false
	end
	local ok2, result = pcall(player.IsInGroup, player, groupId)
	return ok2 and result == true
end

local function claimChest(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local data = state.Data
	local readyAt = (data.ChestAt or 0) + Config.ChestEvery
	if now() < readyAt then
		local left = readyAt - now()
		return toast(player, ("The FREE chest opens again in %dm %ds"):format(left // 60, left % 60), "info")
	end
	-- BAÚ DA COMUNIDADE: só abre para quem está no nosso grupo (a tela abre o convite para entrar)
	if not inCommunity(player) then
		toast(player, "\u{1F381} Join our community to open the FREE chest!", "warning")
		net:FireClient(player, "JoinCommunity", communityId())
		return
	end
	data.ChestAt = now()
	local cash = math.max(Config.ChestMinCash, math.floor((state.Income or 0) * 60 * Config.ChestMinutes))
	local speed = math.max(Config.ChestMinSpeed, (state.Gain or 2) * Config.ChestSpeedSteps)
	data.Money += cash
	data.Speed += speed
	applySpeed(player)
	banner(player, ("FREE CHEST! +%s  +%s Speed"):format(Format.Money(cash), Format.Short(speed)), Color3.fromRGB(120, 255, 120))
	net:FireClient(player, "Purchased")
	net:FireClient(player, "ChestOpened")
	publish(player)
end

local function claimIndex(player: Player, id: string?): number
	local state = states[player]
	local data = state.Data
	local claimed = 0
	local cashTotal, speedTotal = 0, 0
	for petId, zoneIndex in data.Index do
		if not data.Claimed[petId] and (id == nil or id == petId) then
			local def = Critters.ById[petId]
			if def then
				local cash, speed = Config.IndexReward(def, if typeof(zoneIndex) == "number" then zoneIndex else zoneOfDef[petId])
				data.Claimed[petId] = true
				cashTotal += cash
				speedTotal += speed
				claimed += 1
			end
		end
	end
	if claimed > 0 then
		data.Money += cashTotal
		data.Speed += speedTotal
		applySpeed(player)
		toast(player, ("Index reward! +%s  +%s Speed"):format(Format.Money(cashTotal), Format.Short(speedTotal)), "success")
		net:FireClient(player, "Purchased")
		publish(player, true)
	end
	return claimed
end

local function fuse(player: Player, indices: any)
	local state = states[player]
	local data = state.Data
	if type(indices) ~= "table" or #indices ~= Config.FuseCount then
		return
	end
	local seen, slots, rarity, bestZone = {}, {}, nil, 1
	for _, index in indices do
		if type(index) ~= "number" or seen[index] then
			return
		end
		seen[index] = true
		local slot = data.Slots[index]
		local def = slot and Critters.ById[slot.Id]
		if not slot or slot.Kind ~= "Pet" or not def then
			return toast(player, "Pick 3 hatched pets!", "error")
		end
		if rarity and def.Rarity ~= rarity then
			return toast(player, "All 3 pets must have the SAME rarity!", "error")
		end
		rarity = def.Rarity
		bestZone = math.max(bestZone, slot.Zone or 1)
		table.insert(slots, slot)
	end
	local nextIndex = (Config.RarityIndex[rarity] or 1) + 1
	local nextRarity = Config.Rarities[nextIndex]
	if not nextRarity or (Config.RarityIndex[nextRarity.Name] or 0) >= Config.RarityIndex.Divine then
		return toast(player, "These pets are too rare to fuse!", "warning")
	end
	-- bichinho da raridade de cima, da melhor zona que tiver essa raridade
	local result, zoneIndex = nil, bestZone
	for z = bestZone, 1, -1 do
		local list = poolFor(Config.Zones[z], nextRarity.Name)
		if #list > 0 then
			result = list[math.random(1, #list)]
			zoneIndex = z
			break
		end
	end
	if not result then
		for z = bestZone + 1, #Config.Zones do
			local list = poolFor(Config.Zones[z], nextRarity.Name)
			if #list > 0 then
				result, zoneIndex = list[math.random(1, #list)], z
				break
			end
		end
	end
	if not result then
		return toast(player, "Nothing to fuse into right now.", "warning")
	end
	table.sort(indices, function(a, b)
		return a > b
	end)
	for _, index in indices do
		table.remove(data.Slots, index)
	end
	table.insert(data.Slots, { Kind = "Egg", Id = result.Id, Scale = 1, Zone = zoneIndex, Left = 0, Mut = rollMutation(Random.new()) })
	redrawPen(player)
	computeIncome(state)
	banner(player, ("FUSED! A %s egg is ready to hatch!"):format(string.upper(nextRarity.Name)), nextRarity.Color)
	net:FireClient(player, "Purchased")
	publish(player, true)
end


---------------------------------------------------------------------
-- PvP: TACO e ARMADILHAS (igual ao jogo de referência)
---------------------------------------------------------------------
local trapsFolder: Folder
local traps = {} -- { Model, Owner, Pos, Until }

local function inSafeZone(position: Vector3): boolean
	return position.Z < 2
end

local function sfxAt(name: string, position: Vector3)
	net:FireAllClients("SfxAt", name, position)
end

local function stun(player: Player, seconds: number, fling: Vector3?)
	local state = states[player]
	local humanoid = humanoidOf(player)
	local root = rootOf(player)
	if not state or not humanoid or not root then
		return
	end
	state.StunUntil = os.clock() + seconds
	if state.Carry then
		endCarry(player, false, true) -- larga o ovo no chão
		toast(player, "You got hit and DROPPED the egg! Grab it back!", "warning")
	end
	applySpeed(player)
	if fling then
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = fling
	end
	net:FireClient(player, "Stunned", seconds, fling)
	task.delay(seconds, function()
		if states[player] and (states[player].StunUntil or 0) <= os.clock() + 0.05 then
			if humanoid.Parent then
				humanoid.PlatformStand = false
			end
			applySpeed(player)
		end
	end)
end

-- taco (Tool): a tela manda "Swing" quando clica; o servidor confere tudo
local function batInfo(state)
	return Config.Bats[state.Data.Bat or 0] or Config.Bats[0]
end

local function zoneComplete(state, zoneIndex: number): boolean
	local zone = Config.Zones[zoneIndex]
	if not zone then
		return false
	end
	local any = false
	for _, rarity in zone.Rarities do
		for _, def in poolFor(zone, rarity) do
			any = true
			if not state.Data.Index[def.Id] then
				return false
			end
		end
	end
	return any
end


-- monta o taco a partir do modelo do Toolbox (Tool ou Model). Devolve nil se não existir.
function buildToolboxBat(info, glow: boolean): Tool?
	local folder = game:GetService("ServerStorage"):FindFirstChild("ToolboxAssets")
	local source = folder and folder:FindFirstChild("Bat")
	if not source then
		return nil
	end
	local ok, result = pcall(function()
		local tool: Tool
		if source:IsA("Tool") then
			tool = source:Clone()
		else
			local model = source:Clone() :: Model
			-- tamanho padrão: 4.6 studs de comprimento
			local _, size = model:GetBoundingBox()
			local longest = math.max(size.X, size.Y, size.Z)
			if longest > 0.1 then
				pcall(function()
					model:ScaleTo(model:GetScale() * 4.6 / longest)
				end)
			end
			local parts = {}
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					table.insert(parts, item)
				end
			end
			if #parts == 0 then
				return nil
			end
			local handle = model:FindFirstChild("Handle", true)
			if not (handle and handle:IsA("BasePart")) then
				handle = parts[1]
				for _, part in parts do
					if part.Size.X * part.Size.Y * part.Size.Z > handle.Size.X * handle.Size.Y * handle.Size.Z then
						handle = part
					end
				end
			end
			-- eixo comprido do taco (no espaço do Handle) e de que lado fica a parte pesada
			local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
			local massSum, weighted = 0, Vector3.zero
			for _, part in parts do
				local rel = handle.CFrame:ToObjectSpace(part.CFrame)
				local half = part.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner = rel * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
							minV = minV:Min(corner)
							maxV = maxV:Max(corner)
						end
					end
				end
				local volume = part.Size.X * part.Size.Y * part.Size.Z
				massSum += volume
				weighted += rel.Position * volume
			end
			local extent = maxV - minV
			local axis = if extent.X >= extent.Y and extent.X >= extent.Z then "X" elseif extent.Y >= extent.Z then "Y" else "Z"
			local centroid = weighted / math.max(massSum, 1e-3)
			local lo, hi = (minV :: any)[axis], (maxV :: any)[axis]
			local mid = (lo + hi) / 2
			-- a mão segura o lado mais leve, a 12% da ponta
			local gripAt = if (centroid :: any)[axis] > mid then lo + (hi - lo) * 0.12 else hi - (hi - lo) * 0.12
			local upSign = if (centroid :: any)[axis] > mid then 1 else -1
			local center = (minV + maxV) / 2
			local gripPos = Vector3.new(if axis == "X" then gripAt else center.X, if axis == "Y" then gripAt else center.Y, if axis == "Z" then gripAt else center.Z)
			local rot
			if axis == "Y" then
				rot = if upSign > 0 then CFrame.identity else CFrame.Angles(math.pi, 0, 0)
			elseif axis == "X" then
				rot = if upSign > 0 then CFrame.Angles(0, 0, -math.pi / 2) else CFrame.Angles(0, 0, math.pi / 2)
			else
				rot = if upSign > 0 then CFrame.Angles(math.pi / 2, 0, 0) else CFrame.Angles(-math.pi / 2, 0, 0)
			end
			tool = Instance.new("Tool")
			for _, part in parts do
				if part ~= handle then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = part
					weld.Parent = part
				end
				part.Parent = tool
			end
			handle.Name = "Handle"
			tool.Grip = CFrame.new(gripPos) * rot
			model:Destroy()
		end
		for _, item in tool:GetDescendants() do
			if item:IsA("BaseScript") or item:IsA("ModuleScript") or item:IsA("Sound") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored = false
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.Massless = true
			end
		end
		tool.Name = info.Name
		tool:SetAttribute("GameTool", "Bat")
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool.ToolTip = "Hit players carrying eggs to make them DROP it!"
		local handle = tool:FindFirstChild("Handle")
		if handle then
			-- rastro do golpe
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.6, 0)
			a0.Parent = handle
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, 2.4, 0)
			a1.Parent = handle
			local trail = Instance.new("Trail")
			trail.Name = "SwingTrail"
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.15
			trail.Transparency = NumberSequence.new(0.4, 1)
			trail.Color = ColorSequence.new(Color3.new(1, 1, 1), info.Color or Color3.new(1, 1, 1))
			trail.Enabled = false
			trail.Parent = handle
			if glow then
				local light = Instance.new("PointLight")
				light.Color = info.Color or Color3.new(1, 1, 1)
				light.Range = 6
				light.Parent = handle
			end
		end
		return tool
	end)
	if ok and result then
		return result
	end
	if not ok then
		warn("[Game] taco do Toolbox falhou:", result)
	end
	return nil
end

local function giveTools(player: Player)
	local state = states[player]
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not state or not backpack then
		return
	end
	for _, holder in { backpack, player.Character } do
		if holder then
			for _, item in holder:GetChildren() do
				if item:IsA("Tool") and item:GetAttribute("GameTool") then
					item:Destroy()
				end
			end
		end
	end
	local info = batInfo(state)
	-- TACO DO TOOLBOX: se existir ServerStorage > ToolboxAssets > "Bat", usa ele (fica bem mais bonito)
	local fancy = buildToolboxBat(info, (state.Data.Bat or 0) > 0)
	if fancy then
		fancy.Parent = backpack
	end
	local bat = Instance.new("Tool")
	bat.Name = info.Name
	bat:SetAttribute("GameTool", "Bat")
	bat.CanBeDropped = false
	bat.ToolTip = "Hit players carrying eggs to make them DROP it!"
	bat.Grip = CFrame.new(0, -1.4, 0) * CFrame.Angles(0, 0, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 4.2, 0.5)
	handle.Color = info.Color
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = bat
	local tip = Instance.new("Part")
	tip.Name = "Barrel"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.9, 0.9, 0.9)
	tip.Color = info.Color:Lerp(Color3.new(1, 1, 1), 0.15)
	tip.Material = Enum.Material.Wood
	tip.CanCollide = false
	tip.Massless = true
	tip.CFrame = handle.CFrame * CFrame.new(0, 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = tip
	tip.Parent = bat
	if (state.Data.Bat or 0) > 0 then
		local glow = Instance.new("PointLight")
		glow.Color = info.Color
		glow.Range = 6
		glow.Parent = tip
	end
	-- rastro do golpe (liga só durante a tacada)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -0.4, 0)
	a0.Parent = tip
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0.4, 0)
	a1.Parent = tip
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.15
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.Enabled = false
	trail.Parent = tip
	if fancy then
		bat:Destroy()
	else
		bat.Parent = backpack
	end

	local trap = Instance.new("Tool")
	trap.Name = "Bear Trap"
	trap:SetAttribute("GameTool", "Trap")
	trap.CanBeDropped = false
	trap.ToolTip = "Place a trap: catches players carrying eggs (not in the Safe Zone)"
	trap.Grip = CFrame.new(0, 0, -0.6)
	local disc = Instance.new("Part")
	disc.Name = "Handle"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.4, 2.2, 2.2)
	disc.Color = Color3.fromRGB(110, 110, 120)
	disc.Material = Enum.Material.Metal
	disc.CanCollide = false
	disc.Massless = true
	disc.Parent = trap
	trap.Parent = backpack
end

local function swing(player: Player)
	local state = states[player]
	local root = rootOf(player)
	if not state or not root or state.Carry or (state.StunUntil or 0) > os.clock() then
		return
	end
	local clock = os.clock()
	if clock - (state.LastSwing or 0) < Config.Bat.Cooldown then
		return
	end
	state.LastSwing = clock
	local info = batInfo(state)
	net:FireAllClients("Swing", player)
	sfxAt("Swing", root.Position)
	local character = player.Character
	local trail = character and character:FindFirstChild("SwingTrail", true)
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		task.delay(0.35, function()
			trail.Enabled = false
		end)
	end
	for other, otherState in states do
		local otherRoot = rootOf(other)
		if other ~= player and otherRoot and not inSafeZone(otherRoot.Position) then
			local offset = otherRoot.Position - root.Position
			local flat = offset * Vector3.new(1, 0, 1)
			if flat.Magnitude <= info.Range and (flat.Magnitude < 2 or flat.Unit:Dot(root.CFrame.LookVector * Vector3.new(1, 0, 1)) > 0.2) then
				local dir = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
				local wasCarrying = otherState.Carry ~= nil
				if wasCarrying then
					questAdd(player, "Hit")
				end
				stun(other, info.Stun, dir * info.Force + Vector3.new(0, 32, 0))
				sfxAt("Hit", otherRoot.Position)
				-- estrelinhas no acerto + aviso para quem bateu
				pcall(function()
					local spark = Instance.new("Attachment")
					spark.Parent = otherRoot
					local emitter = Instance.new("ParticleEmitter")
					emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					emitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80))
					emitter.LightEmission = 1
					emitter.Size = NumberSequence.new(1.2, 0)
					emitter.Speed = NumberRange.new(10, 18)
					emitter.SpreadAngle = Vector2.new(180, 180)
					emitter.Lifetime = NumberRange.new(0.4, 0.7)
					emitter.Rate = 0
					emitter.Parent = spark
					emitter:Emit(25)
					game:GetService("Debris"):AddItem(spark, 1)
				end)
				if wasCarrying then
					toast(player, ("BONK! %s dropped the egg - grab it!"):format(other.DisplayName), "success")
				end
			end
		end
	end
end

local function buildTrapModel(position: Vector3, owner: Player): Model
	local model = Instance.new("Model")
	model.Name = "BearTrap"
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.3, 4.4, 4.4)
	base.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(95, 95, 105)
	base.Material = Enum.Material.Metal
	base.Parent = model
	for k = 0, 9 do
		local a = math.rad(k * 36)
		local spike = Instance.new("WedgePart")
		spike.Name = "Spike"
		spike.Size = Vector3.new(0.3, 0.9, 0.5)
		spike.CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 1.8, 0.65, math.sin(a) * 1.8)) * CFrame.Angles(0, -a + math.pi / 2, 0)
		spike.Color = Color3.fromRGB(200, 200, 210)
		spike.Material = Enum.Material.Metal
		spike.Parent = model
	end
	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Shape = Enum.PartType.Cylinder
	plate.Size = Vector3.new(0.35, 1.6, 1.6)
	plate.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	plate.Color = Color3.fromRGB(200, 60, 60)
	plate.Material = Enum.Material.Neon
	plate.Parent = model
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	model:SetAttribute("Owner", owner.UserId)
	model.Parent = trapsFolder
	return model
end

local function trapLimit(state): number
	return Config.Trap.Max + (if state.Passes and state.Passes.VIP then 1 else 0)
end

local function placeTrap(player: Player)
	local state = states[player]
	local root = rootOf(player)
	if not state or not root or night then
		return
	end
	local spot = root.Position + root.CFrame.LookVector * 4
	spot = Vector3.new(spot.X, 0, spot.Z)
	if inSafeZone(spot) then
		return toast(player, "You can't place traps in the SAFE ZONE!", "error")
	end
	if (state.TrapCount or 0) >= trapLimit(state) then
		return toast(player, ("You can only have %d traps out!"):format(trapLimit(state)), "warning")
	end
	state.TrapCount = (state.TrapCount or 0) + 1
	table.insert(traps, { Model = buildTrapModel(spot, player), Owner = player, Pos = spot, Until = os.clock() + Config.Trap.Life })
	sfxAt("Trap", spot)
	publish(player)
end

local function removeTrap(index: number)
	local trap = table.remove(traps, index)
	if trap then
		if trap.Model then
			trap.Model:Destroy()
		end
		local state = states[trap.Owner]
		if state then
			state.TrapCount = math.max(0, (state.TrapCount or 1) - 1)
			publish(trap.Owner)
		end
	end
end

local function tickTraps(clock: number)
	for index = #traps, 1, -1 do
		local trap = traps[index]
		local removed = false
		if clock >= trap.Until or not trap.Owner.Parent or night then
			removeTrap(index)
			removed = true
		end
		if not removed then
			for player, state in states do
				local root = rootOf(player)
				if player ~= trap.Owner and state.Carry and root then
					local flat = (Vector3.new(root.Position.X, 0, root.Position.Z) - trap.Pos).Magnitude
					if flat <= Config.Trap.Radius then
						sfxAt("Trap", trap.Pos)
						stun(player, Config.Trap.Stun)
						if trap.Owner:IsA("Player") then
							toast(trap.Owner, ("Your trap caught %s!"):format(player.DisplayName), "success")
						end
						removeTrap(index)
						break
					end
				end
			end
		end
	end
end

-- ovos soltos que ninguém pegou voltam para o ninho
local function tickLooseEggs(clock: number)
	for _, zone in zones do
		for _, nest in zone.Nests do
			local egg = nest.Egg
			if egg and egg.LooseUntil and not egg.Thief and clock >= egg.LooseUntil and egg.Model.Parent then
				egg.LooseUntil = nil
				egg.Prompt.ActionText = "Steal"
				egg.Model:SetAttribute("Loose", nil)
				egg.Model:PivotTo(nest.CFrame + Vector3.new(0, pivotHeight(egg.Model), 0))
			end
		end
	end
end

local function equipBat(player: Player, zoneIndex: any)
	local state = states[player]
	if type(zoneIndex) ~= "number" or not Config.Bats[zoneIndex] then
		return
	end
	if zoneIndex > 0 and not zoneComplete(state, zoneIndex) then
		return toast(player, "Complete this zone's Index to unlock its bat!", "warning")
	end
	state.Data.Bat = zoneIndex
	giveTools(player)
	toast(player, ("%s equipped!"):format(Config.Bats[zoneIndex].Name), "success")
	net:FireClient(player, "Purchased")
	publish(player, true)
end

---------------------------------------------------------------------
-- ROBUX: passes e produtos
---------------------------------------------------------------------
local function bestZoneFor(state): number
	local best = 1
	for index, zone in Config.Zones do
		if state.Data.Speed >= zone.Speed then
			best = index
		end
	end
	return best
end

local function addEggSlot(player: Player, def, zoneIndex: number, scale: number, mutation: string?, ready: boolean): boolean
	local state = states[player]
	local data = state.Data
	if #data.Slots >= Config.SlotCount(data.PenLevel) then
		local cash = Config.SellValue(def, scale, mutation, zoneIndex) * 10
		data.Money += cash
		toast(player, ("Pen full! You got %s instead."):format(Format.Money(cash)), "warning")
		return false
	end
	table.insert(data.Slots, { Kind = "Egg", Id = def.Id, Scale = scale, Mut = mutation, Zone = zoneIndex, Left = if ready then 0 else Config.GrowSeconds(def, scale) })
	renderSlot(player, #data.Slots)
	return true
end

-- PRESENTES POR TEMPO JOGADO
local function claimGift(player: Player, index: any)
	local state = states[player]
	local info = type(index) == "number" and Config.Gifts[index]
	if not state or not info then
		return
	end
	state.GiftsClaimed = state.GiftsClaimed or {}
	if state.GiftsClaimed[index] then
		return
	end
	local played = os.time() - (state.SessionStart or os.time())
	if played < info.Minutes * 60 then
		local left = info.Minutes * 60 - played
		return toast(player, ("This gift opens in %dm %ds"):format(left // 60, left % 60), "info")
	end
	state.GiftsClaimed[index] = true
	local data = state.Data
	local cash = math.max(info.MinCash, math.floor((state.Income or 0) * 60 * info.Cash))
	data.Money += cash
	data.Speed += info.Speed
	applySpeed(player)
	local extra = ""
	if info.Egg then
		local zoneIndex = bestZoneFor(state)
		local def, mutation = rollEgg(Config.Zones[zoneIndex], Random.new(), Config.RarityIndex.Rare)
		if def and #data.Slots < Config.SlotCount(data.PenLevel) then
			addEggSlot(player, def, zoneIndex, Config.RollScale(Random.new()), mutation, true)
			extra = "  + " .. def.Rarity .. " egg!"
		end
	end
	local list = {}
	for i in state.GiftsClaimed do
		table.insert(list, tostring(i))
	end
	player:SetAttribute("GiftsClaimed", table.concat(list, ","))
	banner(player, ("GIFT! +%s  +%s Speed%s"):format(Format.Money(cash), Format.Short(info.Speed), extra), Color3.fromRGB(255, 120, 200))
	net:FireClient(player, "Purchased")
	publish(player, true)
end

local function grantProduct(player: Player, key: string)
	local state = states[player]
	local data = state.Data
	local info = Config.ProductByKey[key]
	if not info then
		return false
	end
	if info.Speed then
		data.Speed += info.Speed
		applySpeed(player)
		banner(player, ("+%s SPEED!"):format(Format.Short(info.Speed)), Color3.fromRGB(255, 80, 140))
	elseif key == "GrowAll" then
		-- Instant Hatch: todos os ovos chocam agora
		local list = {}
		for index, slot in data.Slots do
			if slot.Kind == "Egg" then
				slot.Left = 0
				if hatch(player, index, true) then
					table.insert(list, { slot.Id, slot.Mut, slot.Scale or 1, slot.Zone or 1 })
				end
			end
		end
		if #list > 0 then
			net:FireClient(player, "Hatched", list)
		end
		banner(player, ("INSTANT HATCH! %d eggs hatched!"):format(#list), Color3.fromRGB(255, 220, 80))
	elseif key == "Money2Boost" then
		local start = math.max(now(), data.Boosts.Money2 or 0)
		data.Boosts.Money2 = start + 30 * 60
		computeIncome(state)
		banner(player, "2x CASH for 30 minutes!", Color3.fromRGB(110, 255, 90))
	elseif key == "Cash" then
		local cash = math.max(50_000, math.floor((state.Income or 0) * 3600))
		data.Money += cash
		banner(player, "+" .. Format.Money(cash), Color3.fromRGB(110, 255, 90))
	elseif key == "Starter" then
		data.StarterBought = true
		local zoneIndex = bestZoneFor(state)
		local def, mutation = rollEgg(Config.Zones[zoneIndex], Random.new(), Config.RarityIndex.Epic)
		if def then
			addEggSlot(player, def, zoneIndex, Config.RollScale(Random.new()), mutation, true)
		end
		local cash = 50_000
		data.Money += cash
		local start = math.max(now(), data.Boosts.Money2 or 0)
		data.Boosts.Money2 = start + 15 * 60
		computeIncome(state)
		banner(player, "STARTER PACK! +$50K  + Royal Egg  + 2x Cash 15 min!", Color3.fromRGB(255, 150, 60))
	elseif key == "LuckyEgg" then
		local zoneIndex = bestZoneFor(state)
		local def, mutation = rollEgg(Config.Zones[zoneIndex], Random.new(), Config.RarityIndex.Epic)
		if def then
			addEggSlot(player, def, zoneIndex, Config.RollScale(Random.new()), mutation, true)
			banner(player, ("Lucky Egg: %s %s!"):format(def.Rarity, def.Name), rarityColor(def))
		end
	end
	net:FireClient(player, "Purchased")
	publish(player, true)
	return true
end

local function applyPasses(player: Player)
	local state = states[player]
	state.Passes = state.Passes or {}
	for _, info in Config.Passes do
		if info.Id and info.Id > 0 and not state.Passes[info.Key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, info.Id)
			if ok and owns then
				state.Passes[info.Key] = true
			end
		end
	end
	computeIncome(state)
	publish(player, true)
end

local function buy(player: Player, key: any)
	if type(key) ~= "string" then
		return
	end
	local pass = Config.PassByKey[key]
	local product = Config.ProductByKey[key]
	local info = pass or product
	if not info then
		return
	end
	if not info.Id or info.Id <= 0 then
		return toast(player, "This item isn't set up yet (add its ID in Config.Passes / Config.Products).", "warning")
	end
	if product and product.OneTime and states[player].Data.StarterBought then
		return toast(player, "You already got the Starter Pack!", "info")
	end
	if pass then
		if states[player].Passes and states[player].Passes[key] then
			return toast(player, "You already own this pass!", "info")
		end
		MarketplaceService:PromptGamePassPurchase(player, info.Id)
	else
		MarketplaceService:PromptProductPurchase(player, info.Id)
	end
end

local function setupMarketplace()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, info in Config.Passes do
			if info.Id == passId and states[player] then
				states[player].Passes = states[player].Passes or {}
				states[player].Passes[info.Key] = true
				banner(player, ("%s unlocked! Thank you!"):format(info.Name), Color3.fromRGB(255, 215, 60))
				if info.Key == "VIP" then
					giveTools(player)
				end
				computeIncome(states[player])
				net:FireClient(player, "Purchased")
				publish(player, true)
			end
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local state = player and states[player]
		if not state then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = state.Data
		data.Receipts = data.Receipts or {}
		if table.find(data.Receipts, receipt.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		for _, info in Config.Products do
			if info.Id == receipt.ProductId then
				local ok, err = pcall(grantProduct, player, info.Key)
				if not ok then
					warn("[Robux] grant failed:", err)
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				table.insert(data.Receipts, receipt.PurchaseId)
				while #data.Receipts > 50 do
					table.remove(data.Receipts, 1)
				end
				task.spawn(Data.Save, player)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

---------------------------------------------------------------------
-- Prêmio diário, rebirth, amigos, offline
---------------------------------------------------------------------
local function claimDaily(player: Player)
	local state = states[player]
	local data = state.Data
	local today = os.time() // 86400
	if (data.DailyDay or 0) >= today then
		return toast(player, "You already claimed today's reward. Come back tomorrow!", "info")
	end
	local streak = if (data.DailyDay or 0) == today - 1 then (data.DailyStreak or 0) % #Config.Daily + 1 else 1
	local reward = Config.Daily[streak]
	data.DailyDay = today
	data.DailyStreak = streak
	local cash = math.max(reward.MinCash, math.floor((state.Income or 0) * 60 * reward.Minutes))
	if state.Passes and state.Passes.VIP then
		cash *= 2 -- VIP: prêmio diário em dobro
	end
	data.Money += cash
	data.Speed += reward.Speed
	applySpeed(player)
	banner(player, ("DAY %d REWARD! +%s  +%s Speed"):format(streak, Format.Money(cash), Format.Short(reward.Speed)), Color3.fromRGB(120, 255, 120))
	if reward.Egg then
		local zoneIndex = bestZoneFor(state)
		local def, mutation = rollEgg(Config.Zones[zoneIndex], Random.new(), Config.RarityIndex.Rare)
		if def then
			addEggSlot(player, def, zoneIndex, 1, mutation, true)
		end
	end
	net:FireClient(player, "Purchased")
	publish(player, true)
end

local function rebirth(player: Player)
	local state = states[player]
	local data = state.Data
	local cost = Config.RebirthCost(data.Rebirths or 0)
	if data.Money < cost then
		return toast(player, "You need " .. Format.Money(cost) .. " to Rebirth!", "error")
	end
	if state.Carry then
		endCarry(player, false)
	end
	data.Rebirths = (data.Rebirths or 0) + 1
	data.Money = 0
	data.Speed = Config.StartSpeed
	data.TreadLevel = 1
	data.Trails = {}
	data.Trail = nil
	-- REBIRTH agora também leva os bichinhos e os ovos do cercado (fica o cercado, o Index e os passes)
	data.Slots = {}
	redrawPen(player)
	-- presente para recomeçar: 1 ovo pronto Raro ou melhor
	pcall(function()
		local zoneIndex = bestZoneFor(state)
		local def, mutation = rollEgg(Config.Zones[zoneIndex], Random.new(), Config.RarityIndex.Rare)
		if def then
			addEggSlot(player, def, zoneIndex, 1, mutation, true)
		end
	end)
	applySpeed(player)
	applyTrail(player)
	computeIncome(state)
	banner(player, ("REBIRTH %d! +%d%% money forever!"):format(data.Rebirths, math.floor(Config.RebirthMoney * data.Rebirths * 100)), Color3.fromRGB(255, 120, 255))
	toastAll(("\u{1F504} %s just reached Rebirth %d!"):format(player.DisplayName, data.Rebirths), "rare")
	net:FireClient(player, "Purchased")
	publish(player, true)
end

local friendCache: { [string]: boolean } = {}
local function areFriends(a: Player, b: Player): boolean
	local key = if a.UserId < b.UserId then a.UserId .. ":" .. b.UserId else b.UserId .. ":" .. a.UserId
	if friendCache[key] == nil then
		local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
		friendCache[key] = ok and result == true
	end
	return friendCache[key]
end

local function refreshFriendBoosts()
	for player, state in states do
		local count = 0
		for other in states do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end
		local before = state.FriendBoost or 0
		state.FriendBoost = math.min(Config.FriendBoostMax, count * Config.FriendBoost)
		if count > 0 and not state.FriendSince then
			state.FriendSince = os.clock()
		elseif count == 0 then
			state.FriendSince = nil
		end
		if state.FriendBoost > before then
			toast(player, ("\u{1F465} Playing with friends: +%d%% cash! Stay 2 min together for a FREE FRIEND EGG!"):format(math.floor(state.FriendBoost * 100 + 0.5)), "success")
		end
		computeIncome(state)
	end
end

-- etiqueta em cima da cabeça: VIP e rebirths
local function applyTag(player: Player)
	local state = states[player]
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not state or not head then
		return
	end
	local old = head:FindFirstChild("PlayerTag")
	if old then
		old:Destroy()
	end
	local parts = {}
	if state.Passes and state.Passes.VIP then
		table.insert(parts, '<font color="#FFD23C">[VIP]</font>')
	end
	if (state.Data.Rebirths or 0) > 0 then
		table.insert(parts, ('<font color="#FF78FF">\u{1F504} %d</font>'):format(state.Data.Rebirths))
	end
	if #parts == 0 then
		return
	end
	local label = billboard(head, 2.4, 6, 1.2)
	label.Parent.Name = "PlayerTag"
	label.Parent.MaxDistance = 80
	label.Text = table.concat(parts, "  ")
end

local function claimQuest(player: Player, key: any)
	local state = states[player]
	local q = questData(state)
	for _, info in Config.Quests do
		if info.Key == key then
			if q.Claimed[key] then
				return toast(player, "Already claimed!", "info")
			end
			if (q.Progress[key] or 0) < info.Goal then
				return toast(player, "Not finished yet!", "warning")
			end
			q.Claimed[key] = true
			local cash = math.max(info.MinCash, math.floor((state.Income or 0) * 60 * info.Minutes))
			state.Data.Money += cash
			state.Data.Speed += info.Speed
			applySpeed(player)
			banner(player, ("QUEST REWARD! +%s  +%s Speed"):format(Format.Money(cash), Format.Short(info.Speed)), Color3.fromRGB(120, 255, 120))
			net:FireClient(player, "Purchased")
			player:SetAttribute("Quests", questJson(state))
			publish(player)
		end
	end
end

---------------------------------------------------------------------
-- Pedidos da tela
---------------------------------------------------------------------
local lastRequest: { [Player]: number } = {}

local function onRequest(player: Player, action: any, arg: any)
	local state = states[player]
	if not state then
		return
	end
	if action == "Swing" then
		return swing(player)
	end
	local clock = os.clock()
	if clock - (lastRequest[player] or 0) < 0.15 then
		return
	end
	lastRequest[player] = clock
	if action == "Upgrade" and (arg == "Pen" or arg == "Treadmill") then
		upgrade(player, arg)
	elseif action == "SlowMode" then
		player:SetAttribute("SlowMode", arg == true)
		applySpeed(player)
	elseif action == "Hatch" and type(arg) == "number" then
		if hatch(player, arg) then
			publish(player, true)
		end
	elseif action == "HatchAll" then
		local count = 0
		local list = {}
		for index = 1, #state.Data.Slots do
			if hatch(player, index, true) then
				count += 1
				local slot = state.Data.Slots[index]
				table.insert(list, { slot.Id, slot.Mut, slot.Scale or 1, slot.Zone or 1 })
			end
		end
		if count > 0 then
			net:FireClient(player, "Hatched", list)
			banner(player, ("Hatched %d eggs!"):format(count), Color3.fromRGB(255, 225, 80))
			publish(player, true)
		end
	elseif action == "Sell" and type(arg) == "number" then
		local value = sellAt(player, arg)
		if value > 0 then
			toast(player, "Sold for " .. Format.Money(value), "success")
			net:FireClient(player, "Sold", value)
			redrawPen(player)
			computeIncome(state)
			publish(player)
		end
	elseif action == "SellAll" then
		-- vende todos menos Legendary ou melhor e os com mutação (para ninguém perder o que é raro sem querer)
		local total = 0
		for index = #state.Data.Slots, 1, -1 do
			local slot = state.Data.Slots[index]
			local def = Critters.ById[slot.Id]
			if slot.Kind == "Pet" and def and not slot.Mut and (Config.RarityIndex[def.Rarity] or 1) < Config.RarityIndex.Legendary then
				total += sellAt(player, index)
			end
		end
		if total > 0 then
			toast(player, "Sold for " .. Format.Money(total), "success")
			net:FireClient(player, "Sold", total)
			redrawPen(player)
			computeIncome(state)
			publish(player)
		else
			toast(player, "Nothing to sell (Legendary+ and mutated pets are kept).", "info")
		end
	elseif action == "Fuse" then
		fuse(player, arg)
	elseif action == "Trail" and type(arg) == "string" then
		buyTrail(player, arg)
	elseif action == "Boost" and type(arg) == "string" then
		buyBoost(player, arg)
	elseif action == "Chest" then
		claimChest(player)
	elseif action == "Gift" then
		claimGift(player, arg)
	elseif action == "ClaimIndex" then
		claimIndex(player, if type(arg) == "string" then arg else nil)
	elseif action == "PlaceTrap" then
		placeTrap(player)
	elseif action == "EquipBat" then
		equipBat(player, arg)
	elseif action == "Buy" then
		buy(player, arg)
	elseif action == "Daily" then
		claimDaily(player)
	elseif action == "Rebirth" then
		rebirth(player)
	elseif action == "ClaimQuest" then
		claimQuest(player, arg)
	end
end

---------------------------------------------------------------------
-- Placares (OrderedDataStore; sem API usa só quem está no servidor)
---------------------------------------------------------------------
local stores = {}
pcall(function()
	stores.Income = DataStoreService:GetOrderedDataStore("EggRunIncome_v1")
	stores.Speed = DataStoreService:GetOrderedDataStore("EggRunSpeed_v1")
end)

local nameCache: { [number]: string } = {}

local function encodeBig(n: number): number
	-- OrderedDataStore só aceita inteiros: guarda log10 * 1e6
	return math.floor(math.log10(math.max(n, 1)) * 1_000_000)
end

local function decodeBig(v: number): number
	return 10 ^ (v / 1_000_000)
end

local function refreshLeaderboards()
	for _, board in World.Boards do
		local rows = {}
		local store = stores[board.Kind]
		local ok = false
		if store then
			ok = pcall(function()
				local pages = store:GetSortedAsync(false, 10)
				for _, entry in pages:GetCurrentPage() do
					local userId = tonumber(string.match(entry.key, "%d+"))
					local name = nameCache[userId]
					if not name then
						name = "?"
						pcall(function()
							name = Players:GetNameFromUserIdAsync(userId)
						end)
						nameCache[userId] = name
					end
					table.insert(rows, { name, decodeBig(entry.value) })
				end
			end)
		end
		if not ok or #rows == 0 then
			rows = {}
			for player, state in states do
				table.insert(rows, { player.DisplayName, if board.Kind == "Income" then state.Income or 0 else state.Data.Speed })
			end
			table.sort(rows, function(a, b)
				return a[2] > b[2]
			end)
		end
		local list = board.Gui:FindFirstChild("Rows")
		for r = 1, 10 do
			local label = list and list:FindFirstChild("Row" .. r)
			if label then
				local row = rows[r]
				label.Text = if row then ("%d. %s  -  %s"):format(r, row[1], if board.Kind == "Income" then Format.Money(row[2]) .. "/s" else Format.Short(row[2])) else ""
				label.TextColor3 = if r == 1 then Color3.fromRGB(255, 215, 60) elseif r == 2 then Color3.fromRGB(220, 220, 230) elseif r == 3 then Color3.fromRGB(230, 150, 80) else Color3.new(1, 1, 1)
			end
		end
	end
end

local function saveLeaderboards()
	for player, state in states do
		if stores.Income then
			pcall(function()
				stores.Income:SetAsync("u" .. player.UserId, encodeBig(state.Income or 0))
			end)
		end
		if stores.Speed then
			pcall(function()
				stores.Speed:SetAsync("u" .. player.UserId, encodeBig(state.Data.Speed))
			end)
		end
	end
end

---------------------------------------------------------------------
-- Jogadores
---------------------------------------------------------------------
local function freePlot()
	for _, plot in World.Plots do
		if not plot.Owner then
			return plot
		end
	end
	return nil
end

local function onCharacter(player: Player, character: Model)
	local state = states[player]
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not state or not humanoid then
		return
	end
	if state.Plot then
		task.defer(function()
			character:PivotTo(state.Plot.Spawn)
		end)
	end
	character:WaitForChild("HumanoidRootPart", 10)
	state.StunUntil = nil
	applySpeed(player)
	applyTrail(player)
	task.defer(giveTools, player)
	task.delay(1, applyTag, player)
	humanoid.Died:Connect(function()
		if states[player] and states[player].Carry then
			endCarry(player, false)
		end
	end)
end

local function onPlayerAdded(player: Player)
	local data = Data.Load(player)
	if not player.Parent then
		return
	end
	-- campos novos (saves antigos)
	data.Trails = data.Trails or {}
	data.Boosts = data.Boosts or {}
	data.Claimed = data.Claimed or {}
	data.ChestAt = data.ChestAt or 0
	data.Rebirths = data.Rebirths or 0
	data.Bat = data.Bat or 0
	data.DailyDay = data.DailyDay or 0
	data.DailyStreak = data.DailyStreak or 0
	data.Receipts = data.Receipts or {}
	local away = data.__Away or 0
	data.__Away = nil
	for id, value in data.Index do
		if value == true then
			data.Index[id] = zoneOfDef[id] or 1
		end
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local income = Instance.new("StringValue")
	income.Name = "Money/s"
	income.Parent = stats
	local speed = Instance.new("StringValue")
	speed.Name = "Speed"
	speed.Parent = stats
	stats.Parent = player

	local plot = freePlot()
	local state = { Data = data, Plot = plot, SlotModels = {}, Income = 0, Gain = 0, Carry = nil, Walk = 16, InShop = {}, Passes = {}, TrapCount = 0, FriendBoost = 0 }
	states[player] = state
	funnel(player, "Joined")
	state.SessionStart = os.time()
	state.GiftsClaimed = {}
	player:SetAttribute("SessionStart", workspace:GetServerTimeNow())
	player:SetAttribute("GiftsClaimed", "")
	if plot then
		plot.Owner = player
		plot.OwnerLabel.Text = player.DisplayName .. "'s Pen"
		World.BuildPen(plot, data.PenLevel)
		while #data.Slots > Config.SlotCount(data.PenLevel) do
			table.remove(data.Slots)
		end
		redrawPen(player)
		player:SetAttribute("PlotX", plot.X)
		player:SetAttribute("PlotFront", plot.Front)
	else
		toast(player, "All pens are taken on this server.", "warning")
	end
	computeIncome(state)
	-- ganho offline (uma parte da renda enquanto esteve fora)
	if away > 60 and (state.Income or 0) > 0 then
		local seconds = math.min(away, Config.OfflineMaxHours * 3600)
		local cash = math.floor(state.Income * seconds * Config.OfflineRate)
		if cash > 0 then
			data.Money += cash
			task.delay(4, function()
				if player.Parent then
					banner(player, ("While you were away your pets made %s!"):format(Format.Money(cash)), Color3.fromRGB(110, 255, 90))
				end
			end)
		end
	end
	publish(player, true)
	player:SetAttribute("Quests", questJson(state))
	task.spawn(applyPasses, player)
	task.spawn(function()
		refreshFriendBoosts()
		for other, otherState in states do
			computeIncome(otherState)
			publish(other)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if data.Stolen == 0 then
		task.delay(3, function()
			if player.Parent then
				banner(player, "Run into the FOREST and STEAL an egg!", Color3.fromRGB(255, 225, 80))
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	if state.Carry then
		endCarry(player, false)
	end
	for index = #traps, 1, -1 do
		if traps[index].Owner == player then
			removeTrap(index)
		end
	end
	for index in state.SlotModels do
		clearSlotModel(state, index)
	end
	if state.Plot then
		state.Plot.Owner = nil
		state.Plot.OwnerLabel.Text = "Empty Pen"
		World.BuildPen(state.Plot, 0)
		World.SetTreadmillLocked(state.Plot, true)
		state.Plot.Belt.AssemblyLinearVelocity = Vector3.zero
		state.Plot.Belt:SetAttribute("OwnerId", nil)
		state.Plot.Belt:SetAttribute("Unlocked", nil)
	end
	states[player] = nil
	Data.Release(player)
	refreshFriendBoosts()
end

local function boardPrompt(board: BasePart, plot, what: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Upgrade"
	prompt.ObjectText = what
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	prompt.Triggered:Connect(function(player)
		if plot.Owner == player then
			upgrade(player, what)
		else
			toast(player, "This is not your pen!", "error")
		end
	end)
end

---------------------------------------------------------------------
function Game.Init()
	net = Instance.new("RemoteEvent")
	net.Name = "Net"
	net.Parent = ReplicatedStorage
	net.OnServerEvent:Connect(onRequest)

	World.Build()
	contentsFolder = Instance.new("Folder")
	contentsFolder.Name = "Live"
	contentsFolder.Parent = workspace
	trapsFolder = Instance.new("Folder")
	trapsFolder.Name = "Traps"
	trapsFolder.Parent = workspace
	setupMarketplace()
	-- só no Studio: atalhos para testar PvP sozinho pela barra de comandos (lado do servidor)
	if game:GetService("RunService"):IsStudio() then
		local debugApi = {
			Stun = function(player, seconds, fling)
				stun(player, seconds, fling)
				return states[player] and states[player].Carry ~= nil
			end,
			Trap = function(position: Vector3)
				local dummy = workspace:FindFirstChild("TrapDummyOwner") or Instance.new("Folder")
				dummy.Name = "TrapDummyOwner"
				dummy.Parent = workspace
				table.insert(traps, { Model = buildTrapModel(Vector3.new(position.X, 0, position.Z), Players:GetPlayers()[1]), Owner = dummy, Pos = Vector3.new(position.X, 0, position.Z), Until = os.clock() + 60 })
				return #traps
			end,
			Carrying = function(player)
				return states[player] and states[player].Carry ~= nil
			end,
			Golden = function()
				spawnGoldenEgg()
				return #goldNests
			end,
			Pets = function(player, count)
				local state = states[player]
				for _ = 1, count or 3 do
					local zoneIndex = math.random(1, 4)
					local def, mutation = rollEgg(Config.Zones[zoneIndex], Random.new())
					if def and #state.Data.Slots < Config.SlotCount(state.Data.PenLevel) then
						table.insert(state.Data.Slots, { Kind = "Pet", Id = def.Id, Scale = 1, Mut = mutation, Zone = zoneIndex })
					end
				end
				redrawPen(player)
				computeIncome(state)
				publish(player, true)
				return #state.Data.Slots
			end,
			Money = function(player, amount)
				states[player].Data.Money += amount
				publish(player)
			end,
		}
		local bindable = Instance.new("BindableFunction")
		bindable.Name = "EggDebug"
		bindable.OnInvoke = function(name, ...)
			return debugApi[name](...)
		end
		bindable.Parent = game:GetService("ServerStorage")
	end
	if World.FuseSign then
		World.FuseSign.Text = "3 pets \u{2192} 1 better egg"
	end

	for _, plot in World.Plots do
		boardPrompt(plot.PenBoard, plot, "Pen")
		boardPrompt(plot.TreadBoard, plot, "Treadmill")
		World.SetTreadmillLocked(plot, true)
	end
	if World.ChestPrompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "FREE Chest"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = World.ChestPrompt
		prompt.Triggered:Connect(claimChest)
	end
	for _, info in World.Zones do
		local zone = { Index = info.Index, Def = info.Def, Center = info.Center, Folder = info.Folder, Nests = {}, Awake = false }
		for _, cframe in info.Nests do
			table.insert(zone.Nests, { CFrame = cframe, Egg = nil, RefillAt = nil })
		end
		buildGuardian(zone)
		table.insert(zones, zone)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- loop rápido: guardiões, entrega na SAFE ZONE, esteiras, lojinhas
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local clock = os.clock()
			local dt = math.min(clock - last, 0.5)
			last = clock
			for _, zone in zones do
				local ok, err = pcall(tickZone, zone, dt, clock)
				if not ok then
					warn("[Game] zone:", err)
				end
			end
			local okTraps, errTraps = pcall(tickTraps, clock)
			if not okTraps then
				warn("[Game] traps:", errTraps)
			end
			pcall(tickLooseEggs, clock)
			pcall(tickGoldNests, clock)
			for player, state in states do
				local root = rootOf(player)
				if state.Carry and root then
					local carry = state.Carry
					if not carry.Egg.Model.Parent or not carry.Weld.Parent then
						endCarry(player, false)
					elseif root.Position.Z < -1 then
						deliver(player)
					end
				end
				-- chão da esteira anda para +Z na velocidade do dono (quem corre olha para -Z)
				-- CORREÇÃO: antes o chão andava na velocidade do jogador (até 150!) e arremessava quem parava ou
				-- virava. Agora o chão NÃO empurra: a tela do dono segura o personagem correndo no lugar.
				if state.Plot then
					local unlocked = state.Data.PenLevel >= Config.TreadmillUnlockPen
					local belt = state.Plot.Belt
					belt.AssemblyLinearVelocity = Vector3.zero
					belt:SetAttribute("OwnerId", player.UserId)
					belt:SetAttribute("Unlocked", unlocked)
				end
				-- entrou numa lojinha: abre a janela dela (uma vez por entrada)
				if root then
					for _, shop in World.Shops do
						local inside = (Vector3.new(root.Position.X, 0, root.Position.Z) - shop.Center).Magnitude <= shop.Radius
						if inside and not state.InShop[shop.Name] then
							state.InShop[shop.Name] = true
							if shop.Name == "Chest" then
								claimChest(player)
							else
								net:FireClient(player, "Open", shop.Name)
							end
						elseif not inside then
							state.InShop[shop.Name] = nil
						end
					end
				end
			end
		end
	end)

	-- loop de 1 segundo: dinheiro, ovos crescendo, esteira, dia/noite
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			local t = os.time()
			local id = t // Config.Cycle
			local phase = t % Config.Cycle
			local isNight = phase >= Config.Cycle - Config.Night
			workspace:SetAttribute("CycleEnd", if isNight then (id + 1) * Config.Cycle else (id + 1) * Config.Cycle - Config.Night)
			-- fim de semana (sáb/dom UTC) = dinheiro x2; evento da sorte a cada 30 min
			local weekday = (t // 86400 + 4) % 7 -- 0 = domingo
			workspace:SetAttribute("Weekend", weekday == 0 or weekday == 6)
			local luckyStart = t - t % Config.LuckyEvery
			local luckyEnd = luckyStart + Config.LuckyLength
			-- ovo dourado a cada 8 minutos (no meio do ciclo, nunca na noite)
			if t % 480 == 150 then
				task.spawn(spawnGoldenEgg)
			end
			if t < luckyEnd then
				if workspace:GetAttribute("LuckyEnd") ~= luckyEnd then
					workspace:SetAttribute("LuckyEnd", luckyEnd)
					banner(nil, "\u{1F340} LUCKY EVENT! Rare eggs x3 for 3 minutes!", Color3.fromRGB(120, 255, 120))
					net:FireAllClients("Sfx", "Alarm")
				end
			end
			if World.NightCountdown then
				World.NightCountdown.Text = if isNight then tostring(Config.Cycle - phase) else ""
			end
			if id ~= cycleId then
				cycleId = id
				if night then
					setNight(false)
				end
				if not isNight then
					local ok, err = pcall(resetNests, id)
					if not ok then
						warn("[Game] reset:", err)
					end
				end
			end
			if isNight and not night then
				setNight(true)
			end
			-- aviso antes da noite (quem estiver nas zonas corre para casa com o ovo)
			if phase == Config.Cycle - Config.Night - 15 then
				banner(nil, "\u{1F319} NIGHT in 15 seconds! Bring your eggs HOME!", Color3.fromRGB(170, 190, 255))
			end
			for player, state in states do
				local data = state.Data
				computeIncome(state)
				if (state.Income or 0) > 0 then
					data.Money += state.Income
				end
				local growth = (if night then Config.NightGrowth else 1) * (if boostOn(state, "Grow2") then 2 else 1) * (if state.Passes and state.Passes.Grow2 then 2 else 1)
				for _, slot in data.Slots do
					if slot.Kind == "Egg" and (slot.Left or 0) > 0 then
						slot.Left = math.max(0, slot.Left - growth)
					end
				end
				updateEggLabels(state)
				-- esteira: em cima dela e andando = ganha velocidade
				local root = rootOf(player)
				local humanoid = humanoidOf(player)
				local plot = state.Plot
				if plot and root and humanoid and not state.Carry and data.PenLevel >= Config.TreadmillUnlockPen then
					local belt = plot.Belt
					local rel = belt.CFrame:PointToObjectSpace(root.Position)
					if math.abs(rel.X) < belt.Size.X / 2 + 0.5 and math.abs(rel.Z) < belt.Size.Z / 2 + 0.5 and rel.Y < 7 and humanoid.MoveDirection.Magnitude > 0.1 then
						local gain = computeGain(state)
						data.Speed += gain
						applySpeed(player)
						net:FireClient(player, "Step", gain)
						questAdd(player, "Steps")
					end
				end
				-- OVO DA AMIZADE: 2 minutos jogando com um amigo = ovo Raro+ pronto (1 por dia)
				if state.FriendSince and os.clock() - state.FriendSince >= Config.FriendEggSeconds then
					local today = os.time() // 86400
					if (data.FriendEggDay or 0) < today and #data.Slots < Config.SlotCount(data.PenLevel) then
						data.FriendEggDay = today
						local zoneIndex = bestZoneFor(state)
						local def, mutation = rollEgg(Config.Zones[zoneIndex], Random.new(), Config.RarityIndex.Rare)
						if def then
							addEggSlot(player, def, zoneIndex, Config.RollScale(Random.new()), mutation, true)
							banner(player, ("FRIEND EGG! A %s %s egg is ready in your pen!"):format(def.Rarity, def.Name), Color3.fromRGB(120, 220, 255))
							net:FireClient(player, "Purchased")
						end
					end
				end
				publish(player, tick % 5 == 0)
			end
			if tick % 20 == 1 then
				task.spawn(refreshLeaderboards)
			end
			if tick % 120 == 0 then
				task.spawn(saveLeaderboards)
			end
		end
	end)
end

return Game
