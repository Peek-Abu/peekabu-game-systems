--!strict
--[=[
	TestRunner: Runs all tests in the project using TestEZ.
	
	Runs:
	1. TestEZ spec files (*.spec.luau) - ~135+ tests
	2. Battle system unit tests - 25 tests
	3. Legacy integration tests - SpeedQueueTest, RealTimeParryTest
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)
local GameItems = require(ReplicatedStorage.Shared.Modules.GameItems)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

-- Suppress debug/info logs during tests (only show warnings/errors)
local originalLogLevel = Logger.getGlobalLevel()
Logger.setGlobalLevel(originalLogLevel)

-- Override print/warn to suppress non-Logger output during tests
local originalPrint = print
local originalWarn = warn
local function noop() end

-- Suppress print/warn BEFORE initializing anything
print = noop
warn = noop

-- Locations to search for *.spec.luau files
local testLocations = {
	ReplicatedStorage.Shared,
	ServerScriptService.Modules,
	ServerScriptService.Services,
}

-- Initialize game data so tests have items to reference
GameItems.init()

originalPrint("\n" .. string.rep("=", 60))
originalPrint("RUNNING ALL TESTS")
originalPrint(string.rep("=", 60))

-- Run TestEZ spec files
originalPrint("\n━━━ TestEZ Spec Files ━━━")
local results = TestEZ.TestBootstrap:run(testLocations, TestEZ.Reporters.TextReporter)

-- Run battle system unit tests
originalPrint("\n━━━ Battle System Unit Tests ━━━")
local BattleSystemTests = require(ServerScriptService.Tests.BattleSystem)
local battleSuccess = BattleSystemTests.runAll()

-- Run legacy integration tests
originalPrint("\n━━━ Legacy Integration Tests ━━━")
require(ServerScriptService.Tests.SpeedQueueTest)
require(ServerScriptService.Tests.RealTimeParryTest)

-- Summary
originalPrint("\n" .. string.rep("=", 60))
originalPrint(string.format(
	"TestEZ: %d passed, %d failed, %d total",
	results.successCount,
	results.failureCount,
	results.successCount + results.failureCount
))

if results.failureCount == 0 and battleSuccess then
	originalPrint("✅ ALL TESTS PASSED!")
else
	originalWarn("❌ SOME TESTS FAILED!")
end
originalPrint(string.rep("=", 60) .. "\n")

-- Restore print/warn and log level
print = originalPrint
warn = originalWarn
Logger.setGlobalLevel(originalLogLevel)

-- Exit with error if tests failed (useful for CI)
if results.failureCount > 0 then
	error("Tests failed!")
end
