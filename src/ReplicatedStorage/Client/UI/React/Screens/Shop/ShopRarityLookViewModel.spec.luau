local VM = require(script.Parent.ShopRarityLookViewModel)

local TIERS = { "default", "uncommon", "rare", "epic", "legendary", "odd" }

local function brightness(color)
	return color.R + color.G + color.B
end

return function()
	describe("look", function()
		it("gives every tier its own backdrop colours, light at the top", function()
			local seen = {}
			for _, tier in TIERS do
				local look = VM.look(tier)
				local key = look.top:ToHex() .. look.bottom:ToHex()
				expect(seen[key]).to.equal(nil)
				seen[key] = true
				expect(brightness(look.top) > brightness(look.bottom)).to.equal(true)
			end
		end)

		it("shows the tier's name behind the model, in words a player reads on the flag", function()
			expect(VM.look("default").word).to.equal("COMMON")
			expect(VM.look("legendary").word).to.equal("LEGENDARY")
			expect(VM.look("odd").word).to.equal("ODD")
		end)

		it("keeps the name faint so it never competes with the item", function()
			for _, tier in TIERS do
				expect(VM.look(tier).wordTransparency >= 0.5).to.equal(true)
			end
		end)

		it("has no rays for Common and Uncommon, and stronger rays up the ladder", function()
			expect(VM.look("default").rays).to.equal(nil)
			expect(VM.look("uncommon").rays).to.equal(nil)
			local rare = VM.look("rare").rays
			local epic = VM.look("epic").rays
			local legendary = VM.look("legendary").rays
			expect(rare ~= nil and epic ~= nil and legendary ~= nil).to.equal(true)
			expect(epic.transparency < rare.transparency).to.equal(true)
			expect(legendary.transparency < epic.transparency).to.equal(true)
		end)

		it("gives only Legendary a second ray layer", function()
			for _, tier in TIERS do
				expect(VM.look(tier).counterRays ~= nil).to.equal(tier == "legendary")
			end
		end)

		it("gives only Odd the goo and the red screen edges, with no rays", function()
			for _, tier in TIERS do
				local look = VM.look(tier)
				expect(look.goo).to.equal(tier == "odd")
				expect(look.edge ~= nil).to.equal(tier == "odd")
			end
			expect(VM.look("odd").rays).to.equal(nil)
		end)
	end)
end
