--[[
	Weather: o CLIMA do servidor (versão 5). Um clima de cada vez, o mesmo para todo mundo; troca sozinho.
	Todo clima só ajuda: faz alguns negócios pagarem mais por ciclo (Config.Weather; regras em Sim.Weather*).

	  • começa "limpo"; depois de Config.Weather.First segundos entra no rodízio (sorteio pelos pesos, nunca
	    o mesmo duas vezes seguidas). O PRÓXIMO clima já fica sorteado: a tela mostra a previsão.
	  • a cada troca: atributos em workspace (Weather = id, WeatherUntil = hora do servidor em que acaba,
	    WeatherNext = id do próximo), Fx "weather" para todos (id, segundos) e estado novo para todos.
	    Quem entra no meio lê os atributos.
	  • Game.Ctx(player).Weather = Weather.Current: é por aí que o clima entra nas contas (Sim.Payout).

	O cliente só DESENHA (céu, chuva, selo nos prédios, chip no topo): quem paga a mais é o servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sim = require(ReplicatedStorage.Shared.Sim)
local Registry = require(script.Parent.Registry)

local Weather = {}

local START = "limpo" -- clima de quando o servidor liga (se não existir no Config, vale o 1º da lista)

Weather.Current = START :: string -- id do clima de agora
Weather.Next = START :: string -- id do próximo (previsão)
Weather.Until = 0 -- workspace:GetServerTimeNow() em que o clima de agora acaba
-- Rodízio ligado? Com false o clima de agora fica até alguém chamar Weather.Force (os testes automáticos
-- desligam para as contas de moedas não mudarem no meio; no Studio: VUODebug "weather", "stop" / "auto").
Weather.Auto = true

local function defOf(id: any): any?
	return type(id) == "string" and Config.WeatherById[id] or nil
end

-- Publica o clima de agora: atributos (para quem entra depois) + efeito + estado de todo mundo.
local function publish(seconds: number, announce: boolean)
	workspace:SetAttribute("Weather", Weather.Current)
	workspace:SetAttribute("WeatherUntil", Weather.Until)
	workspace:SetAttribute("WeatherNext", Weather.Next)
	if not announce then
		return
	end
	Registry.Remotes.Fx:FireAllClients("weather", nil, Weather.Current, seconds)
	for _, player in Players:GetPlayers() do
		Registry.Game.Push(player)
	end
	-- (o clima muda o PAGAMENTO, não o ritmo: os atributos Rate<i> dos terrenos continuam valendo)
end

-- Entra o clima "def" por "seconds" segundos e já sorteia o seguinte.
local function start(def: any, seconds: number, announce: boolean)
	Weather.Current = def.Id
	Weather.Until = workspace:GetServerTimeNow() + seconds
	Weather.Next = Sim.NextWeather(Config, def.Id, math.random).Id
	publish(seconds, announce)
end

-- Troca para o próximo da previsão (chamado pelo relógio quando o clima de agora acaba).
function Weather.Advance()
	local def = defOf(Weather.Next) or Sim.NextWeather(Config, Weather.Current, math.random)
	start(def, Sim.WeatherSeconds(def, math.random), true)
end

-- Põe um clima AGORA (ferramenta de teste: VUODebug "weather"). Dura o tempo normal dele e depois o
-- rodízio segue (se estiver ligado). false = id que não existe.
function Weather.Force(id: any): boolean
	local def = defOf(id)
	if not def then
		return false
	end
	start(def, Sim.WeatherSeconds(def, math.random), true)
	return true
end

-- O que vai no estado de cada jogador: { Id, Until, Next }
function Weather.Info(): any
	return { Id = Weather.Current, Until = Weather.Until, Next = Weather.Next }
end

function Weather.Init()
	if not Config.Weather or not Config.WeatherById then
		return
	end
	local first = defOf(START) or Config.Weather.List[1]
	start(first, Config.Weather.First, false)
	task.spawn(function()
		while true do
			task.wait(1)
			if Weather.Auto and workspace:GetServerTimeNow() >= Weather.Until then
				local ok, err = pcall(Weather.Advance)
				if not ok then
					warn("[Weather] troca de clima:", err)
					-- não fica tentando a cada segundo: espera um pouco com o clima que está
					Weather.Until = workspace:GetServerTimeNow() + 30
				end
			end
		end
	end)
end

return Weather
