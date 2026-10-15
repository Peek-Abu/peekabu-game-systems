--!strict
--[=[
	OfficeAtmosphereUtils: which atmosphere the office has (Cleanup Crew spec §7 "The office at night"; "Tier up";
	"Overtime: lighting shifts dim red"). In the depot hub (no snapshot, the lobby, or a player off the running
	crew: DepotAtmosphereUtils) it is the depot's warm evening, so a shift's lighting never outlasts the shift; for
	the crew, from the arrival countdown through the results it is night; while running, each pressure tier darkens
	it a step, Harlow's break lifts it a little and overtime turns it dim red (and the lights red). The fluorescent
	hum plays whenever the crew is in a shift. Pure.

	@class OfficeAtmosphereUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotAtmosphereConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotAtmosphereConstants)
local DepotAtmosphereUtils = require(ReplicatedStorage.Client.Features.Depot.Utils.DepotAtmosphereUtils)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

local OfficeAtmosphereUtils = {}

function OfficeAtmosphereUtils.preset(snapshot: ShiftSnapshot?, userId: number): string
	if snapshot == nil or DepotAtmosphereUtils.inHub(snapshot, userId) then
		return DepotAtmosphereConstants.EVENING
	end
	if snapshot.phase ~= "running" then
		return OfficeAtmosphereConstants.NIGHT
	end
	if snapshot.stage == "overtime" then
		return OfficeAtmosphereConstants.OVERTIME
	end
	if snapshot.stage == "break" then
		return OfficeAtmosphereConstants.BREAK
	end
	if snapshot.tier >= 2 then
		return OfficeAtmosphereConstants.TIER2
	end
	if snapshot.tier >= 1 then
		return OfficeAtmosphereConstants.TIER1
	end
	return OfficeAtmosphereConstants.NIGHT
end

function OfficeAtmosphereUtils.overtime(snapshot: ShiftSnapshot?, userId: number): boolean
	return snapshot ~= nil
		and not DepotAtmosphereUtils.inHub(snapshot, userId)
		and snapshot.phase == "running"
		and snapshot.stage == "overtime"
end

function OfficeAtmosphereUtils.hum(snapshot: ShiftSnapshot?, userId: number): boolean
	return snapshot ~= nil and not DepotAtmosphereUtils.inHub(snapshot, userId)
end

return OfficeAtmosphereUtils
