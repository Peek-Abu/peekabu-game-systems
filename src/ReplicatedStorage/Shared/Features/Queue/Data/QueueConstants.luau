--!strict
--[=[
	QueueConstants: names, defaults and limits for queue pads, teleports and arrivals. Static data
	(spec-exempt). Every number is a tuning value.

	@class QueueConstants
]=]

return table.freeze({
	-- CollectionService tag on a pad: a BasePart whose top players stand on.
	TAG = "QueuePad",
	-- Pad attributes, read once when the pad is tagged (set them before tagging).
	CAPACITY_ATTRIBUTE = "QueueCapacity",
	COUNTDOWN_ATTRIBUTE = "QueueCountdown",
	DESTINATION_ATTRIBUTE = "QueueDestination",
	DEFAULT_CAPACITY = 4,
	-- TeleportAsync moves at most 50 players at once.
	MAX_CAPACITY = 50,
	DEFAULT_COUNTDOWN = 15,
	MAX_COUNTDOWN = 300,
	-- Studs above the pad's top surface a HumanoidRootPart still counts as aboard.
	ABOARD_HEIGHT = 8,
	-- How often pads are sampled and timers checked (seconds).
	TICK_INTERVAL = 0.25,
	-- Seconds before retry 1, 2 and 3. After the third retry fails the party is back on its pad.
	RETRY_DELAYS = table.freeze({ 1, 2, 4 }),
	-- Seconds a player may still be here after their teleport started before it counts as failed. Long
	-- enough that a slow but healthy TeleportAsync (and ReserveServer) is not retried on top of itself.
	TELEPORT_WATCHDOG = 30,
	-- Seconds an arrival server waits for the expected party before starting with whoever arrived.
	ARRIVAL_TIMEOUT = 20,
	-- A role's PlaceId before its place exists; reached by a local move.
	PLACEHOLDER_PLACE_ID = 0,
	TICKET_VERSION = 1,
	MAX_PAYLOAD_KEYS = 32,
	MAX_PAYLOAD_KEY_LENGTH = 64,
	MAX_PAYLOAD_STRING = 1000,
	-- The StateSyncWorldStore entry the pads are published under.
	WORLD_ENTRY = "queue",
	DEPART_FAILED_TEXT = "Couldn't leave. You're back on the pad.",
	RETURN_FAILED_TEXT = "Couldn't travel. Try again in a moment.",
	REDIRECT_KICK_TEXT = "This server is full. Please rejoin.",
})
