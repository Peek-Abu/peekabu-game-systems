--!strict
--[=[
	Battle System Test Suite Runner
	
	Runs all unit tests for the battle system and reports results.
	
	@class BattleSystemTests
]=]

local ActionAgendaTest = require(script.ActionAgendaTest)
local BattleSessionTest = require(script.BattleSessionTest)
local QTESystemTest = require(script.QTESystemTest)

local BattleSystemTests = {}

local function runTest(testName: string, testFn: () -> boolean): boolean
	local success, result = pcall(testFn)
	
	if success and result then
		print(`  ✓ {testName}`)
		return true
	else
		warn(`  ✗ {testName}`)
		if not success then
			warn(`    Error: {result}`)
		end
		return false
	end
end

local function runTestSuite(suiteName: string, testModule: any): { passed: number, failed: number }
	print(`\n━━━ {suiteName} ━━━`)
	
	local passed = 0
	local failed = 0
	
	for testName, testFn in testModule do
		if type(testFn) == "function" and testName:match("^test") then
			if runTest(testName, testFn) then
				passed += 1
			else
				failed += 1
			end
		end
	end
	
	return { passed = passed, failed = failed }
end

function BattleSystemTests.runAll()
	print("\n╔═══════════════════════════════════════════╗")
	print("║   BATTLE SYSTEM TEST SUITE               ║")
	print("╚═══════════════════════════════════════════╝")
	
	local totalPassed = 0
	local totalFailed = 0
	
	-- Run ActionAgenda tests
	local agendaResults = runTestSuite("ActionAgenda Tests", ActionAgendaTest)
	totalPassed += agendaResults.passed
	totalFailed += agendaResults.failed
	
	-- Run BattleSession tests
	local sessionResults = runTestSuite("BattleSession Tests", BattleSessionTest)
	totalPassed += sessionResults.passed
	totalFailed += sessionResults.failed
	
	-- Run QTE System tests
	local qteResults = runTestSuite("QTE System Tests", QTESystemTest)
	totalPassed += qteResults.passed
	totalFailed += qteResults.failed
	
	-- Summary
	print("\n╔═══════════════════════════════════════════╗")
	print(`║   RESULTS: {totalPassed} passed, {totalFailed} failed`)
	print("╚═══════════════════════════════════════════╝\n")
	
	return totalFailed == 0
end

return BattleSystemTests
