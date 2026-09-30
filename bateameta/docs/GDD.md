# GDD: Bate a Meta: Turno da Noite (Hit the Quota: Night Shift)

**Versão:** 1.0 (MVP) · **Data:** 30/09/2026 · **Plataforma:** Roblox (PC, celular, console) · **Produção:** 100% em código (builder Python gera o `.rbxlx`, scripts em Luau), sem abrir o Roblox Studio.

---

## 1. Resumo

| Item | Definição |
|---|---|
| **Nome (pt-BR)** | Bate a Meta: Turno da Noite |
| **Nome (en)** | Hit the Quota: Night Shift |
| **Gênero** | Horror cooperativo de extração com elementos de roguelite (família Lethal Company / DOORS). De 1 a 4 jogadores, partidas em rodadas, mapas gerados por procedimento, e dá para jogar sozinho. |
| **Duração** | Turno de 5 min · Contrato (3 turnos) de cerca de 19 min · Sessão-alvo de 30 a 45 min |
| **Jogadores por servidor** | 4 (uma equipe por servidor) |
| **Classificação-alvo** | **Moderada** (questionário de maturidade do Roblox) |

**Pitch.** Você é temporário do turno da noite da **RefugoCorp S.A.**, uma empresa de "reaproveitamento" bem suspeita. Toda noite o elevador de carga desce até o **Armazém 13**, um complexo de galpão e escritórios abandonado, escuro, que muda de formato a cada turno. Você tem uma lanterna com bateria fraca, 4 bolsos e uma meta para bater. O gerador está morrendo: a **ENERGIA** cai de 100% até o **APAGÃO**, e depois do apagão o elevador sobe em 60 segundos, com ou sem você. No escuro, **O Vigia**, alto e sem rosto, só se mexe quando ninguém está olhando para ele. **O Rastejante**, com uma placa de "PISO MOLHADO" no lugar da cabeça, caça pelo som. São três turnos por contrato. Quem bate a meta é **PROMOVIDO**, e quem não bate recebe o carimbo de **DEMITIDO** na Avaliação de Desempenho.

**Por que é para 16+**
1. **O humor é de vida de trabalho:** meta, hora extra, vale-refeição, comunicado do RH, "somos uma família (sem vínculo empregatício)", a escada de Estagiário a CEO. Quem tem ou está prestes a ter o primeiro emprego entende as piadas. Criança pequena não entende.
2. **Tensão e fracasso de verdade:** o turno é uma aposta entre ir mais fundo e voltar agora. Dá para ser demitido.
3. **Visual adulto:** concreto, lâmpada de sódio, escuridão, interface de terminal. Não tem bichinho fofo nem cor de doce. É o oposto do Steal a Critter, e isso deixa o teste de público limpo.
4. **Diversão social:** "NÃO PARA DE OLHAR PRA ELE!". Voz espacial e roda de pings favorecem os jogadores mais velhos.
5. **Habilidade e conhecimento** das regras de cada monstro, em vez de progresso ocioso (idle).

**Maturidade Moderada: como respeitamos**

O Roblox **não tem** classificação 16+. "16+" é um **posicionamento**, feito com título, thumbnail, descrição e tom. O resultado é medido na faixa etária do Creator Hub (seção 11).

| Categoria do questionário | Resposta honesta | Como garantimos |
|---|---|---|
| Violência | Leve a moderada, de fantasia | Monstros derrubam o jogador e há barra de vida. Não existe PvP. A pá só afeta monstros. |
| Sangue / gore | Nenhum | O nocaute é o personagem caindo, fade para preto e o texto "NOCAUTEADO". `BreakJointsOnDeath = false`. Não há corpo nem partes soltas. |
| Medo | Moderado | Escuro, perseguição e sustos de no máximo 1,2 s. Há opção de "Susto suave" e nenhum estrobo acima de 3 Hz. |
| Humor grosseiro | Leve | Privada de Ouro, Almofada de Pum. |
| Romance / sexual | Nenhum | Não tem "romance de escritório". |
| Álcool, drogas, tabaco | Nenhum | A copa só tem café. Não existe sucata de cerveja ou cigarro. |
| Jogos de azar | Nenhum | Nada aleatório é vendido. A sucata aleatória só se ganha jogando. |
| Texto livre | Só o chat padrão filtrado do Roblox | Nenhum texto do jogador aparece em placas ou nomes. Os pings são frases fixas. |
| Outros | — | Sem automutilação e sem tragédias reais. A empresa é fictícia, sem marcas ou pessoas reais e sem referência a violência no trabalho. |

---

## 2. Por que este conceito

**Evidência de mercado** (títulos grandes; os números de CCU não foram conferidos daqui, confirme no RoMonitor/Roblox Charts):
- **DOORS** e **Pressure** provam que horror cooperativo de salas procedurais para 1 a 4 jogadores funciona no Roblox, inclusive solo.
- **Deadly Delivery** (2025) trouxe o loop "junta sucata, bate a cota, foge" do Lethal Company para o Roblox. **99 Nights in the Forest** e **Dead Rails** (2025) mostram que corridas curtas com amigos chegam ao topo.
- Fora do Roblox, **Lethal Company** (2023) e **R.E.P.O.** (2025) são enormes na faixa de 16 a 25 anos e viralizam em clipes no TikTok e no YouTube.

**O diferencial**
- **Sátira corporativa brasileira escrita em PT-BR primeiro**, com inglês automático. Quase não existe horror cooperativo que fale o humor do Brasil.
- **ENERGIA = relógio.** O prédio escurece zona por zona até o APAGÃO. Dá para ler o tempo sem texto, e isso gera clipe.
- **O Vigia** transforma "quem está olhando para onde" em trabalho de equipe e não precisa de nenhuma animação.
- **Turnos de 5 min e balanceamento pensado primeiro para 1 jogador**, feito para um jogo novo com servidores de 1 a 2 pessoas.
- **A Avaliação de Desempenho** com títulos de zoeira gera prints e clipes.
- **Mapas gerados** dão rejogabilidade infinita a uma equipe pequena.

**Por que venceu** (163 pontos, contra 150, 143 e 140). É o único conceito que assume pouca gente online: o solo puxa a alavanca e joga na hora, e quem entra atrasado desce direto no turno em andamento. Tem o menor escopo que dá para lançar (1 tema, 2 monstros sem animação) e a melhor estrutura de medição (funil, eventos, A/B, pesquisa, tudo em `Config`). Também tem as redes de segurança certas para quem não usa o Studio: autoteste do gerador com seed reserva, `pcall` por subsistema e comandos de admin. Os outros conceitos tinham ganchos melhores (Linha Zero), sistemas melhores (APAGÃO) ou retenção melhor (Hora Extra), mas eram 2 a 3 vezes mais caros ou dependiam de física cliente-servidor impossível de ajustar sem testar.

**Enxertos incorporados:**
- **Do APAGÃO:** medidor de ENERGIA como relógio; núcleo do gerador em Luau puro testado com Lune; Meta do Dia; orçamento de luzes; brilho com piso mínimo; susto suave; cada monstro percebe por um sentido diferente.
- **Da Linha Zero:** buzina aos 60 s e aos 15 s; legendas para todo som; crachá que resgata o colega; pagamento dividido com a equipe e regra anti-AFK; "DEMITIDO nunca paga zero"; câmera em terceira pessoa (não travada em primeira).
- **Da Hora Extra:** Pizza da Firma; `AutoLocalize` desligado e servidor mandando só chaves de texto; roda de pings; Memo da Diretoria semanal; pedido de favoritar e convite com LaunchData; 2x XP no primeiro contrato do dia; Rastejante com a placa "PISO MOLHADO".

---

## 3. Loop principal

### Minuto a minuto (30 a 90 s)
Sair do elevador, varrer as salas com a lanterna (a bateria gasta) e achar sucata pelo brilho ou pelo escâner. Aí vem a decisão: **4 itens pequenos nos bolsos** ou **1 item pesado nas duas mãos**, que vale mais, deixa você 25% mais lento e desliga a lanterna (só fica a luz do capacete). No caminho:
- **manter os olhos no Vigia**;
- **andar agachado** perto do Rastejante, jogar um sinalizador para atraí-lo ou atordoá-lo com a pá;
- dar ping para a equipe.

De volta ao elevador, jogar tudo na caçamba de venda, ver o valor subir na meta e decidir: **mais uma viagem ou encerrar?**

### Um turno (5:00 de tempo real)

| Tempo real | Relógio no HUD | ENERGIA | O que acontece |
|---|---|---|---|
| 0:00 | 22:00 | 100% | Portas abrem. Luzes fluorescentes normais. |
| 0:30 | ~22:50 | 88% | O Rastejante acorda. |
| 0:45 | ~23:20 | 81% | O Vigia aparece (no mínimo 5 células longe do elevador). |
| 2:00 | 01:30 | 50% | **Zona 4 (a mais funda) apaga.** Legenda "[zumbido elétrico morrendo]". |
| 2:36 | ~02:30 | 35% | **Zona 3 apaga.** |
| 3:12 | 03:36 | 20% | **Emergência:** todas as fluorescentes desligam, as luzes vermelhas acendem (0,5 Hz, fixas com "Reduzir flashes") e os monstros ficam +15% mais rápidos. |
| 4:00 | 05:00 | 0% | **APAGÃO:** até as vermelhas apagam. Restam as placas SAÍDA em Neon (sem luz real) e o elevador. A névoa fecha, os monstros ficam +30% e a audição do Rastejante vai a x1,5. **Buzina: "[buzina do elevador: 60 s]"**. |
| 4:45 | 05:45 | — | **Buzina: "[buzina do elevador: 15 s]"**. A luz laranja do elevador pisca. |
| 4:55 | 05:55 | — | As portas começam a fechar (animação de 5 s). |
| 5:00 | 06:00 | — | **Portas lacradas.** Quem ficou fora é "deixado para trás" (nocaute e perde o que carrega). |

O relógio corre cerca de 34 s por hora de jogo até 05:00, e a última hora dura 60 s. É isso que cria o momento "corrida para o elevador", o clipe-assinatura.

### Um contrato (cerca de 19 min) e a sessão
**Alavanca → Descida (6 s) → Turno 1 → Avaliação (15 s) → Hub (até 45 s de loja) → Turno 2 → … → Turno 3 → DIA DA META.**
- **PROMOVIDO:** bônus de Créditos, e o contrato seguinte tem meta maior e monstros mais agressivos.
- **DEMITIDO:** carimbo vermelho, "rescisão" em Créditos, e a recontratação volta pela metade (seção 5.9).
- **Sessão boa:** 1 a 3 contratos.

### Longo prazo
- Carreira de **45 níveis em 9 cargos** (Estagiário → CEO), com algo novo a cada nível.
- Upgrades permanentes comprados com Créditos.
- **Catálogo de Sucata** (32 entradas) e **Relatórios de Incidente** (bestiário).
- **Meta do Dia**, com seed igual para todos e placar próprio.
- Sequência de **Vale-Refeição** de 7 dias e **Ordens de Serviço** diárias.
- **Memo da Diretoria** semanal, que muda as regras.

---

## 4. Estrutura de partida e servidor

- **4 jogadores por servidor, uma equipe.** Um único place, sem teleporte. O tamanho do servidor e o preenchimento ("preencher ao máximo") são configurados pelo dono no Creator Hub.
- **Hub (a Doca):** doca de carga na chuva, à noite, com luz de sódio quente, a van da RefugoCorp e o prédio com o **elevador de carga**. Dentro do hub ficam:
  - o terminal da loja (CRT verde);
  - o armário de cosméticos;
  - o quadro da meta;
  - o quadro do Memo da Diretoria;
  - o mural dos placares;
  - o mural de Relatórios de Incidente;
  - a **ALAVANCA DE TURNO** e a **alavanca META DO DIA**.
- **Início:**
  - **Solo:** puxou a alavanca, contagem de 3 s.
  - **2 ou mais jogadores:** contagem de 15 s. Se a maioria apertar PRONTO, cai para 3 s.
  - Quem estiver dentro do elevador desce. Quem ficou no hub pode descer depois.
  - A instalação é gerada durante a contagem e a descida (cerca de 250 peças por frame).
- **Escolha de contrato inicial** (na alavanca, quando não há contrato em andamento): **"Contrato 1"** ou **"Recontratação"**. A recontratação começa no contrato `máx(1, ⌊menor recorde entre os presentes ÷ 2⌋)`, para veteranos não recomeçarem sempre do zero.
- **Descida:** as portas fecham, a câmera treme e luzes passam pela janela (6 s). Um fade de 0,3 s esconde o teleporte: o servidor chama `RequestStreamAroundAsync` e move cada personagem com `PivotTo` para o elevador gêmeo dentro da instalação. Não existe um veículo levando os jogadores, o que torna a descida robusta.
- **Entrar atrasado:** quem chega com o turno em andamento aparece no hub e vê o botão **"DESCER"**, válido enquanto faltarem 45 s ou mais para as portas fecharem. Ele entra com bateria cheia e recebe parte do pagamento daquele turno.
- **Sair no meio:** sem punição. A meta de cada turno já se ajusta ao tamanho da equipe (seção 5.9).
- **Com 1 jogador sozinho:**
  - fator de meta 1,0 e instalação de 25 células;
  - 1 Vigia, com velocidade x0,85, e 1 Rastejante;
  - se o Vigia passar 25 s sem conseguir se aproximar, ele "perde o interesse" e se reposiciona longe (evita o solo ficar travado olhando para ele para sempre);
  - **nocaute solo encerra o turno**: o que já foi vendido conta, e o Plano de Saúde permite 1 revive.
- **Servidores privados:** ligados, a 49 Robux por mês.

---

## 5. Sistemas do MVP

Todos os números abaixo ficam em `Config.luau` e podem ser ajustados sem mexer na lógica.

### 5.1 Hub e fluxo de entrada
- Alavanca com votação de pronto, botão DESCER e escolha de contrato inicial.
- Dentro do elevador ficam a **caçamba de venda**, o **carregador de bateria** (5% por segundo) e a cura de **+10 HP por segundo**. O elevador é **zona segura**: monstros não entram na célula do elevador.
- **"Bater o ponto":** se todos os vivos estiverem no elevador, segurar 3 s encerra o turno mais cedo. Isso deixa as sessões ágeis.

### 5.2 Máquina de estados (servidor)
`HUB → CONTAGEM → DESCIDA → TURNO → LACRE → AVALIAÇÃO → INTERVALO → (turno 2, turno 3) → DIA_DA_META → HUB`.

O estado fica em atributos do `Workspace` (`Phase`, `PhaseEndsAt`, `Power`, `Contract`, `Shift`, `Quota`, `Sold`), no mesmo padrão do `Environment.luau`. Os tempos são:

| Fase | Duração |
|---|---|
| Contagem | 15 s (3 s solo) |
| Descida | 6 s |
| Turno | 300 s |
| Lacre | 3 s |
| Avaliação | 15 s |
| Intervalo | até 45 s (pula quando todos estão prontos) |
| Dia da Meta | 12 s |

### 5.3 ENERGIA (o relógio do turno)
- Cai de 100% a 0% em 240 s, e depois vêm 60 s de APAGÃO. Os limiares estão na tabela da seção 3.
- A instalação se divide em **4 zonas por profundidade** (distância em células até o elevador). A mais funda apaga primeiro.
- **Quadro de Força:** há 1 por instalação (2 se forem 3 ou mais jogadores), na zona 2 ou 3.
  - Segurar o botão por 4 s sozinho, ou por 2 s se 2 jogadores seguram juntos.
  - Rende **+12% de energia** (cerca de 29 s) e reacende uma zona apagada.
  - Uso único por quadro e faz ruído de 20 studs.
- **Hora Extra** (produto): +60 s de energia para a equipe, uma vez por turno.

### 5.4 Gerador de instalação
Grade de células de 24 studs, com **18 + 5 × jogadores + 2 × contrato** células (máximo 60). O algoritmo e o visual estão na seção 6.

As regras de jogo são:
- **Orçamento de valor em sucata** = parcela da meta do turno × `(2,4 − 0,1 × (contrato − 1))`, com mínimo de 1,6. No contrato 1 basta coletar cerca de 42% do que existe. No contrato 9, cerca de 62%.
- Cada sala tem uma **faixa livre** de 6 studs entre o centro e cada porta, onde não entra prop. Assim a IA e os jogadores nunca ficam presos.
- **Autoteste:** tudo alcançável e peças ≤ 4.000. Se falhar, tenta `seed+1` até 5 vezes e depois usa uma seed de `Config.KnownGoodSeeds`.

### 5.5 Sucata, bolsos e venda (tudo decidido no servidor)
- **4 bolsos** (upgrade para 5) + **1 item pesado nas mãos**.
- **Velocidade:** cada item pequeno tira 2% (no máximo −10%). Um pesado multiplica por 0,75, não deixa usar a pá e desliga a lanterna de mão.
- **Pegar:** ProximityPrompt com alcance de 10 studs, validado no servidor. O item pequeno sai do mundo e vira dado. O pesado é soldado à frente do personagem pelo servidor (`WeldConstraint`, `Massless`, `CanCollide = false`), sem física controlada pelo cliente.
- **Soltar:** tecla G. Faz ruído (pequeno 16 studs, pesado 40 studs).
- **Nocaute:** tudo cai no chão onde o jogador caiu, e os colegas podem recuperar.
- **Venda:** botão "Vender" na caçamba do elevador vende tudo de uma vez, com o valor saltando na tela. Faz ruído de 35 studs.

**Os 16 tipos de sucata** (valor base em $, multiplicado pela zona e pelo contrato):

| # | pt-BR | en | Tipo | Valor base | Onde aparece |
|---|---|---|---|---|---|
| 1 | Cone de Trânsito | Traffic Cone | bolso | 8–14 | Z1+, comum |
| 2 | Almofada de Pum | Whoopee Cushion | bolso | 10–16 | Z1+, comum |
| 3 | Caneca "Melhor Chefe" | "Best Boss" Mug | bolso | 12–20 | Z1+, comum |
| 4 | Extintor | Fire Extinguisher | bolso | 16–26 | Z1+ |
| 5 | Sino de Latão | Brass Bell | bolso | 18–28 | Z1+ |
| 6 | Cabeça de Manequim | Mannequin Head | bolso | 22–34 | Z2+ |
| 7 | Lâmina de Servidor | Server Blade | bolso | 24–38 | Z2+, sala de servidor |
| 8 | Troféu "Funcionário do Mês" | "Employee of the Month" Trophy | bolso | 30–48 | Z2+, incomum |
| 9 | Cadeira de Escritório | Office Chair | pesado | 28–42 | Z1+ |
| 10 | Micro-ondas | Microwave | pesado | 34–50 | Z2+, copa |
| 11 | Pato de Borracha Gigante | Giant Rubber Duck | pesado | 35–55 | Z2+ |
| 12 | TV de Tubo | CRT TV | pesado | 42–62 | Z2+ |
| 13 | Máquina de Café | Coffee Machine | pesado | 48–72 | Z3+, copa |
| 14 | Caixa Registradora | Cash Register | pesado | 60–90 | Z3+ |
| 15 | Cofre Pequeno | Small Safe | pesado | 85–125 | Z4, raro |
| 16 | Privada de Ouro | Gold Toilet | pesado | 160–240 | Z4, 25% de chance, no máximo 1 |

- **Multiplicador de zona:** Z1 x1,0 · Z2 x1,2 · Z3 x1,45 · Z4 x1,75.
- **Multiplicador de contrato:** `1 + 0,08 × (c − 1)`.
- **Edição Brilhante:** 3% de chance, material Foil com reflexo, valor x2,5. Conta como entrada separada no Catálogo.

### 5.6 Kit do jogador

| Item | Números |
|---|---|
| Vida | 100 HP. Não regenera na instalação; recupera +10 HP/s no elevador. |
| Movimento | Andar 14 · Correr 22 · Agachado 7 (sem ruído; baixa `Humanoid.CameraOffset`, sem animação) |
| Fôlego | 100. Correr gasta 18/s (cerca de 5,5 s). Recupera 20/s depois de 1 s sem correr. Ao zerar, só volta a correr com 35. |
| Lanterna | `SpotLight` com alcance 50, ângulo 45°, brilho 3. Bateria de **150 s ligada** (Bateria I/II/III: 190, 230, 270 s). Só a lanterna **do próprio jogador** projeta sombra. |
| Luz do capacete | `PointLight` com alcance 10 e brilho 0,5, sempre acesa e sem bateria. É o **piso de visibilidade**. |
| Pá | Alcance 7. Atordoa o Rastejante por 3 s (4,5 s com upgrade). Recarga de 4 s (3 s com upgrade). Não afeta jogadores nem o Vigia. |
| Sinalizador | 1 por turno (até 3 com upgrade; extras a 60 CR, no máximo 4). Arremesso de cerca de 30 studs, dura 20 s, luz vermelha com alcance 24. **Segura o Vigia** num raio de 20 studs, **atrai o Rastejante** (ruído de 60) e o atordoa por 3 s se cair a até 6 studs dele. |
| Escâner | Desbloqueado em Trainee, custa 1.000 CR. Mostra o valor da sucata num raio de 40 studs por 5 s. Recarga de 12 s, ruído de 12. |
| Câmera | **Terceira pessoa por padrão** (zoom de 0,5 a 8 studs), com primeira pessoa opcional. O avatar aparece nos clipes. |

**Controles no PC:** E pegar · G soltar · F lanterna · C agachar · Shift correr · Q escâner · T sinalizador · Clique para usar a pá · Z (segurar) para a roda de ping · V para trocar a câmera.

**No celular:** botões grandes de contexto (Pegar/Soltar, Lanterna, Agachar, Correr, Sinalizador, Escâner, Ping, Pá).

### 5.7 Ruído (a audição do Rastejante)
Raio em studs de cada ação:

| Ação | Raio |
|---|---|
| Correr | 30 (um pulso a cada 0,4 s) |
| Andar | 10 |
| Agachado | 0 |
| Aterrissar de um pulo | 18 |
| Soltar item pequeno | 16 |
| Soltar item pesado | 40 |
| Vender | 35 |
| Pá acertando | 25 |
| Escâner | 12 |
| Quadro de Força | 20 |
| Sinalizador aceso | 60, contínuo |

Multiplicador de audição: x1,5 no APAGÃO e na "Semana do Silêncio".

### 5.8 Vida, nocaute, crachá e resgate
- **Nocaute** (HP 0, toque do Vigia ou ficar para trás): o personagem cai, a tela faz fade e aparece "NOCAUTEADO". O jogador **assiste os colegas** até o fim do turno.
- No lugar da queda fica um **Crachá** brilhante: uma peça Neon ciano com o nome do jogador em SurfaceGui. Ele ocupa 1 bolso e tem peso 0.
- **Resgate:** um colega leva o crachá até o elevador e o jogador **volta na hora** dentro do elevador, com 50 HP e 50% de bateria. O resgatador ganha +30 XP.
- **Plano de Saúde** (produto): revive a si mesmo no elevador com 100 HP, 1 vez por turno.
- **Primeiro nocaute grátis:** no primeiro turno da vida do jogador em uma equipe mista, o primeiro nocaute revive sozinho no elevador.
- No turno seguinte, todos descem de novo normalmente.

### 5.9 Meta, salário e Dia da Meta
- **A meta do contrato é a soma das metas de cada turno.** Cada turno contribui com `⅓ × 600 × 1,35^(c−1) × fator(n)`, onde `n` é o número de jogadores no início daquele turno. Fatores: 1 jogador 1,0 · 2 jogadores 1,6 · 3 jogadores 2,1 · 4 jogadores 2,5. Assim a meta acompanha quem realmente jogou cada turno.
  - Exemplos: contrato 1 solo = $600; contrato 1 com 4 jogadores = $1.500; contrato 5 solo ≈ $1.993.
- **Salário do turno (Créditos, "CR"):** sua parte igual do que a equipe vendeu, ou seja `vendido ÷ n × (1 + 0,1 × (n − 1))`. Quem ajuda nunca perde.
- **Anti-AFK:** para receber 100% do salário, o jogador precisa ter pelo menos 1 venda **ou** 60 s fora do elevador no turno. Caso contrário recebe 50%.
- **PROMOVIDO:** cada jogador recebe +100 × c CR, mais 50% do excedente da meta dividido pela equipe, e +150 XP. O contrato seguinte é c+1.
- **DEMITIDO:** "Rescisão" de +50 × c CR e +50 XP. **Nunca paga zero**: salários e XP já ganhos ficam. O próximo contrato é `máx(1, ⌊c/2⌋)`.
- **Contrato "Assistido":** vira assistido se alguém usar Hora Extra ou Plano de Saúde nele. Contratos assistidos não entram no placar "Maior Contrato Limpo".

### 5.10 Treinamento (primeiro turno)
- Vale se a equipe é solo ou só tem novatos: **Vigia desligado**; Rastejante com velocidade de 60%, audição x0,7 e aparecendo só aos 90 s.
- Um **feixe-guia** (Beam no cliente) aponta para a sucata mais próxima e depois para o elevador.
- **5 memorandos do RH** curtos: lanterna, pegar, vender, energia, agachar.
- Em equipe mista, o novato recebe só as dicas e o primeiro nocaute grátis.

### 5.11 Avaliação de Desempenho (15 s)
Uma "folha" branca de memorando do RH mostra valor vendido, viagens, sustos, causa do nocaute e o carimbo **PROMOVIDO** ou **DEMITIDO** (feito com `UIStroke` e rotação). Cada jogador ganha um **título de zoeira**, que pode equipar e que aparece num BillboardGui:

| Título | Critério |
|---|---|
| Funcionário do Mês | Maior valor vendido |
| Estagiário Perdido | Mais tempo longe do elevador sem vender |
| Pé de Chumbo | Mais ruído |
| Coração de Estagiário | Mais sustos ou mais tempo perto de monstro |
| Segurou a Porta | Último a entrar antes do lacre |
| Herói do RH | Resgatou um crachá |
| Olho de Gerente | Mais segundos segurando o Vigia com o olhar |
| Funcionário do Mês: ninguém | A equipe vendeu $0 |

### 5.12 Roda de ping (sem texto livre)
São **8 frases fixas**, e cada pessoa vê a frase **no próprio idioma**:
1. Sucata aqui!
2. Perigo!
3. Vigia aqui, olhem pra ele!
4. Me ajuda (pesado)
5. Voltem pro elevador!
6. Corre!
7. Me segue
8. Valeu!

O marcador fica visível através das paredes por 6 s, com recarga de 1,5 s e no máximo 3 ativos por jogador. O ping "Vigia" gruda no Vigia se ele estiver na mira (é só visual: não conta como "visto"). A voz espacial fica ligada no Creator Hub.

### 5.13 Legendas de áudio
O lançamento é sem sons enviados. Todo acontecimento sonoro vira **legenda estilizada e localizada** acompanhada de tremor de câmera e piscar de luz. Exemplos:
- "[arranhões na parede]"
- "[algo arrastando]"
- "[zumbido elétrico morrendo]"
- "[buzina do elevador: 60 s]"
- "[portas fechando]"
- "[passos molhados]"

Os passos padrão do personagem tocam sozinhos. `Config.Audio` tem espaços vazios para o dono colar IDs da Creator Store depois, sem mexer em código.

### 5.14 Configurações e acessibilidade
Tudo é salvo no perfil do jogador:
- **Brilho** de 0 a 100 (padrão 50), controlando `ExposureCompensation` de −0,3 a +1,0 e o Ambient, **com piso mínimo**.
- **Susto:** Completo ou Suave.
- **Reduzir flashes.**
- **Tremor de câmera** de 0 a 100%.
- **Gráficos leves.**
- **Sensibilidade.**
- **Tamanho das legendas:** P, M ou G.
- **Idioma:** Auto, PT ou EN.
- **Primeira pessoa fixa.**
- **Volume** (para quando houver áudio).

Se o FPS ficar abaixo de 25 por 20 s, o jogo sugere os gráficos leves (herdado do `SettingsUI.luau`).

### 5.15 Meta do Dia (seed diária)
- A **seed é a data em Brasília** (AAAAMMDD, virando às 00:00 BRT). O **mapa é igual para todos**: 30 células fixas no nível do contrato 3.
- É **1 turno de 5 min**.
- **Pontuação** = valor vendido ÷ fator de jogadores.
- Usa o **Kit Padrão**: upgrades desligados, 4 bolsos, 1 sinalizador, sem escâner. **Nenhum produto pago** e nenhum efeito de game pass.
- **1 tentativa ranqueada por dia por jogador.** Pode repetir sem valer ranking.
- Recompensa: 300 CR + 150 XP ao terminar. O top 100 do dia ganha o título "Funcionário do Dia" por 24 h.

### 5.16 Memo da Diretoria (modificador semanal)
Uma lista em `Config.Memos` gira toda segunda às 00:00 BRT. **Na semana 1 de lançamento o memo é neutro**, para medir o jogo base sem distorção.

| Memo | Efeito |
|---|---|
| Corte de Custos | Energia dura 20% menos; sucata vale +25% |
| Semana de Auditoria | +1 Vigia; +20% de Créditos |
| Balanço Trimestral | +40% de sucata no mapa; meta +20% |
| Semana do Silêncio | Rastejante ouve 50% mais longe; agachar é 20% mais rápido |
| **Festa da Firma (Halloween, 26/10 a 02/11)** | Abóboras feitas de peças; sucata sazonal "Abóbora da Diretoria" ($40–70); luz laranja na copa; título sazonal |

### 5.17 Save (reaproveita o `Data.luau`)
- **DataStore:** `BateAMeta_Data_v1`. **Nunca mudar depois de lançar.**
- **Esquema:** `Credits, XP, Level, Upgrades{}, Cosmetics{Owned, Equipped}, Titles{}, Catalog{}, Bestiary{}, Stats{Shifts, Sold, KOs, Rescues, BestContract, BestCleanContract}, Settings{}, Streak{Day, LastClaim}, Orders{Day, List}, DailySeed{LastRankedDay}, FirstJoin, SessionCount, LastDay, FirstContractToday, Flags{TrainingDone, SurveyDone, FavoritePrompted}, Tokens{HoraExtra, PlanoSaude}, ABBucket, Receipts`.

### 5.18 Admin, autoteste e anti-trapaça
- **Comandos** (reaproveitam o `checkAdmin` do `Admin.luau`): `/seed N`, `/regen`, `/skipshift`, `/power N`, `/spawn vigia|rastejante|mimico`, `/monsters off`, `/contract N`, `/credits N`, `/debug` (desenha o grafo de células com Beams).
- **Proteções:**
  - `pcall` em cada subsistema (padrão do `Main.server.luau`);
  - autoteste do gerador na inicialização (50 seeds só no núcleo, sem peças);
  - distância de pegar ≤ 10 studs e venda só dentro do elevador;
  - checagem de velocidade: acima de 30 studs/s sustentados, o jogador volta à última posição válida;
  - relatório de olhar validado (seção 7);
  - limite de frequência em todos os remotes.

---

## 6. Mapa e visual feito só com código

**O conceito visual é "industrial liminar à noite".** A escuridão faz a direção de arte, e peças primitivas meio iluminadas parecem assustadoras, não baratas.

### Geração do mapa (Armazém 13)

**Núcleo em Luau puro** (`FacilityCore.luau`, **sem API do Roblox**, com PRNG próprio `Rng.luau` para ser determinístico no Lune e no Roblox):
1. **Grade:** células de 24 × 24 studs. A célula (0,0) é o poço do elevador.
2. **Árvore geradora por random walk:** a partir do elevador até atingir N células. Depois abre **10 a 15% de conexões extras** (laços), para que perseguições tenham rotas de fuga.
3. **Profundidade e zonas:** uma busca em largura a partir do elevador dá a distância de cada célula, dividida em 4 faixas (Z1 a Z4).
4. **Tipo de sala** por grau e profundidade, entre **12 modelos** (dados em `RoomTemplates.luau`): corredor, curva, T, cruzamento, depósito com prateleiras, escritório com baias, copa, câmara fria, sala de servidor, doca de carga, escada sem saída e poço do elevador.
5. **Pontos de interesse:** sucata (pelo orçamento de valor, com peso maior nas zonas fundas), luminárias, Quadro de Força, spawn de monstros (Z3+, no mínimo 5 células do elevador) e a **seta de SAÍDA** de cada célula, apontando para o pai na árvore da busca. As placas sempre mostram o caminho de volta.
6. **Validação:** busca de alcance em todos os pontos, elevador conectado, faixas livres respeitadas e estimativa de peças ≤ 4.000.
7. **Saída:** uma tabela com o grafo de células, que o A* dos monstros usa.

**Camada de construção** (`FacilityBuilder.luau`, servidor):
- Cria as peças **fora do hub** (deslocamento X = +4.000), cerca de 250 peças por frame.
- **Paredes mescladas:** uma peça por aresta de célula, ou duas mais uma verga quando há vão de porta.
- **Pisos e tetos** fundidos em retângulos gulosos, cerca de 10 peças.
- Destrói tudo depois da avaliação. Cada turno tem seed nova (`seed do contrato + turno`), registrada no log do servidor.

**Exemplo de modelo de sala:**
```lua
{ Id = "copa", MinZone = 1, Weight = 3, Floor = "CeramicTiles", Walls = "Plaster",
  Props = { "mesa", "geladeira", "maquina_cafe", "cartaz" }, Lights = 2, ScrapSlots = 2 }
```

**Passe de desgaste (com seed):**
- 15% das placas de forro faltando (buracos escuros);
- 10% das luminárias quebradas (apagadas ou soltando faísca);
- placas de sujeira (peças escuras com transparência 0,6);
- poças (peças finas de `Glass` com reflexo);
- caixas tombadas e papéis no chão.

**Props:** cada um tem de 3 a 10 peças, montadas pelo `PropBuilder.luau` no padrão do `CritterBuilder.luau`: prateleiras, paletes, mesas, baias, armários, canos (cilindros), dutos, geladeiras e racks com LEDs.

### Iluminação (definida pelo builder no `.rbxlx`)
`Lighting.Technology = Future` e `StreamingEnabled` **não podem ser mudados por script**, então o builder grava os dois direto no arquivo.

O cliente troca de predefinição conforme a área (Hub, Elevador ou Instalação), com tween de 1,5 s:

| Parâmetro | Hub (seguro) | Instalação | Emergência / APAGÃO |
|---|---|---|---|
| ClockTime | 0,5 | 0,5 | 0,5 |
| Ambient | (35, 28, 22), quente | (8, 9, 11), que é o piso | (8, 6, 6) |
| OutdoorAmbient | (40, 35, 45) | (0, 0, 0) | (0, 0, 0) |
| Atmosphere Density / Haze | 0,30 / 1,5 (chuva) | 0,35 / 1,2 | 0,45 / **0,60** no APAGÃO |
| ColorCorrection | Tint (255, 230, 200), Sat −0,05 | Tint (200, 225, 230) azul-petróleo, Sat −0,25, Contraste +0,1 | Tint (255, 190, 190) |
| Bloom | Int 0,6, Size 24, Threshold 0,9 | igual | igual |
| DepthOfField | leve | FarIntensity 0,15, Focus 30, raio 40 | igual |

**Detalhe importante:** com `Atmosphere` presente, `FogStart`/`FogEnd` são ignorados. A "névoa fechando" no APAGÃO é feita **subindo `Atmosphere.Density`** de 0,35 para 0,60.

**Fontes de luz**
- **Fluorescente:** peça Neon de 4 × 0,2 × 1 com `SurfaceLight` (face de baixo, alcance 16, brilho 1,2, ângulo 110°, cor (220, 235, 255)). Pisca por script.
- **Sódio** no hub e na doca: (255, 170, 90).
- **Emergência:** `PointLight` vermelha (255, 40, 30), alcance 14.
- **Placas SAÍDA:** Neon verde com SurfaceGui "SAÍDA ↑" localizada.
- **Olhos do Vigia:** Neon com `PointLight` de alcance 4.
- **Tela CRT:** Neon verde.
- **Orçamento de luz no cliente** (`LightBudget.luau`): só as **16 luminárias mais próximas** ficam ligadas (8 nos gráficos leves). As peças Neon distantes continuam brilhando, então de longe parece aceso. Sombras só na lanterna local e, em gráfico alto, nas 4 luminárias mais próximas.
- **Cone falso da lanterna:** `Beam` sem textura, largura de 0,5 a 12 e transparência de 0,85 a 1.

### Partículas (texturas embutidas, sem envio)
Usam `rbxasset://textures/particles/smoke_main.dds` e `sparkles_main.dds`, as mesmas constantes do `Scenery.luau` e do `WorldFX.luau`:
- **Poeira no feixe:** `LightInfluence = 1`, então **só aparece onde há luz**. Taxa de 6/s, tamanho de 0,05 a 0,1.
- **Vapor** saindo de canos.
- **Faíscas** em luminárias quebradas (rajada a cada 4 a 9 s; mais raras com "Reduzir flashes").
- **Névoa branca** na câmara fria.
- **Chuva no hub:** partículas em volta da câmera, técnica do `Atmos.luau`, com Squash para virar riscos.

### Materiais e cor (só materiais embutidos)
- **Materiais:** Concrete, DiamondPlate, CorrodedMetal, Plaster, Carpet, CeramicTiles, Cardboard, Metal, WoodPlanks, Glass, Asphalt (hub molhado com reflexo leve) e Rubber.
- **Faixas de perigo:** amarelo (230, 190, 40) alternado com preto.
- **Código de cor:** hub e elevador **quentes** = seguro; instalação **fria** = perigo; **vermelho** = tempo acabando.

### Texto como arte (SurfaceGui, montado no cliente no idioma de cada um)
Cartazes, placas, lousas e o letreiro "ARMAZÉM 13, SETOR 7B". Slogans:

| pt-BR | en |
|---|---|
| "Segurança em 1º lugar. Ou 2º." | "Safety first. Or second." |
| "Seu turno. Sua meta." | "Your shift. Your quota." |
| "Sorria, você está sendo avaliado." | "Smile, you're being evaluated." |
| "Aqui somos uma família (sem vínculo empregatício)." | "We're a family here (not legally binding)." |
| "Não olhe para trás. Olhe para a meta." | "Don't look back. Look at the quota." |
| "Proibido correr. O Rastejante agradece." | "No running. The Crawler thanks you." |

### O hub
- Pátio de asfalto molhado com poste de sódio e cerca de peças finas.
- **Van da RefugoCorp:** caixas, faróis com `SpotLight` e logotipo em SurfaceGui.
- Prédio com portas de enrolar e o elevador de carga com luz giratória laranja.
- Banco de descanso com máquina de café, terminal CRT, armários e murais.
- Ao fundo, um **horizonte de cidade** de caixas com janelas Neon acesas ao acaso.

### Efeitos de tela (em código)
- Vinheta com 4 bordas em `UIGradient`.
- Estática VHS com frames e linhas de varredura.
- Pulso de batimento na vinheta perto de monstros.
- Tremor e "punch" de campo de visão com o `Juice.Shake`.
- Dessaturação quando a vida está baixa.

---

## 7. Inimigos e IA

As máquinas de estado seguem o padrão do `Bandits.luau` (estados em texto, `Humanoid` construído por código, `SetStateEnabled(Dead, false)`). A navegação é **A\* próprio no grafo de células** (`GridPath.luau`, puro e testável), sem navmesh. Dentro da célula, o monstro anda em linha reta pela faixa livre até a porta.

### O Vigia (The Watcher): visão
- **Aparência:** 9 studs, SmoothPlastic preto. Pernas de 0,8 × 5 × 0,8, braços longos de 0,6 × 5,5 × 0,6 pendendo até os joelhos, cabeça sem rosto inclinada 12°, dois olhos Neon (200, 220, 255) e um **crachá "SUPERVISOR"** pendurado.
- **Regra central:** **só se move quando ninguém o vê.** "Visto" exige as três condições:
  1. **Cone de visão:** produto escalar ≥ cos 40° entre o olhar do jogador e a direção até o Vigia.
  2. **Raycast livre** da câmera até a cabeça, o tronco ou os pés.
  3. **Iluminado:** dentro do cone da lanterna ligada de algum jogador (≤ 22,5° e ≤ 50 studs), **ou** numa zona com energia, **ou** a até 20 studs de um sinalizador. No APAGÃO, só lanterna e sinalizador contam.
- **Relatório de olhar:** o cliente manda o CFrame da câmera 5 vezes por segundo via `UnreliableRemoteEvent`. O servidor valida que a câmera está a até 12 studs da cabeça. Um relatório com mais de 0,6 s de idade vale "não está vendo". O servidor decide 10 vezes por segundo.
- **Estados:**

| Estado | Comportamento |
|---|---|
| ESPREITA | Parado, olhando para o jogador mais próximo |
| AVANÇO | Não visto por 0,4 s ou mais (janela de reação): anda em **passos de 4 studs a cada 0,2 s** (20 studs/s), com gagueira proposital, sem animação, só `PivotTo` ancorado. Luzes num raio de 20 studs piscam quando ele se move. |
| CONGELADO | Visto: para no lugar. A cabeça gira bruscamente para quem olha. |
| DESINTERESSE | Só no solo: 25 s sem se aproximar, reaparece longe |

- **Ataque:** a até 4 studs, **nocaute instantâneo** (checado por distância no servidor, sem `Touched`). O susto completo tem snap da câmera por 0,6 s com FOV 40 e estática por 0,4 s. O suave é um fade de 0,8 s.
- **Não atordoa.** A pá não faz efeito. Só luz e olhares o seguram.

### O Rastejante (The Crawler): audição
- **Aparência:** corpo baixo de 5 × 1,6 × 6 em CorrodedMetal escuro, 8 pernas finas de 2 segmentos e **uma placa amarela "CUIDADO: PISO MOLHADO" no lugar da cabeça** (duas peças finas em A com SurfaceGui). É engraçado e sinistro ao mesmo tempo, e funciona como thumbnail.
- **As pernas tremem só no cliente:** `Motor6D.Transform` com seno e ruído em cada `RenderStepped`, o que não custa nada ao servidor. Ele deixa **pegadas molhadas** que somem em 20 s e contam por onde passou.
- **Movimento:** `Humanoid:MoveTo` pelos pontos do A\*, com dono de rede no servidor. Se ficar travado (menos de 2 studs em 2 s), pula para o próximo ponto enquanto ninguém o vê.
- **Estados:**

| Estado | Velocidade | Regra |
|---|---|---|
| PATRULHA | 8 | Vaga entre células aleatórias |
| INVESTIGAR | 14 | Vai até o último ruído ouvido (esquece depois de 8 s) |
| CAÇAR | 21 | Ruído contínuo a até 10 studs |
| ATAQUE | — | A até 5 studs: preparo de 0,4 s (as pernas sobem, legenda "[chiado]"), **35 de dano**, recarga de 1,5 s |
| ATORDOADO | 0 | 3 s depois da pá ou do sinalizador perto; imune a novo atordoamento por 6 s |
| RECUAR | 14 | Depois de atordoado, recua 3 células e volta a patrulhar |

- O sinalizador aceso "rouba" a atenção dele por 20 s.

### O Mímico (The Mimic): extra barato
- Parece uma sucata pequena qualquer, mas é levemente descolorido, treme quando ninguém olha, e o escâner mostra "???" no lugar do valor.
- Ao ser pego: 15 de dano, susto (respeitando a configuração), e ele foge 3 células. Se for pego de novo depois disso, vira sucata comum valendo x1,5.
- Chance: 0% no contrato 1, 50% nos contratos 2 e 3, 100% do contrato 4 em diante (no máximo 2).

### Escalada de dificuldade

| Contrato | Velocidade dos monstros | Rastejantes | Vigias | Rastejante surge | Vigia surge |
|---|---|---|---|---|---|
| 1 | x1,00 | 1 (+1 se 3 ou mais jogadores) | 1 | 30 s | 45 s |
| 2 | x1,05 | idem | 1 | 27 s | 40 s |
| 3 | x1,10 | idem | 1 | 24 s | 35 s |
| 4 | x1,15 | +1 (máx. 3) | 1 | 21 s | 30 s |
| 5+ | +0,05 por contrato (teto x1,30) | máx. 3 | 2 | −3 s (mín. 12 s) | −5 s (mín. 20 s) |

Além disso: +15% a 20% de energia e +30% no APAGÃO. O Memo da Diretoria pode somar monstros. No solo, o Vigia anda a x0,85.

---

## 8. Progressão, retenção e social

**Moedas**
- **$ (valor de venda):** vale só para a meta. Some no fim do contrato.
- **Créditos (CR):** moeda permanente. Vêm do salário, dos bônus, das diárias e dos códigos.

**Carreira (XP)**
- Por turno: `0,4 × sua parte do valor vendido`, +40 por sobreviver, +30 por crachá resgatado e +10 por atordoamento (máximo 3).
- Por contrato: PROMOVIDO +150, DEMITIDO +50.
- **"Hora extra dobrada":** 2x XP no primeiro contrato do dia (o dia vira às 00:00 BRT).
- **"Panelinha":** +10% de XP com um amigo do Roblox na equipe.
- **Curva:** para passar do nível n precisa de `250 + 100 × n` XP. São 45 níveis, cerca de 110 mil XP no total. A primeira sessão chega ao nível 4 ou 5, e CEO leva umas 30 horas.
- **Cargos** (5 subníveis de I a V cada):

| Cargo | Níveis |
|---|---|
| Estagiário | 1–5 |
| Trainee | 6–10 |
| Júnior | 11–15 |
| Pleno | 16–20 |
| Sênior | 21–25 |
| Coordenador | 26–30 |
| Gerente | 31–35 |
| Diretor | 36–40 |
| CEO | 41–45 |

- **Recompensa de cada nível:** +50 × nível CR. Em nível ímpar vem um cosmético (cor do feixe, do uniforme ou da luz do capacete). Em cada troca de cargo, um item novo na loja e um título. CEO ganha capacete e feixe dourados e o título "CEO".

**Upgrades permanentes (loja do terminal)**

| Upgrade | Preço (CR) | Efeito | Libera em |
|---|---|---|---|
| Bateria I / II / III | 500 / 1.500 / 3.500 | 190 / 230 / 270 s | Estagiário / Trainee / Sênior |
| Fôlego I / II | 800 / 2.000 | Fôlego 130 / 160 | Estagiário / Júnior |
| Escâner | 1.000 | Libera o escâner | Trainee |
| Kit Sinalizador I / II | 800 / 2.000 | +1 / +2 sinalizadores por turno | Trainee / Júnior |
| Bolso +1 | 2.500 | 5 bolsos | Júnior |
| Pá Reforçada | 1.500 | Atordoa 4,5 s, recarga 3 s | Pleno |
| Botas Silenciosas | 2.500 | Andar faz ruído 5 em vez de 10 | Coordenador |

- **Consumíveis por turno:** Sinalizador extra (60 CR) e Pilha Reserva (80 CR, recarrega 50% da bateria dentro da instalação, 1 por turno).
- **Cosméticos** (cerca de 16 no MVP, todos feitos de peças): capacetes, coletes refletivos, cordões de crachá, cores de feixe e de luz, e títulos. Custam de 300 a 3.000 CR.

**Coleções**
- **Catálogo de Sucata:** 16 itens × 2 variantes = 32 entradas. A cada 8 entradas, +500 CR. Completo, dá o título "Colecionador de Tralha".
- **Relatórios de Incidente:** 3 entradas. Cada uma abre no primeiro encontro com o monstro e ganha um segundo nível de lore depois de 5 fugas. São memorandos corporativos sombrios, só texto.

**Retenção diária e semanal**
- **Vale-Refeição** (sequência de 7 dias, prêmios fixos): 150 / 200 / 250 / 300 / 400 / 500 CR, e no dia 7, **800 CR + cosmético exclusivo que roda todo mês**. Adapta o `Retention.luau`, **removendo a roleta aleatória**.
- **3 Ordens de Serviço por dia**, valendo de 200 a 400 CR cada. Uma é **sempre social**, por exemplo "Termine um turno com outro jogador" ou "Resgate um crachá".
- **Meta do Dia** (seção 5.15) e **Memo da Diretoria** (seção 5.16).
- **Placares globais** (reaproveitam o `Leaderboards.luau`, atualizados a cada 60 s): **Meta do Dia**, **Maior Contrato Limpo** e **Nível de Carreira**.

**Social**
- **Convite com LaunchData:** aparece depois de um turno em que a equipe bateu 100% da parcela ("Traz a equipe amanhã"). Usa `SocialService:PromptGameInvite` com `LaunchData = "crew:<UserId>"`, reaproveitando `ClientMain.client.luau` (cerca da linha 450) e `Social.luau` (cerca da linha 657, que lê `GetJoinData`).
- **Pedido para favoritar:** uma vez, depois do primeiro PROMOVIDO, com `AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)`. O resultado é registrado.
- Roda de pings, voz espacial, salário dividido e Panelinha +10% de XP.
- **Códigos** (`Codes.luau`) divulgados nas redes do dono: CR e cosméticos.

---

## 9. Monetização justa e dentro das regras do Roblox

**Princípios**
- **Nada aleatório é vendido.** Cada produto entrega uma coisa fixa. O `Policy.luau` continua ativo como modo seguro padrão e também controla `AllowedExternalLinkReferences`: só se mencionam Discord ou YouTube na tela se o país permitir.
- Não existe troca entre jogadores, janela de compra automática, cronômetro falso ou produto que dê vantagem em placar.
- Todo ID fica em `Config.DevProducts` / `Config.GamePasses`, e **ID 0 esconde o produto**, como na verificação `id <= 0` do `Products.luau`. Dá para lançar sem produto nenhum.

| Produto | Tipo | Preço sugerido | O que faz | Regras de justiça |
|---|---|---|---|---|
| **Kit Executivo** | Game pass | 149 Robux | Terno de peças, feixe dourado, título "Executivo", 2 cores extras | Só visual |
| **2x Salário** | Game pass | 249 Robux | Dobra os Créditos de salário, bônus e ordens | Não mexe no valor da sucata, na meta, no XP nem nos placares. Desligado na Meta do Dia. |
| **Hora Extra** | Dev product | 25 Robux | +60 s de energia para a equipe no turno atual. Anúncio: "**Fulano pagou hora extra!**" | 1 por turno. Não existe na Meta do Dia. Marca o contrato como Assistido. O botão só aparece no HUD com energia ≤ 30%. |
| **Plano de Saúde** | Dev product | 29 Robux | Revive você no elevador com 100 HP | 1 por turno por jogador, fora da Meta do Dia, marca Assistido. Se o recibo chegar tarde (um colega já resgatou, o turno acabou), **vira ficha guardada** para o próximo nocaute: nunca se perde. |
| **Pizza da Firma** | Dev product | 99 Robux | Festa no hub (confete do `Juice.Confetti`, caixas de pizza de peças, faixa "**Fulano pagou a pizza da firma!**") e **+15% de CR para todos no servidor** por 15 min | Acumula até 60 min. Generosidade pública, sem efeito na meta. |
| Pacotes de CR P / M / G | Dev product | 49 / 149 / 399 Robux | 1.000 / 3.500 / 10.000 CR fixos | **ID 0 no lançamento.** Ligar nas semanas 2 e 3, depois de calibrar a economia. |
| Servidor privado | — | 49 Robux/mês | Para grupos de amigos | — |

- **Cortado de propósito:** o "Bolso Extra" pago do conceito original. Era poder pago que mexe na meta. O +1 bolso virou upgrade que se ganha jogando (2.500 CR).
- **Premium:** Premium Payouts pelo tempo de sessão, mais um cordão "Premium" cosmético (sem poder).
- **Fluxo de compra:** reaproveita o `Products.luau`. O cliente pede `PromptProduct`, o servidor confere com `CanBuy` (turno ativo? já usou? Meta do Dia?) e só então abre a janela. No `ProcessReceipt` o servidor **entrega, salva e só então confirma**, e guarda o recibo para nunca entregar duas vezes (`Data.AddReceipt`).

---

## 10. Idiomas (pt-BR e en)

- **Uma tabela só:** `ReplicatedStorage/Shared/Strings.luau`, com as chaves `pt` e `en`. Todo texto do jogo passa por `Locale.T(chave, args)`: HUD, placas, memorandos, títulos, legendas, pings, nomes de sucata e monstros.
```lua
return {
  pt = { HUD_POWER = "ENERGIA", STAMP_FIRED = "DEMITIDO", PING_WATCHER = "Vigia aqui, olhem pra ele!",
         HORN = "[buzina do elevador: {s} s]", PAID_OVERTIME = "{name} pagou hora extra!" },
  en = { HUD_POWER = "POWER", STAMP_FIRED = "FIRED", PING_WATCHER = "Watcher here, keep eyes on it!",
         HORN = "[elevator horn: {s} s]", PAID_OVERTIME = "{name} paid for overtime!" },
}
```
- **Detecção automática no cliente:** `LocalizationService.RobloxLocaleId` (com `Player.LocaleId` como alternativa). Qualquer valor começando com `pt` vira pt-BR, e o resto vira en. A escolha manual (Auto, PT ou EN) fica salva em `Settings.Language`.
- **O servidor nunca manda frase pronta.** Manda só a chave e os argumentos, por exemplo `Notify:FireClient(p, "HORN", {s = 60})`, e cada cliente monta a frase no próprio idioma. Os SurfaceGui das placas e cartazes são criados **no cliente** a partir do atributo `SignKey` das peças.
- **`AutoLocalize = false`** em todas as ScreenGui, SurfaceGui e BillboardGui, e a captura automática de texto fica desligada no Creator Hub. Isso evita que a tradução automática do Roblox traduza de novo o que já traduzimos.
- **Números:** pt "1.234" e en "1,234" (adaptar o `Format.luau`). O relógio é "05:00" nos dois.
- **Um teste no Lune** garante que `pt` e `en` têm exatamente as mesmas chaves e que todos os `{args}` existem nos dois idiomas. Se faltar uma chave, o jogo cai em en e depois na própria chave, sem travar.
- **Nome, descrição e thumbnails** do jogo são traduzidos à mão pelo dono no Creator Hub (pt-BR e en).

---

## 11. Métricas para testar o público

**Funil de onboarding** (`AnalyticsService:LogOnboardingFunnelStepEvent`, reaproveitando `FUNNEL_STEPS` do `Analytics.luau`):

`1 Joined → 2 LoadedHub → 3 EnteredElevator → 4 EnteredFacility → 5 PickedFirstScrap → 6 SoldFirstScrap → 7 SurvivedShift1 → 8 FinishedContract1 → 9 StartedContract2`

**Eventos personalizados** (`LogCustomEvent`, no máximo 3 campos, sempre com **poucos valores distintos**; a seed vai só para o log do servidor):

| Evento | Valor | Campos |
|---|---|---|
| ShiftEnd | valor vendido | resultado (ok/KO/abandono), jogadores (1–4), grupo A/B |
| KO | segundos no turno | causa (vigia/rastejante/mímico/deixado), contrato (1–5+), turno |
| QuotaDay | contrato | promovido/demitido, jogadores, assistido (s/n) |
| SessionEnd | minutos | turnos jogados (faixa), idioma (pt/en) |
| ReturnVisit | dias desde a primeira entrada | número de sessões (faixa) |
| Survey_PlayAgain | 1 = sim, 0 = não | idioma |
| DailySeed | pontuação | ranqueado (s/n) |
| Social | 1 | tipo (convite enviado, favoritou, ping usado por tipo) |

Também entram os **eventos de economia** (fontes e gastos de "Creditos", com buffer de 60 s já existente) e os **contratos como eventos de progressão**.

**Pesquisa:** depois da avaliação do **2º turno** do jogador, uma única vez: "Jogaria de novo amanhã? [Sim] [Não]".

**A/B** (`Config.Experiments`, com grupo = hash do UserId % 100):
- **Duração do turno** (300 vs 420 s): o grupo é **por servidor** (hash do JobId), porque vale para a equipe inteira.
- **Carência do treinamento** (liga/desliga): o grupo é por jogador.
- Rodar **um experimento de cada vez**, porque o tráfego vai ser baixo.

**Critérios depois de 1 a 2 semanas** (amostra mínima de **1.000 jogadores novos**; o D7 só vale a partir do 8º dia):

| Métrica | Verde (investir mais) | Amarelo (iterar) | Vermelho (repensar) |
|---|---|---|---|
| Funil: EnteredFacility / SoldFirstScrap / SurvivedShift1 / FinishedContract1 | ≥ 85% / 70% / 50% / 25% | 5 a 15 pontos abaixo | mais de 15 pontos abaixo |
| Retenção D1 | ≥ 18% | 12–18% | < 10% |
| Retenção D7 | ≥ 6% | 4–6% | < 3% |
| Sessão média | ≥ 18 min e ≥ 3 turnos | 12–18 min | < 10 min |
| Pesquisa "jogaria amanhã" | ≥ 60% sim | 45–60% | < 45% |
| Turnos com 2 ou mais jogadores | ≥ 35% | 20–35% | < 20% |
| **Faixa etária (Creator Hub > Audiência)** | Maioria 13+ **e** fatia 18+ pelo menos o **dobro** da do Steal a Critter | 13+ é maioria, mas a fatia 18+ está parecida | Perfil igual ao do Steal a Critter |

O Roblox não separa 16-17 anos: use **13-17 vs 18+** como indicador. Compare solo com equipe separadamente pelo campo "jogadores" do ShiftEnd.

---

## 12. Arquitetura técnica

**Estrutura** (novo projeto no mesmo repositório, reaproveitando `tools/rbxlx.py`):
```
bateameta/
  src/ReplicatedStorage/Shared/   src/ServerScriptService/{Main.server.luau, Game/}
  src/StarterPlayer/StarterPlayerScripts/   builder/{build.py, hub.py, lighting.py}
  tests/{run.luau, facility_spec.luau, gridpath_spec.luau, economy_spec.luau, locale_spec.luau}
tools/rbxlx.py (reaproveitado)   tools/publish.py (novo: Open Cloud)
```

**Compartilhados (`ReplicatedStorage/Shared`)**

| Módulo | Responsabilidade |
|---|---|
| `Config.luau` | Todos os números: tempos, meta, monstros, preços, IDs, `KnownGoodSeeds`, `Experiments`, `Memos`, `Audio` |
| `Strings.luau` / `Locale.luau` | Tabela pt/en, `T()`, detecção de idioma |
| `Rng.luau` | PRNG determinístico (PCG32) em Luau puro |
| `FacilityCore.luau` | Gerador puro: grade, árvore, laços, zonas, salas, spawns, setas de SAÍDA, validação |
| `RoomTemplates.luau` | Os 12 modelos de sala em dados |
| `GridPath.luau` | A\* no grafo de células (puro) |
| `Scrap.luau` / `Props.luau` / `PropBuilder.luau` | Definições da sucata e dos props (receitas de peças) e o montador |
| `Ranks.luau` | Cargos, curva de XP, desbloqueios |
| `Cosmetics.luau`, `Memos.luau`, `Format.luau` | Cosméticos de peças, memorandos semanais, números por idioma |

**Servidor (`ServerScriptService/Game`)**

| Módulo | Responsabilidade |
|---|---|
| `Main.server.luau` | Inicialização, `Registry`, `pcall` por subsistema, laço de save a cada 60 s |
| `ShiftDirector` | Máquina de estados do contrato, contagem, descida, lacre, Dia da Meta |
| `FacilityBuilder` | Instancia o núcleo, mescla paredes, controla o orçamento, constrói em vários frames, limpa |
| `SelfCheck` | 50 seeds na inicialização, tentativas e seed reserva |
| `PowerDirector` | Energia, zonas, emergência, APAGÃO, Quadro de Força, Hora Extra |
| `ScrapService` | Spawn, pegar, bolsos, carga pesada soldada, soltar, venda |
| `NoiseService` | Eventos de ruído e raios |
| `MonsterDirector`, `Watcher`, `Crawler`, `Mimic` | Spawn, escalada e IA |
| `PlayerKit` | Lanterna, pá e sinalizador de peças; fôlego; checagens de velocidade |
| `Crew` | Equipe, nocaute, crachá, resgate, espectador, salário, anti-AFK |
| `Payroll` | Créditos, XP, níveis, loja, upgrades, consumíveis |
| `Orders`, `DailySeed`, `Memo` | Diárias, Meta do Dia, modificador semanal |
| `Pings`, `LookReports` | Valida e retransmite pings; recebe e valida o olhar |
| `Experiments` | Grupos A/B e pesquisa |

**Cliente (`StarterPlayerScripts`)**

| Módulo | Responsabilidade |
|---|---|
| `ClientMain.client.luau` | Inicialização enxuta (novo) |
| `HUD` | Energia, relógio, meta, bolsos, fôlego, bateria, vida |
| `Ambience` | Predefinições de iluminação por área e transições |
| `LightBudget` | Liga só as luzes próximas, pisca, apaga zonas, emergência |
| `Flashlight` | Mira local em tempo real; lanterna dos outros interpolada a partir do olhar (5 Hz) |
| `LookReporter` | Envia o CFrame da câmera pelo `UnreliableRemoteEvent` |
| `Captions` | Legendas e sons opcionais de `Config.Audio` |
| `MonsterFX` | Pernas do Rastejante, olhos do Vigia, vinheta, tremor |
| `PingWheel`, `ReviewUI`, `TerminalUI`, `Signage`, `Spectate`, `MobileButtons`, `TutorialHints`, `SurveyUI` | Interfaces |

**O que reaproveitar do Steal a Critter (`/home/user/apggroup/src`)**

| Arquivo | Como reaproveitar |
|---|---|
| `ServerScriptService/Game/Data.luau` | Como está: trava de sessão com `UpdateAsync` (150 s), tentativas, recibos (100), save ao sair e ao fechar. Troca só `defaultData()` e `Config.DataStoreName`. |
| `Game/Products.luau` | Fluxo `CanBuy` → `Prompt` → `processReceipt` (entrega, salva, confirma). Troca os handlers. |
| `Game/Policy.luau` | Como está: modo SAFE por padrão e atributos no jogador. Acrescenta `AllowedExternalLinkReferences`. |
| `Game/Analytics.luau` | `safe()`, buffer de economia de 60 s, funil. Troca os passos e `CURRENCY = "Creditos"`. |
| `Game/Remotes.luau`, `Game/Registry.luau` | Mesmo padrão, mais um `UnreliableRemoteEvent` "Look". |
| `Game/Leaderboards.luau` | 3 placares globais em OrderedDataStore, atualizados a cada 60 s |
| `Game/Retention.luau` | Base da sequência diária (sem a roleta) |
| `Game/Codes.luau`, `Game/Admin.luau` | Tipos de recompensa e datas; `checkAdmin` com novos comandos |
| `Game/Bandits.luau` | Modelo das máquinas de estado dos monstros e do `Humanoid` construído por código |
| `Game/Combat.luau` | `makeTool()` com peças e recarga do golpe (base da pá) |
| `Game/Environment.luau` | Padrão de estado em atributos do Workspace |
| `Game/Tutorial.luau` | Padrão de passo por atributo, para o Treinamento |
| `Game/Social.luau` (≈ linha 657) + `ClientMain.client.luau` (≈ linha 450) | Convite com `LaunchData` e leitura de `GetJoinData` |
| `Game/Season.luau` | Reservado para o passe "Livro de Ponto" (depois do MVP) |
| `Shared/CritterBuilder.luau`, `Shared/Models3D.luau` | Padrão de montar modelos a partir de dados, com um modelo 3D opcional como substituto no futuro |
| `StarterPlayerScripts/UIKit.luau`, `Juice.luau` | Kit de UI (**nova pele**: carvão, âmbar e azul-petróleo; fontes BuilderSans e `Enum.Font.Code` no lugar da FredokaOne); `Shake`, `Confetti`, pops |
| `SettingsUI.luau` | Estrutura das configurações, atributos `LowGfx`/`CameraShake` e sugestão de gráficos leves |
| `Atmos.luau`, `WorldFX.luau`, `Game/Scenery.luau` | Partículas em volta da câmera (chuva) e constantes de textura embutidas |
| `tools/rbxlx.py` | `Inst`, `V3`, `CF`, `Color`, `Token`, atributos, `write_place`, `scripts_from_dir` |
| `tools/place_tools.py` | Útil depois, para trocar só o código se o dono um dia editar o place no Studio |

**Não reaproveitar** (é específico de jogo infantil): Plots, CritterService, Economy, Pets, Mounts, Battle, Minigames, Explore, GiantEgg, Worlds, Hybrids.

**Como o builder Python gera o `.rbxlx`** (`python3 bateameta/builder/build.py`)
1. **Lighting:** `Technology = Future` (via `Token`), `GlobalShadows`, `ClockTime 0,5`, e os filhos `Atmosphere`, `ColorCorrectionEffect`, `BloomEffect` e `DepthOfFieldEffect`.
2. **Workspace:** `StreamingEnabled = true` (raio-alvo de 256, mínimo de 64). O `hub.py` monta a doca, a van, o prédio, o elevador gêmeo do hub, o terminal, as alavancas e os murais, com funções `box/wedge/cyl/fixture/sign` e o atributo `SignKey` nas placas. Limite de 2.500 peças.
3. **StarterPlayer:** `CameraMaxZoomDistance = 8`, `CameraMinZoomDistance = 0,5`, `CharacterWalkSpeed = 14`.
4. **Scripts:** `scripts_from_dir()` para Shared, Game, Main e StarterPlayerScripts.
5. **Grava** `place/BateAMeta-v1.rbxlx`, imprime a contagem de peças e confere se o XML abre.

A instalação **não** vai no arquivo: ela é gerada em tempo real.

**Qualidade sem o Studio**
- `selene bateameta/src` (já instalado em `~/.cargo/bin`).
- Instalar o **Lune** (`cargo install lune --locked` ou o binário do GitHub) e rodar `lune run bateameta/tests/run` com:
  - **5.000 seeds** checando conexão, alcance do elevador e do Quadro de Força, faixas livres e peças ≤ 4.000;
  - A\* sempre achando caminho;
  - contas de meta e salário;
  - paridade das Strings.
- Opcional: checagem de tipos com `luau-lsp analyze` usando as definições do Roblox.

**Publicar sem o Studio.** O `tools/publish.py` faz `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published` com `x-api-key` e `Content-Type: application/xml`. O dono cria a chave de API no Creator Hub com permissão de escrita de places. Criar a experiência vazia é feito uma vez só pelo Creator Hub.

No Creator Hub o dono também:
- define o servidor de 4 jogadores;
- liga voz espacial e servidores privados;
- preenche o questionário de maturidade;
- cria os produtos e cola os IDs em `Config`;
- traduz nome e descrição;
- tira screenshots no cliente para ícone e thumbnails.

**Checklist do teste privado** (dono + 2 amigos, 15 min, celular e PC):
1. O jogo abre e o idioma é detectado.
2. A alavanca solo funciona.
3. A descida teleporta todos.
4. Pegar e vender funcionam.
5. As zonas apagam, as buzinas tocam e as portas fecham.
6. O Vigia congela quando alguém olha.
7. O Rastejante segue o ruído.
8. O crachá resgata.
9. A Avaliação e o Dia da Meta aparecem.
10. O save persiste ao voltar.
11. O FPS no celular fica ≥ 30.

**Cronograma sugerido**
- **30/09 a 06/10:** builder e hub, FacilityCore com testes no Lune, FacilityBuilder, máquina de estados.
- **07/10 a 13/10:** sucata e venda, kit, energia, Vigia, Rastejante, nocaute e crachá, save.
- **14/10 a 20/10:** UI e Strings, Avaliação, loja, analytics, produtos, configurações, Meta do Dia, **teste privado em 18 e 19/10**.
- **Lançamento público por volta de 21/10.** Memo Festa da Firma de 26/10 a 02/11. Leitura de D1 e D7 em 29/10 e 05/11.

---

## 13. Fora do MVP

- **v1.1 (2 a 3 semanas depois do lançamento):**
  - **Comunicado do RH:** terceira ameaça feita só de UI e regras. Um memorando define por 45 s uma regra que o servidor consegue checar ("não corra", "lanternas desligadas", "não carregue pesado"). Alguns memorandos são falsos e têm um detalhe errado. Quebrar uma regra verdadeira faz um Vigia surgir perto.
  - Bastões de luz que seguram o Vigia.
  - Placar semanal.
  - Estátua do **Funcionário da Semana**, com o avatar real do primeiro colocado via `CreateHumanoidModelFromDescription`.
  - Passe de temporada **"Livro de Ponto"** (sobre o `Season.luau`), com trilha grátis e paga só de cosméticos.
  - **Vínculo de Equipe** (bônus por jogar sempre com os mesmos amigos).
- **v1.2:**
  - Segundo tema, **"Shopping Abandonado"**.
  - **O Novato:** mímico que usa o avatar de um colega de equipe.
  - Carga frágil que perde valor quando bate (calculada no servidor) e itens para carregar em 2 pessoas.
  - Porta trancada com pé de cabra.
- **v2 e eventos:**
  - **Linha Zero** como evento ou tema de metrô liminar, com o gancho "as portas estão fechando".
  - Lobby com matchmaking por teleporte quando houver mais gente online.
  - **Monstros que reagem à voz** (`AudioAnalyzer`, opcional).
  - Walkie-talkie com a nova Audio API.
  - Modo Supervisor para criadores de conteúdo.
  - Notificações (`ExperienceNotificationService`).
  - Anúncios com recompensa, se a conta for elegível.
  - Sons da Creator Store preenchidos em `Config.Audio`.

---

## 14. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Horror sem áudio fica fraco | Legendas localizadas, tremor, piscar de luz e vinheta de batimento. Passos padrão tocam sozinhos. `Config.Audio` para o dono colar IDs na semana 1 sem código. Medir se a versão silenciosa segura a sessão. |
| Não há como garantir 16+ (Moderada deixa entrar 13+, e menores com permissão dos pais) | Título, thumbnail e descrição para público mais velho. Tom e dificuldade adultos. Ler a faixa etária no Creator Hub comparando com o Steal a Critter. Usar segmentação por idade nos anúncios, se existir. |
| Bugs de geração procedural que não se veem sem o Studio | Núcleo puro testado com 5.000 seeds no Lune. Autoteste na inicialização com seed reserva. Faixas livres para a IA. `/debug` e `/regen`. |
| Pouca gente online, servidores vazios | Balanceamento pensado primeiro para 1 jogador, fator de meta, Treinamento, turnos de 5 min, DESCER no meio do turno, preenchimento máximo do servidor, funis solo e equipe separados. |
| Celular fraco com Future lighting | Orçamento de 16 luzes (8 no leve), sombra só na lanterna local, peças ≤ 4.000, paredes mescladas, StreamingEnabled, gráficos leves, instalação destruída a cada turno. O próprio Roblox rebaixa a iluminação em aparelhos fracos. |
| Escuro demais em tela de celular | Brilho com piso mínimo, luz do capacete sempre acesa, hub e elevador bem iluminados, sinais visuais (não só sonoros) de cada monstro. |
| Vigia injusto ou confuso | Janela de reação de 0,4 s, spawn a 5 ou mais células, "desinteresse" no solo, sinalizador segura o Vigia, regra explicada no Treinamento e no Relatório de Incidente. |
| Trapaça (olhar falso, teleporte, venda falsa) | Tudo decidido no servidor: alcance, venda só no elevador, checagem de velocidade, olhar validado contra a cabeça e raycast. O jogo é cooperativo contra o ambiente, então o impacto é pequeno. |
| Perder o contrato ao ser demitido faz o jogador desistir | "Nunca zero" (salários, XP e rescisão ficam), recontratação pela metade, escolha de contrato inicial na alavanca. |
| Monstros de primitivas parecendo bobos na luz | Silhuetas escuras com olhos Neon, nunca aparecem no hub claro, cone de lanterna estreito, movimento com "gagueira" em vez de animação lisa. |
| Classificação acima de Moderada | Sem sangue, sustos curtos com modo suave, questionário respondido com honestidade e revisto a cada monstro ou tema novo. |
| Gênero lotado (DOORS, Pressure, os parecidos com Lethal Company) | Humor corporativo brasileiro, APAGÃO como relógio visual, a regra do Vigia, a Avaliação para prints, o Rastejante com "PISO MOLHADO" na thumbnail. |
| Excesso de escopo | Lançar com **1 tema, 2 monstros e o Mímico só se sobrar tempo**. Tudo da seção 13 espera os dados de D1 e D7. |
| Economia mal calibrada | Pacotes de CR com ID 0 no lançamento. Números em `Config`. Eventos de economia para ver de onde vem e para onde vai cada Crédito. |