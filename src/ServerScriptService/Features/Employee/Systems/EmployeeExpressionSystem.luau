--!strict
--[=[
	EmployeeExpressionSystem: the server's per-player expression pass. Each tick it reads the Manager's mind and
	position (through `sources`) and each subject's busy flag, decides the face (EmployeeFaceRules) and writes it
	to the character's EmployeeFace attribute, which replicates; every client then shows it (EmployeeFaceSystem).
	Only employee characters (with an EmployeeName attribute) are touched; an unchanged face is not rewritten.

	Remembers, per UserId, when the player was last busy (for the Happy linger).

	@class EmployeeExpressionSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeFaceRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeFaceRules)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

export type Sources = {
	mind: () -> OccupantTypes.Mind?,
	managerPosition: () -> Vector3?,
	now: () -> number,
}

export type Subject = {
	userId: number,
	character: Model,
	-- Vacuuming, carrying, or holding pocketed cargo right now.
	busy: boolean,
}

export type EmployeeExpressionState = {
	tracked: number,
	faces: { [EmployeeRegistry.Face]: number },
}

export type EmployeeExpressionSystem = {
	tick: (subjects: { Subject }) -> (),
	forget: (userId: number) -> (),
	getState: () -> EmployeeExpressionState,
}

local EmployeeExpressionSystem = {}

function EmployeeExpressionSystem.new(sources: Sources): EmployeeExpressionSystem
	local lastBusyAt: { [number]: number } = {}
	local shown: { [number]: EmployeeRegistry.Face } = {}

	return {
		tick = function(subjects)
			local mind = sources.mind()
			local manager = sources.managerPosition()
			local now = sources.now()
			for _, subject in subjects do
				local character = subject.character
				if character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == nil then
					continue
				end
				if subject.busy then
					lastBusyAt[subject.userId] = now
				end
				local distance: number? = if manager ~= nil
					then (character:GetPivot().Position - manager).Magnitude
					else nil
				local threatened = mind ~= nil
					and EmployeeFaceRules.isThreatened(mind.mode, mind.target == subject.userId, distance)
				local face: EmployeeRegistry.Face =
					EmployeeFaceRules.decide(threatened, subject.busy, now, lastBusyAt[subject.userId])
				shown[subject.userId] = face
				if character:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE) ~= face then
					character:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, face)
				end
			end
		end,

		forget = function(userId)
			lastBusyAt[userId] = nil
			shown[userId] = nil
		end,

		getState = function()
			local faces: { [EmployeeRegistry.Face]: number } = { Happy = 0, Worried = 0, Content = 0 }
			local tracked = 0
			for _, face: EmployeeRegistry.Face in shown do
				faces[face] += 1
				tracked += 1
			end
			return { tracked = tracked, faces = faces }
		end,
	}
end

return EmployeeExpressionSystem
