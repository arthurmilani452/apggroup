--[[
	Fairness (ModuleScript em ServerScriptService > Game)
	Deixa o jogo justo para quem está começando (jogador novo que é roubado logo de cara desiste):
	  • ESCUDO DE NOVATO: ninguém rouba a base de quem tem menos de 10 min de jogo (tempo total, salvo)
	  • VINGANÇA: quem é roubado ganha +velocidade por 30 s e vê o ladrão brilhando através das paredes
	  • AZARÃO: quem ganha bem menos que o melhor jogador do servidor ganha +25% de dinheiro
	  • SEM COVARDIA: quem ganha 20x mais não pode roubar de quem é muito mais fraco
	Os números ficam em Config (NewbieShieldSeconds, RevengeSeconds, UnderdogBonus, BullyIncomeRatio...).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Fairness = {}

local underdog: { [Player]: boolean } = {}
local shieldAnnounced: { [Player]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getData(player: Player): any
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

-- Segundos de escudo que ainda faltam
function Fairness.ShieldLeft(player: Player): number
	local plot = Registry.Plots.Get(player)
	local untilTime = plot and plot.Model:GetAttribute("ShieldUntil")
	if typeof(untilTime) ~= "number" then
		return 0
	end
	return math.max(0, untilTime - now())
end

function Fairness.SetupPlayer(player: Player)
	local data = getData(player)
	local plot = Registry.Plots.Get(player)
	if not data or not plot then
		return
	end
	local left = Config.NewbieShieldSeconds - (tonumber(data.PlayTime) or 0)
	-- v20: escudo comprado (Base Shield) continua valendo se o jogador sair e voltar
	left = math.max(left, (tonumber(data.PaidShieldUntil) or 0) - os.time())
	if left > 0 then
		plot.Model:SetAttribute("ShieldUntil", now() + left)
		shieldAnnounced[player] = false
	else
		plot.Model:SetAttribute("ShieldUntil", nil)
		shieldAnnounced[player] = true
	end
end

-- v20: Base Shield comprado: soma ao escudo que já tem, até o máximo (Config.PaidShieldMaxSeconds)
function Fairness.AddPaidShield(player: Player, seconds: number): boolean
	local data = getData(player)
	local plot = Registry.Plots.Get(player)
	if not data or not plot then
		return false
	end
	local paidLeft = math.max(0, (tonumber(data.PaidShieldUntil) or 0) - os.time())
	local total = math.min(paidLeft + seconds, Config.PaidShieldMaxSeconds)
	data.PaidShieldUntil = os.time() + total
	local current = Fairness.ShieldLeft(player)
	plot.Model:SetAttribute("ShieldUntil", now() + math.max(current, total))
	shieldAnnounced[player] = true
	Registry.Remotes.Notify(player, ("BASE SHIELD ON: nobody can steal from you for %s!"):format(Format.Time(math.max(current, total))), "success")
	return true
end

function Fairness.HasPaidShield(player: Player): boolean
	local data = getData(player)
	return data ~= nil and (tonumber(data.PaidShieldUntil) or 0) > os.time()
end

-- Pode roubar? (o servidor sempre confere; a tela só esconde o botão)
function Fairness.CanSteal(thief: Player, owner: Player): (boolean, string?)
	-- vingança: quem foi roubado sempre pode roubar de volta de quem o roubou
	local revengeUntil = thief:GetAttribute("RevengeUntil")
	if thief:GetAttribute("RevengeTarget") == owner.UserId and typeof(revengeUntil) == "number" and revengeUntil > now() then
		return true, nil
	end
	if owner:GetAttribute("InMinigame") then
		return false, owner.DisplayName .. " is playing a minigame. Their base is safe until they come back!"
	end
	local left = Fairness.ShieldLeft(owner)
	if left > 0 then
		return false, ("%s is new! Their base has a New Player Shield (%s)."):format(owner.DisplayName, Format.Time(left))
	end
	-- "Power" = renda da base + mochila (guardar tudo na mochila não engana a regra)
	local thiefIncome = tonumber(thief:GetAttribute("Power")) or 0
	local ownerIncome = tonumber(owner:GetAttribute("Power")) or 0
	if thiefIncome > 0 and ownerIncome * Config.BullyIncomeRatio < thiefIncome then
		return false, owner.DisplayName .. " is much weaker than you. Steal from someone your size!"
	end
	return true, nil
end

-- Vingança: +velocidade por alguns segundos e o ladrão fica brilhando na tela da vítima
local function startRevenge(victim: Player, thief: Player)
	if not victim.Parent then
		return
	end
	local untilTime = now() + Config.RevengeSeconds
	victim:SetAttribute("RevengeUntil", untilTime)
	victim:SetAttribute("RevengeTarget", thief.UserId)
	Registry.Economy.ApplySpeed(victim)
	task.delay(Config.RevengeSeconds + 0.1, function()
		if victim.Parent and (victim:GetAttribute("RevengeUntil") or 0) <= now() then
			victim:SetAttribute("RevengeTarget", nil)
			Registry.Economy.ApplySpeed(victim)
		end
	end)
end

function Fairness.OnGrab(victim: Player, thief: Player)
	startRevenge(victim, thief)
	-- novato que começa a roubar perde o escudo (senão a vítima não consegue se vingar)
	-- (o Base Shield comprado não some: v20)
	if Fairness.ShieldLeft(thief) > 0 and not Fairness.HasPaidShield(thief) then
		local plot = Registry.Plots.Get(thief)
		if plot then
			plot.Model:SetAttribute("ShieldUntil", nil)
		end
		shieldAnnounced[thief] = true
		local data = getData(thief)
		if data then
			data.PlayTime = math.max(tonumber(data.PlayTime) or 0, Config.NewbieShieldSeconds)
		end
		Registry.Remotes.Notify(thief, "You started stealing, so your New Player Shield is gone!", "warning")
	end
end

function Fairness.OnStolen(victim: Player, thief: Player)
	startRevenge(victim, thief)
	Registry.Remotes.Notify(victim, ("REVENGE! +%d speed for %ds. Go steal it back from %s!"):format(Config.RevengeSpeedBonus, Config.RevengeSeconds, thief.DisplayName), "warning")
end

function Fairness.SpeedBonus(player: Player): number
	local untilTime = player:GetAttribute("RevengeUntil")
	if typeof(untilTime) == "number" and untilTime > now() then
		return Config.RevengeSpeedBonus
	end
	return 0
end

function Fairness.IncomeMultiplier(player: Player): number
	return if underdog[player] then 1 + Config.UnderdogBonus else 1
end

-- Admin (testes no Studio): acaba o escudo de alguém ou dá o escudo de novo
function Fairness.EndShield(player: Player)
	local data = getData(player)
	if data then
		data.PlayTime = math.max(tonumber(data.PlayTime) or 0, Config.NewbieShieldSeconds)
		data.PaidShieldUntil = 0
	end
	local plot = Registry.Plots.Get(player)
	if plot then
		plot.Model:SetAttribute("ShieldUntil", nil)
	end
	shieldAnnounced[player] = true
end

function Fairness.RestartShield(player: Player)
	local data = getData(player)
	if data then
		data.PlayTime = 0
	end
	Fairness.SetupPlayer(player)
end

function Fairness.RemovePlayer(player: Player)
	underdog[player] = nil
	shieldAnnounced[player] = nil
end

function Fairness.Init()
	Players.PlayerRemoving:Connect(Fairness.RemovePlayer)

	-- Tempo de jogo (para o escudo) e fim do escudo
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				for _, player in Players:GetPlayers() do
					local data = getData(player)
					if data and player:GetAttribute("Loaded") then
						data.PlayTime = (tonumber(data.PlayTime) or 0) + 1
						if not shieldAnnounced[player] and Fairness.ShieldLeft(player) <= 0 then
							shieldAnnounced[player] = true
							local plot = Registry.Plots.Get(player)
							if plot then
								plot.Model:SetAttribute("ShieldUntil", nil)
							end
							Registry.Remotes.Notify(player, "Your New Player Shield is gone. LOCK your base when thieves come!", "warning")
						end
					end
				end
			end)
			if not ok then
				warn("[Fairness] loop error:", err)
			end
		end
	end)

	-- Azarão: compara a renda de cada um com a do melhor jogador do servidor (a cada 5 s)
	task.spawn(function()
		while true do
			task.wait(5)
			local ok, err = pcall(function()
				local incomes = {}
				local top = 0
				for _, player in Players:GetPlayers() do
					if getData(player) and player:GetAttribute("Loaded") then
						local current = Registry.Economy.GetPower(player) / Fairness.IncomeMultiplier(player)
						incomes[player] = current
						top = math.max(top, current)
					end
				end
				for player, income in incomes do
					local was = underdog[player] == true
					local isUnder
					if top <= 0 then
						isUnder = false
					elseif was then
						isUnder = income < top * Config.UnderdogExit -- sai só um pouco depois (não fica piscando)
					else
						isUnder = income < top * Config.UnderdogEnter
					end
					if isUnder ~= was then
						underdog[player] = isUnder
						player:SetAttribute("Underdog", isUnder)
						if isUnder then
							Registry.Remotes.Notify(player, ("Underdog bonus: +%d%% cash while you catch up!"):format(math.floor(Config.UnderdogBonus * 100)), "success")
						end
						Registry.Economy.Sync(player)
					end
				end
			end)
			if not ok then
				warn("[Fairness] loop error:", err)
			end
		end
	end)
end

return Fairness
