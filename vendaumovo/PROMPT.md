# Prompt: Venda um Ovo (Roblox)

Copie o bloco abaixo inteiro e cole numa sessão nova do Claude Code (com o conector OpenArt ligado).

---

```
Crie um jogo de Roblox chamado "Venda um Ovo" (em inglês: "Sell an Egg"), no mesmo estilo
dos outros jogos deste repositório (veja src/ e zonazero/ para o padrão de código Luau,
pastas ReplicatedStorage / ServerScriptService / StarterPlayer e o builder que gera o .rbxlx).
Coloque tudo numa pasta nova "vendaumovo/" e gere o arquivo vendaumovo/place/VendaUmOvo.rbxlx
para eu abrir direto no Roblox Studio.

## A ideia do jogo
Simulador/tycoon para todas as idades. Cada jogador recebe uma granja (plot) com galinhas.
As galinhas botam ovos sozinhas; o jogador coleta os ovos, leva até a banca de venda e vende
por moedas. Com as moedas ele compra galinhas melhores, upgrades e decorações.

## Loop principal
1. Galinha bota ovo a cada X segundos (o ovo aparece no ninho dela).
2. Jogador encosta no ovo ou aperta E para coletar (carrega até um limite = tamanho da cesta).
3. Jogador anda até a Banca e vende tudo. Preço = valor do ovo x multiplicador do jogador.
4. Compra galinhas novas na Loja de Galinhas, upgrades na Loja de Upgrades.
5. Rebirth: ao juntar muito dinheiro, reseta a granja e ganha multiplicador permanente.

## Tipos de ovo (do mais barato ao mais raro)
Ovo Branco, Ovo Caipira (marrom), Ovo de Pata, Ovo de Codorna, Ovo Dourado, Ovo de Cristal,
Ovo Arco-íris, Ovo Lunar, Ovo de Dragão (lendário). Cada galinha bota um tipo; existe uma
pequena chance de botar um ovo raro (com efeito de brilho e som especial).

## Sistemas
- Moedas (leaderstats), save com DataStore (com retry e save ao sair, sem perder dados
  ao reentrar rápido no mesmo servidor).
- Upgrades: tamanho da cesta, velocidade de postura, velocidade de andar, coleta automática.
- Esteira automática (upgrade caro) que leva os ovos do ninho até a banca.
- Missões diárias simples e presente por tempo de jogo (usar relógio do SERVIDOR).
- Placar global dos maiores vendedores.
- Game passes opcionais: x2 dinheiro, cesta VIP, coleta automática. Entregar a compra pelo
  evento PromptGamePassPurchaseFinished no servidor.
- Toda lógica de dinheiro, venda e compra roda no SERVIDOR. O cliente só pede; o servidor
  valida distância, cooldown por ação e saldo (nada de confiar no cliente).
- Interface em português, bonita, que funcione no celular.

## Arte 3D com OpenArt -> Roblox Studio
Use o OpenArt (ferramentas mcp__open_art__*) para criar a arte do jogo. Antes de gerar,
veja os modelos e o custo com openart_model_list e me mostre quanto vai gastar no total.
Crie um projeto no OpenArt chamado "Venda um Ovo" e guarde tudo lá.

Estilo de TODAS as imagens: 3D estilizado, cartoon, low-poly, cores vivas, cantos
arredondados, iluminação suave, fundo branco liso, parecido com jogos populares do Roblox.
Escreva os prompts de imagem em inglês, detalhados.

Para cada objeto 3D do jogo, gere uma "folha de referência" (turnaround) com vista de
frente, lado, costas e 3/4, objeto centralizado, sem sombra no chão, fundo branco, para
servir de base para virar modelo 3D:
- Os 9 tipos de ovo (um por imagem, mesmo formato e tamanho entre eles)
- Galinha comum, galinha caipira, pata, codorna, galinha dourada, galinha de cristal,
  galinha arco-íris, galinha lunar e um filhote de dragão
- Ninho de palha, galinheiro, cesta de ovos, banca de venda (barraca de feira),
  esteira de ovos, cerca de madeira, placa "VENDA UM OVO", árvore, fardo de feno, moinho

Também gere (estes vão direto para o jogo, sem virar 3D):
- Ícones de UI 512x512, fundo transparente ou branco: cada ovo, moeda, cesta, raio
  (velocidade), estrela (rebirth), presente, troféu
- Texturas que repetem (seamless) 1024x1024: grama, terra, palha, madeira, telha
- Ícone do jogo 512x512 e 2 thumbnails 1920x1080 com o nome "Venda um Ovo" escrito
  (use um modelo bom em texto, como Nano Banana Pro ou GPT Image)

Atenção: o OpenArt gera IMAGENS, não arquivos 3D (.fbx/.obj). Então:
1. Baixe todas as imagens para vendaumovo/arte/ (pastas: referencias3d/, icones/,
   texturas/, marketing/) e liste tudo num arquivo vendaumovo/arte/LISTA.md.
2. No jogo, monte cada objeto com Parts / MeshParts básicos do Roblox (esferas, cilindros,
   cunhas) seguindo as cores e formas das referências, para o jogo já funcionar e ficar
   bonito sem precisar de nada externo.
3. Deixe cada objeto como um Model separado em ReplicatedStorage/Assets com nome claro
   (ex.: "Ovo_Dourado", "Galinha_Cristal"), para eu trocar depois pelo MeshPart de verdade
   sem mexer em código.
4. Escreva em vendaumovo/LEIA-ME.md o passo a passo, em português simples, para eu
   transformar as referências em 3D e colocar no Studio:
   - Opção A: no Roblox Studio, usar o Assistant / gerador de 3D por texto ou imagem
     e colar a descrição de cada objeto.
   - Opção B: usar uma ferramenta de imagem->3D (ex.: Meshy, Tripo ou Higgsfield
     generate_3d) com a imagem de referência, exportar .fbx ou .obj.
   - Importar no Studio pelo 3D Importer (Arquivo > Importar 3D), limite de 20.000
     triângulos por malha, escala certa (ovo ~1,5 studs, galinha ~3 studs).
   - Trocar o Model provisório em ReplicatedStorage/Assets pelo novo, mantendo o nome.
   - Subir ícones e texturas pelo Gerenciador de Ativos e colar os IDs no arquivo
     de configuração (deixe um módulo Config com todos os IDs de imagem num lugar só).

## Entrega
- Código Luau organizado, com um módulo Config para preços, tempos e IDs.
- O .rbxlx pronto para abrir no Studio.
- vendaumovo/LEIA-ME.md explicando como jogar, como testar e o passo a passo da arte.
- Antes de terminar, revise o código procurando exploits (dinheiro infinito, venda pelo
  cliente, spam de RemoteEvent) e corrija.
- Faça commit e push quando estiver pronto.
```

---

## Observação sobre o OpenArt

O conector OpenArt desta conta gera **imagens e vídeos**, não modelos 3D. Por isso o prompt
pede para o OpenArt criar folhas de referência (o objeto visto de vários lados), e o 3D
de verdade sai de um gerador de imagem->3D ou do gerador 3D do próprio Roblox Studio.
O jogo já fica jogável com peças montadas no Studio enquanto os modelos 3D não ficam prontos.

Custo aproximado no OpenArt (saldo atual: 21.587 créditos): ~40 imagens de 15 a 40 créditos
cada, ou seja, de 600 a 1.600 créditos no total.
