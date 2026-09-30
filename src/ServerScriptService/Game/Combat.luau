-- Taco "Bonk Bat": empurra os outros jogadores e faz ladrões derrubarem o bichinho.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)

local Combat = {}

local lastSwing: { [Player]: number } = {}

local REST_GRIP = CFrame.new(0, -1.4, 0)
local SWING_GRIP = CFrame.new(0, -1.4, 0) * CFrame.Angles(math.rad(80), 0, 0)

local function makeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bonk Bat"
	tool.ToolTip = "Click to BONK thieves!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = REST_GRIP

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 3, 0.45)
	handle.Color = Color3.fromRGB(150, 100, 60)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(2.2, 0.95, 0.95)
	barrel.Color = Color3.fromRGB(255, 120, 60)
	barrel.Material = Enum.Material.SmoothPlastic
	barrel.CanCollide = false
	barrel.Massless = true
	barrel.CFrame = handle.CFrame * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	barrel.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = barrel
	weld.Parent = barrel

	local sound = Instance.new("Sound")
	sound.Name = "Swing"
	sound.SoundId = Config.Sounds.Swing.Id
	sound.Volume = Config.Sounds.Swing.Volume
	sound.SoundGroup = game:GetService("SoundService"):FindFirstChild("SFX") :: SoundGroup?
	sound.Parent = handle

	return tool
end

local function inOwnBase(player: Player, position: Vector3): boolean
	local plot = Registry.Plots.Get(player)
	return plot ~= nil and Registry.Plots.IsInside(plot, position)
end

-- Monstros da invasão (LiveEvents) e Bandits (v24): mesmo alcance do taco
local function hitTagged(player: Player, root: BasePart, tag: string, handler: ((Model, Player) -> ())?): boolean
	if not handler then
		return false
	end
	for _, target in CollectionService:GetTagged(tag) do
		local targetRoot = target:IsA("Model") and target.PrimaryPart
		if targetRoot then
			local offset = targetRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local direction = if flat.Magnitude > 0.05 then flat.Unit else root.CFrame.LookVector
			if offset.Magnitude <= Config.SlapRange + 2.5 and (root.CFrame.LookVector:Dot(direction) > 0.1 or offset.Magnitude < 4) then
				handler(target :: Model, player)
				return true -- uma pancada acerta um alvo só
			end
		end
	end
	return false
end

local function hitMonsters(player: Player, root: BasePart)
	local liveEvents = Registry.LiveEvents
	if hitTagged(player, root, "Monster", liveEvents and liveEvents.HitMonster) then
		return
	end
	local banditService = Registry.Bandits
	hitTagged(player, root, "Bandit", banditService and banditService.Hit)
end

local function swing(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < Config.SlapCooldown then
		return
	end
	lastSwing[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	tool.Grip = SWING_GRIP
	task.delay(0.18, function()
		if tool.Parent then
			tool.Grip = REST_GRIP
		end
	end)
	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("Swing") :: Sound?
	if sound then
		sound:Play()
	end

	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherCharacter = other.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
			local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
			if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= Config.SlapRange then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local direction = if flat.Magnitude > 0.05 then flat.Unit else root.CFrame.LookVector
					local facing = root.CFrame.LookVector:Dot(direction)
					-- Quem está dentro da PRÓPRIA base fica protegido (anti-trollagem)
					local protected = inOwnBase(other, otherRoot.Position)
					local minigames = Registry.Minigames
					if minigames and not minigames.BonkAllowed(player, other) then
						protected = true -- minigame: só vale pancada que faz parte do jogo
					end
					if (facing > 0.1 or distance < 3.5) and not protected then
						Registry.Remotes.KnockbackEvent:FireClient(other, direction * Config.SlapForce + Vector3.new(0, 40, 0))
						Registry.Remotes.EffectAll("Bonk", otherRoot.Position + Vector3.new(0, 3, 0))
						Registry.CritterService.OnSlapped(other, player)
						if minigames then
							minigames.OnBonk(player, other)
						end
					end
				end
			end
		end
	end
	hitMonsters(player, root)
end

function Combat.GiveTool(player: Player, character: Model)
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	if player.Character ~= character then
		return
	end
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack or not character.Parent then
		return
	end
	if backpack:FindFirstChild("Bonk Bat") or character:FindFirstChild("Bonk Bat") then
		return
	end
	local tool = makeTool()
	tool.Activated:Connect(function()
		swing(player, tool)
	end)
	tool.Parent = backpack
end

function Combat.RemovePlayer(player: Player)
	lastSwing[player] = nil
end

function Combat.Init() end

return Combat
