--!strict
--[=[
	TestRunner: Runs all tests in the project using TestEZ.
	
	Usage:
	1. Run this script in Studio to execute all tests
	2. Check Output window for test results
	
	@script TestRunner
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

print("\n" .. string.rep("=", 60))
print("🧪 Running Tests...")
print(string.rep("=", 60) .. "\n")

-- Define test locations
local testLocations = {
	ReplicatedStorage.Shared.Modules,
	ServerScriptService.Modules,
	ServerScriptService.Services,
}

-- Initialize game data so tests have items to reference
local GameItems = require(ReplicatedStorage.Shared.Modules.GameItems)
GameItems.init()

-- Run tests
local results = TestEZ.TestBootstrap:run(testLocations, TestEZ.Reporters.TextReporter)

print("\n" .. string.rep("=", 60))
if results.failureCount == 0 then
	print("✅ All tests passed!")
else
	print("❌ Some tests failed!")
end
print(string.rep("=", 60) .. "\n")

-- Print summary
print(string.format(
	"Tests: %d passed, %d failed, %d total",
	results.successCount,
	results.failureCount,
	results.successCount + results.failureCount
))

-- Exit with error code if tests failed (useful for CI)
if results.failureCount > 0 then
	error("Tests failed!")
end
