--!strict
--[=[
	InteractionConstants: tag and attribute names and the distance rules. Static data (spec-exempt).

	@class InteractionConstants
]=]

return table.freeze({
	-- CollectionService tag a builder (or a system) puts on an interactable object.
	TAG = "Interactable",
	-- String attribute naming the object's InteractionRegistry kind.
	KIND_ATTRIBUTE = "InteractionKind",
	-- Boolean attribute; false hides the prompt and refuses triggers. Absent = enabled.
	ENABLED_ATTRIBUTE = "InteractionEnabled",
	-- The name of the ProximityPrompt the server creates (the client finds it by this name).
	PROMPT_NAME = "InteractionPrompt",
	DEFAULT_MAX_DISTANCE = 10,
	-- Extra studs the server allows on top of maxDistance: the player moved a little between pressing and
	-- the server hearing it.
	DISTANCE_TOLERANCE = 4,
	-- String attribute naming an object's channel kind (InteractionRegistry.registerChannel).
	CHANNEL_KIND_ATTRIBUTE = "ChannelKind",
	-- Number attributes the server keeps on a channel target: progress 0-1, and players on it.
	CHANNEL_PROGRESS_ATTRIBUTE = "ChannelProgress",
	CHANNEL_COUNT_ATTRIBUTE = "ChannelCount",
	-- Seconds between channel progress updates.
	CHANNEL_TICK = 0.1,
	-- Seconds: a held channel re-sends its start this often, so a channel the server ended resumes while
	-- the button is still held.
	CHANNEL_RESEND_INTERVAL = 0.5,
})
