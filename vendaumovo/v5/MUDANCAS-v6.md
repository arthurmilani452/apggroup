# Venda um Ovo: o que mudou na v6

Arquivo novo: `place/VendaUmOvo-v6.rbxlx`. Ele é o seu v5 com os scripts trocados: o mapa, as malhas e tudo o que você montou no Studio continuam iguais. O save também é o mesmo (`VendaUmOvo_v4`), então ninguém perde progresso.

## Coisas novas (ideias de Vender Limões e de outros tycoons grandes)

- **Prêmio por tempo jogado.** Em Prêmios aparece uma escada com 5, 10, 20, 35 e 60 minutos. O último degrau também dá 10 minutos de Turbo. Zera quando o jogador sai. O tempo é contado pelo servidor.
- **Convidar amigos.** Também em Prêmios, um botão abre o convite do Roblox. Cada amigo no servidor já dá +20% de renda.
- **Premium.** Quem assina Roblox Premium ganha +10% de renda. Aparece junto com amigos e grupo. O Roblox também te paga pelo tempo que assinantes Premium passam no jogo.
- **Emblemas (badges).** Por entrar, abrir a Granja, a Fábrica e o Foguete, contratar o 1º gerente, renascer e ganhar um Selo. Ficam desligados até você colocar os números em `Config.Badges`.
- **Chocar Já** (produto, 15 Robux). Termina na hora o ovo que mais falta chocar. Só aparece na aba Pets quando tem ovo chocando, e só abre a janela de compra nesse caso. Se mesmo assim não tiver ovo, a compra vira moedas.
- **Primeiro renascimento mais cedo.** O mínimo caiu de 30 para 15 estrelas. Renascer agora tem câmera "respirando", chuva de moedas e vibração no celular.
- **Roleta grátis a cada 1 hora** (antes era a cada 4 horas).
- **Contador de moedas que rola.** Quando entra muito dinheiro de uma vez, o número sobe contando.
- Abrir negócio novo também ganhou a câmera e a vibração.
- **Começo mais calmo.** Chaves secretas e o poder do galo só aparecem a partir do 3º negócio (antes era o 2º).

## Correções de segurança e de bugs

- **Save.** Quando o servidor antigo ainda segura o save de alguém, o jogo espera mais e não "rouba" o save. Antes podia sobrescrever progresso. Ao sair, o save vem antes do placar.
- **Anti-teleporte.** Quem teleporta com hack fica 8 segundos sem pegar nada do que é "por chegar perto": caça aos ovos, ovo surpresa, ovo gigante e obby. O obby agora também exige passar pela largada e levar pelo menos 8 segundos.
- **Curtidas.** Antes dava para curtir de novo quando o dono saía e voltava. Agora vale uma vez por servidor.
- **Configurações.** Número estranho (NaN) não quebra mais o save.
- **Passes.** O passe comprado em outro lugar entra no save quando o jogador volta.
- **Pedido de atualizar** a tela agora tem limite de 1 a cada 2 segundos.
- **Efeito de dinheiro** só vai para quem está perto (antes ia para o servidor inteiro).

## Melhorias na tela e no celular

- Texto nunca fica menor que 9. A tela encolhe menos no celular e os painéis usam melhor a largura.
- A caixa de código não fecha mais o teclado no meio da digitação.
- As contagens (presente, chocadeiras, roleta, prêmio por tempo) mudam só o número, sem refazer o painel todo a cada segundo.
- Galinhas longe da câmera não animam, e os pets dos outros jogadores são mais leves (no máximo 3 por jogador). Isso ajuda muito em celular fraco.
- As moedas voando não passam por cima de painel aberto.
- Sons iguais tocados juntos não se cortam mais.

## O que você precisa fazer no Roblox

1. **Emblemas.** Em create.roblox.com > seu jogo > Emblemas, crie os 7 emblemas. Cole os números em `ReplicatedStorage > Shared > Config`, na tabela `Config.Badges`.
2. **Chocar Já.** Em Produtos do Desenvolvedor, crie um produto de 15 Robux. Cole o número no `Id` do item `ChocarJa` em `Config.Products`.
3. **Recarga de Poderes.** Ela ainda está com `Id = 0`. Crie também se quiser vender.
4. **Modelos 3D.** Os 21 modelos do Higgsfield estão em `higgsfield/`. Veja `higgsfield/COMO-IMPORTAR.md`, que tem os nomes e tamanhos.

No Studio a loja mostra todos os itens, mesmo sem Id, para você ver como fica. No jogo publicado, item sem Id não aparece.

## Segunda rodada da v6

- **Meio do jogo sem travar.** Do Depósito em diante as compras ficaram mais baratas. Na simulação, a Omeleteria abriu aos 26 min (antes 29), o Laboratório já na 1ª corrida aos 50 min, e o Foguete aos 106 min (antes 196). O começo, que já estava bom, ficou igual.
- **Painel de renascer mostra o ganho antes:** "Bônus das estrelas: x1,3 → x1,9".
- **Título em cima da cabeça**, que todos veem, pelo número de renascimentos: Granjeiro, Fazendeiro, Coronel do Ovo, Barão do Ovo, Magnata da Gema, Lenda da Granja e Imperador do Ovo. Com Selo, o título fica na cor do Selo. Os nomes ficam em `Config.Titles`.
- **Baú do Grupo:** quem está no grupo do jogo abre de graça a cada 20 h, na aba Prêmios. Quem não está vê o convite para entrar. Regras em `Config.GroupChest`.
- **Menos coisa no meio da tela, pensando no celular:**
  - Os textos grandes ("Negócio novo!", "Renasceu!") ficaram menores, mais no alto, e não seguram o toque.
  - Prêmio do dia a dia (missão, presente, curtida, tempo jogado) virou um aviso pequeno no alto, em vez do texto gigante.
  - No celular, as janelas que aparecem sozinhas (encomenda e corrida) vão para o alto da tela e ficam menores.
  - As outras janelas também encolhem um pouco no celular.

## Terceira rodada da v6

- **Conquistas:** é uma aba nova ao lado de Renascer e Talentos, com 10 metas para a vida toda (vender, comprar, ovos raros, mutantes, chocar, renascer, baús, obby, roleta e curtidas). Cada degrau dá estrelas, e elas não zeram ao renascer. O botão de Renascer acende quando tem conquista para pegar. As metas e os prêmios ficam em `Config.Achievements`.
- **Placares na praça:** ao lado do TOP 10 de moedas que já existia, o jogo cria sozinho mais duas placas, viradas para o meio da praça:
  - à esquerda, o **TOP 10 de Renascimentos** de todos os servidores;
  - à direita, os **Mais ricos agora** neste servidor, pela renda por segundo e atualizado a cada 10 s.
- **💰 no título:** quem tem a maior renda do servidor (com 2 ou mais jogadores) ganha o 💰 em dourado em cima da cabeça.
- **Modo leve** em Configurações, para celular fraco: tira partículas, deixa as aves paradas e esconde os pets dos outros. Fica salvo.
- **Favoritar:** depois de 15 min jogando, o próprio Roblox pergunta uma vez se a pessoa quer favoritar o jogo. O tempo fica em `Config.FavoriteAfter`.
- **Lembrete de curtir:** depois de 25 min aparece uma vez um cartão pequeno no meio da tela, "Tá curtindo a granja? Deixa um 👍 na página do jogo". Some em 10 s, não segura o toque e tem X para fechar. O tempo fica em `Config.LikeReminderAfter`.
  - O Roblox não deixa o jogo abrir o botão de curtir, e é proibido dar prêmio em troca de curtida ou favorito. Por isso é só um lembrete, sem recompensa.
