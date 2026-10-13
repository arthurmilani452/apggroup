--!nonstrict
-- Liga tudo na ordem certa (o mapa é montado por código dentro do Game.Init)
local Game = script.Parent:WaitForChild("Game")
local Data = require(Game:WaitForChild("Data"))
local GameModule = require(Game:WaitForChild("Game"))

-- modelos 3D importados que ficaram soltos no Workspace vão para ReplicatedStorage > Models3D
pcall(function()
	require(game:GetService("ReplicatedStorage").Shared.Models3D).CollectFromWorkspace()
end)

-- câmera: começa afastada (vê o ovo nas costas e o guardião atrás)
local StarterPlayer = game:GetService("StarterPlayer")
StarterPlayer.CameraMinZoomDistance = 9
StarterPlayer.CameraMaxZoomDistance = 60
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CameraMinZoomDistance = 9
	player.CameraMaxZoomDistance = 60
end)

Data.Init()
GameModule.Init()
print("[EggRun] server ready")
