--[[
	Events (ModuleScript em ServerScriptService > Game)
	Eventos com hora marcada (a tela mostra a contagem regressiva):
	  • CHUVA DE OVOS: a cada 15 min caem ovos GRÁTIS do céu nos caminhos (2x chance de mutação)
	  • EVENTO DA SORTE: no meio do caminho entre duas chuvas, ovos raros e mutações ficam mais comuns
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Events = {}

local raining = false

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Um ponto aleatório nos caminhos ao lado da esteira (fora das bases)
local function randomDropPoint(): Vector3
	local side = if math.random() < 0.5 then -1 else 1
	local x = math.random(-160, 160)
	local z = side * (8 + math.random() * 14)
	return Vector3.new(x, 0.2, z)
end

function Events.StartLucky(duration: number?, byName: string?)
	-- v20: se já está na sorte, o tempo SOMA (Lucky Potion comprada no meio do evento não perde nada)
	local current = tonumber(workspace:GetAttribute("LuckyUntil")) or 0
	local start = math.max(current, now())
	workspace:SetAttribute("LuckyUntil", start + (duration or Config.LuckyEventDuration))
	if byName then
		Registry.Remotes.NotifyAll(("%s used a LUCKY POTION! Rare eggs x%d and 2x mutations for EVERYONE!"):format(byName, Config.LuckyEggMultiplier), "rare")
	else
		Registry.Remotes.NotifyAll(("LUCKY EVENT! Rare eggs x%d and 2x mutations!"):format(Config.LuckyEggMultiplier), "rare")
	end
	Registry.Remotes.EffectAll("Lucky")
end

function Events.StartRain()
	if raining then
		return
	end
	raining = true
	workspace:SetAttribute("RainUntil", now() + Config.RainDuration)
	Registry.Remotes.NotifyAll("EGG RAIN! Free eggs are falling from the sky. CATCH THEM!", "rare")
	Registry.Remotes.EffectAll("Rain")
	task.spawn(function()
		local CritterService = Registry.CritterService
		local interval = Config.RainDuration / Config.RainCount
		-- ovos da chuva: sorteio próprio (Config.RainEggWeights), nunca Cosmic
		local total = 0
		for _, weight in Config.RainEggWeights do
			total += weight
		end
		for _ = 1, Config.RainCount do
			local roll = math.random() * total
			local chosen = Config.Eggs[1]
			for _, egg in Config.Eggs do
				local weight = Config.RainEggWeights[egg.Id] or 0
				if weight > 0 then
					roll -= weight
					if roll <= 0 then
						chosen = egg
						break
					end
				end
			end
			CritterService.SpawnRainEgg(chosen, randomDropPoint())
			task.wait(interval)
		end
		raining = false
	end)
end

function Events.Init()
	local start = now()
	workspace:SetAttribute("NextRain", start + Config.EventEvery)
	workspace:SetAttribute("NextLucky", start + Config.EventEvery / 2)

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				local t = now()
				local nextRain = workspace:GetAttribute("NextRain") :: number
				if t >= nextRain then
					workspace:SetAttribute("NextRain", nextRain + Config.EventEvery)
					Events.StartRain()
				end
				local nextLucky = workspace:GetAttribute("NextLucky") :: number
				if t >= nextLucky then
					workspace:SetAttribute("NextLucky", nextLucky + Config.EventEvery)
					Events.StartLucky()
				end
			end)
			if not ok then
				warn("[Events] loop error:", err)
			end
		end
	end)
end

return Events
