--[[
	VENDA SEU OVO - todos os números do jogo ficam aqui.
	Mudou um número, rodou o builder (ou editou no Studio), pronto.
]]

local Config = {}

Config.DataStoreName = "VendaSeuOvo_v1"
Config.WalkSpeed = 18
Config.StartMoney = 20
Config.StartHens = { "caipira", "caipira" } -- galinhas de quem joga pela primeira vez
Config.StartNest = { caipira = 3 } -- ovos já no ninho no primeiro acesso (o tutorial começa por eles)

-- Sons: cole aqui IDs da Creator Store ("rbxassetid://123"). Vazio = sem som.
Config.Sounds = {
	Sale = "",
	Refuse = "",
	Buy = "",
	Cackle = "",
	Alarm = "",
	Rain = "",
}

-- GALINHAS. EggValue = valor de um ovo cru no preço sugerido. CartWeight = chance de aparecer na Carroça.
-- Para criar uma raça nova, copie uma linha (e coloque o nome dela em Strings: H_<id>).
Config.Hens = {
	{
		Id = "caipira",
		Price = 60,
		LayTime = 10,
		EggValue = 6,
		InShop = true,
		CartWeight = 0,
		Body = Color3.fromRGB(196, 140, 90),
		Wing = Color3.fromRGB(150, 95, 55),
		Egg = Color3.fromRGB(236, 214, 178),
	},
	{
		Id = "pintada",
		Price = 600,
		LayTime = 9,
		EggValue = 25,
		InShop = true,
		CartWeight = 70,
		Body = Color3.fromRGB(70, 70, 78),
		Wing = Color3.fromRGB(235, 235, 235),
		Egg = Color3.fromRGB(150, 205, 230),
		Spots = true,
	},
	{
		Id = "dourada",
		Price = 6000,
		LayTime = 8,
		EggValue = 120,
		InShop = false,
		CartWeight = 30,
		Body = Color3.fromRGB(255, 196, 40),
		Wing = Color3.fromRGB(255, 150, 20),
		Egg = Color3.fromRGB(255, 205, 50),
		Glow = true,
	},
}

Config.HenById = {}
for index, hen in Config.Hens do
	hen.Order = index
	Config.HenById[hen.Id] = hen
end

Config.SellHenFraction = 0.5 -- vender galinha devolve 50% do preço

-- RECEITAS. Mult = quantas vezes o valor do ovo cru.
Config.Recipes = {
	{ Id = "raw", Mult = 1 },
	{ Id = "boiled", Mult = 2 },
}
Config.RecipeById = {}
for _, recipe in Config.Recipes do
	Config.RecipeById[recipe.Id] = recipe
end

-- Preço que o jogador escolhe, em % do preço sugerido
Config.Markup = { Min = 50, Max = 300, Step = 10, Default = 100 }

Config.NestCapacity = 12 -- as galinhas param de botar com o ninho cheio

-- MELHORIAS. Values[1] é o nível 0 (de graça); Costs[n] leva ao nível n.
Config.Upgrades = {
	{ Id = "Yard", Costs = { 300, 2500, 20000 }, Values = { 4, 6, 8, 10 } }, -- vagas de galinha
	{ Id = "Showcase", Costs = { 200, 1500, 12000 }, Values = { 6, 8, 10, 12 } }, -- vagas da vitrine
	{ Id = "Basket", Costs = { 150, 1200, 9000 }, Values = { 10, 15, 20, 30 } }, -- tamanho da cesta
	{ Id = "Stove", Costs = { 150, 1000, 8000, 40000 }, Values = { 0, 2, 3, 4, 6 } }, -- bocas do fogão (0 = sem fogão)
	{ Id = "Awning", Costs = { 500, 5000, 30000 }, Values = { 0, 0.3, 0.6, 1 } }, -- toldo: estrelas extras para atrair cliente
}
Config.UpgradeById = {}
for _, upgrade in Config.Upgrades do
	Config.UpgradeById[upgrade.Id] = upgrade
end
Config.StoveCookTime = { 0, 6, 5, 4, 3 } -- segundos para cozinhar, por nível do fogão

-- CLIENTES (o coração do jogo). Veja Market.luau para as fórmulas.
Config.Market = {
	StartRep = 2.5, -- estrelas iniciais (0 a 5)
	WillingMin = 1.0, -- o cliente aceita pagar entre 100% ...
	WillingMax = 1.5, -- ... e 150% do preço sugerido (vezes o fator da reputação)
	RepFactorMin = 0.85, -- 0 estrelas: clientes pagam 15% menos
	RepFactorMax = 1.15, -- 5 estrelas: clientes pagam 15% mais
	VipMult = 5,
	GoodDealRatio = 0.85, -- preço até 85% do máximo do cliente = "pechincha" (reputação sobe mais)
	RepSale = 0.01,
	RepGoodDeal = 0.03,
	RepRefuse = -0.05,
	RepEmpty = -0.01,
	RepEmptyFloor = 1.5, -- vitrine vazia nunca derruba a reputação abaixo disso
	BaseRate = 5, -- clientes por minuto em cada barraca...
	RatePerStar = 2.5, -- ... mais isto por estrela
	EmptyRateMult = 0.35, -- vitrine vazia atrai menos gente
	NewbieRateBonus = 4, -- clientes extras por minuto para quem ainda vendeu pouco
	NewbieSales = 5,
	BoiledPref = 0.4, -- chance de o cliente preferir cozido
	BoiledPrefRain = 0.7,
	RainBoiledBonus = 1.2, -- na chuva, cozido vale 20% mais para o cliente
	RainRateMult = 0.7, -- na chuva vem menos gente
}

Config.Customers = {
	MaxAlive = 30,
	QueueSize = 4,
	WalkSpeed = 12,
	ServeTime = 1.2,
	Patience = 30, -- desiste da fila depois disso
	VipChance = 0.03,
	MaxLife = 90,
}

Config.Weather = { Cycle = 180, RainChance = 0.35 }

Config.Cart = { Interval = 150, Duration = 60, Slots = 3, Discount = 0.8 }

Config.Steal = {
	HoldHen = 1.5,
	HoldBasket = 1.0,
	BasketMax = 5,
	HenSpeedMult = 0.6,
	BasketSpeedMult = 0.8,
	MaxCarry = 120, -- ninguém segura item roubado por mais que isso (volta ao dono)
	StolenLock = 120, -- item roubado não pode ser vendido nesse tempo
	NewbieShield = 600, -- novatos não podem ser roubados nos primeiros 10 min de jogo
	RevengeSpeed = 1.2, -- vítima fica 20% mais rápida enquanto estão roubando dela
	GateTime = 45,
	GateCooldown = 150,
	OwnerGuardDistance = 16, -- com o dono perto do balcão, ninguém rouba a vitrine
	PromptDistance = 12,
}

Config.RequestCooldown = 0.15 -- intervalo mínimo entre pedidos iguais do mesmo jogador

return Config
