--!strict
--[=[
	DepotSpotConstants: the hub's spots (owner's picks, 2026-11-11; plan docs/superpowers/plans/2026-11-11-hub-interactables.md).
	A spot is a Studio part with the base Interaction tag and `InteractionKind` set to one of KINDS; a standee also
	carries EMPLOYEE_ATTRIBUTE. The prompt words are for young players. The radio's stations, the bell's cooldown and
	the delivery truck that drives past the yard (DRIVE_BY) live here too. Static data (spec-exempt).

	@class DepotSpotConstants
]=]

export type Spot = "shop" | "standee" | "coffee" | "crew" | "rank" | "radio" | "bell"

export type Station = {
	-- The toast's words.
	name: string,
	-- The registered music id it plays (DepotAssets), or nil for a quiet station.
	track: string?,
}

-- Interaction kind (the InteractionKind attribute in Studio) per spot.
local KINDS: { [string]: string } = table.freeze({
	shop = "depot-spot-shop",
	standee = "depot-spot-standee",
	coffee = "depot-spot-coffee",
	crew = "depot-spot-crew",
	rank = "depot-spot-rank",
	radio = "depot-spot-radio",
	bell = "depot-spot-bell",
})

-- The prompt per spot: its verb and noun (a standee's noun is replaced by the employee's name).
local PROMPTS: { [string]: { action: string, object: string } } = table.freeze({
	shop = table.freeze({ action = "Shop", object = "Supply Counter" }),
	standee = table.freeze({ action = "Meet", object = "Crew member" }),
	coffee = table.freeze({ action = "Coffee", object = "Coffee machine" }),
	crew = table.freeze({ action = "Look", object = "Top crews" }),
	rank = table.freeze({ action = "Look", object = "Rank chart" }),
	radio = table.freeze({ action = "Next song", object = "Radio" }),
	bell = table.freeze({ action = "Ring", object = "Shift bell" }),
})

local STATIONS: { Station } = {
	table.freeze({ name = "Garage Tunes", track = "depotHubTheme" }),
	table.freeze({ name = "Quiet Night", track = nil }),
}

local DepotSpotConstants = {
	KINDS = KINDS,
	PROMPTS = PROMPTS,
	-- A standee names its employee (EmployeeRegistry name) here.
	EMPLOYEE_ATTRIBUTE = "DepotEmployee",
	-- Studs: how close a player must stand (the server checks it too).
	MAX_DISTANCE = 9,
	-- Seconds one player waits before using the same spot again (the Interaction feature's cooldown).
	USE_COOLDOWN = 0.75,
	-- Seconds a bell rests after it rings, for everyone (so a crew can't spam it).
	BELL_COOLDOWN = 2.5,
	-- The registered bell sound (DepotAssets), played at the bell on every client.
	BELL_SOUND = "depotShiftBell",
	STATIONS = table.freeze(STATIONS),
	-- The coffee scene's words.
	COFFEE_LINE = "2x pay on your next shift!",
	-- The scenes the client opens.
	SCENES = table.freeze({
		coffee = "depot.Coffee",
		crew = "depot.CrewWall",
		rank = "depot.RankChart",
	}),
	-- The delivery truck outside: a road of parts tagged TAG with Order = 1..N; a truck drives it every
	-- MIN_GAP..MAX_GAP seconds at SPEED studs/s and honks once on the way.
	DRIVE_BY = table.freeze({
		TAG = "DepotDriveBy",
		ORDER_ATTRIBUTE = "Order",
		-- The truck itself: one Model with this tag, parked out of sight at the road's start, its pivot facing
		-- forward. Each client drives its own copy (anchored parts moved locally), so nothing replicates.
		VEHICLE_TAG = "DepotDriveByVehicle",
		MIN_GAP = 35,
		MAX_GAP = 75,
		SPEED = 26,
		HORN_SOUND = "depotDriveByHorn",
		-- The chance the truck honks on a pass.
		HORN_CHANCE = 0.5,
	}),
}

return table.freeze(DepotSpotConstants)
