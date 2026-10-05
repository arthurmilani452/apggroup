-- Remotes: canais entre servidor e jogadores (todos criados aqui).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string, unreliable: boolean?): any
	local e = Instance.new(if unreliable then "UnreliableRemoteEvent" else "RemoteEvent")
	e.Name = name
	e.Parent = folder
	return e
end

Remotes.Request = event("Request") -- jogador -> servidor: (ação: string, a, b)
Remotes.State = event("State") -- servidor -> jogador: tabela com o estado dele (dinheiro, cesta, preços...)
Remotes.Notify = event("Notify") -- servidor -> jogador(es): (chave do texto, args, tipo)
Remotes.Fx = event("Fx", true) -- servidor -> todos: efeitos visuais ("money", posição, valor) (pode perder um)

folder.Parent = ReplicatedStorage

function Remotes.NotifyPlayer(player: Player, key: string, args: { [string]: any }?, kind: string?)
	Remotes.Notify:FireClient(player, key, args or {}, kind or "info")
end

function Remotes.NotifyAll(key: string, args: { [string]: any }?, kind: string?)
	Remotes.Notify:FireAllClients(key, args or {}, kind or "info")
end

-- Pedidos do jogador: cada ação tem o próprio limite de tempo (lição do Steal a Critter v28)
local handlers: { [string]: (Player, any, any) -> () } = {}
local lastRequest: { [Player]: { [string]: number } } = {}

function Remotes.On(action: string, handler: (Player, any, any) -> ())
	handlers[action] = handler
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
	if now - (times[action] or 0) < Config.RequestCooldown then
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
