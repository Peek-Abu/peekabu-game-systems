--!strict
--[=[
	TitleTypes: the shared type vocabulary of the titles registry (titles design spec, Decision 1).

	Every title is declared as a `TitleDef` in a domain module under `Constants/Titles/`, composed
	by `TitleRegistry`. The profile stores ONLY ids, so reshaping these definitions is always a
	registry edit and never a migration.

	@class TitleTypes
]=]

--[=[
	One registered title: PURE display metadata — nothing else ships in V1 (design spec Decision 1;
	rarity/gradients/effects deferred, YAGNI).
	@interface TitleDef
	.id string -- repeated on the entry so consumers holding a def never need its lookup key
	.displayName string -- shown by future display consumers; non-empty (registry-enforced)
	.color Color3 -- the title's display color
]=]
export type TitleDef = {
	id: string,
	displayName: string,
	color: Color3,
}

--[=[
	A domain module's export: entry key -> definition. Keys are stable ids unique ACROSS domains —
	the composed registry enforces that.
	@type TitleDomain { [string]: TitleDef }
]=]
export type TitleDomain = { [string]: TitleDef }

return {}
