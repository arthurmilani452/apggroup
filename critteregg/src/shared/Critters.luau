--[[
	LISTA DE BICHINHOS (critters)

	Cada bichinho tem:
	  Id       -> nome interno (sem espaço, NUNCA mude depois de lançar)
	  Name     -> nome que aparece no jogo
	  Rarity   -> Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret ou Divine (v32)
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
	  World    -> (opcional) mundo de onde sai: "candy", "frost", "lava", "reef", "galaxy", "dino", "pirate", "robot" (sem World = Meadow)

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

	-- BICHINHOS NOVOS (v33): mais variedade em cada mundo, todos em 3D (gerador do Roblox Studio, pasta
	--   Models3D > Novos3D). Renda e preço iguais aos da mesma raridade/mundo.
	--   (Soon = true num bichinho = ainda sem 3D: ele fica guardado e NÃO sai em ovo nenhum.)
	-- v58: BICHINHOS ENGRAÇADOS do Meadow (os primeiros que o jogador novo vê). Soon = true até o modelo 3D entrar em
	--   Models3D > Novos3D com o MESMO nome do Id; depois é só apagar o "Soon = true, " da linha.
	{ Id = "grumpytoast", Soon = true, Name = "Grumpy Toast", Rarity = "Common", Price = 150, Income = 5, Body = "blob", Color = rgb(225, 170, 100), Accent = rgb(140, 90, 50) },
	{ Id = "picklepug", Name = "Pickle Pug", Rarity = "Common", Price = 250, Income = 8, Body = "cat", Color = rgb(110, 170, 70), Accent = rgb(70, 110, 45) },
	{ Id = "tacocat", Name = "Taco Cat", Rarity = "Uncommon", Price = 1_000, Income = 28, Body = "cat", Color = rgb(255, 205, 90), Accent = rgb(120, 200, 80) },
	{ Id = "noodledoggo", Name = "Noodle Doggo", Rarity = "Uncommon", Price = 1_600, Income = 42, Body = "cat", Color = rgb(255, 230, 150), Accent = rgb(230, 90, 60) },
	{ Id = "discopotato", Name = "Disco Potato", Rarity = "Rare", Price = 9_000, Income = 190, Body = "blob", Color = rgb(190, 140, 90), Accent = rgb(255, 80, 220), Glow = true, Sparkles = true, SparkleColors = "rainbow" },
	{ Id = "captainwobble", Name = "Captain Wobble", Rarity = "Epic", Price = 60_000, Income = 1_000, Body = "bird", Color = rgb(120, 220, 255), Accent = rgb(40, 40, 60), Material = "Glass" },
	{ Id = "buzzybee", Name = "Buzzy Bee", Rarity = "Rare", Price = 10_000, Income = 200, Body = "bird", Color = rgb(255, 215, 50), Accent = rgb(40, 40, 50) },
	{ Id = "rainbowfox", Name = "Rainbow Fox", Rarity = "Epic", Price = 85_000, Income = 1_500, Body = "cat", Color = rgb(255, 140, 80), Accent = rgb(140, 220, 255), Sparkles = true, SparkleColors = "rainbow" },
	{ Id = "thunderwolf", Name = "Thunder Wolf", Rarity = "Legendary", Price = 900_000, Income = 12_000, Body = "cat", Color = rgb(90, 100, 160), Accent = rgb(255, 230, 70), EyeColor = rgb(255, 240, 120), Glow = true, Sparkles = true },
	{ Id = "jellypup", World = "candy", Name = "Jelly Pup", Rarity = "Rare", Price = 12_000_000, Income = 20_000, Body = "cat", Color = rgb(120, 230, 160), Accent = rgb(255, 120, 190), Material = "Glass" },
	{ Id = "marshmallowbun", World = "candy", Name = "Marshmallow Bun", Rarity = "Epic", Price = 27_000_000, Income = 45_000, Body = "bunny", Color = rgb(255, 245, 250), Accent = rgb(255, 170, 210) },
	{ Id = "caramelwyrm", World = "candy", Name = "Caramel Wyrm", Rarity = "Legendary", Price = 66_000_000, Income = 110_000, Body = "dragon", Color = rgb(215, 140, 60), Accent = rgb(255, 230, 160), Glow = true, Sparkles = true },
	{ Id = "frostowl", World = "frost", Name = "Frost Owl", Rarity = "Rare", Price = 72_000_000, Income = 120_000, Body = "bird", Color = rgb(235, 245, 255), Accent = rgb(120, 190, 255) },
	{ Id = "polarcub", World = "frost", Name = "Polar Cub", Rarity = "Epic", Price = 162_000_000, Income = 270_000, Body = "blob", Color = rgb(250, 252, 255), Accent = rgb(90, 160, 230) },
	{ Id = "glacierunicorn", World = "frost", Name = "Glacier Unicorn", Rarity = "Legendary", Price = 396_000_000, Income = 660_000, Body = "unicorn", Color = rgb(180, 230, 255), Accent = rgb(255, 255, 255), Material = "Ice", Glow = true, Sparkles = true },
	{ Id = "ashbunny", World = "lava", Name = "Ash Bunny", Rarity = "Rare", Price = 432_000_000, Income = 720_000, Body = "bunny", Color = rgb(90, 85, 90), Accent = rgb(255, 120, 40) },
	{ Id = "lavalizard", World = "lava", Name = "Lava Lizard", Rarity = "Epic", Price = 972_000_000, Income = 1_620_000, Body = "dino", Color = rgb(200, 60, 30), Accent = rgb(255, 210, 60), Material = "CrackedLava" },
	{ Id = "magmaphoenix", World = "lava", Name = "Magma Phoenix", Rarity = "Legendary", Price = 2_376_000_000, Income = 3_960_000, Body = "blob", Special = "phoenix", Color = rgb(255, 100, 30), Accent = rgb(255, 220, 80), Fire = true, Glow = true, Sparkles = true },
	{ Id = "coralcrab", World = "reef", Name = "Coral Crab", Rarity = "Rare", Price = 2_592_000_000, Income = 4_320_000, Body = "toad", Color = rgb(255, 110, 90), Accent = rgb(255, 220, 200) },
	{ Id = "dolphinpup", World = "reef", Name = "Dolphin Pup", Rarity = "Epic", Price = 5_832_000_000, Income = 9_720_000, Body = "blob", Color = rgb(120, 170, 220), Accent = rgb(230, 245, 255) },
	{ Id = "glowmanta", World = "reef", Name = "Glow Manta", Rarity = "Legendary", Price = 14_280_000_000, Income = 23_800_000, Body = "bird", Color = rgb(40, 60, 120), Accent = rgb(90, 240, 230), Glow = true, Sparkles = true },
	{ Id = "rocketpup", World = "galaxy", Name = "Rocket Pup", Rarity = "Rare", Price = 15_540_000_000, Income = 25_900_000, Body = "cat", Color = rgb(240, 240, 250), Accent = rgb(255, 80, 80) },
	{ Id = "saturntoad", World = "galaxy", Name = "Saturn Toad", Rarity = "Epic", Price = 34_980_000_000, Income = 58_300_000, Body = "toad", Color = rgb(255, 200, 120), Accent = rgb(170, 110, 255) },
	{ Id = "cosmodragon", World = "galaxy", Name = "Cosmo Dragon", Rarity = "Legendary", Price = 85_800_000_000, Income = 143_000_000, Body = "dragon", Color = rgb(60, 30, 130), Accent = rgb(120, 230, 255), Material = "Neon", Glow = true, Sparkles = true, SparkleColors = "rainbow" },

	-- DIVINOS (v32): a raridade mais rara do jogo. 1 em 10.000 ovos (0,01%) de QUALQUER ovo do mundo.
	--   Brilho arco-íris, aura e coroa; quando alguém choca, o servidor inteiro vê o aviso.
	{ Id = "divineunicorn", Name = "Divine Unicorn", Rarity = "Divine", Price = 1_800_000_000, Income = 6_000_000, Body = "unicorn", Special = "celestial", Color = rgb(255, 255, 255), Accent = rgb(255, 215, 90), Material = "Neon", Crown = true, Aura = true, Float = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Meadow egg!" },
	{ Id = "rainbowphoenix", World = "candy", Name = "Rainbow Phoenix", Rarity = "Divine", Price = 6_000_000_000, Income = 20_000_000, Body = "blob", Special = "phoenix", Color = rgb(255, 120, 200), Accent = rgb(120, 230, 255), Material = "Neon", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Candy egg!" },
	{ Id = "crystalmammoth", World = "frost", Name = "Crystal Mammoth", Rarity = "Divine", Price = 36_000_000_000, Income = 120_000_000, Body = "blob", Special = "frostmammoth", Color = rgb(170, 240, 255), Accent = rgb(255, 255, 255), Material = "Glass", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Frost egg!" },
	{ Id = "infernodragon", World = "lava", Name = "Inferno Dragon", Rarity = "Divine", Price = 216_000_000_000, Income = 720_000_000, Body = "blob", Special = "voiddragon", Color = rgb(255, 80, 30), Accent = rgb(255, 230, 90), Material = "Neon", Crown = true, Aura = true, Fire = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Lava egg!" },
	{ Id = "abysskraken", World = "reef", Name = "Abyss Kraken", Rarity = "Divine", Price = 1_300_000_000_000, Income = 4_300_000_000, Body = "blob", Special = "kraken", Color = rgb(40, 200, 220), Accent = rgb(255, 170, 230), Material = "Neon", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Reef egg!" },
	{ Id = "starsovereign", World = "galaxy", Name = "Star Sovereign", Rarity = "Divine", Price = 7_800_000_000_000, Income = 26_000_000_000, Body = "blob", Special = "sun", Color = rgb(120, 60, 255), Accent = rgb(120, 230, 255), Material = "Neon", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Galaxy egg!" },

	-- v42: DINO JUNGLE (World = "dino")
	{ Id = "rexling", World = "dino", Name = "Rexling", Rarity = "Uncommon", Price = 37_440_000_000, Income = 62_400_000, Body = "dino", Color = rgb(110, 200, 80), Accent = rgb(250, 225, 110) },
	{ Id = "tricerapup", World = "dino", Name = "Tricera Pup", Rarity = "Rare", Price = 93_240_000_000, Income = 155_400_000, Body = "dino", Color = rgb(255, 150, 60), Accent = rgb(255, 235, 200) },
	{ Id = "pterokid", World = "dino", Name = "Ptero Kid", Rarity = "Rare", Price = 93_240_000_000, Income = 155_400_000, Body = "bird", Color = rgb(60, 190, 180), Accent = rgb(255, 150, 60) },
	{ Id = "stegobub", World = "dino", Name = "Stego Bub", Rarity = "Epic", Price = 209_880_000_000, Income = 349_800_000, Body = "dino", Color = rgb(80, 140, 255), Accent = rgb(255, 220, 80) },
	{ Id = "raptorik", World = "dino", Name = "Raptor Rik", Rarity = "Epic", Price = 209_880_000_000, Income = 349_800_000, Body = "dino", Color = rgb(230, 70, 60), Accent = rgb(70, 130, 255), Glow = true },
	{ Id = "brontoboom", World = "dino", Name = "Bronto Boom", Rarity = "Legendary", Price = 514_800_000_000, Income = 858_000_000, Body = "dino", Color = rgb(170, 110, 255), Accent = rgb(230, 210, 255), Glow = true, Sparkles = true },
	{ Id = "ankylord", World = "dino", Name = "Ankylord", Rarity = "Legendary", Price = 514_800_000_000, Income = 858_000_000, Body = "dino", Color = rgb(150, 105, 70), Accent = rgb(255, 205, 70), Glow = true, Sparkles = true },
	{ Id = "spinoking", World = "dino", Name = "Spino King", Rarity = "Mythic", Price = 1_864_800_000_000, Income = 3_108_000_000, Body = "dragon", Color = rgb(60, 150, 110), Accent = rgb(255, 70, 60), Crown = true, Glow = true, Sparkles = true },
	{ Id = "volcanorex", World = "dino", Name = "Volcano Rex", Rarity = "Secret", Price = 23_328_000_000_000, Income = 38_880_000_000, Body = "dino", Color = rgb(50, 40, 40), Accent = rgb(255, 120, 30), Material = "CrackedLava", Crown = true, Glow = true, Sparkles = true, Hint = "The jungle shakes when it walks... hides in Rex Eggs." },
	{ Id = "dinotitan", World = "dino", Name = "Dino Titan", Rarity = "Divine", Price = 46_800_000_000_000, Income = 156_000_000_000, Body = "dino", Color = rgb(255, 210, 70), Accent = rgb(120, 255, 230), Material = "Neon", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Dino Jungle egg!" },
	-- v42: PIRATE BAY (World = "pirate")
	{ Id = "captainpolly", World = "pirate", Name = "Captain Polly", Rarity = "Uncommon", Price = 224_640_000_000, Income = 374_400_000, Body = "bird", Color = rgb(230, 60, 60), Accent = rgb(255, 215, 60) },
	{ Id = "crabbybeard", World = "pirate", Name = "Crabby Beard", Rarity = "Rare", Price = 559_440_000_000, Income = 932_400_000, Body = "toad", Color = rgb(255, 110, 70), Accent = rgb(60, 60, 70) },
	{ Id = "monkeymate", World = "pirate", Name = "Monkey Mate", Rarity = "Rare", Price = 559_440_000_000, Income = 932_400_000, Body = "cat", Color = rgb(160, 110, 70), Accent = rgb(230, 60, 60) },
	{ Id = "sharkbite", World = "pirate", Name = "Shark Bite", Rarity = "Epic", Price = 1_259_280_000_000, Income = 2_098_800_000, Body = "blob", Color = rgb(110, 150, 190), Accent = rgb(240, 245, 255) },
	{ Id = "octopirate", World = "pirate", Name = "Octo Pirate", Rarity = "Epic", Price = 1_259_280_000_000, Income = 2_098_800_000, Body = "blob", Color = rgb(190, 90, 210), Accent = rgb(60, 60, 70), Glow = true },
	{ Id = "treasureturtle", World = "pirate", Name = "Treasure Turtle", Rarity = "Legendary", Price = 3_088_800_000_000, Income = 5_148_000_000, Body = "dino", Color = rgb(70, 170, 120), Accent = rgb(255, 205, 60), Glow = true, Sparkles = true },
	{ Id = "ghostcaptain", World = "pirate", Name = "Ghost Captain", Rarity = "Legendary", Price = 3_088_800_000_000, Income = 5_148_000_000, Body = "blob", Color = rgb(170, 255, 230), Accent = rgb(40, 60, 90), Material = "Glass", Float = true, Glow = true, Sparkles = true },
	{ Id = "krakenlord", World = "pirate", Name = "Kraken Lord", Rarity = "Mythic", Price = 11_188_800_000_000, Income = 18_648_000_000, Body = "blob", Color = rgb(120, 40, 160), Accent = rgb(120, 255, 200), Special = "kraken", Glow = true, Sparkles = true },
	{ Id = "skullking", World = "pirate", Name = "Skull King", Rarity = "Secret", Price = 139_968_000_000_000, Income = 233_280_000_000, Body = "blob", Color = rgb(240, 235, 220), Accent = rgb(255, 205, 60), Crown = true, Glow = true, Sparkles = true, Hint = "He guards the biggest treasure of the bay... hides in Kraken Eggs." },
	{ Id = "seaemperor", World = "pirate", Name = "Sea Emperor", Rarity = "Divine", Price = 280_800_000_000_000, Income = 936_000_000_000, Body = "dragon", Color = rgb(255, 205, 70), Accent = rgb(60, 220, 255), Material = "Neon", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Pirate Bay egg!" },
	-- v42: ROBOT CITY (World = "robot")
	{ Id = "boltbot", World = "robot", Name = "Bolt Bot", Rarity = "Uncommon", Price = 1_347_840_000_000, Income = 2_246_400_000, Body = "blob", Color = rgb(200, 210, 225), Accent = rgb(255, 200, 60), Material = "Metal" },
	{ Id = "gearpup", World = "robot", Name = "Gear Pup", Rarity = "Rare", Price = 3_356_640_000_000, Income = 5_594_400_000, Body = "cat", Color = rgb(150, 160, 180), Accent = rgb(255, 140, 40), Material = "Metal" },
	{ Id = "dronebee", World = "robot", Name = "Drone Bee", Rarity = "Rare", Price = 3_356_640_000_000, Income = 5_594_400_000, Body = "bird", Color = rgb(255, 215, 60), Accent = rgb(40, 40, 50), Float = true },
	{ Id = "mechacat", World = "robot", Name = "Mecha Cat", Rarity = "Epic", Price = 7_555_680_000_000, Income = 12_592_800_000, Body = "cat", Color = rgb(60, 70, 90), Accent = rgb(90, 230, 255), Glow = true },
	{ Id = "tankturtle", World = "robot", Name = "Tank Turtle", Rarity = "Epic", Price = 7_555_680_000_000, Income = 12_592_800_000, Body = "dino", Color = rgb(90, 140, 90), Accent = rgb(255, 90, 60), Material = "Metal" },
	{ Id = "cyberwolf", World = "robot", Name = "Cyber Wolf", Rarity = "Legendary", Price = 18_532_800_000_000, Income = 30_888_000_000, Body = "cat", Color = rgb(40, 40, 60), Accent = rgb(190, 90, 255), Glow = true, Sparkles = true },
	{ Id = "rocketrex", World = "robot", Name = "Rocket Rex", Rarity = "Legendary", Price = 18_532_800_000_000, Income = 30_888_000_000, Body = "dino", Color = rgb(220, 60, 60), Accent = rgb(255, 200, 60), Glow = true, Sparkles = true },
	{ Id = "megamech", World = "robot", Name = "Mega Mech", Rarity = "Mythic", Price = 67_132_800_000_000, Income = 111_888_000_000, Body = "blob", Color = rgb(60, 90, 200), Accent = rgb(255, 215, 60), Material = "Metal", Glow = true, Sparkles = true },
	{ Id = "omegacore", World = "robot", Name = "Omega Core", Rarity = "Secret", Price = 839_808_000_000_000, Income = 1_399_680_000_000, Body = "blob", Color = rgb(30, 30, 45), Accent = rgb(90, 255, 220), Material = "Neon", Float = true, Crown = true, Glow = true, Sparkles = true, Hint = "The brain of the whole city... hides in Omega Eggs." },
	{ Id = "titanprime", World = "robot", Name = "Titan Prime", Rarity = "Divine", Price = 1_684_800_000_000_000, Income = 5_616_000_000_000, Body = "blob", Color = rgb(255, 210, 70), Accent = rgb(90, 230, 255), Material = "Neon", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "1 in 10,000 eggs... from ANY Robot City egg!" },
	-- CELESTIAL (a mais rara de todas: 1 em ~50.000 ovos)
	{ Id = "celestialdragon", Name = "Celestial Dragon", Rarity = "Celestial", Price = 9_000_000_000, Income = 30_000_000, Body = "dragon", Color = rgb(170, 240, 255), Accent = rgb(255, 120, 230), Material = "Neon", Crown = true, Aura = true, Float = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "The rarest critter of the Forest... 1 in 50,000 eggs!" },
	{ Id = "tidalleviathan", World = "reef", Name = "Tidal Leviathan", Rarity = "Celestial", Price = 6_500_000_000_000, Income = 21_500_000_000, Body = "blob", Special = "kraken", Color = rgb(80, 230, 255), Accent = rgb(255, 255, 255), Material = "Glass", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "Sleeps at the bottom of the Abyss... 1 in 50,000 eggs!" },
	{ Id = "candycosmo", World = "candy", Name = "Candy Cosmo", Rarity = "Celestial", Price = 30_000_000_000, Income = 100_000_000, Body = "unicorn", Special = "celestial", Color = rgb(255, 170, 230), Accent = rgb(120, 240, 255), Material = "Neon", Crown = true, Aura = true, Float = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "Made of stardust and sugar... 1 in 50,000 eggs!" },
	{ Id = "nebulaphoenix", World = "galaxy", Name = "Nebula Phoenix", Rarity = "Celestial", Price = 39_000_000_000_000, Income = 130_000_000_000, Body = "blob", Special = "phoenix", Color = rgb(130, 70, 255), Accent = rgb(120, 240, 255), Material = "Neon", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "Born inside a nebula... 1 in 50,000 eggs!" },
	{ Id = "omegaguardian", World = "robot", Name = "Omega Guardian", Rarity = "Celestial", Price = 8_400_000_000_000_000, Income = 28_000_000_000_000, Body = "dragon", Color = rgb(40, 40, 60), Accent = rgb(120, 255, 240), Material = "Neon", Crown = true, Aura = true, Glow = true, Sparkles = true, SparkleColors = "rainbow", Hint = "The last machine ever built... 1 in 50,000 eggs!" },

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
	-- v63: CRIATURAS MALUCAS (estilo meme: bicho + comida + nome bobo que rima). NÃO se misturam com os bichinhos
	--   antigos: cada grupo sai só do seu ovo. Feitas de peças + fantasia (Cape, HeadBand, Emblem, WitchHat, Stem)
	--   até ganharem modelo 3D em Models3D > Novos3D com o MESMO nome do Id.
	-- HALLOWEEN (World = "spooky"): só no Spooky Egg, na época do Halloween (Config.Holidays)
	{ Id = "pumpkinopinguino", World = "spooky", Name = "Pumpkino Pinguino", Rarity = "Common", Price = 280, Income = 9, Body = "bird", Color = rgb(255, 135, 35), Accent = rgb(40, 35, 45), Stem = true },
	{ Id = "ghostinitoastini", World = "spooky", Name = "Ghostini Toastini", Rarity = "Common", Price = 320, Income = 10, Body = "blob", Color = rgb(245, 245, 255), Accent = rgb(200, 150, 90), Material = "Glass", Float = true },
	{ Id = "battoburrito", World = "spooky", Name = "Batto Burrito", Rarity = "Uncommon", Price = 1_400, Income = 38, Body = "bird", Color = rgb(95, 60, 130), Accent = rgb(235, 200, 140), Float = true },
	{ Id = "candycornounicorno", World = "spooky", Name = "Candy Corno Unicorno", Rarity = "Uncommon", Price = 2_100, Income = 52, Body = "unicorn", Color = rgb(255, 220, 70), Accent = rgb(255, 140, 40) },
	{ Id = "witchysandwichy", World = "spooky", Name = "Witchy Sandwichy", Rarity = "Rare", Price = 9_000, Income = 190, Body = "toad", Color = rgb(120, 200, 90), Accent = rgb(255, 170, 60), WitchHat = rgb(70, 40, 110) },
	{ Id = "spaghettiskeletti", World = "spooky", Name = "Spaghetti Skeletti", Rarity = "Rare", Price = 15_000, Income = 320, Body = "cat", Color = rgb(245, 240, 225), Accent = rgb(230, 70, 50), HeadBand = rgb(230, 70, 50) },
	{ Id = "mummygummy", World = "spooky", Name = "Mummy Gummy", Rarity = "Epic", Price = 90_000, Income = 1_600, Body = "bunny", Color = rgb(255, 110, 170), Accent = rgb(250, 250, 240), Material = "Glass", HeadBand = rgb(250, 250, 240), Glow = true },
	{ Id = "vampiropepperoni", World = "spooky", Name = "Vampiro Pepperoni", Rarity = "Legendary", Price = 800_000, Income = 11_000, Body = "cat", Color = rgb(200, 50, 45), Accent = rgb(255, 215, 120), EyeColor = rgb(255, 70, 70), Cape = rgb(35, 20, 45), Glow = true, Sparkles = true, Hint = "Hides in the SPOOKY EGG around Halloween..." },
	-- SUPER CRITTERS (World = "hero"): só no Hero Egg, o ano todo. Heróis inventados (nada de marca famosa).
	{ Id = "captaincannoli", World = "hero", Name = "Captain Cannoli", Rarity = "Uncommon", Price = 1_800, Income = 46, Body = "blob", Color = rgb(235, 200, 150), Accent = rgb(255, 250, 240), Cape = rgb(220, 45, 45), HeadBand = rgb(220, 45, 45) },
	{ Id = "turbotortellini", World = "hero", Name = "Turbo Tortellini", Rarity = "Uncommon", Price = 2_200, Income = 54, Body = "bunny", Color = rgb(255, 225, 130), Accent = rgb(60, 130, 255), Cape = rgb(60, 130, 255), Emblem = rgb(255, 240, 90) },
	{ Id = "mightymeatballo", World = "hero", Name = "Mighty Meatballo", Rarity = "Rare", Price = 11_000, Income = 230, Body = "blob", Color = rgb(140, 85, 55), Accent = rgb(230, 60, 45), Cape = rgb(60, 180, 90), Emblem = rgb(255, 240, 90) },
	{ Id = "laserlasagna", World = "hero", Name = "Laser Lasagna", Rarity = "Rare", Price = 17_000, Income = 340, Body = "cat", Color = rgb(255, 170, 60), Accent = rgb(220, 60, 40), EyeColor = rgb(255, 40, 40), HeadBand = rgb(40, 40, 50), Glow = true },
	{ Id = "thundertacosaurus", World = "hero", Name = "Thunder Tacosaurus", Rarity = "Epic", Price = 95_000, Income = 1_650, Body = "dino", Color = rgb(255, 205, 90), Accent = rgb(110, 200, 80), Cape = rgb(90, 70, 200), Emblem = rgb(255, 240, 90), Glow = true },
	{ Id = "bananabandana", World = "hero", Name = "Banana Bandana", Rarity = "Epic", Price = 130_000, Income = 2_200, Body = "bird", Color = rgb(255, 230, 70), Accent = rgb(120, 80, 40), HeadBand = rgb(230, 50, 50), Cape = rgb(230, 50, 50) },
	{ Id = "supergelatogato", World = "hero", Name = "Super Gelato Gato", Rarity = "Legendary", Price = 1_000_000, Income = 13_000, Body = "cat", Color = rgb(255, 170, 210), Accent = rgb(140, 235, 255), Cape = rgb(60, 200, 230), Emblem = rgb(255, 255, 255), Glow = true, Sparkles = true, SparkleColors = "rainbow" },
	{ Id = "megamozzarella", World = "hero", Name = "Mega Mozzarella", Rarity = "Mythic", Price = 7_000_000, Income = 70_000, Body = "blob", Color = rgb(255, 250, 235), Accent = rgb(255, 205, 60), Material = "Foil", Cape = rgb(255, 200, 40), HeadBand = rgb(230, 50, 50), Emblem = rgb(255, 90, 60), Float = true, Glow = true, Sparkles = true, Hint = "The mightiest hero of the HERO EGG..." },
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

-- v33: bichinhos "Soon" ficam guardados fora do jogo até ganharem o modelo 3D.
Critters.Soon = {}
for i = #Critters.List, 1, -1 do
	if Critters.List[i].Soon then
		table.insert(Critters.Soon, 1, table.remove(Critters.List, i))
	end
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

-- v45: COLEÇÃO POR MUNDO. Quem descobre TODOS os bichinhos de um mundo (menos o DIVINO, que é 1 em 10.000)
--   ganha um prêmio para sempre (Config.WorldSetBonus). SetOf[mundo] = lista dos Ids que contam.
Critters.SetOf = {}
for _, def in Critters.List do
	if def.Rarity ~= "Divine" and not def.Week and not def.Hidden then
		Critters.SetOf[def.World] = Critters.SetOf[def.World] or {}
		table.insert(Critters.SetOf[def.World], def.Id)
	end
end

-- Quantos bichinhos da coleção do mundo já foram descobertos (index = tabela { [Id] = true })
function Critters.SetProgress(worldId: string, index: { [string]: any }): (number, number)
	local list = Critters.SetOf[worldId]
	if not list then
		return 0, 0
	end
	local found = 0
	for _, id in list do
		if index[id] then
			found += 1
		end
	end
	return found, #list
end

return Critters
