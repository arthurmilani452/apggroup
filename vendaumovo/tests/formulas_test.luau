--[[
	Testes das contas do jogo (Formulas) fora do Studio:
	    luau vendaumovo/tests/formulas_test.luau
	(baixe o luau em github.com/luau-lang/luau/releases)
]]

local Config = require("../src/ReplicatedStorage/Shared/Config")
local Formulas = require("../src/ReplicatedStorage/Shared/Formulas")
local Format = require("../src/ReplicatedStorage/Shared/Format")

local failures, total = 0, 0
local function check(cond: boolean, msg: string)
	total += 1
	if not cond then
		failures += 1
		print("FALHOU: " .. msg)
	end
end

local function freshData()
	local upgrades = {}
	for _, u in Config.Upgrades do
		upgrades[u.Id] = 0
	end
	return {
		Coins = 0,
		Rebirths = 0,
		Hens = { "comum" },
		Basket = {},
		Upgrades = upgrades,
		Passes = {},
		Boosts = {},
		Daily = { Day = 0, List = {} },
	}
end

local NOW = 1_800_000_000

-- Venda básica
do
	local d = freshData()
	d.Basket = { branco = 10, ["dourado*"] = 1 }
	local value, count = Formulas.BasketValue(Config, d, nil, NOW)
	check(count == 11, "conta 11 ovos")
	check(value == 10 * 1 + 250 * Config.RareMult, "valor: 10 brancos + 1 dourado raro, deu " .. value)
end

-- Multiplicadores: rebirth, decoração, game pass x2 e boost
do
	local d = freshData()
	d.Rebirths = 2
	check(Formulas.Multiplier(Config, d, nil, NOW) == 2, "2 rebirths = x2")
	d.Upgrades.Decoracao = 1
	check(math.abs(Formulas.Multiplier(Config, d, nil, NOW) - 2 * 1.03) < 1e-9, "decoração nível 1 = +3%")
	check(math.abs(Formulas.Multiplier(Config, d, { Dinheiro2x = true }, NOW) - 4 * 1.03) < 1e-9, "pass x2 dobra")
	d.Boosts.Turbo = NOW + 10
	check(math.abs(Formulas.Multiplier(Config, d, nil, NOW) - 2 * 1.03 * Config.TurboBoostMult) < 1e-9, "boost turbo ativo")
	check(math.abs(Formulas.Multiplier(Config, d, nil, NOW + 11) - 2 * 1.03) < 1e-9, "boost turbo acabou")
end

-- Cesta, melhorias e custos
do
	local d = freshData()
	check(Formulas.BasketCapacity(Config, d, nil) == 10, "cesta inicial 10")
	check(Formulas.BasketCapacity(Config, d, { CestaVIP = true }) == 20, "cesta VIP dobra")
	d.Upgrades.Cesta = #Config.UpgradeById.Cesta.Costs
	check(Formulas.UpgradeCost(Config, d, "Cesta") == nil, "cesta no máximo não tem custo")
	d.Upgrades.Cesta = 999 -- valor estragado no save não pode quebrar
	check(Formulas.UpgradeValue(Config, d, "Cesta") == Config.UpgradeById.Cesta.Values[#Config.UpgradeById.Cesta.Values], "nível fora do limite usa o máximo")
	check(Formulas.LayTime(Config, freshData(), "comum") == Config.HenById.comum.LayTime, "postura base")
end

-- Rebirth fica mais caro
do
	local d = freshData()
	local c0 = Formulas.RebirthCost(Config, d)
	d.Rebirths = 1
	check(Formulas.RebirthCost(Config, d) == c0 * Config.RebirthCostGrowth, "rebirth 2 custa mais")
end

-- Missões: mesmas no mesmo dia, sem repetir tipo, prêmio cresce com a melhor ave
do
	local d = freshData()
	local a = Formulas.MakeMissions(Config, d, 20000)
	local b = Formulas.MakeMissions(Config, d, 20000)
	check(#a == Config.DailyMissionCount, "3 missões")
	local seen = {}
	for i, m in a do
		check(m.Id == b[i].Id, "mesmo dia = mesmas missões")
		check(not seen[m.Id], "missão repetida: " .. m.Id)
		seen[m.Id] = true
		check(m.Target > 0 and m.Reward >= Config.MissionRewardMin, "alvo e prêmio válidos")
	end
	local rich = freshData()
	rich.Hens = { "comum", "dourada" }
	check(Formulas.MakeMissions(Config, rich, 20000)[1].Reward > a[1].Reward, "prêmio cresce com a melhor ave")
	local differentDay = false
	for day = 20001, 20010 do
		if Formulas.MakeMissions(Config, d, day)[1].Id ~= a[1].Id then
			differentDay = true
		end
	end
	check(differentDay, "dias diferentes trocam as missões")
end

-- Produtos e presente crescem com o jogador
do
	local d = freshData()
	local product = Config.Products[1]
	check(Formulas.ProductCoins(Config, product, d) == product.Min, "pacote pequeno no começo = mínimo")
	d.Hens = { "lunar" }
	check(Formulas.ProductCoins(Config, product, d) > product.Min, "pacote cresce com a melhor ave")
	check(Formulas.GiftReward(Config, freshData(), nil, NOW) >= Config.GiftMin, "presente mínimo")
end

-- Chaves de ovo raro
do
	local id, rare = Formulas.ParseKey(Formulas.EggKey("lunar", true))
	check(id == "lunar" and rare, "chave rara ida e volta")
	local id2, rare2 = Formulas.ParseKey("branco")
	check(id2 == "branco" and not rare2, "chave normal")
end

-- Ganho offline: nada se ficou pouco tempo, para em 2 h, cresce com mais aves
do
	local d = freshData()
	local e0, c0 = Formulas.OfflineEarnings(Config, d, nil, Config.Offline.MinSeconds - 1, NOW)
	check(e0 == 0 and c0 == 0, "offline: pouco tempo não dá nada")
	local e1, c1 = Formulas.OfflineEarnings(Config, d, nil, 3600, NOW)
	check(e1 == math.floor(3600 / Config.HenById.comum.LayTime * Config.Offline.Rate), "offline: 1 h de uma galinha comum")
	check(c1 == e1 * Config.EggById.branco.Value, "offline: valor dos ovos brancos")
	local eMax = Formulas.OfflineEarnings(Config, d, nil, Config.Offline.MaxSeconds, NOW)
	local eHuge = Formulas.OfflineEarnings(Config, d, nil, 10 ^ 9, NOW)
	check(eHuge == eMax, "offline: para no máximo (mudar o relógio não adianta)")
	d.Hens = { "comum", "comum", "comum", "comum", "comum", "comum" } -- mais aves que ninhos
	local eCap = Formulas.OfflineEarnings(Config, d, nil, 3600, NOW)
	check(eCap == e1 * Formulas.UpgradeValue(Config, d, "Ninhos"), "offline: só conta aves que cabem nos ninhos")
end

-- Sequência diária
do
	check(Formulas.StreakNext({ Day = 0, Last = 0 }, 100) == 1, "sequência: primeiro dia")
	check(Formulas.StreakNext({ Day = 3, Last = 99 }, 100) == 4, "sequência: dia seguido soma")
	check(Formulas.StreakNext({ Day = 7, Last = 99 }, 100) == 1, "sequência: depois do 7 recomeça")
	check(Formulas.StreakNext({ Day = 5, Last = 97 }, 100) == 1, "sequência: pulou dia, volta pro 1")
	check(Formulas.StreakNext({ Day = 2, Last = 100 }, 100) == nil, "sequência: já pegou hoje")
	local d = freshData()
	check(Formulas.StreakReward(Config, d, 7) > Formulas.StreakReward(Config, d, 1), "sequência: dia 7 vale mais")
end

-- Códigos
do
	check(Formulas.NormalizeCode("  ovo-100 ") == "OVO100", "código: limpa e põe em maiúsculas")
	check(Formulas.FindCode(Config, "ovo100") ~= nil, "código: acha OVO100")
	check(Formulas.FindCode(Config, "NAOEXISTE") == nil, "código: inexistente")
	local entry = Formulas.FindCode(Config, "OVO100")
	check(Formulas.CodeReward(Config, freshData(), entry) == entry.Min, "código: prêmio mínimo no começo")
end

-- Clientes: decoração atrai mais, cesta vazia atrai menos
do
	local d = freshData()
	local base = Formulas.CustomerRate(Config, d, 5)
	d.Upgrades.Decoracao = 3
	check(Formulas.CustomerRate(Config, d, 5) > base, "clientes: decoração atrai mais")
	check(Formulas.CustomerRate(Config, d, 0) < Formulas.CustomerRate(Config, d, 5), "clientes: cesta vazia atrai menos")
end

-- Formatação
check(Format.Short(950) == "950", "950")
check(Format.Short(1250) == "1.2K", "1.2K deu " .. Format.Short(1250))
check(Format.Short(3000000) == "3M", "3M deu " .. Format.Short(3000000))
check(Format.Time(65) == "1:05", "1:05")

-- Progressão: cada ave paga a próxima num tempo razoável (sem rebirth nem boost).
-- Ninhos que o jogador costuma ter em cada fase: 4 no começo, 12 no fim.
local NESTS_BY_TIER = { 4, 4, 6, 8, 10, 12, 12, 12, 12 }
for i = 1, #Config.Hens - 1 do
	local hen, nextHen = Config.Hens[i], Config.Hens[i + 1]
	local perMinute = Config.EggById[hen.Egg].Value * 60 / hen.LayTime * NESTS_BY_TIER[i]
	local minutes = nextHen.Price / perMinute
	check(minutes < 60, ("%s -> %s demora %.0f min"):format(hen.Name, nextHen.Name, minutes))
end

print(("%d testes, %d falhas"):format(total, failures))
if failures > 0 then
	error("testes falharam")
end
