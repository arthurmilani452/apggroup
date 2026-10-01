-- Config.Shift: máquina de estados do contrato, tempos, elevador, treinamento.   dono: shift-power
return {
	-- Fases (valor do atributo Workspace.Phase)
	Phases = { "Hub", "Countdown", "Descent", "Shift", "Seal", "Review", "Intermission", "QuotaDay" },

	ShiftsPerContract = 3,

	-- Contagem na alavanca
	CountdownSeconds = 15, -- 2 ou mais jogadores
	CountdownSoloSeconds = 3, -- sozinho
	CountdownReadySeconds = 3, -- quando a maioria aperta PRONTO a contagem cai para isso
	ReadyMajority = 0.5, -- "maioria" = mais que esta fração dos jogadores do servidor

	-- Descida (hub -> instalação)
	DescentSeconds = 6,
	FadeOutSeconds = 0.3, -- fade para preto que esconde o teleporte
	FadeHoldSeconds = 0.2,
	FadeInSeconds = 0.3,
	DescentShake = 0.35, -- força do tremor da câmera durante a descida

	-- Turno: 240 s de energia (Config.Power.DrainSeconds) + 60 s de APAGÃO = 300 s.
	-- O fim do turno (lacre) é SEMPRE BlackoutSeconds depois do apagão; energia extra adia o apagão.
	ShiftSecondsNominal = 300,
	SealSeconds = 3,
	ReviewSeconds = 15,
	IntermissionSeconds = 45, -- pula quando todos apertam PRONTO
	QuotaDaySeconds = 12,

	-- Elevador
	HornSecondsLeft = { 60, 15 }, -- buzina quando faltam X s para o lacre
	BeaconBlinkSecondsLeft = 15, -- a luz laranja pisca a partir daqui
	DoorsCloseSecondsLeft = 5, -- as portas começam a fechar (animação de 5 s)
	PunchClockHoldSeconds = 3, -- "bater o ponto": todos os vivos no elevador, segurar 3 s
	ElevatorHealPerSecond = 10, -- HP por segundo dentro do elevador
	ElevatorChargePerSecond = 0.05, -- fração da bateria por segundo (5%/s)

	-- Entrar atrasado ("DESCER")
	LateJoinMinSecondsLeft = 45, -- só enquanto faltarem 45 s ou mais para o lacre
	LateJoinPayByTime = true, -- quem desce atrasado recebe proporcional ao tempo presente no turno

	-- Contratos
	FirstContract = 1,
	RehireDivisor = 2, -- recontratação: max(1, floor(menor recorde entre os presentes / 2))

	-- Relógio do HUD: 22:00 com 100% de energia, 05:00 com 0%, 06:00 no lacre
	ClockStartMinutes = 22 * 60,
	ClockPowerMinutes = 7 * 60, -- 22:00 -> 05:00 enquanto a energia cai
	ClockBlackoutMinutes = 60, -- 05:00 -> 06:00 durante o APAGÃO

	-- Treinamento (primeiro turno de uma equipe solo ou só de novatos)
	Training = {
		WatcherEnabled = false,
		CrawlerSpeedMult = 0.6,
		CrawlerHearingMult = 0.7,
		CrawlerSpawnSeconds = 90,
		Hints = { "Flashlight", "Pickup", "Sell", "Power", "Crouch" }, -- 5 memorandos do RH
	},

	-- Solo
	Solo = {
		WatcherSpeedMult = 0.85,
		WatcherBoredSeconds = 25, -- "perde o interesse" e reaparece longe
		KOEndsShift = true, -- nocaute solo encerra o turno (o que foi vendido conta)
	},

	-- Nocaute por ficar para trás
	LeftBehindCause = "LeftBehind",
}
