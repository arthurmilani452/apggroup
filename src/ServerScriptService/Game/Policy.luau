--[[
	Policy (ModuleScript em ServerScriptService > Game)
	v17: respeita as regras de cada país do Roblox (PolicyService), exigidas no questionário de maturidade.
	  • ArePaidRandomItemsRestricted = true  -> não vende Cash Packs (Robux -> dinheiro -> ovos aleatórios)
	                                          e troca os OVOS do Season Pass pago por dinheiro fixo
	  • IsPaidItemTradingAllowed = false     -> presentes (dar bichinhos) ficam desligados
	  • IsContentSharingAllowed = false      -> o botão de foto não abre "compartilhar" (só salva na galeria)
	O resultado vira atributo do jogador (a tela esconde os botões):
	  PolicyRandomRestricted, PolicyTradingAllowed, PolicyShareAllowed, PolicyReady
	Se o Roblox não responder, o jogo fica no modo MAIS SEGURO (tudo restrito) e tenta de novo.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Seasons = require(ReplicatedStorage.Shared.Seasons)

local Policy = {}

export type Info = { RandomRestricted: boolean, TradingAllowed: boolean, ShareAllowed: boolean, Ready: boolean }

local SAFE: Info = { RandomRestricted = true, TradingAllowed = false, ShareAllowed = false, Ready = false }
local STUDIO: Info = { RandomRestricted = false, TradingAllowed = true, ShareAllowed = true, Ready = true }

local cache: { [Player]: Info } = {}

-- permite trocar o PolicyService nos testes
Policy.Fetch = function(player: Player): any
	return PolicyService:GetPolicyInfoForPlayerAsync(player)
end

local function apply(player: Player, info: Info)
	cache[player] = info
	if player.Parent then
		player:SetAttribute("PolicyRandomRestricted", info.RandomRestricted)
		player:SetAttribute("PolicyTradingAllowed", info.TradingAllowed)
		player:SetAttribute("PolicyShareAllowed", info.ShareAllowed)
		player:SetAttribute("PolicyReady", info.Ready)
	end
end

-- Converte a resposta do Roblox (campos que faltarem = modo seguro)
function Policy.FromResult(result: any): Info
	if type(result) ~= "table" then
		return table.clone(SAFE)
	end
	return {
		RandomRestricted = result.ArePaidRandomItemsRestricted ~= false,
		TradingAllowed = result.IsPaidItemTradingAllowed == true,
		ShareAllowed = result.IsContentSharingAllowed == true,
		Ready = true,
	}
end

function Policy.Load(player: Player)
	apply(player, table.clone(SAFE))
	if RunService:IsStudio() then
		-- no Studio o PolicyService não responde de verdade: libera tudo para testar
		apply(player, table.clone(STUDIO))
		return
	end
	for attempt = 1, 4 do
		local ok, result = pcall(Policy.Fetch, player)
		if not player.Parent then
			return
		end
		if ok and type(result) == "table" then
			apply(player, Policy.FromResult(result))
			return
		end
		task.wait(2 * attempt)
	end
	warn("[Policy] no answer for", player.Name, "- keeping the safe mode")
end

function Policy.Get(player: Player): Info
	return cache[player] or SAFE
end

-- Pode vender coisas que viram itens aleatórios (Cash Packs)?
function Policy.CanBuyRandom(player: Player): boolean
	return not Policy.Get(player).RandomRestricted
end

-- Pode dar/receber bichinhos (que podem ter sido comprados com Robux)?
function Policy.CanTrade(player: Player): boolean
	return Policy.Get(player).TradingAllowed
end

-- Recompensa PAGA (Season Pass): onde itens aleatórios pagos são proibidos, os ovos viram dinheiro fixo
function Policy.SafePaidReward(player: Player, reward: any): any
	if Policy.CanBuyRandom(player) then
		return reward
	end
	return Seasons.NoRandom(reward)
end

-- Para testes
function Policy.Set(player: Player, info: Info)
	apply(player, info)
end

function Policy.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(Policy.Load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(Policy.Load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

return Policy
