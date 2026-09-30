--[[
	Encyclopedia (ModuleScript em ReplicatedStorage > Shared)
	Parte 26: cada bichinho do jogo foi inspirado num animal DE VERDADE.
	Toque num bichinho já descoberto no INDEX para ler a curiosidade.
	Animal = o bicho real; Fact = uma curiosidade verdadeira, em inglês simples (o jogo é em inglês).
]]

local Encyclopedia = {}

Encyclopedia.ById = {
	-- MEADOW
	blobby = { Animal = "Slime mold", Fact = "Slime molds have no brain, but they can still find the shortest path through a maze to reach food!" },
	pebbo = { Animal = "Pebble toad", Fact = "The pebble toad from Venezuela curls into a ball and bounces down the rocks to escape danger." },
	squeak = { Animal = "Mouse", Fact = "A mouse's front teeth never stop growing, so it chews all the time to keep them short." },
	mossy = { Animal = "Mossy frog", Fact = "Vietnamese mossy frogs look just like moss, so predators walk right past them." },
	nibbles = { Animal = "Rabbit", Fact = "A rabbit can see almost all the way around its body without turning its head." },
	fluffo = { Animal = "Angora rabbit", Fact = "Angora rabbits have fur so soft and long that people spin it into yarn." },
	chirpy = { Animal = "Hummingbird", Fact = "A hummingbird's heart can beat more than 1,000 times a minute!" },
	toadle = { Animal = "Toad", Fact = "Touching a toad does NOT give you warts. That's just an old myth!" },
	leafy = { Animal = "Brachiosaurus", Fact = "Plant-eating dinosaurs like Brachiosaurus were about as tall as a 4-story building." },
	zapkit = { Animal = "Electric eel", Fact = "Electric eels can make shocks of more than 600 volts to stun their food." },
	frostbun = { Animal = "Arctic hare", Fact = "Many Arctic hares turn white in winter so they can hide in the snow." },
	embertail = { Animal = "Red panda", Fact = "Red pandas wrap their fluffy tails around themselves like a blanket to stay warm." },
	shellbo = { Animal = "Ankylosaurus", Fact = "Ankylosaurus was covered in bony armor and had a heavy club on its tail." },
	nebulowl = { Animal = "Owl", Fact = "Owls can turn their heads about 270 degrees, almost all the way around!" },
	prismfox = { Animal = "Fennec fox", Fact = "Fennec foxes use their giant ears to let heat out and stay cool in the desert." },
	voltpup = { Animal = "Dog", Fact = "Every dog's nose print is different, just like a human fingerprint." },
	sugardrake = { Animal = "Komodo dragon", Fact = "The Komodo dragon is the biggest lizard in the world and can grow to 3 meters long." },
	sunwing = { Animal = "Flamingo", Fact = "Flamingos are pink because of the shrimp and algae they eat." },
	glaciamoth = { Animal = "Woolly mammoth", Fact = "The last woolly mammoths lived about 4,000 years ago, after the first pyramids in Egypt were built!" },
	magmaroo = { Animal = "Kangaroo", Fact = "Kangaroos use their strong tail like a fifth leg when they move slowly." },
	stormhorn = { Animal = "Bighorn sheep", Fact = "Bighorn rams run at each other and crash their horns together to show who is strongest." },
	voidra = { Animal = "Anglerfish", Fact = "Anglerfish live in the dark deep sea and use a glowing lure on their head to catch food." },
	prismacorn = { Animal = "Narwhal", Fact = "Narwhals are called the unicorns of the sea. Their long horn is actually a tooth!" },
	krakenox = { Animal = "Giant squid", Fact = "Giant squid have some of the biggest eyes of any animal, about as big as a dinner plate." },
	cosmoking = { Animal = "Tardigrade", Fact = "Tardigrades are tiny animals that survived a trip into outer space!" },
	goldengoober = { Animal = "Golden tortoise beetle", Fact = "The golden tortoise beetle can change its shiny gold color to red when it is bothered." },
	aurorawing = { Animal = "Arctic tern", Fact = "Arctic terns fly from the Arctic to the Antarctic and back every year, the longest trip of any animal." },
	emberdrake = { Animal = "Fire salamander", Fact = "People once believed fire salamanders were born in fire, because they crawled out of logs thrown on the fire." },
	tidalox = { Animal = "Octopus", Fact = "An octopus has three hearts and blue blood." },
	solarking = { Animal = "Sun bear", Fact = "Sun bears have a super long tongue, up to 25 cm, for licking honey out of beehives." },
	-- CANDY KINGDOM
	gummybun = { Animal = "Gummy squirrel", Fact = "A deep-sea sea cucumber is nicknamed the 'gummy squirrel' because it looks like a gummy candy with a tail!" },
	lollicat = { Animal = "Cat", Fact = "Cats sleep about 12 to 16 hours every day." },
	cupcaketoad = { Animal = "Strawberry poison frog", Fact = "Some strawberry poison frogs are bright red with blue legs. Their colors warn predators: don't eat me!" },
	cottonphoenix = { Animal = "Roseate spoonbill", Fact = "Roseate spoonbills are pink and swing their spoon-shaped beaks side to side to catch food." },
	chocodrake = { Animal = "Chocolate chip sea star", Fact = "The chocolate chip sea star has dark bumps on its back that look like chocolate chips." },
	sugarqueen = { Animal = "Honeybee queen", Fact = "A queen honeybee can lay up to 2,000 eggs in a single day." },
	-- FROST PEAKS
	snowpup = { Animal = "Snow leopard", Fact = "Snow leopards wrap their long, fluffy tails around their faces like a scarf." },
	penguino = { Animal = "Emperor penguin", Fact = "Emperor penguin dads keep the egg warm on their feet for about two months." },
	frostfox = { Animal = "Arctic fox", Fact = "Arctic foxes have fur on the bottom of their paws so they can walk on ice." },
	yetimammoth = { Animal = "Musk ox", Fact = "Musk oxen grow a super warm wool called qiviut, much warmer than sheep wool." },
	blizzardwyrm = { Animal = "Ice worm", Fact = "Ice worms are real! They live inside glaciers and can't survive if it gets even a little warm." },
	auroraking = { Animal = "Polar bear", Fact = "Polar bears have black skin under their white-looking fur." },
	-- LAVA LAND
	emberpup = { Animal = "Dalmatian", Fact = "Long ago, Dalmatians ran next to fire wagons to clear the way for firefighters." },
	magmatoad = { Animal = "Fire-bellied toad", Fact = "Fire-bellied toads show their bright orange belly to warn predators that they taste bad." },
	cinderbird = { Animal = "Northern cardinal", Fact = "Only male cardinals are bright red. Females are brown with red touches." },
	volcanoram = { Animal = "Mountain goat", Fact = "Mountain goats can climb cliffs so steep they look like walls." },
	infernobeast = { Animal = "Pompeii worm", Fact = "The Pompeii worm lives next to super hot vents on the ocean floor." },
	lavalord = { Animal = "Lava lizard", Fact = "Lava lizards of the Galapagos Islands do push-ups to show off to other lizards." },
	-- CORAL REEF
	bubblefin = { Animal = "Pufferfish", Fact = "Pufferfish gulp lots of water to puff up into a spiky ball." },
	shellturtle = { Animal = "Sea turtle", Fact = "Many sea turtles return to the same beach where they hatched to lay their own eggs." },
	jellyglow = { Animal = "Jellyfish", Fact = "Jellyfish have no brain, no heart and no bones." },
	tideunicorn = { Animal = "Seahorse", Fact = "Seahorse dads carry the babies in a pouch until they are born." },
	deepkraken = { Animal = "Dumbo octopus", Fact = "Dumbo octopuses live very deep in the ocean and flap ear-like fins to swim." },
	pearlempress = { Animal = "Pearl oyster", Fact = "A pearl forms when an oyster covers something that got inside it, usually a tiny parasite, with shiny layers." },
	-- GALAXY STATION
	moonbun = { Animal = "Rabbit", Fact = "Rabbits can jump really high: the record is almost 1 meter!" },
	astrocat = { Animal = "Felicette the space cat", Fact = "In 1963 a French cat named Felicette flew to space and came back safely." },
	cometbird = { Animal = "Peregrine falcon", Fact = "The peregrine falcon is the fastest animal: it can dive at more than 300 km/h!" },
	starunicorn = { Animal = "Sea star", Fact = "Sea stars can grow back an arm if they lose one." },
	nebuladragon = { Animal = "Flying dragon lizard", Fact = "Draco lizards glide from tree to tree using wing-like flaps of skin." },
	galaxyemperor = { Animal = "Dung beetle", Fact = "Some dung beetles use the Milky Way in the night sky to find their way!" },
	-- CLIMA E NOITE
	puddlepup = { Animal = "Sea otter", Fact = "Sea otters sometimes hold hands while they sleep so they don't float away from each other." },
	thundertoad = { Animal = "Frog", Fact = "Frogs don't drink with their mouths. They soak up water through their skin!" },
	stormdrake = { Animal = "Frigatebird", Fact = "Frigatebirds can stay in the air for weeks and even sleep while flying." },
	flurryfox = { Animal = "Red fox", Fact = "Red foxes jump headfirst into the snow to catch mice they hear underneath." },
	snowglobebun = { Animal = "Pika", Fact = "Pikas collect little piles of grass in summer to eat during the winter." },
	blizzardowl = { Animal = "Snowy owl", Fact = "Unlike most owls, snowy owls often hunt during the day." },
	moonmoth = { Animal = "Luna moth", Fact = "Adult luna moths can't eat at all and live only about one week." },
	shadowcat = { Animal = "Black panther", Fact = "A black panther is a leopard or jaguar with dark fur. In bright light you can still see its spots!" },
	starlightunicorn = { Animal = "Firefly", Fact = "Fireflies make light inside their bodies and blink to talk to each other." },
	-- HÍBRIDOS
	mosqueak = { Animal = "Capybara", Fact = "The capybara is the biggest rodent in the world and a great swimmer." },
	chirbun = { Animal = "Puffin", Fact = "Puffins can carry about 10 small fish in their beak at the same time." },
	fluffysaur = { Animal = "Feathered dinosaur", Fact = "Many dinosaurs had feathers. Birds are actually living dinosaurs!" },
	steambun = { Animal = "Jackrabbit", Fact = "Jackrabbits' giant ears let out heat and help them stay cool." },
	shelltoad = { Animal = "Box turtle", Fact = "Box turtles can close their shell completely, like a box with a lid." },
	dragato = { Animal = "Chameleon", Fact = "Chameleons can move each eye in a different direction at the same time." },
	prismowl = { Animal = "Burrowing owl", Fact = "Burrowing owls live in holes in the ground instead of trees." },
	thunderpup = { Animal = "Platypus", Fact = "Platypuses can feel the tiny electric signals made by the animals they hunt." },
	glaciaroo = { Animal = "Tree kangaroo", Fact = "Tree kangaroos live in rainforests and climb trees." },
	voidicorn = { Animal = "Okapi", Fact = "The okapi has zebra stripes on its legs, but its closest relative is the giraffe!" },
	-- FESTAS
	pumpkat = { Animal = "Black cat", Fact = "In some places, like Japan and parts of the UK, black cats are thought to bring good luck!" },
	batwing = { Animal = "Bat", Fact = "Bats are the only mammals that can really fly." },
	jingledeer = { Animal = "Reindeer", Fact = "Reindeer are the only deer where both the males and the females grow antlers." },
	frostpuff = { Animal = "Rock ptarmigan", Fact = "Rock ptarmigans turn white in winter and even grow feathers on their feet like snow boots." },
	lovebird = { Animal = "Lovebird", Fact = "Lovebirds are small parrots that love to sit close to their partner." },
	heartcorn = { Animal = "Pink fairy armadillo", Fact = "The pink fairy armadillo is the smallest armadillo, small enough to fit in your hand." },
	sunnyshell = { Animal = "Hermit crab", Fact = "Hermit crabs move into bigger shells as they grow." },
	tropicaw = { Animal = "Macaw", Fact = "Big parrots like macaws can live for more than 50 years." },
	-- EXPLORAÇÃO
	coconutcrab = { Animal = "Coconut crab", Fact = "The coconut crab is the biggest crab that lives on land, and it can climb trees!" },
	islandtortoise = { Animal = "Galapagos tortoise", Fact = "Galapagos tortoises can live for more than 100 years." },
	tinyrex = { Animal = "Tyrannosaurus rex", Fact = "T. rex had teeth about as long as a banana!" },
	amberraptor = { Animal = "Velociraptor", Fact = "Real velociraptors were about the size of a turkey and had feathers." },
	glowsquid = { Animal = "Firefly squid", Fact = "Firefly squid glow bright blue and light up the sea near Japan every spring." },
	isopodking = { Animal = "Giant isopod", Fact = "Giant isopods live deep in the ocean and can go a very long time without eating." },
	-- PRESENTES
	crowny = { Animal = "Grey crowned crane", Fact = "The grey crowned crane has a crown of golden feathers on its head." },
	globey = { Animal = "Three-banded armadillo", Fact = "The three-banded armadillo can roll itself into an almost perfect ball." },
	unidrake = { Animal = "Axolotl", Fact = "Axolotls can grow back lost legs, their tail and even parts of their heart." },
	-- CRITTER DA SEMANA (v27: faltavam estes 8)
	sugarpaw = { Animal = "Rabbit", Fact = "A happy rabbit jumps and twists in the air. This little dance is called a binky!" },
	voltbeak = { Animal = "Hummingbird", Fact = "Hummingbirds can flap their wings up to 80 times every second and even fly backwards." },
	mochidino = { Animal = "Triceratops", Fact = "Triceratops had three horns and a big bony frill, and ate only plants." },
	nightcat = { Animal = "Cat", Fact = "Cats can see well in very dim light, which helps them explore at night." },
	bubbletoad = { Animal = "Toad", Fact = "Toads can drink water through their skin, so they never need to open their mouths to drink." },
	emberuni = { Animal = "Horse", Fact = "Horses can sleep standing up thanks to special locks in their legs." },
	cloudpuff = { Animal = "Sheep", Fact = "A sheep's wool keeps growing all year, so farmers trim it like a haircut." },
	galaxydrake = { Animal = "Komodo dragon", Fact = "The Komodo dragon is the biggest lizard in the world and can be as long as a car." },
}

return Encyclopedia
