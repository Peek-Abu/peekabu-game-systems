local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrouchRequestUtils = require(script.Parent.CrouchRequestUtils)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)

local CONFIRM = CrouchConstants.TOGGLE_CONFIRM

return function()
	local fresh = CrouchRequestUtils.fresh

	describe("wanted", function()
		it("wants a crouch while the key is held or a toggle is on", function()
			expect(CrouchRequestUtils.wanted(fresh())).to.equal(false)
			expect(CrouchRequestUtils.wanted(CrouchRequestUtils.hold(fresh(), true))).to.equal(true)
			expect(CrouchRequestUtils.wanted(CrouchRequestUtils.toggle(fresh(), false, 0))).to.equal(true)
		end)
	end)

	describe("toggle", function()
		it("turns on when standing, off when crouched or already on", function()
			local on = CrouchRequestUtils.toggle(fresh(), false, 0)
			expect(on.toggled).to.equal(true)
			expect(CrouchRequestUtils.toggle(on, false, 1).toggled).to.equal(false)
			expect(CrouchRequestUtils.toggle(fresh(), true, 0).toggled).to.equal(false)
		end)

		it("never changes the held key", function()
			local held = CrouchRequestUtils.hold(fresh(), true)
			expect(CrouchRequestUtils.toggle(held, true, 0).held).to.equal(true)
		end)
	end)

	describe("settle", function()
		it("keeps a toggle the server honours", function()
			local on = CrouchRequestUtils.toggle(fresh(), false, 0)
			local settled = CrouchRequestUtils.settle(on, false, true, 0.1)
			expect(settled.toggled).to.equal(true)
			-- Confirmed: no timeout any more.
			expect(CrouchRequestUtils.settle(settled, true, true, 10).toggled).to.equal(true)
		end)

		it("lets a toggle go when the server stands the player up (a sprint, a hide, a big pick-up)", function()
			local on = CrouchRequestUtils.settle(CrouchRequestUtils.toggle(fresh(), false, 0), false, true, 0.1)
			expect(CrouchRequestUtils.settle(on, true, false, 2).toggled).to.equal(false)
		end)

		it("lets an unhonoured toggle go after TOGGLE_CONFIRM, so it never crouches the player later", function()
			local on = CrouchRequestUtils.toggle(fresh(), false, 0)
			expect(CrouchRequestUtils.settle(on, false, false, CONFIRM * 0.5).toggled).to.equal(true)
			expect(CrouchRequestUtils.settle(on, false, false, CONFIRM + 0.01).toggled).to.equal(false)
		end)

		it("leaves the held key alone (a key still held crouches again once allowed)", function()
			local held = CrouchRequestUtils.hold(fresh(), true)
			expect(CrouchRequestUtils.settle(held, true, false, 5).held).to.equal(true)
		end)

		it("returns new tables (pure)", function()
			local on = CrouchRequestUtils.toggle(fresh(), false, 0)
			local settled = CrouchRequestUtils.settle(on, false, false, 9)
			expect(settled).never.to.equal(on)
			expect(on.toggled).to.equal(true)
		end)
	end)
end
