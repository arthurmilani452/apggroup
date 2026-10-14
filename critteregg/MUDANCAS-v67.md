# Steal a Critter Egg - v67 (14/10/2026)

Feito em cima da **v66.1**, com tudo dela junto.

Arquivo novo: `place/StealACritterEgg-v67.rbxl`. Mudou só o código dos scripts: mapa, modelos 3D e configurações do Studio estão iguais.

Nenhuma das melhorias deixa roubar do cercado dos outros, e nada pago tem prêmio sorteado.

## Como colocar no jogo
1. Abra o `StealACritterEgg-v67.rbxl` no Studio.
2. Aperte **Play** e teste a lista do fim deste arquivo (10 minutos).
3. **File > Publish to Roblox** por cima do jogo e reinicie os servidores. O passo a passo está no `COMO-PUBLICAR.md`.

---

## 1. Primeiros minutos e "Próxima Meta" (para a criança não desistir)
- **Começo calmo:** o Prêmio Diário e a faixa do Halloween não pulam mais na cara de quem acabou de entrar.
  - O Diário abre sozinho uns 4 s depois do 1º bichinho chocado.
  - A faixa do Halloween aparece depois do 1º ovo entregue.
  - Quem já jogava antes continua vendo tudo na entrada, como sempre.
- **1º ovo surpresa:** o 1º ovo que a criança entrega sai **Raro ou melhor**, com a faixa "SURPRESA! Seu primeiro ovo é RARO!".
- **Escudo da noite:** nos 3 primeiros ovos, se a noite chegar enquanto o novato carrega um ovo da zona 1, ele fica com o ovo em vez de perder.
- **Próxima Meta sem fim:** antes, depois de uns 5 minutos de jogo, a tela parava de dizer o que fazer. Agora a linha de baixo sempre tem uma meta com seta, por exemplo:
  - "Cercado cheio! Melhore ($X) ou VENDA";
  - "Pegue 3 prêmios do Índice" (o botão Índice balança);
  - "Ovo dourado em Sunny Sands!";
  - "Roube um ovo de PUDDLE POND - 12x dinheiro!";
  - "🎯 Treine até 1K de velocidade → PUDDLE POND (62%)";
  - "🎯 Rebirth 34%".

  A linha some quando uma janela está aberta, em cima da esteira e na hora de chocar.
- **Relógio de eventos:** agora mostra o Ovo Dourado ativo, a contagem do Ovo de Abóbora e o Halloween. Ele gira até 4 itens, e o Bicho da Semana aparece sempre nos dias de semana (antes nunca aparecia).
- **Favoritar:** depois de 8 min de jogo e de uma conquista (zona nova ou Lendário), o jogo pede **uma vez** para favoritar. Não dá prêmio, porque a Roblox não deixa.
- **Celular:** guardiões dormindo brilham menos, o que é mais leve.

## 2. Prêmio Diário 2.0
- **O dia vira à meia-noite do Brasil** (antes virava às 21h). O fim de semana 2x também segue o horário de Brasília.
- **Escudo de sequência 🛡:** perdeu 1 dia? O escudo salva a sequência (até 2 guardados).
- **Calendário de 28 dias:** conta os dias em que a criança pegou o prêmio, mesmo que não seja seguido:

| Dia | Prêmio |
|---|---|
| 3 | 2x Money por 15 min |
| 7 | **Calendar Cat** (Épico exclusivo) |
| 14 | **Sunny Pup** (Lendário exclusivo) |
| 21 | 2x Money + 2x esteira por 30 min + título "Calendar Champ" |
| 28 | **Crown Critter** (Mítico exclusivo) |

  Na 2ª volta, o bichinho que você já tem vira **Dourado**. Se ele já é Dourado, vira dinheiro (30 min de renda). Assim o cercado não enche de repetidos.
- **Bichinhos exclusivos 📅🤝:**
  - não podem ser vendidos nem fundidos;
  - continuam depois do rebirth;
  - acompanham a zona onde você está.

  Se o cercado estiver cheio, o bichinho espera e entra sozinho quando abrir espaço.

## 3. Mais emoção
- **Chocar animado no celular:** o ovo treme, cresce, brilha, racha e explode em cascas. Antes isso era feito no servidor e dava um "engasgo" no jogo de todo mundo. Agora quem anima é o celular de cada um.
- **POR UM TRIZ!:** escapou com o guardião quase pegando (a 8 studs ou mais da linha segura)? Ganha 1 min de renda e +1 na sequência de roubos. Só conta onde o guardião ainda é perigoso para você, então não dá para ganhar sem risco numa zona fácil.
- **SALVO!:** um carimbo verde aparece quando você entrega o ovo.
- **Câmera:** abre um pouco enquanto você carrega um ovo e dá um "soco" de zoom ao revelar um bicho Raro ou melhor.
- **Perseguição:** com o guardião perto, toca um "tum-tum" de coração e a borda da tela fica vermelha.
- **Menos alarme:** o aviso grande para o servidor todo só aparece para coisas realmente raras (Mítico ou melhor, Gigante, Arco-íris, dourado, abóbora), no máximo 1 a cada 20 s. O Admin Abuse sempre aparece.

## 4. Convide amigos (escada de prêmios)

| Amigos | Prêmio |
|---|---|
| 1 | Friendship Trail (x1.5) |
| 3 | **Pal Pup** (Lendário exclusivo) |
| 5 | título **Squad Leader** + placa dourada no cercado |
| 10 | **Party Panda** (Mítico exclusivo) |

- O amigo conta quando joga 5 min e rouba 1 ovo. Cada amigo conta 1 vez só.
- **Convidou e saiu do jogo?** O crédito fica guardado e chega quando você voltar.
- **"📸 Mostrar pros amigos":** ao chocar um Lendário ou melhor, aparece um botão para convidar amigos. Quem entra pelo convite cai no servidor e a seta leva até o cercado do amigo.

> Convites só funcionam no jogo publicado, no celular. No Studio não dá para testar.

## 5. Estrelas de coleção ⭐
Cada zona tem 3 estrelas no Índice:

| Estrela | O que precisa | Prêmio |
|---|---|---|
| ★1 | todos os Comuns, Incomuns e Raros da zona | libera o **taco da zona** (antes precisava da zona INTEIRA, quase impossível) |
| ★2 | todos os Épicos e Lendários | 10 min de renda |
| ★3 | todos os Míticos e Secretos | 30 min de renda + aviso para o servidor |

- **Colecionador I a VII:** quanto mais bichinhos descobertos, maior o nível. Cada nível dá +3% de renda.
- O Índice mostra as estrelas de cada zona e uma barra de coleção. Quando faltam 2 ou menos, os cartões que faltam ficam dourados, com uma dica de onde achar.

## 6. Etiqueta em cima da cabeça
- **Linha 1:** [VIP], 🔄 rebirths, 🔥 sequência de roubos (5+), 👑, 📅, 🤝.
- **Linha 2:** o **título** mais alto que a criança ganhou, na cor dele. Exemplos: Wild Vines Runner, Egg Thief, Master Thief, Collector III, Calendar Champ, Squad Leader, Rebirth Royalty.
- **Linha 3:** o melhor bichinho que ela já teve (Raro ou melhor).
- **👑 Rei do Servidor:** quem tem a maior renda no servidor (com 2 jogadores ou mais) ganha a coroa.
- O título também aparece no chat.
- Antes a etiqueta só mudava quando o personagem renascia; agora muda na hora.

## 7. Bichinho Parceiro 🐾
- O seu melhor bichinho anda atrás de você pelo mapa, pulando e comemorando quando você rouba ou choca algo raro. **Todo mundo vê.**
- Em Pets, toque no 🐾 de qualquer bicho para ele virar o parceiro.
- Ele é só de enfeite (não dá dinheiro a mais) e fica leve no celular: longe, ele simplifica, e muito longe, ele some.

## 8. Mapa mais leve
O mesmo visual de xadrez com cerca de **36% menos peças** no mapa (de ~12.400 para ~7.950):
- **Paredes e chão:** cada parede e cada chão virou 1 peça grande mais os quadradinhos da outra cor, finos.
- **Ninhos:** palha com 5 pedaços em vez de 10.
- **Esqueletos e pilares:** no máximo 2 esqueletos de dino e 3 pilares grandes por zona.
- **Efeitos dos modelos do Toolbox:**
  - no máximo 1 efeito por modelo, com menos partículas;
  - sem fumaça;
  - sombra só nos modelos grandes.

No Studio, o Output mostra `[World] BaseParts no mapa: N`.

---

## O que você faz no Creator Hub (tudo opcional)
- **Badges:** crie em Creations > Steal a Critter Egg > Engagement > Badges > Create a Badge. Cole os números em `Config.Badges` (no `Config.luau`):
  - 1 badge para cada nível de Colecionador (I a VII);
  - 1 para cada título.

  Badge aparece no perfil da criança, e isso ajuda o jogo a ser descoberto.
- **Grupo e descrição:** poste "Dia 28 = Crown Critter grátis" e "Convide 3 amigos = Pal Pup".
- **Analytics:** depois de 1 a 2 semanas, compare:
  - Retention D1/D7;
  - o funil Onboarding (novo passo "First Index claim");
  - os Custom Events `CloseCall`, `StreakSaverUsed`, `CalendarDay`, `IndexStar` e `CollectorLevel`.

## Como testar no Studio (10 minutos)
1. **Novato:** entre com um save novo.
   - O Diário não abre na entrada.
   - O 1º ovo entregue sai Raro.
   - Depois do 1º bichinho chocado, o Diário abre sozinho.
2. **Meta:** encha o cercado, pegue prêmio do Índice e corra para a esteira. A linha de baixo deve mudar de meta e a seta deve apontar certo.
3. **Diário:** Menu > Diário mostra o calendário "Dia N/28" e o 🛡.
4. **Chocar:** choque 3 ovos. Eles tremem, racham e explodem um depois do outro.
5. **POR UM TRIZ:** fuja com o guardião bem perto (longe da linha segura). Aparece "POR UM TRIZ!" e você ganha o bônus.
6. **Parceiro:** o bichinho anda atrás de você. Em Pets, toque no 🐾 de outro bicho e veja ele trocar.
7. **Etiqueta:** veja título, 🔥 e melhor bichinho em cima da cabeça. Com 2 jogadores (Test > Clients and Servers), um deles ganha a 👑.
8. **Índice:** as estrelas aparecem nas abas das zonas, e o taco libera com ★1.
9. **Mapa:** ande pelas zonas 1, 6, 8 e 11. O xadrez deve estar igual e ninguém atravessa parede. Se algum quadradinho escuro piscar de longe, avise.
10. **Celular:** em Test > Device (Android pequeno), nada pode ficar em cima do analógico, do pulo ou da barra do taco.
11. **Output:** nenhuma linha vermelha.
