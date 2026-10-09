local InteractionRules = require(script.Parent.InteractionRules)

local function input(overrides)
	local base = {
		hasCharacter = true,
		distance = 5,
		maxDistance = 10,
		tolerance = 2,
		enabled = true,
		cooldownRemaining = 0,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	it("allows a trigger in range, enabled, off cooldown", function()
		expect(InteractionRules.check(input())).to.equal(true)
	end)

	it("refuses with no character", function()
		local ok, reason = InteractionRules.check(input({ hasCharacter = false }))
		expect(ok).to.equal(false)
		expect(reason).to.equal("no-character")
	end)

	it("allows up to maxDistance plus tolerance, and refuses beyond", function()
		expect(InteractionRules.check(input({ distance = 12 }))).to.equal(true)
		local ok, reason = InteractionRules.check(input({ distance = 12.5 }))
		expect(ok).to.equal(false)
		expect(reason).to.equal("too-far")
	end)

	it("refuses a disabled object", function()
		local ok, reason = InteractionRules.check(input({ enabled = false }))
		expect(ok).to.equal(false)
		expect(reason).to.equal("disabled")
	end)

	it("refuses while on cooldown", function()
		local ok, reason = InteractionRules.check(input({ cooldownRemaining = 0.3 }))
		expect(ok).to.equal(false)
		expect(reason).to.equal("cooldown")
	end)
end
