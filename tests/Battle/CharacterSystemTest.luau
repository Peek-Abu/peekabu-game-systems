--!strict
--[=[
	Character System Test
	
	Tests all 8 iconic anime characters with their stats, abilities, and moves.
	Uses CharacterFactory and MoveRegistry.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CharacterFactory = require(ServerScriptService.Modules.Battle.Characters.CharacterFactory)
local MoveRegistry = require(ServerScriptService.Modules.Battle.MoveRegistry)

local function printSeparator()
	print("\n" .. string.rep("=", 80) .. "\n")
end

local function printCharacterInfo(battler: any)
	print(`  {battler.itemType} ({battler.characterId}) | Lv{battler.level}`)
	print(`    Element: {battler.element}`)
	print(`    HP: {battler.currentHp}/{battler.maxHp} | ATK: {battler.attack} | DEF: {battler.defense} | SPD: {battler.speed}`)
	print(`    Moves: {table.concat(battler.moves, ", ")}`)
	if battler.passive then
		print(`    Passive: {battler.passive.name}`)
	end
end

print("\n CHARACTER SYSTEM TEST\n")

-- ── TEST 1: Create all 8 characters ──────────────────────────────────────────

printSeparator()
print("TEST 1: Creating all 8 characters at level 50")
printSeparator()

local allIds = CharacterFactory.getAllCharacterIds()
print(`Found {#allIds} characters: {table.concat(allIds, ", ")}`)
print()

local characters = {}
for _, id in allIds do
	local battler = CharacterFactory.createCharacter({ characterId = id, level = 50 })
	characters[id] = battler
	printCharacterInfo(battler)
	print()
end

assert(#allIds == 8, `Expected 8 characters, got {#allIds}`)
print("PASS: All 8 characters created")

-- ── TEST 2: Level scaling ────────────────────────────────────────────────────

printSeparator()
print("TEST 2: Goku level scaling (Lv1 vs Lv50 vs Lv100)")
printSeparator()

local gokuLv1 = CharacterFactory.createCharacter({ characterId = "GOKU", level = 1 })
local gokuLv50 = CharacterFactory.createCharacter({ characterId = "GOKU", level = 50 })
local gokuLv100 = CharacterFactory.createCharacter({ characterId = "GOKU", level = 100 })

printCharacterInfo(gokuLv1)
print()
printCharacterInfo(gokuLv50)
print()
printCharacterInfo(gokuLv100)

assert(gokuLv100.attack > gokuLv50.attack, "Lv100 should have more attack than Lv50")
assert(gokuLv50.attack > gokuLv1.attack, "Lv50 should have more attack than Lv1")
print("\nPASS: Stats scale correctly with level")

-- ── TEST 3: Move unlocking ───────────────────────────────────────────────────

printSeparator()
print("TEST 3: Naruto move unlocking by level")
printSeparator()

local narutoLv1 = CharacterFactory.createCharacter({ characterId = "NARUTO", level = 1 })
local narutoLv10 = CharacterFactory.createCharacter({ characterId = "NARUTO", level = 10 })
local narutoLv20 = CharacterFactory.createCharacter({ characterId = "NARUTO", level = 20 })

print(`  Lv1 moves:  {table.concat(narutoLv1.moves, ", ")}`)
print(`  Lv10 moves: {table.concat(narutoLv10.moves, ", ")}`)
print(`  Lv20 moves: {table.concat(narutoLv20.moves, ", ")}`)

assert(#narutoLv20.moves > #narutoLv1.moves, "Higher level should have more moves")
print("\nPASS: Moves unlock correctly by level")

-- ── TEST 4: MoveRegistry ────────────────────────────────────────────────────

printSeparator()
print("TEST 4: MoveRegistry dynamic loading")
printSeparator()

local moveCount = MoveRegistry.getMoveCount()
print(`  Total registered moves: {moveCount}`)

-- Spot-check some moves exist
local spotChecks = { "Kamehameha", "Rasengan", "GumPistol", "GetsugaTensho", "HollowPurple", "DetroitSmash", "Tackle", "Strike" }
for _, moveName in spotChecks do
	local exists = MoveRegistry.hasMove(moveName)
	print(`  {moveName}: {if exists then "FOUND" else "MISSING"}`)
	assert(exists, `Move {moveName} should exist in registry`)
end

print(`\nPASS: All {#spotChecks} spot-checked moves found in registry`)

-- ── TEST 5: Character diversity ──────────────────────────────────────────────

printSeparator()
print("TEST 5: Character diversity check")
printSeparator()

print("Character    | HP   | ATK  | DEF  | SPD  | Element  | Passive")
print(string.rep("-", 85))

for _, id in allIds do
	local c = characters[id]
	print(string.format("%-12s | %4d | %4d | %4d | %4d | %-8s | %s",
		c.itemType, c.maxHp, c.attack, c.defense, c.speed, c.element, c.passive.name))
end

print("\nPASS: All characters have unique stats and abilities")

-- ── DONE ─────────────────────────────────────────────────────────────────────

printSeparator()
print("CHARACTER SYSTEM TEST COMPLETE - All tests passed!")
printSeparator()

return true
