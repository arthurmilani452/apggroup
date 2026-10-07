--[[
	Sim: TODAS as regras e contas do jogo, sem nada do Roblox (roda em teste fora do Studio).
	  C    = Config
	  data = dados salvos do jogador (ver Sim.NewData)
	  run  = estado da sessão que não é salvo (moedas no chão, ciclos em andamento, ovos raros nos ninhos)
	  ctx  = contexto do momento: { Now = os.time(), Owned = {passes da sessão}, EventSpeed = 1,
	         Friends = 0 (bônus 0..1), Group = false, Weather = id do clima do servidor (versão 5; nil = sem clima) }
	O servidor só chama estas funções e desenha o resultado; o cliente usa as mesmas contas para mostrar.

	Negócios (C.Businesses): cada um roda em CICLOS. Um ciclo paga Payout x melhorias de dinheiro x bônus
	gerais, e dura Cycle / (melhorias de velocidade x bônus de velocidade). Com gerente, os ciclos rodam
	sozinhos (Sim.Tick). Sem gerente, o jogador faz: Sim.Click (banca) ou Sim.StartWork + Sim.FinishWork;
	o dinheiro do ciclo feito na mão vale HandMult e cai no chão (run.Ground) até ele passar e pegar.
]]

local Sim = {}

-- ---------------------------------------------------------------------------
-- Dados
-- ---------------------------------------------------------------------------
function Sim.NewData(C: any): any
	return {
		V = C.Version,
		Coins = 0,
		RunEarned = 0, -- ganho desde o último renascer
		SealEarned = 0, -- ganho desde o último Selo (define as Estrelas)
		StarsEarned = 0, -- Estrelas já entregues por SealEarned
		TotalEarned = 0, -- ganho da vida toda (placar)
		Owned = {}, -- [idDoBotão] = true (zera ao renascer)
		Basket = {}, -- ovos raros na cesta: ["branco:s"] = n
		Stars = 0, -- Estrelas para gastar em Talentos
		StarsTotal = 0, -- Estrelas ganhas desde o último Selo (dão o bônus de renda)
		Rebirths = 0,
		Seal = 0, -- 0 = nenhum; 1 = bronze...
		Talents = {}, -- [id] = nível
		Album = {}, -- [chave do ovo] = quantos (figurinha normal ao liberar a ave; raras ao vender)
		Passes = {},
		Boosts = {}, -- { Turbo = os.time() em que acaba, Sorte = ... }
		Receipts = {},
		Bought = {}, -- produtos de compra única já entregues: [Key do produto] = true (ver Sim.DeliverProduct)
		VipDay = 0, -- dia (Sim.DayKey) em que o passe VIP deu o giro/presente diário pela última vez
		Daily = { Day = 0, List = {} },
		GiftSeconds = 0,
		GroupChestAt = 0, -- v6: quando abriu o Baú do Grupo pela última vez (os.time)
		Achieved = {}, -- v6: conquistas: [id] = quantos degraus já pegou
		FavoriteAsked = false, -- v6: a janela de favoritar já apareceu uma vez
		LikeAsked = false, -- v6: o lembrete de curtir já apareceu uma vez
		Streak = { Day = 0, Count = 0 },
		Codes = {},
		Hunt = {}, -- [índice do ovo escondido] = true
		Pets = {}, -- [chave do pet] = quantos já chocou (repetido = nível)
		Equip = {}, -- lista das chaves equipadas
		Hatch = {}, -- ["1"] = { Key = chave do ovo, Ready = os.time() em que nasce }
		Keys = 0, -- chaves secretas na mão (0..C.Keys.Need); abrem o Baú Secreto (ver Sim.KeyTick / Sim.OpenChest)
		Powers = {}, -- poderes: [id] = os.time() em que fica pronto de novo (sem a chave do poder = pronto)
		PowerOn = {}, -- poderes com duração: [id] = os.time() em que o efeito acaba (hoje só o "galo")
		Spins = 0, -- giros guardados da roleta
		SpinAt = 0, -- os.time() do próximo giro grátis
		ObbyAt = 0, -- os.time() em que o obby dá prêmio de novo
		GiantPity = 0, -- rachaduras do Ovo Gigante sem ganhar o pet
		RareSeen = false, -- já apareceu o 1º ovo raro da vida
		Likes = 0,
		LastSeen = 0,
		OfflinePending = 0,
		OfflineSeconds = 0,
		Settings = {},
		Stats = { Worked = 0, Tips = 0, Sold = 0, Mutants = 0, Buttons = 0, Orders = 0, PlayTime = 0, Hatched = 0, Giant = 0, Spun = 0, Obby = 0, Bags = 0, Keys = 0, Chests = 0, Powers = 0 },
		SaveSeq = 0,
	}
end

function Sim.NewRun(): any
	return {
		Acc = {}, -- [negócio] = fração de ciclo acumulada (com gerente)
		Work = {}, -- [negócio] = senha do ciclo manual em andamento
		WorkSeq = 0,
		Ground = {}, -- [negócio] = moedas no chão esperando o jogador
		Tips = 0, -- gorjetas no chão da banca
		TipAcc = 0,
		Rare = {}, -- ovos raros nos ninhos: { Line = ave, Slot = ninho, Mut = raridade }
		RareAcc = 0,
		Apples = 0,
		AppleAcc = 0,
		Golden = 0,
		AutoAcc = 0, -- passe SuperClique: fração de clique automático acumulada
		-- saco de dinheiro (ver Sim.BagTick): Bag = o saco que está no chão ({ Id, Spot, Golden, Seconds, Left })
		-- ou nil; BagWait = segundos de jogo até cair o próximo (nil = ainda não sorteou); BagSeq = contador;
		-- BagSpot = último lugar usado (o próximo cai em outro).
		BagSeq = 0,
		-- chave secreta (ver Sim.KeyTick): Key = a chave escondida no terreno ({ Id, Spot, Age }) ou nil;
		-- KeyWait = segundos de jogo até nascer a próxima (nil = ainda não sorteou); KeySeq = contador;
		-- KeySpot = último lugar usado (a próxima nasce em outro).
		KeySeq = 0,
	}
end

local function count(t: any): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end
Sim.Count = count

function Sim.Has(data: any, id: string): boolean
	return data.Owned[id] == true
end

function Sim.HasPass(data: any, ctx: any, key: string): boolean
	return (ctx ~= nil and ctx.Owned ~= nil and ctx.Owned[key] == true) or data.Passes[key] == true
end

function Sim.BoostActive(data: any, ctx: any, boost: string): boolean
	return (tonumber(data.Boosts[boost]) or 0) > ((ctx and ctx.Now) or 0)
end

-- Chave do ovo na cesta/álbum
function Sim.EggKey(lineId: string, mutId: string?): string
	if mutId and mutId ~= "" then
		return lineId .. ":" .. mutId
	end
	return lineId
end

function Sim.ParseKey(key: string): (string, string)
	local at = string.find(key, ":", 1, true)
	if at then
		return string.sub(key, 1, at - 1), string.sub(key, at + 1)
	end
	return key, ""
end

-- ---------------------------------------------------------------------------
-- Talentos
-- ---------------------------------------------------------------------------
local PASS_TALENT = { magnet = "Ima", remote = "CompraRemota" }

function Sim.TalentLevel(C: any, data: any, ctx: any, id: string): number
	local talent = C.TalentById[id]
	if not talent then
		return 0
	end
	local pass = PASS_TALENT[id]
	if pass and Sim.HasPass(data, ctx, pass) then
		return #talent.Values
	end
	return math.clamp(tonumber(data.Talents[id]) or 0, 0, #talent.Values)
end

-- Valor do talento no nível atual (default quando o nível é 0)
function Sim.TalentValue(C: any, data: any, ctx: any, id: string, default: number): number
	local level = Sim.TalentLevel(C, data, ctx, id)
	if level <= 0 then
		return default
	end
	return C.TalentById[id].Values[level]
end

function Sim.TalentCost(C: any, data: any, id: string): number?
	local talent = C.TalentById[id]
	if not talent then
		return nil
	end
	return talent.Costs[(tonumber(data.Talents[id]) or 0) + 1]
end

function Sim.BuyTalent(C: any, data: any, id: string): (boolean, string?)
	local cost = Sim.TalentCost(C, data, id)
	if not cost then
		return false, "max"
	end
	if data.Stars < cost then
		return false, "stars"
	end
	data.Stars -= cost
	data.Talents[id] = (tonumber(data.Talents[id]) or 0) + 1
	return true, nil
end

function Sim.WalkSpeed(C: any, data: any, ctx: any): number
	return C.BaseWalkSpeed * Sim.TalentValue(C, data, ctx, "speed", 1)
end

function Sim.CollectRadius(C: any, data: any, ctx: any): number
	return Sim.TalentValue(C, data, ctx, "magnet", C.CollectRadius)
end

-- ---------------------------------------------------------------------------
-- Negócios e multiplicadores
-- ---------------------------------------------------------------------------
-- O que o jogador tem de um negócio: { Unlocked, Manager, Cash, Speed, CashStep, SpeedStep }
function Sim.BizInfo(C: any, data: any, index: number): any
	local biz = C.Businesses[index]
	local info = { Unlocked = false, Manager = false, Cash = 1, Speed = 1, CashStep = 0, SpeedStep = 0 }
	if not biz or not data.Owned[biz.Id .. "_unlock"] then
		return info
	end
	info.Unlocked = true
	info.Manager = data.Owned[biz.Id .. "_gerente"] == true
	local chains = C.Upgrades[biz.Id]
	for _, def in chains.cash do
		if data.Owned[biz.Id .. "_" .. def[1]] then
			info.Cash *= def[2]
			info.CashStep += 1
		end
	end
	for _, def in chains.speed do
		if data.Owned[biz.Id .. "_" .. def[1]] then
			info.Speed *= def[2]
			info.SpeedStep += 1
		end
	end
	return info
end

-- Quantos negócios o jogador já abriu
function Sim.BizCount(C: any, data: any): number
	local n = 0
	for _, biz in C.Businesses do
		if data.Owned[biz.Id .. "_unlock"] then
			n += 1
		end
	end
	return n
end

-- Aves: a 1ª vem com a Granja; as outras são botões "ave_<id>"
function Sim.HasBird(C: any, data: any, index: number): boolean
	local line = C.Lines[index]
	if not line or not data.Owned.granja_unlock then
		return false
	end
	return index == 1 or data.Owned["ave_" .. line.Id] == true
end

function Sim.BirdCount(C: any, data: any): number
	local n = 0
	for index in C.Lines do
		if Sim.HasBird(C, data, index) then
			n += 1
		end
	end
	return n
end

-- A melhor ave que o jogador tem (0 = nenhuma)
function Sim.BestLine(C: any, data: any): number
	local best = 0
	for index in C.Lines do
		if Sim.HasBird(C, data, index) then
			best = index
		end
	end
	return best
end

function Sim.AlbumCount(data: any): number
	return count(data.Album)
end

function Sim.HuntCount(data: any): number
	return count(data.Hunt)
end

-- Multiplicador de dinheiro de TUDO (permanente + aves + decoração + passe + amigos). Devolve também as partes.
function Sim.CashMult(C: any, data: any, ctx: any): (number, any)
	local parts = {
		Stars = 1 + C.StarBonus * (tonumber(data.StarsTotal) or 0),
		Seal = C.SealMult ^ (tonumber(data.Seal) or 0),
		Album = 1 + C.AlbumBonus * Sim.AlbumCount(data),
		Birds = 1,
		Decor = 1,
		Pass = 1,
		Social = 1,
		Hunt = 1,
		Pets = Sim.PetMult(C, data, ctx),
	}
	for index, line in C.Lines do
		if index > 1 and Sim.HasBird(C, data, index) then
			parts.Birds *= line.Cash
		end
	end
	for _, def in C.GlobalButtons do
		if def.Cash and data.Owned["G_" .. def.Kind] then
			parts.Decor *= def.Cash
		end
	end
	if Sim.HasPass(data, ctx, "Dinheiro2x") then
		parts.Pass = 2
	end
	-- o VIP multiplica com o resto (com o Dinheiro2x: 2 x 1,5 = 3x)
	if C.VIP and Sim.HasPass(data, ctx, "VIP") then
		parts.Pass *= 1 + C.VIP.CashBonus
	end
	local social = 1 + math.clamp((ctx and ctx.Friends) or 0, 0, C.FriendBonusMax)
	if ctx and ctx.Group then
		social += C.GroupBonus
	end
	if ctx and ctx.Premium then
		social += C.PremiumBonus or 0
	end
	parts.Social = social
	if (tonumber(data.HuntTotal) or 0) > 0 and Sim.HuntCount(data) >= data.HuntTotal then
		parts.Hunt = C.HuntAllBonus
	end
	local mult = parts.Stars * parts.Seal * parts.Album * parts.Birds * parts.Decor * parts.Pass * parts.Social * parts.Hunt * parts.Pets
	return mult, parts
end

-- Multiplicador de velocidade de TODOS os negócios (moinho, evento, boost)
function Sim.SpeedMult(C: any, data: any, ctx: any): number
	local mult = 1
	for _, def in C.GlobalButtons do
		if def.SpeedAll and data.Owned["G_" .. def.Kind] then
			mult *= def.SpeedAll
		end
	end
	if ctx then
		mult *= ctx.EventSpeed or 1
		if Sim.BoostActive(data, ctx, "Turbo") then
			mult *= C.TurboBoostMult
		end
		-- poder de velocidade ligado ("Canto do Galo"; ver Sim.UsePower). Com o contexto neutro (Now =
		-- infinito) nunca está ligado: prêmios e renda offline não enxergam o poder.
		for _, power in C.Powers or {} do
			if power.Speed and Sim.PowerActive(C, data, ctx, power.Id) then
				mult *= power.Speed
			end
		end
	end
	return mult
end

-- Ciclo feito na mão vale mais (bônus de mão x talento). O passe SuperClique soma ao bônus de mão.
function Sim.HandMult(C: any, data: any, ctx: any): number
	local bonus = C.HandBonus
	if C.SuperClick and Sim.HasPass(data, ctx, "SuperClique") then
		bonus += C.SuperClick.HandBonus
	end
	return bonus * Sim.TalentValue(C, data, ctx, "hands", 1)
end

-- ---------------------------------------------------------------------------
-- CLIMA (versão 5; C.Weather). O servidor inteiro tem um clima de cada vez (Server/Weather.lua) e põe o
-- id dele em ctx.Weather. Todo clima só AJUDA: alguns negócios pagam Mult vezes por ciclo. O contexto
-- neutro (Sim.BaseCtx) não leva o clima: prêmios "em segundos de renda" (saco, baú, roleta, gorjeta, ovo
-- raro...) e a renda offline não mudam com o tempo que está fazendo.
-- ---------------------------------------------------------------------------
-- O clima do contexto: a definição do Config, ou nil (sem clima, id desconhecido, Config sem clima).
-- ctx.Weather é o ID ("chuva"); aceita também a própria definição, para quem já a tem na mão.
function Sim.WeatherDef(C: any, ctx: any): any?
	local weather = ctx and ctx.Weather
	if weather == nil or not C.WeatherById then
		return nil
	end
	if type(weather) == "table" then
		return weather
	end
	return C.WeatherById[weather]
end

-- Quantas vezes o clima multiplica o PAGAMENTO de um ciclo do negócio (1 = o clima não mexe nele)
function Sim.WeatherMult(C: any, ctx: any, index: number): number
	local def = Sim.WeatherDef(C, ctx)
	if not def then
		return 1
	end
	if def.All or (def.Biz and table.find(def.Biz, index) ~= nil) then
		return tonumber(def.Mult) or 1
	end
	return 1
end

-- Quantas vezes mais rápido o relógio dos ovos raros anda neste clima (1 = normal)
function Sim.WeatherRare(C: any, ctx: any): number
	local def = Sim.WeatherDef(C, ctx)
	return math.max(1, tonumber(def and def.Rare) or 1)
end

-- Sorteia o próximo clima pelos pesos. Nunca o mesmo duas vezes seguidas (currentId fica fora do sorteio).
function Sim.NextWeather(C: any, currentId: string?, rng: () -> number): any
	local list = C.Weather.List
	local total = 0
	for _, def in list do
		if def.Id ~= currentId then
			total += def.Weight or 1
		end
	end
	local roll = rng() * total
	local last = nil
	for _, def in list do
		if def.Id ~= currentId then
			last = def
			roll -= def.Weight or 1
			if roll < 0 then
				return def
			end
		end
	end
	return last or list[1] -- (só chega aqui por arredondamento, ou se a lista tiver um clima só)
end

-- Quantos segundos (de relógio) este clima fica (sorteado entre os dois números do Config)
function Sim.WeatherSeconds(def: any, rng: () -> number): number
	local range = def.Seconds
	return range[1] + rng() * (range[2] - range[1])
end

-- Moedas de UM ciclo do negócio (com gerente; na mão ainda multiplica por HandMult). O clima entra aqui:
-- vale para o ciclo do gerente, o ciclo feito na mão e o clique da banca.
function Sim.Payout(C: any, data: any, ctx: any, index: number, info: any?, cash: number?): number
	local biz = C.Businesses[index]
	if not biz then
		return 0
	end
	info = info or Sim.BizInfo(C, data, index)
	if not info.Unlocked then
		return 0
	end
	cash = cash or Sim.CashMult(C, data, ctx)
	return biz.Payout * info.Cash * cash * Sim.WeatherMult(C, ctx, index)
end

-- Segundos de um ciclo do negócio
function Sim.CycleTime(C: any, data: any, ctx: any, index: number, info: any?, speed: number?): number
	local biz = C.Businesses[index]
	info = info or Sim.BizInfo(C, data, index)
	speed = speed or Sim.SpeedMult(C, data, ctx)
	return biz.Cycle / (info.Speed * speed)
end

-- Renda por segundo do negócio se estiver rodando sem parar (0 se fechado)
function Sim.BizIncome(C: any, data: any, ctx: any, index: number, info: any?, cash: number?, speed: number?): number
	info = info or Sim.BizInfo(C, data, index)
	if not info.Unlocked then
		return 0
	end
	return Sim.Payout(C, data, ctx, index, info, cash) / Sim.CycleTime(C, data, ctx, index, info, speed)
end

-- Renda por segundo: auto = só negócios com gerente; all = todos os abertos (régua dos prêmios)
function Sim.Income(C: any, data: any, ctx: any): (number, number)
	local cash = Sim.CashMult(C, data, ctx)
	local speed = Sim.SpeedMult(C, data, ctx)
	local auto, all = 0, 0
	for index in C.Businesses do
		local info = Sim.BizInfo(C, data, index)
		if info.Unlocked then
			local perSecond = Sim.BizIncome(C, data, ctx, index, info, cash, speed)
			if info.Manager then
				auto += perSecond
			end
			all += perSecond
		end
	end
	return auto, all
end

-- Contexto "neutro": sem evento, sem boost por tempo, sem clima e sem poder ligado (para prêmios e renda
-- offline). Now = infinito: nenhum boost "ainda não acabou" (com Now = 0, qualquer boost já ganho contava
-- como ligado para sempre e dobrava os prêmios e a renda offline). O clima (ctx.Weather) fica de fora de
-- propósito: um baú aberto na chuva vale o mesmo que no sol.
function Sim.BaseCtx(ctx: any): any
	return { Now = math.huge, Owned = ctx and ctx.Owned, EventSpeed = 1, Friends = 0, Group = ctx and ctx.Group }
end

-- Prêmio que vale "seconds" segundos da renda do jogador
function Sim.Reward(C: any, data: any, ctx: any, seconds: number, minimum: number?): number
	local _, all = Sim.Income(C, data, Sim.BaseCtx(ctx))
	local income = math.max(all, C.MinIncomeForRewards)
	return math.max(minimum or 0, math.floor(income * seconds))
end

-- ---------------------------------------------------------------------------
-- Moedas
-- ---------------------------------------------------------------------------
function Sim.Mission(data: any, missionId: string, amount: number)
	local list = data.Daily and data.Daily.List
	if not list then
		return
	end
	for _, mission in list do
		if mission.Id == missionId and not mission.Claimed and mission.Progress < mission.Target then
			mission.Progress = math.min(mission.Target, mission.Progress + amount)
		end
	end
end

-- earned = conta para as Estrelas, o placar e a missão "ganhe moedas"
function Sim.AddCoins(data: any, amount: number, earned: boolean)
	if amount ~= amount or amount <= 0 then
		return
	end
	data.Coins += amount
	if earned then
		data.RunEarned += amount
		data.SealEarned += amount
		data.TotalEarned += amount
		Sim.Mission(data, "earn", amount)
	end
end

-- ---------------------------------------------------------------------------
-- Trabalho na mão (sem gerente) e moedas no chão
-- ---------------------------------------------------------------------------
local function drop(run: any, index: number, amount: number)
	run.Ground[index] = (run.Ground[index] or 0) + amount
end

local function worked(data: any)
	data.Stats.Worked = (data.Stats.Worked or 0) + 1
	Sim.Mission(data, "work", 1)
end

-- Um clique na banca: vende um ovo na hora. Devolve as moedas que caíram no chão (0 se a banca está fechada).
function Sim.Click(C: any, data: any, run: any, ctx: any): number
	local info = Sim.BizInfo(C, data, 1)
	if not info.Unlocked then
		return 0
	end
	local amount = Sim.Payout(C, data, ctx, 1, info) * Sim.HandMult(C, data, ctx)
	drop(run, 1, amount)
	worked(data)
	return amount
end

-- Dá para começar um ciclo na mão neste negócio? (aberto, sem gerente, sem ciclo em andamento)
function Sim.CanWork(C: any, data: any, run: any, index: number): boolean
	if index < 2 or run.Work[index] ~= nil then
		return false
	end
	local info = Sim.BizInfo(C, data, index)
	return info.Unlocked and not info.Manager
end

-- Começa um ciclo na mão. Devolve (segundos do ciclo, senha) ou nil. Quem chama espera os segundos e
-- chama Sim.FinishWork com a senha.
function Sim.StartWork(C: any, data: any, run: any, ctx: any, index: number): (number?, number?)
	if not Sim.CanWork(C, data, run, index) then
		return nil, nil
	end
	run.WorkSeq += 1
	run.Work[index] = run.WorkSeq
	return math.max(C.MinCycle, Sim.CycleTime(C, data, ctx, index)), run.WorkSeq
end

-- Termina o ciclo: as moedas caem no chão do negócio. Devolve quanto (0 se a senha não vale mais).
function Sim.FinishWork(C: any, data: any, run: any, ctx: any, index: number, token: number): number
	if run.Work[index] ~= token then
		return 0
	end
	run.Work[index] = nil
	local info = Sim.BizInfo(C, data, index)
	if not info.Unlocked then
		return 0
	end
	local amount = Sim.Payout(C, data, ctx, index, info) * Sim.HandMult(C, data, ctx)
	drop(run, index, amount)
	worked(data)
	return amount
end

-- Pega as moedas do chão de um negócio
function Sim.CollectGround(C: any, data: any, run: any, index: number): number
	local amount = run.Ground[index] or 0
	if amount <= 0 then
		return 0
	end
	run.Ground[index] = nil
	Sim.AddCoins(data, amount, true)
	return amount
end

function Sim.GroundTotal(run: any): number
	local total = 0
	for _, amount in run.Ground do
		total += amount
	end
	return total
end

-- Pega tudo que está no chão (saiu do jogo, renasceu...). Devolve o total.
function Sim.CollectAllGround(C: any, data: any, run: any, ctx: any): number
	local total = 0
	for index in C.Businesses do
		total += Sim.CollectGround(C, data, run, index)
	end
	local tips = Sim.CollectTips(C, data, run, ctx)
	return total + tips
end

-- Gorjetas: devolve (moedas, quantas gorjetas)
function Sim.CollectTips(C: any, data: any, run: any, ctx: any): (number, number)
	local n = run.Tips or 0
	if n <= 0 then
		return 0, 0
	end
	run.Tips = 0
	local amount = n * Sim.Reward(C, data, ctx, C.TipSeconds, 1)
	Sim.AddCoins(data, amount, true)
	data.Stats.Tips = (data.Stats.Tips or 0) + n
	Sim.Mission(data, "tips", n)
	return amount, n
end

-- ---------------------------------------------------------------------------
-- Cesta e ovos raros
-- ---------------------------------------------------------------------------
function Sim.BasketCap(C: any, data: any, ctx: any): number
	local cap = C.StartBasket
	for _, def in C.GlobalButtons do
		if def.Basket and data.Owned["G_" .. def.Kind] then
			cap = math.max(cap, def.Basket)
		end
	end
	return math.floor(cap * Sim.TalentValue(C, data, ctx, "basket", 1))
end

function Sim.BasketCount(data: any): number
	local total = 0
	for _, n in data.Basket do
		total += n
	end
	return total
end

-- Sorte: divide o tempo entre ovos raros
function Sim.MutationChanceMult(C: any, data: any, ctx: any): number
	local mult = Sim.TalentValue(C, data, ctx, "luck", 1)
	if Sim.HasPass(data, ctx, "Sorte2x") then
		mult *= 2
	end
	if Sim.BoostActive(data, ctx, "Sorte") then
		mult *= C.LuckBoostMult
	end
	return mult
end

-- Sorteia a raridade de um ovo raro pelos pesos
function Sim.RollMutation(C: any, rng: () -> number): string
	local total = 0
	for _, mutation in C.Mutations do
		total += mutation.Weight
	end
	local roll = rng() * total
	for i = #C.Mutations, 1, -1 do
		roll -= C.Mutations[i].Weight
		if roll < 0 then
			return C.Mutations[i].Id
		end
	end
	return C.Mutations[1].Id
end

-- Põe um ovo raro num ninho livre. Devolve o ovo { Line, Slot, Mut } ou nil (sem ave ou ninhos cheios).
function Sim.SpawnRare(C: any, data: any, run: any, rng: () -> number, mut: string?): any?
	local best = Sim.BestLine(C, data)
	if best <= 0 or #run.Rare >= C.RareMax then
		return nil
	end
	-- metade das vezes na ave mais nova; o resto, em qualquer ave que ele tenha
	local line = best
	if rng() >= 0.5 then
		local owned = {}
		for index in C.Lines do
			if Sim.HasBird(C, data, index) then
				table.insert(owned, index)
			end
		end
		line = owned[math.clamp(math.floor(rng() * #owned) + 1, 1, #owned)]
	end
	local used = {}
	for _, egg in run.Rare do
		if egg.Line == line then
			used[egg.Slot] = true
		end
	end
	local free = {}
	for slot = 1, C.BirdsPerPen do
		if not used[slot] then
			table.insert(free, slot)
		end
	end
	if #free == 0 then
		return nil
	end
	local egg = { Line = line, Slot = free[math.clamp(math.floor(rng() * #free) + 1, 1, #free)], Mut = mut or Sim.RollMutation(C, rng) }
	table.insert(run.Rare, egg)
	return egg
end

-- Pega o ovo raro número i dos ninhos. Devolve a chave ("pata:s") ou nil (cesta cheia / não existe).
function Sim.PickRare(C: any, data: any, run: any, ctx: any, i: number): string?
	local egg = run.Rare[i]
	if not egg or Sim.BasketCount(data) >= Sim.BasketCap(C, data, ctx) then
		return nil
	end
	table.remove(run.Rare, i)
	local key = Sim.EggKey(C.Lines[egg.Line].Id, egg.Mut)
	data.Basket[key] = (data.Basket[key] or 0) + 1
	data.Stats.Mutants = (data.Stats.Mutants or 0) + 1
	Sim.Mission(data, "mutant", 1)
	return key
end

-- Quanto vale UM ovo raro vendido no balcão
function Sim.RareValue(C: any, data: any, ctx: any, key: string): number
	local lineId, mut = Sim.ParseKey(key)
	local line = C.LineById[lineId]
	local mutation = C.MutationById[mut]
	if not line or not mutation then
		return 0
	end
	-- ave melhor = ovo raro um pouco mais caro. NÃO multiplica pelo bônus de mão (HandMult): esse bônus é só
	-- do trabalho feito na mão (clique e tapete); senão o talento das mãos multiplicava os ovos raros por 8.
	return Sim.Reward(C, data, ctx, mutation.Seconds * (1 + 0.1 * (line.Index - 1)), 5)
end

function Sim.BasketValue(C: any, data: any, ctx: any): (number, number)
	local total, n = 0, 0
	for key, amount in data.Basket do
		total += amount * Sim.RareValue(C, data, ctx, key)
		n += amount
	end
	return total, n
end

-- Vende a cesta de ovos raros. Devolve valor, quantidade e a lista de figurinhas NOVAS do álbum.
function Sim.Sell(C: any, data: any, ctx: any): (number, number, { string })
	local value, n = Sim.BasketValue(C, data, ctx)
	local fresh = {}
	if n <= 0 then
		return 0, 0, fresh
	end
	for key, amount in data.Basket do
		if data.Album[key] == nil then
			table.insert(fresh, key)
		end
		data.Album[key] = (data.Album[key] or 0) + amount
	end
	table.sort(fresh)
	data.Basket = {}
	data.Stats.Sold = (data.Stats.Sold or 0) + n
	Sim.Mission(data, "sell", n)
	Sim.AddCoins(data, value, true)
	return value, n, fresh
end

-- ---------------------------------------------------------------------------
-- Produção (chamado a cada Config.TickSeconds)
-- Devolve: { Earned = moedas dos gerentes, Cycles = {[negócio] = ciclos feitos}, Tip = true se caiu gorjeta,
--            Rare = { ovos raros que apareceram agora }, Apples = true se nasceu maçã }
-- ---------------------------------------------------------------------------
function Sim.Tick(C: any, data: any, run: any, ctx: any, dt: number, rng: () -> number): any
	local out = { Earned = 0, Cycles = {}, Rare = {} }
	local cash = Sim.CashMult(C, data, ctx)
	local speed = Sim.SpeedMult(C, data, ctx)
	local managed = false
	for index in C.Businesses do
		local info = Sim.BizInfo(C, data, index)
		if info.Unlocked and info.Manager then
			managed = true
			local acc = (run.Acc[index] or 0) + dt / Sim.CycleTime(C, data, ctx, index, info, speed)
			local cycles = math.floor(acc)
			run.Acc[index] = acc - cycles
			if cycles > 0 then
				out.Cycles[index] = cycles
				out.Earned += cycles * Sim.Payout(C, data, ctx, index, info, cash)
			end
		else
			run.Acc[index] = nil
		end
	end
	if out.Earned > 0 then
		Sim.AddCoins(data, out.Earned, true)
	end
	-- gorjetas (só com pelo menos um gerente trabalhando)
	if managed then
		run.TipAcc = (run.TipAcc or 0) + dt
		if run.TipAcc >= C.TipEvery then
			run.TipAcc -= C.TipEvery
			if (run.Tips or 0) < C.TipMax then
				run.Tips = (run.Tips or 0) + 1
				out.Tip = true
			end
		end
	end
	-- ovos raros nos ninhos da Granja
	if data.Owned.granja_unlock then
		local every = if data.RareSeen then C.RareEvery else C.RareFirst
		-- (o clima, hoje só o arco-íris, faz este relógio andar mais rápido: Sim.WeatherRare)
		run.RareAcc = math.min(every, (run.RareAcc or 0) + dt * (if data.RareSeen then Sim.MutationChanceMult(C, data, ctx) else 1) * Sim.WeatherRare(C, ctx))
		if run.RareAcc >= every then
			local egg = Sim.SpawnRare(C, data, run, rng, if data.RareSeen then nil else C.Mutations[1].Id)
			if egg then
				run.RareAcc = 0
				data.RareSeen = true
				table.insert(out.Rare, egg)
			end
		end
	end
	-- macieira
	if data.Owned.G_tree then
		run.AppleAcc += dt
		while run.AppleAcc >= C.AppleEvery do
			run.AppleAcc -= C.AppleEvery
			if run.Apples < C.AppleMax then
				run.Apples += 1
				if rng() < C.GoldenAppleChance then
					run.Golden += 1
				end
				out.Apples = true
			end
		end
	end
	return out
end

-- Maçãs: devolve o prêmio (0 se não tinha)
function Sim.PickApples(C: any, data: any, run: any, ctx: any): (number, number, number)
	local apples, golden = run.Apples, run.Golden
	if apples <= 0 then
		return 0, 0, 0
	end
	local each = Sim.Reward(C, data, ctx, C.AppleSeconds, 5)
	local total = each * (apples - golden) + each * C.GoldenAppleMult * golden
	run.Apples, run.Golden = 0, 0
	Sim.AddCoins(data, total, true)
	return total, apples, golden
end

-- ---------------------------------------------------------------------------
-- SACO DE DINHEIRO (C.MoneyBag): surpresa que cai no terreno de tempos em tempos.
-- Estado no run: run.Bag (o saco no chão) e run.BagWait (segundos até o próximo). Nada é salvo: quem sai
-- do jogo com um saco no chão perde o saco (é bônus de quem está jogando), nunca moedas já ganhas.
-- Quem chama: Sim.BagTick a cada produção (devolve o que aconteceu) e Sim.TakeBag quando o dono encosta.
-- ---------------------------------------------------------------------------
local function between(range: { number }, rng: () -> number): number
	return range[1] + rng() * (range[2] - range[1])
end

-- Sorteia um lugar. spots = quantos lugares existem (número) OU a lista dos índices que valem agora.
-- last = o lugar usado da vez anterior: fica fora do sorteio se houver outro para escolher.
-- Devolve o índice do lugar, ou nil se não há nenhum. Pede UM número ao rng (só quando há lugar).
local function pickSpot(spots: any, last: number?, rng: () -> number): number?
	local list: { number } = {}
	if type(spots) == "table" then
		list = table.clone(spots)
	else
		for index = 1, math.floor(tonumber(spots) or 0) do
			list[index] = index
		end
	end
	if #list > 1 and last ~= nil then
		local at = table.find(list, last)
		if at then
			table.remove(list, at)
		end
	end
	if #list == 0 then
		return nil
	end
	return list[math.clamp(math.floor(rng() * #list) + 1, 1, #list)]
end

-- Só cai saco para quem já abriu a banca (antes disso o jogador ainda está aprendendo a comprar)
function Sim.BagOpen(C: any, data: any): boolean
	return C.MoneyBag ~= nil and data.Owned.banca_unlock == true
end

-- Segundos de jogo até o próximo saco. O 1º da vida (nunca pegou nenhum) vem mais cedo.
function Sim.BagDelay(C: any, data: any, rng: () -> number): number
	local B = C.MoneyBag
	local first = B.First ~= nil and (tonumber(data.Stats.Bags) or 0) <= 0
	return between(if first then B.First else B.Every, rng)
end

-- Põe um saco no chão AGORA (o BagTick chama quando o relógio zera; o teste do Studio chama direto).
-- spots = quantos lugares existem (número) OU a lista dos índices que valem agora (o servidor passa os que
-- estão a uma distância boa do dono). golden: true/false força; nil sorteia (1 em C.MoneyBag.GoldenEvery).
-- Devolve o saco { Id, Spot, Golden, Seconds, Left } ou nil (banca fechada, já tem saco ou não há lugar).
function Sim.DropBag(C: any, data: any, run: any, rng: () -> number, spots: any, golden: boolean?): any?
	if not Sim.BagOpen(C, data) or run.Bag ~= nil then
		return nil
	end
	local B = C.MoneyBag
	-- não repete o lugar do saco anterior (se tiver outro para escolher)
	local spot = pickSpot(spots, run.BagSpot, rng)
	if not spot then
		return nil
	end
	if golden == nil then
		golden = rng() < 1 / math.max(1, B.GoldenEvery)
	end
	run.BagSeq = (run.BagSeq or 0) + 1
	local bag = { Id = run.BagSeq, Spot = spot, Golden = golden == true, Seconds = between(B.Seconds, rng), Left = B.Life }
	run.Bag = bag
	run.BagSpot = spot
	run.BagWait = nil
	return bag
end

-- Um passo do relógio do saco (dt = segundos de jogo). Devolve o que aconteceu:
--   ("drop", saco) caiu um saco agora   |   ("gone", saco) o saco do chão sumiu sem ninguém pegar   |   nil
function Sim.BagTick(C: any, data: any, run: any, dt: number, rng: () -> number, spots: any): (string?, any?)
	local bag = run.Bag
	if not Sim.BagOpen(C, data) then
		run.Bag, run.BagWait = nil, nil
		if bag then
			return "gone", bag
		end
		return nil, nil
	end
	if bag then
		bag.Left -= dt
		if bag.Left <= 0 then
			run.Bag = nil
			return "gone", bag
		end
		return nil, nil
	end
	-- sem saco no chão: o relógio do próximo anda (só começa a contar depois que o anterior saiu)
	if run.BagWait == nil then
		run.BagWait = Sim.BagDelay(C, data, rng)
	end
	run.BagWait -= dt
	if run.BagWait > 0 then
		return nil, nil
	end
	local dropped = Sim.DropBag(C, data, run, rng, spots)
	if dropped then
		return "drop", dropped
	end
	run.BagWait = 0 -- não havia lugar agora: tenta de novo no próximo passo
	return nil, nil
end

-- Quanto o saco vale AGORA (segundos de renda do saco x renda de hoje; o dourado multiplica)
function Sim.BagValue(C: any, data: any, ctx: any, bag: any): number
	local B = C.MoneyBag
	local mult = if bag.Golden then B.GoldenMult else 1
	return Sim.Reward(C, data, ctx, bag.Seconds * mult, B.Min * mult)
end

-- O dono encostou no saco: paga e tira do chão. Devolve (moedas, saco) ou (0, nil) se não havia saco.
-- Conta como dinheiro GANHO (igual a gorjeta e maçã: é coisa que ele pegou jogando).
function Sim.TakeBag(C: any, data: any, run: any, ctx: any): (number, any?)
	local bag = run.Bag
	if not bag or not Sim.BagOpen(C, data) then
		return 0, nil
	end
	run.Bag = nil
	local amount = Sim.BagValue(C, data, ctx, bag)
	Sim.AddCoins(data, amount, true)
	data.Stats.Bags = (tonumber(data.Stats.Bags) or 0) + 1
	Sim.Mission(data, "bags", 1)
	return amount, bag
end

-- ---------------------------------------------------------------------------
-- CHAVES SECRETAS e BAÚ SECRETO (versão 5; C.Keys). De tempos em tempos uma chave nasce ESCONDIDA num
-- canto do terreno (Layout.KeySpots; sem facho de luz: é para procurar). Só o dono pega. Com Need chaves
-- ele abre o Baú Secreto do terreno: moedas + giros da roleta. Tudo grátis (nada aqui é vendido).
-- Salvo: data.Keys (chaves na mão), data.Stats.Keys / Chests. Sessão: run.Key ({ Id, Spot, Age }),
-- run.KeyWait, run.KeySeq, run.KeySpot. Quem chama: Sim.KeyTick a cada produção, Sim.TakeKey quando o
-- dono encosta na chave e Sim.OpenChest quando ele chega ao baú com as chaves.
-- Renascer e Selo: as chaves NA MÃO ficam (são do jogador, como os pets); a chave escondida no chão e o
-- relógio dela zeram junto com a granja (como o saco) e voltam quando ele reabrir MinBiz negócios.
-- ---------------------------------------------------------------------------
-- Chaves e baú só para quem já abriu MinBiz negócios (antes disso o terreno ainda é pequeno demais)
function Sim.KeysOpen(C: any, data: any): boolean
	return C.Keys ~= nil and Sim.BizCount(C, data) >= (C.Keys.MinBiz or 0)
end

-- Chaves na mão (sempre um inteiro de 0 a Need, mesmo se o save vier estranho)
function Sim.KeyCount(C: any, data: any): number
	if not C.Keys then
		return 0
	end
	local n = tonumber(data.Keys) or 0
	if n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, C.Keys.Need)
end

-- Segundos de jogo até a próxima chave. A 1ª da vida (nunca achou nenhuma) vem mais cedo.
function Sim.KeyDelay(C: any, data: any, rng: () -> number): number
	local K = C.Keys
	local first = K.First ~= nil and (tonumber(data.Stats.Keys) or 0) <= 0
	return between(if first then K.First else K.Every, rng)
end

-- Faz nascer uma chave AGORA (o KeyTick chama quando o relógio zera; o teste do Studio chama direto).
-- spots = quantos lugares existem (número) OU a lista dos índices que valem agora (o servidor tira os que
-- estão colados no dono). Devolve a chave { Id, Spot, Age } ou nil (ainda não liberou, já tem uma chave
-- escondida, já está com Need chaves na mão ou não há lugar).
function Sim.DropKey(C: any, data: any, run: any, rng: () -> number, spots: any): any?
	if not Sim.KeysOpen(C, data) or run.Key ~= nil or Sim.KeyCount(C, data) >= C.Keys.Need then
		return nil
	end
	-- nunca no mesmo lugar da anterior (se tiver outro para escolher)
	local spot = pickSpot(spots, run.KeySpot, rng)
	if not spot then
		return nil
	end
	run.KeySeq = (run.KeySeq or 0) + 1
	local key = { Id = run.KeySeq, Spot = spot, Age = 0 }
	run.Key = key
	run.KeySpot = spot
	run.KeyWait = nil
	return key
end

-- Um passo do relógio da chave (dt = segundos de jogo). Devolve ("drop", chave) quando nasce uma, ou nada.
-- O relógio só anda SEM chave escondida e com menos de Need chaves na mão; a chave não expira (Age só
-- conta há quanto tempo ela espera). Se as chaves "fecharam" com uma no chão (não acontece jogando: renascer
-- já limpa o run), ela some: ("gone", chave), para quem desenha poder apagar.
function Sim.KeyTick(C: any, data: any, run: any, dt: number, rng: () -> number, spots: any): (string?, any?)
	local key = run.Key
	if not Sim.KeysOpen(C, data) then
		run.Key, run.KeyWait = nil, nil
		if key then
			return "gone", key
		end
		return nil, nil
	end
	if key then
		key.Age = (key.Age or 0) + dt
		return nil, nil
	end
	if Sim.KeyCount(C, data) >= C.Keys.Need then
		return nil, nil -- mãos cheias: primeiro abre o baú
	end
	if run.KeyWait == nil then
		run.KeyWait = Sim.KeyDelay(C, data, rng)
	end
	run.KeyWait -= dt
	if run.KeyWait > 0 then
		return nil, nil
	end
	local dropped = Sim.DropKey(C, data, run, rng, spots)
	if dropped then
		return "drop", dropped
	end
	run.KeyWait = 0 -- não havia lugar agora: tenta de novo no próximo passo
	return nil, nil
end

-- O dono encostou na chave escondida: ela vai para a mão. Devolve (quantas chaves ele tem agora, a chave
-- que pegou) ou (quantas tem, nil) se não havia chave para pegar.
function Sim.TakeKey(C: any, data: any, run: any): (number, any?)
	local key = run.Key
	if not key or not Sim.KeysOpen(C, data) then
		return Sim.KeyCount(C, data), nil
	end
	run.Key = nil
	run.KeyWait = nil -- o relógio da próxima recomeça agora (se ainda couber chave na mão)
	data.Keys = math.min(C.Keys.Need, Sim.KeyCount(C, data) + 1)
	data.Stats.Keys = (tonumber(data.Stats.Keys) or 0) + 1
	return data.Keys, key
end

function Sim.CanOpenChest(C: any, data: any): boolean
	return Sim.KeysOpen(C, data) and Sim.KeyCount(C, data) >= C.Keys.Need
end

-- Abre o Baú Secreto: gasta Need chaves e paga. Devolve { Coins, Golden, Spins } ou nil (faltam chaves).
-- Moedas = Sim.Reward de Seconds segundos de renda (sorteado entre os dois números), no mínimo Min; o
-- baú de número múltiplo de GoldenEvery (o 5º, o 10º... da vida) é DOURADO: GoldenMult vezes os segundos e
-- o mínimo. Não há sorteio de "dourado ou não": todo mundo ganha o dourado na mesma conta.
-- Conta como dinheiro GANHO (estrelas, placar, missão "earn"), como o saco de dinheiro.
function Sim.OpenChest(C: any, data: any, ctx: any, rng: () -> number): any?
	if not Sim.CanOpenChest(C, data) then
		return nil
	end
	local K = C.Keys
	local chest = K.Chest
	data.Keys = Sim.KeyCount(C, data) - K.Need
	local number = (tonumber(data.Stats.Chests) or 0) + 1
	data.Stats.Chests = number
	local golden = (chest.GoldenEvery or 0) > 0 and number % chest.GoldenEvery == 0
	local mult = if golden then chest.GoldenMult or 1 else 1
	local coins = Sim.Reward(C, data, ctx, between(chest.Seconds, rng) * mult, (chest.Min or 0) * mult)
	Sim.AddCoins(data, coins, true)
	-- o giro da roleta vem só no baú dourado (GoldenSpins): com giro em todo baú o jogo inteiro andava 30% mais rápido
	local spins = if golden then chest.GoldenSpins or chest.Spins or 0 else chest.Spins or 0
	if spins > 0 then
		Sim.AddSpins(C, data, spins)
	end
	return { Coins = coins, Golden = golden, Spins = spins }
end

-- ---------------------------------------------------------------------------
-- PODERES (versão 5; C.Powers). Botões que o jogador aperta quando quiser; cada um recarrega sozinho.
-- Salvo: data.Powers[id] = os.time() em que fica pronto de novo; data.PowerOn[id] = os.time() em que o
-- efeito acaba (só poder com Duration); data.Stats.Powers. O que cada um faz sai dos CAMPOS do Config:
--   Duration + Speed  todos os negócios Speed vezes mais rápidos por Duration segundos ("galo")
--   Seconds (+ Min)   paga na hora Seconds segundos de renda ("moedas")
--   Mut               põe um ovo raro dessa raridade num ninho livre ("sorte")
-- Renascer e Selo: as recargas continuam correndo (são tempo de relógio); o poder fica TRANCADO enquanto
-- o jogador não reabrir MinBiz negócios (liberado = Sim.BizCount de agora) e o efeito ligado acaba.
-- ---------------------------------------------------------------------------
-- O efeito do poder (com duração) está ligado agora?
function Sim.PowerActive(C: any, data: any, ctx: any, id: string): boolean
	if not C.PowerById or not C.PowerById[id] or type(data.PowerOn) ~= "table" then
		return false
	end
	return (tonumber(data.PowerOn[id]) or 0) > ((ctx and ctx.Now) or 0)
end

-- Como está o poder: { Unlocked = liberado?, Ready = dá para usar agora?, ReadyAt = os.time() em que fica
-- pronto (0 = nunca usou), Until = os.time() em que o efeito acaba (0 = sem efeito) }. nil = id que não existe.
function Sim.PowerInfo(C: any, data: any, ctx: any, id: string): any?
	local def = C.PowerById and C.PowerById[id]
	if not def then
		return nil
	end
	local now = (ctx and ctx.Now) or 0
	local readyAt = tonumber(type(data.Powers) == "table" and data.Powers[id]) or 0
	local ends = tonumber(type(data.PowerOn) == "table" and data.PowerOn[id]) or 0
	local unlocked = Sim.BizCount(C, data) >= (def.MinBiz or 0)
	return { Unlocked = unlocked, Ready = unlocked and readyAt <= now, ReadyAt = readyAt, Until = ends }
end

-- Ovo raro num ninho livre de QUALQUER ave do jogador. (O Sim.SpawnRare sorteia a ave primeiro e desiste
-- se os ninhos dela estiverem cheios; para o poder, "tem ninho livre?" precisa olhar a granja toda.)
local function rareAnywhere(C: any, data: any, run: any, rng: () -> number, mut: string?): any?
	local egg = Sim.SpawnRare(C, data, run, rng, mut)
	if egg or #run.Rare >= C.RareMax then
		return egg
	end
	for index = #C.Lines, 1, -1 do
		if Sim.HasBird(C, data, index) then
			local used = {}
			for _, other in run.Rare do
				if other.Line == index then
					used[other.Slot] = true
				end
			end
			for slot = 1, C.BirdsPerPen do
				if not used[slot] then
					egg = { Line = index, Slot = slot, Mut = mut or Sim.RollMutation(C, rng) }
					table.insert(run.Rare, egg)
					return egg
				end
			end
		end
	end
	return nil
end

-- Usa um poder. Devolve o resultado { Id, Seconds = duração do efeito, Until, Coins = moedas pagas,
-- Rare = o ovo raro { Line, Slot, Mut } } (só os campos do que o poder faz), ou (nil, motivo):
--   "locked" ainda não abriu MinBiz negócios | "wait" recarregando | "nonest" sem ninho livre (o poder
--   NÃO é gasto: pode tentar de novo) | "unknown" id que não existe ou contexto sem hora.
-- As moedas contam como dinheiro GANHO (o jogador fez por merecer: esperou a recarga jogando).
function Sim.UsePower(C: any, data: any, run: any, ctx: any, id: string, rng: () -> number): (any?, string?)
	local def = C.PowerById and C.PowerById[id]
	local now = ctx and ctx.Now
	if not def or type(now) ~= "number" or now ~= now or now == math.huge then
		return nil, "unknown"
	end
	local info = Sim.PowerInfo(C, data, ctx, id)
	if not info.Unlocked then
		return nil, "locked"
	end
	if not info.Ready then
		return nil, "wait"
	end
	local out: any = { Id = id }
	-- primeiro o que pode falhar (nada foi gasto ainda)
	if def.Mut then
		local egg = rareAnywhere(C, data, run, rng, if C.MutationById[def.Mut] then def.Mut else nil)
		if not egg then
			return nil, "nonest"
		end
		out.Rare = egg
	end
	if type(data.Powers) ~= "table" then
		data.Powers = {}
	end
	if type(data.PowerOn) ~= "table" then
		data.PowerOn = {}
	end
	if def.Duration then
		data.PowerOn[id] = now + def.Duration
		out.Seconds = def.Duration
		out.Until = data.PowerOn[id]
	end
	if def.Seconds then
		out.Coins = Sim.Reward(C, data, ctx, def.Seconds, def.Min)
		Sim.AddCoins(data, out.Coins, true)
	end
	data.Powers[id] = now + (def.Cooldown or 0)
	data.Stats.Powers = (tonumber(data.Stats.Powers) or 0) + 1
	return out, nil
end

-- Produto "Recarga" (Kind "refill"): faz sentido comprar agora?
--   "ok" = tem poder liberado recarregando | "ready" = os liberados já estão todos prontos (comprar seria
--   jogar Robux fora) | "locked" = nenhum poder liberado ainda
function Sim.RefillState(C: any, data: any, ctx: any): string
	local unlocked, waiting = 0, 0
	for _, def in C.Powers or {} do
		local info = Sim.PowerInfo(C, data, ctx, def.Id)
		if info and info.Unlocked then
			unlocked += 1
			if not info.Ready then
				waiting += 1
			end
		end
	end
	if unlocked == 0 then
		return "locked"
	end
	return if waiting > 0 then "ok" else "ready"
end

-- ---------------------------------------------------------------------------
-- Botões do tycoon
-- ---------------------------------------------------------------------------
-- "owned" | "available" (aparece no chão) | "hidden"
function Sim.ButtonState(C: any, data: any, id: string): string
	local button = C.ButtonById[id]
	if not button then
		return "hidden"
	end
	if data.Owned[id] then
		return "owned"
	end
	if button.Requires and not data.Owned[button.Requires] then
		return "hidden"
	end
	return "available"
end

function Sim.AvailableButtons(C: any, data: any): { any }
	local list = {}
	for _, button in C.Buttons do
		if Sim.ButtonState(C, data, button.Id) == "available" then
			table.insert(list, button)
		end
	end
	return list
end

-- O botão disponível mais barato (a seta de ajuda aponta para ele)
function Sim.NextButton(C: any, data: any): any?
	local best = nil
	for _, button in C.Buttons do
		if Sim.ButtonState(C, data, button.Id) == "available" and (best == nil or button.Cost < best.Cost) then
			best = button
		end
	end
	return best
end

function Sim.Buy(C: any, data: any, id: string): (boolean, string?)
	local state = Sim.ButtonState(C, data, id)
	if state ~= "available" then
		return false, state
	end
	local button = C.ButtonById[id]
	if data.Coins < button.Cost then
		return false, "coins"
	end
	data.Coins -= button.Cost
	data.Owned[id] = true
	data.Stats.Buttons += 1
	Sim.Mission(data, "buy", 1)
	-- ave nova: figurinha "normal" dela no álbum
	local line = if id == "granja_unlock" then C.Lines[1] elseif button.Kind == "bird" then C.Lines[button.Line] else nil
	if line and data.Album[line.Id] == nil then
		data.Album[line.Id] = 1
	end
	return true, nil
end

-- ---------------------------------------------------------------------------
-- Renascer e Selos
-- ---------------------------------------------------------------------------
-- Estrelas que o jogador ganharia se renascesse agora.
-- Regra (igual aos "anjos" dos jogos incrementais clássicos): o TOTAL de estrelas depende de tudo que ele
-- já ganhou desde o último Selo: total = StarK * (SealEarned / StarBase) ^ StarPow. Renascer entrega a
-- diferença. Por isso não adianta renascer toda hora: só rende quando a granja foi mais longe.
function Sim.StarsFor(C: any, data: any): number
	local total = math.floor(C.StarK * ((tonumber(data.SealEarned) or 0) / C.StarBase) ^ C.StarPow)
	return math.max(0, total - (tonumber(data.StarsEarned) or 0))
end

function Sim.CanRebirth(C: any, data: any): boolean
	return Sim.StarsFor(C, data) >= C.RebirthMinStars
end

local function resetRun(data: any, run: any)
	data.Coins = 0
	data.RunEarned = 0
	data.Owned = {}
	-- a cesta de ovos raros fica (o jogador ainda pode vender ou chocar)
	run.Acc = {}
	run.Work = {}
	run.Ground = {}
	run.Tips, run.TipAcc = 0, 0
	run.Rare = {}
	run.RareAcc = 0
	run.Apples, run.AppleAcc, run.Golden = 0, 0, 0
	-- o saco de dinheiro some junto com a banca (e o relógio do próximo recomeça quando ela reabrir)
	run.Bag, run.BagWait = nil, nil
	-- chave secreta: a que estava ESCONDIDA no chão e o relógio dela zeram com a granja (voltam quando ele
	-- reabrir os negócios); as chaves na mão (data.Keys) e a conta de baús ficam: são do jogador
	run.Key, run.KeyWait = nil, nil
	-- poderes: as recargas (data.Powers) continuam correndo; o efeito que estava ligado acaba aqui (o
	-- poder fica trancado até ele reabrir os negócios: trancado e "ligado" ao mesmo tempo confundiria a tela)
	data.PowerOn = {}
end

function Sim.Rebirth(C: any, data: any, run: any): (boolean, number)
	local gain = Sim.StarsFor(C, data)
	if gain < C.RebirthMinStars then
		return false, 0
	end
	resetRun(data, run)
	data.StarsEarned += gain
	data.Stars += gain
	data.StarsTotal += gain
	data.Rebirths += 1
	return true, gain
end

function Sim.NextSeal(C: any, data: any): any?
	return C.Seals[(tonumber(data.Seal) or 0) + 1]
end

function Sim.CanEvolve(C: any, data: any): boolean
	local seal = Sim.NextSeal(C, data)
	return seal ~= nil and data.StarsTotal >= seal.Stars
end

function Sim.Evolve(C: any, data: any, run: any): boolean
	if not Sim.CanEvolve(C, data) then
		return false
	end
	resetRun(data, run)
	data.SealEarned = 0
	data.StarsEarned = 0
	data.Stars = 0
	data.StarsTotal = 0
	data.Talents = {}
	data.Seal += 1
	return true
end

-- ---------------------------------------------------------------------------
-- Renda offline
-- ---------------------------------------------------------------------------
function Sim.OfflineCap(C: any, data: any): number
	local cap = C.OfflineCap
	for _, button in C.Buttons do
		if button.OfflineHours and data.Owned[button.Id] then
			cap = math.max(cap, button.OfflineHours * 3600)
		end
	end
	return cap
end

function Sim.Offline(C: any, data: any, ctx: any, now: number): number
	local last = tonumber(data.LastSeen) or 0
	if last <= 0 then
		return 0
	end
	local away = math.clamp(now - last, 0, Sim.OfflineCap(C, data))
	if away < C.OfflineMin then
		return 0
	end
	local auto = Sim.Income(C, data, Sim.BaseCtx(ctx))
	local amount = math.floor(auto * away * C.OfflineRate * (if Sim.HasPass(data, ctx, "Offline2x") then 2 else 1))
	if amount <= 0 then
		return 0
	end
	data.OfflinePending = (tonumber(data.OfflinePending) or 0) + amount
	data.OfflineSeconds = away
	return amount
end

function Sim.ClaimOffline(data: any): number
	local amount = tonumber(data.OfflinePending) or 0
	if amount <= 0 then
		return 0
	end
	data.OfflinePending = 0
	data.OfflineSeconds = 0
	Sim.AddCoins(data, amount, true)
	return amount
end

-- ---------------------------------------------------------------------------
-- Missões diárias, sequência de dias e códigos
-- ---------------------------------------------------------------------------
function Sim.DayKey(now: number): number
	return math.floor(now / 86400)
end

-- Sempre as mesmas missões para o mesmo dia (sorteio com a semente do dia)
function Sim.MakeMissions(C: any, data: any, ctx: any, day: number): { any }
	local seed = (day * 7919 + 17) % 2147483647
	local function nextInt(lo: number, hi: number): number
		seed = (seed * 48271) % 2147483647
		return lo + seed % (hi - lo + 1)
	end
	local pool = table.clone(C.Missions)
	local list = {}
	for _ = 1, math.min(C.DailyMissionCount, #pool) do
		local mission = table.remove(pool, nextInt(1, #pool))
		local target = mission.Base
		if mission.Id == "earn" then
			target = Sim.Reward(C, data, ctx, 600, 500)
		end
		table.insert(list, { Id = mission.Id, Target = target, Progress = 0, Claimed = false })
	end
	return list
end

function Sim.CheckDaily(C: any, data: any, ctx: any, now: number): boolean
	local today = Sim.DayKey(now)
	if data.Daily.Day ~= today then
		data.Daily = { Day = today, List = Sim.MakeMissions(C, data, ctx, today) }
		return true
	end
	return false
end

function Sim.ClaimMission(C: any, data: any, ctx: any, index: number): number
	local mission = data.Daily.List[index]
	if not mission or mission.Claimed or mission.Progress < mission.Target then
		return 0
	end
	mission.Claimed = true
	local reward = Sim.Reward(C, data, ctx, C.MissionSeconds, C.MissionMin)
	Sim.AddCoins(data, reward, false)
	return reward
end

function Sim.ClaimGift(C: any, data: any, ctx: any): number
	if data.GiftSeconds < C.GiftInterval then
		return 0
	end
	data.GiftSeconds = 0
	local reward = Sim.Reward(C, data, ctx, C.GiftSeconds, C.GiftMin)
	Sim.AddCoins(data, reward, false)
	return reward
end

-- Sequência: devolve (podePegar, diaDaSequência que vai pegar)
function Sim.StreakState(data: any, now: number): (boolean, number)
	local today = Sim.DayKey(now)
	local streak = data.Streak
	if streak.Day == today then
		return false, math.max(1, streak.Count)
	end
	if streak.Day == today - 1 then
		return true, streak.Count + 1
	end
	return true, 1
end

function Sim.ClaimStreak(C: any, data: any, ctx: any, now: number): (number, number, number)
	local can, day = Sim.StreakState(data, now)
	if not can then
		return 0, 0, 0
	end
	local slot = math.min(day, #C.StreakSeconds)
	local coins = Sim.Reward(C, data, ctx, C.StreakSeconds[slot], 100 * slot)
	local stars = C.StreakStars[slot] or 0
	data.Streak = { Day = Sim.DayKey(now), Count = day }
	Sim.AddCoins(data, coins, false)
	if stars > 0 then
		data.Stars += stars
		data.StarsTotal += stars
	end
	return coins, stars, day
end

function Sim.RedeemCode(C: any, data: any, ctx: any, text: string): (boolean, number, number)
	local code = string.upper(string.gsub(text, "%s", ""))
	local def = C.Codes[code]
	if not def or data.Codes[code] then
		return false, 0, 0
	end
	data.Codes[code] = true
	local coins = Sim.Reward(C, data, ctx, def.Seconds or 0, def.Min or 0)
	local stars = def.Stars or 0
	Sim.AddCoins(data, coins, false)
	if stars > 0 then
		data.Stars += stars
		data.StarsTotal += stars
	end
	if def.Spins then
		Sim.AddSpins(C, data, def.Spins)
	end
	return true, coins, stars
end

-- Caça aos ovos: devolve (novo, quantos já achou)
function Sim.FindHunt(C: any, data: any, index: number, total: number): (boolean, number)
	local key = tostring(index)
	data.HuntTotal = total
	if data.Hunt[key] then
		return false, Sim.HuntCount(data)
	end
	data.Hunt[key] = true
	data.Stars += C.HuntStars
	data.StarsTotal += C.HuntStars
	return true, Sim.HuntCount(data)
end

-- ---------------------------------------------------------------------------
-- Pets e chocadeiras
-- ---------------------------------------------------------------------------
function Sim.PetLevel(C: any, data: any, key: string): number
	return math.clamp(tonumber(data.Pets[key]) or 0, 0, C.Pets.MaxLevel)
end

-- Bônus de UM pet no nível dado (0.1 = +10% de renda)
function Sim.PetBonus(C: any, key: string, level: number): number
	local lineId, mut = Sim.ParseKey(key)
	local base = 0
	local special = C.SpecialPets[lineId]
	if special then
		base = special.Bonus
	else
		local line = C.LineById[lineId]
		if not line then
			return 0
		end
		base = (C.Pets.LineBonus[line.Index] or 0) * (C.Pets.RarityMult[mut] or 0)
	end
	return base * (1 + C.Pets.LevelBonus * (math.max(level, 1) - 1))
end

function Sim.PetCount(data: any): number
	return count(data.Pets)
end

function Sim.PetSlots(C: any, data: any, ctx: any): number
	local slots = C.Pets.Slots
	local distinct = count(data.Pets)
	for _, need in C.Pets.SlotAt do
		if distinct >= need then
			slots += 1
		end
	end
	if Sim.HasPass(data, ctx, "MaisPets") then
		slots += C.PassPetSlots
	end
	return slots
end

-- Quantos pets diferentes faltam para a próxima vaga (nil = não tem mais)
function Sim.NextPetSlotAt(C: any, data: any): number?
	local distinct = count(data.Pets)
	for _, need in C.Pets.SlotAt do
		if distinct < need then
			return need
		end
	end
	return nil
end

function Sim.PetMult(C: any, data: any, ctx: any): number
	local equip = data.Equip
	if not equip then
		return 1
	end
	local slots = Sim.PetSlots(C, data, ctx)
	local total = 0
	for i, key in equip do
		if i > slots then
			break
		end
		local level = Sim.PetLevel(C, data, key)
		if level > 0 then
			total += Sim.PetBonus(C, key, level)
		end
	end
	return 1 + total
end

local function isEquipped(data: any, key: string): number?
	return table.find(data.Equip, key)
end

function Sim.EquipPet(C: any, data: any, ctx: any, key: string): boolean
	if (tonumber(data.Pets[key]) or 0) <= 0 or isEquipped(data, key) then
		return false
	end
	if #data.Equip >= Sim.PetSlots(C, data, ctx) then
		return false
	end
	table.insert(data.Equip, key)
	return true
end

function Sim.UnequipPet(data: any, key: string): boolean
	local at = isEquipped(data, key)
	if not at then
		return false
	end
	table.remove(data.Equip, at)
	return true
end

-- Equipa os melhores pets que cabem nas vagas
function Sim.EquipBest(C: any, data: any, ctx: any)
	local list = {}
	for key in data.Pets do
		table.insert(list, { Key = key, Bonus = Sim.PetBonus(C, key, Sim.PetLevel(C, data, key)) })
	end
	table.sort(list, function(a, b)
		if a.Bonus ~= b.Bonus then
			return a.Bonus > b.Bonus
		end
		return a.Key < b.Key
	end)
	local equip = {}
	for i = 1, math.min(#list, Sim.PetSlots(C, data, ctx)) do
		equip[i] = list[i].Key
	end
	data.Equip = equip
end

-- Ganha um pet (repetido sobe de nível). Devolve (novo?, nível). Equipa sozinho se tiver vaga.
function Sim.AddPet(C: any, data: any, ctx: any, key: string): (boolean, number)
	local before = tonumber(data.Pets[key]) or 0
	data.Pets[key] = before + 1
	if before == 0 then
		Sim.EquipPet(C, data, ctx, key)
	end
	return before == 0, Sim.PetLevel(C, data, key)
end

function Sim.HatchSlots(C: any, data: any): number
	local n = 0
	for _, def in C.GlobalButtons do
		if def.Hatch and data.Owned["G_" .. def.Kind] then
			n += def.Hatch
		end
	end
	return n
end

-- O ovo raro mais valioso da cesta (nil se não tiver nenhum)
function Sim.BestMutantInBasket(C: any, data: any): string?
	local best, bestScore = nil, -1
	for key, amount in data.Basket do
		if amount > 0 then
			local lineId, mut = Sim.ParseKey(key)
			local line = C.LineById[lineId]
			local mutation = C.MutationById[mut]
			if line and mutation then
				local score = Sim.PetBonus(C, key, 1) * 1000 + line.Index
				if score > bestScore then
					best, bestScore = key, score
				end
			end
		end
	end
	return best
end

function Sim.FreeHatchSlot(C: any, data: any): string?
	for i = 1, Sim.HatchSlots(C, data) do
		local slot = tostring(i)
		if data.Hatch[slot] == nil then
			return slot
		end
	end
	return nil
end

-- Põe o melhor ovo raro da cesta numa chocadeira livre. Devolve (vaga, chave, segundos) ou nil.
function Sim.StartHatch(C: any, data: any, now: number): (string?, string?, number?)
	local slot = Sim.FreeHatchSlot(C, data)
	if not slot then
		return nil, nil, nil
	end
	local key = Sim.BestMutantInBasket(C, data)
	if not key then
		return nil, nil, nil
	end
	local _, mut = Sim.ParseKey(key)
	local seconds = C.HatchTime[mut] or 60
	if count(data.Pets) == 0 and count(data.Hatch) == 0 then
		seconds = math.min(seconds, C.FirstHatchTime)
	end
	local left = data.Basket[key] - 1
	data.Basket[key] = if left > 0 then left else nil
	data.Hatch[slot] = { Key = key, Ready = now + seconds }
	return slot, key, seconds
end

-- Pega um pet que já nasceu. Devolve (vaga, chave, novo?, nível) ou nil.
function Sim.ClaimHatch(C: any, data: any, ctx: any, now: number): (string?, string?, boolean?, number?)
	for i = 1, 3 do
		local slot = tostring(i)
		local hatch = data.Hatch[slot]
		if hatch and now >= (tonumber(hatch.Ready) or 0) then
			data.Hatch[slot] = nil
			local fresh, level = Sim.AddPet(C, data, ctx, hatch.Key)
			data.Stats.Hatched = (data.Stats.Hatched or 0) + 1
			Sim.Mission(data, "hatch", 1)
			return slot, hatch.Key, fresh, level
		end
	end
	return nil, nil, nil, nil
end

-- ---------------------------------------------------------------------------
-- Roleta, obby e Ovo Gigante
-- ---------------------------------------------------------------------------
function Sim.AddSpins(C: any, data: any, n: number)
	data.Spins = math.min(C.Wheel.MaxBanked, (tonumber(data.Spins) or 0) + n)
end

-- Devolve (giros disponíveis agora, segundos até o próximo giro grátis)
function Sim.SpinState(C: any, data: any, now: number): (number, number)
	local wait = math.max(0, (tonumber(data.SpinAt) or 0) - now)
	return (tonumber(data.Spins) or 0) + (if wait <= 0 then 1 else 0), wait
end

-- Gira a roleta. Devolve (índice do prêmio, valor para mostrar) ou nil se não tem giro.
function Sim.Spin(C: any, data: any, ctx: any, now: number, rng: () -> number): (number?, any)
	if now >= (tonumber(data.SpinAt) or 0) then
		data.SpinAt = now + C.Wheel.FreeEvery
	elseif (tonumber(data.Spins) or 0) > 0 then
		data.Spins -= 1
	else
		return nil, nil
	end
	local total = 0
	for _, prize in C.Wheel.Prizes do
		total += prize.Weight
	end
	local roll = rng() * total
	local index = #C.Wheel.Prizes
	for i, prize in C.Wheel.Prizes do
		roll -= prize.Weight
		if roll < 0 then
			index = i
			break
		end
	end
	local prize = C.Wheel.Prizes[index]
	local shown: any = 0
	if prize.Seconds then
		shown = Sim.Reward(C, data, ctx, prize.Seconds, prize.Min)
		Sim.AddCoins(data, shown, false)
	elseif prize.Stars then
		shown = prize.Stars
		data.Stars += prize.Stars
		data.StarsTotal += prize.Stars
	elseif prize.Boost then
		shown = prize.BoostSeconds
		data.Boosts[prize.Boost] = math.max(now, tonumber(data.Boosts[prize.Boost]) or 0) + prize.BoostSeconds
	elseif prize.Egg then
		local line = C.Lines[math.max(1, Sim.BestLine(C, data))]
		shown = Sim.EggKey(line.Id, prize.Egg)
		data.Basket[shown] = (data.Basket[shown] or 0) + 1
	end
	data.Stats.Spun = (data.Stats.Spun or 0) + 1
	return index, shown
end

-- Chegou ao baú do obby. Devolve as moedas (0 = ainda em espera).
function Sim.ClaimObby(C: any, data: any, ctx: any, now: number): number
	if now < (tonumber(data.ObbyAt) or 0) then
		return 0
	end
	data.ObbyAt = now + C.Obby.Cooldown
	local coins = Sim.Reward(C, data, ctx, C.Obby.Seconds, C.Obby.Min)
	Sim.AddCoins(data, coins, false)
	Sim.AddSpins(C, data, C.Obby.Spins)
	data.Stats.Obby = (data.Stats.Obby or 0) + 1
	return coins
end

function Sim.GiantVariant(C: any, now: number): string
	local list = C.Giant.Variants
	return list[math.floor(now / 604800) % #list + 1]
end

-- O Ovo Gigante rachou: prêmio de um jogador. Devolve (moedas, chave do pet ou nil).
function Sim.GiantReward(C: any, data: any, ctx: any, near: boolean, variant: string, rng: () -> number): (number, string?)
	local G = C.Giant
	local coins = Sim.Reward(C, data, ctx, G.Seconds * (if near then G.NearBonus else 1), G.Min)
	Sim.AddCoins(data, coins, false)
	data.Stats.Giant = (data.Stats.Giant or 0) + 1
	local petKey = nil
	if near then
		Sim.AddSpins(C, data, 1)
		data.GiantPity = (tonumber(data.GiantPity) or 0) + 1
		if rng() < G.PetChance or data.GiantPity >= G.Pity then
			data.GiantPity = 0
			petKey = "ovinho:" .. variant
			Sim.AddPet(C, data, ctx, petKey)
		end
	end
	return coins, petKey
end

-- ---------------------------------------------------------------------------
-- LOJA EM ROBUX: regras puras dos passes e produtos (o servidor só chama e desenha; ver Server/Store.lua).
-- Nada aqui fala com o Roblox: quem confere a compra é o Store; aqui é só "o que o jogador recebe".
-- ---------------------------------------------------------------------------
-- Produto de compra única (Once) que este jogador já comprou?
function Sim.ProductBought(data: any, key: string): boolean
	return data.Bought ~= nil and data.Bought[key] == true
end

-- A loja pode oferecer este produto a este jogador? (Id 0 = desligado; compra única já feita = não)
-- C e ctx são opcionais: com o C, a "Recarga" de poderes só é oferecida a quem já liberou algum poder
-- (se os liberados estão todos prontos quem recusa a compra é o Store, com Sim.RefillState).
function Sim.CanOfferProduct(data: any, product: any, C: any?, ctx: any?): boolean
	if not product or (tonumber(product.Id) or 0) <= 0 then
		return false
	end
	if product.Kind == "refill" and C then
		return Sim.RefillState(C, data, ctx) ~= "locked"
	end
	return not (product.Once and Sim.ProductBought(data, product.Key))
end

-- Entrega um produto pago. Devolve o que foi dado: { Coins, Boost, BoostSeconds, Egg = chave do ovo, Again,
-- Refill = quantos poderes estavam recarregando (só no Kind "refill") }.
-- Again = true: era de compra única e o jogador já tinha (o Roblox cobrou de novo mesmo assim): em vez
-- de perder a compra, ele recebe AgainSeconds de renda em moedas.
-- Moedas de produto não contam como "ganhas" (não viram Estrelas nem sobem no placar): quem paga anda
-- mais rápido no próprio jogo, mas não passa na frente de ninguém.
function Sim.DeliverProduct(C: any, data: any, ctx: any, product: any, now: number): any
	local out: any = { Coins = 0 }
	if type(data.Bought) ~= "table" then
		data.Bought = {}
	end
	if product.Once then
		if data.Bought[product.Key] then
			out.Again = true
			out.Coins = Sim.Reward(C, data, ctx, product.AgainSeconds or product.Seconds or 0, product.Min)
			Sim.AddCoins(data, out.Coins, false)
			return out
		end
		data.Bought[product.Key] = true
	end
	-- "refill": todos os poderes prontos na hora (zera as recargas; não mexe em efeito ligado)
	if product.Kind == "refill" then
		local waiting = 0
		if type(data.Powers) == "table" then
			for _, readyAt in data.Powers do
				if (tonumber(readyAt) or 0) > now then
					waiting += 1
				end
			end
		end
		data.Powers = {}
		out.Refill = waiting
		-- não havia nada recarregando (a janela de compra ficou aberta até as recargas acabarem, por
		-- exemplo): a compra não se perde, vira o pagamento FIXO do poder de moedas. Como toda moeda de
		-- produto, não conta como "ganha".
		if waiting == 0 then
			for _, def in C.Powers or {} do
				if def.Seconds then
					out.Coins = Sim.Reward(C, data, ctx, def.Seconds, def.Min)
					Sim.AddCoins(data, out.Coins, false)
					break
				end
			end
		end
		return out
	end
	-- "hatch": a chocadeira com mais tempo faltando termina agora. Nada chocando: vira moedas (não perde a compra)
	if product.Kind == "hatch" then
		local best, left = nil, 0
		for slot, hatch in data.Hatch or {} do
			local remaining = (tonumber(hatch.Ready) or 0) - now
			if remaining > left then
				best, left = slot, remaining
			end
		end
		if best then
			data.Hatch[best].Ready = now
			out.Hatched = best
		else
			out.Coins = Sim.Reward(C, data, ctx, product.Seconds or 0, product.Min)
			Sim.AddCoins(data, out.Coins, false)
		end
		return out
	end
	-- moedas: "skip" e "pack" (no "boost", Seconds é a duração do efeito)
	if product.Kind ~= "boost" and (product.Seconds or 0) > 0 then
		out.Coins = Sim.Reward(C, data, ctx, product.Seconds, product.Min)
		Sim.AddCoins(data, out.Coins, false)
	end
	if product.Boost then
		local seconds = if product.Kind == "boost" then product.Seconds else product.BoostSeconds
		if (seconds or 0) > 0 then
			data.Boosts[product.Boost] = math.max(now, tonumber(data.Boosts[product.Boost]) or 0) + seconds
			out.Boost, out.BoostSeconds = product.Boost, seconds
		end
	end
	-- ovo raro (raridade fixa, nada de sorteio) da melhor ave: vai direto para a cesta, mesmo cheia
	if product.Egg and C.MutationById[product.Egg] then
		local line = C.Lines[math.max(1, Sim.BestLine(C, data))]
		out.Egg = Sim.EggKey(line.Id, product.Egg)
		data.Basket[out.Egg] = (data.Basket[out.Egg] or 0) + 1
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Conquistas (v6)
-- ---------------------------------------------------------------------------
function Sim.AchievementValue(data: any, def: any): number
	if def.Stat == "Rebirths" or def.Stat == "Likes" then
		return tonumber(data[def.Stat]) or 0
	end
	return tonumber(type(data.Stats) == "table" and data.Stats[def.Stat]) or 0
end

-- Devolve (degraus pegos, meta do próximo ou nil, estrelas do próximo, valor atual)
function Sim.AchievementInfo(data: any, def: any): (number, number?, number, number)
	local done = math.clamp(math.floor(tonumber(type(data.Achieved) == "table" and data.Achieved[def.Id]) or 0), 0, #def.Goals)
	return done, def.Goals[done + 1], def.Stars[done + 1] or 0, Sim.AchievementValue(data, def)
end

-- Pega o próximo degrau de uma conquista. Devolve as estrelas ganhas (0 = ainda não dá).
function Sim.ClaimAchievement(C: any, data: any, id: string): number
	local def = nil
	for _, d in C.Achievements do
		if d.Id == id then
			def = d
		end
	end
	if not def then
		return 0
	end
	local done, goal, stars, value = Sim.AchievementInfo(data, def)
	if not goal or value < goal then
		return 0
	end
	if type(data.Achieved) ~= "table" then
		data.Achieved = {}
	end
	data.Achieved[id] = done + 1
	data.Stars += stars
	data.StarsTotal += stars
	return stars
end

-- Passe VIP: uma vez por dia dá o giro extra da roleta. Com ctx.NoRandom (lugar onde o Roblox restringe
-- prêmio sorteado ligado a compra) ou DailySpins = 0, dá um presente FIXO em moedas no lugar.
-- Devolve ("spins", n) | ("coins", moedas) | (nil, 0) se não tem o passe ou já ganhou hoje.
function Sim.VipDaily(C: any, data: any, ctx: any, now: number): (string?, number)
	if not C.VIP or not Sim.HasPass(data, ctx, "VIP") then
		return nil, 0
	end
	local today = Sim.DayKey(now)
	if (tonumber(data.VipDay) or 0) >= today then
		return nil, 0
	end
	data.VipDay = today
	local spins = C.VIP.DailySpins or 0
	if spins > 0 and not (ctx and ctx.NoRandom) then
		Sim.AddSpins(C, data, spins)
		return "spins", spins
	end
	local coins = Sim.Reward(C, data, ctx, C.VIP.DailySeconds, C.VIP.DailyMin)
	Sim.AddCoins(data, coins, false)
	return "coins", coins
end

-- O jogador ganhou um passe (comprou agora, ou o Roblox avisou ao entrar que ele tem). Guarda no save e
-- faz o que só acontece na PRIMEIRA vez. Devolve { New, OfflineDoubled = moedas a mais, Vip, VipAmount }.
function Sim.GrantPass(C: any, data: any, ctx: any, key: string, now: number): any
	local out: any = { New = not Sim.HasPass(data, nil, key) }
	data.Passes[key] = true
	if not out.New then
		return out
	end
	-- a janela de renda offline oferece este passe: quem compra ali dobra também o que está esperando
	if key == "Offline2x" then
		local pending = tonumber(data.OfflinePending) or 0
		if pending > 0 then
			data.OfflinePending = pending * 2
			out.OfflineDoubled = pending
		end
	elseif key == "VIP" then
		out.Vip, out.VipAmount = Sim.VipDaily(C, data, ctx, now)
	end
	return out
end

-- Passe SuperClique: quantos cliques automáticos na banca o servidor credita agora (dt = segundos desde
-- a última chamada). Só chame com o jogador perto da banca; longe dela, zere run.AutoAcc.
function Sim.AutoClicks(C: any, data: any, run: any, ctx: any, dt: number): number
	if not C.SuperClick or not Sim.HasPass(data, ctx, "SuperClique") or not Sim.BizInfo(C, data, 1).Unlocked then
		run.AutoAcc = 0
		return 0
	end
	local acc = (run.AutoAcc or 0) + math.max(0, dt) * C.SuperClick.PerSecond
	local n = math.floor(acc + 1e-9)
	-- nunca "desconta o atraso" com uma rajada: no máximo 1 segundo de cliques de uma vez
	run.AutoAcc = math.min(acc - n, 1)
	return math.min(n, C.SuperClick.PerSecond)
end

-- Passe Ima (Coletor Automático): recolhe TUDO que está no terreno: moedas do chão de todos os negócios,
-- gorjetas e os ovos raros dos ninhos (enquanto couber na cesta). Sem o passe não faz nada (devolve nil).
-- Devolve nil se não havia nada, ou { Coins, Ground = {[negócio] = moedas}, Tips = n, TipCoins,
-- Eggs = { { Line, Slot, Key } }, Full = sobrou ovo raro porque a cesta encheu }.
function Sim.AutoCollect(C: any, data: any, run: any, ctx: any): any?
	if not Sim.HasPass(data, ctx, "Ima") then
		return nil
	end
	local out: any = { Coins = 0, Ground = {}, Tips = 0, TipCoins = 0, Eggs = {}, Full = false }
	for index in C.Businesses do
		local amount = Sim.CollectGround(C, data, run, index)
		if amount > 0 then
			out.Ground[index] = amount
			out.Coins += amount
		end
	end
	out.TipCoins, out.Tips = Sim.CollectTips(C, data, run, ctx)
	out.Coins += out.TipCoins
	for i = #run.Rare, 1, -1 do
		local egg = run.Rare[i]
		local key = Sim.PickRare(C, data, run, ctx, i)
		if key then
			table.insert(out.Eggs, { Line = egg.Line, Slot = egg.Slot, Key = key })
		else
			out.Full = true
		end
	end
	if out.Coins <= 0 and #out.Eggs == 0 then
		return nil
	end
	return out
end

return Sim
