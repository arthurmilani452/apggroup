--[[
	Bandits (ModuleScript em ServerScriptService > Game)
	v24: LADRÃO NPC para servidor vazio. Quando tem pouca gente online (Config.Bandits.MaxPlayers),
	um guaxinim "Bandit" (primo do Sneaky) aparece de tempos em tempos, vai até a base de um jogador
	e fica alguns segundos "roubando" o dinheiro do COLETOR (nunca leva bichinhos, nunca mexe no save).
	  • O dono dá BONK nele com o taco (Config.Bandits.Hits pancadas): ganha dinheiro, às vezes um ovo,
	    e conta na missão diária "BONK a thief" (que era impossível em servidor vazio).
	  • Se ninguém derruba: o Bandit foge com uma parte do dinheiro que estava no coletor (Vault).
	  • Base trancada: o Bandit bate no laser e vai embora (ensina a usar a trava).
	Os números ficam em Config.Bandits. O Combat chama Bandits.Hit quando o taco acerta um "Bandit".
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Models3D = require(ReplicatedStorage.Shared.Models3D)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Registry = require(script.Parent.Registry)

local Bandits = {}

type Bandit = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Target: Player,
	HP: number,
	MaxHP: number,
	Hitters: { [Player]: boolean },
	Title: TextLabel,
	Hearts: TextLabel,
	Status: TextLabel,
	State: string, -- "Walking" | "Stealing" | "Fleeing" | "Down"
	StealUntil: number,
	Id: number,
	Loot: string?, -- v25: id do critter que ele trouxe nas costas (bonk = vira seu)
	PadPosition: Vector3?, -- onde ele fica roubando (volta para lá depois de uma pancada)
}

local bandits: { [Model]: Bandit } = {}
local byTarget: { [Player]: Bandit } = {}
local nextVisit: { [Player]: number } = {}
local folder: Folder? = nil
local banditId = 0

local function settings()
	return Config.Bandits
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getData(player: Player)
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function random(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function scheduleVisit(player: Player, seconds: number)
	nextVisit[player] = now() + seconds
end

-- Quantos jogadores carregados estão no servidor
local function loadedCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Loaded") then
			count += 1
		end
	end
	return count
end

---------------------------------------------------------------------
-- Boneco
---------------------------------------------------------------------
local function part(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	if shape then
		p.Shape = shape
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function heartsText(hp: number, max: number): string
	return string.rep("\u{2764}", hp) .. string.rep("\u{2661}", math.max(0, max - hp))
end

local function makeLabel(parent: Instance, size: UDim2, position: UDim2, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function buildBandit(position: Vector3, hp: number, target: Player): Bandit
	local model = Instance.new("Model")
	model.Name = "Bandit"
	local root = part("HumanoidRootPart", Vector3.new(3, 3, 3), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.Massless = false
	root.CFrame = CFrame.new(position)
	root.Parent = model
	model.PrimaryPart = root

	-- modelo 3D do Sneaky (ReplicatedStorage > Models3D > sneaky), se existir; senão, um guaxinim de peças
	local mesh = Models3D.Get("sneaky", { Size = 5.6, Fit = "Height", Anchored = false })
	if mesh then
		mesh:PivotTo(root.CFrame * CFrame.new(0, -3.7, 0)) -- pés no chão (HipHeight 2.2 + meia raiz 1.5)
		for _, d in mesh:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.Massless = true
				d.Parent = model
				weld(root, d)
			end
		end
		mesh:Destroy()
	else
		local gray = Color3.fromRGB(120, 120, 130)
		local body = part("Body", Vector3.new(3.6, 3.2, 3.6), gray, Enum.PartType.Ball)
		body.CFrame = root.CFrame * CFrame.new(0, -0.6, 0)
		body.Parent = model
		weld(root, body)
		local head = part("Head", Vector3.new(2.4, 2.4, 2.4), gray, Enum.PartType.Ball)
		head.CFrame = root.CFrame * CFrame.new(0, 1.6, -0.4)
		head.Parent = model
		weld(root, head)
		local mask = part("Mask", Vector3.new(2.5, 0.8, 1.2), Color3.fromRGB(35, 30, 40))
		mask.CFrame = root.CFrame * CFrame.new(0, 1.8, -1.4)
		mask.Parent = model
		weld(root, mask)
		for side = -1, 1, 2 do
			local eye = part("Eye", Vector3.new(0.5, 0.5, 0.5), Color3.new(1, 1, 1), Enum.PartType.Ball)
			eye.CFrame = root.CFrame * CFrame.new(side * 0.55, 1.85, -1.95)
			eye.Parent = model
			weld(root, eye)
			local ear = part("Ear", Vector3.new(0.8, 0.8, 0.4), gray)
			ear.CFrame = root.CFrame * CFrame.new(side * 0.9, 2.8, -0.2)
			ear.Parent = model
			weld(root, ear)
		end
		local tail = part("Tail", Vector3.new(1, 1, 3), Color3.fromRGB(70, 65, 80))
		tail.CFrame = root.CFrame * CFrame.new(0, -0.4, 2.6) * CFrame.Angles(math.rad(35), 0, 0)
		tail.Parent = model
		weld(root, tail)
	end
	-- bandana vermelha: mostra que é o ladrão, não o mascote
	local bandana = part("Bandana", Vector3.new(2.7, 0.5, 2.7), Color3.fromRGB(220, 40, 50), Enum.PartType.Cylinder)
	bandana.CFrame = root.CFrame * CFrame.new(0, 2.5, -0.3) * CFrame.Angles(0, 0, math.rad(90))
	bandana.Parent = model
	weld(root, bandana)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- sem pernas: fica de pé pela HipHeight
	humanoid.HipHeight = 2.2
	humanoid.WalkSpeed = settings().WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(9, 3.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.AlwaysOnTop = true
	local title = makeLabel(gui, UDim2.fromScale(1, 0.36), UDim2.fromScale(0, 0), "BANDIT!", Color3.fromRGB(255, 215, 60))
	local hearts = makeLabel(gui, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.36), heartsText(hp, hp), Color3.fromRGB(255, 90, 120))
	local status = makeLabel(gui, UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0.66), "BONK me with your bat!", Color3.new(1, 1, 1))
	gui.Parent = root

	model:AddTag("Bandit")
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	banditId += 1
	return {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Target = target,
		HP = hp,
		MaxHP = hp,
		Hitters = {},
		Title = title,
		Hearts = hearts,
		Status = status,
		State = "Walking",
		StealUntil = 0,
		Id = banditId,
		Loot = nil,
		PadPosition = nil,
	}
end

local function remove(bandit: Bandit)
	bandits[bandit.Model] = nil
	if byTarget[bandit.Target] == bandit then
		byTarget[bandit.Target] = nil
	end
	bandit.Model:Destroy()
end

---------------------------------------------------------------------
-- v25: Bandit com um critter roubado nas costas (de outra base...). BONK = o critter cai e vira seu.
---------------------------------------------------------------------
local function pickLoot(): string?
	local s = settings()
	if math.random() >= (s.CarryChance or 0) then
		return nil
	end
	local pool = {}
	for _, def in Critters.List do
		if (def.World == nil or def.World == "meadow") and (def.Rarity == "Common" or def.Rarity == "Uncommon") and not def.RebirthRequired then
			table.insert(pool, def.Id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.random(#pool)]
end

local function attachLoot(bandit: Bandit, critterId: string)
	local def = Critters.ById[critterId]
	if not def then
		return
	end
	bandit.Loot = critterId
	local mesh = Models3D.Get(critterId, { Size = 2.6, Fit = "Height", Anchored = false })
	if mesh then
		-- nas costas, de cabeça para baixo (carregado como saco)
		mesh:PivotTo(bandit.Root.CFrame * CFrame.new(0, 1.2, 2.2) * CFrame.Angles(0, math.pi, math.rad(180)))
		for _, d in mesh:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.Massless = true
				d.Parent = bandit.Model
				weld(bandit.Root, d)
			end
		end
		mesh:Destroy()
	else
		local sack = part("Loot", Vector3.new(2.2, 2.2, 2.2), def.Color or Color3.fromRGB(200, 200, 200), Enum.PartType.Ball)
		sack.CFrame = bandit.Root.CFrame * CFrame.new(0, 1.4, 2.2)
		sack.Parent = bandit.Model
		weld(bandit.Root, sack)
	end
	bandit.Title.Text = "BANDIT + " .. string.upper(def.Name) .. "!"
end

---------------------------------------------------------------------
-- Prêmio / castigo
---------------------------------------------------------------------
local function rewardText(player: Player): string
	local Economy = Registry.Economy
	local s = settings()
	local amount = math.floor(math.max(Economy.GetIncome(player) * 60 * s.RewardMinutes, s.RewardMinCash))
	Economy.AddCash(player, amount, false, "Bandit")
	local text = "+" .. Format.Money(amount)
	if math.random() < s.EggChance and Config.EggById[s.EggId] then
		local ok = Registry.CritterService.GrantEgg(player, s.EggId)
		text ..= " + " .. Config.EggById[s.EggId].Name .. (if ok then "" else " (queued: base full)")
	end
	return text
end

-- Chamado pelo Combat quando um taco acerta um Bandit
function Bandits.Hit(model: Model, player: Player)
	local bandit = bandits[model]
	if not bandit or bandit.HP <= 0 or bandit.State == "Down" then
		return
	end
	bandit.HP -= 1
	bandit.Hitters[player] = true
	bandit.Hearts.Text = heartsText(bandit.HP, bandit.MaxHP)
	Registry.Remotes.EffectAll("Bonk", bandit.Root.Position + Vector3.new(0, 3, 0))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local away = bandit.Root.Position - root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		if flat.Magnitude > 0.1 then
			-- empurrão curto (o ladrão fica perto para a 2ª pancada) e ele "perde" 2 s do roubo
			bandit.Root.AssemblyLinearVelocity = flat.Unit * 12 + Vector3.new(0, 16, 0)
		end
	end
	if bandit.HP > 0 then
		bandit.Status.Text = "Ouch! Again!"
		if bandit.State == "Stealing" then
			bandit.StealUntil += 2
			-- volta para o coletor (fica ao alcance da 2ª pancada)
			local id = bandit.Id
			task.delay(0.8, function()
				if bandits[bandit.Model] and bandit.Id == id and bandit.State == "Stealing" and bandit.PadPosition then
					bandit.Humanoid:MoveTo(bandit.PadPosition)
				end
			end)
		end
		return
	end
	-- derrubado: quem bateu ganha
	bandit.State = "Down"
	local position = bandit.Root.Position
	Registry.Remotes.EffectAll("HatchBurst", { Position = position, Rarity = "Rare" })
	for hitter in bandit.Hitters do
		if hitter.Parent and hitter:GetAttribute("Loaded") then
			local text = rewardText(hitter)
			if bandit.Loot and Critters.ById[bandit.Loot] then
				-- v25: o critter que ele carregava cai e vira do jogador que derrubou (o primeiro que bateu)
				local ok = Registry.CritterService.GrantCritter(hitter, bandit.Loot, nil, os.time())
				if ok then
					text ..= " + " .. Critters.ById[bandit.Loot].Name .. " (dropped!)"
					if Registry.Progress then
						pcall(Registry.Progress.Event, hitter, "Steal") -- conta na missão "Steal X critters"
					end
					bandit.Loot = nil
				end
			end
			Registry.Remotes.Notify(hitter, "You BONKED the Bandit! " .. text, "success")
			Registry.Economy.AddDefense(hitter, nil) -- conquista "Base Guardian" + missão "BONK a thief" + XP
			if Registry.Analytics then
				pcall(Registry.Analytics.Event, hitter, "BanditBonked")
			end
		end
	end
	remove(bandit)
end

local function flee(bandit: Bandit, text: string)
	if bandit.State == "Down" then
		return
	end
	bandit.State = "Fleeing"
	bandit.Status.Text = text
	bandit.Humanoid.WalkSpeed = settings().WalkSpeed * 1.6
	local plot = Registry.Plots.Get(bandit.Target)
	local outside = if plot then (Registry.Plots.PathPoints(plot)) else bandit.Root.Position
	bandit.Humanoid:MoveTo(outside + (outside - bandit.Root.Position).Unit * 60)
	local id = bandit.Id
	task.delay(5, function()
		if bandits[bandit.Model] and bandit.Id == id then
			remove(bandit)
		end
	end)
end

local function stealAndFlee(bandit: Bandit)
	local owner = bandit.Target
	local plot = Registry.Plots.Get(owner)
	local s = settings()
	local taken = 0
	if plot and owner.Parent and owner:GetAttribute("Loaded") then
		local cap = math.max(Registry.Economy.GetIncome(owner) * 60 * s.VaultMaxMinutes, 50)
		taken = math.floor(math.min(plot.Vault * s.VaultShare, cap))
		if taken >= 1 then
			plot.Vault -= taken
			if Registry.Analytics then
				pcall(Registry.Analytics.Event, owner, "BanditStole", taken)
			end
		end
	end
	if taken >= 1 then
		Registry.Remotes.Notify(owner, ("The Bandit ran off with %s from your collector! BONK him next time (or LOCK your base)."):format(Format.Money(taken)), "warning")
		flee(bandit, "Hehe! Got " .. Format.Money(taken) .. "!")
	else
		Registry.Remotes.Notify(owner, "The Bandit found your collector empty and left. Nice!", "info")
		flee(bandit, "Empty?! Boo!")
	end
end

---------------------------------------------------------------------
-- Visita
---------------------------------------------------------------------
local function canVisit(player: Player): boolean
	if not player.Parent or not player:GetAttribute("Loaded") or player:GetAttribute("Leaving") then
		return false
	end
	local data = getData(player)
	if not data or not data.TutorialDone then
		return false
	end
	if (player:GetAttribute("World") or "meadow") ~= "meadow" or player:GetAttribute("InMinigame") then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local plot = Registry.Plots.Get(player)
	if not plot or plot.Owner ~= player then
		return false
	end
	if #Registry.CritterService.GetBaseList(player) < 1 then
		return false -- sem bichinho, sem coletor rendendo: nada para "roubar"
	end
	return true
end

local function startVisit(player: Player)
	local plot = Registry.Plots.Get(player)
	if not plot then
		return
	end
	local s = settings()
	local outside, inside = Registry.Plots.PathPoints(plot)
	local start = outside + (outside - inside).Unit * 30 -- começa lá no caminho, vindo em direção à base
	local bandit = buildBandit(Vector3.new(start.X, 3.5, start.Z), s.Hits, player)
	bandits[bandit.Model] = bandit
	byTarget[player] = bandit
	local loot = pickLoot()
	if loot then
		attachLoot(bandit, loot)
		Registry.Remotes.Notify(player, "A BANDIT with a stolen critter is sneaking to your base! BONK him and the critter is YOURS!", "warning")
	else
		Registry.Remotes.Notify(player, "A BANDIT is sneaking to your base! BONK him with your bat!", "warning")
	end
	Registry.Remotes.Effect(player, "Alarm")
	if Registry.Analytics then
		pcall(Registry.Analytics.Event, player, "BanditVisit")
	end

	local id = bandit.Id
	task.spawn(function()
		local function alive(): boolean
			return bandits[bandit.Model] ~= nil and bandit.Id == id and bandit.State ~= "Down"
		end
		-- 1) anda até a entrada
		bandit.Humanoid:MoveTo(outside)
		bandit.Humanoid.MoveToFinished:Wait()
		if not alive() then
			return
		end
		-- 2) base trancada? bate no laser e foge
		if Registry.Plots.IsLocked(plot) then
			Registry.Remotes.Notify(player, "Your LOCK kept the Bandit out! Well done!", "success")
			flee(bandit, "Ouch! Lasers!")
			return
		end
		-- 3) entra e vai até o coletor
		bandit.Humanoid:MoveTo(inside)
		bandit.Humanoid.MoveToFinished:Wait()
		if not alive() then
			return
		end
		local pad: BasePart = plot.CollectPad
		bandit.PadPosition = pad.Position + Vector3.new(0, 0, 3)
		bandit.Humanoid:MoveTo(bandit.PadPosition)
		bandit.Humanoid.MoveToFinished:Wait()
		if not alive() then
			return
		end
		if Registry.Plots.IsLocked(plot) then
			Registry.Remotes.Notify(player, "Your LOCK kicked the Bandit out! Well done!", "success")
			flee(bandit, "Ouch! Lasers!")
			return
		end
		-- 4) rouba por alguns segundos (dá tempo do dono chegar e dar BONK)
		bandit.State = "Stealing"
		bandit.StealUntil = now() + s.StealSeconds
		while alive() and bandit.State == "Stealing" do
			local left = math.ceil(bandit.StealUntil - now())
			if left <= 0 then
				break
			end
			bandit.Status.Text = ("Stealing your cash... %ds"):format(left)
			if Registry.Plots.IsLocked(plot) then
				Registry.Remotes.Notify(player, "Your LOCK kicked the Bandit out! Well done!", "success")
				flee(bandit, "Ouch! Lasers!")
				return
			end
			task.wait(0.5)
		end
		if alive() and bandit.State == "Stealing" then
			stealAndFlee(bandit)
		end
	end)
end

-- Teste/admin: manda um Bandit agora para a base do jogador (ignora o relógio; respeita só a base)
function Bandits.ForceVisit(player: Player): boolean
	if not folder or byTarget[player] or not Registry.Plots.Get(player) then
		return false
	end
	startVisit(player)
	return true
end

---------------------------------------------------------------------
function Bandits.Init()
	local s = settings()
	if not s or not s.Enabled then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Bandits"
	folder.Parent = workspace

	local function watch(player: Player)
		scheduleVisit(player, s.FirstAfter)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		nextVisit[player] = nil
		local bandit = byTarget[player]
		if bandit then
			remove(bandit)
		end
	end)
	CollectionService:GetInstanceRemovedSignal("Bandit"):Connect(function(instance)
		local bandit = bandits[instance :: Model]
		if bandit then
			bandits[instance :: Model] = nil
			if byTarget[bandit.Target] == bandit then
				byTarget[bandit.Target] = nil
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(3)
			local ok, err = pcall(function()
				if loadedCount() > s.MaxPlayers or workspace:GetAttribute("InvasionUntil") ~= nil then
					return -- servidor cheio ou invasão: os ladrões de verdade/monstros já dão trabalho
				end
				local t = now()
				for _, player in Players:GetPlayers() do
					local due = nextVisit[player]
					if due and t >= due and not byTarget[player] then
						if canVisit(player) then
							scheduleVisit(player, random(s.Every))
							startVisit(player)
						else
							scheduleVisit(player, 30) -- tenta de novo daqui a pouco
						end
					end
				end
			end)
			if not ok then
				warn("[Bandits] loop error:", err)
			end
		end
	end)
end

return Bandits
