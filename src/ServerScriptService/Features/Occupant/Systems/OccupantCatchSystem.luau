--!strict
--[=[
	OccupantCatchSystem: the catch sequence (Cleanup Crew spec §4 "Catch"). `begin` turns Harlow to face the
	player (unless he sits or stands planted, already facing them), freezes them (their root anchored), points their camera at his face (OccupantEvents.CatchCam),
	kills the lights around him for everyone (OccupantEvents.LightsOut). After
	SNAP_SECONDS the player is released and killed with a launch (base Death: ragdoll + velocity), away from him
	and up; Carry drops their hands item and Cargo scatters their pockets as they die (M1), at the catch point
	(the Died handlers run before the launch velocity moves the body). Death's spectate and respawn delay give
	the ~8 s of watching, and `hooks.onCaught` does the rest (Shift's catch count, toasts). At the throw he says the
	line ("You're FIRED!", not during the scare), the caught player's public deadline (`caughtUntil`) is published
	for the roster and their private incident report (room, shift clock, what they dropped) is sent
	(OccupantEvents.CatchReport); `caught` counts the catch for Shift, toasts the crew and owes the player the Rehired
	notice, which `watchRehires` sends on their next character (`rehired`: the deadline cleared, the notice sent);
	`dropRehires` forgets what is owed when the shift ends. If the shift ended
	meanwhile (`hooks.stillOn`), the player is just released. He plays his grab clip at the start and his throw clip at
	the launch when they are uploaded (OccupantAssets).

	The freeze is the anchored root, not PlatformStand, and Death's ragdoll swaps Motor6Ds for ball sockets
	without PlatformStand either, so Cargo's client slip restore (PlatformStand = false after SLIP_SECONDS,
	skipped once Health is 0) cannot undo any part of the catch.

	Called from the NPC think (onAttack), so `begin` itself never yields: the wait is a task.delay.

	Spec-exempt shell (Instances, ByteNet, Death); the decisions are the specced OccupantCatchRules.

	@class OccupantCatchSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantEvents = require(ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents)
local OccupantAnimationUtils = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantAnimationUtils)
local OccupantFeedbackUtils = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantFeedbackUtils)
local OccupantCatchRules = require(ServerScriptService.Features.Occupant.Rules.OccupantCatchRules)
local Reach = require(ServerScriptService.Features.Occupant.Rules.OccupantReachRules)
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local Sense = require(ServerScriptService.Features.Occupant.Systems.OccupantSenseSystem)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

-- What the service knows about a would-be catch that the rig and the player do not say.
export type Attempt = {
	inGrace: boolean,
	resting: boolean,
	zone: OccupantTypes.Zone,
	-- A clear ray to them, or a hider he found (he knows where they are).
	inView: boolean,
	-- A hider he found at their spot (the brain's catch effect: a check, a cabinet he opened, a sit-in), not a chase grab.
	found: boolean,
}

export type Hooks = {
	-- Whether the catch may still finish (a shift is still running and Harlow is still there).
	stillOn: () -> boolean,
	onCaught: (player: Player) -> (),
}

-- How far in front of his face the caught player's camera sits.
local FACE_DISTANCE = 2.5

-- UserIds whose catch is running.
local catching: { [number]: boolean } = {}

local function registered(id: string): boolean
	return AnimationRegistry.get(id) ~= nil
end

-- Plays one of his catch clips on the rig, when it is uploaded (nothing while pending).
local function act(rig: OccupantRigSystem.Rig, id: string)
	local clip = OccupantAnimationUtils.action(id, registered)
	if clip ~= nil then
		AnimationServiceServer:playOnRig(rig.model, clip)
	end
end

-- The caught player's incident report, read before the kill drops what they carry.
local function reportFor(player: Player, position: Vector3): OccupantTypes.CatchReport
	local carried = CarryServiceServer:getCarried(player)
	local hands = if carried ~= nil then carried:GetAttribute(CarryConstants.KIND_ATTRIBUTE) else nil
	local pockets: { string } = {}
	for _, entry in CargoServiceServer:pocketsOf(player) do
		table.insert(pockets, entry.kind)
	end
	local room = OfficeServiceServer:whereIs(position)
	local endsAt = ShiftServiceServer:getShift().endsAt
	local now = Workspace:GetServerTimeNow()
	return {
		room = room or OccupantConstants.CATCH_ROOM_FALLBACK,
		clock = if endsAt ~= nil then math.max(0, endsAt - now) else 0,
		backAt = now + OccupantConstants.SPECTATE_SECONDS,
		dropped = OccupantFeedbackUtils.droppedNames(
			if type(hands) == "string" then hands else nil,
			pockets,
			CargoRegistry.get
		),
	}
end

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
		local report = reportFor(player, root.Position)
		local velocity = OccupantCatchRules.launch(
			rig.root.Position,
			root.Position,
			OccupantConstants.LAUNCH_SPEED,
			OccupantConstants.LAUNCH_UP
		)
		act(rig, "harlowThrow")
		DeathServiceServer:kill(victim, "caught", { launch = velocity })
		-- Figma 4a: the line comes with the throw, not the scare.
		OccupantRigSystem.say(rig, OccupantConstants.LINES.caught)
		StateSyncPublicPlayerStore.set(userId, { [OccupantConstants.PUBLIC_CAUGHT_UNTIL] = report.backAt })
		OccupantEvents.packets.CatchReport.sendTo(report, player)
		hooks.onCaught(player)
	end)

	local harlow = rig.root
	-- Seated at a desk or planted at a spot he already faces them (and must not turn off his chair).
	if not harlow.Anchored then
		harlow.CFrame = CFrame.lookAt(harlow.Position, Vector3.new(root.Position.X, harlow.Position.Y, root.Position.Z))
	end
	root.Anchored = true
	local face = rig.head.Position
	local eye = face + harlow.CFrame.LookVector * FACE_DISTANCE
	OccupantEvents.packets.CatchCam.sendTo(CFrame.lookAt(eye, face), player)
	OccupantEvents.packets.LightsOut.sendToAll(harlow.Position)
	act(rig, "harlowGrab")
	return true
end

--[=[
	Catches `player` if the server's re-check allows (OccupantCatchRules: alive, not already caught, not on the break,
	not in their grace or the truck's box, not hidden unseen, within reach and the grab volume, in view): drags them
	out of a hiding spot first (`evict`), then `begin`. True when the catch began. Never yields.
]=]
function OccupantCatchSystem.attempt(
	rig: OccupantRigSystem.Rig,
	player: Player,
	attempt: Attempt,
	hooks: Hooks
): (boolean, string?)
	local character = player.Character
	local found = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local root = if found ~= nil and found:IsA("BasePart") then found else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local ok, reason = OccupantCatchRules.canCatch({
		-- Horizontal reach plus a separate body-height and line-of-sight recheck.
		distance = if root ~= nil
			then Vector3.new(root.Position.X - rig.root.Position.X, 0, root.Position.Z - rig.root.Position.Z).Magnitude
			else math.huge,
		reachable = root ~= nil and humanoid ~= nil and Reach.canReach(
			rig.root.Position,
			root.Position,
			Sense.feetY(root, humanoid),
			rig.head.Position.Y + rig.head.Size.Y / 2,
			OccupantCatchRules.reach(attempt.found)
		),
		clear = attempt.inView,
		hidden = HideServiceServer:isHidden(player) and not HideServiceServer:seenEntering(player),
		position = if root ~= nil then root.Position else rig.root.Position,
		alive = humanoid ~= nil and humanoid.Health > 0 and not DeathServiceServer:isDead(player),
		catching = catching[player.UserId] == true,
		inGrace = attempt.inGrace,
		resting = attempt.resting,
		zone = attempt.zone,
		found = attempt.found,
	})
	if not ok then
		return false, reason
	end
	-- Dragged out of the spot he found them in, then caught.
	HideServiceServer:evict(player, "evicted")
	return OccupantCatchSystem.begin(rig, player, hooks), nil
end

--[=[
	Clears a player's public deadline without the Rehired notice (the shift ended before they respawned).
]=]
function OccupantCatchSystem.clearDeadline(userId: number)
	StateSyncPublicPlayerStore.clearField(userId, OccupantConstants.PUBLIC_CAUGHT_UNTIL)
end

--[=[
	A caught player's new character spawned: clears their public deadline and tells them they are back (the Rehired card).
]=]
function OccupantCatchSystem.rehired(player: Player)
	OccupantCatchSystem.clearDeadline(player.UserId)
	OccupantEvents.packets.Rehired.sendTo(true, player)
end

--[=[
	Forgets every running catch (the service stopping). Their delayed steps still release the players.
]=]
function OccupantCatchSystem.clear()
	table.clear(catching)
end

-- UserIds caught this life: their next character gets the Rehired notice.
local rehire: { [number]: boolean } = {}

--[=[
	A catch went through (the service's `onCaught` hook): Shift counts it, the crew is told, and the player is owed the
	Rehired notice on their next character.
]=]
function OccupantCatchSystem.caught(player: Player)
	rehire[player.UserId] = true
	ShiftServiceServer:noteCatch(player)
	ToastServiceServer:send("all", {
		text = OccupantFeedbackUtils.caughtText(player.DisplayName, OccupantConstants.SPECTATE_SECONDS),
		style = ShiftConstants.TOAST_STICKY,
		duration = 4,
	})
end

--[=[
	Sends the Rehired notice on each caught player's next character (a player who leaves is owed nothing). Returns the
	stopper.
]=]
function OccupantCatchSystem.watchRehires(): () -> ()
	local stopObserving = Observers.observeCharacter(function(player: Player, _character: Model)
		if rehire[player.UserId] then
			rehire[player.UserId] = nil
			OccupantCatchSystem.rehired(player)
		end
		return nil
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		rehire[player.UserId] = nil
	end)
	return function()
		stopObserving()
		leaving:Disconnect()
	end
end

--[=[
	The shift is over: no deadline left showing, no notice owed.
]=]
function OccupantCatchSystem.dropRehires()
	for userId in rehire do
		OccupantCatchSystem.clearDeadline(userId)
	end
	table.clear(rehire)
end

return OccupantCatchSystem
