--!strict
--[=[
	DebuggerEvents: the ByteNet packet contract for the in-game Service & State Debugger.

	This is the codebase's FIRST live ByteNet consumer — the pattern every future discrete/event
	packet set should copy (a shared namespace module both realms require; see docs/architecture.md
	Networking). It intentionally exercises the `ByteNetMax` dependency that was provisioned-but-unused.

	Three packets:
	- `SetSubscription` (client → server, `bool`): the overlay sends `true` when the player opens it
	  (F4) and `false` when they close it. The server only streams snapshots to subscribed players,
	  so a closed overlay costs zero bandwidth. Routed through RequestHandler on the server for rate
	  limiting + the `isAdmin` gate.
	- `Snapshot` (server → client, `unknown`): the assembled debug snapshot. Typed as `unknown` for
	  the SAME reason the charm-sync transport is exempt from a static struct (see
	  StateSyncServiceServer): the payload aggregates arbitrary `getState()` shapes and live atom
	  values, which no fixed ByteNet struct can describe. `Snapshot` (the Luau type below) documents
	  its real shape; the client shape-guards then narrows at the trust boundary, mirroring
	  StateSyncServiceClient's existing `type(payload) ~= "table"` check.

	Boot-timing note: ByteNet's client-side namespace lookup uses `FindFirstChild` (not
	`WaitForChild`), so the per-namespace replicated value must already exist before the client calls
	`defineNamespace`. The server creates it when it requires this module (at DebuggerServiceServer
	init); the client `WaitForChild`s it below before defining. Get this wrong and the client errors
	with a nil namespace read.

	@class DebuggerEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)

local NAMESPACE = "DebuggerEvents"

--[=[
	One service's row in the snapshot: its lifecycle flags, declared dependencies, boot timing/health,
	and the result of its optional `getState()`. `state` is nil when the service exposes no `getState`;
	`stateError` is set instead when `getState()` threw or timed out during assembly. The
	`initDurationMs`/`startDurationMs`/`initError`/`startError` fields mirror ServiceController's boot
	introspection and drive the Services health board.
]=]
export type ServiceSnapshot = {
	name: string,
	initialized: boolean,
	started: boolean,
	dependencies: { string },
	initDurationMs: number?,
	startDurationMs: number?,
	initError: string?,
	startError: string?,
	state: { [string]: any }?,
	stateError: string?,
}

--[=[
	A player present on the server, for the State tab's entity sidebar (entity ≈ player).
]=]
export type PlayerInfo = {
	userId: number,
	name: string,
}

--[=[
	One live rate-limit counter: how many requests `userId` has made for `action` inside its window.
	Sourced from RequestHandler.getRateLimitStatus.
]=]
export type RateLimitSnapshot = {
	userId: number,
	action: string,
	requestsInWindow: number,
}

--[=[
	One replicated state slice, per player, as mirrored in ServerStore (e.g. currency, inventory).
]=]
export type AtomSnapshot = {
	slice: string,
	userId: number,
	value: any,
}

--[=[
	The full debug snapshot the server assembles each tick and ships to subscribed overlays.
	`realm`/`phase`/`clock` are server-wide; the arrays are the per-panel payloads. `logs` reuses
	Logger's own entry type so there is one definition of a log line across the codebase.
]=]
export type Snapshot = {
	realm: string,
	phase: ServiceController.Phase,
	clock: number,
	players: { PlayerInfo },
	services: { ServiceSnapshot },
	atoms: { AtomSnapshot },
	rateLimits: { RateLimitSnapshot },
	logs: { Logger.LogEntry },
}

-- Client boot-timing guard (see the boot-timing note above). ByteNet's `values.start()` already
-- WaitForChild'd BytenetStorage when the package was required, so this only waits on the per-namespace
-- StringValue the server creates.
if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local DebuggerEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: true = open/subscribe, false = close/unsubscribe
			SetSubscription = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- server -> client: the assembled debug snapshot (see the Snapshot type)
			Snapshot = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
			-- client -> server: clear the server's log ring buffer (the overlay's Clear button in
			-- server context). Gated by isAdmin server-side like SetSubscription. Payload is unused; the
			-- packet itself is the signal.
			ClearServerLogs = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		-- Empty but present: `defineNamespace` types the closure return as the full `namespaceData`
		-- shape, and the runtime fills `structs` itself and defaults `queries`. We declare no queries
		-- (this contract is packet-only) or structs.
		queries = {},
		structs = {},
	}
end)

return DebuggerEvents
