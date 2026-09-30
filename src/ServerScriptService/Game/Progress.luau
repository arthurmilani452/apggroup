--[[
	Progress (ModuleScript em ServerScriptService > Game)
	Parte 26 + missões diárias + conquistas (v10). O servidor decide tudo:
	  • nível da conta (o XP vem junto com o XP da temporada, com o mesmo limite diário anti-farm)
	  • árvore de habilidades (1 ponto por nível) e reset grátis 1 vez por dia
	  • classes Thief / Guardian / Creator (troca grátis, espera 30 min)
	  • prestígio com 10 rebirths: aura, estrela no nome e +100% de dinheiro para sempre
	  • 3 missões por dia + 1 troca grátis; prêmio em dinheiro e um ovo grátis por completar as 3
	  • conquistas (e Badges do Roblox, se os IDs estiverem em Progression.BadgeIds)
	  • recordes pessoais para a tela PROFILE
	A tela recebe tudo pelo RemoteEvent "ProgressSync".
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Critters = require(ReplicatedStorage.Shared.Critters)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Registry = require(script.Parent.Registry)

local Progress = {}

local dirty: { [Player]: boolean } = {}
local needsCheck: { [Player]: boolean } = {}
local badgeTried: { [Player]: { [string]: boolean } } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

-- Arruma os campos novos (saves antigos não têm nada disso)
local function ensure(data: any)
	if type(data.Progress) ~= "table" then
		data.Progress = {}
	end
	local progress = data.Progress
	progress.XP = math.max(0, tonumber(progress.XP) or 0)
	if type(progress.Skills) ~= "table" then
		progress.Skills = {}
	end
	progress.ResetDay = tonumber(progress.ResetDay) or 0
	progress.Class = if type(progress.Class) == "string" and Progression.Classes[progress.Class] then progress.Class else ""
	progress.ClassAt = tonumber(progress.ClassAt) or 0
	if type(data.Records) ~= "table" then
		data.Records = {}
	end
	if type(data.Achievements) ~= "table" then
		data.Achievements = {}
	end
	if type(data.BadgesSent) ~= "table" then
		data.BadgesSent = {}
	end
	if type(data.Missions) ~= "table" then
		data.Missions = {}
	end
	data.Prestige = math.max(0, math.floor(tonumber(data.Prestige) or 0))
	data.PeakRebirths = math.max(tonumber(data.PeakRebirths) or 0, tonumber(data.Rebirths) or 0)
end

local function markDirty(player: Player)
	dirty[player] = true
	needsCheck[player] = true
end

---------------------------------------------------------------------
-- Nível e habilidades
---------------------------------------------------------------------
function Progress.Level(player: Player): number
	local data = getData(player)
	if not data or type(data.Progress) ~= "table" then
		return 1
	end
	return (Progression.LevelFromXP(tonumber(data.Progress.XP) or 0))
end

local function rank(player: Player, name: string): number
	local data = getData(player)
	local skills = data and type(data.Progress) == "table" and data.Progress.Skills
	local info = Progression.Skills[name]
	if type(skills) ~= "table" or not info then
		return 0
	end
	return math.clamp(math.floor(tonumber(skills[name]) or 0), 0, info.Max)
end

local function classOf(player: Player): string
	local data = getData(player)
	return if data and type(data.Progress) == "table" and type(data.Progress.Class) == "string" then data.Progress.Class else ""
end

local function spentPoints(data: any): number
	local spent = 0
	for _, name in Progression.SkillOrder do
		spent += math.clamp(math.floor(tonumber(data.Progress.Skills[name]) or 0), 0, Progression.Skills[name].Max)
	end
	return spent
end

-- Efeitos (quem chama: Economy, Plots e CritterService)
function Progress.SpeedMultiplier(player: Player): number
	return 1 + rank(player, "Speed") * Progression.Skills.Speed.Per
end

function Progress.CarryMultiplier(player: Player, base: number): number
	local bonus = rank(player, "Steal") * Progression.Skills.Steal.Per
	if classOf(player) == "Thief" then
		bonus += Progression.ThiefCarry
	end
	return math.min(Progression.MaxCarryMultiplier, base + bonus)
end

function Progress.LockBonus(player: Player): number
	local bonus = rank(player, "Defense") * Progression.Skills.Defense.Per
	if classOf(player) == "Guardian" then
		bonus += Progression.GuardianLock
	end
	return bonus
end

function Progress.LuckMultiplier(player: Player): number
	return 1 + rank(player, "Luck") * Progression.Skills.Luck.Per
end

function Progress.HatchMultiplier(player: Player): number
	return if classOf(player) == "Creator" then Progression.CreatorHatch else 1
end

function Progress.PrestigeMultiplier(player: Player): number
	local data = getData(player)
	local prestige = if data then tonumber(data.Prestige) or 0 else 0
	return 1 + prestige * Progression.PrestigeBonus
end

-- Rebirths que contam para vagas e esteira (o prestígio não tira as vagas que você já tinha)
function Progress.PeakRebirths(player: Player): number
	local data = getData(player)
	if not data then
		return 0
	end
	return math.max(tonumber(data.Rebirths) or 0, tonumber(data.PeakRebirths) or 0)
end

---------------------------------------------------------------------
-- Prêmios
---------------------------------------------------------------------
local function grant(player: Player, reward): string
	local codes = Registry.Codes
	if not codes then
		return ""
	end
	local ok, parts = pcall(codes.Grant, player, reward)
	return if ok and type(parts) == "table" then table.concat(parts, " + ") else ""
end

---------------------------------------------------------------------
-- Missões diárias
---------------------------------------------------------------------
local function ensureMissions(player: Player, data: any)
	local day = today()
	local missions = data.Missions
	if missions.Day == day and type(missions.List) == "table" then
		return missions
	end
	local list = {}
	for _, pick in Progression.PickMissions(player.UserId, day) do
		table.insert(list, { Kind = pick.Kind, Need = pick.Need, Have = 0, Done = false })
	end
	data.Missions = { Day = day, List = list, Swapped = false, Bonus = false }
	return data.Missions
end

local function completeMission(player: Player, data: any, missions: any, mission: any)
	mission.Done = true
	mission.Have = mission.Need
	local text = grant(player, Progression.MissionReward)
	Registry.Remotes.Notify(player, ("QUEST COMPLETE: %s! +%s"):format(Progression.MissionText(mission.Kind, mission.Need), text), "success")
	Registry.Remotes.Effect(player, "Quest")
	for _, other in missions.List do
		if not other.Done then
			return
		end
	end
	if not missions.Bonus then
		missions.Bonus = true
		data.Records.MissionDays = (tonumber(data.Records.MissionDays) or 0) + 1
		local bonus = grant(player, Progression.MissionBonus)
		local season = Registry.Season
		if season then
			season.AddXP(player, Progression.MissionBonusXP, "Quests")
		end
		Registry.Remotes.Notify(player, "ALL 3 QUESTS DONE! Bonus: " .. bonus .. ". New quests tomorrow!", "rare")
		Registry.Remotes.Effect(player, "QuestsAll")
	end
end

-- Troca 1 missão (1 vez por dia, grátis)
function Progress.Swap(player: Player, index: any)
	local data = getData(player)
	if not data or typeof(index) ~= "number" then
		return
	end
	ensure(data)
	local missions = ensureMissions(player, data)
	local mission = missions.List[math.floor(index)]
	if not mission or mission.Done then
		return
	end
	if missions.Swapped then
		Registry.Remotes.Notify(player, "You already swapped a quest today. New quests tomorrow!", "info")
		return
	end
	local used = {}
	for _, other in missions.List do
		used[other.Kind] = true
	end
	local options = {}
	for _, info in Progression.MissionPool do
		if not used[info.Kind] then
			table.insert(options, info)
		end
	end
	if #options == 0 then
		return
	end
	local pick = options[math.random(1, #options)]
	missions.List[math.floor(index)] = { Kind = pick.Kind, Need = pick.Need, Have = 0, Done = false }
	missions.Swapped = true
	Registry.Remotes.Notify(player, "New quest: " .. Progression.MissionText(pick.Kind, pick.Need), "info")
	markDirty(player)
end

---------------------------------------------------------------------
-- Eventos (chocou, roubou, fez carinho...) -> missões e recordes
---------------------------------------------------------------------
local RECORD_OF = {
	Shiny = "Shinies", GiantEgg = "GiantEggs", Mix = "Mixes", Monster = "Monsters", Minigame = "Minigames", MinigameWin = "MinigameWins",
	Island = "IslandVisits", Fish = "Fish", Fossil = "Fossils", HuntDone = "HuntDays", Hunt = "HuntEggs", Dig = "Digs",
}

function Progress.Event(player: Player, kind: string, amount: number?)
	local data = getData(player)
	if not data or not player:GetAttribute("Loaded") then
		return
	end
	ensure(data)
	local count = math.max(1, math.floor(amount or 1))
	local record = RECORD_OF[kind]
	if record then
		data.Records[record] = (tonumber(data.Records[record]) or 0) + count
	end
	local missions = ensureMissions(player, data)
	for _, mission in missions.List do
		if mission.Kind == kind and not mission.Done then
			mission.Have = math.min(mission.Need, (tonumber(mission.Have) or 0) + count)
			if mission.Have >= mission.Need then
				completeMission(player, data, missions, mission)
			end
		end
	end
	markDirty(player)
end

---------------------------------------------------------------------
-- XP da conta (o Season chama depois de aplicar o limite diário)
---------------------------------------------------------------------
function Progress.AddXP(player: Player, amount: number)
	local data = getData(player)
	if not data or amount <= 0 then
		return
	end
	ensure(data)
	local before = Progression.LevelFromXP(data.Progress.XP)
	data.Progress.XP += math.floor(amount)
	local after = Progression.LevelFromXP(data.Progress.XP)
	if after > before then
		player:SetAttribute("Level", after)
		Registry.Remotes.Notify(player, ("LEVEL UP! You are level %d. You got a skill point: open QUESTS > SKILLS"):format(after), "rare")
		Registry.Remotes.Effect(player, "LevelUp", after)
	end
	markDirty(player)
end

---------------------------------------------------------------------
-- Habilidades e classes (pedidos da tela)
---------------------------------------------------------------------
function Progress.SkillUp(player: Player, name: any)
	local data = getData(player)
	local info = typeof(name) == "string" and Progression.Skills[name]
	if not data or not info then
		return
	end
	ensure(data)
	local points = Progression.PointsForLevel(Progress.Level(player)) - spentPoints(data)
	local current = rank(player, name)
	if current >= info.Max then
		Registry.Remotes.Notify(player, info.Name .. " is already MAX!", "info")
		return
	end
	if points <= 0 then
		Registry.Remotes.Notify(player, "No skill points left. Level up to get more!", "info")
		return
	end
	data.Progress.Skills[name] = current + 1
	Registry.Economy.ApplySpeed(player)
	Registry.Remotes.Effect(player, "SkillUp", name)
	markDirty(player)
end

function Progress.SkillReset(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	if data.Progress.ResetDay == today() then
		Registry.Remotes.Notify(player, "You already used your free reset today. Come back tomorrow!", "info")
		return
	end
	if spentPoints(data) == 0 then
		return
	end
	data.Progress.Skills = {}
	data.Progress.ResetDay = today()
	Registry.Economy.ApplySpeed(player)
	Registry.Remotes.Notify(player, "Skills reset! Spend your points again.", "success")
	markDirty(player)
end

function Progress.SetClass(player: Player, name: any)
	local data = getData(player)
	if not data or typeof(name) ~= "string" or not Progression.Classes[name] then
		return
	end
	ensure(data)
	if data.Progress.Class == name then
		return
	end
	local wait = data.Progress.ClassAt + Progression.ClassCooldown - os.time()
	if data.Progress.Class ~= "" and wait > 0 then
		Registry.Remotes.Notify(player, "You can change class again in " .. Format.Time(wait), "info")
		return
	end
	data.Progress.Class = name
	data.Progress.ClassAt = os.time()
	player:SetAttribute("Class", name)
	Registry.Economy.ApplySpeed(player)
	Registry.Remotes.Notify(player, ("You are now a %s! %s"):format(name, Progression.Classes[name].Desc), "success")
	Registry.Remotes.Effect(player, "SkillUp", name)
	markDirty(player)
end

---------------------------------------------------------------------
-- Prestígio (10 rebirths)
---------------------------------------------------------------------
function Progress.ApplyAura(player: Player)
	local data = getData(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return
	end
	local old = root:FindFirstChild("PrestigeAura")
	if old then
		old:Destroy()
	end
	local prestige = tonumber(data.Prestige) or 0
	if prestige <= 0 then
		return
	end
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "PrestigeAura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(Progression.PrestigeColor(prestige))
	aura.LightEmission = 0.7
	aura.Size = NumberSequence.new(0.5, 0)
	aura.Transparency = NumberSequence.new(0.2, 1)
	aura.Lifetime = NumberRange.new(1, 1.6)
	aura.Speed = NumberRange.new(1, 2.5)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Rate = 6 + math.min(prestige, 5) * 2
	aura.Parent = root
end

function Progress.Prestige(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	local needed = Progression.PrestigeNeed(data.Prestige)
	if data.Rebirths < needed then
		Registry.Remotes.Notify(player, ("You need %d rebirths to Prestige."):format(needed), "info")
		return
	end
	if Registry.CritterService.IsCarrying(player) then
		Registry.Remotes.Notify(player, "Put down what you are carrying first!", "warning")
		return
	end
	data.PeakRebirths = math.max(data.PeakRebirths, data.Rebirths)
	data.Rebirths = 0
	data.Cash = 0
	data.Prestige += 1
	local plot = Registry.Plots.Get(player)
	if plot then
		plot.Vault = 0
		Registry.Plots.RefreshSlots(plot, Registry.Economy.GetSlotCount(player))
	end
	player:SetAttribute("Prestige", data.Prestige)
	Registry.Economy.Sync(player)
	Registry.Economy.ApplySpeed(player)
	Progress.ApplyAura(player)
	local customize = Registry.Customize
	if customize then
		customize.RefreshTag(player)
	end
	Registry.Remotes.NotifyAll(("%s reached PRESTIGE %d!"):format(player.DisplayName, data.Prestige), "rare")
	Registry.Remotes.Effect(player, "Prestige", data.Prestige)
	Registry.Remotes.Popup(
		player,
		"PRESTIGE " .. data.Prestige .. "!",
		("Your cash is now x%g forever, you have a new aura and a star next to your name. You kept your critters, worlds, slots and pets!"):format(
			Progress.PrestigeMultiplier(player)
		)
	)
	markDirty(player)
	task.spawn(Registry.Data.Save, player)
end

---------------------------------------------------------------------
-- Conquistas e Badges
---------------------------------------------------------------------
-- 1 tentativa por sessão para cada Badge (sem ficar repetindo se o Roblox recusar)
local function awardBadge(player: Player, data: any, id: string)
	local badgeId = Progression.BadgeIds[id]
	if type(badgeId) ~= "number" or badgeId <= 0 or data.BadgesSent[id] then
		return
	end
	local tried = badgeTried[player] or {}
	badgeTried[player] = tried
	if tried[id] then
		return
	end
	tried[id] = true
	task.spawn(function()
		local okHas, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if okHas and has then
			data.BadgesSent[id] = true
			return
		end
		local ok, awarded = pcall(function()
			return BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if ok and awarded then
			data.BadgesSent[id] = true
		end
	end)
end

local function summary(player: Player, data: any)
	local best = { Legendary = 0, Mythic = 0, Secret = 0 }
	for id in data.Index do
		local def = Critters.ById[id]
		if def and best[def.Rarity] then
			best[def.Rarity] = 1
		end
	end
	local worlds = Registry.Worlds
	return {
		Joined = 1,
		Hatched = tonumber(data.Hatched) or 0,
		Steals = tonumber(data.Steals) or 0,
		Defends = tonumber(data.Defends) or 0,
		Collected = tonumber(data.Collected) or 0,
		Rebirths = math.max(tonumber(data.Rebirths) or 0, tonumber(data.PeakRebirths) or 0),
		Prestige = tonumber(data.Prestige) or 0,
		Level = (Progression.LevelFromXP(data.Progress.XP)),
		Shinies = tonumber(data.Records.Shinies) or 0,
		GiantEggs = tonumber(data.Records.GiantEggs) or 0,
		Mixes = tonumber(data.Records.Mixes) or 0,
		MissionDays = tonumber(data.Records.MissionDays) or 0,
		MinigameWins = tonumber(data.Records.MinigameWins) or 0,
		IslandVisits = tonumber(data.Records.IslandVisits) or 0,
		Fish = tonumber(data.Records.Fish) or 0,
		Fossils = tonumber(data.Records.Fossils) or 0,
		HuntDays = tonumber(data.Records.HuntDays) or 0,
		Galaxy = if worlds and worlds.IsUnlocked(player, "galaxy") then 1 else 0,
		Legendary = best.Legendary,
		Mythic = best.Mythic,
		Secret = best.Secret,
	}
end

function Progress.CheckAchievements(player: Player, quiet: boolean?)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	local stats = summary(player, data)
	local quietCount = 0
	for _, achievement in Progression.Achievements do
		if not data.Achievements[achievement.Id] and (stats[achievement.Stat] or 0) >= achievement.At then
			data.Achievements[achievement.Id] = os.time()
			if quiet then
				quietCount += if achievement.Id == "Welcome" then 0 else 1
			elseif achievement.Id ~= "Welcome" then
				Registry.Remotes.Notify(player, ("ACHIEVEMENT: %s! (%s)"):format(achievement.Name, achievement.Desc), "rare")
				Registry.Remotes.Effect(player, "Achievement", achievement.Name)
			end
			dirty[player] = true
		end
		if data.Achievements[achievement.Id] then
			awardBadge(player, data, achievement.Id)
		end
	end
	if quietCount > 0 then
		Registry.Remotes.Notify(player, ("You already earned %d achievements! See them in QUESTS > PROFILE."):format(quietCount), "rare")
	end
end

---------------------------------------------------------------------
-- Tela
---------------------------------------------------------------------
function Progress.Sync(player: Player)
	local data = getData(player)
	if not data or not player.Parent then
		return
	end
	ensure(data)
	dirty[player] = nil
	local missions = ensureMissions(player, data)
	local level, into, need = Progression.LevelFromXP(data.Progress.XP)
	local skills = {}
	for _, name in Progression.SkillOrder do
		skills[name] = rank(player, name)
	end
	local list = {}
	for _, mission in missions.List do
		table.insert(list, { Kind = mission.Kind, Need = mission.Need, Have = mission.Have, Done = mission.Done })
	end
	local achievements = {}
	for id in data.Achievements do
		table.insert(achievements, id)
	end
	local records = {}
	for key, value in data.Records do
		records[key] = tonumber(value) or 0
	end
	records.Hatched = tonumber(data.Hatched) or 0
	records.Steals = tonumber(data.Steals) or 0
	records.Defends = tonumber(data.Defends) or 0
	records.Collected = tonumber(data.Collected) or 0
	records.PlayTime = tonumber(data.PlayTime) or 0
	records.TotalEarned = tonumber(data.TotalEarned) or 0
	records.PeakRebirths = math.max(tonumber(data.Rebirths) or 0, tonumber(data.PeakRebirths) or 0)
	local classWait = data.Progress.ClassAt + Progression.ClassCooldown - os.time()
	Registry.Remotes.ProgressEvent:FireClient(player, {
		Level = level,
		XPInto = into,
		XPNeed = need,
		Points = Progression.PointsForLevel(level) - spentPoints(data),
		Skills = skills,
		ResetReady = data.Progress.ResetDay ~= today(),
		Class = data.Progress.Class,
		ClassWait = if data.Progress.Class ~= "" then math.max(0, classWait) else 0,
		Prestige = data.Prestige,
		PrestigeNeed = Progression.PrestigeNeed(data.Prestige),
		Rebirths = data.Rebirths,
		Missions = list,
		Swapped = missions.Swapped == true,
		Bonus = missions.Bonus == true,
		DayEndsIn = (today() + 1) * 86400 - os.time(),
		Records = records,
		Achievements = achievements,
	})
end

function Progress.SetupPlayer(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	ensureMissions(player, data)
	player:SetAttribute("Level", Progress.Level(player))
	player:SetAttribute("Prestige", data.Prestige)
	player:SetAttribute("PeakRebirths", data.PeakRebirths)
	player:SetAttribute("Class", data.Progress.Class)
	Progress.CheckAchievements(player, true) -- quem já jogava ganha tudo de uma vez, sem chuva de avisos
	Progress.Sync(player)
end

function Progress.OnCharacter(player: Player)
	Progress.ApplyAura(player)
end

function Progress.RemovePlayer(player: Player)
	dirty[player] = nil
	needsCheck[player] = nil
	badgeTried[player] = nil
end

function Progress.Init()
	Players.PlayerRemoving:Connect(Progress.RemovePlayer)
	-- conquistas e tela: no máximo 1 vez por segundo por jogador
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				for player in needsCheck do
					needsCheck[player] = nil
					if player.Parent then
						Progress.CheckAchievements(player)
					end
				end
				for player in dirty do
					if player.Parent then
						Progress.Sync(player)
					else
						dirty[player] = nil
					end
				end
			end)
			if not ok then
				warn("[Progress] loop error:", err)
			end
		end
	end)
	-- a cada minuto: missão "jogar X minutos" e recordes
	task.spawn(function()
		while true do
			task.wait(60)
			local ok, err = pcall(function()
				for _, player in Players:GetPlayers() do
					local data = getData(player)
					if data and player:GetAttribute("Loaded") then
						ensure(data)
						local income = Registry.Economy.GetIncome(player)
						data.Records.BestIncome = math.max(tonumber(data.Records.BestIncome) or 0, income)
						data.Records.BestCash = math.max(tonumber(data.Records.BestCash) or 0, tonumber(data.Cash) or 0)
						Progress.Event(player, "Minute")
					end
				end
			end)
			if not ok then
				warn("[Progress] loop error:", err)
			end
		end
	end)
end

return Progress
