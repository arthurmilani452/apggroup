--[[
	Codes (ModuleScript em ServerScriptService > Game)
	Códigos promocionais. Ficam SÓ no servidor: nenhum jogador consegue ler esta lista.
	Cada jogador usa cada código uma vez. Maiúsculas e espaços não importam ("hatch it" = HATCHIT).

	Tipos de recompensa (pode juntar vários no mesmo código):
	  Cash = 5000          -> dinheiro fixo
	  Minutes = 10         -> 10 minutos da SUA renda (mínimo $200 por minuto): vale para novato e para veterano
	  WorldEgg = 1         -> ovo(s) normal(is) do mundo mais novo que você destravou (Meadow: Spotted Egg)
	  BigEgg = 1           -> ovo(s) grande(s) desse mundo (Meadow: Crystal Egg)
	  Boost = 15           -> 2x Cash por 15 minutos (soma tempo, até 3 horas)
	  Egg = "crystal"      -> um ovo específico
	  Critter = "blobby"   -> um bichinho específico (use para as criaturas de youtuber); Mutation = "Gold" opcional
	  Starts = os.time()   -> só funciona depois dessa data (opcional)
	  Expires = os.time()  -> para de funcionar nessa data (opcional; o plano de divulgação usa códigos sem fim)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Codes = {}

Codes.List = {
	-- os primeiros
	RELEASE = { Cash = 5_000 },
	SNEAKY = { Egg = "spotted" },

	-- Plano de divulgação: 1 código em cada Short
	HATCHIT = { Minutes = 10 },
	STEALIT = { WorldEgg = 1 },
	KEEPIT = { Boost = 15 },
	SECRET = { Minutes = 15 },
	MYTHIC = { WorldEgg = 1 },
	LASER = { Boost = 10 },
	COSMIC = { BigEgg = 1 },
	EGGRAIN = { WorldEgg = 3 },
	RAINBOW = { Minutes = 20 },
	CANDY = { WorldEgg = 1 },
	FROSTY = { Boost = 15 },
	LAVA = { Minutes = 20 },
	REEF = { WorldEgg = 1 },
	GALAXY = { BigEgg = 1 },
	REVENGE = { Boost = 15 },
	REBIRTH = { Minutes = 30 },
	RACCOON = { WorldEgg = 1 },
	BONK = { Boost = 20 },
	THANKYOU1K = { BigEgg = 1, Minutes = 30 },
	SPOOKY = { WorldEgg = 3 },

	-- Criatura de youtuber (exemplo): troque o nome e o Id quando fizer a parceria
	-- CREATORNAME = { Critter = "blobby", Mutation = "Gold" },
}

local lastTry: { [Player]: number } = {}

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

-- Mundo mais novo que o jogador destravou
local function newestWorld(player: Player): string
	local newest = "meadow"
	for _, world in Config.Worlds do
		if Registry.Worlds.IsUnlocked(player, world.Id) then
			newest = world.Id
		end
	end
	return newest
end

local function giftEgg(player: Player, big: boolean): string?
	local pair = Config.GiftEggs[newestWorld(player)] or Config.GiftEggs.meadow
	local eggId = pair[if big then 2 else 1]
	return if Config.EggById[eggId] then eggId else nil
end

-- Normaliza o que o jogador digitou: "hatch it" -> "HATCHIT"
function Codes.Normalize(raw: string): string
	return string.upper((string.gsub(raw, "%s+", "")))
end

-- 2x Cash por alguns minutos (soma com o que já tinha, até o máximo)
function Codes.AddBoost(player: Player, minutes: number)
	local data = getData(player)
	if not data then
		return
	end
	local now = os.time()
	local current = math.max(tonumber(data.BoostUntil) or 0, now)
	data.BoostUntil = math.min(current + minutes * 60, now + Config.BoostMaxMinutes * 60)
	player:SetAttribute("BoostUntil", data.BoostUntil)
	Registry.Economy.Sync(player)
end

function Codes.IsBoosted(player: Player): boolean
	local data = getData(player)
	return data ~= nil and (tonumber(data.BoostUntil) or 0) > os.time()
end

-- Dá a recompensa e devolve o texto do que o jogador ganhou (usado também pelo passe da temporada)
function Codes.Grant(player: Player, reward): { string }
	local Economy = Registry.Economy
	local CritterService = Registry.CritterService
	local parts = {}
	if type(reward.Cash) == "number" and reward.Cash > 0 then
		Economy.AddCash(player, reward.Cash, false, "Code")
		table.insert(parts, Format.Money(reward.Cash))
	end
	if type(reward.Minutes) == "number" and reward.Minutes > 0 then
		local amount = math.floor(math.max(Economy.GetIncome(player) * 60 * reward.Minutes, reward.Minutes * 200))
		Economy.AddCash(player, amount, false, "Code")
		table.insert(parts, Format.Money(amount))
	end
	for _, kind in { "WorldEgg", "BigEgg" } do
		local count = reward[kind]
		if type(count) == "number" and count > 0 then
			local eggId = giftEgg(player, kind == "BigEgg")
			if eggId then
				for _ = 1, math.min(count, 5) do
					CritterService.GrantEgg(player, eggId)
				end
				table.insert(parts, ("%s%s"):format(if count > 1 then count .. "x " else "a FREE ", Config.EggById[eggId].Name))
			end
		end
	end
	if type(reward.Egg) == "string" and Config.EggById[reward.Egg] then
		CritterService.GrantEgg(player, reward.Egg)
		table.insert(parts, "a FREE " .. Config.EggById[reward.Egg].Name)
	end
	if type(reward.Critter) == "string" and Critters.ById[reward.Critter] then
		local mutation = if type(reward.Mutation) == "string" and Config.MutationByName[reward.Mutation] then reward.Mutation else nil
		CritterService.GrantCritter(player, reward.Critter, mutation)
		table.insert(parts, (if mutation then mutation .. " " else "") .. Critters.ById[reward.Critter].Name)
	end
	if type(reward.Boost) == "number" and reward.Boost > 0 then
		Codes.AddBoost(player, reward.Boost)
		table.insert(parts, ("2x Cash for %d min"):format(reward.Boost))
	end
	if type(reward.Cosmetic) == "string" then
		-- "trail:season_sweet", "title:...", "decor:..." -> fica para sempre na tela STYLE
		local data = getData(player)
		if data and type(data.Style) == "table" and type(data.Style.Owned) == "table" then
			data.Style.Owned[reward.Cosmetic] = true
			table.insert(parts, "a new " .. string.split(reward.Cosmetic, ":")[1] .. " (see STYLE)")
		end
	end
	return parts
end

function Codes.Redeem(player: Player, raw: any)
	local data = getData(player)
	local Remotes = Registry.Remotes
	if not data or typeof(raw) ~= "string" or #raw > 30 then
		return
	end
	local t = os.clock()
	if t - (lastTry[player] or 0) < 2 then
		Remotes.Notify(player, "Wait a moment before trying another code.", "warning")
		return
	end
	lastTry[player] = t
	local code = Codes.Normalize(raw)
	local reward = Codes.List[code]
	local now = os.time()
	if not reward or (reward.Expires and now > reward.Expires) or (reward.Starts and now < reward.Starts) then
		Remotes.Notify(player, "Invalid or expired code.", "error")
		return
	end
	if data.Codes[code] then
		Remotes.Notify(player, "You already used this code!", "warning")
		return
	end
	data.Codes[code] = true
	local parts = Codes.Grant(player, reward)
	Remotes.Notify(player, "Code " .. code .. " redeemed: " .. table.concat(parts, " + ") .. "!", "rare")
	Remotes.Effect(player, "Purchase", "Legendary")
	local analytics = Registry.Analytics
	if analytics then
		pcall(analytics.Event, player, "Code_" .. code)
	end
end

function Codes.RemovePlayer(player: Player)
	lastTry[player] = nil
end

return Codes
