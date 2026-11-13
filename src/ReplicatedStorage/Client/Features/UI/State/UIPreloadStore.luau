--!strict
--[=[
	UIPreloadStore: how far this client's art preload is (UIPreloadSystem): `progress` (0..1, the share of essential
	batches done, the first load screen's bar) and `ready` (the essential art is in, or the wait ran out: the first load
	screen may lift), and `screenReady` (the load screen's own art is in: the welcome card draws its Pippa only then, so
	she never shows half loaded). UIPreloadSystem writes it; the load screen (ShiftTransitSystem) reads it.

	@class UIPreloadStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local progress = Charm.atom(0)
local ready = Charm.atom(false)
local screenReady = Charm.atom(false)

local UIPreloadStore = { progress = progress, ready = ready, screenReady = screenReady }

function UIPreloadStore.reset()
	progress(0)
	ready(false)
	screenReady(false)
end

return UIPreloadStore
