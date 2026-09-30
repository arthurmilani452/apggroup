--[[
	Minigames (ModuleScript em ServerScriptService > Game)
	Parte 23 (v12): HUB DE MINIGAMES na ilha ao norte do Meadow.
	  • A cada ~4 minutos: "OBBY RACE starting in 30s!" com botão JOIN (fila automática)
	  • Rodadas de 1 a 2 minutos e meio. Entrada GRÁTIS, sem aposta: só ganha quem joga.
	  • Jogos: Obby Race, King of the Hill, Critter Battle (Battle.luau), Cops & Robbers, Hide & Seek
	  • Todo mundo corre na MESMA velocidade (nada comprado ajuda) e a base de quem está jogando fica protegida
	  • Fim de semana (sábado e domingo, UTC): TORNEIO. Pontos no placar da ilha; 20 pontos = título "Weekend Champ"
	Estado para as telas: atributos do Workspace (MgState, MgGame, MgStarts, MgEnds, MgQueue, MgInfo)
	e do jogador (MgQueued, InMinigame, MgRole, MgSpeed).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Minigames = {}

local SETTINGS = Config.Minigames

type PlayerState = { Score: number, Role: string, Alive: boolean, Progress: number, LastCheckpoint: BasePart?, Finished: boolean, LastX: number, LastAt: number }
type Round = {
	Id: string,
	Info: any,
	Players: { [Player]: PlayerState },
	Ended: boolean,
	GoAt: number,
	EndsAt: number,
	Finishers: { Player },
	StartCount: number,
	Coins: number,
	Goal: number,
	LastFree: number,
	CoinParts: { BasePart },
}

local respawnAt: { [BasePart]: CFrame } = {} -- chão embaixo de cada checkpoint da corrida
local state = "idle"
local queue: { [Player]: boolean } = {}
local round: Round? = nil
local nextAnnounce = 0
local announced: any = nil
local startsAt = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function island(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Minigames")
end

local function piece(gameName: string, name: string): BasePart?
	local root = island()
	local folder = root and root:FindFirstChild(gameName)
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function publish()
	workspace:SetAttribute("MgState", state)
	workspace:SetAttribute("MgGame", if announced then announced.Id elseif round then round.Id else nil)
	local count = 0
	for _ in queue do
		count += 1
	end
	workspace:SetAttribute("MgQueue", count)
end

-- Leva o personagem (carrega o chão antes, por causa do StreamingEnabled)
local function sendTo(player: Player, cframe: CFrame)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cframe.Position, 3)
		end)
		local character = player.Character
		if character and character.Parent then
			character:PivotTo(cframe + Vector3.new(0, 3, 0))
		end
	end)
end

local function setSpeed(player: Player, speed: number)
	player:SetAttribute("MgSpeed", speed)
	Registry.Economy.ApplySpeed(player)
end

-- Esconde nome, título e pets (esconde-esconde) ou mostra de novo
local function setHidden(player: Player, hidden: boolean)
	player:SetAttribute("HidePets", if hidden then true else nil)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = if hidden then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BillboardGui") and (descendant.Name == "NameTag" or descendant.Name == "VipTag") then
			descendant.Enabled = not hidden
		elseif descendant:IsA("Trail") or (descendant:IsA("ParticleEmitter") and descendant.Name == "PrestigeAura") then
			descendant.Enabled = not hidden -- rastro e aura do prestígio entregariam o esconderijo
		end
	end
end

local function setHighlight(player: Player, color: Color3?)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("MgTeam")
	if old then
		old:Destroy()
	end
	if color then
		local highlight = Instance.new("Highlight")
		highlight.Name = "MgTeam"
		highlight.FillTransparency = 0.75
		highlight.OutlineColor = color
		highlight.FillColor = color
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = character
	end
end

local function roundNotify(text: string, kind: string?)
	if not round then
		return
	end
	for player in round.Players do
		if player.Parent then
			Registry.Remotes.Notify(player, text, kind)
		end
	end
end

local function info(value: any)
	if value == nil then
		workspace:SetAttribute("MgInfo", nil)
		return
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	workspace:SetAttribute("MgInfo", if ok then json else nil)
end

---------------------------------------------------------------------
-- Torneio de fim de semana
---------------------------------------------------------------------
local tournamentStore: OrderedDataStore? = nil
local tournamentWeek = -1
local boardText: TextLabel? = nil

local function isWeekend(): boolean
	local day = os.date("!*t", os.time()).wday
	return day == 1 or day == 7 -- domingo ou sábado (UTC)
end

local function weekId(): number
	return math.floor((os.time() - 4 * 86400) / 604800) -- semanas começando na segunda (UTC)
end

local function addTournament(player: Player, points: number)
	if points <= 0 or not isWeekend() then
		return
	end
	local data = getData(player)
	if not data then
		return
	end
	if type(data.Tournament) ~= "table" or data.Tournament.Week ~= weekId() then
		data.Tournament = { Week = weekId(), Points = 0 }
	end
	data.Tournament.Points += points
	Registry.Remotes.Notify(player, ("+%d tournament points! (%d this weekend)"):format(points, data.Tournament.Points), "info")
	local total = math.floor(data.Tournament.Points)
	local store = tournamentStore
	if store and tournamentWeek == weekId() then
		task.spawn(function()
			pcall(function()
				(store :: OrderedDataStore):SetAsync("u_" .. player.UserId, total)
			end)
		end)
	end
	if data.Tournament.Points >= SETTINGS.ChampPoints and type(data.Style) == "table" and type(data.Style.Owned) == "table" and not data.Style.Owned["title:champ"] then
		local codes = Registry.Codes
		if codes then
			codes.Grant(player, { Cosmetic = "title:champ" })
			Registry.Remotes.Notify(player, "WEEKEND CHAMP! You unlocked the title \"Weekend Champ\" (see STYLE).", "rare")
		end
	end
end

local function refreshTournamentBoard()
	if not boardText then
		return
	end
	if not isWeekend() then
		boardText.Text = "WEEKEND TOURNAMENT\n\nStarts on Saturday!\nWin minigames on the weekend\nfor points. 20 points =\n\"Weekend Champ\" title."
		return
	end
	local week = weekId()
	if week ~= tournamentWeek then
		tournamentWeek = week
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("Tournament_" .. week)
		end)
		tournamentStore = if ok then store else nil
	end
	local store = tournamentStore
	if not store then
		boardText.Text = "WEEKEND TOURNAMENT\n\n(only in the published game)"
		return
	end
	for _, player in Players:GetPlayers() do
		local data = getData(player)
		if data and type(data.Tournament) == "table" and data.Tournament.Week == week and data.Tournament.Points > 0 then
			pcall(function()
				store:SetAsync("u_" .. player.UserId, math.floor(data.Tournament.Points))
			end)
		end
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return
	end
	local lines = { "WEEKEND TOURNAMENT" }
	for i, entry in pages:GetCurrentPage() do
		local id = tonumber(string.sub(entry.key, 3)) or 0
		local okName, name = pcall(function()
			return Players:GetNameFromUserIdAsync(id)
		end)
		table.insert(lines, ("#%d %s - %d"):format(i, if okName then name else "Player", entry.value))
	end
	if #lines == 1 then
		table.insert(lines, "\nBe the first! Win a minigame.")
	end
	boardText.Text = table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- Prêmios
---------------------------------------------------------------------
local function grant(player: Player, minutes: number): string
	local codes = Registry.Codes
	if not codes or minutes <= 0 then
		return ""
	end
	local ok, parts = pcall(codes.Grant, player, { Minutes = minutes })
	return if ok and type(parts) == "table" then table.concat(parts, " + ") else ""
end

local function progressEvent(player: Player, kind: string)
	if Registry.Progress then
		Registry.Progress.Event(player, kind)
	end
end

---------------------------------------------------------------------
-- Entrar / sair
---------------------------------------------------------------------
function Minigames.Join(player: Player)
	if state ~= "announce" then
		return
	end
	if queue[player] then
		queue[player] = nil
		player:SetAttribute("MgQueued", nil)
		publish()
		return
	end
	local here = player:GetAttribute("World")
	if here ~= nil and here ~= "meadow" then
		Registry.Remotes.Notify(player, "Go back to Meadow Valley to join minigames (HOME button)!", "info")
		return
	end
	if Registry.CritterService.IsCarrying(player) then
		Registry.Remotes.Notify(player, "Put down what you're carrying first!", "warning")
		return
	end
	queue[player] = true
	player:SetAttribute("MgQueued", true)
	publish()
	Registry.Remotes.Notify(player, "You joined! Get ready...", "success")
end

-- Tira o jogador do minigame (fim da rodada, saiu, morreu)
local function release(player: Player, goHome: boolean)
	player:SetAttribute("InMinigame", nil)
	player:SetAttribute("MgRole", nil)
	player:SetAttribute("MgSpeed", nil)
	player:SetAttribute("MgProgress", nil)
	setHidden(player, false)
	setHighlight(player, nil)
	if player.Parent then
		Registry.Economy.ApplySpeed(player)
		local customize = Registry.Customize
		if customize then
			customize.RefreshTag(player)
		end
		if goHome then
			local plot = Registry.Plots.Get(player)
			if plot then
				sendTo(player, Registry.Plots.SpawnCFrame(plot))
			end
		end
	end
	local battle = Registry.Battle
	if battle then
		battle.Remove(player)
	end
end

---------------------------------------------------------------------
-- Fim da rodada
---------------------------------------------------------------------
local function finish(ranking: { Player }, winners: { [Player]: boolean }, title: string)
	local r = round
	if not r or r.Ended then
		return
	end
	r.Ended = true
	state = "results"
	publish()
	local lines = {}
	for place, player in ranking do
		if place <= 3 then
			table.insert(lines, ("%d. %s"):format(place, player.DisplayName))
		end
	end
	-- sozinho (ou só contra o Grumblob) é treino: ganha só a participação
	local competitive = r.StartCount >= 2
	local tournament = r.StartCount >= 3
	for player in r.Players do
		if player.Parent and player:GetAttribute("Loaded") then
			local place = table.find(ranking, player)
			local text
			if not competitive then
				text = grant(player, SETTINGS.Participation)
			elseif winners[player] then
				text = grant(player, SETTINGS.TeamWin)
				if tournament then
					addTournament(player, SETTINGS.TournamentWinPoints)
				end
				progressEvent(player, "MinigameWin")
			elseif place and place <= 3 and next(winners) == nil then
				text = grant(player, SETTINGS.Rewards[place])
				if tournament then
					addTournament(player, SETTINGS.TournamentPoints[place])
				end
				if place == 1 then
					progressEvent(player, "MinigameWin")
				end
			else
				text = grant(player, SETTINGS.Participation)
			end
			progressEvent(player, "Minigame")
			Registry.Remotes.Popup(
				player,
				title,
				(if #lines > 0 then table.concat(lines, "\n") .. "\n\n" else "")
					.. "You got: "
					.. text
					.. (if competitive then "" else "\n(Practice round: play with 2+ players to win prizes!)")
			)
		end
	end
	task.delay(SETTINGS.Results, function()
		for player in r.Players do
			if player.Parent then
				release(player, true)
			end
		end
		table.clear(r.Players)
		for _, coin in r.CoinParts do
			coin:Destroy()
		end
		if round == r then
			round = nil
		end
		state = "idle"
		nextAnnounce = now() + SETTINGS.Gap
		info(nil)
		workspace:SetAttribute("MgEnds", nil)
		publish()
	end)
end

local function alivePlayers(r: Round): { Player }
	local list = {}
	for player in r.Players do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function spread(center: CFrame, index: number, total: number, radius: number): CFrame
	local angle = (index / math.max(total, 1)) * math.pi * 2
	local position = center.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	return CFrame.lookAt(position, Vector3.new(center.Position.X, position.Y, center.Position.Z))
end

local function countdown(r: Round, seconds: number, speedAfter: number?)
	r.GoAt = now() + seconds
	workspace:SetAttribute("MgCountdown", r.GoAt)
	for player in r.Players do
		setSpeed(player, 0)
	end
	task.delay(seconds, function()
		if round == r and not r.Ended then
			for player in r.Players do
				if player.Parent and player:GetAttribute("MgRole") ~= "Seeker" then
					setSpeed(player, speedAfter or SETTINGS.Speed)
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- OBBY RACE
---------------------------------------------------------------------
local function startRace(r: Round)
	local start = piece("Race", "Start")
	if not start then
		finish({}, {}, "RACE")
		return
	end
	local list = alivePlayers(r)
	for index, player in list do
		local column = (index - 1) % 4
		local row = math.floor((index - 1) / 4)
		sendTo(player, CFrame.new(start.Position + Vector3.new(-4 + row * 3, 1, -7.5 + column * 5)) * CFrame.Angles(0, -math.pi / 2, 0))
		r.Players[player].LastCheckpoint = start
		r.Players[player].LastX = start.Position.X
	end
	countdown(r, 4)
	task.spawn(function()
		while round == r and not r.Ended do
			task.wait(0.3)
			for player, ps in r.Players do
				local root = rootOf(player)
				if root and not ps.Finished and root.Position.Y < 5 then
					local checkpoint = ps.LastCheckpoint or start
					root.AssemblyLinearVelocity = Vector3.zero
					local spot = respawnAt[checkpoint] or CFrame.new(checkpoint.Position.X, checkpoint.Position.Y + checkpoint.Size.Y / 2 + 3, checkpoint.Position.Z)
					player.Character:PivotTo(spot * CFrame.Angles(0, -math.pi / 2, 0))
				end
			end
			local total, done = 0, 0
			for player, ps in r.Players do
				if player.Parent then
					total += 1
					if ps.Finished then
						done += 1
					end
				end
			end
			if total == 0 or done >= total or now() >= r.EndsAt then
				finish(table.clone(r.Finishers), {}, "OBBY RACE RESULTS") -- prêmios só para quem chegou
			end
		end
	end)
end

local function onRaceTouch(player: Player, part: BasePart)
	local r = round
	local ps = r and r.Id == "Race" and not r.Ended and r.Players[player]
	if not r or not ps or ps.Finished or now() < r.GoAt then
		return
	end
	local number = tonumber(string.match(part.Name, "^CP(%d+)$"))
	-- contra teleporte: tem que levar pelo menos o tempo de correr até ali (com folga)
	local startAt = if ps.Progress == 0 then r.GoAt else ps.LastAt
	local tooFast = now() - startAt < math.abs(part.Position.X - ps.LastX) / (SETTINGS.Speed * 1.35)
	if tooFast then
		return
	end
	if number and number == ps.Progress + 1 then
		ps.LastX = part.Position.X
		ps.LastAt = now()
		ps.Progress = number
		ps.LastCheckpoint = part
		player:SetAttribute("MgProgress", number)
		Registry.Remotes.Notify(player, ("Checkpoint %d/4!"):format(number), "info")
	elseif part.Name == "Finish" and ps.Progress >= 4 then
		ps.Finished = true
		table.insert(r.Finishers, player)
		local place = #r.Finishers
		setSpeed(player, 0)
		roundNotify(("%s finished #%d!"):format(player.DisplayName, place), if place <= 3 then "rare" else "info")
	end
end

---------------------------------------------------------------------
-- KING OF THE HILL
---------------------------------------------------------------------
local function scoreRanking(r: Round): { Player }
	local list = {}
	for player, ps in r.Players do
		if player.Parent and ps.Score > 0 then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		return r.Players[a].Score > r.Players[b].Score
	end)
	return list
end

local function startKing(r: Round)
	local center = piece("King", "Center")
	local zone = piece("King", "Zone")
	if not center or not zone then
		finish({}, {}, "KING OF THE HILL")
		return
	end
	local list = alivePlayers(r)
	for index, player in list do
		sendTo(player, spread(CFrame.new(center.Position), index, #list, 38))
	end
	countdown(r, 4)
	task.spawn(function()
		local ticks = 0
		while round == r and not r.Ended do
			task.wait(0.25)
			ticks += 1
			if now() >= r.GoAt then
				for player, ps in r.Players do
					local root = rootOf(player)
					if root then
						local offset = root.Position - zone.Position
						if Vector3.new(offset.X, 0, offset.Z).Magnitude <= 7.5 and offset.Y > -1 and offset.Y < 9 then
							ps.Score += 0.25
						end
					end
				end
			end
			if ticks % 4 == 0 then
				local top = {}
				for _, player in scoreRanking(r) do
					if #top < 5 then
						table.insert(top, { N = player.DisplayName, S = math.floor(r.Players[player].Score) })
					end
				end
				info({ Top = top })
			end
			if #alivePlayers(r) == 0 or now() >= r.EndsAt then
				finish(scoreRanking(r), {}, "KING OF THE HILL RESULTS")
			end
		end
	end)
end

---------------------------------------------------------------------
-- COPS & ROBBERS
---------------------------------------------------------------------
local function randomPoint(area: BasePart): Vector3
	local size = area.Size
	return area.Position + Vector3.new((math.random() - 0.5) * (size.X - 12), 2.5, (math.random() - 0.5) * (size.Z - 12))
end

local function spawnCoin(r: Round, area: BasePart)
	local coin = Instance.new("Part")
	coin.Name = "MgCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.5, 3, 3)
	coin.Color = Color3.fromRGB(255, 205, 60)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CFrame = CFrame.new(randomPoint(area)) * CFrame.Angles(0, 0, math.pi / 2)
	coin:AddTag("Spin")
	coin.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local ps = player and r.Players[player]
		if not ps or r.Ended or round ~= r or ps.Role ~= "Robber" or not ps.Alive or not coin.Parent then
			return
		end
		coin:Destroy()
		ps.Score += 1
		r.Coins += 1
		info({ Coins = r.Coins, Goal = r.Goal })
		if r.Coins >= r.Goal then
			return
		end
		task.delay(2, function()
			if round == r and not r.Ended then
				spawnCoin(r, area)
			end
		end)
	end)
	coin.Parent = island()
	table.insert(r.CoinParts, coin)
end

local function teamRanking(r: Round, role: string): { Player }
	local list = {}
	for player, ps in r.Players do
		if player.Parent and ps.Role == role then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		return r.Players[a].Score > r.Players[b].Score
	end)
	return list
end

local function endTeams(r: Round, winningRole: string, title: string)
	local winners = {}
	local ranking = teamRanking(r, winningRole)
	for _, player in ranking do
		winners[player] = true
	end
	finish(ranking, winners, title)
end

local function startCops(r: Round)
	local area = piece("Playground", "Area")
	local copSpawn = piece("Playground", "CopSpawn")
	local robberSpawn = piece("Playground", "RobberSpawn")
	if not area or not copSpawn or not robberSpawn then
		finish({}, {}, "COPS & ROBBERS")
		return
	end
	local list = alivePlayers(r)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	local cops = math.max(1, math.floor(#list / 3))
	local robbers = #list - cops
	for index, player in list do
		local ps = r.Players[player]
		ps.Role = if index <= cops then "Cop" else "Robber"
		player:SetAttribute("MgRole", ps.Role)
		setHighlight(player, if ps.Role == "Cop" then Color3.fromRGB(70, 140, 255) else Color3.fromRGB(255, 150, 60))
		local spawnPart = if ps.Role == "Cop" then copSpawn else robberSpawn
		sendTo(player, CFrame.new(spawnPart.Position + Vector3.new(math.random(-8, 8), 1, math.random(-8, 8))))
	end
	r.Goal = 10 + 2 * robbers
	info({ Coins = 0, Goal = r.Goal })
	countdown(r, 4)
	for _ = 1, 12 do
		spawnCoin(r, area)
	end
	task.spawn(function()
		while round == r and not r.Ended do
			task.wait(0.5)
			local free = 0
			local robbersLeft = 0
			for player, ps in r.Players do
				if player.Parent and ps.Role == "Robber" then
					robbersLeft += 1
					if ps.Alive then
						free += 1
					end
				end
			end
			if r.Coins >= r.Goal then
				endTeams(r, "Robber", "ROBBERS WIN! (all the coins)")
			elseif robbersLeft == 0 or free == 0 then
				endTeams(r, "Cop", "COPS WIN! (everyone in jail)")
			elseif #teamRanking(r, "Cop") == 0 then
				endTeams(r, "Robber", "ROBBERS WIN!")
			elseif now() >= r.EndsAt then
				endTeams(r, "Robber", "ROBBERS WIN! (time's up)")
			end
		end
	end)
end

local function onJailButton(player: Player)
	local r = round
	local ps = r and r.Id == "Cops" and not r.Ended and r.Players[player]
	if not r or not ps or ps.Role ~= "Robber" or not ps.Alive or os.clock() - r.LastFree < 8 then
		return
	end
	local robberSpawn = piece("Playground", "RobberSpawn")
	local freed = 0
	for other, otherState in r.Players do
		if otherState.Role == "Robber" and not otherState.Alive and other.Parent and robberSpawn then
			otherState.Alive = true
			freed += 1
			sendTo(other, CFrame.new(robberSpawn.Position + Vector3.new(math.random(-6, 6), 1, math.random(-6, 6))))
		end
	end
	if freed > 0 then
		r.LastFree = os.clock()
		roundNotify(("%s opened the jail! %d robbers are free!"):format(player.DisplayName, freed), "rare")
	end
end

---------------------------------------------------------------------
-- HIDE & SEEK
---------------------------------------------------------------------
local SEEKER_WAIT = 15

local function startHide(r: Round)
	local area = piece("Playground", "Area")
	local seekerSpot = piece("Playground", "SeekerSpot")
	if not area or not seekerSpot then
		finish({}, {}, "HIDE & SEEK")
		return
	end
	local list = alivePlayers(r)
	local seeker = list[math.random(1, #list)]
	for _, player in list do
		local ps = r.Players[player]
		ps.Role = if player == seeker then "Seeker" else "Hider"
		player:SetAttribute("MgRole", ps.Role)
		if ps.Role == "Seeker" then
			sendTo(player, CFrame.new(seekerSpot.Position))
			setHighlight(player, Color3.fromRGB(255, 70, 70))
		else
			setHidden(player, true)
			sendTo(player, CFrame.new(randomPoint(area)))
		end
	end
	countdown(r, 3)
	setSpeed(seeker, 0)
	workspace:SetAttribute("MgSeekerAt", now() + SEEKER_WAIT)
	info({ Hiders = #list - 1, Found = 0 })
	task.delay(SEEKER_WAIT, function()
		if round == r and not r.Ended and seeker.Parent then
			sendTo(seeker, CFrame.new(area.Position + Vector3.new(0, 1, 0)))
			setSpeed(seeker, SETTINGS.Speed + 3)
			roundNotify("READY OR NOT, HERE I COME! The seeker is out!", "warning")
		end
	end)
	task.spawn(function()
		while round == r and not r.Ended do
			task.wait(0.5)
			local hiders, hidden = 0, 0
			local seekerHere = false
			for player, ps in r.Players do
				if player.Parent then
					if ps.Role == "Hider" then
						hiders += 1
						if ps.Alive then
							hidden += 1
						end
					elseif ps.Role == "Seeker" then
						seekerHere = true
					end
				end
			end
			info({ Hiders = hiders, Found = hiders - hidden })
			if hiders > 0 and hidden == 0 then
				endTeams(r, "Seeker", "THE SEEKER FOUND EVERYONE!")
			elseif not seekerHere or hiders == 0 or now() >= r.EndsAt then
				local winners = {}
				local ranking = {}
				for player, ps in r.Players do
					if player.Parent and ps.Role == "Hider" and ps.Alive then
						winners[player] = true
						table.insert(ranking, player)
					end
				end
				finish(ranking, winners, "HIDERS WIN!")
			end
		end
	end)
end

---------------------------------------------------------------------
-- CRITTER BATTLE
---------------------------------------------------------------------
local function startBattle(r: Round)
	local spot = piece("Battle", "Spot")
	local list = alivePlayers(r)
	if spot then
		for index, player in list do
			sendTo(player, spread(CFrame.new(spot.Position), index, #list, 12))
		end
	end
	for player in r.Players do
		setSpeed(player, 0)
	end
	task.spawn(function()
		local winners, _ = Registry.Battle.Run(list, r.Info.Duration - 5) -- vitória contra o Grumblob não conta
		if round ~= r or r.Ended then
			return
		end
		local set = {}
		for _, player in winners do
			set[player] = true
		end
		finish(winners, set, "CRITTER BATTLE RESULTS")
	end)
end

---------------------------------------------------------------------
-- Pancadas (o Combat pergunta antes de empurrar)
---------------------------------------------------------------------
local function roleOf(player: Player): string?
	local r = round
	local ps = r and r.Players[player]
	return ps and ps.Role
end

function Minigames.BonkAllowed(attacker: Player, victim: Player): boolean
	local a = attacker:GetAttribute("InMinigame")
	local v = victim:GetAttribute("InMinigame")
	if a == nil and v == nil then
		return true -- mundo normal
	end
	local r = round
	if a ~= v or not r or r.Ended then
		return false
	end
	if r.Id == "King" then
		return true
	elseif r.Id == "Cops" then
		local ra, rv = roleOf(attacker), roleOf(victim)
		local psv = r.Players[victim]
		return (ra == "Cop" and rv == "Robber" and psv ~= nil and psv.Alive) or (ra == "Robber" and rv == "Cop")
	elseif r.Id == "Hide" then
		local psv = r.Players[victim]
		return roleOf(attacker) == "Seeker" and roleOf(victim) == "Hider" and psv ~= nil and psv.Alive and now() >= r.GoAt
	end
	return false
end

function Minigames.OnBonk(attacker: Player, victim: Player)
	local r = round
	if not r or r.Ended then
		return
	end
	local psa, psv = r.Players[attacker], r.Players[victim]
	if not psa or not psv then
		return
	end
	if r.Id == "Cops" and psa.Role == "Cop" and psv.Role == "Robber" and psv.Alive then
		psv.Alive = false
		psa.Score += 1
		local jail = piece("Playground", "JailSpot")
		if jail then
			task.delay(0.2, function()
				sendTo(victim, CFrame.new(jail.Position))
			end)
		end
		roundNotify(("%s was caught by %s!"):format(victim.DisplayName, attacker.DisplayName), "warning")
	elseif r.Id == "Hide" and psa.Role == "Seeker" and psv.Role == "Hider" and psv.Alive then
		psv.Alive = false
		psa.Score += 1
		setHidden(victim, false)
		local stands = piece("Playground", "StandsSpot")
		if stands then
			task.delay(0.2, function()
				sendTo(victim, CFrame.new(stands.Position))
			end)
		end
		roundNotify(("Found %s!"):format(victim.DisplayName), "warning")
	end
end

---------------------------------------------------------------------
-- Ciclo: anuncia -> joga -> resultado -> espera
---------------------------------------------------------------------
local STARTERS = { Race = startRace, King = startKing, Cops = startCops, Hide = startHide, Battle = startBattle }

local function loadedCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Loaded") then
			count += 1
		end
	end
	return count
end

local forced = false

function Minigames.Announce(gameId: string?, force: boolean?)
	if state ~= "idle" then
		return
	end
	forced = force == true -- admin: começa mesmo com pouca gente (para testar)
	local online = loadedCount()
	local pick = if gameId then Config.MinigameById[gameId] else nil
	if not pick then
		local total = 0
		for _, info2 in SETTINGS.Games do
			if info2.Min <= online then
				total += info2.Weight
			end
		end
		local roll = math.random() * total
		for _, info2 in SETTINGS.Games do
			if info2.Min <= online then
				roll -= info2.Weight
				if roll <= 0 then
					pick = info2
					break
				end
			end
		end
	end
	if not pick then
		nextAnnounce = now() + 60
		return
	end
	announced = pick
	state = "announce"
	startsAt = now() + SETTINGS.Announce
	workspace:SetAttribute("MgStarts", startsAt)
	table.clear(queue)
	publish()
	Registry.Remotes.NotifyAll(("%s starting in %ds! Tap JOIN at the top of the screen."):format(string.upper(pick.Name), SETTINGS.Announce), "rare")
	Registry.Remotes.EffectAll("MinigameAnnounce", pick.Id)
end

local function start()
	local pick = announced
	announced = nil
	local players = {}
	for player in queue do
		local here = player:GetAttribute("World")
		if player.Parent and player:GetAttribute("Loaded") and not Registry.CritterService.IsCarrying(player) and (here == nil or here == "meadow") then
			table.insert(players, player)
		end
		player:SetAttribute("MgQueued", nil)
	end
	table.clear(queue)
	if not pick or #players == 0 or (#players < pick.Min and not forced) then
		state = "idle"
		nextAnnounce = now() + 45
		publish()
		if pick then
			Registry.Remotes.NotifyAll(("Not enough players joined %s (needs %d). Next minigame soon!"):format(pick.Name, pick.Min), "info")
		end
		return
	end
	local r: Round = {
		Id = pick.Id,
		Info = pick,
		Players = {},
		Ended = false,
		GoAt = now(),
		EndsAt = now() + pick.Duration,
		Finishers = {},
		StartCount = #players,
		Coins = 0,
		Goal = 0,
		LastFree = 0,
		CoinParts = {},
	}
	for _, player in players do
		r.Players[player] = { Score = 0, Role = "Player", Alive = true, Progress = 0, LastCheckpoint = nil, Finished = false, LastX = 0, LastAt = 0 }
		player:SetAttribute("InMinigame", pick.Id)
		player:SetAttribute("MgRole", "Player")
	end
	round = r
	state = "play"
	workspace:SetAttribute("MgEnds", r.EndsAt)
	publish()
	for player in r.Players do
		Registry.Remotes.Notify(player, pick.Desc, "info")
	end
	STARTERS[pick.Id](r)
end

-- Personagem novo (resetou/morreu): sai do minigame
function Minigames.OnCharacter(player: Player)
	local r = round
	if r and r.Players[player] then
		r.Players[player] = nil
		release(player, false)
	end
end

function Minigames.RemovePlayer(player: Player)
	queue[player] = nil
	local r = round
	if r then
		r.Players[player] = nil
	end
	local battle = Registry.Battle
	if battle then
		battle.Remove(player)
	end
	publish()
end

function Minigames.Init()
	Players.PlayerRemoving:Connect(Minigames.RemovePlayer)
	nextAnnounce = now() + SETTINGS.FirstAfter
	publish()
	task.spawn(function()
		local root = workspace:WaitForChild("Map"):WaitForChild("Minigames", 30)
		if not root then
			warn("[Minigames] Map.Minigames not found: minigames are off")
			return
		end
		-- corrida: checkpoints e chegada
		local race = root:FindFirstChild("Race")
		if race then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { race }
			for _, child in race:GetChildren() do
				if child:IsA("BasePart") and (string.match(child.Name, "^CP%d+$") or child.Name == "Start") then
					local hit = workspace:Raycast(Vector3.new(child.Position.X, 60, child.Position.Z), Vector3.new(0, -80, 0), params)
					if hit then
						respawnAt[child] = CFrame.new(hit.Position + Vector3.new(0, 3.5, 0))
					end
				end
			end
			for _, child in race:GetChildren() do
				if child:IsA("BasePart") and (string.match(child.Name, "^CP%d+$") or child.Name == "Finish") then
					child.Touched:Connect(function(hit)
						local player = Players:GetPlayerFromCharacter(hit.Parent)
						if player then
							onRaceTouch(player, child)
						end
					end)
				end
			end
		end
		local button = piece("Playground", "JailButton")
		if button then
			button.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					onJailButton(player)
				end
			end)
		end
		-- placar do torneio
		local board = root:FindFirstChild("TournamentBoard") :: BasePart?
		if board then
			local surface = Instance.new("SurfaceGui")
			surface.Face = Enum.NormalId.Back
			surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			surface.PixelsPerStud = 25
			surface.LightInfluence = 0
			local text = Instance.new("TextLabel")
			text.Size = UDim2.new(1, -30, 1, -30)
			text.Position = UDim2.fromOffset(15, 15)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.TextColor3 = Color3.fromRGB(255, 225, 120)
			text.Text = ""
			text.Parent = surface
			surface.Parent = board
			boardText = text
		end
		while true do
			local ok, err = pcall(function()
				refreshTournamentBoard()
			end)
			if not ok then
				warn("[Minigames] loop error:", err)
			end
			task.wait(60)
		end
	end)
	-- relógio do ciclo (+ vigia: quem saiu da ilha no meio da rodada sai do minigame)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				local r = round
				if r and not r.Ended and now() > r.GoAt + 3 then
					for player in r.Players do
						local rootPart = rootOf(player)
						if rootPart and math.abs(rootPart.Position.Z - (-1000)) > 200 then
							r.Players[player] = nil
							release(player, false)
						end
					end
				end
				local t = now()
				if state == "idle" and t >= nextAnnounce then
					Minigames.Announce(nil)
				elseif state == "announce" and t >= startsAt then
					start()
				end
			end)
			if not ok then
				warn("[Minigames] loop error:", err)
			end
		end
	end)
end

return Minigames
