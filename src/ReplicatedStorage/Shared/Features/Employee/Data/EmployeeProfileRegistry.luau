--!strict
--[=[
	EmployeeProfileRegistry: what the screens say about each employee (the pick screen, the Crew cards, the About
	tab): a kind line, three personality words, a short bio, a fun fact, the ability's card text and the five display
	stats, plus the employee's UI colour (their card, page and pick screen are tinted in it).

	The stats change play through EmployeeStatFormulas (1 bar plays like today; each bar above adds a small step). The ability's words live here, but the ability itself
	(and its cooldown, read from there) is AbilityRegistry's: the card can never promise a number the game does not
	keep. The words come from characters/launch/new-employee-requirements.md and the owner can edit them here. Copy is
	kid reading level. Every employee's stats add up to the same total (requirements: equal point totals).

	@class EmployeeProfileRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityRegistry = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityRegistry)

export type Stat = "speed" | "stamina" | "strength" | "suction" | "quiet"

export type Profile = {
	kind: string,
	line: string,
	words: { string },
	bio: string,
	funFact: string,
	-- `icon` names the ability's render in the UI kit (UIAssets.toonIcons).
	ability: { name: string, line: string, detail: string, cooldown: number, icon: string },
	stats: { [Stat]: number },
	-- body: the card/page fill; light: its highlight; dark: its band and shadows.
	color: { body: Color3, light: Color3, dark: Color3 },
}

local STATS: { Stat } = { "speed", "stamina", "strength", "suction", "quiet" }

-- The employee's ability cooldown (AbilityRegistry), 0 when they have none.
local function cooldownOf(employee: string): number
	local def = AbilityRegistry.forEmployee(employee)
	return if def ~= nil then def.cooldown else 0
end

local PROFILES: { [string]: Profile } = {
	Pippa = {
		kind = "Bunny",
		line = "Crew speedster",
		words = { "Bouncy", "Cheerful", "Fast" },
		bio = "Pippa is quick on her feet and always cheers on her crew. She never stops hopping!",
		funFact = "Her bell rings when she is happy. It rings a lot.",
		ability = {
			name = "Let's Go!",
			line = "Speed up your team!",
			detail = "Pippa and the crew near her run faster for 4 seconds.",
			cooldown = cooldownOf("Pippa"),
			icon = "abilityLetsGo",
		},
		stats = { speed = 4, stamina = 4, strength = 2, suction = 3, quiet = 2 },
		color = {
			body = Color3.fromRGB(255, 138, 76),
			light = Color3.fromRGB(255, 194, 154),
			dark = Color3.fromRGB(122, 42, 18),
		},
	},
	Cappy = {
		kind = "Chill kid",
		line = "Finds the good stuff",
		words = { "Chill", "Brave (secretly)", "Doubter" },
		bio = "The boss's nephew, sent on night shifts to learn the family business. He says the building is NOT haunted.",
		funFact = "His badge says NEPHEW. He wears it on his back so nobody can see.",
		ability = {
			name = "Spot It!",
			line = "Find the good stuff!",
			detail = "Shows the closest treasure through walls for 5 seconds.",
			cooldown = cooldownOf("Cappy"),
			icon = "abilitySpotIt",
		},
		stats = { speed = 3, stamina = 2, strength = 3, suction = 3, quiet = 4 },
		color = {
			body = Color3.fromRGB(255, 182, 39),
			light = Color3.fromRGB(255, 224, 138),
			dark = Color3.fromRGB(122, 62, 6),
		},
	},
	Prickles = {
		kind = "Cactus",
		line = "Grumpy but brave",
		words = { "Grumpy", "Sturdy", "Big softy" },
		bio = "Prickles looks grumpy, but he is a big softy. He can hide anywhere!",
		funFact = "He waters his own flower every morning. Do not tell anyone.",
		ability = {
			name = "Potted Plant",
			line = "Pretend to be a plant!",
			detail = "Stand still as a potted plant for up to 8 seconds. The Manager walks right past.",
			cooldown = cooldownOf("Prickles"),
			icon = "abilityPottedPlant",
		},
		-- The all-rounder (owner, 2026-11-03): his ability is the sneaky part, not his stats.
		stats = { speed = 3, stamina = 3, strength = 3, suction = 3, quiet = 3 },
		color = {
			body = Color3.fromRGB(127, 191, 77),
			light = Color3.fromRGB(194, 235, 143),
			dark = Color3.fromRGB(34, 80, 26),
		},
	},
}

local EmployeeProfileRegistry = {
	STATS = table.freeze(STATS),
}

function EmployeeProfileRegistry.get(employee: string): Profile?
	return PROFILES[employee]
end

return EmployeeProfileRegistry
