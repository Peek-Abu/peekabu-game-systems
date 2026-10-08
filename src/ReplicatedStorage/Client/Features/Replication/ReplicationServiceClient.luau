--!strict
--[=[
	ReplicationServiceClient: this client's side of client-only bodies (spec 2026-09-22 §5.1 option A,
	§6; plan R2 Tasks 10–11).

	Owner half: on `Spawn` it builds the owner rig (ReplicationOwnerRigSystem) from `ReplicatedStorage.CharacterRigTemplate` and
	makes it `LocalPlayer.Character`; every Heartbeat it offers the rig's state to ReplicationUplinkSender and sends the
	packets it returns.

	Viewer half: the slot table, enter/leave and downlink batches feed ReplicationRemoteBodyTracker; every PreRender it gives
	each visible body a pooled puppet (ReplicationPuppetPool) and moves all puppets with ONE `Workspace:BulkMoveTo`.

	Animation (R3): ReplicationRigAnimationSystem plays server-granted actions on the owner rig and the puppets; this shell
	tells it about slot rows, bodies leaving, puppets acquired / released and the owner rig, and runs its
	frame in the same PreRender pass, right after placement.

	Appearance (R4): CustomizationOutfitSystem dresses the owner rig on build (before `bodySpawned`) and every puppet
	from the public slice. Each PreRender runs its budgeted step BEFORE placement, and a puppet that is
	not dressed yet stays parked with the hidden ones, so nobody is ever seen undressed (the dressed rule).

	The handshake (`Ready`) goes once every listener is connected.

	Body API (docs/architecture.md, "Bodies"): `bodySpawned` / `bodyDespawned` (player, rig) fire for every rig
	this client shows — the owner rig and each puppet; `getRig(player)`, `getPlayerFromRig(rig)`,
	`getLocalRig()`. Find a body's player by id through this registry, never by instance name.
	The registry lives in ReplicationRigTracker, which also sets each remote player's `Character` to their puppet (R5)
	so the engine draws its speaking icon; nothing reads it.

	Spec-exempt shell (network, Instances, RunService); its cores (ReplicationUplinkSender, ReplicationRemoteBodyTracker) are specced.

	@class ReplicationServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CustomizationClient = ReplicatedStorage.Client.Features.Customization
local ReplicationClient = ReplicatedStorage.Client.Features.Replication
local ReplicationShared = ReplicatedStorage.Shared.Features.Replication
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local ReplicationEvents = require(ReplicationShared.Net.ReplicationEvents)
local ReplicationRecordCodec = require(ReplicationShared.Net.ReplicationRecordCodec)
local ReplicationRenderClockSystem = require(ReplicationShared.Systems.ReplicationRenderClockSystem)
local ReplicationOwnerRigSystem = require(ReplicationClient.Systems.ReplicationOwnerRigSystem)
local ReplicationRigTracker = require(ReplicationClient.State.ReplicationRigTracker)
local ReplicationDiagnosticsSystem = require(ReplicationClient.Systems.ReplicationDiagnosticsSystem)
local ReplicationUplinkSender = require(ReplicationClient.Net.ReplicationUplinkSender)
local ReplicationRemoteBodyTracker = require(ReplicationClient.State.ReplicationRemoteBodyTracker)
local ReplicationPuppetPool = require(ReplicationClient.State.ReplicationPuppetPool)
local ReplicationRigAnimationSystem = require(ReplicationClient.Systems.ReplicationRigAnimationSystem)
local CustomizationOutfitSystem = require(CustomizationClient.Systems.CustomizationOutfitSystem)
local CustomizationDressSystem = require(CustomizationClient.Systems.CustomizationDressSystem)
local CustomizationRigOutfitTracker = require(CustomizationClient.State.CustomizationRigOutfitTracker)

local TEMPLATE_NAME = "CharacterRigTemplate"
local TEMPLATE_WAIT_SECONDS = 30
local PUPPET_FOLDER_NAME = "CharacterPuppets"
local GROUND_RAY_DEPTH = 50
local RESPAWN_RETRY_SECONDS = 1

type HeldPuppet = ReplicationDiagnosticsSystem.HeldPuppet

local log = Logger.new("ReplicationServiceClient")
local janitor = Janitor.new()

local template: Model? = nil
local sessionEpochSeconds: number? = nil
local ownerRig: ReplicationOwnerRigSystem.Rig? = nil
local buildSeq = 0
-- Set while the owner rig is gone (fell) and no newer Spawn has arrived: when the next RespawnRequest is due.
local respawnRetryAt: number? = nil
local sender = ReplicationUplinkSender.new()
local remote: ReplicationRemoteBodyTracker.State? = nil
local pool: ReplicationPuppetPool.Pool? = nil
local puppetFolder: Folder? = nil
-- Built in init: the parked-piece folder must exist before the first rig is dressed.
local outfits: CustomizationOutfitSystem.State? = nil
local held: { [number]: HeldPuppet } = {} -- by slot
local diagnostics: ReplicationDiagnosticsSystem.Watcher? = nil
-- Frames a visible body went without a puppet, by reason (F4): no Player for its userId / the pool had none /
-- its puppet was not dressed yet (parked by the dressed rule).
local unheld = { noPlayer = 0, poolEmpty = 0, undressed = 0 }
local placementSlots: { number } = {}
local placementCFrames: { CFrame } = {}
local placedSlots: { [number]: boolean } = {}
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local standingRootHeight = 0

-- The player ↔ rig registry and the body signals; also the one writer of remote players' `Character` (R5).
local registry = ReplicationRigTracker.new(Players.LocalPlayer.UserId)

local function sessionNowMs(): number?
	local epochSeconds = sessionEpochSeconds
	if epochSeconds == nil then
		return nil
	end
	return (Workspace:GetServerTimeNow() - epochSeconds) * 1000
end

local function refreshGroundFilter()
	local exclude: { Instance } = {}
	local folder = puppetFolder
	if folder ~= nil then
		table.insert(exclude, folder)
	end
	local rig = ownerRig
	if rig ~= nil then
		table.insert(exclude, rig.model)
	end
	groundParams.FilterDescendantsInstances = exclude
end

local function adoptTemplate(found: Model)
	template = found
	local folder = Instance.new("Folder")
	folder.Name = PUPPET_FOLDER_NAME
	folder.Parent = Workspace
	puppetFolder = folder
	janitor:Add(folder, "Destroy")
	pool = ReplicationPuppetPool.new(found, folder)
	local humanoid = found:FindFirstChildOfClass("Humanoid")
	local root = found:FindFirstChild("HumanoidRootPart")
	if humanoid ~= nil and humanoid:IsA("Humanoid") and root ~= nil and root:IsA("BasePart") then
		-- The root's height above the floor when standing: what dead reckoning holds a body at.
		standingRootHeight = humanoid.HipHeight + root.Size.Y / 2
	end
	refreshGroundFilter()
end

local function awaitTemplate(): Model?
	if template == nil then
		local found = ReplicatedStorage:WaitForChild(TEMPLATE_NAME, TEMPLATE_WAIT_SECONDS)
		-- Re-check after the wait: init's warm-up and a Spawn can both be waiting here.
		if template == nil and found ~= nil and found:IsA("Model") then
			adoptTemplate(found)
		end
	end
	return template
end

local function groundBelow(position: Vector3): number
	local hit = Workspace:Raycast(position, Vector3.new(0, -GROUND_RAY_DEPTH, 0), groundParams)
	return if hit ~= nil then hit.Position.Y + standingRootHeight else -math.huge
end

-- `fell`: the rig dropped out of the world, so the engine is already destroying its parts and none of
-- its pieces can be salvaged into the pool.
local function dropOwnerRig(fell: boolean?)
	local rig = ownerRig
	if rig == nil then
		return
	end
	ownerRig = nil
	ReplicationRigAnimationSystem.detachOwner()
	ReplicationRigTracker.unregister(registry, Players.LocalPlayer, rig.model)
	local state = outfits
	if state ~= nil then
		CustomizationOutfitSystem.detachOwner(state, fell ~= true)
	end
	ReplicationOwnerRigSystem.destroy(rig)
end

local function buildOwnerRig(position: Vector3, epoch: number)
	buildSeq += 1
	local mine = buildSeq
	local rigTemplate = awaitTemplate()
	if mine ~= buildSeq then
		return -- a newer Spawn arrived while waiting for the template
	end
	if rigTemplate == nil then
		log:error(`{TEMPLATE_NAME} never replicated; no body`)
		return
	end
	dropOwnerRig()
	local rig, err = ReplicationOwnerRigSystem.build(rigTemplate, position, epoch, function()
		-- The root fell and is gone: drop the dead rig, and keep asking until a Spawn arrives (the server
		-- may refuse a request: rate limit, epoch spacing, or a stale last position).
		dropOwnerRig(true)
		respawnRetryAt = os.clock() + RESPAWN_RETRY_SECONDS
		ReplicationEvents.packets.RespawnRequest.send(true)
	end)
	if rig == nil then
		log:error(`owner rig build failed: {err or "unknown"}`)
		return
	end
	ownerRig = rig
	respawnRetryAt = nil
	ReplicationUplinkSender.reset(sender)
	local state = outfits
	if state ~= nil then
		CustomizationOutfitSystem.attachOwner(state, rig.model, Players.LocalPlayer.UserId)
	end
	ReplicationRigTracker.register(registry, Players.LocalPlayer, rig.model)
	ReplicationRigAnimationSystem.attachOwner(rig.model, epoch)
	refreshGroundFilter()
	log:info(`owner rig built (epoch {epoch})`)
end

local function sampleOwner()
	local retryAt = respawnRetryAt
	if retryAt ~= nil and os.clock() >= retryAt then
		respawnRetryAt = retryAt + RESPAWN_RETRY_SECONDS
		ReplicationEvents.packets.RespawnRequest.send(true)
	end
	local rig = ownerRig
	local nowMs = sessionNowMs()
	if rig == nil or nowMs == nil or rig.root.Parent == nil then
		return
	end
	local cframe = rig.root.CFrame
	local look = cframe.LookVector
	local state = rig.humanoid:GetState()
	local record: ReplicationRecordCodec.Record = {
		slot = 0, -- the server addresses bodies by the sender, not by these fields
		generation = 0,
		epoch = rig.epoch,
		ageMs = 0,
		position = cframe.Position,
		yaw = math.atan2(-look.X, -look.Z),
		pitch = 0,
		velocity = rig.root.AssemblyLinearVelocity,
		state = state.Value % 32,
		grounded = ReplicationUplinkSender.isGrounded(state, rig.humanoid.FloorMaterial),
		hasAction = false,
		rotation = nil,
	}
	local packet = ReplicationUplinkSender.step(sender, math.floor(nowMs), record)
	if packet ~= nil then
		ReplicationEvents.packets.Uplink.send(packet)
	end
end

local function releasePuppet(slot: number)
	local entry = held[slot]
	if entry == nil then
		return
	end
	held[slot] = nil
	ReplicationRigAnimationSystem.detachPuppet(entry.player.UserId)
	ReplicationRigTracker.unregister(registry, entry.player, entry.puppet.model)
	local state = outfits
	if state ~= nil then
		CustomizationOutfitSystem.detachPuppet(state, entry.puppet.outfit)
	end
	local activePool = pool
	if activePool ~= nil then
		ReplicationPuppetPool.release(activePool, entry.puppet)
	end
end

local function renderPuppets()
	local state = remote
	local activePool = pool
	local dressing = outfits
	local nowMs = sessionNowMs()
	if state == nil or activePool == nil or dressing == nil or nowMs == nil then
		return
	end
	ReplicationPuppetPool.beginFrame(activePool)
	for slot, body in state.bodies do
		if body.visible and held[slot] == nil then
			local player = Players:GetPlayerByUserId(body.userId)
			if player ~= nil then
				local puppet = ReplicationPuppetPool.acquire(activePool, player)
				if puppet ~= nil then
					held[slot] = { puppet = puppet, player = player }
					ReplicationRigTracker.register(registry, player, puppet.model)
					ReplicationRigAnimationSystem.attachPuppet(body.userId, slot, body.epoch, puppet)
					CustomizationOutfitSystem.attachPuppet(dressing, puppet.outfit, body.userId)
				else
					unheld.poolEmpty += 1
				end
			else
				unheld.noPlayer += 1
			end
		end
	end
	CustomizationOutfitSystem.frame(dressing)
	local count = ReplicationRemoteBodyTracker.frame(state, nowMs, placementSlots, placementCFrames, groundBelow)
	table.clear(moveParts)
	table.clear(moveCFrames)
	table.clear(placedSlots)
	for i = 1, count do
		local slot = placementSlots[i]
		local entry = held[slot]
		if entry ~= nil and not CustomizationRigOutfitTracker.isDressed(entry.puppet.outfit) then
			unheld.undressed += 1 -- parked below with the hidden ones until its dress lands
		elseif entry ~= nil then
			placedSlots[slot] = true
			table.insert(moveParts, entry.puppet.root)
			table.insert(moveCFrames, placementCFrames[i])
		end
	end
	-- A held puppet with nothing to show (its buffer reset on a respawn, until the first new-epoch sample)
	-- is hidden, not left frozen at its last place; the next sample places it again.
	for slot, entry in held do
		if not placedSlots[slot] then
			table.insert(moveParts, entry.puppet.root)
			table.insert(moveCFrames, ReplicationPuppetPool.HIDDEN_CFRAME)
		end
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	ReplicationRigAnimationSystem.frame(state.bodies, placedSlots)
end

export type ReplicationServiceClient = {
	dependencies: { string },
	init: (self: ReplicationServiceClient) -> (),
	stop: (self: ReplicationServiceClient) -> (),
	bodySpawned: SignalTyped.Signal<Player, Model>,
	bodyDespawned: SignalTyped.Signal<Player, Model>,
	getRig: (self: ReplicationServiceClient, player: Player) -> Model?,
	getPlayerFromRig: (self: ReplicationServiceClient, rig: Model) -> Player?,
	getLocalRig: (self: ReplicationServiceClient) -> Model?,
	getState: (self: ReplicationServiceClient) -> { [string]: any },
}

local ReplicationServiceClient: ReplicationServiceClient = {
	dependencies = {},
	bodySpawned = registry.spawned,
	bodyDespawned = registry.despawned,

	init = function(_self)
		local state = ReplicationRemoteBodyTracker.new(Players.LocalPlayer.UserId)
		remote = state
		local actionCount = #AnimationRegistry.ids()
		local packets = ReplicationEvents.packets

		local dressing, unmountDressing = CustomizationOutfitSystem.mount()
		outfits = dressing

		packets.Session.listen(function(data)
			sessionEpochSeconds = data.epochSeconds
		end)
		packets.Spawn.listen(function(data)
			task.spawn(buildOwnerRig, data.position, data.epoch)
		end)
		packets.SlotEntry.listen(function(entry)
			-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
			local change: ReplicationRemoteBodyTracker.SlotChange?, previous =
				ReplicationRemoteBodyTracker.applySlot(state, entry)
			if change == "replaced" or change == "released" then
				releasePuppet(entry.slot)
			end
			ReplicationRigAnimationSystem.slotEntry(entry, change, previous)
		end)
		packets.Enter.listen(function(data)
			ReplicationRemoteBodyTracker.enter(state, data.slot, data.generation, data.batchTimeMs, data.record)
		end)
		packets.Leave.listen(function(data)
			local body = ReplicationRemoteBodyTracker.leave(state, data.slot, data.generation)
			if body ~= nil then
				releasePuppet(data.slot)
				ReplicationRigAnimationSystem.bodyLeft(body.userId)
			end
		end)
		packets.Downlink.listen(function(batch)
			local nowMs = sessionNowMs()
			if nowMs ~= nil then
				ReplicationRemoteBodyTracker.onBatch(state, batch, nowMs, actionCount)
			end
		end)

		ReplicationRigAnimationSystem.start(sessionNowMs, function(): number
			return state.delayMs
		end)
		janitor:Add(ReplicationRigAnimationSystem.stop, true)
		janitor:Add(RunService.Heartbeat:Connect(sampleOwner), "Disconnect")
		janitor:Add(RunService.PreRender:Connect(renderPuppets), "Disconnect")
		janitor:Add(dropOwnerRig, true)
		janitor:Add(function()
			for slot in held do
				releasePuppet(slot)
			end
			local activePool = pool
			if activePool ~= nil then
				ReplicationPuppetPool.destroy(activePool)
			end
			outfits = nil
			unmountDressing()
		end, true)
		task.spawn(awaitTemplate) -- the pool and the puppet folder are ready before the first body
		-- R5 tripwire: runs only while Workspace `Diagnostics` is true.
		local watcher = ReplicationDiagnosticsSystem.watch(function(): ReplicationDiagnosticsSystem.View?
			return ReplicationDiagnosticsSystem.view(state, held, placedSlots, registry)
		end, log)
		diagnostics = watcher
		janitor:Add(function()
			ReplicationDiagnosticsSystem.stop(watcher)
			diagnostics = nil
		end, true)
		-- Every listener is connected: ask for the session, the slot table and a body.
		packets.Ready.send(true)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,

	getRig = function(_self, player)
		return ReplicationRigTracker.rigFor(registry, player.UserId)
	end,

	getPlayerFromRig = function(_self, rig)
		local userId = ReplicationRigTracker.userIdFor(registry, rig)
		return if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	end,

	getLocalRig = function(_self)
		local rig = ownerRig
		return if rig ~= nil then rig.model else nil
	end,

	--[=[
		This client's replication view, for the F4 Services tab (client context).
	]=]
	getState = function(_self)
		local state = remote
		local activePool = pool
		local rig = ownerRig
		local puppets = 0
		local heldBySlot: { [string]: string } = {}
		for slot, entry in held do
			puppets += 1
			heldBySlot[tostring(slot)] = entry.puppet.model.Name
		end
		local current = state or ReplicationRemoteBodyTracker.new(0) -- before init: an empty view
		local known, visible = ReplicationRemoteBodyTracker.counts(current)
		return {
			hasSession = sessionEpochSeconds ~= nil,
			ownerEpoch = if rig ~= nil then rig.epoch else nil,
			uplinkPackets = sender.sent,
			knownBodies = known,
			visibleBodies = visible,
			puppets = puppets,
			pooledPuppets = if activePool ~= nil then #activePool.idle else 0,
			builtPuppets = if activePool ~= nil then activePool.built else 0,
			delayMs = math.floor(current.delayMs + 0.5),
			lossLevel = current.clock.lossLevel,
			clock = ReplicationRenderClockSystem.stats(current.clock),
			starving = current.starving,
			counters = table.clone(current.stats),
			bodies = ReplicationRemoteBodyTracker.describe(current),
			held = heldBySlot,
			unheldFrames = table.clone(unheld),
			appearance = if outfits ~= nil then CustomizationOutfitSystem.getState(outfits) else nil,
			mounts = CustomizationDressSystem.counters(),
			poolAffinityHits = if activePool ~= nil then activePool.affinityHits else 0,
			poolSpareReuses = if activePool ~= nil then activePool.spareReuses else 0,
			animation = ReplicationRigAnimationSystem.getState(),
			tripwire = if diagnostics ~= nil then ReplicationDiagnosticsSystem.getState(diagnostics) else nil,
		}
	end,
}

return ReplicationServiceClient
