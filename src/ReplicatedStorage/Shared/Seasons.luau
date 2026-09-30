--[[
	Seasons (ModuleScript em ReplicatedStorage > Shared)
	Parte 16: TEMPORADAS de 30 dias com passe de 30 níveis.
	  • Trilha grátis: todo mundo ganha uma recompensa a cada nível
	  • Trilha paga (Season Pass, Dev Product em Config.DevProducts.SeasonPass): mais recompensas
	  • Níveis bônus 31-60: quem NÃO tem o passe ganha as recompensas pagas de graça, uma por nível
	    (tudo que é pago dá para ganhar de graça, só que mais devagar)
	As temporadas mudam sozinhas a cada 30 dias, contando a partir de Seasons.Epoch,
	e os temas (nome, cores, trilha e título exclusivos) vão se repetindo na ordem da lista.
	XP: chocar, roubar, BONK em ladrão, fusão, rebirth, mundo novo, diária e tempo de jogo.
]]

local Seasons = {}

Seasons.Epoch = 1790380800 -- 26/09/2026 00:00 UTC = começo da Temporada 1 (mude para a data do lançamento)
Seasons.Length = 30 * 86400 -- 30 dias
Seasons.Levels = 30
Seasons.BonusLevels = 30
Seasons.BonusCost = 600 -- XP de cada nível bônus

-- XP ganho em cada ação
Seasons.XP = {
	Hatch = 5,
	Steal = 25,
	Defend = 20,
	Fuse = 30,
	Rebirth = 150,
	World = 100,
	Daily = 50,
	Minute = 2, -- a cada minuto jogando
	Mix = 30, -- híbrido no laboratório
	GiantEgg = 40, -- ajudou a chocar o Ovo Gigante do servidor
}
-- Ações que contam no limite diário (para ninguém "farmar" XP com um amigo ou outra conta)
Seasons.ActionXP = { Hatch = true, Steal = true, Defend = true, Fuse = true, Mix = true, GiantEgg = true }
Seasons.DailyActionCap = 600 -- no máximo 600 XP por dia vindos de ações (tempo de jogo, diária, rebirth e mundo não contam)
Seasons.PairCooldown = 300 -- roubar/defender contra a MESMA pessoa só dá XP 1 vez a cada 5 min

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Temas das temporadas (repetem em ordem). TrailColors/TitleColor = visual dos prêmios exclusivos.
Seasons.Themes = {
	{ Id = "sweet", Name = "Sweet Heist", Color = rgb(255, 120, 190), TrailName = "Sugar Rush", TitleName = "Sweet Thief",
		TrailColors = { rgb(255, 120, 190), rgb(255, 255, 255), rgb(120, 220, 255) }, TitleColor = rgb(255, 140, 200) },
	{ Id = "frozen", Name = "Frozen Frenzy", Color = rgb(120, 200, 255), TrailName = "Snowstorm", TitleName = "Ice Bandit",
		TrailColors = { rgb(255, 255, 255), rgb(120, 200, 255), rgb(60, 120, 230) }, TitleColor = rgb(150, 215, 255) },
	{ Id = "blaze", Name = "Lava Rush", Color = rgb(255, 120, 40), TrailName = "Firestorm", TitleName = "Lava Raider",
		TrailColors = { rgb(255, 230, 80), rgb(255, 110, 30), rgb(120, 20, 20) }, TitleColor = rgb(255, 140, 60) },
	{ Id = "deep", Name = "Deep Dive", Color = rgb(60, 210, 210), TrailName = "Tidal Wave", TitleName = "Pirate",
		TrailColors = { rgb(160, 255, 240), rgb(40, 180, 200), rgb(20, 70, 160) }, TitleColor = rgb(90, 230, 220) },
	{ Id = "star", Name = "Star Raiders", Color = rgb(170, 110, 255), TrailName = "Stardust", TitleName = "Space Thief",
		TrailColors = { rgb(255, 235, 140), rgb(190, 120, 255), rgb(40, 20, 100) }, TitleColor = rgb(200, 150, 255) },
	{ Id = "garden", Name = "Garden Party", Color = rgb(110, 210, 90), TrailName = "Petal Storm", TitleName = "Flower Bandit",
		TrailColors = { rgb(255, 170, 210), rgb(255, 240, 120), rgb(110, 210, 90) }, TitleColor = rgb(140, 225, 110) },
}

-- Qual temporada está valendo agora
function Seasons.Current(now: number): (number, any, number, number)
	local index = math.max(0, math.floor((now - Seasons.Epoch) / Seasons.Length))
	local startsAt = Seasons.Epoch + index * Seasons.Length
	local theme = Seasons.Themes[index % #Seasons.Themes + 1]
	return index + 1, theme, startsAt, startsAt + Seasons.Length
end

-- XP para passar do nível (level - 1) para o nível level
function Seasons.Cost(level: number): number
	if level <= Seasons.Levels then
		return 100 + 10 * level -- total dos 30 níveis: 7.650 XP (~25 dias jogando 20 min por dia)
	end
	return Seasons.BonusCost
end

-- Nível atual (0 a 60), XP dentro do nível e XP que falta para o próximo
function Seasons.LevelFromXP(xp: number): (number, number, number)
	local level = 0
	local left = math.max(0, math.floor(xp))
	while level < Seasons.Levels + Seasons.BonusLevels do
		local cost = Seasons.Cost(level + 1)
		if left < cost then
			return level, left, cost
		end
		left -= cost
		level += 1
	end
	return level, 0, 0
end

-- Recompensa de um nível (1 a 30) numa trilha ("Free" ou "Paid").
-- Tipos iguais aos dos códigos: Minutes, WorldEgg, BigEgg, Boost e Cosmetic ("trail:season_sweet").
function Seasons.Reward(theme, level: number, track: string)
	if track == "Free" then
		if level == 30 then
			return { Cosmetic = "title:season_" .. theme.Id, BigEgg = 1 }
		elseif level == 5 then
			return { WorldEgg = 2 }
		elseif level == 10 or level == 20 then
			return { BigEgg = 1 }
		elseif level == 15 then
			return { Boost = 20 }
		elseif level == 25 then
			return { Minutes = 30 }
		elseif level % 2 == 1 then
			return { Minutes = 5 + level // 2 }
		end
		return { WorldEgg = 1 }
	end
	if level == 5 then
		return { Cosmetic = "trail:season_" .. theme.Id }
	elseif level == 30 then
		return { Cosmetic = "decor:seasontrophy", BigEgg = 3 }
	elseif level == 10 or level == 20 then
		return { BigEgg = 2 }
	elseif level == 15 then
		return { Boost = 30 }
	elseif level == 25 then
		return { Minutes = 60 }
	elseif level % 2 == 1 then
		return { Boost = 10 }
	end
	return { WorldEgg = 2 }
end

-- Onde itens aleatórios pagos são proibidos (PolicyService), os OVOS da trilha paga viram dinheiro fixo:
-- Egg = 10 min de renda, Big Egg = 25 min de renda. Sem ovo, a recompensa não muda.
function Seasons.NoRandom(reward: any): any
	if type(reward) ~= "table" or (not reward.WorldEgg and not reward.BigEgg) then
		return reward
	end
	local safe = table.clone(reward)
	safe.Minutes = (safe.Minutes or 0) + (safe.WorldEgg or 0) * 10 + (safe.BigEgg or 0) * 25
	safe.WorldEgg = nil
	safe.BigEgg = nil
	return safe
end

-- Texto curto de uma recompensa (para a tela do passe)
function Seasons.RewardText(theme, reward): string
	local parts = {}
	if reward.Cosmetic then
		local kind = string.split(reward.Cosmetic, ":")[1]
		if kind == "trail" then
			table.insert(parts, "Trail: " .. theme.TrailName)
		elseif kind == "title" then
			table.insert(parts, "Title: " .. theme.TitleName)
		else
			table.insert(parts, "Season Trophy")
		end
	end
	if reward.Minutes then
		table.insert(parts, reward.Minutes .. " min of cash")
	end
	if reward.WorldEgg then
		table.insert(parts, reward.WorldEgg .. "x Egg")
	end
	if reward.BigEgg then
		table.insert(parts, reward.BigEgg .. "x Big Egg")
	end
	if reward.Boost then
		table.insert(parts, "2x Cash " .. reward.Boost .. " min")
	end
	return table.concat(parts, " + ")
end

return Seasons
