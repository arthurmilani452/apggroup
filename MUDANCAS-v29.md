# Steal a Critter v29: bases viram GINÁSIOS 3D

Arquivo para abrir no Studio: `place/StealACritter-v29.rbxlx`

## O que tem de novo
8 temas novos de base, cada um um ginásio (design próprio, sem logo da Nintendo):

| Tema | Id do modelo 3D | Código do arquivo .glb (Higgsfield) |
|---|---|---|
| Fire Gym | `gym_fire` | `d6ff8ecd-1e2e-42a7-b431-2396c7644ea0` |
| Water Gym | `gym_water` | `cdede679-2eeb-497a-b879-c3f525f7ea3b` |
| Grass Gym | `gym_grass` | `2a0d4160-f6fc-4ae5-adfe-6ee48114df03` |
| Electric Gym | `gym_electric` | `7b26305d-fb0f-4a67-8e8a-7c54560b635a` |
| Ice Gym | `gym_ice` | `8ece014b-460e-4cbe-b27d-2e5ec2e5de52` |
| Rock Gym | `gym_rock` | `4743a291-50f9-4fc7-a713-cd097c22615d` |
| Psychic Gym | `gym_psychic` | `ee8c53c8-35d9-4f3f-a5fd-d6c81b44776b` |
| Shadow Gym | `gym_dark` | `9a6d4f33-7882-4ff5-9826-b6deb7a5f09d` |

Os temas são grátis para todo mundo: aba **Style > THEMES > USE**.

## Como colocar os modelos 3D
1. No Higgsfield, baixe os 8 `.glb` dos ginásios (o nome do arquivo termina com o código da tabela).
2. No Studio: **File > Import 3D**, selecione os 8 de uma vez e importe.
3. Arraste para **ReplicatedStorage > Models3D** (ou deixe no Workspace: o servidor leva sozinho).
   Não precisa renomear nada.

Sem o modelo importado o tema ainda funciona: a base só ganha as cores do ginásio.

## Como funciona
- Com o tema de ginásio, as paredes, torres, portão e piso de peças ficam **invisíveis, mas continuam
  batendo**. O ginásio 3D aparece no lugar e é **só visual** (não tem colisão).
  Então nada muda na jogabilidade: pedestais, botão de trancar, laser, coletor, esteira e 2º andar continuam iguais.
- Voltar para outro tema (ou o dono sair) devolve a base normal.

## Ajuste fino no Studio (se precisar)
Coloque atributos no modelo importado (dentro de Models3D):
- `Turn` = gira (0, 90, 180, 270). Se o portão do ginásio ficar para trás, use `Turn = 270`.
- `Size` = maior lado em studs (padrão 96; a base mede 64 x 88).
- `Lift` = sobe/desce em studs (padrão: o piso do modelo fica 1,2 stud abaixo do piso de verdade).
