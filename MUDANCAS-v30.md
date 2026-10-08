# Steal a Critter v30: o que mudou

Arquivo para abrir no Studio: `place/StealACritter-v30.rbxlx`

## Novo: os 8 bichinhos da semana em 3D
Eles eram os únicos que ainda eram de peças. Os modelos foram feitos no Higgsfield (estão na sua conta, aba 3D):

| Bichinho | Código do arquivo .glb |
|---|---|
| Sugarpaw | 62a77801-ad51-40b9-9262-a5db76ce9ba2 |
| Voltbeak | 19dbaa82-b542-4a77-90d6-322ca1392832 |
| Mochi Dino | a27c6401-27f8-493b-b0cb-c992f37aaa6f |
| Nightcat | 1cb8ac40-1084-45a3-952d-f9e10c8c6751 |
| Bubbletoad | 0d2cb482-31af-403f-bcd7-d6ee9e8907c2 |
| Ember Unicorn | 6601eecb-f785-4044-ab82-c086a4a7ce67 |
| Cloudpuff | dd0f8788-98ff-41ac-bd96-af8bbd42b0e7 |
| Galaxy Drake | d7fada12-57e4-4442-94a8-9b8f2999cf2d |

## Como colocar no jogo
1. No Higgsfield, baixe os 8 arquivos .glb (não precisa renomear).
2. No Studio: File > Import 3D, selecione os 8 de uma vez.
3. Jogue os modelos em ReplicatedStorage > Models3D (ou deixe no Workspace: o servidor leva sozinho).
4. Aperte Play: o Output mostra "[Models3D] ... 3D models found" com eles na lista.

Se algum aparecer de costas, coloque o atributo `Turn = 270` no modelo. Enquanto você não importar, eles continuam de peças (nada quebra).

## Também tem tudo da v29
Os 8 temas de ginásio 3D (veja `MUDANCAS-v29.md`).

## Única mudança no código
- `Models3DJobs`: os 8 códigos acima, para o jogo reconhecer cada arquivo pelo nome.
