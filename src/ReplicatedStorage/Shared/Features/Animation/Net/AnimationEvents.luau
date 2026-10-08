--!strict
--[=[
	AnimationEvents: the ByteNet packet contract for animation diagnostics (Phase 6 spec, Decision 5).

	Server → one client: the anim-tracks and anim-report read paths (playback state and asset loading
	live on the client, so the client reports them). Playing an animation on a player's body is NOT here:
	since character replication R3 a server-granted action is timed body state (`ActionStarted` /
	`ActionStopped` in ReplicationEvents), delivered to the owner and every viewer alike.

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
