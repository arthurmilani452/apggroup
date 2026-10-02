# ZONA ZERO: battle royale 16+

Arquivo para abrir no Roblox Studio: **`zonazero/place/ZonaZero.rbxlx`**

## Como o jogo funciona
- **Lobby:** todo mundo nasce em um hangar. Com 1 jogador já começa: depois de 20 s de espera, vem uma contagem de 10 s.
- **Salto:** cada jogador cai de paraquedas num ponto aleatório da ilha, com uma pistola e 24 balas.
- **Bots:** se tiver menos de 8 pessoas, bots completam a partida. Eles andam, procuram inimigos e atiram, errando um pouco.
- **Loot:** 168 pontos de loot no mapa com armas (Pistola, Submetralhadora, Fuzil, Escopeta, Rifle de Precisão), munição e curas (Bandagem, Kit Médico, Célula de Escudo). As armas têm raridade (Comum, Raro, Épico e Lendário), e quanto mais rara, mais dano.
- **Zona:** a parede roxa fecha em 6 fases. Fora dela você toma dano por segundo, e o anel branco no chão mostra a próxima zona.
- **Fim da partida:** quem morre assiste a outro jogador (botão PRÓXIMO). O último vivo vence e todos voltam ao lobby.
- **Progresso salvo:** nível, XP, vitórias e abates (DataStore).
- **Idiomas:** português e inglês, escolhidos automaticamente.

## Mapa
Uma ilha de 1400 x 1400 studs:
- **Cidade:** no centro, com praça, chafariz, casas de 1 e 2 andares e carros para se proteger.
- **Fazenda:** no nordeste, com celeiro, silos, feno e plantação.
- **Porto:** no sudoeste, com 2 armazéns com passarela, contêineres e guindaste.
- **Posto de gasolina:** no noroeste.
- **Torre de rádio:** no sudeste, em cima de um morro com bunker.
- **Florestas, morros, pedras e cabanas** espalhados pelo resto da ilha.

## Controles
- **PC:**
  - Clique esquerdo: atirar.
  - Clique direito: mirar (zoom).
  - R: recarregar.
  - E: pegar item.
  - 1 a 9: trocar de arma ou cura.
  - Para usar uma cura, segure ela na mão e clique.
- **Celular:** botão grande para atirar, botão MIRAR e botão ⟳ para recarregar.

## Modelos 3D (armas e itens de verdade)
O jogo já vem com armas e itens montados com peças. Para trocar por modelos 3D:
1. Gere ou importe o modelo. Dá para usar o gerador de 3D por IA do próprio Studio, a Creator Store ou o *3D Importer* com um arquivo `.glb`/`.fbx`.
2. Coloque o modelo em **ReplicatedStorage > Models3D**, com o nome exato da arma ou do item:
   - Armas: `Pistol`, `SMG`, `Rifle`, `Shotgun`, `Sniper`.
   - Curas: `Bandage`, `Medkit`, `ShieldCell`.
   - Munição: `Ammo`.
3. Deixe o cano virado para a frente (o lado *Front* do Studio).

O jogo ajusta o tamanho sozinho, encaixa na mão, no chão e nos bots, e remove qualquer script que vier junto do modelo.

## Sons
Os tiros ainda estão sem som. Em `ReplicatedStorage > Shared > Config`, no bloco `Config.Sounds`, cole os IDs de sons da Creator Store (`rbxassetid://...`).

## Ajustar o jogo
Todos os números ficam em `ReplicatedStorage > Shared > Config`:
- dano, cadência e pente das armas;
- chance de cada loot;
- tempo e tamanho de cada fase da zona;
- quantos bots completam a partida e a pontaria deles;
- XP de cada coisa.

## Antes de publicar
- **Game Settings > Security:** ligue *Enable Studio Access to API Services* para testar o salvamento no Studio.
- **Tamanho do servidor:** coloque 16 jogadores (Places > Server Size).
- **Questionário de maturidade:** responda com violência *Moderada* (armas, sem sangue). Assim o jogo fica para 13+, já que o Roblox não tem selo de 16+.

## Para quem programa
- `zonazero/src`: todos os scripts (Luau), um arquivo por script.
- `zonazero/builder/build.py`: gera o `.rbxlx` (mapa, lobby, iluminação e scripts). Rode com `python3 zonazero/builder/build.py`.
- O servidor decide tudo: o jogador só manda "atirei mirando aqui", e o servidor confere arma, munição e cadência e faz o próprio raio.
