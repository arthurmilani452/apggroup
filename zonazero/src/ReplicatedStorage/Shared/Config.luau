--[[
	Config (ModuleScript em ReplicatedStorage > Shared)
	TODOS os números do Zona Zero ficam aqui. Pra ajustar o jogo, mexa só neste arquivo.
]]

local Config = {}

Config.GameName = "ZONA ZERO"
Config.DataStoreName = "ZonaZero_Data_v1" -- nunca mude depois de lançar (apaga o progresso de todo mundo)

---------------------------------------------------------------------
-- PARTIDA
---------------------------------------------------------------------
Config.Match = {
	MinHumans = 1, -- com 1 jogador já começa (os bots completam)
	FillWithBots = 8, -- se tiver menos que isso de participantes, entram bots até chegar aqui
	MaxParticipants = 16,
	LobbyWait = 20, -- segundos esperando mais gente antes da contagem
	Countdown = 10, -- contagem final
	EndDelay = 10, -- segundos mostrando o vencedor antes de voltar ao lobby
	DropHeight = 140, -- altura do salto de paraquedas
	ParachuteGravity = 0.12, -- fração da gravidade durante a queda (menor = cai mais devagar)
	StartWeapon = "Pistol", -- arma que todo mundo ganha ao cair (nil = começa sem nada)
	StartAmmo = { Light = 24 },
	MaxWeapons = 4, -- armas na mochila ao mesmo tempo (curas não contam)
	EndWhenOnlyBots = true, -- todos os humanos morreram: a partida acaba (ninguém vai assistir bots)
}

---------------------------------------------------------------------
-- ZONA (a tempestade que fecha)
---------------------------------------------------------------------
-- Cada fase: espera Wait s, depois fecha em Shrink s até Radius; Damage = dano por segundo fora dela
Config.Zone = {
	StartRadius = 620,
	Phases = {
		{ Wait = 45, Shrink = 40, Radius = 380, Damage = 2 },
		{ Wait = 35, Shrink = 35, Radius = 220, Damage = 4 },
		{ Wait = 30, Shrink = 30, Radius = 120, Damage = 7 },
		{ Wait = 25, Shrink = 25, Radius = 55, Damage = 10 },
		{ Wait = 20, Shrink = 25, Radius = 12, Damage = 15 },
		{ Wait = 15, Shrink = 20, Radius = 0, Damage = 25 },
	},
	Color = Color3.fromRGB(150, 60, 255),
}

---------------------------------------------------------------------
-- JOGADOR
---------------------------------------------------------------------
Config.Player = {
	MaxHealth = 100,
	MaxShield = 100,
	WalkSpeed = 18,
	JumpPower = 50,
}

---------------------------------------------------------------------
-- ARMAS
-- Damage = dano por bala (Pellets = balas por tiro, escopeta)
-- Rpm = tiros por minuto; Auto = segura pra atirar
-- Spread = imprecisão em graus (mirando: x AimSpread)
-- Range = alcance máximo em studs; Falloff = a partir de onde o dano cai (até 60%)
-- Ammo = tipo de munição; Mag = pente; Reload = segundos
-- Zoom = campo de visão mirando (botão direito)
---------------------------------------------------------------------
Config.Weapons = {
	Pistol = {
		Damage = 22, Pellets = 1, Rpm = 330, Auto = false, Spread = 1.6, AimSpread = 0.5,
		Range = 320, Falloff = 120, Ammo = "Light", Mag = 12, Reload = 1.3, Headshot = 1.6, Zoom = 60,
		Length = 1.6, Color = Color3.fromRGB(55, 58, 64),
	},
	SMG = {
		Damage = 14, Pellets = 1, Rpm = 780, Auto = true, Spread = 3.2, AimSpread = 0.6,
		Range = 240, Falloff = 70, Ammo = "Light", Mag = 30, Reload = 1.8, Headshot = 1.5, Zoom = 58,
		Length = 2.4, Color = Color3.fromRGB(45, 50, 55),
	},
	Rifle = {
		Damage = 26, Pellets = 1, Rpm = 600, Auto = true, Spread = 1.8, AimSpread = 0.35,
		Range = 600, Falloff = 220, Ammo = "Medium", Mag = 30, Reload = 2.1, Headshot = 1.75, Zoom = 45,
		Length = 3.6, Color = Color3.fromRGB(70, 66, 52),
	},
	Shotgun = {
		Damage = 9, Pellets = 9, Rpm = 75, Auto = false, Spread = 7, AimSpread = 0.75,
		Range = 110, Falloff = 25, Ammo = "Shells", Mag = 6, Reload = 2.6, Headshot = 1.3, Zoom = 60,
		Length = 3.4, Color = Color3.fromRGB(90, 60, 40),
	},
	Sniper = {
		Damage = 95, Pellets = 1, Rpm = 42, Auto = false, Spread = 4, AimSpread = 0.02,
		Range = 1600, Falloff = 1600, Ammo = "Heavy", Mag = 5, Reload = 2.8, Headshot = 2.2, Zoom = 18,
		Length = 4.6, Color = Color3.fromRGB(40, 55, 45),
	},
}
Config.WeaponOrder = { "Pistol", "SMG", "Shotgun", "Rifle", "Sniper" }

-- Raridade: multiplica o dano e pinta o brilho da arma
Config.Rarities = {
	{ Id = "Common", Damage = 1.0, Weight = 60, Color = Color3.fromRGB(200, 200, 205) },
	{ Id = "Rare", Damage = 1.1, Weight = 28, Color = Color3.fromRGB(60, 150, 255) },
	{ Id = "Epic", Damage = 1.2, Weight = 10, Color = Color3.fromRGB(190, 80, 255) },
	{ Id = "Legendary", Damage = 1.3, Weight = 2, Color = Color3.fromRGB(255, 180, 40) },
}

Config.AmmoTypes = {
	Light = { Pickup = 30, Max = 180, Color = Color3.fromRGB(240, 210, 90) },
	Medium = { Pickup = 30, Max = 180, Color = Color3.fromRGB(110, 200, 110) },
	Shells = { Pickup = 8, Max = 40, Color = Color3.fromRGB(230, 90, 70) },
	Heavy = { Pickup = 6, Max = 30, Color = Color3.fromRGB(90, 140, 230) },
}

-- Curas: UseTime = segundos parado usando; Heal = vida; Shield = escudo; MaxHeal = até quanto a vida sobe
Config.Items = {
	Bandage = { UseTime = 2.5, Heal = 20, MaxHeal = 75, Color = Color3.fromRGB(235, 230, 215) },
	Medkit = { UseTime = 6, Heal = 100, MaxHeal = 100, Color = Color3.fromRGB(220, 50, 55) },
	ShieldCell = { UseTime = 3, Shield = 50, Color = Color3.fromRGB(70, 160, 255) },
}

-- Chance de cada tipo de loot por ponto de loot (pesos)
Config.Loot = {
	SpotChance = 0.85, -- chance de um ponto de loot ter alguma coisa
	Table = {
		{ Kind = "Weapon", Id = "Pistol", Weight = 14 },
		{ Kind = "Weapon", Id = "SMG", Weight = 12 },
		{ Kind = "Weapon", Id = "Shotgun", Weight = 10 },
		{ Kind = "Weapon", Id = "Rifle", Weight = 10 },
		{ Kind = "Weapon", Id = "Sniper", Weight = 3 },
		{ Kind = "Ammo", Id = "Light", Weight = 12 },
		{ Kind = "Ammo", Id = "Medium", Weight = 10 },
		{ Kind = "Ammo", Id = "Shells", Weight = 7 },
		{ Kind = "Ammo", Id = "Heavy", Weight = 4 },
		{ Kind = "Item", Id = "Bandage", Weight = 10 },
		{ Kind = "Item", Id = "Medkit", Weight = 3 },
		{ Kind = "Item", Id = "ShieldCell", Weight = 7 },
	},
	PickupRange = 10,
}

---------------------------------------------------------------------
-- BOTS
---------------------------------------------------------------------
Config.Bots = {
	Health = 100,
	WalkSpeed = 15,
	SightRange = 150,
	ReactionTime = { 0.45, 0.9 }, -- segundos entre ver alguém e começar a atirar
	AccuracyDegrees = 5.5, -- erro de mira extra (quanto maior, pior)
	BurstShots = { 3, 6 },
	BurstPause = { 0.6, 1.4 },
	Weapons = { "Pistol", "SMG", "Rifle", "Shotgun" },
	Names = {
		"Recruta_07", "Sombra", "Lobo_Cinza", "Corvo", "Falcão", "Vandal", "Zero_Um", "Raposa",
		"Tanque", "Fantasma", "Cobra", "Trovão", "Nômade", "Vulto", "Garra", "Eco",
	},
}

---------------------------------------------------------------------
-- PROGRESSO
---------------------------------------------------------------------
Config.XP = {
	Kill = 50,
	Win = 300,
	Match = 25,
	PerPlaceAbove = 10, -- XP por jogador que você sobreviveu a mais
}
-- XP para passar do nível n
function Config.XPForLevel(level: number): number
	return 200 + level * 75
end

-- Sons: cole aqui IDs de sons da Creator Store (rbxassetid://...) quando quiser. Vazio = sem som.
Config.Sounds = {
	Pistol = "",
	SMG = "",
	Rifle = "",
	Shotgun = "",
	Sniper = "",
	Reload = "",
	Hit = "",
	Pickup = "",
}

-- Animações padrão do Roblox (R15) usadas pelos bots
Config.BotAnimations = {
	Idle = "rbxassetid://507766388",
	Run = "rbxassetid://507767714",
}

return Config
