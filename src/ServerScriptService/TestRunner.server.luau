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
local RunService = game:GetService("RunService")

-- This is a `.server` Script, so it runs automatically on server start. Only run the
-- suite in Studio — a live server should not execute tests (or ship/run specs) on
-- startup. The CI cloud entry point is tasks/runTests.luau.
if not RunService:IsStudio() then
	return
end

-- OPT-IN ONLY: several specs (e.g. StateSyncServiceServer.spec) exercise init/stop on REAL
-- module singletons — running them inside a live Play session destroys production state
-- (found 2026-07-17: the spec suite tore down and recreated the charm-sync transport
-- mid-session, permanently severing the live client's sync — the client State tab never
-- received another patch). To run the suite: select Workspace in Studio, add a boolean
-- attribute `RunTests`, set it true, then hit Play. Leave it unset for normal play sessions.
if workspace:GetAttribute("RunTests") ~= true then
	return
end

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

print("\n" .. string.rep("=", 60))
print("🧪 Running Tests...")
print(string.rep("=", 60) .. "\n")

-- Test locations come from one shared module; the guard makes a spec outside them a
-- loud failure instead of a silently-skipped file (TestEZ does not scan recursively).
local SpecRoots = require(ServerScriptService.Core.Testing.SpecRoots)
local testLocations = SpecRoots.get()
SpecRoots.assertAllSpecsCovered(testLocations)
SpecRoots.assertAllModulesSpecced(testLocations)

-- Initialize game data so tests have items to reference
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
ItemContentRegistry.init()

-- Run tests: one TestEZ plan per spec module, with a yield between modules. The whole suite as a single plan runs on
-- one thread, so a stretch of specs that never yield adds up past Play's script timeout (10 s on the Play server,
-- whatever the Studio setting says; found 2026-11-13: no spec blocks more than 2 s, yet the run died 10.0 s after
-- its last log line). A module's own tree is printed only when it fails; the totals are the sum of every plan.
local specModules: { ModuleScript } = {}
local function collect(root: Instance)
	for _, child in root:GetChildren() do
		if child:IsA("ModuleScript") and string.match(child.Name, "%.spec$") ~= nil then
			table.insert(specModules, child)
		end
		collect(child)
	end
end
for _, location in testLocations do
	collect(location)
end

local results = { successCount = 0, failureCount = 0, skippedCount = 0 }
local quiet = {
	report = function(_planResults) end,
}
local failedModules: { string } = {}
for _, module in specModules do
	local ok, moduleResults = pcall(TestEZ.TestBootstrap.run, TestEZ.TestBootstrap, { module }, quiet)
	if not ok then
		-- A spec that fails to load (or a plan that errors) is a failure, never a silent skip.
		results.failureCount += 1
		table.insert(failedModules, module:GetFullName())
		warn(`--- {module:GetFullName()} failed to run: {moduleResults}`)
	else
		results.successCount += moduleResults.successCount
		results.failureCount += moduleResults.failureCount
		results.skippedCount += moduleResults.skippedCount
		if moduleResults.failureCount > 0 then
			table.insert(failedModules, module:GetFullName())
			print(`\n--- {module:GetFullName()} ---`)
			TestEZ.Reporters.TextReporter.report(moduleResults)
		end
	end
	task.wait()
end
if #failedModules > 0 then
	print(`\nFailing spec modules ({#failedModules}):\n  ` .. table.concat(failedModules, "\n  "))
end

print("\n" .. string.rep("=", 60))
if results.failureCount == 0 then
	print("✅ All tests passed!")
else
	print("❌ Some tests failed!")
end
print(string.rep("=", 60) .. "\n")

-- Print summary
print(
	string.format(
		"Tests: %d passed, %d failed, %d total",
		results.successCount,
		results.failureCount,
		results.successCount + results.failureCount
	)
)

-- Exit with error code if tests failed (useful for CI)
if results.failureCount > 0 then
	error("Tests failed!")
end
