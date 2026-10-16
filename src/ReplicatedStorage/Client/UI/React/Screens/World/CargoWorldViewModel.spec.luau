local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoWorldViewModel = require(script.Parent.CargoWorldViewModel)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local KEYS = CargoConstants.LABEL_KEYS

-- The attributes the server writes on an item's tag shell.
local function tag(name, category, value, fragile, impacts)
	return {
		[KEYS.name] = name,
		[KEYS.category] = category,
		[KEYS.value] = value,
		[KEYS.fragile] = fragile == true,
		[KEYS.impacts] = impacts or 0,
		[KEYS.hidden] = false,
	}
end

return function()
	describe("priceTag", function()
		it("prices a Recoverable Asset in dollars", function()
			local view = CargoWorldViewModel.priceTag(tag("Coffee machine", "salvage", 50))
			expect(view.name).to.equal("Coffee machine")
			expect(view.price).to.equal("$50")
			expect(view.cracked).to.equal(false)
			expect(view.mark).to.equal(nil)
		end)

		it("shows trash as the clearance it adds", function()
			expect(CargoWorldViewModel.priceTag(tag("Rubbish bag", "trash", 10)).price).to.equal("+10")
		end)

		it("marks an undamaged fragile item FRAGILE", function()
			local view = CargoWorldViewModel.priceTag(tag("Monitor", "salvage", 30, true, 0))
			expect(view.mark).to.equal("FRAGILE")
			expect(view.cracked).to.equal(false)
		end)

		it("marks a cracked item by the value it lost, from the fragile tiers", function()
			local tiers = CargoConstants.FRAGILE_TIERS
			local once = CargoWorldViewModel.priceTag(tag("Fish tank", "salvage", 35, true, 1))
			expect(once.mark).to.equal(`CRACKED −{math.floor((1 - tiers[2]) * 100 + 0.5)}%`)
			expect(once.mark).to.equal("CRACKED −50%")
			expect(once.cracked).to.equal(true)
			expect(once.price).to.equal("$35")
			local twice = CargoWorldViewModel.priceTag(tag("Fish tank", "salvage", 18, true, 2))
			expect(twice.mark).to.equal("CRACKED −75%")
			local many = CargoWorldViewModel.priceTag(tag("Fish tank", "salvage", 18, true, 9))
			expect(many.mark).to.equal("CRACKED −75%")
		end)

		it("puts no mark on a sturdy item, whatever its impacts", function()
			local view = CargoWorldViewModel.priceTag(tag("Coffee machine", "salvage", 50, false, 3))
			expect(view.mark).to.equal(nil)
			expect(view.cracked).to.equal(false)
		end)

		it("rounds a value to a whole price", function()
			expect(CargoWorldViewModel.priceTag(tag("Monitor", "salvage", 14.6)).price).to.equal("$15")
		end)

		it("keeps the longest catalog name whole", function()
			for _, id in CargoRegistry.ids() do
				local def = CargoRegistry.get(id)
				expect(CargoWorldViewModel.priceTag(tag(def.name, def.category, def.value)).name).to.equal(def.name)
			end
			local long = CargoWorldViewModel.priceTag(tag(string.rep("x", 40), "salvage", 1)).name
			expect(utf8.len(long)).to.equal(CargoWorldViewModel.NAME_MAX)
		end)

		it("draws no tag without a name and a value", function()
			expect(CargoWorldViewModel.priceTag({})).to.equal(nil)
			expect(CargoWorldViewModel.priceTag(tag(nil, "trash", 10))).to.equal(nil)
			expect(CargoWorldViewModel.priceTag(tag("Rubbish bag", "trash", "ten"))).to.equal(nil)
		end)
	end)

	describe("grime and appraisal", function()
		-- A valuable's tag: cleanliness 0-1, appraised or not, appraised at a server time.
		local function grimy(value, clean, appraised, appraisedAt, fragile, impacts)
			local attributes = tag("Monitor", "salvage", value, fragile, impacts)
			attributes[KEYS.grimy] = true
			attributes[KEYS.clean] = clean
			attributes[KEYS.appraised] = appraised
			attributes[KEYS.appraisedAt] = appraisedAt
			return attributes
		end

		it("hides an unappraised valuable's price and shows how clean it is", function()
			local view = CargoWorldViewModel.priceTag(grimy(30, 0, false), 0)
			expect(view.price).to.equal("$???")
			expect(view.mark).to.equal("0% CLEAN")
			expect(view.appraised).to.equal(false)
			expect(view.pop).to.equal(false)
		end)

		it("shows the value once appraised, and rounds the cleanliness down", function()
			local view = CargoWorldViewModel.priceTag(grimy(76, 0.669, true, 10), 100)
			expect(view.price).to.equal("$76")
			expect(view.mark).to.equal("66% CLEAN")
			expect(view.appraised).to.equal(true)
			expect(view.pop).to.equal(false)
		end)

		it("pops the APPRAISED stamp while the appraisal is fresh", function()
			expect(CargoWorldViewModel.priceTag(grimy(76, 0.7, true, 10), 11).pop).to.equal(true)
		end)

		it("drops the cleanliness from the mark once spotless", function()
			local view = CargoWorldViewModel.priceTag(grimy(100, 1, true, 10), 100)
			expect(view.mark).to.equal(nil)
		end)

		it("joins grime and the fragile mark", function()
			local view = CargoWorldViewModel.priceTag(grimy(20, 0.4, true, 1, true, 1), 100)
			expect(view.mark).to.equal("40% CLEAN · CRACKED −50%")
			expect(view.cracked).to.equal(true)
		end)

		it("marks a sealed valuable GRIME LOCKED at its cleanliness", function()
			local attributes = grimy(30, 0.62, false)
			attributes[KEYS.sealed] = true
			local view = CargoWorldViewModel.priceTag(attributes, 0)
			expect(view.mark).to.equal("GRIME LOCKED 62%")
			expect(view.price).to.equal("$???")
		end)

		it("joins the grime lock and the fragile mark", function()
			local attributes = grimy(20, 0.4, true, 1, true, 1)
			attributes[KEYS.sealed] = true
			expect(CargoWorldViewModel.priceTag(attributes, 100).mark).to.equal("GRIME LOCKED 40% · CRACKED −50%")
		end)

		it("leaves trash tags as they were", function()
			local view = CargoWorldViewModel.priceTag(tag("Rubbish bag", "trash", 10), 0)
			expect(view.appraised).to.equal(false)
			expect(view.mark).to.equal(nil)
		end)
	end)

	describe("mounted", function()
		it("mounts only within 24 studs, keeps until 28, never under a pile", function()
			expect(CargoConstants.LABEL_DISTANCE).to.equal(24)
			expect(CargoConstants.LABEL_KEEP_DISTANCE).to.equal(28)
			expect(CargoWorldViewModel.mounted(24, false, false)).to.equal(true)
			expect(CargoWorldViewModel.mounted(24.5, false, false)).to.equal(false)
			expect(CargoWorldViewModel.mounted(27, true, false)).to.equal(true)
			expect(CargoWorldViewModel.mounted(28, true, false)).to.equal(true)
			expect(CargoWorldViewModel.mounted(28.5, true, false)).to.equal(false)
			expect(CargoWorldViewModel.mounted(0, false, true)).to.equal(false)
			expect(CargoWorldViewModel.mounted(0, true, true)).to.equal(false)
		end)
	end)

	describe("floater", function()
		it("pops clearance as the number over CLEARED", function()
			local view = CargoWorldViewModel.floater({ text = "+15", tone = "clearance" })
			expect(view.bonus).to.equal(false)
			expect(view.text).to.equal("+15")
			expect(view.caption).to.equal("CLEARED")
		end)

		it("stamps the dollars earned with no caption", function()
			local view = CargoWorldViewModel.floater({ text = "+40", tone = "bonus" })
			expect(view.bonus).to.equal(true)
			expect(view.text).to.equal("+$40")
			expect(view.caption).to.equal(nil)
		end)
	end)
end
