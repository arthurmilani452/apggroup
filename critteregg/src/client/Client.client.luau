--!nonstrict
--[[
	Tela do jogador (só MOSTRA e PEDE; quem decide é o servidor).
	  HUD (v66, "menos coisa na tela"): velocidade (rosa) e dinheiro (verde) embaixo à esquerda (celular: embaixo no meio);
	       5 botões à esquerda (Loja, Índice, Ovos, Pets, Presentes); 1 botão Menu à direita com o resto dentro
	       (Diário, Missões, Rebirth, Boosts, Códigos, Doces, Convidar, Som, Modo Lento, Admin);
	       2 relógios (noite + o evento mais importante) embaixo à direita (celular: em cima à direita);
	       painel da esteira com AUTO CORRER; faixa e avisos no topo. Textos em PT-BR se o Roblox estiver em português.
	  Janelas: Shop (melhorias, trilhas, boosts), Index (cartões 3D por zona + prêmios), Eggs, Pets/Sell,
	           Trails, Fuse, Boosts. As lojinhas do mapa abrem a janela delas quando você entra.
	  Mundo: placas das zonas verdes/vermelhas, seta guia, pose de carregar, bichinhos passeando, listras da esteira.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Critters = require(ReplicatedStorage.Shared:WaitForChild("Critters"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local net = ReplicatedStorage:WaitForChild("Net") :: RemoteEvent

local player = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TOUCH = UserInputService.TouchEnabled

---------------------------------------------------------------------
-- TEXTOS EM PORTUGUÊS (v66): Roblox em português = botões, Menu, Admin, esteira e dicas em PT-BR.
-- (os avisos que vêm do servidor continuam em inglês). Textos curtos para caber nos botões.
---------------------------------------------------------------------
local L: (string) -> string
do
	local PT_BR = false
	pcall(function()
		PT_BR = string.lower(string.sub(game:GetService("LocalizationService").RobloxLocaleId, 1, 2)) == "pt"
	end)
	local TEXTS: { [string]: { string } } = {
		Shop = { "Shop", "Loja" },
		Index = { "Index", "Índice" },
		Eggs = { "Eggs", "Ovos" },
		Pets = { "Pets", "Pets" },
		Gifts = { "Gifts", "Presentes" },
		Menu = { "Menu", "Menu" },
		Daily = { "Daily", "Diário" },
		Quests = { "Quests", "Missões" },
		Rebirth = { "Rebirth", "Renascer" },
		Boosts = { "Boosts", "Boosts" },
		Codes = { "Codes", "Códigos" },
		Candy = { "Candy", "Doces" },
		Invite = { "Invite", "Convidar" },
		InviteSub = { "+%d%% cash per friend playing", "+%d%% $ por amigo jogando" },
		Sound = { "Sound", "Som" },
		SlowMode = { "Slow Mode", "Modo Lento" },
		On = { "ON", "LIGADO" },
		Off = { "OFF", "DESLIGADO" },
		Admin = { "Admin", "Admin" },
		Ready = { "READY!", "PRONTO!" },
		AdminInfo = { "Runs in ALL servers - great for live streams!", "Vale em TODOS os servidores - ótimo para lives!" },
		AdminLuck = { "LUCK x%d (%d min)", "SORTE x%d (%d min)" },
		AdminGolden = { "GOLDEN RAIN", "CHUVA DOURADA" },
		AdminParty = { "UPDATE PARTY NOW", "FESTÃO AGORA" },
		AdminMoney = { "2x MONEY (%d min)", "2x DINHEIRO (%d min)" },
		AdminPumpkin = { "PUMPKIN RAIN", "CHUVA DE ABÓBORAS" },
		TapConfirm = { "TAP AGAIN TO CONFIRM", "TOQUE DE NOVO PARA CONFIRMAR" },
		AutoRun = { "AUTO RUN", "AUTO CORRER" },
		AutoRunOn = { "AUTO RUN: ON", "AUTO: LIGADO" },
		PerStep = { "+%s/step", "+%s/passo" },
		Streak = { "STREAK x%.2f", "SEQUÊNCIA x%.2f" },
		ToGo = { "%s: %s to go", "%s: faltam %s" },
		MaxZone = { "MAX SPEED ZONE!", "ZONA MÁXIMA!" },
		ZoneUnlocked = { "NEW ZONE UNLOCKED: %s!", "ZONA NOVA LIBERADA: %s!" },
		CarryRun = { "\u{1F3C3} RUN BACK TO THE SAFE ZONE!", "\u{1F3C3} VOLTE PARA A ZONA SEGURA!" },
		HintCarry = { "\u{1F3C3} Run back to the SAFE ZONE with the egg!", "\u{1F3C3} Volte para a ZONA SEGURA com o ovo!" },
		HintSteal = { "\u{1F95A} Go into %s and %s on an egg to STEAL it!", "\u{1F95A} Vá até %s e %s num ovo para ROUBAR!" },
		HoldButton = { "hold the button", "segure o botão" },
		HoldE = { "hold E", "segure E" },
		HintHatch = { "\u{1F423} Your egg is READY! Walk to it (or open Eggs) and HATCH it!", "\u{1F423} Seu ovo está PRONTO! Vá até ele (ou abra Ovos) e CHOQUE!" },
		HintGrowing = { "\u{23F3} Your egg is growing... steal MORE eggs while you wait!", "\u{23F3} Seu ovo está crescendo... roube MAIS ovos enquanto espera!" },
		HintIndex = { "\u{1F4D6} NEW CRITTER! Open the INDEX (left) and CLAIM your free cash!", "\u{1F4D6} BICHINHO NOVO! Abra o ÍNDICE (esquerda) e PEGUE o dinheiro grátis!" },
		HintBuyPen = { "\u{1F3E1} Buy PEN LEVEL 1 at the yellow board to unlock your TREADMILL!", "\u{1F3E1} Compre o CERCADO NÍVEL 1 na placa amarela para liberar a ESTEIRA!" },
		HintSavePen = { "\u{1F4B5} Your pets make money! Save %s to unlock the treadmill.", "\u{1F4B5} Seus pets dão dinheiro! Junte %s para liberar a esteira." },
		HintTread = { "\u{1F45F} Stand on your TREADMILL and tap AUTO RUN to get FASTER!", "\u{1F45F} Suba na sua ESTEIRA e toque em AUTO CORRER para ficar MAIS RÁPIDO!" },
		-- v67: PRÓXIMA META (a linha de dica nunca acaba) e avisos curtos
		HintNight = { "\u{1F319} Night! Eggs come back in %s", "\u{1F319} Noite! Os ovos voltam em %s" },
		HintPenFull = { "\u{1F3E1} Pen full! Upgrade (%s) or SELL a pet", "\u{1F3E1} Cercado cheio! Melhore (%s) ou VENDA um pet" },
		HintPenFullMax = { "\u{1F3E1} Pen full! SELL or FUSE pets to make room", "\u{1F3E1} Cercado cheio! VENDA ou FUNDA pets para abrir espaço" },
		HintClaimIndex = { "\u{1F4D6} Claim your Index rewards! (%d)", "\u{1F4D6} Pegue seus prêmios do Índice! (%d)" },
		HintGolden = { "\u{2B50} GOLDEN EGG in %s! Steal it first!", "\u{2B50} OVO DOURADO em %s! Roube primeiro!" },
		HintGoZone = { "\u{1F95A} Steal a %s egg - %dx money!", "\u{1F95A} Roube um ovo de %s - %dx dinheiro!" },
		HintGoalSpeed = { "\u{1F3AF} Train to %s speed \u{2192} %s (%d%%)", "\u{1F3AF} Treine até %s de velocidade \u{2192} %s (%d%%)" },
		HintRebirth = { "\u{1F3AF} Next: REBIRTH %d%% (Menu)", "\u{1F3AF} Próximo: RENASCER %d%% (Menu)" },
		GoldenTicker = { "GOLDEN EGG: %s %s", "OVO DOURADO: %s %s" },
		PumpkinTicker = { "Pumpkin Egg in %s", "Ovo de Abóbora em %s" },
		HalloweenTicker = { "HALLOWEEN %s", "HALLOWEEN %s" },
		FirstHit = { "\u{2694}\u{FE0F} Ouch! Hit thieves with YOUR BAT so they drop the egg!", "\u{2694}\u{FE0F} Ai! Use o seu TACO no ladrão para ele soltar o ovo!" },
		NightKeep = { "\u{1F319} The night guard let you keep it!", "\u{1F319} O guarda da noite deixou você ficar com ele!" },
		FirstRare = { "\u{1F389} SURPRISE! Your first egg is RARE!", "\u{1F389} SURPRESA! Seu primeiro ovo é RARO!" },
		-- v67: PRÊMIO DIÁRIO 2.0 (dia de Brasília, escudo, calendário de 28 dias)
		DailyTitle = { "\u{1F381} Daily Rewards", "\u{1F381} Prêmios Diários" },
		DayN = { "Day %d", "Dia %d" },
		Tomorrow = { "TOMORROW", "AMANHÃ" },
		ClaimDay = { "CLAIM DAY %d!", "PEGAR DIA %d!" },
		ComeBack = { "Come back tomorrow!", "Volte amanhã!" },
		RareEgg = { "+ Rare Egg!", "+ Ovo Raro!" },
		NewRewardIn = { "\u{23F0} New reward in %s", "\u{23F0} Prêmio novo em %s" },
		SaverInfo = { "Streak Saver: saves 1 missed day", "Escudo: salva 1 dia perdido" },
		SaverReady = { "\u{1F6E1} Your Streak Saver will keep your streak!", "\u{1F6E1} Seu Escudo vai salvar a sequência!" },
		SaverUsed = { "\u{1F6E1} Your Streak Saver kept your streak!", "\u{1F6E1} Seu Escudo salvou a sua sequência!" },
		SaverEarned = { "\u{1F6E1} 7 days in a row! +1 Streak Saver", "\u{1F6E1} 7 dias seguidos! +1 Escudo" },
		CalendarDay = { "\u{1F4C5} Calendar: Day %d/%d", "\u{1F4C5} Calendário: Dia %d/%d" },
		CalendarShort = { "Day %d/%d", "Dia %d/%d" },
		CalNext = { "\u{1F381} %s in %d days", "\u{1F381} %s em %d dias" },
		CalNextOne = { "\u{1F381} %s on the next claim!", "\u{1F381} %s no próximo prêmio!" },
		CalChamp = { "Calendar Champ title", "título Calendar Champ" },
		Gold = { "GOLD", "OURO" },
		DailyTomorrow = { "Tomorrow: DAY %d \u{2192} %s", "Amanhã: DIA %d \u{2192} %s" },
		CalExclusive = { "\u{1F4C5} Exclusive!", "\u{1F4C5} Exclusivo!" },
		RebirthInfo = { "You KEEP your pen, Index and \u{1F4C5}/\u{1F91D} exclusives (+ a free Rare egg!).\nYou LOSE money, speed, treadmill, trails and other pets.",
			"Você FICA com o cercado, o Índice e os exclusivos \u{1F4C5}/\u{1F91D} (+ ovo Raro grátis!).\nVocê PERDE dinheiro, velocidade, esteira, trilhas e os outros pets." },
		-- v67: CONVITES (escada de prêmios, "Mostrar pros amigos" no cartão do bichinho, visita ao cercado do amigo)
		InviteNext = { "%d/%d friends \u{2192} %s", "%d/%d amigos \u{2192} %s" },
		InviteMsg = { "Invite friends who PLAY: %s", "Convide amigos que JOGAM: %s" },
		LadderTrail = { "Friendship Trail", "Trilha da Amizade" },
		LadderTitle = { "Squad Leader title", "título Squad Leader" },
		FriendExclusive = { "\u{1F91D} Friend exclusive!", "\u{1F91D} Exclusivo de amigo!" },
		ShareBtn = { "\u{1F4F8} Show friends", "\u{1F4F8} Mostrar pros amigos" },
		ShareMsg = { "Come see my %s!", "Venha ver meu %s!" },
		ShareWait = { "Wait a little to show again!", "Espere um pouco para mostrar de novo!" },
		HintVisit = { "\u{1F440} Go see %s's pen!", "\u{1F440} Vá ver o cercado de %s!" },
		-- v67: EMOÇÃO (carimbo na entrega e fuga por pouco)
		Safe = { "SAFE!", "SALVO!" },
		CloseCall = { "\u{1F605} CLOSE CALL! +%s", "\u{1F605} UFA! POR UM TRIZ! +%s" },
		-- v67: ESTRELAS DE COLEÇÃO e COLECIONADOR (janela do Índice)
		CollectStrip = { "\u{1F4D6} COLLECTION %d/%d  \u{2022}  +%d%% cash\nNext at %d: +%d%% more cash, forever!", "\u{1F4D6} COLEÇÃO %d/%d  \u{2022}  +%d%% dinheiro\nCom %d: +%d%% de dinheiro, para sempre!" },
		CollectMax = { "\u{1F4D6} COLLECTION %d/%d  \u{2022}  +%d%% cash\nCOLLECTOR %s - MAX LEVEL!", "\u{1F4D6} COLEÇÃO %d/%d  \u{2022}  +%d%% dinheiro\nCOLECIONADOR %s - NÍVEL MÁXIMO!" },
		StarsAll = { "ALL STARS! %d/%d", "TODAS AS ESTRELAS! %d/%d" },
		StarLeft = { "%s: %d/%d (%d left)", "%s: %d/%d (faltam %d)" },
		BatLocked = { "\u{1F512} Get \u{2605}1 for the Bat", "\u{1F512} Pegue \u{2605}1 para o Taco" },
		BatEquip = { "EQUIP BAT!", "USAR TACO!" },
		BatEquipped = { "EQUIPPED", "EQUIPADO" },
		FindHint = { "\u{1F50E} Steal %s eggs to find it!", "\u{1F50E} Roube ovos de %s para achar!" },
		-- v67: BICHINHO PARCEIRO (botão 🐾 no cartão da janela Pets)
		Follow = { "Follow", "Seguir" },
		Following = { "Following", "Seguindo" },
		BuddyNow = { "\u{1F43E} %s is following you!", "\u{1F43E} %s está seguindo você!" },
		BuddyFirst = { "\u{1F43E} Your best pet follows you now! Tap \u{1F43E} in Pets to change it.", "\u{1F43E} Seu melhor pet agora segue você! Toque na \u{1F43E} em Pets para trocar." },
	}
	L = function(key: string): string
		local entry = TEXTS[key]
		if not entry then
			return key
		end
		return if PT_BR then entry[2] else entry[1]
	end
end

-- etiqueta no chat: 👑 [VIP] [🔄3] [título] (v67: rebirths, o maior título na cor dele e a coroa do Rei do Servidor;
-- o nome do título vem do servidor, sempre um texto fixo do Config.Titles)
pcall(function()
	local TextChatService = game:GetService("TextChatService")
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local who = source and Players:GetPlayerByUserId(source.UserId)
		if who then
			local tags = {}
			if who:GetAttribute("ServerKing") == true then
				table.insert(tags, "\u{1F451}")
			end
			if table.find(string.split(tostring(who:GetAttribute("Passes") or ""), ","), "VIP") then
				table.insert(tags, '<font color="#FFD23C">[VIP]</font>')
			end
			local rebirths = tonumber(who:GetAttribute("Rebirths")) or 0
			if rebirths > 0 then
				table.insert(tags, ('<font color="#FF78FF">[\u{1F504}%d]</font>'):format(rebirths))
			end
			local title = Config.TitleByKey[tostring(who:GetAttribute("Title") or "")]
			local titleName = who:GetAttribute("TitleName")
			if title and type(titleName) == "string" and titleName ~= "" then
				table.insert(tags, ('<font color="#%s">[%s]</font>'):format(title.Color:ToHex(), titleName))
			end
			if #tags > 0 then
				props.PrefixText = table.concat(tags, " ") .. " " .. message.PrefixText
			end
		end
		return props
	end
end)
local SoundService = game:GetService("SoundService")

---------------------------------------------------------------------
-- SONS (ids em Config.Sounds)
---------------------------------------------------------------------
local soundCache: { [string]: Sound } = {}
local function sfx(name: string, pitch: number?)
	local info = Config.Sounds[name]
	if not info or player:GetAttribute("Muted") then
		return
	end
	local template = soundCache[name]
	if not template then
		template = Instance.new("Sound")
		template.Name = "Sfx_" .. name
		template.SoundId = "rbxassetid://" .. tostring(info.Id)
		template.Volume = info.Volume or 0.6
		template.Parent = SoundService
		soundCache[name] = template
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(12, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end
-- som no mundo (os outros ouvem perto de onde aconteceu)
local function sfxAt(name: string, position: Vector3)
	local info = Config.Sounds[name]
	if not info or player:GetAttribute("Muted") then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(info.Id)
	sound.Volume = (info.Volume or 0.6) * 1.4
	sound.RollOffMaxDistance = 140
	sound.Parent = holder
	sound:Play()
	task.delay(6, function()
		holder:Destroy()
	end)
end
-- música de fundo
task.spawn(function()
	local info = Config.Sounds.Music
	if info then
		local music = Instance.new("Sound")
		music.Name = "Music"
		music.SoundId = "rbxassetid://" .. tostring(info.Id)
		music.Volume = info.Volume or 0.2
		music.Looped = true
		music.Parent = SoundService
		music:Play()
	end
end)

-- câmera atrás do personagem, olhando para onde ele está virado (spawn olha para as zonas)
local function faceCameraForward()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return
	end
	local look = root.CFrame.LookVector
	camera.CFrame = CFrame.lookAt(root.Position - look * 18 + Vector3.new(0, 8, 0), root.Position + look * 6)
end
player.CharacterAdded:Connect(function()
	-- o servidor teleporta para o cercado logo depois de nascer
	task.delay(0.6, faceCameraForward)
	task.delay(1.2, faceCameraForward)
end)
local create, text, button, corner, stroke = Theme.create, Theme.text, Theme.button, Theme.corner, Theme.stroke
Theme.OnClick = function()
	sfx("Click")
end
local GREEN_TEXT = Color3.fromRGB(110, 255, 90)
local PINK_TEXT = Color3.fromRGB(255, 70, 140)
-- v67: estado dos primeiros minutos e da PRÓXIMA META (tudo numa tabela: limite de 200 locais do Luau)
local firstMin = {
	JoinClock = os.clock(),
	DailyShown = false, -- Diário já abriu sozinho nesta sessão
	HitTold = false, -- dica do taco já apareceu (1ª vez que levou taco)
	Pulse = nil :: string?, -- botão balançando agora ("Index")
	StopPulse = nil :: (() -> ())?,
	IndexButton = nil :: GuiObject?,
	Small = false, -- linha da dica já encolheu (depois do tutorial)
	FavDone = false, -- já pediu para favoritar nesta sessão
	TryFavorite = function() end, -- (a de verdade fica perto do net.OnClientEvent)
	ShareAt = -1e9, -- (v67) último "Mostrar pros amigos" (os.clock)
	CanInvite = nil :: boolean?, -- (v67) a Roblox deixa esta conta mandar convite? (nil = ainda não sabe)
	BuddyTap = function(_key: string) end, -- (v67) tocou no 🐾 de um pet (a de verdade fica no bloco do PARCEIRO)
}

-- JSON dos atributos (Slots, Index, Quests, Boosts) com CACHE (v66 perf): só decodifica de novo quando o texto
-- do atributo muda (o servidor troca o atributo => o texto muda). Antes cada chamada (4x por segundo no tutorial,
-- relógios, janelas) criava todas as tabelas de novo. Comparar o texto (e não só ouvir o GetAttributeChangedSignal)
-- deixa certo mesmo se outro "Changed" rodar antes deste.
-- ATENÇÃO: a tabela devolvida é COMPARTILHADA: não modifique (para ordenar, use table.clone antes).
local jsonCache: { [string]: { Raw: string, Value: any } } = {}
local function decode(attribute: string, default)
	local raw = player:GetAttribute(attribute)
	if type(raw) ~= "string" or raw == "" then
		return default
	end
	local cached = jsonCache[attribute]
	if not cached or cached.Raw ~= raw then
		local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok then
			return default
		end
		cached = { Raw = raw, Value = value }
		jsonCache[attribute] = cached
	end
	if cached.Value == nil then
		return default
	end
	return cached.Value
end

-- conjunto de objetos com uma tag (v66 perf): CollectionService:GetTagged cria uma tabela nova a cada chamada
-- (60x por segundo = lixo para o coletor no celular); este conjunto é atualizado pelos sinais da tag.
local function taggedSet(tag: string): { [any]: boolean }
	local set: { [any]: boolean } = {}
	for _, item in CollectionService:GetTagged(tag) do
		set[item] = true
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(item)
		set[item] = true
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(item)
		set[item] = nil
	end)
	return set
end
local guardianSet = taggedSet("Guardian")
local nestEggSet = taggedSet("NestEgg")

-- PREÇO DE VERDADE (v65): com o Regional Pricing a Roblox pode cobrar outro preço em cada país.
-- Pergunta à Roblox uma vez por item e guarda; até responder, mostra o Price do Config.
local MarketplaceService = game:GetService("MarketplaceService")
local livePrice: { [number]: number } = {}
local askedPrice: { [number]: boolean } = {}
local function robuxPrice(info): number
	local id = info.Id
	if type(id) ~= "number" or id <= 0 then
		return info.Price or 0
	end
	if livePrice[id] then
		return livePrice[id]
	end
	if not askedPrice[id] then
		askedPrice[id] = true
		local isPass = Config.PassByKey[info.Key] == info
		task.spawn(function()
			local ok, result = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
			end)
			if ok and type(result) == "table" and type(result.PriceInRobux) == "number" then
				livePrice[id] = result.PriceInRobux
			end
		end)
	end
	return info.Price or 0
end
task.defer(function()
	for _, info in Config.Passes do
		robuxPrice(info)
	end
	for _, info in Config.Products do
		robuxPrice(info)
	end
end)

local gui = create("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local uiScale = create("UIScale", { Parent = gui })
local fitWindows: (() -> ())? = nil -- (definida depois que as janelas existem)
local function rescale()
	local size = workspace.CurrentCamera.ViewportSize
	-- arredonda (no celular o tamanho da tela muda um pouquinho toda hora e o texto ficava piscando)
	local scale = math.clamp(math.min(size.X / 1366, size.Y / 768), 0.4, 1.15)
	if TOUCH then
		-- celular: um pouco menor, mas NO MÍNIMO 0.6 (v66: antes caía para 0.40 e ficava tudo minúsculo).
		-- Janela que não cabe nesse tamanho encolhe sozinha (fitWindows).
		scale = math.max(scale * 0.85, 0.6)
	end
	scale = math.floor(scale * 20 + 0.5) / 20
	if math.abs(uiScale.Scale - scale) > 0.001 then
		uiScale.Scale = scale
	end
	if fitWindows then
		fitWindows()
	end
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

---------------------------------------------------------------------
-- HUD: velocidade e dinheiro (embaixo, à esquerda)
---------------------------------------------------------------------
local stats = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(330, 136), BackgroundTransparency = 1, Parent = gui })
text({ Size = UDim2.fromOffset(56, 52), Text = "\u{1F45F}", Stroke = 0, Parent = stats })
local speedText = text({ Size = UDim2.new(1, -64, 0, 56), Position = UDim2.fromOffset(62, -2), Text = "10", TextColor3 = PINK_TEXT, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4.5, Parent = stats })
text({ Size = UDim2.fromOffset(56, 52), Position = UDim2.fromOffset(0, 58), Text = "\u{1F4B5}", Stroke = 0, Parent = stats })
local moneyText = text({ Size = UDim2.new(1, -64, 0, 56), Position = UDim2.fromOffset(62, 56), Text = "$0", TextColor3 = GREEN_TEXT, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4.5, Parent = stats })
local incomeText = text({ Size = UDim2.new(1, -64, 0, 22), Position = UDim2.fromOffset(64, 112), Text = "+$0/s", TextColor3 = Color3.fromRGB(255, 230, 120), TextXAlignment = Enum.TextXAlignment.Left, Parent = stats })

-- celular: dinheiro/velocidade embaixo, logo à ESQUERDA do meio: o bastão e a armadilha (barra de itens do
-- Roblox, por cima de tudo) ficam no meio, o joystick mais à esquerda e o botão de pular à direita
if TOUCH then
	stats.AnchorPoint = Vector2.new(1, 1)
	stats.Position = UDim2.new(0.5, -115, 1, -6)
end

---------------------------------------------------------------------
-- RELÓGIOS (v66): só 2 "pílulas" (antes eram 5 linhas).
--   A = noite (como antes).  B = a coisa MAIS importante agora, nesta ordem:
--   sorte do admin > 2x dinheiro do admin > FESTÃO > ovo dourado (v67) > abóbora em 1 min (v67) > evento da sorte
--   > boost > fim de semana 2x > noite chegando > "UPDATE in ..." > "Lucky in m:ss" > Halloween (v67) > bicho da semana.
--   Nada acontecendo = alterna até 4 a cada 4 s (v67; antes só 2). Dia de semana: bicho da semana em 2º.
-- PC: embaixo à direita. Celular: em cima à direita, logo abaixo da barra do Roblox (longe do botão de pular).
---------------------------------------------------------------------
do
	local timers = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(310, 108), BackgroundTransparency = 1, Parent = gui })
	local timersLayout = create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = timers })
	if TOUCH then
		timers.AnchorPoint = Vector2.new(1, 0)
		timers.Position = UDim2.new(1, -10, 0, 8)
		timersLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	end
	local function timerChip(order: number): (Frame, TextLabel, TextLabel)
		local frame = create("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(310, 50), BackgroundColor3 = Theme.Dark, BackgroundTransparency = 0.3, Parent = timers }, { corner(25), stroke(3) })
		local icon = text({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 5), Text = "", Stroke = 0, Parent = frame })
		local label = text({ Size = UDim2.new(1, -64, 0, 38), Position = UDim2.fromOffset(54, 6), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3, Parent = frame })
		return frame, icon, label
	end
	local tickerChip, tickerIcon, tickerText = timerChip(1)
	local _, nightIcon, nightText = timerChip(2)
	nightIcon.Text = "\u{1F319}"

	local function clockText(left: number): string
		left = math.max(0, math.floor(left))
		return ("%d:%02d"):format(left // 60, left % 60)
	end

	local lastTicker = ""
	local function updateTimers()
		local t = workspace:GetServerTimeNow()
		-- A: noite
		local cycleEnd = workspace:GetAttribute("CycleEnd")
		local isNight = workspace:GetAttribute("Night") == true
		local nightLeft: number? = nil
		if typeof(cycleEnd) == "number" then
			nightLeft = math.max(0, math.floor(cycleEnd - t))
			nightIcon.Text = if isNight then "\u{2600}\u{FE0F}" else "\u{1F319}"
			nightText.Text = "in " .. clockText(cycleEnd - t)
			nightText.TextColor3 = if isNight then Color3.fromRGB(255, 220, 90) else Color3.new(1, 1, 1)
		end
		-- B: lista em ordem de importância (Active = está acontecendo agora)
		local items = {}
		local function add(active: boolean, icon: string, message: string, color: Color3)
			table.insert(items, { Active = active, Icon = icon, Text = message, Color = color })
		end
		local adminLuckEnd = workspace:GetAttribute("AdminLuckEnd")
		if typeof(adminLuckEnd) == "number" and adminLuckEnd > t then
			local mult = workspace:GetAttribute("AdminLuckMult")
			add(true, "\u{26A1}", ("LUCK x%d! %s"):format(if type(mult) == "number" then math.floor(mult) else 10, clockText(adminLuckEnd - t)), Color3.fromRGB(255, 120, 230))
		end
		local adminMoneyEnd = workspace:GetAttribute("AdminMoneyEnd")
		if typeof(adminMoneyEnd) == "number" and adminMoneyEnd > t then
			add(true, "\u{1F4B5}", "2x MONEY! " .. clockText(adminMoneyEnd - t), GREEN_TEXT)
		end
		-- FESTÃO / ATUALIZAÇÃO DA SEMANA (v65): "UPDATE in 2d 5h" e, na hora, "PARTY x5! 23:10"
		local partyStart, partyEnd = Config.PartyWindow(math.floor(t))
		local attrStart, attrEnd = workspace:GetAttribute("PartyStart"), workspace:GetAttribute("PartyEnd")
		if typeof(attrStart) == "number" and typeof(attrEnd) == "number" and attrStart <= t and attrEnd > t then
			partyStart, partyEnd = attrStart, attrEnd -- festão ligado agora pelo admin
		end
		local partyOn = t >= partyStart and t < partyEnd
		if partyOn then
			local left = math.max(0, partyEnd - t)
			add(true, "\u{1F389}", ("PARTY x%d! %d:%02d"):format(Config.Update.PartyLuck, math.floor(left / 60), math.floor(left % 60)), Color3.fromRGB(255, 200, 80))
		end
		-- v67: OVO DOURADO no mapa agora (zona + tempo) e Ovo de Abóbora chegando (último minuto)
		local goldenUntil, goldenZone = workspace:GetAttribute("GoldenUntil"), workspace:GetAttribute("GoldenZone")
		if typeof(goldenUntil) == "number" and goldenUntil > t and typeof(goldenZone) == "number" and Config.Zones[goldenZone] then
			add(true, "\u{2B50}", L("GoldenTicker"):format(Config.Zones[goldenZone].Name, clockText(goldenUntil - t)), Color3.fromRGB(255, 215, 60))
		end
		local pumpkinAt = workspace:GetAttribute("PumpkinAt")
		if typeof(pumpkinAt) == "number" and pumpkinAt > t and pumpkinAt - t <= 60 then
			add(true, "\u{1F383}", L("PumpkinTicker"):format(clockText(pumpkinAt - t)), Color3.fromRGB(255, 150, 50))
		end
		-- evento da sorte (raros x3)
		local luckyStart = t - t % Config.LuckyEvery
		local luckyLeft = luckyStart + Config.LuckyLength - t
		local luckyEnd = workspace:GetAttribute("LuckyEnd")
		if typeof(luckyEnd) == "number" then
			luckyLeft = math.max(luckyLeft, luckyEnd - t)
		end
		if luckyLeft > 0 then
			add(true, "\u{1F340}", ("LUCKY x%d! %d:%02d"):format(Config.LuckyMult, math.floor(luckyLeft / 60), math.floor(luckyLeft % 60)), Color3.fromRGB(120, 255, 120))
		end
		-- boost mais longo ativo
		local boosts = decode("Boosts", {})
		local bestLeft, bestBoost = 0, nil
		for _, boost in Config.Boosts do
			local left = (tonumber(boosts[boost.Id]) or 0) - t
			if left > bestLeft then
				bestLeft, bestBoost = left, boost
			end
		end
		if bestBoost then
			add(true, bestBoost.Icon, ("%s %s"):format(bestBoost.Name, clockText(bestLeft)), bestBoost.Color)
		end
		-- (não ativos)
		if workspace:GetAttribute("Weekend") == true then
			add(false, "\u{1F4B5}", "WEEKEND 2x MONEY!", GREEN_TEXT)
		end
		if nightLeft and not isNight and nightLeft <= 45 then
			add(false, "\u{1F319}", ("NIGHT in %ds! Go home!"):format(nightLeft), Color3.fromRGB(160, 180, 255))
		end
		if not partyOn then
			local left = partyStart - t
			add(false, "\u{1F389}", if left >= 86400 then ("UPDATE in %dd %dh"):format(math.floor(left / 86400), math.floor(left % 86400 / 3600))
				elseif left >= 3600 then ("UPDATE in %dh %dm"):format(math.floor(left / 3600), math.floor(left % 3600 / 60))
				else ("UPDATE in %d:%02d"):format(math.floor(left / 60), math.floor(left % 60)), Color3.new(1, 1, 1))
		end
		if luckyLeft <= 0 then
			local left = luckyStart + Config.LuckyEvery - t
			add(false, "\u{1F340}", ("Lucky in %d:%02d"):format(math.floor(left / 60), math.floor(left % 60)), Color3.new(1, 1, 1))
		end
		-- v67: quanto falta para o Halloween acabar
		if workspace:GetAttribute("Halloween") == true then
			local left = (Config.Halloween.To or 0) - t
			add(false, "\u{1F383}", L("HalloweenTicker"):format(if left >= 86400 then ("%dd"):format(math.floor(left / 86400))
				elseif left >= 3600 then ("%dh"):format(math.floor(left / 3600)) elseif left > 0 then clockText(left) else ""), Color3.fromRGB(255, 150, 50))
		end
		-- BICHO DA SEMANA (v67: nos dias de semana entra em 2º na fila, para aparecer sempre; antes a fila só
		-- girava os 2 primeiros e ele nunca aparecia)
		local weekly = Critters.ById[Config.WeeklyCritter(math.floor(t))]
		if weekly then
			local left = Config.WeeklyEnds(math.floor(t)) - t
			local message = ("%s x%d! %dd %dh"):format(weekly.Name, Config.WeeklyMult, math.floor(left / 86400), math.floor(left % 86400 / 3600))
			local entry = { Active = false, Icon = "\u{2B50}", Text = message, Color = Color3.fromRGB(255, 220, 90) }
			if workspace:GetAttribute("Weekend") ~= true then
				table.insert(items, math.min(2, #items + 1), entry)
			else
				table.insert(items, entry)
			end
		end
		local pick = nil
		for _, item in items do
			if item.Active then
				pick = item
				break
			end
		end
		if not pick and #items > 0 then
			pick = items[math.floor(os.clock() / 4) % math.min(#items, 4) + 1]
		end
		tickerChip.Visible = pick ~= nil
		if pick then
			tickerIcon.Text = pick.Icon
			tickerText.Text = pick.Text
			tickerText.TextColor3 = pick.Color
			-- trocou de assunto: pulinho para chamar a atenção
			local key = pick.Icon .. string.sub(pick.Text, 1, 6)
			if key ~= lastTicker then
				lastTicker = key
				Theme.popIn(tickerChip)
			end
		end
	end
	local timersWarned = false
	task.spawn(function()
		while true do
			local ok, err = pcall(updateTimers)
			if not ok and not timersWarned then
				timersWarned = true
				warn("[HUD] relógios:", err)
			end
			task.wait(0.5)
		end
	end)
end

---------------------------------------------------------------------
-- Janelas
---------------------------------------------------------------------
local windows: { [string]: Frame } = {}
local onOpen: { [string]: () -> () } = {}
-- refreshers[nome] = atualiza a janela SEM mudar aba/seleção (usado depois de compras, roubos, chocar...)
local refreshers: { [string]: () -> () } = {}
local currentWindow: string? = nil -- nome com que a janela aberta foi aberta (ex.: "Trails" abre o Shop)
local function open(name: string, toggle: boolean?)
	local window = windows[name]
	-- (v66: compara a JANELA e não o nome: Trails/Boosts são o Shop e Sell é o Pets; antes o botão Shop
	-- escondia o próprio Shop pelo apelido "Trails" e nunca fechava no 2º toque)
	if toggle and window and window.Visible then
		window.Visible = false
		currentWindow = nil
		return
	end
	for _, other in windows do
		if other ~= window then
			other.Visible = false
		end
	end
	if not window then
		currentWindow = nil
		return
	end
	window.Visible = true
	currentWindow = name
	Theme.popIn(window)
	if onOpen[name] then
		onOpen[name]()
	end
end
-- v67: tem alguma janela aberta? (olha a janela de verdade: o X e o "Hatched" fecham sem mexer no currentWindow)
local function anyWindowOpen(): boolean
	for _, window in windows do
		if window.Visible then
			return true
		end
	end
	return false
end

-- PRÉVIAS 3D PREGUIÇOSAS (v66 perf): ViewportFrame + cópia do modelo é a peça mais cara da tela.
-- O cartão nasce sem prévia; ela só é criada quando o cartão aparece na área visível da lista,
-- no máximo 3 por frame (abrir o Index/Pets não trava mais o celular).
local function lazyPreviews(list: ScrollingFrame)
	local pending: { [GuiObject]: () -> () } = {}
	local scheduled = false
	local pump: () -> ()
	local function schedule()
		if not scheduled then
			scheduled = true
			task.delay(0, pump)
		end
	end
	pump = function()
		scheduled = false
		if next(pending) == nil then
			return
		end
		local top = list.AbsolutePosition.Y - 160
		local bottom = list.AbsolutePosition.Y + list.AbsoluteSize.Y + 160
		local built, more = 0, false
		for card, build in pending do
			if not card.Parent then
				pending[card] = nil
			else
				local y = card.AbsolutePosition.Y
				if y + card.AbsoluteSize.Y >= top and y <= bottom then
					if built >= 3 then
						more = true
						break
					end
					pending[card] = nil
					built += 1
					local ok, err = pcall(build)
					if not ok then
						warn("[HUD] prévia 3D:", err)
					end
				end
			end
		end
		if more then
			schedule()
		end
	end
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(schedule)
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
	return {
		Add = function(card: GuiObject, build: () -> ())
			pending[card] = build
			schedule()
		end,
		Remove = function(card: GuiObject)
			pending[card] = nil
		end,
		Clear = function()
			table.clear(pending)
		end,
		Pump = schedule,
	}
end

local function scroller(parent: Instance, props: { [string]: any }?, grid: Vector2?): ScrollingFrame
	local frame = create("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(200, 200, 210),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 12,
		Parent = parent,
	})
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	if grid then
		create("UIGridLayout", { CellSize = UDim2.fromOffset(grid.X, grid.Y), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	else
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	end
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = frame })
	return frame
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- linha de loja: ícone, título, subtítulo, botão
local function shopRow(parent: Instance, order: number, icon: string, title: string, sub: string, buttonText: string, buttonColor: Color3, onClick, accent: Color3?)
	local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 96), BackgroundColor3 = Color3.fromRGB(62, 62, 74), ZIndex = 12, Parent = parent }, { corner(12), stroke(3) })
	local iconBox = create("Frame", { Size = UDim2.fromOffset(78, 78), Position = UDim2.fromOffset(9, 9), BackgroundColor3 = accent or Color3.fromRGB(90, 90, 110), ZIndex = 13, Parent = row }, { corner(10), stroke(3) })
	Theme.gloss(iconBox, 0.3)
	text({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = icon, Stroke = 0, ZIndex = 14, Parent = iconBox })
	local titleLabel = text({ Size = UDim2.new(1, -310, 0, 40), Position = UDim2.fromOffset(100, 10), Text = title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = row })
	local subLabel = text({ Size = UDim2.new(1, -310, 0, 30), Position = UDim2.fromOffset(100, 54), Text = sub, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 215, 255), Stroke = 2, ZIndex = 13, Parent = row })
	local btn, btnLabel = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(190, 66), BackgroundColor3 = buttonColor, ZIndex = 13, Parent = row }, buttonText, onClick)
	-- (v66: devolve também os textos, para atualizar a linha no lugar sem refazer)
	return row, btn, btnLabel, subLabel, titleLabel
end

---------------------------------------------------------------------
-- SHOP: abas Upgrades / Trails / Boosts
---------------------------------------------------------------------
local shopWindow, shopBody = Theme.window(gui, "Shop", "Shop", Theme.Green, Vector2.new(820, 560))
windows.Shop = shopWindow
local shopTab = "Upgrades"
local shopList = scroller(shopBody, { Size = UDim2.new(1, -16, 1, -76), Position = UDim2.fromOffset(8, 68) })
local tabBar = create("Frame", { Size = UDim2.new(1, -16, 0, 54), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1, ZIndex = 12, Parent = shopBody }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local refreshShop
local tabButtons = {}
for order, info in { { "Upgrades", "\u{2B06} Upgrades", Theme.Green }, { "Trails", "\u{2728} Trails", Theme.Purple }, { "Boosts", "\u{1F9EA} Boosts", Theme.Pink }, { "Robux", "\u{1F48E} Robux", Theme.Cyan }, { "Rebirth", "\u{1F504} Rebirth", Theme.Orange } } do
	local btn = button({ LayoutOrder = order, Size = UDim2.fromOffset(148, 52), BackgroundColor3 = info[3], ZIndex = 13, Parent = tabBar }, info[2], function()
		shopTab = info[1]
		refreshShop()
	end)
	tabButtons[info[1]] = btn
end

refreshShop = function()
	for key, btn in tabButtons do
		btn.BackgroundTransparency = if key == shopTab then 0 else 0.45
	end
	clear(shopList)
	local money = player:GetAttribute("Money") or 0
	if shopTab == "Upgrades" then
		local pen = player:GetAttribute("PenLevel") or 0
		local nextPen = Config.PenLevels[pen + 1]
		shopRow(shopList, 1, "\u{1F3E1}", if pen == 0 then "Unlock Pen Level 1" else ("Upgrade Pen  (Level %d)"):format(pen),
			("%d slots%s"):format(Config.SlotCount(pen), if nextPen then ("  \u{2192}  %d slots%s"):format(Config.SlotCount(pen + 1), if pen == 0 then " + TREADMILL" else "") else "  (MAX)"),
			if nextPen then Format.Money(nextPen.Cost) else "MAX", if nextPen and money >= nextPen.Cost then Theme.Green else Theme.Gray, function()
				net:FireServer("Upgrade", "Pen")
			end, Color3.fromRGB(150, 100, 60))
		local tread = player:GetAttribute("TreadLevel") or 1
		local current = Config.Treadmills[tread]
		local nextTread = Config.Treadmills[tread + 1]
		shopRow(shopList, 2, "\u{1F3C3}", ("%s Treadmill  (Level %d)"):format(current.Name, tread),
			("+%s/step%s"):format(Format.Short(current.Gain), if nextTread then ("  \u{2192}  %s +%s/step"):format(nextTread.Name, Format.Short(nextTread.Gain)) else "  (MAX)"),
			if nextTread then Format.Money(nextTread.Cost) else "MAX", if nextTread and money >= nextTread.Cost and pen >= 1 then Theme.Green else Theme.Gray, function()
				net:FireServer("Upgrade", "Treadmill")
			end, current.Color)
		shopRow(shopList, 3, "\u{1F381}", "FREE Chest", "Join our community and open the chest every 15 min!", "Go!", Theme.Blue, function()
			shopWindow.Visible = false
		end, Color3.fromRGB(220, 50, 60))
	elseif shopTab == "Trails" then
		local owned = string.split(player:GetAttribute("Trails") or "", ",")
		local equipped = player:GetAttribute("Trail") or ""
		for order, trail in Config.Trails do
			local has = table.find(owned, trail.Id) ~= nil
			if trail.Hidden and not has then
				continue -- (v67) trilha da escada de convites: só aparece para quem ganhou
			end
			local label = if equipped == trail.Id then "EQUIPPED" elseif has then "Equip" else Format.Money(trail.Cost)
			local color = if equipped == trail.Id then Theme.Gray elseif has then Theme.Blue elseif money >= trail.Cost then Theme.Green else Theme.Red
			shopRow(shopList, order, "\u{2728}", trail.Name, ("x%s treadmill speed"):format(tostring(trail.Mult)), label, color, function()
				net:FireServer("Trail", trail.Id)
			end, trail.Color)
		end
	elseif shopTab == "Robux" then
		local passes = string.split(player:GetAttribute("Passes") or "", ",")
		local order = 0
		for _, info in Config.Passes do
			if not info.Id or info.Id <= 0 then
				continue -- ainda não criado no Creator Hub: não aparece
			end
			order += 1
			local owned = table.find(passes, info.Key) ~= nil
			shopRow(shopList, order, info.Icon, info.Name .. "  (GAMEPASS)", info.Desc, if owned then "OWNED" else ("R$ %d"):format(robuxPrice(info)), if owned then Theme.Gray else Theme.Green, function()
				if not owned then
					net:FireServer("Buy", info.Key)
				end
			end, info.Color)
		end
		for _, info in Config.Products do
			if not info.Id or info.Id <= 0 then
				continue
			end
			order += 1
			shopRow(shopList, order, info.Icon, info.Name, info.Desc or "Instant!", ("R$ %d"):format(robuxPrice(info)), Theme.Green, function()
				net:FireServer("Buy", info.Key)
			end, info.Color)
		end
	elseif shopTab == "Rebirth" then
		local rebirths = player:GetAttribute("Rebirths") or 0
		local cost = Config.RebirthCost(rebirths)
		local row = create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 360), BackgroundColor3 = Color3.fromRGB(62, 62, 74), ZIndex = 12, Parent = shopList }, { corner(12), stroke(3) })
		text({ Size = UDim2.new(1, -20, 0, 60), Position = UDim2.fromOffset(10, 10), Text = ("\u{1F504} REBIRTH %d \u{2192} %d"):format(rebirths, rebirths + 1), TextColor3 = Color3.fromRGB(255, 130, 255), ZIndex = 13, Parent = row })
		text({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 80), Text = ("Money: +%d%%  \u{2192}  +%d%%"):format(math.floor(Config.RebirthMoney * rebirths * 100), math.floor(Config.RebirthMoney * (rebirths + 1) * 100)), TextColor3 = GREEN_TEXT, ZIndex = 13, Parent = row })
		text({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 124), Text = ("Treadmill speed: +%d%%  \u{2192}  +%d%%"):format(math.floor(Config.RebirthTread * rebirths * 100), math.floor(Config.RebirthTread * (rebirths + 1) * 100)), TextColor3 = PINK_TEXT, ZIndex = 13, Parent = row })
		text({ Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 172), Text = L("RebirthInfo"), TextColor3 = Color3.fromRGB(200, 210, 230), Stroke = 2, ZIndex = 13, Parent = row })
		-- rebirth leva os bichinhos: precisa tocar 2 vezes para confirmar
		local confirmUntil = 0
		local rebirthLabel
		_, rebirthLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(420, 80), BackgroundColor3 = if money >= cost then Theme.Purple else Theme.Gray, ZIndex = 13, Parent = row }, "REBIRTH  " .. Format.Money(cost), function()
			-- v65: lê o dinheiro de AGORA (antes usava o valor de quando abriu a aba e pulava a confirmação)
			-- sem dinheiro: o servidor avisa quanto falta; com dinheiro: só vale o 2º toque
			if (player:GetAttribute("Money") or 0) < cost or os.clock() < confirmUntil then
				net:FireServer("Rebirth")
			else
				confirmUntil = os.clock() + 4
				rebirthLabel.Text = "TAP AGAIN! (pets will be lost)"
				task.delay(4, function()
					if rebirthLabel.Parent then
						rebirthLabel.Text = "REBIRTH  " .. Format.Money(cost)
					end
				end)
			end
		end)
	else
		local boosts = decode("Boosts", {})
		local income = player:GetAttribute("BaseIncome") or player:GetAttribute("Income") or 0 -- prêmios usam a renda sem os 2x (v66)
		for order, boost in Config.Boosts do
			local price = math.max(boost.MinPrice, math.floor(income * 60 * boost.Price))
			local left = (boosts[boost.Id] or 0) - workspace:GetServerTimeNow()
			shopRow(shopList, order, boost.Icon, boost.Name, if left > 0 then ("ACTIVE: %dm %ds left"):format(left // 60, left % 60) else ("%d minutes"):format(boost.Minutes),
				Format.Money(price), if money >= price then Theme.Green else Theme.Red, function()
					net:FireServer("Boost", boost.Id)
				end, boost.Color)
		end
	end
end
onOpen.Shop = refreshShop
refreshers.Shop = refreshShop

---------------------------------------------------------------------
-- INDEX: zonas à esquerda, cartões no meio, detalhes e prêmios à direita
---------------------------------------------------------------------
-- (do...end: as variáveis do Índice ficam só aqui dentro - limite de 200 locais do Luau)
do
	local indexWindow, indexBody = Theme.window(gui, "Index", "Pet Index", Theme.Blue, Vector2.new(1000, 580))
	windows.Index = indexWindow
	local indexZone = 1
	local indexSelected = nil
	local zoneList = scroller(indexBody, { Size = UDim2.new(0, 190, 1, -16) })
	local cardArea = create("Frame", { Size = UDim2.new(1, -530, 1, -152), Position = UDim2.fromOffset(206, 64), BackgroundTransparency = 1, ZIndex = 12, Parent = indexBody })
	-- v67 COLEÇÃO: faixa em cima dos cartões (total achado, nível de Colecionador e quanto falta para o próximo)
	local collectBack = create("Frame", { Size = UDim2.new(1, -530, 0, 50), Position = UDim2.fromOffset(206, 8), BackgroundColor3 = Color3.fromRGB(20, 20, 26), ZIndex = 12, Parent = indexBody }, { corner(10), stroke(3) })
	local collectFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Gold, BackgroundTransparency = 0.35, ZIndex = 13, Parent = collectBack }, { corner(10) })
	local collectText = text({ Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Text = "", ZIndex = 14, Stroke = 3, Parent = collectBack })
	local cardGrid = scroller(cardArea, { Size = UDim2.fromScale(1, 1), Position = UDim2.new() }, Vector2.new(128, 140))
	local progressBack = create("Frame", { Size = UDim2.new(1, -730, 0, 66), Position = UDim2.new(0, 206, 1, -80), BackgroundColor3 = Color3.fromRGB(20, 20, 26), ZIndex = 12, Parent = indexBody }, { corner(10), stroke(3) })
	local progressFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = progressBack }, { corner(10) })
	Theme.gloss(progressFill, 0.3)
	local progressText = text({ Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), Text = "0/0", ZIndex = 14, Stroke = 4, Parent = progressBack })
	local batButton, batLabel = button({ Size = UDim2.fromOffset(188, 66), Position = UDim2.new(1, -512, 1, -80), BackgroundColor3 = Theme.Gray, ZIndex = 13, Parent = indexBody }, "\u{1F3CF} Bat", function()
		net:FireServer("EquipBat", indexZone)
	end)
	local detail = create("Frame", { Size = UDim2.new(0, 300, 1, -16), Position = UDim2.new(1, -308, 0, 8), BackgroundColor3 = Color3.fromRGB(60, 60, 72), ZIndex = 12, Parent = indexBody }, { corner(12), stroke(3) })
	local detailView = create("Frame", { Size = UDim2.new(1, -20, 0, 200), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(80, 80, 95), ZIndex = 13, Parent = detail }, { corner(10) })
	Theme.gloss(detailView, 0.4)
	local detailName = text({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 214), Text = "", ZIndex = 13, Parent = detail })
	local detailRarity = text({ Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 254), Text = "", ZIndex = 13, Parent = detail })
	local detailIncome = text({ Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 288), Text = "", TextColor3 = GREEN_TEXT, ZIndex = 13, Parent = detail })
	local detailReward = text({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 330), Text = "", TextColor3 = Color3.fromRGB(255, 230, 120), Stroke = 2, ZIndex = 13, Parent = detail })
	-- (v67) a dica (Hint) do bichinho que falta; fica onde o CLAIM aparece (o CLAIM só existe para quem já achou)
	local detailHint = text({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 364), Text = "", TextColor3 = Theme.Gold, TextWrapped = true, Stroke = 2, Visible = false, ZIndex = 13, Parent = detail })
	local claimButton, claimLabel = button({ Size = UDim2.new(1, -40, 0, 56), Position = UDim2.new(0, 20, 1, -132), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = detail }, "CLAIM", function()
		if indexSelected then
			net:FireServer("ClaimIndex", indexSelected)
		end
	end)
	local claimAllButton, claimAllLabel = button({ Size = UDim2.new(1, -40, 0, 56), Position = UDim2.new(0, 20, 1, -68), BackgroundColor3 = Theme.Blue, ZIndex = 13, Parent = detail }, "CLAIM ALL", function()
		net:FireServer("ClaimIndex")
	end)

	local function zoneDefs(zoneIndex: number)
		local zone = Config.Zones[zoneIndex]
		local list, seen = {}, {}
		for _, rarity in zone.Rarities do
			for _, world in zone.Pool do
				local byRarity = Critters.ByWorld[world]
				for _, def in (byRarity and byRarity[rarity]) or {} do
					if not seen[def.Id] then
						seen[def.Id] = true
						table.insert(list, def)
					end
				end
			end
		end
		return list
	end

	-- (v66 perf) os cartões e os botões das zonas ficam prontos e só mudam texto/borda; a zona só é refeita
	-- quando você troca de zona, e a prévia 3D de cada cartão nasce só quando ele aparece na tela (lazyPreviews)
	local refreshIndex
	local indexShown: string? = nil -- cartão mostrado à direita (mesmo não descoberto)
	local detailKey = ""
	local zoneButtons: { [number]: { Button: TextButton, Label: TextLabel, Stroke: UIStroke? } } = {}
	local indexCards: { [string]: any } = {}
	local indexCardsZone = 0
	local indexLazy = lazyPreviews(cardGrid)
	local CLAIM_YELLOW = Color3.fromRGB(255, 230, 80)

	-- borda do cartão: amarela = prêmio para pegar; branca e grossa = o que está aberto à direita;
	-- (v67) dourada = falta pouco para a estrela dele (Config.StarNudge) e ainda não achou
	local function paintIndexCards()
		for id, entry in indexCards do
			local shown = id == indexShown
			entry.Stroke.Color = if entry.Found == 1 then CLAIM_YELLOW elseif shown then Theme.White elseif entry.Near then Theme.Gold else Theme.Dark
			entry.Stroke.Thickness = if shown then 5 elseif entry.Near then 4 else 3
		end
	end

	-- (v67) dica do bichinho que falta: a do Critters (Hint) ou "roube ovos da zona"
	local function hintFor(def): string
		return if def.Hint then "\u{1F50E} " .. def.Hint else L("FindHint"):format(Config.Zones[indexZone].Name)
	end

	local function selectPet(def, found: number?)
		indexSelected = if found then def.Id else nil
		indexShown = def.Id
		-- a prévia girando só é refeita se mudou o bichinho (ou se ele acabou de ser descoberto)
		local key = def.Id .. (if found then "+" else "-")
		if key ~= detailKey then
			detailKey = key
			clear(detailView)
			Theme.preview(detailView, def, not found, true)
		end
		detailName.Text = if found then def.Name else "???"
		detailRarity.Text = def.Rarity
		detailRarity.TextColor3 = Theme.rarityColor(def.Rarity)
		local income = Config.BaseIncome(def, indexZone)
		detailIncome.Text = if found then Format.Money(income) .. "/s" else "Steal it to find out!"
		local cash, speed = Config.IndexReward(def, indexZone)
		detailReward.Text = ("Reward: %s  +%s Speed"):format(Format.Money(cash), Format.Short(speed))
		detailHint.Visible = not found
		detailHint.Text = if found then "" else hintFor(def)
		claimButton.Visible = found == 1
		claimLabel.Text = "CLAIM"
		paintIndexCards()
	end

	-- (re)cria a prévia do cartão quando ele aparecer na tela (sombra preta se ainda não foi descoberto)
	local function queueIndexPreview(entry)
		if entry.View then
			entry.View:Destroy()
			entry.View = nil
		end
		indexLazy.Add(entry.Card, function()
			if entry.Card.Parent and not entry.View then
				entry.View = Theme.preview(entry.Card, entry.Def, not entry.Found, false)
				entry.ViewFound = entry.Found ~= nil
			end
		end)
	end

	local function buildIndexCard(def, order: number)
		local card = create("TextButton", { LayoutOrder = order, Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.cardColor(def.Rarity), ZIndex = 13, Parent = cardGrid }, { corner(10), stroke(3) })
		Theme.gloss(card, 0.35)
		local entry = {
			Def = def,
			Card = card,
			Stroke = card:FindFirstChildOfClass("UIStroke"),
			Name = text({ Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 4), Text = "???", ZIndex = 15, Parent = card }),
			Claim = text({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(60, 22), Text = "CLAIM!", TextColor3 = CLAIM_YELLOW, Visible = false, ZIndex = 15, Parent = card }),
			-- (v67) dica embaixo da sombra quando falta pouco para a estrela
			Hint = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -8, 0, 34), Text = "", TextColor3 = Theme.Gold, TextWrapped = true, Stroke = 2, Visible = false, ZIndex = 15, Parent = card }),
			Near = false,
			Found = nil,
			View = nil,
			ViewFound = false,
		}
		Theme.springy(card)
		card.Activated:Connect(function()
			selectPet(def, entry.Found)
		end)
		indexCards[def.Id] = entry
		queueIndexPreview(entry)
		return entry
	end

	-- (v67) ★ = estrela da zona que já tem; ☆ = que falta (Config.IndexStars, a mesma conta do servidor)
	local function starText(done): string
		local out = ""
		for tier in Config.IndexStars do
			out ..= if done[tier] then "\u{2605}" else "\u{2606}"
		end
		return out
	end

	refreshIndex = function()
		local index = decode("Index", {})
		local unclaimed = 0
		for _, value in index do
			if value == 1 then
				unclaimed += 1
			end
		end
		claimAllLabel.Text = ("CLAIM ALL (%d)!"):format(unclaimed)
		claimAllButton.BackgroundColor3 = if unclaimed > 0 then Theme.Blue else Theme.Gray
		for order, zone in Config.Zones do
			local defs = zoneDefs(order)
			local count = 0
			for _, def in defs do
				if index[def.Id] then
					count += 1
				end
			end
			local entry = zoneButtons[order]
			if not entry then
				local btn, label = button({ LayoutOrder = order, Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = zone.Floor[1], ZIndex = 13, Parent = zoneList }, "", function()
					if indexZone ~= order then
						indexZone = order
						refreshIndex()
					end
				end)
				entry = { Button = btn, Label = label, Stroke = btn:FindFirstChildOfClass("UIStroke") }
				zoneButtons[order] = entry
			end
			entry.Label.Text = ("%s %s\n%s %d/%d"):format(zone.Emoji or "", zone.Name, starText((Config.ZoneStars(order, Critters.ByWorld, index))), count, #defs)
			entry.Button.BackgroundTransparency = if order == indexZone then 0 else 0.35
			if entry.Stroke then
				entry.Stroke.Color = if order == indexZone then Theme.White else Theme.Dark
			end
		end
		local defs = zoneDefs(indexZone)
		-- trocou de zona: refaz os cartões (só os desta zona existem; prévias nascem aos poucos)
		if indexCardsZone ~= indexZone then
			indexCardsZone = indexZone
			indexLazy.Clear()
			clear(cardGrid)
			table.clear(indexCards)
			cardGrid.CanvasPosition = Vector2.zero
			for order, def in defs do
				buildIndexCard(def, order)
			end
		end
		local count = 0
		local first = nil
		local done, missing = Config.ZoneStars(indexZone, Critters.ByWorld, index)
		for _, def in defs do
			local found = index[def.Id]
			if found then
				count += 1
			end
			local entry = indexCards[def.Id]
			if entry then
				entry.Found = found
				entry.Name.Text = if found then def.Name else "???"
				entry.Claim.Visible = found == 1
				-- (v67) quase lá: a estrela deste bichinho só precisa de Config.StarNudge ou menos = borda dourada + dica
				local tier = Config.StarTier[def.Rarity]
				entry.Near = not found and tier ~= nil and not done[tier] and missing[tier] <= Config.StarNudge
				entry.Hint.Visible = entry.Near
				entry.Hint.Text = if entry.Near then hintFor(def) else ""
				-- acabou de descobrir: troca a sombra pela prévia colorida
				if entry.View and entry.ViewFound ~= (found ~= nil) then
					queueIndexPreview(entry)
				end
			end
			first = first or { def, found }
		end
		indexLazy.Pump()
		-- (v67) barra de baixo = a próxima estrela da zona (a 1ª que falta); todas = a zona inteira
		local tiers = Config.ZoneTiers(indexZone, Critters.ByWorld)
		local nextTier = nil
		for tier, list in tiers do
			if not done[tier] and #list > 0 then
				nextTier = tier
				break
			end
		end
		if nextTier then
			local need = #tiers[nextTier]
			progressFill.Size = UDim2.fromScale((need - missing[nextTier]) / need, 1)
			progressText.Text = L("StarLeft"):format("\u{2605}" .. nextTier, need - missing[nextTier], need, missing[nextTier])
		else
			progressFill.Size = UDim2.fromScale(1, 1)
			progressText.Text = "\u{2605}\u{2605}\u{2605} " .. L("StarsAll"):format(count, #defs)
		end
		-- o taco da zona sai com a ★1 (igual ao servidor: batUnlocked)
		local complete = false
		for tier, info in Config.IndexStars do
			if info.Bat then
				complete = done[tier] == true
			end
		end
		local equipped = (player:GetAttribute("Bat") or 0) == indexZone
		batLabel.Text = if equipped then L("BatEquipped") elseif complete then L("BatEquip") else L("BatLocked")
		batButton.BackgroundColor3 = if equipped then Theme.Gray elseif complete then Theme.Orange else Color3.fromRGB(80, 80, 90)
		-- (v67) faixa da COLEÇÃO: total achado e o próximo nível de Colecionador (+3% cada)
		local found, total = Config.CollectionCount(Critters.ByWorld, index)
		local level = math.max(Config.CollectorLevel(found, total), tonumber(player:GetAttribute("Collector")) or 0)
		local bonus = math.floor(level * Config.CollectorCash * 100 + 0.5)
		local nextNeed = Config.Collector[level + 1]
		if nextNeed then
			nextNeed = math.min(nextNeed, total)
			local prev = Config.Collector[level] or 0
			collectFill.Size = UDim2.fromScale(math.clamp((found - prev) / math.max(nextNeed - prev, 1), 0, 1), 1)
			collectText.Text = L("CollectStrip"):format(found, total, bonus, nextNeed, math.floor(Config.CollectorCash * 100 + 0.5))
		else
			collectFill.Size = UDim2.fromScale(1, 1)
			collectText.Text = L("CollectMax"):format(found, total, bonus, Config.CollectorNames[level] or tostring(level))
		end
		if first then
			local keep = false
			for _, def in defs do
				if def.Id == indexShown then
					keep = true
					selectPet(def, index[def.Id])
				end
			end
			if not keep then
				selectPet(first[1], first[2])
			end
		end
	end
	onOpen.Index = refreshIndex
	refreshers.Index = refreshIndex
end

---------------------------------------------------------------------
-- EGGS (ovos crescendo) e PETS / SELL
---------------------------------------------------------------------
local eggsWindow, eggsBody = Theme.window(gui, "Eggs", "Growing Eggs", Theme.Orange, Vector2.new(760, 520))
windows.Eggs = eggsWindow
local eggsList = scroller(eggsBody, { Size = UDim2.new(1, -16, 1, -84) })
local hatchAll = button({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.new(0, 8, 1, -68), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = eggsBody }, "\u{1F423} HATCH ALL READY", function()
	net:FireServer("HatchAll")
end)
local _ = hatchAll

local function timeText(left: number): string
	if left <= 0 then
		return "READY!"
	elseif left >= 3600 then
		return ("%dh %dm %ds"):format(left // 3600, (left % 3600) // 60, left % 60)
	elseif left >= 60 then
		return ("%dm %ds"):format(left // 60, left % 60)
	end
	return ("%ds"):format(left)
end

-- (v66 perf) as linhas ficam prontas: a cada segundo só mudam o tempo e a cor do botão. Só refaz quando entra
-- ou sai um ovo (antes destruía e recriava tudo 1x por segundo e o toque em HATCH se perdia no meio).
local eggRows: { [string]: any } = {}
local eggSignature: string? = nil
local function refreshEggs()
	local eggs, keys = {}, {}
	for _, slot in decode("Slots", {}) do
		if type(slot) == "table" and slot.k == "Egg" and Critters.ById[slot.id] then
			table.insert(eggs, slot)
			table.insert(keys, ("%s:%s:%s:%s"):format(tostring(slot.i), tostring(slot.id), tostring(slot.s), tostring(slot.inc)))
		end
	end
	local signature = table.concat(keys, "|")
	if signature ~= eggSignature then
		eggSignature = signature
		clear(eggsList)
		table.clear(eggRows)
		for n, slot in eggs do
			local def = Critters.ById[slot.id]
			local row = create("Frame", { LayoutOrder = slot.l or 0, Size = UDim2.new(1, -8, 0, 86), BackgroundColor3 = Color3.fromRGB(62, 62, 74), ZIndex = 12, Parent = eggsList }, { corner(12), stroke(3) })
			local box = create("Frame", { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.cardColor(def.Rarity), ZIndex = 13, Parent = row }, { corner(10), stroke(3) })
			text({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = "\u{1F95A}", Stroke = 0, ZIndex = 14, Parent = box })
			local label = Config.SizeLabel(slot.s or 1)
			text({ Size = UDim2.new(1, -330, 0, 38), Position = UDim2.fromOffset(90, 6), Text = ("%s%s Egg"):format(if label then label .. " " else "", def.Name), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = row })
			text({ Size = UDim2.new(1, -330, 0, 28), Position = UDim2.fromOffset(90, 48), Text = ("%s  \u{2022}  %s/s"):format(def.Rarity, Format.Money(slot.inc or 0)), TextColor3 = Theme.rarityColor(def.Rarity), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2, ZIndex = 13, Parent = row })
			local slotIndex = slot.i
			local hatchButton, hatchLabel = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(220, 62), BackgroundColor3 = Theme.Gray, ZIndex = 13, Parent = row }, "", function()
				net:FireServer("Hatch", slotIndex)
			end)
			eggRows[keys[n]] = { Row = row, Button = hatchButton, Label = hatchLabel }
		end
		if #eggs == 0 then
			text({ Size = UDim2.new(1, -20, 0, 60), Text = "No eggs growing. Go STEAL some eggs!", TextColor3 = Color3.fromRGB(200, 210, 230), ZIndex = 13, Parent = eggsList })
		end
	end
	for n, slot in eggs do
		local entry = eggRows[keys[n]]
		if entry then
			local left = slot.l or 0
			local ready = left <= 0
			entry.Row.LayoutOrder = left
			entry.Label.Text = if ready then "HATCH!" else timeText(left)
			entry.Button.BackgroundColor3 = if ready then Theme.Green else Theme.Gray
		end
	end
end
onOpen.Eggs = refreshEggs
refreshers.Eggs = refreshEggs
-- o tempo dos ovos vem no atributo Slots (o servidor troca 1x por segundo enquanto há ovo crescendo)
player:GetAttributeChangedSignal("Slots"):Connect(function()
	if eggsWindow.Visible then
		refreshEggs()
	end
end)

-- (do...end: as variáveis das janelas Pets e Fusão ficam só aqui dentro - limite de 200 locais do Luau)
do
	local petsWindow, petsBody = Theme.window(gui, "Pets", "My Pets", Theme.Orange, Vector2.new(860, 560))
	windows.Pets = petsWindow
	local petsTitle = petsWindow.Header.Title
	local petsGrid = scroller(petsBody, { Size = UDim2.new(1, -16, 1, -84) }, Vector2.new(150, 196))
	button({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.new(0, 8, 1, -68), BackgroundColor3 = Theme.Red, ZIndex = 13, Parent = petsBody }, "\u{1F4B0} SELL ALL  (keeps Legendary+ and mutated)", function()
		net:FireServer("SellAll")
	end)

	local petsLazy = lazyPreviews(petsGrid)
	-- lazy = a prévia 3D nasce só quando o cartão aparece na tela (v66 perf)
	local function petCard(parent: Instance, slot, def, order: number, extra: (Frame) -> (), lazy)
		local card = create("Frame", { LayoutOrder = order, BackgroundColor3 = Theme.cardColor(def.Rarity), ZIndex = 13, Parent = parent }, { corner(10), stroke(3) })
		Theme.gloss(card, 0.35)
		local view = create("Frame", { Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1, ZIndex = 13, Parent = card })
		if lazy then
			lazy.Add(card, function()
				if view.Parent then
					Theme.preview(view, def, false, false)
				end
			end)
		else
			Theme.preview(view, def, false, false)
		end
		local label = Config.SizeLabel(slot.s or 1)
		text({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 4), Text = (if slot.m then slot.m .. " " else "") .. def.Name, ZIndex = 15, Parent = card })
		if label then
			text({ Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 82), Text = label, TextColor3 = Color3.fromRGB(255, 230, 90), ZIndex = 15, Parent = card })
		end
		text({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 102), Text = Format.Money(slot.inc or 0) .. "/s", TextColor3 = GREEN_TEXT, ZIndex = 15, Parent = card })
		extra(card)
		return card
	end

	-- v67 🐾 PARCEIRO: botão em cada cartão escolhe quem segue você; verde = o de agora ("id|mutação" do atributo
	-- Buddy: cópias iguais do mesmo bichinho ficam todas verdes). Trocar só repinta os botões (não refaz a lista)
	local pawEntries: { { Button: TextButton, Caption: TextLabel, Key: string } } = {}
	local function paintPaws()
		local current = player:GetAttribute("Buddy")
		for _, entry in pawEntries do
			local on = entry.Key == current
			entry.Button.BackgroundColor3 = if on then Theme.Green else Color3.fromRGB(70, 70, 88)
			entry.Caption.Text = L(if on then "Following" else "Follow")
		end
	end
	player:GetAttributeChangedSignal("Buddy"):Connect(paintPaws)

	local function refreshPets()
		petsLazy.Clear()
		clear(petsGrid)
		table.clear(pawEntries)
		-- (cópia: a tabela do decode é compartilhada e o sort mudaria a ordem para as outras janelas)
		local slots = table.clone(decode("Slots", {}))
		local order = 0
		table.sort(slots, function(a, b)
			return (a.inc or 0) > (b.inc or 0)
		end)
		for _, slot in slots do
			local def = Critters.ById[slot.id]
			if slot.k == "Pet" and def then
				order += 1
				petCard(petsGrid, slot, def, order, function(card)
					local key = Config.BuddyKey(slot.id, slot.m)
					local paw, pawIcon = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 28), Size = UDim2.fromOffset(56, 48), BackgroundColor3 = Color3.fromRGB(70, 70, 88), ZIndex = 16, Parent = card }, "\u{1F43E}", function()
						firstMin.BuddyTap(key)
						net:FireServer("Buddy", { slot.i, slot.id })
					end)
					pawIcon.Size = UDim2.new(1, -8, 0, 27)
					pawIcon.Position = UDim2.fromOffset(4, 2)
					local caption = text({ Size = UDim2.new(1, -6, 0, 16), Position = UDim2.new(0, 3, 1, -19), Text = "", ZIndex = 16, Parent = paw })
					table.insert(pawEntries, { Button = paw, Caption = caption, Key = key })
					if def.Keep then
						-- v67: exclusivo (do calendário ou dos convites) não vende (e fica até no Rebirth)
						text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -14, 0, 44), Text = if def.World == "friend" then L("FriendExclusive") else L("CalExclusive"), TextColor3 = Color3.fromRGB(255, 225, 120), ZIndex = 15, Parent = card })
						return
					end
					local value = math.floor((slot.inc or 0) * 100)
					-- v65: bichinho Raro+ ou com mutação: toca 2 vezes para vender (criança vendia sem querer)
					local precious = slot.m ~= nil or (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Rare
					local confirmUntil = 0
					local sellLabel
					_, sellLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -14, 0, 52), BackgroundColor3 = Theme.Red, ZIndex = 15, Parent = card }, "Sell " .. Format.Money(value), function()
						if precious and os.clock() > confirmUntil then
							confirmUntil = os.clock() + 3
							sellLabel.Text = "Sure? Tap again!"
							task.delay(3, function()
								if sellLabel.Parent and os.clock() >= confirmUntil then
									sellLabel.Text = "Sell " .. Format.Money(value)
								end
							end)
							return
						end
						net:FireServer("Sell", { slot.i, slot.id })
						-- some na hora (a lista é refeita quando chega a resposta)
						card.Visible = false
					end)
				end, petsLazy)
			end
		end
		if order == 0 then
			text({ Size = UDim2.fromOffset(500, 60), Text = "No pets yet. Hatch your eggs!", TextColor3 = Color3.fromRGB(200, 210, 230), ZIndex = 13, Parent = petsGrid })
		end
		paintPaws()
	end
	onOpen.Pets = function()
		petsTitle.Text = "My Pets"
		refreshPets()
	end
	-- a barraquinha SELL abre a mesma janela com outro título
	windows.Sell = petsWindow
	onOpen.Sell = function()
		petsTitle.Text = "\u{1F4B0} Sell Pets"
		refreshPets()
	end
	refreshers.Pets = refreshPets
	refreshers.Sell = refreshPets

	---------------------------------------------------------------------
	-- FUSE
	---------------------------------------------------------------------
	local fuseWindow, fuseBody = Theme.window(gui, "Fuse", "Fuse Machine", Theme.Cyan, Vector2.new(860, 560))
	windows.Fuse = fuseWindow
	local fuseGrid = scroller(fuseBody, { Size = UDim2.new(1, -16, 1, -84) }, Vector2.new(150, 160))
	local fuseSelected: { number } = {}
	local fuseButton, fuseLabel
	local refreshFuse
	fuseButton, fuseLabel = button({ Size = UDim2.new(1, -16, 0, 60), Position = UDim2.new(0, 8, 1, -68), BackgroundColor3 = Theme.Gray, ZIndex = 13, Parent = fuseBody }, "Pick 3 pets of the SAME rarity", function()
		if #fuseSelected == Config.FuseCount then
			net:FireServer("Fuse", fuseSelected)
			fuseSelected = {}
			task.delay(0.4, refreshFuse)
		end
	end)
	-- (v66 perf) os cartões ficam prontos: tocar num pet só muda a borda/transparência (antes refazia TODOS os
	-- cartões, cada um com prévia 3D, a cada toque). Só refaz quando a lista de pets muda.
	local fuseLazy = lazyPreviews(fuseGrid)
	local fuseCards: { [number]: any } = {} -- por slot.i: { Card, Stroke, Def, Key }
	local fuseSignature: string? = nil
	local function fuseRarity(): string?
		for _, i in fuseSelected do
			local entry = fuseCards[i]
			if entry then
				return entry.Def.Rarity
			end
		end
		return nil
	end
	local function paintFuse()
		local rarity = fuseRarity()
		for i, entry in fuseCards do
			local chosen = table.find(fuseSelected, i) ~= nil
			if entry.Stroke then
				entry.Stroke.Color = if chosen then Color3.fromRGB(80, 255, 255) else Theme.Dark
				entry.Stroke.Thickness = if chosen then 5 else 3
			end
			entry.Card.BackgroundTransparency = if rarity and entry.Def.Rarity ~= rarity and not chosen then 0.6 else 0
		end
		local nextRarity = rarity and Config.Rarities[(Config.RarityIndex[rarity] or 1) + 1]
		fuseLabel.Text = if #fuseSelected == Config.FuseCount and nextRarity then ("\u{2728} FUSE \u{2192} %s EGG!"):format(string.upper(nextRarity.Name)) else ("Pick 3 pets of the SAME rarity (%d/3)"):format(#fuseSelected)
		fuseButton.BackgroundColor3 = if #fuseSelected == Config.FuseCount then Theme.Green else Theme.Gray
	end
	refreshFuse = function()
		local pets, keys = {}, {}
		for _, slot in decode("Slots", {}) do
			-- (v67: exclusivo do calendário não funde: nem aparece aqui)
			if type(slot) == "table" and slot.k == "Pet" and Critters.ById[slot.id] and not Critters.ById[slot.id].Keep then
				table.insert(pets, slot)
				table.insert(keys, ("%s:%s:%s:%s:%s"):format(tostring(slot.i), tostring(slot.id), tostring(slot.m), tostring(slot.s), tostring(slot.inc)))
			end
		end
		local signature = table.concat(keys, "|")
		if signature ~= fuseSignature then
			fuseSignature = signature
			local oldKeys: { [number]: string } = {}
			for i, entry in fuseCards do
				oldKeys[i] = entry.Key
			end
			fuseLazy.Clear()
			clear(fuseGrid)
			table.clear(fuseCards)
			for order, slot in pets do
				local def = Critters.ById[slot.id]
				local slotIndex = slot.i
				local card = petCard(fuseGrid, slot, def, order, function(cardFrame)
					local pick = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 16, Parent = cardFrame })
					pick.Activated:Connect(function()
						local at = table.find(fuseSelected, slotIndex)
						if at then
							table.remove(fuseSelected, at)
						else
							local rarity = fuseRarity()
							if #fuseSelected < Config.FuseCount and (rarity == nil or rarity == def.Rarity) then
								table.insert(fuseSelected, slotIndex)
							end
						end
						paintFuse()
					end)
				end, fuseLazy)
				fuseCards[slotIndex] = { Card = card, Stroke = card:FindFirstChildOfClass("UIStroke"), Def = def, Key = keys[order] }
			end
			-- a lista mudou: só continua marcado o pet que ainda é o mesmo naquela vaga
			for k = #fuseSelected, 1, -1 do
				local i = fuseSelected[k]
				if not fuseCards[i] or fuseCards[i].Key ~= oldKeys[i] then
					table.remove(fuseSelected, k)
				end
			end
		end
		paintFuse()
	end
	onOpen.Fuse = function()
		fuseSelected = {}
		refreshFuse()
	end
	refreshers.Fuse = refreshFuse
	player:GetAttributeChangedSignal("Slots"):Connect(function()
		if fuseWindow.Visible then
			refreshFuse() -- (só refaz os cartões se a lista de pets mudou)
		end
	end)

	-- TRAILS e BOOSTS abrem o Shop na aba certa
	windows.Trails = shopWindow
	onOpen.Trails = function()
		shopTab = "Trails"
		refreshShop()
	end
	windows.Boosts = shopWindow
	onOpen.Boosts = function()
		shopTab = "Boosts"
		refreshShop()
	end
	refreshers.Trails = refreshShop
	refreshers.Boosts = refreshShop
end

---------------------------------------------------------------------
-- PRÊMIO DIÁRIO 2.0 (v67): 7 cartões da sequência (o próximo diz AMANHÃ), CALENDÁRIO de 28 dias embaixo
-- (marcos com bichinhos exclusivos, barra "Dia 9/28"), escudo da sequência (🛡) e contagem até o próximo
-- prêmio (meia-noite de Brasília). Os números vêm do servidor (atributos Daily*, Savers).
-- (do...end: as variáveis do Diário ficam só aqui dentro - limite de 200 locais do Luau)
---------------------------------------------------------------------
do
	local dailyWindow, dailyBody = Theme.window(gui, "Daily", L("DailyTitle"), Theme.Purple, Vector2.new(900, 520))
	windows.Daily = dailyWindow
	local dailyRow = create("Frame", { Size = UDim2.new(1, -16, 0, 184), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1, ZIndex = 12, Parent = dailyBody }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dailyClaim, dailyClaimLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(400, 74), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = dailyBody }, "CLAIM!", function()
		net:FireServer("Daily")
	end)
	-- escudo à esquerda do botão, contagem à direita
	local saverText = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -50), Size = UDim2.fromOffset(210, 38), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = dailyBody })
	text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(210, 36), Text = L("SaverInfo"), TextWrapped = true, TextColor3 = Color3.fromRGB(170, 215, 255), Stroke = 2, ZIndex = 13, Parent = dailyBody })
	local countdown = text({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(210, 74), Text = "", TextWrapped = true, TextColor3 = Color3.fromRGB(255, 230, 120), Stroke = 2, ZIndex = 13, Parent = dailyBody })

	-- CALENDÁRIO: faixa com a barra dos 28 dias e um quadrinho em cada marco (bichinho 3D ou ícone do boost)
	local strip = create("Frame", { Size = UDim2.new(1, -16, 0, 130), Position = UDim2.fromOffset(8, 198), BackgroundColor3 = Color3.fromRGB(30, 30, 42), ZIndex = 12, Parent = dailyBody }, { corner(12), stroke(3) })
	local calTitle = text({ Size = UDim2.new(0.5, -12, 0, 28), Position = UDim2.fromOffset(12, 4), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = strip })
	local calNext = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.new(0.5, -12, 0, 26), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 225, 120), Stroke = 2, ZIndex = 13, Parent = strip })
	local bar = create("Frame", { Position = UDim2.new(0, 46, 1, -20), Size = UDim2.new(1, -92, 0, 12), BackgroundColor3 = Color3.fromRGB(14, 14, 22), BorderSizePixel = 0, ZIndex = 13, Parent = strip }, { corner(6) })
	local barFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Gold, BorderSizePixel = 0, ZIndex = 14, Parent = bar }, { corner(6) })
	local milestones = {}
	for day in Config.Calendar do
		table.insert(milestones, day)
	end
	table.sort(milestones)
	local chips: { [number]: any } = {}
	for _, day in milestones do
		local info = Config.Calendar[day]
		local def = info.Critter and Critters.ById[info.Critter]
		local chip = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(day / Config.CalendarDays, 0, 0, -4), Size = UDim2.fromOffset(68, 68),
			BackgroundColor3 = if def then Theme.cardColor(def.Rarity) else Color3.fromRGB(70, 160, 80), ZIndex = 14, Parent = bar }, { corner(10), stroke(3) })
		Theme.gloss(chip, 0.3)
		local holder = create("Frame", { Size = UDim2.new(1, 0, 1, -18), BackgroundTransparency = 1, ZIndex = 14, Parent = chip })
		if not def then
			text({ Size = UDim2.fromScale(1, 1), Text = if info.Title then "\u{1F3C6}" else "\u{1F4B5}", Stroke = 0, ZIndex = 15, Parent = holder })
		end
		text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, -6, 0, 18), Text = L("DayN"):format(day), ZIndex = 17, Parent = chip })
		chips[day] = {
			Def = def,
			Holder = holder,
			Check = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -8), Size = UDim2.fromOffset(26, 26), Text = "\u{2705}", Stroke = 0, Visible = false, ZIndex = 18, Parent = chip }),
			Gold = text({ Position = UDim2.fromOffset(2, 1), Size = UDim2.new(1, -4, 0, 16), Text = L("Gold"), TextColor3 = Theme.Gold, Visible = false, ZIndex = 18, Parent = chip }),
		}
	end
	-- nome do prêmio de um marco (para "Próximo: ...")
	local function prizeName(day: number): string
		local info = Config.Calendar[day]
		local def = info and info.Critter and Critters.ById[info.Critter]
		if def then
			return def.Name
		elseif info and info.Title then
			return L("CalChamp")
		end
		local names = {}
		for _, boost in Config.Boosts do
			if info and info.Boost and info.Boost[boost.Id] then
				table.insert(names, boost.Name)
			end
		end
		return table.concat(names, " + ")
	end

	local previewsMade = false
	local function updateCountdown()
		local ready = player:GetAttribute("DailyReady") == true
		if ready then
			countdown.Text = if player:GetAttribute("DailySave") == true then L("SaverReady") else ""
			return
		end
		local left = math.max(0, math.floor((player:GetAttribute("DailyNextAt") or 0) - workspace:GetServerTimeNow()))
		local clockText = if left >= 3600 then ("%dh %02dm"):format(left // 3600, (left % 3600) // 60) else ("%dm %02ds"):format(left // 60, left % 60)
		countdown.Text = L("NewRewardIn"):format(clockText)
	end

	local function refreshDaily()
		clear(dailyRow)
		local streak = player:GetAttribute("DailyStreak") or 0
		local ready = player:GetAttribute("DailyReady") == true
		-- pronto: o dia que o botão dá AGORA (1 se a sequência zerou); senão: o dia de AMANHÃ
		local nextDay = player:GetAttribute("DailyNext") or (streak % #Config.Daily + 1)
		for day, reward in Config.Daily do
			local current = ready and day == nextDay
			local tomorrow = not ready and day == nextDay
			local done = if ready then day < nextDay else day <= streak and not tomorrow
			local card = create("Frame", { LayoutOrder = day, Size = UDim2.fromOffset(112, 178), BackgroundColor3 = if current then Theme.Gold elseif done then Theme.Green elseif tomorrow then Color3.fromRGB(70, 110, 200) else Color3.fromRGB(70, 70, 86), ZIndex = 13, Parent = dailyRow },
				{ corner(12), stroke(if current or tomorrow then 5 else 3, if current or tomorrow then Color3.new(1, 1, 1) else Theme.Dark) })
			Theme.gloss(card, 0.35)
			text({ Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 4), Text = if tomorrow then L("Tomorrow") else L("DayN"):format(day), ZIndex = 14, Parent = card })
			text({ Size = UDim2.new(1, -8, 0, 52), Position = UDim2.fromOffset(4, 36), Text = if reward.Egg then "\u{1F95A}" elseif done then "\u{2705}" else "\u{1F381}", Stroke = 0, ZIndex = 14, Parent = card })
			text({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 92), Text = reward.Minutes .. " min $", TextColor3 = GREEN_TEXT, ZIndex = 14, Parent = card })
			text({ Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 118), Text = "+" .. Format.Short(reward.Speed) .. " \u{1F45F}", TextColor3 = PINK_TEXT, ZIndex = 14, Parent = card })
			if reward.Egg then
				text({ Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 146), Text = L("RareEgg"), TextColor3 = Color3.fromRGB(255, 230, 90), ZIndex = 14, Parent = card })
			end
		end
		dailyClaimLabel.Text = if ready then L("ClaimDay"):format(nextDay) else L("ComeBack")
		dailyClaim.BackgroundColor3 = if ready then Theme.Green else Theme.Gray
		saverText.Text = ("\u{1F6E1} x%d"):format(player:GetAttribute("Savers") or 0)
		updateCountdown()
		-- calendário
		local total = player:GetAttribute("DailyTotal") or 0
		local shown = Config.CalendarDay(total) -- último dia pego nesta volta (0 = nenhum)
		calTitle.Text = L("CalendarDay"):format(shown, Config.CalendarDays)
		barFill.Size = UDim2.fromScale(shown / Config.CalendarDays, 1)
		local nextPrize, daysLeft = nil, 0
		for _, day in milestones do
			local entry = chips[day]
			local done = total > 0 and shown >= day
			-- número do prêmio (dia total) em que este marco saiu ou vai sair: 2ª volta em diante = Gold
			local claimNumber = if done then total - shown + day else total + day - shown
			entry.Check.Visible = done
			entry.Gold.Visible = entry.Def ~= nil and Config.CalendarMutation(claimNumber) ~= nil
			if not done and not nextPrize then
				nextPrize, daysLeft = day, day - shown
			end
		end
		if not nextPrize then -- volta completa: o 1º marco da próxima volta
			nextPrize = milestones[1]
			daysLeft = Config.CalendarDays - shown + nextPrize
		end
		calNext.Text = if not nextPrize then "" elseif daysLeft <= 1 then L("CalNextOne"):format(prizeName(nextPrize)) else L("CalNext"):format(prizeName(nextPrize), daysLeft)
		-- as prévias 3D (só 3) nascem na 1ª vez que a janela abre (não no começo do jogo)
		if not previewsMade then
			previewsMade = true
			for _, entry in chips do
				if entry.Def then
					pcall(Theme.preview, entry.Holder, entry.Def, false, false)
				end
			end
		end
	end
	-- a contagem anda 1x por segundo SÓ com a janela aberta
	local ticking = false
	onOpen.Daily = function()
		refreshDaily()
		if not ticking then
			ticking = true
			task.spawn(function()
				while dailyWindow.Visible do
					pcall(updateCountdown)
					task.wait(1)
				end
				ticking = false
			end)
		end
	end
	refreshers.Daily = refreshDaily
	-- virou o dia (meia-noite de Brasília) com a janela aberta: o botão acende sozinho
	player:GetAttributeChangedSignal("DailyReady"):Connect(function()
		if dailyWindow.Visible then
			refreshDaily()
		end
	end)
end

---------------------------------------------------------------------
-- MISSÕES DO DIA
---------------------------------------------------------------------
local questWindow, questBody = Theme.window(gui, "Quests", "\u{1F4DC} Daily Quests", Theme.Blue, Vector2.new(820, 520))
windows.Quests = questWindow
local questList = scroller(questBody)
local function refreshQuests()
	clear(questList)
	local q = decode("Quests", { p = {}, c = {} })
	local income = player:GetAttribute("BaseIncome") or player:GetAttribute("Income") or 0 -- prêmios usam a renda sem os 2x (v66)
	for order, info in Config.Quests do
		local progress = math.min((q.p and q.p[info.Key]) or 0, info.Goal)
		local claimed = q.c and q.c[info.Key]
		local done = progress >= info.Goal
		local cash = math.max(info.MinCash, math.floor(income * 60 * info.Minutes))
		local row = shopRow(questList, order, info.Icon, info.Name, ("%d/%d  \u{2022}  %s + %s Speed"):format(progress, info.Goal, Format.Money(cash), Format.Short(info.Speed)),
			if claimed then "CLAIMED" elseif done then "CLAIM!" else ("%d%%"):format(math.floor(progress / info.Goal * 100)),
			if claimed then Theme.Gray elseif done then Theme.Green else Color3.fromRGB(80, 80, 95), function()
				if done and not claimed then
					net:FireServer("ClaimQuest", info.Key)
				end
			end, Theme.Blue)
		-- barrinha de progresso
		local bar = create("Frame", { Size = UDim2.new(1, -310, 0, 8), Position = UDim2.new(0, 100, 1, -14), BackgroundColor3 = Color3.fromRGB(25, 25, 32), BorderSizePixel = 0, ZIndex = 13, Parent = row }, { corner(4) })
		create("Frame", { Size = UDim2.fromScale(progress / info.Goal, 1), BackgroundColor3 = if done then Theme.Green else Theme.Cyan, BorderSizePixel = 0, ZIndex = 14, Parent = bar }, { corner(4) })
	end
end
onOpen.Quests = refreshQuests
refreshers.Quests = refreshQuests
player:GetAttributeChangedSignal("Quests"):Connect(function()
	if questWindow.Visible then
		refreshQuests()
	end
end)

---------------------------------------------------------------------
-- Botões da tela (v66): SÓ 5 botões à esquerda (Loja, Índice, Ovos, Pets, Presentes) + 1 botão Menu à direita.
-- (antes: 8 coisas à esquerda + 6 quadrados à direita; no celular cobriam o joystick e o botão de pular)
---------------------------------------------------------------------
local sideButton: (number, string, string, Color3, () -> ()) -> TextButton
do
	local leftColumn = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(180, 5 * 58 + 4 * 10), BackgroundTransparency = 1, Parent = gui }, {
		create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if TOUCH then
		-- celular: colada em cima, logo abaixo da barra do Roblox (o joystick fica embaixo à esquerda;
		-- no meio da tela o botão Presentes cobria o lugar onde a criança põe o dedão)
		leftColumn.AnchorPoint = Vector2.new(0, 0)
		leftColumn.Position = UDim2.new(0, 10, 0, 4)
		local layout = leftColumn:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.Padding = UDim.new(0, 6)
		end
	end
	-- botão largo da coluna da esquerda (ícone + nome)
	sideButton = function(order: number, icon: string, label: string, color: Color3, onClick): TextButton
		local btn, txt = button({ LayoutOrder = order, Size = UDim2.fromOffset(180, 58), BackgroundColor3 = color, Parent = leftColumn }, label, onClick)
		txt.Size = UDim2.new(1, -64, 1, -10)
		txt.Position = UDim2.fromOffset(58, 5)
		txt.TextXAlignment = Enum.TextXAlignment.Left
		text({ Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(7, 6), Text = icon, Stroke = 0, Parent = btn })
		return btn
	end
end
do
	sideButton(1, "\u{1F6D2}", L("Shop"), Theme.Green, function()
		shopTab = "Upgrades"
		open("Shop", true)
	end)
	local indexButton = sideButton(2, "\u{1F4D6}", L("Index"), Theme.Blue, function()
		open("Index", true)
	end)
	firstMin.IndexButton = indexButton -- (v67: a PRÓXIMA META faz ele balançar quando tem prêmio para pegar)
	local eggsButton = sideButton(3, "\u{1F95A}", L("Eggs"), Theme.Red, function()
		open("Eggs", true)
	end)
	sideButton(4, "\u{1F43E}", L("Pets"), Theme.Orange, function()
		open("Pets", true)
	end)
	-- selos com número: prêmios do Index esperando / ovos prontos para chocar
	-- (v66: só recalcula quando o atributo muda; antes decodificava o JSON 4x por segundo)
	local indexBadge, indexBadgeText = Theme.badge(indexButton, "0")
	local eggsBadge, eggsBadgeText = Theme.badge(eggsButton, "0")
	local function countIndex()
		local unclaimed = 0
		for _, value in decode("Index", {}) do
			if value == 1 then
				unclaimed += 1
			end
		end
		indexBadge.Visible = unclaimed > 0
		indexBadgeText.Text = tostring(unclaimed)
	end
	local function countEggs()
		local ready = 0
		for _, slot in decode("Slots", {}) do
			if type(slot) == "table" and slot.k == "Egg" and (slot.l or 0) <= 0 then
				ready += 1
			end
		end
		eggsBadge.Visible = ready > 0
		eggsBadgeText.Text = tostring(ready)
	end
	player:GetAttributeChangedSignal("Index"):Connect(countIndex)
	player:GetAttributeChangedSignal("Slots"):Connect(countEggs)
	task.defer(countIndex)
	task.defer(countEggs)
end

-- missão pronta para pegar (selo no quadrado Missões do Menu)
local questReady = false
do
	local function updateQuestBadge()
		local q = decode("Quests", { p = {}, c = {} })
		local ready = false
		for _, info in Config.Quests do
			if ((q.p and q.p[info.Key]) or 0) >= info.Goal and not (q.c and q.c[info.Key]) then
				ready = true
			end
		end
		questReady = ready
	end
	player:GetAttributeChangedSignal("Quests"):Connect(updateQuestBadge)
	task.defer(updateQuestBadge)
end

---------------------------------------------------------------------
-- PRESENTES POR TEMPO JOGADO (botão "Gifts" na coluna da esquerda, com contador embaixo)
---------------------------------------------------------------------
do
	local giftWindow, giftBody = Theme.window(gui, "Gifts", "\u{1F381} Free Gifts", Theme.Pink, Vector2.new(820, 560))
	windows.Gifts = giftWindow
	local giftList = scroller(giftBody)
	local function playedSeconds(): number
		local start = player:GetAttribute("SessionStart")
		return if typeof(start) == "number" then workspace:GetServerTimeNow() - start else 0
	end
	local function giftClaimed(index: number): boolean
		return table.find(string.split(player:GetAttribute("GiftsClaimed") or "", ","), tostring(index)) ~= nil
	end
	-- (v66 perf) as linhas são criadas 1 vez (na 1ª abertura); a cada segundo só mudam textos e cores.
	-- Antes a lista era destruída e refeita 1x por segundo e o toque em CLAIM se perdia.
	local giftRows: { [number]: { Button: TextButton, Label: TextLabel, Sub: TextLabel } } = {}
	local function refreshGifts()
		if next(giftRows) == nil then
			for index, info in Config.Gifts do
				local _, giftButton, giftLabel, giftSub = shopRow(giftList, index, if info.Egg then "\u{1F95A}" else "\u{1F381}", ("Gift %d%s"):format(index, if info.Egg then "  - RARE EGG!" else ""),
					"", "", Color3.fromRGB(90, 90, 110), function()
						-- confere na hora do toque (a linha não é mais refeita)
						if not giftClaimed(index) and info.Minutes * 60 - playedSeconds() <= 0 then
							net:FireServer("Gift", index)
						end
					end, Color3.fromRGB(255, 110, 190))
				giftRows[index] = { Button = giftButton, Label = giftLabel, Sub = giftSub }
			end
		end
		local played = playedSeconds()
		local income = player:GetAttribute("BaseIncome") or player:GetAttribute("Income") or 0 -- prêmios usam a renda sem os 2x (v66)
		local claimedList = string.split(player:GetAttribute("GiftsClaimed") or "", ",")
		for index, info in Config.Gifts do
			local row = giftRows[index]
			if row then
				local left = info.Minutes * 60 - played
				local claimed = table.find(claimedList, tostring(index)) ~= nil
				local cash = math.max(info.MinCash, math.floor(income * 60 * info.Cash))
				row.Sub.Text = ("+%s  +%s Speed"):format(Format.Money(cash), Format.Short(info.Speed))
				row.Label.Text = if claimed then "CLAIMED" elseif left <= 0 then "CLAIM!" else ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
				row.Button.BackgroundColor3 = if claimed then Theme.Gray elseif left <= 0 then Theme.Green else Color3.fromRGB(90, 90, 110)
			end
		end
	end
	onOpen.Gifts = refreshGifts
	refreshers.Gifts = refreshGifts
	local giftButton = sideButton(5, "\u{1F381}", L("Gifts"), Theme.Pink, function()
		open("Gifts", true)
	end)
	local giftBadge = Theme.badge(giftButton, "!")
	local giftTimer = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(130, 24), Text = "", TextColor3 = Color3.fromRGB(255, 200, 235), Parent = giftButton })
	task.spawn(function()
		while true do
			task.wait(1)
			local played = playedSeconds()
			local ready, nextLeft = false, nil
			local claimedList = string.split(player:GetAttribute("GiftsClaimed") or "", ",")
			for index, info in Config.Gifts do
				if not table.find(claimedList, tostring(index)) then
					local left = info.Minutes * 60 - played
					if left <= 0 then
						ready = true
					elseif not nextLeft or left < nextLeft then
						nextLeft = left
					end
				end
			end
			giftBadge.Visible = ready
			giftTimer.Text = if ready then L("Ready") elseif nextLeft then ("%d:%02d"):format(math.floor(nextLeft / 60), math.floor(nextLeft % 60)) else ""
			if giftWindow.Visible then
				refreshGifts()
			end
		end
	end)
end

---------------------------------------------------------------------
-- CÓDIGOS (v65): janela para digitar (v66: abre pelo Menu)
---------------------------------------------------------------------
do
	local codeWindow, codeBody = Theme.window(gui, "Codes", "\u{1F39F} Codes", Theme.Cyan, Vector2.new(640, 330))
	windows.Codes = codeWindow
	text({ Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 12), Text = "New codes every Saturday update - check our group!", TextColor3 = Color3.fromRGB(190, 215, 255), Stroke = 2, ZIndex = 13, Parent = codeBody })
	local box = create("TextBox", {
		Size = UDim2.new(1, -24, 0, 72),
		Position = UDim2.fromOffset(12, 56),
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
		Text = "",
		PlaceholderText = "Type a code here",
		PlaceholderColor3 = Color3.fromRGB(140, 140, 155),
		TextColor3 = Color3.fromRGB(30, 30, 40),
		Font = Theme.Font,
		TextScaled = true,
		ClearTextOnFocus = false,
		ZIndex = 13,
		Parent = codeBody,
	}, { corner(10), stroke(3) })
	create("UITextSizeConstraint", { MaxTextSize = 44, Parent = box })
	button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 142), Size = UDim2.fromOffset(260, 66), BackgroundColor3 = Theme.Green, ZIndex = 13, Parent = codeBody }, "REDEEM", function()
		if box.Text ~= "" then
			net:FireServer("Redeem", string.sub(box.Text, 1, 30))
		end
	end)
	net.OnClientEvent:Connect(function(kind)
		if kind == "CodeOk" then
			box.Text = ""
			codeWindow.Visible = false
		end
	end)
end

---------------------------------------------------------------------
-- HALLOWEEN (v65): Loja de Doces (v66: abre pelo quadrado "Doces" do Menu, que só aparece durante o evento)
---------------------------------------------------------------------
do
	local candyWindow, candyBody = Theme.window(gui, "Halloween", "\u{1F383} Candy Shop", Theme.Orange, Vector2.new(820, 560))
	windows.Halloween = candyWindow
	local header = text({ Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 10), Text = "", TextColor3 = Color3.fromRGB(255, 200, 120), ZIndex = 13, Parent = candyBody })
	local candyList = scroller(candyBody, { Size = UDim2.new(1, -16, 1, -64), Position = UDim2.fromOffset(8, 56) })
	local ICONS = { pumpkinopinguino = "\u{1F427}", pumpkat = "\u{1F431}", batwing = "\u{1F987}", vampiropepperoni = "\u{1F9DB}" }
	local function refreshCandy()
		local candy = player:GetAttribute("Candy") or 0
		header.Text = ("\u{1F36C} %d candy  -  steal eggs: +%d  |  Pumpkin Eggs: +%d"):format(candy, Config.Halloween.CandyPerEgg, Config.Halloween.CandyPerPumpkin)
		clear(candyList)
		for index, item in Config.Halloween.Shop do
			local def = Critters.ById[item.Critter]
			if def then
				shopRow(candyList, index, ICONS[item.Critter] or "\u{1F383}", ("%s%s"):format(if item.Mut then item.Mut .. " " else "", def.Name),
					("%s  -  ready to hatch!"):format(string.upper(def.Rarity)), ("\u{1F36C} %d"):format(item.Cost),
					if candy >= item.Cost then Theme.Green else Theme.Gray, function()
						net:FireServer("CandyBuy", index)
					end, Theme.rarityColor(def.Rarity))
			end
		end
	end
	onOpen.Halloween = refreshCandy
	refreshers.Halloween = refreshCandy
	local function update()
		local on = workspace:GetAttribute("Halloween") == true
		if not on then
			candyWindow.Visible = false
		elseif candyWindow.Visible then
			refreshCandy()
		end
	end
	workspace:GetAttributeChangedSignal("Halloween"):Connect(update)
	player:GetAttributeChangedSignal("Candy"):Connect(update)
	task.defer(update)
end

---------------------------------------------------------------------
-- OFERTA NA HORA CERTA (cartão pequeno à direita; some sozinho)
---------------------------------------------------------------------
local showOffer
do
	local offerCard = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, -40), Size = UDim2.fromOffset(340, 210), BackgroundColor3 = Color3.fromRGB(255, 140, 50), Visible = false, ZIndex = 25, Parent = gui }, { corner(16), stroke(4) })
	Theme.gloss(offerCard, 0.3)
	local offerIcon = text({ Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 10), Text = "\u{1F381}", Stroke = 0, ZIndex = 26, Parent = offerCard })
	local offerTitle = text({ Size = UDim2.new(1, -100, 0, 40), Position = UDim2.fromOffset(86, 12), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 26, Parent = offerCard })
	local offerDesc = text({ Size = UDim2.new(1, -100, 0, 28), Position = UDim2.fromOffset(86, 52), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 245, 220), Stroke = 2, ZIndex = 26, Parent = offerCard })
	local offerReason = text({ Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 88), Text = "", Stroke = 2, ZIndex = 26, Parent = offerCard })
	local offerKey = nil
	local _, offerBuyLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(220, 62), BackgroundColor3 = Theme.Green, ZIndex = 26, Parent = offerCard }, "R$ 0", function()
		if offerKey then
			net:FireServer("Buy", offerKey)
		end
		offerCard.Visible = false
	end)
	button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = Theme.Red, ZIndex = 27, Parent = offerCard }, "X", function()
		offerCard.Visible = false
	end)
	local offerSerial = 0
	showOffer = function(key: string, reason: string?)
		local info = Config.ProductByKey[key] or Config.PassByKey[key]
		if not info then
			return
		end
		offerKey = key
		offerIcon.Text = info.Icon or "\u{1F381}"
		offerTitle.Text = info.Name
		offerDesc.Text = info.Desc or ""
		offerReason.Text = reason or ""
		offerBuyLabel.Text = ("R$ %d"):format(robuxPrice(info))
		offerCard.BackgroundColor3 = info.Color or Color3.fromRGB(255, 140, 50)
		offerCard.Visible = true
		Theme.popIn(offerCard)
		sfx("Pop")
		offerSerial += 1
		local mine = offerSerial
		task.delay(14, function()
			if offerSerial == mine then
				offerCard.Visible = false
			end
		end)
	end
end

---------------------------------------------------------------------
-- MENU (v66): UM botão na direita, no meio da altura (nunca em cima do botão de pular do celular).
-- "!" vermelho quando tem algo pronto lá dentro. Abre uma grade de quadrados grandes:
-- Diário, Missões, Rebirth, Boosts, Códigos, Doces (só no Halloween), Convidar, Som, Modo Lento e Admin (só admins).
---------------------------------------------------------------------
local refreshMenuBadge: () -> () = function() end -- (a de verdade fica dentro do bloco abaixo)
do
	local MENU_COLOR = Color3.fromRGB(70, 90, 210)
	local soundOn = true
	local slowOn = false
	local adminMenuSeen = false -- admin: "!" no Menu até abrir uma vez (para achar o painel)
	local menuWindow, menuBody = Theme.window(gui, "Menu", L("Menu"), MENU_COLOR, Vector2.new(840, 440))
	windows.Menu = menuWindow
	local menuGrid = scroller(menuBody, nil, Vector2.new(150, 150))
	local menuTiles: { [string]: any } = {}
	-- quadrado do Menu: ícone grande + nome + texto pequeno (opcional) + selo "!".
	-- keepOpen = liga/desliga (Som, Modo Lento): o Menu continua aberto
	local function menuTile(key: string, order: number, icon: string, color: Color3, onClick: () -> (), keepOpen: boolean?)
		local tile = button({ LayoutOrder = order, BackgroundColor3 = color, ZIndex = 13, Parent = menuGrid }, "", function()
			if not keepOpen then
				menuWindow.Visible = false
			end
			onClick()
			refreshMenuBadge()
		end)
		local iconLabel = text({ Size = UDim2.new(1, -24, 0, 64), Position = UDim2.fromOffset(12, 8), Text = icon, Stroke = 0, ZIndex = 14, Parent = tile })
		text({ Size = UDim2.new(1, -12, 0, 32), Position = UDim2.fromOffset(6, 76), Text = L(key), ZIndex = 14, Parent = tile })
		-- (2 linhas: o texto do Convidar é comprido e ficaria minúsculo no celular)
		local sub = text({ Size = UDim2.new(1, -12, 0, 38), Position = UDim2.fromOffset(6, 108), Text = "", TextWrapped = true, TextColor3 = Color3.fromRGB(255, 245, 210), Stroke = 2, ZIndex = 14, Parent = tile })
		create("UITextSizeConstraint", { MaxTextSize = 24, Parent = sub })
		local badge = Theme.badge(tile, "!")
		local entry = { Tile = tile, Icon = iconLabel, Sub = sub, Badge = badge }
		menuTiles[key] = entry
		return entry
	end
	menuTile("Daily", 1, "\u{1F381}", Theme.Purple, function()
		open("Daily")
	end)
	menuTile("Quests", 2, "\u{1F4DC}", Theme.Blue, function()
		open("Quests")
	end)
	menuTile("Rebirth", 3, "\u{1F504}", Color3.fromRGB(200, 70, 220), function()
		shopTab = "Rebirth"
		open("Shop")
	end)
	menuTile("Boosts", 4, "\u{1F9EA}", Theme.Green, function()
		open("Boosts") -- abre o Shop na aba Boosts
	end)
	menuTile("Codes", 5, "\u{1F39F}", Theme.Cyan, function()
		open("Codes")
	end)
	menuTile("Candy", 6, "\u{1F383}", Theme.Orange, function()
		open("Halloween")
	end)
	-- (v65: o bônus é por AMIGO JOGANDO junto, não por convite enviado)
	-- v67 ESCADA DE CONVITES: o texto pequeno mostra o próximo degrau ("2/3 amigos → Pal Pup") e a janela de
	-- convite da Roblox mostra a escada inteira (Config.InviteLadder; só conta amigo que entrou e jogou)
	local function ladderPrize(step): string
		local def = step.Critter and Critters.ById[step.Critter]
		return if def then def.Name elseif step.Trail then L("LadderTrail") else L("LadderTitle")
	end
	menuTile("Invite", 7, "\u{1F465}", Color3.fromRGB(255, 120, 60), function()
		local steps = {}
		for _, step in Config.InviteLadder do
			table.insert(steps, ("%d = %s"):format(step.Count, ladderPrize(step)))
		end
		pcall(function()
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = L("InviteMsg"):format(table.concat(steps, ", "))
			game:GetService("SocialService"):PromptGameInvite(player, options)
		end)
	end)
	task.spawn(function()
		local ok, can = pcall(function()
			return game:GetService("SocialService"):CanSendGameInviteAsync(player)
		end)
		firstMin.CanInvite = if ok then can == true else nil
	end)
	menuTile("Sound", 8, "\u{1F50A}", Color3.fromRGB(110, 90, 200), function()
		soundOn = not soundOn
		player:SetAttribute("Muted", not soundOn)
		local music = SoundService:FindFirstChild("Music")
		if music then
			music.Volume = if soundOn then (Config.Sounds.Music.Volume or 0.2) else 0
		end
	end, true)
	menuTile("SlowMode", 9, "\u{1F422}", Color3.fromRGB(70, 150, 90), function()
		slowOn = not slowOn
		net:FireServer("SlowMode", slowOn)
	end, true)
	menuTile("Admin", 10, "\u{26A1}", Theme.Red, function()
		open("Admin")
	end)

	-- botão Menu (3 risquinhos desenhados: o símbolo ☰ não existe em todas as fontes)
	local menuButton = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, if TOUCH then -10 else -14, 0.5, 0), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = MENU_COLOR, Parent = gui }, "", function()
		if player:GetAttribute("IsAdmin") == true then
			adminMenuSeen = true
		end
		open("Menu", true)
	end)
	for k = 0, 2 do
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 11 + k * 12), Size = UDim2.fromOffset(40, 7), BackgroundColor3 = Theme.White, BorderSizePixel = 0, Parent = menuButton }, { corner(3), stroke(2) })
	end
	text({ Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0, 4, 1, -26), Text = L("Menu"), Parent = menuButton })
	local menuBadge = Theme.badge(menuButton, "!")

	-- atualiza os quadrados (selos, textos pequenos, quem aparece) e devolve se tem algo pronto
	local function updateMenu(): boolean
		local money = player:GetAttribute("Money") or 0
		local rebirths = player:GetAttribute("Rebirths") or 0
		local progress = math.clamp(money / math.max(Config.RebirthCost(rebirths), 1), 0, 1)
		local dailyReady = player:GetAttribute("DailyReady") == true
		local halloween = workspace:GetAttribute("Halloween") == true
		local candy = player:GetAttribute("Candy") or 0
		local candyReady = false
		if halloween then
			for _, item in Config.Halloween.Shop do
				if candy >= item.Cost then
					candyReady = true
				end
			end
		end
		local admin = player:GetAttribute("IsAdmin") == true
		menuTiles.Daily.Badge.Visible = dailyReady
		-- (v67) não pronto: em que dia do calendário de 28 dias você está
		local calendarDay = Config.CalendarDay(player:GetAttribute("DailyTotal") or 0)
		menuTiles.Daily.Sub.Text = if dailyReady then L("Ready") elseif calendarDay > 0 then L("CalendarShort"):format(calendarDay, Config.CalendarDays) else ""
		menuTiles.Quests.Badge.Visible = questReady
		menuTiles.Quests.Sub.Text = if questReady then L("Ready") else ""
		menuTiles.Rebirth.Badge.Visible = progress >= 1
		menuTiles.Rebirth.Sub.Text = if progress >= 1 then L("Ready") else ("%d%%"):format(math.floor(progress * 100))
		menuTiles.Candy.Tile.Visible = halloween
		menuTiles.Candy.Badge.Visible = candyReady
		menuTiles.Candy.Sub.Text = ("\u{1F36C} %d"):format(candy)
		menuTiles.Sound.Icon.Text = if soundOn then "\u{1F50A}" else "\u{1F507}"
		menuTiles.Sound.Sub.Text = if soundOn then L("On") else L("Off")
		menuTiles.Sound.Sub.TextColor3 = if soundOn then GREEN_TEXT else Color3.fromRGB(255, 120, 120)
		menuTiles.SlowMode.Sub.Text = if slowOn then L("On") else L("Off")
		menuTiles.SlowMode.Sub.TextColor3 = if slowOn then GREEN_TEXT else Color3.fromRGB(255, 120, 120)
		menuTiles.Admin.Tile.Visible = admin
		-- (v67) próximo degrau da escada de convites; escada completa = o bônus de amigo jogando junto
		local friends = player:GetAttribute("Referred") or 0
		local nextStep = Config.LadderNext(friends)
		menuTiles.Invite.Sub.Text = if nextStep then L("InviteNext"):format(friends, nextStep.Count, ladderPrize(nextStep))
			else L("InviteSub"):format(math.floor((Config.FriendBoost or 0.25) * 100 + 0.5))
		return dailyReady or questReady or progress >= 1 or candyReady or (admin and not adminMenuSeen)
	end
	refreshMenuBadge = function()
		menuBadge.Visible = updateMenu()
	end
	onOpen.Menu = refreshMenuBadge
	refreshers.Menu = refreshMenuBadge
	task.defer(refreshMenuBadge)

	---------------------------------------------------------------------
	-- ADMIN (v66, só admins): liga eventos AO VIVO em todos os servidores (o servidor confere quem é admin).
	-- Toque 2 vezes para confirmar (um toque sem querer mexeria em TODOS os servidores).
	---------------------------------------------------------------------
	do
		local abuse = Config.AdminAbuse or { LuckMult = 10, Minutes = 15 }
		local adminWindow, adminBody = Theme.window(gui, "Admin", "\u{26A1} " .. L("Admin"), Theme.Red, Vector2.new(640, 560))
		windows.Admin = adminWindow
		text({ Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 10), Text = L("AdminInfo"), TextColor3 = Color3.fromRGB(255, 220, 120), Stroke = 2, ZIndex = 13, Parent = adminBody })
		local list = create("Frame", { Size = UDim2.new(1, -24, 1, -64), Position = UDim2.fromOffset(12, 54), BackgroundTransparency = 1, ZIndex = 12, Parent = adminBody }, {
			create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local commands = {
			{ "Luck", L("AdminLuck"):format(math.floor(abuse.LuckMult or 10), math.floor(abuse.Minutes or 15)), Theme.Green },
			{ "Golden", L("AdminGolden"), Color3.fromRGB(235, 175, 30) },
			{ "Party", L("AdminParty"), Theme.Purple },
			{ "Money", L("AdminMoney"):format(math.floor(abuse.Minutes or 15)), Color3.fromRGB(40, 160, 80) },
			{ "Pumpkin", L("AdminPumpkin"), Theme.Orange },
		}
		for order, info in commands do
			local cmd, label, color = info[1], info[2], info[3]
			local confirmUntil = 0
			local commandLabel
			_, commandLabel = button({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = color, ZIndex = 13, Parent = list }, label, function()
				if player:GetAttribute("IsAdmin") ~= true then
					return
				end
				if os.clock() > confirmUntil then
					confirmUntil = os.clock() + 3
					commandLabel.Text = L("TapConfirm")
					task.delay(3, function()
						if commandLabel.Parent and os.clock() >= confirmUntil then
							commandLabel.Text = label
						end
					end)
					return
				end
				confirmUntil = 0
				commandLabel.Text = label
				net:FireServer("Admin", { cmd = cmd })
			end)
		end
		player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
			if player:GetAttribute("IsAdmin") ~= true then
				adminWindow.Visible = false
			end
			refreshMenuBadge()
		end)
	end

	-- v66: janela maior que a tela (celular com a tela no 0.6) encolhe para caber com margem
	local function fitAllWindows()
		local screen = gui.AbsoluteSize
		if screen.X < 50 or screen.Y < 50 then
			return
		end
		local scale = math.max(uiScale.Scale, 0.1)
		local done: { [Frame]: boolean } = {}
		for _, window in windows do
			if not done[window] then
				done[window] = true
				local width, height = window.Size.X.Offset, window.Size.Y.Offset
				if width > 0 and height > 0 then
					-- a janela fica centrada em 52% da altura: cabe se a metade de baixo couber
					local fit = math.min(1, (screen.X - 24) / (width * scale), (screen.Y * 0.96 - 24) / (height * scale))
					Theme.fit(window, math.max(fit, 0.35))
				end
			end
		end
	end
	fitWindows = fitAllWindows
	fitAllWindows()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
end

-- DIÁRIO ABRE SOZINHO (v67: "primeiros minutos quietos"): quem já jogou antes (Stolen > 0) vê aos 6 s, como antes.
-- Novato não: o Diário espera o 1º ovo chocado (ver "Hatched"), para a criança aprender a roubar primeiro.
task.delay(6, function()
	local waited = 0
	while player:GetAttribute("Stolen") == nil and waited < 20 do
		waited += task.wait(1) -- (o save ainda carregando)
	end
	if (player:GetAttribute("Stolen") or 0) > 0 and player:GetAttribute("DailyReady") == true and not firstMin.DailyShown and (waited == 0 or not anyWindowOpen()) then
		firstMin.DailyShown = true
		open("Daily")
	end
end)

---------------------------------------------------------------------
-- Faixa grande e avisos
---------------------------------------------------------------------
local bannerText = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(900, 86), Text = "", Stroke = 6, Visible = false, ZIndex = 30, Parent = gui })
if TOUCH then
	-- celular: não passa por cima dos 2 relógios do canto de cima à direita (320 de largura de cada lado)
	bannerText.Size = UDim2.new(1, -680, 0, 76)
end
local bannerToken = 0
local function showBanner(message: string, color: Color3?)
	bannerToken += 1
	local token = bannerToken
	bannerText.Text = message
	bannerText.TextColor3 = color or Color3.new(1, 1, 1)
	bannerText.Visible = true
	Theme.popIn(bannerText)
	task.delay(3.2, function()
		if bannerToken == token then
			bannerText.Visible = false
		end
	end)
end

local toastHolder = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(640, 230), BackgroundTransparency = 1, ZIndex = 30, Parent = gui }, {
	create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toastColors = { info = Color3.fromRGB(50, 120, 230), success = Color3.fromRGB(40, 170, 70), warning = Color3.fromRGB(235, 150, 30), error = Color3.fromRGB(215, 45, 60), rare = Color3.fromRGB(165, 70, 240) }
local toastOrder = 0
local function showToast(message: string, kind: string?)
	toastOrder += 1
	local frame = create("Frame", { LayoutOrder = toastOrder, Size = UDim2.fromOffset(620, 42), BackgroundColor3 = toastColors[kind or "info"] or toastColors.info, ZIndex = 30, Parent = toastHolder }, { corner(10), stroke(3) })
	Theme.gloss(frame, 0.3)
	text({ Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Text = message, ZIndex = 31, Parent = frame })
	local items = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(items, child)
		end
	end
	if #items > 4 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(4.5, function()
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

-- chuva de moedas na tela (roubar / vender / presente)
local function coinBurst(count: number?, color: Color3?)
	for _ = 1, count or 18 do
		local coin = text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(44, 44),
			Text = if color then "\u{2B50}" else "\u{1FA99}",
			Stroke = 0,
			ZIndex = 35,
			Parent = gui,
		})
		local target = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.7, 0.55 + (math.random() - 0.6) * 0.6)
		TweenService:Create(coin, TweenInfo.new(0.5 + math.random() * 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target, Rotation = math.random(-90, 90) }):Play()
		task.delay(0.8, function()
			-- as moedas voam para o dinheiro (canto de baixo à esquerda)
			TweenService:Create(coin, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, 120, 1, -60), TextTransparency = 1 }):Play()
		end)
		task.delay(1.4, function()
			coin:Destroy()
		end)
	end
end

-- MOMENTO ÉPICO (servidor inteiro): faixa gigante no meio da tela, tela treme, som e estrelas
local epicLabel = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(1000, 80), Text = "", Stroke = 6, Visible = false, ZIndex = 50, Parent = gui })
local epicSerial = 0
function showEpic(message: string, color: Color3?)
	epicSerial += 1
	local mine = epicSerial
	epicLabel.Text = message
	epicLabel.TextColor3 = if typeof(color) == "Color3" then color else Color3.fromRGB(255, 220, 60)
	epicLabel.Visible = true
	epicLabel.Rotation = -4
	epicLabel.Size = UDim2.fromOffset(500, 40)
	TweenService:Create(epicLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(1000, 80), Rotation = 0 }):Play()
	sfx("Alarm", 1.2)
	sfx("Delivered")
	coinBurst(20, epicLabel.TextColor3)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		task.spawn(function()
			for k = 1, 14 do
				humanoid.CameraOffset = Vector3.new(math.random(-10, 10) / 18, math.random(-10, 10) / 18, 0) * (1 - k / 14)
				task.wait(0.03)
			end
			humanoid.CameraOffset = Vector3.zero
		end)
	end
	task.delay(4, function()
		if epicSerial == mine then
			epicLabel.Visible = false
		end
	end)
end

local function floatText(message: string, color: Color3)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local board = create("BillboardGui", { Size = UDim2.fromScale(6, 2), StudsOffsetWorldSpace = Vector3.new(math.random(-15, 15) / 10, 2, 0), Adornee = head, AlwaysOnTop = true, Parent = gui })
	local label = text({ Size = UDim2.fromScale(1, 1), Text = message, TextColor3 = color, Parent = board })
	local labelStroke = label:FindFirstChildOfClass("UIStroke")
	TweenService:Create(board, TweenInfo.new(1.2), { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
	if labelStroke then
		TweenService:Create(labelStroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	end
	task.delay(1.3, function()
		board:Destroy()
	end)
end

---------------------------------------------------------------------
-- v67 EMOÇÃO: "soco" de zoom da câmera (FOV) e carimbo SALVO! na entrega.
-- (as duas funções ficam numa tabela só: limite de 200 locais do Luau neste arquivo)
--   FOV normal 70; correndo com ovo 78 (sensação de velocidade); bichinho novo Raro/Épico 60, Lendário+ 52 e volta.
--   Só mexe com a câmera normal (CameraType Custom); volta ao normal ao entregar, ser pego ou nascer de novo.
---------------------------------------------------------------------
local juice = {
	Punch = function(_target: number) end,
	Stamp = function() end,
}
do
	local BASE_FOV, CARRY_FOV = 70, 78
	local token = 0 -- cada pedido novo ganha um número: o "volta ao normal" de um soco antigo não briga com o novo
	local tween: Tween? = nil
	local function rest(): number
		return if player:GetAttribute("Carrying") then CARRY_FOV else BASE_FOV
	end
	local function fovTo(target: number, time: number, style: Enum.EasingStyle?): boolean
		local camera = workspace.CurrentCamera
		if not camera or camera.CameraType ~= Enum.CameraType.Custom then
			return false
		end
		if tween then
			tween:Cancel()
		end
		local created = TweenService:Create(camera, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = target })
		tween = created
		created:Play()
		return true
	end
	juice.Punch = function(target: number)
		token += 1
		local mine = token
		if fovTo(target, 0.08) then
			task.delay(0.12, function()
				if token == mine then
					fovTo(rest(), 0.5, Enum.EasingStyle.Sine)
				end
			end)
		end
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		token += 1
		fovTo(rest(), 0.4)
	end)
	player.CharacterAdded:Connect(function()
		token += 1
		if tween then
			tween:Cancel()
			tween = nil
		end
		local camera = workspace.CurrentCamera
		if camera and camera.CameraType == Enum.CameraType.Custom then
			camera.FieldOfView = BASE_FOV
		end
	end)

	-- carimbo SALVO! torto no meio da tela + clarão branco rápido (criados 1 vez e reaproveitados)
	local stamp = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(560, 150), Text = "", Rotation = -8,
		TextColor3 = Color3.fromRGB(120, 255, 120), Stroke = 8, Visible = false, ZIndex = 38, Parent = gui })
	local stampStroke = stamp:FindFirstChildOfClass("UIStroke")
	local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Active = false, ZIndex = 37, Parent = gui })
	local serial = 0
	juice.Stamp = function()
		serial += 1
		local mine = serial
		stamp.Text = L("Safe")
		stamp.TextTransparency = 0
		if stampStroke then
			stampStroke.Transparency = 0
		end
		stamp.Visible = true
		Theme.popIn(stamp)
		flash.BackgroundTransparency = 0.45
		flash.Visible = true
		TweenService:Create(flash, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
		task.delay(0.85, function()
			if serial == mine then
				TweenService:Create(stamp, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
				if stampStroke then
					TweenService:Create(stampStroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
				end
			end
		end)
		task.delay(1.2, function()
			if serial == mine then
				stamp.Visible = false
				flash.Visible = false
			end
		end)
	end
end

---------------------------------------------------------------------
-- ANIMAÇÃO DE CHOCAR: ovo treme, racha, flash e o bichinho aparece com confete
---------------------------------------------------------------------
local hatchQueue = {}
local hatchBusy = false
local hatchLayer = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 40, Active = false, Parent = gui })

-- camada só de efeitos (confete da zona nova): não bloqueia toques
local fxLayer = create("Frame", { Name = "Fx", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 45, Active = false, Parent = gui })

local function confetti(color: Color3, layer: GuiObject?)
	for _ = 1, 40 do
		local piece = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = if math.random() < 0.5 then color else Color3.fromHSV(math.random(), 0.8, 1),
			BorderSizePixel = 0,
			ZIndex = 45,
			Parent = layer or hatchLayer,
		})
		local target = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.9, 0.45 + (math.random() - 0.3) * 0.9)
		TweenService:Create(piece, TweenInfo.new(1.4 + math.random() * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target, Rotation = piece.Rotation + math.random(-360, 360), BackgroundTransparency = 1 }):Play()
		task.delay(2.2, function()
			piece:Destroy()
		end)
	end
end

local function playHatch(entry)
	local def = Critters.ById[entry[1]]
	if not def then
		return
	end
	local mutation, scale = entry[2], entry[3] or 1
	local rarityColor = Theme.rarityColor(def.Rarity)
	hatchLayer.Visible = true
	TweenService:Create(hatchLayer, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
	local rays = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1, ZIndex = 41, Parent = hatchLayer })
	for k = 0, 7 do
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 40, 1, 0), Rotation = k * 22.5, BackgroundColor3 = rarityColor, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 41, Parent = rays })
	end
	local spinning = true
	task.spawn(function()
		while spinning and rays.Parent do
			rays.Rotation += 1
			task.wait(1 / 60)
		end
	end)
	-- ovo 3D de verdade (o estilo da zona de onde ele veio) dentro de uma janelinha 3D
	local egg = create("ViewportFrame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, Ambient = Color3.fromRGB(210, 210, 210), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 43, Parent = hatchLayer })
	local eggModel
	pcall(function()
		local zone = Config.Zones[entry[4] or 1] or Config.Zones[1]
		eggModel = require(ReplicatedStorage.Shared.CritterBuilder).BuildEgg({ Name = def.Name .. " Egg", Size = 3.4, Style = zone.Egg.Style, Color = zone.Egg.Color, Accent = zone.Egg.Accent })
		eggModel:PivotTo(CFrame.new())
		eggModel.Parent = egg
		local cf, size = eggModel:GetBoundingBox()
		local cam = create("Camera", { FieldOfView = 40, CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.15, size.Y * 2.6), cf.Position), Parent = egg })
		egg.CurrentCamera = cam
	end)
	-- o ovo já tremeu e rachou NA BASE (todo mundo vê); aqui é só uma tremidinha antes de revelar
	for shake = 3, 3 do
		sfx("Crack", 0.9 + shake * 0.12)
		for _ = 1, 6 do
			local angle = math.rad(math.random(-14, 14) * shake / 2)
			if eggModel then
				eggModel:PivotTo(CFrame.Angles(0, 0, angle))
			end
			egg.Rotation = math.deg(angle) * 0.3
			task.wait(0.04)
		end
		if eggModel then
			eggModel:PivotTo(CFrame.new())
		end
		egg.Rotation = 0
		egg.Size = UDim2.fromOffset(300 + shake * 24, 300 + shake * 24)
		task.wait(0.28)
	end
	local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 46, Parent = hatchLayer })
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	-- v67: soco de zoom na revelação (Raro/Épico pouco, Lendário+ forte)
	local revealIndex = Config.RarityIndex[def.Rarity] or 1
	if revealIndex >= Config.RarityIndex.Legendary then
		juice.Punch(52)
	elseif revealIndex >= Config.RarityIndex.Rare then
		juice.Punch(60)
	end
	task.delay(0.55, function()
		flash:Destroy()
	end)
	egg:Destroy()
	sfx("Pop")
	if (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Legendary then
		sfx("Delivered")
	end
	local card = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 1, ZIndex = 43, Parent = hatchLayer })
	Theme.preview(card, def, false, true).ZIndex = 44
	local label = Config.SizeLabel(scale)
	local title = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 170), Size = UDim2.fromOffset(700, 64), Text = ("%s%s%s"):format(if mutation then mutation .. " " else "", if label then label .. " " else "", def.Name), Stroke = 5, ZIndex = 44, Parent = hatchLayer })
	local sub = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 236), Size = UDim2.fromOffset(500, 44), Text = string.upper(def.Rarity), TextColor3 = rarityColor, Stroke = 4, ZIndex = 44, Parent = hatchLayer })
	Theme.popIn(card)
	Theme.popIn(title)
	confetti(rarityColor)
	-- v67 MOSTRAR PROS AMIGOS: Lendário+ ou com mutação = o cartão fica 4 s com um botão (à direita do bichinho:
	-- embaixo não cabe no celular) que abre o convite da Roblox ("Venha ver meu ...!"). Quem entra por ele vê a seta
	-- no seu cercado. Compartilhar não dá prêmio; só conta o amigo que entra e joga (escada de convites).
	local share: GuiObject? = nil
	local stopPulse: (() -> ())? = nil
	if (revealIndex >= Config.RarityIndex.Legendary or mutation ~= nil) and firstMin.CanInvite ~= false then
		share = button({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 170, 0.45, 0), Size = UDim2.fromOffset(280, 84), BackgroundColor3 = Theme.Blue, ZIndex = 45, Parent = hatchLayer }, L("ShareBtn"), function()
			if os.clock() - firstMin.ShareAt < Config.ShareGap then
				showToast(L("ShareWait"), "info")
				return
			end
			firstMin.ShareAt = os.clock()
			pcall(function()
				local options = Instance.new("ExperienceInviteOptions")
				options.PromptMessage = L("ShareMsg"):format((if mutation then mutation .. " " else "") .. def.Name)
				options.LaunchData = ("b:%d:%s"):format(player.UserId, def.Id)
				game:GetService("SocialService"):PromptGameInvite(player, options)
			end)
		end)
		if share then
			stopPulse = Theme.pulse(share)
		end
	end
	task.wait(if share then 4 else 2.2)
	spinning = false
	if stopPulse then
		stopPulse()
	end
	if share then
		share:Destroy()
	end
	for _, item in { card, title, sub, rays } do
		item:Destroy()
	end
end

local function queueHatch(list)
	table.sort(list, function(a, b)
		local da, db = Critters.ById[a[1]], Critters.ById[b[1]]
		return (da and Config.RarityIndex[da.Rarity] or 0) > (db and Config.RarityIndex[db.Rarity] or 0)
	end)
	for index, entry in list do
		if index <= 3 then
			table.insert(hatchQueue, entry)
		end
	end
	if hatchBusy then
		return
	end
	hatchBusy = true
	task.spawn(function()
		-- celular: a barra do bastão/armadilha (por cima de tudo) cobria o nome e a raridade do bichinho novo
		local StarterGui = game:GetService("StarterGui")
		if TOUCH then
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		end
		while #hatchQueue > 0 do
			local ok, err = pcall(playHatch, table.remove(hatchQueue, 1))
			if not ok then
				warn("[Hatch] animação falhou:", err)
			end
		end
		TweenService:Create(hatchLayer, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		task.wait(0.3)
		hatchLayer.Visible = false
		if TOUCH then
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, true)
		end
		hatchBusy = false
	end)
end

-- taco: animação do braço (todo mundo vê) e aviso de atordoado
local swinging: { [Model]: number } = {}
local stunText = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(500, 70), Text = "\u{1F4AB} STUNNED!", TextColor3 = Color3.fromRGB(255, 220, 90), Stroke = 5, Visible = false, ZIndex = 30, Parent = gui })

-- (celular, v66: EMBAIXO no meio, logo acima do dinheiro/velocidade; antes ficava em cima, por baixo da faixa
-- grande "RUN!!" (y 40..126). Ali embaixo não encosta em nada: carregando ovo, a dica do tutorial e o painel
-- da esteira ficam escondidos; o joystick e o botão de pular ficam nos cantos)
local carryText = text({ AnchorPoint = Vector2.new(0.5, 1), Position = if TOUCH then UDim2.new(0.5, 0, 1, -150) else UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(if TOUCH then 600 else 760, if TOUCH then 48 else 54), Text = L("CarryRun"), TextColor3 = Color3.fromRGB(255, 225, 80), Stroke = 5, Visible = false, Parent = gui })

-- tela escura da noite (o muro e o céu fazem o resto)
local nightShade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 15, 50), BackgroundTransparency = 1, ZIndex = 0, Parent = gui })

-- v67: pede para FAVORITAR o jogo 1 vez por conta, SEM prêmio (a Roblox não deixa premiar favorito).
-- Só num momento feliz (zona nova ou Lendário+ chocado), depois de 8 min jogando e nunca carregando ovo.
firstMin.TryFavorite = function()
	local waited = 0
	while (hatchBusy or hatchLayer.Visible) and waited < 15 do
		waited += task.wait(0.5) -- espera o cartão do bichinho sumir
	end
	if firstMin.FavDone or player:GetAttribute("FavAsked") ~= false or os.clock() - firstMin.JoinClock < 480 or player:GetAttribute("Carrying")
		or os.clock() - firstMin.ShareAt < 30 then -- (v67: acabou de abrir o convite: não empilha outro pedido)
		return
	end
	firstMin.FavDone = true
	net:FireServer("FavAsked")
	pcall(function()
		game:GetService("AvatarEditorService"):PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
end

net.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Toast" then
		showToast(a, b)
		if b == "error" then
			sfx("Error")
		end
	elseif kind == "Banner" then
		showBanner(a, b)
	elseif kind == "Step" then
		floatText("+" .. Format.Short(a), PINK_TEXT)
		sfx("Step", 0.9 + math.random() * 0.3)
	elseif kind == "Grabbed" then
		showBanner("RUN!!", Color3.fromRGB(255, 70, 70))
		sfx("Grab")
		sfx("Alarm")
	elseif kind == "Caught" then
		showBanner("CAUGHT!", Color3.fromRGB(255, 70, 70))
		sfx("Caught")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and typeof(b) == "Vector3" then
			root.AssemblyLinearVelocity = b -- o personagem é do jogador: o empurrão tem que ser aplicado aqui
		end
	elseif kind == "Stole" then
		sfx("Delivered")
		sfx("Coin")
		coinBurst(14, Color3.fromRGB(255, 220, 80))
		juice.Stamp() -- (v67) carimbo SALVO!
	elseif kind == "CloseCall" and type(a) == "number" then
		-- v67: o guardião quase pegou e você cruzou a SAFE = prêmio extra (o servidor calcula)
		showBanner(L("CloseCall"):format(Format.Money(a)), Color3.fromRGB(255, 150, 70))
		for k = 0, 2 do
			task.delay(0.2 + k * 0.12, function()
				sfx("Coin", 1.1 + k * 0.15)
			end)
		end
	elseif kind == "Sold" and type(a) == "number" then
		floatText("+" .. Format.Money(a), GREEN_TEXT)
		coinBurst(math.clamp(math.floor(math.log10(math.max(a, 10)) * 5), 8, 30))
		for k = 0, 2 do
			task.delay(k * 0.12, function()
				sfx("Coin", 1 + k * 0.15)
			end)
		end
	elseif kind == "Epic" and type(a) == "string" then
		showEpic(a, b)
	elseif kind == "Offer" and type(a) == "string" then
		showOffer(a, b)
	elseif kind == "Purchased" then
		sfx("Coin")
	elseif kind == "Hatched" and type(a) == "table" then
		windows.Eggs.Visible = false
		-- espera o ovo rachar e explodir na base antes de mostrar o card do bichinho
		task.delay(Config.HatchTime + 0.05, function()
			queueHatch(a)
		end)
		-- v67: o Diário abre sozinho 4 s depois do 1º ovo chocado da sessão (novato: nada abre antes disso),
		-- só sem janela aberta e sem ovo nas mãos; senão tenta de novo no próximo ovo
		if not firstMin.DailyShown and player:GetAttribute("DailyReady") == true and (player:GetAttribute("Stolen") or 0) >= 1 then
			task.delay(4, function()
				local waited = 0
				while (hatchBusy or hatchLayer.Visible) and waited < 15 do
					waited += task.wait(0.5)
				end
				if not firstMin.DailyShown and player:GetAttribute("DailyReady") == true and not anyWindowOpen() and not player:GetAttribute("Carrying") then
					firstMin.DailyShown = true
					open("Daily")
				end
			end)
		end
		-- v67: chocou Lendário ou melhor = momento feliz para pedir o favorito (1 vez por conta)
		for _, entry in a do
			local def = type(entry) == "table" and Critters.ById[entry[1]]
			if def and (Config.RarityIndex[def.Rarity] or 1) >= Config.RarityIndex.Legendary then
				task.delay(4, firstMin.TryFavorite)
				break
			end
		end
	elseif kind == "Sfx" then
		sfx(a)
	elseif kind == "SfxAt" and typeof(b) == "Vector3" then
		sfxAt(a, b)
	elseif kind == "Swing" and typeof(a) == "Instance" and a:IsA("Player") and a.Character then
		swinging[a.Character] = os.clock()
	elseif kind == "Pushed" and typeof(a) == "Vector3" then
		-- v65: empurrãozinho do taco (quem não carrega ovo não fica atordoado)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = a
		end
	elseif kind == "Stunned" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and typeof(b) == "Vector3" then
			root.AssemblyLinearVelocity = b
		end
		stunText.Visible = true
		Theme.popIn(stunText)
		task.delay(a or 1, function()
			stunText.Visible = false
		end)
		-- v67: a dica do taco virou aviso de 1 vez (na 1ª vez que a criança leva um taco)
		if not firstMin.HitTold and (player:GetAttribute("Stolen") or 0) < 10 then
			firstMin.HitTold = true
			task.delay(1.5, function()
				showToast(L("FirstHit"), "info")
			end)
		end
	elseif kind == "GuardianAwake" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if typeof(b) == "Vector3" then
			-- onda de choque vermelha saindo do chefão
			local wave = Instance.new("Part")
			wave.Anchored = true
			wave.CanCollide = false
			wave.CanQuery = false
			wave.CanTouch = false
			wave.Shape = Enum.PartType.Cylinder
			wave.Material = Enum.Material.Neon
			wave.Color = Color3.fromRGB(255, 60, 60)
			wave.Transparency = 0.2
			wave.Size = Vector3.new(0.4, 4, 4)
			wave.CFrame = CFrame.new(b.X, 0.3, b.Z) * CFrame.Angles(0, 0, math.rad(90))
			wave.Parent = workspace
			TweenService:Create(wave, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = Vector3.new(0.4, 90, 90), Transparency = 1 }):Play()
			task.delay(1, function()
				wave:Destroy()
			end)
		end
		if root and a and root.Position.Z > 0 and math.floor(root.Position.Z / Config.Map.LaneLength) + 1 == a then
			sfx("Alarm", 0.8)
			sfx("Night", 0.6)
			-- tremida na câmera
			task.spawn(function()
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					return
				end
				for k = 1, 12 do
					humanoid.CameraOffset = Vector3.new(math.random(-10, 10) / 25, math.random(-10, 10) / 25, 0) * (1 - k / 12)
					task.wait(0.03)
				end
				humanoid.CameraOffset = Vector3.zero
			end)
		end
	elseif kind == "Open" then
		open(a)
		sfx("Pop")
	elseif kind == "JoinCommunity" and type(a) == "number" and a > 0 then
		-- abre o convite oficial da Roblox para entrar na comunidade; entrou = abre o baú na hora
		task.spawn(function()
			local ok, status = pcall(function()
				return game:GetService("GroupService"):PromptJoinAsync(a)
			end)
			if ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember) then
				task.wait(0.5)
				net:FireServer("Chest")
			end
		end)
	elseif kind == "ChestOpened" then
		-- pedir o like só depois de ganhar algo (não dá prêmio pelo like: a Roblox não deixa)
		task.delay(2.5, function()
			showToast("\u{1F44D} Enjoying the game? Leave a LIKE - it helps a lot!", "info")
		end)
	elseif kind == "ZoneUnlocked" and type(a) == "number" then
		-- v66: a velocidade passou do portão de uma zona nova pela 1ª vez = festa grande
		local zone = Config.Zones[a]
		if zone then
			local color = Color3.fromRGB(120, 255, 160)
			showEpic(L("ZoneUnlocked"):format(string.upper(zone.Name)) .. " " .. (zone.Emoji or ""), color)
			confetti(color, fxLayer)
			task.delay(0.6, function()
				confetti(Theme.Gold, fxLayer)
				sfx("Pop")
			end)
			for k = 0, 3 do
				task.delay(0.15 * k, function()
					sfx("Coin", 1 + k * 0.12)
				end)
			end
			task.delay(4, firstMin.TryFavorite) -- (v67: momento feliz para pedir o favorito)
		end
	elseif kind == "DailyClaimed" and type(a) == "number" then
		-- v67: depois da faixa do prêmio de hoje, o gancho para voltar: "Amanhã: DIA 3 -> $12K + 800 👟"
		local nextDay = math.floor(a) % #Config.Daily + 1
		local reward = Config.Daily[nextDay]
		if reward then
			local income = player:GetAttribute("BaseIncome") or 0
			local vip = table.find(string.split(player:GetAttribute("Passes") or "", ","), "VIP") ~= nil
			local cash = math.max(reward.MinCash, math.floor(income * 60 * reward.Minutes)) * (if vip then 2 else 1)
			local prize = ("%s + %s \u{1F45F}%s"):format(Format.Money(cash), Format.Short(reward.Speed), if reward.Egg then " + \u{1F95A}" else "")
			task.delay(3.4, function()
				showBanner(L("DailyTomorrow"):format(nextDay, prize), Color3.fromRGB(200, 175, 255))
			end)
		end
	elseif kind == "Say" and type(a) == "string" then
		-- v67: aviso do servidor com o texto da TELA (PT/EN pelo L()): "banner" = faixa grande, senão aviso
		if b == "banner" then
			showBanner(L(a), Color3.fromRGB(255, 220, 90))
			sfx("Pop")
		else
			showToast(L(a), if type(b) == "string" then b else "info")
		end
	elseif kind == "NightTeleport" then
		task.delay(0.1, faceCameraForward)
		nightShade.BackgroundTransparency = 0
		TweenService:Create(nightShade, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
	end
	-- qualquer mudança: atualiza a janela aberta (v66: pelo NOME com que ela foi aberta, guardado no open();
	-- antes o laço parava na 1ª janela visível e os apelidos Trails/Boosts/Sell faziam pular a atualização)
	if kind == "Purchased" or kind == "Stole" or kind == "Hatched" or kind == "Sold" or kind == "Refresh" then
		task.delay(0.2, function()
			local name = currentWindow
			local window = name and windows[name]
			local refresh = name and refreshers[name]
			if window and window.Visible and refresh then
				refresh()
			end
		end)
	end
end)


---------------------------------------------------------------------
-- Ferramentas (taco e armadilha) e tutorial
---------------------------------------------------------------------
local hookedTools: { [Tool]: boolean } = {}
local function hookTool(item: Instance)
	if not item:IsA("Tool") or hookedTools[item] then
		return
	end
	local kind = item:GetAttribute("GameTool")
	if not kind then
		return
	end
	hookedTools[item] = true
	item.Activated:Connect(function()
		if kind == "Bat" then
			net:FireServer("Swing")
		elseif kind == "Trap" then
			net:FireServer("PlaceTrap")
		end
	end)
	item.Destroying:Connect(function()
		hookedTools[item] = nil
	end)
end
local function watchHolder(holder: Instance)
	for _, item in holder:GetChildren() do
		hookTool(item)
	end
	holder.ChildAdded:Connect(function(item)
		task.wait()
		hookTool(item)
	end)
end
task.spawn(function()
	watchHolder(player:WaitForChild("Backpack"))
end)
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watchHolder(child)
	end
end)
player.CharacterAdded:Connect(watchHolder)
if player.Character then
	watchHolder(player.Character)
end

workspace:GetAttributeChangedSignal("Night"):Connect(function()
	if workspace:GetAttribute("Night") then
		sfx("Night")
	end
end)

local tutorialText = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if TOUCH then -160 else -96), Size = UDim2.fromOffset(if TOUCH then 820 else 700, 46), Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), Stroke = 4, Visible = false, Parent = gui })
local tutorialStep = ""

-- devolve (alvo da seta, texto, botão para balançar) conforme o progresso do jogador.
-- v67: PRÓXIMA META: depois dos passos do tutorial a linha NUNCA acaba. Ordem: carregando > tutorial > noite
-- > cercado cheio > prêmios do Índice > ovo dourado (20 s) > zona nova sem roubo > treinar até a próxima zona
-- > rebirth. A dica do taco saiu daqui (virou aviso na 1ª vez que a criança leva taco).
local function tutorial(root: BasePart): (Vector3?, string?, string?)
	local slots = decode("Slots", {})
	local eggs, ready, pets = 0, 0, 0
	for _, slot in slots do
		if slot.k == "Egg" then
			eggs += 1
			if (slot.l or 0) <= 0 then
				ready += 1
			end
		else
			pets += 1
		end
	end
	local x, front = player:GetAttribute("PlotX"), player:GetAttribute("PlotFront")
	local stolen = player:GetAttribute("Stolen") or 0
	local pen = player:GetAttribute("PenLevel") or 0
	local money = player:GetAttribute("Money") or 0
	local speed = player:GetAttribute("Speed") or 0
	-- ovo mais perto numa zona (golden = só ovo dourado que dá para alcançar)
	local function nearestEgg(zoneIndex: number?, golden: boolean?): (Vector3?, number?)
		local best, target, where = math.huge, nil, nil
		for egg in nestEggSet do
			local z = egg:GetAttribute("Zone")
			local okEgg = if golden then egg:GetAttribute("Golden") == true and not egg:GetAttribute("Pumpkin") and typeof(z) == "number"
				and Config.Zones[z] ~= nil and speed >= Config.Zones[z].Speed else z == zoneIndex
			if okEgg and egg.PrimaryPart then
				local d = (egg.PrimaryPart.Position - root.Position).Magnitude
				if d < best then
					best, where = d, z
					target = egg.PrimaryPart.Position + Vector3.new(0, 3, 0)
				end
			end
		end
		return target, where
	end
	if player:GetAttribute("Carrying") then
		return Vector3.new(root.Position.X, 2, -8), L("HintCarry"), nil
	end
	-- v67: entrou pelo "Mostrar pros amigos": a seta mostra o cercado do amigo por uns 30 s (todos os cercados
	-- têm a mesma frente, então serve a sua PlotFront)
	local visitUntil, visitX = player:GetAttribute("VisitUntil"), player:GetAttribute("VisitPen")
	if typeof(visitUntil) == "number" and typeof(visitX) == "number" and typeof(front) == "number" and workspace:GetServerTimeNow() < visitUntil then
		return Vector3.new(visitX, 3, front - 12), L("HintVisit"):format(tostring(player:GetAttribute("VisitName") or "")), nil
	end
	-- NOITE: os ninhos ficam vazios, então "vá roubar" vira "os ovos voltam em 0:08"
	local nightHint: string? = nil
	if workspace:GetAttribute("Night") == true then
		local cycleEnd = workspace:GetAttribute("CycleEnd")
		local left = if typeof(cycleEnd) == "number" then math.max(0, math.floor(cycleEnd - workspace:GetServerTimeNow())) else 0
		nightHint = L("HintNight"):format(("%d:%02d"):format(left // 60, left % 60))
	end
	if stolen == 0 then
		if nightHint then
			return nil, nightHint, nil
		end
		return nearestEgg(1), L("HintSteal"):format(string.upper(Config.Zones[1].Name), if TOUCH then L("HoldButton") else L("HoldE")), nil
	end
	if typeof(x) ~= "number" or typeof(front) ~= "number" then
		return nil, nightHint, nil
	end
	if ready > 0 then
		return Vector3.new(x, 3, front - 12), L("HintHatch"), nil
	end
	if pets == 0 and eggs > 0 then
		if nightHint then
			return nil, nightHint, nil
		end
		return nearestEgg(1), L("HintGrowing"), nil
	end
	local unclaimedIndex = 0
	for _, value in decode("Index", {}) do
		if value == 1 then
			unclaimedIndex += 1
		end
	end
	if pen == 0 and unclaimedIndex > 0 then
		return nil, L("HintIndex"), "Index"
	end
	if pen == 0 and pets > 0 then
		if money >= (Config.PenLevels[1] and Config.PenLevels[1].Cost or 1000) then
			return Vector3.new(x - 12, 4, front + 6), L("HintBuyPen"), nil
		end
		return nil, L("HintSavePen"):format(Format.Money(Config.PenLevels[1] and Config.PenLevels[1].Cost or 1000)), nil
	end
	local treadSpot = Vector3.new(x + 13, 3, front + 22)
	if pen >= 1 and speed < 300 then
		return treadSpot, L("HintTread"), nil
	end
	-- ===== PRÓXIMA META =====
	if nightHint then
		return nil, nightHint, nil
	end
	-- cercado cheio: melhorar (seta na placa amarela) ou vender
	if #slots >= Config.SlotCount(pen) then
		local nextPen = Config.PenLevels[pen + 1]
		if nextPen then
			return Vector3.new(x - 12, 4, front + 6), L("HintPenFull"):format(Format.Money(nextPen.Cost)), nil
		end
		return nil, L("HintPenFullMax"), nil
	end
	if unclaimedIndex > 0 then
		return nil, L("HintClaimIndex"):format(unclaimedIndex), "Index"
	end
	-- ovo dourado nos primeiros 20 s, numa zona que você alcança (só depois do 3º ovo: antes atrapalha)
	if stolen >= 3 then
		local goldenUntil = workspace:GetAttribute("GoldenUntil")
		if typeof(goldenUntil) == "number" and workspace:GetServerTimeNow() < goldenUntil - 160 then
			local target, where = nearestEgg(nil, true)
			if target and where then
				return target, L("HintGolden"):format(string.upper(Config.Zones[where].Name)), nil
			end
		end
	end
	-- zona mais funda que a velocidade alcança e a próxima zona
	local reached, nextIndex = 1, nil
	for index, zone in Config.Zones do
		if speed >= zone.Speed then
			reached = index
		elseif not nextIndex then
			nextIndex = index
		end
	end
	-- chegou numa zona nova e ainda não roubou de lá: seta na entrada (ou no ovo mais perto, se já está dentro)
	if reached >= 2 and reached > (player:GetAttribute("BestStolenZone") or 0) then
		local zone = Config.Zones[reached]
		local startZ = Config.Map.LaneLength * (reached - 1)
		local target = if root.Position.Z >= startZ then nearestEgg(reached) else nil
		return target or Vector3.new(0, 3, startZ + 20),
			L("HintGoZone"):format(string.upper(zone.Name), math.floor(zone.Mult / math.max(Config.Zones[reached - 1].Mult, 1))), nil
	end
	if nextIndex then
		if pen < 1 then
			-- (sem esteira ainda: roube mais ovos para juntar dinheiro)
			return nearestEgg(1), L("HintGrowing"), nil
		end
		local gate = Config.Zones[nextIndex].Speed
		local pct = math.clamp(math.floor(speed / math.max(gate, 1) * 100), 0, 99)
		-- seta para a esteira só quando está longe dela (perto, o painel da esteira já explica)
		return if (root.Position - treadSpot).Magnitude > 40 then treadSpot else nil,
			L("HintGoalSpeed"):format(Format.Short(gate), string.upper(Config.Zones[nextIndex].Name), pct), nil
	end
	-- última zona: rebirth
	local cost = Config.RebirthCost(player:GetAttribute("Rebirths") or 0)
	return nil, L("HintRebirth"):format(math.clamp(math.floor(money / math.max(cost, 1) * 100), 0, 100)), nil
end

---------------------------------------------------------------------
-- Seta guia (primeiro ovo; carregando = volta para a SAFE ZONE)
---------------------------------------------------------------------
local arrow0 = Instance.new("Attachment")
local targetPart = create("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, Parent = workspace })
local arrow1 = create("Attachment", { Parent = targetPart })
local beam = create("Beam", {
	Attachment0 = arrow0, Attachment1 = arrow1, Color = ColorSequence.new(Color3.fromRGB(255, 230, 80)), Width0 = 1.4, Width1 = 1.4, FaceCamera = true, LightEmission = 0.7,
	Texture = "rbxasset://textures/particles/sparkles_main.dds", TextureMode = Enum.TextureMode.Wrap, TextureSpeed = 2, Enabled = false, Parent = targetPart,
})

---------------------------------------------------------------------
-- Bichinhos passeando no cercado (só na tela)
---------------------------------------------------------------------
local wanderers: { [Model]: any } = {}
local function track(model: Instance)
	if model:IsA("Model") and model:GetAttribute("Wander") and not wanderers[model] then
		local base = model:GetAttribute("Base")
		if typeof(base) == "Vector3" then
			wanderers[model] = { Base = base, Height = model:GetAttribute("Height") or 2, Next = os.clock() + math.random() * 3, Busy = false, Popup = os.clock() + math.random() * 3 }
		end
	end
end
task.spawn(function()
	local live = workspace:WaitForChild("Live", 60)
	if not live then
		return
	end
	for _, model in live:GetChildren() do
		track(model)
	end
	live.ChildAdded:Connect(function(model)
		task.wait()
		track(model)
	end)
	live.ChildRemoved:Connect(function(model)
		local info = wanderers[model]
		if info and info.Pop then
			info.Pop.Board:Destroy()
		end
		wanderers[model] = nil
	end)
end)

-- "+$" saindo dos bichinhos do SEU cercado.
-- (v66 perf) UMA placa por bichinho, criada na 1ª vez e reaproveitada (antes: BillboardGui + texto + 2 tweens
-- novos para CADA pet a cada 3 s, mesmo com você do outro lado do mapa). Quem chama só pede perto de você.
local POP_TIME = TweenInfo.new(1.4)
local POP_START = Vector3.new(0, 3, 0)
local function moneyPop(model: Model, info)
	local root = model.PrimaryPart
	local income = model:GetAttribute("Income")
	if not root or type(income) ~= "number" then
		return
	end
	local pop = info.Pop
	if not pop or pop.Root ~= root or not pop.Board.Parent then
		if pop then
			pop.Board:Destroy()
		end
		local board = create("BillboardGui", { Size = UDim2.fromScale(5, 1.6), StudsOffsetWorldSpace = POP_START, Adornee = root, MaxDistance = 70, Enabled = false, Parent = gui })
		local label = text({ Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = GREEN_TEXT, Parent = board })
		local labelStroke = label:FindFirstChildOfClass("UIStroke")
		local tweens = { TweenService:Create(board, POP_TIME, { StudsOffsetWorldSpace = Vector3.new(0, 7, 0) }), TweenService:Create(label, POP_TIME, { TextTransparency = 1 }) }
		if labelStroke then
			table.insert(tweens, TweenService:Create(labelStroke, POP_TIME, { Transparency = 1 }))
		end
		pop = { Root = root, Board = board, Label = label, Stroke = labelStroke, Tweens = tweens, Serial = 0 }
		info.Pop = pop
	end
	-- volta para o começo e toca de novo as mesmas animações
	pop.Label.Text = "+" .. Format.Money(income * 3)
	pop.Label.TextTransparency = 0
	if pop.Stroke then
		pop.Stroke.Transparency = 0
	end
	pop.Board.StudsOffsetWorldSpace = POP_START
	pop.Board.Enabled = true
	for _, tween in pop.Tweens do
		tween:Play()
	end
	pop.Serial += 1
	local serial = pop.Serial
	task.delay(1.5, function()
		if pop.Serial == serial then
			pop.Board.Enabled = false
		end
	end)
end

---------------------------------------------------------------------
-- ANIMAÇÃO DOS BICHOS (só na tela, 60 fps): corpo inteiro amassa/estica, pula, balança e inclina.
-- Serve para os guardiões (seguem o "Goal" que o servidor manda) e para os pets do cercado.
---------------------------------------------------------------------
local Rig = {}
Rig.__index = Rig

-- guarda a posição de cada peça em relação ao "chão" do modelo (e, das que têm SpecialMesh, como esticar)
local function absVector(v: Vector3): Vector3
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end
function Rig.new(model: Model)
	local pivot = model:GetPivot()
	local box, size = model:GetBoundingBox()
	local bottomY = box.Position.Y - size.Y / 2
	local base = CFrame.new(pivot.Position.X, bottomY, pivot.Position.Z) * (pivot - pivot.Position)
	local parts = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local offset = base:ToObjectSpace(item.CFrame)
			local rot = offset - offset.Position
			local entry: any = { Part = item, Offset = offset, Pos = offset.Position, Rot = rot }
			-- (MeshPart nunca muda de tamanho: o squash dela é só pela posição das peças)
			local mesh = item:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				entry.Mesh = mesh
				entry.MeshScale = mesh.Scale
			elseif item.ClassName == "Part" then
				entry.Size = item.Size -- peça simples: só muda de tamanho no "nascer" do pet (resize)
			end
			if mesh or entry.Size then
				entry.AX = absVector(rot.RightVector)
				entry.AY = absVector(rot.UpVector)
				entry.AZ = absVector(rot.LookVector)
			end
			table.insert(parts, entry)
		end
	end
	return setmetatable({
		Model = model,
		Parts = parts,
		Lift = pivot.Position.Y - bottomY,
		Height = size.Y,
		Live = {}, -- peças válidas (conferidas 2x por segundo)
		List = {}, -- as mesmas peças, para o BulkMoveTo
		Frames = {}, -- CFrames deste frame (tabela reaproveitada: não cria lixo)
		CheckAt = 0,
		Squashed = false,
		Resized = false,
	}, Rig)
end

-- ground = CFrame no chão (posição + direção); sx/sy/sz = amassar/esticar.
-- squash = também estica as peças com SpecialMesh (só de perto).
-- resize = também muda o Size das peças simples (Part); só nos 0.7 s do pet "nascendo" do ovo.
-- (v66 perf) MeshPart NUNCA muda de Size (redimensionada 60x/s trava o celular) e Part só no nascer: o
-- "amassar" vem da posição das peças + SpecialMesh.Scale. Todas as peças andam num único workspace:BulkMoveTo.
function Rig:Pose(ground: CFrame, sx: number, sy: number, sz: number, squash: boolean?, resize: boolean?)
	local clock = os.clock()
	local live, list, frames = self.Live, self.List, self.Frames
	if clock >= self.CheckAt then
		self.CheckAt = clock + 0.5
		table.clear(live)
		table.clear(list)
		table.clear(frames)
		for _, info in self.Parts do
			local part = info.Part
			if part.Parent and part.Anchored then
				table.insert(live, info)
				table.insert(list, part)
			end
		end
	end
	local n = #live
	if n == 0 then
		return
	end
	local scaled = sx ~= 1 or sy ~= 1 or sz ~= 1
	local scale = Vector3.new(sx, sy, sz)
	for k = 1, n do
		local info = live[k]
		frames[k] = if scaled then ground * (CFrame.new(info.Pos * scale) * info.Rot) else ground * info.Offset
	end
	local ok = pcall(workspace.BulkMoveTo, workspace, list, frames, Enum.BulkMoveMode.FireCFrameChanged)
	if not ok then
		-- (alguma peça sumiu no meio do caminho: move uma a uma e reconfere a lista no próximo frame)
		self.CheckAt = 0
		for k = 1, n do
			local part = list[k]
			if part.Parent then
				part.CFrame = frames[k]
			end
		end
	end
	local resizing = resize == true and squash == true and scaled
	if squash and scaled then
		-- aproxima: escala no eixo do próprio pedaço
		self.Squashed = true
		for k = 1, n do
			local info = live[k]
			local mesh = info.Mesh
			if mesh then
				mesh.Scale = info.MeshScale * Vector3.new(info.AX:Dot(scale), info.AY:Dot(scale), info.AZ:Dot(scale))
			elseif resizing and info.Size then
				info.Part.Size = info.Size * Vector3.new(info.AX:Dot(scale), info.AY:Dot(scale), info.AZ:Dot(scale))
			end
		end
	elseif self.Squashed then
		-- parou de esticar (ou ficou longe): devolve o tamanho normal 1 vez
		self.Squashed = false
		for _, info in self.Parts do
			if info.Mesh then
				info.Mesh.Scale = info.MeshScale
			end
		end
	end
	if resizing then
		self.Resized = true
	elseif self.Resized then
		self.Resized = false
		for _, info in self.Parts do
			if info.Size and info.Part.Parent then
				info.Part.Size = info.Size
			end
		end
	end
end

local function damp(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

-- GUARDIÕES ----------------------------------------------------------
local guardianState: { [Model]: any } = {}
local function guardianInfo(model: Model)
	local info = guardianState[model]
	if not info then
		local ok, rig = pcall(Rig.new, model)
		if not ok then
			return nil
		end
		local goal = model:GetAttribute("Goal")
		local start = if typeof(goal) == "CFrame" then goal else model:GetPivot()
		info = { Rig = rig, Pos = start.Position - Vector3.new(0, rig.Lift, 0), Look = start.LookVector, Phase = 0, Lean = 0, Sleeping = model:GetAttribute("Sleeping"), Jump = 0, Speed = 0 }
		guardianState[model] = info
	end
	return info
end

-- near = perto da câmera (< ANIM_NEAR): animação completa. Longe: segue o caminho sem amassar.
local function animateGuardian(model: Model, info, dt: number, t: number, near: boolean)
	local rig = info.Rig
	local goal = model:GetAttribute("Goal")
	if typeof(goal) ~= "CFrame" then
		return
	end
	local target = goal.Position - Vector3.new(0, rig.Lift, 0)
	local before = info.Pos
	info.Pos = info.Pos:Lerp(target, damp(10, dt))
	local moved = (info.Pos - before) * Vector3.new(1, 0, 1)
	local speed = moved.Magnitude / math.max(dt, 1e-3)
	info.Speed += (speed - info.Speed) * damp(8, dt)
	local look = goal.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.01 then
		local newLook = info.Look:Lerp(look.Unit, damp(8, dt))
		info.Look = if newLook.Magnitude > 0.01 then newLook.Unit else info.Look
	end
	local sleeping = model:GetAttribute("Sleeping")
	if sleeping ~= info.Sleeping then
		info.Sleeping = sleeping
		if not sleeping then
			info.Jump = 1 -- pulo de susto ao acordar
		end
	end
	local h = rig.Height
	local y, sx, sy, roll, pitch, yawWiggle = 0, 1, 1, 0, 0, 0
	local running = info.Speed > 2
	if running then
		-- corrida: passos pesados (pula e amassa ao tocar o chão), balança de um lado pro outro, inclina pra frente
		info.Phase += dt * (5 + math.min(info.Speed, 120) * 0.09)
		local s = math.sin(info.Phase)
		local bounce = math.abs(s)
		y = bounce * math.clamp(h * 0.09, 0.4, 3)
		local squash = 1 - bounce
		sy = 1 - squash * 0.14 + bounce * 0.05
		sx = 1 + squash * 0.09
		roll = math.sin(info.Phase) * 7
		pitch = -math.min(info.Speed, 60) * 0.18
	elseif sleeping then
		-- dormindo: respira devagar e balança a cabeça
		local breath = math.sin(t * 1.7 + model:GetAttribute("Zone") or 0)
		sy = 1 + breath * 0.035
		sx = 1 - breath * 0.018
		roll = math.sin(t * 0.8) * 2.5
		pitch = 4
	else
		-- acordado parado: procura o ladrão (vira pros lados) e fica "pronto"
		local breath = math.sin(t * 5)
		sy = 1 + breath * 0.025
		sx = 1 - breath * 0.012
		yawWiggle = math.sin(t * 2.2) * 18
	end
	if info.Jump > 0 then
		info.Jump = math.max(0, info.Jump - dt * 1.8)
		local p = 1 - info.Jump
		y += math.sin(math.clamp(p, 0, 1) * math.pi) * h * 0.35
		sy *= 1 + math.sin(p * math.pi) * 0.12
	end
	info.Lean += (pitch - info.Lean) * damp(6, dt)
	if near then
		info.RestPosed = false
	else
		-- longe: dormindo e parado a pose quase não muda: posa 1 vez e não mexe mais nas peças
		local resting = sleeping and info.Jump <= 0 and info.Speed < 0.3 and (target - info.Pos).Magnitude < 0.05
		if resting and info.RestPosed then
			return
		end
		info.RestPosed = resting
		sx, sy = 1, 1
	end
	local ground = CFrame.lookAt(info.Pos, info.Pos + info.Look)
		* CFrame.Angles(0, math.rad(yawWiggle), 0)
		* CFrame.new(0, y, 0)
		* CFrame.Angles(math.rad(info.Lean), 0, math.rad(roll))
	rig:Pose(ground, sx, sy, sx, near)
end

-- PETS DO CERCADO ----------------------------------------------------
local petState: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any -- (v65: chave fraca: não vaza memória)
local function petInfo(model: Model)
	local info = petState[model]
	if not info then
		local base = model:GetAttribute("Base")
		if typeof(base) ~= "Vector3" then
			return nil
		end
		local ok, rig = pcall(Rig.new, model)
		if not ok then
			return nil
		end
		local pivot = model:GetPivot()
		info = { Rig = rig, Base = base, Pos = Vector3.new(pivot.Position.X, base.Y, pivot.Position.Z), Look = pivot.LookVector * Vector3.new(1, 0, 1), Target = nil, Phase = math.random() * 6, Next = os.clock() + math.random() * 2, Jump = 0, Spin = 0, Seed = math.random() * 10 }
		if info.Look.Magnitude < 0.01 then
			info.Look = Vector3.new(0, 0, 1)
		end
		info.Look = info.Look.Unit
		petState[model] = info
	end
	return info
end

-- full = perto (estica o SpecialMesh); mais longe só a posição das peças
local function animatePet(model: Model, info, dt: number, t: number, root: BasePart?, full: boolean)
	local rig = info.Rig
	local clock = os.clock()
	if not info.Target and clock >= info.Next then
		local roll = math.random()
		if roll < 0.18 then
			info.Jump = 1 -- pulinho de alegria
			info.Spin = if math.random() < 0.5 then 1 else 0
			info.Next = clock + 1.5 + math.random() * 2
		else
			local range = model:GetAttribute("WanderRange") or 4.5
			info.Target = info.Base + Vector3.new((math.random() * 2 - 1) * range, 0, (math.random() * 2 - 1) * range)
		end
	end
	local y, sx, sy, roll, pitch = 0, 1, 1, 0, 0
	if info.Target then
		local delta = (info.Target - info.Pos) * Vector3.new(1, 0, 1)
		if delta.Magnitude < 0.15 then
			info.Target = nil
			info.Next = clock + 1.5 + math.random() * 3.5
		else
			local step = math.min(delta.Magnitude, dt * (3.5 + rig.Height * 0.3))
			info.Pos += delta.Unit * step
			info.Look = info.Look:Lerp(delta.Unit, damp(10, dt)).Unit
			-- anda pulando (hop hop) com amassadinha
			info.Phase += dt * 11
			local bounce = math.abs(math.sin(info.Phase))
			y = bounce * math.clamp(rig.Height * 0.18, 0.25, 1.2)
			local squash = 1 - bounce
			sy = 1 - squash * 0.16 + bounce * 0.06
			sx = 1 + squash * 0.1
			roll = math.sin(info.Phase) * 8
			pitch = -6
		end
	else
		-- parado: respira, olha para você se estiver perto
		local breath = math.sin(t * 2.4 + info.Seed)
		sy = 1 + breath * 0.04
		sx = 1 - breath * 0.02
		if root then
			local toPlayer = (root.Position - info.Pos) * Vector3.new(1, 0, 1)
			if toPlayer.Magnitude < 22 and toPlayer.Magnitude > 0.1 then
				info.Look = info.Look:Lerp(toPlayer.Unit, damp(4, dt)).Unit
			end
		end
	end
	local spin = 0
	if info.Jump > 0 then
		info.Jump = math.max(0, info.Jump - dt * 1.6)
		local p = 1 - info.Jump
		y += math.sin(p * math.pi) * math.clamp(rig.Height * 0.6, 1, 3.5)
		sy *= 1 + math.sin(p * math.pi) * 0.15
		if info.Spin > 0 then
			spin = p * 360
		end
		if p < 0.12 then
			sy *= 0.85 -- agacha antes de pular
			sx *= 1.08
		end
	end
	-- acabou de chocar: o bichinho "pula" para fora do ovo (cresce com elástico + gira)
	local popAt = model:GetAttribute("PopIn")
	local popping = false
	if typeof(popAt) == "number" then
		local p = (workspace:GetServerTimeNow() - popAt) / 0.7
		if p >= 0 and p < 1 then
			popping = true
			local k = 1 - math.exp(-6 * p) * math.cos(p * 14) -- elástico: 0 -> passa de 1 -> volta para 1
			k = math.max(k, 0.05)
			sx *= k
			sy *= k
			y += math.sin(p * math.pi) * math.clamp(rig.Height * 0.8, 1.5, 5)
			spin += (1 - p) * 360
		end
	end
	local ground = CFrame.lookAt(info.Pos, info.Pos + info.Look)
		* CFrame.Angles(0, math.rad(spin), 0)
		* CFrame.new(0, y, 0)
		* CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
	rig:Pose(ground, sx, sy, sx, full, full and popping)
end

-- OVOS NOS NINHOS: balançam de vez em quando (os prontos no cercado balançam mais)
local eggWobble: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any
local function animateEgg(model: Model, dt: number, t: number)
	local root = model.PrimaryPart
	if not root or not root.Anchored then
		eggWobble[model] = nil
		return
	end
	local info = eggWobble[model]
	if not info then
		info = { Next = os.clock() + math.random() * 4, Until = 0, Base = nil }
		eggWobble[model] = info
	end
	local clock = os.clock()
	if clock >= info.Next and clock > info.Until then
		info.Base = model:GetPivot()
		info.Until = clock + 0.7
		info.Next = clock + 2.5 + math.random() * 4
	end
	if info.Base then
		if clock < info.Until then
			local p = 1 - (info.Until - clock) / 0.7
			local angle = math.sin(p * math.pi * 4) * (1 - p) * 14
			model:PivotTo(info.Base * CFrame.Angles(0, 0, math.rad(angle)))
		else
			model:PivotTo(info.Base)
			info.Base = nil
		end
	end
end

-- (v66 perf) distâncias da animação: perto = completa; guardião longe = segue o caminho a 15 fps sem amassar;
-- pet entre PET_SQUASH e ANIM_NEAR = 30 fps sem esticar o mesh; mais longe que ANIM_NEAR = parado.
local ANIM_NEAR = 120
local GUARDIAN_FAR = 450
local PET_SQUASH = 50
local nearEggs: { Model } = {}
local nearEggsAt = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for model in guardianSet do
		if model.Parent then
			local info = guardianInfo(model)
			if info then
				local distance = (info.Pos - camPos).Magnitude
				if distance < ANIM_NEAR then
					info.Acc = 0
					animateGuardian(model, info, dt, t, true)
				elseif distance < GUARDIAN_FAR then
					-- longe: continua andando (um chefão correndo atrás de alguém), mas 15x por segundo e sem amassar
					info.Acc = (info.Acc or 0) + dt
					if info.Acc >= 1 / 15 then
						animateGuardian(model, info, info.Acc, t, false)
						info.Acc = 0
					end
				else
					-- muito longe: só acompanha a posição (sem animação)
					local goal = model:GetAttribute("Goal")
					if typeof(goal) == "CFrame" then
						info.Pos = goal.Position - Vector3.new(0, info.Rig.Lift, 0)
					end
				end
			end
		end
	end
	for model in guardianState do
		if not model.Parent then
			guardianState[model] = nil
		end
	end
	for model in wanderers do
		if model.Parent then
			local info = petInfo(model)
			if info then
				local distance = (info.Pos - camPos).Magnitude
				if distance < PET_SQUASH then
					info.Acc = 0
					animatePet(model, info, dt, t, root, true)
				elseif distance < ANIM_NEAR then
					-- (começa num ponto aleatório para os pets não andarem todos no mesmo frame)
					info.Acc = (info.Acc or math.random() / 30) + dt
					if info.Acc >= 1 / 30 then
						animatePet(model, info, info.Acc, t, root, false)
						info.Acc = 0
					end
				end
			end
		else
			petState[model] = nil
		end
	end
	-- ovo carregado: balança no ritmo da corrida (pesado = balança mais devagar e mais forte)
	for _, other in Players:GetPlayers() do
		local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local weld = otherRoot and otherRoot:FindFirstChild("CarryWeld")
		local baseC0 = weld and weld:GetAttribute("BaseC0")
		if weld and typeof(baseC0) == "CFrame" then
			local heavy = math.clamp(weld:GetAttribute("Heavy") or 1, 0.6, 6)
			local moving = math.clamp((otherRoot.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude / 20, 0, 1)
			local speedT = t * (12 / math.sqrt(heavy))
			local bob = (math.abs(math.sin(speedT)) * 0.35 * moving) + math.sin(t * 2.5) * 0.08
			local tilt = math.sin(speedT) * 6 * moving + math.sin(t * 1.7) * 2
			local target = baseC0 * CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(-4 * moving), 0, math.rad(tilt))
			local from = weld:GetAttribute("From")
			local grabAt = weld:GetAttribute("GrabAt")
			local p = if typeof(grabAt) == "number" then (workspace:GetServerTimeNow() - grabAt) / 0.35 else 1
			if typeof(from) == "CFrame" and p < 1 then
				-- arco: o ovo sobe do ninho e cai nas mãos
				local e = 1 - (1 - math.clamp(p, 0, 1)) ^ 3
				local arc = math.sin(e * math.pi) * 2.5
				weld.C0 = from:Lerp(target, e) * CFrame.new(0, arc, 0)
			else
				weld.C0 = target
			end
		end
	end
	-- ovos dos ninhos: a lista dos que estão perto da câmera é refeita 3x por segundo
	-- (antes: GetTagged + GetPivot de TODOS os ovos do mapa a cada frame)
	if t >= nearEggsAt then
		nearEggsAt = t + 0.33
		table.clear(nearEggs)
		for model in nestEggSet do
			if model.Parent and (model:GetPivot().Position - camPos).Magnitude < 140 then
				table.insert(nearEggs, model)
			end
		end
	end
	for _, model in nearEggs do
		if nestEggSet[model] and model.Parent and not model:GetAttribute("Loose") then
			animateEgg(model, dt, t)
		end
	end
end)

---------------------------------------------------------------------
-- v67 BICHINHO PARCEIRO 🐾 (só na tela, enfeite: não muda nada no jogo). O servidor só diz QUAL é (atributo "Buddy" =
-- "id|mutação": o do 🐾 na janela Pets ou o de maior renda) e quando comemorar ("Cheer": entrega e Lendário+ chocado).
-- Cada tela monta e anima: segue o dono atrás e à direita, pula quando ele anda (igual aos pets do cercado), flutua se
-- o bicho flutua, comemora com pulo e giro e, longe demais (renasceu, teleporte da noite), pula direto para o dono.
-- Celular (Config.Buddy): o dos OUTROS só é montado até 150 studs da câmera e apagado depois de 200, com no máximo
-- 75 peças, e some no gráfico manual 1-3; animação completa até 60 studs, 15 fps depois; no máximo 1 montagem por frame.
---------------------------------------------------------------------
do
	local B = Config.Buddy
	local Builder = require(ReplicatedStorage.Shared:WaitForChild("CritterBuilder"))
	local folder = Instance.new("Folder")
	folder.Name = "Buddies"
	folder.Parent = workspace
	local buddies: { [Player]: any } = {}
	local shapes: { [string]: any } = {} -- por bichinho: modelo pronto, nº de peças e altura do que aparece (ou false)
	-- Busy = montando agora (o 1º modelo 3D pode esperar a pasta Models3D: não monta 2 ao mesmo tempo)
	local flags = { Low = false, Busy = false, Frame = 0, Tap = nil :: string?, TapAt = -1e9, FirstTold = false }
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true

	-- o raio do chão pula os personagens (e os parceiros): refeito quando alguém nasce ou sai
	local function refreshRay()
		local list: { Instance } = { folder }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(list, other.Character)
			end
		end
		rayParams.FilterDescendantsInstances = list
	end

	-- peças do modelo pronto, altura e largura do que aparece (sem a Root invisível e sem aura), medidas 1 vez por bichinho
	local function shapeOf(def)
		local shape = shapes[def.Id]
		if shape == nil then
			shape = false
			local ok, template = pcall(Theme.critterTemplate, def)
			if ok and template then
				local count, minY, maxY, wide = 0, math.huge, -math.huge, 0
				local pivot = template:GetPivot().Position
				for _, part in template:GetDescendants() do
					if part:IsA("BasePart") then
						count += 1
						if part ~= template.PrimaryPart and part.Transparency < 1 and part.Name ~= "Aura" then
							local cf, half = part.CFrame, part.Size / 2
							local ex = math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z
							local ey = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
							local ez = math.abs(cf.RightVector.Z) * half.X + math.abs(cf.UpVector.Z) * half.Y + math.abs(cf.LookVector.Z) * half.Z
							minY = math.min(minY, cf.Position.Y - ey)
							maxY = math.max(maxY, cf.Position.Y + ey)
							wide = math.max(wide, math.abs(cf.Position.X - pivot.X) + ex, math.abs(cf.Position.Z - pivot.Z) + ez)
						end
					end
				end
				if maxY > minY then
					shape = { Template = template, Parts = count, Bottom = minY - pivot.Y, Height = maxY - minY, Wide = wide, Float = template:GetAttribute("Float") == true }
				end
			end
			shapes[def.Id] = shape
		end
		return shape or nil
	end

	local function destroy(info)
		if info.Model then
			info.Model:Destroy()
		end
		info.Model, info.Rig, info.Built = nil, nil, nil
	end

	-- monta o parceiro (false = este não dá: não tenta de novo até trocar de parceiro)
	local function build(who: Player, info, root: BasePart): boolean
		local key = info.Key
		local id, mutation = Config.BuddyParse(key)
		local def = id and Critters.ById[id]
		local shape = def and shapeOf(def)
		if not def or not shape or (who ~= player and shape.Parts > B.MaxParts) then
			return false
		end
		local height = Config.BuddyHeight(def.Rarity)
		local scale = height / shape.Height
		local ok, model = pcall(function()
			local m = shape.Template:Clone()
			m:ScaleTo(m:GetScale() * scale)
			if mutation then
				Builder.ApplyMutation(m, mutation)
			end
			for _, item in m:GetDescendants() do
				if item:IsA("BasePart") then
					item.Anchored = true
					item.CanCollide = false
					item.CanQuery = false
					item.CanTouch = false
					item.CastShadow = false
				end
			end
			m.Name = "Buddy" .. who.UserId
			m:PivotTo(CFrame.new(root.Position))
			m.Parent = folder
			return m
		end)
		if not ok or not model then
			return false
		end
		local rigOk, rig = pcall(Rig.new, model)
		if not rigOk or not rig then
			model:Destroy()
			return false
		end
		info.Model, info.Rig, info.Built = model, rig, key
		info.Height = height
		info.Spread = math.max(height * 0.25, shape.Wide * scale - 1) -- (asa grande de dragão não bate no dono)
		info.Sink = shape.Bottom * scale + rig.Lift -- do fundo da caixa (com a Root) até o pé que aparece
		info.Float = shape.Float
		return true
	end

	local function animate(info, root: BasePart, character: Model, dt: number, t: number, serverNow: number, full: boolean)
		local h = info.Height
		-- ponto atrás e à direita do dono (só o giro dele, sem inclinar); bicho maior/mais largo fica mais longe
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = if look.Magnitude > 0.01 then look.Unit else info.Look
		local right = Vector3.new(-look.Z, 0, look.X)
		local goal = root.Position + right * (B.Side + info.Spread) - look * (B.Behind + info.Spread)
		-- chão embaixo do ponto (sem chão = altura dos pés do dono)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hip = (if humanoid and humanoid.HipHeight > 0 then humanoid.HipHeight else 2) + root.Size.Y / 2
		local hit = workspace:Raycast(Vector3.new(goal.X, root.Position.Y + 1, goal.Z), Vector3.new(0, -(hip + 14), 0), rayParams)
		local groundY = if hit then hit.Position.Y else root.Position.Y - hip
		local target = Vector3.new(goal.X, groundY, goal.Z)
		if not info.Pos or (target - info.Pos).Magnitude > B.Snap then
			info.Pos = target -- nasceu agora ou ficou longe demais: pula direto para perto do dono
			info.Look = look
			info.Speed = 0
		end
		local before = info.Pos
		local ownerSpeed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local xz = before:Lerp(Vector3.new(goal.X, before.Y, goal.Z), damp(math.max(6, ownerSpeed / 4), dt))
		info.Pos = Vector3.new(xz.X, before.Y + (groundY - before.Y) * damp(12, dt), xz.Z)
		local moved = (info.Pos - before) * Vector3.new(1, 0, 1)
		info.Speed += (moved.Magnitude / math.max(dt, 1e-3) - info.Speed) * damp(10, dt)
		local walking = info.Speed > 1.2
		local newLook = if walking and moved.Magnitude > 1e-4 then info.Look:Lerp(moved.Unit, damp(10, dt)) else info.Look:Lerp(look, damp(3, dt))
		info.Look = if newLook.Magnitude > 0.01 then newLook.Unit else look
		if info.CheerAt and serverNow >= info.CheerAt then
			info.CheerAt = nil
			info.Jump, info.Spin = 1, 1 -- comemora: pulo com giro
		end
		local lift, sx, sy, roll, pitch = 0, 1, 1, 0, 0
		if info.Float then
			-- flutua: sobe e desce devagar, balança e inclina para a frente quando anda
			lift = h * 0.35 + math.sin(t * 2.2 + info.Seed) * h * 0.06
			roll = math.sin(t * 1.6 + info.Seed) * 4
			pitch = if walking then -math.min(info.Speed, 40) * 0.3 else 0
		elseif walking then
			-- anda pulando (hop hop) com amassadinha, igual aos pets do cercado
			info.Phase += dt * (11 + math.min(info.Speed, 60) * 0.08)
			local bounce = math.abs(math.sin(info.Phase))
			lift = bounce * math.clamp(h * 0.18, 0.25, 1.2)
			local squash = 1 - bounce
			sy = 1 - squash * 0.16 + bounce * 0.06
			sx = 1 + squash * 0.1
			roll = math.sin(info.Phase) * 8
			pitch = -6
		else
			-- parado: respira
			local breath = math.sin(t * 2.4 + info.Seed)
			sy = 1 + breath * 0.04
			sx = 1 - breath * 0.02
		end
		local spin = 0
		if info.Jump > 0 then
			info.Jump = math.max(0, info.Jump - dt * 1.6)
			local p = 1 - info.Jump
			lift += math.sin(p * math.pi) * math.clamp(h * 0.6, 1, 3.5)
			sy *= 1 + math.sin(p * math.pi) * 0.15
			if info.Spin > 0 then
				spin = p * 360
			end
			if p < 0.12 then
				sy *= 0.85 -- agacha antes de pular
				sx *= 1.08
			end
			if info.Jump <= 0 then
				info.Spin = 0
			end
		end
		local feet = Vector3.new(info.Pos.X, info.Pos.Y - info.Sink, info.Pos.Z)
		local ground = CFrame.lookAt(feet, feet + info.Look)
			* CFrame.Angles(0, math.rad(spin), 0)
			* CFrame.new(0, lift, 0)
			* CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
		info.Rig:Pose(ground, sx, sy, sx, full)
	end

	local function infoOf(who: Player)
		local info = buddies[who]
		if info then
			return info
		end
		info = { Key = "", Look = Vector3.new(0, 0, -1), Speed = 0, Phase = 0, Jump = 0, Spin = 0, Acc = 0, Seed = math.random() * 10 }
		buddies[who] = info
		local function readKey()
			local key = who:GetAttribute("Buddy")
			info.Key = if type(key) == "string" then key else ""
		end
		readKey()
		who:GetAttributeChangedSignal("Buddy"):Connect(readKey)
		who:GetAttributeChangedSignal("Cheer"):Connect(function()
			local at = who:GetAttribute("Cheer")
			if type(at) == "number" and at > workspace:GetServerTimeNow() - 2 then
				info.CheerAt = at -- (pode ser no futuro: o Lendário ainda está saindo do ovo)
			end
		end)
		who.CharacterAdded:Connect(function()
			task.defer(refreshRay)
		end)
		return info
	end
	for _, who in Players:GetPlayers() do
		infoOf(who)
	end
	Players.PlayerAdded:Connect(infoOf)
	Players.PlayerRemoving:Connect(function(who)
		local info = buddies[who]
		if info then
			destroy(info)
		end
		buddies[who] = nil
		task.defer(refreshRay)
	end)
	refreshRay()

	-- gráfico no manual de 1 até LowQuality: só o seu parceiro aparece
	pcall(function()
		local gameSettings = UserSettings():GetService("UserGameSettings")
		local function readQuality()
			local level = gameSettings.SavedQualityLevel.Value
			flags.Low = level >= 1 and level <= B.LowQuality
		end
		readQuality()
		gameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(readQuality)
	end)

	-- avisos (só os seus): tocou no 🐾 = "X está seguindo você!"; 1º parceiro da sessão = dica do 🐾 na janela Pets
	local function sayBuddy(key: string)
		local id = Config.BuddyParse(key)
		local def = id and Critters.ById[id]
		if def then
			showToast(L("BuddyNow"):format(def.Name), "success")
			sfx("Pop")
		end
	end
	firstMin.BuddyTap = function(key: string)
		flags.Tap, flags.TapAt = key, os.clock()
		if player:GetAttribute("Buddy") == key then
			-- já era ele (o automático): agora fica escolhido; avisa na hora e ele dá um pulinho
			flags.Tap = nil
			sayBuddy(key)
			local mine = buddies[player]
			if mine then
				mine.Jump = 1
			end
		end
	end
	local lastKey = player:GetAttribute("Buddy")
	player:GetAttributeChangedSignal("Buddy"):Connect(function()
		local key = player:GetAttribute("Buddy")
		if type(key) == "string" and key ~= "" then
			if flags.Tap == key and os.clock() - flags.TapAt < 5 then
				flags.Tap = nil
				sayBuddy(key)
			elseif lastKey == "" and not flags.FirstTold then
				-- o 1º pet (o atributo já existia vazio: não é o carregar do save): dica depois do cartão do ovo
				flags.FirstTold = true
				task.delay(Config.HatchTime + 1.5, function()
					local waited = 0
					while (hatchBusy or hatchLayer.Visible) and waited < 15 do
						waited += task.wait(0.5)
					end
					showToast(L("BuddyFirst"), "info")
				end)
			end
		end
		lastKey = key
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		local serverNow = workspace:GetServerTimeNow()
		local builtOne = false -- no máximo 1 montagem por frame
		flags.Frame += 1
		local frame = flags.Frame
		for who, info in buddies do
			local mine = who == player
			if info.Key == "" or (flags.Low and not mine) then
				if info.Model then
					destroy(info)
				end
				continue
			end
			if info.Model and info.Built ~= info.Key then
				-- trocou de parceiro: o novo nasce no lugar do antigo, com pulinho
				destroy(info)
				info.Jump = 1
			end
			local character = who.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not root or not root:IsA("BasePart") then
				continue
			end
			local here = if info.Model and info.Pos then info.Pos else root.Position
			local lod = Config.BuddyLod((here - camPos).Magnitude, mine)
			if lod == "drop" then
				if info.Model then
					destroy(info)
					info.Pos = nil
				end
				continue
			end
			if not info.Model then
				if builtOne or flags.Busy or lod == "keep" or info.Failed == info.Key then
					continue
				end
				builtOne = true
				flags.Busy = true
				local key = info.Key
				local ok, done = pcall(build, who, info, root)
				flags.Busy = false
				if flags.Frame ~= frame then
					if buddies[who] ~= info then
						destroy(info)
					end
					break -- (esperou a pasta Models3D: os frames novos já cuidam de tudo; não continua a lista velha)
				end
				if not ok or not done then
					info.Failed = key
					continue
				end
			end
			if lod == "full" then
				info.Acc = 0
				animate(info, root, character, dt, t, serverNow, true)
			else
				info.Acc += dt
				if info.Acc >= 1 / 15 then
					animate(info, root, character, info.Acc, t, serverNow, false)
					info.Acc = 0
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- v67 OVO CHOCANDO NA BASE (só na tela de quem está a menos de 150 studs): o servidor só marca o ovo
-- (tag "Hatching" + HatchAt/HatchColor/HatchBig) e AQUI ele treme, cresce, brilha, racha (3 estalos), explode
-- em luz e solta cascas. Antes o servidor fazia isso a cada frame e o "Chocar todos" engasgava o jogo de todos.
-- Celular: no máximo 4 luzes e 32 cascas ao mesmo tempo; o laço só fica ligado enquanto tem ovo chocando.
---------------------------------------------------------------------
do
	local FAR = 150
	local SHELL_SIZE = Vector3.new(0.9, 0.25, 0.9)
	local hatching: { [Model]: any } = {}
	local count = { Lights = 0, Shells = 0, Crack = 0 }
	local loop: RBXScriptConnection? = nil

	local function crack(position: Vector3)
		local now = os.clock()
		if now - count.Crack > 0.07 then -- (vários ovos juntos: no máximo 1 estalo a cada 0,07 s)
			count.Crack = now
			sfxAt("Crack", position)
		end
	end

	-- fim do tremor: o ovo some na SUA tela (o servidor apaga logo depois), luz + estrelinhas + cascas voando
	local function finish(model: Model, info, p: number)
		hatching[model] = nil
		if info.Light then
			info.Light:Destroy()
			count.Lights -= 1
		end
		if not info.Started and p < 0 then
			return
		end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = 1
			end
		end
		local position = info.Start.Position
		sfxAt("Pop", position)
		if info.Big then
			sfxAt("Delivered", position)
		end
		local ball = create("Part", { Name = "HatchBurst", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(position), Color = info.Color,
			Material = Enum.Material.Neon, Transparency = 0.2, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = workspace })
		local emitter = create("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(info.Color, Color3.new(1, 1, 1)), LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(14, 26), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -25, 0), Rate = 0, Parent = ball,
		})
		emitter:Emit(if info.Big then 90 else 45)
		TweenService:Create(ball, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
		task.delay(1.5, function()
			ball:Destroy()
		end)
		if count.Shells + 8 > 32 then
			return -- ("Chocar todos": só os primeiros ovos soltam cascas)
		end
		count.Shells += 8
		local pieces = table.create(8)
		for k = 1, 8 do
			local shell = create("Part", { Name = "Shell", Size = SHELL_SIZE, Color = info.ShellColor, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false,
				CanTouch = false, CastShadow = false, CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), Parent = workspace })
			local a = (k / 8) * math.pi * 2
			shell.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 14, 22 + math.random() * 8, math.sin(a) * 14)
			shell.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
			pieces[k] = shell
		end
		task.delay(1.6, function()
			for _, shell in pieces do
				shell:Destroy()
			end
			count.Shells -= 8
		end)
	end

	local function step()
		local now = workspace:GetServerTimeNow()
		for model, info in hatching do
			local p = (now - info.At) / Config.HatchTime
			if not model.Parent or p >= 1 then
				finish(model, info, p)
			elseif p >= 0 then -- (antes disso o ovo espera a vez dele no "Chocar todos")
				if not info.Started then
					info.Started = true
					local root = model.PrimaryPart
					if root and count.Lights < 4 then
						count.Lights += 1
						info.Light = create("PointLight", { Color = info.Color, Range = 4, Brightness = 0, Parent = root })
					end
				end
				if p >= info.NextCrack then
					info.NextCrack += 1 / 3
					crack(info.Start.Position)
				end
				local power = 4 + p * 22 -- treme cada vez mais forte
				local angle = math.sin(p * 60) * power
				model:PivotTo(info.Start * CFrame.new(0, math.abs(math.sin(p * 30)) * 0.4 * p, 0) * CFrame.Angles(math.rad(angle * 0.4), 0, math.rad(angle)))
				-- cresce 1 -> 1,25 (ScaleTo mexe em todas as peças: só a cada +0,02)
				local grow = 1 + p * 0.25
				if grow - info.Scale >= 0.02 then
					info.Scale = grow
					pcall(model.ScaleTo, model, grow)
				end
				if info.Light then
					info.Light.Range = 4 + p * 14
					info.Light.Brightness = p * 4
				end
			end
		end
		if next(hatching) == nil and loop then
			loop:Disconnect()
			loop = nil
		end
	end

	local function begin(model: Instance)
		if not model:IsA("Model") or hatching[model] then
			return
		end
		local now = workspace:GetServerTimeNow()
		local at = model:GetAttribute("HatchAt")
		if typeof(at) ~= "number" then
			at = now
		end
		local camera = workspace.CurrentCamera
		local pivot = model:GetPivot()
		if now - at >= Config.HatchTime or not camera or (pivot.Position - camera.CFrame.Position).Magnitude > FAR then
			return -- longe ou já acabou: ninguém vê
		end
		local color = model:GetAttribute("HatchColor")
		local shellColor = Color3.new(1, 1, 1)
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") and item.Transparency < 1 then
				shellColor = item.Color
				break
			end
		end
		hatching[model] = {
			At = at, Start = pivot, Scale = 1, NextCrack = 0, Started = false, Light = nil :: PointLight?, ShellColor = shellColor,
			Color = if typeof(color) == "Color3" then color else Color3.new(1, 1, 1), Big = model:GetAttribute("HatchBig") == true,
		}
		if not loop then
			loop = RunService.RenderStepped:Connect(step)
		end
	end
	CollectionService:GetInstanceAddedSignal("Hatching"):Connect(begin)
	for _, model in CollectionService:GetTagged("Hatching") do
		begin(model)
	end
end

RunService.Stepped:Connect(function()
	local now = os.clock()
	for model, start in swinging do
		local t = (now - start) / 0.32
		local shoulder = model.Parent and model:FindFirstChild("RightShoulder", true)
		if t >= 1 or not shoulder then
			swinging[model] = nil
		elseif shoulder:IsA("Motor6D") then
			local angle = if t < 0.35 then 150 * (t / 0.35) else 150 - 230 * ((t - 0.35) / 0.65)
			shoulder.Transform = CFrame.Angles(math.rad(angle), 0, math.rad(-20))
		end
	end
	-- quem está carregando ovo: braços para frente segurando o ovo (todo mundo vê)
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character and other:GetAttribute("Carrying") then
			local moving = 0
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				moving = math.clamp((root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude / 20, 0, 1)
			end
			local sway = math.sin(now * 12) * 6 * moving
			for _, side in { "Right", "Left" } do
				local sign = if side == "Right" then 1 else -1
				local shoulder = character:FindFirstChild(side .. "Shoulder", true) -- R15
				if shoulder and shoulder:IsA("Motor6D") then
					shoulder.Transform = CFrame.Angles(math.rad(78 + sway), 0, math.rad(18 * sign))
				else
					local r6 = character:FindFirstChild(side .. " Shoulder", true) -- R6
					if r6 and r6:IsA("Motor6D") then
						r6.Transform = CFrame.Angles(0, 0, math.rad((80 + sway) * sign)) * CFrame.Angles(math.rad(-15 * sign), 0, 0)
					end
				end
				local elbow = character:FindFirstChild(side .. "Elbow", true)
				if elbow and elbow:IsA("Motor6D") then
					elbow.Transform = CFrame.Angles(math.rad(25), 0, 0)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- ESTEIRA 2.0 (v66, tela): em cima da SUA esteira aparece um painel com +X/passo, a SEQUÊNCIA (correndo sem
-- parar rende mais: RunMult/RunStreak do servidor) e quanto falta para a próxima zona, e o botão AUTO CORRER
-- (a criança não precisa ficar segurando o joystick). O AUTO CORRER desliga sozinho ao sair da esteira,
-- pegar um ovo ou mexer o personagem.
---------------------------------------------------------------------
local treadHud = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = if TOUCH then UDim2.new(0.5, 0, 1, -150) else UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(440, 150), BackgroundTransparency = 1, Visible = false, Parent = gui })
-- PC: acima da barra de itens do Roblox (bastão/armadilha, ~72 px embaixo no meio, por cima de tudo).
-- A barra não muda com a escala da tela, então a distância é calculada em pixels de verdade.
-- (dentro de do...end: o script já está perto do limite de 200 variáveis locais do Luau)
do
	local function aboveHotbar(object: GuiObject)
		if TOUCH then
			return
		end
		local function place()
			object.Position = UDim2.new(0.5, 0, 1, -math.ceil(78 / math.max(uiScale.Scale, 0.1)))
		end
		uiScale:GetPropertyChangedSignal("Scale"):Connect(place)
		place()
	end
	aboveHotbar(treadHud)
	aboveHotbar(carryText)
end
local autoRun = false
local autoArmed = false -- (v66) só desliga o AUTO RUN num movimento NOVO, não no dedo que já estava no joystick
local setAutoRun: (boolean) -> ()
local movingByHand: () -> boolean
local updateTreadHud: (number) -> ()
do
	local treadGain = text({ Size = UDim2.new(0.5, -4, 0, 40), Text = "", TextColor3 = PINK_TEXT, Stroke = 4, Parent = treadHud })
	local treadStreak = text({ Size = UDim2.new(0.5, -4, 0, 40), Position = UDim2.new(0.5, 4, 0, 0), Text = "", TextColor3 = Color3.fromRGB(255, 170, 60), Stroke = 4, Parent = treadHud })
	local zoneBar = create("Frame", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 46), BackgroundColor3 = Color3.fromRGB(20, 20, 26), Parent = treadHud }, { corner(10), stroke(3) })
	local zoneFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Green, Parent = zoneBar }, { corner(10) })
	Theme.gloss(zoneFill, 0.3)
	local zoneText = text({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", Stroke = 3, ZIndex = 2, Parent = zoneBar })

	local autoButton, autoLabel = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(260, 62), BackgroundColor3 = Theme.Gray, Parent = treadHud }, L("AutoRun"), function()
		setAutoRun(not autoRun)
	end)
	setAutoRun = function(on: boolean)
		autoRun = on
		autoArmed = false
		autoButton.BackgroundColor3 = if on then Theme.Green else Theme.Gray
		autoLabel.Text = if on then L("AutoRunOn") else L("AutoRun")
	end

	-- o módulo de controle do próprio Roblox diz se a criança está mexendo (teclado, joystick da tela ou controle)
	local controls: any = nil
	task.spawn(function()
		pcall(function()
			local requireModule: any = require
			local playerModule = requireModule(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 30))
			controls = playerModule:GetControls()
		end)
	end)
	movingByHand = function(): boolean
		if not controls then
			return false
		end
		local ok, vector = pcall(function()
			return controls:GetMoveVector()
		end)
		return ok and typeof(vector) == "Vector3" and vector.Magnitude > 0.2
	end
	local MOVE_KEYS = {
		[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
		[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
	}
	-- (digitando no chat não conta; o movimento em si também é visto pelo módulo de controle, logo abaixo)
	UserInputService.InputBegan:Connect(function(input, processed)
		if autoRun and not processed and MOVE_KEYS[input.KeyCode] then
			setAutoRun(false)
		end
	end)
	-- corre "para a frente" da esteira (quem corre olha para -Z, igual à trava de baixo).
	-- Roda DEPOIS do controle do Roblox (que mandaria "parado" quando ninguém toca no joystick).
	RunService:BindToRenderStep("CritterAutoRun", Enum.RenderPriority.Input.Value + 1, function()
		if autoRun then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:Move(Vector3.new(0, 0, -1), false)
			end
		end
	end)

	updateTreadHud = function(speed: number)
		local mult = player:GetAttribute("RunMult")
		if type(mult) ~= "number" or mult <= 0 then
			mult = 1
		end
		local streak = player:GetAttribute("RunStreak")
		local streaking = type(streak) == "number" and streak > 0
		treadGain.Text = L("PerStep"):format(Format.Short(math.floor((tonumber(player:GetAttribute("Gain")) or 0) * mult)))
		treadStreak.Text = "\u{1F525} " .. L("Streak"):format(mult)
		treadStreak.TextColor3 = if mult > 1 then Color3.fromRGB(255, 170, 60) elseif streaking then Color3.fromRGB(255, 220, 150) else Color3.fromRGB(200, 200, 210)
		-- próxima zona = a primeira que pede mais velocidade do que você tem
		local nextIndex = nil
		for index, zone in Config.Zones do
			if zone.Speed > speed then
				nextIndex = index
				break
			end
		end
		if nextIndex then
			local zone = Config.Zones[nextIndex]
			local from = if nextIndex > 1 then Config.Zones[nextIndex - 1].Speed else 0
			zoneFill.Size = UDim2.fromScale(math.clamp((speed - from) / math.max(zone.Speed - from, 1), 0, 1), 1)
			zoneText.Text = L("ToGo"):format(zone.Name, Format.Short(math.ceil(zone.Speed - speed)))
		else
			zoneFill.Size = UDim2.fromScale(1, 1)
			zoneText.Text = L("MaxZone")
		end
	end
end

local lastSlow = 0
local stripeOffset = 0
local currentZone = 0
local myBelt: BasePart? = nil
local beltPin: Vector3? = nil
local beltSearch = 0
local onMyBelt = false -- em cima da própria esteira (parado ou correndo)

-- listras da SUA esteira (v66): só as suas andam, só com você correndo, na cor do nível da esteira.
-- (listra invisível = a esteira 3D do Toolbox está por cima: pula)
local stripes = { List = {}, Of = nil :: BasePart?, Level = 0, Shown = -1 }
local function collectStripes(belt: BasePart)
	for _, info in stripes.List do
		if info.Part.Parent then
			info.Part.Position = info.Start -- devolve as da esteira antiga para o lugar
		end
	end
	stripes.List = {}
	stripes.Of = belt
	stripes.Level = 0
	stripes.Shown = -1
	local holder = belt.Parent
	if holder then
		for _, item in holder:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("BeltStripe") and item.Transparency < 1 then
				table.insert(stripes.List, { Part = item, Start = item.Position })
			end
		end
	end
end
RunService.RenderStepped:Connect(function()
	if stripeOffset == stripes.Shown then
		return
	end
	stripes.Shown = stripeOffset
	for _, info in stripes.List do
		local z = info.Start.Z + stripeOffset
		info.Part.Position = Vector3.new(info.Start.X, info.Start.Y, if z > info.Start.Z + 1.6 then z - 3.2 else z)
	end
end)

-- acha a SUA esteira (v66 perf): só dentro do SEU cercado (atributo PlotX do servidor) e no máximo 1x por
-- segundo, e para de procurar quando acha. Antes: workspace.Map:GetDescendants() (milhares de peças) a cada
-- frame até achar; quem ficou sem cercado (servidor cheio) varria o mapa para sempre.
local function findMyBelt(): BasePart?
	local plotX = player:GetAttribute("PlotX")
	local map = workspace:FindFirstChild("Map")
	if typeof(plotX) ~= "number" or not map then
		return nil -- ainda sem cercado: nem procura
	end
	-- o cercado certo = o "PlotN" cuja esteira está mais perto do X do seu cercado
	local best, bestDistance = nil, math.huge
	for _, plot in map:GetChildren() do
		if string.sub(plot.Name, 1, 4) == "Plot" then
			local tread = plot:FindFirstChild("Treadmill")
			local belt = (tread and tread:FindFirstChild("Belt")) or plot:FindFirstChild("Belt", true)
			if belt and belt:IsA("BasePart") then
				local distance = math.abs(belt.Position.X - plotX)
				if distance < bestDistance then
					best, bestDistance = belt, distance
				end
			end
		end
	end
	if best and best:GetAttribute("OwnerId") == player.UserId then
		return best
	end
	return nil
end

-- Z z Z dos guardiões: a placa "Info" de cada um é achada 1 vez (antes: busca recursiva 4x por segundo)
local guardianZzz: { [Instance]: BillboardGui } = setmetatable({}, { __mode = "k" }) :: any
local lastSignSpeed: number? = nil
local signsAt = 0

RunService.Heartbeat:Connect(function(dt)
	local clock = os.clock()
	local character = player.Character
	local carrying = player:GetAttribute("Carrying")
	carryText.Visible = carrying ~= nil
	-- ESTEIRA: correndo para a frente em cima da SUA esteira = corre no lugar (não é mais arremessado).
	-- Andando para o lado ou para trás você sai normalmente.
	local running = false
	onMyBelt = false
	pcall(function()
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not carrying then
			if not myBelt and clock >= beltSearch then
				beltSearch = clock + 1
				myBelt = findMyBelt()
			end
			if myBelt and (myBelt:GetAttribute("OwnerId") ~= player.UserId or not myBelt.Parent) then
				myBelt = nil
			end
			if myBelt and myBelt:GetAttribute("Unlocked") then
				if stripes.Of ~= myBelt then
					collectStripes(myBelt)
				end
				local rel = myBelt.CFrame:PointToObjectSpace(root.Position)
				-- altura folgada: no pulo (~7 studs) você continua "em cima da esteira" (o AUTO RUN e o painel não piscam)
				local inside = math.abs(rel.X) < myBelt.Size.X / 2 + 0.5 and math.abs(rel.Z) < myBelt.Size.Z / 2 + 0.5 and rel.Y > -1 and rel.Y < 16
				local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
				local forward = move.Magnitude > 0.1 and move.Unit:Dot(Vector3.new(0, 0, -1)) > 0.4
				onMyBelt = inside
				if inside and (forward or autoRun) then
					running = true
					if not beltPin then
						local center = myBelt.Position
						beltPin = Vector3.new(center.X, 0, center.Z + 2)
					end
					local pinned = Vector3.new(beltPin.X, root.Position.Y, beltPin.Z)
					root.CFrame = CFrame.lookAt(pinned, pinned + Vector3.new(0, 0, -1))
					stripeOffset = (stripeOffset + dt * math.clamp(humanoid.WalkSpeed, 8, 60) * 0.5) % 3.2
				end
			end
		end
	end)
	if not running then
		beltPin = nil
	end
	-- AUTO CORRER desliga sozinho: saiu da esteira, pegou um ovo ou mexeu o personagem.
	-- O dedo que já estava no joystick quando ligou não conta: só depois de soltar uma vez (autoArmed).
	local hand = autoRun and movingByHand()
	if autoRun and not hand then
		autoArmed = true
	end
	if autoRun and (not onMyBelt or carrying or (hand and autoArmed)) then
		setAutoRun(false)
	end
	if treadHud.Visible ~= onMyBelt then
		treadHud.Visible = onMyBelt
		if onMyBelt then
			updateTreadHud(player:GetAttribute("Speed") or 0)
			Theme.popIn(treadHud)
		end
	end
	if clock - lastSlow < 0.25 then
		return
	end
	lastSlow = clock
	local speed = player:GetAttribute("Speed") or 0
	speedText.Text = Format.Short(speed)
	moneyText.Text = Format.Money(player:GetAttribute("Money") or 0)
	incomeText.Text = "+" .. Format.Money(player:GetAttribute("Income") or 0) .. "/s"
	-- "!" do Menu (Diário, Missões, Rebirth, Doces, Admin) e textos dos quadrados
	refreshMenuBadge()
	-- "+$" saindo dos SEUS bichinhos, a cada 3 s, só dos que estão a menos de 70 studs de você
	-- (v66 perf: antes 60x por segundo lia o dono de todos os bichos do servidor e criava placas mesmo longe)
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	for model, info in wanderers do
		if clock >= info.Popup then
			info.Popup = clock + 3
			if myRoot and model.Parent and (info.Base - myRoot.Position).Magnitude < 70 and model:GetAttribute("Owner") == player.UserId then
				moneyPop(model, info)
			end
		end
	end
	-- painel da esteira
	if treadHud.Visible then
		updateTreadHud(speed)
	end
	-- listras da sua esteira na cor do nível dela
	local treadLevel = player:GetAttribute("TreadLevel") or 1
	if treadLevel ~= stripes.Level and #stripes.List > 0 then
		stripes.Level = treadLevel
		local treadInfo = Config.Treadmills[treadLevel] or Config.Treadmills[1]
		for _, stripe in stripes.List do
			stripe.Part.Color = treadInfo.Color
		end
	end
	-- placas das zonas: verde se você já tem a velocidade recomendada
	-- (só quando a velocidade muda, ou a cada 2 s para placas novas)
	if speed ~= lastSignSpeed or clock >= signsAt then
		lastSignSpeed = speed
		signsAt = clock + 2
		for _, board in CollectionService:GetTagged("ZoneSign") do
			local need = board:GetAttribute("Need")
			local signGui = board:FindFirstChild("SignGui")
			local line = signGui and signGui:FindFirstChild("Line2")
			if line and typeof(need) == "number" then
				line.TextColor3 = if speed >= need then Color3.fromRGB(110, 255, 110) else Color3.fromRGB(255, 70, 80)
			end
		end
		for _, anchor in CollectionService:GetTagged("ZoneSpeedTag") do
			local need = anchor:GetAttribute("Need")
			local bb = anchor:FindFirstChild("Billboard")
			local line = bb and bb:FindFirstChild("Line2")
			if line and typeof(need) == "number" and need > 0 then
				line.TextColor3 = if speed >= need then Color3.fromRGB(110, 255, 110) else Color3.fromRGB(255, 70, 80)
			end
		end
	end
	-- ovos dos ninhos: mostra se você consegue fugir com ele (verde) ou se é pesado demais (vermelho)
	for egg in nestEggSet do
		local need = egg:GetAttribute("Need")
		local eggRoot = egg.PrimaryPart
		local tagOld = eggRoot and eggRoot:FindFirstChild("SpeedTag")
		if tagOld then
			tagOld.Enabled = eggRoot.Anchored and not player:GetAttribute("PhotoMode")
		end
		if typeof(need) == "number" and eggRoot then
			local tag = eggRoot:FindFirstChild("SpeedTag")
			if not tag then
				tag = create("BillboardGui", { Name = "SpeedTag", Size = UDim2.fromScale(8, 1.3), StudsOffsetWorldSpace = Vector3.new(0, -egg:GetExtentsSize().Y / 2 - 0.4, 0), AlwaysOnTop = true, MaxDistance = 45, LightInfluence = 0, Parent = eggRoot })
				text({ Name = "Label", Size = UDim2.fromScale(1, 1), Text = "", Parent = tag })
				tag.Adornee = eggRoot
			end
			local label = tag:FindFirstChild("Label")
			if label then
				local ok = speed >= need
				label.Text = if ok then "\u{2705} You can escape!" else ("\u{26A0} HEAVY! Need %s \u{1F45F}"):format(Format.Short(math.ceil(need)))
				label.TextColor3 = if ok then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 90, 90)
			end
		end
	end
	-- Z z Z balançando
	for guardian in guardianSet do
		local info = guardianZzz[guardian]
		if not info or not info.Parent then
			local found = guardian:FindFirstChild("Info", true)
			info = if found and found:IsA("BillboardGui") then found else nil
			guardianZzz[guardian] = info
		end
		if info then
			info.StudsOffset = if guardian:GetAttribute("Sleeping") then Vector3.new(0, math.sin(clock * 2) * 0.8, 0) else Vector3.zero
		end
	end
	-- céu de cada zona (cor do ar muda conforme a zona em que você está)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local zoneIndex = if root.Position.Z < 0 then 0 else math.clamp(math.floor(root.Position.Z / Config.Map.LaneLength) + 1, 1, #Config.Zones)
		if zoneIndex ~= currentZone then
			currentZone = zoneIndex
			-- (a cor do ar de cada zona agora é do Ambience.client)
			if zoneIndex > 0 then
				showBanner(("%s %s"):format(Config.Zones[zoneIndex].Emoji or "", Config.Zones[zoneIndex].Name), Color3.new(1, 1, 1))
			end
		end
	end
	-- seta guia + dica do tutorial
	local target: Vector3? = nil
	local hint: string? = nil
	local pulse: string? = nil
	if root then
		target, hint, pulse = tutorial(root)
	end
	-- (na esteira o painel já explica; v67: some também com janela aberta e no cartão do bichinho novo)
	tutorialText.Visible = hint ~= nil and not carrying and not treadHud.Visible and not hatchLayer.Visible and not anyWindowOpen() and not stunText.Visible -- (no celular ficava embaixo do ATORDOADO)
	if hint and hint ~= tutorialStep then
		-- pulinho só quando muda a META (v67: o relógio da noite e o % mudam o texto toda hora)
		local newGoal = string.sub(hint, 1, 12) ~= string.sub(tutorialStep, 1, 12)
		tutorialStep = hint
		tutorialText.Text = hint
		if newGoal then
			Theme.popIn(tutorialText)
		end
	end
	-- v67: depois do tutorial a linha da meta fica mais fina (46 -> 34 px)
	local small = (player:GetAttribute("Stolen") or 0) >= 6 and (player:GetAttribute("PenLevel") or 0) >= 1
	if small ~= firstMin.Small then
		firstMin.Small = small
		tutorialText.Size = UDim2.fromOffset(tutorialText.Size.X.Offset, if small then 34 else 46)
	end
	-- v67: botão da esquerda balançando (Índice com prêmio para pegar)
	if pulse ~= firstMin.Pulse then
		firstMin.Pulse = pulse
		local stop = firstMin.StopPulse
		firstMin.StopPulse = nil
		if stop then
			stop()
		end
		if pulse == "Index" and firstMin.IndexButton then
			firstMin.StopPulse = Theme.pulse(firstMin.IndexButton)
		end
	end
	if target and root then
		arrow0.Parent = root
		targetPart.Position = target
		beam.Enabled = true
	else
		beam.Enabled = false
	end
	-- (a janela Eggs se atualiza sozinha quando o atributo Slots muda: ver refreshEggs)
end)

---------------------------------------------------------------------
-- v67 PERSEGUIÇÃO: carregando ovo e o guardião da SUA zona a menos de 30 studs de te pegar = coração batendo
-- (o som Step bem grave, mais rápido abaixo de 12 studs) e borda vermelha na tela (mais forte quanto mais perto).
-- Sem imagens: 4 faixas com gradiente, criadas 1 vez. Sem ovo nas mãos o laço sai na 1ª linha.
---------------------------------------------------------------------
do
	local RANGE, CLOSE = 30, 12
	local edges = {}
	for _, side in {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.2), 90 }, -- cima (gradiente de cima para baixo)
		{ UDim2.fromScale(0, 0.8), UDim2.fromScale(1, 0.2), -90 }, -- baixo
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.14, 1), 0 }, -- esquerda
		{ UDim2.fromScale(0.86, 0), UDim2.fromScale(0.14, 1), 180 }, -- direita
	} do
		table.insert(edges, create("Frame", {
			Position = side[1], Size = side[2], BackgroundColor3 = Color3.fromRGB(255, 25, 40), BackgroundTransparency = 1, BorderSizePixel = 0,
			Visible = false, Active = false, ZIndex = 0, Parent = gui,
		}, { create("UIGradient", { Rotation = side[3], Transparency = NumberSequence.new(0, 1) }) }))
	end
	local chase = { Shown = false, Level = 1, NextBeat = 0, Zone = nil :: number?, Guardian = nil :: Model? }
	local function show(on: boolean, transparency: number)
		if on ~= chase.Shown then
			chase.Shown = on
			for _, edge in edges do
				edge.Visible = on
			end
		end
		if on and math.abs(transparency - chase.Level) > 0.01 then
			chase.Level = transparency
			for _, edge in edges do
				edge.BackgroundTransparency = transparency
			end
		end
	end
	RunService.Heartbeat:Connect(function()
		local zoneIndex = player:GetAttribute("CarryZone")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if type(zoneIndex) ~= "number" or not root or not player:GetAttribute("Carrying") then
			if chase.Shown then
				show(false, 1)
			end
			return
		end
		-- acha o guardião da zona do ovo (1 vez por ovo; de novo se ele sumir)
		local guardian = chase.Guardian
		if chase.Zone ~= zoneIndex or not guardian or not guardian.Parent then
			guardian = nil
			for model in guardianSet do
				if model:GetAttribute("Zone") == zoneIndex then
					guardian = model
					break
				end
			end
			chase.Zone = zoneIndex
			chase.Guardian = guardian
		end
		if not guardian then
			show(false, 1)
			return
		end
		-- posição que a tela mostra (a animação suave) ou, sem ela, a meta que o servidor mandou
		local info = guardianState[guardian]
		local goal = guardian:GetAttribute("Goal")
		local pos = if info then info.Pos elseif typeof(goal) == "CFrame" then goal.Position else guardian:GetPivot().Position
		local catchRange = guardian:GetAttribute("CatchRange")
		local gap = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z).Magnitude - (if type(catchRange) == "number" then catchRange else 4)
		if gap >= RANGE or guardian:GetAttribute("Sleeping") then
			show(false, 1)
			return
		end
		local near = 1 - math.clamp(gap / RANGE, 0, 1) -- 0 = longe ... 1 = encostando
		show(true, 0.9 - 0.4 * near)
		local clock = os.clock()
		if clock >= chase.NextBeat then
			chase.NextBeat = clock + (if gap < CLOSE then 0.35 else 0.6)
			-- "tum-tum" (sfx já fica mudo com o Som desligado)
			sfx("Step", 0.45)
			task.delay(0.13, sfx, "Step", 0.4)
		end
	end)
end

---------------------------------------------------------------------
-- MODO FOTO (só no Studio): P = esconde a tela, Z/X = troca de cena, V = voo de câmera, C = volta ao normal
---------------------------------------------------------------------
if RunService:IsStudio() then
	local StarterGui = game:GetService("StarterGui")
	local LANE = Config.Map.LaneLength
	local function zoneShot(index: number, side: number?)
		local z0 = LANE * (index - 1)
		local s = side or 1
		return CFrame.lookAt(Vector3.new(38 * s, 34, z0 + 125), Vector3.new(0, 12, z0 + LANE * 0.75))
	end
	local shots = {
		CFrame.lookAt(Vector3.new(0, 70, 60), Vector3.new(0, 4, -120)),
		CFrame.lookAt(Vector3.new(-112, 20, -4), Vector3.new(-112, 6, -36)),
		CFrame.lookAt(Vector3.new(118, 22, -2), Vector3.new(118, 6, -36)),
		CFrame.lookAt(Vector3.new(0, 7, -22), Vector3.new(0, 22, 60)),
		zoneShot(1),
		zoneShot(2, -1),
		zoneShot(3),
		zoneShot(4, -1),
		zoneShot(5),
		zoneShot(6, -1),
		zoneShot(7),
		zoneShot(8, -1),
		zoneShot(9),
		zoneShot(10, -1),
		zoneShot(11),
		zoneShot(12, -1),
	}
	-- closes dos chefões (para ícone e thumbnails)
	for _, index in { 1, 6, 9, 10, 4, 11 } do
		local zone = Config.Zones[index]
		local z = LANE * (index - 1) + LANE * 0.75
		local h = zone.Height or 20
		table.insert(shots, CFrame.lookAt(Vector3.new(h * 0.45, h * 0.62, z - h * 1.35), Vector3.new(0, h * 0.5, z)))
	end
	local shotIndex = 0
	local hidden = false
	local function setHidden(on: boolean)
		hidden = on
		player:SetAttribute("PhotoMode", on)
		for _, item in player.PlayerGui:GetChildren() do
			if item:IsA("ScreenGui") then
				item.Enabled = not on
			end
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, not on)
		-- placas flutuantes do mundo também somem (foto limpa)
		for _, item in workspace:GetDescendants() do
			if item:IsA("BillboardGui") then
				item.Enabled = not on
			end
		end
		local character = player.Character
		if character then
			for _, item in character:GetDescendants() do
				if item:IsA("BasePart") or item:IsA("Decal") then
					item.LocalTransparencyModifier = if on then 1 else 0
				end
			end
		end
	end
	local flying = false
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local camera = workspace.CurrentCamera
		if input.KeyCode == Enum.KeyCode.P then
			setHidden(not hidden)
		elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Z then
			shotIndex = (shotIndex + (if input.KeyCode == Enum.KeyCode.X then 1 else -1) - 1) % #shots + 1
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = shots[shotIndex]
		elseif input.KeyCode == Enum.KeyCode.C then
			flying = false
			camera.CameraType = Enum.CameraType.Custom
		elseif input.KeyCode == Enum.KeyCode.V and not flying then
			-- voo: hub -> lojas -> portão -> zonas, devagar
			flying = true
			camera.CameraType = Enum.CameraType.Scriptable
			task.spawn(function()
				local path = { shots[1], shots[2], shots[3], shots[4], zoneShot(1), zoneShot(3), zoneShot(5, -1), zoneShot(6), zoneShot(9, -1), zoneShot(10), zoneShot(12, -1) }
				camera.CFrame = path[1]
				for k = 2, #path do
					if not flying then
						break
					end
					local tween = TweenService:Create(camera, TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = path[k] })
					tween:Play()
					tween.Completed:Wait()
					task.wait(0.4)
				end
				flying = false
			end)
		end
	end)
end
