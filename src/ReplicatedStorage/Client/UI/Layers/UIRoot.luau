--!strict
--[=[
	UIRoot: the shared, process-wide UI layer singleton.

	Wires the pure UILayers core to the real UILayerHost factory, once, and re-exports it. Every UI
	consumer requires THIS module and calls `UIRoot.acquire(layerName)` — services share it by module
	identity, not through ServiceController (see ServiceController's note against `getService`). Kept
	as its own module (rather than a field on UILayers) so the UILayers core never references the
	Instance/renderer shell, which would make the two cyclically dependent.

	Exempt from the spec-first rule: it is one expression of wiring with nothing of ours to assert —
	the bookkeeping is specced in UILayers.spec, the Instance factory is the UILayerHost shell.

	@class UIRoot
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UILayers = require(ReplicatedStorage.Client.UI.Layers.UILayers)
local UILayerHost = require(ReplicatedStorage.Client.UI.Layers.UILayerHost)

-- Constructing the core is pure (no Instances until a layer is acquired), so building it eagerly at
-- require time is safe and keeps consumers from each holding their own instance.
local UIRoot: UILayers.UILayersCore = UILayers.new(UILayerHost.factory)

return UIRoot
