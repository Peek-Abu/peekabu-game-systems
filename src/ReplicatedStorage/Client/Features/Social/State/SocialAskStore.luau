--!strict
--[=[
	SocialAskStore: whether the favorite/like ask card is up (SocialAskCard), and which shift's review last showed it,
	so one review never asks twice.

	@class SocialAskStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local visible = Charm.atom(false)
-- The shift number whose review showed the ask (0 = none yet).
local askedShift = Charm.atom(0)

local SocialAskStore = {
	visible = visible,
	askedShift = askedShift,
}

-- Shows the ask for shift `shift`'s review; false (and nothing shown) when that review already asked.
function SocialAskStore.show(shift: number): boolean
	if askedShift() == shift then
		return false
	end
	askedShift(shift)
	visible(true)
	return true
end

function SocialAskStore.hide()
	visible(false)
end

function SocialAskStore.reset()
	visible(false)
	askedShift(0)
end

return SocialAskStore
