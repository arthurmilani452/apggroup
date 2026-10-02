# GDD: Prefeito Tycoon

**Versão:** 1.0 (MVP) · **Data:** 02/10/2026 · **Plataforma:** Roblox (PC e celular) · **Produção:** 100% em código (o `prefeito/build.py` gera o `.rbxlx` e os scripts são em Luau), sem precisar abrir o Studio para montar nada.

---

## 1. Resumo

| Item | Definição |
|---|---|
| **Nome** | Prefeito Tycoon (en: *Mayor Tycoon*) |
| **Gênero** | Tycoon de construção de cidade, com mundos lado a lado e interação entre cidades |
| **Público** | Mais velho (13+ no posicionamento). O visual é sóbrio, estilo SimCity, numa cidade ao entardecer com janelas acesas. Nada de bichinhos e cores de doce. |
| **Jogadores por servidor** | 8 (um terreno por jogador) |
| **Sessão-alvo** | 20 a 40 min. Chegar a Metrópole leva umas 2 a 3 sessões. |

**Pitch.** Você é prefeito de uma ilha vazia. Puxa rua da Avenida, levanta casas, liga a energia, abre comércio e serviços, e vê a cidade crescer de **Vila** até **Megalópole**. A renda cai no **Cofre da Prefeitura** e você precisa ir buscar, que é o loop clássico de tycoon. As cidades do servidor ficam uma do lado da outra: **morador infeliz faz as malas e se muda para a cidade do vizinho**, e você vê o aviso na hora.

## 2. Por que este conceito

- **Tycoon** é um dos gêneros que mais retêm no Roblox: o jogador se apega ao que construiu e volta para coletar.
- **Construção livre em grade** dá a sensação de "a cidade é minha", diferente do tycoon de botões no chão.
- **O diferencial está na relação entre as cidades:** migração de moradores, recomendações (estrelas), bônus de renda por visitante e eventos globais que atingem todo mundo ao mesmo tempo. Isso gera rivalidade e motivo para visitar o vizinho.
- **Visual noturno com neon e torres de vidro** fica bonito em thumbnail e clipe, e conversa com o público mais velho.

## 3. Loops

**Minuto a minuto:** construir (rua, casa, energia, comércio, serviço, lazer), olhar o painel e corrigir o que falta ("sem rua", "falta energia", "moradores querem saúde").

**A cada 5 a 10 min:** ir até o cofre e coletar. Se demorar, o cofre enche e a renda para de entrar.

**Sessão:** subir de nível da cidade (libera prédios novos), expandir o terreno, aumentar o cofre, visitar e recomendar outras cidades, aproveitar o evento global da vez.

**Longo prazo:** **Reeleição** (rebirth). Com 5.000 moradores a cidade recomeça do zero, mas toda renda ganha **+50% para sempre** a cada mandato. Também tem o placar global de estrelas e de maior cidade.

## 4. Regras da cidade

Todos os números estão em `src/ReplicatedStorage/Shared/Config.luau` e `Buildings.luau`. A conta fica em `CityMath.luau`, que é testada.

| Regra | Como funciona |
|---|---|
| **Rua** | Todo prédio (menos árvore) precisa encostar de lado numa rua ligada à **Avenida** (a fileira da frente, fixa). Prédio sem rua mostra a placa **SEM RUA** e não funciona. |
| **Energia** | Usinas produzem e prédios consomem. Faltando energia, a renda cai até 60% e a felicidade cai até 15 pontos. A renda nunca chega a zero, então o jogador nunca fica travado. |
| **Necessidades** | Comércio e Saúde (desde Vila), Segurança e Educação (a partir de Cidade). Cada casa precisa estar no **alcance** de um prédio que atende a necessidade: +8 de felicidade se atende, −9 se falta. |
| **Lazer e poluição** | Praça, parque e estádio somam felicidade por perto (até +25). Indústria e gerador tiram (até −40). |
| **População** | A meta é `vagas × ocupação`, e a ocupação vai de 30% (felicidade 0) a 100% (felicidade 100). A população anda 20% em direção à meta a cada 5 s. |
| **Migração** | Se a felicidade fica abaixo de 40, quem sai vai para a cidade mais feliz do servidor (felicidade a partir de 60) que tenha vaga. Os dois prefeitos recebem aviso. |
| **Renda** | Impostos ($0,20/s por morador) + comércio e indústria (proporcional aos empregos preenchidos). Multiplicadores: mandatos, passe Renda x2, evento, visitantes (+5% cada, até +25%). |
| **Cofre** | Guarda de 5 a 120 min de renda, conforme o nível. Offline continua enchendo, a 50% da renda e por até 12 h. |

**Níveis:** Vila (0) → Cidade (150) → Cidade Grande (1.000) → Metrópole (5.000) → Megalópole (20.000). Prédio liberado não trava de novo se a população cair.

**Expansões:** 12×12 (grátis) → 16×16 ($7,5K) → 20×20 ($90K) → 24×24 ($900K).

**27 prédios** em 7 categorias: Ruas, Moradia (Casa → Arranha-céu), Comércio (Padaria → Torre Comercial), Indústria (Oficina → Polo Tecnológico), Serviços (Posto de Saúde, Delegacia, Escola, Hospital, Bombeiros, Universidade), Lazer (Árvore → Torre de TV), Energia (Gerador a Diesel → Usina Térmica).

## 5. Social

- **Viajar:** lista das cidades do servidor (prefeito, população, felicidade, estrelas) com teleporte.
- **Recomendar (★):** 1 por cidade por dia. Quem recomenda ganha 60 s da própria renda, e o dono ganha 1 estrela e 30 s da renda dele.
- **Visitantes:** cada jogador andando na sua cidade dá +5% de renda (até +25%).
- **Nomes de cidade** são escolhidos de duas listas ("Nova" + "Esperança"). Não existe texto livre, então não há nada para filtrar.
- **Placares globais no hub:** prefeitos mais recomendados e maiores cidades (pico de população).

## 6. Eventos globais

A cada 10 min, um evento de 2 min vale para todas as cidades do servidor:

| Evento | Efeito |
|---|---|
| Apagão Regional | Usinas produzem 40% a menos |
| Feriadão | Comércio x2, indústria x0,5 |
| Onda de Calor | −12 de felicidade |
| Boom Imobiliário | População cresce 3x mais rápido, impostos +50% |
| Rodada de Investimento | Toda renda +30% |

## 7. Monetização (desligada até ter os Ids)

Os Ids ficam em `Config.GamePasses` e `Config.DevProducts`, e `0` = desligado.
- **Renda x2** (passe)
- **Cofre Automático** (passe): a renda vai direto para o bolso
- **Pacotes de dinheiro**: 10 ou 60 min da renda atual, com um valor mínimo garantido

Nada aleatório é vendido. O passe é entregue pelo evento `PromptGamePassPurchaseFinished` do servidor (a lição do Steal a Critter v28), e cada recibo de produto é salvo para nunca entregar duas vezes.

## 8. Primeira sessão (tutorial)

1. Faça uma Rua saindo da Avenida
2. Construa 4 Casas
3. Construa um Gerador a Diesel
4. Construa uma Padaria
5. Colete o Cofre da Prefeitura

Começa com $1.500, e o tutorial custa $960 (o teste `economy_spec` garante que sempre cabe).

## 9. Técnico

```
prefeito/
  build.py                           gera place/PrefeitoTycoon-v1.rbxlx
  src/ReplicatedStorage/Shared/      Config, Buildings, Grid, CityMath, BuildingModels, LotLayout, Format
  src/ServerScriptService/Main.server.luau
  src/ServerScriptService/Game/      Data, Remotes, Lots, City, Events, Products, Leaderboards
  src/StarterPlayer/StarterPlayerScripts/
                                     ClientMain, UI, State, HUD, BuildMode, CityPanel, Travel,
                                     Citizens, Tutorial, Ambience
  tests/                             testes no Lune (grade, conta da cidade, ritmo, modelos 3D)
```

- **O servidor confere tudo.** O cliente só desenha e pede, e cada pedido passa por `City.HandleRequest`, com intervalo mínimo entre ações.
- **Salvamento:** é o mesmo `Data` do Steal a Critter v28 (trava de sessão, várias tentativas, espera o save da saída antes de recarregar no mesmo servidor). A cidade é salva como uma lista curta de textos `"id,x,z,r"`.
- **Modelos 3D:** todos feitos com Parts por código (`BuildingModels`). As janelas são um núcleo de neon por trás das lajes, o que dá cidade acesa à noite com poucas peças.
- **StreamingEnabled desligado:** o cliente lê os prédios de todos os terrenos (grade, viajar, pedestres).

**Como testar fora do Roblox:** `lune run prefeito/tests/run` (da raiz do repositório).

**Como gerar o lugar:** `python3 prefeito/build.py`, depois abrir `place/PrefeitoTycoon-v1.rbxlx` no Studio e publicar. Para o salvamento funcionar no Studio, ligue *Game Settings → Security → Enable Studio Access to API Services*.

## 10. Próximos passos (depois do MVP)

- Carros nas ruas e trânsito como necessidade (rua cheia = felicidade menor)
- **Mundos privados** (servidor reservado só seu e dos amigos)
- Estilos de terreno: neve, ilha tropical, cidade flutuante
- Missões diárias e conquistas
- Prédios especiais de evento (só durante o evento)
- Ranking semanal com estátua no hub para o prefeito da semana
