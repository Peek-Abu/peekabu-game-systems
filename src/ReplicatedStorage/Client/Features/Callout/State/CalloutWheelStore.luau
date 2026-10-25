--!strict
--[=[
	CalloutWheelStore: the chat wheel's state: whether it is open, what the pointer leans toward (what a released T
	sends), and the spot a ping would mark (aimed when T went down). Charm atoms the wheel screen writes and
	CalloutServiceClient reads.

	@class CalloutWheelStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Pick = { kind: "ping", id: string } | { kind: "sticker", slot: number }

local noPick: Pick? = nil
local noSpot: Vector3? = nil
local open = Charm.atom(false)
local hovered = Charm.atom(noPick)
local aim = Charm.atom(noSpot)

local CalloutWheelStore = {
	open = open,
	hovered = hovered,
	aim = aim,
}

function CalloutWheelStore.show(spot: Vector3?)
	hovered(nil)
	aim(spot)
	open(true)
end

-- Closes the wheel; hands back what was leaned toward and the aimed spot.
function CalloutWheelStore.hide(): (Pick?, Vector3?)
	local pick, spot = hovered(), aim()
	hovered(nil)
	aim(nil)
	open(false)
	return pick, spot
end

function CalloutWheelStore.hover(pick: Pick?)
	hovered(pick)
end

-- Forgets everything (between specs).
function CalloutWheelStore.reset()
	open(false)
	hovered(nil)
	aim(nil)
end

return CalloutWheelStore
