--[[
	Steal: roubar galinhas (do quintal) e cestas de ovos (da vitrine) de outros jogadores.
	Proteções que já nascem com o jogo (lições do Steal a Critter v28):
	  • anti-teleporte DURANTE o caminho (cada salto grande demais devolve o item) e tempo mínimo de viagem
	  • ninguém segura item roubado por mais de Config.Steal.MaxCarry (volta ao dono)
	  • o que foi roubado fica travado (não dá para vender/pôr na vitrine na hora)
	  • novatos protegidos; portão fechado protege o quintal; dono no balcão protege a vitrine
	  • o roubo leva produto, nunca dinheiro. Até chegar na base do ladrão, a galinha continua nos dados do dono.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Registry = require(script.Parent.Registry)

local Steal = {}

local S = Config.Steal

type Carry = {
	Kind: string, -- "hen" | "basket"
	Thief: Player,
	Owner: Player,
	OwnerStand: any,
	HenUid: string?,
	HenId: string?,
	Items: { any }?,
	Start: number,
	From: Vector3,
	LastPos: Vector3?,
	LastTime: number?,
	Strikes: number,
	Model: Model?,
	Done: boolean,
}

local carrying: { [Player]: Carry } = {}
local carriedHens: { [string]: Carry } = {}

function Steal.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function Steal.IsHenCarried(uid: string): boolean
	return carriedHens[uid] ~= nil
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

local function whatKey(carry: Carry): string
	return if carry.Kind == "hen" then "#H_" .. (carry.HenId or "caipira") else "#BASKET_WHAT"
end

-- velocidade de cada um (ladrão carregando fica lento; vítima de roubo ganha +20%)
local function refreshSpeed(player: Player)
	local _, humanoid = rootOf(player)
	if not humanoid then
		return
	end
	local speed = Config.WalkSpeed
	local carry = carrying[player]
	if carry then
		speed *= if carry.Kind == "hen" then S.HenSpeedMult else S.BasketSpeedMult
	else
		for _, other in carrying do
			if other.Owner == player then
				speed *= S.RevengeSpeed
				break
			end
		end
	end
	humanoid.WalkSpeed = speed
end

local function attachVisual(carry: Carry)
	local root = rootOf(carry.Thief)
	local character = carry.Thief.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not root or not head then
		return
	end
	local model: Model
	if carry.Kind == "hen" then
		model = Models.Hen(Config.HenById[carry.HenId or "caipira"])
	else
		model = Instance.new("Model")
		model.Name = "Basket"
		local basket = Instance.new("Part")
		basket.Name = "Root"
		basket.Size = Vector3.new(2.4, 1.2, 2.4)
		basket.Color = Color3.fromRGB(170, 120, 60)
		basket.Material = Enum.Material.WoodPlanks
		basket.CanCollide = false
		basket.Massless = true
		basket.Parent = model
		model.PrimaryPart = basket
		for i, item in carry.Items or {} do
			local hen = Config.HenById[item.E]
			if hen and i <= 5 then
				local egg = Models.Egg(hen.Egg)
				egg.Anchored = false
				egg.CFrame = basket.CFrame * CFrame.new((i - 3) * 0.4, 0.7, 0)
				egg.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = basket
				weld.Part1 = egg
				weld.Parent = egg
			end
		end
	end
	Models.SetAnchored(model, false)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.Massless = true
		end
	end
	local primary = model.PrimaryPart :: BasePart
	model:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + primary.Size.Y / 2 + 0.2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = primary
	weld.Parent = primary
	-- todo mundo menos o ladrão pode "pegar de volta"
	local prompt = Registry.Stands.MakePrompt(primary, "P_TAKE_BACK", if carry.Kind == "hen" then "H_" .. (carry.HenId or "caipira") else "BASKET_WHAT", "notthief", 0.4, S.PromptDistance)
	prompt:SetAttribute("Thief", carry.Thief.UserId)
	prompt.Triggered:Connect(function(player)
		Steal.TakeBack(player, carry)
	end)
	if carry.Kind == "hen" and Config.Sounds.Cackle ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = Config.Sounds.Cackle
		sound.Looped = true
		sound.Volume = 0.8
		sound.RollOffMaxDistance = 120
		sound.Parent = primary
		sound:Play()
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.6
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.Parent = model
	model.Parent = character
	carry.Model = model
end

local function finish(carry: Carry)
	if carry.Done then
		return
	end
	carry.Done = true
	if carrying[carry.Thief] == carry then
		carrying[carry.Thief] = nil
	end
	if carry.HenUid and carriedHens[carry.HenUid] == carry then
		carriedHens[carry.HenUid] = nil
	end
	if carry.Model then
		carry.Model:Destroy()
		carry.Model = nil
	end
	carry.Thief:SetAttribute("CarryEnd", nil)
	refreshSpeed(carry.Thief)
	refreshSpeed(carry.Owner)
end

-- Devolve ao dono (deixou cair, morreu, teleportou, demorou demais, alguém pegou de volta)
local function returnToOwner(carry: Carry, reason: string)
	if carry.Done then
		return
	end
	finish(carry)
	local ownerData = Registry.Economy.Data(carry.Owner) or (Registry.Data.Get(carry.Owner) and Registry.Data.Get(carry.Owner).Data)
	if carry.Kind == "basket" and ownerData then
		for _, item in carry.Items or {} do
			table.insert(ownerData.Showcase, item)
		end
	end
	local stand = carry.OwnerStand
	if stand and stand.Owner == carry.Owner then
		Registry.Stands.RefreshHens(stand)
		Registry.Stands.RefreshShowcase(stand)
	end
	if carry.Owner.Parent then
		Registry.Remotes.NotifyPlayer(carry.Owner, "STEAL_RETURNED", { what = whatKey(carry) }, "success")
		Registry.Economy.Push(carry.Owner)
	end
	if carry.Thief.Parent and reason ~= "left" then
		Registry.Remotes.NotifyPlayer(carry.Thief, "STEAL_FAILED", nil, "error")
	end
end

local function complete(carry: Carry)
	if carry.Done then
		return
	end
	local thief, owner = carry.Thief, carry.Owner
	local thiefData = Registry.Economy.Data(thief)
	local ownerData = Registry.Economy.Data(owner)
	if not thiefData or not ownerData then
		returnToOwner(carry, "invalid")
		return
	end
	if carry.Kind == "hen" then
		local found = nil
		for index, hen in ownerData.Hens do
			if hen.U == carry.HenUid then
				found = index
				break
			end
		end
		if not found or #thiefData.Hens >= Registry.Economy.UpgradeValue(thiefData, "Yard") then
			returnToOwner(carry, "invalid")
			return
		end
		finish(carry)
		local hen = table.remove(ownerData.Hens, found)
		hen.L = os.time() + S.StolenLock
		table.insert(thiefData.Hens, hen)
	else
		finish(carry)
		local lock = os.time() + S.StolenLock
		for _, item in carry.Items or {} do
			table.insert(thiefData.Basket, { E = item.E, R = item.R, L = lock })
		end
	end
	thiefData.Stats.Steals += 1
	ownerData.Stats.Stolen += 1
	local what = whatKey(carry)
	Registry.Remotes.NotifyPlayer(thief, "STEAL_DONE_THIEF", { what = what }, "success")
	Registry.Remotes.NotifyPlayer(owner, "STEAL_DONE_VICTIM", { name = thief.DisplayName, what = what }, "error")
	Registry.Economy.Log(thief, "StealDone_" .. carry.Kind)
	local thiefStand = Registry.Stands.Of(thief)
	if thiefStand then
		Registry.Stands.RefreshHens(thiefStand)
	end
	if carry.OwnerStand and carry.OwnerStand.Owner == owner then
		Registry.Stands.RefreshHens(carry.OwnerStand)
	end
	Registry.Economy.Push(thief)
	Registry.Economy.Push(owner)
end

-- Conferências comuns antes de começar um roubo
local function canSteal(thief: Player, stand: any, part: BasePart): (boolean, Player?)
	local owner = stand.Owner
	if not owner or owner == thief then
		return false, nil
	end
	local thiefData = Registry.Economy.Data(thief)
	local ownerData = Registry.Economy.Data(owner)
	if not thiefData or not ownerData then
		return false, nil
	end
	local root, humanoid = rootOf(thief)
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, nil
	end
	if (root.Position - part.Position).Magnitude > S.PromptDistance + 4 then
		return false, nil
	end
	if carrying[thief] then
		Registry.Remotes.NotifyPlayer(thief, "CARRYING_ALREADY", nil, "error")
		return false, nil
	end
	if Registry.Economy.ShieldLeft(ownerData) > 0 then
		Registry.Remotes.NotifyPlayer(thief, "VICTIM_SHIELD", nil, "error")
		return false, nil
	end
	local thiefStand = Registry.Stands.Of(thief)
	if not thiefStand then
		return false, nil
	end
	return true, owner
end

local function startCarry(carry: Carry)
	local thiefData = Registry.Economy.Data(carry.Thief)
	if thiefData and not thiefData.ShieldOff then
		local hadShield = Registry.Economy.ShieldLeft(thiefData) > 0
		thiefData.ShieldOff = true
		if hadShield then
			Registry.Remotes.NotifyPlayer(carry.Thief, "SHIELD_LOST", nil, "warning")
			local stand = Registry.Stands.Of(carry.Thief)
			if stand then
				Registry.Stands.RefreshInfo(stand)
			end
		end
	end
	carrying[carry.Thief] = carry
	carry.Thief:SetAttribute("CarryEnd", workspace:GetServerTimeNow() + S.MaxCarry)
	attachVisual(carry)
	refreshSpeed(carry.Thief)
	refreshSpeed(carry.Owner)
	Registry.Remotes.NotifyPlayer(carry.Owner, "STEAL_START_VICTIM", { name = carry.Thief.DisplayName, what = whatKey(carry) }, "alarm")
	Registry.Remotes.NotifyPlayer(carry.Thief, "STEAL_START_THIEF", nil, "warning")
	Registry.Economy.Log(carry.Thief, "StealStart_" .. carry.Kind)
	Registry.Economy.Push(carry.Thief)
end

function Steal.GrabHen(thief: Player, stand: any, uid: string)
	local model = stand.HenModels[uid]
	if not model or carriedHens[uid] then
		return
	end
	local ok, owner = canSteal(thief, stand, model.PrimaryPart)
	if not ok or not owner then
		return
	end
	if Registry.Stands.IsGateClosed(stand) then
		Registry.Remotes.NotifyPlayer(thief, "GATE_CLOSED", nil, "error")
		return
	end
	local thiefData = Registry.Economy.Data(thief)
	if #thiefData.Hens >= Registry.Economy.UpgradeValue(thiefData, "Yard") then
		Registry.Remotes.NotifyPlayer(thief, "NO_ROOM_HEN", nil, "error")
		return
	end
	local ownerData = Registry.Economy.Data(owner)
	local henId = nil
	for _, hen in ownerData.Hens do
		if hen.U == uid then
			henId = hen.Id
		end
	end
	if not henId then
		return
	end
	local root = rootOf(thief) :: BasePart
	local carry: Carry = {
		Kind = "hen",
		Thief = thief,
		Owner = owner,
		OwnerStand = stand,
		HenUid = uid,
		HenId = henId,
		Items = nil,
		Start = os.clock(),
		From = root.Position,
		LastPos = nil,
		LastTime = nil,
		Strikes = 0,
		Model = nil,
		Done = false,
	}
	carriedHens[uid] = carry
	Registry.Stands.RefreshHens(stand) -- a galinha some do quintal
	startCarry(carry)
end

function Steal.GrabBasket(thief: Player, stand: any)
	local counter = stand.Parts.Counter
	local ok, owner = canSteal(thief, stand, counter)
	if not ok or not owner then
		return
	end
	local ownerRoot = rootOf(owner)
	if ownerRoot and (ownerRoot.Position - counter.Position).Magnitude <= S.OwnerGuardDistance then
		Registry.Remotes.NotifyPlayer(thief, "OWNER_GUARD", nil, "error")
		return
	end
	local ownerData = Registry.Economy.Data(owner)
	local thiefData = Registry.Economy.Data(thief)
	if #ownerData.Showcase == 0 then
		Registry.Remotes.NotifyPlayer(thief, "SHOWCASE_EMPTY", nil, "error")
		return
	end
	local space = Registry.Economy.UpgradeValue(thiefData, "Basket") - #thiefData.Basket
	if space <= 0 then
		Registry.Remotes.NotifyPlayer(thief, "NO_ROOM_BASKET", nil, "error")
		return
	end
	-- leva os mais valiosos
	local order = {}
	for index in ownerData.Showcase do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		return Registry.Economy.ItemValue(ownerData.Showcase[a]) > Registry.Economy.ItemValue(ownerData.Showcase[b])
	end)
	local take = {}
	for i = 1, math.min(S.BasketMax, space, #order) do
		take[order[i]] = true
	end
	local items, kept = {}, {}
	for index, item in ownerData.Showcase do
		if take[index] then
			table.insert(items, item)
		else
			table.insert(kept, item)
		end
	end
	ownerData.Showcase = kept
	Registry.Stands.RefreshShowcase(stand)
	Registry.Economy.Push(owner)
	local root = rootOf(thief) :: BasePart
	startCarry({
		Kind = "basket",
		Thief = thief,
		Owner = owner,
		OwnerStand = stand,
		HenUid = nil,
		HenId = nil,
		Items = items,
		Start = os.clock(),
		From = root.Position,
		LastPos = nil,
		LastTime = nil,
		Strikes = 0,
		Model = nil,
		Done = false,
	})
end

function Steal.TakeBack(player: Player, carry: Carry)
	if carry.Done or player == carry.Thief then
		return
	end
	local root = rootOf(player)
	local thiefRoot = rootOf(carry.Thief)
	if not root or not thiefRoot or (root.Position - thiefRoot.Position).Magnitude > S.PromptDistance + 4 then
		return
	end
	returnToOwner(carry, "takeback")
	Registry.Remotes.NotifyPlayer(carry.Thief, "TOOK_BACK", { name = player.DisplayName }, "error")
	if player ~= carry.Owner and carry.Owner.Parent then
		Registry.Remotes.NotifyPlayer(carry.Owner, "TOOK_BACK", { name = player.DisplayName }, "success")
	end
end

-- Quem sai do jogo: devolve o que estava carregando, e o que estavam roubando DELE volta antes do save
function Steal.OnPlayerRemoving(player: Player)
	local own = carrying[player]
	if own then
		returnToOwner(own, "left")
	end
	for _, carry in carrying do
		if carry.Owner == player then
			returnToOwner(carry, "left")
		end
	end
end

function Steal.Init()
	task.spawn(function()
		while true do
			task.wait(0.15)
			for thief, carry in carrying do
				local ok, err = pcall(function()
					if carry.Done then
						carrying[thief] = nil
						return
					end
					local root, humanoid = rootOf(thief)
					local now = os.clock()
					local teleported = false
					if root and humanoid then
						local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
						if carry.LastPos and carry.LastTime then
							local dt = math.max(now - carry.LastTime, 0.05)
							local maxStep = (humanoid.WalkSpeed * 2 + 30) * dt + 8
							if (flat - carry.LastPos).Magnitude > maxStep then
								carry.Strikes += 1
								teleported = carry.Strikes >= 2 -- uma folga para pico de lag
							else
								carry.Strikes = 0
							end
						end
						carry.LastPos = flat
						carry.LastTime = now
					end
					local weldOk = carry.Model ~= nil and carry.Model.Parent ~= nil
					if not root or not humanoid or humanoid.Health <= 0 or not weldOk then
						returnToOwner(carry, "dropped")
					elseif teleported then
						returnToOwner(carry, "invalid")
					elseif now - carry.Start > S.MaxCarry then
						returnToOwner(carry, "timeout")
					elseif carry.OwnerStand.Owner ~= carry.Owner then
						returnToOwner(carry, "invalid")
					else
						local home = Registry.Stands.Of(thief)
						if home and Registry.Stands.IsInside(home, root.Position) then
							local distance = (root.Position - carry.From).Magnitude
							local minimumTime = distance / (humanoid.WalkSpeed * 1.5 + 6)
							if now - carry.Start >= minimumTime then
								complete(carry)
							else
								returnToOwner(carry, "invalid")
							end
						end
					end
				end)
				if not ok then
					warn("[Steal] erro:", err)
					pcall(returnToOwner, carry, "dropped")
					carrying[thief] = nil
				end
			end
		end
	end)
end

return Steal
