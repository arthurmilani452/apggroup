# Farmar Aura: referências e prompt do jogo

Um tycoon idle de **farmar aura e vender aura**, com a estrutura do Vender Limões (Sell Lemons), que tem mais de 400 milhões de visitas e 95% de aprovação, e o tema do "aura farming", a febre de 2025.

O documento tem duas partes:
- **Parte 1:** as referências pesquisadas e o que tirar de cada uma.
- **Parte 2:** o prompt pronto para colar no Claude Code (de preferência no seu PC, com o Roblox Studio ligado).

> Copiamos **ideias de mecânica**, nunca nomes, modelos, textos ou músicas de outros jogos. Mecânica não tem dono, mas arte e marca têm.

---

## Parte 1: referências

### 1.1 Vender Limões (Sell Lemons): a base

- **Página do jogo:** https://www.roblox.com/games/79268393072444/Sell-Lemons
- **Wiki (fandom):**
  - https://sell-lemons-roblox.fandom.com/wiki/Income_Sources
  - https://sell-lemons-roblox.fandom.com/wiki/Rebirth
  - https://sell-lemons-roblox.fandom.com/wiki/Evolution
  - https://sell-lemons-roblox.fandom.com/wiki/Ascension
  - https://sell-lemons-roblox.fandom.com/wiki/Investors
  - https://sell-lemons-roblox.fandom.com/wiki/The_Staircase
  - https://sell-lemons-roblox.fandom.com/wiki/LemonDash
  - https://sell-lemons-roblox.fandom.com/wiki/Lemon_Depot
  - https://sell-lemons-roblox.fandom.com/wiki/LemonX
- **Guias:**
  - https://www.pocketgamer.com/roblox/sell-lemons-guide/
  - https://www.sportskeeda.com/roblox-news/sell-lemons-a-beginner-s-guide
  - https://progameguides.com/roblox/sell-lemons-beginners-guide-roblox/
  - https://bloxron.com/sell-lemons/guide/beginner-guide
  - https://bloxron.com/sell-lemons/income-sources
  - https://selllemonswiki.wiki/guides/investors-guide/
  - https://selllemons.com/secrets
  - https://selllemons.games/gamepass/sell-lemons-gamepass-list/
- **Vídeos de gameplay (assista pelo menos 3 antes de começar):**
  - Do zero ao rico: https://www.youtube.com/watch?v=09uY2uOFL18
  - Guia completo de como jogar: https://www.youtube.com/watch?v=IbU5bw4PDV4
  - Virei bilionário: https://www.youtube.com/watch?v=9yQEpkgL064
  - De 0 a 100 trilhões: https://www.youtube.com/watch?v=SZa1Dgn0dmA
  - Gameplay: https://www.youtube.com/watch?v=C7Cc4omDQZc
  - Labirinto (segredo), em português: https://www.youtube.com/watch?v=SXIcP0B5GT8

**Por que ele funciona** (é isso que precisamos repetir):

1. **O primeiro minuto é ridículo de simples.** Você tem $1 e uma barraca. Clica na barraca, o dinheiro cai no chão e você anda por cima para pegar.
2. **Automação logo cedo.** O primeiro gerente/vendedor tira o clique, e a partir daí o jogo vira "ver o número subir". Os guias dizem: compre gerente primeiro e a melhoria do negócio mais novo em segundo.
3. **8 fontes de renda que se MULTIPLICAM**, uma não substitui a outra: Barraca → LemonDash ($17 mil, entrega com drone x7) → Depósito ($13,5 bilhões, gerente a $14 trilhões) → Trading → Labs → Robotics → Republic → LemonX (estação espacial).
4. **5 lugares no mapa, em ordem:** barraca de $1 → casinha das entregas → armazém verde → arranha-céu na montanha (4 negócios num prédio só) → foguete para a estação espacial.
5. **Renascer com um NPC.** O alienígena Joe, no disco voador atrás da barraca, troca o seu dinheiro por **Investidores**, cada um +1% de dinheiro. Ao renascer, perde dinheiro e negócios, mas as frutas, a escadaria e as compras com Robux ficam. A primeira volta "parece um passo para trás por 10 minutos" e depois tudo acelera.
6. **Poderes:** melhorias permanentes pagas com investidores (velocidade, dinheiro, desconto). Algumas têm espera, e um passe pula essa espera.
7. **Evolução:** a 2ª camada de reset. As frutas mudam (limão → laranja...), com 9 níveis, e cada uma multiplica a venda.
8. **Ascensão:** a 3ª camada. Uma escadaria no espaço, x2,33 permanente por ascensão.
9. **Clima do Vazio:** evento raro em que a renda fica x3 a x8 (cerca de x4,5). "Comprar durante o Vazio é o grande salto dos jogadores grátis."
10. **Renda offline de 100%, sem limite.** É o motivo de voltar todo dia.
11. **Segredos:** a chave do esgoto (alavancas em ordem certa num labirinto atrás do depósito), a chave do disco voador (insígnia de "bom samaritano") e a Fruta da Pureza (100% do jogo, só cerca de 20 pessoas no mundo têm).
12. **Monetização enxuta:** 4 itens. Boost x8 por 15 min (40 R$), manter melhorias ao ascender (90), pular espera dos poderes (180) e +4% de investidor por compra (630). Quase todo o crescimento é de graça.

### 1.2 Jogos de aura: o tema

- **Páginas no Roblox:**
  - Aura Farm Game: https://www.roblox.com/games/137852381015219/Aura-Farm-Game
  - AURA FARM: https://www.roblox.com/games/122656975780055/AURA-FARM
  - Aura Farm Simulator: https://www.roblox.com/games/119254427034490/Aura-Farm-Simulator
  - AURA.: https://www.roblox.com/games/75467339082089/AURA
- **Guias:**
  - https://deltiasgaming.com/roblox-aura-farm-game-a-beginners-guide/
  - https://www.sportskeeda.com/roblox-news/aura-farm-game-a-beginner-s-guide
- **Sol's RNG**, o maior jogo de "colecionar auras":
  - https://www.solrng.wiki/guides/how-to-play/
  - https://solrng.wiki/en/auras/aura-rarities/
  - https://www.solrng.wiki/en/biomes/biome-guide/
- **A febre "aura farming"** (o menino do barco da Indonésia, Rayyan Arkan Dikha, e a música "Young Black & Rich"):
  - https://www.scmp.com/postmag/culture/article/3321096/what-aura-farming-gen-zs-viral-obsession-looking-cool
  - https://meme.com/memes/aura-farming

**O que pegar de cada um:**
- **Dos simuladores de aura:** clicar para farmar aura, aura visível no boneco, música phonk, ranks e renascer com multiplicador.
- **Do Sol's RNG:**
  - colecionar auras de raridades bem diferentes (de 1 em 2 até 1 em milhões);
  - "biomas" (climas) que mudam a sorte, e as pessoas jogam esperando o bioma;
  - a coleção de auras raras é o que deixa a pessoa se exibir.
- **Da febre:** pose confiante, óculos escuros, a ponta do barco com gente remando atrás. É a cena mais reconhecível do tema e precisa estar no jogo.

**O que NÃO pegar:**
- **Sorteio pago:** comprar giro ou "sorte" com Robux é proibido onde o Roblox restringe e deixa o jogo com cara de cassino. Os giros de aura vêm só de jogar.
- **Músicas com direito autoral:** use só faixas phonk liberadas na biblioteca de áudio do Roblox (Creator Store).

### 1.3 O que já temos pronto (Venda um Ovo v6, neste repositório)

O motor do Venda um Ovo já faz quase tudo que o Vender Limões faz:
- regras no servidor;
- 8 negócios com gerentes e melhorias;
- dinheiro no chão;
- renascer, selos e talentos;
- clima, poderes, chaves secretas e baú;
- renda offline e save seguro;
- loja, conquistas, presentes por tempo, placares e títulos;
- interface pronta para celular.

**Não começar do zero:** copiar `vendaumovo/v5/src` e trocar o tema. São semanas de trabalho já testadas.

---

## Parte 2: o prompt (cole no Claude Code)

```
Você é um desenvolvedor Roblox de nível top 100. Vamos criar "Farmar Aura", um tycoon idle
inspirado na ESTRUTURA do Sell Lemons (Vender Limões) com o tema "aura farming".
Leia farmaraura/PROMPT-JOGO-PERFEITO.md inteiro antes de começar (tem as referências).

BASE TÉCNICA
- Copie vendaumovo/v5/src para farmaraura/src e adapte. É o motor do Venda um Ovo v6:
  Sim.luau (regras puras), Config.luau (todos os números), Lang.luau (pt/en), servidor
  autoritativo (Registry/Remotes com intervalo por ação), save com trava de sessão e
  ProcessReceipt que salva antes de entregar. Mantenha tudo isso.
- DataStore NOVO: "FarmarAura_v1" (é outro jogo).
- Use o Roblox Studio conectado: monte o mapa direto no Studio e teste com Play.

O LOOP (igual ao Sell Lemons, com aura)
- Começa com 1 de Aura numa pedra à beira do rio. Toque em POSAR: o boneco faz a pose, sobe
  aura do corpo e caem "frascos de aura" no chão. Andar por cima vende (moedas).
- 8 FONTES DE RENDA que se multiplicam (não se substituem), em 5 lugares do mapa:
  1. Pedra do Rio: posar na mão (o "clique da barraca")
  2. Canal de Cortes: edits com phonk para as redes (casinha com computador)
  3. Academia do Shape
  4. Barco de Corrida: o menino na ponta do barco e os remadores. É a cena símbolo do jogo:
     faça bonito e com animação.
  5. Estúdio de Phonk (no arranha-céu da montanha, junto com o 6 e o 7)
  6. Passarela de Moda
  7. Estádio Lotado
  8. Templo no Céu (foguete ou escadaria de nuvens até lá)
  Cada uma tem: botão de comprar no chão, gerente (automatiza), 2 filas de melhorias
  (dinheiro e velocidade). Primeira compra de gerente custa ~1 minuto de jogo.
- RENASCER com um NPC: "Mestre", um velhinho de óculos escuros meditando numa pedra atrás
  da Pedra do Rio. Troca o dinheiro por FÃS (cada fã +1% de renda, para sempre).
  Perde: dinheiro e negócios. Fica: auras, poses, escadaria, compras com Robux.
  Primeiro renascimento por volta de 25-35 min de jogo.
- PODERES (pagos com fãs): velocidade de andar, +dinheiro, desconto nas melhorias,
  ímã de frascos, gerente mais rápido. Alguns com espera de tempo real.
- EVOLUÇÃO DA AURA (2ª camada, 9 níveis): a cor da aura do boneco muda:
  branca, azul, verde, roxa, vermelha, dourada, arco-íris, preta e "do vazio".
  Cada nível multiplica a venda. Todo mundo vê a sua cor: é status.
- ASCENSÃO (3ª camada): Escadaria das Nuvens até o Templo; x2 permanente por ascensão.
- COLEÇÃO DE AURAS (estilo Sol's RNG, mas SÓ GRÁTIS): ganha giros jogando (presentes por
  tempo, conquistas, obby, baús). Cada giro sorteia uma aura com raridade
  (Comum 1/2 ... Lendária 1/10.000 ... Mítica 1/1.000.000). A aura equipada aparece no
  boneco e dá bônus pequeno; a coleção completa dá bônus grande. A sorte sobe com renascer e
  com os climas. NUNCA vender giro, sorte ou caixa com Robux.
- CLIMAS DO SERVIDOR: Hora Dourada (pôr do sol, x2 aura), Chuva de Phonk (gerentes x2 mais
  rápidos), Lua de Sangue (sorte x3 nos giros) e o raro FENDA DO VAZIO (céu rachado, tudo
  x4,5 por 3 minutos, anúncio para todo o servidor).
- RENDA OFFLINE 100%, sem limite de horas (o grande motivo para voltar todo dia).
- SEGREDOS (3, com insígnia): alavancas em ordem num labirinto embaixo da ponte (chave do
  rio), ajudar 10 jogadores novos a pegar frascos (chave do templo), e a "Aura Pura" (100% do
  jogo, muito difícil).
- SOCIAL: placares no meio do mapa (Mais Aura de todos os tempos, Mais Renascimentos,
  Mais ricos agora no servidor), título em cima da cabeça pelo renascimento, cor da aura
  visível, +20% por amigo no servidor, baú do grupo, curtir a granja dos outros.
- RETENÇÃO: presentes por tempo (5 a 60 min, grade de caixas), sequência de dias, missões
  diárias, conquistas, lembrete de favoritar (uma vez), códigos.

LOJA (pouca e justa, como o Sell Lemons)
- Produtos: Boost x8 por 15 min, Pular 30 min / 4 h de renda, Pacote Inicial (uma vez).
- Passes: Manter Melhorias ao Ascender, Pular Espera dos Poderes, +Fãs (bônus permanente),
  Dinheiro 2x, VIP (título dourado e +bônus), Ímã Automático.
- Regra: cada item diz em UMA frase o que faz e mostra o preço. Sem contagem regressiva,
  sem "última chance", sem desconto riscado, sem janela que abre sozinha, sem sorteio pago.

VISUAL E SOM
- Mapa: rio com barcos e a pedra do começo, cidade pequena, montanha com arranha-céu,
  nuvens com o templo. Cores fortes, fim de tarde dourado.
- Modelos 3D do Higgsfield (tripo_3d, até 18 mil triângulos, detalhe alto): barco de corrida
  longo, pedra de pose, estúdio de phonk, passarela, estádio, templo nas nuvens, academia,
  frasco de aura brilhante, velhinho meditando, foguete, troféus. Use o
  ServerScriptService/Game/Instalar3D.luau para colocar no jogo.
- Aura no boneco: ParticleEmitter + Highlight leve; no celular, poucas partículas (Modo leve).
- Phonk: só faixas liberadas do Creator Store. Volume baixo, música para quando a pessoa
  desliga.
- Interface: tudo em português natural (com inglês), botões grandes com relevo, grade de
  caixas para presentes, quase sem texto explicativo. NADA de lista genérica de cartões
  com emoji: isso tem cara de IA. Pense primeiro no celular: nada no meio da tela
  atrapalhando o personagem.

RITMO (meça com um bot como o vendaumovo faz)
- 1º minuto: 3 compras. 10 min: 4 negócios com gerente. 25-35 min: 1º renascimento.
- Do 4º negócio em diante, a espera entre compras cresce no máximo 4% por compra.

ANTES DE ENTREGAR
- Rode lint (selene) e compile tudo; dê Play no Studio com 2 jogadores; teste no modo
  celular; faça uma revisão de exploits (todo prêmio por proximidade passa pelo Guard;
  todo remote confere tipo, intervalo e dono).
- Escreva LEIA-ME.md em português simples: o que o jogo tem, onde trocar números
  (Config), quais IDs criar no Roblox (passes, produtos, insígnias).
```

---

## Checklist do "jogo perfeito"

- [ ] Em 10 segundos a pessoa entende o que fazer (só um botão grande: POSAR)
- [ ] Em 1 minuto ela já automatizou algo
- [ ] Aos 10 minutos tem 4 negócios rodando sozinhos e a aura visível no boneco
- [ ] Antes de 35 minutos renasce pela primeira vez e sente o jogo acelerar
- [ ] Sempre existe uma meta visível na tela (próxima compra, próximo presente, próxima cor de aura)
- [ ] Quem volta no dia seguinte encontra uma pilha de dinheiro offline
- [ ] O barco de corrida é bonito o bastante para virar clipe de TikTok
- [ ] Roda liso num celular simples (Modo leve funciona)
- [ ] A loja é honesta e não tem nada sorteado pago
