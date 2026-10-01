-- Config.Noise: raio (studs) de cada ação — a audição do Rastejante.   dono: scrap-kit
return {
	Radius = {
		Sprint = 30, -- um pulso a cada SprintPulseSeconds
		Walk = 10,
		WalkQuiet = 5, -- Botas Silenciosas
		Crouch = 0,
		Land = 18, -- aterrissar de um pulo
		DropSmall = 16,
		DropHeavy = 40,
		Sell = 35,
		ShovelHit = 25,
		Scanner = 12,
		Breaker = 20,
		Flare = 60, -- contínuo enquanto aceso
	},
	SprintPulseSeconds = 0.4,
	WalkPulseSeconds = 0.8,
	MinMoveSpeed = 2, -- abaixo disso (studs/s) conta como parado
	-- Multiplicador de audição: APAGÃO x1,5 (Config.Power.HearingMult) e "Semana do Silêncio" (Config.Future)
	RecentSeconds = 8, -- NoiseService guarda os ruídos por este tempo (o Rastejante esquece depois de 8 s)
}
