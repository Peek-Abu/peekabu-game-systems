local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideViewModel = require(script.Parent.HideViewModel)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

local PROMPT = { id = 1, action = "Hide under", noun = "Desk", key = "C", hold = 0.6 }
local HIDDEN = { spotId = "locker.a", kind = "inside", noun = "locker", since = 100 }

return function()
	describe("chip", function()
		it("reads the spot's prompt with an empty hold strip", function()
			local view = HideViewModel.chip(PROMPT, nil, "C", 100, false)
			expect(view.text).to.equal("HIDE UNDER desk")
			expect(view.key).to.equal("C")
			expect(view.fill).to.equal(0)
			expect(view.warn).to.equal(false)
		end)

		it("fills the strip while the key is held", function()
			local held = table.clone(PROMPT)
			held.holdStartedAt = 100
			expect(HideViewModel.chip(held, nil, "C", 100.3, false).fill).to.be.near(0.5, 1e-6)
			expect(HideViewModel.chip(held, nil, "C", 105, false).fill).to.equal(1)
		end)

		it("offers the way out while hiding, over any prompt", function()
			local view = HideViewModel.chip(PROMPT, HIDDEN, "C", 105, false)
			expect(view.text).to.equal("LEAVE locker")
			expect(view.fill).to.equal(nil)
		end)

		it("warns when the stay gets cramped, counting down to being pushed out", function()
			local now = 100 + HideConstants.CAMP_WARN_SECONDS
			local view = HideViewModel.chip(nil, HIDDEN, "C", now, false)
			expect(view.warn).to.equal(true)
			expect(view.text).to.equal(
				`CRAMPED · out in {HideConstants.CAMP_SECONDS - HideConstants.CAMP_WARN_SECONDS}s`
			)
		end)

		it("shows nothing without a prompt or a spot, or while the HUD is hidden", function()
			expect(HideViewModel.chip(nil, nil, "C", 0, false)).to.equal(nil)
			expect(HideViewModel.chip(PROMPT, HIDDEN, "C", 0, true)).to.equal(nil)
		end)
	end)

	describe("overlay", function()
		it("frames a locker's slits inside and the underside under a desk", function()
			expect(HideViewModel.overlay(HIDDEN)).to.equal("inside")
			expect(HideViewModel.overlay({ spotId = "desk.a", kind = "under", noun = "desk", since = 0 })).to.equal(
				"under"
			)
			expect(HideViewModel.overlay(nil)).to.equal(nil)
		end)
	end)
end
