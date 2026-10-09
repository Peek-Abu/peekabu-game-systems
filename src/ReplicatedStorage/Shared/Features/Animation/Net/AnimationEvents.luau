--!strict
--[=[
	AnimationEvents: the ByteNet packet contract for animation (server → the OWNING client only).

	- `ActionStarted` / `ActionStopped`: a server-granted action on the player's own character. Native
	  characters replicate their own animations, so the owner plays the track and Roblox replicates it to
	  every other client — one packet, to one client, no double plays.
	- `ReportTracks` / `ProbeAssets`: the anim-tracks and anim-report read paths (playback state and asset
	  loading live on the client, so the client reports them).

	Boot-timing note (same as DebuggerEvents): the client waits for the per-namespace replicated
	value the server creates when IT requires this module (at AnimationServiceServer init).

	@class AnimationEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "AnimationEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local AnimationEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- server -> owner: play a granted action on your character. `layer` is
			-- AnimationTypes.layerIndex, `wireId` the registry's compact id, `variant` the server's pick
			-- (0 = the entry's own asset), `speedMilli` the clamped speed in thousandths.
			ActionStarted = ByteNet.definePacket({
				value = ByteNet.struct({
					layer = ByteNet.uint8,
					wireId = ByteNet.uint16,
					variant = ByteNet.uint8,
					speedMilli = ByteNet.uint16,
				}),
				reliabilityType = "reliable",
			}),
			-- server -> owner: end the action on this layer early.
			ActionStopped = ByteNet.definePacket({
				value = ByteNet.struct({
					layer = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),
			-- server -> client: log your live animation bookkeeping (the anim-tracks command's
			-- read path — playback state lives on the owning client, so the CLIENT reports it).
			-- Payload unused; the packet is the signal.
			ReportTracks = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- server -> client: probe every registry asset id (PreloadAsync) and log failures —
			-- the anim-report command's asset half. Payload unused; the packet is the signal.
			ProbeAssets = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		-- Empty but present: `defineNamespace` types the closure return as the full namespaceData
		-- shape (the DebuggerEvents precedent).
		queries = {},
		structs = {},
	}
end)

return AnimationEvents
