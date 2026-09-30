--[[
	Hybrids (ModuleScript em ReplicatedStorage > Shared)
	Parte 21: receitas do LABORATÓRIO DE MISTURA.
	Junte 2 espécies diferentes da mochila e, se a dupla for uma receita, nasce um híbrido
	com nome misturado (ex.: Zapkit, um gato, + Sugardrake, um dragão = "Dragato").
	A ordem não importa (A + B = B + A). Os dois pais são usados na mistura.
	Hint = dica que aparece no álbum enquanto a receita não foi descoberta.
	Para criar uma receita nova: crie o híbrido em Critters (World = "hybrid") e adicione uma linha aqui.
]]

local Hybrids = {}

Hybrids.Recipes = {
	{ A = "squeak", B = "mossy", Result = "mosqueak", Hint = "A squeaky cat + a mossy toad" },
	{ A = "nibbles", B = "chirpy", Result = "chirbun", Hint = "A bunny + a little bird" },
	{ A = "fluffo", B = "leafy", Result = "fluffysaur", Hint = "A fluffy bunny + a tiny dino" },
	{ A = "frostbun", B = "embertail", Result = "steambun", Hint = "Ice + fire = steam!" },
	{ A = "shellbo", B = "toadle", Result = "shelltoad", Hint = "A shell + a toad" },
	{ A = "zapkit", B = "sugardrake", Result = "dragato", Hint = "A cat + a dragon" },
	{ A = "nebulowl", B = "prismfox", Result = "prismowl", Hint = "An owl + a shiny fox" },
	{ A = "voltpup", B = "stormhorn", Result = "thunderpup", Hint = "Electric pup + storm beast" },
	{ A = "glaciamoth", B = "magmaroo", Result = "glaciaroo", Hint = "Frozen moth + lava beast" },
	{ A = "voidra", B = "prismacorn", Result = "voidicorn", Hint = "The void + a unicorn" },
}

Hybrids.ByResult = {}
for _, recipe in Hybrids.Recipes do
	Hybrids.ByResult[recipe.Result] = recipe
end

-- Qual híbrido sai de a + b (nil = essa dupla não mistura)
function Hybrids.Find(a: string, b: string)
	if a == b then
		return nil
	end
	for _, recipe in Hybrids.Recipes do
		if (recipe.A == a and recipe.B == b) or (recipe.A == b and recipe.B == a) then
			return recipe
		end
	end
	return nil
end

return Hybrids
