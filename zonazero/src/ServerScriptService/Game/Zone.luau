--[[
	Zone: a tempestade que fecha (Config.Zone.Phases). Quem fica fora toma dano por segundo.
	Os números ficam em atributos do Workspace; cada tela desenha a parede da zona sozinha (ZoneMath).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ZoneMath = require(ReplicatedStorage.Shared.ZoneMath)
local Registry = require(script.Parent.Registry)

local Zone = {}

local rng = Random.new()
local runId = 0
local damagePerSecond = 0

local function set(cx, cz, r, ncx, ncz, nr, shrinkStart, shrinkEnd, stage)
	workspace:SetAttribute("ZoneCX", cx)
	workspace:SetAttribute("ZoneCZ", cz)
	workspace:SetAttribute("ZoneR", r)
	workspace:SetAttribute("ZoneNCX", ncx)
	workspace:SetAttribute("ZoneNCZ", ncz)
	workspace:SetAttribute("ZoneNR", nr)
	workspace:SetAttribute("ZoneShrinkStart", shrinkStart)
	workspace:SetAttribute("ZoneShrinkEnd", shrinkEnd)
	workspace:SetAttribute("ZoneStage", stage)
end

function Zone.Stop()
	runId += 1
	damagePerSecond = 0
	set(0, 0, Config.Zone.StartRadius, 0, 0, Config.Zone.StartRadius, 0, 0, 0)
	workspace:SetAttribute("ZonePhaseEnds", 0)
end

-- Começa a sequência de fases (roda até a partida acabar)
function Zone.Start(center: Vector3)
	runId += 1
	local myRun = runId
	local cx, cz, r = center.X, center.Z, Config.Zone.StartRadius
	set(cx, cz, r, cx, cz, r, 0, 0, 1)
	task.spawn(function()
		for index, phase in Config.Zone.Phases do
			if runId ~= myRun then
				return
			end
			-- escolhe o próximo círculo inteiro dentro do atual
			local maxOffset = math.max(0, r - phase.Radius)
			local angle = rng:NextNumber() * math.pi * 2
			local dist = math.sqrt(rng:NextNumber()) * maxOffset
			local ncx, ncz = cx + math.cos(angle) * dist, cz + math.sin(angle) * dist
			local now = workspace:GetServerTimeNow()
			local shrinkStart = now + phase.Wait
			local shrinkEnd = shrinkStart + phase.Shrink
			set(cx, cz, r, ncx, ncz, phase.Radius, shrinkStart, shrinkEnd, index)
			workspace:SetAttribute("ZonePhaseEnds", shrinkStart)
			damagePerSecond = if index == 1 then 1 else Config.Zone.Phases[index - 1].Damage
			task.wait(phase.Wait)
			if runId ~= myRun then
				return
			end
			workspace:SetAttribute("ZonePhaseEnds", shrinkEnd)
			damagePerSecond = phase.Damage
			task.wait(phase.Shrink)
			if runId ~= myRun then
				return
			end
			cx, cz, r = ncx, ncz, phase.Radius
		end
		-- última zona: fica parada e o dano continua
		set(cx, cz, r, cx, cz, r, 0, 0, #Config.Zone.Phases + 1)
		workspace:SetAttribute("ZonePhaseEnds", 0)
	end)
end

function Zone.Init()
	Zone.Stop()
	-- dano de quem está fora, 1 vez por segundo (ignora escudo)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				if (workspace:GetAttribute("ZoneStage") or 0) <= 0 or damagePerSecond <= 0 then
					return
				end
				for _, entry in Registry.Match.AliveEntries() do
					local root = entry.Model and entry.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and not ZoneMath.IsInside(root.Position) then
						entry.LastZoneDamage = os.clock()
						Registry.Combat.Damage(entry, damagePerSecond, nil, true)
					end
				end
			end)
			if not ok then
				warn("[Zone] erro:", err)
			end
		end
	end)
end

return Zone
