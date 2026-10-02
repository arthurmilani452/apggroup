-- Remotes: canais entre servidor e jogadores (todos criados aqui).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string, unreliable: boolean?): any
	local e = Instance.new(if unreliable then "UnreliableRemoteEvent" else "RemoteEvent")
	e.Name = name
	e.Parent = folder
	return e
end

Remotes.Fire = event("Fire") -- jogador -> servidor: (aimPoint: Vector3, aiming: boolean)
Remotes.Reload = event("Reload") -- jogador -> servidor: ()
Remotes.Spectate = event("Spectate") -- jogador -> servidor: () pede o próximo para assistir
Remotes.Effect = event("Effect", true) -- servidor -> jogadores: efeitos visuais (tracer, acerto...)
Remotes.Notify = event("Notify") -- servidor -> jogador(es): (chave do texto, args, tipo)
Remotes.Killfeed = event("Killfeed") -- servidor -> todos: (chave, args)
Remotes.Result = event("Result") -- servidor -> jogador: fim de partida { Place, Total, Kills, XP, Won, Winner }
Remotes.SpectateTarget = event("SpectateTarget") -- servidor -> jogador: (Model?, nome)

folder.Parent = ReplicatedStorage

function Remotes.NotifyPlayer(player: Player, key: string, args: { [string]: any }?, kind: string?)
	Remotes.Notify:FireClient(player, key, args or {}, kind or "info")
end

function Remotes.NotifyAll(key: string, args: { [string]: any }?, kind: string?)
	Remotes.Notify:FireAllClients(key, args or {}, kind or "info")
end

return Remotes
