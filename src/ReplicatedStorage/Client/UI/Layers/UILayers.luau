--!strict
--[=[
	UILayers: the pure bookkeeping core for UI layer roots — lazy acquisition, caching, ordered
	teardown. `new(factory)` takes an injectable factory so this runs with no PlayerGui and no
	renderer; the real Instance/ReactRoblox factory is UILayerHost, and `UIRoot` wires the two into
	the shared singleton every UI consumer requires.

	**Why a layer owns the root, not each screen:** the engine only honours `ResetOnSpawn = false` on
	a LayerCollector that is a DIRECT child of PlayerGui — a ScreenGui nested inside a Folder is
	invisible to the respawn-reset scan, is destroyed on death, and never returns because a service
	`start()` mounts once. A slot switch respawns the character, so this bit hard. Centralising root
	creation here means no screen ever news its own ScreenGui (a CI gate enforces it), and the
	`ResetOnSpawn` handling lives in exactly one place: UILayerHost.

	Roots are created lazily — a layer costs nothing until a screen registers into it — so the `Wheel`
	and `Overlay` rungs of the ladder mount nothing this phase.

	@class UILayers
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UILayerConstants = require(ReplicatedStorage.Client.UI.Layers.UILayerConstants)

type LayerName = UILayerConstants.LayerName

--[=[
	One layer's live root, as the factory produces it. `render` draws a React element into the layer's
	root; `unmount` tears down the React tree; `destroy` removes the host ScreenGui and MUST be called
	after `unmount` (unmount alone leaves the container parented under PlayerGui — the leak the old
	DebuggerServiceClient documented).
]=]
export type LayerHandle = {
	render: (element: React.ReactNode) -> (),
	unmount: () -> (),
	destroy: () -> (),
}

--[=[
	Creates a layer's live root for `layerName` at `displayOrder`. Injected so the bookkeeping core is
	testable without a renderer; the real implementation is UILayerHost.factory.
]=]
export type LayerFactory = (layerName: LayerName, displayOrder: number) -> LayerHandle

--[=[
	The bookkeeping core: lazy acquisition, caching, ordered teardown. Closure-based rather than a
	`self` table so there are no `self` casts (the project's service-shape rule) and each instance's
	state is fully private.
]=]
export type UILayersCore = {
	acquire: (layerName: LayerName) -> (element: React.ReactNode) -> (),
	teardown: () -> (),
}

local UILayers = {}

--[=[
	Builds a bookkeeping core over `factory`. Used directly by specs with a fake factory; UIRoot uses
	the real UILayerHost factory to build the shared singleton.
	@param factory LayerFactory -- Produces a layer's live root
	@return UILayersCore
]=]
function UILayers.new(factory: LayerFactory): UILayersCore
	-- Keyed by plain string, not LayerName: indexing a `{ [LayerName]: … }` table with a
	-- union-of-singletons key trips a Luau typechecker limitation (same reason StateSyncClientStore's atom
	-- registry is string-keyed). The public API stays narrow — `acquire` takes a LayerName.
	local handles: { [string]: LayerHandle } = {}
	-- Acquisition order, so teardown is deterministic (matches the order roots were created).
	local order: { string } = {}

	local function acquire(layerName: LayerName): (element: React.ReactNode) -> ()
		local handle = handles[layerName]
		if handle == nil then
			-- orderOf validates the name (errors on a typo) BEFORE the factory runs, so an unknown
			-- layer never creates a partial root.
			local displayOrder = UILayerConstants.orderOf(layerName)
			handle = factory(layerName, displayOrder)
			handles[layerName] = handle
			table.insert(order, layerName)
		end
		return handle.render
	end

	local function teardown()
		-- Numeric loop, not `for _, name in order`: the generic iterator widens a `{LayerName}`
		-- element to plain `string`, which then fails the `handles[...]` lookup (keyed by LayerName).
		for index = 1, #order do
			local layerName = order[index]
			local handle = handles[layerName]
			handle.unmount()
			handle.destroy()
		end
		table.clear(handles)
		table.clear(order)
	end

	return {
		acquire = acquire,
		teardown = teardown,
	}
end

return UILayers
