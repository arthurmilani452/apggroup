--[[
	ClientMain (LocalScript em StarterPlayerScripts)          Prefeito Tycoon
	Liga a interface. Cada parte começa num pcall: se uma quebrar, o resto continua.
]]

local Scripts = script.Parent

for _, name in { "HUD", "BuildMode", "CityPanel", "Travel", "Citizens", "Tutorial", "Ambience" } do
	local module = Scripts:WaitForChild(name, 10)
	if module then
		local ok, err = pcall(function()
			require(module :: any).Init()
		end)
		if not ok then
			warn("[Cliente] " .. name .. " não iniciou:", err)
		end
	end
end
