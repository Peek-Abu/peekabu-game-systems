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

--[=[
	Every unordered pair of `items`, each once. A ragdoll's body parts get one NoCollisionConstraint per
	pair: a rig's limbs overlap at the joints (and a toon rig's limbs overlap its torso), and a ball socket,
	unlike the Motor6D it replaces, does not stop its two parts colliding, so overlapping limbs that are
	made collidable push each other apart forever against the sockets.
]=]
function DeathRagdollUtils.selfCollisionPairs<T>(items: { T }): { { T } }
	local result: { { T } } = {}
	for i = 1, #items - 1 do
		for j = i + 1, #items do
			table.insert(result, { items[i], items[j] })
		end
	end
	return result
end

return DeathRagdollUtils
