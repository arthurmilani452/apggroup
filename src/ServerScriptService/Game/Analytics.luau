--[[
	Analytics (ModuleScript em ServerScriptService > Game)
	Manda números para o painel do Creator Hub (Analytics > Funnels / Economy / Custom):
	  • FUNIL do tutorial: onde os jogadores novos desistem
	  • ECONOMIA: de onde vem o dinheiro (coletar, vender, diária...) e para onde vai (ovos, vagas...)
	  • EVENTOS: ovos chocados por raridade, roubos, códigos, rebirths
	O dinheiro é somado e enviado 1x por minuto (o Roblox tem limite de eventos por minuto).
	Se algo falhar aqui, o jogo continua normal (tudo dentro de pcall).
]]

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local CURRENCY = "Cash"
local FLUSH_EVERY = 60

-- buffer[player][flow][kind] = soma
local buffer: { [Player]: { Source: { [string]: number }, Sink: { [string]: number } } } = {}
local funnelDone: { [Player]: { [number]: boolean } } = {}

local FUNNEL_STEPS = {
	"Joined",
	"BoughtEgg",
	"EggArrived",
	"Hatched",
	"Collected",
	"Locked",
	"Finished",
}

local function safe(callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warn("[Analytics]", err)
	end
end

local function cashOf(player: Player): number
	local cash = player:GetAttribute("Cash")
	return if typeof(cash) == "number" then cash else 0
end

local function add(player: Player, flow: string, kind: string, amount: number)
	if amount ~= amount or amount <= 0 then
		return
	end
	local entry = buffer[player]
	if not entry then
		entry = { Source = {}, Sink = {} }
		buffer[player] = entry
	end
	local list = entry[flow]
	list[kind] = (list[kind] or 0) + amount
end

local function flush(player: Player)
	local entry = buffer[player]
	if not entry then
		return
	end
	buffer[player] = nil
	local balance = cashOf(player)
	for kind, amount in entry.Source do
		safe(function()
			AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, CURRENCY, math.floor(amount), balance, kind)
		end)
	end
	for kind, amount in entry.Sink do
		safe(function()
			AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, CURRENCY, math.floor(amount), balance, kind)
		end)
	end
end

-- Dinheiro que ENTRA (kind: "Collect", "Sell", "Daily", "Offline", "Code", "Tutorial", "CashPack"...)
function Analytics.CashSource(player: Player, amount: number, kind: string)
	add(player, "Source", kind, amount)
end

-- Dinheiro que SAI (kind: "Egg", "Speed", "Slot", "Rebirth")
function Analytics.CashSink(player: Player, amount: number, kind: string)
	add(player, "Sink", kind, amount)
end

-- Funil do tutorial (cada passo só conta 1x por jogador)
function Analytics.Funnel(player: Player, stepName: string)
	local step = table.find(FUNNEL_STEPS, stepName)
	if not step then
		return
	end
	local done = funnelDone[player]
	if not done then
		done = {}
		funnelDone[player] = done
	end
	if done[step] then
		return
	end
	done[step] = true
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function Analytics.Event(player: Player, eventName: string, value: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1)
	end)
end

-- Chamados pelo CritterService
function Analytics.EggBought(player: Player, egg, price: number)
	Analytics.CashSink(player, price, "Egg")
	Analytics.Event(player, "EggBought_" .. egg.Id)
end

function Analytics.Hatched(player: Player, def, _mutation: string?, _egg)
	Analytics.Event(player, "Hatch_" .. def.Rarity)
end

function Analytics.Stole(player: Player, _rec)
	Analytics.Event(player, "Steal")
end

-- Chamado pelo Main quando o jogador sai (depois de guardar o dinheiro do coletor)
function Analytics.RemovePlayer(player: Player)
	flush(player)
	buffer[player] = nil
	funnelDone[player] = nil
end

function Analytics.Init()
	task.spawn(function()
		while true do
			task.wait(FLUSH_EVERY)
			local ok, err = pcall(function()
				for player in buffer do
					if player.Parent then
						flush(player)
					else
						buffer[player] = nil
					end
				end
			end)
			if not ok then
				warn("[Analytics] loop error:", err)
			end
		end
	end)
end

return Analytics
