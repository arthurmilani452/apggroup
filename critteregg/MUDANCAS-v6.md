# Steal a Critter Egg - v6 (13/10/2026)

Backup dos scripts antigos: pasta `backup-src-antes-v6`.

## O que mudou
- PLACAS: preço do Upgrade Pen / Upgrade Treadmill, tela da esteira, placa do título e placas de velocidade das zonas voltaram a aparecer (o texto estava sendo empurrado para fora da placa).
- Placa flutuante grande em cada zona: "NEED 900 SPEED" (verde se você já tem, vermelho se não).
- ESTEIRA: não arremessa mais. Correndo para frente em cima da sua esteira você corre no lugar; andando para o lado/trás você sai.
- CHOCAR: o ovo treme, racha, brilha e explode em pedaços na base (todo mundo vê); o bichinho pula para fora girando. Depois aparece o card.
- BICHOS RAROS MAIORES: Common 3 -> Divine 10.2 de tamanho. Raro+ ganha pedestal brilhante na cor da raridade; Lendário+ ganha coluna de luz e fica no pedestal.
- TACO: modelo novo (cabo com fita, corpo redondo, faixa colorida), rastro no golpe, estrelinhas no acerto e aviso "BONK!".
- MAPA: modelos do Toolbox que ficavam deitados/boiando (pilares, cristais, esqueletos) agora ficam em pé.
- BAÚ GRÁTIS: só abre para quem está na comunidade (grupo). Quem não está recebe o convite oficial da Roblox; entrou = abre na hora. Depois de abrir, pede um like (sem prêmio pelo like: a Roblox não permite).
- FUNIL: Creator Hub > Analytics > Funnels > Onboarding mostra em qual passo as crianças desistem.

## Como colocar no jogo
1. Abra o CritterEggRun-v5.rbxl no Studio (ou a versão publicada mais nova).
2. Dê dois cliques em INICIAR-ROJO.bat e no Studio: Plugins > Rojo > Connect.
3. BAÚ BONITO DO TOOLBOX: na barra de comandos (View > Command Bar) cole e aperte Enter:

local m = game:GetObjects("rbxassetid://18473723806")[1]; local f = game.ServerStorage:FindFirstChild("ToolboxAssets") or Instance.new("Folder", game.ServerStorage); f.Name = "ToolboxAssets"; if not m:IsA("Model") then local w = Instance.new("Model"); m.Parent = w; m = w end; m.Name = "Chest"; m.Parent = f; print("Chest OK")

4. Aperte Play e teste: placas, esteira, chocar um ovo, taco, baú.
5. File > Publish to Roblox.
6. O baú usa o grupo Critter Club Studios (Config.CommunityId = 869887016). Para usar outro grupo, troque esse número.

## v6.1 - primeiros minutos, presentes, ofertas
- Cercado nível 1 (libera a esteira) agora custa $250 (era $1K).
- O PRIMEIRO ovo roubado choca em 5 segundos.
- Dica nova: quando descobre bicho novo, manda abrir o INDEX e pegar o dinheiro grátis.
- Botão GIFTS (direita, rosa): 8 presentes por tempo jogado (1, 3, 6, 10, 15, 20, 30 e 45 min); o último dá um ovo Raro+.
- Contador do evento da sorte sempre na tela ("Lucky in 12m" / "LUCKY x3!").
- Chuva de moedas ao roubar e ao vender; "+$" voando ao vender.
- Ofertas na hora certa (Starter Pack depois do 1º chocar, Grow All quando o ovo demora, velocidade quando o guardião pega). Só aparecem quando o item tiver Id no Config.
- Funil e tudo da v6 continuam.

## Robux: AINDA NÃO ESTÁ VENDENDO
Os Ids em Config.Passes / Config.Products estão 0. No Creator Hub já existem itens do jogo antigo que podem ser usados.
