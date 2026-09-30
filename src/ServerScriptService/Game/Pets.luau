--[[
	Pets (ModuleScript em ServerScriptService > Game)
	Parte 14: MOCHILA, PETS e FUSÃO.
	  • Mochila: até Config.InventoryMax bichinhos guardados. Guardado não rende dinheiro, mas ninguém rouba.
	  • Pets: até Config.PetEquipMax bichinhos da mochila seguem você e dão +% de dinheiro (máx. Config.PetBonusCap).
	  • Fusão: 5 iguais (mesmo bichinho e mesma mutação) viram 1 Gold; 5 Gold iguais viram 1 Rainbow.
	Sem duplicação: cada bichinho da mochila tem uma chave única ("k12"), e toda troca
	(base <-> mochila, fusão, venda) acontece de uma vez só, sem pausa no meio.
	A base continua no CritterService; aqui ficam só a mochila e os pets.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Critters = require(ReplicatedStorage.Shared.Critters)
local Format = require(ReplicatedStorage.Shared.Format)
local Hybrids = require(ReplicatedStorage.Shared.Hybrids)
local Registry = require(script.Parent.Registry)

local Pets = {}

-- B = quando nasceu (crescimento), S = shiny
type Entry = { K: string, Id: string, M: string?, B: number?, S: boolean? }

local dirty: { [Player]: boolean } = {}

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function validMutation(value: any): string?
	if type(value) == "string" and Config.MutationByName[value] then
		return value
	end
	return nil
end

local function entryName(entry: Entry): string
	local def = Critters.ById[entry.Id]
	return (if entry.S then "Shiny " else "") .. (if entry.M then entry.M .. " " else "") .. (if def then def.Name else entry.Id)
end

local function entryBonus(entry: Entry): number
	local def = Critters.ById[entry.Id]
	return if def then Config.PetBonusOf(def.Rarity, entry.M) else 0
end

local function entryIncome(entry: Entry): number
	local def = Critters.ById[entry.Id]
	return if def then def.Income * Config.IncomeMultiplier(entry.M) else 0
end

local function findIndex(data, key: any): number?
	if type(key) ~= "string" then
		return nil
	end
	for index, entry in data.Inventory do
		if entry.K == key then
			return index
		end
	end
	return nil
end

local function isEquipped(data, key: string): boolean
	return table.find(data.Equipped, key) ~= nil
end

local function unequipKey(data, key: string)
	local index = table.find(data.Equipped, key)
	if index then
		table.remove(data.Equipped, index)
	end
end

local function newKey(data): string
	data.NextKey = (tonumber(data.NextKey) or 0) + 1
	return "k" .. data.NextKey
end

---------------------------------------------------------------------
-- Estado visível (atributos) e sincronização com a tela
---------------------------------------------------------------------
function Pets.Bonus(player: Player): number
	local data = getData(player)
	if not data then
		return 0
	end
	local total = 0
	for _, key in data.Equipped do
		local index = findIndex(data, key)
		if index then
			total += entryBonus(data.Inventory[index])
		end
	end
	return math.min(total, Config.PetBonusCap)
end

-- "Pets" = "blobby:,zapkit:Gold" -> a tela de TODOS os jogadores desenha os pets seguindo
local function publish(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local parts = {}
	for _, key in data.Equipped do
		local index = findIndex(data, key)
		if index then
			local entry = data.Inventory[index]
			table.insert(parts, entry.Id .. ":" .. (entry.M or ""))
		end
	end
	player:SetAttribute("Pets", table.concat(parts, ","))
	player:SetAttribute("PetBonus", Pets.Bonus(player))
	Registry.Economy.Sync(player)
end

function Pets.MarkDirty(player: Player?)
	if player then
		dirty[player] = true
	end
end

-- Manda a mochila + os bichinhos da base para a tela do jogador
-- Receitas de híbridos que o jogador já descobriu (lista de Ids)
local function recipeList(data): { string }
	local list = {}
	if type(data.Recipes) == "table" then
		for id, known in data.Recipes do
			if known == true and type(id) == "string" and Critters.ById[id] then
				table.insert(list, id)
			end
		end
	end
	return list
end

function Pets.Sync(player: Player)
	local data = getData(player)
	if not data or not player.Parent then
		return
	end
	dirty[player] = nil
	local items = {}
	for _, entry in data.Inventory do
		table.insert(items, { K = entry.K, Id = entry.Id, M = entry.M, B = entry.B, S = entry.S })
	end
	Registry.Remotes.InventoryEvent:FireClient(player, {
		Items = items,
		Equipped = table.clone(data.Equipped),
		Base = Registry.CritterService.GetBaseList(player),
		Max = Config.InventoryMax,
		EquipMax = Config.PetEquipMax,
		Recipes = recipeList(data),
		FeedCost = Registry.CritterService.FeedCost(player),
	})
end

-- Arruma a mochila salva (Ids que não existem mais, pets repetidos...) quando o jogador entra
function Pets.SetupPlayer(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	if type(data.Inventory) ~= "table" then
		data.Inventory = {}
	end
	if type(data.Equipped) ~= "table" then
		data.Equipped = {}
	end
	if type(data.Recipes) ~= "table" then
		data.Recipes = {}
	end
	local clean = {}
	local seen = {}
	for _, entry in data.Inventory do
		if type(entry) == "table" and type(entry.Id) == "string" and Critters.ById[entry.Id] then
			local key = if type(entry.K) == "string" and not seen[entry.K] then entry.K else newKey(data)
			seen[key] = true
			-- save antigo sem nascimento = já é gigante
			table.insert(clean, { K = key, Id = entry.Id, M = validMutation(entry.M), B = tonumber(entry.B) or (os.time() - 86400), S = if entry.S == true then true else nil })
		end
	end
	data.Inventory = clean
	local equipped = {}
	for _, key in data.Equipped do
		if #equipped < Config.PetEquipMax and findIndex(data, key) and not table.find(equipped, key) then
			table.insert(equipped, key)
		end
	end
	data.Equipped = equipped
	publish(player)
	dirty[player] = true
end

-- Renda que a mochila teria na base (a regra "sem covardia" conta a mochila também)
function Pets.BagIncome(player: Player): number
	local data = getData(player)
	local total = 0
	if data then
		for _, entry in data.Inventory do
			total += entryIncome(entry)
		end
	end
	return total
end

-- Ninguém guarda bichinho na mochila com ladrão dentro da base (senão o roubo nunca dá certo)
local function intruderBlocks(player: Player): boolean
	local plot = Registry.Plots.Get(player)
	if plot and Registry.Plots.HasIntruder(plot) then
		Registry.Remotes.Notify(player, "A thief is inside your base! BONK them before picking critters up.", "warning")
		return true
	end
	return false
end

function Pets.Count(player: Player): number
	local data = getData(player)
	return if data then #data.Inventory else 0
end

function Pets.HasSpace(player: Player, amount: number?): boolean
	local data = getData(player)
	return data ~= nil and #data.Inventory + (amount or 1) <= Config.InventoryMax
end

-- Coloca um bichinho na mochila (devolve a chave, ou nil se estiver cheia)
function Pets.Add(player: Player, critterId: string, mutation: string?, born: number?, shiny: boolean?): string?
	local data = getData(player)
	if not data or not Critters.ById[critterId] or #data.Inventory >= Config.InventoryMax then
		return nil
	end
	local key = newKey(data)
	table.insert(data.Inventory, { K = key, Id = critterId, M = validMutation(mutation), B = born or os.time(), S = if shiny then true else nil })
	Registry.Economy.Discover(player, critterId)
	dirty[player] = true
	return key
end

-- Tira da mochila (tira dos pets também). Devolve a entrada removida.
local function removeEntry(player: Player, data, index: number): Entry
	local entry = table.remove(data.Inventory, index) :: Entry
	if isEquipped(data, entry.K) then
		unequipKey(data, entry.K)
		publish(player)
	end
	dirty[player] = true
	return entry
end

-- Presentes (Social): procurar, tirar e ver se cabe
function Pets.Find(player: Player, key: any): Entry?
	local data = getData(player)
	local index = data and findIndex(data, key)
	return if index then data.Inventory[index] else nil
end

function Pets.Take(player: Player, key: any): Entry?
	local data = getData(player)
	local index = data and findIndex(data, key)
	if not index then
		return nil
	end
	return removeEntry(player, data, index)
end

function Pets.HasRoom(player: Player): boolean
	return Pets.HasSpace(player, 1)
end

---------------------------------------------------------------------
-- Ações (vêm da tela do jogador; tudo é conferido aqui)
---------------------------------------------------------------------
-- Base -> mochila
function Pets.Store(player: Player, uid: any)
	local data = getData(player)
	local Remotes = Registry.Remotes
	if not data or typeof(uid) ~= "number" then
		return
	end
	if #data.Inventory >= Config.InventoryMax then
		Remotes.Notify(player, ("Your backpack is full (%d)! Sell or fuse something first."):format(Config.InventoryMax), "error")
		return
	end
	if intruderBlocks(player) then
		return
	end
	local locked = Registry.CritterService.StolenLockLeft(player, uid)
	if locked > 0 then
		Remotes.Notify(player, ("You just stole this one! It can go to your backpack in %ds."):format(math.ceil(locked)), "warning")
		return
	end
	local critterId, mutation, born, shiny = Registry.CritterService.TakeFromBase(player, uid)
	if not critterId then
		return
	end
	Pets.Add(player, critterId, mutation, born, shiny)
	Registry.CritterService.PlacePending(player)
	Remotes.Notify(player, entryName({ K = "", Id = critterId, M = mutation }) .. " went to your backpack. (Backpack critters don't make cash.)", "info")
	Remotes.Effect(player, "Purchase", "Common")
end

-- Mochila -> base
function Pets.Place(player: Player, key: any)
	local data = getData(player)
	local Remotes = Registry.Remotes
	local index = data and findIndex(data, key)
	if not data or not index then
		return
	end
	local CritterService = Registry.CritterService
	if not CritterService.HasFreeSlot(player) then
		Remotes.Notify(player, "Your base is full! Pick something up or buy more slots.", "error")
		return
	end
	local entry = removeEntry(player, data, index)
	if not CritterService.PlaceFromInventory(player, entry.Id, entry.M, entry.B, entry.S) then
		-- não coube (não deveria acontecer): volta para a mochila
		table.insert(data.Inventory, entry)
		return
	end
	Remotes.Notify(player, entryName(entry) .. " is back on your base making cash!", "success")
	Remotes.Effect(player, "Purchase", "Common")
end

function Pets.Equip(player: Player, key: any)
	local data = getData(player)
	if not data or not findIndex(data, key) or isEquipped(data, key) then
		return
	end
	if #data.Equipped >= Config.PetEquipMax then
		Registry.Remotes.Notify(player, ("You can equip %d pets. Unequip one first!"):format(Config.PetEquipMax), "warning")
		return
	end
	table.insert(data.Equipped, key)
	publish(player)
	dirty[player] = true
end

function Pets.Unequip(player: Player, key: any)
	local data = getData(player)
	if not data or type(key) ~= "string" or not isEquipped(data, key) then
		return
	end
	unequipKey(data, key)
	publish(player)
	dirty[player] = true
end

-- Equipa os melhores (maior bônus; empate = maior renda)
function Pets.EquipBest(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local list = table.clone(data.Inventory)
	table.sort(list, function(a, b)
		local ba, bb = entryBonus(a), entryBonus(b)
		if ba ~= bb then
			return ba > bb
		end
		return entryIncome(a) > entryIncome(b)
	end)
	local equipped = {}
	for i = 1, math.min(Config.PetEquipMax, #list) do
		table.insert(equipped, list[i].K)
	end
	data.Equipped = equipped
	publish(player)
	dirty[player] = true
	if #equipped == 0 then
		Registry.Remotes.Notify(player, "Your backpack is empty! Pick up a critter from your base first.", "warning")
	else
		Registry.Remotes.Notify(player, ("Equipped your best %d pets: +%d%% cash!"):format(#equipped, math.floor(Pets.Bonus(player) * 100 + 0.5)), "success")
	end
end

-- Quantos iguais existem (mochila + base) para fundir
function Pets.CountSame(player: Player, critterId: string, mutation: string?): number
	local data = getData(player)
	if not data then
		return 0
	end
	local count = 0
	for _, entry in data.Inventory do
		if entry.Id == critterId and entry.M == mutation and not entry.S then
			count += 1
		end
	end
	return count + #Registry.CritterService.FindBaseUids(player, critterId, mutation)
end

-- Fusão: 5 iguais -> 1 com a mutação seguinte. Usa primeiro os da mochila (os não equipados antes).
function Pets.Fuse(player: Player, request: any)
	local data = getData(player)
	local Remotes = Registry.Remotes
	if not data or type(request) ~= "table" or type(request.Id) ~= "string" then
		return
	end
	local def = Critters.ById[request.Id]
	local mutation = validMutation(request.M)
	if not def or (request.M ~= nil and request.M ~= "" and not mutation) then
		return
	end
	local result = Config.FuseResult(mutation)
	if not result then
		Remotes.Notify(player, "This critter can't be fused any further!", "warning")
		return
	end
	local need = Config.FuseCount
	if Pets.CountSame(player, def.Id, mutation) < need then
		Remotes.Notify(player, ("You need %d of the same critter to fuse!"):format(need), "error")
		return
	end

	-- escolhe quem vai ser usado (tudo decidido antes de mexer em qualquer coisa)
	local fromBag: { string } = {}
	local wasEquipped = false
	for pass = 1, 2 do
		for _, entry in data.Inventory do
			if #fromBag >= need then
				break
			end
			if entry.Id == def.Id and entry.M == mutation and not entry.S then
				local equipped = isEquipped(data, entry.K)
				if (pass == 1 and not equipped) or (pass == 2 and equipped) then
					table.insert(fromBag, entry.K)
					wasEquipped = wasEquipped or equipped
				end
			end
		end
	end
	local fromBase: { number } = {}
	if #fromBag < need and intruderBlocks(player) then
		return
	end
	if #fromBag < need then
		for _, uid in Registry.CritterService.FindBaseUids(player, def.Id, mutation) do
			if #fromBag + #fromBase >= need then
				break
			end
			table.insert(fromBase, uid)
		end
	end
	if #fromBag + #fromBase < need then
		return
	end

	-- usa (sem pausa entre conferir e usar: ninguém consegue duplicar no meio)
	local oldest = os.time() -- o resultado herda a idade do mais velho (fusão não volta a ser bebê)
	for _, uid in fromBase do
		local takenId, takenMutation, born = Registry.CritterService.TakeFromBase(player, uid)
		if takenId ~= def.Id or takenMutation ~= mutation then
			warn("[Pets] fusão: bichinho da base mudou no meio", player.Name, uid)
		end
		oldest = math.min(oldest, born or oldest)
	end
	for _, key in fromBag do
		local index = findIndex(data, key)
		if index then
			local removed = removeEntry(player, data, index)
			oldest = math.min(oldest, removed.B or oldest)
		end
	end
	local newKeyValue = Pets.Add(player, def.Id, result, oldest)
	if newKeyValue then
		if wasEquipped and #data.Equipped < Config.PetEquipMax then
			table.insert(data.Equipped, newKeyValue)
		end
	elseif not Registry.CritterService.PlaceFromInventory(player, def.Id, result, oldest) then
		-- mochila cheia e base cheia (não deveria acontecer: acabamos de liberar 5 lugares)
		table.insert(data.Pending, { Id = def.Id, Mutation = result, B = oldest })
	end
	publish(player)
	Registry.CritterService.PlacePending(player)
	Remotes.Effect(player, "Fused", { Critter = def.Id, Mutation = result })
	Registry.Economy.SeasonXP(player, "Fuse")
	Remotes.Notify(player, ("FUSED! 5 %s became 1 %s %s (x%d cash)!"):format(entryName({ K = "", Id = def.Id, M = mutation }), string.upper(result), def.Name, Config.IncomeMultiplier(result)), "rare")
	if result == "Rainbow" then
		Remotes.NotifyAll(("%s fused a RAINBOW %s!"):format(player.DisplayName, def.Name), "rare")
	end
	local analytics = Registry.Analytics
	if analytics then
		pcall(analytics.Event, player, "Fuse_" .. result)
	end
end

-- Vender da mochila
function Pets.Sell(player: Player, key: any)
	local data = getData(player)
	local index = data and findIndex(data, key)
	if not data or not index then
		return
	end
	local entry = removeEntry(player, data, index)
	local def = Critters.ById[entry.Id]
	local amount = math.floor(def.Price * Config.PriceMultiplier(entry.M) * (if entry.S then Config.ShinyIncome else 1) * Config.CritterSellRefund)
	if amount > 0 then
		Registry.Economy.AddCash(player, amount, false, "Sell")
	end
	Registry.Remotes.Notify(player, ("Sold %s for %s"):format(entryName(entry), Format.Money(amount)), "info")
end

-- LABORATÓRIO DE MISTURA: 2 espécies diferentes da mochila -> 1 híbrido (se a dupla for uma receita)
-- Precisa estar perto do laboratório (Map.Booths.Lab). Dupla sem receita: nada é gasto.
local LAB_RANGE = 40
local function nearLab(player: Player): boolean
	local map = workspace:FindFirstChild("Map")
	local booths = map and map:FindFirstChild("Booths")
	local lab = booths and booths:FindFirstChild("Lab")
	local counter = lab and lab:FindFirstChild("Counter") :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not counter or not root then
		return false
	end
	return (counter.CFrame.Position - root.Position).Magnitude <= LAB_RANGE
end

function Pets.Mix(player: Player, request: any)
	local data = getData(player)
	local Remotes = Registry.Remotes
	if not data or type(request) ~= "table" or type(request.A) ~= "string" or type(request.B) ~= "string" or request.A == request.B then
		return
	end
	if not nearLab(player) then
		Remotes.Notify(player, "Go to the MIX LAB behind the bases to mix critters!", "warning")
		return
	end
	local indexA, indexB = findIndex(data, request.A), findIndex(data, request.B)
	if not indexA or not indexB then
		return
	end
	local a, b = data.Inventory[indexA], data.Inventory[indexB]
	if a.S or b.S then
		Remotes.Notify(player, "Shiny critters are too special to mix!", "warning")
		return
	end
	local recipe = Hybrids.Find(a.Id, b.Id)
	if not recipe then
		Remotes.Notify(player, "Nothing happened... these two don't mix. Try another pair!", "info")
		Remotes.Effect(player, "MixFail")
		return
	end
	local hybrid = Critters.ById[recipe.Result]
	if not hybrid then
		return
	end
	-- mesma mutação nos dois pais = o híbrido herda
	local mutation = if a.M and a.M == b.M then a.M else nil
	local oldest = math.min(a.B or os.time(), b.B or os.time())
	local wasEquipped = isEquipped(data, a.K) or isEquipped(data, b.K)
	local isNew = not Registry.Economy.HasDiscovered(player, hybrid.Id)
	-- tira os dois (o índice maior primeiro, para o outro não mudar de lugar)
	local first, second = math.max(indexA, indexB), math.min(indexA, indexB)
	removeEntry(player, data, first)
	removeEntry(player, data, second)
	local key = Pets.Add(player, hybrid.Id, mutation, oldest)
	if key and wasEquipped and #data.Equipped < Config.PetEquipMax then
		table.insert(data.Equipped, key)
	end
	if type(data.Recipes) ~= "table" then
		data.Recipes = {}
	end
	data.Recipes[hybrid.Id] = true
	publish(player)
	Remotes.Effect(player, "Mixed", { Critter = hybrid.Id, Mutation = mutation, New = isNew })
	Remotes.Notify(player, ("MIXED! %s + %s = %s!"):format(entryName(a), entryName(b), hybrid.Name), "rare")
	if isNew then
		Remotes.NotifyAll(("%s discovered the %s recipe!"):format(player.DisplayName, hybrid.Name), "rare")
	end
	Registry.Economy.SeasonXP(player, "Mix")
end

-- Admin/teste: vários iguais de uma vez (para testar a fusão)
function Pets.AdminGive(player: Player, critterId: string, mutation: string?, amount: number)
	for _ = 1, amount do
		if not Pets.Add(player, critterId, mutation) then
			break
		end
	end
	Pets.Sync(player)
end

function Pets.RemovePlayer(player: Player)
	dirty[player] = nil
end

function Pets.Init()
	Players.PlayerRemoving:Connect(Pets.RemovePlayer)
	-- manda as mudanças para a tela no máximo 2x por segundo
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(function()
				for player in dirty do
					if player.Parent and player:GetAttribute("Loaded") then
						Pets.Sync(player)
					else
						dirty[player] = nil
					end
				end
			end)
			if not ok then
				warn("[Pets] loop error:", err)
			end
		end
	end)
end

return Pets
