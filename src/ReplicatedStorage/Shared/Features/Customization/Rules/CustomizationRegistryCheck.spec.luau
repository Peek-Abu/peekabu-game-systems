--!strict
--[=[
	Unit tests for CustomizationRegistryCheck — the registry's load-time assertions, now testable because they
	take their value as an argument instead of running only at module load. Each case constructs the
	malformed shape the rule exists to reject, which was impossible while the logic lived inline.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationRegistryCheck =
	require(ReplicatedStorage.Shared.Features.Customization.Rules.CustomizationRegistryCheck)

return function()
	describe("assertColorComponent", function()
		it("accepts an in-range integer", function()
			expect(function()
				CustomizationRegistryCheck.assertColorComponent(0, "x")
				CustomizationRegistryCheck.assertColorComponent(255, "x")
			end).never.to.throw()
		end)

		it("rejects a fraction, a negative, an over-range value, and a non-number", function()
			for _, bad in { 0.5, -1, 256 } do
				expect(function()
					CustomizationRegistryCheck.assertColorComponent(bad, "x")
				end).to.throw()
			end
			expect(function()
				CustomizationRegistryCheck.assertColorComponent("nope" :: any, "x")
			end).to.throw()
		end)
	end)

	describe("assertSocketList", function()
		it("accepts nil — the field is optional", function()
			expect(function()
				CustomizationRegistryCheck.assertSocketList(nil, "cowl.occupies")
			end).never.to.throw()
		end)

		it("accepts a dense list of unique non-empty strings", function()
			expect(function()
				CustomizationRegistryCheck.assertSocketList({ "Head", "Chest" }, "cowl.occupies")
			end).never.to.throw()
		end)

		-- An empty list is worse than an absent one: #list reads 0 and the cosmetic silently never
		-- mounts, so the rule insists you omit the field instead.
		it("rejects an empty list", function()
			expect(function()
				CustomizationRegistryCheck.assertSocketList({}, "cowl.occupies")
			end).to.throw()
		end)

		-- A duplicate in `occupies` makes an accessory conflict with itself in the occupancy rule.
		it("rejects a duplicate", function()
			expect(function()
				CustomizationRegistryCheck.assertSocketList({ "Head", "Head" }, "cowl.occupies")
			end).to.throw()
		end)

		it("rejects a non-string or empty-string entry", function()
			expect(function()
				CustomizationRegistryCheck.assertSocketList({ "Head", "" }, "cowl.occupies")
			end).to.throw()
			expect(function()
				CustomizationRegistryCheck.assertSocketList({ "Head", 7 } :: any, "cowl.occupies")
			end).to.throw()
		end)

		it("rejects a sparse array (a hole makes #list disagree with the real count)", function()
			local sparse: { string } = {}
			sparse[1] = "Head"
			sparse[3] = "Chest"
			expect(function()
				CustomizationRegistryCheck.assertSocketList(sparse, "cowl.occupies")
			end).to.throw()
		end)
	end)
end
