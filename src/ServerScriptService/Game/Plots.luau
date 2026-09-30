--[[
	Plots (ModuleScript em ServerScriptService > Game)
	As 8 bases: dono, trava de laser (com recarga), coletor de dinheiro, 24 pedestais,
	esteira de treino (corra nela = mais velocidade de graça) e alarme de invasão.
	v19/v20: 2º ANDAR com rampa e mais 18 pedestais (vagas 25-42). Ele fica guardado e só aparece
	na base quando o dono passa de 24 vagas (Config.FloorSlots).
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Plots = {}

local HALF_X = 32
local HALF_Z = 44 -- v20: a base ficou 16 studs mais funda (88)

local plots = {}
local byPlayer: { [Player]: any } = {}
local lastAlarm: { [string]: number } = {}

local LOCK_READY_COLOR = Color3.fromRGB(255, 70, 70)
local LOCK_BUSY_COLOR = Color3.fromRGB(120, 120, 120)
local SLOT_OPEN_COLOR = Color3.fromRGB(245, 245, 245)
local SLOT_LOCKED_COLOR = Color3.fromRGB(90, 90, 95)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function makeLabel(parent: Instance, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
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

local function makeBillboard(adornee: BasePart, offsetY: number, width: number, height: number, text: string, color: Color3): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = UDim2.new(width, 0, height, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = adornee
	return gui, makeLabel(gui, text, color)
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if model then
		return Players:GetPlayerFromCharacter(model)
	end
	return nil
end

local function setBarrier(plot, locked: boolean)
	plot.Barrier.CanCollide = locked
	plot.Barrier.Transparency = if locked then 0.3 else 1
end

local function publishLockState(plot)
	plot.Model:SetAttribute("LockedUntil", plot.LockedUntil)
	plot.Model:SetAttribute("CooldownUntil", plot.CooldownUntil)
end

function Plots.IsInside(plot, position: Vector3): boolean
	local p = plot.Origin.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= HALF_X and math.abs(p.Z) <= HALF_Z and p.Y < 40
end

-- Tem alguém que não é o dono dentro da base?
function Plots.HasIntruder(plot): boolean
	for _, other in Players:GetPlayers() do
		if other ~= plot.Owner then
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and Plots.IsInside(plot, root.Position) then
				return true
			end
		end
	end
	return false
end

function Plots.IsLocked(plot): boolean
	return plot.LockedUntil > now()
end

function Plots.Get(player: Player)
	return byPlayer[player]
end

function Plots.All()
	return plots
end

function Plots.FreeSlot(plot, count: number): number?
	for slot = 1, math.min(count, #plot.SlotParts) do
		if plot.Slots[slot] == nil then
			return slot
		end
	end
	return nil
end

function Plots.FreeSlotCount(plot, count: number): number
	local free = 0
	for slot = 1, math.min(count, #plot.SlotParts) do
		if plot.Slots[slot] == nil then
			free += 1
		end
	end
	return free
end

-- Altura do topo de uma peça (funciona com pedestal redondo, que é um cilindro deitado girado)
local function topOf(part: BasePart): number
	local cf, size = part.CFrame, part.Size
	return part.Position.Y
		+ math.abs(cf.RightVector.Y) * size.X / 2
		+ math.abs(cf.UpVector.Y) * size.Y / 2
		+ math.abs(cf.LookVector.Y) * size.Z / 2
end

-- Posição do bichinho em cima do pedestal, olhando para a frente da base
function Plots.SlotCFrame(plot, slot: number, groundOffset: number): CFrame
	local pedestal: BasePart = plot.SlotParts[slot]
	local top = Vector3.new(pedestal.Position.X, topOf(pedestal) + groundOffset, pedestal.Position.Z)
	return CFrame.lookAt(top, top + plot.Origin.CFrame.LookVector)
end

-- Pontos do caminho até a base (fora da entrada / logo depois da entrada)
function Plots.PathPoints(plot): (Vector3, Vector3)
	local origin: CFrame = plot.Origin.CFrame
	local outside = (origin * CFrame.new(0, 0, -(HALF_Z + 8))).Position
	local inside = (origin * CFrame.new(0, 0, -(HALF_Z - 6))).Position
	return Vector3.new(outside.X, 0, outside.Z), Vector3.new(inside.X, plot.FloorTop, inside.Z)
end

-- O 2º andar está aparecendo nesta base?
function Plots.HasFloor2(plot): boolean
	return plot.Floor2 ~= nil and plot.Floor2.Parent == plot.Model
end

-- Mostra/guarda o 2º andar. Devolve true se mudou.
local function setFloor2(plot, visible: boolean): boolean
	local floor2 = plot.Floor2
	if not floor2 or Plots.HasFloor2(plot) == visible then
		return false
	end
	floor2.Parent = if visible then plot.Model else nil
	plot.Model:SetAttribute("Floor2", visible)
	local customize = Registry.Customize
	if customize and customize.RefreshProps then
		customize.RefreshProps(plot) -- enfeites do tema sobem para cima do vidro do 2º andar
	end
	return true
end

-- Pontos por onde um bichinho passa para chegar à vaga (a rampa, se a vaga for lá em cima)
function Plots.SlotRoute(plot, slot: number): { Vector3 }
	if slot > Config.FloorSlots and plot.RampBottom and plot.RampTop then
		return { plot.RampBottom.CFrame.Position, plot.RampTop.CFrame.Position }
	end
	return {}
end

function Plots.RefreshSlots(plot, count: number)
	for slot, pedestal in plot.SlotParts do
		local open = slot <= count
		pedestal.Color = if open then SLOT_OPEN_COLOR else SLOT_LOCKED_COLOR
		pedestal.Transparency = if open then 0 else 0.35
		plot.SlotLabels[slot].Enabled = not open
	end
	local owner = plot.Owner
	local grew = setFloor2(plot, count > Config.FloorSlots) and count > Config.FloorSlots
	-- só comemora quando o andar aparece com o dono jogando (não quando ele entra no jogo)
	if grew and owner and plot.RefreshedFor == owner then
		Registry.Remotes.Notify(owner, "Your base grew! 2ND FLOOR unlocked!", "rare")
		Registry.Remotes.Effect(owner, "Purchase", "Legendary")
	end
	plot.RefreshedFor = owner
end

local function updateSign(plot)
	if plot.Owner then
		plot.SignLabel.Text = plot.Owner.DisplayName .. "'s Base"
	else
		plot.SignLabel.Text = "Empty Base"
	end
end

local function ejectIntruders(plot)
	local origin: CFrame = plot.Origin.CFrame
	for _, other in Players:GetPlayers() do
		if other ~= plot.Owner then
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if character and root and Plots.IsInside(plot, root.Position) then
				Registry.CritterService.DropCarried(other)
				local spot = (origin * CFrame.new(math.random(-6, 6), 0, -(HALF_Z + 10))).Position + Vector3.new(0, 4, 0)
				character:PivotTo(CFrame.lookAt(spot, spot + origin.LookVector))
			end
		end
	end
end

local function lockNow(plot, player: Player)
	local economy = Registry.Economy
	local duration = if economy and economy.HasPass(player, "LongLock") then Config.LockDurationPass else Config.LockDuration
	local progress = Registry.Progress
	if progress then
		duration += progress.LockBonus(player) -- habilidade Defense e classe Guardian
	end
	plot.LockedUntil = now() + duration
	plot.CooldownUntil = 0
	publishLockState(plot)
	setBarrier(plot, true)
	ejectIntruders(plot)
	Registry.Remotes.Notify(player, ("Base locked for %d seconds!"):format(duration), "success")
	Registry.Remotes.Effect(player, "Lock")
	if Registry.Tutorial then
		Registry.Tutorial.Event(player, "Locked")
	end
end

local function tryLock(plot, player: Player)
	if plot.Owner ~= player or Plots.IsLocked(plot) then
		return
	end
	local t = now()
	if plot.CooldownUntil > t then
		if t - (plot.LastCooldownWarn or 0) > 2 then
			plot.LastCooldownWarn = t
			Registry.Remotes.Notify(player, ("Lock recharging: %ds (or use INSTANT LOCK)"):format(math.ceil(plot.CooldownUntil - t)), "warning")
		end
		return
	end
	lockNow(plot, player)
end

-- Usado pelo Dev Product "Instant Lock": tranca na hora, mesmo recarregando
function Plots.ForceLock(player: Player): boolean
	local plot = byPlayer[player]
	if not plot then
		return false
	end
	lockNow(plot, player)
	return true
end

local function tryCollect(plot, player: Player)
	if plot.Owner ~= player then
		return
	end
	local t = os.clock()
	if t - (plot.LastCollect or 0) < 0.4 then
		return
	end
	plot.LastCollect = t
	local amount = math.floor(plot.Vault)
	if amount < 1 then
		return
	end
	plot.Vault -= amount
	Registry.Economy.AddCash(player, amount, true, "Collect")
	Registry.Remotes.Effect(player, "Collect", amount)
	if Registry.Tutorial then
		Registry.Tutorial.Event(player, "Collected")
	end
end

function Plots.Init()
	local map = workspace:WaitForChild("Map")
	local folder = map:WaitForChild("Plots")

	local index = 1
	while true do
		local model = folder:FindFirstChild("Plot" .. index)
		if not model then
			break
		end
		local plot = {
			Index = index,
			Model = model,
			Origin = model:WaitForChild("Origin") :: BasePart,
			Barrier = model:WaitForChild("Barrier") :: BasePart,
			LockButton = model:WaitForChild("LockButton") :: BasePart,
			CollectPad = model:WaitForChild("CollectPad") :: BasePart,
			SpawnPoint = model:WaitForChild("SpawnPoint") :: BasePart,
			Sign = model:WaitForChild("Sign") :: BasePart,
			Belt = nil :: BasePart?,
			SlotParts = {},
			SlotLabels = {},
			Slots = {},
			Owner = nil :: Player?,
			LockedUntil = 0,
			CooldownUntil = 0,
			LastCooldownWarn = 0,
			Vault = 0,
			LastCollect = 0,
			FloorTop = 0.5,
		}
		local floor = model:FindFirstChild("Floor") :: BasePart?
		if floor then
			plot.FloorTop = floor.Position.Y + floor.Size.Y / 2
		end

		local slotsFolder = model:WaitForChild("Slots")
		local floor2 = model:FindFirstChild("Floor2") :: Model?
		local floor2Slots = floor2 and floor2:FindFirstChild("Slots")
		if floor2 then
			plot.Floor2 = floor2
			plot.RampBottom = floor2:FindFirstChild("RampBottom") :: BasePart?
			plot.RampTop = floor2:FindFirstChild("RampTop") :: BasePart?
			local sign2 = floor2:FindFirstChild("Sign2") :: BasePart?
			if sign2 then
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.LightInfluence = 0
				gui.PixelsPerStud = 40
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.Parent = sign2
				makeLabel(gui, "2ND FLOOR", Color3.fromRGB(255, 255, 255))
			end
		end
		for slot = 1, Config.MaxSlots do
			local pedestal = (slotsFolder:FindFirstChild("Slot" .. slot) or (floor2Slots and floor2Slots:FindFirstChild("Slot" .. slot))) :: BasePart?
			if pedestal then
				plot.SlotParts[slot] = pedestal
				local gui = makeBillboard(pedestal, 2.5, 5, 1.4, "REBIRTH or +SLOTS", Color3.fromRGB(255, 220, 120))
				gui.MaxDistance = 45
				plot.SlotLabels[slot] = gui
			end
		end

		-- Placa do dono (virada para a esteira)
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Front
		surface.LightInfluence = 0
		surface.PixelsPerStud = 40
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.Parent = plot.Sign
		plot.SignLabel = makeLabel(surface, "Empty Base", Color3.fromRGB(255, 255, 255))

		-- Barreira laser: todo mundo bate nela, menos o dono
		local barrierGroup = "Barrier" .. index
		local ownerGroup = "Owner" .. index
		PhysicsService:RegisterCollisionGroup(barrierGroup)
		PhysicsService:RegisterCollisionGroup(ownerGroup)
		PhysicsService:CollisionGroupSetCollidable(barrierGroup, ownerGroup, false)
		plot.Barrier.CollisionGroup = barrierGroup
		setBarrier(plot, false)
		publishLockState(plot)

		-- v24: a plaquinha do botão ficava a 3 studs (dentro do boneco de quem está em cima): agora fica
		-- mais alta, maior e sempre por cima de tudo, então dá para ver os segundos parado no botão.
		local lockGui, lockLabel = makeBillboard(plot.LockButton, 7.5, 11, 3, "LOCK BASE", Color3.fromRGB(255, 255, 255))
		lockGui.AlwaysOnTop = true
		lockGui.MaxDistance = 160
		plot.LockLabel = lockLabel
		-- v23: placa GRANDE em cima do portão com os segundos da trava (todo mundo vê, de longe)
		local gateGui, gateLabel = makeBillboard(plot.Barrier, 12, 16, 3.2, "", Color3.fromRGB(255, 90, 90))
		gateGui.MaxDistance = 220
		gateGui.AlwaysOnTop = false
		gateGui.Enabled = false
		plot.GateGui = gateGui
		plot.GateLabel = gateLabel
		local _, collectLabel = makeBillboard(plot.CollectPad, 3.5, 8, 2.4, "COLLECT", Color3.fromRGB(120, 255, 120))
		plot.CollectLabel = collectLabel

		plot.LockButton.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				tryLock(plot, player)
			end
		end)
		-- Esteira de treino: empurra para trás; quem corre em cima ganha velocidade
		local treadmill = model:FindFirstChild("Treadmill")
		local belt = treadmill and treadmill:FindFirstChild("Belt") :: BasePart?
		if belt then
			plot.Belt = belt
			belt.AssemblyLinearVelocity = -plot.Origin.CFrame.RightVector * Config.TreadmillPush
			local gui = makeBillboard(belt, 4.5, 10, 2.6, "TREADMILL\nRUN = +SPEED", Color3.fromRGB(120, 220, 255))
			gui.MaxDistance = 60
		end

		plot.CollectPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				tryCollect(plot, player)
			end
		end)

		Plots.RefreshSlots(plot, Config.StartSlots) -- guarda o 2º andar até alguém ter 19 vagas
		updateSign(plot)
		table.insert(plots, plot)
		index += 1
	end

	-- Atualiza trava, recarga, coletor, esteira de treino e alarme de invasão
	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			local ok, err = pcall(function()
				local t = now()
				for _, plot in plots do
					-- Esteira de treino (só o dono treina na própria base)
					local trainer = plot.Owner
					if trainer and plot.Belt then
						local character = trainer.Character
						local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						local onBelt = false
						if root and humanoid and humanoid.Health > 0 then
							local belt = plot.Belt :: BasePart
							local p = belt.CFrame:PointToObjectSpace(root.Position)
							onBelt = math.abs(p.X) <= belt.Size.X / 2 + 0.5 and math.abs(p.Z) <= belt.Size.Z / 2 + 0.5 and p.Y > 0 and p.Y < 6
						end
						if onBelt then
							Registry.Economy.Train(trainer, math.min(dt, 0.5))
						end
						if trainer:GetAttribute("Training") ~= onBelt then
							trainer:SetAttribute("Training", onBelt)
						end
					end

					if plot.LockedUntil > 0 and t >= plot.LockedUntil then
						plot.LockedUntil = 0
						plot.CooldownUntil = t + Config.LockCooldown
						publishLockState(plot)
						setBarrier(plot, false)
						if plot.Owner then
							Registry.Remotes.Notify(plot.Owner, "Your base is UNLOCKED!", "warning")
						end
					end
					if plot.LockedUntil > t then
						local left = math.ceil(plot.LockedUntil - t)
						plot.LockLabel.Text = "\u{1F512} LOCKED " .. left .. "s"
						plot.LockLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
						plot.LockButton.Color = LOCK_BUSY_COLOR
						if plot.GateGui then
							plot.GateGui.Enabled = true
							plot.GateLabel.Text = "\u{1F512} LOCKED " .. left .. "s"
						end
					elseif plot.CooldownUntil > t then
						plot.LockLabel.Text = if plot.Owner then "READY IN " .. math.ceil(plot.CooldownUntil - t) .. "s" else ""
						plot.LockLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
						plot.LockButton.Color = LOCK_BUSY_COLOR
						if plot.GateGui then
							plot.GateGui.Enabled = false
						end
					else
						plot.LockLabel.Text = if plot.Owner then "LOCK BASE" else ""
						plot.LockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
						plot.LockButton.Color = LOCK_READY_COLOR
						if plot.GateGui then
							plot.GateGui.Enabled = false
						end
					end
					if plot.Owner then
						plot.CollectLabel.Text = "COLLECT\n" .. Format.Money(plot.Vault)
					else
						plot.CollectLabel.Text = ""
					end

					-- Alarme: alguém entrou na sua base
					local owner = plot.Owner
					if owner then
						for _, other in Players:GetPlayers() do
							if other ~= owner then
								local character = other.Character
								local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
								if root and Plots.IsInside(plot, root.Position) then
									local key = plot.Index .. ":" .. other.UserId
									if os.clock() - (lastAlarm[key] or 0) > Config.IntruderAlarmCooldown then
										lastAlarm[key] = os.clock()
										Registry.Remotes.Notify(owner, "INTRUDER! " .. other.DisplayName .. " entered your base!", "error")
										Registry.Remotes.Effect(owner, "Alarm")
									end
								end
							end
						end
					end
				end
			end)
			if not ok then
				warn("[Plots] loop error:", err)
			end
		end
	end)
end

function Plots.Assign(player: Player)
	if byPlayer[player] then
		return byPlayer[player]
	end
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.Vault = 0
			plot.LockedUntil = 0
			plot.CooldownUntil = 0
			plot.Slots = {}
			setBarrier(plot, false)
			publishLockState(plot)
			plot.Model:SetAttribute("ShieldUntil", nil)
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.Model:SetAttribute("OwnerName", player.DisplayName)
			byPlayer[player] = plot
			updateSign(plot)
			return plot
		end
	end
	return nil
end

function Plots.Release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.Owner = nil
	plot.Vault = 0
	plot.LockedUntil = 0
	plot.CooldownUntil = 0
	plot.Slots = {}
	setBarrier(plot, false)
	publishLockState(plot)
	plot.Model:SetAttribute("OwnerUserId", nil)
	plot.Model:SetAttribute("OwnerName", nil)
	plot.Model:SetAttribute("ShieldUntil", nil)
	Plots.RefreshSlots(plot, Config.StartSlots)
	updateSign(plot)
	if Registry.Customize then
		Registry.Customize.ResetPlot(plot) -- tema e decoração voltam ao normal para o próximo dono
	end
	for key in lastAlarm do
		if string.sub(key, 1, #tostring(plot.Index) + 1) == plot.Index .. ":" then
			lastAlarm[key] = nil
		end
	end
end

function Plots.SpawnCFrame(plot): CFrame
	local base = plot.SpawnPoint.Position + Vector3.new(0, 4, 0)
	return CFrame.lookAt(base, base + plot.Origin.CFrame.LookVector)
end

function Plots.SetupCharacter(player: Player, character: Model)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	local group = "Owner" .. plot.Index
	local function apply(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
	for _, descendant in character:GetDescendants() do
		apply(descendant)
	end
	character.DescendantAdded:Connect(apply)

	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		task.wait(0.15)
		if character.Parent and byPlayer[player] == plot then
			character:PivotTo(Plots.SpawnCFrame(plot))
		end
	end)
end

return Plots
