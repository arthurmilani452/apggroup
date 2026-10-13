# Steal a Critter Egg - v66.1 (13/10/2026)

> **v66.1 (use ESTE arquivo: StealACritterEgg-v66.1.rbxl).** Correções da revisão final:
> - **Vender:** tocando rápido em dois bichos da mesma espécie, o jogo podia vender **outro**, até um Dourado ou Gigante, sem pedir confirmação. Agora o servidor confere espécie, mutação, tamanho e zona.
> - **Memória do celular:** cada bicho vendido, fundido ou apagado no rebirth ficava guardado na memória de todo mundo até o fim da partida, e o celular ia ficando lento. Corrigido.
> - **Admin Abuse:** servidores que abrem **durante** o evento (gente entrando por causa dele) agora também entram no evento, e todos terminam juntos. Testar no Studio fica só no Studio. "Pumpkin Rain" só funciona no Halloween (antes prometia doces que não vinham).
> - **Halloween** aparece no relógio, com os doces, e o aviso diz que a loja fica no Menu.
> - **Slow Mode:** o botão não mostra mais "OFF" com o modo ligado.
> - **Celular bem pequeno (iPhone SE):** a tela encolhe um pouco mais, então os textos não ficam mais em cima dos botões.
> - **Índice:** o prêmio mostrado é o mesmo que você ganha.
> - **Missões:** o "CLAIM!" não se perde mais enquanto você corre na esteira.
> - **Trilhas:** equipar uma trilha que já é sua mostra o aviso.
> - **Sequência de roubos:** aparece no aviso de correr e a cada entrega.


Feito em cima do **StealACritterEgg-v64.rbxl** que você mandou, com tudo da v65.1 junto.

Arquivo novo: `place/StealACritterEgg-v66.1.rbxl`. Mudou só o código dos scripts: mapa, modelos 3D e configurações do Studio estão iguais ao v64.

> **Sobre "100% de certeza que vai viralizar":** ninguém consegue garantir isso, nem copiando o Steal an Egg igualzinho. Cópia exata ainda corre risco de denúncia e de ser derrubada. O que dá para copiar com segurança é **o que faz esses jogos crescerem**, e foi isso que a v66 fez: eventos ao vivo de admin em todos os servidores, atualização toda semana com festa, tela limpa no celular, esteira que dá vontade de melhorar e uma economia que não acaba em 40 minutos.

## Como colocar no jogo

1. Abra o `StealACritterEgg-v66.1.rbxl` no Studio. Ou, no seu jeito de sempre, copie a pasta `src` desta versão por cima da sua e ligue o Rojo.
2. Aperte **Play** e teste a lista do fim deste arquivo.
3. **File > Publish to Roblox** por cima do jogo que já existe. O passo a passo está no `COMO-PUBLICAR.md`.

---

## 1. Tela mais limpa (o que você pediu: "tem muita coisa na tela")

**Antes:** 2 colunas de botões, 5 relógios, barra de rebirth, chave de Slow Mode e botões de Som, Convite, Códigos e Doces, tudo aberto ao mesmo tempo.

**Agora:**
- **Esquerda: só 5 botões grandes.** Shop, Index, Eggs, Pets e Gifts.
  - Index mostra quantos prêmios faltam pegar.
  - Eggs mostra quantos ovos estão prontos.
  - Gifts mostra o "!" e o tempo do próximo presente.
- **Direita: 1 botão ☰ Menu.** Ele abre 10 quadrados: Daily, Quests, Rebirth (com %), Boosts, Codes, Candy (só no Halloween), Invite, Sound, Slow Mode e Admin (só para admins). Uma bolinha vermelha "!" avisa quando tem coisa para pegar lá dentro.
- **Relógios: 2 em vez de 5.**
  - O 1º mostra quanto falta para a noite.
  - O 2º mostra o evento mais importante do momento (Admin Abuse, festa, sorte, Halloween...). Se nada estiver ligado, ele alterna entre os 2 próximos a cada 4 s.
- **Celular:**
  - a tela nunca fica pequena demais (escala mínima 0.6);
  - janela que não cabe encolhe sozinha;
  - os 5 botões ficam em cima, à esquerda, longe do analógico;
  - o dinheiro e a velocidade ficam embaixo, ao lado da barra do taco e da armadilha, sem ficar escondidos atrás dela;
  - na hora de chocar, a barra do taco some para mostrar o nome do bicho novo.
- **Português:** quem joga com o Roblox em português vê os botões, o Menu, as dicas do tutorial e a esteira em português. O resto continua em inglês. Ligue a tradução automática no Creator Hub para completar.

Todas as janelas (Shop, Index, Codes, Doces...) continuam iguais. Só o caminho até elas mudou.

## 2. Esteira

### Cada nível com uma cara nova (o que você pediu: "cada melhoria ter uma aparência mais foda")
Quando a criança compra um nível, a esteira dela muda na hora, com explosão de brilho, som e aviso para o servidor todo:

| Nível | Nome | O que aparece |
|---|---|---|
| 1 | Basic | esteira simples |
| 2-3 | Bronze, Silver | trilhos de metal dos lados |
| 4 | Gold | trilhos dourados + brilhinhos subindo |
| 5-8 | Ruby, Emerald, Sapphire, Diamond | pilares de pedra preciosa com joia em cima |
| 9 | Neon | arco de neon com luz |
| 10 | Lava | brasas de lava subindo |
| 11 | Frost | neve caindo e gelo |
| 12 | Cosmic | estrelas em volta |
| 13 | Mythic | bola de aura mágica |
| 14 | Celestial | coluna de luz para o céu |
| 15 | Angelic | auréola e asas |
| 16 | Divine | arco-íris + raios dourados |

Cada nível mantém o que os anteriores já tinham, então a esteira vai ficando cada vez mais cheia de efeitos.

### Esteira 2.0
- **Sequência:** correndo sem parar, o ganho sobe +5% a cada 30 s, até +50%. Se sair da esteira por mais de 4 s, a sequência volta a zero (`Config.Treadmill`).
- **Painel da esteira:** só aparece na SUA esteira. Mostra quanto ganha por passo, o bônus da sequência e uma barra até a próxima zona (ou "MAX SPEED ZONE!").
- **AUTO RUN:** botão que corre sozinho na esteira. Desliga quando a criança sai da esteira, pega um ovo ou mexe o personagem.
- **Zona nova liberada:** mensagem grande no meio da tela, confete e som.

## 3. Economia (o que você pediu: "está muito fácil ficar rico")

Você tinha razão. Medi com um simulador (`tools/sim/progression.py`) que joga como uma criança no celular, 1 hora por dia:

| | v65 | v66 |
|---|---|---|
| Chegar na última zona (Hero Heights) | **40 minutos** | **~25 horas** jogadas |
| Zona 2 | 2 min | 3 min |
| Zona 5 | 15 min | 42 min |
| Zona 8 | 23 min | 2,7 h |
| Fazer rebirth vale a pena? | não mudava nada | chega 28% mais rápido |

O começo continua rápido, para a criança não desistir. O que mudou:

- **Index:** antes, 1 Lendário sortudo dava velocidade suficiente para pular 1 ou 2 zonas inteiras. Agora cada bicho novo dá uma fatia do caminho até a próxima zona (Comum 1% ... Celestial 25%). Uma zona completa vale ~85% do caminho, então nunca abre a próxima sozinha.
- **Esteira mais cara do nível 4 em diante:** cada nível custa 33x o anterior (antes 5,5x). Os níveis 1 a 3 têm o mesmo preço. Quem já comprou um nível continua com ele.
- **Zona 9 (Starry Space):** portão de 620M para 190M. Antes era uma parede de várias horas.
- **Rebirth:** cada rebirth agora dá +50% de ganho na esteira (antes +25%). Agora compensa fazer.
- **Prêmios não multiplicam mais por 16:** presentes, diário, missões, baú, códigos, sequência de roubos, convite e dinheiro offline agora usam a renda **base**. Antes, passe 2x + boost 2x + fim de semana 2x + Admin 2x multiplicavam cada presente. Os 2x continuam valendo na renda por segundo, que é o que a criança vê subindo.
- **Bicho da Semana:** 24 Lendários/Míticos que cobrem as 12 zonas, trocando toda segunda. Na zona dele, ele sai de 3 a 9 vezes mais (antes quase não fazia diferença).

> Jogadores antigos: o preço dos próximos níveis de esteira sobe e os prêmios do Index que ainda não pegaram (da zona 3 em diante) ficam menores. Quem já tem entre 190M e 620M de velocidade libera a zona 9 na hora.

## 4. Admin Abuse (eventos ao vivo em TODOS os servidores)

É o que mais faz o Steal an Egg e os "brainrot" lotarem: o dono entra e solta um evento em todos os servidores ao mesmo tempo.

**Quem pode:**
- você (o dono do jogo);
- se o jogo for de um grupo, quem tem cargo 254 ou 255 (`Config.AdminMinRank`);
- quem você colocar em `Config.Admins`, por exemplo `Config.Admins = { 12345678 }`;
- no Studio, todo mundo pode, para você testar (o evento fica só no teste, nunca nos servidores de verdade).

**Como usar:** Menu ☰ > **Admin**. Toque 2 vezes no botão (dentro de 3 s) para confirmar, porque 1 toque sem querer liga em todos os servidores.

| Botão | O que faz |
|---|---|
| Luck x10 | sorte x10 em Lendário ou melhor por 15 min |
| Golden Rain | 5 ovos dourados em cada servidor |
| Pumpkin Rain | 3 ovos de abóbora em cada servidor (só no Halloween) |
| Party | começa o Festão da atualização agora |
| 2x Money | renda em dobro por 15 min |

Os números ficam em `Config.AdminAbuse`.

**Dica:** marque no grupo e no Discord, por exemplo "Admin Abuse sábado às 15h", e entre no jogo na hora. É isso que lota os servidores.

## 5. Mais coisas que dão vontade de voltar
- **Sequência de roubos:** a cada 5 entregas sem ser pego, ganha 2 min de renda. A sequência aparece no aviso de correr e zera quando o guardião pega.
- **Notícias:** quando alguém choca Divine ou Celestial, todos os servidores ficam sabendo.
- **Convite de amigo:** o amigo novo ganha $2K + 500 de velocidade na hora. Quem convidou ganha depois que o amigo joga 5 min e rouba 1 ovo, no máximo 5 por dia.

## 6. Mais leve no celular
- A tela não decodifica mais a lista de bichos 4 vezes por segundo, só quando ela muda.
- A esteira procura o personagem a cada 2 s, em vez de varrer o mapa a cada quadro.
- As listras animadas aparecem só na sua esteira e só enquanto você corre.
- Os 5 relógios e os 3 loops deles viraram 1 só.

## 7. Correções
- A sorte do Bicho da Semana agora conta também na raridade, não só dentro dela.
- Os efeitos da esteira de quem sai do servidor são apagados, e o cercado fica limpo para o próximo jogador.

---

## O que você faz no Creator Hub
1. **Tamanho do servidor: 7 jogadores.** O mapa tem 7 cercados. Com 12 jogadores, 5 crianças ficam sem cercado ("All pens are taken"). Vá em Creations > Steal a Critter Egg > Places > (o lugar) > **Max Players = 7**.
2. **Passes:** 399 Robux é caro para criança. Jogos desse tipo vendem mais entre 99 e 199. Teste 149 no 2x Cash por 1 semana e compare em Analytics > Monetization.
3. **Eventos:** crie "Admin Abuse" no Events para o dia que você vai entrar. Aparece o botão "Avise-me" na página do jogo.
4. **Tradução automática:** Localization > ligue português e espanhol.

## Como testar no Studio (10 minutos)
1. **Tela:** no celular (Test > Device > iPhone ou um Android pequeno), veja se os 5 botões, o Menu e os 2 relógios não ficam em cima do analógico nem do pulo.
2. **Menu:** abra cada um dos 10 quadrados.
3. **Esteira:**
   - suba na sua e ligue o AUTO RUN; veja a sequência subir a cada 30 s;
   - pegue um ovo e veja o AUTO RUN desligar;
   - dê dinheiro com o comando `game.Players.SeuNome:SetAttribute` ou com o Admin "2x Money" e compre níveis para ver cada visual.
4. **Admin:** Menu > Admin > toque 2x em "Luck x10" e veja o relógio da direita mostrar o evento.
5. **Zona nova:** corra até liberar a zona 2 e veja a festa na tela.
6. **Economia:** confira se o nível 4 da esteira custa $454K (antes $75,6K).
