--[[
	PetMotion (ModuleScript em StarterPlayer > StarterPlayerScripts)
	A "animação" dos pets que seguem o jogador. Só conta; quem move as peças é o PetFollow.
	Os modelos 3D são uma peça só (sem ossos), então a animação é feita mexendo o corpo inteiro:
	  • andando: pulinhos no ritmo da velocidade, balanço de um lado pro outro, inclina pra frente,
	    amassa quando pisa e estica no ar (sem mudar o volume), inclina nas curvas
	  • parado: respira, olha para os lados, dá pulinhos de alegria, gira ou se sacode de vez em quando
	  • dono pulou: o pet pula junto (cada um com um tiquinho de atraso) e amassa ao cair
	  • voadores (Lendário ou melhor): flutuam, batem "asas" (esticadinha rápida) e inclinam nas curvas
	Tudo roda só na tela de cada jogador.
]]

local PetMotion = {}

local TAU = math.pi * 2
local GRAVITY = 70
local MAX_SPEED = 42
local TELEPORT = 60

export type State = {
	Float: boolean,
	Size: number,
	Phase: number,
	Index: number,
	Seed: number,
	Position: Vector3?,
	Velocity: Vector3,
	Yaw: number,
	YawRate: number,
	Step: number,
	Moving: number,
	JumpY: number,
	JumpVel: number,
	JumpDelay: number,
	Squash: number,
	SquashVel: number,
	IdleFor: number,
	NextIdle: number,
	Action: string?,
	ActionT: number,
	WasOwnerUp: boolean,
}

export type Input = {
	Target: Vector3, -- lugar do pet atrás do dono
	OwnerLook: Vector3, -- para onde o dono olha (sem Y)
	OwnerRising: boolean, -- o dono está subindo (pulou)
	GroundY: number, -- altura do chão embaixo do pet
	Now: number,
}

export type Pose = {
	CFrame: CFrame, -- os PÉS do pet (centro embaixo), olhando para -Z
	Scale: Vector3, -- amassa/estica (X e Z iguais, Y diferente; volume ~1)
	Landed: boolean, -- acabou de pisar (poeirinha)
	Speed: number,
}

-- número "aleatório" fixo por pet (para cada pet ter o seu jeito)
local function hash(n: number): number
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

local function angleDelta(from: number, to: number): number
	local d = (to - from) % TAU
	if d > math.pi then
		d -= TAU
	end
	return d
end

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

function PetMotion.YawOf(direction: Vector3): number
	return yawOf(direction)
end

function PetMotion.new(options: { Float: boolean?, Size: number?, Index: number?, Seed: number? }): State
	local seed = options.Seed or math.random() * 1000
	return {
		Float = options.Float == true,
		Size = math.clamp(options.Size or 2, 0.4, 6),
		Phase = hash(seed) * TAU,
		Index = options.Index or 1,
		Seed = seed,
		Position = nil,
		Velocity = Vector3.zero,
		Yaw = 0,
		YawRate = 0,
		Step = 0,
		Moving = 0,
		JumpY = 0,
		JumpVel = 0,
		JumpDelay = -1,
		Squash = 0,
		SquashVel = 0,
		IdleFor = 0,
		NextIdle = 2 + hash(seed + 1) * 4,
		Action = nil,
		ActionT = 0,
		WasOwnerUp = false,
	}
end

-- próxima brincadeira de quando o pet está parado
local IDLE_ACTIONS = { "hop", "look", "spin", "wiggle", "hop", "look" }
local ACTION_TIME = { hop = 0.75, look = 1.8, spin = 0.7, wiggle = 0.55, loop = 1.1 }

local function pickAction(state: State, now: number): string
	local roll = hash(state.Seed + math.floor(now * 3))
	if state.Float then
		return if roll < 0.35 then "loop" elseif roll < 0.7 then "look" else "wiggle"
	end
	return IDLE_ACTIONS[1 + math.floor(roll * #IDLE_ACTIONS) % #IDLE_ACTIONS]
end

function PetMotion.Step(state: State, dt: number, input: Input): Pose
	dt = math.clamp(dt, 0, 0.1)
	local size = state.Size
	local sizeFactor = math.clamp(size / 2, 0.5, 1.4)
	local now = input.Now

	-- 1) SEGUIR: a velocidade vai atrás do lugar dele (suave, igual em 30 ou 60 FPS)
	local target = Vector3.new(input.Target.X, 0, input.Target.Z)
	local position = state.Position
	local landed = false
	if not position or (position - target).Magnitude > TELEPORT then
		position = target -- dono teleportou: o pet vai junto
		state.Velocity = Vector3.zero
	end
	local toTarget = target - position
	local distance = toTarget.Magnitude
	local wanted = toTarget * 6
	if wanted.Magnitude > MAX_SPEED then
		wanted = wanted.Unit * MAX_SPEED
	end
	if distance < 0.15 then
		wanted = Vector3.zero
	end
	state.Velocity = state.Velocity:Lerp(wanted, 1 - math.exp(-dt * 9))
	position += state.Velocity * dt
	state.Position = position
	local speed = state.Velocity.Magnitude
	local movingGoal = math.clamp((speed - 1) / 6, 0, 1)
	state.Moving += (movingGoal - state.Moving) * (1 - math.exp(-dt * 8))
	local moving = state.Moving

	-- 2) VIRAR: andando olha para onde vai; parado olha para onde o dono olha
	local look = input.OwnerLook
	local wantedYaw = if speed > 1.5 then yawOf(state.Velocity) else yawOf(if look.Magnitude > 0.01 then look else Vector3.new(0, 0, -1))
	local turn = angleDelta(state.Yaw, wantedYaw) * (1 - math.exp(-dt * 9))
	state.Yaw += turn
	local yawRate = if dt > 0 then turn / dt else 0
	state.YawRate += (yawRate - state.YawRate) * (1 - math.exp(-dt * 10))

	-- 3) PULO JUNTO COM O DONO (cada pet com um pouquinho de atraso)
	local ownerUp = input.OwnerRising
	if ownerUp and not state.WasOwnerUp and state.JumpY <= 0.01 and state.JumpDelay < 0 then
		state.JumpDelay = 0.05 + 0.07 * (state.Index - 1)
	end
	state.WasOwnerUp = ownerUp
	if state.JumpDelay >= 0 then
		state.JumpDelay -= dt
		if state.JumpDelay < 0 then
			state.JumpVel = (if state.Float then 10 else 17) * math.sqrt(sizeFactor)
			state.Squash = 0.14 -- estica ao sair do chão
		end
	end
	if state.JumpY > 0 or state.JumpVel > 0 then
		state.JumpVel -= GRAVITY * dt
		state.JumpY += state.JumpVel * dt
		if state.JumpY <= 0 then
			state.JumpY = 0
			if state.JumpVel < -4 and not state.Float then
				state.Squash = -0.28 -- amassa ao cair
				landed = true
			end
			state.JumpVel = 0
		end
	end

	-- 4) BRINCADEIRAS QUANDO PARADO
	if moving < 0.1 and state.JumpY <= 0 then
		state.IdleFor += dt
	else
		state.IdleFor = 0
		if state.Action and state.Action ~= "look" then
			state.Action = nil
		end
	end
	if not state.Action and state.IdleFor > 1.2 and state.IdleFor >= state.NextIdle then
		state.Action = pickAction(state, now)
		state.ActionT = 0
		state.IdleFor = 0
		state.NextIdle = 3.5 + hash(state.Seed + now) * 5
	end
	local actionYaw, actionRoll, actionPitch, actionHop = 0, 0, 0, 0
	if state.Action then
		state.ActionT += dt
		local total = ACTION_TIME[state.Action] or 1
		local t = math.clamp(state.ActionT / total, 0, 1)
		if state.Action == "hop" then
			-- dois pulinhos de alegria
			local k = (t * 2) % 1
			actionHop = 4 * k * (1 - k) * 0.55 * sizeFactor
			if state.ActionT + dt >= total * 0.5 and state.ActionT < total * 0.5 then
				state.Squash = -0.18
			end
		elseif state.Action == "look" then
			actionYaw = math.sin(t * TAU) * math.rad(35) * (if hash(state.Seed + 7) > 0.5 then 1 else -1)
		elseif state.Action == "spin" then
			local e = t * t * (3 - 2 * t)
			actionYaw = e * TAU
			actionHop = 4 * t * (1 - t) * 0.35 * sizeFactor
		elseif state.Action == "wiggle" then
			actionRoll = math.sin(t * TAU * 3) * math.rad(12) * (1 - t)
		elseif state.Action == "loop" then
			-- voador dá uma cambalhota
			local e = t * t * (3 - 2 * t)
			actionPitch = -e * TAU
			actionHop = math.sin(t * math.pi) * 0.8 * sizeFactor
		end
		if t >= 1 then
			if state.Action == "hop" or state.Action == "spin" then
				state.Squash = -0.2
				landed = state.Action == "hop"
			end
			state.Action = nil
		end
	end

	-- 5) ANDAR: pulinhos no ritmo da velocidade (termina o pulo antes de parar)
	local hop, stepSquash, roll, pitch = 0, 0, 0, 0
	local breathe = 0
	if state.Float then
		local rate = 2.4 + moving * 1.6
		hop = 2.2 * sizeFactor + math.sin(now * rate + state.Phase) * 0.35 * sizeFactor
		pitch = -math.rad(16) * math.clamp(speed / 22, 0, 1)
		roll = math.sin(now * 1.3 + state.Phase) * math.rad(5) * (1 - moving)
		-- "bater asas": estica rapidinho
		breathe = math.sin(now * (if moving > 0.3 then 11 else 4) + state.Phase) * (0.02 + 0.035 * moving)
	else
		local stepRate = math.clamp(1.7 + speed * 0.13, 1.7, 4.4)
		local frac = state.Step % 1
		if moving > 0.05 or frac > 0.02 then
			local before = state.Step
			state.Step += dt * stepRate
			if math.floor(state.Step) > math.floor(before) then
				-- pisou
				if moving < 0.05 then
					state.Step = math.floor(state.Step) -- parou no chão
				end
				stepSquash = 0
				if speed > 6 then
					landed = true
				end
				state.Squash = math.min(state.Squash, -0.12 - 0.1 * moving)
			end
		end
		local t = state.Step % 1
		local amount = math.max(moving, if t > 0.02 then 0.35 else 0)
		hop = 4 * t * (1 - t) * math.clamp(0.28 + speed * 0.022, 0.28, 0.7) * sizeFactor * amount
		stepSquash = 4 * t * (1 - t) * 0.08 * amount -- estica no ar
		roll = math.sin(state.Step * math.pi) * math.rad(8) * moving -- balança de um lado pro outro
		pitch = -math.rad(11) * math.clamp(speed / 20, 0, 1) -- inclina pra frente correndo
		breathe = math.sin(now * 2.2 + state.Phase) * 0.035 * (1 - moving)
	end
	-- inclina nas curvas
	roll += math.clamp(state.YawRate * (if state.Float then 0.1 else 0.05), -0.35, 0.35)

	-- 6) MOLA DO AMASSA/ESTICA (balança um pouco e volta ao normal)
	state.SquashVel += (-state.Squash * 260 - state.SquashVel * 14) * dt
	state.Squash += state.SquashVel * dt
	state.Squash = math.clamp(state.Squash, -0.4, 0.4)

	local sy = math.clamp(1 + state.Squash + stepSquash + breathe, 0.6, 1.4)
	local sxz = 1 / math.sqrt(sy)

	local y = input.GroundY + hop + state.JumpY + actionHop
	-- gira em volta de um ponto do corpo (perto dos pés andando, no meio voando/dando cambalhota)
	local pivotY = size * (if state.Float or state.Action == "loop" then 0.5 else 0.3)
	local feet = CFrame.new(position.X, y + pivotY, position.Z)
		* CFrame.Angles(0, state.Yaw + actionYaw, 0)
		* CFrame.Angles(pitch + actionPitch, 0, 0)
		* CFrame.Angles(0, 0, roll + actionRoll)
		* CFrame.new(0, -pivotY, 0)
	return {
		CFrame = feet,
		Scale = Vector3.new(sxz, sy, sxz),
		Landed = landed,
		Speed = speed,
	}
end

return PetMotion
