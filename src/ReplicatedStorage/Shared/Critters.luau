--[[
	LISTA DE BICHINHOS (critters)

	Cada bichinho tem:
	  Id       -> nome interno (sem espaço, NUNCA mude depois de lançar)
	  Name     -> nome que aparece no jogo
	  Rarity   -> Common, Uncommon, Rare, Epic, Legendary, Mythic ou Secret
	  Price    -> valor do bichinho (vender devolve Config.CritterSellRefund disso)
	  Income   -> dinheiro por segundo na sua base
	  Body     -> formato: "blob", "bunny", "cat", "bird", "toad", "dino", "dragon", "unicorn"
	  Color    -> cor do corpo
	  Accent   -> cor dos detalhes (orelhas, asas, espinhos...)
	  Material -> (opcional) "Neon", "Ice", "Glass", "Foil", "CrackedLava", "Slate"...
	  Glow / Sparkles / Crown / Float -> (opcional) efeitos especiais
	  Special  -> (opcional) montagem épica: "phoenix", "frostmammoth", "lavabeast",
	              "stormram", "voiddragon", "celestial", "kraken", "sun"
	  EyeColor -> (opcional) cor do olho brilhante dos bichos bravos
	  Palette  -> (opcional) 4 cores das penas da fênix
	  Fire     -> (opcional) chamas de verdade no corpo
	  RebirthRequired -> (opcional) só sai dos ovos para quem já tem esse rebirth
	  Hint     -> (opcional) dica misteriosa no álbum enquanto o jogador não descobriu
	  World    -> (opcional) mundo de onde sai: "candy", "frost", "lava", "reef", "galaxy" (sem World = Meadow)

	Pra adicionar um bichinho novo é só copiar uma linha, mudar o Id e os valores.
]]

local rgb = Color3.fromRGB

local Critters = {}

Critters.List = {
	-- COMMON
	{ Id = "blobby", Name = "Blobby", Rarity = "Common", Price = 25, Income = 1, Body = "blob", Color = rgb(120, 190, 255), Accent = rgb(80, 140, 230) },
	{ Id = "pebbo", Name = "Pebbo", Rarity = "Common", Price = 60, Income = 2, Body = "blob", Color = rgb(150, 140, 130), Accent = rgb(110, 100, 95), Material = "Slate" },
	{ Id = "squeak", Name = "Squeak", Rarity = "Common", Price = 120, Income = 4, Body = "cat", Color = rgb(255, 190, 210), Accent = rgb(255, 140, 170) },
	{ Id = "mossy", Name = "Mossy", Rarity = "Common", Price = 200, Income = 6, Body = "toad", Color = rgb(120, 180, 80), Accent = rgb(80, 130, 50) },
	{ Id = "nibbles", Name = "Nibbles", Rarity = "Common", Price = 300, Income = 9, Body = "bunny", Color = rgb(215, 180, 130), Accent = rgb(255, 190, 200) },

	-- UNCOMMON
	{ Id = "fluffo", Name = "Fluffo", Rarity = "Uncommon", Price = 600, Income = 16, Body = "bunny", Color = rgb(250, 250, 250), Accent = rgb(255, 160, 200) },
	{ Id = "chirpy", Name = "Chirpy", Rarity = "Uncommon", Price = 900, Income = 24, Body = "bird", Color = rgb(255, 225, 80), Accent = rgb(255, 150, 40) },
	{ Id = "toadle", Name = "Toadle", Rarity = "Uncommon", Price = 1_300, Income = 34, Body = "toad", Color = rgb(60, 200, 190), Accent = rgb(30, 140, 150) },
	{ Id = "leafy", Name = "Leafy", Rarity = "Uncommon", Price = 2_000, Income = 50, Body = "dino", Color = rgb(110, 210, 90), Accent = rgb(250, 220, 90) },

	-- RARE
	{ Id = "zapkit", Name = "Zapkit", Rarity = "Rare", Price = 5_000, Income = 110, Body = "cat", Color = rgb(255, 220, 40), Accent = rgb(60, 60, 60), Glow = true },
	{ Id = "frostbun", Name = "Frostbun", Rarity = "Rare", Price = 8_000, Income = 170, Body = "bunny", Color = rgb(170, 225, 255), Accent = rgb(230, 250, 255), Material = "Ice" },
	{ Id = "embertail", Name = "Embertail", Rarity = "Rare", Price = 12_000, Income = 250, Body = "cat", Color = rgb(255, 120, 50), Accent = rgb(255, 220, 80), Glow = true },
	{ Id = "shellbo", Name = "Shellbo", Rarity = "Rare", Price = 16_000, Income = 330, Body = "dino", Color = rgb(90, 190, 170), Accent = rgb(170, 110, 60) },

	-- EPIC
	{ Id = "nebulowl", Name = "Nebulowl", Rarity = "Epic", Price = 45_000, Income = 800, Body = "bird", Color = rgb(90, 50, 160), Accent = rgb(120, 220, 255), Glow = true, Sparkles = true },
	{ Id = "prismfox", Name = "Prismfox", Rarity = "Epic", Price = 70_000, Income = 1_200, Body = "cat", Color = rgb(255, 170, 230), Accent = rgb(140, 240, 255), Material = "Glass" },
	{ Id = "voltpup", Name = "Voltpup", Rarity = "Epic", Price = 100_000, Income = 1_700, Body = "cat", Color = rgb(60, 110, 255), Accent = rgb(120, 255, 255), Glow = true },
	{ Id = "sugardrake", Name = "Sugardrake", Rarity = "Epic", Price = 140_000, Income = 2_300, Body = "dragon", Color = rgb(255, 180, 210), Accent = rgb(160, 230, 255) },

	-- LEGENDARY (montagens especiais: veja CritterBuilder)
	{ Id = "sunwing", Name = "Sunwing", Rarity = "Legendary", Price = 450_000, Income = 6_500, Body = "blob", Special = "phoenix", Color = rgb(255, 200, 50), Accent = rgb(255, 120, 30), EyeColor = rgb(255, 120, 20), Glow = true, Sparkles = true },
	{ Id = "glaciamoth", Name = "Glaciamoth", Rarity = "Legendary", Price = 750_000, Income = 10_000, Body = "blob", Special = "frostmammoth", Color = rgb(200, 235, 255), Accent = rgb(120, 230, 255), Material = "Ice", EyeColor = rgb(80, 220, 255), Glow = true },
	{ Id = "magmaroo", Name = "Magmaroo", Rarity = "Legendary", Price = 1_100_000, Income = 14_000, Body = "dino", Special = "lavabeast", Color = rgb(95, 35, 25), Accent = rgb(255, 120, 30), Material = "CrackedLava", EyeColor = rgb(255, 210, 50), Glow = true, Sparkles = true },
	{ Id = "stormhorn", Name = "Stormhorn", Rarity = "Legendary", Price = 1_600_000, Income = 20_000, Body = "blob", Special = "stormram", Color = rgb(50, 75, 190), Accent = rgb(255, 225, 60), EyeColor = rgb(255, 235, 80), Glow = true, Sparkles = true },

	-- MYTHIC
	{ Id = "voidra", Name = "Voidra", Rarity = "Mythic", Price = 6_000_000, Income = 60_000, Body = "blob", Special = "voiddragon", Color = rgb(32, 20, 52), Accent = rgb(190, 80, 255), EyeColor = rgb(210, 110, 255), Glow = true, Sparkles = true },
	{ Id = "prismacorn", Name = "Prismacorn", Rarity = "Mythic", Price = 10_000_000, Income = 95_000, Body = "unicorn", Special = "celestial", Color = rgb(255, 255, 255), Accent = rgb(255, 210, 60), Glow = true, Sparkles = true, SparkleColors = "rainbow" },
	{ Id = "krakenox", Name = "Krakenox", Rarity = "Mythic", Price = 15_000_000, Income = 140_000, Body = "blob", Special = "kraken", Color = rgb(55, 28, 115), Accent = rgb(255, 90, 200), EyeColor = rgb(90, 240, 255), Glow = true, Sparkles = true },

	-- SECRET
	{ Id = "cosmoking", Name = "Cosmo King", Rarity = "Secret", Price = 150_000_000, Income = 1_000_000, Body = "blob", Color = rgb(70, 30, 140), Accent = rgb(255, 210, 60), Material = "Neon", Crown = true, Glow = true, Sparkles = true, Float = true, Hint = "A king born among the stars... hides in Cosmic Eggs." },
	{ Id = "goldengoober", Name = "Golden Goober", Rarity = "Secret", Price = 250_000_000, Income = 1_600_000, Body = "blob", Color = rgb(255, 200, 50), Accent = rgb(255, 90, 90), Material = "Foil", Crown = true, Glow = true, Sparkles = true, Hint = "Loves gold. Hides in Cosmic Eggs." },

	-- EXCLUSIVOS DE REBIRTH (aparecem na esteira para todos, mas só compra quem tem o rebirth; roubar pode!)
	{ Id = "aurorawing", Name = "Aurorawing", Rarity = "Legendary", RebirthRequired = 1, Price = 2_500_000, Income = 30_000, Body = "blob", Special = "phoenix", Color = rgb(120, 220, 255), Accent = rgb(200, 120, 255), EyeColor = rgb(170, 90, 255), Palette = { rgb(210, 255, 255), rgb(120, 230, 255), rgb(170, 140, 255), rgb(255, 120, 230) }, Glow = true, Sparkles = true, Hint = "Reborn once, the sky lights up..." },
	{ Id = "emberdrake", Name = "Emberdrake", Rarity = "Mythic", RebirthRequired = 2, Price = 22_000_000, Income = 200_000, Body = "blob", Special = "voiddragon", Color = rgb(70, 20, 15), Accent = rgb(255, 120, 30), EyeColor = rgb(255, 210, 60), Material = "CrackedLava", Fire = true, Glow = true, Sparkles = true, Hint = "Reborn twice, fire answers." },
	{ Id = "tidalox", Name = "Tidalox", Rarity = "Mythic", RebirthRequired = 3, Price = 35_000_000, Income = 300_000, Body = "blob", Special = "kraken", Color = rgb(20, 90, 130), Accent = rgb(80, 255, 220), EyeColor = rgb(255, 240, 120), Glow = true, Sparkles = true, Hint = "Reborn three times, the ocean rises." },
	{ Id = "solarking", Name = "Solar King", Rarity = "Secret", RebirthRequired = 5, Price = 500_000_000, Income = 3_000_000, Body = "blob", Special = "sun", Color = rgb(255, 170, 40), Accent = rgb(255, 240, 150), Material = "Neon", Crown = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "Only the 5x reborn meet the Sun." },

	-- CANDY KINGDOM (World = "candy"): saem do Gumdrop Egg e do Lollipop Egg
	{ Id = "gummybun", World = "candy", Name = "Gummy Bun", Rarity = "Uncommon", Price = 4_800_000, Income = 8_000, Body = "bunny", Color = rgb(255, 110, 175), Accent = rgb(255, 230, 120), Material = "Glass" },
	{ Id = "lollicat", World = "candy", Name = "Lollicat", Rarity = "Rare", Price = 12_000_000, Income = 20_000, Body = "cat", Color = rgb(255, 200, 230), Accent = rgb(110, 215, 255) },
	{ Id = "cupcaketoad", World = "candy", Name = "Cupcake Toad", Rarity = "Epic", Price = 27_000_000, Income = 45_000, Body = "toad", Color = rgb(250, 215, 165), Accent = rgb(255, 105, 170), Sparkles = true },
	{ Id = "cottonphoenix", World = "candy", Name = "Cotton Phoenix", Rarity = "Legendary", Price = 66_000_000, Income = 110_000, Body = "blob", Special = "phoenix", Color = rgb(255, 190, 230), Accent = rgb(150, 220, 255), EyeColor = rgb(255, 90, 180), Palette = { rgb(255, 255, 255), rgb(255, 200, 235), rgb(170, 225, 255), rgb(255, 150, 210) }, Glow = true, Sparkles = true },
	{ Id = "chocodrake", World = "candy", Name = "Choco Drake", Rarity = "Mythic", Price = 240_000_000, Income = 400_000, Body = "blob", Special = "voiddragon", Color = rgb(95, 55, 30), Accent = rgb(255, 170, 210), EyeColor = rgb(255, 120, 200), Glow = true, Sparkles = true },
	{ Id = "sugarqueen", World = "candy", Name = "Sugar Queen", Rarity = "Secret", Price = 3_000_000_000, Income = 5_000_000, Body = "blob", Color = rgb(255, 150, 205), Accent = rgb(255, 255, 255), Material = "Neon", Crown = true, Float = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "The sweetest ruler... hides in Lollipop Eggs." },

	-- FROST PEAKS (World = "frost"): Snowball Egg e Glacier Egg
	{ Id = "snowpup", World = "frost", Name = "Snow Pup", Rarity = "Uncommon", Price = 28_800_000, Income = 48_000, Body = "cat", Color = rgb(240, 245, 255), Accent = rgb(150, 200, 255) },
	{ Id = "penguino", World = "frost", Name = "Penguino", Rarity = "Rare", Price = 72_000_000, Income = 120_000, Body = "bird", Color = rgb(40, 45, 62), Accent = rgb(255, 195, 60) },
	{ Id = "frostfox", World = "frost", Name = "Frost Fox", Rarity = "Epic", Price = 162_000_000, Income = 270_000, Body = "cat", Color = rgb(195, 232, 255), Accent = rgb(255, 255, 255), Material = "Ice", Glow = true },
	{ Id = "yetimammoth", World = "frost", Name = "Yeti Mammoth", Rarity = "Legendary", Price = 396_000_000, Income = 660_000, Body = "blob", Special = "frostmammoth", Color = rgb(248, 248, 252), Accent = rgb(170, 215, 255), EyeColor = rgb(90, 200, 255), Glow = true, Sparkles = true },
	{ Id = "blizzardwyrm", World = "frost", Name = "Blizzard Wyrm", Rarity = "Mythic", Price = 1_440_000_000, Income = 2_400_000, Body = "blob", Special = "voiddragon", Color = rgb(165, 215, 255), Accent = rgb(255, 255, 255), Material = "Ice", EyeColor = rgb(80, 220, 255), Glow = true, Sparkles = true },
	{ Id = "auroraking", World = "frost", Name = "Aurora King", Rarity = "Secret", Price = 18_000_000_000, Income = 30_000_000, Body = "blob", Color = rgb(110, 255, 215), Accent = rgb(200, 120, 255), Material = "Neon", Crown = true, Float = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "Dances in the northern lights... hides in Glacier Eggs." },

	-- LAVA LAND (World = "lava"): Ember Egg e Magma Egg
	{ Id = "emberpup", World = "lava", Name = "Ember Pup", Rarity = "Uncommon", Price = 172_800_000, Income = 288_000, Body = "cat", Color = rgb(90, 40, 30), Accent = rgb(255, 130, 40), Glow = true },
	{ Id = "magmatoad", World = "lava", Name = "Magma Toad", Rarity = "Rare", Price = 432_000_000, Income = 720_000, Body = "toad", Color = rgb(70, 30, 25), Accent = rgb(255, 100, 20), Material = "CrackedLava" },
	{ Id = "cinderbird", World = "lava", Name = "Cinder Bird", Rarity = "Epic", Price = 972_000_000, Income = 1_620_000, Body = "bird", Color = rgb(255, 90, 30), Accent = rgb(255, 220, 60), Fire = true, Glow = true },
	{ Id = "volcanoram", World = "lava", Name = "Volcano Ram", Rarity = "Legendary", Price = 2_376_000_000, Income = 3_960_000, Body = "blob", Special = "stormram", Color = rgb(60, 25, 20), Accent = rgb(255, 120, 30), EyeColor = rgb(255, 200, 50), Glow = true, Sparkles = true },
	{ Id = "infernobeast", World = "lava", Name = "Inferno Beast", Rarity = "Mythic", Price = 8_640_000_000, Income = 14_400_000, Body = "dino", Special = "lavabeast", Color = rgb(40, 15, 10), Accent = rgb(255, 70, 20), Material = "CrackedLava", EyeColor = rgb(255, 230, 60), Fire = true, Glow = true, Sparkles = true },
	{ Id = "lavalord", World = "lava", Name = "Lava Lord", Rarity = "Secret", Price = 108_000_000_000, Income = 180_000_000, Body = "blob", Color = rgb(255, 90, 20), Accent = rgb(255, 230, 90), Material = "CrackedLava", Crown = true, Float = true, Fire = true, Glow = true, Sparkles = true, Hint = "Sleeps inside the volcano... hides in Magma Eggs." },

	-- CORAL REEF (World = "reef"): Pearl Egg e Coral Egg
	{ Id = "bubblefin", World = "reef", Name = "Bubblefin", Rarity = "Uncommon", Price = 1_038_000_000, Income = 1_730_000, Body = "blob", Color = rgb(120, 200, 255), Accent = rgb(255, 255, 255), Material = "Glass" },
	{ Id = "shellturtle", World = "reef", Name = "Shell Turtle", Rarity = "Rare", Price = 2_592_000_000, Income = 4_320_000, Body = "dino", Color = rgb(90, 190, 140), Accent = rgb(200, 140, 80) },
	{ Id = "jellyglow", World = "reef", Name = "Jellyglow", Rarity = "Epic", Price = 5_832_000_000, Income = 9_720_000, Body = "blob", Color = rgb(255, 150, 230), Accent = rgb(170, 120, 255), Material = "Neon", Float = true, Glow = true },
	{ Id = "tideunicorn", World = "reef", Name = "Tide Unicorn", Rarity = "Legendary", Price = 14_280_000_000, Income = 23_800_000, Body = "unicorn", Color = rgb(130, 220, 255), Accent = rgb(255, 255, 255), Glow = true, Sparkles = true },
	{ Id = "deepkraken", World = "reef", Name = "Deep Kraken", Rarity = "Mythic", Price = 51_840_000_000, Income = 86_400_000, Body = "blob", Special = "kraken", Color = rgb(20, 70, 110), Accent = rgb(90, 255, 200), EyeColor = rgb(255, 230, 90), Glow = true, Sparkles = true },
	{ Id = "pearlempress", World = "reef", Name = "Pearl Empress", Rarity = "Secret", Price = 648_000_000_000, Income = 1_080_000_000, Body = "blob", Color = rgb(250, 245, 240), Accent = rgb(255, 170, 210), Material = "Foil", Crown = true, Float = true, Glow = true, Sparkles = true, Hint = "Guards the biggest pearl... hides in Coral Eggs." },

	-- GALAXY STATION (World = "galaxy"): Nebula Egg e Supernova Egg
	{ Id = "moonbun", World = "galaxy", Name = "Moon Bun", Rarity = "Uncommon", Price = 6_240_000_000, Income = 10_400_000, Body = "bunny", Color = rgb(205, 205, 220), Accent = rgb(120, 120, 145), Material = "Slate" },
	{ Id = "astrocat", World = "galaxy", Name = "Astro Cat", Rarity = "Rare", Price = 15_540_000_000, Income = 25_900_000, Body = "cat", Color = rgb(60, 40, 125), Accent = rgb(255, 220, 90), Glow = true },
	{ Id = "cometbird", World = "galaxy", Name = "Comet Bird", Rarity = "Epic", Price = 34_980_000_000, Income = 58_300_000, Body = "bird", Color = rgb(120, 220, 255), Accent = rgb(255, 255, 255), Glow = true, Sparkles = true },
	{ Id = "starunicorn", World = "galaxy", Name = "Star Unicorn", Rarity = "Legendary", Price = 85_800_000_000, Income = 143_000_000, Body = "unicorn", Special = "celestial", Color = rgb(40, 30, 95), Accent = rgb(255, 210, 60), Glow = true, Sparkles = true, SparkleColors = "rainbow" },
	{ Id = "nebuladragon", World = "galaxy", Name = "Nebula Dragon", Rarity = "Mythic", Price = 310_800_000_000, Income = 518_000_000, Body = "blob", Special = "voiddragon", Color = rgb(70, 20, 120), Accent = rgb(255, 90, 220), EyeColor = rgb(120, 240, 255), Glow = true, Sparkles = true },
	{ Id = "galaxyemperor", World = "galaxy", Name = "Galaxy Emperor", Rarity = "Secret", Price = 3_888_000_000_000, Income = 6_480_000_000, Body = "blob", Special = "sun", Color = rgb(70, 25, 150), Accent = rgb(120, 230, 255), Material = "Neon", Crown = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "Rules every star in the sky... hides in Supernova Eggs." },

	-- CLIMA E NOITE (v9): saem dos ovos Storm (chuva), Snowflake (neve) e Moon (noite)
	{ Id = "puddlepup", World = "storm", Name = "Puddle Pup", Rarity = "Rare", Price = 18_000, Income = 400, Body = "cat", Color = rgb(110, 170, 255), Accent = rgb(230, 245, 255), Material = "Glass" },
	{ Id = "thundertoad", World = "storm", Name = "Thunder Toad", Rarity = "Epic", Price = 143_000, Income = 2_600, Body = "toad", Color = rgb(255, 225, 60), Accent = rgb(120, 70, 200), Glow = true },
	{ Id = "stormdrake", World = "storm", Name = "Storm Drake", Rarity = "Legendary", Price = 1_680_000, Income = 24_000, Body = "blob", Special = "voiddragon", Color = rgb(40, 60, 130), Accent = rgb(255, 230, 70), EyeColor = rgb(255, 240, 100), Glow = true, Sparkles = true, Hint = "Only hatches while it RAINS..." },
	{ Id = "flurryfox", World = "snow", Name = "Flurry Fox", Rarity = "Rare", Price = 18_000, Income = 400, Body = "cat", Color = rgb(245, 250, 255), Accent = rgb(140, 200, 255), Material = "Ice" },
	{ Id = "snowglobebun", World = "snow", Name = "Snowglobe Bun", Rarity = "Epic", Price = 143_000, Income = 2_600, Body = "bunny", Color = rgb(190, 230, 255), Accent = rgb(255, 255, 255), Material = "Glass", Sparkles = true },
	{ Id = "blizzardowl", World = "snow", Name = "Blizzard Owl", Rarity = "Legendary", Price = 1_680_000, Income = 24_000, Body = "bird", Color = rgb(235, 245, 255), Accent = rgb(90, 170, 255), Material = "Ice", Float = true, Glow = true, Sparkles = true, Hint = "Only hatches while it SNOWS..." },
	{ Id = "moonmoth", World = "night", Name = "Moon Moth", Rarity = "Rare", Price = 22_500, Income = 500, Body = "bird", Color = rgb(150, 120, 230), Accent = rgb(255, 245, 170), Float = true, Glow = true },
	{ Id = "shadowcat", World = "night", Name = "Shadow Cat", Rarity = "Epic", Price = 176_000, Income = 3_200, Body = "cat", Color = rgb(30, 25, 45), Accent = rgb(190, 110, 255), Glow = true },
	{ Id = "starlightunicorn", World = "night", Name = "Starlight Unicorn", Rarity = "Legendary", Price = 2_100_000, Income = 30_000, Body = "unicorn", Special = "celestial", Color = rgb(30, 30, 80), Accent = rgb(255, 225, 120), Glow = true, Sparkles = true, Hint = "Only comes out in the DARK..." },

	-- HÍBRIDOS (v9): saem do Laboratório de Mistura (receitas em Shared > Hybrids). Rendem 20% a mais que os dois pais juntos.
	{ Id = "mosqueak", World = "hybrid", Name = "Mosqueak", Rarity = "Common", Price = 384, Income = 12, Body = "toad", Color = rgb(255, 190, 210), Accent = rgb(120, 180, 80) },
	{ Id = "chirbun", World = "hybrid", Name = "Chirbun", Rarity = "Uncommon", Price = 1_440, Income = 40, Body = "bunny", Color = rgb(255, 225, 80), Accent = rgb(255, 150, 40) },
	{ Id = "fluffysaur", World = "hybrid", Name = "Fluffysaur", Rarity = "Uncommon", Price = 3_120, Income = 79, Body = "dino", Color = rgb(250, 250, 250), Accent = rgb(110, 200, 90) },
	{ Id = "steambun", World = "hybrid", Name = "Steambun", Rarity = "Rare", Price = 24_000, Income = 504, Body = "bunny", Color = rgb(200, 230, 255), Accent = rgb(255, 130, 60) },
	{ Id = "shelltoad", World = "hybrid", Name = "Shelltoad", Rarity = "Rare", Price = 20_760, Income = 437, Body = "toad", Color = rgb(60, 200, 190), Accent = rgb(200, 140, 80) },
	{ Id = "dragato", World = "hybrid", Name = "Dragato", Rarity = "Epic", Price = 174_000, Income = 2_892, Body = "cat", Color = rgb(255, 150, 200), Accent = rgb(255, 220, 40), Glow = true },
	{ Id = "prismowl", World = "hybrid", Name = "Prismowl", Rarity = "Epic", Price = 138_000, Income = 2_400, Body = "bird", Color = rgb(170, 120, 255), Accent = rgb(120, 230, 255), Glow = true, Sparkles = true },
	{ Id = "thunderpup", World = "hybrid", Name = "Thunderpup", Rarity = "Legendary", Price = 2_040_000, Income = 26_040, Body = "cat", Color = rgb(60, 80, 200), Accent = rgb(255, 235, 60), Glow = true, Sparkles = true },
	{ Id = "glaciaroo", World = "hybrid", Name = "Glaciaroo", Rarity = "Legendary", Price = 2_220_000, Income = 28_800, Body = "dino", Color = rgb(170, 220, 255), Accent = rgb(255, 120, 30), Material = "Ice", Glow = true, Sparkles = true },
	{ Id = "voidicorn", World = "hybrid", Name = "Voidicorn", Rarity = "Mythic", Price = 19_200_000, Income = 186_000, Body = "unicorn", Special = "celestial", Color = rgb(35, 20, 60), Accent = rgb(200, 110, 255), Glow = true, Sparkles = true },

	-- FESTAS DO CALENDÁRIO (v11): só saem dos ovos de festa, e só na época da festa
	{ Id = "pumpkat", World = "halloween", Name = "Pumpkat", Rarity = "Epic", Price = 180_000, Income = 3_000, Body = "cat", Color = rgb(255, 130, 30), Accent = rgb(40, 30, 40), EyeColor = rgb(255, 230, 80), Glow = true },
	{ Id = "batwing", World = "halloween", Name = "Batwing", Rarity = "Legendary", Price = 2_100_000, Income = 30_000, Body = "bird", Color = rgb(60, 30, 80), Accent = rgb(255, 140, 40), EyeColor = rgb(255, 80, 60), Float = true, Glow = true, Sparkles = true, Hint = "Flies in only around HALLOWEEN..." },
	{ Id = "jingledeer", World = "winter", Name = "Jingle Deer", Rarity = "Epic", Price = 180_000, Income = 3_000, Body = "blob", Special = "stormram", Color = rgb(150, 95, 60), Accent = rgb(230, 40, 50), Glow = true },
	{ Id = "frostpuff", World = "winter", Name = "Frost Puff", Rarity = "Legendary", Price = 2_100_000, Income = 30_000, Body = "bird", Color = rgb(245, 250, 255), Accent = rgb(90, 170, 255), Material = "Ice", Float = true, Glow = true, Sparkles = true, Hint = "Arrives with the WINTER holidays..." },
	{ Id = "lovebird", World = "valentine", Name = "Lovebird", Rarity = "Epic", Price = 180_000, Income = 3_000, Body = "bird", Color = rgb(255, 120, 160), Accent = rgb(120, 230, 140), Glow = true },
	{ Id = "heartcorn", World = "valentine", Name = "Heartcorn", Rarity = "Legendary", Price = 2_100_000, Income = 30_000, Body = "unicorn", Special = "celestial", Color = rgb(255, 170, 200), Accent = rgb(255, 60, 110), Glow = true, Sparkles = true, Hint = "Shows up on VALENTINE'S DAY..." },
	{ Id = "sunnyshell", World = "summer", Name = "Sunny Shell", Rarity = "Epic", Price = 180_000, Income = 3_000, Body = "dino", Color = rgb(255, 210, 90), Accent = rgb(255, 110, 70) },
	{ Id = "tropicaw", World = "summer", Name = "Tropicaw", Rarity = "Legendary", Price = 2_100_000, Income = 30_000, Body = "bird", Color = rgb(40, 200, 120), Accent = rgb(255, 220, 40), EyeColor = rgb(40, 40, 40), Glow = true, Sparkles = true, Hint = "Comes for the SUMMER party in July..." },

	-- PRESENTES ESPECIAIS (v11): ninguém compra; vêm da meta da comunidade e da visita do criador
	{ Id = "crowny", World = "event", Name = "Crowny", Rarity = "Epic", Price = 150_000, Income = 2_500, Body = "blob", Color = rgb(255, 215, 70), Accent = rgb(255, 120, 60), Material = "Foil", Crown = true, Glow = true, Hint = "A gift when the game's CREATOR visits your server!" },
	{ Id = "globey", World = "event", Name = "Globey", Rarity = "Epic", Price = 180_000, Income = 3_000, Body = "blob", Color = rgb(70, 150, 255), Accent = rgb(90, 210, 110), Glow = true, Sparkles = true, Hint = "Reward for the first COMMUNITY GOAL!" },
	-- EXPLORAÇÃO (v13): ilha secreta, fósseis (cavando) e fundo do mar (submarino)
	{ Id = "coconutcrab", World = "island", Name = "Coconut Crab", Rarity = "Epic", Price = 210_000, Income = 3_400, Body = "toad", Color = rgb(170, 90, 50), Accent = rgb(90, 200, 230), Glow = true },
	{ Id = "islandtortoise", World = "island", Name = "Island Tortoise", Rarity = "Legendary", Price = 2_500_000, Income = 34_000, Body = "dino", Color = rgb(120, 170, 90), Accent = rgb(230, 200, 120), Glow = true, Sparkles = true, Hint = "Lives on the SECRET ISLAND..." },
	{ Id = "tinyrex", World = "fossil", Name = "Tiny Rex", Rarity = "Epic", Price = 200_000, Income = 3_200, Body = "dino", Color = rgb(200, 180, 140), Accent = rgb(120, 90, 60), Material = "Slate" },
	{ Id = "amberraptor", World = "fossil", Name = "Amber Raptor", Rarity = "Legendary", Price = 2_400_000, Income = 33_000, Body = "dino", Color = rgb(255, 170, 40), Accent = rgb(120, 70, 30), Material = "Glass", Glow = true, Sparkles = true, Hint = "Dig in the sand patches for FOSSIL eggs..." },
	{ Id = "glowsquid", World = "deep", Name = "Glow Squid", Rarity = "Epic", Price = 220_000, Income = 3_500, Body = "blob", Special = "kraken", Color = rgb(40, 80, 200), Accent = rgb(120, 230, 255), Glow = true },
	{ Id = "isopodking", World = "deep", Name = "Isopod King", Rarity = "Legendary", Price = 2_600_000, Income = 35_000, Body = "bunny", Color = rgb(170, 170, 190), Accent = rgb(90, 90, 120), Material = "Metal", Crown = true, Glow = true, Sparkles = true, Hint = "Take the SUBMARINE in Coral Reef..." },
	{ Id = "unidrake", World = "event", Name = "Unidrake", Rarity = "Legendary", Price = 2_100_000, Income = 30_000, Body = "blob", Special = "voiddragon", Color = rgb(255, 150, 200), Accent = rgb(120, 230, 255), EyeColor = rgb(255, 255, 255), Glow = true, Sparkles = true, Hint = "Reward for a big COMMUNITY GOAL!" },
}

-- CRITTER DA SEMANA (v26): um exclusivo por semana (segunda a domingo, UTC). Só sai do "Weekly Egg" da esteira
--   do Meadow e só na semana dele; depois some por 8 semanas (ver ReplicatedStorage > Shared > Weekly).
--   Week = a posição no rodízio (1..8). Adicione mais linhas para um rodízio maior.
local WEEKLY = {
	{ Week = 1, Id = "sugarpaw", Name = "Sugarpaw", Rarity = "Epic", Price = 120_000, Income = 2_000, Body = "bunny", Color = rgb(255, 200, 225), Accent = rgb(255, 255, 255), Sparkles = true, Hint = "Critter of the Week #1 - only from the Weekly Egg on its week!" },
	{ Week = 2, Id = "voltbeak", Name = "Voltbeak", Rarity = "Epic", Price = 120_000, Income = 2_000, Body = "bird", Color = rgb(255, 230, 60), Accent = rgb(70, 130, 255), Glow = true, Hint = "Critter of the Week #2 - only from the Weekly Egg on its week!" },
	{ Week = 3, Id = "mochidino", Name = "Mochi Dino", Rarity = "Epic", Price = 120_000, Income = 2_000, Body = "dino", Color = rgb(170, 240, 200), Accent = rgb(255, 170, 200), Hint = "Critter of the Week #3 - only from the Weekly Egg on its week!" },
	{ Week = 4, Id = "nightcat", Name = "Nightcat", Rarity = "Legendary", Price = 500_000, Income = 7_000, Body = "cat", Color = rgb(40, 40, 90), Accent = rgb(180, 120, 255), Glow = true, Float = true, Hint = "Critter of the Week #4 - a LEGENDARY only from the Weekly Egg!" },
	{ Week = 5, Id = "bubbletoad", Name = "Bubbletoad", Rarity = "Epic", Price = 120_000, Income = 2_000, Body = "toad", Color = rgb(120, 230, 255), Accent = rgb(255, 255, 255), Material = "Glass", Hint = "Critter of the Week #5 - only from the Weekly Egg on its week!" },
	{ Week = 6, Id = "emberuni", Name = "Ember Unicorn", Rarity = "Legendary", Price = 500_000, Income = 7_000, Body = "unicorn", Color = rgb(255, 120, 40), Accent = rgb(255, 230, 90), Fire = true, Glow = true, Hint = "Critter of the Week #6 - a LEGENDARY only from the Weekly Egg!" },
	{ Week = 7, Id = "cloudpuff", Name = "Cloudpuff", Rarity = "Epic", Price = 120_000, Income = 2_000, Body = "blob", Color = rgb(250, 250, 255), Accent = rgb(150, 200, 255), Float = true, Hint = "Critter of the Week #7 - only from the Weekly Egg on its week!" },
	{ Week = 8, Id = "galaxydrake", Name = "Galaxy Drake", Rarity = "Legendary", Price = 500_000, Income = 7_000, Body = "dragon", Color = rgb(90, 40, 160), Accent = rgb(255, 220, 120), Sparkles = true, Glow = true, Hint = "Critter of the Week #8 - a LEGENDARY only from the Weekly Egg!" },
}
Critters.Weekly = WEEKLY
for _, def in WEEKLY do
	def.World = "weekly"
	table.insert(Critters.List, def)
end

Critters.ById = {}
Critters.ByRarity = {}
Critters.ByWorld = {} -- ByWorld[mundo][raridade] = lista

for order, def in Critters.List do
	def.Order = order
	def.World = def.World or "meadow"
	Critters.ById[def.Id] = def
	local bucket = Critters.ByRarity[def.Rarity]
	if not bucket then
		bucket = {}
		Critters.ByRarity[def.Rarity] = bucket
	end
	table.insert(bucket, def)
	local world = Critters.ByWorld[def.World]
	if not world then
		world = {}
		Critters.ByWorld[def.World] = world
	end
	world[def.Rarity] = world[def.Rarity] or {}
	table.insert(world[def.Rarity], def)
end

return Critters
