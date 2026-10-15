--!strict
--[=[
	AnimationCarryRegistry: how each cargo kind is held (static data, per kind; never inferred from price or icon).

	The hold rules (AnimationCarryContactUtils.plan; every hold keeps the wrists neutral, only the shoulders and
	elbows aim the hands):

	- `oneHandHang`: may be held in ONE hand: only light kinds (the cargo `tiny` and `light` size classes), soft bags
	  and small items. It hangs from the relaxed right hand (the arm down by the side, 10-30 degrees out, 8 forward)
	  by its tie or handle (`CarryHandle` on the art; else its top) and swings from it, when it then clears the
	  floor and the body's side. Too big for that on this carrier (Pippa's relaxed hand is ~1.2 studs off the floor:
	  every bag), it is hugged with both arms instead (palms on its sides, low in front, under the chin), or carried
	  on the forearms when it is narrower than the shoulders.
	- `twoHandSupport`: rigid or heavier things, always two hands: on both forearms, palms up under its bottom, the
	  item riding on the upper torso.
	- `chest`: a small item cupped up at the chest from below, elbows out on a round-bodied carrier (no kind uses it
	  now: small items go in one hand).
	- `cart`: pushed ahead at its caller-owned offset, on the root (it does not bob with the walk).

	@class AnimationCarryRegistry
]=]
export type Style = "twoHandSupport" | "chest" | "oneHandHang" | "cart"
local styles: { [string]: Style } = {
	rubbishBag = "oneHandHang",
	dustBag = "oneHandHang",
	bottleBag = "oneHandHang",
	recyclingBox = "twoHandSupport",
	officePlant = "twoHandSupport",
	plaque = "oneHandHang",
	monitor = "twoHandSupport",
	waterJug = "twoHandSupport",
	printer = "twoHandSupport",
	coffeeMachine = "twoHandSupport",
	fishTank = "twoHandSupport",
	goldenStapler = "oneHandHang",
	filingCabinet = "cart",
}
table.freeze(styles)
local AnimationCarryRegistry = {}
function AnimationCarryRegistry.get(kind: string): Style
	return styles[kind] or "twoHandSupport"
end
return table.freeze(AnimationCarryRegistry)
