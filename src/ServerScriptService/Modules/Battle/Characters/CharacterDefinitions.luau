--!strict
--[=[
	Character Definitions - 8 ACTUAL iconic anime characters
	
	Each character has:
	- Unique base stats that define their playstyle
	- An element that shapes their abilities
	- A passive ability that makes them unique (always-on playstyle hook)
	- A signature moveset with unlockable moves
	
	Design Philosophy:
	- These ARE the actual characters, not "inspired by"
	- Faithful to their anime abilities and personalities
	- Creative mechanics that capture their essence
	- Fun factor over pure balance
	
	@class CharacterDefinitions
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BattleModifiers = require(ServerScriptService.Modules.Battle.Base.BattleModifiers)
local Effect = require(ServerScriptService.Modules.Battle.Base.Effect)
local TypeConstants = require(game:GetService("ReplicatedStorage").Shared.Classes.Constants.TypeConstants)
local ELEMENTS = TypeConstants.ELEMENTS

local CharacterDefinitions = {}

-- Helper: fire a BattleLog event from a passive context
local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "passive",
		})
	end
end

export type PassiveAbility = {
	name: string,
	description: string,
	trigger: string | { string }, -- single or multiple: "OnHit", "BeforeHit", "BeforeAccuracyCheck", etc.
	effect: (context: any) -> (),
}

export type CharacterData = {
	id: string,
	name: string,
	title: string,
	element: TypeConstants.ElementType,
	description: string,
	
	-- Base stats (level 50)
	baseHp: number,
	baseAttack: number,
	baseDefense: number,
	baseSpeed: number,
	
	-- Passive ability
	passive: PassiveAbility,
	
	-- Moveset
	moves: {
		{
			name: string,
			unlockLevel: number,
		}
	},
	
	-- Visual/flavor
	model: string?, -- Model name in workspace
	voiceLines: { string }?,
	animations: { [string]: string }?,
}

--[=[
	CHARACTER 1: GOKU - Burst Assassin / Speed Demon
	From: Dragon Ball Z
	Playstyle: All-in nuker or comeback carry with Zenkai Boost
	Element: Brawler
]=]
local GOKU: CharacterData = {
	id = "GOKU",
	name = "Goku",
	title = "Saiyan Warrior",
	element = ELEMENTS.BRAWLER,
	description = "A pure-hearted Saiyan who grows stronger through battle. Never gives up.",
	
	baseHp = 850,      -- 85 base
	baseAttack = 260,  -- 28 base
	baseDefense = 120, -- 16 base
	baseSpeed = 220,   -- 22 base
	
	passive = {
		name = "Zenkai Boost",
		description = "After taking fatal damage, revive at 50% HP with +20% all stats (once per battle). The more you fight, the stronger you become.",
		trigger = "OnDamaged",
		effect = function(context)
			local battler = context.defender
			
			-- Check for fatal damage
			if battler.currentHp <= 0 and not battler._zenkaiUsed then
				battler._zenkaiUsed = true
				
				-- Revive at 50% HP
				battler.currentHp = math.floor(battler.maxHp * 0.5)
				
				-- Boost all stats by 20%
				battler.attack = math.floor(battler.attack * 1.2)
				battler.defense = math.floor(battler.defense * 1.2)
				battler.speed = math.floor(battler.speed * 1.2)
				
				fireLog(context, `{battler.itemType} activates Zenkai Boost passive! Revived with +20% all stats!`, "passive")
			end
		end,
	},
	
	moves = {
		{ name = "Kamehameha", unlockLevel = 1 },
		{ name = "SpiritBomb", unlockLevel = 1 },
		{ name = "SuperSaiyan", unlockLevel = 5 },
		{ name = "InstantTransmission", unlockLevel = 10 },
		{ name = "DragonFist", unlockLevel = 15 },
		{ name = "UltraInstinct", unlockLevel = 20 },
	},
	
	model = "Goku",
	voiceLines = {
		"Let's fight!",
		"I won't let you destroy my world!",
		"Kame... Hame... HA!",
	},
}

--[=[
	CHARACTER 2: NARUTO - Sustain Swarm / Rasengan Blaster
	From: Naruto
	Playstyle: Swarm distractions or poke machine with infinite clones
	Element: Wind
]=]
local NARUTO: CharacterData = {
	id = "NARUTO",
	name = "Naruto",
	title = "Hokage of the Hidden Leaf",
	element = ELEMENTS.WIND,
	description = "A ninja who never gives up. Creates shadow clones that explode on death.",
	
	baseHp = 900,      -- 90 base
	baseAttack = 240,  -- 24 base
	baseDefense = 180, -- 18 base
	baseSpeed = 200,   -- 20 base
	
	passive = {
		name = "Clone Factory",
		description = "Shadow clones cost 0 energy and explode on death dealing splash damage. Can have up to 3 clones active.",
		trigger = "OnHit",
		effect = function(context)
			local battler = context.attacker
			
			-- Track active clones
			battler._activeClones = battler._activeClones or 0
			
			-- Clones deal 30% of Naruto's damage
			if battler._activeClones > 0 then
				local cloneDamage = math.floor(context.damage * 0.3 * battler._activeClones)
				context.defender:takeDamage(cloneDamage)
				fireLog(context, `{battler._activeClones} shadow clones deal {cloneDamage} bonus damage!`, "passive")
			end
		end,
	},
	
	moves = {
		{ name = "Rasengan", unlockLevel = 1 },
		{ name = "ShadowClone", unlockLevel = 1 },
		{ name = "TailedBeastBomb", unlockLevel = 5 },
		{ name = "SageMode", unlockLevel = 10 },
		{ name = "Rasenshuriken", unlockLevel = 15 },
		{ name = "BaryonMode", unlockLevel = 20 },
	},
	
	model = "Naruto",
	voiceLines = {
		"Believe it!",
		"I never go back on my word!",
		"Shadow Clone Jutsu!",
	},
}

--[=[
	CHARACTER 3: LUFFY - Stretch Brawler / Gear Shifter
	From: One Piece
	Playstyle: Unhittable tank or wild aggro with rubber physics
	Element: Brawler
]=]
local LUFFY: CharacterData = {
	id = "LUFFY",
	name = "Luffy",
	title = "Future Pirate King",
	element = ELEMENTS.BRAWLER,
	description = "A rubber man who can stretch and bounce. His rubber body grants him natural resistance to blunt strikes and total immunity to lightning.",
	
	baseHp = 950,      -- 95 base
	baseAttack = 260,  -- 26 base
	baseDefense = 220, -- 22 base
	baseSpeed = 180,   -- 18 base
	
	passive = {
		name = "Rubber Human",
		description = "Reduces damage from Blunt attacks by 40%. Immune to Lightning damage. Stretching attacks ignore 50% enemy defense.",
		trigger = { "BeforeHit", "OnDamaged" },
		effect = function(context)
			local battler = context.battler
			local move = context.move
			
			-- 1. Lightning Immunity (OnDamaged or BeforeHit)
			if move and move.element == ELEMENTS.LIGHTNING then
				if context.trigger == "BeforeHit" and context.defender == battler then
					BattleModifiers.push(context, "cancelHit", true, "Rubber Human (Immunity)")
					fireLog(context, `{battler.itemType}'s rubber body is an insulator! Lightning has no effect!`, "passive")
				end
				return
			end

			-- 2. Blunt Resistance (BeforeHit)
			if context.trigger == "BeforeHit" and context.defender == battler then
				if move and move.damageSubType == "Blunt" then
					BattleModifiers.push(context, "damageMultiplier", 0.6, "Rubber Human (Resist)")
					fireLog(context, `{battler.itemType}'s rubber body absorbs the impact!`, "passive")
				end
			end

			-- 3. Stretching attacks ignore 50% defense (Offensive)
			if context.trigger == "BeforeHit" and context.attacker == battler then
				-- We assume all of Luffy's "Gum-Gum" moves are stretching attacks
				if move and move.name:match("^Gum") then
					BattleModifiers.push(context, "defenseMultiplier", 0.5, "Rubber Human (Stretch)")
				end
			end
		end,
	},
	
	moves = {
		{ name = "GumPistol", unlockLevel = 1 },
		{ name = "GumBazooka", unlockLevel = 1 },
		{ name = "GumBell", unlockLevel = 5 },
		{ name = "GumBalloon", unlockLevel = 10 },
		{ name = "Gear2", unlockLevel = 12 },
		{ name = "Gear4", unlockLevel = 15 },
		{ name = "ConquerorHaki", unlockLevel = 18 },
		{ name = "Gear5", unlockLevel = 22 },
		{ name = "BajrangGun", unlockLevel = 25 },
	},
	
	model = "Luffy",
	voiceLines = {
		"I'm gonna be King of the Pirates!",
		"Gomu Gomu no...",
		"Gear Second!",
	},
}

--[=[
	CHARACTER 4: ICHIGO - Form Shifter / Hollow Berserker
	From: Bleach
	Playstyle: Adaptive slayer or rage mode with form switching
	Element: Dark
]=]
local ICHIGO: CharacterData = {
	id = "ICHIGO",
	name = "Ichigo",
	title = "Substitute Soul Reaper",
	element = ELEMENTS.SPIRIT,
	description = "A soul reaper with Hollow powers. Can shift forms mid-battle for different advantages.",
	
	baseHp = 820,      -- 82 base
	baseAttack = 270,  -- 27 base
	baseDefense = 150, -- 15 base
	baseSpeed = 240,   -- 24 base
	
	passive = {
		name = "Hybrid Forms",
		description = "Toggle between Shikai (damage), Bankai (speed), and Hollow (power/control) forms mid-fight. Each form has unique advantages.",
		trigger = "BattlerTurnStart",
		effect = function(context)
			local battler = context.battler
			
			-- Default to Shikai if no form set
			battler._currentForm = battler._currentForm or "Shikai"
			
			-- Apply form bonuses
			if battler._currentForm == "Shikai" then
				battler._formDamageBonus = 1.15 -- +15% damage
			elseif battler._currentForm == "Bankai" then
				battler._formSpeedBonus = 1.3 -- +30% speed
			elseif battler._currentForm == "Hollow" then
				battler._formPowerBonus = 1.4 -- +40% power but -10% control
				battler._formAccuracyPenalty = 0.9
			end
		end,
	},
	
	moves = {
		{ name = "GetsugaTensho", unlockLevel = 1 },
		{ name = "BankaiSpeed", unlockLevel = 1 },
		{ name = "Mugetsu", unlockLevel = 5 },
		{ name = "VastoLorde", unlockLevel = 10 },
		{ name = "GranRey", unlockLevel = 15 },
		{ name = "TrueZangetsu", unlockLevel = 20 },
	},
	
	model = "Ichigo",
	voiceLines = {
		"Bankai!",
		"Getsuga Tensho!",
		"I'll protect everyone!",
	},
}

--[=[
	CHARACTER 5: GOJO - Zone Controller / Infinity Untouchable
	From: Jujutsu Kaisen
	Playstyle: Poke god or team protector with Infinity
	Element: Void
]=]
local GOJO: CharacterData = {
	id = "GOJO",
	name = "Gojo",
	title = "The Strongest Sorcerer",
	element = ELEMENTS.VOID,
	description = "A sorcerer with Limitless and Six Eyes. Controls space itself and is nearly untouchable.",
	
	baseHp = 700,      -- 70 base
	baseAttack = 300,  -- 30 base
	baseDefense = 140, -- 14 base
	baseSpeed = 230,   -- 23 base
	
	passive = {
		name = "Infinity Field",
		description = "Slows incoming attacks by 50%. Perfect QTE = reverse attack to sender. Attacks never miss.",
		trigger = { "BeforeAccuracyCheck", "BeforeHit" },
		effect = function(context)
			if context.trigger == "BeforeAccuracyCheck" then
				-- Six Eyes - never miss
				if context.attacker == context.battler then
					BattleModifiers.push(context, "accuracyOverride", true, "Six Eyes")
				end
			elseif context.trigger == "BeforeHit" then
				-- Infinity halves incoming damage
				if context.defender == context.battler then
					BattleModifiers.push(context, "damageMultiplier", 0.5, "Infinity Field")
					
					-- Perfect QTE reversal
					if BattleModifiers.has(context, "perfectQTE") then
						local reflectDamage = math.floor(context.attacker.attack * 0.5)
						context.attacker:takeDamage(reflectDamage)
						context.cancelled = true
					end
				end
			end
		end,
	},
	
	moves = {
		{ name = "LapseBlue", unlockLevel = 1 },
		{ name = "ReversalRed", unlockLevel = 1 },
		{ name = "HollowPurple", unlockLevel = 5 },
		{ name = "DomainExpansion", unlockLevel = 10 },
		{ name = "TeleportSwap", unlockLevel = 15 },
		{ name = "UnlimitedVoid", unlockLevel = 20 },
	},
	
	model = "Gojo",
	voiceLines = {
		"Throughout Heaven and Earth, I alone am the honored one.",
		"Infinity.",
		"Domain Expansion: Unlimited Void.",
	},
}

--[=[
	CHARACTER 6: NATSU - Dragon Slayer Pyro
	From: Fairy Tail
	Playstyle: Aggressive fire stacker — burns enemies, eats fire damage, cashes out stacks
	Element: Fire
	
	Passive: Dragon Slayer Hunger
	  - When Natsu takes Fire damage: reduce by 50%, gain 1 Fire Dragon Stack (max 5).
	  - Each Fire Dragon Stack = +5% Fire damage dealt, +5% Burn chance, +3% resistance to Fire/Beast/Brawler moves.
	  - Dragon's Feast move consumes all stacks for burst heal + damage amp.
	
	Triggers:
	  - BeforeHit: apply Fire Dragon Stacks damage bonus + Dragon's Feast bonus to Fire moves
	  - OnDamaged: reduce incoming Fire damage by 50%, Fire Dragon Stacks resistance on Fire/Beast/Brawler moves, gain Fire Dragon Stacks on fire
]=]
local NATSU: CharacterData = {
	id = "NATSU",
	name = "Natsu",
	title = "The Salamander",
	element = ELEMENTS.FIRE,
	description = "A Dragon Slayer who devours fire to power up. Each Fire Dragon Stack makes his attacks burn hotter.",

	baseHp = 780,      -- 78 base
	baseAttack = 250,  -- 25 base
	baseDefense = 170, -- 17 base
	baseSpeed = 210,   -- 21 base

	passive = {
		name = "Fire Dragon Slayer's Hunger",
		description = "Natsu's skin hardens with fiery dragon scales as he builds stacks. Each stack increases power (Fire/Beast/Brawler) by 5%, and increases resistance (Fire/Beast/Brawler) by 3%. Max 5 stacks.",
		trigger = { "BeforeHit", "OnDamaged" },
		effect = function(context)
			local battler = context.battler
			local TypeConstants = require(ReplicatedStorage.Shared.Classes.Constants.TypeConstants)
			local ELEMENTS = TypeConstants.ELEMENTS
			local stacks = battler._fireDragonStacks or 0

			-- Defensive: 50% Fire reduction + stack-based resistance (3% per stack)
			if context.trigger == "BeforeHit" and context.defender == battler then
				if context.move then
					local el = context.move.element
					local cat = context.move.category
					
					-- Base Fire Slayer's Hunger (50%)
					if el == ELEMENTS.FIRE then
						BattleModifiers.push(context, "damageMultiplier", 0.5, "Fire Dragon Slayer's Hunger")
					end

					-- Tiered Resistance: 3% per stack for Fire, Beast, or Brawler
					if (el == ELEMENTS.FIRE or el == ELEMENTS.BEAST or el == ELEMENTS.BRAWLER) and stacks > 0 then
						local reduction = 1 - (stacks * 0.03)
						BattleModifiers.push(context, "damageMultiplier", reduction, "Fire Dragon Stacks")
					end
				end
			end

			-- Defensive Gain: Add stack ONLY when hit actually lands (OnDamaged)
			if context.trigger == "OnDamaged" and context.defender == battler then
				-- Ignore self-hits
				if context.attacker == battler then return end

				if context.move and context.move.element == ELEMENTS.FIRE then
					-- TODO: In the future, we could gate this stack gain behind a successful defensive QTE 
					-- or specific move triggers for more skill-based expression.
					battler._fireDragonStacks = math.min(5, (battler._fireDragonStacks or 0) + 1)
					Effect.removeBuff(battler, "Fire Dragon Stacks")
					Effect.registerBuff(battler, { 
						name = "Fire Dragon Stacks", 
						desc = `Fire Dragon Stacks: {battler._fireDragonStacks}/5 (+{battler._fireDragonStacks * 5}% Power, +{battler._fireDragonStacks * 3}% Res, +{battler._fireDragonStacks * 5}% Burn chance)` 
					})
					fireLog(context, `{battler.itemType} built draconic power! Stacks: {battler._fireDragonStacks}`, "passive")
				end
			end

			-- Offensive: Power boost for Fire, Beast, and Brawler techniques
			if context.trigger == "BeforeHit" and context.attacker == battler then
				if stacks > 0 and context.move then
					local el = context.move.element
					if el == ELEMENTS.FIRE or el == ELEMENTS.BEAST or el == ELEMENTS.BRAWLER then
						local bonus = 0.05 * stacks
						BattleModifiers.push(context, "damageMultiplier", 1 + bonus, "Fire Dragon Stacks")
						
						-- Burn chance applies to all Fire, Beast, or Brawler moves (e.g. Iron Fist)
						BattleModifiers.push(context, "chanceBonus", { tag = "Burn", value = bonus * 100 }, "Fire Dragon Stacks")
					end
				end

				if battler._dragonsFeastBonus and battler._dragonsFeastBonus > 1 and context.move and
					(context.move.element == ELEMENTS.FIRE or context.move.element == ELEMENTS.BRAWLER or context.move.element == ELEMENTS.BEAST) then
					BattleModifiers.push(context, "damageMultiplier", battler._dragonsFeastBonus, "Fire Dragon's Feast")
					battler._dragonsFeastBonus = nil
					Effect.removeBuff(battler, "Fire Dragon's Feast")
				end
			end
		end,
	},
	
	moves = {
		{ name = "FireDragonIronFist", unlockLevel = 1 },
		{ name = "FireDragonRoar", unlockLevel = 1 },
		{ name = "FlamesOfEmotion", unlockLevel = 5 },
		{ name = "DragonsFeast", unlockLevel = 10 },
	},
	
	model = "Natsu",
	voiceLines = {
		"I'm all fired up!",
		"Fire Dragon's Roar!",
		"I'll burn everything!",
	},
}

--[=[
	CHARACTER 7: ALL MIGHT - Smash Tank / Hero Rally
	From: My Hero Academia
	Playstyle: Frontline anchor or party enabler
	Element: Brawler
]=]
local ALL_MIGHT: CharacterData = {
	id = "ALL_MIGHT",
	name = "All Might",
	title = "Symbol of Peace",
	element = ELEMENTS.BRAWLER,
	description = "The #1 Hero who inspires everyone. Smashes enemies and rallies allies.",
	
	baseHp = 1000,     -- 100 base
	baseAttack = 290,  -- 29 base
	baseDefense = 200, -- 20 base
	baseSpeed = 190,   -- 19 base
	
	passive = {
		name = "Hero Presence",
		description = "Nearby allies +10% Atk/Def. Your smashes apply 'Fear' debuff (enemy -speed).",
		trigger = "OnHit",
		effect = function(context)
			local battler = context.attacker
			
			-- Apply Fear debuff
			if battler.itemType == "All Might" then
				local target = context.defender
				target._fearDebuff = true
				target.speed = math.floor(target.speed * 0.85)
				fireLog(context, `{target.itemType} is intimidated! Speed reduced!`, "status")
			end
			
			-- TODO: Ally buff (requires team system)
			-- Allies within range get +10% Atk/Def
		end,
	},
	
	moves = {
		{ name = "DetroitSmash", unlockLevel = 1 },
		{ name = "UnitedStatesSmash", unlockLevel = 1 },
		{ name = "FullCowl", unlockLevel = 5 },
		{ name = "OneForAll100", unlockLevel = 10 },
		{ name = "UnitedSmash", unlockLevel = 15 },
		{ name = "FinalStand", unlockLevel = 20 },
	},
	
	model = "AllMight",
	voiceLines = {
		"I am here!",
		"PLUS ULTRA!",
		"A true hero always finds a way to win!",
	},
}

--[=[
	CHARACTER 8: RIMURU - Mimic Thief / Slime Adapt
	From: That Time I Got Reincarnated as a Slime
	Playstyle: Counter-pick meta or skill hoarder
	Element: Water
]=]
local RIMURU: CharacterData = {
	id = "RIMURU",
	name = "Rimuru",
	title = "Slime Demon Lord",
	element = ELEMENTS.WATER,
	description = "A slime who can analyze and copy enemy abilities. Adapts to any situation.",
	
	baseHp = 750,      -- 75 base
	baseAttack = 230,  -- 23 base
	baseDefense = 190, -- 19 base
	baseSpeed = 200,   -- 20 base
	
	passive = {
		name = "Predator Skill",
		description = "25% chance to permanently learn enemy's move on hit. Can store up to 5 copied moves.",
		trigger = "OnHit",
		effect = function(context)
			local battler = context.attacker
			
			if battler.itemType == "Rimuru" and math.random(100) <= 25 then
				-- Initialize copied moves
				battler._copiedMoves = battler._copiedMoves or {}
				
				-- Check if we can copy more moves
				if #battler._copiedMoves < 5 then
					local enemyMove = context.move
					if enemyMove and not table.find(battler._copiedMoves, enemyMove.name) then
						table.insert(battler._copiedMoves, enemyMove.name)
						table.insert(battler.moves, enemyMove.name)
						fireLog(context, `{battler.itemType} learned {enemyMove.name} with Predator!`, "passive")
					end
				end
			end
		end,
	},
	
	moves = {
		{ name = "PredatorMimic", unlockLevel = 1 },
		{ name = "WaterBlade", unlockLevel = 1 },
		{ name = "Beelzebub", unlockLevel = 5 },
		{ name = "BarrierWall", unlockLevel = 10 },
		{ name = "StormTempest", unlockLevel = 15 },
		{ name = "UltimateEvolve", unlockLevel = 20 },
	},
	
	model = "Rimuru",
	voiceLines = {
		"Predator!",
		"I'll analyze that.",
		"Great Sage, what should I do?",
	},
}

-- Export all characters
CharacterDefinitions.GOKU = GOKU
CharacterDefinitions.NARUTO = NARUTO
CharacterDefinitions.LUFFY = LUFFY
CharacterDefinitions.ICHIGO = ICHIGO
CharacterDefinitions.GOJO = GOJO
CharacterDefinitions.NATSU = NATSU
CharacterDefinitions.ALL_MIGHT = ALL_MIGHT
CharacterDefinitions.RIMURU = RIMURU

CharacterDefinitions.ALL_CHARACTERS = {
	GOKU,
	NARUTO,
	LUFFY,
	ICHIGO,
	GOJO,
	NATSU,
	ALL_MIGHT,
	RIMURU,
}

function CharacterDefinitions.getCharacterById(id: string): CharacterData?
	for _, char in CharacterDefinitions.ALL_CHARACTERS do
		if char.id == id then
			return char
		end
	end
	return nil
end

function CharacterDefinitions.createBattlerFromCharacter(characterId: string, level: number, userId: number?): any
	local char = CharacterDefinitions.getCharacterById(characterId)
	if not char then
		error(`Character "{characterId}" not found. Available: {table.concat(CharacterDefinitions.getAllCharacterIds(), ", ")}`)
	end
	
	-- Scale stats by level (level 50 is baseline)
	local levelMultiplier = level / 50
	
	-- Populate moves based on unlock level
	local unlockedMoves = {}
	for _, moveData in char.moves do
		if level >= moveData.unlockLevel then
			table.insert(unlockedMoves, moveData.name)
		end
	end
	
	return {
		userId = userId,
		itemType = char.name,
		characterId = char.id,
		element = char.element,
		currentHp = math.floor(char.baseHp * levelMultiplier),
		maxHp = math.floor(char.baseHp * levelMultiplier),
		attack = math.floor(char.baseAttack * levelMultiplier),
		defense = math.floor(char.baseDefense * levelMultiplier),
		speed = math.floor(char.baseSpeed * levelMultiplier),
		level = level,
		statusEffects = {},
		moves = unlockedMoves,
		passive = char.passive,
	}
end

--- Get all character IDs
function CharacterDefinitions.getAllCharacterIds(): { string }
	local ids = {}
	for _, char in CharacterDefinitions.ALL_CHARACTERS do
		table.insert(ids, char.id)
	end
	return ids
end

return CharacterDefinitions
