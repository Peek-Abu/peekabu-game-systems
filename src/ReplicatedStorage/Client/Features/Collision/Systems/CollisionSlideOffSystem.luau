--!strict
--[=[
	CollisionSlideOffSystem (R6 spec 2026-10-08 §5 step 2): heads aren't standable.

	The Humanoid never treats a blocker as floor (the blocker groups don't collide with the rig's own
	parts) and blockers are frictionless, so without a push a dead-centre landing would sit on a head. While
	my feet rest on a SOLID puppet's head top, my outward horizontal speed is raised to SLIDE_OFF_SPEED (the
	CP7 spike's rule). Only the solid set is checked, which is typically 0–5 puppets. One push per frame.

	@class CollisionSlideOffSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionShapeUtils = require(ReplicatedStorage.Shared.Features.Collision.Utils.CollisionShapeUtils)
local CollisionBlockerSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionBlockerSystem)

local CollisionSlideOffSystem = {}

--[=[
	Pushes `root` off the first solid puppet whose head its feet rest on.
	@param blockers CollisionBlockerSystem.State
	@param root BasePart -- the local rig's root
	@return boolean -- true when resting on a head this frame
]=]
function CollisionSlideOffSystem.step(blockers: CollisionBlockerSystem.State, root: BasePart): boolean
	local here = root.Position
	local velocity = root.AssemblyLinearVelocity
	for _, capsule in blockers.solid do
		local theirs = capsule.root.Position
		if CollisionShapeUtils.restingOn(here, velocity.Y, theirs) then
			local direction = CollisionShapeUtils.pushDirection(here, theirs, root.CFrame.LookVector)
			local pushed = CollisionShapeUtils.slideOffVelocity(velocity, direction)
			if pushed ~= nil then
				root.AssemblyLinearVelocity = pushed
			end
			return true
		end
	end
	return false
end

return CollisionSlideOffSystem
