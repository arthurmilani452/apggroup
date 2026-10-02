--[[
	Data (ModuleScript em ServerScriptService > Game)          Prefeito Tycoon
	Salva e carrega o progresso de cada jogador com segurança (mesmo sistema do Steal a Critter v28):
	  • UpdateAsync com "trava de sessão": dois servidores nunca mexem nos dados do mesmo jogador
	  • várias tentativas quando o Roblox falha
	  • salva ao sair, a cada Config.AutosaveEvery segundos e quando o servidor fecha
	  • quem sai e volta no MESMO servidor espera o save da saída terminar
	  • guarda os recibos de compra para nunca entregar (nem cobrar) duas vezes
	Data.BeforeSave(player, data) é preenchido pelo City para copiar a cidade antes de cada save.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local Data = {}
Data.BeforeSave = nil :: ((Player, any) -> ())?

type Profile = {
	Data: any,
	CanSave: boolean,
	IsNew: boolean,
	Saving: boolean,
	Final: boolean,
}

local SESSION_TIMEOUT = 150 -- segundos: trava mais velha que isso = servidor antigo caiu
local MAX_RECEIPTS = 100

local profiles: { [Player]: Profile } = {}
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
	return {
		Cash = Config.StartCash,
		Vault = 0, -- dinheiro esperando no cofre da Prefeitura
		VaultLevel = 1,
		Expansion = 1,
		Buildings = {}, -- { "id,x,z,r" } (Shared/Grid.Serialize)
		Population = 0,
		TierReached = 1, -- maior nível da cidade neste mandato (os prédios liberados não travam de novo)
		Reelections = 0,
		Stars = 0, -- recomendações recebidas
		Recommended = { Day = 0, Users = {} }, -- cidades que você recomendou hoje (UserIds)
		PeakPopulation = 0,
		TotalEarned = 0,
		NameA = 0, -- índices em Config.CityNameA / CityNameB (0 = sorteia na primeira vez)
		NameB = 0,
		Tutorial = 0,
		LastOnline = 0,
		Receipts = {},
		Version = 1,
	}
end

local function reconcile(data: any)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
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

-- v28: saves finais em andamento por UserId. Quem sai e volta no MESMO servidor precisa esperar
-- o save da saída terminar; senão carregava dados velhos e depois apagava o progresso da sessão anterior.
local finalSaving: { [number]: boolean } = {}

function Data.Load(player: Player): Profile
	local waitedFinal = 0
	while finalSaving[player.UserId] and waitedFinal < 40 and player.Parent do
		waitedFinal += task.wait(0.25)
	end
	local loaded = false
	local result: any = nil
	local isNew = false

	if store then
		local attempts = 6
		for attempt = 1, attempts do
			if not player.Parent then
				break -- saiu enquanto carregava
			end
			local locked = false
			local ok, err = pcall(function()
				(store :: DataStore):UpdateAsync(keyFor(player), function(old)
					-- Outro servidor ainda está com esse jogador: espera (na última tentativa assume)
					if lockedByOther(old) and attempt < attempts then
						locked = true
						return nil
					end
					locked = false
					isNew = type(old) ~= "table"
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
					break -- no Studio sem acesso à API não adianta insistir
				end
			end
			task.wait(if locked then 3 else 2)
		end
	end

	local profile: Profile = {
		Data = if loaded and result then result else defaultData(),
		CanSave = loaded,
		IsNew = if loaded then isNew else true,
		Saving = false,
		Final = false,
	}
	profiles[player] = profile

	if not loaded then
		warn("[Data] O progresso de " .. player.Name .. " NÃO será salvo nesta sessão.")
		if RunService:IsStudio() then
			task.delay(4, function()
				if player.Parent then
					Remotes.Notify(player, "Studio: o salvamento está DESLIGADO. Publique e ligue 'Studio Access to API Services' para testar.", "erro")
				end
			end)
		end
	end
	return profile
end

function Data.Get(player: Player): Profile?
	return profiles[player]
end

-- Quantos saves estão em andamento (o servidor espera eles terminarem antes de fechar)
function Data.ActiveSaves(): number
	return activeSaves
end

-- isFinal = true quando o jogador está saindo (libera a trava e não salva mais nada dele)
function Data.Save(player: Player, isFinal: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return false
	end
	activeSaves += 1
	if isFinal then
		finalSaving[player.UserId] = true -- marcado já antes de esperar um autosave em andamento
	end
	local waited = 0
	local limit = if isFinal then 30 else 15
	while profile.Saving and waited < limit do
		waited += task.wait(0.1)
	end
	-- nunca dois saves do mesmo jogador ao mesmo tempo: se o outro ainda não acabou, este desiste
	-- (o save da saída espera mais e segue; o número SaveSeq impede o save velho de apagar o novo)
	if profile.Final or not profile.CanSave or (profile.Saving and not isFinal) then
		if isFinal and not profile.Saving then -- se outro save final ainda roda, ele mesmo limpa no fim
			finalSaving[player.UserId] = nil
		end
		activeSaves -= 1
		return false
	end
	profile.Saving = true
	if isFinal then
		profile.Final = true
	end

	-- a cidade (prédios, população, cofre) vive no módulo City enquanto o jogador joga
	if Data.BeforeSave then
		Data.BeforeSave(player, profile.Data)
	end
	-- só marca "online agora" depois de carregar (senão o cofre offline se perde)
	if player:GetAttribute("Loaded") then
		profile.Data.LastOnline = os.time()
	end
	-- "foto" dos dados agora; mudanças durante a espera entram no próximo save
	profile.Data.SaveSeq = (tonumber(profile.Data.SaveSeq) or 0) + 1
	local snapshot = deepCopy(profile.Data)

	local success = false
	local lostLock = false
	for attempt = 1, if isFinal then 5 else 3 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function(old)
				if lockedByOther(old) then
					lostLock = true
					return nil
				end
				lostLock = false
				if type(old) == "table" and (tonumber(old.SaveSeq) or 0) > snapshot.SaveSeq then
					return nil -- já tem um save mais novo guardado: não volta no tempo
				end
				snapshot.Session = if isFinal then nil else { JobId = game.JobId, Time = os.time() }
				return snapshot, { player.UserId }
			end)
		end)
		if ok then
			success = not lostLock
			break
		end
		warn(("[Data] Falha ao salvar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(1)
	end

	if lostLock then
		-- Outro servidor assumiu os dados: este servidor para de salvar para não estragar nada
		warn("[Data] " .. player.Name .. " foi carregado em outro servidor; este servidor não salva mais.")
		profile.CanSave = false
		if player.Parent and not isFinal then
			player:Kick("Seu progresso foi aberto em outro servidor. Entre de novo!")
		end
	end

	profile.Saving = false
	if isFinal then
		finalSaving[player.UserId] = nil
	end
	activeSaves -= 1
	return success
end

function Data.HasReceipt(profile: Profile, purchaseId: string): boolean
	return table.find(profile.Data.Receipts, purchaseId) ~= nil
end

function Data.AddReceipt(profile: Profile, purchaseId: string)
	local receipts = profile.Data.Receipts
	table.insert(receipts, purchaseId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
end

function Data.Remove(player: Player)
	profiles[player] = nil
end

return Data
