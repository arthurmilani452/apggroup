-- Testes de ritmo: o começo do jogo nunca trava e cada nível é alcançável com os prédios liberados
return function(t)
	local Config = t.require("ReplicatedStorage/Shared/Config")
	local Buildings = t.require("ReplicatedStorage/Shared/Buildings")
	local Grid = t.require("ReplicatedStorage/Shared/Grid")
	local CityMath = t.require("ReplicatedStorage/Shared/CityMath")
	local def = Buildings.ById

	-- o tutorial (rua + 4 casas + gerador + padaria) cabe no dinheiro inicial
	local tutorial = def.rua.Cost + 4 * def.casa.Cost + def.gerador.Cost + def.padaria.Cost
	t.check(tutorial <= Config.StartCash, "tutorial custa " .. tutorial .. ", começa com " .. Config.StartCash)

	-- casas sem energia ainda rendem alguma coisa (nunca fica sem saída)
	local s = Grid.new()
	for x = 7, 10 do
		Grid.Place(s, def.casa, x, 2, 0)
	end
	local pop = 0
	for _ = 1, 30 do
		local st = CityMath.Compute(s, { Population = pop })
		pop = CityMath.StepPopulation(pop, st.TargetPopulation)
	end
	t.check(pop > 0, "casas sem luz ainda atraem gente")
	t.check(CityMath.Compute(s, { Population = pop }).IncomePerSec > 0, "renda nunca é zero")

	-- cada nível: dá para chegar na população com a moradia liberada até ali, no terreno da época
	for i = 2, #Config.Tiers do
		local best = 0
		for _, b in Buildings.List do
			if b.Housing and b.Tier < i then
				best = math.max(best, b.Housing / (b.W * b.D))
			end
		end
		local cells = Config.GridSize * (Config.GridSize - 1) -- terreno cheio (a Avenida não conta)
		-- 55% das casas com moradia (o resto: ruas, serviços, energia) e ocupação de 70%
		local reachable = best * cells * 0.55 * 0.7
		t.check(reachable >= Config.Tiers[i].Population, ("nível %s inalcançável (%d)"):format(Config.Tiers[i].Name, reachable))
	end
	-- a reeleição pede um nível que existe
	t.check(CityMath.TierFor(Config.Reelection.Population).Population == Config.Reelection.Population, "reeleição = começo de um nível")
end
