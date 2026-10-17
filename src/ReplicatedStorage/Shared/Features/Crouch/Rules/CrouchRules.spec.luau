local CrouchRules = require(script.Parent.CrouchRules)

local function input(extra)
	local value = {
		requested = true,
		alive = true,
		frozen = false,
		hidden = false,
		sprinting = false,
		heldSize = nil,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("canCrouch", function()
		local function refused(extra, expected)
			local ok, reason = CrouchRules.canCrouch(input(extra))
			expect(ok).to.equal(false)
			expect(reason).to.equal(expected)
		end

		it("crouches a living, free player who asks with empty hands", function()
			expect(CrouchRules.canCrouch(input())).to.equal(true)
		end)

		it("crouches with a small (tiny or light) item in the hands", function()
			expect(CrouchRules.canCrouch(input({ heldSize = "tiny" }))).to.equal(true)
			expect(CrouchRules.canCrouch(input({ heldSize = "light" }))).to.equal(true)
		end)

		it("refuses without asking, dead, frozen or hidden", function()
			refused({ requested = false }, "not asked")
			refused({ alive = false }, "not alive")
			refused({ frozen = true }, "frozen")
			refused({ hidden = true }, "hidden")
		end)

		it("refuses while sprinting: a sprint ends the crouch", function()
			refused({ sprinting = true }, "sprinting")
		end)

		it("refuses with a big item in the hands, or a held thing that is not cargo", function()
			refused({ heldSize = "medium" }, "hands full")
			refused({ heldSize = "heavy" }, "hands full")
			refused({ heldSize = "bulky" }, "hands full")
			refused({ heldSize = "unknown" }, "hands full")
		end)
	end)

	describe("offered", function()
		it("offers the phone's button whenever the player is not hiding", function()
			expect(CrouchRules.offered(false)).to.equal(true)
			expect(CrouchRules.offered(true)).to.equal(false)
		end)
	end)
end
