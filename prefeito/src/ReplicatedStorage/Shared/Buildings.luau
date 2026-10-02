--[[
	Buildings (ModuleScript em ReplicatedStorage > Shared)          Prefeito Tycoon
	Lista de prédios. PURO: dá para testar no Lune.

	Campos:
	  Id, Name, Desc, Category, Tier (nível da cidade que libera), Cost
	  W, D            tamanho em casas da grade (antes de girar)
	  Housing         vagas de moradia
	  Jobs            vagas de emprego
	  Income          $/s com todos os empregos preenchidos (comércio e indústria)
	  Power           energia que consome
	  PowerSupply     energia que produz
	  Need, Radius    necessidade que atende e alcance (em casas, distância "de xadrez")
	  Leisure, LeisureRadius     felicidade que dá para as casas por perto
	  Pollution, PollutionRadius felicidade que tira das casas por perto
	  NoRoad          funciona sem rua do lado (árvores)
	  Model           como desenhar (Shared/BuildingModels)
]]

export type Building = {
	Id: string,
	Name: string,
	Desc: string,
	Category: string,
	Tier: number,
	Cost: number,
	W: number,
	D: number,
	Housing: number?,
	Jobs: number?,
	Income: number?,
	Power: number?,
	PowerSupply: number?,
	Need: string?,
	Radius: number?,
	Leisure: number?,
	LeisureRadius: number?,
	Pollution: number?,
	PollutionRadius: number?,
	NoRoad: boolean?,
	Model: { [string]: any },
}

local Buildings = {}

Buildings.Categories = {
	{ Id = "road", Name = "Ruas" },
	{ Id = "residential", Name = "Moradia" },
	{ Id = "commercial", Name = "Comércio" },
	{ Id = "industrial", Name = "Indústria" },
	{ Id = "service", Name = "Serviços" },
	{ Id = "leisure", Name = "Lazer" },
	{ Id = "power", Name = "Energia" },
}

local list: { Building } = {
	-- ===== Ruas =====
	{
		Id = "rua", Name = "Rua", Desc = "Todo prédio precisa de rua do lado, ligada à Avenida.",
		Category = "road", Tier = 1, Cost = 10, W = 1, D = 1,
		Model = { Kind = "road" },
	},

	-- ===== Moradia =====
	{
		Id = "casa", Name = "Casa", Desc = "Moradia simples. 6 moradores.",
		Category = "residential", Tier = 1, Cost = 100, W = 1, D = 1, Housing = 6, Power = 1,
		Model = { Kind = "house", Height = 9, Color = { 214, 196, 170 }, Roof = { 140, 62, 48 } },
	},
	{
		Id = "sobrado", Name = "Sobrado", Desc = "Dois andares. 14 moradores.",
		Category = "residential", Tier = 2, Cost = 450, W = 1, D = 1, Housing = 14, Power = 2,
		Model = { Kind = "house", Height = 15, Color = { 186, 196, 204 }, Roof = { 60, 64, 72 } },
	},
	{
		Id = "predio", Name = "Prédio Residencial", Desc = "Oito andares. 120 moradores.",
		Category = "residential", Tier = 3, Cost = 7000, W = 2, D = 2, Housing = 120, Power = 6,
		Model = { Kind = "tower", Height = 34, Color = { 168, 150, 132 }, Window = { 255, 214, 140 } },
	},
	{
		Id = "torre", Name = "Torre Residencial", Desc = "Vidro e concreto. 500 moradores.",
		Category = "residential", Tier = 4, Cost = 70000, W = 2, D = 2, Housing = 500, Power = 25,
		Model = { Kind = "tower", Height = 70, Color = { 70, 86, 104 }, Window = { 150, 210, 255 }, Glass = true },
	},
	{
		Id = "arranhaceu", Name = "Arranha-céu Residencial", Desc = "O topo do skyline. 2.000 moradores.",
		Category = "residential", Tier = 5, Cost = 450000, W = 3, D = 3, Housing = 2000, Power = 80,
		Model = { Kind = "tower", Height = 120, Color = { 40, 46, 60 }, Window = { 255, 120, 220 }, Glass = true, Spire = true },
	},

	-- ===== Comércio =====
	{
		Id = "padaria", Name = "Padaria", Desc = "Pão quente e empregos. Atende Comércio.",
		Category = "commercial", Tier = 1, Cost = 250, W = 1, D = 1, Jobs = 3, Income = 3, Power = 1,
		Need = "comercio", Radius = 4,
		Model = { Kind = "shop", Height = 8, Color = { 230, 200, 140 }, Awning = { 200, 70, 50 } },
	},
	{
		Id = "mercado", Name = "Mercado", Desc = "Bairro inteiro faz compras aqui.",
		Category = "commercial", Tier = 2, Cost = 1500, W = 2, D = 2, Jobs = 10, Income = 14, Power = 4,
		Need = "comercio", Radius = 6,
		Model = { Kind = "shop", Height = 11, Color = { 210, 214, 220 }, Awning = { 40, 140, 80 } },
	},
	{
		Id = "shopping", Name = "Shopping", Desc = "Ar-condicionado e praça de alimentação.",
		Category = "commercial", Tier = 3, Cost = 20000, W = 3, D = 3, Jobs = 40, Income = 110, Power = 15,
		Need = "comercio", Radius = 9,
		Model = { Kind = "shop", Height = 18, Color = { 236, 232, 226 }, Awning = { 30, 90, 200 }, Sign = true },
	},
	{
		Id = "torrecomercial", Name = "Torre Comercial", Desc = "Escritórios caros. Muita renda.",
		Category = "commercial", Tier = 4, Cost = 90000, W = 2, D = 2, Jobs = 150, Income = 600, Power = 40,
		Need = "comercio", Radius = 10,
		Model = { Kind = "tower", Height = 90, Color = { 30, 60, 90 }, Window = { 120, 255, 230 }, Glass = true },
	},

	-- ===== Indústria =====
	{
		Id = "oficina", Name = "Oficina", Desc = "Boa renda, um pouco de poluição.",
		Category = "industrial", Tier = 2, Cost = 1800, W = 2, D = 2, Jobs = 12, Income = 20, Power = 5,
		Pollution = 10, PollutionRadius = 4,
		Model = { Kind = "factory", Height = 10, Color = { 150, 120, 96 }, Chimneys = 1 },
	},
	{
		Id = "fabrica", Name = "Fábrica", Desc = "Muita renda e muita fumaça. Longe das casas!",
		Category = "industrial", Tier = 3, Cost = 16000, W = 3, D = 3, Jobs = 50, Income = 140, Power = 20,
		Pollution = 18, PollutionRadius = 6,
		Model = { Kind = "factory", Height = 14, Color = { 120, 110, 104 }, Chimneys = 2 },
	},
	{
		Id = "polotech", Name = "Polo Tecnológico", Desc = "Indústria limpa e muito lucrativa.",
		Category = "industrial", Tier = 4, Cost = 150000, W = 3, D = 3, Jobs = 200, Income = 1400, Power = 60,
		Pollution = 4, PollutionRadius = 3,
		Model = { Kind = "campus", Height = 22, Color = { 230, 236, 240 }, Window = { 90, 200, 255 } },
	},

	-- ===== Serviços =====
	{
		Id = "postosaude", Name = "Posto de Saúde", Desc = "Atende Saúde.",
		Category = "service", Tier = 1, Cost = 600, W = 2, D = 2, Jobs = 4, Power = 2,
		Need = "saude", Radius = 6,
		Model = { Kind = "civic", Height = 9, Color = { 240, 240, 240 }, Accent = { 200, 40, 40 }, Icon = "+" },
	},
	{
		Id = "delegacia", Name = "Delegacia", Desc = "Atende Segurança.",
		Category = "service", Tier = 2, Cost = 2200, W = 2, D = 2, Jobs = 8, Power = 3,
		Need = "seguranca", Radius = 7,
		Model = { Kind = "civic", Height = 11, Color = { 200, 206, 220 }, Accent = { 30, 60, 160 }, Icon = "★" },
	},
	{
		Id = "escola", Name = "Escola", Desc = "Atende Educação.",
		Category = "service", Tier = 2, Cost = 2000, W = 2, D = 2, Jobs = 8, Power = 3,
		Need = "educacao", Radius = 7,
		Model = { Kind = "civic", Height = 11, Color = { 236, 214, 170 }, Accent = { 200, 140, 30 }, Icon = "A" },
	},
	{
		Id = "hospital", Name = "Hospital", Desc = "Saúde para meia cidade.",
		Category = "service", Tier = 3, Cost = 18000, W = 3, D = 3, Jobs = 30, Power = 12,
		Need = "saude", Radius = 11,
		Model = { Kind = "civic", Height = 22, Color = { 246, 246, 246 }, Accent = { 200, 40, 40 }, Icon = "+" },
	},
	{
		Id = "bombeiros", Name = "Quartel de Bombeiros", Desc = "Segurança com alcance grande.",
		Category = "service", Tier = 3, Cost = 9000, W = 2, D = 2, Jobs = 14, Power = 6,
		Need = "seguranca", Radius = 10,
		Model = { Kind = "civic", Height = 13, Color = { 190, 50, 40 }, Accent = { 240, 240, 240 }, Icon = "B" },
	},
	{
		Id = "universidade", Name = "Universidade", Desc = "Educação para a metrópole.",
		Category = "service", Tier = 4, Cost = 80000, W = 3, D = 3, Jobs = 60, Power = 25,
		Need = "educacao", Radius = 14,
		Model = { Kind = "civic", Height = 20, Color = { 160, 90, 70 }, Accent = { 240, 220, 170 }, Icon = "U" },
	},

	-- ===== Lazer =====
	{
		Id = "arvore", Name = "Árvore", Desc = "Um pouco de verde. Não precisa de rua.",
		Category = "leisure", Tier = 1, Cost = 40, W = 1, D = 1, Leisure = 2, LeisureRadius = 2, NoRoad = true,
		Model = { Kind = "tree" },
	},
	{
		Id = "praca", Name = "Praça", Desc = "Banco, fonte e pombos.",
		Category = "leisure", Tier = 1, Cost = 150, W = 1, D = 1, Leisure = 6, LeisureRadius = 3,
		Model = { Kind = "plaza" },
	},
	{
		Id = "parque", Name = "Parque", Desc = "Muito verde e felicidade.",
		Category = "leisure", Tier = 2, Cost = 1200, W = 2, D = 2, Leisure = 10, LeisureRadius = 5,
		Model = { Kind = "park" },
	},
	{
		Id = "estadio", Name = "Estádio", Desc = "Domingo de clássico. Felicidade enorme.",
		Category = "leisure", Tier = 4, Cost = 70000, W = 3, D = 3, Jobs = 20, Power = 20, Leisure = 20, LeisureRadius = 12,
		Model = { Kind = "stadium", Color = { 220, 220, 225 } },
	},
	{
		Id = "torretv", Name = "Torre de TV", Desc = "Cartão-postal. Felicidade em toda a cidade.",
		Category = "leisure", Tier = 5, Cost = 600000, W = 2, D = 2, Jobs = 30, Power = 40, Leisure = 25, LeisureRadius = 24,
		Model = { Kind = "spire", Height = 160, Color = { 220, 60, 60 } },
	},

	-- ===== Energia =====
	{
		Id = "gerador", Name = "Gerador a Diesel", Desc = "Energia barata, mas polui.",
		Category = "power", Tier = 1, Cost = 300, W = 1, D = 1, PowerSupply = 20,
		Pollution = 5, PollutionRadius = 3,
		Model = { Kind = "generator", Color = { 230, 190, 40 } },
	},
	{
		Id = "solar", Name = "Usina Solar", Desc = "Energia limpa.",
		Category = "power", Tier = 2, Cost = 2500, W = 2, D = 2, PowerSupply = 60,
		Model = { Kind = "solar" },
	},
	{
		Id = "eolica", Name = "Usina Eólica", Desc = "Muita energia limpa.",
		Category = "power", Tier = 3, Cost = 15000, W = 2, D = 2, PowerSupply = 250,
		Model = { Kind = "wind" },
	},
	{
		Id = "termica", Name = "Usina Térmica", Desc = "Energia de sobra, poluição de sobra.",
		Category = "power", Tier = 4, Cost = 120000, W = 3, D = 3, PowerSupply = 1200, Jobs = 40,
		Pollution = 20, PollutionRadius = 8,
		Model = { Kind = "plant", Color = { 160, 160, 165 } },
	},
}

Buildings.List = list
Buildings.ById = {} :: { [string]: Building }
for index, def in list do
	(def :: any).Order = index
	Buildings.ById[def.Id] = def
end

function Buildings.Get(id: string): Building?
	return Buildings.ById[id]
end

-- Tamanho na grade depois de girar (rot 0..3; 1 e 3 trocam largura e profundidade)
function Buildings.Footprint(def: Building, rot: number): (number, number)
	if rot % 2 == 1 then
		return def.D, def.W
	end
	return def.W, def.D
end

return Buildings
