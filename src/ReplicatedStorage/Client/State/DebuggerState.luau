--!strict
--[=[
	DebuggerState: the client-side reactive state for the Service & State Debugger overlay.

	Two atoms drive the overlay:
	- `visible` — whether the F4 overlay is open. DebuggerServiceClient flips this (and sends the
	  matching subscription packet); the overlay reads it to show/hide without unmounting.
	- `serverSnapshot` — the latest snapshot the server streamed. DebuggerServiceClient writes inbound
	  packets here; the overlay reads it via `useAtom` and re-renders each tick while open.

	The CLIENT half of the service tree and logs is read locally (this realm's ServiceController and
	Logger buffer), since the server snapshot only covers server services. These readers are plain
	(non-reactive) pulls invoked during render — the overlay already re-renders at the server tick rate
	when `serverSnapshot` changes, so client state refreshes in lockstep for free.

	@class DebuggerState
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)
local SyncState = require(ReplicatedStorage.Shared.State.SyncState)
local DebuggerEvents = require(ReplicatedStorage.Shared.Events.DebuggerEvents)
local ClientStore = require(ReplicatedStorage.Client.State.ClientStore)

type ServiceSnapshot = DebuggerEvents.ServiceSnapshot
type AtomSnapshot = DebuggerEvents.AtomSnapshot
type PlayerInfo = DebuggerEvents.PlayerInfo

--[=[
	Which realm the overlay is inspecting. The header's Server/Client toggle flips this; every panel
	reads it to decide whether to show snapshot data (server) or locally-read data (client).
]=]
export type Context = "server" | "client"

-- `nil` until the first snapshot arrives, so the overlay can show a waiting state (same idiom as
-- ClientStore.currency starting nil).
local visible = Charm.atom(false)
local serverSnapshot = Charm.atom(nil :: DebuggerEvents.Snapshot?)
local context = Charm.atom("server" :: Context)

local DebuggerState = {
	visible = visible,
	serverSnapshot = serverSnapshot,
	context = context,
}

--[=[
	Reads this realm's (client) registered services into the same ServiceSnapshot shape the server
	uses, so the overlay renders server and client trees identically. Each `getState()` is pcall-
	isolated so one faulty client service can't break the panel.
	@return { ServiceSnapshot } -- The client service tree
]=]
function DebuggerState.getClientServices(): { ServiceSnapshot }
	local result: { ServiceSnapshot } = {}
	for name, entry in ServiceController:getAllServices() do
		-- Carry the SAME fields the server's assembleServices snapshot does, so the overlay renders
		-- both realms identically. Previously this dropped the error/timing fields, which hid the
		-- one failure the board exists to surface: a client service whose start() threw rendered
		-- green "started" because ServicesPanel.statusOf keys off startError first (now populated).
		local snapshot: ServiceSnapshot = {
			name = name,
			initialized = entry.initialized,
			started = entry.started,
			dependencies = entry.dependencies,
			initDurationMs = entry.initDurationMs,
			startDurationMs = entry.startDurationMs,
			initError = entry.initError,
			startError = entry.startError,
		}
		if entry.module.getState then
			local ok, state = pcall(entry.module.getState, entry.module)
			if ok then
				snapshot.state = state
			else
				snapshot.stateError = tostring(state)
			end
		end
		table.insert(result, snapshot)
	end
	return result
end

--[=[
	Returns this realm's (client) log history — the local Logger ring buffer.
	@return { Logger.LogEntry } -- Client log lines, oldest first
]=]
function DebuggerState.getClientLogs(): { Logger.LogEntry }
	return Logger.getHistory()
end

--[=[
	The client "entity" list for the State sidebar: just the local player (the only player whose state
	this realm holds). Kept as a list so the State panel treats both realms uniformly.
	@return { PlayerInfo } -- The local player
]=]
function DebuggerState.getClientPlayers(): { PlayerInfo }
	local player = Players.LocalPlayer
	return { { userId = player.UserId, name = player.Name } }
end

--[=[
	Reads the local player's ClientStore slices as AtomSnapshots (slice-agnostic via
	SyncState.SLICES + ClientStore.readSlice), so the State panel renders client state with the same
	rows as server state.
	@return { AtomSnapshot } -- One entry per synced slice for the local player
]=]
function DebuggerState.getClientAtoms(): { AtomSnapshot }
	local userId = Players.LocalPlayer.UserId
	local result: { AtomSnapshot } = {}
	for _, slice in SyncState.SLICES do
		table.insert(result, {
			slice = slice,
			userId = userId,
			value = ClientStore.readSlice(slice),
		})
	end
	return result
end

--[=[
	Clears logs for the given context: the local Logger buffer for client, or a gated server request
	for server (the server clears its own buffer and re-streams the emptied state). Takes a plain string
	because the context value widens across the useAtom generic boundary.
	@param forContext string -- Which realm's logs to clear ("client" or "server")
]=]
function DebuggerState.clearLogs(forContext: string)
	if forContext == "client" then
		Logger.clearHistory()
	else
		DebuggerEvents.packets.ClearServerLogs.send(true)
	end
end

return DebuggerState
