--[[
	Config (ModuleScript-pasta em ReplicatedStorage > Shared)     dono: foundation
	TODOS os números do jogo ficam aqui, separados por área. Cada arquivo filho vira um "espaço":
	  Config.Game, Config.Shift, Config.Power, Config.Facility, Config.Build, Config.Hub,
	  Config.Scrap, Config.Kit, Config.Noise, Config.Monsters, Config.Economy, Config.Progression,
	  Config.Titles, Config.Products, Config.Retention, Config.Leaderboards, Config.Analytics,
	  Config.Social, Config.Pings, Config.Settings, Config.Lighting, Config.Audio, Config.Future
	Cada grupo de implementação é dono dos seus arquivos (veja docs/CONTRACTS.md).
	Regras:
	  • Só dados (e no máximo funções pequenas e puras). Fórmulas ficam em Shared/Formulas.
	  • ATENÇÃO: o cliente consegue ler tudo que está aqui. Nada secreto (códigos ficam no servidor).
	  • Um arquivo com erro não derruba os outros: vira uma tabela vazia com aviso.
]]

local Config = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, result = pcall(require, child)
		if ok and type(result) == "table" then
			Config[child.Name] = result
		else
			warn("[Config] falha ao carregar " .. child.Name .. ": " .. tostring(result))
			Config[child.Name] = {}
		end
	end
end

return Config
