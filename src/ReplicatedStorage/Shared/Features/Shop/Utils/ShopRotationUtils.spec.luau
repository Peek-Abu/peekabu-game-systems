local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopRotationUtils = require(script.Parent.ShopRotationUtils)

return function()
	-- 2026-10-24 12:00 UTC
	local NOON = 1792929600
	local DAY = ShopConstants.DAY

	local function ids(list)
		local out = {}
		for _, offer in list do
			table.insert(out, offer.id)
		end
		return table.concat(out, ",")
	end

	local function offer(id, pool, starts, ends)
		return { id = id, items = { id }, currency = "gleam", price = 10, pool = pool, starts = starts, ends = ends }
	end

	it("shows the same shop to every server on the same UTC day", function()
		local a = ShopRotationUtils.live(ShopRegistry.all(), NOON)
		local b = ShopRotationUtils.live(ShopRegistry.all(), NOON + 3600)
		expect(a.featured.id).to.equal(b.featured.id)
		expect(ids(a.picks)).to.equal(ids(b.picks))
	end)

	it("changes at the rotation hour and says when", function()
		local today = ShopRotationUtils.live(ShopRegistry.all(), NOON)
		expect(today.nextRotation > NOON).to.equal(true)
		expect(today.nextRotation - NOON <= DAY).to.equal(true)
		expect(today.nextRotation % DAY).to.equal(ShopConstants.ROTATION_HOUR_UTC * 3600)
		-- Over a week the featured banner takes turns.
		local seen = {}
		local count = 0
		for day = 0, 6 do
			local id = ShopRotationUtils.live(ShopRegistry.all(), NOON + day * DAY).featured.id
			if not seen[id] then
				seen[id] = true
				count += 1
			end
		end
		expect(count > 1).to.equal(true)
	end)

	it("picks up to PICKS distinct offers from the picks pool only", function()
		for day = 0, 9 do
			local live = ShopRotationUtils.live(ShopRegistry.all(), NOON + day * DAY)
			expect(#live.picks <= ShopConstants.PICKS).to.equal(true)
			local seen = {}
			for _, pick in live.picks do
				expect(pick.pool).to.equal("picks")
				expect(seen[pick.id]).to.equal(nil)
				seen[pick.id] = true
			end
		end
	end)

	it("sells an event offer only inside its dates, and flags its first days and its last", function()
		local offers = { offer("A", "picks", NOON - 3600, NOON + 3600), offer("B", "picks", NOON + DAY, nil) }
		expect(ShopRotationUtils.available(offers[1], NOON)).to.equal(true)
		expect(ShopRotationUtils.available(offers[1], NOON + 7200)).to.equal(false)
		expect(ShopRotationUtils.available(offers[2], NOON)).to.equal(false)
		local live = ShopRotationUtils.live(offers, NOON)
		expect(ids(live.picks)).to.equal("A")
		local flags = ShopRotationUtils.flags(offers[1], NOON)
		expect(table.find(flags, "new")).to.be.ok()
		expect(table.find(flags, "lastDay")).to.be.ok()
		expect(#ShopRotationUtils.flags(offer("C", "picks", nil, nil), NOON)).to.equal(0)
	end)

	it("copes with an empty catalogue", function()
		local live = ShopRotationUtils.live({}, NOON)
		expect(live.featured).to.equal(nil)
		expect(#live.picks).to.equal(0)
	end)
end
