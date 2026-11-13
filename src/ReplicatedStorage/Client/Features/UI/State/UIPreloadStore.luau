--!strict
--[=[
	UIPreloadStore: how far this client's art preload is (UIPreloadSystem): `progress` (0..1, the share of essential
	batches done, the first load screen's bar) and `ready` (the essential art is in, or the wait ran out: the first load
	screen may lift). UIPreloadSystem writes it; the load screen (ShiftTransitSystem) reads it.

	@class UIPreloadStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local progress = Charm.atom(0)
local ready = Charm.atom(false)

local UIPreloadStore = { progress = progress, ready = ready }

function UIPreloadStore.reset()
	progress(0)
	ready(false)
end

return UIPreloadStore
