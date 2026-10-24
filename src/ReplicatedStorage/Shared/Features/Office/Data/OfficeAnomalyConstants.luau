--!strict
--[=[
	OfficeAnomalyConstants: the exterior anomalies a run can show (ids, the slot tag and attribute the client finds
	them by, the attribute publishing the run's set, and the welcome-screen words). Static data.

	@class OfficeAnomalyConstants
]=]

export type AnomalyId = "silhouette" | "autoDoors" | "carTicking" | "welcomeScreen" | "boothTv" | "wetFloor" | "banner"

return table.freeze({
	IDS = table.freeze({
		"silhouette",
		"autoDoors",
		"carTicking",
		"welcomeScreen",
		"boothTv",
		"wetFloor",
		"banner",
	}),
	SLOT_TAG = "OfficeAnomalySlot",
	SLOT_ATTRIBUTE = "AnomalyId",
	-- A comma-joined id list on the office model.
	PUBLISHED_ATTRIBUTE = "OfficeAnomalies",
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
