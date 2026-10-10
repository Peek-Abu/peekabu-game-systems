--!strict
--[=[
	OfficeAtmosphereUtils: which atmosphere the office has (Cleanup Crew spec §7 "The office at night"; "Tier up";
	"Overtime: lighting shifts dim red"). Outside a shift (no snapshot, or the lobby) the place keeps its own
	lighting; from the arrival countdown through the results it is night; while running, each pressure tier darkens
	it a step, Harlow's break lifts it a little and overtime turns it dim red (and the lights red). The fluorescent
	hum plays whenever the office is in a shift. Pure.

	@class OfficeAtmosphereUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

local OfficeAtmosphereUtils = {}

function OfficeAtmosphereUtils.preset(snapshot: ShiftSnapshot?): string?
	if snapshot == nil or snapshot.phase == "lobby" then
		return nil
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

function OfficeAtmosphereUtils.overtime(snapshot: ShiftSnapshot?): boolean
	return snapshot ~= nil and snapshot.phase == "running" and snapshot.stage == "overtime"
end

function OfficeAtmosphereUtils.hum(snapshot: ShiftSnapshot?): boolean
	return snapshot ~= nil and snapshot.phase ~= "lobby"
end

return OfficeAtmosphereUtils
