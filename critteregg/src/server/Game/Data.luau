--!nonstrict
--[[
	Data: salva e carrega o progresso (DataStore), com trava de sessão simples, autosave e BindToClose.
	No Studio sem "Enable Studio Access to API Services" o jogo funciona sem salvar (avisa no Output).
	Formato:
	  Money, Speed, PenLevel, TreadLevel, Stolen
	  Slots = { [1..n] = { Kind = "Egg"|"Pet", Id = critterId, Scale = s, Mut = mutation?, Left = segundos para chocar } }
	  Index = { [critterId] = true }
	  SavedAt = os.time()
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Data = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local profiles: { [Player]: any } = {}
local LOCK_SECONDS = 1800
local SESSION = game.JobId ~= "" and game.JobId or ("studio-" .. tostring(math.random(1, 1e9)))

local function defaults()
	return {
		Money = Config.StartMoney,
		Speed = Config.StartSpeed,
		PenLevel = 0,
		TreadLevel = 1,
		Stolen = 0,
		Slots = {},
		Index = {},
		SavedAt = os.time(),
	}
end

local function fill(data)
	local base = defaults()
	for key, value in base do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

local function keyOf(player: Player): string
	return "p_" .. player.UserId
end

function Data.Load(player: Player)
	local data = nil
	local noSave = false
	if store then
		local loaded = false
		for attempt = 1, 4 do
			local locked = false
			local ok, err = pcall(function()
				store:UpdateAsync(keyOf(player), function(old)
					old = old or {}
					local lock = old.Lock
					if lock and lock.Session ~= SESSION and os.time() - (lock.Time or 0) < LOCK_SECONDS and attempt < 4 then
						locked = true
						return nil -- outra sessão ainda está com os dados (o servidor antigo ainda salvando): tenta de novo
					end
					old.Lock = { Session = SESSION, Time = os.time() }
					data = old.Data
					return old
				end)
			end)
			if ok and not locked then
				loaded = true
				break
			end
			warn("[Data] load attempt", attempt, if locked then "locked by another server" else err)
			if not ok and string.find(string.lower(tostring(err)), "studio", 1, true) then
				break -- Studio sem acesso às APIs: não adianta tentar de novo
			end
			task.wait(3)
		end
		noSave = not loaded -- não conseguiu ler: NÃO salva por cima (senão apagaria o progresso de verdade)
	elseif RunService:IsStudio() then
		warn("[Data] DataStore indisponível: jogando SEM salvar (ligue Game Settings > Security > API Services)")
	end
	data = fill(data or defaults())
	-- os ovos continuam crescendo enquanto o jogador estava fora (velocidade normal)
	local away = math.max(0, os.time() - (data.SavedAt or os.time()))
	for _, slot in data.Slots do
		if slot.Kind == "Egg" then
			slot.Left = math.max(0, (slot.Left or 0) - away)
		end
	end
	data.__Away = away -- o Game usa para o ganho offline e apaga
	profiles[player] = data
	if noSave then
		data.__NoSave = true
	end
	return data
end

function Data.Get(player: Player)
	return profiles[player]
end

function Data.Save(player: Player, release: boolean?)
	local data = profiles[player]
	if not data or not store or data.__NoSave then
		return
	end
	data.SavedAt = os.time()
	local ok, err = pcall(function()
		store:UpdateAsync(keyOf(player), function(old)
			old = old or {}
			if old.Lock and old.Lock.Session ~= SESSION and os.time() - (old.Lock.Time or 0) < LOCK_SECONDS then
				return nil -- outra sessão pegou os dados: não sobrescreve
			end
			old.Data = data
			old.Lock = if release then nil else { Session = SESSION, Time = os.time() }
			return old
		end)
	end)
	if not ok then
		warn("[Data] save failed:", err)
	end
end

function Data.Release(player: Player)
	Data.Save(player, true)
	profiles[player] = nil
end

function Data.Init()
	task.spawn(function()
		while true do
			task.wait(Config.SaveEvery)
			for player in profiles do
				task.spawn(Data.Save, player)
			end
		end
	end)
	game:BindToClose(function()
		for player in profiles do
			task.spawn(Data.Release, player)
		end
		task.wait(if RunService:IsStudio() then 1 else 5)
	end)
end

return Data
