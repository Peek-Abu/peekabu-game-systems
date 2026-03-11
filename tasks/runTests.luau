-- Open Cloud CI entry point. Uploaded and executed against the built place by the
-- Open Cloud Luau Execution API (see scripts/python/upload_and_run_task.py).
--
-- This runs the full TestEZ suite. If any test fails, the script ERRORS, which marks
-- the Luau Execution task as FAILED, which makes the CI job fail. Mirrors the local
-- src/ServerScriptService/TestRunner.server.luau.
--
-- NOTE: this file is intentionally outside `src/` so it is NOT built into the place;
-- it is sent as the task script to run inside the uploaded place's DataModel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)
local GameItems = require(ReplicatedStorage.Shared.Modules.GameItems)

-- Seed item definitions so the inventory specs have items to reference.
GameItems.init()

-- Shared root list + orphan-spec guard (mirrors TestRunner.server.luau; see SpecRoots).
local SpecRoots = require(ServerScriptService.Modules.SpecRoots)
local testLocations = SpecRoots.get()
SpecRoots.assertAllSpecsCovered(testLocations)
SpecRoots.assertAllModulesSpecced(testLocations)

local results = TestEZ.TestBootstrap:run(testLocations, TestEZ.Reporters.TextReporter)

if results.failureCount > 0 then
	error(`CI tests failed: {results.failureCount} failure(s) out of {results.successCount + results.failureCount}`)
end

print(`All {results.successCount} tests passed`)
