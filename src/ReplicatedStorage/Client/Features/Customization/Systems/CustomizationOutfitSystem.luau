--!strict
--[=[
	CustomizationOutfitSystem: decides WHAT each client-built rig should wear and WHEN (R4 spec, Section 3); the
	CustomizationDressQueueSystem does the dressing.

	- Owner rig: dresses from the player's own synced appearance (StateSyncClientStore.appearance), no network
	  hop, and SYNCHRONOUSLY on attach, so the player never sees their own rig undressed. Later changes
	  go through the queue and apply in place. Its versions are a local counter: the atom carries none.
	- Puppets: dress from the public slice entry (`appearance` + `appearanceVersion`). An attached
	  puppet stays undressed — parked by the caller — until its job lands. If the entry has not arrived
	  within `DEFAULT_LOOK_SECONDS`, the default look is dressed instead (version 0, below any real
	  version), and the real entry replaces it when it arrives.
	- Every public-slice change re-checks the tracked puppets; only a NEWER version than the rig's (or
	  its pending job's) makes a request, so health updates on the same slice cost a lookup each.

	State is per instance (`new`), so specs drive a private one with their own atoms and dress callback.

	@class CustomizationOutfitSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CustomizationClient = ReplicatedStorage.Client.Features.Customization
local Charm = require(ReplicatedStorage.Packages.Charm)
local CustomizationDressQueueSystem = require(CustomizationClient.Systems.CustomizationDressQueueSystem)
local CustomizationDressSystem = require(CustomizationClient.Systems.CustomizationDressSystem)
local CustomizationWearRules = require(ReplicatedStorage.Shared.Features.Customization.Rules.CustomizationWearRules)
local CustomizationOutfitDiffUtils = require(CustomizationClient.Utils.CustomizationOutfitDiffUtils)
local CustomizationPiecePool = require(CustomizationClient.State.CustomizationPiecePool)
local CustomizationRigOutfitTracker = require(CustomizationClient.State.CustomizationRigOutfitTracker)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)

export type Dress = (
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	ops: { CustomizationOutfitDiffUtils.DiffOp }
) -> ()

export type Deps = {
	ownAppearance: Charm.Atom<PlayerDataTypes.Appearance>,
	publicPlayers: Charm.Atom<PublicPlayerTypes.PublicPlayerMap>,
	pieces: CustomizationPiecePool.CustomizationPiecePool,
	dress: Dress?, -- default: CustomizationDressSystem.apply with `pieces`
	now: (() -> number)?, -- seconds; os.clock by default
	budgetMs: number?,
}

type Tracked = { userId: number, since: number }

export type State = {
	queue: CustomizationDressQueueSystem.Queue,
	pieces: CustomizationPiecePool.CustomizationPiecePool,
	dress: Dress,
	now: () -> number,
	ownAppearance: Charm.Atom<PlayerDataTypes.Appearance>,
	publicPlayers: Charm.Atom<PublicPlayerTypes.PublicPlayerMap>,
	owner: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker?,
	ownerVersion: number,
	puppets: { [CustomizationRigOutfitTracker.CustomizationRigOutfitTracker]: Tracked },
	defaultLook: CustomizationOutfitDiffUtils.Outfit,
	defaultLooks: number, -- puppets dressed in the default look after the timeout (F4)
	cleanups: { () -> () },
}

local CustomizationOutfitSystem = {}

CustomizationOutfitSystem.DEFAULT_LOOK_SECONDS = 1
CustomizationOutfitSystem.DEFAULT_LOOK_VERSION = 0

local function requestFromEntry(
	state: State,
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	userId: number,
	entry: PublicPlayerTypes.PublicPlayer
)
	local version = entry.appearanceVersion
	local pending = CustomizationDressQueueSystem.pendingVersion(state.queue, outfit)
	if version <= outfit.version or (pending ~= nil and version <= pending) then
		return
	end
	CustomizationDressQueueSystem.request(
		state.queue,
		outfit,
		userId,
		version,
		CustomizationOutfitDiffUtils.target(entry.appearance)
	)
end

local function refreshPuppets(state: State, publicPlayers: PublicPlayerTypes.PublicPlayerMap)
	for outfit, tracked in state.puppets do
		local entry = publicPlayers[StateSyncConstants.publicEntryKey(tracked.userId)]
		if entry ~= nil then
			requestFromEntry(state, outfit, tracked.userId, entry)
		end
	end
end

--[=[
	@param deps Deps
	@return State
]=]
function CustomizationOutfitSystem.new(deps: Deps): State
	local pieces = deps.pieces
	local state: State = {
		queue = CustomizationDressQueueSystem.new(deps.budgetMs),
		pieces = pieces,
		dress = deps.dress or function(outfit, ops)
			CustomizationDressSystem.apply(outfit, ops, pieces)
		end,
		now = deps.now or os.clock,
		ownAppearance = deps.ownAppearance,
		publicPlayers = deps.publicPlayers,
		owner = nil,
		ownerVersion = 0,
		puppets = {},
		defaultLook = CustomizationOutfitDiffUtils.target(CustomizationWearRules.defaultAppearance()),
		defaultLooks = 0,
		cleanups = {},
	}
	table.insert(
		state.cleanups,
		Charm.subscribe(deps.publicPlayers, function(publicPlayers)
			refreshPuppets(state, publicPlayers)
		end)
	)
	table.insert(
		state.cleanups,
		Charm.subscribe(deps.ownAppearance, function(appearance)
			state.ownerVersion += 1
			local owner = state.owner
			if owner ~= nil then
				CustomizationDressQueueSystem.request(
					state.queue,
					owner,
					owner.ownerUserId,
					state.ownerVersion,
					CustomizationOutfitDiffUtils.target(appearance)
				)
			end
		end)
	)
	return state
end

--[=[
	Dresses a freshly built owner rig at once, from the player's own appearance.
	@param state State
	@param rig Model
	@param userId number
	@return CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
]=]
function CustomizationOutfitSystem.attachOwner(
	state: State,
	rig: Model,
	userId: number
): CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
	CustomizationOutfitSystem.detachOwner(state, true)
	local outfit = CustomizationRigOutfitTracker.new(rig)
	CustomizationRigOutfitTracker.assign(outfit, userId)
	state.ownerVersion += 1
	local target = CustomizationOutfitDiffUtils.target(state.ownAppearance())
	state.dress(outfit, CustomizationOutfitDiffUtils.compute(outfit.worn, target))
	CustomizationRigOutfitTracker.setWorn(outfit, target, state.ownerVersion)
	state.owner = outfit
	return outfit
end

--[=[
	Forgets the owner rig before it is destroyed: parks its pieces when `salvage` (a rebuild), destroys
	them when not (a rig that fell out of the world — see CustomizationDressSystem.strip).
	@param state State
	@param salvage boolean
]=]
function CustomizationOutfitSystem.detachOwner(state: State, salvage: boolean)
	local owner = state.owner
	if owner == nil then
		return
	end
	state.owner = nil
	CustomizationDressQueueSystem.cancel(state.queue, owner)
	CustomizationDressSystem.strip(owner, state.pieces, salvage)
end

--[=[
	Starts dressing a puppet just acquired for `userId` (ReplicationPuppetPool already assigned its outfit).
	@param state State
	@param outfit CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
	@param userId number
]=]
function CustomizationOutfitSystem.attachPuppet(
	state: State,
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	userId: number
)
	state.puppets[outfit] = { userId = userId, since = state.now() }
	local entry = state.publicPlayers()[StateSyncConstants.publicEntryKey(userId)]
	if entry ~= nil then
		requestFromEntry(state, outfit, userId, entry)
	end
end

--[=[
	Stops dressing a puppet going back to the pool. Its outfit (and record) stays on the rig.
	@param state State
	@param outfit CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
]=]
function CustomizationOutfitSystem.detachPuppet(
	state: State,
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
)
	state.puppets[outfit] = nil
	CustomizationDressQueueSystem.cancel(state.queue, outfit)
end

--[=[
	One frame: default look for puppets that waited too long, then the queue's budgeted step. Call
	before placing puppets, so a rig dressed this frame is placed this frame.
	@param state State
	@return number -- dresses applied
]=]
function CustomizationOutfitSystem.frame(state: State): number
	local now = state.now()
	for outfit, tracked in state.puppets do
		if
			not CustomizationRigOutfitTracker.isDressed(outfit)
			and CustomizationDressQueueSystem.pendingVersion(state.queue, outfit) == nil
			and now - tracked.since >= CustomizationOutfitSystem.DEFAULT_LOOK_SECONDS
		then
			state.defaultLooks += 1
			CustomizationDressQueueSystem.request(
				state.queue,
				outfit,
				tracked.userId,
				CustomizationOutfitSystem.DEFAULT_LOOK_VERSION,
				state.defaultLook
			)
		end
	end
	return CustomizationDressQueueSystem.step(state.queue, state.dress)
end

--[=[
	Diagnostics for F4.
	@param state State
	@return { [string]: number }
]=]
function CustomizationOutfitSystem.getState(state: State): { [string]: number }
	local tracked, undressed = 0, 0
	for outfit in state.puppets do
		tracked += 1
		if not CustomizationRigOutfitTracker.isDressed(outfit) then
			undressed += 1
		end
	end
	return {
		trackedPuppets = tracked,
		undressedPuppets = undressed,
		queued = CustomizationDressQueueSystem.size(state.queue),
		applied = state.queue.applied,
		droppedStale = state.queue.dropped,
		lastStepMs = state.queue.lastStepMs,
		defaultLooks = state.defaultLooks,
		piecesParked = state.pieces.parked,
		pieceHits = state.pieces.hits,
		pieceMisses = state.pieces.misses,
	}
end

--[=[
	Unsubscribes and forgets every rig. Rigs and pieces belong to the caller.
	@param state State
]=]
function CustomizationOutfitSystem.destroy(state: State)
	for _, cleanup in state.cleanups do
		cleanup()
	end
	table.clear(state.cleanups)
	table.clear(state.puppets)
	state.owner = nil
end

-- Where the shared cosmetic pieces live while they are on a rig or pooled.
local PIECE_FOLDER_NAME = "CosmeticPieces"

--[=[
	Mounts the game's outfit system: the `CosmeticPieces` folder in Workspace, its piece pool, and a
	system that dresses from this client's synced atoms. Returns the system and the one call that tears
	all three down, in reverse order. The replication client decides WHEN; WHAT gets built is
	Customization's job.
	@return (State, () -> ())
]=]
function CustomizationOutfitSystem.mount(): (State, () -> ())
	local folder = Instance.new("Folder")
	folder.Name = PIECE_FOLDER_NAME
	folder.Parent = Workspace
	local pieces = CustomizationPiecePool.new(folder)
	local state = CustomizationOutfitSystem.new({
		ownAppearance = StateSyncClientStore.appearance,
		publicPlayers = StateSyncClientStore.publicPlayers,
		pieces = pieces,
	})
	return state,
		function()
			CustomizationOutfitSystem.destroy(state)
			CustomizationPiecePool.destroy(pieces)
			folder:Destroy()
		end
end

return CustomizationOutfitSystem
