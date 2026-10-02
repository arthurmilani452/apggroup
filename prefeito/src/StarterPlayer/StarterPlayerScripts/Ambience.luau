--[[
	Ambience (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	Clima da cidade: música baixinha e as pás das usinas eólicas girando (só perto da câmera).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Ambience = {}

local SPIN = 1.2 -- radianos por segundo
local VIEW = 400

function Ambience.Init()
	if #Config.Music > 0 then
		local music = Instance.new("Sound")
		music.Name = "Music"
		music.SoundId = Config.Music[1]
		music.Volume = Config.MusicVolume
		music.Looped = true
		music.Parent = SoundService
		music:Play()
	end

	local turbines: { Model } = {}
	local function scan()
		table.clear(turbines)
		local lots = workspace:FindFirstChild("Lots")
		if not lots then
			return
		end
		for _, lot in lots:GetChildren() do
			local folder = lot:FindFirstChild("Buildings")
			if folder then
				for _, model in folder:GetChildren() do
					if model:GetAttribute("Id") == "eolica" then
						table.insert(turbines, model :: Model)
					end
				end
			end
		end
	end
	task.spawn(function()
		while true do
			pcall(scan)
			task.wait(3)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		for _, model in turbines do
			local rotor = model.Parent and model:FindFirstChild("Rotor") :: BasePart?
			if rotor and (rotor.Position - camera.CFrame.Position).Magnitude < VIEW then
				local axis = rotor.CFrame.LookVector
				local spin = CFrame.fromAxisAngle(axis, SPIN * dt)
				local center = rotor.Position
				for _, blade in model:GetChildren() do
					if blade.Name == "Blade" and blade:IsA("BasePart") then
						local relative = blade.CFrame - center
						blade.CFrame = (spin * relative) + center
					end
				end
			end
		end
	end)
end

return Ambience
