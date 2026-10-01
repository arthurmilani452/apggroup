-- Config.Power: ENERGIA (o relógio do turno), zonas, emergência, APAGÃO, Quadro de Força.   dono: shift-power
return {
	Start = 100, -- %
	DrainSeconds = 240, -- 100% -> 0% em 240 s
	BlackoutSeconds = 60, -- depois do apagão o elevador sobe em 60 s
	TickHz = 4, -- atualizações por segundo do atributo Workspace.Power

	-- Zonas apagam (a mais funda primeiro). Zona -> energia (%) em que apaga.
	ZoneOffAt = { [4] = 50, [3] = 35, [2] = 20, [1] = 20 },
	EmergencyAt = 20, -- todas as fluorescentes desligam, vermelhas acendem
	BlackoutAt = 0, -- até as vermelhas apagam

	EmergencyBlinkHz = 0.5, -- luzes vermelhas (fixas com "Reduzir flashes")

	-- Monstros ficam mais rápidos
	MonsterSpeedBonus = { Normal = 0, Emergency = 0.15, Blackout = 0.30 },
	-- Audição do Rastejante
	HearingMult = { Normal = 1, Emergency = 1, Blackout = 1.5 },

	-- Quadro de Força
	Breaker = {
		PerFacility = 1,
		PerFacilityBigCrew = 2, -- com 3 ou mais jogadores
		BigCrewPlayers = 3,
		Zones = { 2, 3 }, -- aparece na zona 2 ou 3
		HoldSecondsSolo = 4, -- segurar sozinho
		HoldSecondsDuo = 2, -- 2 jogadores segurando juntos (progresso = segurando / 4 por segundo)
		PowerGain = 12, -- +12% (cerca de 29 s)
		RelightsZone = true, -- reacende a zona do quadro se estava apagada (até a emergência)
		Noise = 20,
		PromptRange = 8,
	},

	-- Hora Extra (produto): +60 s de energia para a equipe, 1 vez por turno
	Overtime = {
		Seconds = 60, -- vira +25% de energia (60 / 240)
		OncePerShift = true,
		ShowButtonAtOrBelow = 30, -- o botão só aparece no HUD com energia <= 30%
		MarksAssisted = true,
	},
}
