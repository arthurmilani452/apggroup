--[[
	Data: salva e carrega o progresso (base segura):
	  • UpdateAsync com trava de sessão (dois servidores nunca mexem nos dados do mesmo jogador)
	  • várias tentativas quando o Roblox falha
	  • salva ao sair, a cada 60 s e quando o servidor fecha
	  • se o carregamento falhar, NÃO salva por cima (o progresso antigo fica seguro)
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sim = require(ReplicatedStorage.Shared.Sim)

local Data = {}

export type Profile = {
	Data: any,
	CanSave: boolean,
	Saving: boolean,
	Final: boolean,
}

local SESSION_TIMEOUT = 150

local profiles: { [Player]: Profile } = {}
local finalSaving: { [number]: boolean } = {}
local activeSaves = 0

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore indisponível:", result)
	end
end

local function defaultData()
	return Sim.NewData(Config)
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Tabelas que ganham chaves novas quando o jogo cresce (estatística nova...)
local NESTED = { Stats = true, Streak = true, Daily = true }

-- Completa o que faltar (versões antigas do save), sem mexer em listas que já existem
local function reconcile(data: any)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		elseif NESTED[key] and type(data[key]) == "table" then
			for subKey, subValue in value do
				if data[key][subKey] == nil then
					data[key][subKey] = subValue
				end
			end
		elseif type(value) == "table" and type(data[key]) ~= "table" then
			data[key] = value
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function lockedByOther(value: any): boolean
	if type(value) ~= "table" or type(value.Session) ~= "table" then
		return false
	end
	local session = value.Session
	return session.JobId ~= game.JobId and os.time() - (tonumber(session.Time) or 0) < SESSION_TIMEOUT
end

function Data.Load(player: Player): Profile
	-- quem saiu e voltou no MESMO servidor espera o save da saída terminar
	local waited = 0
	while finalSaving[player.UserId] and waited < 40 and player.Parent do
		waited += task.wait(0.25)
	end
	local loaded, result = false, nil
	if store then
		local attempts = 6
		for attempt = 1, attempts do
			if not player.Parent then
				break
			end
			local locked = false
			local ok, err = pcall(function()
				(store :: DataStore):UpdateAsync(keyFor(player), function(old)
					if lockedByOther(old) and attempt < attempts then
						locked = true
						return nil
					end
					locked = false
					local data = reconcile(if type(old) == "table" then old else defaultData())
					data.Session = { JobId = game.JobId, Time = os.time() }
					result = data
					return data, { player.UserId }
				end)
			end)
			if ok and not locked then
				loaded = true
				break
			end
			if not ok then
				warn(("[Data] Falha ao carregar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(err)))
				if RunService:IsStudio() then
					break
				end
			end
			task.wait(if locked then 3 else 2)
		end
	end
	local profile: Profile = {
		Data = if loaded and result then result else defaultData(),
		CanSave = loaded,
		Saving = false,
		Final = false,
	}
	profiles[player] = profile
	if not loaded then
		warn("[Data] O progresso de " .. player.Name .. " NÃO será salvo nesta sessão.")
	end
	return profile
end

function Data.Get(player: Player): Profile?
	return profiles[player]
end

function Data.ActiveSaves(): number
	return activeSaves
end

function Data.Save(player: Player, isFinal: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return false
	end
	activeSaves += 1
	if isFinal then
		finalSaving[player.UserId] = true
	end
	local waited = 0
	local limit = if isFinal then 30 else 15
	while profile.Saving and waited < limit do
		waited += task.wait(0.1)
	end
	if profile.Final or not profile.CanSave or (profile.Saving and not isFinal) then
		if isFinal and not profile.Saving then
			finalSaving[player.UserId] = nil
		end
		activeSaves -= 1
		return false
	end
	profile.Saving = true
	if isFinal then
		profile.Final = true
	end
	profile.Data.SaveSeq = (tonumber(profile.Data.SaveSeq) or 0) + 1
	profile.Data.LastSeen = os.time() -- a renda offline conta a partir daqui
	local snapshot = deepCopy(profile.Data)

	local success, lostLock, stale = false, false, false
	for attempt = 1, if isFinal then 5 else 3 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function(old)
				if lockedByOther(old) then
					lostLock = true
					return nil
				end
				lostLock = false
				if type(old) == "table" and (tonumber(old.SaveSeq) or 0) > snapshot.SaveSeq then
					stale = true -- já existe um save mais novo: nada foi escrito (não conta como "salvou")
					return nil
				end
				stale = false
				snapshot.Session = if isFinal then nil else { JobId = game.JobId, Time = os.time() }
				return snapshot, { player.UserId }
			end)
		end)
		if ok then
			success = not lostLock and not stale
			break
		end
		warn(("[Data] Falha ao salvar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(1)
	end
	if lostLock then
		profile.CanSave = false
		if player.Parent and not isFinal then
			player:Kick("Seu progresso abriu em outro servidor. Entra de novo.")
		end
	end
	profile.Saving = false
	if isFinal then
		finalSaving[player.UserId] = nil
	end
	activeSaves -= 1
	return success
end

function Data.Remove(player: Player)
	profiles[player] = nil
end

return Data
