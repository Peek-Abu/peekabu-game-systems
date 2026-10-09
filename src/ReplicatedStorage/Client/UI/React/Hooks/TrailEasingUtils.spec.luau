--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrailEasingUtils = require(ReplicatedStorage.Client.UI.React.Hooks.TrailEasingUtils)

return function()
	describe("approach", function()
		it("returns the target when already there", function()
			expect(TrailEasingUtils.approach(0.5, 0.5, 10, 10, 1 / 60)).to.equal(0.5)
		end)

		it("moves partway toward a higher target using the up rate", function()
			-- factor = dt*rate = 0.1*2 = 0.2; 0 + (1-0)*0.2 = 0.2
			local result = TrailEasingUtils.approach(0, 1, 2, 100, 0.1)
			expect(result).to.be.near(0.2, 1e-6)
		end)

		it("moves partway toward a lower target using the down rate", function()
			-- factor = 0.1*2 = 0.2; 1 + (0-1)*0.2 = 0.8
			local result = TrailEasingUtils.approach(1, 0, 100, 2, 0.1)
			expect(result).to.be.near(0.8, 1e-6)
		end)

		it("uses the up rate, not the down rate, when moving up", function()
			-- up rate 5 vs down rate 1: a big up rate should close most of the gap
			local up = TrailEasingUtils.approach(0, 1, 5, 1, 0.1) -- factor 0.5 -> 0.5
			expect(up).to.be.near(0.5, 1e-6)
		end)

		it("never overshoots — a large dt*rate clamps to the target", function()
			expect(TrailEasingUtils.approach(0.2, 0.9, 100, 100, 1)).to.equal(0.9)
		end)

		it("snaps exactly onto the target within epsilon", function()
			-- current 0.9999 approaching 1: the eased value lands within 0.001, so it snaps to 1
			local result = TrailEasingUtils.approach(0.9999, 1, 1, 1, 1 / 60)
			expect(result).to.equal(1)
		end)
	end)
end
