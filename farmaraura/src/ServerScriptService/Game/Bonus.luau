--[[
	Bonus (v6): prêmios por tempo jogado nesta visita e emblemas (badges) do Roblox.
	Prêmio por tempo: Config.PlayRewards em escada (5, 10, 20, 35 e 60 min). O relógio é do servidor:
	o atributo PlayStart guarda a hora em que o jogador entrou (workspace:GetServerTimeNow) e PlayClaimed
	quantos degraus já pegou. A tela só mostra a contagem; quem confere o tempo é o servidor.
	Emblemas: Config.Badges (Id = 0 fica desligado). Dar emblema nunca trava o jogo (pcall).
	Título em cima da cabeça: Config.Titles, pelo número de renascimentos (criado no servidor: todos veem).
	Baú do grupo: Config.GroupChest, de graça para quem está no grupo, uma vez a cada Every segundos (salvo).
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sim = require(ReplicatedStorage.Shared.Sim)
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

-- Título em cima da cabeça. Fica acima da etiqueta do VIP quando ela existe.
function Bonus.RefreshTitle(player: Player)
	local data = Registry.Game.Data(player)
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not data or not head then
		return
	end
	local title = nil
	for _, def in Config.Titles do
		if (tonumber(data.Rebirths) or 0) >= def.Rebirths then
			title = def
		end
	end
	local richest = player:GetAttribute("Richest") == true
	local gui = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not title and not richest then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "TitleTag"
		newGui.Size = UDim2.fromScale(5, 0.85)
		newGui.MaxDistance = 90
		newGui.LightInfluence = 0
		newGui.Adornee = head
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeColor3 = Color3.fromRGB(70, 38, 15)
		label.TextStrokeTransparency = 0
		label.Parent = newGui
		newGui.Parent = head
		gui = newGui
	end
	local tag = gui :: BillboardGui
	tag.StudsOffsetWorldSpace = Vector3.new(0, if player:GetAttribute("VIP") then 4.15 else 3.2, 0)
	local seal = Config.Seals[tonumber(data.Seal) or 0]
	local label = tag:FindFirstChild("Text") :: TextLabel
	local text = if title then ("%s · %d"):format(title.Text, data.Rebirths) else "Mais rico do servidor"
	label.Text = if richest then "💰 " .. text else text
	label.TextColor3 = if richest then Color3.fromRGB(255, 215, 60) elseif seal then seal.Color else Color3.fromRGB(255, 250, 230)
end

local function claimGroupChest(player: Player)
	local data = Registry.Game.Data(player)
	if not data or not Registry.Game.Ctx(player).Group then
		return
	end
	local now = os.time()
	local last = tonumber(data.GroupChestAt) or 0
	if now - last < Config.GroupChest.Every then
		Registry.Remotes.NotifyPlayer(player, "n.groupChestWait", nil, "error")
		return
	end
	data.GroupChestAt = now
	local reward = Registry.Game.Reward(player, Config.GroupChest.Seconds, Config.GroupChest.Min, false)
	Registry.Remotes.Fx:FireClient(player, "reward", nil, reward, "group")
end

-- Pega TODAS as caixas de tempo que já abriram (quem volta depois de 30 min pega 5 de uma vez)
local function claimPlay(player: Player)
	local data = Registry.Game.Data(player)
	local start = player:GetAttribute("PlayStart")
	if not data or type(start) ~= "number" then
		return
	end
	local played = workspace:GetServerTimeNow() - start
	local claimed = tonumber(player:GetAttribute("PlayClaimed")) or 0
	local coins, spins, turbo = 0, 0, 0
	while true do
		local step = Config.PlayRewards[claimed + 1]
		if not step or played < step.Minutes * 60 - 1 then
			break
		end
		claimed += 1
		coins += Registry.Game.Reward(player, step.Seconds, step.Min, false)
		spins += step.Spins or 0
		turbo += step.Turbo or 0
	end
	if claimed == (tonumber(player:GetAttribute("PlayClaimed")) or 0) then
		Registry.Remotes.NotifyPlayer(player, "n.playNotYet", nil, "error")
		return
	end
	player:SetAttribute("PlayClaimed", claimed)
	local rolls = 0
	for i = (tonumber(player:GetAttribute("PlayClaimed")) or 0) + 1, claimed do
		rolls += Config.PlayRewards[i].Rolls or 0
	end
	if rolls > 0 then
		Sim.AddAuraRolls(Config, data, rolls)
		Registry.Remotes.NotifyPlayer(player, "play.rolls", { n = rolls }, "success")
	end
	if spins > 0 then
		Sim.AddSpins(Config, data, spins)
		Registry.Remotes.NotifyPlayer(player, "n.playSpins", { n = spins }, "success")
	end
	if turbo > 0 then
		local now = os.time()
		data.Boosts.Turbo = math.max(now, tonumber(data.Boosts.Turbo) or 0) + turbo
		Registry.Remotes.NotifyPlayer(player, "n.playTurbo", { n = math.floor(turbo / 60) }, "success")
	end
	Registry.Game.Push(player)
	Registry.Remotes.Fx:FireClient(player, "reward", nil, coins, "play")
end

function Bonus.Init()
	local function joined(player: Player)
		player:SetAttribute("PlayStart", workspace:GetServerTimeNow())
		player:SetAttribute("PlayClaimed", 0)
		Bonus.Badge(player, "Bemvindo")
		-- título: a cada personagem novo (espera o save carregar) e quando o VIP muda de lugar
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			for _ = 1, 30 do
				if Registry.Game.Data(player) then
					break
				end
				task.wait(1)
			end
			Bonus.RefreshTitle(player)
		end)
		player:GetAttributeChangedSignal("VIP"):Connect(function()
			Bonus.RefreshTitle(player)
		end)
		if player.Character then
			task.spawn(Bonus.RefreshTitle, player)
		end
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player)
		given[player] = nil
	end)
	-- v6: o jogador com a maior renda por segundo do servidor ganha o 💰 no título (com 2+ jogadores)
	task.spawn(function()
		while true do
			task.wait(15)
			local best, bestIncome = nil, 0
			local players = Players:GetPlayers()
			if #players >= 2 then
				for _, player in players do
					local data = Registry.Game.Data(player)
					if data then
						local ok, income = pcall(Sim.Income, Config, data, Registry.Game.Ctx(player))
						if ok and income > bestIncome then
							best, bestIncome = player, income
						end
					end
				end
			end
			for _, player in players do
				local richest = player == best
				if (player:GetAttribute("Richest") == true) ~= richest then
					player:SetAttribute("Richest", richest)
					Bonus.RefreshTitle(player)
				end
			end
		end
	end)
	Registry.Remotes.On("ClaimPlay", claimPlay, 1)
	Registry.Remotes.On("ClaimGroupChest", claimGroupChest, 2)
end

return Bonus
