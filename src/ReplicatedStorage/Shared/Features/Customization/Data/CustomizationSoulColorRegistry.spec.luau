--!strict
--[=[
	Unit tests for CustomizationSoulColorRegistry — the soul-colour catalog and the pure resolution of an id (single
	or multi-hue) into a dominant colour and gradient stops.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationSoulColorRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationSoulColorRegistry)

return function()
	describe("isRegistered", function()
		it("accepts a single registered hue", function()
			expect(CustomizationSoulColorRegistry.isRegistered("blue")).to.equal(true)
			expect(CustomizationSoulColorRegistry.isRegistered("black")).to.equal(true)
		end)

		it("accepts a multi-hue id — ONE soul carrying two hues, not two souls", function()
			expect(CustomizationSoulColorRegistry.isRegistered("blue-green")).to.equal(true)
		end)

		it("rejects an unknown hue, empty string, and a non-string", function()
			expect(CustomizationSoulColorRegistry.isRegistered("chartreuse")).to.equal(false)
			expect(CustomizationSoulColorRegistry.isRegistered("blue-chartreuse")).to.equal(false)
			expect(CustomizationSoulColorRegistry.isRegistered("")).to.equal(false)
			expect(CustomizationSoulColorRegistry.isRegistered(42)).to.equal(false)
		end)

		it("rejects more hues than MAX_HUES", function()
			local tooMany =
				table.concat({ "blue", "green", "pink", "white" }, CustomizationSoulColorRegistry.HUE_SEPARATOR)
			expect(CustomizationSoulColorRegistry.isRegistered(tooMany)).to.equal(false)
		end)
	end)

	describe("dominantColor", function()
		it("returns a single hue's own colour", function()
			local white = CustomizationSoulColorRegistry.dominantColor("white")
			expect(white.r).to.equal(255)
			expect(white.g).to.equal(255)
			expect(white.b).to.equal(255)
		end)

		it("averages a multi-hue id rather than picking the first hue", function()
			-- white (255,255,255) + black (0,0,0) -> 127 each, floored.
			local mixed = CustomizationSoulColorRegistry.dominantColor("white-black")
			expect(mixed.r).to.equal(127)
			expect(mixed.g).to.equal(127)
			expect(mixed.b).to.equal(127)
		end)

		it("returns integers, never fractions", function()
			local mixed = CustomizationSoulColorRegistry.dominantColor("white-black")
			expect(mixed.r % 1).to.equal(0)
		end)

		it("returns nil for an unregistered id", function()
			expect(CustomizationSoulColorRegistry.dominantColor("chartreuse")).to.equal(nil)
		end)
	end)

	describe("gradient", function()
		it("gives a single hue one stop at 0", function()
			local stops = CustomizationSoulColorRegistry.gradient("blue")
			expect(#stops).to.equal(1)
			expect(stops[1].position).to.equal(0)
		end)

		it("spreads a two-hue soul across 0..1 in hue order", function()
			local stops = CustomizationSoulColorRegistry.gradient("white-black")
			expect(#stops).to.equal(2)
			expect(stops[1].position).to.equal(0)
			expect(stops[2].position).to.equal(1)
			expect(stops[1].color.r).to.equal(255)
			expect(stops[2].color.r).to.equal(0)
		end)

		-- Order is significant: the two ids are different souls that render differently, so neither is
		-- normalised into the other.
		it("treats reversed hue order as a different gradient", function()
			local forward = CustomizationSoulColorRegistry.gradient("white-black")
			local reversed = CustomizationSoulColorRegistry.gradient("black-white")
			expect(forward[1].color.r).to.equal(255)
			expect(reversed[1].color.r).to.equal(0)
		end)

		it("returns nil for an unregistered id", function()
			expect(CustomizationSoulColorRegistry.gradient("blue-chartreuse")).to.equal(nil)
		end)
	end)

	describe("hueNames", function()
		it("lists the single hues sorted, for enums and UI lists", function()
			local names = CustomizationSoulColorRegistry.hueNames()
			expect(#names > 1).to.equal(true)
			for index = 2, #names do
				expect(names[index - 1] < names[index]).to.equal(true)
			end
		end)
	end)
end
