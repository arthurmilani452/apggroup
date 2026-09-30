--[[
	Environment (ModuleScript em ServerScriptService > Game)
	Parte 21: DIA E NOITE + CLIMA do servidor.
	  • Dia e noite: um dia inteiro dura Config.DayLength (20 min). O relógio sai do horário do servidor,
	    então todo mundo vê a mesma hora. A tela de cada jogador muda o Lighting.ClockTime.
	  • Clima: Sun, Rain ou Snow, trocando a cada 4-6 minutos (Config.WeatherChances).
	  • Ovos de clima (Storm/Snowflake/Moon) só aparecem na esteira e só chocam no clima certo.
	O estado fica em atributos do Workspace: "Weather" e "Night" (as telas leem daí).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Environment = {}

local weather = "Sun"
local forcedNightUntil = 0

-- Hora do dia (0-24) num instante; o dia claro ocupa Config.DayFraction do ciclo
function Environment.ClockAt(serverTime: number): number
	local phase = (serverTime % Config.DayLength) / Config.DayLength
	local day = Config.DayFraction
	if phase < day then
		return 6.5 + phase / day * 11 -- 6:30 até 17:30
	end
	return (17.5 + (phase - day) / (1 - day) * 13) % 24 -- 17:30 até 6:30 do outro dia
end

function Environment.IsNight(): boolean
	if os.clock() < forcedNightUntil then
		return true
	end
	local clock = Environment.ClockAt(workspace:GetServerTimeNow())
	return clock >= 18.5 or clock < 5.5
end

function Environment.Weather(): string
	return weather
end

-- "Rain", "Snow" ou "Night" está valendo agora?
function Environment.IsActive(condition: string): boolean
	if condition == "Night" then
		return Environment.IsNight()
	end
	if condition == "Weekly" then -- v26: o Weekly Egg fica na esteira a semana inteira
		return require(game:GetService("ReplicatedStorage").Shared.Weekly).Current() ~= nil
	end
	return weather == condition
end

local MESSAGES = {
	Rain = "It's RAINING! Storm Eggs are on the conveyor!",
	Snow = "It's SNOWING! Snowflake Eggs are on the conveyor!",
	Sun = "The sun is back!",
}

function Environment.SetWeather(newWeather: string)
	if not Config.WeatherChances[newWeather] or newWeather == weather then
		return
	end
	weather = newWeather
	workspace:SetAttribute("Weather", weather)
	local remotes = Registry.Remotes
	if remotes then
		remotes.NotifyAll(MESSAGES[weather] or weather, if weather == "Sun" then "info" else "rare")
	end
end

-- Admin/teste: noite agora por 3 minutos
function Environment.ForceNight(seconds: number)
	forcedNightUntil = os.clock() + seconds
	workspace:SetAttribute("ForcedNight", workspace:GetServerTimeNow() + seconds)
end

local function rollWeather(): string
	local total = 0
	for _, chance in Config.WeatherChances do
		total += chance
	end
	local roll = math.random() * total
	for _, name in { "Sun", "Rain", "Snow" } do
		roll -= Config.WeatherChances[name] or 0
		if roll <= 0 then
			return name
		end
	end
	return "Sun"
end

function Environment.Init()
	workspace:SetAttribute("Weather", weather)
	workspace:SetAttribute("DayLength", Config.DayLength)
	workspace:SetAttribute("DayFraction", Config.DayFraction)
	-- troca de clima
	task.spawn(function()
		while true do
			task.wait(math.random(Config.WeatherMinutes[1] * 60, Config.WeatherMinutes[2] * 60))
			local ok, err = pcall(function()
				Environment.SetWeather(rollWeather())
			end)
			if not ok then
				warn("[Environment] loop error:", err)
			end
		end
	end)
	-- avisa quando começa a noite
	task.spawn(function()
		local wasNight = Environment.IsNight()
		while true do
			task.wait(2)
			local ok, err = pcall(function()
				local night = Environment.IsNight()
				workspace:SetAttribute("Night", night)
				if night ~= wasNight then
					wasNight = night
					local remotes = Registry.Remotes
					if remotes and night then
						remotes.NotifyAll("Night has fallen... Moon Eggs are on the conveyor!", "rare")
					end
				end
			end)
			if not ok then
				warn("[Environment] loop error:", err)
			end
		end
	end)
end

return Environment
