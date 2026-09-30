--[[
	Worlds (ModuleScript em ServerScriptService > Game)
	Os 6 mundos do jogo:
	  • destravar: ter os Rebirths pedidos + pagar o Cash (uma vez; fica para sempre)
	  • viajar: portais no fim do Meadow, botão WORLDS na tela e portal "HOME" em cada mundo
	  • o jogo guarda em qual mundo cada jogador está (atributo "World") para ligar só as esteiras usadas
	Os mundos ficam em Config.Worlds; o mapa de cada um fica em Workspace > Map > Worlds.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Worlds = {}

local spawns: { [string]: BasePart } = {}
local lookAt: { [string]: Vector3 } = {}
local lastTravel: { [Player]: number } = {}
local lastPortalHint: { [Player]: number } = {}
local traveling: { [Player]: boolean } = {}

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

-- Texto do que precisa para destravar ("Rebirth 1 + $100M")
function Worlds.RequirementText(world): string
	local parts = {}
	if world.Rebirths > 0 then
		table.insert(parts, "Rebirth " .. world.Rebirths)
	end
	if world.Cash > 0 then
		table.insert(parts, Format.Money(world.Cash))
	end
	return if #parts > 0 then table.concat(parts, " + ") else "FREE"
end

function Worlds.IsUnlocked(player: Player, worldId: string): boolean
	if worldId == "meadow" then
		return true
	end
	local data = getData(player)
	return data ~= nil and type(data.Worlds) == "table" and data.Worlds[worldId] == true
end

-- A tela lê "WorldsUnlocked" = "meadow,candy,..."
function Worlds.Sync(player: Player)
	local list = {}
	for _, world in Config.Worlds do
		if Worlds.IsUnlocked(player, world.Id) then
			table.insert(list, world.Id)
		end
	end
	player:SetAttribute("WorldsUnlocked", table.concat(list, ","))
end

function Worlds.SpawnCFrame(worldId: string): CFrame?
	local pad = spawns[worldId]
	if not pad then
		return nil
	end
	local base = pad.Position + Vector3.new(0, 4, 0)
	-- olhando para a esteira do mundo (que fica no meio da ilha)
	local look = lookAt[worldId]
	local target = if look then Vector3.new(look.X, base.Y, look.Z) else base - Vector3.zAxis
	return CFrame.lookAt(base, target)
end

function Worlds.Travel(player: Player, worldId: string)
	local Remotes = Registry.Remotes
	local world = Config.WorldById[worldId]
	if not world or not player:GetAttribute("Loaded") then
		return
	end
	if player:GetAttribute("InMinigame") then
		Remotes.Notify(player, "Finish your minigame first!", "info")
		return
	end
	if not Worlds.IsUnlocked(player, worldId) then
		Remotes.Notify(player, ("%s is locked: %s"):format(world.Name, Worlds.RequirementText(world)), "warning")
		Remotes.Effect(player, "OpenWorlds", worldId)
		return
	end
	local t = os.clock()
	if traveling[player] or t - (lastTravel[player] or 0) < Config.WorldTravelCooldown then
		return
	end
	if Registry.CritterService.IsCarrying(player) then
		Remotes.Notify(player, "You can't travel while carrying something! Run to your base first.", "error")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local target: CFrame? = nil
	if worldId == "meadow" then
		local plot = Registry.Plots.Get(player)
		target = if plot then Registry.Plots.SpawnCFrame(plot) else nil
	else
		target = Worlds.SpawnCFrame(worldId)
	end
	if not target then
		return
	end
	lastTravel[player] = t

	-- carrega o chão do destino antes (StreamingEnabled), senão o jogador cai
	traveling[player] = true
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 5)
	end)
	if not player.Parent then
		return -- saiu durante a viagem (não guarda nada dele)
	end
	traveling[player] = nil
	lastTravel[player] = os.clock()
	if not player.Parent or player.Character ~= character or humanoid.Health <= 0 then
		return
	end
	if Registry.CritterService.IsCarrying(player) then
		return
	end
	character:PivotTo(target)
	player:SetAttribute("World", worldId)
	Registry.CritterService.ActivateLane(worldId)
	Remotes.Effect(player, "Travel", worldId)
	if worldId ~= "meadow" then
		Remotes.Notify(player, "Welcome to " .. world.Name .. "! Eggs you buy here fly to your base.", "info")
	end
end

function Worlds.Unlock(player: Player, worldId: string)
	local Remotes = Registry.Remotes
	local Economy = Registry.Economy
	local world = Config.WorldById[worldId]
	local data = getData(player)
	if not world or worldId == "meadow" or not data or not player:GetAttribute("Loaded") then
		return
	end
	if Worlds.IsUnlocked(player, worldId) then
		Worlds.Travel(player, worldId)
		return
	end
	-- os mundos abrem em ordem
	local previous = Config.Worlds[(Config.WorldIndex[worldId] or 2) - 1]
	if previous and not Worlds.IsUnlocked(player, previous.Id) then
		Remotes.Notify(player, "Unlock " .. previous.Name .. " first!", "warning")
		return
	end
	if Economy.GetPeakRebirths(player) < world.Rebirths then -- o prestígio não tranca mundos
		Remotes.Notify(player, ("You need Rebirth %d to unlock %s!"):format(world.Rebirths, world.Name), "error")
		return
	end
	if not Economy.TrySpend(player, world.Cash, "World") then
		Remotes.Notify(player, ("You need %s to unlock %s!"):format(Format.Money(world.Cash), world.Name), "error")
		return
	end
	if type(data.Worlds) ~= "table" then
		data.Worlds = {}
	end
	data.Worlds[worldId] = true
	Worlds.Sync(player)
	Economy.SeasonXP(player, "World")
	Remotes.Effect(player, "WorldUnlocked", worldId)
	Remotes.NotifyAll(("%s unlocked %s!"):format(player.DisplayName, string.upper(world.Name)), "rare")
	local analytics = Registry.Analytics
	if analytics then
		analytics.Event(player, "WorldUnlocked_" .. worldId)
	end
	task.spawn(Registry.Data.Save, player)
	lastTravel[player] = nil
	task.delay(1.2, Worlds.Travel, player, worldId)
end

-- Admin/teste: destrava todos
function Worlds.UnlockAll(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	data.Worlds = type(data.Worlds) == "table" and data.Worlds or {}
	for _, world in Config.Worlds do
		if world.Id ~= "meadow" then
			data.Worlds[world.Id] = true
		end
	end
	Worlds.Sync(player)
end

-- Renasceu: sempre volta para a base (Meadow)
function Worlds.OnCharacter(player: Player)
	player:SetAttribute("World", "meadow")
end

function Worlds.SetupPlayer(player: Player)
	player:SetAttribute("World", "meadow")
	Worlds.Sync(player)
end

function Worlds.RemovePlayer(player: Player)
	lastTravel[player] = nil
	lastPortalHint[player] = nil
	traveling[player] = nil
end

local function makeSignText(part: BasePart, face: Enum.NormalId, title: string, subtitle: string, color: Color3)
	local surface = Instance.new("SurfaceGui")
	surface.Face = face
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 25
	local function line(text: string, y: number, height: number, textColor: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -20, height, 0)
		label.Position = UDim2.new(0, 10, y, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = textColor
		label.Text = text
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(20, 20, 35)
		stroke.Parent = label
		label.Parent = surface
	end
	line(title, 0.04, if subtitle ~= "" then 0.56 else 0.9, color)
	if subtitle ~= "" then
		line(subtitle, 0.62, 0.34, Color3.fromRGB(255, 230, 120))
	end
	surface.Parent = part
end

local function connectPortal(disc: BasePart, worldId: string)
	disc.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local t = os.clock()
		if Registry.CritterService.IsCarrying(player) then
			if t - (lastPortalHint[player] or 0) > 3 then
				lastPortalHint[player] = t
				Registry.Remotes.Notify(player, "You can't travel while carrying something! Run to your base first.", "error")
			end
		elseif Worlds.IsUnlocked(player, worldId) then
			Worlds.Travel(player, worldId)
		else
			if t - (lastPortalHint[player] or 0) > 3 then
				lastPortalHint[player] = t
				local world = Config.WorldById[worldId]
				Registry.Remotes.Notify(player, ("%s: %s to unlock"):format(world.Name, Worlds.RequirementText(world)), "warning")
				Registry.Remotes.Effect(player, "OpenWorlds", worldId)
			end
		end
	end)
end

function Worlds.Init()
	local map = workspace:WaitForChild("Map")

	-- Portais no Meadow (um para cada mundo)
	local portals = map:FindFirstChild("WorldPortals")
	if portals then
		for _, world in Config.Worlds do
			local portal = portals:FindFirstChild(world.Id)
			if portal then
				local disc = portal:FindFirstChild("Disc") :: BasePart?
				local sign = portal:FindFirstChild("Sign") :: BasePart?
				if disc then
					connectPortal(disc, world.Id)
				end
				if sign then
					makeSignText(sign, Enum.NormalId.Left, string.upper(world.Name), Worlds.RequirementText(world), world.Color)
				end
			end
		end
	end

	-- Cada mundo: ponto de chegada, portal de volta e placa com o nome
	local worldsFolder = map:FindFirstChild("Worlds")
	if worldsFolder then
		for _, world in Config.Worlds do
			local area = worldsFolder:FindFirstChild(world.Id)
			if area then
				local spawn = area:FindFirstChild("Spawn") :: BasePart?
				if spawn then
					spawns[world.Id] = spawn
				end
				local belt = area:FindFirstChild("Conveyor") :: BasePart?
				if belt then
					lookAt[world.Id] = belt.Position
				end
				local home = area:FindFirstChild("HomePortal")
				local disc = home and home:FindFirstChild("Disc") :: BasePart?
				if disc then
					connectPortal(disc, "meadow")
				end
				local homeSign = home and home:FindFirstChild("Sign") :: BasePart?
				if homeSign then
					makeSignText(homeSign, Enum.NormalId.Front, "BACK TO BASE", "", Color3.fromRGB(120, 255, 120))
				end
				local title = area:FindFirstChild("TitleSign") :: BasePart?
				if title then
					for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
						makeSignText(title, face, string.upper(world.Name), "", world.Color)
					end
				end
			end
		end
	end

	Players.PlayerRemoving:Connect(Worlds.RemovePlayer)
end

return Worlds
