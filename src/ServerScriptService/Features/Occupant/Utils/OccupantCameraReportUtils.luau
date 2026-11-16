--!strict
--[=[
	OccupantCameraReportUtils: a crew camera report as the server keeps it (split out of OccupantWatchSystem, which takes
	the reports in through OccupantEvents.CameraReport): `parseReport` checks it is finite, makes the look unit, squares
	the up to it and holds the FOV and aspect to a real screen (OccupantWatchRules.screen).

	Pure: nothing here yields or touches an Instance.

	@class OccupantCameraReportUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OccupantWatchRules = require(ServerScriptService.Features.Occupant.Rules.OccupantWatchRules)

type Report = OccupantWatchRules.Report

local OccupantCameraReportUtils = {}

local function finite(vector: Vector3): boolean
	return vector.X == vector.X
		and vector.Y == vector.Y
		and vector.Z == vector.Z
		and math.abs(vector.X) < math.huge
		and math.abs(vector.Y) < math.huge
		and math.abs(vector.Z) < math.huge
end

-- The camera report as it arrives (OccupantEvents.CameraReport).
export type ReportData = { position: Vector3, look: Vector3, up: Vector3, fov: number, aspect: number }

local function number(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

--[=[
	A camera report as the server keeps it (OccupantWatchRules.Report, less its time): its position, unit look, an up
	square to the look (world up when the sent one is broken or along the look) and its half-screen tangents
	(OccupantWatchRules.screen: the FOV and aspect held to a real screen). Nil when the position, look, FOV or aspect is
	not finite, or the look is (near) zero.
]=]
function OccupantCameraReportUtils.parseReport(data: ReportData): Report?
	local position, look, up = data.position, data.look, data.up
	if typeof(position) ~= "Vector3" or typeof(look) ~= "Vector3" then
		return nil
	end
	if not finite(position) or not finite(look) or look.Magnitude < 1e-3 then
		return nil
	end
	if not number(data.fov) or not number(data.aspect) then
		return nil
	end
	local unit = look.Unit
	local sent = if typeof(up) == "Vector3" and finite(up) then up else Vector3.yAxis
	local square = sent - unit * sent:Dot(unit)
	if square.Magnitude < 1e-3 then
		-- A broken up, or one along the look: square world up (or, looking straight up or down, world forward).
		local world = if math.abs(unit.Y) < 0.99 then Vector3.yAxis else Vector3.zAxis
		square = world - unit * world:Dot(unit)
	end
	local tanV, tanH = OccupantWatchRules.screen(data.fov, data.aspect)
	return { position = position, look = unit, up = square.Unit, tanV = tanV, tanH = tanH, receivedAt = 0 }
end

return OccupantCameraReportUtils
