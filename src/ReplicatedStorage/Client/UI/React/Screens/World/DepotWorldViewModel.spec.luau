local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotWorldViewModel = require(script.Parent.DepotWorldViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local NOW = 1000

-- A queue pad snapshot: `left` seconds on its countdown (nil: no countdown), optionally departing.
local function pad(members, left, departing)
	return {
		members = members,
		capacity = 4,
		destination = "shift",
		endsAt = if left ~= nil then NOW + left else nil,
		departing = departing == true,
	}
end

-- The public player map, from userId -> truck number.
local function players(trucks)
	local map = {}
	for userId, truck in trucks do
		map[tostring(userId)] = { [DepotConstants.PUBLIC_TRUCK] = truck }
	end
	return map
end

return function()
	describe("truckTag", function()
		it("shows an empty truck with open seats and how to join", function()
			local tag = DepotWorldViewModel.truckTag(1, 4, nil, NOW)
			expect(tag.title).to.equal("TRUCK 1")
			expect(#tag.seats).to.equal(4)
			for _, filled in tag.seats do
				expect(filled).to.equal(false)
			end
			expect(tag.count).to.equal("0 / 4 ABOARD")
			expect(tag.line).to.equal("Stand in the bed to join")
			expect(tag.warn).to.equal(false)
		end)

		it("fills a seat per player aboard and keeps the join line while time is left", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 11, 12 }, 15), NOW)
			expect(tag.seats[1]).to.equal(true)
			expect(tag.seats[2]).to.equal(true)
			expect(tag.seats[3]).to.equal(false)
			expect(tag.seats[4]).to.equal(false)
			expect(tag.count).to.equal("2 / 4 ABOARD")
			expect(tag.line).to.equal("Stand in the bed to join")
			expect(tag.warn).to.equal(false)
		end)

		it("counts down in red when the truck is full", function()
			local tag = DepotWorldViewModel.truckTag(3, 4, pad({ 1, 2, 3, 4 }, 30), NOW)
			expect(tag.count).to.equal("4 / 4 ABOARD")
			expect(tag.line).to.equal("Leaving in 0:30")
			expect(tag.warn).to.equal(true)
		end)

		it("counts down in red once TAG_WARN_SECONDS or fewer remain", function()
			local warn = DepotConstants.TAG_WARN_SECONDS
			local at = DepotWorldViewModel.truckTag(1, 4, pad({ 1 }, warn), NOW)
			expect(at.line).to.equal(`Leaving in 0:{string.format("%02d", warn)}`)
			expect(at.warn).to.equal(true)
			local before = DepotWorldViewModel.truckTag(1, 4, pad({ 1 }, warn + 0.5), NOW)
			expect(before.line).to.equal("Stand in the bed to join")
			expect(before.warn).to.equal(false)
		end)

		it("says the truck is leaving while it departs", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, nil, true), NOW)
			expect(tag.line).to.equal("Leaving now")
			expect(tag.warn).to.equal(true)
		end)

		it("never counts below 0:00", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2, 3, 4 }, -3), NOW)
			expect(tag.line).to.equal("Leaving in 0:00")
		end)
	end)

	describe("padFor", function()
		it("finds the pad whose crew stand in the truck", function()
			local snapshot = { pads = { a = pad({ 11 }, 10), b = pad({ 21, 22 }, 12) } }
			local found = DepotWorldViewModel.padFor(snapshot, 2, players({ [11] = 1, [21] = 2, [22] = 2 }))
			expect(found).to.equal(snapshot.pads.b)
		end)

		it("finds nothing for an empty truck, no snapshot, or crew without a truck field", function()
			local snapshot = { pads = { a = pad({ 11 }, 10) } }
			expect(DepotWorldViewModel.padFor(snapshot, 3, players({ [11] = 1 }))).to.equal(nil)
			expect(DepotWorldViewModel.padFor(nil, 1, players({ [11] = 1 }))).to.equal(nil)
			expect(DepotWorldViewModel.padFor(snapshot, 1, {})).to.equal(nil)
		end)
	end)

	describe("sameTag", function()
		it("is the same tag only when every drawn line matches", function()
			local a = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW))).to.equal(
				true
			)
			-- 0.2 s later the clock still reads 0:09: nothing to re-render.
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW + 0.2))).to.equal(
				true
			)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 8), NOW))).to.equal(
				false
			)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2, 3 }, 9), NOW))).to.equal(
				false
			)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(1, 4, pad({ 1, 2 }, 9), NOW))).to.equal(
				false
			)
			expect(DepotWorldViewModel.sameTag(nil, a)).to.equal(false)
			expect(DepotWorldViewModel.sameTag(a, nil)).to.equal(false)
			expect(DepotWorldViewModel.sameTag(nil, nil)).to.equal(true)
		end)
	end)
end
