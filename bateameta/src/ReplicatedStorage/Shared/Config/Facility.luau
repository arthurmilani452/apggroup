-- Config.Facility: gerador puro (FacilityCore) — grade, árvore, laços, zonas, validação.   dono: facility-core
-- (os números de CONSTRUÇÃO — peças por frame, materiais, luzes — ficam em Config.Build)
return {
	CellSize = 24, -- studs
	WallHeight = 12, -- altura do teto
	WallThickness = 1,
	DoorWidth = 8, -- vão de porta
	DoorHeight = 9,
	ClearLaneWidth = 6, -- faixa livre do centro até cada porta (nenhum prop entra)

	-- Número de células: 18 + 5 × jogadores + 2 × contrato (máximo 60). Solo no contrato 1 = 25.
	BaseCells = 18,
	CellsPerPlayer = 5,
	CellsPerContract = 2,
	MaxCells = 60,

	-- Laços extras depois da árvore geradora (rotas de fuga)
	LoopFractionMin = 0.10,
	LoopFractionMax = 0.15,

	Zones = 4, -- 4 faixas de profundidade (Z1 perto do elevador ... Z4 a mais funda)
	ElevatorMaxDoors = 2, -- o poço do elevador tem no máximo 2 saídas

	-- Pontos de interesse
	MonsterSpawnMinZone = 3,
	MonsterSpawnMinDepth = 5, -- no mínimo 5 células do elevador
	BreakerZones = { 2, 3 },
	ScrapZoneWeight = { 1.0, 1.4, 1.9, 2.5 }, -- sucata pesa mais nas zonas fundas
	LightsPerCellDefault = 1,

	-- Passe de desgaste (com seed)
	Wear = {
		MissingCeilingTileChance = 0.15,
		BrokenLightChance = 0.10,
		DirtPerCell = { 0, 2 },
		PuddleChance = 0.20,
		TippedBoxChance = 0.25,
		PapersChance = 0.40,
	},

	-- Validação e autoteste
	MaxParts = 4000, -- estimativa de peças da instalação
	PartEstimate = { -- usado pela estimativa do núcleo (a construção real conta de verdade)
		Wall = 1,
		WallWithDoor = 3,
		FloorCeilingRects = 20, -- pisos e tetos fundidos em retângulos (total)
		Light = 2,
		PropAverage = 6,
		Scrap = 3,
		ExitSign = 1,
		ElevatorCell = 40,
		Breaker = 5,
		WearPerCell = 3,
	},
	SelfCheck = {
		StartupSeeds = 50, -- seeds testadas só no núcleo quando o servidor liga
		Retries = 5, -- seed+1 até 5 vezes
	},
	KnownGoodSeeds = { 1337, 2024, 4242, 777, 90210, 31337, 8080, 5150 }, -- reserva (o SelfCheck confere)
}
