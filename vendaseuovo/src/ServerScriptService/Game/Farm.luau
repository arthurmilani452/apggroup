--[[
	Farm: a produção da barraca.
	  galinhas botam no ninho → Recolher (cesta) → Cozinhar (opcional) → Abastecer a vitrine
	Também conta o tempo de jogo (proteção de novato) e vende galinhas.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Farm = {}

local layTimers: { [string]: number } = {} -- uid da galinha -> segundos acumulados

local function ownerData(player: Player, stand: any): any?
	if stand.Owner ~= player then
		return nil
	end
	return Registry.Economy.Data(player)
end

local function busy(player: Player): boolean
	if Registry.Steal.IsCarrying(player) then
		Registry.Remotes.NotifyPlayer(player, "CANT_WHILE_CARRYING", nil, "error")
		return true
	end
	return false
end

-- Ninho → cesta (ovos mais valiosos primeiro)
function Farm.Collect(player: Player, stand: any)
	local data = ownerData(player, stand)
	if not data or busy(player) then
		return
	end
	local space = Registry.Economy.UpgradeValue(data, "Basket") - #data.Basket
	if space <= 0 then
		Registry.Remotes.NotifyPlayer(player, "BASKET_FULL", nil, "error")
		return
	end
	local moved = 0
	for i = #Config.Hens, 1, -1 do
		local id = Config.Hens[i].Id
		while (data.Nest[id] or 0) > 0 and moved < space do
			data.Nest[id] -= 1
			table.insert(data.Basket, { E = id, R = "raw", L = 0 })
			moved += 1
		end
		if (data.Nest[id] or 0) <= 0 then
			data.Nest[id] = nil
		end
	end
	if moved == 0 then
		Registry.Remotes.NotifyPlayer(player, "NEST_EMPTY", nil, "error")
		return
	end
	Registry.Stands.RefreshNest(stand)
	Registry.Economy.Advance(player, 0)
	Registry.Economy.Push(player)
end

-- Cesta → vitrine (só itens destravados; os mais valiosos primeiro)
function Farm.Stock(player: Player, stand: any)
	local data = ownerData(player, stand)
	if not data or busy(player) then
		return
	end
	local space = Registry.Economy.UpgradeValue(data, "Showcase") - #data.Showcase
	if space <= 0 then
		Registry.Remotes.NotifyPlayer(player, "SHOWCASE_FULL", nil, "error")
		return
	end
	local now = os.time()
	local candidates = {}
	for index, item in data.Basket do
		if (item.L or 0) <= now then
			table.insert(candidates, index)
		end
	end
	table.sort(candidates, function(a, b)
		return Registry.Economy.ItemValue(data.Basket[a]) > Registry.Economy.ItemValue(data.Basket[b])
	end)
	local take = {}
	for i = 1, math.min(space, #candidates) do
		take[candidates[i]] = true
	end
	local kept, moved = {}, 0
	for index, item in data.Basket do
		if take[index] then
			table.insert(data.Showcase, { E = item.E, R = item.R, L = 0 })
			moved += 1
		else
			table.insert(kept, item)
		end
	end
	if moved == 0 then
		Registry.Remotes.NotifyPlayer(player, "NOTHING_TO_STOCK", nil, "error")
		return
	end
	data.Basket = kept
	Registry.Stands.RefreshShowcase(stand)
	Registry.Remotes.NotifyPlayer(player, "STOCKED", { count = moved }, "success")
	Registry.Economy.Advance(player, 1)
	Registry.Economy.Push(player)
end

-- Fogão: primeiro pega o que está pronto, depois coloca ovos crus da cesta nas bocas livres
function Farm.Cook(player: Player, stand: any)
	local data = ownerData(player, stand)
	if not data or busy(player) then
		return
	end
	local slots = Registry.Economy.UpgradeValue(data, "Stove")
	if slots <= 0 then
		Registry.Remotes.NotifyPlayer(player, "P_STOVE_LOCKED", nil, "error")
		return
	end
	local now = os.time()
	local basketMax = Registry.Economy.UpgradeValue(data, "Basket")
	local took = 0
	local still = {}
	for _, slot in data.Stove do
		if now >= slot.T and #data.Basket < basketMax then
			table.insert(data.Basket, { E = slot.E, R = "boiled", L = 0 })
			took += 1
		else
			table.insert(still, slot)
		end
	end
	data.Stove = still
	if took > 0 then
		Registry.Remotes.NotifyPlayer(player, "COOK_TOOK", { count = took }, "success")
	elseif #data.Basket >= basketMax and #data.Stove > 0 then
		Registry.Remotes.NotifyPlayer(player, "BASKET_FULL", nil, "error")
	end

	local free = slots - #data.Stove
	local cookTime = Config.StoveCookTime[math.clamp(Registry.Economy.UpgradeLevel(data, "Stove") + 1, 1, #Config.StoveCookTime)]
	local added = 0
	if free > 0 and took == 0 then
		local kept = {}
		for _, item in data.Basket do
			if added < free and item.R == "raw" and (item.L or 0) <= now then
				table.insert(data.Stove, { E = item.E, T = now + cookTime })
				added += 1
			else
				table.insert(kept, item)
			end
		end
		data.Basket = kept
		if added > 0 then
			Registry.Remotes.NotifyPlayer(player, "COOKING", { count = added }, "success")
		elseif #data.Stove == 0 then
			Registry.Remotes.NotifyPlayer(player, "COOK_NOTHING", nil, "error")
		end
	elseif took == 0 and free <= 0 then
		Registry.Remotes.NotifyPlayer(player, "STOVE_BUSY", nil, "error")
	end
	Registry.Stands.RefreshStove(stand)
	Registry.Economy.Push(player)
end

function Farm.SellHen(player: Player, stand: any, uid: string)
	local data = ownerData(player, stand)
	if not data or busy(player) or Registry.Steal.IsHenCarried(uid) then
		return
	end
	for index, hen in data.Hens do
		if hen.U == uid then
			local now = os.time()
			if (hen.L or 0) > now then
				Registry.Remotes.NotifyPlayer(player, "HEN_LOCKED", { time = (hen.L - now) .. "s" }, "error")
				return
			end
			local henConfig = Config.HenById[hen.Id]
			local price = if henConfig then math.floor(henConfig.Price * Config.SellHenFraction) else 0
			table.remove(data.Hens, index)
			layTimers[uid] = nil
			Registry.Economy.AddMoney(player, price)
			Registry.Stands.RefreshHens(stand)
			Registry.Remotes.NotifyPlayer(player, "HEN_SOLD", { price = "$" .. price }, "success")
			return
		end
	end
end

-- Dá uma galinha nova (compra). Devolve false se o quintal estiver cheio.
function Farm.GiveHen(player: Player, henId: string, lockSeconds: number?): boolean
	local data = Registry.Economy.Data(player)
	if not data then
		return false
	end
	if #data.Hens >= Registry.Economy.UpgradeValue(data, "Yard") then
		return false
	end
	table.insert(data.Hens, {
		U = game:GetService("HttpService"):GenerateGUID(false),
		Id = henId,
		L = if lockSeconds then os.time() + lockSeconds else 0,
	})
	local stand = Registry.Stands.Of(player)
	if stand then
		Registry.Stands.RefreshHens(stand)
	end
	Registry.Economy.Push(player)
	return true
end

function Farm.Init()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, stand in Registry.Stands.All() do
				local owner = stand.Owner
				if not owner then
					continue
				end
				local ok, err = pcall(function()
					local data = Registry.Economy.Data(owner)
					if not data then
						return
					end
					-- tempo de jogo (proteção de novato)
					local hadShield = Registry.Economy.ShieldLeft(data) > 0
					data.PlayTime += 1
					if hadShield and Registry.Economy.ShieldLeft(data) <= 0 then
						Registry.Stands.RefreshInfo(stand)
						Registry.Economy.Push(owner)
					end
					-- galinhas botam
					local nestCount = Registry.Economy.NestCount(data)
					local laid = false
					for _, hen in data.Hens do
						local henConfig = Config.HenById[hen.Id]
						if henConfig and not Registry.Steal.IsHenCarried(hen.U) then
							local t = (layTimers[hen.U] or math.random() * henConfig.LayTime * 0.5) + 1
							if t >= henConfig.LayTime then
								if nestCount < Config.NestCapacity then
									data.Nest[hen.Id] = (data.Nest[hen.Id] or 0) + 1
									nestCount += 1
									laid = true
									t = 0
								else
									t = henConfig.LayTime -- espera o ninho esvaziar
								end
							end
							layTimers[hen.U] = t
						end
					end
					if laid then
						Registry.Stands.RefreshNest(stand)
						Registry.Economy.Push(owner)
					end
					-- fogão: avisa quando algo fica pronto
					local now = os.time()
					local readyNow = 0
					for _, slot in data.Stove do
						if now >= slot.T then
							readyNow += 1
						end
					end
					if readyNow ~= (stand.Model:GetAttribute("StoveReady") or 0) then
						stand.Model:SetAttribute("StoveReady", readyNow)
						Registry.Stands.RefreshStove(stand)
						Registry.Economy.Push(owner)
					end
				end)
				if not ok then
					warn("[Farm] erro:", err)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local profile = Registry.Data.Get(player)
		if profile then
			for _, hen in profile.Data.Hens do
				layTimers[hen.U] = nil
			end
		end
	end)
end

return Farm
