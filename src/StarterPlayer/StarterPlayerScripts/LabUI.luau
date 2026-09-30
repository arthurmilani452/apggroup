--[[
	LabUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Parte 21: MIX LAB (laboratório atrás das bases). Junte 2 bichinhos da mochila e crie um HÍBRIDO!
	  • toque em 2 bichinhos da lista; se a dupla tem receita, o botão MIX acende
	  • receita que você ainda não descobriu aparece como "???" (surpresa!)
	  • dupla sem receita: nada é gasto
	  • RECIPES mostra o livro de receitas (descobertas + dicas das que faltam)
	Tudo é conferido no servidor (Pets.Mix).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Critters = require(Shared:WaitForChild("Critters"))
local Hybrids = require(Shared:WaitForChild("Hybrids"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local LabUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

type Item = { K: string, Id: string, M: string?, B: number?, S: boolean? }

local function itemName(item: Item): string
	local def = Critters.ById[item.Id]
	return (if item.S then "Shiny " else "") .. (if item.M then item.M .. " " else "") .. (if def then def.Name else "?")
end

function LabUI.Init(ctx)
	local frame, content = ctx.makePanel("Lab", "MIX LAB", C.Teal)
	content.Position = UDim2.fromOffset(16, 200)
	content.Size = UDim2.new(1, -32, 1, -212)
	local grid = create("UIGridLayout", {
		CellSize = UDim2.fromOffset(142, 54),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = content,
	})

	local items: { Item } = {}
	local known: { [string]: boolean } = {}
	local pickA: string? = nil
	local pickB: string? = nil
	local showRecipes = false

	local function box(x: number, width: number, text: string): (Frame, TextLabel)
		local holder = create("Frame", {
			Position = UDim2.fromOffset(x, 68),
			Size = UDim2.fromOffset(width, 66),
			BackgroundColor3 = C.Row,
			ZIndex = 6,
			Parent = frame,
		}, { corner(14), UI.border(C.Teal, 2) })
		local textLabel = label({ Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5), Text = text, TextWrapped = true, ZIndex = 6, Parent = holder })
		return holder, textLabel
	end
	local slotA, slotAText = box(16, 176, "Pick critter 1")
	label({ Position = UDim2.fromOffset(194, 68), Size = UDim2.fromOffset(34, 66), Text = "+", TextColor3 = C.Gold, ZIndex = 6, Parent = frame })
	local slotB, slotBText = box(230, 176, "Pick critter 2")
	label({ Position = UDim2.fromOffset(408, 68), Size = UDim2.fromOffset(28, 66), Text = "=", TextColor3 = C.Gold, ZIndex = 6, Parent = frame })
	local _, resultText = box(438, 186, "?")

	local render: () -> ()
	local mixButton, mixText = button({
		Position = UDim2.fromOffset(16, 142),
		Size = UDim2.fromOffset(300, 48),
		BackgroundColor3 = C.Gray,
		ZIndex = 6,
		Parent = frame,
	}, "MIX!", function()
		local a = pickA
		local b = pickB
		if not a or not b then
			ctx.toast("Pick 2 critters from your backpack first!", "info")
			return
		end
		ctx.play("Click")
		ctx.RequestEvent:FireServer("Mix", { A = a, B = b })
	end)
	local _, recipesText = button({
		Position = UDim2.fromOffset(324, 142),
		Size = UDim2.fromOffset(300, 48),
		BackgroundColor3 = C.Purple,
		ZIndex = 6,
		Parent = frame,
	}, "RECIPES", function()
		ctx.play("Click")
		showRecipes = not showRecipes
		render()
	end)

	local function find(key: string?): Item?
		if not key then
			return nil
		end
		for _, item in items do
			if item.K == key then
				return item
			end
		end
		return nil
	end

	local function clearList()
		for _, child in content:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function renderRecipes()
		grid.CellSize = UDim2.new(1, -8, 0, 54)
		local count = 0
		for order, recipe in Hybrids.Recipes do
			local result = Critters.ById[recipe.Result]
			local a, b = Critters.ById[recipe.A], Critters.ById[recipe.B]
			local found = known[recipe.Result] == true
			if found then
				count += 1
			end
			local row = create("Frame", { LayoutOrder = order, BackgroundColor3 = C.Row, ZIndex = 5, Parent = content }, { corner(12) })
			local rarity = result and Config.RarityByName[result.Rarity]
			label({
				Size = UDim2.new(1, -16, 1, -8),
				Position = UDim2.fromOffset(8, 4),
				Text = if found and a and b and result
					then ("%s + %s = %s"):format(a.Name, b.Name, result.Name)
					else "??? + ??? = ???   HINT: " .. recipe.Hint,
				TextColor3 = if found and rarity then rarity.Color else Color3.fromRGB(200, 210, 230),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 1.5,
				ZIndex = 5,
				Parent = row,
			})
		end
		recipesText.Text = ("BACK  (%d/%d found)"):format(count, #Hybrids.Recipes)
	end

	local function renderItems()
		grid.CellSize = UDim2.fromOffset(142, 54)
		local count = 0
		for _ in known do
			count += 1
		end
		recipesText.Text = ("RECIPES %d/%d"):format(count, #Hybrids.Recipes)
		local list = table.clone(items)
		table.sort(list, function(x, y)
			local dx, dy = Critters.ById[x.Id], Critters.ById[y.Id]
			if dx.Name ~= dy.Name then
				return dx.Name < dy.Name
			end
			return x.K < y.K
		end)
		for order, item in list do
			local def = Critters.ById[item.Id]
			local rarity = Config.RarityByName[def.Rarity]
			local picked = item.K == pickA or item.K == pickB
			local cell = create("Frame", {
				LayoutOrder = order,
				BackgroundColor3 = if picked then C.Teal else C.Row,
				ZIndex = 5,
				Parent = content,
			}, { corner(12), UI.border(rarity.Color, 2) })
			label({
				Size = UDim2.new(1, -8, 1, -6),
				Position = UDim2.fromOffset(4, 3),
				Text = itemName(item) .. (if item.S then "\n(can't mix)" else "\n" .. def.Rarity),
				TextWrapped = true,
				TextColor3 = if item.S then C.Gold else C.White,
				StrokeThickness = 1.5,
				ZIndex = 5,
				Parent = cell,
			})
			local tap = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = cell })
			tap.Activated:Connect(function()
				ctx.play("Click")
				if item.S then
					ctx.toast("Shiny critters are too special to mix!", "info")
					return
				end
				if pickA == item.K then
					pickA = nil
				elseif pickB == item.K then
					pickB = nil
				elseif not pickA then
					pickA = item.K
				else
					pickB = item.K
				end
				render()
			end)
		end
		if #list == 0 then
			local empty = create("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, ZIndex = 5, Parent = content })
			label({ Size = UDim2.fromScale(1, 1), Text = "Your backpack is empty! Put critters in it (PICK UP)", TextWrapped = true, ZIndex = 5, Parent = empty })
			grid.CellSize = UDim2.new(1, -8, 0, 70)
		end
	end

	render = function()
		local a, b = find(pickA), find(pickB)
		pickA = if a then pickA else nil
		pickB = if b then pickB else nil
		slotAText.Text = if a then itemName(a) else "Pick critter 1"
		slotBText.Text = if b then itemName(b) else "Pick critter 2"
		local recipe = if a and b then Hybrids.Find(a.Id, b.Id) else nil
		if recipe then
			local result = Critters.ById[recipe.Result]
			resultText.Text = if known[recipe.Result] and result then result.Name else "??? (new!)"
			resultText.TextColor3 = C.Gold
			mixButton.BackgroundColor3 = C.Green
			mixText.Text = "MIX!"
		elseif a and b then
			resultText.Text = "These don't mix"
			resultText.TextColor3 = Color3.fromRGB(255, 150, 150)
			mixButton.BackgroundColor3 = C.Gray
			mixText.Text = "TRY ANOTHER PAIR"
		else
			resultText.Text = "?"
			resultText.TextColor3 = C.White
			mixButton.BackgroundColor3 = C.Gray
			mixText.Text = "MIX!"
		end
		if not frame.Visible then
			return
		end
		clearList()
		if showRecipes then
			renderRecipes()
		else
			renderItems()
		end
	end

	ctx.InventoryEvent.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		items = {}
		if type(payload.Items) == "table" then
			for _, item in payload.Items do
				if type(item) == "table" and type(item.K) == "string" and Critters.ById[item.Id] then
					table.insert(items, item)
				end
			end
		end
		known = {}
		if type(payload.Recipes) == "table" then
			for _, id in payload.Recipes do
				known[id] = true
			end
		end
		render()
	end)

	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "Mixed" and type(data) == "table" then
			local def = Critters.ById[tostring(data.Critter)]
			pickA, pickB = nil, nil
			ctx.play("Rare")
			ctx.flash(C.Teal, 0.7)
			ctx.bigText(if data.New then "NEW HYBRID!" else "MIXED!", C.Gold)
			Juice.Confetti(ctx.gui, 100, { C.Teal, C.Gold, C.White })
			Juice.Shake(0.5, 0.5)
			if def then
				ctx.toast(("You made %s%s! It's in your backpack."):format(if data.Mutation then data.Mutation .. " " else "", def.Name), "rare")
			end
		elseif kind == "MixFail" then
			ctx.play("Error")
			UI.shake(slotA)
			UI.shake(slotB)
		end
	end)

	ctx.panelOpened.Lab = function()
		ctx.RequestEvent:FireServer("InventorySync")
		render()
	end
	return frame
end

return LabUI
