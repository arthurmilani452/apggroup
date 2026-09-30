--[[
	NPCs (ModuleScript em ReplicatedStorage > Shared)
	v14: personagens do mapa. Chegue perto e aperte "Talk" para ouvir dicas.
	  • Sneaky: o mascote (guaxinim gordinho com máscara de ladrão, sempre abraçado a um ovo dourado)
	  • os outros ficam nas barracas e nos lugares novos e explicam o que fazer ali
	Para mudar o que falam, edite as Lines (inglês simples: o jogo é traduzido pelo UI.csv só nos textos fixos).
	Position = onde fica (no chão); Look = para onde olha.
	v14: se existir um modelo 3D em ReplicatedStorage > Models3D > <Id>, ele é usado (senão, monta com peças).
	Height = altura em studs (padrão: 5.6 para pessoas, 6.5 para o Sneaky).
]]

local NPCs = {}

NPCs.List = {
	{
		Id = "sneaky",
		Title = "Mascot",
		Name = "Sneaky",
		Kind = "raccoon",
		Height = 6.5,
		Position = Vector3.new(12, 0, 18), -- ao lado do ponto de nascimento
		Look = Vector3.new(0, 0, 14),
		Lines = {
			"Shhh... Sneaky time! Welcome to Steal a Critter!",
			"Buy eggs on the conveyor, then watch them hatch in your base.",
			"Your critters make cash. Tap COLLECT in your base to grab it!",
			"Thieves coming? Step on LOCK BASE, or BONK them with your bat!",
			"Big players can't steal from much smaller ones. It's only fair!",
			"Psst... codes hide in my videos. Try the code SNEAKY!",
			"Hug your eggs. Eggs are life.",
		},
	},
	{
		Id = "penny",
		Title = "Shop",
		Skin = Color3.fromRGB(255, 214, 170),
		Name = "Penny",
		Kind = "person",
		Shirt = Color3.fromRGB(70, 190, 100),
		Hair = Color3.fromRGB(120, 70, 40),
		Position = Vector3.new(-195.5, 0, -46), -- atrás do balcão da SHOP
		Look = Vector3.new(-150, 0, -46),
		Lines = {
			"Hi! I run the SHOP. Buy more slots and speed with game cash!",
			"Everything in the shop shows its price before you buy.",
			"Want to go faster for free? Run on the treadmill in your base!",
		},
	},
	{
		Id = "professor",
		Title = "Mix Lab",
		Skin = Color3.fromRGB(250, 215, 180),
		Name = "Professor Mix",
		Kind = "person",
		Shirt = Color3.fromRGB(240, 240, 250),
		Hair = Color3.fromRGB(230, 230, 230),
		Position = Vector3.new(-49.5, 0, 150), -- atrás do balcão do MIX LAB
		Look = Vector3.new(0, 0, 150),
		Lines = {
			"Welcome to my MIX LAB! Pick two critters from your backpack and press MIX.",
			"If a pair doesn't mix, nothing is lost. Try another one!",
			"Open RECIPES to read the hints for every hybrid.",
		},
	},
	{
		Id = "coach",
		Title = "Minigames",
		Skin = Color3.fromRGB(141, 85, 36),
		Name = "Coach Zip",
		Kind = "person",
		Shirt = Color3.fromRGB(255, 140, 40),
		Hair = Color3.fromRGB(40, 30, 30),
		Position = Vector3.new(12, 0, 104),
		Look = Vector3.new(0, 0, 80),
		Lines = {
			"Every few minutes a MINIGAME starts. Tap JOIN at the top of the screen!",
			"In minigames everyone runs at the same speed. Only skill wins!",
			"Behind me is the GIANT EGG. Tap it with everyone to hatch it!",
			"On weekends, minigame wins give tournament points!",
		},
	},
	{
		Id = "finn",
		Title = "Fishing & Digging",
		Skin = Color3.fromRGB(234, 192, 134),
		Name = "Old Finn",
		Kind = "person",
		Shirt = Color3.fromRGB(60, 110, 200),
		Hair = Color3.fromRGB(200, 200, 200),
		Position = Vector3.new(221, 0, -118),
		Look = Vector3.new(230, 0, -140),
		Lines = {
			"Fishing is easy: tap when the hook is in the GREEN part!",
			"Three good taps and you might catch a treasure chest.",
			"Look for sand patches around the valley too. Dig them for fossils!",
		},
	},
	{
		Id = "luna",
		Title = "Worlds Guide",
		Skin = Color3.fromRGB(198, 134, 66),
		Name = "Luna",
		Kind = "person",
		Shirt = Color3.fromRGB(170, 110, 255),
		Hair = Color3.fromRGB(255, 220, 120),
		Position = Vector3.new(214, 0, 26),
		Look = Vector3.new(250, 0, 0),
		Lines = {
			"These portals lead to new WORLDS with better eggs.",
			"Some worlds need Rebirths. Rebirth keeps your critters!",
			"At minute 30 of every hour, a SECRET ISLAND opens next to the Giant Egg!",
			"Every day, 10 Hunt Eggs are hidden around Meadow. Can you find them all?",
		},
	},
	{
		Id = "captain",
		Title = "Submarine",
		Skin = Color3.fromRGB(255, 219, 172),
		Name = "Captain Coral",
		Kind = "person",
		Shirt = Color3.fromRGB(240, 240, 240),
		Hair = Color3.fromRGB(80, 60, 40),
		World = "reef",
		Position = Vector3.new(4130, 0, 64),
		Look = Vector3.new(4140, 0, 70),
		Lines = {
			"Ahoy! My SUBMARINE takes you to the bottom of the sea.",
			"Down there you'll find treasure chests and the Deep Sea Egg!",
		},
	},
}

NPCs.ById = {}
for _, npc in NPCs.List do
	NPCs.ById[npc.Id] = npc
end

return NPCs
