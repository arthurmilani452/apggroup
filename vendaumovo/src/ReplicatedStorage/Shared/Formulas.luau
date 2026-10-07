--[[
	Formulas: todas as contas do jogo, sem nada do Roblox (dá para testar fora do Studio).
	"C" é o Config. "data" são os dados salvos do jogador.
]]

local Formulas = {}

function Formulas.UpgradeLevel(data: any, id: string): number
	return tonumber(data.Upgrades and data.Upgrades[id]) or 0
end

function Formulas.UpgradeValue(C: any, data: any, id: string): number
	local upgrade = C.UpgradeById[id]
	local level = math.clamp(Formulas.UpgradeLevel(data, id), 0, #upgrade.Values - 1)
	return upgrade.Values[level + 1]
end

function Formulas.UpgradeCost(C: any, data: any, id: string): number?
	local upgrade = C.UpgradeById[id]
	return upgrade.Costs[Formulas.UpgradeLevel(data, id) + 1]
end

function Formulas.HasPass(data: any, key: string, owned: { [string]: boolean }?): boolean
	return (owned ~= nil and owned[key] == true) or (data.Passes ~= nil and data.Passes[key] == true)
end

function Formulas.BoostActive(data: any, boost: string, now: number): boolean
	return (tonumber(data.Boosts and data.Boosts[boost]) or 0) > now
end

-- Multiplicador de venda: rebirths × decoração × game pass x2 × boost x2
function Formulas.Multiplier(C: any, data: any, owned: { [string]: boolean }?, now: number): number
	local mult = 1 + C.RebirthBonus * (tonumber(data.Rebirths) or 0)
	mult *= 1 + Formulas.UpgradeValue(C, data, "Decoracao") / 100
	if Formulas.HasPass(data, "Dinheiro2x", owned) then
		mult *= 2
	end
	if Formulas.BoostActive(data, "Turbo", now) then
		mult *= C.TurboBoostMult
	end
	return mult
end

function Formulas.BasketCapacity(C: any, data: any, owned: { [string]: boolean }?): number
	local cap = Formulas.UpgradeValue(C, data, "Cesta")
	if Formulas.HasPass(data, "CestaVIP", owned) then
		cap *= 2
	end
	return cap
end

function Formulas.BasketCount(data: any): number
	local total = 0
	for _, count in data.Basket do
		total += count
	end
	return total
end

-- Chave da cesta: "dourado" (normal) ou "dourado*" (raro)
function Formulas.EggKey(eggId: string, rare: boolean): string
	return if rare then eggId .. "*" else eggId
end

function Formulas.ParseKey(key: string): (string, boolean)
	if string.sub(key, -1) == "*" then
		return string.sub(key, 1, -2), true
	end
	return key, false
end

function Formulas.EggValue(C: any, eggId: string, rare: boolean): number
	local egg = C.EggById[eggId]
	if not egg then
		return 0
	end
	return egg.Value * (if rare then C.RareMult else 1)
end

-- Quanto vale vender a cesta inteira agora
function Formulas.BasketValue(C: any, data: any, owned: { [string]: boolean }?, now: number): (number, number)
	local base, count = 0, 0
	for key, n in data.Basket do
		local eggId, rare = Formulas.ParseKey(key)
		base += Formulas.EggValue(C, eggId, rare) * n
		count += n
	end
	return math.floor(base * Formulas.Multiplier(C, data, owned, now) + 0.5), count
end

function Formulas.LayTime(C: any, data: any, henId: string): number
	local hen = C.HenById[henId]
	return (if hen then hen.LayTime else 10) * Formulas.UpgradeValue(C, data, "Postura")
end

function Formulas.RareChance(C: any, data: any, now: number): number
	return C.RareChance * (if Formulas.BoostActive(data, "Sorte", now) then C.LuckBoostMult else 1)
end

function Formulas.RebirthCost(C: any, data: any): number
	return C.RebirthBaseCost * C.RebirthCostGrowth ^ (tonumber(data.Rebirths) or 0)
end

-- A melhor ave que o jogador tem (serve de régua para prêmios crescerem junto com ele)
function Formulas.BestHen(C: any, data: any): any
	local best = C.Hens[1]
	for _, henId in data.Hens do
		local hen = C.HenById[henId]
		if hen and hen.Tier > best.Tier then
			best = hen
		end
	end
	return best
end

function Formulas.BestEggValue(C: any, data: any): number
	local hen = Formulas.BestHen(C, data)
	return C.EggById[hen.Egg].Value
end

function Formulas.GiftReward(C: any, data: any, owned: { [string]: boolean }?, now: number): number
	local value = Formulas.BestEggValue(C, data) * C.GiftEggs * Formulas.Multiplier(C, data, owned, now)
	return math.max(C.GiftMin, math.floor(value))
end

function Formulas.ProductCoins(C: any, product: any, data: any): number
	local value = Formulas.BestEggValue(C, data) * product.Eggs * Formulas.RebirthMult(C, data)
	return math.max(product.Min, math.floor(value))
end

-- Multiplicador "de base" (rebirth): usado por prêmios que crescem com o jogador
function Formulas.RebirthMult(C: any, data: any): number
	return 1 + C.RebirthBonus * (tonumber(data.Rebirths) or 0)
end

-- Ganho offline: quantos ovos as aves botaram fora do jogo e quanto isso vale (já vendido)
function Formulas.OfflineEarnings(C: any, data: any, owned: { [string]: boolean }?, seconds: number, now: number): (number, number)
	if seconds < C.Offline.MinSeconds then
		return 0, 0
	end
	local t = math.min(seconds, C.Offline.MaxSeconds)
	local eggs, value = 0, 0
	local cap = Formulas.UpgradeValue(C, data, "Ninhos")
	for i, henId in data.Hens do
		local hen = C.HenById[henId]
		if hen and i <= cap then
			local n = math.floor(t / Formulas.LayTime(C, data, henId) * C.Offline.Rate)
			eggs += n
			value += n * C.EggById[hen.Egg].Value
		end
	end
	return eggs, math.floor(value * Formulas.Multiplier(C, data, owned, now) + 0.5)
end

-- Sequência diária. streak = { Day = último dia pego (1-7), Last = DayKey do último prêmio }
-- Devolve o dia que pode pegar hoje (1-7), ou nil se já pegou hoje.
function Formulas.StreakNext(streak: any, today: number): number?
	local last = tonumber(streak and streak.Last) or 0
	if last == today then
		return nil
	end
	local day = tonumber(streak and streak.Day) or 0
	if last == today - 1 then
		return day % 7 + 1
	end
	return 1
end

function Formulas.StreakReward(C: any, data: any, day: number): number
	local eggs = C.Streak.Eggs[day] or C.Streak.Eggs[1]
	local min = C.Streak.Min[day] or C.Streak.Min[1]
	return math.max(min, math.floor(Formulas.BestEggValue(C, data) * eggs * Formulas.RebirthMult(C, data)))
end

-- Códigos: só letras e números, em maiúsculas
function Formulas.NormalizeCode(text: string): string
	return string.upper((string.gsub(text, "[^%w]", "")))
end

function Formulas.FindCode(C: any, text: string): any?
	local code = Formulas.NormalizeCode(text)
	for _, entry in C.Codes do
		if entry.Code == code then
			return entry
		end
	end
	return nil
end

function Formulas.CodeReward(C: any, data: any, entry: any): number
	return math.max(entry.Min, math.floor(Formulas.BestEggValue(C, data) * entry.Eggs * Formulas.RebirthMult(C, data)))
end

-- Clientes por minuto numa granja
function Formulas.CustomerRate(C: any, data: any, basketCount: number): number
	local rate = C.Customers.BaseRate + C.Customers.DecorBonus * Formulas.UpgradeLevel(data, "Decoracao")
	if basketCount <= 0 then
		rate *= C.Customers.EmptyRateMult
	end
	return rate
end

-- Missões do dia: sempre as mesmas para o mesmo dia (sorteio com a semente do dia)
function Formulas.DayKey(now: number): number
	return math.floor(now / 86400)
end

function Formulas.MakeMissions(C: any, data: any, day: number): { any }
	-- gerador simples com semente (igual em qualquer servidor)
	local seed = (day * 7919 + 17) % 2147483647
	local function nextInt(lo: number, hi: number): number
		seed = (seed * 48271) % 2147483647
		return lo + seed % (hi - lo + 1)
	end
	local pool = table.clone(C.Missions)
	local list = {}
	local best = Formulas.BestHen(C, data)
	local reward = math.max(C.MissionRewardMin, math.floor(best.Price * C.MissionRewardHenFraction))
	for _ = 1, math.min(C.DailyMissionCount, #pool) do
		local mission = table.remove(pool, nextInt(1, #pool))
		local target = mission.Base
		if mission.Id == "earn" then
			target = math.max(500, Formulas.BestEggValue(C, data) * 150)
		end
		table.insert(list, { Id = mission.Id, Target = target, Progress = 0, Reward = reward, Claimed = false })
	end
	return list
end

return Formulas
