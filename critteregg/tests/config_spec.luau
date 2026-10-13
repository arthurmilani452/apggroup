-- Testes das contas puras do Config (rodam fora do Roblox com o Lune):
--   lune run tests/config_spec.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	Random = roblox.Random,
}, { __index = _G })
local Config = luau.load(fs.readFile("src/shared/Config.luau"), { debugName = "Config", environment = env })()

local failed = 0
local function check(name: string, ok: boolean, detail: any?)
	if ok then
		print("ok   " .. name)
	else
		failed += 1
		print("FAIL " .. name, detail)
	end
end

local function utc(y, m, d, h, mi)
	return os.time({ year = y, month = m, day = d, hour = h, min = mi or 0, sec = 0 })
end
-- os.time com tabela usa o fuso local: força UTC comparando com um ponto conhecido
local base = os.time({ year = 2026, month = 10, day = 17, hour = 17, min = 0, sec = 0 })
local offset = base - 1792256400 -- 17/10/2026 17:00 UTC (sábado 14:00 de Brasília)

local function at(y, m, d, h, mi)
	return utc(y, m, d, h, mi) - offset
end

-- sábado 14:00 de Brasília = 17:00 UTC
local saturday = at(2026, 10, 17, 17, 0)
local s, e = Config.PartyWindow(at(2026, 10, 13, 12, 0)) -- terça antes
check("next party is Saturday 17:00 UTC", s == saturday, s - saturday)
check("party lasts PartyMinutes", e - s == Config.Update.PartyMinutes * 60)
s = Config.PartyWindow(saturday + 60) -- durante
check("during the party returns the current one", s == saturday, s - saturday)
s = Config.PartyWindow(saturday + Config.Update.PartyMinutes * 60) -- acabou agora
check("right after it ends returns next week", s == saturday + 7 * 86400, s - saturday)
s = Config.PartyWindow(saturday - 1)
check("one second before returns this one", s == saturday)

-- hora que passa da meia-noite UTC (22h de Brasília = 01:00 UTC do dia seguinte)
Config.Update.HourBR = 22
local sunday1am = at(2026, 10, 18, 1, 0)
s = Config.PartyWindow(at(2026, 10, 18, 0, 30)) -- domingo 00:30 UTC
check("late hour wraps to next UTC day", s == sunday1am, s - sunday1am)
Config.Update.HourBR = 14

-- portões das zonas: sempre crescendo
local last = -1
local increasing = true
for _, zone in Config.Zones do
	if zone.Speed < last then
		increasing = false
	end
	last = zone.Speed
end
check("zone gates increase", increasing)

-- nenhum número/nome igual ao Steal an Egg
local copied = { Forest = true, Lake = true, Desert = true, Jungle = true, Snow = true, Volcano = true, ["Abyss Ocean"] = true, Prehistoric = true, Cosmic = true, ["Cherry Blossom"] = true, ["Titan Temple"] = true }
local theirGates = { [900] = true, [10_000] = true, [40_000] = true, [170_000] = true, [700_000] = true, [2_500_000] = true, [18_000_000] = true, [700_000_000] = true, [2_500_000_000] = true, [7_000_000_000] = true, [20_000_000_000] = true }
local clean = true
for _, zone in Config.Zones do
	if copied[zone.Name] or theirGates[zone.Speed] then
		clean = false
	end
end
check("zone names and gates are ours", clean)

-- nada pago sorteado
check("no Lucky Egg product", Config.ProductByKey.LuckyEgg == nil)
check("Starter Pack has fixed rewards", Config.ProductByKey.Starter.Cash ~= nil and Config.ProductByKey.Starter.Speed ~= nil)

-- loja de doces aponta para bichinhos e mutações que existem
local critterIds = {}
for id in string.gmatch(fs.readFile("src/shared/Critters.luau"), 'Id = "([%w_]+)"') do
	critterIds[id] = true
end
local shopOk = true
for _, item in Config.Halloween.Shop do
	if not critterIds[item.Critter] or (item.Mut and not Config.MutationByName[item.Mut]) then
		shopOk = false
		print("  bad item", item.Critter, item.Mut)
	end
end
check("candy shop items exist", shopOk)
check("Spooky never rolls outside the event", Config.MutationByName.Spooky.Chance == 0)

---------------------------------------------------------------------
-- v66: economia (números vindos do tools/sim/progression.py)
---------------------------------------------------------------------
-- bichinhos que saem dos ninhos: Id -> Rarity/World (Soon = fora; os exclusivos do WEEKLY não saem de zona nenhuma)
local critterSrc = fs.readFile("src/shared/Critters.luau")
local weeklyAt = string.find(critterSrc, "local WEEKLY", 1, true) or math.huge
local critters = {}
local init = 1
while true do
	local first, last = string.find(critterSrc, "[^\n]+", init)
	if not first then
		break
	end
	local line = string.sub(critterSrc, first, last)
	init = last + 1
	local id = string.match(line, 'Id = "([%w_]+)"')
	local rarity = string.match(line, 'Rarity = "(%w+)"')
	local soon = string.find(line, "Soon = true", 1, true) ~= nil
	local weeklyOnly = first > weeklyAt and string.find(line, "Week = ", 1, true) ~= nil
	if id and rarity and not soon and not weeklyOnly then
		critters[id] = { Rarity = rarity, World = string.match(line, 'World = "(%w+)"') or "meadow" }
	end
end
-- zona "natural" do bichinho (igual ao zoneOfDef do Game.luau)
local function naturalZone(id: string): number?
	local info = critters[id]
	if not info then
		return nil
	end
	for index, zone in Config.Zones do
		if table.find(zone.Pool, info.World) and table.find(zone.Rarities, info.Rarity) then
			return index
		end
	end
	return nil
end

-- Index: a velocidade sobe com a zona e com a raridade
local monotonic = true
for z = 1, #Config.Zones do
	for i, rarity in Config.Rarities do
		local value = Config.IndexSpeedReward(rarity.Name, z)
		if z > 1 and value < Config.IndexSpeedReward(rarity.Name, z - 1) then
			monotonic = false
			print("  smaller than previous zone:", z, rarity.Name)
		end
		if i > 1 and value < Config.IndexSpeedReward(Config.Rarities[i - 1].Name, z) then
			monotonic = false
			print("  smaller than previous rarity:", z, rarity.Name)
		end
	end
end
check("Index speed grows with zone and rarity", monotonic)

-- da zona 2 em diante, nenhum bichinho sozinho chega perto de abrir a próxima zona (no v65 um Lendário abria 1-20 zonas)
local singleOk = true
for z = 2, #Config.Zones do
	for _, rarity in Config.Zones[z].Rarities do
		local value = Config.IndexSpeedReward(rarity, z)
		if value > 0.3 * Config.NextGate(z) then
			singleOk = false
			print("  too big:", z, rarity, value)
		end
	end
end
check("one discovery is at most 30% of the next gate (zone 2+)", singleOk)

-- e descobrir TODOS os bichinhos de uma zona também não abre a próxima sozinho (no v65 bastavam 2-4)
local zoneSum = {}
for id, info in critters do
	local z = naturalZone(id)
	if z then
		zoneSum[z] = (zoneSum[z] or 0) + Config.IndexSpeedReward(info.Rarity, z)
	end
end
local wholeOk = true
for z = 2, #Config.Zones do
	local gap = Config.NextGate(z) - Config.Zones[z].Speed
	if (zoneSum[z] or 0) >= gap then
		wholeOk = false
		print("  whole zone opens the next one:", z, zoneSum[z], gap)
	end
end
check("a whole zone of discoveries never opens the next zone by itself (zone 2+)", wholeOk)

-- mesmos números que o simulador usa (mudou IndexShare/IndexSpeed/portões? atualize aqui e rode o simulador)
check("Index speed values match the sim", Config.IndexSpeedReward("Uncommon", 1) == 130 and Config.IndexSpeedReward("Rare", 3) == 540
	and Config.IndexSpeedReward("Legendary", 8) == 8_700_000 and Config.IndexSpeedReward("Celestial", 12) == 9_000_000_000)
local sampleDef = { Id = "sunwing", Rarity = "Legendary" }
local cash, speed = Config.IndexReward(sampleDef, 5)
check("IndexReward = 100x base income + IndexSpeedReward", cash == math.floor(Config.BaseIncome(sampleDef, 5) * 100) and speed == Config.IndexSpeedReward("Legendary", 5))
check("NextGate after the last zone is 3x its gate", Config.NextGate(#Config.Zones) == Config.Zones[#Config.Zones].Speed * 3 and Config.NextGate(99) == Config.NextGate(1))

local minOk = true
for z = 2, #Config.Zones do
	if Config.Zones[z].MinSpeed > Config.Zones[z].Speed then
		minOk = false
	end
end
check("escape speed (MinSpeed) never above the gate", minOk)

-- esteira: níveis 1-3 baratos como antes, depois sempre mais caro e mais forte
local treadOk = Config.Treadmills[1].Cost == 0 and Config.Treadmills[2].Cost == 2_500 and Config.Treadmills[3].Cost == 13_750
for level = 2, #Config.Treadmills do
	if Config.Treadmills[level].Cost <= Config.Treadmills[level - 1].Cost or Config.Treadmills[level].Gain <= Config.Treadmills[level - 1].Gain then
		treadOk = false
	end
end
check("treadmill prices and gains always go up", treadOk)

-- BICHO DA SEMANA
local monday = at(2026, 10, 12, 0, 0) -- segunda 00:00 UTC
local weekly = Config.WeeklyCritter(monday)
check("weekly critter is the same all week", Config.WeeklyCritter(monday + 3 * 86400) == weekly and Config.WeeklyCritter(monday + 7 * 86400 - 1) == weekly)
check("weekly critter changes on Monday 00:00 UTC", Config.WeeklyCritter(monday - 1) ~= weekly and Config.WeeklyCritter(monday + 7 * 86400) ~= weekly
	and Config.WeeklyEnds(monday) == monday + 7 * 86400)
local seenWeekly, weeklyZones, rotationOk = {}, {}, true
for week = 0, #Config.WeeklyCritters - 1 do
	local id = Config.WeeklyCritter(monday + week * 7 * 86400)
	local z = naturalZone(id)
	if seenWeekly[id] or not z then
		rotationOk = false
		print("  weekly critter repeated or not in any zone:", id)
	end
	seenWeekly[id] = true
	if z then
		weeklyZones[z] = true
	end
end
local zoneCount = 0
for _ in weeklyZones do
	zoneCount += 1
end
check("weekly rotation: each critter once and all hatch from a zone", rotationOk)
check("weekly rotation covers at least 8 zones", zoneCount >= 8, zoneCount)
local weeklyDef = { Id = weekly, Rarity = critters[weekly] and critters[weekly].Rarity }
local otherDef = { Id = Config.WeeklyCritter(monday + 7 * 86400) }
check("WeeklyBoostFor boosts only this week's critter", Config.WeeklyRarityMult > 1 and Config.WeeklyBoostFor(weeklyDef, monday) == Config.WeeklyRarityMult
	and Config.WeeklyBoostFor(otherDef, monday) == 1 and Config.WeeklyBoostFor(nil, monday) == 1)
check("WeeklyBoostFor is deterministic", Config.WeeklyBoostFor(weeklyDef, monday) == Config.WeeklyBoostFor(weeklyDef, monday + 86400))

---------------------------------------------------------------------
-- v67: PRÊMIO DIÁRIO 2.0 (dia de Brasília, escudo, calendário de 28 dias)
---------------------------------------------------------------------
-- o dia vira à meia-noite de Brasília (03:00 UTC), não às 21h de Brasília (00:00 UTC)
local brMidnight = at(2026, 10, 14, 3, 0) -- quarta 00:00 de Brasília
check("day changes at 00:00 Brasilia", Config.Day(brMidnight) == Config.Day(brMidnight - 1) + 1)
check("21:00 Brasilia (00:00 UTC) is still the same day", Config.Day(at(2026, 10, 14, 0, 0)) == Config.Day(brMidnight - 1)
	and Config.Day(at(2026, 10, 14, 0, 0)) == Config.Day(at(2026, 10, 13, 12, 0)))
check("NextDayAt = next Brasilia midnight", Config.NextDayAt(brMidnight - 1) == brMidnight and Config.NextDayAt(brMidnight) == brMidnight + 86400
	and Config.NextDayAt(at(2026, 10, 14, 1, 30)) == brMidnight)

-- sequência e escudo: gap = hoje - último dia pego
local week = #Config.Daily
local function step(gap, streak, savers)
	return table.pack(Config.DailyNext(gap, streak, savers))
end
local r = step(1, 3, 0)
check("next day continues the streak", r[1] == 4 and r[2] == 0 and r[3] == false)
r = step(2, 3, 1)
check("missing ONE day with a saver keeps the streak", r[1] == 4 and r[2] == 0 and r[3] == true)
r = step(2, 3, 0)
check("missing one day without a saver restarts", r[1] == 1 and r[2] == 0 and r[3] == false)
r = step(3, 5, 2)
check("missing two days restarts even with savers (and keeps them)", r[1] == 1 and r[2] == 2 and r[3] == false)
r = step(1, week - 1, 0)
check("day 7 earns a saver", r[1] == week and r[2] == 1)
r = step(1, week - 1, Config.MaxSavers)
check("savers never go above MaxSavers", r[1] == week and r[2] == Config.MaxSavers)
r = step(1, week, 1)
check("after day 7 the week loops to day 1", r[1] == 1 and r[2] == 1)
r = step(2, week - 1, 1)
check("saver used on the way to day 7 comes back", r[1] == week and r[2] == 1 and r[3] == true)
r = step(19000, 0, 0)
check("first claim ever is day 1", r[1] == 1 and r[2] == 0 and r[3] == false)

-- calendário: dia 1..28 pelo total, nunca sorteado, bichinhos que existem e são exclusivos
check("CalendarDay cycles 1..28", Config.CalendarDay(0) == 0 and Config.CalendarDay(1) == 1 and Config.CalendarDay(28) == 28
	and Config.CalendarDay(29) == 1 and Config.CalendarDay(56) == 28)
check("calendar critters are Gold from the 2nd lap on", Config.CalendarMutation(7) == nil and Config.CalendarMutation(28) == nil
	and Config.CalendarMutation(29) == "Gold" and Config.CalendarMutation(35) == "Gold" and Config.MutationByName.Gold ~= nil)
local calendarOk, calendarCritters = true, 0
for day, info in Config.Calendar do
	if type(day) ~= "number" or day < 1 or day > Config.CalendarDays then
		calendarOk = false
		print("  bad calendar day", day)
	end
	for id in info.Boost or {} do
		local known = false
		for _, boost in Config.Boosts do
			known = known or boost.Id == id
		end
		if not known then
			calendarOk = false
			print("  unknown boost", id)
		end
	end
	if info.Critter then
		calendarCritters += 1
		local line = string.match(critterSrc, '[^\n]*Id = "' .. info.Critter .. '"[^\n]*')
		if not line or not string.find(line, 'World = "calendar"', 1, true) or not string.find(line, "Keep = true", 1, true) then
			calendarOk = false
			print("  calendar critter missing or not exclusive", info.Critter)
		elseif naturalZone(info.Critter) then
			calendarOk = false
			print("  calendar critter drops from a zone", info.Critter)
		end
	end
end
check("calendar milestones point to real boosts and exclusive critters", calendarOk and calendarCritters == 3)
check("day 28 gives the mark and a Mythic", Config.Calendar[28] ~= nil and Config.Calendar[28].Mark == true and critters[Config.Calendar[28].Critter].Rarity == "Mythic")

-- v67: POR UM TRIZ, sequência de roubos e quando é MOMENTO ÉPICO
check("close call pays at least MinCash", Config.CloseCallBonus(nil) == Config.CloseCall.MinCash and Config.CloseCallBonus(0) == Config.CloseCall.MinCash)
check("close call pays Minutes of base income", Config.CloseCallBonus(1000) == math.max(Config.CloseCall.MinCash, 1000 * 60 * Config.CloseCall.Minutes))
check("close call needs you past the guardian's Z clamp (6)", Config.CloseCall.MinZ > 6 and Config.CloseCall.Window > 0 and Config.CloseCall.Margin > 0)
check("close call is smaller than a streak prize", Config.CloseCall.Minutes < Config.StealStreak.Minutes and Config.CloseCall.MinCash < Config.StealStreak.MinCash)
local every = Config.StealStreak.Every
check("streak prize on each multiple of Every", Config.StreakBonusDue(every - 1, every) and Config.StreakBonusDue(2 * every - 1, 2 * every)
	and not Config.StreakBonusDue(0, 1) and not Config.StreakBonusDue(every, every + 1))
check("streak +2 (close call) never skips the prize", Config.StreakBonusDue(every - 1, every + 1) and Config.StreakBonusDue(every - 2, every)
	and not Config.StreakBonusDue(every + 1, every + 3) and not Config.StreakBonusDue(3, 3))
check("epic: Mythic+, GIANT, Rainbow or golden/pumpkin", Config.EpicEgg("Mythic") and Config.EpicEgg("Celestial") and Config.EpicEgg("Common", 4)
	and Config.EpicEgg("Common", 1, "Rainbow") and Config.EpicEgg("Rare", 1, "Gold", true))
check("epic: not for Legendary, HUGE or Gold", not Config.EpicEgg("Legendary") and not Config.EpicEgg("Epic", 2.5) and not Config.EpicEgg("Rare", 1, "Gold")
	and not Config.EpicEgg("Common", nil, nil, false))
check("epic cooldown and hatch time are sane", Config.EpicCooldown >= 10 and Config.HatchTime > 0.5 and Config.HatchTime < 2)

if failed > 0 then
	error(("%d test(s) failed"):format(failed))
end
print("all good")
