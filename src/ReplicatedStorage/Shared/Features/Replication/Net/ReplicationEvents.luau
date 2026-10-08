--!strict
--[=[
	ReplicationEvents: the ByteNet contract for client-only bodies (spec 2026-09-22 §6.1, C7; plan
	R2 Task 9). The repo's first UNRELIABLE packets: continuous, high-rate, per-viewer motion is neither
	queryable state (charm-sync) nor a one-off event — see docs/architecture.md, Networking.

	Unreliable (single `buff` payload):
	- `Uplink`   owner → server: `u32 sentMs · u8 count · records` (ReplicationUplinkCodec).
	- `Downlink` server → viewer: one batch per viewer per frame (header + records, ≤ 700 B).

	Reliable (typed structs):
	- `Ready`          client → server once its listeners are connected; the server answers with `Session`,
	                   the whole slot table, and (on join) a `Spawn`.
	- `RespawnRequest` client → server: the owner rig fell through the fall plane.
	- `Session`        the session time epoch (seconds): every time on the wire is ms since it.
	- `SlotEntry`      one row of the slot table: slot → userId, generation, full 8-bit epoch, active. Sent to
	                   everyone on claim, epoch bump and release; the reliable epoch resets a viewer that missed
	                   a bump.
	- `Spawn`          to the owner: build your rig here, in this epoch.
	- `Enter`/`Leave`  to a viewer: a body entered / left its visibility set. `Enter` carries a full-state
	                   record (age relative to `batchTimeMs`) so the body can be placed at once.
	- `ActionStarted`  R3 timed body state, kind "action": a server-granted animation on `userId`'s body in
	                   body epoch `epoch`, on layer index `layer` (AnimationTypes.ANIMATION_LAYERS), the
	                   registry entry `wireId`, asset `variant` (0 = the entry's own), speed in thousandths,
	                   session `startMs`, and `durationMs` (absent = open-ended). To the owner and every
	                   observer; replayed to a viewer right after its `Enter`. 20 B (24 B with a duration).
	- `ActionStopped`  the grant on that layer that started at `startMs` ended early. 14 B.

	Boot timing: the client waits for the namespace value the server creates when it requires this module
	(same guard as DebuggerEvents).

	@class ReplicationEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "ReplicationEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local ReplicationEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Uplink = ByteNet.definePacket({
				value = ByteNet.buff,
				reliabilityType = "unreliable",
			}),
			Downlink = ByteNet.definePacket({
				value = ByteNet.buff,
				reliabilityType = "unreliable",
			}),
			Ready = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			RespawnRequest = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			Session = ByteNet.definePacket({
				value = ByteNet.struct({
					epochSeconds = ByteNet.float64,
				}),
				reliabilityType = "reliable",
			}),
			SlotEntry = ByteNet.definePacket({
				value = ByteNet.struct({
					slot = ByteNet.uint8,
					userId = ByteNet.float64,
					generation = ByteNet.uint8,
					epoch = ByteNet.uint8,
					active = ByteNet.bool,
				}),
				reliabilityType = "reliable",
			}),
			Spawn = ByteNet.definePacket({
				value = ByteNet.struct({
					position = ByteNet.vec3,
					epoch = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),
			Enter = ByteNet.definePacket({
				value = ByteNet.struct({
					slot = ByteNet.uint8,
					generation = ByteNet.uint8,
					batchTimeMs = ByteNet.uint32,
					record = ByteNet.buff,
				}),
				reliabilityType = "reliable",
			}),
			Leave = ByteNet.definePacket({
				value = ByteNet.struct({
					slot = ByteNet.uint8,
					generation = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),
			ActionStarted = ByteNet.definePacket({
				value = ByteNet.struct({
					userId = ByteNet.float64,
					epoch = ByteNet.uint8,
					layer = ByteNet.uint8,
					wireId = ByteNet.uint16,
					variant = ByteNet.uint8,
					speedMilli = ByteNet.uint16,
					startMs = ByteNet.uint32,
					durationMs = ByteNet.optional(ByteNet.uint32),
				}),
				reliabilityType = "reliable",
			}),
			ActionStopped = ByteNet.definePacket({
				value = ByteNet.struct({
					userId = ByteNet.float64,
					epoch = ByteNet.uint8,
					layer = ByteNet.uint8,
					startMs = ByteNet.uint32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return ReplicationEvents
