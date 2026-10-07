--[[
	Guard (v6): anti-teleporte para os prêmios "por chegar perto".
	O personagem é controlado pelo celular/PC do jogador, então um hack consegue teletransportar o boneco.
	A cada 0,2 s o servidor compara onde cada um estava e onde está: um salto maior do que dá para andar
	(com folga para lag, pulo e queda) deixa o jogador "suspeito" por alguns segundos, e nesse tempo os
	prêmios por proximidade (caça aos ovos, obby, ovo surpresa, ovo gigante) não pagam.
	Quando o PRÓPRIO servidor move o jogador (nascer, botão de teleporte), ele chama Guard.Grace antes.
	Sentado (trator, VehicleSeat) não conta: o veículo é mais rápido que andar.
	O obby também exige passar pela largada e levar um tempo mínimo até o baú.
]]

local Players = game:GetService("Players")

local Guard = {}

local SUSPECT_SECONDS = 8
local OBBY_MIN_SECONDS = 8 -- ninguém faz o obby inteiro mais rápido que isso
local OBBY_WINDOW = 600 -- passou pela largada há no máximo 10 min

type Track = { Pos: Vector3?, At: number, Suspect: number, Grace: number, ObbyStart: number }

local tracks: { [Player]: Track } = {}

local function track(player: Player): Track
	local t = tracks[player]
	if not t then
		t = { Pos = nil, At = 0, Suspect = 0, Grace = os.clock() + 5, ObbyStart = 0 }
		tracks[player] = t
	end
	return t
end

-- O servidor vai mover o jogador: não conta como salto suspeito
function Guard.Grace(player: Player, seconds: number?)
	local t = track(player)
	t.Grace = math.max(t.Grace, os.clock() + (seconds or 2))
	t.Pos = nil
end

-- Pode receber prêmio por proximidade agora?
function Guard.Ok(player: Player): boolean
	local t = tracks[player]
	return t ~= nil and os.clock() >= t.Suspect
end

-- Obby: chamado quando o jogador está na largada
function Guard.ObbyStarted(player: Player)
	track(player).ObbyStart = os.clock()
end

-- Obby: chegou no baú de um jeito possível? (passou pela largada, levou um tempo mínimo e não teleportou)
function Guard.ObbyOk(player: Player): boolean
	local t = tracks[player]
	if not t or not Guard.Ok(player) then
		return false
	end
	local since = os.clock() - t.ObbyStart
	return t.ObbyStart > 0 and since >= OBBY_MIN_SECONDS and since <= OBBY_WINDOW
end

function Guard.Init()
	task.spawn(function()
		while true do
			local dt = task.wait(0.2)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local t = track(player)
				if not root or not humanoid or humanoid.Health <= 0 then
					t.Pos = nil
					continue
				end
				local pos = root.Position
				local flat = Vector3.new(pos.X, 0, pos.Z)
				if humanoid.SeatPart or now < t.Grace then
					t.Pos = flat
					t.At = now
					continue
				end
				if t.Pos then
					local elapsed = math.max(now - t.At, dt, 0.05)
					local maxStep = (humanoid.WalkSpeed * 1.6 + 20) * elapsed + 10
					if (flat - t.Pos).Magnitude > maxStep then
						t.Suspect = now + SUSPECT_SECONDS
					end
				end
				t.Pos = flat
				t.At = now
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
end

return Guard
