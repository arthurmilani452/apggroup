# Venda um Ovo (Sell an Egg)

Arquivo para abrir no Roblox Studio: **`vendaumovo/place/VendaUmOvo.rbxlx`**

Tycoon de granja para todas as idades, numa ilha flutuante. Cada jogador ganha uma das 12 granjas em volta da ilha, com uma banca de ovos virada para a estrada (igual barraquinha de limonada). As aves botam sozinhas, você junta os ovos na cesta, leva até a banca e vende. Com as moedas, compra aves melhores e melhorias, e depois faz rebirth.

## O mapa
- **Centro:** celeiro vermelho, silo, cercadinho com galinhas soltas, o ovo dourado no pedestal e o placar dos maiores vendedores.
- **Anel do meio (entre a estrada de terra e o asfalto):** Galinheiro do Seu Zé (aves), Mercado com barracas e carrinhos (missões), Oficina com a engrenagem (melhorias), Portão Arco-íris trancado (rebirth), Banco com a moeda (loja de Robux) e a Fábrica com esteiras.
- **Em volta:** as 12 granjas, cada uma na beira da estrada asfaltada.
- **Borda da ilha:** lagos com ponte, moinho no morro, rotatória com caminhão, pinheiros e fardos de feno. Tem parede invisível na beirada, ninguém cai.

## Como jogar
1. Você nasce na sua granja. A placa do portão mostra seu nome.
2. As aves botam no ninho de cada uma (até 3 ovos por ninho; ninho cheio = ela espera).
3. Encoste no ovo ou aperte **E** perto do ninho para pegar. A cesta tem limite.
4. Vá até a **banca** (na frente da granja) e aperte **E** ou pise no tapete verde atrás do balcão. Vende tudo de uma vez.
5. No anel do meio da ilha ficam os balcões (chegue perto e aperte **E**):
   - **Galinheiro do Seu Zé**: aves novas. Com os ninhos cheios, a ave mais fraca sai e devolve 25% do preço dela.
   - **Oficina**: melhorias (cesta, mais ninhos, postura rápida, tênis veloz, coleta automática, esteira, decoração).
   - **Portão Arco-íris**: rebirth. Recomeça a granja, e toda venda passa a valer +50% por rebirth, pra sempre.
   - **Mercado**: quadro das missões do dia.
   - **Banco**: loja de Robux.
6. Botões da esquerda: Aves, Melhorias, Rebirth, Missões, Presente e Loja (Robux).

Seta amarela no começo: aponta o ninho com ovo ou a banca, até a pessoa juntar 2.000 moedas.

### Ovos (do mais barato ao mais raro)
Branco (1) → Caipira (4) → Pata (15) → Codorna (50) → Dourado (250) → Cristal (1.200) → Arco-íris (6.000) → Lunar (35.000) → **Dragão (250.000, lendário)**.
Cada ave bota um tipo. **4% dos ovos saem raros**: brilham, tocam um som e valem 5x. Ovo de dragão raro aparece para o servidor todo.

## Testar no Studio
1. Abra o `.rbxlx` e aperte **Play**.
2. Para o save funcionar no Studio: **Game Settings > Security > Enable Studio Access to API Services** (o jogo precisa estar publicado).
3. Para testar com várias pessoas: aba **Test > Clients and Servers**, 2 ou 3 jogadores.
4. **Places > Server Size: 12** (o mapa tem 12 granjas; o 13º jogador é mandado para outro servidor).

## Ajustar o jogo
Tudo fica em **`ReplicatedStorage > Shared > Config`**: preços, tempos, chance de ovo raro, melhorias, rebirth, missões, presente, game passes, produtos e todos os IDs de imagem, textura e som.

## Vender Robux
O jogo já vem pronto para vender. Falta só criar os itens no Creator Hub e colar os IDs no Config.

**Game passes** (compra uma vez), em `Config.GamePasses`:
| Passe | O que faz |
|---|---|
| Dinheiro x2 | toda venda vale o dobro |
| Cesta VIP | cesta com o dobro de espaço |
| Coleta Automática | pega os ovos sozinho |

**Produtos** (compra quantas vezes quiser), em `Config.Products`:
| Produto | O que faz | Preço sugerido |
|---|---|---|
| Saquinho / Baú / Caminhão de Moedas | moedas (crescem junto com a granja da pessoa) | 25 / 99 / 399 Robux |
| Sorte x3 (15 min) | 3x mais ovo raro | 49 Robux |
| Venda x2 (10 min) | vendas valem o dobro | 39 Robux |

Como criar: **Creator Hub > seu jogo > Monetização > Passes** (ou **Produtos de desenvolvedor**) > criar, copiar o ID e colar no campo `Id` certo. Com `Id = 0`, o item some da loja.

Entrega segura: game pass é dado pelo evento `PromptGamePassPurchaseFinished` no servidor e fica salvo. Produto passa pelo `ProcessReceipt`: cada compra é entregue uma vez só e só é confirmada ao Roblox depois de salvar.

## Arte 3D: das imagens do OpenArt para o Studio
As referências estão listadas em **`vendaumovo/arte/LISTA.md`** (com link de cada uma). Para baixar tudo: `python3 vendaumovo/arte/baixar.py`.

O jogo já funciona com modelos feitos de peças (esferas, cilindros e cunhas, com as cores das referências). Cada um está em **`ReplicatedStorage > Assets`** com um nome claro: `Ovo_Dourado`, `Galinha_Cristal`, `Banca`, `Moinho`... Trocar por 3D de verdade não exige mexer em código.

### Opção A: gerar dentro do Studio
1. Abra o **Assistant** do Studio (ou o gerador de 3D, se sua conta tiver).
2. Peça o objeto com uma descrição curta. Exemplos:
   - "ovo dourado brilhante estilo cartoon, low poly, 1,5 studs de altura"
   - "galinha de cristal azul clara translúcida, fofinha, estilo cartoon low poly, 3 studs de altura"
   - "barraquinha de feira de madeira com toldo listrado vermelho e branco, estilo cartoon"
3. Siga os passos de "Trocar o modelo" lá embaixo.

### Opção B: imagem → 3D (Meshy, Tripo, Higgsfield)
1. Abra a ferramenta e envie a imagem de referência (`arte/referencias3d/...`). Se pedir uma imagem só, recorte a vista 3/4 (a última do lado direito).
2. Gere o modelo com textura e exporte **.fbx** ou **.obj** (ou .glb).
3. Mantenha leve: **no máximo 20.000 triângulos por malha** (a maioria das ferramentas tem a opção "target polycount").

### Importar e trocar o modelo
1. No Studio: **Arquivo > Importar 3D** (3D Importer). Escolha o arquivo.
2. Confira a escala: **ovo com uns 1,5 studs** de altura e **ave com uns 3 studs**. (O jogo ainda ajusta sozinho pela tabela `Config.AssetHeights`.)
3. Deixe a frente do modelo virada para **-Z** (a frente do Studio).
4. Arraste o modelo para **ReplicatedStorage > Assets**, apague o antigo e **dê ao novo o mesmo nome** (ex.: `Galinha_Cristal`).
5. Pronto: aves e ovos usam o modelo novo na hora. Os objetos do cenário (árvore, cerca, banca, moinho, ninho, feno, galinheiro, esteira, placa) são trocados em todo o mapa quando o servidor liga.

### Ícones e texturas
1. **Ver > Gerenciador de Ativos > Importar**: envie as imagens de `arte/icones/` e `arte/texturas/`.
2. Clique com o botão direito em cada uma > **Copiar ID do ativo**.
3. Cole em `Config.Images` (ícones) ou `Config.Textures` (texturas) no formato `"rbxassetid://123456"`.
4. Ícones sem ID aparecem como emoji. Texturas com ID cobrem chão, caminhos, madeira, palha e telhados.

### Ícone e thumbnails
`arte/marketing/`: suba no **Creator Hub > seu jogo > Places > Basic Info** (ícone 512×512, thumbnails 1920×1080).

## Para quem programa
- `vendaumovo/src`: todos os scripts (Luau), um arquivo por script.
- `vendaumovo/builder/build.py`: monta o `.rbxlx` (mapa, modelos de `Assets`, iluminação e scripts). Rode com `python3 vendaumovo/builder/build.py`.
- `vendaumovo/tests/formulas_test.luau`: testes das contas (venda, multiplicadores, rebirth, missões, ritmo de progressão). Rode com `luau vendaumovo/tests/formulas_test.luau`.
- **O servidor decide tudo.** O cliente só pede ("quero vender", "quero a Pata"). O servidor confere dono, distância da banca, da loja e do ninho, saldo, preço do Config, intervalo por ação e tipo de cada argumento. Moeda nunca vem do cliente.
- Relógios (missões do dia, presente, boosts) usam só o horário do servidor.
- Save: `UpdateAsync` com trava de sessão, várias tentativas, save a cada 60 s, ao sair e ao fechar o servidor. Quem sai e volta rápido para o mesmo servidor espera o save terminar (não perde nada).
