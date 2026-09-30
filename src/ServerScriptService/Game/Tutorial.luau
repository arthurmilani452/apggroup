--[[
	Tutorial (ModuleScript em ServerScriptService > Game)
	Guia o jogador novo no primeiro minuto. O servidor diz em qual passo ele está
	(atributo "TutorialStep") e a tela mostra o texto e a seta.
	  1 = comprar um ovo na esteira   2 = seguir o ovo até a base   3 = esperar o ovo chocar
	  4 = coletar no pad verde        5 = trancar a base            6 = explicar roubo e taco (fim)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Tutorial = {}

-- qual evento completa cada passo
local STEP_OF = {
	Bought = 1,
	Placed = 2,
	Hatched = 3,
	Collected = 4,
	Locked = 5,
}
local LAST_STEP = 6

local ORDER = { "Bought", "Placed", "Hatched", "Collected", "Locked" }
local FUNNEL = {
	Bought = "BoughtEgg",
	Placed = "EggArrived",
	Hatched = "Hatched",
	Collected = "Collected",
	Locked = "Locked",
}

local function funnel(player: Player, name: string)
	local analytics = Registry.Analytics
	if analytics then
		analytics.Funnel(player, name)
	end
end

local function setStep(player: Player, step: number?)
	player:SetAttribute("TutorialStep", step)
end

function Tutorial.Finish(player: Player, skipped: boolean?)
	local profile = Registry.Data.Get(player)
	if not profile or profile.Data.TutorialDone or player:GetAttribute("TutorialStep") == nil then
		return
	end
	profile.Data.TutorialDone = true
	local stepAtEnd = tonumber(player:GetAttribute("TutorialStep")) or 0
	if skipped and stepAtEnd >= LAST_STEP then
		skipped = false -- apertou SKIP no último passo: já fez tudo, ganha o prêmio
	end
	setStep(player, nil)
	if skipped then
		local analytics = Registry.Analytics
		if analytics then
			analytics.Event(player, "TutorialSkipped", stepAtEnd)
		end
		return
	end
	funnel(player, "Finished")
	Registry.Economy.AddCash(player, Config.TutorialReward, false, "Tutorial")
	local starter = Config.EggById[Config.StarterEgg]
	if starter then
		Registry.CritterService.GrantEgg(player, starter.Id)
	end
	Registry.Remotes.Notify(player, ("Tutorial complete! +%s and a FREE %s!"):format(Format.Money(Config.TutorialReward), if starter then starter.Name else "egg"), "rare")
end

function Tutorial.Start(player: Player)
	local profile = Registry.Data.Get(player)
	if not profile or profile.Data.TutorialDone then
		return
	end
	funnel(player, "Joined")
	setStep(player, 1)
end

function Tutorial.Event(player: Player, eventName: string)
	local step = player:GetAttribute("TutorialStep")
	local done = STEP_OF[eventName]
	if typeof(step) ~= "number" or not done then
		return
	end
	-- Os passos do ovo (comprar -> chegar -> chocar) podem acontecer rápido e "pular" passos.
	-- Coletar e trancar só contam no passo certo.
	local valid = done == step or (done > step and done <= STEP_OF.Hatched)
	if not valid then
		return
	end
	-- registra também os passos que foram "pulados" (o funil fica certinho)
	for i = step, done do
		funnel(player, FUNNEL[ORDER[i]])
	end
	local nextStep = done + 1
	-- se a base já está trancada ou recarregando, pula o passo de trancar
	if nextStep == STEP_OF.Locked then
		local plot = Registry.Plots.Get(player)
		local cooldownUntil = if plot then plot.Model:GetAttribute("CooldownUntil") or 0 else 0
		if plot and (Registry.Plots.IsLocked(plot) or cooldownUntil > workspace:GetServerTimeNow()) then
			nextStep = LAST_STEP
			funnel(player, FUNNEL.Locked)
		end
	end
	setStep(player, nextStep)
	if nextStep == LAST_STEP then
		task.delay(10, function()
			if player.Parent and player:GetAttribute("TutorialStep") == LAST_STEP then
				Tutorial.Finish(player)
			end
		end)
	end
end

function Tutorial.Init() end

return Tutorial
