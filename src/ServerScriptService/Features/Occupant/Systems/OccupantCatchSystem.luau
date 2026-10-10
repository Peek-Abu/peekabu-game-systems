--!strict
--[=[
	OccupantCatchSystem: the catch sequence (Cleanup Crew spec §4 "Catch"). `begin` turns Harlow to face the
	player, freezes them (their root anchored), points their camera at his face (OccupantEvents.CatchCam),
	kills the lights around him for everyone (OccupantEvents.LightsOut) and has him say "You're FIRED!". After
	SNAP_SECONDS the player is released and killed with a launch (base Death: ragdoll + velocity), away from him
	and up; Carry drops their hands item and Cargo scatters their pockets as they die (M1), at the catch point
	(the Died handlers run before the launch velocity moves the body). Death's spectate and respawn delay give
	the ~8 s of watching, and `hooks.onCaught` does the rest (Shift's catch count, toasts). If the shift ended
	meanwhile (`hooks.stillOn`), the player is just released.

	The freeze is the anchored root, not PlatformStand, and Death's ragdoll swaps Motor6Ds for ball sockets
	without PlatformStand either, so Cargo's client slip restore (PlatformStand = false after SLIP_SECONDS,
	skipped once Health is 0) cannot undo any part of the catch.

	Called from the NPC think (onAttack), so `begin` itself never yields: the wait is a task.delay.

	Spec-exempt shell (Instances, ByteNet, Death); the decisions are the specced OccupantCatchRules.

	@class OccupantCatchSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantEvents = require(ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents)
local OccupantCatchRules = require(ServerScriptService.Features.Occupant.Rules.OccupantCatchRules)
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)

export type Hooks = {
	-- Whether the catch may still finish (a shift is still running and Harlow is still there).
	stillOn: () -> boolean,
	onCaught: (player: Player) -> (),
}

-- How far in front of his face the caught player's camera sits.
local FACE_DISTANCE = 2.5

-- UserIds whose catch is running.
local catching: { [number]: boolean } = {}

local OccupantCatchSystem = {}

function OccupantCatchSystem.isCatching(userId: number): boolean
	return catching[userId] == true
end

--[=[
	Starts catching `player`. False when they are already being caught or have no living character.
]=]
function OccupantCatchSystem.begin(rig: OccupantRigSystem.Rig, player: Player, hooks: Hooks): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local found = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if catching[player.UserId] or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	if found == nil or not found:IsA("BasePart") then
		return false
	end
	local root: BasePart = found
	local victim: Humanoid = humanoid
	local userId = player.UserId
	catching[userId] = true

	-- Scheduled first: whatever throws below, the player is still released.
	task.delay(OccupantConstants.SNAP_SECONDS, function()
		catching[userId] = nil
		if root.Parent ~= nil then
			root.Anchored = false
		end
		if not hooks.stillOn() or victim.Parent == nil or victim.Health <= 0 then
			return
		end
		local velocity = OccupantCatchRules.launch(
			rig.root.Position,
			root.Position,
			OccupantConstants.LAUNCH_SPEED,
			OccupantConstants.LAUNCH_UP
		)
		DeathServiceServer:kill(victim, "caught", { launch = velocity })
		hooks.onCaught(player)
	end)

	local harlow = rig.root
	harlow.CFrame = CFrame.lookAt(harlow.Position, Vector3.new(root.Position.X, harlow.Position.Y, root.Position.Z))
	root.Anchored = true
	local face = rig.head.Position
	local eye = face + harlow.CFrame.LookVector * FACE_DISTANCE
	OccupantEvents.packets.CatchCam.sendTo(CFrame.lookAt(eye, face), player)
	OccupantEvents.packets.LightsOut.sendToAll(harlow.Position)
	OccupantRigSystem.say(rig, OccupantConstants.LINES.caught)
	return true
end

--[=[
	Forgets every running catch (the service stopping). Their delayed steps still release the players.
]=]
function OccupantCatchSystem.clear()
	table.clear(catching)
end

return OccupantCatchSystem
