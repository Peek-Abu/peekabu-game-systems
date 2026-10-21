local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local DeathKnockdownUtils = require(script.Parent.DeathKnockdownUtils)

return function()
	local THROW = Vector3.new(30, 35, 0)

	describe("launchOf", function()
		it("reads the throw from a knockdown's value and nothing from anything else", function()
			expect(DeathKnockdownUtils.launchOf(THROW)).to.equal(THROW)
			expect(DeathKnockdownUtils.launchOf(nil)).to.equal(nil)
			expect(DeathKnockdownUtils.launchOf(true)).to.equal(nil)
		end)
	end)

	describe("isDown", function()
		it("is down while the attribute holds a throw, and up once it is cleared", function()
			local character = Instance.new("Model")
			expect(DeathKnockdownUtils.isDown(character)).to.equal(false)
			character:SetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE, THROW)
			expect(DeathKnockdownUtils.isDown(character)).to.equal(true)
			character:SetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE, nil)
			expect(DeathKnockdownUtils.isDown(character)).to.equal(false)
			character:Destroy()
		end)

		it("is never down without a character (a reset: the new character carries no knockdown)", function()
			expect(DeathKnockdownUtils.isDown(nil)).to.equal(false)
		end)
	end)

	describe("standsUp", function()
		it("lets a knockdown's own timer stand the character up", function()
			expect(DeathKnockdownUtils.standsUp(1, 1)).to.equal(true)
		end)

		it("leaves a later knockdown down, and one already stood up alone", function()
			expect(DeathKnockdownUtils.standsUp(2, 1)).to.equal(false)
			expect(DeathKnockdownUtils.standsUp(nil, 1)).to.equal(false)
		end)
	end)

	describe("next", function()
		it("goes down for the hit, then gets up when the server clears it", function()
			expect(DeathKnockdownUtils.next(false, THROW, true)).to.equal("fall")
			expect(DeathKnockdownUtils.next(true, nil, true)).to.equal("rise")
		end)

		it("gets up when a reset or the shift's end clears it mid-knockdown", function()
			expect(DeathKnockdownUtils.next(true, nil, true)).to.equal("rise")
		end)

		it("takes a new throw while already down", function()
			expect(DeathKnockdownUtils.next(true, THROW, true)).to.equal("fall")
		end)

		it("gives the controls back but never stands up a body that died", function()
			expect(DeathKnockdownUtils.next(true, THROW, false)).to.equal("release")
			expect(DeathKnockdownUtils.next(true, nil, false)).to.equal("release")
			expect(DeathKnockdownUtils.next(false, THROW, false)).to.equal("none")
		end)

		it("does nothing for a character that was never down", function()
			expect(DeathKnockdownUtils.next(false, nil, true)).to.equal("none")
		end)
	end)
end
