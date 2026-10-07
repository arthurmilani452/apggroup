-- Remotes: canais entre servidor e jogadores (todos criados aqui).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string): RemoteEvent
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = folder
	return e
end

Remotes.Request = event("Request") -- jogador -> servidor: (ação: string, a, b)
Remotes.State = event("State") -- servidor -> jogador: estado completo (quando algo importante muda)
Remotes.Tick = event("Tick") -- servidor -> jogador: só os números que mudam o tempo todo
Remotes.Notify = event("Notify") -- servidor -> jogador(es): (chave do texto, args, tipo)
Remotes.Fx = event("Fx") -- servidor -> jogador(es): efeitos (tipo, posição, valor, extra)

folder.Parent = ReplicatedStorage

function Remotes.NotifyPlayer(player: Player, key: string, args: { [string]: any }?, kind: string?)
	Remotes.Notify:FireClient(player, key, args or {}, kind or "info")
end

function Remotes.NotifyAll(key: string, args: { [string]: any }?, kind: string?)
	Remotes.Notify:FireAllClients(key, args or {}, kind or "info")
end

-- Pedidos do jogador: cada ação tem o próprio limite de tempo.
-- O normal é Config.RequestCooldown (0,25 s). Uma ação pode pedir outro intervalo em Remotes.On:
-- o "Click" da banca passa 0 (sem espera aqui) porque o Farm já conta os cliques por segundo.
local handlers: { [string]: (Player, any, any) -> () } = {}
local intervals: { [string]: number } = {}
local lastRequest: { [Player]: { [string]: number } } = {}

function Remotes.On(action: string, handler: (Player, any, any) -> (), interval: number?)
	handlers[action] = handler
	intervals[action] = if type(interval) == "number" then math.max(0, interval) else nil
end

Remotes.Request.OnServerEvent:Connect(function(player: Player, action: any, a: any, b: any)
	if type(action) ~= "string" then
		return
	end
	local handler = handlers[action]
	if not handler then
		return
	end
	local times = lastRequest[player]
	if not times then
		times = {}
		lastRequest[player] = times
	end
	local now = os.clock()
	local last = times[action]
	if last and now - last < (intervals[action] or Config.RequestCooldown) then
		return
	end
	times[action] = now
	local ok, err = pcall(handler, player, a, b)
	if not ok then
		warn("[Remotes] " .. action .. " falhou:", err)
	end
end)

function Remotes.RemovePlayer(player: Player)
	lastRequest[player] = nil
end

return Remotes
