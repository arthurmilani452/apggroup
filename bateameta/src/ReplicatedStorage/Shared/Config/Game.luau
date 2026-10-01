-- Config.Game: dados gerais, save e limites de rede.              dono: foundation
return {
	-- Nome do DataStore. NUNCA mudar depois de lançar (todo mundo perderia o progresso).
	DataStoreName = "BateAMeta_Data_v1",
	DataVersion = 1,
	SessionLockSeconds = 150, -- trava de sessão mais velha que isso = servidor antigo caiu
	MaxReceipts = 100, -- recibos de compra guardados (para nunca entregar duas vezes)
	SaveIntervalSeconds = 60, -- save automático
	SyncDebounceSeconds = 0.25, -- junta várias mudanças do perfil num único ProfileSync

	MaxPlayers = 4, -- uma equipe por servidor (o limite real é configurado no Creator Hub)

	-- UserIds de admin além do dono do jogo (jogo de grupo: coloque aqui)
	Admins = {
		-- [123456] = true,
	},

	-- Fuso de Brasília (BRT, UTC-3): o "dia" do jogo vira às 00:00 BRT
	DayOffsetHours = -3,

	-- Limites do despachante de ações (Remotes.OnAction). Cada ação pode ter o seu (Rate/Burst).
	RateLimits = {
		GlobalPerSecond = 30, -- todas as ações somadas de um jogador
		DefaultRate = 4, -- fichas por segundo
		DefaultBurst = 6, -- fichas acumuladas no máximo
		LookPerSecond = 8, -- relatórios de olhar (UnreliableRemoteEvent "Look")
		MaxStringLength = 64, -- texto maior que isso é recusado (a não ser que a ação diga outro limite)
	},

	-- Mensagens de expulsão (o Roblox mostra antes do cliente carregar): chaves de Strings,
	-- traduzidas no servidor pelo LocaleId do jogador com Locale.ForPlayer.
	KickLoadFailedKey = "COMMON_KICK_LOAD_FAILED",
	KickOtherServerKey = "COMMON_KICK_OTHER_SERVER",
}
