--[[
	Progression (ModuleScript em ReplicatedStorage > Shared)
	Parte 26 + missões diárias + conquistas (v10). Tudo o que o servidor e as telas precisam saber:
	  • NÍVEL da conta (XP de jogar, chocar, roubar...; o mesmo limite diário anti-farm do passe)
	  • ÁRVORE DE HABILIDADES: 1 ponto por nível; Speed, Luck, Defense e Steal (5 níveis cada)
	  • CLASSES: Thief, Guardian ou Creator (trocar é grátis; espera 30 min entre trocas)
	  • PRESTÍGIO: com 10 rebirths, recomeça os rebirths e ganha aura, estrela no nome e +100% de dinheiro para sempre
	  • MISSÕES DIÁRIAS: 3 por dia (iguais para o mesmo jogador no mesmo dia), 1 troca grátis por dia
	  • CONQUISTAS: aparecem no PROFILE; se você criar os Badges no Roblox, coloque os IDs em BadgeIds
	Nada disso é vendido: tudo se ganha jogando.
]]

local Progression = {}

---------------------------------------------------------------------
-- Nível da conta
---------------------------------------------------------------------
-- XP para ir do nível L para o L+1
function Progression.LevelCost(level: number): number
	return 100 + 40 * level
end

-- (nível, XP dentro do nível, XP que falta para o próximo)
function Progression.LevelFromXP(xp: number): (number, number, number)
	local level = 1
	local left = math.max(0, math.floor(xp))
	while level < 999 and left >= Progression.LevelCost(level) do
		left -= Progression.LevelCost(level)
		level += 1
	end
	return level, left, Progression.LevelCost(level)
end

---------------------------------------------------------------------
-- Habilidades (1 ponto por nível a partir do nível 2)
---------------------------------------------------------------------
Progression.SkillOrder = { "Speed", "Luck", "Defense", "Steal" }
Progression.Skills = {
	Speed = { Name = "Speed", Max = 5, Per = 0.02, Desc = "+2% walk speed per level" },
	Luck = { Name = "Luck", Max = 5, Per = 0.05, Desc = "+5% mutation chance per level (Gold, Diamond, Rainbow)" },
	Defense = { Name = "Defense", Max = 5, Per = 3, Desc = "+3 seconds of base lock per level" },
	Steal = { Name = "Steal", Max = 5, Per = 0.02, Desc = "+2% speed while carrying a stolen critter per level" },
}

function Progression.PointsForLevel(level: number): number
	return math.max(0, level - 1)
end

---------------------------------------------------------------------
-- Classes (efeitos pequenos: ninguém fica imbatível)
---------------------------------------------------------------------
Progression.ClassOrder = { "Thief", "Guardian", "Creator" }
Progression.Classes = {
	Thief = { Name = "Thief", Desc = "+5% speed while carrying a stolen critter", Color = Color3.fromRGB(255, 110, 110) },
	Guardian = { Name = "Guardian", Desc = "+10 seconds of base lock", Color = Color3.fromRGB(90, 160, 255) },
	Creator = { Name = "Creator", Desc = "Your eggs hatch 15% faster", Color = Color3.fromRGB(120, 230, 140) },
}
Progression.ClassCooldown = 30 * 60
Progression.ThiefCarry = 0.05
Progression.GuardianLock = 10
Progression.CreatorHatch = 0.85
Progression.MaxCarryMultiplier = 0.95 -- quem carrega nunca fica mais rápido do que 95% do normal

---------------------------------------------------------------------
-- Prestígio
---------------------------------------------------------------------
Progression.PrestigeRebirths = 10 -- o 1º prestígio pede 10 rebirths; cada próximo pede +1 (11, 12...)
Progression.PrestigeBonus = 1.0 -- +100% de dinheiro por prestígio (para sempre)
Progression.PrestigeColors = {
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(90, 230, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 110, 190),
	Color3.fromRGB(120, 255, 150),
}

function Progression.PrestigeNeed(prestige: number): number
	return Progression.PrestigeRebirths + math.max(0, prestige)
end

function Progression.PrestigeColor(prestige: number): Color3
	local colors = Progression.PrestigeColors
	return colors[math.clamp(prestige, 1, #colors)]
end

---------------------------------------------------------------------
-- Missões diárias
---------------------------------------------------------------------
-- Kind = o evento que conta; Need = quantas vezes; Weight = chance de ser sorteada
Progression.MissionPool = {
	{ Kind = "Hatch", Need = 5, Weight = 3, Text = "Hatch %d eggs" },
	{ Kind = "Buy", Need = 3, Weight = 3, Text = "Buy %d eggs from the conveyor" },
	{ Kind = "Pet", Need = 3, Weight = 2, Text = "Pet %d of your critters (press T)" },
	{ Kind = "Minute", Need = 15, Weight = 2, Text = "Play for %d minutes" },
	{ Kind = "Feed", Need = 1, Weight = 1, Text = "Feed your critters %d time" },
	{ Kind = "Steal", Need = 2, Weight = 2, Text = "Steal %d critters" },
	{ Kind = "Defend", Need = 1, Weight = 1, Text = "BONK %d thief with your bat" },
	{ Kind = "GiantEgg", Need = 1, Weight = 1, Text = "Help hatch the Giant Egg %d time" },
	{ Kind = "Rain", Need = 2, Weight = 1, Text = "Catch %d free eggs in the Egg Rain" },
	{ Kind = "Minigame", Need = 1, Weight = 2, Text = "Play %d minigame" },
	{ Kind = "Hunt", Need = 3, Weight = 2, Text = "Find %d hidden Hunt Eggs in Meadow" },
	{ Kind = "Fish", Need = 3, Weight = 1, Text = "Catch %d fish at the pond" },
	{ Kind = "Dig", Need = 2, Weight = 1, Text = "Dig %d sand patches" },
}
Progression.MissionCount = 3
Progression.MissionReward = { Minutes = 5 } -- cada missão: 5 minutos da sua renda (mínimo $1,000)
Progression.MissionBonus = { WorldEgg = 1 } -- as 3 do dia: um ovo grátis do seu melhor mundo
Progression.MissionBonusXP = 60

function Progression.MissionText(kind: string, need: number): string
	for _, info in Progression.MissionPool do
		if info.Kind == kind then
			return info.Text:format(need)
		end
	end
	return kind
end

-- As 3 missões do dia (mesmo dia + mesmo jogador = mesmas missões, até em outro servidor)
function Progression.PickMissions(userId: number, day: number, skip: string?): { { Kind: string, Need: number } }
	local random = Random.new((userId % 1000003) * 7919 + day * 104729)
	local pool = {}
	for _, info in Progression.MissionPool do
		if info.Kind ~= skip then
			table.insert(pool, info)
		end
	end
	local chosen = {}
	while #chosen < Progression.MissionCount and #pool > 0 do
		local total = 0
		for _, info in pool do
			total += info.Weight
		end
		local roll = random:NextNumber() * total
		for index, info in pool do
			roll -= info.Weight
			if roll <= 0 or index == #pool then
				table.insert(chosen, { Kind = info.Kind, Need = info.Need })
				table.remove(pool, index)
				break
			end
		end
	end
	return chosen
end

---------------------------------------------------------------------
-- Conquistas (in-game) + Badges do Roblox (opcional)
---------------------------------------------------------------------
-- Stat = campo do resumo que o servidor calcula; At = quanto precisa
Progression.Achievements = {
	{ Id = "Welcome", Name = "Welcome!", Desc = "Join Steal a Critter", Stat = "Joined", At = 1 },
	{ Id = "FirstHatch", Name = "First Hatch", Desc = "Hatch your first egg", Stat = "Hatched", At = 1 },
	{ Id = "Hatcher", Name = "Egg Expert", Desc = "Hatch 100 eggs", Stat = "Hatched", At = 100 },
	{ Id = "FirstSteal", Name = "Sneaky!", Desc = "Steal your first critter", Stat = "Steals", At = 1 },
	{ Id = "MasterThief", Name = "Master Thief", Desc = "Steal 50 critters", Stat = "Steals", At = 50 },
	{ Id = "Guardian", Name = "Base Guardian", Desc = "BONK 10 thieves", Stat = "Defends", At = 10 },
	{ Id = "Legendary", Name = "Legend!", Desc = "Find a Legendary critter", Stat = "Legendary", At = 1 },
	{ Id = "Mythic", Name = "Myth Hunter", Desc = "Find a Mythic critter", Stat = "Mythic", At = 1 },
	{ Id = "Secret", Name = "Secret Keeper", Desc = "Find a Secret critter", Stat = "Secret", At = 1 },
	{ Id = "Shiny", Name = "So Shiny!", Desc = "Hatch a SHINY critter (1 in 1000)", Stat = "Shinies", At = 1 },
	{ Id = "Mixer", Name = "Mad Scientist", Desc = "Make a hybrid at the MIX LAB", Stat = "Mixes", At = 1 },
	{ Id = "Teamwork", Name = "Teamwork", Desc = "Help hatch a Giant Egg", Stat = "GiantEggs", At = 1 },
	{ Id = "Rebirth", Name = "Reborn", Desc = "Do your first Rebirth", Stat = "Rebirths", At = 1 },
	{ Id = "Galaxy", Name = "Space Explorer", Desc = "Unlock Galaxy Station", Stat = "Galaxy", At = 1 },
	{ Id = "Collector", Name = "Collector", Desc = "Find 50 different critters", Stat = "Collected", At = 50 },
	{ Id = "Quests", Name = "Quest Master", Desc = "Finish all 3 daily quests", Stat = "MissionDays", At = 1 },
	{ Id = "Level10", Name = "Level 10", Desc = "Reach level 10", Stat = "Level", At = 10 },
	{ Id = "Prestige", Name = "PRESTIGE", Desc = "Prestige for the first time (10 rebirths)", Stat = "Prestige", At = 1 },
	{ Id = "Champion", Name = "Champion", Desc = "Win 10 minigames", Stat = "MinigameWins", At = 10 },
	{ Id = "Explorer", Name = "Explorer", Desc = "Visit the Secret Island", Stat = "IslandVisits", At = 1 },
	{ Id = "Angler", Name = "Angler", Desc = "Catch 25 fish", Stat = "Fish", At = 25 },
	{ Id = "Paleontologist", Name = "Paleontologist", Desc = "Dig up a Fossil Egg", Stat = "Fossils", At = 1 },
	{ Id = "EggHunt", Name = "Egg Hunt Master", Desc = "Find all 10 Hunt Eggs in one day", Stat = "HuntDays", At = 1 },
}
Progression.AchievementById = {}
for _, achievement in Progression.Achievements do
	Progression.AchievementById[achievement.Id] = achievement
end

-- IDs dos Badges (Creator Dashboard > seu jogo > Engagement > Badges). 0 = só a conquista dentro do jogo.
Progression.BadgeIds = {
	Welcome = 2905435231756459, -- v25: criados no Creator Hub em 29/09/2026 (5 grátis por dia)
	FirstHatch = 2046121741778047,
	Hatcher = 0,
	FirstSteal = 1340781185028401,
	MasterThief = 0,
	Guardian = 3523557668066225,
	Legendary = 953304939592936,
	Mythic = 0,
	Secret = 0,
	Shiny = 0,
	Mixer = 0,
	Teamwork = 0,
	Rebirth = 0,
	Galaxy = 0,
	Collector = 0,
	Quests = 0,
	Level10 = 0,
	Prestige = 0,
	Champion = 0,
	Explorer = 0,
	Angler = 0,
	Paleontologist = 0,
	EggHunt = 0,
}

return Progression
