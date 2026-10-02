--[[
	Config (ModuleScript em ReplicatedStorage > Shared)          Prefeito Tycoon
	Todos os números do jogo num lugar só. PURO (sem API do Roblox): dá para testar no Lune.
	Mexer no balanceamento = mexer aqui. Os prédios ficam em Shared/Buildings.
]]

local Config = {}

Config.GameName = "Prefeito Tycoon"
Config.DataStoreName = "PrefeitoTycoon_v1"
Config.LeaderboardStores = {
	Stars = "PrefeitoTycoon_Stars_v1", -- recomendações recebidas (total)
	Population = "PrefeitoTycoon_Pop_v1", -- maior população já alcançada
}

-- ===== Mapa =====
Config.MaxPlayers = 8 -- um terreno por jogador
Config.GridSize = 24 -- terreno de 24 x 24 casas
Config.CellSize = 8 -- cada casa tem 8 studs
Config.LotRadius = 330 -- distância do centro do hub até o começo de cada terreno
Config.LotGroundY = 0 -- altura do chão dos terrenos (topo do chão)
Config.AvenueRow = 1 -- a fileira z = 1 é a Avenida (rua fixa, sempre ligada à Prefeitura)

-- Expansões do terreno: largura liberada (centralizada) e profundidade a partir da avenida
Config.Expansions = {
	{ Size = 12, Cost = 0 },
	{ Size = 16, Cost = 7500 },
	{ Size = 20, Cost = 90000 },
	{ Size = 24, Cost = 900000 },
}

-- ===== Economia =====
Config.StartCash = 1500
Config.SimInterval = 5 -- segundos entre cada passo da simulação da cidade
Config.TaxPerResident = 0.2 -- $ por morador por segundo
Config.WorkerShare = 0.6 -- parte da população que trabalha
Config.SellRefund = 0.5 -- demolir devolve 50% do preço
Config.PowerFloor = 0.4 -- sem energia nenhuma a cidade ainda rende 40% (nunca trava o jogador sem dinheiro)
Config.MaxCash = 1e15

-- Cofre da Prefeitura: a renda cai nele e o jogador precisa ir lá coletar (o loop do tycoon).
-- Capacidade = minutos de renda que cabem. Offline o cofre continua enchendo (com OfflineRate).
Config.Vault = {
	MinCapacity = 1500,
	Levels = {
		{ Minutes = 5, Cost = 0 },
		{ Minutes = 10, Cost = 4000 },
		{ Minutes = 20, Cost = 35000 },
		{ Minutes = 45, Cost = 300000 },
		{ Minutes = 120, Cost = 2500000 },
	},
	OfflineRate = 0.5,
	OfflineMaxHours = 12,
}

-- ===== Cidade =====
-- Níveis da cidade pela população: liberam prédios novos e novas necessidades dos moradores
Config.Tiers = {
	{ Id = 1, Name = "Vila", Population = 0 },
	{ Id = 2, Name = "Cidade", Population = 150 },
	{ Id = 3, Name = "Cidade Grande", Population = 1000 },
	{ Id = 4, Name = "Metrópole", Population = 5000 },
	{ Id = 5, Name = "Megalópole", Population = 20000 },
}

-- Necessidades: a partir de qual nível a falta dela começa a deixar o morador infeliz
Config.Needs = {
	{ Id = "comercio", Name = "Comércio", Tier = 1 },
	{ Id = "saude", Name = "Saúde", Tier = 1 },
	{ Id = "seguranca", Name = "Segurança", Tier = 2 },
	{ Id = "educacao", Name = "Educação", Tier = 2 },
}

Config.Happiness = {
	Base = 50,
	NeedCovered = 8, -- por necessidade atendida
	NeedMissing = 9, -- por necessidade em falta
	LeisureCap = 25, -- bônus máximo de lazer
	PollutionCap = 40, -- castigo máximo de poluição
	NoPower = 15, -- castigo inteiro quando falta energia (proporcional ao que falta)
	Unhappy = 40, -- abaixo disso os moradores começam a se mudar
	Attractive = 60, -- cidades a partir disso recebem quem se muda
}

Config.Population = {
	FillMin = 0.3, -- ocupação das casas com felicidade 0
	FillMax = 1.0, -- ocupação com felicidade 100
	Step = 0.2, -- quanto da diferença para a meta muda por passo
	LeaveStep = 0.2, -- parte dos insatisfeitos que vai embora por passo
}

-- ===== Reeleição (rebirth) =====
Config.Reelection = {
	Population = 5000, -- precisa ser Metrópole
	BonusPerTerm = 0.5, -- +50% de renda por mandato
	KeepStars = true,
}

-- ===== Turismo =====
Config.Tourism = {
	VisitorBonus = 0.05, -- +5% de renda por visitante na sua cidade
	VisitorBonusCap = 0.25,
	RecommendRewardSeconds = 60, -- quem recomenda ganha 60 s da própria renda
	RecommendMinReward = 100,
	OwnerRewardSeconds = 30, -- o dono ganha 30 s da renda dele
}

-- ===== Eventos globais (valem para todas as cidades do servidor) =====
Config.EventEvery = 600 -- segundos entre eventos
Config.EventDuration = 120
Config.Events = {
	{
		Id = "apagao",
		Name = "Apagão Regional",
		Text = "A rede caiu: as usinas produzem 40% a menos. Tenha energia sobrando!",
		Power = 0.6,
	},
	{
		Id = "feriado",
		Name = "Feriadão",
		Text = "Comércio vende o dobro, mas as indústrias param pela metade.",
		Commerce = 2,
		Industry = 0.5,
	},
	{
		Id = "calor",
		Name = "Onda de Calor",
		Text = "Todo mundo de mau humor: -12 de felicidade. Parques ajudam.",
		Happiness = -12,
	},
	{
		Id = "boom",
		Name = "Boom Imobiliário",
		Text = "Gente chegando: a população cresce 3x mais rápido e os impostos rendem +50%.",
		Growth = 3,
		Tax = 1.5,
	},
	{
		Id = "investidores",
		Name = "Rodada de Investimento",
		Text = "Investidores no hub: toda renda +30%.",
		Income = 1.3,
	},
}

-- ===== Nomes de cidade (sem texto livre: nada para filtrar) =====
Config.CityNameA = {
	"Nova", "Vila", "Porto", "São", "Santa", "Alto", "Campo", "Serra", "Monte", "Ribeirão",
	"Lago", "Rio", "Vale", "Ponta", "Barra", "Bela",
}
Config.CityNameB = {
	"Esperança", "Aurora", "Horizonte", "Dourada", "do Sol", "Verde", "das Pedras", "Alegre",
	"do Norte", "do Sul", "Brilhante", "dos Ventos", "Azul", "Serena", "Imperial", "Neon",
}

-- ===== Loja (0 = desligado; troque pelos Ids publicados no Creator Hub) =====
Config.GamePasses = {
	DoubleIncome = 0, -- renda x2
	AutoCollect = 0, -- o cofre cai direto no bolso
}
Config.DevProducts = {
	-- dinheiro = minutos da renda atual (mínimo garantido)
	{ Id = 0, Minutes = 10, Min = 5000 },
	{ Id = 0, Minutes = 60, Min = 40000 },
}

-- ===== Sons (sons oficiais e grátis da Roblox, os mesmos do Steal a Critter) =====
Config.Sounds = {
	Place = { Id = "rbxassetid://15675059323", Volume = 0.5, Speed = 1 }, -- Roblox_UI_Bright_Click
	Remove = { Id = "rbxassetid://15675075163", Volume = 0.5, Speed = 0.9 }, -- Roblox_UI_Delete
	Coin = { Id = "rbxassetid://127645268874265", Volume = 0.55, Speed = 1.2 }, -- CoinTransfer_01
	Click = { Id = "rbxassetid://15675032796", Volume = 0.4, Speed = 1 }, -- Roblox_UI_Small_Click
	Error = { Id = "rbxassetid://15675075163", Volume = 0.4, Speed = 0.8 },
	Upgrade = { Id = "rbxassetid://15675043410", Volume = 0.8, Speed = 1.1 }, -- Roblox_UI_Tonal_Stinger
	Fanfare = { Id = "rbxassetid://12222253", Volume = 0.7, Speed = 1 }, -- victory.wav
	Alert = { Id = "rbxassetid://17208361335", Volume = 0.6, Speed = 1 }, -- Notification High
	Whoosh = { Id = "rbxassetid://15675024286", Volume = 0.5, Speed = 1 }, -- Roblox_UI_Whoosh_01
}
Config.Music = { "rbxassetid://15675069601" } -- Roblox_UI_Loop_Calm_Music
Config.MusicVolume = 0.12

-- ===== Segurança =====
Config.ActionCooldown = 0.08 -- intervalo mínimo entre pedidos de construir/demolir
Config.AutosaveEvery = 60

return Config
