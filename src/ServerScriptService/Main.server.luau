--[[
	STEAL A CRITTER - script principal do servidor.
	(Script chamado "Main" em ServerScriptService)
	Liga todos os módulos da pasta "Game" e cuida da entrada/saída dos jogadores.
	Pra ajustar o jogo, mexa em ReplicatedStorage > Shared > Config (e Critters).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameFolder = script.Parent:WaitForChild("Game")
local Registry = require(GameFolder.Registry)

Registry.Remotes = require(GameFolder.Remotes)
Registry.Policy = require(GameFolder.Policy)
Registry.Data = require(GameFolder.Data)
Registry.Plots = require(GameFolder.Plots)
Registry.CritterService = require(GameFolder.CritterService)
Registry.Economy = require(GameFolder.Economy)
Registry.Combat = require(GameFolder.Combat)
Registry.Admin = require(GameFolder.Admin)
Registry.Events = require(GameFolder.Events)
Registry.Leaderboards = require(GameFolder.Leaderboards)
Registry.Products = require(GameFolder.Products)
Registry.Tutorial = require(GameFolder.Tutorial)
Registry.Analytics = require(GameFolder.Analytics)
Registry.Worlds = require(GameFolder.Worlds)
Registry.Scenery = require(GameFolder.Scenery)
Registry.Fairness = require(GameFolder.Fairness)
Registry.Codes = require(GameFolder.Codes)
Registry.Pets = require(GameFolder.Pets)
Registry.Customize = require(GameFolder.Customize)
Registry.Season = require(GameFolder.Season)
Registry.Environment = require(GameFolder.Environment)
Registry.Discoveries = require(GameFolder.Discoveries)
Registry.GiantEgg = require(GameFolder.GiantEgg)
Registry.Progress = require(GameFolder.Progress)
Registry.Social = require(GameFolder.Social)
Registry.LiveEvents = require(GameFolder.LiveEvents)
Registry.Battle = require(GameFolder.Battle)
Registry.Minigames = require(GameFolder.Minigames)
Registry.Explore = require(GameFolder.Explore)
Registry.Mounts = require(GameFolder.Mounts)
Registry.Retention = require(GameFolder.Retention) -- v23: presentes de tempo de jogo + roleta diária
Registry.WorldFun = require(GameFolder.WorldFun) -- v27: brincadeiras dos mundos (baús e bolas de neve)
Registry.NPCService = require(GameFolder.NPCService)
Registry.Bandits = require(GameFolder.Bandits) -- v24: ladrão NPC quando o servidor está vazio

-- v15: modelos 3D importados que ficaram soltos no Workspace vão para ReplicatedStorage > Models3D
do
	local moved = require(game:GetService("ReplicatedStorage").Shared.Models3D).CollectFromWorkspace()
	if moved > 0 then
		print(("[Models3D] moved %d imported 3D models from Workspace to ReplicatedStorage.Models3D"):format(moved))
	end
end
-- v21: a janela do chat do Roblox fica no canto de BAIXO, à esquerda (o canto de cima é dos avisos do jogo).
-- A configuração já vem salva no lugar (tools/build_project.py); aqui só garante, caso o Roblox recrie.
task.spawn(function()
	pcall(function()
		local window = game:GetService("TextChatService"):WaitForChild("ChatWindowConfiguration", 10)
		if window then
			window.HorizontalAlignment = Enum.HorizontalAlignment.Left
			window.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
	end)
end)
Registry.Policy.Init() -- regras do país (PolicyService) antes de tudo
Registry.Scenery.Init()
Registry.Plots.Init()
Registry.CritterService.Init()
Registry.Economy.Init()
Registry.Combat.Init()
Registry.Admin.Init()
Registry.Events.Init()
Registry.Leaderboards.Init()
Registry.Products.Init()
Registry.Tutorial.Init()
Registry.Analytics.Init()
Registry.Worlds.Init()
Registry.Fairness.Init()
Registry.Pets.Init()
Registry.Customize.Init()
Registry.Season.Init()
Registry.Environment.Init()
Registry.Discoveries.Init()
task.spawn(Registry.GiantEgg.Init) -- espera o mapa sem travar o resto
Registry.Progress.Init()
Registry.Social.Init()
Registry.LiveEvents.Init()
Registry.Battle.Init()
Registry.Minigames.Init()
Registry.Explore.Init()
Registry.Mounts.Init()
Registry.Retention.Init()
Registry.WorldFun.Init()
task.spawn(Registry.NPCService.Init) -- mascote + ajudantes (3D se estiverem importados)
Registry.Bandits.Init()
Registry.Weekly = require(game:GetService("ReplicatedStorage").Shared.Weekly) -- v26: critter da semana
Registry.Weekly.InitServer(Registry)

-- Placa gigante com o nome do jogo em cima da esteira
do
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
	local titleSign = workspace:WaitForChild("Map"):FindFirstChild("TitleSign")
	if titleSign then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local surface = Instance.new("SurfaceGui")
			surface.Face = face
			surface.LightInfluence = 0
			surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			surface.PixelsPerStud = 20
			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(1, -40, 1, -30)
			title.Position = UDim2.fromOffset(20, 15)
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.FredokaOne
			title.TextScaled = true
			title.TextColor3 = Color3.fromRGB(255, 255, 255)
			title.Text = string.upper(Config.GameName)
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 6
			stroke.Color = Color3.fromRGB(30, 20, 60)
			stroke.Parent = title
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 120, 60))
			gradient.Rotation = 90
			gradient.Parent = title
			title.Parent = surface
			surface.Parent = titleSign
		end
	end
end

local function onCharacter(player: Player, character: Model)
	Registry.Minigames.OnCharacter(player) -- renasceu no meio de um minigame: sai dele
	Registry.Worlds.OnCharacter(player)
	Registry.Plots.SetupCharacter(player, character)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			Registry.Economy.ApplySpeed(player)
		end
		character:WaitForChild("Head", 10)
		Registry.Customize.OnCharacter(player) -- trilha e título em cima da cabeça
		character:WaitForChild("HumanoidRootPart", 10)
		Registry.Progress.OnCharacter(player) -- aura do prestígio
	end)
	task.spawn(Registry.Combat.GiveTool, player, character)
end

local function onPlayerAdded(player: Player)
	local plot = Registry.Plots.Assign(player)
	if not plot then
		player:Kick("This server is full. Please join another server!")
		return
	end
	Registry.Admin.SetupPlayer(player)

	local profile = Registry.Data.Load(player)
	if not player.Parent then
		-- saiu enquanto carregava: libera a trava dos dados
		if profile.CanSave then
			Registry.Data.Save(player, true)
		end
		Registry.Plots.Release(player)
		Registry.Data.Remove(player)
		return
	end
	if not profile.CanSave and not RunService:IsStudio() then
		player:Kick("Couldn't load your save (Roblox servers are busy). Your progress is safe - please rejoin!")
		return
	end

	Registry.Economy.SetupPlayer(player, profile)
	if not player.Parent or player:GetAttribute("Leaving") then
		return
	end
	Registry.Worlds.SetupPlayer(player)
	Registry.Fairness.SetupPlayer(player)
	Registry.CritterService.LoadForPlayer(player, profile.Data.Critters, profile.Data.Eggs)
	Registry.Pets.SetupPlayer(player)
	Registry.Customize.SetupPlayer(player)
	Registry.Economy.AfterLoad(player, profile)
	Registry.Season.SetupPlayer(player) -- depois do dinheiro offline/diária (um 2x do passe não dobra o offline)
	Registry.Progress.SetupPlayer(player) -- nível, missões do dia e conquistas (v10)
	Registry.Social.SetupPlayer(player, profile) -- likes, clã e convites (v11)
	player:SetAttribute("Loaded", true)
	Registry.LiveEvents.SetupPlayer(player) -- presentes da comunidade/criador e mercador (v11): precisa do Loaded
	Registry.Explore.SetupPlayer(player) -- caça aos ovos do dia (v13)
	Registry.Tutorial.Start(player)

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

-- Dinheiro que ficou no coletor vai para o bolso antes de salvar
local function bankVault(player: Player)
	local plot = Registry.Plots.Get(player)
	if plot and plot.Vault >= 1 and player:GetAttribute("Loaded") then
		Registry.Economy.AddCash(player, math.floor(plot.Vault), true, "Collect")
		plot.Vault = 0
	end
end

local function onPlayerRemoving(player: Player)
	player:SetAttribute("Leaving", true)
	Registry.CritterService.DropCarried(player)
	bankVault(player)
	Registry.Analytics.RemovePlayer(player)
	Registry.Data.Save(player, true)
	Registry.CritterService.ClearOwnerCritters(player)
	Registry.Plots.Release(player)
	Registry.Economy.RemovePlayer(player)
	Registry.Combat.RemovePlayer(player)
	Registry.Codes.RemovePlayer(player)
	Registry.Data.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Salva todo mundo de tempos em tempos
task.spawn(function()
	while true do
		task.wait(60)
		local ok, err = pcall(function()
			for _, player in Players:GetPlayers() do
				task.spawn(Registry.Data.Save, player)
			end
		end)
		if not ok then
			warn("[Main] loop error:", err)
		end
	end
end)

-- Salva quando o servidor fecha
game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Leaving", true)
		Registry.CritterService.DropCarried(player)
	end
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			bankVault(player)
			Registry.Data.Save(player, true)
			pending -= 1
		end)
	end
	local started = os.clock()
	while (pending > 0 or Registry.Data.ActiveSaves() > 0) and os.clock() - started < 25 do
		task.wait(0.1)
	end
	if RunService:IsStudio() then
		task.wait(0.5)
	end
end)
