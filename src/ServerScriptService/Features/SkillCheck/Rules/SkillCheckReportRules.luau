--!strict
--[=[
	SkillCheckReportRules: whether a client's ring report can be taken at all (the trust boundary). A report names a
	ring (a whole id, 1 to 2^32 - 1, as the packet carries it) and the icon's angle (finite; wrapped into [0, 360)).
	`window` says where the server's clock sits against a ring's arrival: too early, open (judged), or too late (a
	miss). Pure.

	@class SkillCheckReportRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillCheckTypes = require(ReplicatedStorage.Shared.Features.SkillCheck.Data.SkillCheckTypes)
local SkillCheckAngleFormulas = require(ReplicatedStorage.Shared.Features.SkillCheck.Utils.SkillCheckAngleFormulas)

export type Window = "early" | "open" | "late"

local MAX_ID = 2 ^ 32 - 1

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local SkillCheckReportRules = {}

--[=[
	The report from a packet's `id` and `angle` fields, or nil and why it was refused.
]=]
function SkillCheckReportRules.parse(id: unknown, angle: unknown): (SkillCheckTypes.Report?, string?)
	if type(id) ~= "number" or not finite(id) or id ~= math.floor(id) or id < 1 or id > MAX_ID then
		return nil, "bad ring id"
	end
	if type(angle) ~= "number" or not finite(angle) then
		return nil, "bad angle"
	end
	return { id = id, angle = SkillCheckAngleFormulas.normalize(angle) }, nil
end

--[=[
	Where `now` sits against a ring arriving at `arriveAt`: open from `early` seconds before to `late` seconds after (both
	edges included), "early" before that, "late" after it (and for a clock that is not a number).
]=]
function SkillCheckReportRules.window(now: number, arriveAt: number, early: number, late: number): Window
	if not finite(now) then
		return "late"
	end
	if now < arriveAt - early then
		return "early"
	end
	if now > arriveAt + late then
		return "late"
	end
	return "open"
end

return SkillCheckReportRules
