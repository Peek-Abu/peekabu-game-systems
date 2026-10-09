--!strict
--[=[
	DeathRagdollUtils: which ragdoll limits a joint gets, and which joints are skipped. Pure; the
	Instance work is DeathServiceServer's.

	@class DeathRagdollUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local DeathTypes = require(ReplicatedStorage.Shared.Features.Death.Data.DeathTypes)

local DeathRagdollUtils = {}

function DeathRagdollUtils.limitsFor(jointName: string): DeathTypes.JointLimits
	return DeathConstants.JOINT_LIMITS[jointName] or DeathConstants.DEFAULT_LIMITS
end

function DeathRagdollUtils.isRootJoint(jointName: string): boolean
	return table.find(DeathConstants.ROOT_JOINT_NAMES, jointName) ~= nil
end

return DeathRagdollUtils
