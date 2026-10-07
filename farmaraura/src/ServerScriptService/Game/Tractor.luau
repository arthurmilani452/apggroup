--[[
	Tractor: o trator da granja (botão G_tractor). Dá para sentar e dirigir.
	Feito para ser simples e difícil de quebrar: o trator é um bloco só (tudo soldado no chassi),
	apoiado em 4 esferas invisíveis sem atrito. Quem empurra é um LinearVelocity (a velocidade que o
	trator deve ter, no plano do chão) e quem gira é um AngularVelocity. O servidor lê o acelerador e a
	direção do VehicleSeat e aponta a velocidade para a frente do trator.
	O jogador sentado continua comprando e pegando moedas e ovos raros: o Farm olha a posição do personagem.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLib = require(ReplicatedStorage.Shared.AssetLib)
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Registry = require(script.Parent.Registry)

local Tractor = {}

type Rig = { Model: Model, Chassis: BasePart, Seat: VehicleSeat, Move: LinearVelocity, Turn: AngularVelocity }

local rigs: { [any]: Rig } = {} -- [plot] = rig
local folder: Folder

local function homeCFrame(plot: any): CFrame
	local s = Layout.TractorSpawn
	return Registry.Plots.CF(plot, s[1], s[2], s[3], 0.4)
end

local function build(plot: any): Rig?
	local model = AssetLib.Get("Trator")
	if not model then
		return nil
	end
	local home = homeCFrame(plot)
	model.Name = "Trator"
	model:PivotTo(home)
	model:SetAttribute("PlotIndex", plot.Index)

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(4, 1, 8)
	chassis.Transparency = 1
	chassis.CanCollide = false
	chassis.CanTouch = false
	chassis.CanQuery = false
	chassis.CFrame = home * CFrame.new(0, 2.2, 0)
	chassis.CustomPhysicalProperties = PhysicalProperties.new(3, 0, 0, 100, 100)
	chassis.Parent = model

	local function weld(part: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = chassis
		w.Part1 = part
		w.Parent = part
	end

	-- 4 apoios redondos sem atrito (passam por degraus pequenos sem travar)
	for _, offset in { Vector3.new(-2.2, 1.3, -3.4), Vector3.new(2.2, 1.3, -3.4), Vector3.new(-2.2, 1.3, 2.8), Vector3.new(2.2, 1.3, 2.8) } do
		local ball = Instance.new("Part")
		ball.Name = "Apoio"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(2.6, 2.6, 2.6)
		ball.Transparency = 1
		ball.CanTouch = false
		ball.CanQuery = false
		ball.CFrame = home * CFrame.new(offset)
		ball.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
		ball.Parent = model
		weld(ball)
	end

	local seatMark = AssetLib.Find(model, "Assento")
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Banco"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.CFrame = if seatMark then seatMark.CFrame * CFrame.new(0, 0.35, 0) else home * CFrame.new(0, 3.3, 2.4)
	seat.Parent = model

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= chassis and d.Name ~= "Apoio" then
			d.CanCollide = false
			d.CanTouch = d == seat
			d.Massless = true
			weld(d)
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end

	local attachment = Instance.new("Attachment")
	attachment.Parent = chassis
	local move = Instance.new("LinearVelocity")
	move.Attachment0 = attachment
	move.RelativeTo = Enum.ActuatorRelativeTo.World
	move.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	move.VectorVelocity = Vector3.new(0, 0, 0)
	-- força só no plano do chão: a gravidade continua cuidando do sobe-e-desce
	move.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	move.MaxAxesForce = Vector3.new(60000, 0, 60000)
	move.Parent = chassis
	local turn = Instance.new("AngularVelocity")
	turn.Attachment0 = attachment
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.AngularVelocity = Vector3.new(0, 0, 0)
	turn.MaxTorque = 2000000
	turn.Parent = chassis

	model.PrimaryPart = chassis
	model.Parent = folder
	return { Model = model, Chassis = chassis, Seat = seat, Move = move, Turn = turn }
end

local function destroy(plot: any)
	local rig = rigs[plot]
	if rig then
		rigs[plot] = nil
		rig.Model:Destroy()
	end
end

-- Cria ou apaga o trator conforme o dono tem (ou não) o botão comprado
function Tractor.Ensure(plot: any)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local owned = data ~= nil and data.Owned.G_tractor == true
	if owned and not rigs[plot] then
		local ok, rig = pcall(build, plot)
		if ok and rig then
			rigs[plot] = rig
		elseif not ok then
			warn("[Tractor] não deu para montar:", rig)
		end
	elseif not owned and rigs[plot] then
		destroy(plot)
	end
end

-- Leva o trator de volta para a garagem (se ninguém estiver dirigindo)
function Tractor.Home(plot: any): boolean
	local rig = rigs[plot]
	if not rig or rig.Seat.Occupant then
		return false
	end
	rig.Chassis.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	rig.Chassis.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	rig.Model:PivotTo(homeCFrame(plot) * CFrame.new(0, 2.2, 0))
	return true
end

local function step(plot: any, rig: Rig)
	local seat = rig.Seat
	local throttle, steer = 0, 0
	if seat.Occupant then
		throttle, steer = seat.Throttle, seat.Steer
	end
	local look = rig.Chassis.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	rig.Move.VectorVelocity = look * (throttle * Config.Tractor.Speed * (if throttle < 0 then 0.5 else 1))
	local direction = if throttle < 0 then -1 else 1
	rig.Turn.AngularVelocity = Vector3.new(0, -steer * Config.Tractor.Turn * direction, 0)
	-- caiu do mundo ou capotou longe: volta para a garagem
	local position = rig.Chassis.CFrame.Position
	if position.Y < -40 or position.Y > 400 then
		rig.Chassis.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rig.Model:PivotTo(homeCFrame(plot) * CFrame.new(0, 2.2, 0))
	end
end

function Tractor.Init()
	folder = Instance.new("Folder")
	folder.Name = "Vehicles"
	folder.Parent = workspace

	Registry.Remotes.On("TractorHome", function(player: Player)
		local plot = Registry.Plots.Of(player)
		if plot and rigs[plot] then
			if Tractor.Home(plot) then
				Registry.Remotes.NotifyPlayer(player, "n.tractorHome", nil, "success")
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.05)
			for plot, rig in rigs do
				if not rig.Model.Parent then
					rigs[plot] = nil
				else
					local ok, err = pcall(step, plot, rig)
					if not ok then
						warn("[Tractor]", err)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local plot = Registry.Plots.Of(player)
		if plot then
			destroy(plot)
		end
	end)
end

return Tractor
