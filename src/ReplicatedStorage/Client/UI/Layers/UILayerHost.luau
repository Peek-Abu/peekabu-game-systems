--!strict
--[=[
	UILayerHost: the real Instance/ReactRoblox factory for a UI layer root.

	This is the Instance-touching shell behind UILayers — the one place that news a `ScreenGui` and a
	`ReactRoblox.createRoot`. It is exempt from the spec-first rule (SpecRoots.EXEMPT_MODULES) for the
	same reason CustomizationDressSystem and AnimationPlayerEngineSystem are: every branch needs a live
	PlayerGui and a renderer, which TestEZ cannot fixture. The bookkeeping that decides WHEN a root is
	made and torn down lives in the pure UILayers core, which is fully specced.

	**The load-bearing detail:** the ScreenGui is parented DIRECTLY to PlayerGui with
	`ResetOnSpawn = false`. The engine only honours that property on a LayerCollector that is an
	immediate child of PlayerGui — nest it inside a Folder and the respawn reset destroys it, and it
	never comes back (documented at DebuggerServiceClient.luau, and it bites on every death and every
	slot switch). Do not reparent these roots under a container.

	@class UILayerHost
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILayers = require(ReplicatedStorage.Client.UI.Layers.UILayers)

local UILayerHost = {}

--[=[
	Creates a layer's ScreenGui (direct child of PlayerGui, `ResetOnSpawn = false`, explicit
	`DisplayOrder`) and a ReactRoblox root on it, returning the LayerHandle UILayers caches.
	@param layerName string -- The layer's name (used for the ScreenGui name)
	@param displayOrder number -- The layer's DisplayOrder from the ladder
	@return UILayers.LayerHandle
]=]
function UILayerHost.factory(layerName: string, displayOrder: number): UILayers.LayerHandle
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local container = Instance.new("ScreenGui")
	container.Name = `UILayer_{layerName}`
	container.ResetOnSpawn = false -- survives respawns and slot switches (must be a direct PlayerGui child)
	container.IgnoreGuiInset = true -- roots span the full viewport; individual screens pad as needed
	container.DisplayOrder = displayOrder
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.Parent = playerGui

	local root = ReactRoblox.createRoot(container)

	return {
		render = function(element: React.ReactNode)
			root:render(element)
		end,
		unmount = function()
			root:unmount()
		end,
		destroy = function()
			-- Destroy AFTER unmount only; unmount tears down the React tree but leaves the container
			-- parented under PlayerGui, so destroying it here is what prevents an orphaned root.
			container:Destroy()
		end,
	}
end

return UILayerHost
