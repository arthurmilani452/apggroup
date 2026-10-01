-- Config.Build: construção da instalação em peças (FacilityBuilder, PropBuilder).   dono: facility-build
return {
	Origin = Vector3.new(4000, 0, 0), -- célula (0,0) = poço do elevador; o piso fica em Y = Origin.Y
	PartsPerFrame = 250,
	FolderName = "Facility", -- Workspace.Facility

	Materials = {
		Floor = Enum.Material.Concrete,
		Wall = Enum.Material.Concrete,
		Ceiling = Enum.Material.Concrete,
		ElevatorFloor = Enum.Material.DiamondPlate,
		ElevatorWall = Enum.Material.CorrodedMetal,
		Puddle = Enum.Material.Glass,
		Dirt = Enum.Material.SmoothPlastic,
	},
	Colors = {
		Floor = Color3.fromRGB(70, 72, 74),
		Wall = Color3.fromRGB(96, 100, 104),
		Ceiling = Color3.fromRGB(40, 42, 45),
		HazardYellow = Color3.fromRGB(230, 190, 40),
		HazardBlack = Color3.fromRGB(20, 20, 20),
		Dirt = Color3.fromRGB(25, 22, 18),
		Puddle = Color3.fromRGB(30, 40, 45),
		ExitGreen = Color3.fromRGB(40, 220, 90),
	},
	DirtTransparency = 0.6,

	-- Luminária fluorescente: peça Neon 4 × 0,2 × 1 com SurfaceLight virada para baixo
	Fluorescent = {
		Size = Vector3.new(4, 0.2, 1),
		Range = 16,
		Brightness = 1.2,
		Angle = 110,
		Color = Color3.fromRGB(220, 235, 255),
	},
	-- Luz de emergência
	Emergency = {
		Color = Color3.fromRGB(255, 40, 30),
		Range = 14,
		Brightness = 1.5,
	},
	-- Elevador da instalação
	Elevator = {
		BeaconColor = Color3.fromRGB(255, 140, 30),
		DoorColor = Color3.fromRGB(120, 110, 90),
		SpawnCount = 4, -- pontos de chegada Spawn_1..4
	},
	DebugBeamColor = Color3.fromRGB(0, 255, 200),
}
