# Steal a Critter Egg: plano de melhorias (13/10/2026)

Este plano junta 3 fontes:

1. **Os seus documentos:** MUDANCAS-v6 e LEIA-ME.
2. **Os erros que já achamos nos seus outros jogos:** Steal a Critter v28 e Venda um Ovo v6. Muitos se repetem em jogos do mesmo tipo.
3. **Pesquisa na internet** sobre o Steal an Egg e sobre as regras da Roblox. Todos os pontos foram conferidos duas vezes.

O código do jogo (pasta `src`) não veio junto. Por isso, onde está escrito "conferir no código", é algo que ainda precisa ser checado.

---

## 1. URGENTE: antes de ligar os Robux e antes de crescer

| # | O que fazer | Por quê |
|---|---|---|
| 1 | **Criar os passes e produtos NESTE jogo** (Creator Hub > seu jogo > Monetization) e colar os números em `Config.Passes` / `Config.Products`. | O MUDANCAS-v6 diz que dá para usar os itens do jogo antigo. **Não dá mais:** desde 30/05/2026 a Roblox desligou a venda de passe ou produto de um jogo dentro de outro jogo. Hoje o jogo não vende nada. A Roblox também usa as compras para decidir quais jogos mostrar na página inicial. |
| 2 | **"Lucky Egg" (ovo pago com bicho sorteado):** trocar por um ovo com raridade garantida ("Ovo Raro garantido"). | A Roblox exige mostrar a chance de cada raridade antes da compra e usar o `PolicyService`. **No Brasil (ECA Digital, desde 17/03/2026), menor de 18 anos não pode comprar item pago com prêmio sorteado.** Um jogo que tem item sorteado pago e não usa o `PolicyService` deixa de abrir para menores de 18 no Brasil. |
| 3 | **Conferir os caminhos indiretos de sorteio pago:** Cash Pack (Robux vira dinheiro, dinheiro compra ovo sorteado), Grow All, passes de sorte. | Também contam como "item sorteado pago" para a Roblox. O Steal a Critter v28 já resolve isso no `Policy.luau`: desliga o Cash Pack para quem não pode. |
| 4 | **Entrega de compra à prova de falha:** só confirmar a compra para a Roblox **depois** de salvar. Guardar o número da compra para nunca entregar duas vezes. Passes: entregar no evento `PromptGamePassPurchaseFinished` do servidor. | Foi o problema aberto do v28: logo depois da compra, a Roblox pode responder que o jogador ainda não tem o passe. O Venda um Ovo v6 já tem o jeito certo em `Store.luau`. |
| 5 | **Salvamento seguro:** quando o jogador sai e volta rápido para o mesmo servidor, esperar o salvamento da saída terminar antes de carregar. Também travar a sessão para dois servidores não salvarem por cima um do outro. | O v28 perdia progresso assim. O `Data.luau` do v28 e o do Venda um Ovo v6 já têm a correção. |
| 6 | **Roubo com teleporte:** o servidor confere o caminho do ovo a cada 0,15 s, não só o tempo total da viagem. | Exploit corrigido no v28. Atenção: a revisão achou um furo até na correção do v28. Um teleporte único logo antes de chegar ainda passa, então a regra precisa ser "qualquer salto grande devolve o ovo". |
| 7 | **Portal da zona e "NEED 900 SPEED":** o servidor confere a velocidade salva. Quem está carregando ovo não entra no portal. | A placa sozinha não impede trapaça. Sem essa regra, o portal vira um teleporte de graça para casa. |
| 8 | **Ovo sem dono para sempre:** no máximo 2 min carregando. O ovo volta se o jogador morrer, sair ou o servidor fechar. | Corrigido no v28. |
| 9 | **Não vender na hora o que acabou de roubar** (trava de uns 60 s). | Corrigido no v28. Senão o taco e a vingança não valem nada. |
| 10 | **Procurar "vírus" (backdoor) nos modelos do Toolbox** e no baú inserido com `GetObjects`. | Modelos grátis às vezes trazem scripts escondidos que dão controle do jogo a estranhos. Use a ferramenta `tools/ProcurarVirus.lua` deste pacote. |
| 11 | **Tirar o que é idêntico ao Steal an Egg:** 2ª zona com 900 de velocidade, nomes "X2 MONEY!", "X2 GROWTH SPEED!", "Grow All Eggs" e pacote "+150K Speed". | Mecânica igual não tem problema. Números, nomes e arte iguais é o que dá risco de denúncia. O Steal an Egg tem a zona Lake com 900 e os passes com exatamente esses nomes. |

## 2. Dinheiro (Robux): o que ligar primeiro

1. **Passe DINHEIRO 2X** e **passe CHOCA 2X MAIS RÁPIDO**, com nomes seus. O Steal an Egg cobra 399 R$ e 467 R$. Comece mais barato (149 a 299 R$) e ajuste depois.
2. **"Chocar este ovo agora"**, bem barato (5 a 15 R$), para um ovo só. É a compra mais fácil de uma criança decidir.
3. **Pacotes de velocidade** calculados para "abrir a próxima zona". **Nunca** um pacote que pule o mapa inteiro.
4. **Ligar o "Regional Pricing"** (preço por país). No Brasil o preço fica mais justo e vende mais.
5. **Na loja, mostrar o preço que a Roblox informa** (`GetProductInfoAsync`), não o número escrito no `Config`.
6. **Ofertas na hora certa, com freio:**
   - no máximo 1 oferta a cada 10 minutos;
   - janela pequena, com o X bem visível;
   - nunca abrir a tela de compra sozinha;
   - sem contagem regressiva falsa nem "última chance";
   - a oferta depois de ser pego pelo guardião, no máximo 1 vez por sessão.

## 3. Conteúdo e motivos para voltar

| Prioridade | O que fazer | De onde veio |
|---|---|---|
| Alta | **Atualização fixa toda semana**, mesmo dia e hora, com placa "Próxima atualização em 3d 4h". **Este pacote já traz isso.** | O Steal an Egg atualiza quase todo sábado, por volta de 12h de Brasília. |
| Alta | **"Festão" semanal automático:** sorte x5 por 30 min na hora da atualização. Roda sozinho, sem você online. **Este pacote já traz isso** (falta ligar a sorte no `Game.luau`). | O "Admin Abuse" do Steal an Egg (30 a 60 min antes de cada atualização). |
| Alta | **Mutações ao chocar:** Dourado 2x, Arco-íris 3x e uma só do Critter. **Este pacote já traz o sorteio e o visual** (falta chamar na hora de chocar). | Steal an Egg e Steal a Brainrot. |
| Alta | **Prêmio por completar uma zona no Index:** taco novo da zona + velocidade. Mostrar "7/10 Floresta". | Steal an Egg. |
| Alta | **Halloween** até uns 24/10: decoração, um ovo-abóbora e 2 bichos que se ganham jogando, sem Robux. **Este pacote já traz a decoração.** | O "Halloween Dimension" do Steal an Egg começa em 17/10. |
| Média | **Peso aleatório no ovo** (kg): o mais pesado deixa você até uns 15% mais lento, mas choca um bicho maior que rende mais. | Steal an Egg. |
| Média | **Loja de rastros** que multiplicam a velocidade da esteira (x1,5, x2, x3...), comprados com dinheiro do jogo. | Steal an Egg. |
| Média | **Sequência de 7 dias** no prêmio diário (dia 7 = ovo Raro) e 3 missões por dia. | Venda um Ovo v6 e Steal a Critter v28. |
| Média | **Máquina "3 iguais = 1 ovo melhor"**, para dar uso aos bichos repetidos. Mostrar as chances na própria máquina. | Steal an Egg. |
| Média | **Aviso para o servidor inteiro** quando alguém choca Lendário ou melhor. | Gênero. |
| Média | **"Bem-vindo de volta! Você ganhou $X"** (ganho offline) e uma placa no cercado: "Você ganha $X por dia offline". | Steal an Egg. |
| Baixa | **Montarias** (andar no próprio bicho). Deixe para depois: dá muito trabalho. | Steal an Egg. |

**Meta de conteúdo:** 4 a 6 bichos por zona (uns 50 a 70 no total) e de 5 a 8 bichos novos por atualização. O Steal an Egg passou de uns 70 para 198 pets entre agosto e outubro.

## 4. Primeiros minutos e frustração (crianças)

- **Placa da zona que diz o que fazer:** em vez de só vermelho/verde, mostrar "FALTAM 320 — treine na esteira".
- **Primeiros 3 a 5 ovos curtos** (menos de 1 minuto). Ovos de horas, só nas zonas finais.
- **Proteção para iniciante:** escudo contra taco e armadilha nos primeiros 10 minutos, e regra anti-valentão. O `Fairness.luau` do v28 tem a ideia, mas lá ela vale para roubo de base. Para o taco, é regra nova.
- **Taco e armadilha mais leves:**
  - atordoar no máximo uns 2 a 3 s;
  - a armadilha só pega quem carrega ovo;
  - no máximo 3 armadilhas por jogador;
  - nunca na área SAFE nem nas bases.
- **Ovo que caiu** brilha, tem contagem e volta ao ninho em uns 15 s.
- **"SALVO!"** bem grande, com som, ao cruzar a linha SAFE.
- **"Tem certeza?"** antes de vender um bicho Raro ou melhor.
- **Antes do rebirth**, mostrar o que a criança ganha e o que perde, e dar algo visível: título, coroa ou cor de rastro.

## 5. Social e crescimento

- **Botão "Convidar amigos"** com o convite oficial da Roblox, com prêmio quando o amigo entra pelo convite. A Roblox permite isso, e jogar com amigos ajuda o jogo a aparecer na página inicial. **Este pacote já traz o botão** (o prêmio funciona depois de ligar o `Bridge`).
- **Caixa de códigos:** 1 código por atualização e 1 por YouTuber. Prêmios pequenos. **Este pacote já traz isso.**
- **Rankings no hub:** mais dinheiro, mais rebirths, mais velocidade. **Este pacote já traz isso** (lê o `leaderstats`).
- **Like e favorito: nunca dar prêmio.** O seu jogo já acerta nisso. Use o pedido oficial de favorito (`PromptSetFavorite`) uma vez por conta, depois de uns 15 min de jogo.
- **Servidores privados** grátis ou baratos. Atenção: dependendo do controle dos pais, menores de 13 anos podem não conseguir entrar.
- **Sem troca de bichos entre jogadores por enquanto:** com crianças, vira golpe.
- **Não dependa de Discord:** é só para maiores de 13. Use o grupo da Roblox e os **Eventos** do Creator Hub (botão "Avise-me" na página do jogo).

## 6. Celular e desempenho

- **Modo leve** salvo nas configurações: desliga chuva de moedas, partículas e luzes extras. Celulares Android baratos travam.
- **Efeitos visuais só para quem está perto.**
- **Janelas pequenas, no alto,** sem bloquear o polegar direito, que fica no pulo.
- **Esteira com "correr sozinho"** no celular.
- **Português:** ligue a tradução automática no Creator Hub (Localization). Os textos com números ("NEED 900 SPEED") precisam de tradução escrita por você.

## 7. Creator Hub: o que dá para fazer HOJE sem programar

Veja o arquivo `CREATOR-HUB.md`.

## 8. O que NÃO copiar do Steal an Egg

- **Vídeo rolando na tela da esteira.** O Steal an Egg foi tirado do ar por umas 3 a 4 h em 24 e 25/08/2026 por causa dos "Reels" na esteira. Depois a Roblox passou a deixar de fora do **Roblox Kids** (5 a 8 anos) e do **Select** (9 a 15 anos) os jogos que juntam feed de vídeo, reprodução automática e prêmio por assistir.
- **Números exponenciais até bilhões** e pacotes de +1B de velocidade. Os jogadores chamam isso de "pay to win".
- **Pressa para comprar:** "1/1 left", ovo só por Robux durante a atualização, limite semanal de compras.
- **Ovos normais de 10 a 18 horas.**
- **Dar prêmio por like e favorito.** O Steal an Egg faz isso, o seu não, e é o certo.

## 9. Onde você já está na frente (use na descrição e nas imagens)

- **Primeiro bicho em 5 segundos** e primeiro upgrade por $250. No Steal an Egg custa $1K.
- **O chocar é um show** que todo mundo vê, e o bicho raro fica gigante, num pedestal com coluna de luz. É o melhor material para ícone e thumbnail.
- **Presentes por tempo jogado + prêmio diário.** A pesquisa não achou isso no Steal an Egg.
- **Bônus de amigos, rebirth e evento da sorte** com contagem sempre na tela.

## 10. Para o jogo aparecer para crianças (muito importante em 2026)

- Contas de quem tem menos de 16 anos só veem jogos aprovados para o **Roblox Kids** (5 a 8) e o **Select** (9 a 15).
- Para entrar, o jogo precisa passar pela avaliação da Roblox. Desde 19/08/2026 isso exige 250 jogadas de usuários com idade verificada em 60 dias, e o Kids só mostra jogos com classificação Mínima ou Leve.
- **Preencha o questionário de maturidade com sinceridade.** O taco em desenho, com estrelinhas, sem sangue, deve ficar como "Leve" (Mild).
