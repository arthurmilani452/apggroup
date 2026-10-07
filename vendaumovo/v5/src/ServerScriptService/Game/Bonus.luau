--[[
	Bonus (v6): prêmios por tempo jogado nesta visita e emblemas (badges) do Roblox.
	Prêmio por tempo: Config.PlayRewards em escada (5, 10, 20, 35 e 60 min). O relógio é do servidor:
	o atributo PlayStart guarda a hora em que o jogador entrou (workspace:GetServerTimeNow) e PlayClaimed
	quantos degraus já pegou. A tela só mostra a contagem; quem confere o tempo é o servidor.
	Emblemas: Config.Badges (Id = 0 fica desligado). Dar emblema nunca trava o jogo (pcall).
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Bonus = {}

local given: { [Player]: { [string]: boolean } } = {}

function Bonus.Badge(player: Player, key: string)
	local id = tonumber((Config.Badges or {})[key]) or 0
	if id <= 0 or not player.Parent then
		return
	end
	local mine = given[player]
	if not mine then
		mine = {}
		given[player] = mine
	end
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and not has then
			local awarded, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
			if not awarded then
				mine[key] = nil -- tenta de novo na próxima vez
				warn("[Bonus] emblema falhou:", key, err)
			end
		end
	end)
end

local function claimPlay(player: Player)
	local data = Registry.Game.Data(player)
	local start = player:GetAttribute("PlayStart")
	if not data or type(start) ~= "number" then
		return
	end
	local index = (tonumber(player:GetAttribute("PlayClaimed")) or 0) + 1
	local step = Config.PlayRewards[index]
	if not step then
		return
	end
	if workspace:GetServerTimeNow() - start < step.Minutes * 60 - 1 then
		Registry.Remotes.NotifyPlayer(player, "n.playNotYet", nil, "error")
		return
	end
	player:SetAttribute("PlayClaimed", index)
	local reward = Registry.Game.Reward(player, step.Seconds, step.Min, false)
	if step.Turbo then
		local now = os.time()
		data.Boosts.Turbo = math.max(now, tonumber(data.Boosts.Turbo) or 0) + step.Turbo
		Registry.Remotes.NotifyPlayer(player, "n.playTurbo", { n = math.floor(step.Turbo / 60) }, "success")
		Registry.Game.Push(player)
	end
	Registry.Remotes.Fx:FireClient(player, "reward", nil, reward, "play")
end

function Bonus.Init()
	local function joined(player: Player)
		player:SetAttribute("PlayStart", workspace:GetServerTimeNow())
		player:SetAttribute("PlayClaimed", 0)
		Bonus.Badge(player, "Bemvindo")
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player)
		given[player] = nil
	end)
	Registry.Remotes.On("ClaimPlay", claimPlay, 1)
end

return Bonus
