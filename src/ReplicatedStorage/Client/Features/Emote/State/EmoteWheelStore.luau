--!strict
--[=[
	EmoteWheelStore: the in-game emote wheel's state: whether it is open and which slot the pointer leans toward (the
	slot a released B plays). Charm atoms the wheel screen writes and EmoteServiceClient reads.

	@class EmoteWheelStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local noSlot: number? = nil
local open = Charm.atom(false)
local hovered = Charm.atom(noSlot)

local EmoteWheelStore = {
	open = open,
	hovered = hovered,
}

function EmoteWheelStore.show()
	hovered(nil)
	open(true)
end

-- Closes the wheel and hands back the slot that was leaned toward (nil = none).
function EmoteWheelStore.hide(): number?
	local slot = hovered()
	hovered(nil)
	open(false)
	return slot
end

function EmoteWheelStore.hover(slot: number?)
	hovered(slot)
end

-- Forgets everything (between specs).
function EmoteWheelStore.reset()
	open(false)
	hovered(nil)
end

return EmoteWheelStore
