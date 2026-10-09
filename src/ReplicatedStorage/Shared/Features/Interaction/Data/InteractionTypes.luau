--!strict
--[=[
	InteractionTypes: the types the Interaction feature shares. Types only (spec-exempt).
	Design: docs/superpowers/specs/2026-10-09-interaction-design.md.

	@class InteractionTypes
]=]

export type InteractionDef = {
	-- The prompt's verb ("Open", "Pick up").
	actionText: string,
	-- The prompt's noun ("Door"); absent = the engine default (empty).
	objectText: string?,
	-- Seconds the key must be held; absent or 0 = a press.
	holdDuration: number?,
	-- Studs; absent = InteractionConstants.DEFAULT_MAX_DISTANCE.
	maxDistance: number?,
	-- Seconds before the same player may use the same object again; absent = none.
	cooldown: number?,
	requiresLineOfSight: boolean?,
}

return {}
