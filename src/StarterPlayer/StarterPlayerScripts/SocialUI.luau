--[[
	SocialUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Parte 24 (v11): botão "FRIENDS" no menu, com 2 abas:
	  • PLAYERS: quem está no servidor. VISIT (vai até a entrada da base), GIFT (dá um bichinho da mochila;
	    a outra pessoa precisa aceitar) e CLAN+ (convida para o seu clã)
	  • CLAN: criar um clã (nome filtrado pelo Roblox), ver os membros, o bônus e sair
	Também: botão LIKE nos postes das bases (só aparece nas bases dos outros), pedidos de presente/clã
	(sempre com "tem certeza?") e o botão de FOTO ao lado do dinheiro.
]]

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Critters = require(Shared:WaitForChild("Critters"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local SocialUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

function SocialUI.Init(ctx)
	local player = Players.LocalPlayer
	local frame, content = ctx.makePanel("Social", "FRIENDS & CLAN", C.Pink)
	content.Position = UDim2.fromOffset(16, 116)
	content.Size = UDim2.new(1, -32, 1, -128)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })

	local state: any = { Likes = 0, LikedToday = {}, GiftsLeft = Config.GiftsPerDay, Clan = nil }
	local bag: { any } = {} -- mochila (para escolher o presente)
	local tab = "PLAYERS"
	local giftTarget: Player? = nil
	local render: () -> ()

	local tabBar = create("Frame", {
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 0, 44),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = frame,
	}, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local tabButtons = {}
	for order, name in { "PLAYERS", "CLAN" } do
		tabButtons[name] = button({ LayoutOrder = order, Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = C.Row, ZIndex = 6, Parent = tabBar }, name, function()
			ctx.play("Click")
			tab = name
			giftTarget = nil
			render()
		end)
	end

	ctx.menuButton(-2, "\u{1F46B}", "FRIENDS", C.Pink, function()
		ctx.openPanel("Social")
	end)

	local function clear()
		for _, child in content:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function row(order: number, height: number, color: Color3?): Frame
		return create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -12, 0, height), BackgroundColor3 = color or C.Row, ZIndex = 5, Parent = content }, { corner(12) })
	end

	local function small(parent: Instance, order: number, text: string, color: Color3, onClick: () -> ())
		button({ LayoutOrder = order, Size = UDim2.new(0.33, -6, 1, 0), BackgroundColor3 = color, ZIndex = 6, Parent = parent }, text, onClick)
	end

	local function note(order: number, text: string)
		local box = row(order, 44, C.Panel)
		label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = text, TextWrapped = true, TextColor3 = Color3.fromRGB(200, 215, 240), ZIndex = 5, Parent = box })
	end

	---------------------------------------------------------------------
	-- PLAYERS
	---------------------------------------------------------------------
	local function renderGiftPicker(target: Player)
		note(0, ("Pick a critter from your backpack to give to %s (%d gifts left today)"):format(target.DisplayName, state.GiftsLeft or 0))
		if #bag == 0 then
			note(1, "Your backpack is empty! Use PICK UP on a critter in your base first.")
		end
		for order, item in bag do
			local def = Critters.ById[item.Id]
			if def then
				local box = row(order, 52)
				local rarity = Config.RarityByName[def.Rarity]
				label({
					Position = UDim2.fromOffset(12, 4),
					Size = UDim2.new(0.66, -12, 1, -8),
					Text = (if item.S then "Shiny " else "") .. (if item.M then item.M .. " " else "") .. def.Name .. "  (" .. def.Rarity .. ")",
					TextColor3 = rarity.Color,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
					Parent = box,
				})
				button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.new(0.3, -8, 0, 40),
					BackgroundColor3 = C.Pink,
					ZIndex = 6,
					Parent = box,
				}, "GIVE", function()
					UI.confirm(ctx.gui, "GIVE THIS CRITTER?", ("Give %s to %s?\nIt leaves your backpack if they accept. You can't undo it."):format(def.Name, target.DisplayName), "GIVE", C.Pink, function()
						ctx.RequestEvent:FireServer("Gift", { To = target.UserId, Key = item.K })
						giftTarget = nil
						render()
					end, ctx.scaleNow)
				end)
			end
		end
		local back = row(100, 48, C.Panel)
		button({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -8), BackgroundColor3 = C.Gray, ZIndex = 6, Parent = back }, "BACK", function()
			giftTarget = nil
			render()
		end)
	end

	local function renderPlayers()
		if giftTarget and giftTarget.Parent then
			renderGiftPicker(giftTarget)
			return
		end
		note(0, ("Your base has %d \u{2764} likes. Visit bases and tap the \u{2764} post at their gate (1 like per base per day)."):format(state.Likes or 0))
		local order = 1
		local myClan = state.Clan
		for _, other in Players:GetPlayers() do
			if other ~= player then
				order += 1
				local box = row(order, 92)
				local clanName = other:GetAttribute("ClanName")
				label({
					Position = UDim2.fromOffset(12, 4),
					Size = UDim2.new(1, -24, 0, 30),
					Text = other.DisplayName .. (if typeof(clanName) == "string" then "  [" .. clanName .. "]" else "") .. ("   \u{2764} %d"):format(tonumber(other:GetAttribute("Likes")) or 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
					Parent = box,
				})
				local buttons = create("Frame", {
					Position = UDim2.fromOffset(8, 40),
					Size = UDim2.new(1, -16, 0, 44),
					BackgroundTransparency = 1,
					ZIndex = 6,
					Parent = box,
				}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
				small(buttons, 1, "VISIT", C.Blue, function()
					ctx.play("Click")
					ctx.RequestEvent:FireServer("Visit", other.UserId)
					frame.Visible = false
				end)
				-- regras do país (PolicyService): onde trocar itens pagos é proibido, presentes ficam desligados
				local canGift = player:GetAttribute("PolicyTradingAllowed") == true and other:GetAttribute("PolicyTradingAllowed") == true
				small(buttons, 2, "GIFT", if canGift then C.Pink else C.Gray, function()
					ctx.play("Click")
					if not canGift then
						ctx.toast(if player:GetAttribute("PolicyTradingAllowed") == true then other.DisplayName .. " can't receive gifts." else "Gifts are not available where you live.", "info")
						return
					end
					giftTarget = other
					ctx.RequestEvent:FireServer("InventorySync")
					render()
				end)
				local canInvite = myClan ~= nil and typeof(clanName) ~= "string"
				small(buttons, 3, "CLAN +", if canInvite then C.Teal else C.Gray, function()
					if not myClan then
						ctx.toast("Make a clan first in the CLAN tab!", "info")
						return
					end
					if not canInvite then
						ctx.toast(other.DisplayName .. " is already in a clan.", "info")
						return
					end
					ctx.play("Click")
					ctx.RequestEvent:FireServer("ClanInvite", other.UserId)
				end)
			end
		end
		if order == 1 then
			note(2, "You're the only one here! Press INVITE to call your friends (you get a FREE egg for each new friend who joins).")
		end
	end

	---------------------------------------------------------------------
	-- CLAN
	---------------------------------------------------------------------
	local function renderClan()
		local clan = state.Clan
		if not clan then
			note(0, ("Make a clan with up to %d friends! Each clanmate in your server gives +%d%% cash (max +%d%%)."):format(
				Config.ClanMax,
				math.floor(Config.ClanBonusPerMate * 100),
				math.floor(Config.ClanBonusMax * 100)
			))
			local box = row(1, 60)
			local input = create("TextBox", {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(0.62, -12, 1, -16),
				BackgroundColor3 = C.White,
				PlaceholderText = "Clan name (3-20 letters)",
				Text = "",
				ClearTextOnFocus = false,
				TextScaled = true,
				Font = Enum.Font.FredokaOne,
				TextColor3 = C.Dark,
				ZIndex = 6,
				Parent = box,
			}, { corner(10) })
			button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0.36, -8, 1, -16),
				BackgroundColor3 = C.Green,
				ZIndex = 6,
				Parent = box,
			}, "CREATE", function()
				local name = input.Text
				if #name < 3 then
					ctx.toast("Type a clan name first (3 to 20 letters).", "info")
					return
				end
				ctx.play("Click")
				ctx.RequestEvent:FireServer("ClanCreate", string.sub(name, 1, 20))
			end)
			note(2, "Clan names are checked by Roblox's filter. Be nice!")
			return
		end
		local top = row(0, 72, C.Panel)
		label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 34), Text = "[" .. tostring(clan.Name) .. "]", TextColor3 = Color3.fromRGB(140, 230, 255), ZIndex = 5, Parent = top })
		label({
			Position = UDim2.fromOffset(12, 40),
			Size = UDim2.new(1, -24, 0, 26),
			Text = ("%d/%d members  |  bonus now: +%d%% cash"):format(#(clan.Members or {}), Config.ClanMax, math.floor((tonumber(clan.Bonus) or 0) * 100 + 0.5)),
			TextColor3 = Color3.fromRGB(200, 215, 240),
			ZIndex = 5,
			Parent = top,
		})
		for order, member in clan.Members or {} do
			local box = row(order, 40)
			label({
				Position = UDim2.fromOffset(12, 4),
				Size = UDim2.new(1, -24, 1, -8),
				Text = (if member.Id == clan.Owner then "\u{1F451} " else "") .. tostring(member.Name) .. (if member.Online then "  (here)" else ""),
				TextColor3 = if member.Online then Color3.fromRGB(140, 255, 150) else C.White,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5,
				Parent = box,
			})
		end
		local leave = row(100, 52, C.Panel)
		button({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -8), BackgroundColor3 = C.Red, ZIndex = 6, Parent = leave }, "LEAVE CLAN", function()
			UI.confirm(ctx.gui, "LEAVE CLAN?", "Leave your clan? You can join another one later.", "LEAVE", C.Red, function()
				ctx.RequestEvent:FireServer("ClanLeave")
			end, ctx.scaleNow)
		end)
	end

	render = function()
		for name, btn in tabButtons do
			btn.BackgroundColor3 = if name == tab then C.Pink else C.Row
		end
		if not frame.Visible then
			return
		end
		clear()
		if tab == "PLAYERS" then
			renderPlayers()
		else
			renderClan()
		end
	end

	ctx.RemotesFolder:WaitForChild("SocialSync").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			state = payload
			render()
		end
	end)
	ctx.InventoryEvent.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Items) == "table" then
			bag = payload.Items
			if giftTarget then
				render()
			end
		end
	end)
	for _, attribute in { "ClanName" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			ctx.RequestEvent:FireServer("SocialSync")
		end)
	end

	-- Pedidos que chegam: presente e convite de clã (sempre perguntam; um de cada vez, em fila)
	local queue: { any } = {}
	local showing = false
	local function showNext()
		if showing or #queue == 0 then
			return
		end
		if ctx.gui:FindFirstChild("ConfirmDialog") then
			task.delay(1, showNext) -- espera a outra janela fechar (não fecha a janela do jogador)
			return
		end
		local request = table.remove(queue, 1)
		showing = true
		ctx.play("Rare")
		local answered = false
		local dialog
		if request.Kind == "GiftOffer" then
			dialog = UI.confirm(ctx.gui, "A GIFT FOR YOU!", ("%s wants to give you %s. Accept?"):format(tostring(request.From), tostring(request.Name)), "ACCEPT", C.Green, function()
				answered = true
				ctx.RequestEvent:FireServer("GiftAnswer", { OfferId = request.OfferId, Accept = true })
			end, ctx.scaleNow)
		else
			dialog = UI.confirm(ctx.gui, "CLAN INVITE", ("%s invited you to the clan [%s]. Join?"):format(tostring(request.From), tostring(request.Name)), "JOIN", C.Teal, function()
				answered = true
				ctx.RequestEvent:FireServer("ClanAnswer", true)
			end, ctx.scaleNow)
		end
		dialog.Destroying:Connect(function()
			task.delay(0.3, function()
				if not answered and request.Kind == "GiftOffer" then
					ctx.RequestEvent:FireServer("GiftAnswer", { OfferId = request.OfferId, Accept = false })
				end
				showing = false
				showNext()
			end)
		end)
	end
	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if (kind == "GiftOffer" or kind == "ClanInvite") and type(data) == "table" then
			if #queue < 3 then
				data.Kind = kind
				table.insert(queue, data)
			end
			showNext()
		elseif kind == "Liked" then
			ctx.play("Coin")
			Juice.Confetti(ctx.gui, 25, { C.Pink, C.White })
		end
	end)

	-- LIKE: o poste só aparece nas bases dos OUTROS
	local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")
	local function filterLike(plot: Instance)
		local post = plot:FindFirstChild("LikePost")
		local prompt = post and post:FindFirstChild("LikePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			local owner = plot:GetAttribute("OwnerUserId")
			prompt.Enabled = typeof(owner) == "number" and owner ~= player.UserId
			prompt.ObjectText = tostring(plot:GetAttribute("OwnerName") or "Base") .. "'s base"
		end
	end
	for _, plot in plots:GetChildren() do
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			filterLike(plot)
		end)
		plot.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "LikePrompt" then
				filterLike(plot)
			end
		end)
		filterLike(plot)
	end

	-- FOTO: salvar na galeria ou compartilhar (quem abrir o link entra pelo seu convite)
	local cashPanel = ctx.gui:FindFirstChild("CashPanel")
	button({
		AnchorPoint = Vector2.new(0, 0),
		Position = if cashPanel then UDim2.new(1, 8, 0, 4) else UDim2.new(0.5, 170, 0, 12),
		Size = UDim2.fromOffset(48, 36),
		BackgroundColor3 = C.Panel,
		Parent = cashPanel or ctx.gui,
	}, "\u{1F4F7}", function()
		ctx.play("Click")
		-- regras do país (PolicyService): onde compartilhar conteúdo é proibido, só salva na galeria
		local canShare = player:GetAttribute("PolicyShareAllowed") == true
		local ok = pcall(function()
			CaptureService:CaptureScreenshot(function(contentId)
				ctx.flash(C.White, 0.6)
				local function save()
					pcall(function()
						(CaptureService :: any):PromptSaveCapturesToGallery({ contentId }, function() end)
					end)
				end
				if not canShare then
					save()
					return
				end
				pcall(function()
					(CaptureService :: any):PromptShareCapture(contentId, "inv:" .. player.UserId, function() end, save)
				end)
			end)
		end)
		if not ok then
			ctx.toast("Photos only work in the published game.", "info")
		end
	end)

	ctx.panelOpened.Social = function()
		ctx.RequestEvent:FireServer("SocialSync")
		ctx.RequestEvent:FireServer("InventorySync")
		render()
	end
	Players.PlayerAdded:Connect(function()
		task.delay(2, render)
	end)
	Players.PlayerRemoving:Connect(function(left)
		if left == giftTarget then
			giftTarget = nil
		end
		task.defer(render)
	end)
	return frame
end

return SocialUI
