--[[
	Market: as contas do mercado (sem nada do Roblox, dá para testar fora do Studio).
	"cfg" é Config.Market.

	Ideia: cada cliente aceita pagar até   sugerido × vontade(1,0 a 1,5) × fator da reputação × humor.
	Preço baixo = vende sempre e a reputação sobe. Preço alto = lucra mais por venda, mas há recusas e a reputação cai.
]]

local Market = {}

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

-- Preço exato (sem arredondar) de um item: valor do ovo × receita × markup%
function Market.ExactPrice(eggValue: number, recipeMult: number, markup: number): number
	return eggValue * recipeMult * markup / 100
end

-- Preço cobrado (arredondado, mínimo $1)
function Market.Price(eggValue: number, recipeMult: number, markup: number): number
	return math.max(1, math.floor(Market.ExactPrice(eggValue, recipeMult, markup) + 0.5))
end

function Market.RepFactor(rep: number, cfg: any): number
	local t = clamp(rep / 5, 0, 1)
	return cfg.RepFactorMin + (cfg.RepFactorMax - cfg.RepFactorMin) * t
end

-- Quanto um cliente aceita pagar. roll vai de 0 a 1 (sorteio do cliente).
function Market.MaxPrice(suggested: number, rep: number, roll: number, mood: number, vip: boolean, cfg: any): number
	local willing = cfg.WillingMin + (cfg.WillingMax - cfg.WillingMin) * clamp(roll, 0, 1)
	return suggested * willing * Market.RepFactor(rep, cfg) * mood * (if vip then cfg.VipMult else 1)
end

function Market.Buys(exactPrice: number, maxPrice: number): boolean
	return exactPrice <= maxPrice + 1e-9
end

-- Mudança de reputação depois de um cliente ser atendido
function Market.RepChange(exactPrice: number, maxPrice: number, bought: boolean, cfg: any): number
	if not bought then
		return cfg.RepRefuse
	end
	if exactPrice <= maxPrice * cfg.GoodDealRatio then
		return cfg.RepSale + cfg.RepGoodDeal
	end
	return cfg.RepSale
end

function Market.ClampRep(rep: number): number
	return clamp(rep, 0, 5)
end

-- Clientes por minuto numa barraca
function Market.Rate(rep: number, bonusStars: number, hasStock: boolean, raining: boolean, sold: number, cfg: any): number
	local rate = cfg.BaseRate + cfg.RatePerStar * clamp(rep + bonusStars, 0, 6)
	if not hasStock then
		rate *= cfg.EmptyRateMult
	end
	if raining then
		rate *= cfg.RainRateMult
	end
	if sold < cfg.NewbieSales then
		rate += cfg.NewbieRateBonus
	end
	return rate
end

-- Qual receita o cliente quer. Se não tiver a preferida, leva a outra.
function Market.PickRecipe(roll: number, hasRaw: boolean, hasBoiled: boolean, raining: boolean, cfg: any): string?
	local wantsBoiled = roll < (if raining then cfg.BoiledPrefRain else cfg.BoiledPref)
	if wantsBoiled then
		return if hasBoiled then "boiled" elseif hasRaw then "raw" else nil
	end
	return if hasRaw then "raw" elseif hasBoiled then "boiled" else nil
end

-- Escolhe um item pelo peso (lista de { Weight = n })
function Market.Weighted(list: { any }, roll: number): any?
	local total = 0
	for _, item in list do
		total += item.Weight or 0
	end
	if total <= 0 then
		return nil
	end
	local target = clamp(roll, 0, 0.999999) * total
	for _, item in list do
		target -= item.Weight or 0
		if target < 0 then
			return item
		end
	end
	return list[#list]
end

return Market
