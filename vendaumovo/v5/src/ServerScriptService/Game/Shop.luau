--[[
	Shop: tudo que o jogador PEDE pela tela (o cliente só pede; o servidor confere e faz):
	renascer, selo, talentos, missões, presente, sequência de dias, códigos, renda offline,
	curtir granja, teleporte e configurações.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Sim = require(ReplicatedStorage.Shared.Sim)
local Registry = require(script.Parent.Registry)

local Shop = {}

local function notify(player: Player, key: string, args: any?, kind: string?)
	Registry.Remotes.NotifyPlayer(player, key, args, kind)
end

local function fx(player: Player, kind: string, value: any, extra: any)
	Registry.Remotes.Fx:FireClient(player, kind, nil, value, extra)
end

local function rebirth(player: Player)
	local data = Registry.Game.Data(player)
	local plot = Registry.Plots.Of(player)
	if not data or not plot then
		return
	end
	-- As moedas que ainda estão no chão também contam para as Estrelas. Confere com elas na conta e só
	-- então junta tudo (se não der para renascer, o chão fica como está: nada de pegar moeda de longe).
	local probe = { SealEarned = data.SealEarned + Sim.GroundTotal(plot.Run), StarsEarned = data.StarsEarned }
	if not Sim.CanRebirth(Config, probe) then
		notify(player, "n.rebirthNotYet", nil, "error")
		return
	end
	Registry.Farm.Sweep(player)
	local ok, gain = Sim.Rebirth(Config, data, plot.Run)
	if not ok then
		notify(player, "n.rebirthNotYet", nil, "error")
		return
	end
	Registry.Plots.Reset(plot)
	Registry.Game.ApplySpeed(player)
	Registry.Game.Push(player)
	fx(player, "rebirth", gain, data.Rebirths)
	Registry.Bonus.Badge(player, "Renasceu")
	Registry.Bonus.RefreshTitle(player)
	Registry.Remotes.NotifyAll("n.rebirth", { player = player.DisplayName, n = data.Rebirths }, "event")
	task.spawn(Registry.Data.Save, player) -- renascer é importante: salva já
end

local function evolve(player: Player)
	local data = Registry.Game.Data(player)
	local plot = Registry.Plots.Of(player)
	if not data or not plot then
		return
	end
	if not Sim.CanEvolve(Config, data) then
		notify(player, "n.sealNotYet", nil, "error")
		return
	end
	-- o Selo zera a granja: o que estava no chão entra antes no total ganho (placar)
	Registry.Farm.Sweep(player)
	if not Sim.Evolve(Config, data, plot.Run) then
		notify(player, "n.sealNotYet", nil, "error")
		return
	end
	Registry.Plots.Reset(plot)
	Registry.Game.ApplySpeed(player)
	Registry.Game.Push(player)
	local seal = Config.Seals[data.Seal]
	fx(player, "seal", data.Seal, seal and seal.Id)
	Registry.Bonus.Badge(player, "Selo")
	Registry.Bonus.RefreshTitle(player)
	Registry.Remotes.NotifyAll("n.seal", { player = player.DisplayName, seal = seal and seal.Id or "" }, "event")
	task.spawn(Registry.Data.Save, player)
end

local function buyTalent(player: Player, id: any)
	local data = Registry.Game.Data(player)
	if not data or type(id) ~= "string" or not Config.TalentById[id] then
		return
	end
	local ok, reason = Sim.BuyTalent(Config, data, id)
	if not ok then
		notify(player, if reason == "max" then "n.talentMax" else "n.noStars", nil, "error")
		return
	end
	Registry.Game.ApplySpeed(player)
	Registry.Game.Push(player)
	fx(player, "sound", "Comprar")
	notify(player, "n.talentUp", { talent = id, level = data.Talents[id] }, "success")
end

local function claimMission(player: Player, index: any)
	local data = Registry.Game.Data(player)
	if not data or type(index) ~= "number" then
		return
	end
	local ctx = Registry.Game.Ctx(player)
	Sim.CheckDaily(Config, data, ctx, os.time())
	local reward = Sim.ClaimMission(Config, data, ctx, index)
	if reward > 0 then
		fx(player, "reward", reward, "mission")
		Registry.Game.Push(player)
	end
end

local function claimGift(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local reward = Sim.ClaimGift(Config, data, Registry.Game.Ctx(player))
	if reward > 0 then
		fx(player, "reward", reward, "gift")
		Registry.Game.Push(player)
	end
end

local function claimStreak(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local coins, stars, day = Sim.ClaimStreak(Config, data, Registry.Game.Ctx(player), os.time())
	if day > 0 then
		fx(player, "reward", coins, "streak")
		if stars > 0 then
			notify(player, "n.starsGain", { n = stars }, "success")
		end
		Registry.Game.Push(player)
	end
end

local function redeemCode(player: Player, text: any)
	local data = Registry.Game.Data(player)
	if not data or type(text) ~= "string" or #text > 40 then
		return
	end
	local ok, coins, stars = Sim.RedeemCode(Config, data, Registry.Game.Ctx(player), text)
	if not ok then
		notify(player, "n.codeBad", nil, "error")
		return
	end
	fx(player, "reward", coins, "code")
	if stars > 0 then
		notify(player, "n.starsGain", { n = stars }, "success")
	end
	Registry.Game.Push(player)
end

local function claimOffline(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local amount = Sim.ClaimOffline(data)
	if amount > 0 then
		fx(player, "reward", amount, "offline")
		Registry.Game.Push(player)
	end
end

-- Curtir a granja de outro jogador (uma vez por dono por servidor).
-- v6: guardado por quem curtiu x dono (antes era por granja e zerava quando o dono saía e voltava:
-- dava para curtir de novo e ganhar o prêmio de novo)
local likedOwners: { [number]: { [number]: boolean } } = {}

function Shop.Like(player: Player, plot: any)
	local owner = plot.Owner
	if not owner or owner == player or plot.LikedBy[player.UserId] then
		return
	end
	local mine = likedOwners[player.UserId]
	if not mine then
		mine = {}
		likedOwners[player.UserId] = mine
	end
	if mine[owner.UserId] then
		return
	end
	local ownerData = Registry.Game.Data(owner)
	if not ownerData or not Registry.Game.Data(player) then
		return
	end
	plot.LikedBy[player.UserId] = true
	mine[owner.UserId] = true
	ownerData.Likes += 1
	Registry.Plots.RefreshSign(plot)
	local reward = Registry.Game.Reward(player, Config.LikeSeconds, 10, false)
	fx(player, "reward", reward, "like")
	notify(owner, "n.liked", { player = player.DisplayName }, "success")
	Registry.Game.Push(owner)
end

-- v6: conquistas
local function claimAchievement(player: Player, id: any)
	local data = Registry.Game.Data(player)
	if not data or type(id) ~= "string" or #id > 30 then
		return
	end
	local stars = Sim.ClaimAchievement(Config, data, id)
	if stars > 0 then
		Registry.Game.ApplySpeed(player)
		Registry.Game.Push(player)
		fx(player, "sound", "Premio")
		notify(player, "n.achievement", { n = stars }, "success")
	end
end

local function teleport(player: Player, where: any)
	local character = player.Character
	local root = Registry.Plots.RootOf(player)
	if not character or not root then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Sit then
		humanoid.Sit = false -- desce do trator antes de teleportar
		task.wait(0.15)
	end
	Registry.Guard.Grace(player, 3) -- teleporte do próprio jogo
	if where == "plaza" then
		local s = Layout.PlazaSpawn
		character:PivotTo(CFrame.new(s[1], 5, s[2]))
	else
		local plot = Registry.Plots.Of(player)
		if plot then
			character:PivotTo(Registry.Plots.SpawnCFrame(plot))
		end
	end
end

-- Pets: equipar, tirar, equipar os melhores
local function equipPet(player: Player, key: any)
	local data = Registry.Game.Data(player)
	if not data or type(key) ~= "string" or #key > 40 then
		return
	end
	if Sim.EquipPet(Config, data, Registry.Game.Ctx(player), key) then
		Registry.Game.Push(player)
	else
		notify(player, "n.petFull", nil, "error")
	end
end

local function unequipPet(player: Player, key: any)
	local data = Registry.Game.Data(player)
	if not data or type(key) ~= "string" or #key > 40 then
		return
	end
	if Sim.UnequipPet(data, key) then
		Registry.Game.Push(player)
	end
end

local function equipBest(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	Sim.EquipBest(Config, data, Registry.Game.Ctx(player))
	Registry.Game.Push(player)
end

-- Roleta: o servidor sorteia; a tela só gira até o prêmio que veio
local function spin(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local index, shown = Sim.Spin(Config, data, Registry.Game.Ctx(player), os.time(), math.random)
	if not index then
		notify(player, "n.noSpins", nil, "error")
		return
	end
	fx(player, "spin", index, shown)
	Registry.Game.Push(player)
end

local ALLOWED_SETTINGS = { Lang = "string", Music = "boolean", Sfx = "boolean", Arrow = "boolean", Light = "boolean", Tutorial = "number" }

local function setSetting(player: Player, key: any, value: any)
	local data = Registry.Game.Data(player)
	if not data or type(key) ~= "string" or ALLOWED_SETTINGS[key] ~= type(value) then
		return
	end
	if key == "Lang" and value ~= "pt" and value ~= "en" then
		return
	end
	-- v6: número tem que ser inteiro e pequeno (NaN ou infinito quebrava o save do próprio jogador)
	if type(value) == "number" and (value ~= value or math.abs(value) > 1e6 or value % 1 ~= 0) then
		return
	end
	data.Settings[key] = value
end

function Shop.Init()
	local on = Registry.Remotes.On
	on("Rebirth", rebirth)
	on("Evolve", evolve)
	on("BuyTalent", buyTalent)
	on("ClaimMission", claimMission)
	on("ClaimGift", claimGift)
	on("ClaimStreak", claimStreak)
	on("RedeemCode", redeemCode)
	on("ClaimOffline", claimOffline)
	on("Teleport", teleport)
	on("EquipPet", equipPet)
	on("UnequipPet", unequipPet)
	on("EquipBest", equipBest)
	on("Spin", spin)
	on("ClaimAchievement", claimAchievement)
	on("FavoriteAsked", function(player: Player)
		local data = Registry.Game.Data(player)
		if data then
			data.FavoriteAsked = true
		end
	end, 5)
	on("LikeAsked", function(player: Player)
		local data = Registry.Game.Data(player)
		if data then
			data.LikeAsked = true
		end
	end, 5)
	on("Setting", setSetting)
	on("Refresh", function(player: Player)
		Registry.Game.Push(player)
	end, 2) -- v6: no máximo a cada 2 s (o estado inteiro é pesado de montar e enviar)

	-- relógio do servidor: tempo do presente e virada do dia das missões
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(1)
			ticks += 1
			for _, player in Players:GetPlayers() do
				local data = Registry.Game.Data(player)
				if data then
					local before = data.GiftSeconds
					data.GiftSeconds = math.min(Config.GiftInterval, data.GiftSeconds + 1)
					if before < Config.GiftInterval and data.GiftSeconds >= Config.GiftInterval then
						notify(player, "n.giftReady", nil, "event")
						Registry.Game.Push(player)
					end
					if ticks % 30 == 0 and Sim.CheckDaily(Config, data, Registry.Game.Ctx(player), os.time()) then
						Registry.Game.Push(player)
					end
				end
			end
		end
	end)
end

return Shop
