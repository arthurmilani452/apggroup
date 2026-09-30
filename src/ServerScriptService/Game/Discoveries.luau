--[[
	Discoveries (ModuleScript em ServerScriptService > Game)
	Parte 21: "DESCOBERTO POR" — o primeiro jogador do MUNDO INTEIRO a chocar cada bichinho Secret
	fica com o nome no Índice para sempre.
	  • Tudo numa chave só do DataStore "Discoveries_v1" (poucos Secrets = leitura barata)
	  • UpdateAsync: se dois servidores tentarem ao mesmo tempo, só o primeiro ganha (o outro vê que já tem dono)
	  • As telas leem o atributo "Discoveries" do ReplicatedStorage (texto JSON), atualizado a cada 5 min
	No Studio sem "API Services" ligado o DataStore falha: aí vale só para o servidor atual (sem erro).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Critters = require(ReplicatedStorage.Shared.Critters)
local Registry = require(script.Parent.Registry)

local Discoveries = {}

local KEY = "SecretFirsts"
type Entry = { N: string, U: number, T: number }
local cache: { [string]: Entry } = {}
local claiming: { [string]: boolean } = {}
local store: DataStore? = nil

local function publish()
	local ok, json = pcall(function()
		return HttpService:JSONEncode(cache)
	end)
	if ok then
		ReplicatedStorage:SetAttribute("Discoveries", json)
	end
end

local function merge(saved: any)
	if type(saved) ~= "table" then
		return
	end
	for id, entry in saved do
		if type(id) == "string" and Critters.ById[id] and type(entry) == "table" and type(entry.N) == "string" then
			cache[id] = { N = string.sub(entry.N, 1, 40), U = tonumber(entry.U) or 0, T = tonumber(entry.T) or 0 }
		end
	end
end

local function refresh()
	if not store then
		return
	end
	local ok, saved = pcall(function()
		return (store :: DataStore):GetAsync(KEY)
	end)
	if ok then
		merge(saved)
		publish()
	end
end

-- Quem descobriu primeiro (ou nil)
function Discoveries.Get(critterId: string): Entry?
	return cache[critterId]
end

-- Chamado quando alguém choca um Secret
function Discoveries.Claim(player: Player, critterId: string)
	if cache[critterId] or claiming[critterId] then
		return
	end
	local def = Critters.ById[critterId]
	if not def then
		return
	end
	claiming[critterId] = true
	local mine: Entry = { N = player.DisplayName, U = player.UserId, T = os.time() }
	local won = false
	if store then
		local ok = pcall(function()
			(store :: DataStore):UpdateAsync(KEY, function(saved)
				saved = if type(saved) == "table" then saved else {}
				if saved[critterId] then
					merge(saved) -- outro servidor chegou antes
					won = false
					return nil -- não muda nada
				end
				saved[critterId] = mine
				won = true
				return saved
			end)
		end)
		if not ok then
			won = false
		end
	else
		won = true
	end
	if won then
		cache[critterId] = mine
	end
	claiming[critterId] = nil
	publish()
	if won and player.Parent then
		Registry.Remotes.NotifyAll(("WORLD FIRST! %s is the first player EVER to discover %s!"):format(player.DisplayName, def.Name), "rare")
		Registry.Remotes.Effect(player, "WorldFirst", def.Name)
	end
end

function Discoveries.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Discoveries_v1")
	end)
	store = if ok then result else nil
	publish()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				refresh()
			end)
			if not ok then
				warn("[Discoveries] loop error:", err)
			end
			task.wait(5 * 60)
		end
	end)
end

return Discoveries
