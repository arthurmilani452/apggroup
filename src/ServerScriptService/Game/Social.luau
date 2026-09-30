--[[
	Social (ModuleScript em ServerScriptService > Game)
	Parte 24 (v11): jogar junto.
	  • LIKE: 1 curtida por base por dia (placa MOST LIKED no mapa)
	  • VISIT: vai até a entrada da base de outro jogador (nunca para dentro dela)
	  • PRESENTE: dá um bichinho da mochila para outro jogador; quem recebe precisa ACEITAR
	  • CLÃ: até 10 amigos; nome filtrado pelo Roblox (TextService); +2% de dinheiro por colega no servidor (máx. +10%)
	  • CONVITE: amigo NOVO que entra pelo seu convite = ovo grátis para você (até 5 por dia)
	O servidor confere tudo; a tela só pede (ações no Economy: Like, Visit, Gift, GiftAnswer, Clan*).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserService = game:GetService("UserService")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Registry = require(script.Parent.Registry)

local Social = {}

type Offer = { From: Player, Key: string, Id: string, Expires: number, OfferId: number }
type ClanInvite = { From: Player, ClanId: string, Name: string, Expires: number }

local giftOffers: { [Player]: Offer } = {}
local clanInvites: { [Player]: ClanInvite } = {}
local lastVisit: { [Player]: number } = {}
local busy: { [Player]: boolean } = {} -- pedido de clã em andamento (DataStore demora)
local clanCache: { [string]: any } = {}
local nameCache: { [number]: string } = {} -- nomes dos membros de clã fora do servidor (só na memória)
local nextOfferId = 0
local lastAsk: { [Player]: { [number]: number } } = {} -- anti-spam: quem pediu para quem (presente/clã)

-- 1 pedido (presente ou convite de clã) para a mesma pessoa a cada 30 s
local function canAsk(player: Player, target: Player): boolean
	local list = lastAsk[player] or {}
	lastAsk[player] = list
	if os.clock() - (list[target.UserId] or -math.huge) < 30 then
		Registry.Remotes.Notify(player, "Wait a little before asking " .. target.DisplayName .. " again.", "info")
		return false
	end
	list[target.UserId] = os.clock()
	return true
end

local clanStore: DataStore? = nil
local inviteStore: DataStore? = nil

local function today(): number
	return math.floor(os.time() / 86400)
end

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function ensure(data: any)
	data.Likes = math.max(0, math.floor(tonumber(data.Likes) or 0))
	if type(data.LikedToday) ~= "table" or data.LikedToday.Day ~= today() then
		data.LikedToday = { Day = today(), Owners = {} }
	end
	if type(data.GiftsToday) ~= "table" or data.GiftsToday.Day ~= today() then
		data.GiftsToday = { Day = today(), Count = 0 }
	end
	if type(data.Clan) ~= "string" then
		data.Clan = ""
	end
	if type(data.InviteRewards) ~= "table" or data.InviteRewards.Day ~= today() then
		data.InviteRewards = { Day = today(), Count = 0 }
	end
end

local function playerById(userId: number): Player?
	local found = Players:GetPlayerByUserId(userId)
	if found and found:GetAttribute("Loaded") then
		return found
	end
	return nil
end

---------------------------------------------------------------------
-- Tela
---------------------------------------------------------------------
function Social.Sync(player: Player)
	local data = getData(player)
	if not data or not player.Parent then
		return
	end
	ensure(data)
	local clan = if data.Clan ~= "" then clanCache[data.Clan] else nil
	local members = {}
	if clan then
		for id in clan.Members or {} do
			local userId = tonumber(id) or 0
			local online = Players:GetPlayerByUserId(userId)
			table.insert(members, { Id = userId, Name = if online then online.DisplayName else (nameCache[userId] or "Player"), Online = online ~= nil })
		end
		table.sort(members, function(a, b)
			return a.Name < b.Name
		end)
	end
	local liked = {}
	for id in data.LikedToday.Owners do
		table.insert(liked, tonumber(id))
	end
	Registry.Remotes.SocialEvent:FireClient(player, {
		Likes = data.Likes,
		LikedToday = liked,
		GiftsLeft = math.max(0, Config.GiftsPerDay - data.GiftsToday.Count),
		Clan = if clan
			then { Id = data.Clan, Name = clan.Name, Owner = clan.Owner, Members = members, Bonus = Social.ClanBonus(player) }
			else nil,
	})
end

-- Nomes dos membros (não salvamos nomes: perguntamos ao Roblox e guardamos só na memória)
local function fetchNames(clan: any)
	if type(clan) ~= "table" or type(clan.Members) ~= "table" then
		return
	end
	local missing = {}
	for id in clan.Members do
		local userId = tonumber(id)
		if userId and not nameCache[userId] and not Players:GetPlayerByUserId(userId) then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end
	pcall(function()
		for _, info in UserService:GetUserInfosByUserIdsAsync(missing) do
			nameCache[info.Id] = info.DisplayName
		end
	end)
end

local function syncAll()
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("Loaded") then
			Social.Sync(other)
		end
	end
end

---------------------------------------------------------------------
-- LIKE (1 por base por dia)
---------------------------------------------------------------------
function Social.Like(player: Player, ownerId: any)
	local data = getData(player)
	if not data or typeof(ownerId) ~= "number" or ownerId == player.UserId then
		return
	end
	local owner = playerById(ownerId)
	local ownerData = owner and getData(owner)
	if not owner or not ownerData then
		return
	end
	ensure(data)
	ensure(ownerData)
	local key = tostring(ownerId)
	if data.LikedToday.Owners[key] then
		Registry.Remotes.Notify(player, "You already liked this base today. Come back tomorrow!", "info")
		return
	end
	data.LikedToday.Owners[key] = true
	ownerData.Likes += 1
	owner:SetAttribute("Likes", ownerData.Likes)
	Registry.Remotes.Notify(player, ("You liked %s's base! \u{2764}"):format(owner.DisplayName), "success")
	Registry.Remotes.Notify(owner, ("%s liked your base! \u{2764} (%d likes)"):format(player.DisplayName, ownerData.Likes), "rare")
	Registry.Remotes.Effect(owner, "Liked")
	Registry.Remotes.Effect(player, "Liked")
	Social.Sync(player)
end

---------------------------------------------------------------------
-- VISIT (até a entrada da base do outro)
---------------------------------------------------------------------
function Social.Visit(player: Player, ownerId: any)
	if typeof(ownerId) ~= "number" or ownerId == player.UserId then
		return
	end
	local owner = playerById(ownerId)
	local plot = owner and Registry.Plots.Get(owner)
	local character = player.Character
	if not plot or not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	if Registry.CritterService.IsCarrying(player) then
		Registry.Remotes.Notify(player, "You can't visit while carrying something!", "warning")
		return
	end
	if player:GetAttribute("InMinigame") then
		Registry.Remotes.Notify(player, "Finish your minigame first!", "info")
		return
	end
	local here = player:GetAttribute("World")
	if here ~= nil and here ~= "meadow" then
		Registry.Remotes.Notify(player, "Go back to Meadow Valley first (HOME button)!", "info")
		return
	end
	if os.clock() - (lastVisit[player] or 0) < 8 then
		Registry.Remotes.Notify(player, "Wait a moment before visiting again.", "info")
		return
	end
	lastVisit[player] = os.clock()
	-- na frente da entrada (do lado de fora), olhando para a base
	local origin = plot.Origin.CFrame
	local halfZ = plot.Origin.Size.Z / 2
	local spot = (origin * CFrame.new(math.random(-4, 4), 0, -(halfZ + 8))).Position + Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(spot, Vector3.new(origin.Position.X, spot.Y, origin.Position.Z)))
	Registry.Remotes.Notify(player, ("Welcome to %s's base! Like it with the \u{2764} button on their sign."):format(owner.DisplayName), "info")
end

---------------------------------------------------------------------
-- PRESENTES (quem recebe precisa aceitar)
---------------------------------------------------------------------
function Social.GiftOffer(player: Player, request: any)
	local data = getData(player)
	if not data or type(request) ~= "table" or typeof(request.To) ~= "number" or typeof(request.Key) ~= "string" then
		return
	end
	ensure(data)
	local target = playerById(request.To)
	if not target or target == player then
		return
	end
	-- regras do país (PolicyService): onde trocar itens pagos é proibido, presentes ficam desligados
	if not Registry.Policy.CanTrade(player) then
		Registry.Remotes.Notify(player, "Gifts are not available where you live.", "info")
		return
	end
	if not Registry.Policy.CanTrade(target) then
		Registry.Remotes.Notify(player, target.DisplayName .. " can't receive gifts.", "info")
		return
	end
	if data.GiftsToday.Count >= Config.GiftsPerDay then
		Registry.Remotes.Notify(player, ("You can give %d gifts per day. Come back tomorrow!"):format(Config.GiftsPerDay), "info")
		return
	end
	local entry = Registry.Pets.Find(player, request.Key)
	if not entry then
		return
	end
	if (giftOffers[target] and giftOffers[target].Expires > os.clock()) or (clanInvites[target] and clanInvites[target].Expires > os.clock()) then
		Registry.Remotes.Notify(player, target.DisplayName .. " is answering another request. Try again in a moment!", "info")
		return
	end
	if not canAsk(player, target) then
		return
	end
	local def = Critters.ById[entry.Id]
	nextOfferId += 1
	giftOffers[target] = { From = player, Key = request.Key, Id = entry.Id, Expires = os.clock() + 30, OfferId = nextOfferId }
	Registry.Remotes.Effect(target, "GiftOffer", {
		OfferId = nextOfferId,
		From = player.DisplayName,
		Name = (if entry.S then "Shiny " else "") .. (if entry.M then entry.M .. " " else "") .. def.Name,
		Critter = entry.Id,
	})
	Registry.Remotes.Notify(player, ("Gift sent to %s. Waiting for them to accept..."):format(target.DisplayName), "info")
end

function Social.GiftAnswer(target: Player, answer: any)
	local offer = giftOffers[target]
	-- a resposta tem que ser para ESTA oferta (uma janela velha não recusa um presente novo)
	if not offer or type(answer) ~= "table" or answer.OfferId ~= offer.OfferId then
		return
	end
	giftOffers[target] = nil
	local accept = answer.Accept
	local sender = offer.From
	if accept ~= true then
		if sender.Parent then
			Registry.Remotes.Notify(sender, target.DisplayName .. " said no thanks to your gift. You kept it!", "info")
		end
		return
	end
	if not Registry.Policy.CanTrade(sender) or not Registry.Policy.CanTrade(target) then
		return
	end
	local senderData = getData(sender)
	if offer.Expires < os.clock() or not sender.Parent or not senderData then
		Registry.Remotes.Notify(target, "That gift expired.", "info")
		return
	end
	ensure(senderData)
	if senderData.GiftsToday.Count >= Config.GiftsPerDay then
		return
	end
	-- confere de novo (o bichinho pode ter sido vendido/usado nesses segundos) e troca de dono na mesma hora
	local entry = Registry.Pets.Find(sender, offer.Key)
	if not entry or entry.Id ~= offer.Id then
		Registry.Remotes.Notify(target, "That gift is not available anymore.", "info")
		return
	end
	if not Registry.Pets.HasRoom(target) then
		Registry.Remotes.Notify(target, "Your backpack is full! Make space and ask for the gift again.", "warning")
		Registry.Remotes.Notify(sender, target.DisplayName .. "'s backpack is full. You kept your critter.", "info")
		return
	end
	local taken = Registry.Pets.Take(sender, offer.Key)
	if not taken then
		return
	end
	Registry.Pets.Add(target, taken.Id, taken.M, taken.B, taken.S)
	senderData.GiftsToday.Count += 1
	local def = Critters.ById[taken.Id]
	Registry.Remotes.Notify(target, ("%s gave you %s! It's in your backpack."):format(sender.DisplayName, def.Name), "rare")
	Registry.Remotes.Notify(sender, ("You gave %s to %s. So kind!"):format(def.Name, target.DisplayName), "success")
	Registry.Remotes.Effect(target, "Stolen", def.Rarity)
	Registry.Analytics.Event(sender, "GiftGiven")
	Social.Sync(sender)
end

---------------------------------------------------------------------
-- CLÃS (DataStore "Clans_v1": um registro por clã)
---------------------------------------------------------------------
local function applyClan(player: Player, clanId: string, clan: any?)
	local data = getData(player)
	if not data then
		return
	end
	data.Clan = if clan then clanId else ""
	player:SetAttribute("ClanId", if clan then clanId else nil)
	player:SetAttribute("ClanName", if clan then clan.Name else nil)
	if clan then
		clanCache[clanId] = clan
	end
	local customize = Registry.Customize
	if customize then
		customize.RefreshTag(player)
	end
end

-- Bônus: +2% por colega de clã no mesmo servidor (máx. +10%)
function Social.ClanBonus(player: Player): number
	local clanId = player:GetAttribute("ClanId")
	if typeof(clanId) ~= "string" then
		return 0
	end
	local mates = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("ClanId") == clanId then
			mates += 1
		end
	end
	return math.min(Config.ClanBonusMax, mates * Config.ClanBonusPerMate)
end

local function refreshClanmates(clanId: string?)
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("Loaded") and (clanId == nil or other:GetAttribute("ClanId") == clanId) then
			Registry.Economy.Sync(other)
			Social.Sync(other)
		end
	end
end

local function filterName(player: Player, raw: string): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(raw, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(result) ~= "string" or string.find(result, "#", 1, true) then
		return nil
	end
	return result
end

-- Criar/sair de clã: um pouco de espera entre as ações e no máximo 3 clãs novos por dia
-- (evita encher o DataStore de clãs vazios)
local CLAN_ACTION_COOLDOWN = 20
local CLAN_CREATES_PER_DAY = 3

local function clanActionReady(player: Player, data: any): boolean
	local wait = (tonumber(data.ClanActionAt) or 0) + CLAN_ACTION_COOLDOWN - os.time()
	if wait > 0 then
		Registry.Remotes.Notify(player, ("Wait %d seconds and try again."):format(math.ceil(wait)), "info")
		return false
	end
	return true
end

function Social.ClanCreate(player: Player, rawName: any)
	if typeof(rawName) ~= "string" or #rawName > 40 then
		return
	end
	local data = getData(player)
	if not data or busy[player] then
		return
	end
	ensure(data)
	if data.Clan ~= "" then
		Registry.Remotes.Notify(player, "Leave your clan first to make a new one.", "info")
		return
	end
	if not clanActionReady(player, data) then
		return
	end
	local today = math.floor(os.time() / 86400)
	if data.ClanCreateDay ~= today then
		data.ClanCreateDay = today
		data.ClanCreates = 0
	end
	if (tonumber(data.ClanCreates) or 0) >= CLAN_CREATES_PER_DAY then
		Registry.Remotes.Notify(player, ("You can make up to %d clans per day. Try again tomorrow!"):format(CLAN_CREATES_PER_DAY), "info")
		return
	end
	local name = string.gsub(string.gsub(rawName, "[^%w ]", ""), "^%s*(.-)%s*$", "%1")
	if #name < 3 or #name > 20 then
		Registry.Remotes.Notify(player, "Clan names need 3 to 20 letters or numbers.", "warning")
		return
	end
	busy[player] = true
	local clean = filterName(player, name)
	if not clean then
		busy[player] = nil
		Registry.Remotes.Notify(player, "That name isn't allowed. Try another one!", "warning")
		return
	end
	local clanId = HttpService:GenerateGUID(false)
	local clan = {
		Name = clean,
		Owner = player.UserId,
		Members = { [tostring(player.UserId)] = true },
		Created = os.time(),
	}
	local ok = true
	if clanStore then
		ok = pcall(function()
			(clanStore :: DataStore):SetAsync(clanId, clan)
		end)
	end
	busy[player] = nil
	if not ok then
		Registry.Remotes.Notify(player, "Couldn't create the clan right now. Try again soon!", "error")
		return
	end
	clanCache[clanId] = clan
	data.ClanActionAt = os.time()
	data.ClanCreates = (tonumber(data.ClanCreates) or 0) + 1
	if player.Parent then
		applyClan(player, clanId, clan)
		Registry.Remotes.Notify(player, ("Clan \"%s\" created! Invite friends in the FRIENDS menu."):format(clean), "rare")
		refreshClanmates(clanId)
	end
end

function Social.ClanInvite(player: Player, targetId: any)
	local data = getData(player)
	if not data or typeof(targetId) ~= "number" then
		return
	end
	ensure(data)
	local clan = clanCache[data.Clan]
	local target = playerById(targetId)
	local targetData = target and getData(target)
	if not clan or not target or not targetData or target == player then
		return
	end
	ensure(targetData)
	if targetData.Clan ~= "" then
		Registry.Remotes.Notify(player, target.DisplayName .. " is already in a clan.", "info")
		return
	end
	if (clanInvites[target] and clanInvites[target].Expires > os.clock()) or (giftOffers[target] and giftOffers[target].Expires > os.clock()) then
		Registry.Remotes.Notify(player, target.DisplayName .. " is answering another request. Try again in a moment!", "info")
		return
	end
	if not canAsk(player, target) then
		return
	end
	clanInvites[target] = { From = player, ClanId = data.Clan, Name = clan.Name, Expires = os.clock() + 30 }
	Registry.Remotes.Effect(target, "ClanInvite", { From = player.DisplayName, Name = clan.Name })
	Registry.Remotes.Notify(player, "Clan invite sent to " .. target.DisplayName .. "!", "info")
end

function Social.ClanAnswer(target: Player, accept: any)
	local invite = clanInvites[target]
	clanInvites[target] = nil
	local data = getData(target)
	if not invite or not data or busy[target] then
		return
	end
	ensure(data)
	if accept ~= true or invite.Expires < os.clock() or data.Clan ~= "" then
		return
	end
	busy[target] = true
	local joined = nil
	local full = false
	if clanStore then
		pcall(function()
			(clanStore :: DataStore):UpdateAsync(invite.ClanId, function(clan)
				if type(clan) ~= "table" or type(clan.Members) ~= "table" or clan.Closed then
					return nil
				end
				local count = 0
				for _ in clan.Members do
					count += 1
				end
				if count >= Config.ClanMax then
					full = true
					return nil
				end
				clan.Members[tostring(target.UserId)] = true
				clan.Names = nil -- nomes não ficam salvos (só os UserIds)
				joined = clan
				return clan
			end)
		end)
	else
		-- sem DataStore (Studio sem API): só neste servidor
		local clan = clanCache[invite.ClanId]
		if clan and not clan.Closed then
			local count = 0
			for _ in clan.Members do
				count += 1
			end
			if count < Config.ClanMax then
				clan.Members[tostring(target.UserId)] = true
				joined = clan
			else
				full = true
			end
		end
	end
	busy[target] = nil
	if full then
		Registry.Remotes.Notify(target, ("That clan is full (%d players)."):format(Config.ClanMax), "info")
		return
	end
	if joined and not target.Parent then
		-- saiu enquanto entrava: desfaz (senão vira "membro fantasma" ocupando vaga)
		if clanStore then
			pcall(function()
				(clanStore :: DataStore):UpdateAsync(invite.ClanId, function(clan)
					if type(clan) == "table" and type(clan.Members) == "table" then
						clan.Members[tostring(target.UserId)] = nil
						return clan
					end
					return nil
				end)
			end)
		end
		return
	end
	if not joined then
		return
	end
	applyClan(target, invite.ClanId, joined)
	Registry.Remotes.Notify(target, ("You joined the clan \"%s\"!"):format(joined.Name), "rare")
	refreshClanmates(invite.ClanId)
end

function Social.ClanLeave(player: Player)
	local data = getData(player)
	if not data or busy[player] then
		return
	end
	ensure(data)
	local clanId = data.Clan
	if clanId == "" then
		return
	end
	if not clanActionReady(player, data) then
		return
	end
	busy[player] = true
	local key = tostring(player.UserId)
	local empty = false
	local function remove(clan)
		if type(clan) ~= "table" or type(clan.Members) ~= "table" then
			return nil
		end
		clan.Members[key] = nil
		clan.Names = nil
		if clan.Owner == player.UserId then
			clan.Owner = nil
			for id in clan.Members do
				clan.Owner = tonumber(id) -- o dono passa para outro membro
				break
			end
		end
		empty = next(clan.Members) == nil
		if empty then
			clan.Closed = true -- ninguém entra mais (o registro vai ser apagado logo em seguida)
		end
		return clan
	end
	if clanStore then
		local ok = pcall(function()
			(clanStore :: DataStore):UpdateAsync(clanId, remove)
		end)
		if not ok then
			busy[player] = nil
			Registry.Remotes.Notify(player, "Couldn't leave the clan right now. Try again soon!", "error")
			return -- só sai de verdade quando o registro do clã mudou
		end
		if empty then
			-- último membro saiu: apaga o registro do clã (não sobra lixo no DataStore)
			pcall(function()
				(clanStore :: DataStore):RemoveAsync(clanId)
			end)
			clanCache[clanId] = nil
		end
	elseif clanCache[clanId] then
		remove(clanCache[clanId])
		if empty then
			clanCache[clanId] = nil
		end
	end
	data.ClanActionAt = os.time()
	busy[player] = nil
	applyClan(player, clanId, nil)
	Registry.Remotes.Notify(player, "You left your clan.", "info")
	refreshClanmates(clanId)
	Social.Sync(player)
end

local function loadClan(player: Player)
	local data = getData(player)
	if not data or data.Clan == "" then
		return
	end
	local clanId = data.Clan
	local clan = clanCache[clanId]
	if clanStore then
		local ok, stored = pcall(function()
			return (clanStore :: DataStore):GetAsync(clanId)
		end)
		if ok then
			clan = stored
		elseif not clan then
			return -- DataStore fora do ar: tenta na próxima vez
		end
	end
	if not player.Parent then
		return
	end
	if type(clan) == "table" and type(clan.Members) == "table" and clan.Members[tostring(player.UserId)] then
		fetchNames(clan)
		applyClan(player, clanId, clan)
		refreshClanmates(clanId)
	else
		applyClan(player, clanId, nil) -- o clã acabou ou você saiu por outro servidor
	end
end

---------------------------------------------------------------------
-- CONVITES (LaunchData = "inv:<UserId de quem convidou>")
---------------------------------------------------------------------
-- devolve quantos NÃO couberam hoje (ficam guardados para outro dia)
local function rewardInviter(inviter: Player, count: number): number
	local data = getData(inviter)
	if not data then
		return count
	end
	ensure(data)
	local room = Config.InviteRewardsPerDay - data.InviteRewards.Count
	local give = math.clamp(count, 0, room)
	if give <= 0 then
		return count
	end
	data.InviteRewards.Count += give
	local codes = Registry.Codes
	if codes then
		local parts = codes.Grant(inviter, { WorldEgg = give })
		Registry.Remotes.Notify(inviter, ("A friend joined from your invite! You got %s."):format(table.concat(parts, " + ")), "rare")
	end
	return count - give
end

local function checkInvite(player: Player, profile)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local launch = ok and type(joinData) == "table" and joinData.LaunchData
	local inviterId = if type(launch) == "string" then tonumber(string.match(launch, "^inv:(%d+)$")) else nil
	if not inviterId or inviterId == player.UserId or not profile.IsNew then
		return -- só conta amigo NOVO (quem já jogava não dá prêmio)
	end
	-- contra contas falsas: tem que ser amigo de verdade de quem convidou e jogar 10 minutos
	local okFriends, friends = pcall(function()
		return player:IsFriendsWithAsync(inviterId)
	end)
	if not okFriends or not friends then
		return
	end
	task.wait(600)
	if not player.Parent then
		return
	end
	local codes = Registry.Codes
	if codes then
		codes.Grant(player, { Minutes = 5 })
		Registry.Remotes.Notify(player, "Thanks for playing 10 minutes with your friend's invite! You both get a gift!", "rare")
	end
	local inviter = playerById(inviterId)
	if inviter and rewardInviter(inviter, 1) == 0 then
		return
	elseif inviteStore then
		pcall(function()
			(inviteStore :: DataStore):UpdateAsync("u_" .. inviterId, function(old)
				return math.min((tonumber(old) or 0) + 1, 50)
			end)
		end)
	end
end

local function claimInviteRewards(player: Player)
	if not inviteStore then
		return
	end
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	local room = Config.InviteRewardsPerDay - data.InviteRewards.Count
	if room <= 0 then
		return
	end
	local take = 0
	pcall(function()
		(inviteStore :: DataStore):UpdateAsync("u_" .. player.UserId, function(old)
			local count = tonumber(old) or 0
			take = math.min(count, room)
			if take <= 0 then
				return nil
			end
			return count - take -- o que não coube hoje fica para outro dia
		end)
	end)
	if take > 0 and player.Parent then
		rewardInviter(player, take)
	end
end

---------------------------------------------------------------------
function Social.SetupPlayer(player: Player, profile)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	player:SetAttribute("Likes", data.Likes)
	task.spawn(function()
		loadClan(player)
		claimInviteRewards(player)
		Social.Sync(player)
	end)
	task.spawn(checkInvite, player, profile) -- espera 10 min jogando antes de dar o prêmio
end

function Social.RemovePlayer(player: Player)
	lastAsk[player] = nil
	giftOffers[player] = nil
	clanInvites[player] = nil
	lastVisit[player] = nil
	busy[player] = nil
	local clanId = player:GetAttribute("ClanId")
	for target, offer in giftOffers do
		if offer.From == player then
			giftOffers[target] = nil
		end
	end
	if typeof(clanId) == "string" then
		task.defer(refreshClanmates, clanId) -- o bônus dos colegas cai
	end
end

function Social.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Clans_v1")
	end)
	clanStore = if ok then result else nil
	local ok2, result2 = pcall(function()
		return DataStoreService:GetDataStore("InviteRewards_v1")
	end)
	inviteStore = if ok2 then result2 else nil
	if RunService:IsStudio() and clanStore then
		-- Studio sem "API Services": os clãs ficam só neste servidor (para dar para testar)
		task.spawn(function()
			local works = pcall(function()
				return (clanStore :: DataStore):GetAsync("test")
			end)
			if not works then
				clanStore = nil
				inviteStore = nil
			end
		end)
	end
	Players.PlayerRemoving:Connect(Social.RemovePlayer)
	-- botão LIKE no poste de cada base (a tela só mostra para quem NÃO é o dono)
	task.spawn(function()
		local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")
		for _, plot in plots:GetChildren() do
			local post = plot:FindFirstChild("LikePost")
			if post and post:IsA("BasePart") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "LikePrompt"
				prompt.ActionText = "Like \u{2764}"
				prompt.ObjectText = "This base"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.KeyboardKeyCode = Enum.KeyCode.F
				prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
				prompt.Triggered:Connect(function(player)
					local ownerId = plot:GetAttribute("OwnerUserId")
					if typeof(ownerId) == "number" then
						Social.Like(player, ownerId)
					end
				end)
				prompt.Parent = post
			end
		end
	end)
	-- a lista de jogadores da tela muda quando alguém entra/sai
	Players.PlayerAdded:Connect(function()
		task.delay(3, syncAll)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(syncAll)
	end)
end

return Social
