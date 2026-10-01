-- Config.Monsters: O Vigia, O Rastejante, escalada de dificuldade.   dono: monsters
return {
	Ids = { "Watcher", "Crawler" }, -- "Mimic" fica em Config.Future (fora do MVP)

	Watcher = {
		Height = 9,
		Colors = { Body = Color3.fromRGB(12, 12, 14), Eyes = Color3.fromRGB(200, 220, 255), Badge = Color3.fromRGB(235, 235, 225) },
		LegSize = Vector3.new(0.8, 5, 0.8),
		ArmSize = Vector3.new(0.6, 5.5, 0.6),
		HeadTiltDegrees = 12,
		EyeLightRange = 4,

		-- Regra central: só se move quando ninguém o vê
		ViewConeDegrees = 40, -- produto escalar >= cos 40° entre o olhar e a direção até ele
		FlashlightConeDegrees = 22.5, -- "iluminado" pela lanterna ligada (<= 22,5° e <= 50 studs)
		FlashlightRange = 50,
		FlareHoldRadius = 20, -- a até 20 studs de um sinalizador = iluminado
		DecideHz = 10, -- o servidor decide 10 vezes por segundo
		ReactionWindow = 0.4, -- não visto por 0,4 s -> AVANÇO

		StepStuds = 4, -- passos de 4 studs a cada 0,2 s (20 studs/s), sem animação (PivotTo ancorado)
		StepInterval = 0.2,
		FlickerRadius = 20, -- luzes a 20 studs piscam quando ele se move
		KillRange = 4, -- nocaute instantâneo (distância checada no servidor, sem Touched)
		SpawnMinDepth = 5,
		BoredSeconds = 25, -- solo: sem se aproximar por 25 s -> reaparece longe (DESINTERESSE)
		BoredMinDepth = 4,

		Scare = { SnapSeconds = 0.6, SnapFOV = 40, StaticSeconds = 0.4, SoftFadeSeconds = 0.8 },
	},

	Crawler = {
		BodySize = Vector3.new(5, 1.6, 6),
		Colors = { Body = Color3.fromRGB(45, 40, 36), Sign = Color3.fromRGB(245, 205, 30) },
		Legs = 8,
		Speeds = { Patrol = 8, Investigate = 14, Hunt = 21, Retreat = 14 },
		ForgetSeconds = 8, -- INVESTIGAR esquece o ruído depois de 8 s
		HuntRange = 10, -- ruído contínuo a até 10 studs -> CAÇAR
		AttackRange = 5,
		AttackWindup = 0.4, -- as pernas sobem, legenda "[chiado]"
		Damage = 35,
		AttackCooldown = 1.5,
		StunSeconds = 3,
		StunImmunitySeconds = 6,
		RetreatCells = 3,
		StuckDistance = 2, -- menos de 2 studs em 2 s = travado
		StuckSeconds = 2,
		FlareDistractSeconds = 20,
		FootprintLifetime = 20,
		FootprintEverySeconds = 0.5,
	},

	-- Escalada por contrato (tabela da seção 7 do GDD)
	Escalation = {
		SpeedPerContract = 0.05, -- x1,00 no contrato 1, +0,05 por contrato
		SpeedCap = 1.30,
		CrawlerBase = 1,
		CrawlerExtraAtPlayers = 3, -- +1 com 3 ou mais jogadores
		CrawlerExtraFromContract = 4, -- +1 a partir do contrato 4
		CrawlerMax = 3,
		WatcherBase = 1,
		WatcherExtraFromContract = 5, -- 2 Vigias do contrato 5 em diante
		WatcherMax = 2,
		CrawlerSpawn = { Base = 30, PerContract = 3, Min = 12 }, -- segundos depois do início do turno
		WatcherSpawn = { Base = 45, PerContract = 5, Min = 20 },
	},

	-- Relatórios de Incidente (bestiário): 1º encontro abre; 5 fugas abrem o 2º nível de lore
	Bestiary = { EscapesForLore2 = 5 },

	-- "Coração de Estagiário": tempo perto de monstro
	NearMonsterRadius = 20,
}
