--!strict
--[=[
	UILayerConstants: the fixed, ordered UI layer ladder.

	Every player-facing React root lives in exactly one layer, and each layer has an EXPLICIT
	`DisplayOrder`. This is deliberate: the census of the old game found `DisplayOrder` left at 0 on
	nearly every one of its 21 ScreenGuis, so on-screen layering emerged from Explorer sibling order
	and needed startup code to correct nine screens by hand. Here the order is data.

	The ladder is declared in full even though this phase only populates `Hud`, `Panel`, and `Debug`
	— mapping the whole order space is what keeps the next screen from picking an arbitrary order.
	`UILayers` creates a layer's actual ScreenGui root lazily, so `Wheel` and `Overlay` cost nothing
	until something registers into them.

	@class UILayerConstants
]=]

--[=[
	The name of a UI layer. A closed set — new layers are added here, never invented at a call site.
]=]
export type LayerName = "Hud" | "Panel" | "Wheel" | "Overlay" | "Debug"

export type LayerDef = {
	name: LayerName,
	displayOrder: number,
}

-- Ordered low → high. The gaps (10, 100, 200, …) leave room to slot a future layer between two
-- existing ones without renumbering. `Debug` sits far above everything so the F4 overlay always
-- draws over gameplay UI.
local LAYERS: { LayerDef } = {
	{ name = "Hud", displayOrder = 10 },
	{ name = "Panel", displayOrder = 100 },
	{ name = "Wheel", displayOrder = 200 },
	{ name = "Overlay", displayOrder = 300 },
	{ name = "Debug", displayOrder = 1000 },
}

-- Freeze each entry and the list, so the ladder can never be mutated at runtime (the "authored state
-- disagrees with runtime state" failure mode the census caught).
for _, layer in LAYERS do
	table.freeze(layer)
end
table.freeze(LAYERS)

local ORDER_BY_NAME: { [string]: number } = {}
for _, layer in LAYERS do
	ORDER_BY_NAME[layer.name] = layer.displayOrder
end
table.freeze(ORDER_BY_NAME)

local UILayerConstants = {
	LAYERS = LAYERS,
}

--[=[
	Returns the `DisplayOrder` for a layer, erroring on an unknown name so a typo fails loudly at the
	call site rather than silently mounting a root at order 0.
	@param name string -- A layer name (widens to string across the useAtom/generic boundary)
	@return number -- The layer's DisplayOrder
]=]
function UILayerConstants.orderOf(name: string): number
	local order = ORDER_BY_NAME[name]
	if order == nil then
		error(`UILayerConstants: no such layer "{name}"`, 2)
	end
	return order
end

--[=[
	Whether `name` is a declared layer.
	@param name string
	@return boolean
]=]
function UILayerConstants.isLayer(name: string): boolean
	return ORDER_BY_NAME[name] ~= nil
end

return UILayerConstants
