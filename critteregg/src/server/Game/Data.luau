--!nonstrict
--[[
	Data: salva e carrega o progresso (DataStore), com trava de sessão simples, autosave e BindToClose.
	No Studio sem "Enable Studio Access to API Services" o jogo funciona sem salvar (avisa no Output).
	Formato:
	  Money, Speed, PenLevel, TreadLevel, Stolen
	  Slots = { [1..n] = { Kind = "Egg"|"Pet", Id = critterId, Scale = s, Mut = mutation?, Left = segundos para chocar } }
	  Index = { [critterId] = true }
	  SavedAt = os.time()

	v65:
	  • Sair e voltar RÁPIDO para o MESMO servidor: o Load espera o save da saída terminar
	    (antes carregava o save velho e o próximo autosave apagava o que a criança tinha feito).
	  • Save devolve true/false (a compra com Robux só é confirmada depois de salvar de verdade).
	  • Depois do save final, o autosave não salva mais esse jogador (não trava os dados de novo).
	  • Ao fechar o servidor, espera os saves terminarem de verdade (até 25 s), não um tempo fixo.
	  • Trava de outro servidor: espera até ~20 s; só "toma" a trava se ela estiver velha (servidor caído).
	    Antes tomava depois de ~9 s mesmo com o outro servidor ainda salvando (e o save dele se perdia).
	  • Data.Forget: quem sai enquanto ainda está carregando solta a trava sem gravar nada por cima.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Data = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local profiles: { [Player]: any } = {}
local released: { [any]: boolean } = {} -- perfis que já fizeram o save final (o autosave pula)
local finalSaving: { [number]: number } = {} -- UserId -> quantos saves finais ainda estão rodando
local loading: { [number]: number } = {} -- UserId -> loads em andamento (o BindToClose espera também)
local LOCK_SECONDS = 1800
local LOAD_TRIES = 6
local STALE_LOCK = Config.SaveEvery + 15 -- servidor vivo renova a trava a cada autosave
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
	-- saiu e voltou rápido para ESTE servidor: espera o save da saída terminar antes de ler
	local waited = 0
	while (finalSaving[player.UserId] or 0) > 0 and waited < 40 and player.Parent do
		waited += task.wait(0.25)
	end
	local data = nil
	local noSave = false
	loading[player.UserId] = (loading[player.UserId] or 0) + 1
	if store then
		local loaded = false
		for attempt = 1, LOAD_TRIES do
			local locked = false
			local ok, err = pcall(function()
				store:UpdateAsync(keyOf(player), function(old)
					old = old or {}
					local lock = old.Lock
					local age = os.time() - ((lock and lock.Time) or 0)
					-- só uma trava FRESCA segura (servidor vivo renova a cada autosave); trava velha = servidor
					-- caído: pega na hora (v65.1; antes ainda esperava ~20 s)
					if lock and lock.Session ~= SESSION and age < STALE_LOCK then
						locked = true
						return nil -- outra sessão ainda está com os dados (o servidor antigo ainda salvando): tenta de novo
					end
					locked = false
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
			if not player.Parent then
				break
			end
			task.wait(4)
		end
		noSave = not loaded -- não conseguiu ler: NÃO salva por cima (senão apagaria o progresso de verdade)
	elseif RunService:IsStudio() then
		warn("[Data] DataStore indisponível: jogando SEM salvar (ligue Game Settings > Security > API Services)")
	end
	loading[player.UserId] = (loading[player.UserId] or 1) - 1
	if loading[player.UserId] <= 0 then
		loading[player.UserId] = nil
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
	released[data] = nil
	if noSave then
		data.__NoSave = true
	end
	return data
end

function Data.Get(player: Player)
	return profiles[player]
end

-- pode salvar este jogador? (false = os dados não carregaram; o Game usa para não vender nada a quem não salva)
function Data.CanSave(player: Player): boolean
	local data = profiles[player]
	return data ~= nil and store ~= nil and not data.__NoSave
end

-- devolve true se o save chegou no DataStore (e, como 2º valor, true se outro servidor tem a trava)
function Data.Save(player: Player, release: boolean?): (boolean, boolean?)
	local data = profiles[player]
	if not data or not store or data.__NoSave then
		return false
	end
	if released[data] and not release then
		return false -- já fez o save final (o jogador saiu): o autosave não trava os dados de novo
	end
	data.SavedAt = os.time()
	local written = false
	local lockLost = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyOf(player), function(old)
			old = old or {}
			if old.Lock and old.Lock.Session ~= SESSION and os.time() - (old.Lock.Time or 0) < LOCK_SECONDS then
				written = false
				lockLost = true
				return nil -- outra sessão pegou os dados: não sobrescreve
			end
			if released[data] and not release then
				written = false
				return nil
			end
			old.Data = data
			old.Lock = if release then nil else { Session = SESSION, Time = os.time() }
			written = true
			return old
		end)
	end)
	if not ok then
		warn("[Data] save failed:", err)
		return false
	end
	return written, lockLost
end

function Data.Release(player: Player)
	local data = profiles[player]
	local userId = player.UserId
	finalSaving[userId] = (finalSaving[userId] or 0) + 1
	if data and released[data] then
		-- (v65.1) já tem um save final deste perfil rodando (saída + fechamento do servidor): só espera ele
		local waited = 0
		while profiles[player] == data and waited < 30 do
			waited += task.wait(0.2)
		end
		finalSaving[userId] = (finalSaving[userId] or 1) - 1
		if finalSaving[userId] <= 0 then
			finalSaving[userId] = nil
		end
		return
	end
	if data then
		released[data] = true
	end
	-- (v65.1) até 3 tentativas: se o save final falhar, a trava ficaria presa e a criança seria
	-- mandada embora na próxima entrada
	for attempt = 1, 3 do
		local ok, saved, lockLost = pcall(Data.Save, player, true)
		if not ok then
			warn("[Data] final save error:", saved)
		end
		if (ok and (saved or lockLost)) or not data or data.__NoSave or not store then
			break
		end
		task.wait(2 ^ attempt)
	end
	if profiles[player] == data then
		profiles[player] = nil
	end
	if data then
		released[data] = nil
	end
	finalSaving[userId] = (finalSaving[userId] or 1) - 1
	if finalSaving[userId] <= 0 then
		finalSaving[userId] = nil
	end
end

-- o jogador saiu antes de terminar de carregar (ou foi mandado embora): solta a trava SEM gravar os
-- dados (nada mudou) e esquece o perfil (antes ele ficava na memória e o autosave gravava por cima)
function Data.Forget(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	profiles[player] = nil
	if not store or data.__NoSave then
		return
	end
	local userId = player.UserId
	finalSaving[userId] = (finalSaving[userId] or 0) + 1
	for attempt = 1, 3 do
		local ok = pcall(function()
			store:UpdateAsync(keyOf(player), function(old)
				if type(old) ~= "table" or not old.Lock or old.Lock.Session ~= SESSION then
					return nil
				end
				old.Lock = nil
				return old
			end)
		end)
		if ok then
			break
		end
		task.wait(2 ^ attempt)
	end
	finalSaving[userId] = (finalSaving[userId] or 1) - 1
	if finalSaving[userId] <= 0 then
		finalSaving[userId] = nil
	end
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
		-- espera os saves terminarem de verdade (no máximo 25 s; o Roblox dá 30)
		local started = os.clock()
		while (next(finalSaving) ~= nil or next(loading) ~= nil) and os.clock() - started < 25 do
			task.wait(0.2)
		end
		if RunService:IsStudio() then
			task.wait(0.5)
		end
	end)
end

return Data
