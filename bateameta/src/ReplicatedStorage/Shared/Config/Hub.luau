-- Config.Hub: a Doca (hub) em tempo de jogo.   dono: hub-map
return {
	FolderName = "Hub", -- Workspace.Hub (montado pelo builder/hub.py)
	SodiumColor = Color3.fromRGB(255, 170, 90),
	BeaconColor = Color3.fromRGB(255, 140, 30),
	BeaconSpinSeconds = 2, -- uma volta da luz giratória do elevador
	LeverPromptRange = 8,
	TerminalPromptRange = 8,

	-- Placas: o nome da peça em Hub/Signs É a chave de texto (SignKey). Estilo e face por chave:
	SignStyles = {
		SIGN_WAREHOUSE = { Style = "Board", Face = "Front" },
		SIGN_SLOGAN_1 = { Style = "Poster", Face = "Front" },
		SIGN_SLOGAN_2 = { Style = "Poster", Face = "Front" },
		SIGN_SLOGAN_3 = { Style = "Poster", Face = "Front" },
		SIGN_SLOGAN_4 = { Style = "Poster", Face = "Front" },
		SIGN_SLOGAN_5 = { Style = "Poster", Face = "Front" },
		SIGN_SLOGAN_6 = { Style = "Poster", Face = "Front" },
		SIGN_ELEVATOR = { Style = "Board", Face = "Front" },
		SIGN_DAILY_SOON = { Style = "Board", Face = "Front" },
		SIGN_LOCKER_SOON = { Style = "Board", Face = "Front" },
	},

	-- Pizza da Firma: caixas de pizza em cima da mesa (peças), por quanto tempo durar a festa
	PizzaBoxesMax = 6,

	-- Chuva no hub (cliente, Ambience)
	Rain = { Rate = 250, Radius = 40, Speed = 80 },
}
