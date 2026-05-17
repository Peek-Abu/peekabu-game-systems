--!strict
--[=[
	PhysicsServiceServer - Configures physics and collision groups for the game.

	Collision groups are set up in code (not Studio) so they are fully
	version-controlled and survive Rojo syncs.

	Groups:
	- "Players" — all player character parts. Players do not collide with each other.

	@class PhysicsServiceServer
]=]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("PhysicsServiceServer")

local PhysicsServiceServer = {}
PhysicsServiceServer.dependencies = {} :: { string }

local PLAYER_GROUP = "Players"

local function assignCharacter(character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(part, PLAYER_GROUP)
		end
	end
	character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(desc, PLAYER_GROUP)
		end
	end)
end

--[=[
	Sets up collision groups and connects PlayerAdded / CharacterAdded.
	@param self PhysicsServiceServer
]=]
function PhysicsServiceServer.init(_self: typeof(PhysicsServiceServer))
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)
	log:info(`Registered collision group "{PLAYER_GROUP}" (self-collision disabled)`)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(assignCharacter)
		if player.Character then
			assignCharacter(player.Character)
		end
	end)

	for _, player in Players:GetPlayers() do
		if player.Character then
			assignCharacter(player.Character)
		end
		player.CharacterAdded:Connect(assignCharacter)
	end
end

return PhysicsServiceServer