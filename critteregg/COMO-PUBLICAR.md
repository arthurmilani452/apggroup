# Como publicar a v65

## 1. Abrir no Studio
1. Baixe o **StealACritterEgg-v65.rbxl**: o Claude manda no chat, e ele também fica na pasta `place/`.
2. Abra o **Roblox Studio** e vá em **File > Open from File...**. Escolha o arquivo.
3. Para testar o salvamento no Studio: **Game Settings > Security > Enable Studio Access to API Services**.

> Prefere o Rojo? Copie a pasta `src` da v65 por cima da sua. Depois abra o seu jogo no Studio, clique em **Plugins > Rojo > Connect** e siga a partir do passo 3 da seção "Publicar".

## 2. Testar (5 minutos)
Aperte **Play** e confira a lista "Como testar no Studio" do `MUDANCAS-v65.md`: roubar, Halloween, Codes, taco e presentes.

## 3. Publicar POR CIMA do jogo que já existe
1. **File > Publish to Roblox As...**
2. Escolha o jogo **Steal a Critter Egg** que você já tem. **Não** clique em "Create new experience".
3. Escolha o lugar (place) dele e confirme para **substituir** (Overwrite).

Assim o jogo continua com os mesmos jogadores, o mesmo save e os mesmos itens de Robux.

## 4. Mandar todo mundo para a versão nova
Os servidores que já estão abertos continuam na versão velha. No **Creator Hub**:

1. Abra **Creations > Steal a Critter Egg**.
2. No menu "**...**" do jogo, escolha **Restart servers** ("Migrate to latest update").

As crianças passam para a versão nova sem perder nada.

## 5. Antes de 17/10 (Halloween) — no Creator Hub
- **Monetization:** confira se cada passe/produto do `Config` está listado **neste** jogo. Se não estiver, crie de novo e cole o número novo no `Config`.
- **Events > Create Event:**
  - "Halloween Event", de 17/10 a 02/11;
  - "Update Party", todo sábado às 14h.

  Aparece o botão "Avise-me" na página do jogo.
- **Questionário de maturidade:** responda que **não** há itens pagos sorteados (agora não há mesmo).
- **Ícone e thumbnails:** suba uma imagem de Halloween, por exemplo um bichinho Spooky gigante no pedestal com abóboras. Mande de 3 a 5 imagens: a Roblox testa qual funciona melhor.
- **Título:** `[🎃 HALLOWEEN] Steal a Critter Egg`.
- **Grupo:** poste os códigos `CRITTER` e `SPOOKY`.
- **Localization:** ligue a tradução automática para português e espanhol.

## 6. Toda semana
1. Solte a atualização no sábado às 14h. O Festão começa sozinho.
2. Crie 1 código novo em `Game.luau`, procurando `local CODES`.
3. Olhe **Analytics**:
   - **Funnels > Onboarding:** onde as crianças desistem;
   - **Economy:** de onde vem o dinheiro;
   - **Custom Events:** `CaughtInZone` diz em qual zona o guardião mais pega.
