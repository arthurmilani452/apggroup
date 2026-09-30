--[[
	InventoryUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Tela "CRITTERS": mochila + bichinhos da base, pets equipados, filtros e fusão.
	  • toque num card para escolher; os botões de baixo mudam conforme o card
	  • EQUIP BEST equipa os 3 melhores pets de uma vez
	  • FUSE: 5 iguais viram 1 Gold; 5 Gold viram 1 Rainbow (sempre pede confirmação)
	  • v9: estágio (bebê/adulto/gigante), SHINY e FEED ALL (comida para a base: +15% por 10 min)
	A tela só PEDE; o servidor (Pets.luau) confere tudo e manda a lista nova.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Critters = require(Shared:WaitForChild("Critters"))
local Format = require(Shared:WaitForChild("Format"))
local Builder = require(Shared:WaitForChild("CritterBuilder"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local InventoryUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

type Entry = { Key: string, Where: string, K: string?, U: number?, Id: string, M: string?, B: number?, S: boolean?, Equipped: boolean }

local WHERE = { "All", "Backpack", "Base", "Pets" }
local SORTS = { "Best", "Rarity", "Name" }

local function entryName(entry): string
	local def = Critters.ById[entry.Id]
	return (if entry.S then "Shiny " else "") .. (if entry.M then entry.M .. " " else "") .. (if def then def.Name else "?")
end

-- Estágio de crescimento pela data de nascimento (B)
local function entryStage(entry)
	local born = tonumber(entry.B) or 0
	local _, stage = Config.GrowthStage(workspace:GetServerTimeNow() - born)
	return stage
end

-- Renda na base (com estágio e shiny; sem o bônus de carinho/comida, que é passageiro)
local function entryIncome(entry): number
	local def = Critters.ById[entry.Id]
	if not def then
		return 0
	end
	return def.Income * Config.IncomeMultiplier(entry.M) * (if entry.S then Config.ShinyIncome else 1) * entryStage(entry).Income
end

function InventoryUI.Init(ctx)
	local player = game:GetService("Players").LocalPlayer
	local frame, content = ctx.makePanel("Critters", "CRITTERS", C.Teal)
	content.Position = UDim2.fromOffset(16, 152)
	content.Size = UDim2.new(1, -32, 1, -152 - 92)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(108, 140),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})

	-- Topo: resumo + EQUIP BEST
	local info = label({
		Position = UDim2.fromOffset(18, 64),
		Size = UDim2.new(0.5, -18, 0, 34),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = frame,
	})
	button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 62),
		Size = UDim2.new(0.25, -12, 0, 40),
		BackgroundColor3 = C.Green,
		ZIndex = 6,
		Parent = frame,
	}, "EQUIP BEST", function()
		ctx.play("Click")
		ctx.RequestEvent:FireServer("PetEquipBest")
	end)
	local feedCost = 0
	local _, feedText = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.75, -8, 0, 62),
		Size = UDim2.new(0.25, -12, 0, 40),
		BackgroundColor3 = C.Orange,
		ZIndex = 6,
		Parent = frame,
	}, "FEED ALL", function()
		ctx.play("Click")
		local cost = feedCost
		UI.confirm(
			ctx.gui,
			"FEED ALL?",
			("Feed every critter in your base for %s?\nThey earn +%d%% cash for 10 minutes. (Petting them is free: press T next to a critter!)"):format(
				Format.Money(cost),
				math.floor(Config.FeedBonus * 100)
			),
			"FEED!",
			C.Green,
			function()
				ctx.RequestEvent:FireServer("FeedAll", cost)
			end,
			ctx.scaleNow
		)
	end)

	-- Filtros (tocar troca a opção)
	local filters = { Where = 1, Rarity = 1, World = 1, Sort = 1 }
	local rarityOptions = { "All" }
	for _, rarity in Config.Rarities do
		table.insert(rarityOptions, rarity.Name)
	end
	local worldOptions = { "All" }
	for _, world in Config.Worlds do
		table.insert(worldOptions, world.Id)
	end
	table.insert(worldOptions, "special") -- clima, noite e híbridos
	local filterRow = create("Frame", {
		Position = UDim2.fromOffset(16, 106),
		Size = UDim2.new(1, -32, 0, 40),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = frame,
	}, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local render: () -> ()
	local function filterButton(order: number, key: string, options: { string }, names: (string) -> string)
		local btnText
		local _, text = button({
			LayoutOrder = order,
			Size = UDim2.new(0.25, -6, 1, 0),
			BackgroundColor3 = C.Row,
			ZIndex = 6,
			Parent = filterRow,
		}, "", function()
			ctx.play("Click")
			filters[key] = filters[key] % #options + 1
			btnText.Text = names(options[filters[key]])
			render()
		end)
		btnText = text
		btnText.Text = names(options[1])
	end
	filterButton(1, "Where", WHERE, function(value)
		return "Show: " .. value
	end)
	filterButton(2, "Rarity", rarityOptions, function(value)
		return "Rarity: " .. value
	end)
	filterButton(3, "World", worldOptions, function(value)
		local world = Config.WorldById[value]
		return "World: " .. (if world then string.split(world.Name, " ")[1] elseif value == "special" then "Special" else "All")
	end)
	filterButton(4, "Sort", SORTS, function(value)
		return "Sort: " .. value
	end)

	-- Barra de baixo: o card escolhido e as ações
	local actionBar = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -24, 0, 76),
		BackgroundColor3 = C.Row,
		ZIndex = 6,
		Parent = frame,
	}, { corner(14) })
	local selectedText = label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(0.34, -10, 1, -12),
		Text = "Tap a critter",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		ZIndex = 6,
		Parent = actionBar,
	})
	local actionHolder = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.66, -8, 0, 56),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = actionBar,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local actionSlots = {}
	for i = 1, 4 do
		local slot: any = { Callback = nil }
		local btn, text = button({
			LayoutOrder = i,
			Size = UDim2.new(0.25, -5, 1, 0),
			BackgroundColor3 = C.Gray,
			Visible = false,
			ZIndex = 6,
			Parent = actionHolder,
		}, "", function()
			if slot.Callback then
				ctx.play("Click")
				slot.Callback()
			end
		end)
		slot.Button = btn
		slot.Text = text
		actionSlots[i] = slot
	end

	local emptyLabel = label({
		Position = UDim2.fromOffset(30, 200),
		Size = UDim2.new(1, -60, 0, 80),
		Text = "",
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(200, 210, 230),
		StrokeThickness = 1.5,
		Visible = false,
		ZIndex = 6,
		Parent = frame,
	})

	-- Estado vindo do servidor
	local state = { Items = {}, Equipped = {}, Base = {}, Max = Config.InventoryMax, EquipMax = Config.PetEquipMax, FeedCost = 0 }
	local entries: { [string]: Entry } = {}
	local cards: { [string]: any } = {}
	local templates: { [string]: Model } = {}
	local selected: string? = nil

	local function template(id: string, mutation: string?): Model
		local key = id .. ":" .. (mutation or "")
		local cached = templates[key]
		if cached then
			return cached
		end
		local def = Critters.ById[id]
		local model = Builder.Build(def)
		local aura = model:FindFirstChild("Aura")
		if aura then
			aura:Destroy()
		end
		if mutation then
			Builder.ApplyMutation(model, mutation)
		end
		templates[key] = model
		return model
	end

	local function sameCount(id: string, mutation: string?): number
		local count = 0
		for _, entry in entries do
			if entry.Id == id and entry.M == mutation and not entry.S then -- shiny não entra na fusão
				count += 1
			end
		end
		return count
	end

	local function makeCard(entry: Entry)
		local def = Critters.ById[entry.Id]
		local rarity = Config.RarityByName[def.Rarity]
		local card = create("Frame", { BackgroundColor3 = C.Row, ZIndex = 5, Parent = content }, { corner(12) })
		local stroke = create("UIStroke", { Color = rarity.Color, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		local viewport = create("ViewportFrame", {
			Size = UDim2.new(1, -8, 0, 70),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(170, 170, 170),
			LightColor = C.White,
			LightDirection = Vector3.new(-0.4, -1, 0.6),
			ZIndex = 5,
			Parent = card,
		})
		local model = template(entry.Id, entry.M):Clone()
		model.Parent = viewport
		local boxCFrame, boxSize = model:GetBoundingBox()
		local radius = boxSize.Magnitude / 2
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(boxCFrame.Position + Vector3.new(radius * 0.8, radius * 0.6, -radius * 2.2), boxCFrame.Position)
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		label({ Position = UDim2.fromOffset(4, 76), Size = UDim2.new(1, -8, 0, 20), Text = def.Name, ZIndex = 5, Parent = card })
		local mutationInfo = entry.M and Config.MutationByName[entry.M]
		label({
			Position = UDim2.fromOffset(4, 96),
			Size = UDim2.new(1, -8, 0, 16),
			Text = (if entry.S then "SHINY " else "") .. string.upper(if entry.M then entry.M else def.Rarity),
			TextColor3 = if entry.S then C.Gold elseif mutationInfo then mutationInfo.Color else rarity.Color,
			ZIndex = 5,
			Parent = card,
		})
		local incomeLabel = label({
			Position = UDim2.fromOffset(4, 114),
			Size = UDim2.new(1, -8, 0, 18),
			Text = "",
			TextColor3 = Color3.fromRGB(140, 255, 140),
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = card,
		})
		-- estágio (canto de cima, à direita): BABY / GIANT
		local stageLabel = label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(50, 18),
			Text = "",
			TextColor3 = Color3.fromRGB(255, 220, 150),
			StrokeThickness = 1.5,
			ZIndex = 6,
			Parent = card,
		})
		local badge = create("Frame", {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(46, 20),
			BackgroundColor3 = C.Blue,
			ZIndex = 6,
			Parent = card,
		}, { corner(8) })
		local badgeText = label({ Size = UDim2.new(1, -4, 1, -2), Position = UDim2.fromOffset(2, 1), Text = "", StrokeThickness = 1, ZIndex = 6, Parent = badge })
		local tap = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 7, Parent = card })
		tap.Activated:Connect(function()
			ctx.play("Click")
			selected = entry.Key
			render()
		end)
		cards[entry.Key] = { Frame = card, Stroke = stroke, Rarity = rarity.Color, Badge = badge, BadgeText = badgeText, Income = incomeLabel, Stage = stageLabel }
	end

	local function setAction(i: number, text: string?, color: Color3?, callback: (() -> ())?)
		local slot = actionSlots[i]
		slot.Button.Visible = text ~= nil
		slot.Text.Text = text or ""
		slot.Button.BackgroundColor3 = color or C.Gray
		slot.Callback = callback
	end

	local function fuseAction(i: number, entry: Entry)
		local def = Critters.ById[entry.Id]
		local result = Config.FuseResult(entry.M)
		local count = sameCount(entry.Id, entry.M)
		if entry.S then
			setAction(i, "SHINY", C.Gray, function()
				ctx.toast("Shiny critters are too special to fuse!", "info")
			end)
			return
		end
		if not result then
			setAction(i, "MAX FUSE", C.Gray, function()
				ctx.toast("This critter can't be fused any further.", "info")
			end)
			return
		end
		local need = Config.FuseCount
		setAction(i, ("FUSE %d/%d"):format(math.min(count, need), need), if count >= need then C.Purple else C.Gray, function()
			if count < need then
				ctx.toast(("Get %d of the same %s to fuse them into a %s one!"):format(need, entryName(entry), string.upper(result)), "info")
				return
			end
			UI.confirm(
				ctx.gui,
				"FUSE?",
				("Fuse %d %s into 1 %s %s?\nIt makes x%d cash. The %d critters will be used up (backpack first)."):format(
					need,
					entryName(entry),
					string.upper(result),
					def.Name,
					Config.IncomeMultiplier(result),
					need
				),
				"FUSE!",
				C.Purple,
				function()
					ctx.RequestEvent:FireServer("PetFuse", { Id = entry.Id, M = entry.M or "" })
				end,
				ctx.scaleNow
			)
		end)
	end

	local function refreshActions()
		local entry = selected and entries[selected]
		if not entry then
			selected = nil
			selectedText.Text = "Tap a critter to see what you can do."
			for i = 1, 4 do
				setAction(i, nil)
			end
			return
		end
		local def = Critters.ById[entry.Id]
		local bonus = Config.PetBonusOf(def.Rarity, entry.M)
		selectedText.Text = ("%s (%s)\n%s/s  |  pet +%g%%"):format(entryName(entry), entryStage(entry).Name, Format.Money(entryIncome(entry)), math.floor(bonus * 1000 + 0.5) / 10)
		if entry.Where == "bag" then
			local key = entry.K :: string
			if entry.Equipped then
				setAction(1, "UNEQUIP", C.Gray, function()
					ctx.RequestEvent:FireServer("PetUnequip", key)
				end)
			else
				setAction(1, "EQUIP", C.Green, function()
					ctx.RequestEvent:FireServer("PetEquip", key)
				end)
			end
			setAction(2, "PLACE", C.Blue, function()
				ctx.RequestEvent:FireServer("PetPlace", key)
			end)
			fuseAction(3, entry)
			local price = math.floor(def.Price * Config.PriceMultiplier(entry.M) * (if entry.S then Config.ShinyIncome else 1) * Config.CritterSellRefund)
			setAction(4, "SELL " .. Format.Money(price), C.Red, function()
				UI.confirm(ctx.gui, "SELL?", ("Sell %s for %s?\nYou can't undo this."):format(entryName(entry), Format.Money(price)), "SELL", C.Red, function()
					ctx.RequestEvent:FireServer("PetSell", key)
				end, ctx.scaleNow)
			end)
		else
			local uid = entry.U :: number
			setAction(1, "PICK UP", C.Teal, function()
				ctx.RequestEvent:FireServer("PetStore", uid)
			end)
			fuseAction(2, entry)
			setAction(3, nil)
			setAction(4, nil)
		end
	end

	local function passes(entry: Entry): boolean
		local def = Critters.ById[entry.Id]
		local where = WHERE[filters.Where]
		local wanted = ({ Backpack = "bag", Base = "base" } :: { [string]: string })[where]
		if wanted and entry.Where ~= wanted then
			return false
		end
		if where == "Pets" and not entry.Equipped then
			return false
		end
		local rarity = rarityOptions[filters.Rarity]
		if rarity ~= "All" and def.Rarity ~= rarity then
			return false
		end
		local world = worldOptions[filters.World]
		if world ~= "All" and Config.IndexTabOf(def.World) ~= world then
			return false
		end
		return true
	end

	render = function()
		-- junta mochila + base
		local equippedSet = {}
		for _, key in state.Equipped do
			equippedSet[key] = true
		end
		local fresh: { [string]: Entry } = {}
		for _, item in state.Items do
			local key = "bag:" .. item.K
			fresh[key] = { Key = key, Where = "bag", K = item.K, Id = item.Id, M = item.M, B = item.B, S = item.S == true, Equipped = equippedSet[item.K] == true }
		end
		for _, item in state.Base do
			local key = "base:" .. item.U
			fresh[key] = { Key = key, Where = "base", U = item.U, Id = item.Id, M = item.M, B = item.B, S = item.Sh == true, Equipped = false }
		end
		entries = fresh
		for key, card in cards do
			if not fresh[key] then
				card.Frame:Destroy()
				cards[key] = nil
			end
		end
		if not frame.Visible then
			return -- os cards só são montados com a tela aberta (mais leve no celular)
		end

		local list = {}
		for key, entry in fresh do
			if passes(entry) then
				table.insert(list, entry)
			elseif cards[key] then
				cards[key].Frame.Visible = false
			end
		end
		local sort = SORTS[filters.Sort]
		table.sort(list, function(a, b)
			if a.Equipped ~= b.Equipped then
				return a.Equipped
			end
			local da, db = Critters.ById[a.Id], Critters.ById[b.Id]
			if sort == "Rarity" and da.Rarity ~= db.Rarity then
				return Config.RarityIndex[da.Rarity] > Config.RarityIndex[db.Rarity]
			elseif sort == "Name" and da.Name ~= db.Name then
				return da.Name < db.Name
			end
			local ia, ib = entryIncome(a), entryIncome(b)
			if ia ~= ib then
				return ia > ib
			end
			return a.Key < b.Key
		end)
		for order, entry in list do
			if not cards[entry.Key] then
				makeCard(entry)
			end
			local card = cards[entry.Key]
			card.Frame.Visible = true
			card.Frame.LayoutOrder = order
			local stage = entryStage(entry)
			card.Stage.Text = if stage.Name == "Adult" then "" else string.upper(stage.Name)
			card.Income.Text = Format.Money(entryIncome(entry)) .. "/s"
			if entry.Equipped then
				card.Badge.Visible = true
				card.Badge.BackgroundColor3 = C.Green
				card.BadgeText.Text = "PET"
			elseif entry.Where == "base" then
				card.Badge.Visible = true
				card.Badge.BackgroundColor3 = C.Blue
				card.BadgeText.Text = "BASE"
			else
				card.Badge.Visible = false
			end
			local isSelected = entry.Key == selected
			card.Stroke.Color = if isSelected then C.Gold else card.Rarity
			card.Stroke.Thickness = if isSelected then 5 else 3
		end

		local bonus = tonumber(player:GetAttribute("PetBonus")) or 0
		info.Text = ("Backpack %d/%d  |  Pets %d/%d  |  +%d%% cash"):format(#state.Items, state.Max, #state.Equipped, state.EquipMax, math.floor(bonus * 100 + 0.5))
		feedCost = tonumber(state.FeedCost) or 0
		feedText.Text = "FEED " .. Format.Money(feedCost)
		emptyLabel.Visible = #list == 0
		if #list == 0 then
			emptyLabel.Text = if next(fresh) == nil
				then "No critters yet! Hatch eggs, then press PICK UP (R) on a critter in your base to put it in your backpack."
				else "Nothing here with these filters."
		end
		refreshActions()
	end

	ctx.InventoryEvent.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		state = {
			Items = if type(payload.Items) == "table" then payload.Items else {},
			Equipped = if type(payload.Equipped) == "table" then payload.Equipped else {},
			Base = if type(payload.Base) == "table" then payload.Base else {},
			Max = tonumber(payload.Max) or Config.InventoryMax,
			EquipMax = tonumber(payload.EquipMax) or Config.PetEquipMax,
			FeedCost = tonumber(payload.FeedCost) or 0,
		}
		render()
	end)
	player:GetAttributeChangedSignal("PetBonus"):Connect(function()
		if frame.Visible then
			render()
		end
	end)

	-- Fusão deu certo: festa na tela
	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if kind ~= "Fused" or type(data) ~= "table" then
			return
		end
		ctx.play("Rare")
		Juice.Confetti(ctx.gui, 90)
		Juice.Shake(0.5, 0.5)
	end)

	ctx.panelOpened.Critters = function()
		ctx.RequestEvent:FireServer("InventorySync")
		render()
	end
end

return InventoryUI
