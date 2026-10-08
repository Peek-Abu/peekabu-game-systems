--!strict
--[=[
	ReplicationDiagnosticsSystem (R5 spec 2026-10-05 §1.2): builds ReplicationViewCheck's snapshot from the client
	service's view, and runs the tripwire once a second ONLY while Workspace `Diagnostics` is true.

	Off = nothing runs: the 1 Hz thread does not exist (cancelled, not skipped) and the tripwire's state is
	dropped. The attribute listener is the only cost. One `log:warn` per episode start and end. No recovery:
	an episode is a bug to root-cause (spec decision 7).

	@class ReplicationDiagnosticsSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicationClient = ReplicatedStorage.Client.Features.Replication
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)
local ReplicationRemoteBodyTracker = require(ReplicationClient.State.ReplicationRemoteBodyTracker)
local ReplicationPuppetPool = require(ReplicationClient.State.ReplicationPuppetPool)
local ReplicationRigTracker = require(ReplicationClient.State.ReplicationRigTracker)
local ReplicationViewCheck = require(ReplicationClient.Rules.ReplicationViewCheck)

local ReplicationDiagnosticsSystem = {}

ReplicationDiagnosticsSystem.ATTRIBUTE = "Diagnostics"
ReplicationDiagnosticsSystem.INTERVAL_SECONDS = 1

export type HeldPuppet = { puppet: ReplicationPuppetPool.Puppet, player: Player }

export type View = {
	remote: ReplicationRemoteBodyTracker.State,
	held: { [number]: HeldPuppet },
	placed: { [number]: boolean }, -- slots placed in the last rendered frame
	registry: ReplicationRigTracker.Registry,
	players: { Player },
}

export type Watcher = {
	tripwire: ReplicationViewCheck.Tripwire?,
	thread: thread?,
	connection: RBXScriptConnection,
}

--[=[
	Assembles the live View from the client service's state (kept here so the service stays under the
	file-length cap).
	@return View
]=]
function ReplicationDiagnosticsSystem.view(
	remote: ReplicationRemoteBodyTracker.State,
	held: { [number]: HeldPuppet },
	placed: { [number]: boolean },
	registry: ReplicationRigTracker.Registry
): View
	return { remote = remote, held = held, placed = placed, registry = registry, players = Players:GetPlayers() }
end

--[=[
	The tripwire's view of this client: every other player, every known body (visible ones in detail), every
	held puppet, and whether each remote player's `Character` is the registry's rig for them.
	@param view View
	@return ReplicationViewCheck.Snapshot
]=]
function ReplicationDiagnosticsSystem.snapshot(view: View): ReplicationViewCheck.Snapshot
	local localUserId = view.registry.localUserId
	local present: { [number]: Player } = {}
	local others: { number } = {}
	for _, player in view.players do
		present[player.UserId] = player
		if player.UserId ~= localUserId then
			table.insert(others, player.UserId)
		end
	end
	local known: { [number]: boolean } = {}
	local bodies: { ReplicationViewCheck.BodyView } = {}
	for slot, body in view.remote.bodies do
		known[body.userId] = true
		if body.visible then
			local entry = view.held[slot]
			table.insert(bodies, {
				slot = slot,
				userId = body.userId,
				generation = body.generation,
				epoch = body.epoch,
				held = entry ~= nil,
				placed = view.placed[slot] == true,
				dressed = entry ~= nil and CustomizationRigOutfitTracker.isDressed(entry.puppet.outfit),
				bufferEmpty = #body.samples.samples == 0,
				playerPresent = if present[body.userId] then true else false,
			})
		end
	end
	local held: { ReplicationViewCheck.HeldView } = {}
	for slot, entry in view.held do
		table.insert(held, { slot = slot, ownerUserId = entry.player.UserId })
	end
	local characters: { ReplicationViewCheck.CharacterView } = {}
	for _, userId in others do
		local player = present[userId]
		table.insert(characters, {
			userId = userId,
			matches = player.Character == ReplicationRigTracker.rigFor(view.registry, userId),
		})
	end
	return { otherUserIds = others, knownUserIds = known, bodies = bodies, held = held, characters = characters }
end

local function runOnce(watcher: Watcher, readView: () -> View?, log: Logger.Logger)
	local tripwire = watcher.tripwire
	local view = readView()
	if tripwire == nil or view == nil then
		return
	end
	local started, ended = ReplicationViewCheck.check(tripwire, ReplicationDiagnosticsSystem.snapshot(view), os.clock())
	for _, episode in started do
		log:warn(`tripwire: {ReplicationViewCheck.describe(episode)}`)
	end
	for _, episode in ended do
		log:warn(`tripwire cleared: {ReplicationViewCheck.describe(episode)}`)
	end
end

local function sync(watcher: Watcher, readView: () -> View?, log: Logger.Logger)
	local on = Workspace:GetAttribute(ReplicationDiagnosticsSystem.ATTRIBUTE) == true
	local thread = watcher.thread
	if on and thread == nil then
		watcher.tripwire = ReplicationViewCheck.new()
		watcher.thread = task.spawn(function()
			while true do
				task.wait(ReplicationDiagnosticsSystem.INTERVAL_SECONDS)
				-- A throw must not kill the thread: a dead watcher would read as a clean run. Report, keep looping.
				xpcall(runOnce, function(err: string)
					log:error(`tripwire check failed: {err}`)
				end, watcher, readView, log)
			end
		end)
	elseif not on and thread ~= nil then
		task.cancel(thread)
		watcher.thread = nil
		watcher.tripwire = nil
	end
end

--[=[
	Starts watching Workspace `Diagnostics`. `readView` returns nil until the service has a view.
	@param readView () -> View?
	@param log Logger.Logger
	@return Watcher
]=]
function ReplicationDiagnosticsSystem.watch(readView: () -> View?, log: Logger.Logger): Watcher
	local watcher: Watcher
	watcher = {
		tripwire = nil,
		thread = nil,
		connection = Workspace:GetAttributeChangedSignal(ReplicationDiagnosticsSystem.ATTRIBUTE):Connect(function()
			sync(watcher, readView, log)
		end),
	}
	sync(watcher, readView, log)
	return watcher
end

--[=[
	Stops the listener and the check thread.
	@param watcher Watcher
]=]
function ReplicationDiagnosticsSystem.stop(watcher: Watcher)
	watcher.connection:Disconnect()
	local thread = watcher.thread
	if thread ~= nil then
		task.cancel(thread)
		watcher.thread = nil
	end
	watcher.tripwire = nil
end

--[=[
	For F4. `enabled = false` (and zero counts) while `Diagnostics` is off.
	@param watcher Watcher
]=]
function ReplicationDiagnosticsSystem.getState(watcher: Watcher): {
	enabled: boolean,
	checks: number,
	counts: { [string]: number },
	open: { string },
}
	local tripwire = watcher.tripwire
	if tripwire == nil then
		return { enabled = false, checks = 0, counts = {}, open = {} }
	end
	local state = ReplicationViewCheck.getState(tripwire)
	return { enabled = true, checks = state.checks, counts = state.counts, open = state.open }
end

return ReplicationDiagnosticsSystem
