-- Config.Scrap: os 16 tipos de sucata, multiplicadores, bolsos, venda.   dono: scrap-kit
-- Nome na tela: chave "SCRAP_NAME_<Id>" (Strings/Scrap.luau). Visual: Shared/ScrapModels.
-- Weight = peso no sorteio (comum 10, normal 6, incomum 3, raro 1). Room = sala preferida (peso x3 lá).
return {
	Types = {
		{ Id = "cone", Heavy = false, Min = 8, Max = 14, MinZone = 1, Weight = 10 },
		{ Id = "whoopee", Heavy = false, Min = 10, Max = 16, MinZone = 1, Weight = 10 },
		{ Id = "mug", Heavy = false, Min = 12, Max = 20, MinZone = 1, Weight = 10 },
		{ Id = "extinguisher", Heavy = false, Min = 16, Max = 26, MinZone = 1, Weight = 6 },
		{ Id = "bell", Heavy = false, Min = 18, Max = 28, MinZone = 1, Weight = 6 },
		{ Id = "mannequin_head", Heavy = false, Min = 22, Max = 34, MinZone = 2, Weight = 6 },
		{ Id = "server_blade", Heavy = false, Min = 24, Max = 38, MinZone = 2, Weight = 6, Room = "server" },
		{ Id = "trophy", Heavy = false, Min = 30, Max = 48, MinZone = 2, Weight = 3 },
		{ Id = "office_chair", Heavy = true, Min = 28, Max = 42, MinZone = 1, Weight = 6 },
		{ Id = "microwave", Heavy = true, Min = 34, Max = 50, MinZone = 2, Weight = 5, Room = "breakroom" },
		{ Id = "rubber_duck", Heavy = true, Min = 35, Max = 55, MinZone = 2, Weight = 4 },
		{ Id = "crt_tv", Heavy = true, Min = 42, Max = 62, MinZone = 2, Weight = 4 },
		{ Id = "coffee_machine", Heavy = true, Min = 48, Max = 72, MinZone = 3, Weight = 3, Room = "breakroom" },
		{ Id = "cash_register", Heavy = true, Min = 60, Max = 90, MinZone = 3, Weight = 3 },
		{ Id = "small_safe", Heavy = true, Min = 85, Max = 125, MinZone = 4, Weight = 1 },
		-- Privada de Ouro: fora do sorteio normal; 25% de chance por mapa, no máximo 1, só na Z4
		{ Id = "gold_toilet", Heavy = true, Min = 160, Max = 240, MinZone = 4, Weight = 0, MapChance = 0.25, MaxPerMap = 1 },
	},

	ZoneMult = { 1.0, 1.2, 1.45, 1.75 },
	ContractMultPerLevel = 0.08, -- 1 + 0,08 × (c − 1)

	Shiny = { Chance = 0.03, Mult = 2.5 }, -- "Edição Brilhante": material Foil, entrada separada no Catálogo

	-- Orçamento de valor = parcela da meta do turno × max(Min, Base − PerContract × (c − 1))
	Budget = { Base = 2.4, PerContract = 0.1, Min = 1.6 },

	-- Bolsos e peso
	Pockets = 4,
	PocketsUpgraded = 5, -- upgrade "Bolso +1"
	PocketSpeedPenalty = 0.02, -- cada item pequeno tira 2%
	PocketSpeedPenaltyMax = 0.10,
	HeavySpeedMult = 0.75, -- pesado: x0,75, sem pá, lanterna de mão desligada
	HeavyHoldOffset = CFrame.new(0, 0, -2.2), -- em relação ao HumanoidRootPart (solda do servidor)

	PickupRange = 10, -- studs (ProximityPrompt e checagem do servidor)
	PromptHoldSmall = 0,
	PromptHoldHeavy = 0.4,

	-- Crachá (badge) do jogador nocauteado: ocupa 1 bolso, peso 0
	Badge = {
		TypeId = "badge",
		Color = Color3.fromRGB(0, 255, 255),
		Size = Vector3.new(1.2, 1.6, 0.2),
		PocketSlots = 1,
		SpeedPenalty = 0,
	},

	-- Venda
	SellNoise = 35,
	SellOnlyInElevator = true,
}
