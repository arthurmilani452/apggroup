--[[
	VENDA UM OVO - script principal do servidor (Script "Main" em ServerScriptService).
	Liga os módulos da pasta "Game" e cuida da entrada/saída dos jogadores.
	Pra ajustar o jogo, mexa em ReplicatedStorage > Shared > Config.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sim = require(ReplicatedStorage.Shared.Sim)
local GameFolder = script.Parent:WaitForChild("Game")
local Registry = require(GameFolder.Registry)

-- Texturas (Config.Textures): peças com o atributo "Tex" ganham a textura que repete
for _, d in workspace:GetDescendants() do
	local texName = d:IsA("BasePart") and d:GetAttribute("Tex")
	local id = texName and Config.Textures[texName]
	if id and id ~= "" then
		local faces = { Enum.NormalId.Top }
		if d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
			faces = { Enum.NormalId.Right, Enum.NormalId.Left } -- disco deitado: as tampas são as faces X
		end
		for _, face in faces do
			local texture = Instance.new("Texture")
			texture.Texture = id
			texture.Transparency = Config.TextureFade[texName] or 0
			texture.Face = face
			texture.StudsPerTileU = Config.TextureTile
			texture.StudsPerTileV = Config.TextureTile
			texture.Parent = d
		end
	end
end

Registry.Remotes = require(GameFolder.Remotes)
Registry.Data = require(GameFolder.Data)
Registry.Game = require(GameFolder.Game)
Registry.Weather = require(GameFolder.Weather)
Registry.Plots = require(GameFolder.Plots)
Registry.Farm = require(GameFolder.Farm)
Registry.Shop = require(GameFolder.Shop)
Registry.Events = require(GameFolder.Events)
Registry.Tractor = require(GameFolder.Tractor)
Registry.Store = require(GameFolder.Store)
Registry.Leaderboard = require(GameFolder.Leaderboard)

-- Cada sistema liga sozinho; se um der erro, os outros continuam
for _, name in { "Game", "Weather", "Plots", "Farm", "Shop", "Events", "Tractor", "Store", "Leaderboard" } do
	local ok, err = pcall(Registry[name].Init)
	if not ok then
		warn("[Main] " .. name .. ".Init falhou:", err)
	end
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	Registry.Game.ApplySpeed(player)
	-- renasce sozinho depois de cair/morrer
	humanoid.Died:Connect(function()
		task.wait(3)
		if player.Parent and player.Character == character then
			player:LoadCharacter()
		end
	end)
	-- nasce dentro da própria granja
	local plot = Registry.Plots.Of(player)
	if plot and character:WaitForChild("HumanoidRootPart", 10) then
		task.defer(function()
			character:PivotTo(Registry.Plots.SpawnCFrame(plot))
		end)
	end
end

local function onPlayerAdded(player: Player)
	Registry.Game.SetupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)

	local profile = Registry.Data.Load(player)
	if not player.Parent then
		if profile.CanSave then
			Registry.Data.Save(player, true)
		end
		Registry.Data.Remove(player)
		return
	end
	if not profile.CanSave and not RunService:IsStudio() then
		player:Kick("Não deu pra carregar seu progresso agora (Roblox ocupado). Ele tá salvo, entra de novo. / Could not load your progress right now. It is safe, please rejoin.")
		return
	end
	player:SetAttribute("Loaded", true)
	local data = profile.Data
	local ctx = Registry.Game.Ctx(player)
	local now = os.time()
	-- renda offline (só dos negócios com gerente) e missões do dia
	pcall(Sim.Offline, Config, data, ctx, now)
	data.LastSeen = now
	pcall(Sim.CheckDaily, Config, data, ctx, now)

	local plot = Registry.Plots.Assign(player)
	if not plot then
		player:Kick("Servidor cheio. Tenta outro. / Server is full, try another one.")
		return
	end
	task.spawn(Registry.Store.CheckPasses, player)
	task.spawn(Registry.Game.RefreshSocial, player)
	Registry.Game.Push(player)
	player:LoadCharacter()
end

local function onPlayerRemoving(player: Player)
	-- moedas e gorjetas que ficaram no chão entram na conta antes de salvar (senão sumiriam com o terreno)
	pcall(Registry.Farm.Sweep, player)
	-- devolve o terreno JÁ (antes das chamadas que esperam a internet): daqui em diante nada mais cai no chão
	pcall(Registry.Plots.Release, player)
	pcall(Registry.Leaderboard.Write, player)
	Registry.Remotes.RemovePlayer(player)
	Registry.Data.Save(player, true)
	Registry.Data.Remove(player)
end

Players.CharacterAutoLoads = false -- nasce só depois de carregar os dados e ganhar a granja
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- ---------------------------------------------------------------------------
-- Ferramenta de teste: SÓ existe no Studio. Na barra de comandos (modo Servidor), por exemplo:
--   game.ServerStorage.VUODebug:Invoke("coins", 1e9)   moedas
--   game.ServerStorage.VUODebug:Invoke("stars", 500)   estrelas;  ("earned", 1e12) ganho desde o último selo
--   game.ServerStorage.VUODebug:Invoke("buy", 20)      compra os próximos 20 botões
--   game.ServerStorage.VUODebug:Invoke("tp", "next")   leva ao próximo botão; "sell", "home", "inc" ou um
--                                                      número de 1 a 8 (ponto de abrir/trabalhar do negócio)
--   game.ServerStorage.VUODebug:Invoke("event", "rain")  começa um evento ("rain", "gift", "race", "order")
--   game.ServerStorage.VUODebug:Invoke("rare", "m")    faz aparecer um ovo raro num ninho ("s", "g" ou "m")
--   game.ServerStorage.VUODebug:Invoke("tips", 6)      põe gorjetas no chão da banca
--   game.ServerStorage.VUODebug:Invoke("bag")          faz cair um saco de dinheiro agora;  ("bag", "gold") um dourado
--   game.ServerStorage.VUODebug:Invoke("weather", "chuva")  troca o clima agora ("limpo", "sol", "chuva", "vento", "noite",
--                                                      "arcoiris");  ("weather", "stop") para o rodízio;  ("weather", "auto") religa
--   game.ServerStorage.VUODebug:Invoke("key")          faz nascer uma chave secreta agora;  ("keys", 3) põe 3 chaves na mão
--   game.ServerStorage.VUODebug:Invoke("power", "galo")  usa um poder sem esperar a recarga ("galo", "moedas", "sorte");
--                                                      ("refill") deixa todos os poderes prontos
--   game.ServerStorage.VUODebug:Invoke("egg", "s")     ovo raro direto na cesta;  ("hatch") nasce já;  ("pet", "pata:g")
--   game.ServerStorage.VUODebug:Invoke("spins", 5)     giros;  ("giant", 1) enche o Ovo Gigante;  ("obby") vai ao baú
--   game.ServerStorage.VUODebug:Invoke("pass", "VIP")  liga um passe da loja sem comprar ("todos" = todos);
--                                                      ("nopass") tira todos;  ("product", "PacoteInicial") entrega um produto
--   game.ServerStorage.VUODebug:Invoke("info")
-- ---------------------------------------------------------------------------
if RunService:IsStudio() then
	local Layout = require(ReplicatedStorage.Shared.Layout)
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "VUODebug"
	debugFn.OnInvoke = function(command: any, value: any): string
		local player = Players:GetPlayers()[1]
		local data = player and Registry.Game.Data(player)
		local plot = player and Registry.Plots.Of(player)
		if not player or not data or not plot then
			return "sem jogador carregado"
		end
		if command == "coins" then
			data.Coins = tonumber(value) or 0
		elseif command == "stars" then
			data.Stars = tonumber(value) or 0
			data.StarsTotal = math.max(data.StarsTotal, data.Stars)
		elseif command == "earned" then
			data.SealEarned = tonumber(value) or 0
		elseif command == "buy" then
			for _ = 1, tonumber(value) or 1 do
				local button = Sim.NextButton(Config, data)
				if not button then
					break
				end
				data.Coins = math.max(data.Coins, button.Cost)
				Registry.Farm.TryBuy(player, plot, button)
			end
		elseif command == "tp" then
			local point = Layout.Spawn
			local biz = Layout.Biz[tonumber(value) or 0]
			if biz then
				point = biz.U
			elseif value == "next" then
				local button = Sim.NextButton(Config, data)
				point = if button then Registry.Plots.ButtonPoint(button) else point
			elseif value == "sell" then
				point = Layout.Sell
			elseif value == "inc" then
				point = Layout.Incubators[1]
			end
			if player.Character then
				player.Character:PivotTo(Registry.Plots.CF(plot, point[1], point[2], 180, 4))
			end
		elseif command == "event" then
			if value == "order" then
				Registry.Events.ForceOrder(player)
			else
				return tostring(Registry.Events.Force(tostring(value)))
			end
		elseif command == "rare" then -- ovo raro num ninho: "s", "g" ou "m" (precisa da Granja aberta)
			local egg = Sim.SpawnRare(Config, data, plot.Run, math.random, if Config.MutationById[value] then value else "s")
			if not egg then
				return "sem Granja aberta ou ninhos cheios"
			end
			Registry.Farm.RareSpawned(player, plot, { egg })
		elseif command == "tips" then -- gorjetas no chão da banca (até Config.TipMax)
			plot.Run.Tips = math.clamp(math.floor(tonumber(value) or Config.TipMax), 0, Config.TipMax)
			Registry.Plots.SetTips(plot, plot.Run.Tips)
		elseif command == "bag" then -- saco de dinheiro agora (troca o que estiver no chão): ("bag") normal, ("bag", "gold") dourado
			plot.Run.Bag = nil
			if not Registry.Farm.DropBag(player, plot, value == "gold") then
				Registry.Plots.SyncBag(plot)
				return "sem banca aberta: o saco de dinheiro só cai para quem já abriu a banca"
			end
		elseif command == "weather" then -- clima agora: id do Config.Weather; "stop" / "auto" = para / religa o rodízio
			local W = Registry.Weather
			if value == "stop" or value == "auto" then
				W.Auto = value == "auto"
				return "rodízio do clima " .. (if W.Auto then "ligado" else "parado") .. " (clima de agora: " .. tostring(W.Current) .. ")"
			elseif not W.Force(value) then
				local ids = {}
				for _, def in Config.Weather.List do
					table.insert(ids, def.Id)
				end
				return "clima desconhecido: " .. tostring(value) .. " (use " .. table.concat(ids, ", ") .. ", stop ou auto)"
			end
		elseif command == "key" then -- nasce uma chave secreta agora (num lugar longe do jogador)
			if not Registry.Farm.DropKey(player, plot) then
				return if not Sim.KeysOpen(Config, data)
					then "sem chave: as chaves secretas só aparecem depois de abrir " .. Config.Keys.MinBiz .. " negócios"
					elseif plot.Run.Key then "já tem uma chave escondida no terreno (lugar " .. tostring(plot.Run.Key.Spot) .. ")"
					else "já está com todas as chaves na mão: abra o Baú Secreto"
			end
		elseif command == "keys" then -- põe n chaves na mão (0 a Config.Keys.Need)
			data.Keys = math.clamp(math.floor(tonumber(value) or Config.Keys.Need), 0, Config.Keys.Need)
			Registry.Plots.SyncChest(plot)
		elseif command == "power" then -- usa o poder agora, sem esperar a recarga (trancado continua trancado)
			if type(value) ~= "string" or not Config.PowerById[value] then
				return "poder desconhecido: " .. tostring(value)
			end
			data.Powers[value] = nil
			local ok, reason = Registry.Farm.UsePower(player, value, true)
			if not ok then
				return "não usou o poder " .. value .. ": " .. tostring(reason)
			end
		elseif command == "refill" then -- todos os poderes prontos
			data.Powers = {}
		elseif command == "egg" then -- põe um ovo raro direto na cesta: "s", "g" ou "m"
			local line = Config.Lines[math.max(1, Sim.BestLine(Config, data))]
			local key = Sim.EggKey(line.Id, if Config.MutationById[value] then value else "s")
			data.Basket[key] = (data.Basket[key] or 0) + 1
		elseif command == "hatch" then -- faz os ovos das chocadeiras nascerem agora
			for _, hatch in data.Hatch do
				hatch.Ready = os.time()
			end
			Registry.Plots.SyncHatch(plot)
		elseif command == "pet" then -- ganha um pet: "branco:s", "dragao:m", "ovinho:ouro"...
			Sim.AddPet(Config, data, Registry.Game.Ctx(player), tostring(value))
		elseif command == "spins" then
			Sim.AddSpins(Config, data, tonumber(value) or 1)
		elseif command == "giant" then -- enche o Ovo Gigante (0 a 1)
			Registry.Events.GiantFill(tonumber(value) or 1)
		elseif command == "pass" or command == "nopass" or command == "product" then -- loja em Robux, sem gastar nada
			return Registry.Store.Debug(player, command, value)
		elseif command == "obby" then
			local chest = Layout.Obby.Chest
			if player.Character then
				player.Character:PivotTo(CFrame.new(chest[1], chest[2] + 3, chest[3]))
			end
		end
		Registry.Game.Push(player)
		local auto, all = Sim.Income(Config, data, Registry.Game.Ctx(player))
		return ("moedas %s | no chão %s | estrelas %d | botoes %d/%d | negócios %d | aves %d | renda %s/s (com gerente %s/s) | cesta %d | renascimentos %d | selo %d"):format(
			tostring(data.Coins), tostring(Sim.GroundTotal(plot.Run)), data.Stars, Sim.Count(data.Owned), #Config.Buttons, Sim.BizCount(Config, data), Sim.BirdCount(Config, data), tostring(all), tostring(auto), Sim.BasketCount(data), data.Rebirths, data.Seal
		)
	end
	debugFn.Parent = game:GetService("ServerStorage")
end

-- Salva todo mundo de tempos em tempos
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			task.spawn(Registry.Data.Save, player)
		end
	end
end)

-- Salva quando o servidor fecha
game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			pcall(Registry.Farm.Sweep, player) -- o que está no chão entra na conta antes do último save
			pcall(Registry.Leaderboard.Write, player)
			Registry.Data.Save(player, true)
			pending -= 1
		end)
	end
	local started = os.clock()
	while (pending > 0 or Registry.Data.ActiveSaves() > 0) and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)
