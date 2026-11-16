--!strict
--[=[
	OfficeRebuildSystem: the layout side of rebuilding the office. `fitted` drops the desks and break tables that no
	longer fit where they stand (HIDE_FURNITURE_SCALE); `generateLayout` generates a map's layout from a seed (the
	School's or the Office's generator), trying the next seed up, GENERATE_RETRIES more times, when generation errors,
	then raising; `checkGenerated` asserts a generated layout is valid and playable (capacity, route, hide spots, walk);
	`teardown` destroys an old office a piece at a time, stepping the build's pace between pieces. Split out of
	OfficeServiceServer, whose rebuild calls it. Logs under OfficeServiceServer's tag, as before the split.

	@class OfficeRebuildSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeLayoutConstants = require(OfficeServer.Data.OfficeLayoutConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutRules = require(OfficeServer.Rules.OfficeLayoutRules)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeLayoutGenerationUtils = require(OfficeServer.Utils.OfficeLayoutGenerationUtils)
local SchoolLayoutGenerationUtils = require(ServerScriptService.Features.School.Utils.SchoolLayoutGenerationUtils)
local OfficeBuildPaceTracker = require(OfficeServer.State.OfficeBuildPaceTracker)

-- OfficeServiceServer's tag: these lines logged from it before the split.
local log = Logger.new("OfficeServiceServer")

local OfficeRebuildSystem = {}

-- Desks and break tables grew (HIDE_FURNITURE_SCALE): any that no longer fit where it stands is removed.
function OfficeRebuildSystem.fitted(layout: OfficeTypes.Layout): OfficeTypes.Layout
	local kept, dropped = OfficeLayoutUtils.dropUnfit(layout, OfficeLayoutRules)
	if dropped > 0 then
		log:info(`dropped {dropped} desk(s) and table(s) that no longer fit`)
	end
	return kept
end

-- Seeds tried after the shift's own when generation fails (each the next seed up), before the error is raised.
local GENERATE_RETRIES = 3

OfficeRebuildSystem.GENERATE_RETRIES = GENERATE_RETRIES

-- The layout of `map` generated from `seed`, or, when generation errors (every attempt invalid), from the next seed
-- up, up to GENERATE_RETRIES more times, so a shift still starts; then the last error is raised. Returns the seed used.
function OfficeRebuildSystem.generateLayout(seed: number, map: ShiftTypes.MapId): (OfficeTypes.Layout, number)
	local generate = if map == "school"
		then SchoolLayoutGenerationUtils.generate
		else OfficeLayoutGenerationUtils.generate
	local lastError = ""
	for retry = 0, GENERATE_RETRIES do
		local tried = seed + retry
		local ok, result = pcall(generate, OfficeLayoutConstants.LAYOUT, tried)
		if ok then
			return result, tried
		end
		lastError = tostring(result)
		log:warn(`{map} generation from seed {tried} failed: {lastError}`)
	end
	error(`{map} generation failed from seed {seed} to {seed + GENERATE_RETRIES}: {lastError}`, 0)
end

-- Raises when a generated `layout` is invalid or cannot be played (capacity, route, hide spots, walk).
function OfficeRebuildSystem.checkGenerated(layout: OfficeTypes.Layout)
	local ok, errors = OfficeLayoutRules.validate(layout)
	assert(ok, `generated office layout is invalid: {table.concat(errors, "; ")}`)
	local capacity, reason = OfficeLayoutRules.checkCapacity(layout)
	assert(capacity, reason or "generated layout capacity")
	local routeOk, routeReason = OfficeLayoutRules.checkRoute(layout)
	assert(routeOk, routeReason or "generated layout route")
	local hideOk, hideReason = OfficeLayoutRules.checkHideSpots(layout)
	assert(hideOk, hideReason or "generated layout hide spots")
	local walkOk, walkReason =
		OfficeLayoutRules.checkWalk(layout, OfficeConstants.WALK_SPEED * OfficeConstants.MAX_WALK_SECONDS)
	assert(walkOk, walkReason or "generated layout walk")
end

-- Destroys `instance` a piece at a time (each folder's children, then the folder), stepping the build's pace between
-- pieces: destroying a whole office in one call removes thousands of parts in one unyielding step.
local function teardown(instance: Instance)
	for _, child in instance:GetChildren() do
		if child:IsA("Folder") then
			teardown(child)
		else
			child:Destroy()
		end
		OfficeBuildPaceTracker.step()
	end
	instance:Destroy()
end

OfficeRebuildSystem.teardown = teardown

return OfficeRebuildSystem
