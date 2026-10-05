--[[
	VENDA UM OVO - configuração do jogo inteiro num lugar só.
	Preços, tempos, melhorias, game passes e TODOS os IDs de imagem/textura/som.
	Mudou um número aqui, o jogo inteiro segue (servidor e tela).
]]

local Config = {}

-- fora do Roblox (testes em vendaumovo/tests) não existe Color3: usa uma tabela simples no lugar
local Color3 = Color3 or { fromRGB = function(r: number, g: number, b: number): any
	return { R = r, G = g, B = b }
end }

Config.DataStoreName = "VendaUmOvo_v1"
Config.LeaderboardStore = "VendaUmOvo_TopVendedores_v1"
Config.StartCoins = 10
Config.StartHens = { "comum" }

-- ---------------------------------------------------------------------------
-- IMAGENS (suba no Gerenciador de Ativos do Studio e cole o ID: "rbxassetid://123456")
-- Vazio = o jogo usa um emoji no lugar. Os arquivos estão em vendaumovo/arte/.
-- ---------------------------------------------------------------------------
Config.Images = {
	Moeda = "", -- arte/icones/moeda.png
	Cesta = "", -- arte/icones/cesta.png
	Raio = "", -- arte/icones/raio.png
	Estrela = "", -- arte/icones/estrela.png
	Presente = "", -- arte/icones/presente.png
	Trofeu = "", -- arte/icones/trofeu.png
	Ovo_Branco = "", -- arte/icones/ovo_branco.png
	Ovo_Caipira = "",
	Ovo_Pata = "",
	Ovo_Codorna = "",
	Ovo_Dourado = "",
	Ovo_Cristal = "",
	Ovo_ArcoIris = "",
	Ovo_Lunar = "",
	Ovo_Dragao = "",
}

-- Texturas que repetem (arte/texturas/). Com ID, o chão/madeira/telhado ganham a textura.
Config.Textures = {
	Grama = "",
	Terra = "",
	Palha = "",
	Madeira = "",
	Telha = "",
}
Config.TextureTile = 16 -- tamanho (studs) de cada repetição

-- Sons (Creator Store). Vazio = sem som.
Config.Sounds = {
	Coletar = "",
	Vender = "",
	OvoRaro = "",
	Comprar = "",
	Rebirth = "",
}

-- ---------------------------------------------------------------------------
-- OVOS e AVES. Asset = nome do Model em ReplicatedStorage > Assets (troque o Model, mantenha o nome).
-- ---------------------------------------------------------------------------
Config.Eggs = {
	{ Id = "branco", Name = "Ovo Branco", Asset = "Ovo_Branco", Value = 1, Color = Color3.fromRGB(250, 248, 240) },
	{ Id = "caipira", Name = "Ovo Caipira", Asset = "Ovo_Caipira", Value = 4, Color = Color3.fromRGB(196, 140, 92) },
	{ Id = "pata", Name = "Ovo de Pata", Asset = "Ovo_Pata", Value = 15, Color = Color3.fromRGB(170, 225, 210) },
	{ Id = "codorna", Name = "Ovo de Codorna", Asset = "Ovo_Codorna", Value = 50, Color = Color3.fromRGB(235, 215, 180) },
	{ Id = "dourado", Name = "Ovo Dourado", Asset = "Ovo_Dourado", Value = 250, Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "cristal", Name = "Ovo de Cristal", Asset = "Ovo_Cristal", Value = 1200, Color = Color3.fromRGB(140, 220, 255) },
	{ Id = "arcoiris", Name = "Ovo Arco-íris", Asset = "Ovo_ArcoIris", Value = 6000, Color = Color3.fromRGB(255, 120, 200) },
	{ Id = "lunar", Name = "Ovo Lunar", Asset = "Ovo_Lunar", Value = 35000, Color = Color3.fromRGB(40, 50, 110) },
	{ Id = "dragao", Name = "Ovo de Dragão", Asset = "Ovo_Dragao", Value = 250000, Color = Color3.fromRGB(200, 40, 30), Legendary = true },
}

Config.Hens = {
	{ Id = "comum", Name = "Galinha Comum", Asset = "Galinha_Comum", Egg = "branco", Price = 25, LayTime = 6 },
	{ Id = "caipira", Name = "Galinha Caipira", Asset = "Galinha_Caipira", Egg = "caipira", Price = 250, LayTime = 7 },
	{ Id = "pata", Name = "Pata", Asset = "Pata", Egg = "pata", Price = 1500, LayTime = 8 },
	{ Id = "codorna", Name = "Codorna", Asset = "Codorna", Egg = "codorna", Price = 8000, LayTime = 6 },
	{ Id = "dourada", Name = "Galinha Dourada", Asset = "Galinha_Dourada", Egg = "dourado", Price = 50000, LayTime = 9 },
	{ Id = "cristal", Name = "Galinha de Cristal", Asset = "Galinha_Cristal", Egg = "cristal", Price = 300000, LayTime = 10 },
	{ Id = "arcoiris", Name = "Galinha Arco-íris", Asset = "Galinha_ArcoIris", Egg = "arcoiris", Price = 2000000, LayTime = 10 },
	{ Id = "lunar", Name = "Galinha Lunar", Asset = "Galinha_Lunar", Egg = "lunar", Price = 15000000, LayTime = 11 },
	{ Id = "dragao", Name = "Filhote de Dragão", Asset = "Filhote_Dragao", Egg = "dragao", Price = 120000000, LayTime = 12 },
}

Config.EggById = {}
for index, egg in Config.Eggs do
	egg.Tier = index
	Config.EggById[egg.Id] = egg
end
Config.HenById = {}
for index, hen in Config.Hens do
	hen.Tier = index
	Config.HenById[hen.Id] = hen
end

Config.RareChance = 0.04 -- 4% dos ovos saem "brilhantes" (raros)
Config.RareMult = 5 -- ovo raro vale 5x
Config.EggsPerNest = 3 -- a galinha para de botar com o ninho cheio
Config.ReplaceRefund = 0.25 -- ninhos cheios: a galinha mais fraca sai e devolve 25% do preço dela

-- Altura (studs) de cada Asset no jogo. Um modelo novo importado é ajustado para esta altura.
Config.AssetHeights = {
	Ovo = 1.5,
	Ave = 3,
	Ninho = 1.4,
	Cesta = 1.6,
}

-- ---------------------------------------------------------------------------
-- MELHORIAS. Values[1] = nível 0 (de graça). Costs[n] leva ao nível n.
-- ---------------------------------------------------------------------------
Config.Upgrades = {
	{ Id = "Cesta", Name = "Cesta Maior", Icon = "Cesta", Costs = { 100, 600, 3000, 15000, 80000, 400000, 2000000 }, Values = { 10, 20, 35, 60, 100, 160, 250, 400 }, Format = "{v} ovos" },
	{ Id = "Ninhos", Name = "Mais Ninhos", Icon = "Ovo_Caipira", Costs = { 400, 5000, 60000, 800000 }, Values = { 4, 6, 8, 10, 12 }, Format = "{v} galinhas" },
	{ Id = "Postura", Name = "Postura Rápida", Icon = "Raio", Costs = { 200, 2000, 20000, 200000, 2000000 }, Values = { 1, 0.9, 0.8, 0.7, 0.6, 0.5 }, Format = "ovos {p}% mais rápido" },
	{ Id = "Velocidade", Name = "Tênis Veloz", Icon = "Raio", Costs = { 150, 1500, 15000, 150000, 1500000 }, Values = { 16, 19, 22, 25, 28, 32 }, Format = "velocidade {v}" },
	{ Id = "ColetaAuto", Name = "Coleta Automática", Icon = "Cesta", Costs = { 50000 }, Values = { 0, 1 }, Format = "pega os ovos sozinho" },
	{ Id = "Esteira", Name = "Esteira de Ovos", Icon = "Moeda", Costs = { 250000 }, Values = { 0, 1 }, Format = "leva e vende os ovos sozinha" },
	{ Id = "Decoracao", Name = "Decorar a Granja", Icon = "Trofeu", Costs = { 500, 5000, 50000, 500000, 5000000, 50000000 }, Values = { 0, 3, 6, 9, 12, 15, 18 }, Format = "+{v}% na venda" },
}
Config.UpgradeById = {}
for _, upgrade in Config.Upgrades do
	Config.UpgradeById[upgrade.Id] = upgrade
end

-- Coleta automática / esteira
Config.AutoCollectInterval = 2
Config.ConveyorTravelTime = 4 -- segundos do ninho até a banca

-- ---------------------------------------------------------------------------
-- REBIRTH: com moedas suficientes, recomeça a granja e ganha multiplicador para sempre
-- ---------------------------------------------------------------------------
Config.RebirthBaseCost = 1000000
Config.RebirthCostGrowth = 3
Config.RebirthBonus = 0.5 -- +50% em toda venda por rebirth

-- ---------------------------------------------------------------------------
-- MISSÕES DIÁRIAS e PRESENTE (relógio do SERVIDOR)
-- ---------------------------------------------------------------------------
Config.DailyMissionCount = 3
Config.Missions = {
	{ Id = "collect", Text = "Colete {n} ovos", Base = 60 },
	{ Id = "sell", Text = "Venda {n} ovos", Base = 60 },
	{ Id = "sellTrips", Text = "Venda na banca {n} vezes", Base = 10 },
	{ Id = "rare", Text = "Encontre {n} ovos raros", Base = 2 },
	{ Id = "buyHen", Text = "Compre {n} galinha(s)", Base = 1 },
	{ Id = "earn", Text = "Ganhe {n} moedas", Base = 0 }, -- calculado pelo melhor ovo do jogador
}
Config.MissionRewardHenFraction = 0.6 -- prêmio = 60% do preço da melhor ave que o jogador tem (mínimo abaixo)
Config.MissionRewardMin = 100

Config.GiftInterval = 600 -- um presente a cada 10 min jogando
Config.GiftEggs = 80 -- prêmio = valor de 80 ovos da melhor ave do jogador (com multiplicador)
Config.GiftMin = 50

-- ---------------------------------------------------------------------------
-- GAME PASSES (crie no Creator Hub e cole o ID. 0 = desligado, o botão some)
-- ---------------------------------------------------------------------------
Config.GamePasses = {
	{ Key = "Dinheiro2x", Id = 0, Name = "Dinheiro x2", Desc = "Toda venda vale o dobro", Icon = "Moeda" },
	{ Key = "CestaVIP", Id = 0, Name = "Cesta VIP", Desc = "Cesta com o dobro de espaço", Icon = "Cesta" },
	{ Key = "ColetaAuto", Id = 0, Name = "Coleta Automática", Desc = "Pega os ovos sozinho", Icon = "Raio" },
}

-- PRODUTOS (Developer Products: dá para comprar várias vezes). Crie no Creator Hub > Monetização >
-- Produtos de desenvolvedor e cole o ID. 0 = desligado.
--   Kind "coins": moedas = valor de "Eggs" ovos da melhor ave do jogador (cresce junto com o jogo), mínimo "Min"
--   Kind "boost": liga um efeito por "Seconds" (soma se comprar de novo)
Config.Products = {
	{ Key = "MoedasP", Id = 0, Kind = "coins", Name = "Saquinho de Moedas", Eggs = 300, Min = 500, Icon = "Moeda", Robux = 25 },
	{ Key = "MoedasM", Id = 0, Kind = "coins", Name = "Baú de Moedas", Eggs = 1500, Min = 2500, Icon = "Moeda", Robux = 99 },
	{ Key = "MoedasG", Id = 0, Kind = "coins", Name = "Caminhão de Moedas", Eggs = 8000, Min = 15000, Icon = "Moeda", Robux = 399 },
	{ Key = "Sorte", Id = 0, Kind = "boost", Boost = "Sorte", Seconds = 900, Name = "Sorte x3 (15 min)", Desc = "3x mais ovos raros", Icon = "Estrela", Robux = 49 },
	{ Key = "Turbo", Id = 0, Kind = "boost", Boost = "Turbo", Seconds = 600, Name = "Venda x2 (10 min)", Desc = "Vendas valem o dobro", Icon = "Raio", Robux = 39 },
}
Config.LuckBoostMult = 3
Config.TurboBoostMult = 2

-- ---------------------------------------------------------------------------
-- Segurança e distâncias (o servidor confere tudo)
-- ---------------------------------------------------------------------------
Config.RequestCooldown = 0.25 -- intervalo mínimo entre pedidos iguais
Config.SellDistance = 18 -- até onde pode estar da banca para vender
Config.ShopDistance = 24 -- até onde pode estar da loja para comprar
Config.CollectDistance = 14 -- até onde pode estar do ninho para coletar

Config.MaxPlayers = 12

return Config
