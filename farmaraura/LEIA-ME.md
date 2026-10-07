# Farmar Aura: como está e como abrir

Arquivo do jogo: `place/FarmarAura.rbxlx`. Abra no Roblox Studio e dê Play.

O jogo usa o motor do Venda um Ovo v6, que já tem save seguro, loja, presentes, conquistas, placares e a interface de celular. Em cima dele trocamos o tema para aura. O desenho completo do jogo está em `PROMPT-JOGO-PERFEITO.md`.

## O que já funciona (fase 1)

- **Save novo** (`FarmarAura_v1`): não mistura com o Venda um Ovo.
- **Os 8 negócios de aura:** Pedra do Rio (posar), Canal de Cortes, Academia do Shape, Barco de Corrida, Estúdio de Phonk, Passarela, Estádio Lotado e Templo no Céu, com gerentes e melhorias. Os nomes e as cores já estão trocados; o visual dos prédios ainda é o antigo (veja abaixo).
- **POSAR:** cada toque dá um pulso de aura, e a cada 3 s o boneco faz um gesto (apontar, comemorar, acenar).
- **Aura no boneco**, para todo mundo ver:
  - a cor muda conforme a evolução (Branca → Azul → Verde → Roxa → Vermelha → Dourada → Arco-íris → Preta → do Vazio);
  - a aura equipada da coleção soma um 2º efeito (fogo, faísca, fumaça, vazio ou arco-íris);
  - longe da câmera, ou no Modo leve, fica mais fraca para não pesar no celular.
- **Coleção de Auras** (aba Auras, no botão dos Pets):
  - 20 auras em 8 raridades, de Comum (1 em 2) até Do Vazio (1 em 2,5 milhões);
  - os giros são **só grátis**: 1 por hora, presentes por tempo e Lua de Sangue;
  - a sorte sobe com o renascimento e na Lua de Sangue;
  - Épica garantida a cada 300 giros;
  - cada aura nova dá +1% de renda para sempre, e a equipada dá um bônus maior;
  - Épica ou melhor é anunciada no servidor; Mítica ou melhor, em todos os servidores.
- **Climas:**
  - Hora Dourada (pôr do sol, x2 nos 3 primeiros negócios);
  - Chuva de Phonk;
  - Vento Forte;
  - Lua de Sangue (céu vermelho, sorte x3 e +1 giro para todos);
  - **Fenda do Vazio** (céu roxo, tudo x4,5, rara).
- **Luz padrão de fim de tarde dourado**, com brilho nas auras, como nas artes de conceito.
- **Fãs no lugar de Estrelas:** renascer dá Fãs, cada um +2% de renda. Os títulos em cima da cabeça vão de Confiante até Imperador da Aura.

## O que falta (próximas fases)

1. **O mapa e os prédios com cara de aura:** rio, barco de corrida, estúdio e templo. Hoje o mapa ainda é o do Venda um Ovo, com os nomes novos.
   - Isso se faz no Studio, com os modelos 3D do Higgsfield e o `Instalar3D`.
   - O melhor jeito é o Claude Code no seu PC com o Studio conectado (veja a seção 13 do `PROMPT-JOGO-PERFEITO.md`).
2. **O Mestre** (NPC de renascer meditando na pedra), os 3 segredos e a Escadaria das Nuvens.
3. **Loja:** criar no Roblox os passes e produtos do jogo novo e colar os números em `Config.GamePasses` e `Config.Products`. Hoje estão com `Id = 0` (no Studio aparecem para você ver; publicado, ficam escondidos). O mesmo vale para os emblemas em `Config.Badges`.
4. **Músicas phonk:** escolher faixas liberadas no Creator Store e colocar em `Config.Sounds`.

## Para mudar números

Tudo fica em `src/ReplicatedStorage/Shared/Config.luau`:
- negócios e preços;
- `Config.Auras` e `Config.AuraTiers` (chances e bônus das auras);
- `Config.AuraRolls` (giro grátis, sorte e garantia);
- `Config.Weather` (climas);
- `Config.Seals` (cores da evolução);
- `Config.PlayRewards` (presentes por tempo).

Depois de mudar, rode `python3 farmaraura/tools/repack.py` para gerar o `.rbxlx` de novo.
