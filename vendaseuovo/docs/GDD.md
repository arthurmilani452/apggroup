# GDD: Venda Seu Ovo (Sell Your Egg)

**Versão:** 0.1 (rascunho do MVP) · **Data:** 05/10/2026 · **Plataforma:** Roblox (PC, celular, console) · **Produção:** em código, como o Zona Zero (builder Python gera o `.rbxlx`, scripts em Luau).

---

## 1. Resumo

| Item | Definição |
|---|---|
| **Nome (pt-BR)** | Venda Seu Ovo |
| **Nome (en)** | Sell Your Egg |
| **Gênero** | Tycoon de barraquinha (família "Lemonade Stand") + roubo entre jogadores (família "Steal a…") |
| **Público-alvo** | 8 a 14 anos, o mesmo do Steal a Critter |
| **Jogadores por servidor** | 8 (um mercado com 8 barracas) |
| **Sessão-alvo** | 15 a 25 min, com ganho offline pequeno para trazer o jogador de volta |
| **Classificação-alvo** | Mínima / Leve |

**Pitch.** Você ganhou uma barraquinha caindo aos pedaços na Feira do Galinheiro. No quintal atrás dela, suas galinhas botam ovos. Você recolhe, prepara (cru, cozido, omelete, bolo…), coloca na vitrine e **escolhe o preço**. Os clientes passam, olham a placa e decidem se compram. Barato demais e você não lucra. Caro demais e ninguém compra. Enquanto isso, os vizinhos de barraca estão de olho na sua **Galinha Dourada**…

## 2. Por que não é um "Steal a Critter 2"

| | Steal a Critter | Venda Seu Ovo |
|---|---|---|
| Centro do jogo | Chocar e colecionar bichinhos | **Gerir a barraca**: preparar, pôr preço, atender a fila |
| De onde vem o dinheiro | Bichinho parado na base | **Venda para clientes NPC** (depende do preço, do clima e da reputação) |
| O que se rouba | O bichinho | **Galinhas** (o que gera dinheiro) e **cestas de ovos** (roubo rápido) |
| Decisão principal | Qual ovo comprar | **Que preço cobrar agora** |

Regra de design: **o jogador precisa ganhar mais vendendo bem do que roubando.** O roubo é o tempero.

## 3. Ciclos de jogo

**Ciclo curto (30 s):** recolher os ovos do quintal → colocar na cozinha → levar o produto pronto para a vitrine → os clientes compram → $.

**Ciclo médio (5 min):** gastar o $ em galinha nova, upgrade da cozinha, receita nova, vitrine maior, decoração (que dá reputação) e defesa.

**Ciclo longo (dias):** desbloquear raças de galinha raras, subir o nível da barraca (Barraquinha → Quiosque → Lanchonete → Confeitaria → Rede de Ovos), entrar no ranking do servidor e do mundo, e completar a coleção do Livro de Receitas.

## 4. Sistemas

### 4.1 Galinhas (geradoras)
- Cada galinha bota 1 ovo a cada X segundos no quintal (ninho). O quintal tem um limite de vagas que dá para melhorar.
- Raridades: Caipira, Pintada, Prateada, Dourada, Arco-íris, Cósmica. As raras botam ovos mais caros e mais rápido.
- As galinhas são compradas na **Carroça do Granjeiro**, que passa pelo mercado a cada 2 min com um estoque aleatório. Todo mundo vê a carroça, o que cria disputa e momento de clipe.
- **Não existe compra paga de item aleatório.** Robux só compram coisas fixas (veja a seção 7).

### 4.2 Cozinha (transformação)
| Receita | Ingrediente | Tempo | Valor base |
|---|---|---|---|
| Ovo cru | 1 ovo | 0 s | 1× |
| Ovo cozido | 1 ovo | 5 s | 2× |
| Omelete | 2 ovos | 10 s | 5× |
| Ovo de chocolate | 2 ovos + cacau | 20 s | 12× |
| Bolo | 4 ovos | 40 s | 30× |

O valor também é multiplicado pela raridade do ovo (um bolo de ovo dourado vale muito). Os upgrades da cozinha liberam receitas, mais bocas no fogão e menos tempo de preparo.

### 4.3 Preço e clientes (o coração do jogo)
- O jogador põe o preço de cada produto na **placa da barraca** com botões −/+ e uma marcação de "preço sugerido".
- Cada cliente NPC chega com um **preço máximo**: `valor base × humor do mercado × reputação × variação (0,8 a 1,2)`.
  - Se o preço for menor ou igual ao máximo, ele compra. A reputação sobe um pouco se o preço estiver bem abaixo.
  - Se o preço for maior, ele balança a cabeça, mostra um balão ("Muito caro!") e vai embora.
- **Humor do mercado** (mostrado no quadro da feira):
  - **Clima:** sol, chuva, frio e onda de calor. No frio o ovo cozido vende mais, e na chuva aparece menos gente.
  - **Hora do dia:** de manhã é café da manhã (cru/cozido), à tarde é lanche (bolo/chocolate).
  - **Eventos:** Páscoa (chocolate 3×), Cliente VIP (paga 5× um único pedido), Fiscal da Feira (dá bônus para barraca limpa e decorada).
- **Fila visível:** quanto melhor a reputação, mais longa a fila. Ver a fila da barraca vizinha maior que a sua é o principal motivo para melhorar.

### 4.4 Roubo
- **Cesta de ovos** (roubo rápido): pegar até 5 ovos/produtos da vitrine de outra barraca. Você fica 20% mais lento e precisa chegar à sua barraca.
- **Galinha** (roubo grande): só dá para roubar galinha de quem está online. Você fica 40% mais lento e a galinha **cacareja**, então todo mundo ouve e ela aparece no mapa da vítima.
- **Defesa:** portão do quintal (fecha por 60 s, com recarga), cachorro guardião (late e derruba a cesta de quem rouba), espantalho e alarme.
- **Vingança:** a vítima tem 2 min com o botão "Pegar de volta" e +20% de velocidade.
- **Proteções contra abuso** (as lições do Steal a Critter v28 valem desde o primeiro dia):
  - Conferir o caminho do ladrão, e não só o tempo total (roubo com teleporte).
  - Ninguém segura item roubado por mais de 2 min (refém).
  - Não dá para vender na hora o que acabou de roubar (trava de 2 min).
  - Novatos ficam protegidos de roubo nos primeiros 10 min ou até o nível 3.
  - A barraca não pode ficar no negativo: o roubo leva produto, nunca dinheiro.

### 4.5 Barraca e decoração
- Níveis da barraca: o visual muda e as vagas de vitrine e da fila aumentam.
- Decoração (toldo, placa, flores, luzinhas) dá **reputação** e é a principal coisa a comprar com dinheiro do jogo depois do meio do jogo.

### 4.6 Retenção
- Ganho offline de 2 h no máximo: as galinhas botam e um "ajudante" vende cru, pela metade do preço.
- Presente diário com sequência, missões do dia ("Venda 20 omeletes", "Roube 1 cesta", "Fique com reputação 4★"), códigos e ranking semanal de "Melhor Barraca".

## 5. Mapa
Um mercado ao ar livre com 8 barracas em círculo em volta de uma praça. No centro ficam a fonte, o quadro da feira (clima, hora e evento), o caminho da Carroça do Granjeiro e a saída por onde os clientes NPC chegam e vão embora. Atrás de cada barraca fica o quintal com o ninho das galinhas. Os caminhos entre os quintais são estreitos, para dar perseguição.

## 6. Primeiro minuto (o que decide se o jogador fica)
1. **0 a 10 s:** a pessoa nasce na frente da própria barraca, já com 2 galinhas e 3 ovos no ninho. Uma seta aponta o ninho.
2. **10 a 25 s:** recolhe os ovos e coloca na vitrine. O primeiro cliente já está esperando e compra na hora (fogos, som de caixa registradora).
3. **25 a 45 s:** aparece o tutorial de preço ("Tente cobrar mais!"), e o cliente seguinte recusa para mostrar o limite.
4. **45 a 60 s:** a pessoa compra a terceira galinha. Uma seta mostra a Galinha Dourada do vizinho com o texto "Dá pra roubar… 👀".

## 7. Monetização (sem item aleatório pago)
- **Game passes:** Caixa 2× (dinheiro das vendas em dobro), Cachorro Guardião, Vitrine VIP (+4 vagas), Cozinha Turbo (preparo 2× mais rápido), Galinha Arco-íris (uma galinha fixa).
- **Dev products:** pacotes de moedas, "Fila Cheia" (10 min de clientes extras), "Proteção do quintal" (30 min sem roubo).
- **Entrega da compra:** confiar no `ProcessReceipt` / `PromptGamePassPurchaseFinished` do servidor. Esse é o problema pendente do Steal a Critter e não pode se repetir aqui.

## 8. Métricas (metas para decidir se continua)
| Métrica | Meta para seguir | Sinal ruim |
|---|---|---|
| Retenção D1 | ≥ 25% | < 15% |
| Sessão média | ≥ 12 min | < 6 min |
| Jogadores que mudam o preço na 1ª sessão | ≥ 60% | < 30% (o sistema central não foi entendido) |
| Primeiro roubo na 1ª sessão | ≥ 40% | — |
| Taxa de clique da thumbnail | ≥ 4% | < 2% |

Registrar: funil do primeiro minuto, vendas por preço (relativo ao sugerido), roubos e vinganças, compras.

## 9. Escopo

**MVP (primeira versão jogável):**
- 1 mercado com 8 barracas, quintal e ninho.
- 3 raças de galinha (Caipira, Pintada, Dourada) e 2 receitas (cru e cozido).
- Clientes NPC com preço máximo, a placa de preço e a reputação.
- Clima simples (sol/chuva) e a Carroça do Granjeiro.
- Roubo de cesta e de galinha, com as proteções da seção 4.4.
- Save (DataStore), ranking do servidor, PT-BR e EN.

**Depois, se as métricas forem boas:** as outras receitas, eventos, decoração completa, ganho offline, missões diárias, game passes e níveis de barraca.

## 10. Reaproveitamento do Steal a Critter (`src/`)
Candidatos a adaptar. Conferir cada um antes de copiar:
- `ServerScriptService/Game/Data.luau`: save, incluindo a correção de "sair e voltar rápido".
- `ServerScriptService/Game/Fairness.luau`: verificação de roubo (caminho, refém, trava de venda).
- `ServerScriptService/Game/Plots.luau`: distribuição das bases (vira barracas).
- `ServerScriptService/Game/Economy.luau`, `Leaderboards.luau`, `Codes.luau`, `Analytics.luau`, `Retention.luau`.
- `ServerScriptService/Game/Remotes.luau`: limite de pedidos por ação.
- `ReplicatedStorage/Shared/Format.luau`: formatação de números ($1.2K, $3.4M).

O que é **novo**: clientes NPC com fila e decisão de compra, a placa de preço, a cozinha, as galinhas no ninho e o humor do mercado.

## 11. Riscos
| Risco | O que fazer |
|---|---|
| Parecer clone de "Steal a…" | A thumbnail e o primeiro minuto mostram a **fila de clientes e a placa de preço**, não só o roubo. |
| O preço confunde criança pequena | Preço sugerido sempre visível, com botão "Preço automático" (que vende um pouco abaixo do ideal). |
| O roubo frustra novato | Proteção de 10 min, o roubo nunca tira dinheiro e a vingança fica fácil. |
| Servidor vazio | Clientes NPC funcionam sozinhos, e o jogo é divertido mesmo com 1 jogador. |
| Exploit de roubo e de compra | Aplicar as correções da v28 desde o começo (seções 4.4 e 7). |
