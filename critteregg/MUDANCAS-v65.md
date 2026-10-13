# Steal a Critter Egg - v65 (13/10/2026)

Feito em cima do **StealACritterEgg-v64.rbxl** que você mandou.

Arquivo novo: `place/StealACritterEgg-v65.rbxl`. Mudou só o código dos scripts: mapa, modelos 3D e configurações estão iguais ao v64.

## Como colocar no jogo

1. Abra o `StealACritterEgg-v65.rbxl` no Studio. Ou, no seu jeito de sempre, copie a pasta `src` desta versão por cima da sua e ligue o Rojo.
2. Aperte **Play** e teste a lista do fim deste arquivo.
3. **File > Publish to Roblox**.

---

## 1. Segurança e salvamento (o mais importante)

- **Roubo com teleporte:** antes, quem usava trapaça pegava um ovo da última zona e se teletransportava direto para casa. Agora o servidor acompanha o ovo da pegada até a SAFE ZONE. Se o jogador sumir do mapa, andar mais rápido do que a velocidade que o jogo deu ou der um salto impossível, o ovo volta para o ninho. Quem joga normal não percebe nada.
- **Ovo "refém":** ninguém segura um ovo por mais de 3 minutos (`Config.MaxCarrySeconds`).
- **Sair e voltar rápido** para o mesmo servidor apagava o progresso. Agora o jogo espera o save da saída terminar antes de carregar.
- **Outro servidor ainda salvando:** antes o jogo "tomava" os dados depois de ~9 s e o save do outro servidor se perdia. Agora espera até ~20 s e só toma se o outro servidor caiu.
- **Save que não carregou:** antes a criança jogava sem salvar e perdia tudo, até compras. Agora o jogo pede para entrar de novo (o progresso dela fica guardado).
- **Ao fechar o servidor,** o jogo espera os saves terminarem de verdade.
- **Baú grátis:** a checagem do grupo travava o servidor inteiro por um instante (guardiões e entregas paravam). Também dava para abrir o baú 2 ou 3 vezes seguidas. Os dois foram corrigidos. O convite do grupo aparece no máximo a cada 10 min.
- **Presentes por tempo jogado:** zeravam a cada entrada, então sair e voltar rendia mais que jogar. Agora o tempo fica salvo e só zera depois de 3 horas fora do jogo (`Config.GiftResetHours`).
- **Botões que "não funcionavam":** existia um limite único para todos os botões, que engolia cliques. Agora cada ação tem o seu.

## 2. Robux

- **Compra só é confirmada depois de salvar.** Antes, se o servidor caísse logo depois da compra, a criança pagava e perdia o item.
- **Passes ficam salvos.** Se a Roblox demorar a responder, o passe continua valendo.
- **A loja mostra o preço real da Roblox,** que muda por país com o Regional Pricing.
- **Nada pago tem prêmio sorteado.** O Starter Pack agora dá $50K + 25K de velocidade + 2x Cash por 30 min (sem ovo sorteado), e o "Lucky Egg" saiu. Motivo: item pago com sorteio exige mostrar as chances e usar o PolicyService, e no Brasil o ECA Digital proíbe para menores de 18.
- **"Hatch All Now"** não deixa mais pagar se não tem ovo crescendo.
- **Ofertas mais leves:**
  - no máximo 1 oferta a cada 10 min;
  - o Starter só aparece depois do 3º ovo chocado;
  - a oferta de velocidade depois de ser pego aparece 1 vez por sessão e só depois de 5 min de jogo.
- **Pacotes de velocidade** agora dizem "resets on Rebirth".

> ⚠️ **Você precisa conferir:** os Ids que estão no `Config` (2x Cash, VIP, Speed1-3, Hatch All, Starter, 2x Cash Boost) têm que ser **deste jogo**. Abra Creator Hub > Steal a Critter Egg > Monetization. Se algum item não estiver lá (por exemplo, se veio do jogo antigo), crie de novo e cole o número novo. Desde 30/05/2026 a Roblox não vende mais itens de outro jogo.

## 3. Nada idêntico ao Steal an Egg

As zonas tinham **os mesmos nomes, a mesma ordem e exatamente os mesmos números** do Steal an Egg (Forest 0, Lake 900, Desert 10K...). Mecânica parecida tudo bem; nome + número idênticos dão risco de denúncia. Agora:

| Zona | Antes | Agora |
|---|---|---|
| 1 | Forest 0 | Sprout Woods 0 |
| 2 | Lake 900 | Puddle Pond 800 |
| 3 | Desert 10K | Sunny Sands 9K |
| 4 | Jungle 40K | Wild Vines 36K |
| 5 | Snow 170K | Frosty Peaks 150K |
| 6 | Volcano 700K | Lava Land 620K |
| 7 | Abyss Ocean 2.5M | Deep Reef 2.2M |
| 8 | Prehistoric 18M | Dino Valley 16M |
| 9 | Cosmic 700M | Starry Space 620M |
| 10 | Cherry Blossom 2.5B | Blossom Grove 2.2B |
| 11 | Titan Temple 7B | Robo Ruins 6.2B |
| 12 | Angels & Heroes 20B | Hero Heights 18B |

A curva é a mesma, uns 11% mais baixa: o começo fica um pouco mais fácil. Também mudaram:

- os rastros "Grey Trail" e "Divine Trail x14", que viraram "Pebble Trail" e "Starlight Trail x15";
- o passe "X2 GROWTH SPEED!", que virou "2x Hatch Speed";
- o "+150K Speed", que virou "+175K Speed";
- "Instant Hatch", que virou "Hatch All Now";
- a noite agora faz os ovos crescerem x25.

## 4. PvP mais justo para crianças

- **Quem não carrega ovo** só leva um empurrãozinho do taco, sem ficar atordoado. O taco serve para derrubar ovos.
- **Depois de um atordoamento,** 1,5 s sem poder ser atordoado de novo. Antes, um taco de zona alta prendia a pessoa para sempre.
- **Na SAFE ZONE ninguém bate.** Antes dava para ficar acampado na linha.
- **Armadilha:**
  - 3 s em vez de 5;
  - não pode a menos de 30 studs da SAFE ZONE;
  - pega quem passa correndo rápido (antes "pulava" a armadilha).
- **Guardião:** quem andava colado na parede nunca era pego. Corrigido.
- **Ovo solto** não fica mais preso no chão para sempre.

## 5. Novidades

### 🎉 Atualização da semana + FESTÃO
- **Contagem na tela:** "UPDATE in 2d 5h".
- **Na hora da atualização começa o FESTÃO,** sozinho, em todos os servidores (você não precisa estar online): ovos raros x5, ovo dourado a cada 3 min e ovos crescendo x2, por 30 min.
- **Aviso** 1 hora antes.
- **Para mudar dia e hora:** `Config.Update`. O padrão é **sábado, 14h de Brasília**. Solte suas atualizações sempre nesse horário.

### 🎟️ Códigos
- **Botão "Codes"** à esquerda, em cima do Rebirth.
- **A lista fica só no servidor:** em `Game.luau`, procure `local CODES`. Cada jogador usa cada código uma vez.
- **Códigos que já vêm:**
  - `CRITTER` dá 10 min de renda + 1K de velocidade;
  - `UPDATE` dá 2x Cash por 15 min;
  - `THANKYOU` dá 20 min de renda;
  - `SPOOKY` dá um ovo Raro+ e 10 doces (vale até o fim do Halloween).
- **Dica:** um código novo a cada sábado e um para cada YouTuber.

### 🎃 Evento de Halloween (17/10 a 02/11)
- **Ovo de Abóbora** a cada 4 min, numa zona que dá para alcançar, com os bichinhos de Halloween (Pumpkino Pinguino, Ghostini Toastini, Vampiro Pepperoni...).
- **Mutação Spooky** (x3 de dinheiro, roxinha com brilho de abóbora), só durante o evento.
- **Doces 🍬:** cada ovo roubado vale 1 e o Ovo de Abóbora vale 5.
- **Loja de Doces** (botão "Candy"), sempre com o mesmo bichinho, sem sorteio:
  - Pumpkino Pinguino: 15 doces;
  - Pumpkat: 40 doces;
  - Batwing: 120 doces;
  - Spooky Vampiro Pepperoni: 300 doces.
- **Abóboras** decorando o hub.
- **No Studio o evento já aparece ligado** para você testar (`Config.Halloween.TestInStudio`).
- **Para mudar datas, chances e loja:** `Config.Halloween`.

## Como testar no Studio (Play)

1. **Roubar um ovo e levar para casa:** tem que funcionar normal.
2. **Halloween:**
   - aparece o aviso, as abóboras no hub e o botão "Candy";
   - roube um ovo e ganhe 1 doce;
   - espere 1 min pelo Ovo de Abóbora.
3. **Codes:** digite `critter`. Usar de novo avisa que você já usou.
4. **Contagem do Festão** no canto: "UPDATE in ...". Para testar o Festão, mude `Config.Update.WeekDay` e `HourBR` para daqui a 2 minutos.
5. **Taco:**
   - em quem não carrega ovo, só empurra;
   - em quem carrega, derruba o ovo;
   - na SAFE ZONE, não bate.
6. **Presentes:** saia e volte. O tempo dos presentes continua de onde parou.

## Para o Claude (ferramentas)
- `tools/build_place.py`: coloca o código de `src` dentro do `.rbxl` (só o Source dos scripts muda).
- `tests/config_spec.luau`: testes das contas do Config, que rodam com o Lune.
