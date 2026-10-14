--!strict
-- Grasp intent is per cargo, not inferred from its price or an unrelated icon. Every style holds with two
-- hands when both reach (AnimationCarryContactUtils); "handle" and "small" items settle for one.
export type Style = "handle" | "small" | "twoHand"
local styles: { [string]: Style } = {
	rubbishBag = "handle",
	dustBag = "handle",
	bottleBag = "handle",
	recyclingBox = "twoHand",
	officePlant = "twoHand",
	plaque = "small",
	monitor = "twoHand",
	waterJug = "twoHand",
	printer = "twoHand",
	coffeeMachine = "twoHand",
	fishTank = "twoHand",
	goldenStapler = "small",
	filingCabinet = "twoHand",
}
table.freeze(styles)
local AnimationCarryRegistry = {}
function AnimationCarryRegistry.get(kind: string): Style
	return styles[kind] or "twoHand"
end
return table.freeze(AnimationCarryRegistry)
