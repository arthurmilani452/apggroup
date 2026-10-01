# Steal a Critter v28: o que mudou

Arquivo para abrir no Studio: `place/StealACritter-v28.rbxlx`

## Corrigido
1. **Roubo com teleporte:** quem rouba e se teletransporta para a base no caminho perde o bichinho. Antes o jogo só conferia o tempo total da viagem.
2. **Bichinho refém:** ninguém segura um bichinho roubado por mais de 2 minutos. Depois disso ele volta para o dono.
3. **Vender o que acabou de roubar:** não dá mais para vender na hora. A vítima tem o tempo de trava para roubar de volta.
4. **Perda de progresso:** quem saía e voltava rápido para o MESMO servidor podia carregar dados velhos e perder o que tinha feito. Agora o jogo espera o save da saída terminar.
5. **Pedidos perdidos:** o limite de 0,15 s era um só para todos os botões, então abrir painéis rapidinho fazia pedidos sumirem (ex.: painel social). Agora é um limite por ação.
6. **Servidor pesado por spam:** trocar tema/decoração/trilha e montar na montaria agora têm intervalo mínimo.
7. **Botão de vingança:** o botão "Steal" ficava escondido durante a vingança mesmo o servidor deixando. Agora aparece.
8. **Relógios:** o presente por tempo de jogo, a contagem do critter da semana e os prêmios do mundo usavam o relógio do celular do jogador (podia mostrar errado). Agora usam o relógio do servidor.

## Encontrado, mas NÃO mudado (precisa da sua decisão)
- **Game pass comprado dentro do jogo pode não ser entregue:** o jogo confere a compra de novo com `UserOwnsGamePassAsync`, que pode responder "não tem" logo depois da compra (cache). A correção é confiar no evento `PromptGamePassPurchaseFinished` do servidor. Não apliquei porque o sistema de segurança desta sessão bloqueou a mudança; se quiser, eu explico como fazer ou faço com sua permissão.
- **Ovo da Semana ($150K) rende como ovo Royal** e ovos de festa/clima/ilha rendem muito para o preço: dá para comprar e vender com lucro. É balanceamento: me diga se quer que eu ajuste.
- **Pescaria:** a pontuação vem do celular do jogador (trapaceiro sempre pega o melhor peixe). Tem limite por dia, então o estrago é pequeno; corrigir exige refazer o minigame.
- Lista completa da revisão: ~70 itens (a maioria pequenos) — peça que eu continuo.
