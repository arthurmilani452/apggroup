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
	local gui = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not title then
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
	label.Text = ("%s · %d"):format(title.Text, data.Rebirths)
	label.TextColor3 = if seal then seal.Color else Color3.fromRGB(255, 250, 230)
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
	Registry.Remotes.On("ClaimPlay", claimPlay, 1)
	Registry.Remotes.On("ClaimGroupChest", claimGroupChest, 2)
end

return Bonus
