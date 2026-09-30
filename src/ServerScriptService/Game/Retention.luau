--[[
	Retention (ModuleScript em ServerScriptService > Game)
	v23: duas coisas para o jogador ficar mais tempo e voltar amanhã.
	  • PRESENTES DE TEMPO DE JOGO: a cada X minutos na sessão (Config.PlaytimeGifts) aparece um presente
	    na coluna da esquerda; o jogador clica e recebe (dinheiro, ovo ou 2x Cash). Zera quando sai.
	  • ROLETA DIÁRIA: 1 giro grátis por dia (Config.DailySpin). O servidor sorteia, entrega e manda o
	    resultado; a tela só faz a animação. Nunca custa Robux (por isso pode ser aleatória).
	Tudo é decidido aqui; a tela só pede ("GiftClaim" e "SpinDaily").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Retention = {}

type Session = { Seconds: number, Tier: number, ReadyAt: number } -- ReadyAt = os.time() em que o presente atual fica pronto
local sessions: { [Player]: Session } = {}

local function getData(player: Player)
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Quantos segundos de sessão o presente "tier" exige
local function tierSeconds(tier: number): number
	local gifts = Config.PlaytimeGifts
	if tier <= #gifts then
		return gifts[tier].Minutes * 60
	end
	return gifts[#gifts].Minutes * 60 + (tier - #gifts) * Config.PlaytimeGiftRepeat * 60
end

local function giftFor(tier: number)
	local gifts = Config.PlaytimeGifts
	if tier <= #gifts then
		return gifts[tier]
	end
	return { Cash = 6 } -- depois do último: dinheiro a cada PlaytimeGiftRepeat min
end

local function publish(player: Player, session: Session)
	player:SetAttribute("GiftTier", session.Tier)
	player:SetAttribute("GiftReadyAt", session.ReadyAt) -- os.time(); a tela mostra a contagem
	local gift = giftFor(session.Tier)
	local text = if gift.Egg then (Config.EggById[gift.Egg] or { Name = "Egg" }).Name
		elseif gift.Boost and gift.Cash then ("2x Cash %dm + cash"):format(gift.Boost)
		elseif gift.Boost then ("2x Cash %d min"):format(gift.Boost)
		else "Cash"
	player:SetAttribute("GiftName", text)
end

local function startSession(player: Player)
	local session = { Seconds = 0, Tier = 1, ReadyAt = os.time() + tierSeconds(1) }
	sessions[player] = session
	publish(player, session)
end

-- Entrega um prêmio genérico ({ Cash = minutos, Egg = id, Boost = minutos }) e devolve o texto
local function grant(player: Player, reward, minCash: number, source: string): string
	local parts = {}
	local Economy = Registry.Economy
	if type(reward.Cash) == "number" then
		local amount = math.floor(math.max(Economy.GetIncome(player) * 60 * reward.Cash, minCash))
		Economy.AddCash(player, amount, false, source)
		table.insert(parts, "+" .. Format.Money(amount))
	end
	if type(reward.Boost) == "number" then
		Registry.Codes.AddBoost(player, reward.Boost)
		table.insert(parts, ("2x Cash %d min"):format(reward.Boost))
	end
	if type(reward.Egg) == "string" and Config.EggById[reward.Egg] then
		local ok = Registry.CritterService.GrantEgg(player, reward.Egg)
		table.insert(parts, Config.EggById[reward.Egg].Name .. (if ok then "" else " (queued: base full)"))
	end
	return table.concat(parts, " + ")
end
Retention.Grant = grant -- v27: o WorldFun usa o mesmo jeito de dar prêmio

---------------------------------------------------------------------
-- Presentes de tempo de jogo
---------------------------------------------------------------------
function Retention.ClaimGift(player: Player)
	local session = sessions[player]
	if not session or not player:GetAttribute("Loaded") then
		return
	end
	if os.time() < session.ReadyAt then
		Registry.Remotes.Notify(player, ("Gift in %s!"):format(Format.Time(session.ReadyAt - os.time())), "info")
		return
	end
	local gift = giftFor(session.Tier)
	local text = grant(player, gift, Config.PlaytimeGiftMinCash, "PlaytimeGift")
	Registry.Remotes.Notify(player, ("Playtime gift #%d: %s!"):format(session.Tier, text), "rare")
	Registry.Remotes.Effect(player, "Purchase", "Epic")
	if Registry.Analytics then
		pcall(Registry.Analytics.Event, player, "PlaytimeGift", session.Tier)
	end
	session.Tier += 1
	session.ReadyAt = os.time() + (tierSeconds(session.Tier) - tierSeconds(session.Tier - 1))
	publish(player, session)
end

---------------------------------------------------------------------
-- Roleta diária
---------------------------------------------------------------------
function Retention.SpinReady(player: Player): boolean
	local data = getData(player)
	return data ~= nil and (tonumber(data.SpinDay) or 0) ~= today()
end

function Retention.SyncSpin(player: Player)
	player:SetAttribute("SpinReady", Retention.SpinReady(player))
end

function Retention.Spin(player: Player)
	local data = getData(player)
	if not data or not player:GetAttribute("Loaded") then
		return
	end
	if not Retention.SpinReady(player) then
		Registry.Remotes.Notify(player, "You already spun today! Come back tomorrow.", "info")
		return
	end
	data.SpinDay = today()
	Retention.SyncSpin(player)
	-- sorteio pelos pesos (a tela mostra as % de cada prêmio)
	local total = 0
	for _, prize in Config.DailySpin do
		total += prize.Weight
	end
	local roll = math.random() * total
	local index = #Config.DailySpin
	for i, prize in Config.DailySpin do
		roll -= prize.Weight
		if roll <= 0 then
			index = i
			break
		end
	end
	local prize = Config.DailySpin[index]
	-- a tela gira primeiro (2,6 s) e só depois o prêmio "chega"
	Registry.Remotes.Effect(player, "Spin", { Index = index })
	task.delay(2.7, function()
		if not player.Parent then
			return
		end
		local text = grant(player, prize, Config.DailySpinMinCash, "DailySpin")
		Registry.Remotes.Notify(player, ("Daily spin: %s!"):format(text), "rare")
		if index >= #Config.DailySpin - 1 then
			Registry.Remotes.NotifyAll(("%s hit %s on the Daily Spin!"):format(player.DisplayName, string.upper(prize.Name)), "rare")
		end
	end)
	if Registry.Analytics then
		pcall(Registry.Analytics.Event, player, "DailySpin", index)
	end
end

function Retention.Init()
	local function watch(player: Player)
		startSession(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	-- quando os dados carregam, avisa se a roleta está pronta
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("Loaded"):Connect(function()
			if player:GetAttribute("Loaded") then
				Retention.SyncSpin(player)
			end
		end)
	end)
	-- conta o tempo só de quem está carregado (o relógio do presente é por os.time(), então
	-- o servidor não precisa de loop por frame; aqui só reforça o atributo a cada 30 s)
	-- v24: MARCOS para o Analytics (Creator Hub > Analytics > Custom): minutos de sessão e bichinhos na base.
	--   Cada marco conta 1x por sessão; assim dá para ver em que minuto a criança para de jogar.
	local SESSION_MARKS = { 2, 5, 10, 20, 30, 60 }
	local CRITTER_MARKS = { 3, 5, 10, 25, 42 }
	local marksSent: { [Player]: { [string]: boolean } } = {}
	Players.PlayerRemoving:Connect(function(player)
		marksSent[player] = nil
	end)
	local function mark(player: Player, name: string, value: number?)
		local sent = marksSent[player]
		if not sent then
			sent = {}
			marksSent[player] = sent
		end
		if sent[name] then
			return
		end
		sent[name] = true
		local analytics = Registry.Analytics
		if analytics then
			pcall(analytics.Event, player, name, value)
		end
	end
	task.spawn(function()
		local started: { [Player]: number } = {}
		while true do
			task.wait(30)
			for player, session in sessions do
				if player.Parent then
					publish(player, session)
					if player:GetAttribute("Loaded") then
						Retention.SyncSpin(player)
						started[player] = started[player] or os.time()
						local minutes = (os.time() - started[player]) / 60
						for _, m in SESSION_MARKS do
							if minutes >= m then
								mark(player, ("Session%dMin"):format(m), m)
							end
						end
						local critterService = Registry.CritterService
						if critterService then
							local ok, list = pcall(critterService.GetBaseList, player)
							local count = if ok and type(list) == "table" then #list else 0
							for _, c in CRITTER_MARKS do
								if count >= c then
									mark(player, ("Critters%d"):format(c), c)
								end
							end
						end
					end
				else
					started[player] = nil
				end
			end
		end
	end)
end

return Retention
