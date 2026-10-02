--[[
	CityMath (ModuleScript em ReplicatedStorage > Shared)          Prefeito Tycoon
	A conta da cidade: energia, felicidade, empregos, renda e quanta gente quer morar nela.
	PURO (sem API do Roblox): dá para testar no Lune. O servidor roda isso a cada passo da simulação
	e manda o resultado para o painel do jogador.

	API:
	  CityMath.TierFor(population) -> tier (tabela de Config.Tiers)
	  CityMath.Compute(state, ctx) -> Stats
	      ctx = { Population, Reelections?, DoubleIncome?, Visitors?, Event? (tabela de Config.Events) }
	  CityMath.StepPopulation(population, target, growth?) -> novaPopulação, quantosSaíram
	  CityMath.VaultCapacity(level, incomePerSec) -> $
]]

local Shared = script.Parent
local Config = require(Shared.Config)
local Buildings = require(Shared.Buildings)
local Grid = require(Shared.Grid)

local CityMath = {}

export type Stats = {
	Housing: number,
	Jobs: number,
	Workers: number,
	Staffing: number,
	PowerSupply: number,
	PowerDemand: number,
	PowerRatio: number,
	Happiness: number,
	TargetPopulation: number,
	IncomePerSec: number,
	Multiplier: number,
	Coverage: { [string]: number }, -- necessidade -> parte das moradias atendidas (0..1)
	NoRoad: { [number]: boolean }, -- uids dos prédios sem rua ligada
	NoRoadCount: number,
	Tier: number,
}

function CityMath.TierFor(population: number): any
	local best = Config.Tiers[1]
	for _, tier in Config.Tiers do
		if population >= tier.Population then
			best = tier
		end
	end
	return best
end

local function within(ax: number, az: number, bx: number, bz: number, radius: number): boolean
	return math.max(math.abs(ax - bx), math.abs(az - bz)) <= radius
end

function CityMath.Compute(state: Grid.State, ctx: any): Stats
	local population = math.max(0, tonumber(ctx.Population) or 0)
	local event = ctx.Event or {}
	local tier = CityMath.TierFor(population).Id
	local connected = Grid.Connected(state)

	local providers = {} -- { {cx, cz, need, radius} }
	local leisure = {} -- { {cx, cz, amount, radius} }
	local polluters = {}
	local homes = {} -- { {cx, cz, housing} }
	local noRoad: { [number]: boolean } = {}
	local noRoadCount = 0
	local supply, demand, jobs = 0, 0, 0
	local commerceIncome, industryIncome = 0, 0

	for uid, placed in state.Buildings do
		local def = Buildings.ById[placed.Id]
		if def and def.Category ~= "road" then
			local active = def.NoRoad == true or Grid.HasAccess(state, connected, placed)
			if not active then
				noRoad[uid] = true
				noRoadCount += 1
			else
				local cx, cz = Grid.Center(placed)
				supply += def.PowerSupply or 0
				demand += def.Power or 0
				jobs += def.Jobs or 0
				if def.Need then
					table.insert(providers, { cx, cz, def.Need, def.Radius or 0 })
				end
				if def.Leisure then
					table.insert(leisure, { cx, cz, def.Leisure, def.LeisureRadius or 0 })
				end
				if def.Pollution then
					table.insert(polluters, { cx, cz, def.Pollution, def.PollutionRadius or 0 })
				end
				if def.Housing then
					table.insert(homes, { cx, cz, def.Housing })
				end
				if def.Category == "commercial" then
					commerceIncome += def.Income or 0
				elseif def.Category == "industrial" then
					industryIncome += def.Income or 0
				end
			end
		end
	end

	supply *= event.Power or 1
	local powerRatio = if demand <= 0 then 1 else math.min(1, supply / demand)

	-- felicidade de cada moradia, pesada pelo número de vagas
	local H = Config.Happiness
	local activeNeeds = {}
	for _, need in Config.Needs do
		if tier >= need.Tier then
			table.insert(activeNeeds, need.Id)
		end
	end
	local coveredHousing: { [string]: number } = {}
	for _, need in Config.Needs do
		coveredHousing[need.Id] = 0
	end
	local housing = 0
	local happySum = 0
	local globalShift = (event.Happiness or 0) - H.NoPower * (1 - powerRatio)
	for _, home in homes do
		local hx, hz, size = home[1], home[2], home[3]
		local covered: { [string]: boolean } = {}
		for _, provider in providers do
			if not covered[provider[3]] and within(hx, hz, provider[1], provider[2], provider[4]) then
				covered[provider[3]] = true
			end
		end
		local score = H.Base
		for _, needId in activeNeeds do
			score += if covered[needId] then H.NeedCovered else -H.NeedMissing
		end
		for needId in covered do
			coveredHousing[needId] += size
		end
		local fun = 0
		for _, source in leisure do
			if within(hx, hz, source[1], source[2], source[4]) then
				fun += source[3]
			end
		end
		local dirt = 0
		for _, source in polluters do
			if within(hx, hz, source[1], source[2], source[4]) then
				dirt += source[3]
			end
		end
		score += math.min(fun, H.LeisureCap) - math.min(dirt, H.PollutionCap) + globalShift
		housing += size
		happySum += math.clamp(score, 0, 100) * size
	end
	local happiness = if housing > 0
		then happySum / housing
		else math.clamp(H.Base + globalShift, 0, 100)

	local coverage: { [string]: number } = {}
	for needId, amount in coveredHousing do
		coverage[needId] = if housing > 0 then amount / housing else 0
	end

	local P = Config.Population
	local fill = P.FillMin + (P.FillMax - P.FillMin) * happiness / 100
	local target = math.floor(housing * fill)

	local workers = math.floor(population * Config.WorkerShare)
	local staffing = if jobs > 0 then math.min(1, workers / jobs) else 0

	local multiplier = (1 + (tonumber(ctx.Reelections) or 0) * Config.Reelection.BonusPerTerm)
		* (if ctx.DoubleIncome then 2 else 1)
		* (event.Income or 1)
		* (1 + math.min(Config.Tourism.VisitorBonusCap, (tonumber(ctx.Visitors) or 0) * Config.Tourism.VisitorBonus))
	local income = population * Config.TaxPerResident * (event.Tax or 1)
		+ commerceIncome * staffing * (event.Commerce or 1)
		+ industryIncome * staffing * (event.Industry or 1)
	income *= (Config.PowerFloor + (1 - Config.PowerFloor) * powerRatio) * multiplier

	return {
		Housing = housing,
		Jobs = jobs,
		Workers = workers,
		Staffing = staffing,
		PowerSupply = supply,
		PowerDemand = demand,
		PowerRatio = powerRatio,
		Happiness = happiness,
		TargetPopulation = target,
		IncomePerSec = income,
		Multiplier = multiplier,
		Coverage = coverage,
		NoRoad = noRoad,
		NoRoadCount = noRoadCount,
		Tier = tier,
	}
end

function CityMath.StepPopulation(population: number, target: number, growth: number?): (number, number)
	local P = Config.Population
	if target > population then
		local add = math.max(1, math.ceil((target - population) * P.Step * (growth or 1)))
		return math.min(target, population + add), 0
	elseif target < population then
		local leaving = math.max(1, math.ceil((population - target) * P.LeaveStep))
		leaving = math.min(leaving, population - target)
		return population - leaving, leaving
	end
	return population, 0
end

function CityMath.VaultCapacity(level: number, incomePerSec: number): number
	local levels = Config.Vault.Levels
	local info = levels[math.clamp(level, 1, #levels)]
	return math.max(Config.Vault.MinCapacity * level, incomePerSec * 60 * info.Minutes)
end

return CityMath
