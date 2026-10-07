--[[
	VENDA UM OVO (Sell an Egg) - configuração do jogo inteiro num lugar só.
	Preços, tempos, bônus, eventos, passes e TODOS os IDs de imagem/textura/som.
	Mudou um número aqui, o jogo inteiro segue (servidor e tela).

	Resumo do jogo (versão 4): tycoon de império de ovos, no molde dos grandes tycoons de "venda".
	O jogador começa com uma BANCA: clica, o freguês compra, as moedas caem no chão. Com as moedas pisa nos
	botões e abre 8 NEGÓCIOS em sequência (Banca, Granja, Entregas, Fábrica, Depósito, Omeleteria,
	Laboratório, Foguete). Cada negócio roda em ciclos, tem melhorias "x dinheiro" e "x velocidade" e um
	GERENTE que faz o ciclo sozinho (e rende com o jogador fora).
	A Granja libera 9 aves; cada ave nova multiplica TUDO. Ovos raros aparecem nos ninhos: VENDER
	(dinheiro + Álbum) ou CHOCAR (vira pet que dá bônus para sempre).
	Renascer dá Estrelas; Estrelas compram Talentos; muitas Estrelas liberam um Selo que multiplica tudo.
	O Mega Ovo da praça enche com o jogo de todo mundo do servidor e racha dando prêmios.
]]

local Config = {}

-- fora do Roblox (testes) não existe Color3: usa uma tabela simples no lugar
local Color3 = Color3 or { fromRGB = function(r: number, g: number, b: number): any
	return { R = r, G = g, B = b }
end }

Config.Version = 4
Config.DataStoreName = "VendaUmOvo_v4"
Config.LeaderboardStore = "VendaUmOvo_Top_v4"
Config.RebirthStore = "VendaUmOvo_Renasc_v1" -- v6: placar global de renascimentos
Config.MaxPlayers = 8
Config.GroupId = 869887016 -- grupo Critter Club Studios (0 = sem bônus de grupo)
Config.GroupBonus = 0.10 -- +10% para quem está no grupo
Config.PremiumBonus = 0.10 -- v6: +10% para assinante Roblox Premium (conta no "Amigos e grupo")

-- ---------------------------------------------------------------------------
-- IMAGENS, TEXTURAS e SONS ("rbxassetid://123"). Vazio = o jogo usa emoji/cor no lugar.
-- Estes campos são preenchidos pelo script de envio (tools/enviar_imagens.py).
-- ---------------------------------------------------------------------------
Config.Images = {
	Moeda = "rbxassetid://119056278715471",
	Cesta = "rbxassetid://109207854206824",
	Raio = "rbxassetid://98898010614779",
	Estrela = "rbxassetid://101586451519763",
	Presente = "rbxassetid://103767071253859",
	Trofeu = "rbxassetid://87533721707580",
	Ovo_Branco = "rbxassetid://99939076366001",
	Ovo_Caipira = "rbxassetid://92747719168161",
	Ovo_Pata = "rbxassetid://134307749634245",
	Ovo_Codorna = "rbxassetid://115742093909221",
	Ovo_Dourado = "rbxassetid://71693758034841",
	Ovo_Cristal = "rbxassetid://135744441429183",
	Ovo_ArcoIris = "rbxassetid://86816379689181",
	Ovo_Lunar = "rbxassetid://114781427882662",
	Ovo_Dragao = "rbxassetid://85334291948380",
	-- retratos (vista 3/4 das folhas de referência)
	R_Galinha_Comum = "rbxassetid://95158219636150",
	R_Galinha_Caipira = "rbxassetid://98227275894587",
	R_Pata = "rbxassetid://129898996386960",
	R_Codorna = "rbxassetid://103618991076378",
	R_Galinha_Dourada = "rbxassetid://102289995209784",
	R_Galinha_Cristal = "rbxassetid://114924826209509",
	R_Galinha_ArcoIris = "rbxassetid://121265915566745",
	R_Galinha_Lunar = "rbxassetid://124217333895830",
	R_Filhote_Dragao = "rbxassetid://77784409174130",
	R_Ovo_Branco = "rbxassetid://129766169466085",
	R_Ovo_Caipira = "rbxassetid://104515118384369",
	R_Ovo_Pata = "rbxassetid://111622278322998",
	R_Ovo_Codorna = "rbxassetid://116612793333994",
	R_Ovo_Dourado = "rbxassetid://76862494020066",
	R_Ovo_Cristal = "rbxassetid://111205600127919",
	R_Ovo_ArcoIris = "rbxassetid://76275868137307",
	R_Ovo_Lunar = "rbxassetid://115629223596343",
	R_Ovo_Dragao = "rbxassetid://121063774222724",
	R_Ninho = "rbxassetid://136667928465353",
	R_Galinheiro = "rbxassetid://119017147167897",
	R_Cesta = "rbxassetid://104461717559333",
	R_Banca = "rbxassetid://106860513171134",
	R_Esteira = "rbxassetid://137680957885165",
	R_Cerca = "rbxassetid://133962002656518",
	R_Placa = "rbxassetid://91669807887321",
	R_Arvore = "rbxassetid://136231901292726",
	R_Feno = "rbxassetid://101909823977285",
	R_Moinho = "rbxassetid://99981702731058",
	-- ícones da versão 4 (negócios, loja e botões da tela)
	Biz_banca = "rbxassetid://118504351524896",
	Biz_granja = "rbxassetid://92223502259670",
	Biz_entrega = "rbxassetid://134846869693037",
	Biz_fabrica = "rbxassetid://128382312425030",
	Biz_deposito = "rbxassetid://116811818900300",
	Biz_omeleteria = "rbxassetid://124725374509222",
	Biz_lab = "rbxassetid://112451650844611",
	Biz_foguete = "rbxassetid://74923910671596",
	VIP = "rbxassetid://105289103759303",
	SuperClique = "rbxassetid://84088456681215",
	Ima = "rbxassetid://77390903187144",
	Trevo = "rbxassetid://87428265115046",
	Celular = "rbxassetid://110900545980164",
	Lua = "rbxassetid://120388032192072",
	Pacote = "rbxassetid://125028929542748",
	Relogio = "rbxassetid://133641504975158",
	Sacola = "rbxassetid://104463227592311",
	Negocios = "rbxassetid://115941127891937",
	Pet = "rbxassetid://105996002771070",
	Renascer = "rbxassetid://87660741352005",
	Premios = "rbxassetid://80402895173946",
	Casa = "rbxassetid://77711991285037",
	Praca = "rbxassetid://96051617755827",
	Config = "rbxassetid://98055142320572",
	Gerente = "rbxassetid://92241483968240",
	Saco = "rbxassetid://117271586483150",
}
-- retrato de cada pet especial (os pets comuns usam o retrato da ave da linha)
Config.PetIcon = { ovinho = "Ovo_Dourado" }

Config.Textures = {
	Grama = "rbxassetid://96816101996579",
	Terra = "rbxassetid://124528026224168",
	Palha = "rbxassetid://73181859980293",
	Madeira = "rbxassetid://73959460543878",
	Telha = "rbxassetid://129191361563452",
}
Config.TextureTile = 22 -- tamanho (studs) de cada repetição
-- 0 = textura pura; 0.5 = metade textura, metade a cor da peça (deixa o chão menos "gritante")
Config.TextureFade = { Grama = 0.35, Terra = 0.55, Palha = 0.2, Madeira = 0.2, Telha = 0.2 }

Config.Sounds = {
	Coletar = "rbxassetid://15675055424",
	Vender = "rbxassetid://127645268874265",
	Comprar = "rbxassetid://17208380755",
	Mutante = "rbxassetid://17208327798",
	Renascer = "rbxassetid://15675016548",
	Evento = "rbxassetid://17208361335",
	Chocar = "rbxassetid://15675043410",
	Roleta = "rbxassetid://15675032796",
	Premio = "rbxassetid://10066947742",
	Erro = "rbxassetid://17208353912",
	Clique = "rbxassetid://15675059323",
	Gigante = "rbxassetid://3149249837",
	Musica = "rbxassetid://15930255433",
}
Config.MusicVolume = 0.25

-- ---------------------------------------------------------------------------
-- AVES (espécies da Granja). A 1ª vem com a Granja; cada uma das outras é um botão "ave_<id>" que
-- multiplica TODA a renda por Cash (ovo melhor = tudo vale mais) e enche mais um cercado.
-- Asset/EggAsset = Models em ReplicatedStorage > Assets.
-- ---------------------------------------------------------------------------
Config.Lines = {
	{ Id = "branco", Asset = "Galinha_Comum", EggAsset = "Ovo_Branco", Cash = 1, Color = Color3.fromRGB(245, 242, 235) },
	{ Id = "caipira", Asset = "Galinha_Caipira", EggAsset = "Ovo_Caipira", Cash = 1.5, Color = Color3.fromRGB(196, 132, 84) },
	{ Id = "pata", Asset = "Pata", EggAsset = "Ovo_Pata", Cash = 1.5, Color = Color3.fromRGB(160, 222, 208) },
	{ Id = "codorna", Asset = "Codorna", EggAsset = "Ovo_Codorna", Cash = 1.5, Color = Color3.fromRGB(226, 196, 150) },
	{ Id = "dourado", Asset = "Galinha_Dourada", EggAsset = "Ovo_Dourado", Cash = 2, Color = Color3.fromRGB(255, 200, 50) },
	{ Id = "cristal", Asset = "Galinha_Cristal", EggAsset = "Ovo_Cristal", Cash = 2, Color = Color3.fromRGB(140, 215, 255) },
	{ Id = "arcoiris", Asset = "Galinha_ArcoIris", EggAsset = "Ovo_ArcoIris", Cash = 2, Color = Color3.fromRGB(255, 110, 190) },
	{ Id = "lunar", Asset = "Galinha_Lunar", EggAsset = "Ovo_Lunar", Cash = 2, Color = Color3.fromRGB(70, 80, 170) },
	{ Id = "dragao", Asset = "Filhote_Dragao", EggAsset = "Ovo_Dragao", Cash = 3, Color = Color3.fromRGB(225, 60, 40), Legendary = true },
}
Config.BirdsPerPen = 4

-- ---------------------------------------------------------------------------
-- NEGÓCIOS, na ordem em que abrem. Payout = moedas por ciclo (antes dos multiplicadores);
-- Cycle = segundos por ciclo (antes das melhorias de velocidade). Renda/s = Payout x dinheiro x velocidade / Cycle.
-- Sem gerente o jogador faz o ciclo (banca: clicando; os outros: ficando no tapete azul do negócio) e as
-- moedas caem no chão, valendo HandBonus. Com gerente o ciclo roda sozinho e o dinheiro entra direto.
-- ---------------------------------------------------------------------------
Config.Businesses = {
	{ Id = "banca", Payout = 1, Cycle = 1, Color = Color3.fromRGB(235, 70, 60) },
	{ Id = "granja", Payout = 120, Cycle = 3, Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "entrega", Payout = 800, Cycle = 6, Color = Color3.fromRGB(255, 140, 40) },
	{ Id = "fabrica", Payout = 8000, Cycle = 8, Color = Color3.fromRGB(70, 160, 255) },
	{ Id = "deposito", Payout = 100000, Cycle = 12, Color = Color3.fromRGB(200, 60, 50) },
	{ Id = "omeleteria", Payout = 1.2e6, Cycle = 16, Color = Color3.fromRGB(255, 110, 190) },
	{ Id = "lab", Payout = 1.5e7, Cycle = 24, Color = Color3.fromRGB(60, 200, 190) },
	{ Id = "foguete", Payout = 1.8e8, Cycle = 36, Color = Color3.fromRGB(170, 90, 230) },
}

-- Melhorias de cada negócio: duas filas de botões. cash = multiplica o dinheiro do ciclo; speed = ciclo mais rápido.
-- { nome, multiplicador, campos extras }. O id do botão é "<negócio>_<nome>". Cada uma também põe um enfeite
-- no prédio (ver Layout.Props).
Config.Upgrades = {
	banca = {
		cash = { { "caixas", 2 }, { "placa", 3 }, { "geladeira", 3 }, { "ouro", 7 } },
		speed = { { "panfletos", 3 }, { "baloes", 5 }, { "promo", 10 } },
	},
	granja = {
		cash = { { "racao", 2 }, { "premium", 2 }, { "ninhos", 5 }, { "racaoouro", 10 } },
		speed = { { "luz", 2 }, { "festa", 3 }, { "galinheiro", 7 } },
	},
	entrega = {
		cash = { { "taxa", 2 }, { "plus", 2 }, { "gorjeta", 5 }, { "app", 10 } },
		speed = { { "van2", 2 }, { "expressa", 3 }, { "van3", 7 } },
	},
	fabrica = {
		cash = { { "lavadora", 2 }, { "carimbo", 2 }, { "pintora", 5 }, { "embaladora", 10 } },
		speed = { { "esteira", 2 }, { "motor", 3 }, { "robo", 7 } },
	},
	deposito = {
		cash = { { "celeiro2", 2 }, { "silo", 2 }, { "celeiro4", 5, OfflineHours = 24 }, { "celeiro5", 10 } },
		speed = { { "frota", 2 }, { "gps", 3 }, { "turbo", 7 } },
	},
	omeleteria = {
		cash = { { "cardapio", 2 }, { "chef", 2 }, { "mesas", 5 }, { "estrela", 6 } },
		speed = { { "fogao", 2 }, { "delivery", 3 }, { "rodizio", 5 } },
	},
	lab = {
		cash = { { "microscopio", 2 }, { "proveta", 2 }, { "patente", 4 }, { "superovo", 5 } },
		speed = { { "computador", 2 }, { "robos", 3 }, { "acelerador", 4 } },
	},
	foguete = {
		cash = { { "carga", 2 }, { "estacao", 2 }, { "lunar", 3 }, { "marte", 4 } },
		speed = { { "gema", 2 }, { "reuso", 2 }, { "dobra", 3 } },
	},
}

-- Botões gerais (não são de um negócio). Spot = lugar no terreno (Layout.Global[Spot]).
-- Efeitos: Basket (ovos raros que cabem na cesta), Hatch (+1 chocadeira), Tree (macieira), Tractor,
-- Cash (multiplica tudo), SpeedAll (todos os negócios mais rápidos).
Config.GlobalButtons = {
	{ Kind = "incubator1", Spot = "inc1", Requires = "granja_unlock", Hatch = 1 },
	{ Kind = "basket1", Spot = "basket", Requires = "granja_unlock", Basket = 8 },
	{ Kind = "tree", Spot = "tree", Requires = "entrega_unlock", Tree = true },
	{ Kind = "sign", Spot = "sign", Requires = "fabrica_unlock", Cash = 2 },
	{ Kind = "tractor", Spot = "tractor", Requires = "fabrica_unlock", Tractor = true },
	{ Kind = "incubator2", Spot = "inc2", Requires = "G_incubator1", Hatch = 1 },
	{ Kind = "basket2", Spot = "basket", Requires = "G_basket1", Basket = 20 },
	{ Kind = "fence", Spot = "fence", Requires = "omeleteria_unlock", Cash = 1.5 },
	{ Kind = "windmill", Spot = "windmill", Requires = "lab_unlock", SpeedAll = 2 },
	{ Kind = "incubator3", Spot = "inc3", Requires = "G_incubator2", Hatch = 1 },
	{ Kind = "basket3", Spot = "basket", Requires = "G_basket2", Basket = 50 },
}

-- ---------------------------------------------------------------------------
-- ORDEM PLANEJADA das compras (1ª corrida). O gerador de preços (tests/gen_costs.luau) usa esta ordem:
-- a compra k custa o que o jogador de referência junta em CostW0 * CostR^(k-1) segundos.
-- Todo botão do jogo aparece aqui exatamente uma vez.
-- ---------------------------------------------------------------------------
Config.CostW0 = 4.5
Config.CostR = 1.068
Config.Order = {
	"banca_unlock", "banca_caixas", "banca_placa", "banca_gerente", "banca_panfletos",
	"granja_unlock", "granja_racao", "granja_luz", "granja_premium", "granja_gerente", "G_incubator1", "ave_caipira", "banca_geladeira", "G_basket1",
	"entrega_unlock", "entrega_taxa", "entrega_van2", "entrega_plus", "entrega_gerente", "ave_pata", "granja_festa", "banca_baloes", "G_tree",
	"fabrica_unlock", "fabrica_lavadora", "fabrica_esteira", "fabrica_carimbo", "fabrica_gerente", "ave_codorna", "G_sign", "entrega_expressa", "granja_ninhos", "banca_ouro", "G_tractor",
	"deposito_unlock", "deposito_celeiro2", "deposito_frota", "deposito_silo", "deposito_gerente", "ave_dourado", "fabrica_motor", "entrega_gorjeta", "granja_galinheiro", "banca_promo", "G_incubator2", "G_basket2",
	"omeleteria_unlock", "omeleteria_cardapio", "omeleteria_fogao", "omeleteria_chef", "omeleteria_gerente", "ave_cristal", "G_fence", "deposito_gps", "fabrica_pintora", "entrega_van3", "granja_racaoouro", "G_incubator3",
	"lab_unlock", "lab_microscopio", "lab_computador", "lab_proveta", "lab_gerente", "ave_arcoiris", "G_windmill", "omeleteria_delivery", "deposito_celeiro4", "fabrica_robo", "entrega_app",
	"foguete_unlock", "foguete_carga", "foguete_gema", "foguete_estacao", "ave_lunar", "lab_robos", "omeleteria_mesas", "deposito_turbo", "fabrica_embaladora", "G_basket3",
	"ave_dragao", "foguete_reuso", "lab_patente", "foguete_gerente", "omeleteria_rodizio", "deposito_celeiro5", "foguete_lunar", "lab_acelerador", "omeleteria_estrela", "foguete_dobra", "lab_superovo", "foguete_marte",
}

-- PREÇOS DOS BOTÕES (gerados por tests/gen_costs.luau). Pode mudar à mão; quem manda é esta tabela.
-- v6: do Depósito em diante a espera entre compras cresce 4,2% por compra (antes 6,8%): o meio do jogo não
-- trava mais (Omeleteria ~20 min, Laboratório ~37 min, Foguete ~60 min para o jogador de referência).
-- tempo total do jogador de referência: 7:12:02  |  banca 0.0min  granja 0.5min  entrega 1.8min  fabrica 4.1min  deposito 9.7min  omeleteria 22.6min  lab 51.2min  foguete 106.7min
-- ganho total da corrida: 20Qa  |  renda final: 9.2T/s
Config.ButtonCost = {
	banca_unlock = 0,
	banca_caixas = 29,
	banca_placa = 62,
	banca_gerente = 200,
	banca_panfletos = 250,
	granja_unlock = 340,
	granja_racao = 410,
	granja_luz = 780,
	granja_premium = 1.6e+03,
	granja_gerente = 3.4e+03,
	G_incubator1 = 3.6e+03,
	ave_caipira = 3.9e+03,
	banca_geladeira = 6.3e+03,
	G_basket1 = 8.7e+03,
	entrega_unlock = 9.3e+03,
	entrega_taxa = 1.2e+04,
	entrega_van2 = 1.7e+04,
	entrega_plus = 2.8e+04,
	entrega_gerente = 4e+04,
	ave_pata = 4.3e+04,
	granja_festa = 7.1e+04,
	banca_baloes = 1.1e+05,
	G_tree = 1.3e+05,
	fabrica_unlock = 1.4e+05,
	fabrica_lavadora = 2.5e+05,
	fabrica_esteira = 3.8e+05,
	fabrica_carimbo = 6.5e+05,
	fabrica_gerente = 8.4e+05,
	ave_codorna = 8.9e+05,
	G_sign = 1.5e+06,
	entrega_expressa = 3.2e+06,
	granja_ninhos = 4.1e+06,
	banca_ouro = 5.7e+06,
	G_tractor = 7e+06,
	deposito_unlock = 7.4e+06,
	deposito_celeiro2 = 1.3e+07,
	deposito_frota = 1.9e+07,
	deposito_silo = 3.3e+07,
	deposito_gerente = 4.1e+07,
	ave_dourado = 4.2e+07,
	fabrica_motor = 9.5e+07,
	entrega_gorjeta = 1.2e+08,
	granja_galinheiro = 1.3e+08,
	banca_promo = 1.8e+08,
	G_incubator2 = 2e+08,
	G_basket2 = 2.1e+08,
	omeleteria_unlock = 2.2e+08,
	omeleteria_cardapio = 4.1e+08,
	omeleteria_fogao = 6.1e+08,
	omeleteria_chef = 1e+09,
	omeleteria_gerente = 1.3e+09,
	ave_cristal = 1.3e+09,
	G_fence = 2.9e+09,
	deposito_gps = 4.6e+09,
	fabrica_pintora = 5.6e+09,
	entrega_van3 = 6.6e+09,
	granja_racaoouro = 7.6e+09,
	G_incubator3 = 1e+10,
	lab_unlock = 1.1e+10,
	lab_microscopio = 1.9e+10,
	lab_computador = 2.8e+10,
	lab_proveta = 4.6e+10,
	lab_gerente = 6e+10,
	ave_arcoiris = 5.9e+10,
	G_windmill = 1.3e+11,
	omeleteria_delivery = 2.7e+11,
	deposito_celeiro4 = 3.4e+11,
	fabrica_robo = 3.9e+11,
	entrega_app = 4.3e+11,
	foguete_unlock = 5.1e+11,
	foguete_carga = 9.5e+11,
	foguete_gema = 1.4e+12,
	foguete_estacao = 2.4e+12,
	ave_lunar = 4.6e+12,
	lab_robos = 9.7e+12,
	omeleteria_mesas = 1.2e+13,
	deposito_turbo = 1.3e+13,
	fabrica_embaladora = 1.5e+13,
	G_basket3 = 1.7e+13,
	ave_dragao = 1.7e+13,
	foguete_reuso = 5.8e+13,
	lab_patente = 9.4e+13,
	foguete_gerente = 1e+14,
	omeleteria_rodizio = 1e+14,
	deposito_celeiro5 = 1.3e+14,
	foguete_lunar = 1.8e+14,
	lab_acelerador = 3.1e+14,
	omeleteria_estrela = 4.6e+14,
	foguete_dobra = 6.6e+14,
	lab_superovo = 1.1e+15,
	foguete_marte = 2e+15,
}

Config.StartBasket = 3 -- ovos raros que cabem na cesta no começo
Config.HandBonus = 2 -- ciclo feito pelo jogador (sem gerente) vale 2x
Config.ClickRadius = 15 -- distância máxima da banca para o clique valer
Config.ClickMaxPerSecond = 9 -- cliques por segundo que o servidor aceita
Config.WorkRadius = 5 -- raio do tapete azul de trabalho
Config.MinCycle = 0.35 -- ciclo manual nunca é mais curto que isto (segundos)

-- Gorjetas: com um gerente trabalhando, os fregueses deixam moedas no chão da banca (vale passar para pegar).
Config.TipEvery = 32 -- segundos entre gorjetas
Config.TipSeconds = 2 -- cada gorjeta vale isto em segundos de renda
Config.TipMax = 6 -- gorjetas esperando no chão

-- ---------------------------------------------------------------------------
-- OVOS RAROS: de tempos em tempos um ovo raro aparece num ninho da Granja. O jogador pega andando e
-- escolhe: VENDER atrás do balcão (vale Seconds segundos de renda e cola no Álbum) ou CHOCAR.
-- Weight = peso no sorteio da raridade.
-- ---------------------------------------------------------------------------
Config.Mutations = {
	{ Id = "s", Key = "shiny", Weight = 88, Seconds = 3, Color = Color3.fromRGB(255, 235, 120), Scale = 1.15 },
	{ Id = "g", Key = "giant", Weight = 10.5, Seconds = 15, Color = Color3.fromRGB(120, 255, 170), Scale = 1.7 },
	{ Id = "m", Key = "mythic", Weight = 1.5, Seconds = 100, Color = Color3.fromRGB(200, 120, 255), Scale = 1.4 },
}
Config.RareEvery = 45 -- segundos entre ovos raros (a Sorte divide este tempo)
Config.RareFirst = 15 -- o 1º ovo raro da vida aparece rápido (ensina a chocadeira) e é sempre brilhante
Config.RareMax = 6 -- ovos raros esperando nos ninhos
Config.AlbumBonus = 0.02 -- cada figurinha do Álbum (ovo x variação) dá +2% de renda para sempre

-- ---------------------------------------------------------------------------
-- PETS: ovo raro levado à chocadeira vira pet. Pet equipado dá bônus de renda. Pets NUNCA somem
-- (ficam depois de renascer e de selo). Pet repetido sobe de nível.
--   bônus = LineBonus[linha] * RarityMult[raridade] * (1 + LevelBonus * (nível - 1))
-- ---------------------------------------------------------------------------
Config.Pets = {
	LineBonus = { 0.01, 0.01, 0.012, 0.014, 0.016, 0.018, 0.02, 0.025, 0.03 },
	RarityMult = { s = 1, g = 2, m = 4 },
	LevelBonus = 0.1,
	MaxLevel = 10,
	Slots = 2, -- pets equipados no começo
	SlotAt = { 6, 14, 24 }, -- +1 vaga ao juntar tantos pets DIFERENTES (o passe MaisPets dá mais 2)
	Scale = 0.55, -- tamanho do pet em relação à ave
}
Config.HatchTime = { s = 60, g = 240, m = 900 } -- segundos na chocadeira, por raridade
Config.FirstHatchTime = 10 -- o primeiro pet da vida nasce rápido
Config.IncubatorRadius = 6
-- pets especiais (não vêm de ave): Bonus fixo. O do Ovo Gigante muda de variante toda semana.
Config.SpecialPets = {
	ovinho = { Asset = "Pet_Ovinho", Bonus = 0.1 },
}

-- ---------------------------------------------------------------------------
-- ROLETA: um giro grátis a cada FreeEvery segundos (tempo real) + giros ganhos (obby, Ovo Gigante).
-- Weight = peso no sorteio. Seconds = segundos de renda; Stars; Boost; Egg = ovo raro da melhor linha.
-- ---------------------------------------------------------------------------
Config.Wheel = {
	FreeEvery = 3600, -- v6: de 4 h para 1 h (motivo para voltar ao jogo várias vezes no dia)
	MaxBanked = 20,
	Prizes = {
		{ Id = "coins1", Weight = 30, Seconds = 12, Min = 100, Color = Color3.fromRGB(235, 70, 60) },
		{ Id = "stars1", Weight = 12, Stars = 3, Color = Color3.fromRGB(255, 140, 40) },
		{ Id = "coins2", Weight = 22, Seconds = 50, Min = 400, Color = Color3.fromRGB(255, 205, 50) },
		{ Id = "turbo", Weight = 10, Boost = "Turbo", BoostSeconds = 600, Color = Color3.fromRGB(80, 200, 90) },
		{ Id = "egg", Weight = 6, Egg = "s", Color = Color3.fromRGB(70, 200, 230) },
		{ Id = "coins3", Weight = 7, Seconds = 180, Min = 2000, Color = Color3.fromRGB(70, 120, 255) },
		{ Id = "luck", Weight = 9, Boost = "Sorte", BoostSeconds = 600, Color = Color3.fromRGB(170, 90, 230) },
		{ Id = "stars2", Weight = 4, Stars = 15, Color = Color3.fromRGB(255, 110, 190) },
	},
}

-- OBBY da praça: chegar ao baú dá prêmio (uma vez a cada Cooldown segundos)
Config.Obby = { Seconds = 50, Min = 400, Spins = 1, Cooldown = 900, Radius = 7 }

-- ---------------------------------------------------------------------------
-- OVO GIGANTE da praça: todo mundo do servidor enche junto. Cada jogador ativo soma 1 ponto por
-- segundo + pontos ao vender na mão, chocar e comprar. Meta = Target * jogadores ^ 0.85.
-- Quando enche: racha, todos ganham Seconds de renda (x NearBonus se estiver perto), 1 giro na roleta
-- para quem está perto e chance de ganhar o pet exclusivo da semana.
-- ---------------------------------------------------------------------------
Config.Giant = {
	Target = 600,
	Seconds = 20,
	Min = 300,
	NearRadius = 80,
	NearBonus = 2,
	Countdown = 15,
	PetChance = 0.1,
	Pity = 8, -- garante o pet depois de tantas rachaduras sem ganhar
	SellPoints = 0.4, -- pontos por ovo vendido na mão (até SellMax por venda)
	SellMax = 20,
	HatchPoints = 15,
	BuyPoints = 3,
	WorkPoints = 0.15, -- por ciclo feito na mão
	Variants = { "ouro", "cristal", "arcoiris", "lunar", "dragao" },
	VariantColor = {
		ouro = Color3.fromRGB(255, 205, 50),
		cristal = Color3.fromRGB(140, 215, 255),
		arcoiris = Color3.fromRGB(255, 110, 190),
		lunar = Color3.fromRGB(120, 130, 255),
		dragao = Color3.fromRGB(240, 80, 50),
	},
}

-- TRATOR (dá para dirigir; pega os ovos dos ninhos ao passar)
Config.Tractor = { Speed = 40, Turn = 2.2 }

-- ---------------------------------------------------------------------------
-- RENASCER: zera a granja e dá Estrelas. Cada Estrela ganha = +2% de renda.
--   Total de estrelas = StarK * (tudo que ganhou desde o último Selo / StarBase) ^ StarPow
--   Renascer entrega a diferença para o que já recebeu (não adianta renascer toda hora).
-- ---------------------------------------------------------------------------
Config.RebirthMinStars = 15 -- v6: era 30; o 1º renascimento chega mais cedo -- só pode renascer quando for ganhar pelo menos isto
Config.StarBase = 1e6
Config.StarK = 1
Config.StarPow = 0.3
Config.StarBonus = 0.02

-- TALENTOS: comprados com Estrelas. Costs[n] leva ao nível n. Values[n] = efeito no nível n.
Config.Talents = {
	{ Id = "speed", Icon = "Raio", Costs = { 8, 60, 400, 2500 }, Values = { 1.25, 1.5, 1.75, 2 } },
	{ Id = "basket", Icon = "Cesta", Costs = { 10, 100, 1000 }, Values = { 1.5, 2, 3 } },
	{ Id = "hands", Icon = "Moeda", Costs = { 15, 150, 1500 }, Values = { 2, 4, 8 } },
	{ Id = "luck", Icon = "Estrela", Costs = { 25, 250, 2000 }, Values = { 1.15, 1.3, 1.5 } },
	{ Id = "magnet", Icon = "Ovo_Dourado", Costs = { 40, 400, 3000 }, Values = { 14, 26, 60 } },
	{ Id = "remote", Icon = "Trofeu", Costs = { 120 }, Values = { 1 } },
}
Config.BaseWalkSpeed = 18
Config.CollectRadius = 7 -- sem talento: pega moedas, gorjetas e ovos raros chegando a esta distância

-- SELOS (evolução): precisa de Estrelas TOTAIS; zera Estrelas e Talentos, multiplica a renda para sempre.
Config.SealMult = 8
Config.Seals = {
	{ Id = "bronze", Stars = 300, Color = Color3.fromRGB(205, 127, 50) },
	{ Id = "prata", Stars = 25000, Color = Color3.fromRGB(200, 205, 215) },
	{ Id = "ouro", Stars = 79000, Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "cristal", Stars = 240000, Color = Color3.fromRGB(140, 215, 255) },
	{ Id = "arcoiris", Stars = 720000, Color = Color3.fromRGB(255, 110, 190) },
	{ Id = "lunar", Stars = 2.1e6, Color = Color3.fromRGB(90, 100, 200) },
	{ Id = "dragao", Stars = 6.4e6, Color = Color3.fromRGB(225, 60, 40) },
}

-- ---------------------------------------------------------------------------
-- RENDA OFFLINE: só as linhas com esteira rendem com o jogador fora.
-- ---------------------------------------------------------------------------
Config.OfflineRate = 1 -- 100% da renda automática
Config.OfflineCap = 12 * 3600 -- no máximo 12 horas
Config.OfflineMin = 60 -- só mostra o aviso depois de 1 minuto fora

-- ---------------------------------------------------------------------------
-- PRÊMIOS "em segundos de renda": crescem junto com a granja do jogador.
-- ---------------------------------------------------------------------------
Config.MinIncomeForRewards = 1 -- renda mínima (moedas/s) usada na conta dos prêmios

-- Encomenda (pedido especial que aparece na tela)
Config.OrderEvery = { 240, 360 } -- segundos entre encomendas
Config.OrderSeconds = { 10, 20 } -- vale isto em segundos de renda
Config.OrderHaggleChance = 0.5
Config.OrderHaggleBonus = { 0.25, 1.0 } -- pedir mais: +25% a +100% se der certo; se der errado, perde
Config.OrderTimeout = 30
Config.OrderMinButtons = 10 -- encomendas só depois de tantos botões comprados

-- Macieira
Config.AppleEvery = 100
Config.AppleMax = 6
Config.AppleSeconds = 4
Config.GoldenAppleChance = 0.1
Config.GoldenAppleMult = 10

-- ---------------------------------------------------------------------------
-- SACO DE DINHEIRO: de tempos em tempos cai um saco num canto livre do terreno (Layout.BagSpots), com um
-- facho de luz dourado. Só o dono pega (encostando); se ninguém pegar, some. Só para quem já abriu a banca.
-- É surpresa, não salário: os números foram escolhidos para o saco render de 3% a 6% do dinheiro de um
-- jogador ativo (medido por tests/pace_bot.luau). Quer mexer? Mude AQUI e rode o robô de novo.
-- ---------------------------------------------------------------------------
Config.MoneyBag = {
	Every = { 150, 240 }, -- segundos de jogo entre um saco e o próximo (sorteado; conta depois que o anterior saiu do chão)
	First = { 50, 80 }, -- o 1º saco da vida cai mais cedo (ensina a brincadeira)
	Seconds = { 7, 11 }, -- vale isto em segundos de renda (sorteado)
	Min = 50, -- no mínimo estas moedas (começo do jogo, renda ainda pequena)
	Life = 75, -- segundos no chão antes de sumir
	GoldenEvery = 8, -- 1 em cada tantos sacos é DOURADO...
	GoldenMult = 4, -- ...e vale tantas vezes mais
	Radius = 7, -- distância para pegar (fixa: o Ímã não puxa o saco; a graça é correr até a luz)
	Near = { 20, 75 }, -- cai a esta distância do dono (nem em cima dele, nem do outro lado do terreno)
	Scale = 1.5, -- tamanho do modelo; o dourado usa GoldenScale
	GoldenScale = 2.3,
	Color = Color3.fromRGB(255, 205, 50),
}

-- Eventos do servidor (um a cada EventEvery segundos, em rodízio)
Config.EventEvery = 240
Config.EventFirst = 180
Config.Events = {
	{ Id = "rain", Duration = 60, Speed = 3 }, -- Chuva de Milho: aves botam 3x mais rápido
	{ Id = "gift", Duration = 50, Seconds = { 12, 36 } }, -- Ovo Surpresa na praça
	{ Id = "race", Pick = 25, Run = 14, Seconds = { 30, 14, 6, 2 } }, -- Corrida de Galinhas
}

-- Caça aos ovos escondidos pelo mapa
Config.HuntStars = 3 -- Estrelas por ovo achado
Config.HuntAllBonus = 1.5 -- achou todos: renda x1,5 para sempre

-- ---------------------------------------------------------------------------
-- CLIMA (versão 5). O servidor inteiro tem um clima de cada vez; ele troca sozinho. Todo clima só AJUDA:
-- cada um faz 2 negócios pagarem Mult vezes por ciclo (os 8 negócios aparecem uma vez cada), o "limpo"
-- deixa tudo normal e o arco-íris (raro e curto) ajuda TUDO e faz ovos raros virem Rare vezes mais rápido.
-- Não vale para prêmios nem para renda offline (Sim.BaseCtx não leva o clima). Regras: Sim.Weather*.
-- ---------------------------------------------------------------------------
Config.Weather = {
	First = 45, -- o servidor começa "limpo"; o 1º clima sorteado entra depois de tantos segundos
	List = {
		{ Id = "limpo", Emoji = "⛅", Weight = 3, Seconds = { 100, 140 }, Biz = {}, Mult = 1 },
		{ Id = "sol", Emoji = "☀️", Weight = 2, Seconds = { 120, 160 }, Biz = { 1, 6 }, Mult = 1.3 }, -- banca e omeleteria
		{ Id = "chuva", Emoji = "🌧️", Weight = 2, Seconds = { 120, 160 }, Biz = { 2, 4 }, Mult = 1.3 }, -- granja e fábrica
		{ Id = "vento", Emoji = "🍃", Weight = 2, Seconds = { 120, 160 }, Biz = { 3, 5 }, Mult = 1.3 }, -- entregas e depósito
		{ Id = "noite", Emoji = "🌙", Weight = 2, Seconds = { 120, 160 }, Biz = { 7, 8 }, Mult = 1.3 }, -- laboratório e foguete
		{ Id = "arcoiris", Emoji = "🌈", Weight = 1, Seconds = { 60, 75 }, All = true, Mult = 1.5, Rare = 2 },
	},
}

-- ---------------------------------------------------------------------------
-- CHAVES SECRETAS e BAÚ SECRETO (versão 5). De tempos em tempos uma chave aparece ESCONDIDA no terreno do
-- jogador (sem facho de luz: é para procurar). Com Need chaves ele abre o Baú Secreto do terreno: moedas
-- (Seconds de renda, no mínimo Min); 1 em cada GoldenEvery baús é dourado (GoldenMult vezes as moedas +
-- GoldenSpins giros da roleta). Tudo grátis: chave e baú NÃO são vendidos (nada sorteado é pago). Regras: Sim.Key*/Sim.*Chest.
-- ---------------------------------------------------------------------------
Config.Keys = {
	MinBiz = 3, -- v6: só depois de abrir 3 negócios (antes era 2: muita coisa nova logo no começo)
	First = { 25, 40 }, -- 1ª chave da vida: segundos de jogo depois de liberar
	Every = { 100, 160 }, -- segundos de jogo entre uma chave pega e a próxima aparecer
	Need = 3, -- chaves para abrir o baú (com Need na mão não nasce outra)
	Radius = 6, -- distância para pegar a chave
	ChestRadius = 7, -- distância para abrir o baú
	Hint = 40, -- depois de tantos segundos sem achar, a chave passa a brilhar forte (ninguém fica travado)
	Chest = { Seconds = { 30, 50 }, Min = 400, Spins = 0, GoldenSpins = 1, GoldenEvery = 5, GoldenMult = 3 },
	Color = Color3.fromRGB(255, 200, 60),
}

-- ---------------------------------------------------------------------------
-- PODERES (versão 5). Botões na tela que o jogador aperta quando quiser; cada um recarrega sozinho
-- (Cooldown em segundos de relógio, guardado no save). Liberam com MinBiz negócios abertos.
--   galo   = todos os negócios Speed vezes mais rápidos por Duration segundos
--   moedas = paga na hora Seconds segundos de renda (no mínimo Min)
--   sorte  = faz aparecer agora, num ninho livre, um ovo raro com a mutação Mut
-- Regras: Sim.PowerInfo / Sim.UsePower. O produto "Recarga" (Config.Products) zera as recargas.
-- ---------------------------------------------------------------------------
Config.Powers = {
	{ Id = "galo", Emoji = "🐓", MinBiz = 3, Cooldown = 300, Duration = 20, Speed = 2, Color = Color3.fromRGB(255, 120, 60) },
	{ Id = "moedas", Emoji = "🪙", MinBiz = 4, Cooldown = 360, Seconds = 15, Min = 300, Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "sorte", Emoji = "🍀", MinBiz = 6, Cooldown = 600, Mut = "g", Color = Color3.fromRGB(90, 210, 110) },
}

-- Curtir a granja de outro jogador
Config.LikeSeconds = 6

-- Amigos no mesmo servidor
Config.FriendBonus = 0.2 -- +20% por amigo
Config.FriendBonusMax = 1.0

-- Missões diárias, presente por tempo e sequência de dias
Config.DailyMissionCount = 3
Config.Missions = {
	{ Id = "work", Base = 60 }, -- ciclos feitos na mão (cliques na banca contam)
	{ Id = "tips", Base = 12 }, -- gorjetas pegas no chão
	{ Id = "mutant", Base = 3 }, -- ovos raros pegos
	{ Id = "sell", Base = 2 }, -- ovos raros vendidos
	{ Id = "buy", Base = 8 },
	{ Id = "hatch", Base = 1 },
	{ Id = "earn", Base = 0 }, -- alvo = 10 minutos de renda
	{ Id = "bags", Base = 3 }, -- sacos de dinheiro pegos (cai um a cada 2 a 4 minutos)
}
Config.MissionSeconds = 60
Config.MissionMin = 100
Config.GiftInterval = 600
Config.GiftSeconds = 25
Config.GiftMin = 50
Config.StreakSeconds = { 25, 50, 75, 100, 120, 180, 360 } -- prêmio do dia 1 ao 7 (depois repete o 7)
Config.StreakStars = { 0, 0, 1, 0, 2, 0, 5 } -- Estrelas extras por dia

-- Códigos (o jogador digita em Presentes). Seconds = segundos de renda; Stars = estrelas; Min = mínimo de moedas.
Config.Codes = {
	OVO = { Seconds = 60, Min = 250 },
	GRANJA = { Seconds = 120, Min = 500, Stars = 2 },
	GIGANTE = { Seconds = 60, Min = 300, Spins = 2 },
}

-- ---------------------------------------------------------------------------
-- LOJA EM ROBUX: GAME PASSES (compra uma vez, vale para sempre) e PRODUTOS (pode comprar várias vezes).
-- Crie cada um no Creator Hub e cole o número no campo Id (0 = desligado: o item nem aparece na loja).
-- Passo a passo para o dono do jogo: design/LOJA_ROBUX.md
-- Robux = preço SUGERIDO, só para mostrar na tela. O preço de verdade é o do Creator Hub: se mudar lá,
-- mude aqui também para a loja mostrar o número certo.
-- Regra da loja: só vende o que o jogador QUER (conveniência, velocidade, estilo), com preço e efeito
-- claros. Nada de sorteio pago (regra do Roblox), contagem regressiva falsa ou janela que abre sozinha.
-- Icon = imagem do Config.Images (se tiver ID); Emoji = desenho usado enquanto não tem imagem.
-- ---------------------------------------------------------------------------
Config.GamePasses = {
	{ Key = "Dinheiro2x", Id = 2006469848, Icon = "Moeda", Emoji = "💰", Robux = 199 }, -- tudo vale o dobro
	{ Key = "VIP", Id = 2006595923, Icon = "VIP", Emoji = "👑", Robux = 299 }, -- coroa que todos veem + dinheiro + giro do dia (ver Config.VIP)
	{ Key = "SuperClique", Id = 2006553865, Icon = "SuperClique", Emoji = "👆", Robux = 149 }, -- a banca vende sozinha com ele por perto (ver Config.SuperClick)
	{ Key = "Ima", Id = 2010308250, Icon = "Ima", Emoji = "🧲", Robux = 149 }, -- "Coletor Automático": recolhe moedas, gorjetas e ovos raros do terreno
	{ Key = "Sorte2x", Id = 2005935794, Icon = "Trevo", Emoji = "🍀", Robux = 149 }, -- ovos raros aparecem 2x mais rápido
	{ Key = "MaisPets", Id = 2006733840, Icon = "Pet", Emoji = "🐣", Robux = 149 }, -- +PassPetSlots pets equipados
	{ Key = "CompraRemota", Id = 2010308251, Icon = "Celular", Emoji = "📱", Robux = 99 }, -- botão "comprar o próximo" na tela
	{ Key = "Offline2x", Id = 2010314250, Icon = "Lua", Emoji = "🌙", Robux = 99 }, -- renda dobrada com o jogador fora
}
Config.PassPetSlots = 2
-- Passe VIP. CashBonus multiplica com todo o resto (com o Dinheiro2x: 2 x 1,5 = 3x).
-- DailySpins = giros extras da roleta por dia. Onde o Roblox restringe prêmio sorteado ligado a compra
-- (PolicyService), ou se DailySpins for 0, o VIP ganha no lugar um presente fixo de DailySeconds de renda.
Config.VIP = { CashBonus = 0.5, DailySpins = 0, -- 0 = presente fixo por dia (nada pago dá prêmio sorteado: é o que foi declarado ao Roblox)
	 DailySeconds = 60, DailyMin = 300, Color = Color3.fromRGB(255, 205, 50) }
-- Passe SuperClique: perto da banca o SERVIDOR vende sozinho PerSecond vezes por segundo (entra no mesmo
-- limite de cliques de todo mundo) e o trabalho feito na mão vale HandBonus a mais (2x vira 3x).
Config.SuperClick = { PerSecond = 4, HandBonus = 1 }
-- Passe Ima (Coletor Automático): de quantos em quantos segundos o servidor recolhe o terreno inteiro
Config.AutoCollectEvery = 1
-- PRODUTOS. Kind "skip": dá na hora Seconds segundos de renda (no mínimo Min moedas).
-- Kind "boost": liga o efeito Boost por Seconds (soma o tempo se comprar de novo).
-- Kind "pack": Seconds/Min de moedas + um ovo raro Egg da melhor ave + o efeito Boost por BoostSeconds.
-- Once = true: cada jogador só compra UMA vez (fica guardado no save e o item some da loja). Se o Roblox
-- cobrar de novo mesmo assim, o jogador recebe AgainSeconds de renda em moedas (nunca perde a compra).
Config.Products = {
	{ Key = "PacoteInicial", Id = 3716943894, Kind = "pack", Once = true, Seconds = 1800, Min = 5000, Egg = "g", Boost = "Turbo", BoostSeconds = 900, AgainSeconds = 3600, Icon = "Pacote", Emoji = "🎁", Robux = 49 },
	{ Key = "Pular30", Id = 3716943964, Kind = "skip", Seconds = 1800, Min = 500, Icon = "Relogio", Emoji = "💰", Robux = 29 },
	{ Key = "Pular4h", Id = 3716944016, Kind = "skip", Seconds = 14400, Min = 4000, Icon = "Relogio", Emoji = "💰", Robux = 79 },
	{ Key = "Pular24h", Id = 3716944034, Kind = "skip", Seconds = 86400, Min = 25000, Icon = "Relogio", Emoji = "💰", Robux = 199 },
	{ Key = "Turbo", Id = 3716944104, Kind = "boost", Boost = "Turbo", Seconds = 900, Icon = "Raio", Emoji = "⚡", Robux = 19 },
	{ Key = "Sorte", Id = 3716944132, Kind = "boost", Boost = "Sorte", Seconds = 900, Icon = "Trevo", Emoji = "🍀", Robux = 19 },
	-- Kind "refill": deixa todos os poderes (Config.Powers) prontos na hora. Id = 0: ainda não criado no Roblox (fica fora da loja).
	{ Key = "Recarga", Id = 0, Kind = "refill", Icon = "Raio", Emoji = "⚡", Robux = 19 },
	-- v6. Kind "hatch": a chocadeira com mais tempo faltando termina na hora. Sem ovo chocando, vira
	-- Seconds de renda em moedas. Id = 0: crie o produto no Roblox e cole o número aqui.
	{ Key = "ChocarJa", Id = 0, Kind = "hatch", Seconds = 600, Min = 300, Icon = "Relogio", Emoji = "🐣", Robux = 15 },
}

-- v6: PRESENTES POR TEMPO JOGADO nesta visita (zera ao sair): as 8 caixas da aba Presentes.
-- Minutes desde que entrou; Seconds/Min de renda; Spins = giros da roleta; Turbo = segundos de Turbo grátis.
-- Regras no servidor: ServerScriptService/Game/Bonus.
Config.PlayRewards = {
	{ Minutes = 5, Seconds = 60, Min = 100 },
	{ Minutes = 10, Seconds = 120, Min = 250 },
	{ Minutes = 15, Seconds = 180, Min = 400 },
	{ Minutes = 20, Seconds = 240, Min = 600, Spins = 1 },
	{ Minutes = 30, Seconds = 360, Min = 1000 },
	{ Minutes = 40, Seconds = 480, Min = 1500 },
	{ Minutes = 50, Seconds = 600, Min = 2200, Spins = 1 },
	{ Minutes = 60, Seconds = 900, Min = 3000, Turbo = 600, Spins = 2 },
}

-- v6: TÍTULO em cima da cabeça (todo mundo vê), pelo número de renascimentos. Com Selo, o título fica na
-- cor do Selo. Rebirths = a partir de quantos renascimentos. Antes do 1º renascimento: sem título.
Config.Titles = {
	{ Rebirths = 1, Text = "Granjeiro" },
	{ Rebirths = 3, Text = "Fazendeiro" },
	{ Rebirths = 6, Text = "Coronel do Ovo" },
	{ Rebirths = 10, Text = "Barão do Ovo" },
	{ Rebirths = 20, Text = "Magnata da Gema" },
	{ Rebirths = 35, Text = "Lenda da Granja" },
	{ Rebirths = 60, Text = "Imperador do Ovo" },
}

-- v6: BAÚ DO GRUPO. Quem está no grupo (Config.GroupId) abre de graça a cada Every segundos: Seconds de renda
-- (no mínimo Min). Quem não está vê o convite para entrar no grupo.
Config.GroupChest = { Every = 20 * 3600, Seconds = 600, Min = 500 }

-- v6: CONQUISTAS. Metas da vida inteira (não zeram ao renascer). Stat = contador em data.Stats (ou
-- "Rebirths" / "Likes", que ficam direto no save). Goals = degraus; Stars = estrelas de cada degrau.
-- Estrela de conquista vale igual às outras (+2% de renda cada e serve para os talentos).
Config.Achievements = {
	{ Id = "vendedor", Stat = "Worked", Goals = { 100, 1000, 10000, 100000 }, Stars = { 3, 8, 20, 50 } },
	{ Id = "comprador", Stat = "Buttons", Goals = { 25, 100, 300, 1000 }, Stars = { 3, 8, 20, 50 } },
	{ Id = "raros", Stat = "Sold", Goals = { 10, 100, 1000, 10000 }, Stars = { 3, 8, 20, 50 } },
	{ Id = "mutantes", Stat = "Mutants", Goals = { 5, 50, 500 }, Stars = { 5, 15, 40 } },
	{ Id = "chocadeira", Stat = "Hatched", Goals = { 1, 10, 50, 200 }, Stars = { 2, 6, 15, 40 } },
	{ Id = "renascido", Stat = "Rebirths", Goals = { 1, 5, 15, 40 }, Stars = { 5, 15, 40, 100 } },
	{ Id = "baus", Stat = "Chests", Goals = { 1, 10, 50 }, Stars = { 3, 10, 30 } },
	{ Id = "obby", Stat = "Obby", Goals = { 1, 10, 50 }, Stars = { 3, 10, 30 } },
	{ Id = "roleta", Stat = "Spun", Goals = { 5, 50, 250 }, Stars = { 3, 10, 30 } },
	{ Id = "querido", Stat = "Likes", Goals = { 5, 50, 250 }, Stars = { 3, 10, 30 } },
}

-- v6: PEDIDO DE FAVORITO. Depois de tantos segundos jogando nesta visita, a janela do Roblox pergunta
-- (uma vez só por jogador: fica no save) se ele quer favoritar o jogo. 0 = desligado.
Config.FavoriteAfter = 900
-- v6: LEMBRETE DE CURTIR. Depois de tantos segundos nesta visita aparece UMA vez na vida um cartão pequeno
-- no meio da tela pedindo o 👍 na página do jogo. O Roblox não deixa abrir o botão de curtir pelo jogo nem
-- dar prêmio em troca de curtida: é só o lembrete (some sozinho em 10 s). 0 = desligado.
Config.LikeReminderAfter = 1500

-- v6: EMBLEMAS (badges). Crie em create.roblox.com > seu jogo > Emblemas e cole o número. 0 = desligado.
Config.Badges = {
	Bemvindo = 0, -- entrou no jogo
	Granja = 0, -- abriu o 2º negócio
	Fabrica = 0, -- abriu a Fábrica
	Foguete = 0, -- abriu o Foguete (último negócio)
	Gerente = 0, -- contratou o 1º gerente
	Renasceu = 0, -- 1º renascimento
	Selo = 0, -- ganhou um Selo
}
Config.TurboBoostMult = 2 -- velocidade de todos os negócios
Config.LuckBoostMult = 3 -- ovos raros aparecem tantas vezes mais rápido

-- ---------------------------------------------------------------------------
-- Segurança e ritmo do servidor
-- ---------------------------------------------------------------------------
Config.RequestCooldown = 0.25
Config.TickSeconds = 0.5 -- produção
Config.PollSeconds = 0.2 -- botões, moedas, trabalho, venda (pela posição do jogador)
Config.ButtonRadius = 3.6
Config.ButtonHold = 0.25 -- precisa ficar em cima do botão por este tempo
Config.BuyCooldown = 0.35
Config.SellRadius = 6.5

-- ===========================================================================
-- Tabelas derivadas (não mexer): lista completa de botões e índices
-- ===========================================================================
function Config.Rebuild()
	Config.LineById = {}
	for index, line in Config.Lines do
		line.Index = index
		Config.LineById[line.Id] = line
	end

	Config.MutationById = {}
	for index, mutation in Config.Mutations do
		mutation.Index = index
		Config.MutationById[mutation.Id] = mutation
	end

	Config.TalentById = {}
	for _, talent in Config.Talents do
		Config.TalentById[talent.Id] = talent
	end

	Config.BizById = {}
	for index, biz in Config.Businesses do
		biz.Index = index
		Config.BizById[biz.Id] = biz
	end

	-- Lista completa de botões. Campos: Id, Kind, Cost, Requires e conforme o tipo:
	--   "unlock"  Biz (índice do negócio)          abre o negócio
	--   "manager" Biz                              contrata o gerente
	--   "cash"    Biz, Name, Cash, Step            melhoria de dinheiro (Step = posição na fila)
	--   "speed"   Biz, Name, Speed, Step           melhoria de velocidade
	--   "bird"    Line (índice da ave), Cash       ave nova: multiplica tudo
	--   outros    botões gerais (Spot, Basket, Hatch, Tree, Tractor, Cash, SpeedAll)
	Config.Buttons = {}
	Config.ButtonById = {}
	local function add(button: any)
		button.Cost = Config.ButtonCost[button.Id] or 0
		table.insert(Config.Buttons, button)
		Config.ButtonById[button.Id] = button
	end
	for index, biz in Config.Businesses do
		local unlockId = biz.Id .. "_unlock"
		add({ Id = unlockId, Kind = "unlock", Biz = index, Requires = if index > 1 then Config.Businesses[index - 1].Id .. "_unlock" else nil })
		add({ Id = biz.Id .. "_gerente", Kind = "manager", Biz = index, Requires = unlockId })
		for _, chain in { "cash", "speed" } do
			local previous = unlockId
			for step, def in Config.Upgrades[biz.Id][chain] do
				local button: any = { Id = biz.Id .. "_" .. def[1], Kind = chain, Biz = index, Name = def[1], Step = step, Requires = previous }
				button[if chain == "cash" then "Cash" else "Speed"] = def[2]
				for key, value in def do
					if type(key) == "string" then
						button[key] = value
					end
				end
				add(button)
				previous = button.Id
			end
		end
	end
	local previousBird = "granja_unlock"
	for index, line in Config.Lines do
		if index > 1 then
			add({ Id = "ave_" .. line.Id, Kind = "bird", Line = index, Cash = line.Cash, Requires = previousBird })
			previousBird = "ave_" .. line.Id
		end
	end
	for _, def in Config.GlobalButtons do
		local button = table.clone(def)
		button.Id = "G_" .. def.Kind
		add(button)
	end

	Config.EventById = {}
	for _, event in Config.Events do
		Config.EventById[event.Id] = event
	end

	Config.WeatherById = {}
	for _, weather in Config.Weather.List do
		Config.WeatherById[weather.Id] = weather
	end
	Config.PowerById = {}
	for _, power in Config.Powers do
		Config.PowerById[power.Id] = power
	end
end

Config.Rebuild()

return Config
