--!strict
--[=[
	DeathKnockdownSystem: Death's non-lethal take-down. `knockdown(player, launch, seconds)` marks the player's
	character down (DeathConstants.KNOCKDOWN_ATTRIBUTE = the throw's velocity) and clears the mark `seconds` later.
	The owning client turns the mark into the pose (client DeathKnockdownSystem: PlatformStand and the throw, then
	GettingUp, like Cargo's slip), because a player's character is simulated by its own client; the server owns
	whether and for how long they are down, and gameplay asks it (`DeathKnockdownUtils.isDown`) before the vacuum or
	an interaction. The root is handed to the player's client first, so the throw it applies is the one that counts.

	Nothing can leave anyone down: the mark lives on the character (a reset or respawn drops it with the old one),
	each knockdown's timer clears only its own mark (a later knockdown is not cut short), and `standUp` /
	`standUpAll` clear it at once (a shift ending, the service stopping).

	Spec-exempt shell (character attributes, network ownership, task.delay); the decisions are the specced
	DeathKnockdownUtils.

	@class DeathKnockdownSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local DeathKnockdownUtils = require(ReplicatedStorage.Shared.Features.Death.Utils.DeathKnockdownUtils)

-- The latest knockdown per character. Weak keys: a character that is gone is forgotten.
local latest: { [Model]: number } = {}
setmetatable(latest, { __mode = "k" })
local issued = 0

local function clearMark(character: Model)
	latest[character] = nil
	if character.Parent ~= nil then
		character:SetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE, nil)
	end
end

local DeathKnockdownSystem = {}

--[=[
	Knocks `player` down: thrown with `launch` (studs/s), down for `seconds`, then up where they landed. Nothing
	for a player without a living character. Never yields.
]=]
function DeathKnockdownSystem.knockdown(player: Player, launch: Vector3, seconds: number)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") and not root.Anchored then
		-- The client simulates its own character; make sure it owns the body that takes the throw.
		pcall(function()
			root:SetNetworkOwner(player)
		end)
	end
	issued += 1
	local mine = issued
	latest[character] = mine
	character:SetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE, launch)
	task.delay(seconds, function()
		if DeathKnockdownUtils.standsUp(latest[character], mine) then
			clearMark(character)
		end
	end)
end

--[=[
	Stands `player` up now (nothing when they are not down).
]=]
function DeathKnockdownSystem.standUp(player: Player)
	local character = player.Character
	if character ~= nil and DeathKnockdownUtils.isDown(character) then
		clearMark(character)
	end
end

--[=[
	Stands everyone up now (a character no longer a player's took its mark with it).
]=]
function DeathKnockdownSystem.standUpAll()
	for _, player in Players:GetPlayers() do
		DeathKnockdownSystem.standUp(player)
	end
end

function DeathKnockdownSystem.isDown(player: Player): boolean
	return DeathKnockdownUtils.isDown(player.Character)
end

return DeathKnockdownSystem
