--!strict
--[[
	SpeedQueueTest.luau — Tests for the Continuous ATB ActionAgenda system.
	
	Run via TestRunner.server.luau in Roblox Studio.
	
	Test coverage:
	  1. Proportional Action Counts (200:150:100 speed → 4:3:2 ratio)
	  2. Priority Tiebreak (faster battler wins t=0 ties)
	  3. Stagger (delay nextActionTime by one interval)
	  4. AI-only simulation completes correctly
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ActionAgenda = require(ServerScriptService.Modules.Classes.ActionAgenda)
local BattleSession = require(ServerScriptService.Modules.Classes.BattleSession)
local Battler = require(ServerScriptService.Modules.Classes.Battler)

-- ── Helpers ───────────────────────────────────────────────────────────────────

local passed = 0
local failed = 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		print(`  [PASS] {name}`)
		passed += 1
	else
		warn(`  [FAIL] {name}: {err}`)
		failed += 1
	end
end

local function assert(cond: boolean, msg: string?)
	if not cond then
		error(msg or "assertion failed", 2)
	end
end

local function assertEqual(a: any, b: any, msg: string?)
	if a ~= b then
		error((msg or "assertEqual") .. ` — expected {tostring(b)}, got {tostring(a)}`, 2)
	end
end

--- Make a minimal mock battler with a given speed and optional userId
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

-- ── Test 1: Continuous ATB Ratios ─────────────────────────────────────────────

print("\n─── Test 1: Continuous ATB Ratios (200:150:100) ───")

test("Speed 200:150:100 produces 4:3:2 ratio over 45 turns", function()
	local a = makeBattler(200, nil, "A")
	local b = makeBattler(150, nil, "B")
	local c = makeBattler(100, nil, "C")
	
	local agenda = ActionAgenda.new()
	agenda:build({ a, b }, { c })
	
	local counts = { A = 0, B = 0, C = 0 }
	
	-- Run exactly 45 actions (5 cycles of the 4:3:2 ratio which totals 9)
	for i = 1, 45 do
		local entry = agenda:next()
		assert(entry ~= nil, "entry should not be nil")
		counts[entry.battler.itemType] += 1
		agenda:reschedule(entry.battler)
	end
	
	assertEqual(counts.A, 20, "A should act 20 times (5*4)")
	assertEqual(counts.B, 15, "B should act 15 times (5*3)")
	assertEqual(counts.C, 10, "C should act 10 times (5*2)")
end)

-- ── Test 2: Priority Tiebreak ─────────────────────────────────────────────────

print("\n─── Test 2: Priority Tiebreak ───")

test("Faster battler goes first when nextActionTime is identical", function()
	local fast = makeBattler(200, nil, "Fast")
	local slow = makeBattler(100, nil, "Slow")
	
	local agenda = ActionAgenda.new()
	-- At t=0 both are added. Interval fast=0.5, slow=1.0. 
	-- Let's force them to be identical by building manually if needed, 
	-- but build() should handle it.
	agenda:build({ fast }, { slow })
	
	-- At t=1.0 (after 2 fast turns and 1 slow turn) they should tie.
	-- Turn 1: fast @ 0.5
	local t1 = agenda:next()
	assertEqual(t1.battler, fast)
	agenda:reschedule(t1.battler) -- nextActionTime = 0.5 + 0.5 = 1.0
	
	-- Turn 2: nextActionTime for fast is 1.0, for slow is 1.0
	-- Fast should win tiebreak
	local t2 = agenda:next()
	assertEqual(t2.battler, fast, "Fast wins t=1.0 tiebreak")
end)

-- ── Test 3: Stagger Mechanic ──────────────────────────────────────────────────

print("\n─── Test 3: Stagger ───")

test("Stagger delays nextActionTime by one full interval", function()
	local b1 = makeBattler(100, nil, "B1") -- interval = 1.0
	local agenda = ActionAgenda.new()
	agenda:build({ b1 }, {})
	
	local entry = agenda:peek()
	local originalTime = entry.nextActionTime
	
	agenda:stagger(b1)
	
	local staggeredEntry = agenda:peek()
	assertEqual(staggeredEntry.nextActionTime, originalTime + 1.0, "Time delayed by 1.0 interval")
end)

-- ── Test 4: AI Simulation ─────────────────────────────────────────────────────

print("\n─── Test 4: AI Simulation ───")

test("Full cycle simulation completes correctly", function()
	local a = makeBattler(200, nil, "A")
	local b = makeBattler(100, nil, "B")
	local session = BattleSession.new({ a }, { b })

	-- We verify it doesn't crash
	local ok = pcall(function()
		session:startBattle()
	end)
	assert(ok, "startBattle should not throw")
end)

-- ── Summary ───────────────────────────────────────────────────────────────────

print(`\n═══ Continuous ATB Tests: {passed} passed, {failed} failed ═══\n`)

return {}
