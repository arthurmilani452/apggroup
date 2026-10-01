-- Config.Economy: meta, salário, anti-AFK, Dia da Meta, XP, resgate.   dono: crew-payroll
-- As contas ficam em Shared/Formulas (use sempre as funções de lá).
return {
	Quota = {
		Base = 600, -- meta do contrato 1 solo (soma dos 3 turnos)
		Growth = 1.35, -- × 1,35^(c − 1)
		CrewFactor = { 1.0, 1.6, 2.1, 2.5 }, -- 1, 2, 3, 4 jogadores no início do turno
	},

	Salary = {
		TeamBonusPerExtra = 0.1, -- vendido ÷ n × (1 + 0,1 × (n − 1))
		AntiAfk = { MinSales = 1, MinOutsideSeconds = 60, ReducedFactor = 0.5 },
	},

	Promoted = { CreditsPerContract = 100, ExcessShare = 0.5, XP = 150 },
	Fired = { CreditsPerContract = 50, XP = 50 }, -- "Rescisão": nunca paga zero

	XP = {
		PerSoldShare = 0.4, -- 0,4 × sua parte do valor vendido
		Survive = 40,
		Rescue = 30, -- por crachá resgatado
		Stun = 10, -- por atordoamento
		StunMax = 3,
		FirstContractOfDayMult = 2, -- "Hora extra dobrada"
		FriendBonus = 0.10, -- "Panelinha": amigo do Roblox na equipe
	},

	Rescue = { HP = 50, Battery = 0.5 }, -- volta no elevador com 50 HP e 50% de bateria
	HealthPlan = { HP = 100, OncePerShift = true, MarksAssisted = true }, -- Plano de Saúde
	FirstFreeKO = true, -- primeiro turno da vida numa equipe mista: o 1º nocaute revive sozinho

	CurrencyName = "Creditos", -- nome da moeda nos eventos de economia do Analytics
}
