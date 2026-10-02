--[[
	Remotes (ModuleScript em ServerScriptService > Game)          Prefeito Tycoon
	Canais entre servidor e jogadores. Ficam em ReplicatedStorage > Remotes.
	  Request  jogador -> servidor: (ação, dados)        tudo que o jogador pede passa por aqui
	  Stats    servidor -> jogador: (tabela)             painel da cidade, a cada passo da simulação
	  Notify   servidor -> jogador: (texto, tipo)        avisos ("info", "ok", "erro", "evento")
	  Effect   servidor -> jogador: (tipo, dados)        sons e efeitos ("placed", "collect"...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function makeEvent(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

Remotes.Request = makeEvent("Request")
Remotes.Stats = makeEvent("Stats")
Remotes.NotifyEvent = makeEvent("Notify")
Remotes.EffectEvent = makeEvent("Effect")

folder.Parent = ReplicatedStorage

function Remotes.Notify(player: Player, text: string, kind: string?)
	Remotes.NotifyEvent:FireClient(player, text, kind or "info")
end

function Remotes.NotifyAll(text: string, kind: string?)
	Remotes.NotifyEvent:FireAllClients(text, kind or "info")
end

function Remotes.Effect(player: Player, kind: string, data: any?)
	Remotes.EffectEvent:FireClient(player, kind, data)
end

return Remotes
