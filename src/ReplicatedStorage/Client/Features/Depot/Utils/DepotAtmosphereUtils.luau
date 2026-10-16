--!strict
--[=[
	DepotAtmosphereUtils: whether the local player is in the depot hub, and so lit by its evening preset
	(DepotAtmosphereConstants.EVENING, chosen by OfficeAtmosphereUtils.preset). A player
	is in the hub before the first shift sync, in the lobby, and whenever they are not on the shift's crew (in
	Studio one server plays both roles, so a crew can be on shift while others wait in the depot). The crew is lit
	by the office (OfficeAtmosphereUtils) from the transit (`starting`, behind the load screen) through the results. Pure.

	@class DepotAtmosphereUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

local DepotAtmosphereUtils = {}

function DepotAtmosphereUtils.inHub(snapshot: ShiftSnapshot?, userId: number): boolean
	return snapshot == nil or snapshot.phase == "lobby" or table.find(snapshot.crew, userId) == nil
end

return DepotAtmosphereUtils
