-- Testes da conta da cidade
return function(t)
	local Config = t.require("ReplicatedStorage/Shared/Config")
	local Buildings = t.require("ReplicatedStorage/Shared/Buildings")
	local Grid = t.require("ReplicatedStorage/Shared/Grid")
	local CityMath = t.require("ReplicatedStorage/Shared/CityMath")
	local def = Buildings.ById

	t.eq(CityMath.TierFor(0).Id, 1, "vila")
	t.eq(CityMath.TierFor(150).Id, 2, "cidade")
	t.eq(CityMath.TierFor(1e9).Id, #Config.Tiers, "último nível")

	-- cidade vazia
	local empty = CityMath.Compute(Grid.new(), { Population = 0 })
	t.eq(empty.Housing, 0, "sem casas")
	t.eq(empty.IncomePerSec, 0, "sem renda")
	t.eq(empty.PowerRatio, 1, "sem consumo = energia ok")

	-- casa encostada na avenida funciona; sem gerador falta energia
	local s = Grid.new()
	for x = 7, 10 do
		Grid.Place(s, def.casa, x, 2, 0)
	end
	local st = CityMath.Compute(s, { Population = 0 })
	t.eq(st.Housing, 24, "4 casas = 24 vagas")
	t.eq(st.PowerRatio, 0, "sem gerador")
	t.eq(st.NoRoadCount, 0, "todas na avenida")
	local noPower = st.Happiness

	Grid.Place(s, def.gerador, 11, 2, 0)
	st = CityMath.Compute(s, { Population = 0 })
	t.eq(st.PowerRatio, 1, "gerador cobre 4 casas")
	t.check(st.Happiness > noPower, "energia deixa mais feliz")

	-- casa sem rua não conta
	local lonely = Grid.Place(s, def.casa, 7, 5, 0)
	st = CityMath.Compute(s, { Population = 0 })
	t.eq(st.Housing, 24, "casa sem rua não mora ninguém")
	t.check(st.NoRoad[lonely], "marcada sem rua")

	-- padaria atende comércio e gera renda com empregados
	Grid.Place(s, def.padaria, 12, 2, 0)
	st = CityMath.Compute(s, { Population = 20 })
	t.eq(st.Coverage.comercio, 0.75, "padaria alcança 3 das 4 casas (alcance 4)")
	t.check(st.IncomePerSec > 20 * Config.TaxPerResident, "padaria rende")
	local base = st.IncomePerSec
	local doubled = CityMath.Compute(s, { Population = 20, DoubleIncome = true, Reelections = 1 }).IncomePerSec
	t.check(math.abs(doubled - base * 2 * (1 + Config.Reelection.BonusPerTerm)) < 1e-6, "multiplicadores")

	-- poluição perto das casas derruba a felicidade
	local clean = st.Happiness
	Grid.Place(s, def.gerador, 13, 2, 0)
	Grid.Place(s, def.gerador, 14, 2, 0)
	st = CityMath.Compute(s, { Population = 20 })
	t.check(st.Happiness < clean, "poluição tira felicidade")

	-- evento de calor
	local hot = CityMath.Compute(s, { Population = 20, Event = { Happiness = -12 } })
	t.check(hot.Happiness < st.Happiness, "onda de calor")

	-- população anda até a meta e quem está infeliz vai embora
	local p, left = CityMath.StepPopulation(0, 100)
	t.check(p > 0 and p <= 100 and left == 0, "cresce")
	p, left = CityMath.StepPopulation(100, 50)
	t.check(p < 100 and p >= 50 and left == 100 - p, "encolhe")
	p, left = CityMath.StepPopulation(10, 10)
	t.eq(p, 10, "parado"); t.eq(left, 0, "ninguém sai")
	local steps = 0
	p = 0
	while p < 500 and steps < 200 do
		p = CityMath.StepPopulation(p, 500)
		steps += 1
	end
	t.eq(p, 500, "chega na meta")

	-- cofre
	t.check(CityMath.VaultCapacity(1, 0) >= Config.Vault.MinCapacity, "cofre mínimo")
	t.check(CityMath.VaultCapacity(2, 100) > CityMath.VaultCapacity(1, 100), "nível maior cabe mais")
end
