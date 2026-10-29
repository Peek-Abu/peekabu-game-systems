--!strict
--[=[
	HostConstants: crew hosting's tuning (Odd Hours, characters/launch/crew-hosting/DESIGN.md). Static data
	(spec-exempt). Every number is a one-line edit.

	@class HostConstants
]=]

return table.freeze({
	-- The world entry the hosted trucks are published under (HostSnapshotUtils decodes it).
	WORLD_ENTRY = "host",
	-- A held pad's attribute: its host's UserId, absent while nobody is aboard (the hub draws the truck from it).
	HOST_ATTRIBUTE = "TruckHost",
	-- Seats on a truck, and on a truck whose host owns the Big Crew pass (only the host needs it).
	SEATS = 4,
	PASS_SEATS = 6,
	-- The Big Crew game pass (the host's 6 seats). PASS_ID 0 = not created on the Creator Dashboard yet: the pass is
	-- off (not registered, never prompted, every truck seats SEATS) and the server warns once at boot. Fill the id in
	-- to turn it on.
	PASS_KEY = "bigCrew",
	PASS_ID = 2058797732,
	-- START's countdown (seconds); the host may cancel it, and others may still hop in.
	START_SECONDS = 5,
	-- A truck with anyone aboard that nobody starts for this long starts on its own (an away host can't trap kids).
	IDLE_SECONDS = 60,
	-- Where LEAVE puts a player: this many studs past the pad's front (-Z) edge, the root this high over its floor.
	EXIT_DISTANCE = 7,
	EXIT_HEIGHT = 3,
	-- How often trucks are checked (seconds).
	TICK_INTERVAL = 0.25,
	-- Requests per player per window (each of Start, Cancel, Leave, Kick, SetLock).
	REQUEST_RATE = table.freeze({ maxRequests = 6, windowSeconds = 5 }),
	-- Player-facing words (kid reading level). `friendsOnly` is a string.format pattern: the host's name.
	TEXT = table.freeze({
		kicked = "The host took you off this truck. Try another one!",
		friendsOnly = "This truck is just for %s's friends.",
		hostFallback = "the host",
		-- To a friend who came from an invite while the inviter waits in a truck (the inviter's name).
		invited = "%s is waiting in a truck. Walk in to join!",
		-- The host's chip to buy the Big Crew pass.
		upgrade = "Get 6 seats",
	}),
	-- Seconds after an invited friend joins before they are told (their screen is still loading before that).
	INVITED_TOAST_DELAY = 6,
})
