--!nonstrict
--[[
	CONFIG do jogo novo (estilo "roubar ovos das zonas"). TODOS os números de ajuste ficam aqui.
	Mecânica do gênero "roubar ovos" (pista reta de zonas, guardião dormindo, esteira de velocidade,
	reset a cada 5 minutos). Nomes, criaturas, textos e visual são NOSSOS (bichinhos do Steal a Critter).

	Eixo do mapa: tudo numa linha reta. +Z = para longe das bases (zonas mais fundas).
	  HUB (bases)  z de -230 até 0  -> linha SAFE em z = 0 -> zonas de 260 de comprimento uma atrás da outra.
]]

local Config = {}

Config.GameName = "Steal a Critter Egg" -- troque à vontade (aparece na placa do hub)

---------------------------------------------------------------------
-- Raridades e mutações (o CritterBuilder também usa)
---------------------------------------------------------------------
Config.Rarities = {
	-- Size = tamanho do bichinho (quanto mais raro, MAIOR na base)
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Weight = 60, Size = 3, Grow = 10 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 90), Weight = 25, Size = 3.5, Grow = 30 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Weight = 10, Size = 4.3, Grow = 60 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 90, 255), Weight = 3.5, Size = 5.3, Grow = 180 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 200, 40), Weight = 1.2, Size = 6.6, Grow = 600 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 110), Weight = 0.28, Size = 7.8, Grow = 1800 },
	{ Name = "Secret", Color = Color3.fromRGB(255, 255, 255), Weight = 0.04, Size = 9, Grow = 3600, Announce = true },
	{ Name = "Divine", Color = Color3.fromRGB(255, 225, 90), Weight = 0.006, Size = 10.2, Grow = 10800, Announce = true },
	-- NOVA: a mais rara de todas (1 em ~50.000 ovos), gigante e com raios arco-íris
	{ Name = "Celestial", Color = Color3.fromRGB(120, 240, 255), Weight = 0.0012, Size = 11.5, Grow = 21600, Announce = true },
}
-- maior tamanho que um bichinho pode ter no cercado (studs); as vagas ficam a 11 studs uma da outra
Config.MaxPetSize = 14
Config.RarityByName = {}
Config.RarityIndex = {}
for index, rarity in Config.Rarities do
	Config.RarityByName[rarity.Name] = rarity
	Config.RarityIndex[rarity.Name] = index
end

-- mutação: Chance em %, Income = multiplicador (mutações diferentes somam: 1 + soma(mult - 1))
-- Chance = 0: só aparece em evento (ex.: Spooky no Halloween, ver Config.Halloween)
Config.Mutations = {
	{ Name = "Gold", Chance = 4, Income = 2, Price = 2, Color = Color3.fromRGB(255, 205, 60) },
	{ Name = "Diamond", Chance = 1.5, Income = 4, Price = 4, Color = Color3.fromRGB(150, 235, 255) },
	{ Name = "Rainbow", Chance = 0.5, Income = 10, Price = 10, Color = Color3.fromRGB(255, 120, 220) },
	{ Name = "Spooky", Chance = 0, Income = 3, Price = 3, Color = Color3.fromRGB(255, 130, 40) },
}
Config.MutationByName = {}
for _, mutation in Config.Mutations do
	Config.MutationByName[mutation.Name] = mutation
end

---------------------------------------------------------------------
-- Mapa
---------------------------------------------------------------------
Config.Map = {
	HubWidth = 440, -- x de -220 a 220
	HubDepth = 230, -- z de -230 a 0
	LaneWidth = 150,
	LaneLength = 260,
	WallHeight = 70,
	PlotSpacing = 58,
	PlotZ = -120, -- centro da fileira de bases
	Plots = 7,
	PenWidth = 36,
	NaturalTerrain = false, -- true = cânion de terreno natural; false = paredes e chão de bloquinhos com pininhos
}

-- ZONAS (12 pistas). Speed = velocidade recomendada (placa vermelha/verde);
--   v65: nomes e números NOSSOS (os antigos eram iguais aos de outro jogo do gênero):
--   mecânica parecida tudo bem, mas nome + número idênticos dão risco de denúncia por cópia.
--   A curva é a mesma de antes, uns 11% mais baixa (começo um pouco mais fácil para as crianças).
--   MinSpeed = com essa velocidade e um ovo normal o guardião corre igual a você (escapa por pouco).
--   Pool = de onde saem os bichinhos (World do Critters.luau); Rarities = raridades que aparecem aqui.
--   Mult = quanto os bichinhos desta zona rendem (a renda NÃO usa o Income do Critters: cada zona tem a sua escala).
--   Guardian = bichinho NOSSO que fica gigante e dorme no meio dos ninhos; Height = altura em studs.
local rgb = Color3.fromRGB
local ORANGE_WALL = { rgb(214, 120, 64), rgb(190, 100, 52) }
local GRASS_TOP = rgb(80, 200, 60)
Config.Zones = {
	{ Id = "forest", Name = "Sprout Woods", Speed = 0, MinSpeed = 3, Mult = 1, Pool = { "meadow" }, Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary",  "Mythic", "Secret", "Divine", "Celestial" },
		Guardian = "mossy", Height = 19, Emoji = "\u{1F332}", Sky = rgb(150, 210, 255),
		Floor = { rgb(96, 200, 60), rgb(84, 180, 52) }, Wall = ORANGE_WALL, Top = GRASS_TOP, Props = "forest",
		Egg = { Style = "grass", Color = rgb(245, 235, 210), Accent = rgb(140, 215, 110) } },
	{ Id = "lake", Name = "Puddle Pond", Speed = 1_000, MinSpeed = 1_000, Mult = 12, Pool = { "hybrid" }, Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
		Guardian = "shellbo", Height = 22, Emoji = "\u{1F438}", Sky = rgb(140, 205, 255),
		Floor = { rgb(96, 200, 60), rgb(84, 180, 52) }, Wall = ORANGE_WALL, Top = GRASS_TOP, Props = "lake",
		Egg = { Style = "spotted", Color = rgb(170, 220, 255), Accent = rgb(255, 255, 255) } },
	{ Id = "desert", Name = "Sunny Sands", Speed = 9_000, MinSpeed = 8_500, Mult = 150, Pool = { "pirate" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
		Guardian = "crabbybeard", Height = 16, Emoji = "\u{1F3DC}\u{FE0F}", Sky = rgb(255, 225, 170),
		Floor = { rgb(236, 205, 130), rgb(222, 190, 115) }, Wall = { rgb(225, 170, 105), rgb(205, 150, 90) }, Top = rgb(240, 215, 140), Props = "desert",
		Egg = { Style = "spotted", Color = rgb(240, 210, 140), Accent = rgb(180, 120, 60) } },
	{ Id = "jungle", Name = "Wild Vines", Speed = 36_000, MinSpeed = 31_000, Mult = 1_500, Pool = { "dino" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
		Guardian = "raptorik", Height = 19, Emoji = "\u{1F334}", Sky = rgb(170, 230, 170),
		Floor = { rgb(60, 150, 50), rgb(50, 130, 42) }, Wall = { rgb(110, 120, 60), rgb(90, 100, 50) }, Top = rgb(40, 140, 40), Props = "jungle",
		Egg = { Style = "spotted", Color = rgb(150, 200, 90), Accent = rgb(110, 80, 50) } },
	{ Id = "snow", Name = "Frosty Peaks", Speed = 150_000, MinSpeed = 142_000, Mult = 15_000, Pool = { "frost" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
		Guardian = "yetimammoth", Height = 27, Emoji = "\u{2744}\u{FE0F}", Sky = rgb(220, 235, 255),
		Floor = { rgb(240, 245, 255), rgb(225, 230, 245) }, Wall = { rgb(200, 225, 250), rgb(175, 205, 240) }, Top = rgb(255, 255, 255), Props = "snow",
		Egg = { Style = "crystal", Color = rgb(200, 235, 255), Accent = rgb(255, 255, 255) } },
	{ Id = "volcano", Name = "Lava Land", Speed = 620_000, MinSpeed = 500_000, Mult = 150_000, Pool = { "lava" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
		Guardian = "volcanoram", Height = 24, Emoji = "\u{1F30B}", Sky = rgb(255, 170, 130),
		Floor = { rgb(35, 35, 45), rgb(45, 40, 52) }, Wall = { rgb(55, 45, 50), rgb(40, 32, 38) }, Top = rgb(255, 110, 30), Props = "volcano",
		Egg = { Style = "royal", Color = rgb(255, 120, 50), Accent = rgb(255, 220, 80) } },
	{ Id = "abyss", Name = "Deep Reef", Speed = 2_200_000, MinSpeed = 1_330_000, Mult = 1_500_000, Pool = { "reef" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary",  "Mythic", "Secret", "Divine", "Celestial" },
		Guardian = "glowmanta", Height = 35, Emoji = "\u{1F30A}", Sky = rgb(90, 150, 230),
		Floor = { rgb(30, 60, 140), rgb(38, 72, 155) }, Wall = { rgb(25, 40, 95), rgb(20, 32, 80) }, Top = rgb(90, 220, 230), Props = "abyss",
		Egg = { Style = "crystal", Color = rgb(90, 220, 220), Accent = rgb(255, 180, 230) } },
	{ Id = "prehistoric", Name = "Dino Valley", Speed = 16_000_000, MinSpeed = 11_100_000, Mult = 20_000_000, Pool = { "candy" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary",  "Mythic", "Secret", "Divine", "Celestial" },
		Guardian = "cupcaketoad", Height = 40, Emoji = "\u{1F996}", Sky = rgb(255, 215, 170),
		Floor = { rgb(200, 170, 110), rgb(185, 155, 95) }, Wall = { rgb(140, 100, 65), rgb(120, 85, 55) }, Top = rgb(90, 170, 60), Props = "prehistoric",
		Egg = { Style = "spotted", Color = rgb(255, 180, 220), Accent = rgb(110, 215, 255) } },
	-- v66: Speed 620M -> 190M e MinSpeed 245M -> 105M. O salto 16M -> 620M era 38x (as outras zonas pedem ~4x):
	--   com a esteira mais cara virava um muro de horas. 190M fica no meio do caminho (16M -> 190M -> 2,2B = ~12x cada).
	{ Id = "cosmic", Name = "Starry Space", Speed = 190_000_000, MinSpeed = 105_000_000, Mult = 300_000_000, Pool = { "galaxy" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary",  "Mythic", "Secret", "Divine", "Celestial" },
		Guardian = "cosmodragon", Height = 32, Emoji = "\u{1FA90}", Sky = rgb(120, 90, 200),
		Floor = { rgb(40, 20, 70), rgb(55, 30, 90) }, Wall = { rgb(50, 28, 85), rgb(38, 20, 68) }, Top = rgb(255, 230, 110), Props = "cosmic",
		Egg = { Style = "cosmic", Color = rgb(80, 50, 170), Accent = rgb(255, 230, 120) } },
	{ Id = "cherry", Name = "Blossom Grove", Speed = 2_200_000_000, MinSpeed = 890_000_000, Mult = 4_000_000_000, Pool = { "spooky", "halloween", "night" }, Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },
		Guardian = "heartcorn", Height = 32, Emoji = "\u{1F338}", Sky = rgb(255, 200, 230),
		Floor = { rgb(255, 200, 220), rgb(250, 225, 235) }, Wall = { rgb(250, 190, 215), rgb(235, 170, 200) }, Top = rgb(255, 255, 255), Props = "cherry",
		Egg = { Style = "spotted", Color = rgb(255, 210, 230), Accent = rgb(255, 120, 170) } },
	{ Id = "titan", Name = "Robo Ruins", Speed = 6_200_000_000, MinSpeed = 3_200_000_000, Mult = 50_000_000_000, Pool = { "robot" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary",  "Mythic", "Secret", "Divine", "Celestial" },
		Guardian = "megamech", Height = 46, Emoji = "\u{1F5FF}", Sky = rgb(170, 200, 160),
		Floor = { rgb(90, 110, 80), rgb(78, 96, 70) }, Wall = { rgb(80, 85, 75), rgb(65, 70, 62) }, Top = rgb(60, 140, 60), Props = "titan",
		Egg = { Style = "royal", Color = rgb(150, 160, 140), Accent = rgb(255, 210, 80) } },
	{ Id = "heaven", Name = "Hero Heights", Speed = 18_000_000_000, MinSpeed = 6_850_000_000, Mult = 700_000_000_000, Pool = { "hero" }, Rarities = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
		Guardian = "sunwing", Height = 34, Emoji = "\u{1F607}", Sky = rgb(255, 245, 210),
		Floor = { rgb(250, 248, 240), rgb(235, 230, 215) }, Wall = { rgb(255, 245, 225), rgb(240, 225, 190) }, Top = rgb(255, 210, 80), Props = "heaven",
		Egg = { Style = "royal", Color = rgb(255, 250, 235), Accent = rgb(255, 210, 80) } },
}

-- renda base de cada raridade (vezes o Mult da zona e o tamanho/mutação do ovo)
Config.RarityIncome = { Common = 1, Uncommon = 3, Rare = 8, Epic = 25, Legendary = 90, Mythic = 400, Secret = 2_500, Divine = 15_000, Celestial = 90_000 }
-- prêmio do Index (uma vez por bichinho descoberto): Cash = 100x a renda base; Speed = velocidade de presente.
-- v66: Speed = IndexShare (fatia do CAMINHO da zona até o portão da próxima), nunca menos que IndexSpeed (que só
--   vale nas zonas 1-2). Antes (v65) era IndexSpeed * Mult^0.75: crescia ~5,6x por zona e os portões ~4x, então da
--   zona 3 em diante 2-4 bichinhos novos abriam a zona seguinte e dava para zerar as 12 zonas em ~40 min
--   (tools/sim/progression.py). Agora a zona INTEIRA descoberta vale ~85% do caminho (o normal é achar uns 20-40%).
Config.IndexSpeed = { Common = 60, Uncommon = 130, Rare = 210, Epic = 360, Legendary = 750, Mythic = 2_000, Secret = 6_000, Divine = 20_000, Celestial = 75_000 }
Config.IndexShare = { Common = 0.01, Uncommon = 0.015, Rare = 0.02, Epic = 0.03, Legendary = 0.05, Mythic = 0.08, Secret = 0.12, Divine = 0.18, Celestial = 0.25 }

---------------------------------------------------------------------
-- Ovos, tamanho (Scale) e renda
---------------------------------------------------------------------
Config.NestsPerZone = 5
Config.NestRefill = 45 -- ninho roubado ganha ovo novo depois disso (além do reset de 5 min)
Config.Cycle = 270 -- segundos (alinhado ao relógio UTC: todos os servidores juntos)
Config.Night = 12 -- últimos segundos do ciclo: noite (todo mundo volta para casa, ovos crescem xNightGrowth)
Config.NightGrowth = 22
Config.StealHold = 0.6
-- ninguém segura um ovo mais que isso (segundos): ele volta para o ninho (anti-trapaça e anti-"ovo refém")
Config.MaxCarrySeconds = 180

-- tamanho do ovo: normal quase sempre; às vezes Grande/Enorme/Gigante (rende mais, demora mais, pesa mais)
function Config.RollScale(rng: Random): number
	local u = rng:NextNumber()
	if u < 0.002 then
		return rng:NextNumber(3.7, 6.7)
	elseif u < 0.017 then
		return rng:NextNumber(2.15, 3.7)
	elseif u < 0.097 then
		return rng:NextNumber(1.44, 2.15)
	end
	-- normal: ~0,75 a 1,35
	local g = math.sqrt(-2 * math.log(1 - rng:NextNumber() * 0.999)) * math.cos(2 * math.pi * rng:NextNumber())
	return math.clamp(math.exp(g * 0.15), 0.6, 1.4)
end

function Config.SizeLabel(s: number): string?
	if s >= 3.7 then
		return "GIANT"
	elseif s >= 2.15 then
		return "HUGE"
	elseif s >= 1.44 then
		return "BIG"
	end
	return nil
end

function Config.SizeFactor(s: number): number
	if s <= 5 then
		return s ^ 1.85
	end
	return 19.637875755794113 * (s / 5) ^ 1.2
end

function Config.MutationMult(mutation: string?): number
	local info = mutation and Config.MutationByName[mutation]
	return if info then info.Income else 1
end

function Config.BaseIncome(def, zoneIndex: number?): number
	local zone = Config.Zones[zoneIndex or 1] or Config.Zones[1]
	-- pequena variação por espécie (sempre igual para o mesmo bichinho)
	local h = 0
	for i = 1, #def.Id do
		h = (h * 31 + string.byte(def.Id, i)) % 1000
	end
	return (Config.RarityIncome[def.Rarity] or 1) * zone.Mult * (0.85 + (h / 1000) * 0.3)
end

function Config.PetIncome(def, s: number, mutation: string?, zoneIndex: number?): number
	return math.max(1, math.floor(Config.BaseIncome(def, zoneIndex) * Config.SizeFactor(s) * Config.MutationMult(mutation) + 0.5))
end

function Config.SellValue(def, s: number, mutation: string?, zoneIndex: number?): number
	return math.floor(Config.PetIncome(def, s, mutation, zoneIndex) * 100)
end

-- portão (Speed) da zona SEGUINTE; depois da última zona, um portão imaginário 3x acima
function Config.NextGate(zoneIndex: number?): number
	local index = if Config.Zones[zoneIndex or 1] then zoneIndex or 1 else 1
	local nextZone = Config.Zones[index + 1]
	if nextZone then
		return nextZone.Speed
	end
	return Config.Zones[index].Speed * 3
end

-- velocidade que o Index dá por um bichinho novo desta raridade descoberto nesta zona
function Config.IndexSpeedReward(rarity: string, zoneIndex: number?): number
	local zone = Config.Zones[zoneIndex or 1] or Config.Zones[1]
	local share = Config.IndexShare[rarity] or Config.IndexShare.Common
	local path = Config.NextGate(zoneIndex) - zone.Speed
	return math.floor(math.max(Config.IndexSpeed[rarity] or Config.IndexSpeed.Common, share * path))
end

function Config.IndexReward(def, zoneIndex: number?): (number, number)
	return math.floor(Config.BaseIncome(def, zoneIndex) * 100), Config.IndexSpeedReward(def.Rarity, zoneIndex)
end

function Config.GrowSeconds(def, s: number): number
	local rarity = Config.RarityByName[def.Rarity] or Config.Rarities[1]
	return math.floor(rarity.Grow * (if s >= 1 then s ^ 1.95 else s))
end

-- peso mostrado (kg): só para mostrar
function Config.WeightKg(def, s: number): number
	local rarity = Config.RarityByName[def.Rarity] or Config.Rarities[1]
	return math.floor((rarity.Size * 2) * s ^ 3 * 10 + 0.5) / 10
end

---------------------------------------------------------------------
-- Velocidade
---------------------------------------------------------------------
Config.StartSpeed = 10
Config.WalkCap = 150

function Config.WalkSpeed(speed: number): number
	return math.min(16 + 9.5 * math.log10(1 + math.max(speed, 0)), Config.WalkCap)
end

-- quanto o ovo pesa: ovo normal não atrasa; ovo gigante atrasa muito
function Config.CarryFactor(s: number): number
	local mass = 4 * s ^ 3
	return math.clamp(1 - 0.06 * math.log(math.max(mass / 4, 1), 2), 0.45, 1)
end

-- velocidade do guardião em relação a quem carrega (quanto mais fraco você for para a zona, mais rápido ele é)
-- velocidade para fugir com este ovo (o guardião corre igual a você)
function Config.EscapeSpeed(zone, s: number): number
	return zone.MinSpeed * math.max(s, 0.6) ^ 1.8
end
function Config.GuardianFactor(zone, speed: number, s: number): number
	local required = Config.EscapeSpeed(zone, s)
	local r = math.max(speed, 1) / required
	return math.clamp(r ^ -0.3, 0.6, 1.75)
end

---------------------------------------------------------------------
-- Esteira: cada nível tem um nome, quanto dá por passo (Gain) e o preço. Nível 1 destrava com o cercado nível 1.
---------------------------------------------------------------------
local TREAD_NAMES = { "Basic", "Bronze", "Silver", "Gold", "Ruby", "Emerald", "Sapphire", "Diamond", "Neon", "Lava", "Frost", "Cosmic", "Mythic", "Celestial", "Angelic", "Divine" }
local TREAD_COLORS = { rgb(120, 120, 130), rgb(205, 130, 70), rgb(200, 205, 215), rgb(255, 200, 50), rgb(230, 40, 70), rgb(40, 200, 110), rgb(50, 110, 240), rgb(150, 235, 255),
	rgb(255, 80, 220), rgb(255, 110, 30), rgb(120, 220, 255), rgb(130, 70, 230), rgb(255, 60, 120), rgb(255, 240, 160), rgb(255, 255, 255), rgb(255, 225, 90) }
-- v66: do nível 4 em diante cada nível custa TreadmillRamp vezes mais (5,5x -> 33x por nível; níveis 1-3 iguais).
--   Sem isso a renda (Mult 10x por zona) comprava a esteira rápido demais: mesmo SEM o Index as 12 zonas
--   acabavam em ~2 h (tools/sim/progression.py). Quem já comprou um nível continua com ele.
Config.TreadmillRamp = 6
Config.Treadmills = {}
for level = 1, #TREAD_NAMES do
	table.insert(Config.Treadmills, {
		Name = TREAD_NAMES[level],
		Color = TREAD_COLORS[level],
		Gain = math.floor(2 * 2.6 ^ (level - 1) + 0.5),
		Cost = if level == 1 then 0 else math.floor(2_500 * 5.5 ^ (level - 2) * Config.TreadmillRamp ^ math.max(0, level - 3)),
	})
end
Config.TreadmillUnlockPen = 1 -- a esteira fica trancada (holograma) até comprar o cercado nível 1
-- v66 SEQUÊNCIA DE ROUBOS: a cada Every ovos roubados seguidos sem o guardião pegar = Minutes da renda (mín. MinCash)
Config.StealStreak = { Every = 5, Minutes = 2, MinCash = 1_000 }
-- (v67) a sequência foi de before para after (o POR UM TRIZ soma 2 de uma vez): passou por um múltiplo de Every?
function Config.StreakBonusDue(before: number, after: number): boolean
	local every = Config.StealStreak.Every
	return after > before and math.floor(after / every) > math.floor(before / every)
end
-- v67 POR UM TRIZ: o guardião chegou a menos de Margin studs do alcance de pegar nos últimos Window segundos antes
-- de cruzar a SAFE = Minutes da renda base (mín. MinCash) e +1 na sequência de roubos.
-- Só conta com você a MinZ studs ou mais da SAFE: o guardião não passa de Z = 6, então parado na frente da linha
-- ele "chegava perto" sem nunca poder pegar (dava para ganhar sempre sem risco)
Config.CloseCall = { Margin = 6, Window = 3, Minutes = 1, MinCash = 500, MinZ = 8 }
function Config.CloseCallBonus(baseIncome: number?): number
	local C = Config.CloseCall
	return math.max(C.MinCash, math.floor((baseIncome or 0) * 60 * C.Minutes))
end
-- v67 MOMENTO ÉPICO (alarme + tela tremendo para o servidor inteiro) só para o que é raro de verdade:
-- Mítico ou melhor, GIANT, Rainbow, ovo dourado/abóbora. No máximo 1 a cada EpicCooldown s; o resto vira aviso roxo.
Config.EpicCooldown = 20
function Config.EpicEgg(rarity: string, scale: number?, mutation: string?, special: boolean?): boolean
	return (Config.RarityIndex[rarity] or 1) >= Config.RarityIndex.Mythic or Config.SizeLabel(scale or 1) == "GIANT"
		or mutation == "Rainbow" or special == true
end
-- (v67) quanto dura o ovo tremendo ao chocar (a animação roda na tela de cada jogador; o servidor só espera)
Config.HatchTime = 1.1
-- v66 ESTEIRA 2.0: correndo sem parar, +StreakStep a cada StreakEvery segundos (até +StreakMax).
-- Saiu da esteira por mais de StreakGrace segundos = a sequência zera.
Config.Treadmill = { StreakEvery = 30, StreakStep = 0.05, StreakMax = 0.5, StreakGrace = 4 }

-- TRILHAS (Trails Shop): multiplicam a velocidade ganha na esteira e deixam um rastro colorido atrás de você
Config.Trails = {
	{ Id = "grey", Name = "Pebble Trail", Mult = 1.5, Cost = 5_000, Color = rgb(190, 190, 200) },
	{ Id = "green", Name = "Leafy Trail", Mult = 2, Cost = 150_000, Color = rgb(90, 230, 90) },
	{ Id = "blue", Name = "Ocean Trail", Mult = 3, Cost = 8_000_000, Color = rgb(60, 150, 255) },
	{ Id = "purple", Name = "Galaxy Trail", Mult = 5, Cost = 900_000_000, Color = rgb(170, 90, 255) },
	{ Id = "gold", Name = "Golden Trail", Mult = 8, Cost = 120_000_000_000, Color = rgb(255, 205, 50) },
	{ Id = "rainbow", Name = "Rainbow Trail", Mult = 11, Cost = 20_000_000_000_000, Color = rgb(255, 110, 200) },
	{ Id = "divine", Name = "Starlight Trail", Mult = 15, Cost = 4_000_000_000_000_000, Color = rgb(255, 245, 190) },
	-- v67: Hidden = não está à venda; só da escada de convites (Config.InviteLadder). Mult igual à Pebble (sem vantagem)
	{ Id = "friend", Name = "Friendship Trail", Mult = 1.5, Cost = 0, Hidden = true, Color = rgb(255, 170, 220) },
}
Config.TrailById = {}
for _, trail in Config.Trails do
	Config.TrailById[trail.Id] = trail
end

-- BOOSTS (Boost Stand): duram Minutes; o preço é Price minutos da sua renda (mínimo MinPrice)
Config.Boosts = {
	{ Id = "Tread2", Name = "2x Treadmill", Icon = "\u{1F45F}", Minutes = 10, Price = 4, MinPrice = 2_000, Color = rgb(255, 80, 140) },
	{ Id = "Money2", Name = "2x Money", Icon = "\u{1F4B5}", Minutes = 10, Price = 6, MinPrice = 3_000, Color = rgb(90, 220, 80) },
	{ Id = "Grow2", Name = "2x Egg Growth", Icon = "\u{1F95A}", Minutes = 10, Price = 5, MinPrice = 2_500, Color = rgb(255, 200, 60) },
}

-- BAÚ GRÁTIS: a cada ChestEvery segundos dá ChestMinutes da sua renda + ChestStepMinutes de esteira em velocidade
Config.ChestEvery = 15 * 60
Config.ChestMinutes = 3
Config.ChestSpeedSteps = 120
Config.ChestMinCash = 1_000
Config.ChestMinSpeed = 500
-- o baú grátis só abre para quem está na nossa COMUNIDADE (grupo Critter Club Studios).
-- 0 = usa o grupo dono do jogo automaticamente. Se o jogo não for de um grupo, coloque aqui o número do grupo.
Config.CommunityId = 869887016 -- grupo "Critter Club Studios"

-- FUSE MACHINE: 3 bichinhos da MESMA raridade viram 1 ovo pronto de uma raridade acima (da zona mais alta dos 3)
Config.FuseCount = 3

---------------------------------------------------------------------
-- Cercado (Pen): cada nível = +1 vaga
---------------------------------------------------------------------
Config.PenStartSlots = 3
Config.PenLevels = {}
for level = 1, 15 do
	table.insert(Config.PenLevels, { Cost = math.floor(1_000 * 4.2 ^ (level - 1)) }) -- nível 1 = $1K (destrava a esteira)
end

-- primeiros minutos: o nível 1 do cercado (que libera a esteira) fica barato para a criança chegar lá rápido
Config.PenLevels[1].Cost = 250
-- o PRIMEIRO ovo roubado choca rapidinho (segundos)
Config.FirstEggSeconds = 5

-- PRESENTES POR TEMPO JOGADO. Cash = minutos da sua renda (mínimo MinCash).
-- O tempo jogado fica salvo: sair e voltar NÃO zera (antes dava para farmar). Zera depois de GiftResetHours fora.
Config.GiftResetHours = 3
Config.Gifts = {
	{ Minutes = 1, Cash = 2, MinCash = 150, Speed = 100 },
	{ Minutes = 3, Cash = 3, MinCash = 400, Speed = 250 },
	{ Minutes = 6, Cash = 4, MinCash = 1_000, Speed = 500 },
	{ Minutes = 10, Cash = 5, MinCash = 2_500, Speed = 1_000 },
	{ Minutes = 15, Cash = 6, MinCash = 5_000, Speed = 2_000 },
	{ Minutes = 20, Cash = 8, MinCash = 8_000, Speed = 3_500 },
	{ Minutes = 30, Cash = 10, MinCash = 15_000, Speed = 6_000 },
	{ Minutes = 45, Cash = 15, MinCash = 30_000, Speed = 12_000, Egg = true }, -- último: ovo da sorte (Raro ou melhor)
}

function Config.SlotCount(penLevel: number): number
	return Config.PenStartSlots + (penLevel or 0)
end

-- cor da cerca por nível: madeira, ferro, ouro, diamante
function Config.FenceColor(penLevel: number): Color3
	if penLevel >= 12 then
		return Color3.fromRGB(110, 230, 255)
	elseif penLevel >= 8 then
		return Color3.fromRGB(255, 200, 60)
	elseif penLevel >= 4 then
		return Color3.fromRGB(150, 155, 165)
	end
	return Color3.fromRGB(150, 90, 50)
end

Config.StartMoney = 0
Config.SaveEvery = 60
Config.DataStoreName = "EggRun_v1"

---------------------------------------------------------------------
-- SONS (áudios oficiais da Roblox, públicos). Troque o número por outro som do Creator Store se quiser.
---------------------------------------------------------------------
Config.Sounds = {
	Click = { Id = 15675059323, Volume = 0.5 },
	Pop = { Id = 15675055424, Volume = 0.6 },
	Grab = { Id = 15674975792, Volume = 0.8 },
	Delivered = { Id = 12222253, Volume = 0.7 },
	Caught = { Id = 12222242, Volume = 0.8 },
	Swing = { Id = 12222216, Volume = 0.6 },
	Hit = { Id = 12222046, Volume = 0.9 },
	Trap = { Id = 12222140, Volume = 1 },
	Crack = { Id = 12222005, Volume = 0.6 },
	Coin = { Id = 127645268874265, Volume = 0.5 },
	Alarm = { Id = 12221990, Volume = 0.8 },
	Night = { Id = 12221944, Volume = 0.8 },
	Error = { Id = 15675075163, Volume = 0.5 },
	Step = { Id = 15675032796, Volume = 0.15 },
	Music = { Id = 15675069601, Volume = 0.18 },
}

---------------------------------------------------------------------
-- PvP: todo mundo tem um TACO; acertar quem carrega um ovo derruba o ovo
-- no chão (vira "ovo solto": qualquer um pega). Completar o Index de uma zona dá o taco daquela zona (mais forte).
---------------------------------------------------------------------
Config.Bat = { Cooldown = 0.9, Range = 9, Force = 55, Stun = 0.8 }
Config.Bats = {} -- [0] = taco inicial; [z] = taco da zona z
for z = 0, 12 do
	Config.Bats[z] = {
		Zone = z,
		Name = if z == 0 then "Bat" else nil, -- o nome da zona entra depois (Zones ainda não tem nome aqui)
		Force = 55 * 1.1 ^ z,
		Stun = 0.8 + 0.06 * z,
		Range = 9 + 0.4 * z,
	}
end
for z, zone in Config.Zones do
	Config.Bats[z].Name = zone.Name .. " Bat"
	Config.Bats[z].Color = zone.Floor and zone.Floor[1] or Color3.fromRGB(150, 100, 60)
end
Config.Bats[0].Color = Color3.fromRGB(170, 120, 70)

-- ARMADILHA DE URSO: até 3 por jogador, não pode na SAFE ZONE nem a menos de MinZ studs dela, só pega quem está carregando ovo
-- v65: Stun 5 -> 3 s (para criança 5 s parada é muito) e MinZ: nada de armadilha colada na SAFE ZONE
Config.Trap = { Max = 3, Stun = 3, Life = 180, Radius = 3.2, MinZ = 30 }
-- ovo largado no chão: some e volta para o ninho depois disso
Config.LooseEggSeconds = 20
-- ovo derrubado mais perto que isso da SAFE ZONE volta para o ninho (não vira ovo solto)
Config.LooseMinZ = 30

---------------------------------------------------------------------
-- ROBUX. Crie os passes/produtos no Creator Hub e cole o número (Id) de cada um aqui.
-- Id = 0: o botão aparece mas avisa que ainda não foi configurado.
-- IMPORTANTE (regras da Roblox, 2026):
--   • Use passes/produtos criados NESTE jogo. Desde 30/05/2026 a Roblox não vende mais itens de OUTRO jogo.
--   • NADA pago pode dar prêmio sorteado (ovo aleatório etc.): seria "paid random item" (precisa mostrar as
--     chances + PolicyService) e no Brasil (ECA Digital) é proibido para menores de 18. Por isso o "Lucky Egg"
--     saiu e o Starter Pack não tem mais ovo sorteado. Se criar algo novo, que o jogador SAIBA o que vai ganhar.
---------------------------------------------------------------------
Config.Passes = {
	{ Key = "Money2", Id = 2001800303, Price = 399, Name = "2x Cash", Icon = "\u{1F4B5}", Desc = "Double cash from every critter, forever!", Color = rgb(70, 190, 70) },
	{ Key = "Grow2", Id = 0, Price = 299, Name = "2x Hatch Speed", Icon = "\u{1F95A}", Desc = "Eggs grow 2x faster forever", Color = rgb(255, 180, 40) },
	{ Key = "VIP", Id = 2002610263, Price = 349, Name = "VIP", Icon = "\u{1F451}", Desc = "+20% cash, 2x daily reward, VIP tag and chat tag!", Color = rgb(255, 210, 60) },
}
Config.Products = {
	{ Key = "Speed1", Id = 3718379687, Price = 35, Name = "+10K Speed", Icon = "\u{1F45F}", Desc = "Instant! (resets on Rebirth)", Speed = 10_000, Color = rgb(255, 80, 140) },
	{ Key = "Speed2", Id = 3718379999, Price = 99, Name = "+175K Speed", Icon = "\u{1F45F}", Desc = "Instant! (resets on Rebirth)", Speed = 175_000, Color = rgb(255, 80, 140) },
	{ Key = "Speed3", Id = 3718380159, Price = 279, Name = "+2M Speed", Icon = "\u{1F45F}", Desc = "Instant! (resets on Rebirth)", Speed = 2_000_000, Color = rgb(255, 80, 140) },
	{ Key = "Speed4", Id = 0, Price = 799, Name = "+50M Speed", Icon = "\u{1F45F}", Desc = "Instant! (resets on Rebirth)", Speed = 50_000_000, Color = rgb(255, 80, 140) },
	{ Key = "GrowAll", Id = 3715364797, Price = 29, Name = "Hatch All Now", Icon = "\u{23E9}", Desc = "All your eggs hatch right now!", Color = rgb(255, 200, 60) },
	{ Key = "Cash", Id = 0, Price = 79, Name = "Cash Pack", Icon = "\u{1F4B0}", Desc = "1 hour of your income (min $50K)", Color = rgb(90, 220, 80) },
	-- Starter Pack: só coisas CERTAS (nada sorteado). Ver o comentário de "Robux" acima.
	{ Key = "Starter", Id = 3715364696, Price = 99, Name = "Starter Pack", Icon = "\u{1F381}", Desc = "$50K + 25K Speed + 2x Cash for 30 min. One time only!", OneTime = true, Cash = 50_000, Speed = 25_000, BoostMinutes = 30, Color = rgb(255, 120, 40) },
}
table.insert(Config.Products, { Key = "Money2Boost", Id = 3715364714, Price = 49, Name = "2x Cash Boost", Icon = "\u{1F4B5}", Desc = "2x cash for 30 minutes!", Color = rgb(90, 220, 80) })
Config.VIPCash = 0.2 -- VIP: +20% de dinheiro
Config.PassByKey = {}
for _, info in Config.Passes do
	Config.PassByKey[info.Key] = info
end
-- ofertas na hora certa (no máximo uma a cada OfferCooldown segundos)
Config.OfferCooldown = 600 -- 10 min (criança: nada de oferta toda hora)
Config.ProductByKey = {}
for _, info in Config.Products do
	Config.ProductByKey[info.Key] = info
end

---------------------------------------------------------------------
-- VOLTAR TODO DIA
---------------------------------------------------------------------
-- prêmio diário (sequência de 7 dias; perdeu um dia = volta para o dia 1, menos com escudo). Cash = minutos da sua renda.
Config.Daily = {
	{ Minutes = 5, MinCash = 2_000, Speed = 200 },
	{ Minutes = 8, MinCash = 4_000, Speed = 400 },
	{ Minutes = 10, MinCash = 6_000, Speed = 800 },
	{ Minutes = 15, MinCash = 10_000, Speed = 1_500 },
	{ Minutes = 20, MinCash = 15_000, Speed = 3_000 },
	{ Minutes = 25, MinCash = 25_000, Speed = 6_000 },
	{ Minutes = 60, MinCash = 50_000, Speed = 15_000, Egg = true }, -- dia 7: ovo da sorte
}
-- v67 DIA DO BRASIL: o "dia" do jogo (diário, missões, ovo da amizade, convites, fim de semana) vira à
--   meia-noite de Brasília. Antes era o dia UTC: tudo zerava às 21h, com a criança jogando de noite.
--   (o Brasil não tem mais horário de verão, então -3 o ano todo)
Config.DayOffsetHours = -3
function Config.Day(t: number): number
	return (t + Config.DayOffsetHours * 3600) // 86400
end
-- quando começa o próximo dia do jogo (segundos UTC)
function Config.NextDayAt(t: number): number
	return (Config.Day(t) + 1) * 86400 - Config.DayOffsetHours * 3600
end
-- v67 ESCUDO DA SEQUÊNCIA (Streak Saver): cada semana completa (dia 7) dá 1 escudo (no máximo MaxSavers).
--   Perdeu SÓ 1 dia = o escudo segura a sequência. Perdeu mais = volta para o dia 1 (o calendário não volta).
Config.MaxSavers = 2
-- próximo dia da sequência. gap = hoje - último dia pego (1 = ontem). Devolve (dia 1..7, escudos depois, usou escudo?)
function Config.DailyNext(gap: number, streak: number, savers: number): (number, number, boolean)
	local week = #Config.Daily
	local used = false
	local nextStreak = 1
	if gap == 1 then
		nextStreak = (streak or 0) % week + 1
	elseif gap == 2 and (savers or 0) > 0 then
		nextStreak = (streak or 0) % week + 1
		savers -= 1
		used = true
	end
	savers = savers or 0
	if nextStreak == week then
		savers = math.min(Config.MaxSavers, savers + 1)
	end
	return nextStreak, savers, used
end
-- v67 CALENDÁRIO DE 28 DIAS: conta TODOS os dias pegos (não zera). Tudo garantido, nada sorteado.
--   Boost = minutos de cada boost | Critter = ovo PRONTO de um bichinho exclusivo (Critters.luau, World "calendar")
--   Title = título "Calendar Champ" | Mark = 📅 na etiqueta. Da 2ª volta em diante os bichinhos vêm Gold.
Config.CalendarDays = 28
Config.CalendarGoldAfter = 1 -- voltas completas para os bichinhos virem com a mutação Gold
Config.Calendar = {
	[3] = { Boost = { Money2 = 15 } },
	[7] = { Critter = "calendarcat" },
	[14] = { Critter = "sunnypup" },
	[21] = { Boost = { Money2 = 30, Tread2 = 30 }, Title = true },
	[28] = { Critter = "crowncritter", Mark = true },
}
-- dia do calendário (1..28) do total de dias pegos (0 = ainda nenhum)
function Config.CalendarDay(total: number): number
	if (total or 0) <= 0 then
		return 0
	end
	return (total - 1) % Config.CalendarDays + 1
end
-- mutação do bichinho do calendário no dia "total" (2ª volta em diante = Gold)
function Config.CalendarMutation(total: number): string?
	return if (total - 1) // Config.CalendarDays >= Config.CalendarGoldAfter then "Gold" else nil
end
-- REBIRTH: zera dinheiro, velocidade, esteira, trilhas E OS BICHINHOS/OVOS; mantém cercado e Index.
-- Cada rebirth = +100% dinheiro e +50% velocidade na esteira para sempre.
-- v66: RebirthTread 0.25 -> 0.5. Com +25% quem fazia rebirth assim que podia chegava na última zona DEPOIS de
--   quem nunca fazia (a velocidade do Index não volta); com +50% chega ~25-35% antes (tools/sim/progression.py).
Config.RebirthBase = 1_000_000
Config.RebirthGrowth = 25
Config.RebirthMoney = 1 -- cada rebirth = +100% de dinheiro para sempre (o rebirth leva os bichinhos)
Config.RebirthTread = 0.5
function Config.RebirthCost(rebirths: number): number
	return Config.RebirthBase * Config.RebirthGrowth ^ (rebirths or 0)
end
-- ganho offline: os bichinhos rendem uma parte enquanto você está fora (até OfflineMaxHours)
Config.OfflineRate = 0.15
Config.OfflineMaxHours = 12
-- amigos no mesmo servidor: +25% de dinheiro cada (máx. +100%)
Config.FriendBoost = 0.25 -- +25% de dinheiro por amigo no servidor
Config.FriendBoostMax = 1 -- até +100%
Config.FriendEggSeconds = 120 -- jogar 2 min com amigo = ovo da amizade (1 por dia)
-- v65: CONVITE (botão "Invite"): quem entra pelo convite de um amigo ganha New*, e quem convidou ganha
-- Inviter* (minutos da renda, mínimo InviterMinCash) se estiver no mesmo servidor. 1 vez por amigo.
-- O prêmio de quem convidou sai depois que o amigo jogou 5 min e roubou 1 ovo (no máximo PerDay por dia).
Config.Invite = { NewCash = 2_000, NewSpeed = 500, InviterMinutes = 15, InviterMinCash = 5_000, InviterSpeed = 1_000, PerDay = 5 }
-- v67 ESCADA DE CONVITES: conta os amigos DIFERENTES que entraram pelo seu convite e jogaram de verdade (5 min +
--   1 ovo roubado). Tudo garantido, nada sorteado, nada pago. Quem convidou estava fora? O crédito fica guardado
--   (DataStore InviteCreditStore, até InviteCreditMax) e chega quando ele entra. A escada conta todos; o dinheiro
--   continua no máximo Invite.PerDay por dia. Id = nome salvo (NUNCA mude) | Count = amigos
--   Trail = trilha escondida (volta depois do Rebirth) | Critter = ovo PRONTO de um exclusivo (World "friend", Keep)
--   Title = título "Squad Leader" + placa dourada no cercado
Config.InviteLadder = {
	{ Id = "trail", Count = 1, Trail = "friend" },
	{ Id = "palpup", Count = 3, Critter = "palpup" },
	{ Id = "squad", Count = 5, Title = "Squad" },
	{ Id = "panda", Count = 10, Critter = "partypanda" },
}
Config.InviteCreditStore = "InviteCredit_v1"
Config.InviteCreditMax = 20
-- "Mostrar pros amigos" (cartão de Lendário+ ou com mutação): 1 convite a cada ShareGap s; quem entra por ele vê a
-- seta no cercado do amigo por VisitSeconds s. Compartilhar não dá prêmio.
Config.ShareGap = 120
Config.VisitSeconds = 30
-- quantos amigos contam (chaves da tabela Referred: { ["UserId"] = true })
function Config.InviteCount(referred: any): number
	local count = 0
	if type(referred) == "table" then
		for _ in referred do
			count += 1
		end
	end
	return count
end
-- degraus que o número de amigos já alcançou e ainda não foram entregues (got = { [Id] = true })
function Config.LadderDue(count: number, got: any): { any }
	local due = {}
	for _, step in Config.InviteLadder do
		if (count or 0) >= step.Count and not (type(got) == "table" and got[step.Id]) then
			table.insert(due, step)
		end
	end
	return due
end
-- próximo degrau que falta (para "2/3 → Pal Pup"); nil = escada completa
function Config.LadderNext(count: number): any
	for _, step in Config.InviteLadder do
		if (count or 0) < step.Count then
			return step
		end
	end
	return nil
end
-- EVENTO DA SORTE: a cada LuckyEvery segundos (relógio UTC), durante LuckyLength, raros aparecem x3 nos ninhos.
-- Fim de semana (sáb/dom de Brasília, v67; antes UTC): dinheiro x2 para todo mundo.
-- BICHO DA SEMANA: muda toda segunda (UTC). Na zona onde ele vive, a raridade dele pesa WeeklyRarityMult vezes mais
-- (Config.WeeklyBoostFor) e, dentro da raridade, ele sai WeeklyMult vezes mais que os outros.
-- v66: rodízio de 24 semanas com Lendários/Míticos de TODAS as 12 zonas (alternando começo/meio/fim do mapa).
--   Antes eram 5 bichinhos da zona 1 sozinhos na raridade (Divino/Celestial/Secreto): o x5 não mudava nada.
--   Agora o da semana sai ~3-9x mais na zona dele (python3 tools/sim/progression.py --weekly).
Config.WeeklyCritters = {
	"sunwing", "volcanoram", "glaciaroo", "cosmodragon", "ghostcaptain", "tideunicorn", "brontoboom", "cyberwolf",
	"glacierunicorn", "cottonphoenix", "voidicorn", "supergelatogato", "krakenlord", "starlightunicorn", "spinoking", "deepkraken",
	"blizzardwyrm", "nebuladragon", "stormhorn", "infernobeast", "treasureturtle", "chocodrake", "megamech", "megamozzarella",
}
Config.WeeklyMult = 5
Config.WeeklyRarityMult = 3
function Config.WeeklyCritter(t: number): string
	local week = (t // 86400 + 3) // 7 -- semanas começando na segunda
	return Config.WeeklyCritters[(week % #Config.WeeklyCritters) + 1]
end
-- quanto o peso da RARIDADE deste bichinho sobe no sorteio do ninho (só na semana dele; senão 1).
-- O servidor só aplica na zona onde o bichinho existe (poolFor da zona tem ele).
function Config.WeeklyBoostFor(def, t: number?): number
	if def and def.Id == Config.WeeklyCritter(t or os.time()) then
		return Config.WeeklyRarityMult
	end
	return 1
end
function Config.WeeklyEnds(t: number): number
	local week = (t // 86400 + 3) // 7
	return (week + 1) * 7 * 86400 - 3 * 86400
end
Config.LuckyEvery = 30 * 60
Config.LuckyLength = 3 * 60
Config.LuckyMult = 3

---------------------------------------------------------------------
-- v65: ATUALIZAÇÃO DA SEMANA + FESTÃO (UPDATE PARTY)
-- Escolha um dia e hora fixos e solte as atualizações SEMPRE nesse horário. A tela mostra a contagem
-- ("UPDATE in 2d 5h") e, na hora, começa o FESTÃO sozinho em todos os servidores (você não precisa estar
-- online): ovos raros x PartyLuck nos ninhos, ovo dourado a cada PartyGoldenEvery segundos e ovos
-- crescendo x PartyGrowth no cercado, por PartyMinutes minutos.
---------------------------------------------------------------------
Config.Update = {
	WeekDay = 7, -- 1 = domingo, 2 = segunda ... 7 = sábado
	HourBR = 14, -- hora de Brasília (UTC-3)
	Minute = 0,
	PartyMinutes = 30,
	PartyLuck = 5,
	PartyGrowth = 2,
	PartyGoldenEvery = 180,
}

-- devolve início e fim do Festão de agora (se está acontecendo) ou do próximo (t = segundos UTC)
function Config.PartyWindow(t: number): (number, number)
	local u = Config.Update
	local length = u.PartyMinutes * 60
	local week = 7 * 86400
	local day = t // 86400
	local sunday = (day - (day + 4) % 7) * 86400 -- 1/1/1970 foi quinta-feira
	local start = sunday + (u.WeekDay - 1) * 86400 + (u.HourBR + 3) * 3600 + u.Minute * 60 - week
	while start + length <= t do
		start += week
	end
	return start, start + length
end

---------------------------------------------------------------------
-- v66: ADMIN ABUSE (botão "Admin" no Menu, só para admins): eventos ao vivo em TODOS os servidores.
-- Admins: o dono do jogo; se o jogo for de um grupo, quem tem cargo >= AdminMinRank (254 = admin, 255 = dono);
-- e quem estiver em Admins (UserIds, ex.: { 12345678 }).
---------------------------------------------------------------------
Config.Admins = {}
Config.AdminMinRank = 254
Config.AdminAbuse = { LuckMult = 10, Minutes = 15, GoldenCount = 5, PumpkinCount = 3 }

---------------------------------------------------------------------
-- v65: EVENTO DE HALLOWEEN (de From até To, segundos UTC; 0h de Brasília)
--   • Ovo de Abóbora a cada PumpkinEvery segundos numa zona que dá para alcançar (bichinhos de Halloween)
--   • Mutação Spooky (x3) nos ninhos: SpookyChance % de chance
--   • DOCES: cada ovo roubado = CandyPerEgg, Ovo de Abóbora = CandyPerPumpkin. A Loja de Doces troca doces
--     por bichinhos exclusivos (sempre o mesmo bichinho: nada sorteado)
--   • Abóboras decorando o hub
-- No Studio, TestInStudio = true liga o evento antes da data (para testar).
---------------------------------------------------------------------
Config.Halloween = {
	From = 1792206000, -- 17/10/2026 00:00 (Brasília)
	To = 1793674800, -- 03/11/2026 00:00 (Brasília)
	TestInStudio = true,
	PumpkinEvery = 240,
	SpookyChance = 4,
	CandyPerEgg = 1,
	CandyPerPumpkin = 5,
	-- Loja de Doces: Critter = Id do bichinho (Critters.luau), Mut = mutação garantida (opcional)
	Shop = {
		{ Critter = "pumpkinopinguino", Cost = 15 },
		{ Critter = "pumpkat", Cost = 40 },
		{ Critter = "batwing", Cost = 120 },
		{ Critter = "vampiropepperoni", Mut = "Spooky", Cost = 300 },
	},
}

-- MISSÕES DO DIA (zeram à meia-noite de Brasília, Config.Day). Cash = minutos da sua renda (mínimo MinCash)
Config.Quests = {
	{ Key = "Steal", Name = "Steal 5 eggs", Icon = "\u{1F95A}", Goal = 5, Minutes = 5, MinCash = 3_000, Speed = 300 },
	{ Key = "Hatch", Name = "Hatch 3 eggs", Icon = "\u{1F423}", Goal = 3, Minutes = 5, MinCash = 3_000, Speed = 300 },
	{ Key = "Steps", Name = "Run 300 treadmill steps", Icon = "\u{1F45F}", Goal = 300, Minutes = 8, MinCash = 5_000, Speed = 600 },
	{ Key = "Hit", Name = "Make 2 thieves drop their egg", Icon = "\u{1F3CF}", Goal = 2, Minutes = 10, MinCash = 8_000, Speed = 800 },
}

return Config
