# Modelos 3D do Higgsfield: como colocar no jogo

São 21 modelos (GLB) feitos no Higgsfield. Cada um tem no máximo 18 mil triângulos, então cabe no limite do Roblox (20 mil por malha).

## 1. Baixar

A rede desta sessão não deixou baixar os arquivos daqui. No seu PC, faça uma destas:

- Abra o `baixar-modelos.html` no navegador e clique em cada modelo.
- Ou rode `python baixar.py` dentro desta pasta: os 21 `.glb` caem na pasta `modelos/`.

## 2. Importar no Studio (um por vez)

1. Abra o `VendaUmOvo-v6.rbxlx`.
2. Vá em **Arquivo > Importar 3D** e escolha o `.glb`.
3. Na janela de importação, deixe **Anchored** ligado e clique em Importar.
4. Ajuste o tamanho (ferramenta Escala ou `Model:ScaleTo`) até ficar perto do tamanho da tabela abaixo.
5. Gire o modelo para a frente dele ficar para **-Z**: é para onde o modelo antigo "olha".
6. Renomeie com o **mesmo nome** da tabela.
7. Coloque em **ReplicatedStorage > Assets** e apague o modelo antigo de mesmo nome.

Não precisa criar a peça "Root": se o modelo não tiver, o jogo cria uma na base dele sozinho.

Antes de importar, guarde uma cópia do arquivo. Se algum modelo ficar ruim, é só voltar o antigo.

## Tamanhos (largura x altura x profundidade, em studs)

| Nome | Tamanho | Nome | Tamanho |
|---|---|---|---|
| Celeiro_1 | 36 x 14 x 31 | Maquina_Embaladora | 10 x 9 x 8 |
| Celeiro_2 | 36 x 12 x 28 | Maquina_Lavadora | 9 x 9 x 7 |
| Celeiro_3 | 39 x 13 x 32 | Maquina_Pintora | 9 x 9,5 x 7 |
| Celeiro_4 | 46 x 27 x 14 | Moinho | 25 x 33 x 16 |
| Celeiro_5 | 36 x 23 x 33 | Ovo_Dourado | 1,2 x 1,5 x 1,1 |
| Chocadeira | 6 x 6,5 x 6 | Pet_Ovinho | 2,3 x 2,5 x 2 |
| Esteira | 3,4 x 2,5 x 4 | Pinheiro | 8,4 x 15 x 8,4 |
| Garagem | 13 x 9 x 16 | Placa_Neon | 5 x 10 x 1,8 |
| Lampiao | 1,9 x 9 x 3,8 | Plataforma_Foguete | 18 x 20 x 18 |
| Maquina_Carimbo | 9 x 9,5 x 6 | Portal | 23 x 14 x 3 |
| | | Roleta | 9 x 13 x 4,6 |

## Dicas

- **Pinheiro, Lampiao e Ovo_Dourado** aparecem muitas vezes no mapa. Se o jogo ficar pesado no celular, troque primeiro os grandes (celeiros, moinho, foguete) e deixe esses três como estão.
- Na **Roleta**, só a parte que gira precisa continuar com o mesmo nome de peça do modelo antigo. Se ela parar de girar, volte o modelo antigo.
- Na malha importada, ligue `CanCollide` só no que o jogador pisa ou bate. Em enfeite, deixe desligado: fica mais leve.
