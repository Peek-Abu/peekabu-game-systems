--!strict
--[=[
	AnimationCarryRegistry: how each cargo kind is held (static data, per kind; never inferred from price or icon).

	- `twoHandSupport`: on both forearms, palms up under its bottom, the item riding on the upper torso.
	- `chest`: a small item cupped up at the chest from below, elbows out on a round-bodied carrier.
	- `oneHandHang`: a soft bag hanging from one hand by its tie or handle (`CarryHandle` on the art), on that hand.
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
	plaque = "chest",
	monitor = "twoHandSupport",
	waterJug = "twoHandSupport",
	printer = "twoHandSupport",
	coffeeMachine = "twoHandSupport",
	fishTank = "twoHandSupport",
	goldenStapler = "chest",
	filingCabinet = "cart",
}
table.freeze(styles)
local AnimationCarryRegistry = {}
function AnimationCarryRegistry.get(kind: string): Style
	return styles[kind] or "twoHandSupport"
end
return table.freeze(AnimationCarryRegistry)
