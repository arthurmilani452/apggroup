-- Config.Kit: kit do jogador (vida, movimento, fôlego, lanterna, capacete, pá, sinalizador, escâner).   dono: scrap-kit
return {
	Health = 100, -- não regenera na instalação (StarterCharacterScripts/Health vazio desliga a regeneração)

	WalkSpeed = 14,
	SprintSpeed = 22,
	CrouchSpeed = 7,
	CrouchCameraOffset = Vector3.new(0, -1.6, 0), -- Humanoid.CameraOffset agachado (sem animação)

	Stamina = {
		Max = 100,
		SprintDrain = 18, -- por segundo (cerca de 5,5 s)
		Regen = 20, -- por segundo
		RegenDelay = 1, -- segundos sem correr antes de recuperar
		ResumeAt = 35, -- zerou: só volta a correr com 35
		SyncHz = 10, -- atributo Stamina
	},

	Flashlight = {
		Range = 50,
		Angle = 45, -- SpotLight.Angle (cone total)
		Brightness = 3,
		ConeHalfAngle = 22.5, -- "iluminado pela lanterna" (regra do Vigia)
		Color = Color3.fromRGB(255, 244, 220),
		BatterySeconds = 150, -- ligada
		BatteryUpgradeSeconds = { 190, 230, 270 }, -- Bateria I / II / III
		ShadowsLocalOnly = true, -- só a lanterna do próprio jogador projeta sombra
		FakeCone = { WidthStart = 0.5, WidthEnd = 12, TransparencyStart = 0.85, TransparencyEnd = 1 },
	},

	Helmet = { Range = 10, Brightness = 0.5, Color = Color3.fromRGB(255, 220, 170) }, -- sempre acesa: piso de visibilidade

	Shovel = {
		Range = 7,
		StunSeconds = 3,
		StunSecondsUpgraded = 4.5,
		Cooldown = 4,
		CooldownUpgraded = 3,
		HitNoise = 25,
		ConeDegrees = 70, -- à frente do jogador
	},

	Flare = {
		PerShift = 1,
		MaxTotal = 4, -- com extras comprados
		ThrowDistance = 30,
		ThrowUp = 12, -- velocidade vertical inicial (arco)
		Duration = 20,
		LightRange = 24,
		LightColor = Color3.fromRGB(255, 40, 30),
		HoldWatcherRadius = 20, -- segura o Vigia
		Noise = 60, -- contínuo: atrai o Rastejante
		StunRadius = 6, -- atordoa se cair perto
		StunSeconds = 3,
	},

	Scanner = {
		UnlockRank = "trainee",
		Radius = 40,
		Duration = 5,
		Cooldown = 12,
		Noise = 12,
	},

	SpareBattery = { Refill = 0.5, PerShift = 1 }, -- Pilha Reserva (preço em Config.Progression.Consumables)

	Camera = { MinZoom = 0.5, MaxZoom = 8 }, -- terceira pessoa por padrão; V troca; "Primeira pessoa fixa" nas configurações

	-- Anti-trapaça: acima de 30 studs/s sustentados volta à última posição válida
	SpeedCheck = { MaxSpeed = 30, SustainSeconds = 1, SampleHz = 4 },

	-- Teclas (PC). Celular usa botões grandes (MobileButtons).
	Keys = {
		Pickup = Enum.KeyCode.E, -- ProximityPrompt
		Drop = Enum.KeyCode.G,
		Flashlight = Enum.KeyCode.F,
		Crouch = Enum.KeyCode.C,
		Sprint = Enum.KeyCode.LeftShift,
		Scan = Enum.KeyCode.Q,
		Flare = Enum.KeyCode.T,
		PingWheel = Enum.KeyCode.Z, -- segurar
		Camera = Enum.KeyCode.V,
		-- Pá = clique esquerdo (Enum.UserInputType.MouseButton1)
	},
	GamepadKeys = {
		Drop = Enum.KeyCode.ButtonB,
		Flashlight = Enum.KeyCode.DPadUp,
		Crouch = Enum.KeyCode.ButtonL3,
		Sprint = Enum.KeyCode.ButtonL2,
		Scan = Enum.KeyCode.DPadLeft,
		Flare = Enum.KeyCode.DPadRight,
		PingWheel = Enum.KeyCode.DPadDown,
		Shovel = Enum.KeyCode.ButtonR2,
		Camera = Enum.KeyCode.ButtonR3,
	},
}
