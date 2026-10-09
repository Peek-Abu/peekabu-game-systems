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
})
