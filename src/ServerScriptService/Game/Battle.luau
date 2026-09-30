--[[
	Battle (ModuleScript em ServerScriptService > Game)
	Parte 23 (v12): CRITTER BATTLE, a batalha por turnos da ilha dos minigames.
	  • Cada jogador luta com o SEU melhor bichinho (da base ou da mochila). Duelos 1 contra 1;
	    se sobrar alguém, luta contra um Grumblob.
	  • A cada turno (8 s) os dois escolhem ao mesmo tempo: ATTACK, DEFEND (leva só 35% do dano e cura um pouco)
	    ou SPECIAL (1,8x de dano; depois precisa esperar 3 turnos). Quem não escolher, ataca.
	  • A raridade ajuda só um pouco (no máximo ~30%): escolher bem o DEFEND/SPECIAL vence bichinho mais forte.
	O servidor sorteia e calcula tudo; a tela só manda a escolha ("BattleMove").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Registry = require(script.Parent.Registry)

local Battle = {}

local TURN_SECONDS = 8
local MAX_TURNS = 10
local SPECIAL_COOLDOWN = 3
local MUTATION_BONUS = { Gold = 0.05, Diamond = 0.10, Rainbow = 0.15 }

type Fighter = {
	Player: Player?,
	Name: string,
	Critter: string,
	Mutation: string?,
	HP: number,
	Max: number,
	Atk: number,
	SpecialAt: number,
	Choice: string?,
}
type Duel = { A: Fighter, B: Fighter, Turn: number, Deadline: number, Log: string, Done: boolean, Winner: Fighter? }

local duels: { Duel } = {}
local fighterOf: { [Player]: Fighter } = {}
local duelOf: { [Player]: Duel } = {}
local running = false
local random = Random.new()

-- O melhor bichinho do jogador (base + mochila)
local function bestCritter(player: Player): (string, string?)
	local bestId, bestMutation, bestScore = "blobby", nil, -1
	local function consider(id: any, mutation: any)
		local def = type(id) == "string" and Critters.ById[id]
		if not def then
			return
		end
		local score = (Config.RarityIndex[def.Rarity] or 1) * 10 + (if mutation and MUTATION_BONUS[mutation] then MUTATION_BONUS[mutation] * 20 else 0)
		if score > bestScore then
			bestId, bestMutation, bestScore = def.Id, if type(mutation) == "string" then mutation else nil, score
		end
	end
	for _, item in Registry.CritterService.GetBaseList(player) do
		consider(item.Id, item.M)
	end
	local profile = Registry.Data.Get(player)
	if profile and type(profile.Data.Inventory) == "table" then
		for _, item in profile.Data.Inventory do
			consider(item.Id, item.M)
		end
	end
	return bestId, bestMutation
end

local function makeFighter(player: Player?): Fighter
	if not player then
		return { Player = nil, Name = "Grumblob", Critter = "", Mutation = nil, HP = 120, Max = 120, Atk = 20, SpecialAt = 1, Choice = nil }
	end
	local id, mutation = bestCritter(player)
	local def = Critters.ById[id]
	local tier = Config.RarityIndex[def.Rarity] or 1
	local bonus = 1 + (if mutation then MUTATION_BONUS[mutation] or 0 else 0)
	local hp = math.floor((100 + tier * 8) * bonus)
	return {
		Player = player,
		Name = player.DisplayName,
		Critter = id,
		Mutation = mutation,
		HP = hp,
		Max = hp,
		Atk = math.floor((16 + tier * 1.5) * bonus),
		SpecialAt = 1,
		Choice = nil,
	}
end

local function view(fighter: Fighter, turn: number)
	return {
		Name = fighter.Name,
		Critter = fighter.Critter,
		M = fighter.Mutation,
		HP = math.max(0, math.floor(fighter.HP)),
		Max = fighter.Max,
		SpecialIn = math.max(0, fighter.SpecialAt - turn),
	}
end

local function send(duel: Duel)
	for _, pair in { { duel.A, duel.B }, { duel.B, duel.A } } do
		local me, foe = pair[1], pair[2]
		local player = me.Player
		if player and player.Parent then
			Registry.Remotes.BattleEvent:FireClient(player, {
				Me = view(me, duel.Turn),
				Foe = view(foe, duel.Turn),
				Turn = duel.Turn,
				Deadline = duel.Deadline,
				Log = duel.Log,
				Done = duel.Done,
				Won = duel.Done and duel.Winner == me,
				Chosen = me.Choice,
			})
		end
	end
end

local function botChoice(bot: Fighter, turn: number): string
	if bot.SpecialAt <= turn and random:NextNumber() < 0.45 then
		return "Special"
	end
	return if random:NextNumber() < 0.25 then "Defend" else "Attack"
end

local function damageOf(attacker: Fighter, turn: number): number
	local choice = attacker.Choice
	if choice == "Special" and attacker.SpecialAt <= turn then
		attacker.SpecialAt = turn + SPECIAL_COOLDOWN
		return attacker.Atk * 1.8 * random:NextNumber(0.9, 1.1)
	elseif choice == "Defend" then
		return 0
	end
	attacker.Choice = "Attack" -- special ainda carregando: vira ataque normal
	return attacker.Atk * random:NextNumber(0.85, 1.15)
end

local ACTION_TEXT = { Attack = "ATTACK", Defend = "DEFEND", Special = "SPECIAL" }

local function resolve(duel: Duel)
	local a, b = duel.A, duel.B
	a.Choice = a.Choice or (if a.Player then "Attack" else botChoice(a, duel.Turn))
	b.Choice = b.Choice or (if b.Player then "Attack" else botChoice(b, duel.Turn))
	local toB = damageOf(a, duel.Turn)
	local toA = damageOf(b, duel.Turn)
	if b.Choice == "Defend" then
		toB *= 0.35
		b.HP = math.min(b.Max, b.HP + 6)
	end
	if a.Choice == "Defend" then
		toA *= 0.35
		a.HP = math.min(a.Max, a.HP + 6)
	end
	a.HP -= toA
	b.HP -= toB
	duel.Log = ("%s: %s (-%d)  |  %s: %s (-%d)"):format(
		a.Name,
		ACTION_TEXT[a.Choice or "Attack"] or "ATTACK",
		math.floor(toB + 0.5),
		b.Name,
		ACTION_TEXT[b.Choice or "Attack"] or "ATTACK",
		math.floor(toA + 0.5)
	)
	a.Choice, b.Choice = nil, nil
	if a.HP <= 0 or b.HP <= 0 or duel.Turn >= MAX_TURNS then
		duel.Done = true
		-- quem ficou com mais vida (em %) vence; empate: sorteio
		local ra, rb = a.HP / a.Max, b.HP / b.Max
		duel.Winner = if ra > rb then a elseif rb > ra then b elseif random:NextNumber() < 0.5 then a else b
	end
end

local function runDuel(duel: Duel)
	while running and not duel.Done do
		duel.Turn += 1
		duel.Deadline = workspace:GetServerTimeNow() + TURN_SECONDS
		send(duel)
		-- espera os dois escolherem (ou o tempo acabar)
		local started = os.clock()
		while running and not duel.Done and os.clock() - started < TURN_SECONDS do
			local aReady = duel.A.Choice ~= nil or duel.A.Player == nil
			local bReady = duel.B.Choice ~= nil or duel.B.Player == nil
			if aReady and bReady and os.clock() - started > 0.6 then
				break
			end
			task.wait(0.2)
		end
		if not running or duel.Done then
			return -- alguém saiu (Battle.Remove) ou a rodada acabou
		end
		resolve(duel)
		send(duel)
		task.wait(1.6)
	end
end

-- Começa: devolve quando todas as lutas acabarem (ou o tempo do minigame acabar)
function Battle.Run(participants: { Player }, timeLimit: number): ({ Player }, { Player })
	running = true
	table.clear(duels)
	table.clear(fighterOf)
	table.clear(duelOf)
	local list = table.clone(participants)
	for i = #list, 2, -1 do
		local j = random:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	local index = 1
	while index <= #list do
		local playerA = list[index]
		local playerB = list[index + 1]
		local a = makeFighter(playerA)
		local b = makeFighter(playerB) -- nil = Grumblob
		local duel: Duel = { A = a, B = b, Turn = 0, Deadline = 0, Log = "FIGHT!", Done = false, Winner = nil }
		table.insert(duels, duel)
		fighterOf[playerA] = a
		duelOf[playerA] = duel
		if playerB then
			fighterOf[playerB] = b
			duelOf[playerB] = duel
		end
		index += 2
	end
	for _, duel in duels do
		task.spawn(runDuel, duel)
	end
	local started = os.clock()
	while os.clock() - started < timeLimit do
		local allDone = true
		for _, duel in duels do
			if not duel.Done then
				allDone = false
			end
		end
		if allDone then
			break
		end
		task.wait(0.5)
	end
	running = false
	local winners, losers = {}, {}
	for _, duel in duels do
		if not duel.Done then
			-- acabou o tempo: quem tem mais vida (%) vence
			local ra, rb = duel.A.HP / duel.A.Max, duel.B.HP / duel.B.Max
			duel.Winner = if ra >= rb then duel.A else duel.B
			duel.Done = true
		end
		for _, fighter in { duel.A, duel.B } do
			local player = fighter.Player
			if player and player.Parent then
				-- ganhar do Grumblob não conta como vitória (senão dava para treinar sozinho e farmar)
				local vsBot = duel.A.Player == nil or duel.B.Player == nil
				table.insert(if duel.Winner == fighter and not vsBot then winners else losers, player)
			end
		end
		send(duel)
	end
	table.clear(fighterOf)
	table.clear(duelOf)
	return winners, losers
end

-- Escolha do jogador (só vale uma por turno)
function Battle.Move(player: Player, choice: any)
	local fighter = fighterOf[player]
	local duel = duelOf[player]
	if not fighter or not duel or duel.Done or fighter.Choice ~= nil then
		return
	end
	if choice ~= "Attack" and choice ~= "Defend" and choice ~= "Special" then
		return
	end
	if choice == "Special" and fighter.SpecialAt > duel.Turn then
		return
	end
	fighter.Choice = choice
	send(duel)
end

-- Saiu do jogo/minigame no meio: perde a luta
function Battle.Remove(player: Player)
	local fighter = fighterOf[player]
	local duel = duelOf[player]
	if fighter and duel and not duel.Done then
		fighter.HP = 0
		duel.Done = true
		duel.Winner = if duel.A == fighter then duel.B else duel.A
		send(duel)
	end
	fighterOf[player] = nil
	duelOf[player] = nil
end

function Battle.Stop()
	running = false
end

function Battle.Init()
	Players.PlayerRemoving:Connect(Battle.Remove)
end

return Battle
