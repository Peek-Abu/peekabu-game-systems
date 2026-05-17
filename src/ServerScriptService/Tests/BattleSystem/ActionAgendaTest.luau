--!strict
--[=[
	Unit tests for the ActionAgenda (Continuous ATB) system.
	
	Tests verify:
	- Proportional action frequency based on speed
	- Priority tiebreaking (faster battler wins ties)
	- Stagger mechanic (delay nextActionTime)
	- Queue rescheduling behavior
	
	@class ActionAgendaTest
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ActionAgenda = require(ServerScriptService.Modules.Classes.ActionAgenda)
local Battler = require(ServerScriptService.Modules.Classes.Battler)

local ActionAgendaTest = {}

--- Create a minimal mock battler with specified speed
local function makeBattler(speed: number, userId: number?, name: string?)
	return Battler.new({
		userId = userId,
		itemType = name or `Battler_spd{speed}`,
		currentHp = 100,
		maxHp = 100,
		attack = 10,
		defense = 10,
		speed = speed,
		statusEffects = {},
		moves = { "Strike" },
	})
end

function ActionAgendaTest.testProportionalActionCounts()
	local a = makeBattler(200, nil, "A")
	local b = makeBattler(150, nil, "B")
	local c = makeBattler(100, nil, "C")
	
	local agenda = ActionAgenda.new()
	agenda:build({ a, b }, { c })
	
	local counts = { A = 0, B = 0, C = 0 }
	
	-- Run 45 actions (5 cycles of 4:3:2 ratio = 9 actions per cycle)
	for _ = 1, 45 do
		local entry = agenda:next()
		assert(entry ~= nil, "Entry should not be nil")
		counts[entry.battler.itemType] += 1
		agenda:reschedule(entry.battler)
	end
	
	assert(counts.A == 20, `Expected A to act 20 times, got {counts.A}`)
	assert(counts.B == 15, `Expected B to act 15 times, got {counts.B}`)
	assert(counts.C == 10, `Expected C to act 10 times, got {counts.C}`)
	
	return true
end

function ActionAgendaTest.testPriorityTiebreak()
	local fast = makeBattler(200, nil, "Fast")
	local slow = makeBattler(100, nil, "Slow")
	
	local agenda = ActionAgenda.new()
	agenda:build({ fast }, { slow })
	
	-- Turn 1: fast @ 0.5
	local t1 = agenda:next()
	assert(t1.battler == fast, "Fast should act first")
	agenda:reschedule(t1.battler) -- nextActionTime = 1.0
	
	-- Turn 2: Both at t=1.0, fast should win tiebreak
	local t2 = agenda:next()
	assert(t2.battler == fast, "Fast should win t=1.0 tiebreak")
	
	return true
end

function ActionAgendaTest.testStaggerMechanic()
	local b1 = makeBattler(100, nil, "B1")
	local agenda = ActionAgenda.new()
	agenda:build({ b1 }, {})
	
	local entry = agenda:peek()
	local originalTime = entry.nextActionTime
	
	agenda:stagger(b1)
	
	local staggeredEntry = agenda:peek()
	local expectedTime = originalTime + 1.0 -- interval for speed 100
	assert(
		staggeredEntry.nextActionTime == expectedTime,
		`Expected nextActionTime {expectedTime}, got {staggeredEntry.nextActionTime}`
	)
	
	return true
end

function ActionAgendaTest.testRescheduling()
	local battler = makeBattler(150, nil, "Test")
	local agenda = ActionAgenda.new()
	agenda:build({ battler }, {})
	
	local entry1 = agenda:next()
	local firstTime = entry1.nextActionTime
	
	agenda:reschedule(battler)
	
	local entry2 = agenda:peek()
	local interval = 100 / 150 -- ACTION_UNIT / speed
	local expectedTime = firstTime + interval
	
	assert(
		math.abs(entry2.nextActionTime - expectedTime) < 0.001,
		`Expected nextActionTime {expectedTime}, got {entry2.nextActionTime}`
	)
	
	return true
end

function ActionAgendaTest.testEmptyQueue()
	local agenda = ActionAgenda.new()
	agenda:build({}, {})
	
	assert(agenda:isEmpty(), "Queue should be empty")
	assert(agenda:next() == nil, "next() should return nil for empty queue")
	
	return true
end

function ActionAgendaTest.testFaintedBattlerRemoval()
	local alive = makeBattler(100, nil, "Alive")
	local fainted = makeBattler(100, nil, "Fainted")
	fainted.currentHp = 0
	
	local agenda = ActionAgenda.new()
	agenda:build({ alive }, { fainted })
	
	-- Only alive battler should be in queue
	local entry = agenda:next()
	assert(entry.battler == alive, "Only alive battler should be queued")
	
	return true
end

return ActionAgendaTest
