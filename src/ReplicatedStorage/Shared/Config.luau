--[[
	CONFIG - Aqui você ajusta o jogo inteiro sem mexer no resto do código.
	(ModuleScript em ReplicatedStorage > Shared > Config)

	Dicas:
	  • Mudou um número? Aperte Play (F5) no Studio pra testar.
	  • IDs de Game Pass e Dev Product: já criados no Creator Hub (v20). Item novo = criar lá e colar o ID aqui.
	    Quando criar, cole o número do ID aqui e o botão aparece na loja sozinho.
	  • Os bichinhos (preço, renda, cores) ficam no módulo "Critters".
]]

local Config = {}

Config.GameName = "Steal a Critter"
Config.DataStoreName = "StealACritter_Data_v1" -- NÃO mude depois de lançar (apaga o progresso de todo mundo)

-- ECONOMIA INICIAL
Config.StartCash = 250

-- VAGAS DA BASE (v20: a base ficou mais funda: 24 pedestais no térreo + 18 no 2º ANDAR = 42)
--   8 no começo + até 16 compradas com dinheiro + até 18 por rebirth (+1 cada) = 42 de graça
--   a vaga 25 faz o 2º andar aparecer (com rampa); ver tools/economy_sim.py
--   o Game Pass "+4 Slots" só adianta: dá 4 na hora (o máximo continua 42)
Config.StartSlots = 8
Config.SlotUpgradeCosts = { -- +1 vaga cada, comprando com dinheiro do jogo
	5_000, 75_000, 1_500_000, 25_000_000, -- 3 fileiras do térreo
	5e9, 50e9, 500e9, 5e12, 50e12, 500e12, -- 4ª fileira e começo do 2º andar (5B ... 500T)
	5e15, 50e15, 500e15, 5e18, 50e18, 500e18, -- resto do 2º andar (5Qa ... 500Qi)
}
Config.MaxRebirthSlotBonus = 18
Config.PassSlots = 4
Config.FloorSlots = 24 -- pedestais do térreo; da vaga 25 em diante é o 2º andar
Config.MaxSlots = 42

-- ESTEIRA (conveyor)
Config.ConveyorSpawnInterval = 2.2 -- segundos entre cada ovo novo
Config.ConveyorSpeed = 9 -- velocidade dos ovos na esteira
Config.CritterWalkSpeed = 22 -- velocidade do ovo/bichinho indo até a sua base

-- MUNDOS: o Meadow Valley é o mundo das bases. Os outros são ilhas com esteira, ovos e bichinhos próprios.
--   Para destravar: ter o número de Rebirths E pagar o Cash (uma vez só; fica para sempre, até depois do rebirth).
--   Sky = hora do dia e cor da tela quando você está naquele mundo.
Config.Worlds = {
	{ Id = "meadow", Name = "Meadow Valley", Rebirths = 0, Cash = 0, Color = Color3.fromRGB(120, 220, 110),
		Description = "Home of the bases. Steal and protect!", Sky = { ClockTime = 14, Tint = Color3.fromRGB(255, 255, 255) } },
	{ Id = "candy", Name = "Candy Kingdom", Rebirths = 0, Cash = 50_000_000, Color = Color3.fromRGB(255, 130, 200),
		Description = "Sweet eggs and sugary critters!", Sky = { ClockTime = 15.5, Tint = Color3.fromRGB(255, 232, 245) } },
	{ Id = "frost", Name = "Frost Peaks", Rebirths = 1, Cash = 2_500_000_000, Color = Color3.fromRGB(150, 215, 255),
		Description = "Icy critters from the frozen mountains.", Sky = { ClockTime = 12, Tint = Color3.fromRGB(225, 240, 255) } },
	{ Id = "lava", Name = "Lava Land", Rebirths = 2, Cash = 50_000_000_000, Color = Color3.fromRGB(255, 110, 40),
		Description = "Hot critters born in the volcano.", Sky = { ClockTime = 18.3, Tint = Color3.fromRGB(255, 222, 205) } },
	{ Id = "reef", Name = "Coral Reef", Rebirths = 3, Cash = 800_000_000_000, Color = Color3.fromRGB(80, 220, 220),
		Description = "Shiny critters from under the sea.", Sky = { ClockTime = 13, Tint = Color3.fromRGB(210, 240, 255) } },
	{ Id = "galaxy", Name = "Galaxy Station", Rebirths = 5, Cash = 15_000_000_000_000, Color = Color3.fromRGB(170, 110, 255),
		Description = "The rarest critters in the universe.", Sky = { ClockTime = 0, Tint = Color3.fromRGB(225, 215, 255) } },
}
Config.WorldTravelCooldown = 2 -- segundos entre viagens

-- OVOS: a esteira traz ovos; a raridade do bichinho só aparece ao chocar.
--   Weight = chance de aparecer na esteira do mundo dele; HatchTime = segundos para chocar
--   Odds = chance de cada raridade (soma 100). World = em qual mundo aparece (sem World = Meadow).
--   Announce = avisa o servidor inteiro quando aparece/é comprado. Adicione ovos novos copiando uma linha.
Config.Eggs = {
	{ Id = "grass", Name = "Grass Egg", Price = 200, Weight = 55, HatchTime = 5, Style = "grass", Size = 2.6, Color = Color3.fromRGB(140, 215, 110), Accent = Color3.fromRGB(80, 160, 60),
		Odds = { Common = 86, Uncommon = 13, Rare = 1 } },
	{ Id = "spotted", Name = "Spotted Egg", Price = 20_000, Weight = 27, HatchTime = 15, Style = "spotted", Size = 2.9, Color = Color3.fromRGB(255, 235, 200), Accent = Color3.fromRGB(90, 170, 255),
		Odds = { Common = 30, Uncommon = 45, Rare = 20, Epic = 5 } },
	{ Id = "crystal", Name = "Crystal Egg", Price = 1_500_000, Weight = 12, HatchTime = 30, Style = "crystal", Size = 3.2, Color = Color3.fromRGB(150, 225, 255), Accent = Color3.fromRGB(200, 120, 255),
		Odds = { Uncommon = 15, Rare = 50, Epic = 30, Legendary = 5 } },
	{ Id = "royal", Name = "Royal Egg", Price = 30_000_000, Weight = 5, HatchTime = 60, Style = "royal", Size = 3.5, Color = Color3.fromRGB(255, 200, 60), Accent = Color3.fromRGB(230, 40, 80),
		Odds = { Rare = 15, Epic = 50, Legendary = 31, Mythic = 4 }, Announce = true },
	{ Id = "cosmic", Name = "Cosmic Egg", Price = 400_000_000, Weight = 1, HatchTime = 120, Style = "cosmic", Size = 3.8, Color = Color3.fromRGB(60, 25, 120), Accent = Color3.fromRGB(120, 230, 255),
		Odds = { Epic = 25, Legendary = 50, Mythic = 23, Secret = 2 }, Announce = true },

	-- Ovos dos mundos: um "normal" (Tier 3) e um "deluxe" (Tier 4) em cada mundo
	{ Id = "gumdrop", World = "candy", Tier = 3, Name = "Gumdrop Egg", Price = 75_000_000, Weight = 70, HatchTime = 40, Style = "spotted", Size = 3.2, Color = Color3.fromRGB(255, 160, 210), Accent = Color3.fromRGB(110, 220, 255),
		Odds = { Uncommon = 50, Rare = 35, Epic = 13, Legendary = 2 } },
	{ Id = "lollipop", World = "candy", Tier = 4, Name = "Lollipop Egg", Price = 300_000_000, Weight = 30, HatchTime = 90, Style = "royal", Size = 3.6, Color = Color3.fromRGB(255, 90, 170), Accent = Color3.fromRGB(255, 240, 120),
		Odds = { Rare = 30, Epic = 44.5, Legendary = 20, Mythic = 5, Secret = 0.5 } },
	{ Id = "snowball", World = "frost", Tier = 3, Name = "Snowball Egg", Price = 1_250_000_000, Weight = 70, HatchTime = 50, Style = "crystal", Size = 3.2, Color = Color3.fromRGB(225, 242, 255), Accent = Color3.fromRGB(120, 190, 255),
		Odds = { Uncommon = 50, Rare = 35, Epic = 13, Legendary = 2 } },
	{ Id = "glacier", World = "frost", Tier = 4, Name = "Glacier Egg", Price = 5_000_000_000, Weight = 30, HatchTime = 105, Style = "cosmic", Size = 3.6, Color = Color3.fromRGB(130, 200, 255), Accent = Color3.fromRGB(255, 255, 255),
		Odds = { Rare = 30, Epic = 44.5, Legendary = 20, Mythic = 5, Secret = 0.5 } },
	{ Id = "ember", World = "lava", Tier = 3, Name = "Ember Egg", Price = 12_500_000_000, Weight = 70, HatchTime = 60, Style = "spotted", Size = 3.2, Color = Color3.fromRGB(90, 35, 25), Accent = Color3.fromRGB(255, 130, 40),
		Odds = { Uncommon = 50, Rare = 35, Epic = 13, Legendary = 2 } },
	{ Id = "magma", World = "lava", Tier = 4, Name = "Magma Egg", Price = 50_000_000_000, Weight = 30, HatchTime = 120, Style = "royal", Size = 3.6, Color = Color3.fromRGB(255, 110, 30), Accent = Color3.fromRGB(255, 230, 80),
		Odds = { Rare = 30, Epic = 44.5, Legendary = 20, Mythic = 5, Secret = 0.5 } },
	{ Id = "pearl", World = "reef", Tier = 3, Name = "Pearl Egg", Price = 112_500_000_000, Weight = 70, HatchTime = 70, Style = "crystal", Size = 3.2, Color = Color3.fromRGB(250, 245, 238), Accent = Color3.fromRGB(255, 170, 205),
		Odds = { Uncommon = 50, Rare = 35, Epic = 13, Legendary = 2 } },
	{ Id = "coral", World = "reef", Tier = 4, Name = "Coral Egg", Price = 425_000_000_000, Weight = 30, HatchTime = 135, Style = "royal", Size = 3.6, Color = Color3.fromRGB(255, 120, 110), Accent = Color3.fromRGB(90, 225, 230),
		Odds = { Rare = 30, Epic = 44.5, Legendary = 20, Mythic = 5, Secret = 0.5 } },
	{ Id = "nebula", World = "galaxy", Tier = 3, Name = "Nebula Egg", Price = 1_000_000_000_000, Weight = 70, HatchTime = 80, Style = "cosmic", Size = 3.2, Color = Color3.fromRGB(95, 45, 175), Accent = Color3.fromRGB(255, 120, 230),
		Odds = { Uncommon = 50, Rare = 35, Epic = 13, Legendary = 2 } },
	{ Id = "supernova", World = "galaxy", Tier = 4, Name = "Supernova Egg", Price = 3_750_000_000_000, Weight = 30, HatchTime = 150, Style = "cosmic", Size = 3.7, Color = Color3.fromRGB(25, 12, 45), Accent = Color3.fromRGB(255, 220, 90),
		Odds = { Rare = 30, Epic = 44.5, Legendary = 20, Mythic = 5, Secret = 0.5 } },

	-- OVOS DE CLIMA E DA NOITE (v9): só aparecem na esteira do Meadow nesse clima e só chocam nele
	--   Condition = "Rain", "Snow" ou "Night"; Pool = de onde saem os bichinhos (Critters com World = Pool)
	{ Id = "storm", Name = "Storm Egg", Condition = "Rain", Pool = "storm", Price = 750_000, Weight = 8, HatchTime = 45, Style = "crystal", Size = 3.3, Color = Color3.fromRGB(90, 110, 170), Accent = Color3.fromRGB(255, 230, 80),
		Odds = { Rare = 60, Epic = 32, Legendary = 8 } },
	{ Id = "snowy", Name = "Snowflake Egg", Condition = "Snow", Pool = "snow", Price = 750_000, Weight = 8, HatchTime = 45, Style = "crystal", Size = 3.3, Color = Color3.fromRGB(235, 245, 255), Accent = Color3.fromRGB(130, 200, 255),
		Odds = { Rare = 60, Epic = 32, Legendary = 8 } },
	{ Id = "moon", Name = "Moon Egg", Condition = "Night", Pool = "night", Price = 1_500_000, Weight = 8, HatchTime = 60, Style = "cosmic", Size = 3.4, Color = Color3.fromRGB(40, 35, 90), Accent = Color3.fromRGB(255, 240, 170),
		Odds = { Rare = 50, Epic = 38, Legendary = 12 } },

	-- OVOS DE FESTA (v11): Holiday = qual festa; só aparecem na esteira do Meadow na época dela (Config.Holidays)
	{ Id = "pumpkinegg", Name = "Pumpkin Egg", Holiday = "halloween", Pool = "halloween", Price = 1_500_000, Weight = 10, HatchTime = 50, Style = "spotted", Size = 3.4, Color = Color3.fromRGB(255, 140, 40), Accent = Color3.fromRGB(60, 40, 60),
		Odds = { Epic = 80, Legendary = 20 } },
	{ Id = "giftegg", Name = "Gift Egg", Holiday = "winter", Pool = "winter", Price = 1_500_000, Weight = 10, HatchTime = 50, Style = "royal", Size = 3.4, Color = Color3.fromRGB(220, 50, 60), Accent = Color3.fromRGB(80, 200, 110),
		Odds = { Epic = 80, Legendary = 20 } },
	{ Id = "heartegg", Name = "Heart Egg", Holiday = "valentine", Pool = "valentine", Price = 1_500_000, Weight = 10, HatchTime = 50, Style = "crystal", Size = 3.4, Color = Color3.fromRGB(255, 130, 170), Accent = Color3.fromRGB(255, 60, 110),
		Odds = { Epic = 80, Legendary = 20 } },
	{ Id = "beachegg", Name = "Beach Egg", Holiday = "summer", Pool = "summer", Price = 1_500_000, Weight = 10, HatchTime = 50, Style = "spotted", Size = 3.4, Color = Color3.fromRGB(255, 225, 120), Accent = Color3.fromRGB(60, 190, 230),
		Odds = { Epic = 80, Legendary = 20 } },

	-- OVO DA SEMANA (v26): aparece na esteira do Meadow a semana inteira; choca SÓ o Critter da Semana (Shared > Weekly)
	{ Id = "weeklyegg", Name = "Weekly Egg", Condition = "Weekly", Pool = "weekly", Price = 150_000, Weight = 6, HatchTime = 45, Style = "royal", Size = 3.5, Color = Color3.fromRGB(255, 215, 90), Accent = Color3.fromRGB(255, 255, 255),
		Odds = { Epic = 100 }, Announce = true },

	-- OVOS DE EXPLORAÇÃO (v13): nunca aparecem na esteira (Weight = 0); Where = onde conseguir
	{ Id = "islandegg", Name = "Island Egg", Pool = "island", Where = "the Secret Island shrine", Price = 3_000_000, Weight = 0, Tier = 3, HatchTime = 50, Style = "spotted", Size = 3.4, Color = Color3.fromRGB(90, 200, 150), Accent = Color3.fromRGB(255, 220, 90),
		Odds = { Epic = 75, Legendary = 25 } },
	{ Id = "fossilegg", Name = "Fossil Egg", Pool = "fossil", Where = "digging (free!)", Price = 0, Weight = 0, Tier = 3, HatchTime = 60, Style = "spotted", Size = 3.3, Color = Color3.fromRGB(200, 180, 140), Accent = Color3.fromRGB(120, 90, 60),
		Odds = { Epic = 85, Legendary = 15 } },
	{ Id = "deepegg", Name = "Deep Sea Egg", Pool = "deep", Where = "the submarine in Coral Reef", Price = 4_000_000, Weight = 0, Tier = 3, HatchTime = 55, Style = "crystal", Size = 3.4, Color = Color3.fromRGB(30, 60, 140), Accent = Color3.fromRGB(120, 230, 255),
		Odds = { Epic = 75, Legendary = 25 } },
}
Config.HatchRevealTime = 2.6 -- segundos de suspense antes do bichinho aparecer
Config.LuckyEggMultiplier = 2 -- no Evento da Sorte, ovos Crystal ou melhores aparecem 2x mais (v23: era 3x)
Config.RainEggWeights = { grass = 62, spotted = 30, crystal = 7, royal = 1 } -- ovos da Chuva de Ovos (grátis, só no Meadow)

-- ESTEIRA DE TREINO (na sua base): fique em cima para ganhar velocidade de graça
Config.TreadmillSeconds = 40 -- +1 de velocidade a cada 40 s em cima da esteira (v23: era 15 s)
Config.TreadmillBaseCap = 6 -- máximo de velocidade treinada... (v23: era 10)
Config.TreadmillCapPerRebirth = 3 -- ...que sobe +3 a cada rebirth (v23: era 5)
Config.TreadmillPush = 10 -- força que a esteira empurra (dá a sensação de correr)

-- CÓDIGOS PROMOCIONAIS: a lista fica em ServerScriptService > Game > Codes (só o servidor enxerga,
-- assim ninguém descobre todos os códigos lendo os arquivos do jogo).
-- Ovos de presente dos códigos: { ovo normal, ovo grande } do mundo mais novo que o jogador destravou
Config.GiftEggs = {
	meadow = { "spotted", "crystal" },
	candy = { "gumdrop", "lollipop" },
	frost = { "snowball", "glacier" },
	lava = { "ember", "magma" },
	reef = { "pearl", "coral" },
	galaxy = { "nebula", "supernova" },
}
Config.BoostMaxMinutes = 180 -- "2x Cash" dos códigos soma tempo até no máximo 3 horas

-- MOCHILA E PETS (Parte 14)
--   Mochila: bichinhos guardados (não rendem dinheiro, mas ninguém rouba). Pets equipados seguem você
--   e dão +% de dinheiro. Fusão: 5 iguais = 1 Gold; 5 Gold iguais = 1 Rainbow.
Config.InventoryMax = 60
Config.PetEquipMax = 3
Config.PetBonus = { Common = 0.005, Uncommon = 0.01, Rare = 0.015, Epic = 0.025, Legendary = 0.035, Mythic = 0.05, Secret = 0.075 }
Config.PetMutationBonus = { Gold = 2, Diamond = 3, Rainbow = 4 } -- multiplica o bônus do pet
Config.PetBonusCap = 0.15 -- no máximo +15% somando os pets equipados (mais que isso adiantava o jogo em quase 1 semana)
Config.FuseCount = 5
Config.StolenLockSeconds = 60 -- bichinho recém-roubado não pode ir para a mochila nem para a fusão (dá tempo de roubar de volta)
Config.FuseInto = { [""] = "Gold", Gold = "Rainbow" } -- "" = sem mutação

-- PREMIUM (Parte 15): assinantes do Roblox Premium ganham +10% de dinheiro (0 = desligado)
Config.PremiumBonus = 0.10

-- MUTAÇÕES (chance em %; Income = multiplica o dinheiro; Price = multiplica o preço na esteira)
Config.Mutations = {
	{ Name = "Gold", Chance = 6, Income = 2, Price = 1.5, Color = Color3.fromRGB(255, 205, 60) },
	{ Name = "Diamond", Chance = 2, Income = 4, Price = 2.5, Color = Color3.fromRGB(150, 235, 255) },
	{ Name = "Rainbow", Chance = 0.5, Income = 10, Price = 5, Color = Color3.fromRGB(255, 120, 220) },
}

-- ROUBO
Config.StealHoldDuration = 1.5 -- segundos segurando a tecla pra roubar
Config.CarrySpeedMultiplier = 0.8 -- quem carrega um bichinho roubado fica 20% mais lento
Config.CarryScale = 0.55 -- tamanho do bichinho nas costas
Config.SellRefund = 0.5 -- vender um OVO devolve 50% do preço
Config.CritterSellRefund = 0.3 -- vender um BICHINHO devolve 30% do valor dele (evita lucro comprando e vendendo)
Config.IntruderAlarmCooldown = 8 -- segundos entre alarmes do mesmo invasor

-- JOGADORES NOVOS (justiça)
Config.NewbieShieldSeconds = 10 * 60 -- base de quem tem menos de 10 min de jogo não pode ser roubada
Config.RevengeSeconds = 30 -- quem é roubado ganha velocidade extra por 30 s...
Config.RevengeSpeedBonus = 10 -- ...de +10
Config.UnderdogEnter = 0.10 -- quem ganha menos de 10% do melhor jogador do servidor vira "azarão"...
Config.UnderdogExit = 0.15 -- ...e deixa de ser quando passa de 15%
Config.UnderdogBonus = 0.25 -- azarão ganha +25% de dinheiro
Config.BullyIncomeRatio = 20 -- quem ganha 20x mais que outro jogador não pode roubar dele
Config.StarterEgg = "spotted" -- ovo grátis ao terminar o tutorial

-- TRAVA DA BASE (laser)
Config.LockDuration = 45
Config.LockDurationPass = 90 -- com o Game Pass "LongLock"
Config.LockCooldown = 30 -- recarga depois que a trava acaba

-- VELOCIDADE (loja)
Config.BaseWalkSpeed = 16
Config.SpeedPerLevel = 2
Config.MaxSpeedLevel = 20
Config.SpeedBaseCost = 1_000 -- v23: era 150 (velocidade estava fácil demais)
Config.SpeedCostGrowth = 2 -- v23: era 1.65 (nível 20 custa ~500M)
Config.SpeedCoilBonus = 8 -- Game Pass "SpeedCoil"

-- REBIRTH (zera só o dinheiro; os bichinhos ficam)
Config.RebirthBaseCost = 100_000_000 -- v23: era 30M
Config.RebirthCostGrowth = 10 -- cada rebirth custa 10x o anterior (economia v6: ver tools/economy_sim.py)
Config.RebirthIncomeBonus = 0.5 -- +50% de dinheiro por rebirth

-- BÔNUS
Config.IndexBonusPerCritter = 0.01 -- +1% de dinheiro para cada bichinho descoberto no Índice (v23: era 2%)
Config.FriendBonus = 0.10 -- +10% por amigo no mesmo servidor
Config.MaxFriendBonus = 0.50
Config.GroupId = 869887016 -- grupo "Critter Club Studios" (0 = desligado): membros ganham +10% de dinheiro
Config.GroupBonus = 0.10
Config.VipIncomeBonus = 0.20 -- VIP ganha +20%

-- DINHEIRO OFFLINE (quando o jogador volta)
Config.OfflineRate = 0.06 -- ganha 6% da renda enquanto estava fora (v23: era 10%)
Config.OfflineMaxSeconds = 3 * 60 * 60 -- no máximo 3 horas

-- RECOMPENSA DIÁRIA (dia 1 até dia 7, depois repete). VIP ganha em dobro.
Config.DailyRewards = { 100, 250, 500, 1_000, 2_500, 5_000, 10_000 }
-- ...ou alguns minutos da sua renda, o que for MAIOR (assim a diária continua valendo a pena no fim do jogo)
Config.DailyIncomeMinutes = { 2, 3, 4, 5, 6, 8, 12 }

-- TUTORIAL
Config.TutorialReward = 250

-- PRESENTES DE TEMPO DE JOGO (v23): quanto mais tempo na sessão, mais presentes (botão na coluna da esquerda).
--   Cash = minutos da SUA renda (mínimo PlaytimeGiftMinCash); Egg = ovo na base; Boost = 2x Cash por X min.
--   Depois do último, um presente de dinheiro a cada PlaytimeGiftRepeat minutos. Zera quando sai do jogo.
Config.PlaytimeGifts = {
	{ Minutes = 3, Cash = 2 },
	{ Minutes = 8, Egg = "spotted" },
	{ Minutes = 15, Boost = 10 },
	{ Minutes = 25, Cash = 8 },
	{ Minutes = 40, Egg = "crystal" },
	{ Minutes = 60, Cash = 12, Boost = 20 },
	{ Minutes = 90, Egg = "royal" },
}
Config.PlaytimeGiftRepeat = 30
Config.PlaytimeGiftMinCash = 500

-- ROLETA DIÁRIA (v23): 1 giro GRÁTIS por dia (nunca custa Robux, então pode ser aleatória).
--   Weight = chance (a tela mostra a % de cada prêmio); Cash = minutos da renda (mínimo DailySpinMinCash)
Config.DailySpin = {
	{ Name = "Cash", Weight = 30, Cash = 3, Color = Color3.fromRGB(80, 200, 100) },
	{ Name = "Cash+", Weight = 20, Cash = 8, Color = Color3.fromRGB(60, 180, 90) },
	{ Name = "2x Cash 15m", Weight = 15, Boost = 15, Color = Color3.fromRGB(255, 170, 50) },
	{ Name = "Spotted Egg", Weight = 15, Egg = "spotted", Color = Color3.fromRGB(90, 170, 255) },
	{ Name = "Crystal Egg", Weight = 8, Egg = "crystal", Color = Color3.fromRGB(150, 225, 255) },
	{ Name = "BIG Cash", Weight = 7, Cash = 20, Color = Color3.fromRGB(255, 215, 60) },
	{ Name = "Royal Egg", Weight = 4, Egg = "royal", Color = Color3.fromRGB(230, 40, 80) },
	{ Name = "JACKPOT Cosmic Egg", Weight = 1, Egg = "cosmic", Color = Color3.fromRGB(120, 60, 220) },
}
Config.DailySpinMinCash = 1_000

-- EVENTOS (a cada 15 min; a sorte acontece no meio do caminho entre duas chuvas)
Config.EventEvery = 15 * 60
Config.RainDuration = 45 -- segundos de chuva
Config.RainCount = 8 -- ovos grátis que caem do céu (v23: eram 14)
Config.RainLifetime = 25 -- segundos que cada um fica no chão
Config.LuckyEventDuration = 3 * 60
Config.LuckyMultiplier = 2 -- raros 2x mais comuns (v23: era 3x)
Config.LuckyMutationMultiplier = 2 -- mutações 2x mais comuns

-- BRINCADEIRAS DOS MUNDOS (v27): baú no fim de cada uma (ServerScriptService > Game > WorldFun)
Config.WorldFun = {
	PrizeCooldown = 30 * 60, -- cada baú volta depois de 30 min (por jogador, salvo no perfil)
	PrizeCashMinutes = 2, -- prêmio: 2 minutos da renda do jogador (sem virar dinheiro fácil)...
	PrizeMinCash = 500, -- ...no mínimo $500
	PrizeEggChance = 0.35, -- ...e 35% de chance de um ovo (o mais barato daquele mundo)
	SnowballCooldown = 0.7, -- segundos entre uma bola de neve e outra
	SnowballSpeed = 95,
}

-- BANDIT (v24): ladrão NPC para servidor vazio (ServerScriptService > Game > Bandits).
--   Só aparece com até MaxPlayers jogadores no servidor. Vai até a base do jogador e fica StealSeconds
--   "roubando" o dinheiro do COLETOR (nunca bichinhos). BONK nele = prêmio; não deu = leva parte do coletor.
Config.Bandits = {
	Enabled = false, -- v26: DESLIGADO a pedido do Arthur (as crianças podem não gostar de perder dinheiro). true = volta a aparecer.
	MaxPlayers = 2, -- com 3+ jogadores os ladrões de verdade já dão trabalho
	FirstAfter = 150, -- segundos depois de entrar (o tutorial tem que estar pronto)
	Every = { 150, 300 }, -- intervalo aleatório entre uma visita e outra (por jogador)
	StealSeconds = 12, -- tempo parado no coletor antes de fugir (tempo para o dono chegar)
	Hits = 2, -- pancadas de taco para derrubar
	VaultShare = 0.25, -- leva 25% do dinheiro que estava no coletor...
	VaultMaxMinutes = 2, -- ...no máximo 2 minutos da renda do jogador
	RewardMinutes = 1, -- derrubou: ganha 1 minuto da renda (mínimo RewardMinCash)...
	RewardMinCash = 250,
	EggChance = 0.2, -- ...e 20% de chance de ganhar um ovo
	CarryChance = 0.35, -- v25: 35% das visitas ele chega com um critter roubado nas costas (bonk = vira seu)
	EggId = "spotted",
	WalkSpeed = 11,
}

-- TACO (Bonk Bat) - empurrão de desenho, sem dano
Config.SlapCooldown = 1
Config.SlapRange = 8
Config.SlapForce = 70

-- LEADERBOARDS
Config.LeaderboardRefresh = 60
Config.LeaderboardSize = 10

-- GAME PASSES: cole o ID de cada pass (número). 0 = escondido na loja.
Config.GamePasses = { -- criados no Creator Hub em 28/09/2026 (v20)
	DoubleCash = 2001800303, -- 399 Robux
	MoreSlots = 2002424273, -- 199
	VIP = 2002610263, -- 349
	SpeedCoil = 2002316278, -- 149
	LongLock = 1998963357, -- 99
}
Config.GamePassOrder = { "DoubleCash", "MoreSlots", "VIP", "SpeedCoil", "LongLock" }
Config.GamePassInfo = {
	DoubleCash = { Name = "2x Cash", Description = "Double cash from every critter, forever!" },
	MoreSlots = { Name = "+4 Slots", Description = "4 extra pedestals in your base." },
	VIP = { Name = "VIP", Description = "+20% cash, 2x daily reward, VIP tag and chat tag!" },
	SpeedCoil = { Name = "Speed Coil", Description = "+8 walk speed. Steal faster, escape faster!" },
	LongLock = { Name = "Long Lock", Description = "Your base lock lasts twice as long." },
}

-- DEV PRODUCTS (compras que podem repetir). 0 = escondido na loja.
Config.DevProducts = { -- criados no Creator Hub em 28/09/2026 (v20)
	InstantLock = 3715363926, -- 25 Robux
	SeasonPass = 3715364091, -- 299 (Passe da Temporada: vale só para a temporada em que foi comprado)
	CashSmall = 3715364240, -- 49
	CashMedium = 3715364272, -- 199
	CashLarge = 3715364508, -- 599
	-- v20: mais opções (tudo também dá para ganhar de graça jogando)
	CashXL = 3715364676, -- 1299: 10 horas da renda
	StarterPack = 3715364696, -- 99: 1 vez por jogador: dinheiro + Royal Egg + 2x Cash 15 min
	Boost30 = 3715364714, -- 49: 2x Cash por 30 min (grátis: códigos e recompensa diária)
	LuckyPotion = 3715364762, -- 69: Evento da Sorte para o servidor inteiro por 10 min (grátis: a cada 15 min)
	BaseShield = 3715364783, -- 39: ninguém rouba da sua base por 10 min (grátis: escudo de novato e a trava)
	InstantHatch = 3715364797, -- 29: choca todos os seus ovos agora (grátis: esperar)
}
Config.CashPacks = { -- valor mínimo e "minutos da sua renda" (o jogador ganha o MAIOR dos dois)
	CashSmall = { Name = "Cash Pack S", Minimum = 10_000, Minutes = 5 },
	CashMedium = { Name = "Cash Pack M", Minimum = 100_000, Minutes = 30 },
	CashLarge = { Name = "Cash Pack L", Minimum = 1_000_000, Minutes = 120 },
	CashXL = { Name = "Cash Pack XL", Minimum = 10_000_000, Minutes = 600 },
}
Config.CashPackOrder = { "CashSmall", "CashMedium", "CashLarge", "CashXL" }
-- Produtos novos da v20 (nome, texto da loja e o jeito GRÁTIS de ganhar a mesma coisa)
Config.StarterPack = { Cash = 50_000, Egg = "royal", BoostMinutes = 15 }
Config.PaidBoostMinutes = 30
Config.LuckyPotionSeconds = 10 * 60
Config.PaidShieldSeconds = 10 * 60
Config.PaidShieldMaxSeconds = 60 * 60 -- comprando várias vezes, o escudo soma até 1 hora
Config.ProductInfo = {
	StarterPack = { Name = "Starter Pack (1 time)", Description = "$50K + Royal Egg + 2x Cash 15 min!" },
	Boost30 = { Name = "2x Cash Boost", Description = "2x cash for 30 min. Free: codes & daily reward!" },
	LuckyPotion = { Name = "Lucky Potion", Description = "Lucky Event for EVERYONE: 10 min of rare eggs x3!" },
	BaseShield = { Name = "Base Shield", Description = "Nobody can steal from you for 10 min!" },
	InstantHatch = { Name = "Instant Hatch", Description = "All your eggs hatch right now!" },
}
-- Critters vendidos por Robux (o jogador ESCOLHE qual quer; nada aleatório)
Config.CritterProducts = { -- criados no Creator Hub em 28/09/2026 (v20)
	sunwing = 3715364849, -- 149 Robux
	glaciamoth = 3715364863, -- 149
	magmaroo = 3715364882, -- 199
	stormhorn = 3715364909, -- 199
	voidra = 3715364959, -- 399
	prismacorn = 3715364976, -- 399
	krakenox = 3715364995, -- 499
}

-- SONS: troque por sons da Creator Store colando "rbxassetid://NUMERO"
Config.Sounds = { -- v25: sons oficiais da Roblox (Creator Store, criador "Roblox", grátis); antes era tudo o mesmo "ping"
	Coin = { Id = "rbxassetid://127645268874265", Volume = 0.5, Speed = 1.4 }, -- CoinTransfer_01
	Hatch = { Id = "rbxassetid://15675055424", Volume = 0.8, Speed = 1.1 }, -- Roblox_UI_Cute_Pop
	Train = { Id = "rbxassetid://15675032796", Volume = 0.35, Speed = 1.2 }, -- Roblox_UI_Small_Click
	Buy = { Id = "rbxassetid://15675059323", Volume = 0.6, Speed = 1 }, -- Roblox_UI_Bright_Click
	Rare = { Id = "rbxassetid://12222253", Volume = 0.8, Speed = 1.05 }, -- victory.wav
	Alarm = { Id = "rbxassetid://17208361335", Volume = 0.8, Speed = 1.15 }, -- Roblox GUI - Notification High
	Bonk = { Id = "rbxassetid://12222046", Volume = 1, Speed = 0.9 }, -- hit.wav
	Click = { Id = "rbxassetid://15675032796", Volume = 0.4, Speed = 1 }, -- Roblox_UI_Small_Click
	Error = { Id = "rbxassetid://15675075163", Volume = 0.5, Speed = 0.85 }, -- Roblox_UI_Delete
	Swing = { Id = "rbxassetid://15675024286", Volume = 0.6, Speed = 1 }, -- Roblox_UI_Whoosh_01
	Shiny = { Id = "rbxassetid://15675043410", Volume = 0.9, Speed = 1.3 }, -- Roblox_UI_Tonal_Stinger
}

-- ADMINS: coloque o seu UserId aqui (o dono do jogo e o Studio já são admin automaticamente)
Config.Admins = {
	-- [123456789] = true,
}
-- Jogo de GRUPO: coloque aqui o seu UserId para o jogo saber que o "criador" entrou (presente Crowny).
-- Jogo seu (de usuário) já é reconhecido sozinho.
Config.CreatorUserIds = {
	-- [123456789] = true,
}

-- RARIDADES (a ordem importa: da mais comum para a mais rara)
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Weight = 60, Size = 3 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 90), Weight = 25, Size = 3.5 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Weight = 10, Size = 4 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 90, 255), Weight = 3.5, Size = 4.5 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 200, 40), Weight = 1.2, Size = 6 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 110), Weight = 0.28, Size = 7 },
	{ Name = "Secret", Color = Color3.fromRGB(255, 255, 255), Weight = 0.02, Size = 6.8 },
}

Config.RarityByName = {}
Config.RarityIndex = {}
for index, rarity in Config.Rarities do
	Config.RarityByName[rarity.Name] = rarity
	Config.RarityIndex[rarity.Name] = index
end

Config.MutationByName = {}
for _, mutation in Config.Mutations do
	Config.MutationByName[mutation.Name] = mutation
end

Config.WorldById = {}
Config.WorldIndex = {}
for index, world in Config.Worlds do
	Config.WorldById[world.Id] = world
	Config.WorldIndex[world.Id] = index
end

Config.EggById = {}
for index, egg in Config.Eggs do
	egg.Tier = egg.Tier or (if egg.Condition or egg.Holiday then 3 else index)
	egg.World = egg.World or "meadow"
	egg.Pool = egg.Pool or egg.World -- de onde saem os bichinhos
	Config.EggById[egg.Id] = egg
end

-- Ovos de um mundo (na ordem da lista)
function Config.EggsOfWorld(worldId: string)
	local list = {}
	for _, egg in Config.Eggs do
		if egg.World == worldId then
			table.insert(list, egg)
		end
	end
	return list
end

-- CRIATURAS VIVAS (v9)
--   Crescimento: bebê -> adulto -> gigante com o tempo (conta até com o jogador fora do jogo).
--   Income = quanto do dinheiro "cheio" o bichinho rende; Scale = tamanho na base.
Config.Growth = {
	{ Name = "Baby", Age = 0, Income = 0.8, Scale = 0.75 },
	{ Name = "Adult", Age = 10 * 60, Income = 0.9, Scale = 1 },
	{ Name = "Giant", Age = 60 * 60, Income = 1, Scale = 1.3 },
}
Config.GiantMaxSize = 8.4 -- gigante não passa desse tamanho (não encosta no pedestal do lado)
Config.ShinyChance = 1 / 1000 -- chance de sair SHINY (brilhante) ao chocar
Config.ShinyIncome = 1.5 -- shiny rende 50% a mais
Config.PetHappyBonus = 0.10 -- carinho: +10% por 10 minutos (nunca tem castigo)
Config.FeedBonus = 0.15 -- comida: +15% por 10 minutos
Config.CareSeconds = 10 * 60
Config.FeedCostMinutes = 1 -- alimentar todos custa 1 minuto da sua renda (mínimo $100)
-- Dia e noite: um dia inteiro dura 20 minutos (noite de ~5 min). Clima troca a cada 4-6 minutos.
Config.DayLength = 20 * 60
Config.DayFraction = 0.7
Config.WeatherChances = { Sun = 55, Rain = 25, Snow = 20 }
Config.WeatherMinutes = { 4, 6 }
-- Ovo Gigante do servidor (praça atrás das bases)
Config.GiantEgg = {
	BaseGoal = 150, -- toques necessários com 1 jogador...
	GoalPerPlayer = 40, -- ...+40 por jogador no servidor
	MaxGoal = 500,
	MinTaps = 5, -- precisa ajudar pelo menos 5 vezes para ganhar
	Cooldown = 10 * 60, -- tempo até aparecer o próximo (v23: era 5 min)
	Odds = { Rare = 60, Epic = 30, Legendary = 9, Mythic = 0.9, Secret = 0.1 }, -- v23: era 40/35/20/4.5/0.5
}
-- Abas do Índice (os mundos + "Special": clima, noite e híbridos)
Config.SpecialPools = {
	storm = true, snow = true, night = true, hybrid = true,
	halloween = true, winter = true, valentine = true, summer = true, event = true, -- v11
	island = true, fossil = true, deep = true, -- v13
	weekly = true, -- v26: critter da semana
}

-- FESTAS DO CALENDÁRIO (v11): { mês, dia } de início e fim (horário UTC); podem virar o ano
Config.Holidays = {
	{ Id = "halloween", Name = "Halloween", From = { 10, 20 }, To = { 11, 2 }, Color = Color3.fromRGB(255, 140, 40) },
	{ Id = "winter", Name = "Winter Holidays", From = { 12, 15 }, To = { 1, 3 }, Color = Color3.fromRGB(120, 200, 255) },
	{ Id = "valentine", Name = "Valentine's Day", From = { 2, 9 }, To = { 2, 16 }, Color = Color3.fromRGB(255, 120, 170) },
	{ Id = "summer", Name = "Summer Party", From = { 7, 1 }, To = { 7, 31 }, Color = Color3.fromRGB(255, 210, 70) },
}
Config.HolidayById = {}
for _, holiday in Config.Holidays do
	Config.HolidayById[holiday.Id] = holiday
end

-- Qual festa está acontecendo num instante (os.time); nil = nenhuma
function Config.HolidayAt(time: number)
	local date = os.date("!*t", time)
	local today = date.month * 100 + date.day
	for _, holiday in Config.Holidays do
		local from = holiday.From[1] * 100 + holiday.From[2]
		local to = holiday.To[1] * 100 + holiday.To[2]
		local inside = if from <= to then today >= from and today <= to else today >= from or today <= to
		if inside then
			return holiday
		end
	end
	return nil
end

-- EVENTOS AO VIVO (v11)
Config.Invasion = {
	Enabled = false, -- v25: desligada a pedido (os Grumblobs passeando pelo mapa); o botão ADMIN ainda funciona
	Every = 45 * 60, -- a cada 45 minutos
	FirstAfter = 12 * 60, -- a primeira, 12 min depois de o servidor abrir
	Duration = 150, -- os monstros vão embora depois de 2 min e meio
	Base = 3, -- monstros = 3 + 1 por jogador (máximo 12)
	Max = 12,
	Hits = 3, -- pancadas para derrubar um monstro
	RewardMinutes = 2, -- quem ajudou a derrubar ganha 2 min da sua renda (mínimo $400)
}
Config.Merchant = {
	StayMinutes = 15, -- chega no começo de cada hora (UTC) e fica 15 minutos
	Discount = 0.75, -- ovos com 25% de desconto
	Offers = 3,
}
Config.Vote = {
	Every = 20 * 60, -- votação a cada 20 min
	FirstAfter = 6 * 60,
	Duration = 60,
	Options = { "Rain", "Lucky", "GiantEgg", "Night" },
}
Config.VoteNames = { Rain = "Egg Rain", Lucky = "Lucky Event", GiantEgg = "Giant Egg Now", Night = "Night Time" }
-- Meta da comunidade: todos os servidores somam os ovos chocados
Config.GlobalGoals = {
	{ Goal = 25_000, Name = "Globey for everyone!", Critter = "globey" },
	{ Goal = 250_000, Name = "3 FREE eggs for everyone!", BigEgg = 3 },
	{ Goal = 2_000_000, Name = "Unidrake for everyone!", Critter = "unidrake" },
}
Config.RecordRainMin = 4 -- recorde de jogadores no servidor (a partir de 4) = chuva de ovos
Config.InviteRewardsPerDay = 5 -- ovos grátis por amigo novo que entrou pelo seu convite (máximo por dia)
Config.GiftsPerDay = 20 -- presentes que cada jogador pode dar por dia
Config.ClanMax = 10
Config.ClanBonusPerMate = 0.02 -- +2% de dinheiro por colega de clã no mesmo servidor
Config.ClanBonusMax = 0.10

-- MINIGAMES (v12): ilha longe do Meadow. Entrada grátis; prêmios só para quem joga (sem aposta).
--   Dentro do minigame todo mundo tem a MESMA velocidade (nada comprado ajuda).
Config.Minigames = {
	FirstAfter = 90, -- o primeiro é anunciado 90 s depois de o servidor abrir
	Gap = 120, -- tempo entre um minigame e o anúncio do próximo
	Announce = 30, -- "Minigame starting in 30s!"
	Results = 6,
	Speed = 20,
	Rewards = { 3, 2, 1 }, -- 1º, 2º e 3º: minutos da sua renda (mínimo $200 por minuto)
	Participation = 0.5, -- todo mundo que joga até o fim
	TeamWin = 2, -- time vencedor (Polícia e Ladrão / Esconde-esconde)
	TournamentPoints = { 5, 3, 2 }, -- fim de semana (sábado e domingo, UTC): pontos no placar do torneio
	TournamentWinPoints = 3,
	ChampPoints = 20, -- com 20 pontos no fim de semana ganha o título "Weekend Champ"
	Games = {
		{ Id = "Race", Name = "Obby Race", Min = 1, Duration = 90, Weight = 3, Desc = "Race to the finish! Top 3 win prizes." },
		{ Id = "King", Name = "King of the Hill", Min = 2, Duration = 75, Weight = 2, Desc = "Stay on the golden circle on top of the hill!" },
		{ Id = "Battle", Name = "Critter Battle", Min = 1, Duration = 150, Weight = 2, Desc = "Your best critter fights! Pick ATTACK, DEFEND or SPECIAL." },
		{ Id = "Cops", Name = "Cops & Robbers", Min = 3, Duration = 120, Weight = 2, Desc = "Robbers grab coins, cops BONK robbers into jail!" },
		{ Id = "Hide", Name = "Hide & Seek", Min = 3, Duration = 100, Weight = 2, Desc = "Hide! The seeker BONKs whoever they find." },
	},
}
Config.MinigameById = {}
for _, info in Config.Minigames.Games do
	Config.MinigameById[info.Id] = info
end

-- EXPLORAÇÃO (v13)
Config.Explore = {
	IslandMinute = 30, -- a ILHA SECRETA abre no minuto 30 de cada hora (UTC) e fica 5 minutos
	IslandMinutes = 5,
	HuntEggs = 10, -- caça aos ovos diária: 10 ovos escondidos no Meadow (mesmos lugares para todos no dia)
	HuntReward = { Minutes = 1 }, -- cada ovo achado
	HuntBonus = { BigEgg = 1 }, -- os 10 do dia
	FishCooldown = 4, -- segundos entre lançamentos
	FishPerDay = 60,
	DigCooldown = 10 * 60, -- cada buraco de areia: 1 vez a cada 10 min por jogador
	FossilChance = 0.08,
	FossilsPerDay = 2, -- ovo grátis: no máximo 2 por dia (não atropela a economia)
	ChestRewards = { { Weight = 60, Minutes = 1 }, { Weight = 30, Minutes = 3 }, { Weight = 10, WorldEgg = 1 } },
}
-- Montarias (grátis; destrava pelo nível da conta). Não valem carregando bichinho roubado nem em minigame.
Config.Mounts = {
	{ Id = "skate", Name = "Skateboard", Level = 1, Speed = 1.15 },
	{ Id = "cart", Name = "Go-Kart", Level = 5, Speed = 1.25 },
	{ Id = "critter", Name = "Critter Ride", Level = 12, Speed = 1.3 },
}
Config.MountById = {}
for _, mount in Config.Mounts do
	Config.MountById[mount.Id] = mount
end

-- Em qual aba do Índice fica um bichinho (ou ovo)
function Config.IndexTabOf(worldOrPool: string?): string
	if worldOrPool and Config.SpecialPools[worldOrPool] then
		return "special"
	end
	return worldOrPool or "meadow"
end

-- Estágio de crescimento pela idade em segundos: (índice, dados do estágio)
function Config.GrowthStage(age: number)
	local index = 1
	for i, stage in Config.Growth do
		if age >= stage.Age then
			index = i
		end
	end
	return index, Config.Growth[index]
end

-- Tamanho na base de um bichinho num estágio (o gigante tem limite)
function Config.StageScale(stage, size: number): number
	if stage.Scale > 1 then
		return math.min(stage.Scale, math.max(1, Config.GiantMaxSize / math.max(size, 0.1)))
	end
	return stage.Scale
end

-- A partir de qual raridade o servidor inteiro recebe um aviso
Config.AnnounceFromRarity = 5 -- 5 = Legendary

function Config.SpeedCost(level: number): number
	return math.floor(Config.SpeedBaseCost * Config.SpeedCostGrowth ^ level)
end

function Config.RebirthCost(rebirths: number): number
	return math.floor(Config.RebirthBaseCost * Config.RebirthCostGrowth ^ rebirths)
end

function Config.SlotCount(rebirths: number, boughtSlots: number, hasSlotsPass: boolean?): number
	local slots = Config.StartSlots + math.min(boughtSlots, #Config.SlotUpgradeCosts) + math.min(rebirths, Config.MaxRebirthSlotBonus)
	if hasSlotsPass then
		slots += Config.PassSlots
	end
	return math.min(slots, Config.MaxSlots)
end

function Config.TreadmillCap(rebirths: number): number
	return Config.TreadmillBaseCap + rebirths * Config.TreadmillCapPerRebirth
end

-- Melhor raridade possível de um ovo (para a plaquinha "Best: LEGENDARY 5%")
function Config.EggBest(egg): (string, number)
	local bestName, bestChance, bestIndex = "Common", 0, 0
	for name, chance in egg.Odds do
		local index = Config.RarityIndex[name] or 0
		if chance > 0 and index > bestIndex then
			bestName, bestChance, bestIndex = name, chance, index
		end
	end
	return bestName, bestChance
end

function Config.IncomeMultiplier(mutation: string?): number
	local info = mutation and Config.MutationByName[mutation]
	return if info then info.Income else 1
end

-- Bônus de dinheiro de UM pet equipado (ex.: 0.07 = +7%)
function Config.PetBonusOf(rarity: string, mutation: string?): number
	local base = Config.PetBonus[rarity] or 0
	local boost = if mutation then Config.PetMutationBonus[mutation] or 1 else 1
	return base * boost
end

-- Fusão: em qual mutação 5 iguais viram (nil = não dá para fundir)
function Config.FuseResult(mutation: string?): string?
	return Config.FuseInto[mutation or ""]
end

function Config.PriceMultiplier(mutation: string?): number
	local info = mutation and Config.MutationByName[mutation]
	return if info then info.Price else 1
end

return Config
