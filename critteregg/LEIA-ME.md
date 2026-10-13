# Steal a Critter Egg (jogo novo, estilo "roubar ovos das zonas")

Mecânica inspirada no Steal an Egg; nomes, criaturas, textos e visual são do Steal a Critter.

- `src/shared/Config.luau` — TODOS os números (zonas, velocidades, preços, tempos, sons, Robux, diário, rebirth)
- `src/server/Game/World.luau` — monta o mapa inteiro por código (hub com 7 bases, lojinhas, linha SAFE, 12 zonas com portais)
- `src/server/Game/Game.luau` — ninhos, roubo, guardiões, cercado, chocar, vender, esteira, noite/dia,
  taco e armadilhas (PvP), ovos soltos, Robux, prêmio diário, rebirth, evento da sorte, ganho offline, bônus de amigos
- `src/server/Game/Data.luau` — salvar/carregar (DataStore)
- `src/client/Client.client.luau` — HUD, lojas, Index, diário, animação de chocar, sons, tutorial, seta

O arquivo .rbxl já vem com os modelos 3D dos bichinhos (ReplicatedStorage > Models3D).
Para salvar no Studio: Game Settings > Security > Enable Studio Access to API Services.

## Editar no VS Code com o jogo aberto no Studio (Rojo)
1. Abra esta pasta no VS Code.
2. Dê dois cliques em `INICIAR-ROJO.bat` (deixe a janela preta aberta).
3. No Roblox Studio, abra o .rbxl e vá em **Plugins > Rojo > Connect**.
4. Tudo que você salvar no VS Code aparece na hora no Studio. Aperte Play para testar.

## Ligar os produtos de Robux
1. Publique o jogo. No Creator Hub > seu jogo > Monetization:
   - **Passes**: crie "X2 MONEY!", "X2 GROWTH SPEED!" e "VIP".
   - **Developer Products**: crie "+10K Speed", "+150K Speed", "+2M Speed", "+50M Speed", "Grow All Eggs", "Cash Pack" e "Lucky Egg".
2. Copie o número (ID) de cada um e cole em `Config.Passes` / `Config.Products` no campo `Id = 0`.
3. Enquanto o Id for 0, o botão aparece na loja mas avisa que ainda não foi configurado.

## Sons
Os sons são áudios oficiais da Roblox (públicos). Para trocar algum, mude o número em `Config.Sounds`.

## Testar PvP sozinho no Studio
Durante o Play, na aba **Server**, a barra de comandos pode usar `game.ServerStorage.EggDebug`:
- `game.ServerStorage.EggDebug:Invoke("Stun", game.Players:GetPlayers()[1], 1.5, Vector3.new(0, 30, -40))` — simula levar uma tacada
- `game.ServerStorage.EggDebug:Invoke("Trap", posição)` — coloca uma armadilha
- `game.ServerStorage.EggDebug:Invoke("Money", jogador, 1e6)` — dá dinheiro para testar
(isso só existe no Studio; no jogo publicado não aparece)
