--[[
	Auras (Farmar Aura): coleção de auras com giros GRÁTIS (nunca vendidos), aura visível no boneco.
	  • RollAura: gasta 1 giro; o servidor sorteia (Sim.RollAura) e a tela só mostra o resultado.
	  • EquipAura: troca a aura equipada (só as que o jogador tem).
	  • relógio: 1 giro grátis por hora (Config.AuraRolls), guardado no save.
	  • Lua de Sangue: quando começa, todo mundo online ganha giro(s).
	  • aura Épica ou melhor: aviso no servidor; Mítica ou melhor: aviso em TODOS os servidores.
	  • no boneco: atributos no jogador, que a tela de todo mundo desenha (ClientMain/AuraFx):
	      AuraColor (Color3 da evolução: selo), AuraEquip (id da aura equipada), AuraVoid/AuraRainbow.
]]

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sim = require(ReplicatedStorage.Shared.Sim)
local Registry = require(script.Parent.Registry)

local Auras = {}

local TOPIC = "FarmarAuraRare"

local function notify(player: Player, key: string, args: any?, kind: string?)
	Registry.Remotes.NotifyPlayer(player, key, args, kind)
end

-- cor da evolução + aura equipada, para todo mundo ver
function Auras.Refresh(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	local seal = Config.Seals[tonumber(data.Seal) or 0]
	player:SetAttribute("AuraColor", if seal then seal.Color else Config.AuraBaseColor)
	player:SetAttribute("AuraRainbow", seal ~= nil and seal.Rainbow == true)
	player:SetAttribute("AuraVoid", seal ~= nil and seal.Void == true)
	local equipped = Config.AuraById[data.AuraEquip or ""]
	local owned = equipped and type(data.Auras) == "table" and (data.Auras[equipped.Id] or 0) > 0
	player:SetAttribute("AuraEquip", if owned then equipped.Id else "")
end

local function roll(player: Player)
	local data = Registry.Game.Data(player)
	if not data then
		return
	end
	Sim.AuraFreeTick(Config, data, os.time())
	local aura, tier = Sim.RollAura(Config, data, Registry.Game.Ctx(player), math.random)
	if not aura or not tier then
		notify(player, "n.noRolls", nil, "error")
		return
	end
	-- a tela anima o giro e mostra o resultado (aura, tier)
	Registry.Remotes.Fx:FireClient(player, "auraRoll", nil, aura.Id, tier.Id)
	Auras.Refresh(player)
	Registry.Game.ApplySpeed(player)
	Registry.Game.Push(player)
	if tier.Announce then
		task.delay(2.2, function() -- depois da animação de quem girou
			Registry.Remotes.NotifyAll("n.auraRare", { player = player.DisplayName, aura = aura.Id, tier = tier.Id }, "event")
		end)
	end
	if tier.Global then
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { player = player.DisplayName, aura = aura.Id, tier = tier.Id, job = game.JobId })
		end)
	end
	if tier.Announce then
		task.spawn(Registry.Data.Save, player) -- aura rara: salva já
	end
end

local function equip(player: Player, id: any)
	local data = Registry.Game.Data(player)
	if not data or type(id) ~= "string" or #id > 30 then
		return
	end
	if Sim.EquipAura(Config, data, id) then
		Auras.Refresh(player)
		Registry.Game.Push(player)
	end
end

function Auras.Init()
	Registry.Remotes.On("RollAura", roll, 0.6)
	Registry.Remotes.On("EquipAura", equip, 0.3)
	-- aviso de aura Mítica+ vindo de outros servidores
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local m = message.Data
			if type(m) == "table" and m.job ~= game.JobId and type(m.player) == "string" and type(m.aura) == "string" then
				Registry.Remotes.NotifyAll("n.auraGlobal", { player = m.player, aura = m.aura, tier = m.tier }, "event")
			end
		end)
	end)
	-- relógio dos giros grátis + atributos de quem acabou de carregar
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = Registry.Game.Data(player)
				if data then
					if player:GetAttribute("AuraColor") == nil then
						Auras.Refresh(player)
					end
					if Sim.AuraFreeTick(Config, data, now) then
						Registry.Game.Push(player)
					end
				end
			end
		end
	end)
	-- Lua de Sangue: giro de presente para quem está online
	local lastWeather = workspace:GetAttribute("Weather")
	workspace:GetAttributeChangedSignal("Weather"):Connect(function()
		local id = workspace:GetAttribute("Weather")
		local def = Config.WeatherById and Config.WeatherById[id]
		if id ~= lastWeather and def and def.AuraLuck then
			for _, player in Players:GetPlayers() do
				local data = Registry.Game.Data(player)
				if data then
					Sim.AddAuraRolls(Config, data, Config.AuraRolls.MoonRolls)
					notify(player, "n.auraMoon", nil, "event")
					Registry.Game.Push(player)
				end
			end
		end
		lastWeather = id
	end)
end

return Auras
