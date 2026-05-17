--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Battler = require(ServerScriptService.Modules.Classes.Battler)
local BattleSession = require(ServerScriptService.Modules.Classes.BattleSession)
local SampleMoves = require(ServerScriptService.Modules.Battle.SampleMoves)

-- 1. Setup Battlers
local hero = Battler.new({
	userId = 1,
	itemType = "Hero",
	currentHp = 100,
	maxHp = 100,
	attack = 30,
	defense = 15,
	speed = 20,
	statusEffects = {},
	moves = { "Strike", "Thunderbolt", "FurySwipes" },
})

local monster = Battler.new({
	userId = nil,
	itemType = "Monster",
	currentHp = 120,
	maxHp = 120,
	attack = 25,
	defense = 12,
	speed = 10,
	statusEffects = {},
	moves = { "Bite" },
})

-- 2. Setup Session
local session = BattleSession.new({ hero }, { monster })
session:start()

-- 3. Run Test Turn 1: Thunderbolt (90% Acc, 40 Dmg)
print("\n--- TEST: Thunderbolt ---")
session:processTurn({
	[hero] = { move = SampleMoves.getThunderbolt(), target = monster },
	[monster] = { move = SampleMoves.getStrike(), target = hero },
})

-- 4. Run Test Turn 2: Fury Swipes (Multihit)
print("\n--- TEST: Fury Swipes (Combo) ---")
session:processTurn({
	[hero] = { move = SampleMoves.getFurySwipes(), target = monster },
	[monster] = { move = SampleMoves.getStrike(), target = hero },
})

print("\nFinal HP Verification:")
print(`Hero: {hero.currentHp}/{hero.maxHp}`)
print(`Monster: {monster.currentHp}/{monster.maxHp}`)
print("Battle Status:", session.status)
