--[[
	Cosmetics (ModuleScript em ReplicatedStorage > Shared)
	Parte 15: tudo o que muda o VISUAL (nada aqui dá vantagem no jogo).
	  • Themes  - visual da base inteira. Cada mundo destravado libera o tema dele.
	  • Decor   - enfeites para as 8 vagas de decoração da base (compra uma vez, usa em quantas vagas quiser)
	  • Trails  - rastro colorido atrás do avatar
	  • Titles  - título em cima da cabeça, ganho jogando
	Tudo dá para ganhar de graça jogando. Price = custa dinheiro do jogo. World = precisa ter destravado
	aquele mundo. Requires = conquista (Rebirths, Steals, Hatched, Defends, Index, Secret, Worlds, VIP, Premium).
	Para adicionar um item novo: copie uma linha e troque o Id (o visual do enfeite fica no Customize, no servidor).
]]

local Config = require(script.Parent.Config)
local Seasons = require(script.Parent.Seasons)

local Cosmetics = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Cores e materiais de cada tema (Floor = piso, Stripe = listras, Band = parede de baixo, Top = parede de cima,
-- Trim = borda neon, Tower/Cap = torres, Gate = portão, Rug = tapete). Props = enfeites do tema nas paredes e torres.
Cosmetics.Themes = {
	{ Id = "classic", Name = "Classic", Description = "Your base's own color.", Swatch = rgb(255, 160, 60) },
	{ Id = "garden", Name = "Garden", World = "meadow", Description = "Grass, wood and flowers.", Swatch = rgb(110, 200, 90),
		Floor = { rgb(115, 195, 85), "Grass" }, Stripe = { rgb(140, 215, 105), "Grass" }, Band = { rgb(125, 85, 55), "Wood" },
		Top = { rgb(235, 218, 180), "WoodPlanks" }, Trim = rgb(130, 235, 110), Tower = { rgb(150, 110, 75), "Wood" },
		Cap = { rgb(90, 170, 70), "Grass" }, Gate = { rgb(150, 110, 75), "Wood" }, Rug = rgb(250, 225, 120), Props = "garden" },
	{ Id = "candy", Name = "Candy", World = "candy", Description = "Pink walls and giant lollipops.", Swatch = rgb(255, 130, 200),
		Floor = { rgb(255, 205, 225), "SmoothPlastic" }, Stripe = { rgb(255, 255, 255), "SmoothPlastic" }, Band = { rgb(255, 90, 160), "SmoothPlastic" },
		Top = { rgb(255, 245, 250), "SmoothPlastic" }, Trim = rgb(255, 120, 200), Tower = { rgb(255, 150, 200), "SmoothPlastic" },
		Cap = { rgb(120, 230, 200), "SmoothPlastic" }, Gate = { rgb(255, 110, 170), "SmoothPlastic" }, Rug = rgb(120, 220, 255), Props = "candy" },
	{ Id = "frost", Name = "Frost", World = "frost", Description = "Ice floor and snowy towers.", Swatch = rgb(150, 215, 255),
		Floor = { rgb(205, 232, 255), "Ice" }, Stripe = { rgb(245, 250, 255), "Snow" }, Band = { rgb(110, 160, 220), "SmoothPlastic" },
		Top = { rgb(240, 248, 255), "Snow" }, Trim = rgb(130, 220, 255), Tower = { rgb(170, 210, 245), "SmoothPlastic" },
		Cap = { rgb(250, 252, 255), "Snow" }, Gate = { rgb(120, 180, 235), "SmoothPlastic" }, Rug = rgb(180, 225, 255), Props = "frost" },
	{ Id = "lava", Name = "Lava", World = "lava", Description = "Dark stone and glowing lava.", Swatch = rgb(255, 110, 40),
		Floor = { rgb(55, 45, 45), "Basalt" }, Stripe = { rgb(255, 110, 30), "CrackedLava" }, Band = { rgb(90, 30, 20), "Basalt" },
		Top = { rgb(75, 65, 65), "Slate" }, Trim = rgb(255, 120, 30), Tower = { rgb(60, 45, 45), "Basalt" },
		Cap = { rgb(255, 100, 20), "Neon" }, Gate = { rgb(90, 35, 25), "Basalt" }, Rug = rgb(255, 150, 40), Props = "lava" },
	{ Id = "reef", Name = "Reef", World = "reef", Description = "Sand floor and coral walls.", Swatch = rgb(80, 220, 220),
		Floor = { rgb(240, 222, 170), "Sand" }, Stripe = { rgb(120, 215, 215), "SmoothPlastic" }, Band = { rgb(40, 150, 160), "SmoothPlastic" },
		Top = { rgb(250, 240, 228), "SmoothPlastic" }, Trim = rgb(90, 225, 230), Tower = { rgb(255, 135, 120), "SmoothPlastic" },
		Cap = { rgb(255, 215, 120), "SmoothPlastic" }, Gate = { rgb(40, 160, 170), "SmoothPlastic" }, Rug = rgb(255, 160, 190), Props = "reef" },
	{ Id = "galaxy", Name = "Galaxy", World = "galaxy", Description = "Space floor and floating planets.", Swatch = rgb(170, 110, 255),
		Floor = { rgb(28, 22, 50), "SmoothPlastic" }, Stripe = { rgb(150, 90, 255), "Neon" }, Band = { rgb(40, 30, 85), "SmoothPlastic" },
		Top = { rgb(62, 50, 115), "SmoothPlastic" }, Trim = rgb(190, 130, 255), Tower = { rgb(50, 40, 100), "SmoothPlastic" },
		Cap = { rgb(255, 220, 90), "Neon" }, Gate = { rgb(90, 60, 180), "SmoothPlastic" }, Rug = rgb(120, 80, 220), Props = "galaxy" },

	-- v29: GINÁSIOS. Gym = Id do modelo 3D (feito no Higgsfield, lista de códigos em Models3DJobs).
	-- Com o modelo importado, a base vira o ginásio 3D; sem ele, a base só ganha as cores do ginásio.
	{ Id = "gym_fire", Name = "Fire Gym", Gym = "gym_fire", Description = "A volcanic battle arena.", Swatch = rgb(255, 95, 40),
		Floor = { rgb(200, 120, 80), "Ground" }, Stripe = { rgb(255, 245, 235), "SmoothPlastic" }, Band = { rgb(150, 45, 35), "Brick" },
		Top = { rgb(70, 55, 55), "Basalt" }, Trim = rgb(255, 130, 40), Tower = { rgb(120, 40, 30), "Brick" },
		Cap = { rgb(255, 110, 30), "Neon" }, Gate = { rgb(150, 45, 35), "Brick" }, Rug = rgb(255, 150, 60) },
	{ Id = "gym_water", Name = "Water Gym", Gym = "gym_water", Description = "Waterfalls and blue tiles.", Swatch = rgb(60, 160, 255),
		Floor = { rgb(120, 190, 240), "SmoothPlastic" }, Stripe = { rgb(240, 250, 255), "SmoothPlastic" }, Band = { rgb(50, 130, 210), "SmoothPlastic" },
		Top = { rgb(240, 248, 255), "Marble" }, Trim = rgb(90, 225, 255), Tower = { rgb(70, 150, 225), "SmoothPlastic" },
		Cap = { rgb(250, 230, 210), "SmoothPlastic" }, Gate = { rgb(50, 130, 210), "SmoothPlastic" }, Rug = rgb(120, 220, 255) },
	{ Id = "gym_grass", Name = "Grass Gym", Gym = "gym_grass", Description = "Hedges, wood and flowers.", Swatch = rgb(90, 200, 80),
		Floor = { rgb(105, 185, 80), "Grass" }, Stripe = { rgb(245, 255, 240), "SmoothPlastic" }, Band = { rgb(120, 85, 55), "Wood" },
		Top = { rgb(80, 160, 70), "Grass" }, Trim = rgb(140, 240, 110), Tower = { rgb(130, 95, 60), "Wood" },
		Cap = { rgb(70, 160, 60), "Grass" }, Gate = { rgb(120, 85, 55), "Wood" }, Rug = rgb(255, 160, 190) },
	{ Id = "gym_electric", Name = "Electric Gym", Gym = "gym_electric", Description = "Tesla towers and hazard stripes.", Swatch = rgb(255, 215, 40),
		Floor = { rgb(90, 90, 100), "DiamondPlate" }, Stripe = { rgb(255, 220, 50), "SmoothPlastic" }, Band = { rgb(60, 60, 70), "Metal" },
		Top = { rgb(255, 210, 40), "SmoothPlastic" }, Trim = rgb(255, 235, 80), Tower = { rgb(70, 70, 80), "Metal" },
		Cap = { rgb(255, 240, 90), "Neon" }, Gate = { rgb(60, 60, 70), "Metal" }, Rug = rgb(255, 220, 60) },
	{ Id = "gym_ice", Name = "Ice Gym", Gym = "gym_ice", Description = "Snow walls and crystal towers.", Swatch = rgb(160, 225, 255),
		Floor = { rgb(205, 232, 255), "Ice" }, Stripe = { rgb(250, 252, 255), "Snow" }, Band = { rgb(150, 200, 240), "Ice" },
		Top = { rgb(245, 250, 255), "Snow" }, Trim = rgb(140, 230, 255), Tower = { rgb(180, 220, 250), "Ice" },
		Cap = { rgb(230, 245, 255), "Glass" }, Gate = { rgb(150, 200, 240), "Ice" }, Rug = rgb(190, 230, 255) },
	{ Id = "gym_rock", Name = "Rock Gym", Gym = "gym_rock", Description = "Boulders and sandstone.", Swatch = rgb(170, 125, 80),
		Floor = { rgb(185, 150, 105), "Ground" }, Stripe = { rgb(250, 245, 235), "SmoothPlastic" }, Band = { rgb(140, 100, 65), "Rock" },
		Top = { rgb(215, 185, 140), "Sandstone" }, Trim = rgb(255, 190, 90), Tower = { rgb(120, 90, 65), "Rock" },
		Cap = { rgb(150, 115, 80), "Slate" }, Gate = { rgb(140, 100, 65), "Rock" }, Rug = rgb(235, 200, 140) },
	{ Id = "gym_psychic", Name = "Psychic Gym", Gym = "gym_psychic", Description = "Pink marble and floating crystals.", Swatch = rgb(230, 110, 230),
		Floor = { rgb(250, 215, 245), "Marble" }, Stripe = { rgb(255, 255, 255), "SmoothPlastic" }, Band = { rgb(190, 90, 200), "Marble" },
		Top = { rgb(255, 235, 250), "Marble" }, Trim = rgb(255, 200, 80), Tower = { rgb(210, 120, 220), "Marble" },
		Cap = { rgb(140, 70, 200), "SmoothPlastic" }, Gate = { rgb(190, 90, 200), "Marble" }, Rug = rgb(255, 150, 230) },
	{ Id = "gym_dark", Name = "Shadow Gym", Gym = "gym_dark", Description = "Moonlit stone and lanterns.", Swatch = rgb(110, 80, 200),
		Floor = { rgb(55, 55, 80), "Slate" }, Stripe = { rgb(200, 190, 255), "SmoothPlastic" }, Band = { rgb(35, 35, 70), "Slate" },
		Top = { rgb(70, 60, 110), "Slate" }, Trim = rgb(170, 110, 255), Tower = { rgb(40, 40, 75), "Slate" },
		Cap = { rgb(120, 80, 210), "Neon" }, Gate = { rgb(35, 35, 70), "Slate" }, Rug = rgb(140, 100, 230) },
}

Cosmetics.DecorSpots = 8

Cosmetics.Decor = {
	{ Id = "flowers", Name = "Flower Pot", Price = 5_000, Color = rgb(255, 120, 160) },
	{ Id = "lamp", Name = "Lamp Post", Price = 25_000, Color = rgb(255, 230, 140) },
	{ Id = "bush", Name = "Round Bush", Price = 60_000, Color = rgb(90, 190, 80) },
	{ Id = "balloons", Name = "Balloons", Price = 250_000, Color = rgb(255, 90, 90) },
	{ Id = "fountain", Name = "Fountain", Price = 1_500_000, Color = rgb(110, 200, 255) },
	{ Id = "eggstatue", Name = "Golden Egg Statue", Price = 15_000_000, Color = rgb(255, 200, 60) },
	{ Id = "trophy", Name = "Rebirth Trophy", Requires = { Rebirths = 3 }, Color = rgb(255, 215, 80) },
	{ Id = "lollipop", Name = "Giant Lollipop", Price = 100_000_000, World = "candy", Color = rgb(255, 110, 190) },
	{ Id = "snowman", Name = "Snowman", Price = 2_000_000_000, World = "frost", Color = rgb(240, 248, 255) },
	{ Id = "lavalamp", Name = "Lava Lamp", Price = 40_000_000_000, World = "lava", Color = rgb(255, 120, 30) },
	{ Id = "coral", Name = "Coral Tree", Price = 600_000_000_000, World = "reef", Color = rgb(255, 130, 120) },
	{ Id = "planet", Name = "Mini Planet", Price = 10_000_000_000_000, World = "galaxy", Color = rgb(170, 110, 255) },
}

Cosmetics.Trails = {
	{ Id = "sparkle", Name = "Sparkle", Colors = { rgb(255, 255, 255), rgb(160, 220, 255) } },
	{ Id = "leaf", Name = "Leafy", Price = 10_000, Colors = { rgb(90, 200, 80), rgb(200, 255, 120) } },
	{ Id = "fire", Name = "Fire", Price = 1_000_000, Colors = { rgb(255, 230, 80), rgb(255, 120, 30), rgb(230, 40, 30) } },
	{ Id = "candy", Name = "Candy Cane", World = "candy", Colors = { rgb(255, 80, 150), rgb(255, 255, 255), rgb(255, 80, 150) } },
	{ Id = "ice", Name = "Ice", World = "frost", Colors = { rgb(255, 255, 255), rgb(120, 200, 255) } },
	{ Id = "magma", Name = "Magma", World = "lava", Colors = { rgb(255, 200, 60), rgb(255, 80, 20), rgb(60, 20, 20) } },
	{ Id = "bubble", Name = "Bubbles", World = "reef", Colors = { rgb(120, 240, 240), rgb(60, 140, 255) } },
	{ Id = "galaxy", Name = "Galaxy", World = "galaxy", Colors = { rgb(255, 120, 230), rgb(140, 80, 255), rgb(40, 20, 90) } },
	{ Id = "thief", Name = "Thief", Requires = { Steals = 100 }, Colors = { rgb(255, 60, 60), rgb(20, 20, 20) } },
	{ Id = "gold", Name = "Golden", Requires = { Rebirths = 5 }, Colors = { rgb(255, 245, 160), rgb(255, 190, 40) } },
	{ Id = "rainbow", Name = "Rainbow", Requires = { Hatched = 500 }, Colors = {
		rgb(255, 80, 80), rgb(255, 190, 60), rgb(255, 255, 90), rgb(90, 230, 120), rgb(80, 170, 255), rgb(200, 110, 255),
	} },
}

Cosmetics.Titles = {
	{ Id = "rookie", Name = "Rookie", Color = rgb(200, 200, 210) },
	{ Id = "egghunter", Name = "Egg Hunter", Requires = { Hatched = 50 }, Color = rgb(140, 230, 120) },
	{ Id = "sneaky", Name = "Sneaky Thief", Requires = { Steals = 10 }, Color = rgb(255, 150, 90) },
	{ Id = "master", Name = "Master Thief", Requires = { Steals = 100 }, Color = rgb(255, 80, 80) },
	{ Id = "guardian", Name = "Guardian", Requires = { Defends = 25 }, Color = rgb(90, 170, 255) },
	{ Id = "collector", Name = "Collector", Requires = { Index = 30 }, Color = rgb(120, 220, 255) },
	{ Id = "reborn", Name = "Reborn", Requires = { Rebirths = 1 }, Color = rgb(190, 130, 255) },
	{ Id = "legend", Name = "Rebirth Legend", Requires = { Rebirths = 5 }, Color = rgb(255, 210, 60) },
	{ Id = "secret", Name = "Secret Keeper", Requires = { Secret = 1 }, Color = rgb(255, 255, 255) },
	{ Id = "traveler", Name = "World Traveler", Requires = { Worlds = 6 }, Color = rgb(255, 170, 60) },
	{ Id = "vip", Name = "VIP", Requires = { VIP = 1 }, Color = rgb(255, 215, 60) },
	{ Id = "premium", Name = "Premium", Requires = { Premium = 1 }, Color = rgb(240, 240, 255) },
	{ Id = "champ", Name = "Weekend Champ", Reward = true, Color = rgb(255, 200, 60) }, -- torneio de fim de semana (v12)
}

-- Prêmios das temporadas (Reward = só se ganha no passe da temporada; ficam para sempre)
table.insert(Cosmetics.Decor, { Id = "seasontrophy", Name = "Season Trophy", Reward = true, Color = rgb(255, 215, 90) })
for _, theme in Seasons.Themes do
	table.insert(Cosmetics.Trails, { Id = "season_" .. theme.Id, Name = theme.TrailName, Reward = true, Colors = theme.TrailColors })
	table.insert(Cosmetics.Titles, { Id = "season_" .. theme.Id, Name = theme.TitleName, Reward = true, Color = theme.TitleColor })
end

Cosmetics.ById = { theme = {}, decor = {}, trail = {}, title = {} }
for _, item in Cosmetics.Themes do
	Cosmetics.ById.theme[item.Id] = item
end
for _, item in Cosmetics.Decor do
	Cosmetics.ById.decor[item.Id] = item
end
for _, item in Cosmetics.Trails do
	Cosmetics.ById.trail[item.Id] = item
end
for _, item in Cosmetics.Titles do
	Cosmetics.ById.title[item.Id] = item
end

local REQUIREMENT_TEXT = {
	Rebirths = "Rebirth %d",
	Steals = "Steal %d critters",
	Hatched = "Hatch %d eggs",
	Defends = "BONK %d thieves",
	Index = "Find %d critters",
	Secret = "Hatch a SECRET",
	Worlds = "Unlock all %d worlds",
	VIP = "VIP pass",
	Premium = "Roblox Premium",
}
local REQUIREMENT_ORDER = { "Rebirths", "Steals", "Hatched", "Defends", "Index", "Secret", "Worlds", "VIP", "Premium" }

-- Situação de um item para um jogador:
--   "owned"  = já pode usar
--   "buy"    = liberado, falta comprar (Text = preço)
--   "locked" = falta conquista ou mundo (Text = o que falta)
-- stats = { Rebirths, Steals, Hatched, Defends, Index, Secret, Worlds, VIP, Premium, WorldSet = {id=true}, Owned = {"decor:id"=true} }
function Cosmetics.Status(kind: string, item, stats): (string, string)
	if item.World and not stats.WorldSet[item.World] then
		local world = Config.WorldById[item.World]
		return "locked", "Unlock " .. (if world then world.Name else item.World)
	end
	if item.Reward and not stats.Owned[kind .. ":" .. item.Id] then
		return "locked", "Season Pass reward"
	end
	if item.Requires then
		for _, key in REQUIREMENT_ORDER do
			local need = item.Requires[key]
			if need and (tonumber(stats[key]) or 0) < need then
				return "locked", (REQUIREMENT_TEXT[key]):format(need)
			end
		end
	end
	if item.Price and not stats.Owned[kind .. ":" .. item.Id] then
		return "buy", tostring(item.Price)
	end
	return "owned", ""
end

return Cosmetics
