--!strict
--[=[
	HudRegistry: the persistent HUD's widget catalog. Each game registers its own widgets (a coin counter,
	a stamina bar, a quota meter, an objective tracker) at load; HudRoot renders them as siblings under its
	one hide gate. The framework itself registers nothing, so the base ships an empty HUD.

	Register before UIServiceClient starts (i.e. from a module required during client boot): HudRoot reads
	the catalog when it renders, and a widget registered later appears on the next re-render only.

	@class HudRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

-- A HUD widget reads its own reactive state (atoms) internally, so it takes no props.
export type HudWidget = () -> React.ReactNode

export type HudEntry = {
	key: string,
	component: HudWidget,
	-- Render order among siblings (lower first, so a higher order draws on top); ties break by key. Defaults to 0.
	order: number,
}

-- A widget's layer in HudRoot: the entry and the ZIndex its layer draws at (its rank in `list`, from 1).
export type HudLayer = {
	key: string,
	component: HudWidget,
	zIndex: number,
}

local entries: { [string]: HudEntry } = {}

local HudRegistry = {}

--[=[
	Registers a HUD widget under a unique key. Errors on a duplicate key.
	@param key string
	@param component HudWidget
	@param order number? -- render order (lower first), default 0
]=]
function HudRegistry.register(key: string, component: HudWidget, order: number?)
	if entries[key] ~= nil then
		error(`HudRegistry: widget "{key}" is already registered`, 2)
	end
	entries[key] = { key = key, component = component, order = order or 0 }
end

--[=[
	Whether a widget key is registered.
	@param key string
	@return boolean
]=]
function HudRegistry.has(key: string): boolean
	return entries[key] ~= nil
end

--[=[
	Every registered widget, sorted by order then key (a stable render order).
	@return { HudEntry }
]=]
function HudRegistry.list(): { HudEntry }
	local list: { HudEntry } = {}
	for _, entry in entries do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.key < b.key
	end)
	return list
end

--[=[
	Every widget's layer, in `list` order, with the ZIndex HudRoot draws it at (its rank, from 1): a higher order draws
	on top of a lower one, whatever ZIndex the widget's own root has (HudRoot's layers are siblings under
	ZIndexBehavior.Sibling, so a widget's ZIndexes only order things inside its own layer).
	@return { HudLayer }
]=]
function HudRegistry.layers(): { HudLayer }
	local layers: { HudLayer } = {}
	for index, entry in HudRegistry.list() do
		table.insert(layers, { key = entry.key, component = entry.component, zIndex = index })
	end
	return layers
end

return HudRegistry
