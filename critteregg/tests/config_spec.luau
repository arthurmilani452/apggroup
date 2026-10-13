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

if failed > 0 then
	error(("%d test(s) failed"):format(failed))
end
print("all good")
