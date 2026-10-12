--!strict
--[=[
	UIBillboards: the pure bookkeeping core for world-sign roots (M3b world UI), the UILayers pattern for BillboardGui
	shells. One React root per shell for the shell's whole life: the first `show` makes it through the injected factory,
	every later `show` renders into the same root (a refresh never remounts, so a stamp does not re-pop and a memo does
	not restart typing), `hide` destroys it and forgets the shell, `teardown` destroys every root. The real
	Instance/ReactRoblox factory is UIBillboardHost.factory; the specs pass a spy.

	A hide forgets the shell BEFORE it unmounts, so a hide that re-enters while the root unmounts (a Destroying handler)
	is a no-op and the root is destroyed exactly once.

	@class UIBillboards
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

--[=[
	One shell's live root, as the factory makes it. `render` draws into it; `unmount` tears the React tree down;
	`destroy` removes the root's container and MUST follow `unmount`.
]=]
export type BillboardHandle = {
	render: (element: React.ReactNode) -> (),
	unmount: () -> (),
	destroy: () -> (),
}

export type WorldShell = BillboardGui | SurfaceGui

export type BillboardFactory = (shell: WorldShell) -> BillboardHandle

export type UIBillboardsCore = {
	show: (shell: WorldShell, element: React.ReactNode) -> (),
	hide: (shell: WorldShell) -> (),
	teardown: () -> (),
	count: () -> number,
}

local UIBillboards = {}

function UIBillboards.new(factory: BillboardFactory): UIBillboardsCore
	local handles: { [WorldShell]: BillboardHandle } = {}
	-- Creation order, so teardown is deterministic.
	local order: { WorldShell } = {}

	local function show(shell: WorldShell, element: React.ReactNode)
		local handle = handles[shell]
		if handle == nil then
			handle = factory(shell)
			handles[shell] = handle
			table.insert(order, shell)
		end
		handle.render(element)
	end

	local function hide(shell: WorldShell)
		local handle = handles[shell]
		if handle == nil then
			return
		end
		-- Forgotten first: a hide that re-enters during the unmount finds nothing.
		handles[shell] = nil
		local index = table.find(order, shell)
		if index ~= nil then
			table.remove(order, index)
		end
		handle.unmount()
		handle.destroy()
	end

	local function teardown()
		local shells = table.clone(order)
		for _, shell in shells do
			hide(shell)
		end
	end

	local function count(): number
		return #order
	end

	return {
		show = show,
		hide = hide,
		teardown = teardown,
		count = count,
	}
end

return UIBillboards
