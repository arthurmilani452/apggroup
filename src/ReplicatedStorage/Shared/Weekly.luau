--[[
	Weekly (ModuleScript em ReplicatedStorage > Shared) - v26: CRITTER DA SEMANA
	Toda semana (segunda 00:00 UTC até domingo) um critter exclusivo sai do "Weekly Egg" da esteira do Meadow.
	A lista dos critters fica em Critters (Critters.Weekly, campo Week); o rodízio repete a cada #lista semanas.
	Servidor: Weekly.InitServer(Registry) publica os atributos no Workspace ("WeeklyName", "WeeklyId", "WeeklyEnds")
	e avisa todo mundo quando a semana vira. Cliente: lê os atributos para mostrar na tela.
]]

local Critters = require(script.Parent.Critters)

local Weekly = {}

Weekly.Enabled = true
local WEEK = 7 * 86400
local MONDAY_SHIFT = 3 * 86400 -- o "dia 0" do os.time() foi uma quinta; +3 dias = semanas começando na segunda (UTC)

function Weekly.WeekNumber(t: number?): number
	return math.floor(((t or os.time()) + MONDAY_SHIFT) / WEEK)
end

-- os.time() em que a semana atual termina (domingo 23:59:59 UTC)
function Weekly.EndsAt(t: number?): number
	return (Weekly.WeekNumber(t) + 1) * WEEK - MONDAY_SHIFT
end

function Weekly.Slot(t: number?): number
	local list = Critters.Weekly or {}
	if #list == 0 then
		return 0
	end
	return (Weekly.WeekNumber(t) % #list) + 1
end

-- Definição do critter desta semana (nil se desligado ou sem lista)
function Weekly.Current(t: number?)
	if not Weekly.Enabled then
		return nil
	end
	local list = Critters.Weekly or {}
	return list[Weekly.Slot(t)]
end

-- É o critter da semana ATUAL? (o Weekly Egg só choca esse)
function Weekly.IsCurrent(critterId: string?): boolean
	local def = Weekly.Current()
	return def ~= nil and def.Id == critterId
end

function Weekly.TimeLeftText(t: number?): string
	local left = math.max(0, Weekly.EndsAt(t) - (t or os.time()))
	local days = math.floor(left / 86400)
	local hours = math.floor((left % 86400) / 3600)
	local minutes = math.floor((left % 3600) / 60)
	if days > 0 then
		return ("%dd %dh"):format(days, hours)
	elseif hours > 0 then
		return ("%dh %dm"):format(hours, minutes)
	end
	return ("%dm"):format(math.max(1, minutes))
end

function Weekly.InitServer(Registry)
	local lastId = nil
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				local def = Weekly.Current()
				workspace:SetAttribute("WeeklyId", def and def.Id or nil)
				workspace:SetAttribute("WeeklyName", def and def.Name or nil)
				workspace:SetAttribute("WeeklyRarity", def and def.Rarity or nil)
				workspace:SetAttribute("WeeklyEnds", def and Weekly.EndsAt() or nil)
				if def and lastId ~= nil and lastId ~= def.Id and Registry and Registry.Remotes then
					Registry.Remotes.NotifyAll(("NEW WEEK! Critter of the Week: %s (%s). Find it in the Weekly Egg!"):format(def.Name, string.upper(def.Rarity)), "rare")
				end
				lastId = def and def.Id or nil
			end)
			if not ok then
				warn("[Weekly] loop error:", err)
			end
			task.wait(30)
		end
	end)
end

return Weekly
