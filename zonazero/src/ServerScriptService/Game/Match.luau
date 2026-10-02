--[[
	Match: o ciclo da partida.
	  Lobby -> Countdown -> Match (salto de paraquedas, loot, zona) -> Ended -> Lobby
	Cada participante (jogador ou bot) é uma "entrada":
	  { Id, Player?, IsBot, Name, Model, Humanoid, Alive, Kills, Place }
	Atributos do Workspace para as telas: Phase, PhaseEndsAt, Alive, Total.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Match = {}

local entries: { any } = {}
local byPlayer: { [Player]: any } = {}
local byModel: { [Model]: any } = {}
local total = 0
local ended = false
local rng = Random.new()

local function setPhase(phase: string, endsAt: number?)
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("PhaseEndsAt", endsAt or 0)
end

function Match.Phase(): string
	return workspace:GetAttribute("Phase") or "Lobby"
end

function Match.EntryFor(player: Player): any
	return byPlayer[player]
end

function Match.EntryFromModel(model: Model): any
	return byModel[model]
end

function Match.AliveEntries(): { any }
	local list = {}
	for _, entry in entries do
		if entry.Alive then
			table.insert(list, entry)
		end
	end
	return list
end

local function aliveCount(): number
	return #Match.AliveEntries()
end

local function humansAlive(): number
	local n = 0
	for _, entry in entries do
		if entry.Alive and entry.Player then
			n += 1
		end
	end
	return n
end

local function updateCounts()
	workspace:SetAttribute("Alive", aliveCount())
	workspace:SetAttribute("Total", total)
end

-- Liga o modelo (personagem ou bot) à entrada e escuta a morte
function Match.BindModel(entry: any, model: Model)
	if entry.Model then
		byModel[entry.Model] = nil
	end
	entry.Model = model
	entry.Humanoid = model:FindFirstChildOfClass("Humanoid")
	byModel[model] = entry
	if entry.DiedConn then
		entry.DiedConn:Disconnect()
	end
	if entry.Humanoid then
		entry.DiedConn = entry.Humanoid.Died:Connect(function()
			Match.Eliminate(entry, "died")
		end)
	end
end

local function pickSpectateTarget(exclude: any?): any
	local alive = Match.AliveEntries()
	for _, entry in alive do
		if entry ~= exclude and entry.Player then
			return entry -- prefere assistir gente de verdade
		end
	end
	return alive[1]
end

local function sendSpectate(player: Player, target: any?)
	if target and target.Model then
		Registry.Remotes.SpectateTarget:FireClient(player, target.Model, target.Name)
	else
		Registry.Remotes.SpectateTarget:FireClient(player, nil, "")
	end
end

---------------------------------------------------------------------
-- Morte / eliminação
---------------------------------------------------------------------
function Match.Eliminate(entry: any, _reason: string)
	if not entry.Alive or ended then
		return
	end
	entry.Alive = false
	entry.Place = aliveCount() + 1
	local Combat = Registry.Combat
	local killer = entry.Humanoid and Combat.LastAttacker(entry.Humanoid)
	local root = entry.Model and entry.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local position = if root then root.Position else nil

	-- killfeed
	if killer and killer ~= entry then
		killer.Kills += 1
		if killer.Player then
			killer.Player:SetAttribute("MatchKills", killer.Kills)
		end
		Registry.Remotes.Killfeed:FireAllClients("KILLFEED", { killer = killer.Name, victim = entry.Name })
	elseif entry.LastZoneDamage and os.clock() - entry.LastZoneDamage < 2 then
		Registry.Remotes.Killfeed:FireAllClients("KILLFEED_ZONE", { victim = entry.Name })
	else
		Registry.Remotes.Killfeed:FireAllClients("KILLFEED_FALL", { victim = entry.Name })
	end

	-- tudo cai no chão
	if position then
		if entry.Player then
			Registry.Loot.DropAll(entry.Player, position)
		else
			Registry.Bots.DropLoot(entry, position)
		end
	end

	if entry.Player then
		local player = entry.Player
		player:SetAttribute("InMatch", false)
		Match.GiveResult(entry, false)
		entry.Spectating = if killer and killer.Alive then killer else pickSpectateTarget(entry)
		sendSpectate(player, entry.Spectating)
	end
	-- quem estava assistindo esta pessoa passa para outra
	for _, other in entries do
		if other.Player and not other.Alive and other.Spectating == entry then
			other.Spectating = pickSpectateTarget()
			sendSpectate(other.Player, other.Spectating)
		end
	end
	updateCounts()
	Match.CheckEnd()
end

-- XP e estatísticas de quem saiu da partida (morreu ou venceu)
function Match.GiveResult(entry: any, won: boolean)
	local player = entry.Player
	if not player or entry.ResultGiven then
		return
	end
	entry.ResultGiven = true
	local profile = Registry.Data.Get(player)
	local xp = Config.XP.Match + entry.Kills * Config.XP.Kill + math.max(0, total - entry.Place) * Config.XP.PerPlaceAbove
	if won then
		xp += Config.XP.Win
	end
	local leveledTo = nil
	if profile then
		local data = profile.Data
		data.Matches += 1
		data.Kills += entry.Kills
		if won then
			data.Wins += 1
		else
			data.Deaths += 1
		end
		if data.BestPlace == 0 or entry.Place < data.BestPlace then
			data.BestPlace = entry.Place
		end
		data.XP += xp
		while data.XP >= Config.XPForLevel(data.Level) do
			data.XP -= Config.XPForLevel(data.Level)
			data.Level += 1
			leveledTo = data.Level
		end
		Match.PublishStats(player)
	end
	Registry.Remotes.Result:FireClient(player, {
		Place = entry.Place,
		Total = total,
		Kills = entry.Kills,
		XP = xp,
		Won = won,
		Level = leveledTo,
	})
end

function Match.PublishStats(player: Player)
	local profile = Registry.Data.Get(player)
	if not profile then
		return
	end
	local data = profile.Data
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNeed", Config.XPForLevel(data.Level))
	player:SetAttribute("Wins", data.Wins)
	player:SetAttribute("TotalKills", data.Kills)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats :: any).Wins.Value = data.Wins;
		(stats :: any).Kills.Value = data.Kills
	end
end

function Match.CheckEnd()
	if ended or Match.Phase() ~= "Match" then
		return
	end
	local alive = Match.AliveEntries()
	if #alive <= 1 then
		Match.End(alive[1])
	elseif Config.Match.EndWhenOnlyBots and humansAlive() == 0 then
		Match.End(nil, true)
	end
end

function Match.End(winner: any?, onlyBots: boolean?)
	if ended then
		return
	end
	ended = true
	Registry.Zone.Stop()
	setPhase("Ended", workspace:GetServerTimeNow() + Config.Match.EndDelay)
	if winner then
		winner.Place = 1
		if winner.Player then
			winner.Player:SetAttribute("InMatch", false)
			Match.GiveResult(winner, true)
		end
		Registry.Remotes.NotifyAll("WINNER_IS", { name = winner.Name }, "big")
	elseif onlyBots then
		Registry.Remotes.NotifyAll("BOTS_WON", nil, "big")
	end
end

---------------------------------------------------------------------
-- Começo da partida
---------------------------------------------------------------------
local function clearTools(player: Player)
	for _, tool in Registry.Combat.PlayerTools(player) do
		tool:Destroy()
	end
end

-- Paraquedas: força para cima que segura parte da gravidade até tocar o chão
local function giveParachute(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "ParachuteAttachment"
	attachment.Parent = root
	-- velocidade de queda fixa (só no eixo Y): dá para andar para os lados enquanto desce
	local force = Instance.new("LinearVelocity")
	force.Name = "Parachute"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	force.LineDirection = Vector3.new(0, 1, 0)
	force.LineVelocity = -Config.Match.ParachuteFallSpeed
	force.MaxForce = root.AssemblyMass * workspace.Gravity * 3
	force.Parent = root
	-- velame colorido em cima da cabeça
	local canopy = Instance.new("Part")
	canopy.Name = "Canopy"
	canopy.Size = Vector3.new(9, 1.2, 6)
	canopy.Color = Color3.fromHSV(rng:NextNumber(), 0.7, 0.95)
	canopy.Material = Enum.Material.Fabric
	canopy.CanCollide = false
	canopy.CanQuery = false
	canopy.CanTouch = false
	canopy.Massless = true
	canopy.CFrame = root.CFrame * CFrame.new(0, 8, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = canopy
	weld.Parent = canopy
	canopy.Parent = character
	task.spawn(function()
		local started = os.clock()
		task.wait(1)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		while character.Parent and humanoid.Health > 0 and os.clock() - started < 40 do
			-- pousou: tem chão logo embaixo (raio do servidor, não depende do cliente)
			if workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params) then
				break
			end
			task.wait(0.1)
		end
		force:Destroy()
		attachment:Destroy()
		canopy:Destroy()
	end)
end

local function randomDropPoint(center: Vector3): Vector3
	local angle = rng:NextNumber() * math.pi * 2
	local dist = math.sqrt(rng:NextNumber()) * (Config.Zone.StartRadius * 0.75)
	return center + Vector3.new(math.cos(angle) * dist, Config.Match.DropHeight, math.sin(angle) * dist)
end

local function start()
	ended = false
	table.clear(entries)
	table.clear(byPlayer)
	table.clear(byModel)

	Registry.Loot.SpawnAll()
	local center = Vector3.new(rng:NextNumber(-120, 120), 0, rng:NextNumber(-120, 120))

	-- humanos
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if Registry.Data.Get(player) and humanoid and humanoid.Health > 0 and #entries < Config.Match.MaxParticipants then
			local entry = { Id = "p" .. player.UserId, Player = player, IsBot = false, Name = player.DisplayName, Alive = true, Kills = 0, Place = 0 }
			table.insert(entries, entry)
			byPlayer[player] = entry
		end
	end
	-- bots completam
	local botsNeeded = math.clamp(Config.Match.FillWithBots - #entries, 0, Config.Match.MaxParticipants - #entries)
	local names = table.clone(Config.Bots.Names)
	for i = 1, botsNeeded do
		local name = table.remove(names, rng:NextInteger(1, #names)) or ("Bot_" .. i)
		table.insert(entries, { Id = "b" .. i, Player = nil, IsBot = true, Name = name, Alive = true, Kills = 0, Place = 0 })
	end
	total = #entries

	-- bots primeiro e todos ao mesmo tempo (criar o avatar demora um pouco)
	local pendingBots = 0
	for _, entry in entries do
		if not entry.Player then
			pendingBots += 1
			task.spawn(function()
				local ok, err = pcall(function()
					Registry.Bots.Spawn(entry, Registry.Bots.GroundPoint(center))
					Match.BindModel(entry, entry.Model)
				end)
				if not ok then
					warn("[Match] bot não nasceu:", err)
					entry.Alive = false
				end
				pendingBots -= 1
			end)
		end
	end
	local waitStart = os.clock()
	while pendingBots > 0 and os.clock() - waitStart < 15 do
		task.wait(0.1)
	end

	for _, entry in entries do
		if entry.Player then
			local player = entry.Player
			local character = player.Character :: Model
			local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
			clearTools(player)
			Registry.Combat.ResetPlayer(player)
			humanoid.MaxHealth = Config.Player.MaxHealth
			humanoid.Health = Config.Player.MaxHealth
			character:SetAttribute("Shield", 0)
			player:SetAttribute("MatchKills", 0)
			player:SetAttribute("InMatch", true)
			Match.BindModel(entry, character)
			if Config.Match.StartWeapon then
				local tool = Registry.Combat.MakeWeaponTool(Config.Match.StartWeapon, "Common")
				tool.Parent = player:FindFirstChildOfClass("Backpack")
				for ammoType, amount in Config.Match.StartAmmo do
					Registry.Combat.AddAmmo(player, ammoType, amount)
				end
			end
			character:PivotTo(CFrame.new(randomDropPoint(center)))
			giveParachute(character)
		end
	end
	Registry.Remotes.NotifyAll("MATCH_DROP", nil, "big")
	setPhase("Match")
	updateCounts()
	Registry.Zone.Start(center)
end

local function backToLobby()
	Registry.Bots.Cleanup()
	Registry.Loot.Clear()
	for _, entry in entries do
		if entry.DiedConn then
			entry.DiedConn:Disconnect()
		end
	end
	table.clear(entries)
	table.clear(byPlayer)
	table.clear(byModel)
	total = 0
	updateCounts()
	setPhase("Lobby")
	for _, player in Players:GetPlayers() do
		player:SetAttribute("InMatch", false)
		Registry.Combat.ResetPlayer(player)
		clearTools(player)
		task.spawn(function()
			pcall(function()
				player:LoadCharacter()
			end)
		end)
	end
end

local function humansReady(): number
	local n = 0
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if Registry.Data.Get(player) and humanoid and humanoid.Health > 0 then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------
function Match.OnPlayerRemoving(player: Player)
	local entry = byPlayer[player]
	if entry and entry.Alive then
		Match.Eliminate(entry, "left")
	end
	byPlayer[player] = nil
end

function Match.Init()
	setPhase("Lobby")
	updateCounts()
	Registry.Remotes.Spectate.OnServerEvent:Connect(function(player: Player)
		local me = byPlayer[player]
		if not me or me.Alive then
			return
		end
		local alive = Match.AliveEntries()
		if #alive == 0 then
			return
		end
		local index = table.find(alive, me.Spectating) or 0
		me.Spectating = alive[index % #alive + 1]
		sendSpectate(player, me.Spectating)
	end)

	-- ciclo principal
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				-- LOBBY: espera gente suficiente
				setPhase("Lobby")
				while humansReady() < Config.Match.MinHumans do
					task.wait(1)
				end
				local lobbyEnds = workspace:GetServerTimeNow() + Config.Match.LobbyWait
				setPhase("Lobby", lobbyEnds)
				while workspace:GetServerTimeNow() < lobbyEnds do
					if humansReady() < Config.Match.MinHumans then
						return -- todo mundo saiu: recomeça a espera
					end
					task.wait(0.5)
				end
				local countdownEnds = workspace:GetServerTimeNow() + Config.Match.Countdown
				setPhase("Countdown", countdownEnds)
				task.wait(Config.Match.Countdown)
				if humansReady() < Config.Match.MinHumans then
					return
				end
				-- PARTIDA
				start()
				while not ended do
					task.wait(0.5)
					Match.CheckEnd()
				end
				task.wait(Config.Match.EndDelay)
				backToLobby()
			end)
			if not ok then
				warn("[Match] erro no ciclo:", err)
				ended = true
				pcall(Registry.Zone.Stop)
				pcall(backToLobby)
				task.wait(3)
			end
		end
	end)
end

return Match
