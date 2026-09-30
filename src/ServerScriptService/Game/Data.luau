--[[
	Data (ModuleScript em ServerScriptService > Game)
	Salva e carrega o progresso de cada jogador com segurança:
	  • UpdateAsync com "trava de sessão": dois servidores nunca mexem nos dados do mesmo jogador
	  • várias tentativas quando o Roblox falha
	  • salva ao sair, a cada 60 s (Main) e quando o servidor fecha
	  • guarda os recibos de compra para nunca entregar (nem cobrar) duas vezes
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Data = {}

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
		Rebirths = 0,
		SpeedLevel = 0,
		Critters = {}, -- { {Id, Slot, Mutation}, ... }
		Eggs = {}, -- ovos chocando { {Id, Slot, Left, Result = {Id, Mutation}}, ... }
		Pending = {}, -- esperando vaga: { {Id, Mutation} } ou { {Egg, Result} }
		Index = {},
		Collected = 0, -- quantos bichinhos diferentes já descobriu (leaderboard)
		Hatched = 0,
		Defends = 0, -- ladrões que você derrubou com o taco
		SlotUpgrades = 0, -- vagas compradas com dinheiro do jogo
		TrainedSpeed = 0, -- velocidade ganha na esteira de treino
		Codes = {}, -- códigos já usados
		Worlds = {}, -- mundos destravados { candy = true, ... } (o Meadow é sempre livre)
		PlayTime = 0, -- segundos jogados no total (escudo de novato)
		Inventory = {}, -- mochila: { {K = "k1", Id, M = mutação}, ... } (v7)
		Equipped = {}, -- chaves dos pets equipados (v7)
		NextKey = 0, -- contador das chaves da mochila (cada bichinho guardado tem uma chave única)
		Style = {}, -- personalização da base e do avatar (v7): Theme, Decor, Trail, Title, Owned
		BoostUntil = 0, -- 2x Cash dos códigos acaba nesse os.time()
		PaidShieldUntil = 0, -- v20: escudo comprado (Base Shield) acaba nesse os.time()
		StarterPack = false, -- v20: já comprou o Starter Pack (só 1 vez)
		Season = {}, -- temporada atual: Id, XP, níveis entregues (v8)
		SeasonPasses = {}, -- temporadas em que comprou o passe: { ["1"] = true } (v8)
		Settings = {}, -- configurações da tela (gráfico leve, sons...) (v8)
		Recipes = {}, -- receitas de híbridos descobertas (v9)
		Progress = {}, -- nível da conta, habilidades e classe (v10)
		Missions = {}, -- missões do dia (v10)
		Records = {}, -- recordes pessoais (v10)
		Achievements = {}, -- conquistas: { Id = os.time() } (v10)
		BadgesSent = {}, -- Badges do Roblox já entregues (v10)
		Prestige = 0, -- prestígios feitos (v10)
		PeakRebirths = 0, -- maior número de rebirths (o prestígio não tira as vagas) (v10)
		Likes = 0, -- curtidas que a sua base recebeu (v11)
		LikedToday = {}, -- bases que você curtiu hoje (v11)
		GiftsToday = {}, -- presentes dados hoje (v11)
		Clan = "", -- Id do seu clã (v11)
		InviteRewards = {}, -- prêmios de convite de hoje (v11)
		MerchantBuys = {}, -- compras no mercador nesta hora (v11)
		GlobalClaimed = {}, -- metas da comunidade já recebidas (v11)
		CreatorGift = false, -- já ganhou o Crowny (v11)
		Hunt = {}, -- caça aos ovos do dia (v13)
		Fishing = {}, -- pesca do dia (v13)
		Chests = {}, -- baús abertos hoje (v13)
		Digging = {}, -- fósseis achados hoje (v13)
		DailyDay = 0,
		Streak = 0,
		SpinDay = 0, -- v23: dia (os.time()/86400) do último giro grátis da roleta
		FunPrizes = {}, -- v27: baú de cada brincadeira dos mundos -> quando volta (os.time)
		LastOnline = 0,
		TotalEarned = 0,
		Steals = 0,
		TutorialDone = false,
		Receipts = {},
		Version = 5,
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

function Data.Load(player: Player): Profile
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
					if type(old) == "table" and old.PlayTime == nil and (tonumber(old.TotalEarned) or 0) > 0 then
						old.PlayTime = 3600 -- quem já jogava antes da v6 não é mais novato
					end
					if type(old) == "table" and old.TutorialDone == nil then
						-- save antigo (antes do tutorial existir): quem já jogou não refaz o tutorial
						old.TutorialDone = (tonumber(old.TotalEarned) or 0) > 0 or (tonumber(old.Rebirths) or 0) > 0
					end
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
				local Remotes = Registry.Remotes
				if Remotes and player.Parent then
					Remotes.Notify(player, "Studio: saving is OFF. Publish and enable 'Studio Access to API Services' to test saving.", "warning")
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
	local waited = 0
	local limit = if isFinal then 30 else 15
	while profile.Saving and waited < limit do
		waited += task.wait(0.1)
	end
	-- nunca dois saves do mesmo jogador ao mesmo tempo: se o outro ainda não acabou, este desiste
	-- (o save da saída espera mais e segue; o número SaveSeq impede o save velho de apagar o novo)
	if profile.Final or not profile.CanSave or (profile.Saving and not isFinal) then
		activeSaves -= 1
		return false
	end
	profile.Saving = true
	if isFinal then
		profile.Final = true
	end

	-- Só atualiza a lista de bichinhos e ovos depois que eles já foram colocados na base
	local critterService = Registry.CritterService
	if critterService and player:GetAttribute("Loaded") then
		local list = critterService.GetSaveList(player)
		if list then
			profile.Data.Critters = list
		end
		local eggs = critterService.GetEggSaveList(player)
		if eggs then
			profile.Data.Eggs = eggs
		end
	end
	-- só marca "online agora" depois de carregar (senão o dinheiro offline e os ovos se perdem)
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
			player:Kick("Your progress was loaded in another server. Please rejoin!")
		end
	end

	profile.Saving = false
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
