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
