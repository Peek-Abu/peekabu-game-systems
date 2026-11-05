--!strict
--[=[
	OfficeAnomalyConstants: the exterior anomalies a run can show (ids, the slot tag and attribute the client finds
	them by, the attribute publishing the run's set, the welcome-screen words, and the leaning lamp's tilt). Static data.

	@class OfficeAnomalyConstants
]=]

export type AnomalyId =
	"silhouette"
	| "autoDoors"
	| "carTicking"
	| "welcomeScreen"
	| "boothTv"
	| "wetFloor"
	| "leaningLamp"

return table.freeze({
	IDS = table.freeze({
		"silhouette",
		"autoDoors",
		"carTicking",
		"welcomeScreen",
		"boothTv",
		"wetFloor",
		"leaningLamp",
	}),
	SLOT_TAG = "OfficeAnomalySlot",
	SLOT_ATTRIBUTE = "AnomalyId",
	-- A comma-joined id list on the office model.
	PUBLISHED_ATTRIBUTE = "OfficeAnomalies",
	-- leaningLamp: how far the walk's lamp post leans from upright, toward the slot's LEAN_DIRECTION_ATTRIBUTE (a
	-- horizontal Vector3, away from the walk). Its base stays; the rest turns about the shaft's lower end.
	LEAN_DEGREES = 15,
	LEAN_DIRECTION_ATTRIBUTE = "LeanDirection",
	WELCOME_TEXT = "WE VALUE YOUR TIME",
	-- Consumers (server and client) pick with OfficeSeedUtils.pick(seed, "welcome", WRONG_WORDS).
	WRONG_WORDS = table.freeze({
		"WE VALUE YOUR SLEEP",
		"WE VALUE YOUR SILENCE",
		"WE HEAR YOUR TIME",
		"WE VALUE OUR TIME",
		"WE VALUE YOUR TEETH",
	}),
})
