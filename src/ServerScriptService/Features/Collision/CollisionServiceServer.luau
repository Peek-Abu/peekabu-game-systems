--!strict
--[=[
	CollisionServiceServer (R6 spec 2026-10-08 §5): registers the two player-collision groups at init.

	`CollisionPuppetBlocker` (other players' capsules) and `CollisionSelfCollider` (your own capsule)
	collide ONLY with each other: each is set non-collidable with every registered group (Default, any
	group the place's art registers, and themselves), then the pair is set collidable. Blockers never touch
	the map, and your world movement is unchanged. Groups registered on the server replicate to clients.

	A group registered by code after start must set itself non-collidable with these two. None exists.

	Spec-exempt shell (PhysicsService); the capsules themselves are built client-side by CollisionBlockerSystem.

	@class CollisionServiceServer
]=]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)

local log = Logger.new("CollisionServiceServer")
local registered = false

local function registerGroups()
	local pair = { CollisionConstants.PUPPET_GROUP, CollisionConstants.SELF_GROUP }
	for _, name in pair do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		local name = group.name
		if type(name) == "string" then
			for _, ours in pair do
				PhysicsService:CollisionGroupSetCollidable(ours, name, false)
			end
		end
	end
	PhysicsService:CollisionGroupSetCollidable(CollisionConstants.PUPPET_GROUP, CollisionConstants.SELF_GROUP, true)
	registered = true
end

export type CollisionServiceServer = {
	dependencies: { string },
	init: (self: CollisionServiceServer) -> (),
	start: (self: CollisionServiceServer) -> (),
	stop: (self: CollisionServiceServer) -> (),
	getState: (self: CollisionServiceServer) -> { registered: boolean, groups: number },
}

local CollisionServiceServer: CollisionServiceServer = {
	dependencies = {},

	init = function(_self)
		log:debug("CollisionServiceServer initialized")
		registerGroups()
	end,

	start = function(_self)
		-- Groups are registered in init so they exist before any client can build a capsule.
	end,

	stop = function(_self)
		-- Registered groups belong to the place for the server's life; nothing to undo.
	end,

	getState = function(_self)
		return { registered = registered, groups = #PhysicsService:GetRegisteredCollisionGroups() }
	end,
}

return CollisionServiceServer
