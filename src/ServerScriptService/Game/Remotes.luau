-- Canais de comunicação entre servidor e jogadores.
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

Remotes.NotifyEvent = makeEvent("Notify") -- servidor -> jogador: (texto, tipo)
Remotes.PopupEvent = makeEvent("Popup") -- servidor -> jogador: (título, texto)
Remotes.KnockbackEvent = makeEvent("Knockback") -- servidor -> jogador: (velocidade)
Remotes.EffectEvent = makeEvent("Effect") -- servidor -> jogador(es): (tipo, dados)
Remotes.IndexEvent = makeEvent("IndexSync") -- servidor -> jogador: (tabela do índice)
Remotes.RequestEvent = makeEvent("Request") -- jogador -> servidor: (ação, argumento)
Remotes.InventoryEvent = makeEvent("InventorySync") -- servidor -> jogador: mochila, pets e bichinhos da base
Remotes.StyleEvent = makeEvent("StyleSync") -- servidor -> jogador: temas, decoração, trilhas e títulos
Remotes.SeasonEvent = makeEvent("SeasonSync") -- servidor -> jogador: passe da temporada e placar
Remotes.ProgressEvent = makeEvent("ProgressSync") -- servidor -> jogador: nível, habilidades, missões, conquistas (v10)
Remotes.SocialEvent = makeEvent("SocialSync") -- servidor -> jogador: likes, presentes e clã (v11)
Remotes.BattleEvent = makeEvent("BattleSync") -- servidor -> jogador: a luta do Critter Battle (v12)

folder.Parent = ReplicatedStorage

function Remotes.Notify(player: Player, text: string, kind: string?)
	Remotes.NotifyEvent:FireClient(player, text, kind or "info")
end

function Remotes.NotifyAll(text: string, kind: string?)
	Remotes.NotifyEvent:FireAllClients(text, kind or "info")
end

function Remotes.Popup(player: Player, title: string, body: string)
	Remotes.PopupEvent:FireClient(player, title, body)
end

function Remotes.Effect(player: Player, kind: string, data: any?)
	Remotes.EffectEvent:FireClient(player, kind, data)
end

function Remotes.EffectAll(kind: string, data: any?)
	Remotes.EffectEvent:FireAllClients(kind, data)
end

return Remotes
