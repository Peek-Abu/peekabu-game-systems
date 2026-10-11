--!strict
--[=[
	UIBillboardHost: the real Instance/ReactRoblox side of the world signs (M3b world UI), behind the specced UIBillboards
	core (the UILayerHost pattern).

	- `factory(shell)`: a child Frame "WorldRoot" filling the shell and a ReactRoblox root in it. A React root clears its
	  container, so it never mounts into the server-built shell itself. `unmount` is synchronous (ReactRobloxRoot wraps it
	  in flushSync); `destroy` removes the Frame.
	- `watch(options)`: every BillboardGui carrying `tag` (already tagged, or tagged later) gets `refresh(shell)` once and
	  again on each attribute change; the caller decides what to show (`roots.show`). A shell that leaves (untagged,
	  removed from the DataModel, streamed out, or destroyed, directly or with its part) is dropped once:
	  its connections are cut, `roots.hide(shell)` runs and then `removed(shell)`. `Destroying` fires before the
	  instance is destroyed, while its children can still be unmounted. Returns the stop function, which drops every
	  watched shell.

	Spec-exempt shell (ReactRoblox, CollectionService, Instance events); the root bookkeeping is the specced UIBillboards.

	@class UIBillboardHost
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)

export type WatchOptions = {
	tag: string,
	roots: UIBillboards.UIBillboardsCore,
	-- Draws (or re-draws) one shell: when it is first seen and whenever one of its attributes changes.
	refresh: (shell: BillboardGui) -> (),
	-- After a shell left and its root was hidden.
	removed: ((shell: BillboardGui) -> ())?,
}

local ROOT_NAME = "WorldRoot"

local UIBillboardHost = {}

function UIBillboardHost.factory(shell: BillboardGui): UIBillboards.BillboardHandle
	local container = Instance.new("Frame")
	container.Name = ROOT_NAME
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = shell
	local root = ReactRoblox.createRoot(container)
	return {
		render = function(element: React.ReactNode)
			root:render(element)
		end,
		unmount = function()
			root:unmount()
		end,
		destroy = function()
			container:Destroy()
		end,
	}
end

function UIBillboardHost.watch(options: WatchOptions): () -> ()
	local watched: { [BillboardGui]: { RBXScriptConnection } } = {}

	local function drop(shell: BillboardGui)
		local connections = watched[shell]
		if connections == nil then
			return
		end
		watched[shell] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
		options.roots.hide(shell)
		local removed = options.removed
		if removed ~= nil then
			removed(shell)
		end
	end

	local function add(instance: Instance)
		if not instance:IsA("BillboardGui") then
			return
		end
		local shell: BillboardGui = instance
		if watched[shell] ~= nil then
			return
		end
		watched[shell] = {
			shell.AttributeChanged:Connect(function(_attribute: string)
				options.refresh(shell)
			end),
			shell.Destroying:Connect(function()
				drop(shell)
			end),
			shell.AncestryChanged:Connect(function()
				if not shell:IsDescendantOf(game) then
					drop(shell)
				end
			end),
		}
		options.refresh(shell)
	end

	local added = CollectionService:GetInstanceAddedSignal(options.tag):Connect(add)
	local removedSignal = CollectionService:GetInstanceRemovedSignal(options.tag):Connect(function(instance: Instance)
		if instance:IsA("BillboardGui") then
			drop(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(options.tag) do
		add(instance)
	end

	return function()
		added:Disconnect()
		removedSignal:Disconnect()
		local shells: { BillboardGui } = {}
		for shell in watched do
			table.insert(shells, shell)
		end
		for _, shell in shells do
			drop(shell)
		end
	end
end

return UIBillboardHost
