--!strict
--[=[
	ToonExpressionSystem: the server's per-player expression pass. Each tick it reads the Manager's mind and
	position (through `sources`) and each subject's busy flag, decides the face (ToonFaceRules) and writes it
	to the character's ToonFace attribute, which replicates; every client then shows it (ToonFaceSystem).
	Only toon characters (with a ToonName attribute) are touched; an unchanged face is not rewritten.

	Remembers, per UserId, when the player was last busy (for the Happy linger).

	@class ToonExpressionSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonFaceRules = require(ReplicatedStorage.Shared.Features.Toon.Rules.ToonFaceRules)
local ToonRegistry = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonRegistry)

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

export type ToonExpressionState = {
	tracked: number,
	faces: { [ToonRegistry.Face]: number },
}

export type ToonExpressionSystem = {
	tick: (subjects: { Subject }) -> (),
	forget: (userId: number) -> (),
	getState: () -> ToonExpressionState,
}

local ToonExpressionSystem = {}

function ToonExpressionSystem.new(sources: Sources): ToonExpressionSystem
	local lastBusyAt: { [number]: number } = {}
	local shown: { [number]: ToonRegistry.Face } = {}

	return {
		tick = function(subjects)
			local mind = sources.mind()
			local manager = sources.managerPosition()
			local now = sources.now()
			for _, subject in subjects do
				local character = subject.character
				if character:GetAttribute(ToonConstants.NAME_ATTRIBUTE) == nil then
					continue
				end
				if subject.busy then
					lastBusyAt[subject.userId] = now
				end
				local distance: number? = if manager ~= nil
					then (character:GetPivot().Position - manager).Magnitude
					else nil
				local threatened = mind ~= nil
					and ToonFaceRules.isThreatened(mind.mode, mind.target == subject.userId, distance)
				local face: ToonRegistry.Face =
					ToonFaceRules.decide(threatened, subject.busy, now, lastBusyAt[subject.userId])
				shown[subject.userId] = face
				if character:GetAttribute(ToonConstants.FACE_ATTRIBUTE) ~= face then
					character:SetAttribute(ToonConstants.FACE_ATTRIBUTE, face)
				end
			end
		end,

		forget = function(userId)
			lastBusyAt[userId] = nil
			shown[userId] = nil
		end,

		getState = function()
			local faces: { [ToonRegistry.Face]: number } = { Happy = 0, Worried = 0, Content = 0 }
			local tracked = 0
			for _, face: ToonRegistry.Face in shown do
				faces[face] += 1
				tracked += 1
			end
			return { tracked = tracked, faces = faces }
		end,
	}
end

return ToonExpressionSystem
