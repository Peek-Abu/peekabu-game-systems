local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SprintStaminaFormulas = require(script.Parent.SprintStaminaFormulas)
local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)

local function run(state, seconds, draining, effect)
	local steps = math.round(seconds / 0.05)
	for _ = 1, steps do
		state = SprintStaminaFormulas.step(state, 0.05, draining, effect)
	end
	return state
end

return function()
	it("lasts longer and refills faster with the Stamina stat's effect", function()
		-- 5 bars: 6 x 1.2 = 7.2 s of sprint.
		local state = run(SprintStaminaFormulas.fresh(), 7, true, 1.2)
		expect(state.stamina > 0).to.equal(true)
		state = run(state, 0.2, true, 1.2)
		expect(state.stamina).to.equal(0)
		-- Empty to full in 3.5 / 1.2 s after the regen delay.
		state = run(state, SprintConstants.REGEN_DELAY + SprintConstants.REGEN_SECONDS / 1.2 + 0.05, false, 1.2)
		expect(state.stamina).to.equal(1)
	end)

	it("plays like today with no effect or an effect of 1", function()
		local a = run(SprintStaminaFormulas.fresh(), 2, true, nil)
		local b = run(SprintStaminaFormulas.fresh(), 2, true, 1)
		expect(a.stamina).to.be.near(b.stamina, 1e-9)
		expect(a.stamina).to.be.near(1 - 2 / SprintConstants.STAMINA_SECONDS, 1e-6)
	end)

	it("starts full and rested", function()
		local state = SprintStaminaFormulas.fresh()
		expect(state.stamina).to.equal(1)
		expect(state.exhausted).to.equal(false)
		expect(SprintStaminaFormulas.canStart(state)).to.equal(true)
	end)

	it("lasts STAMINA_SECONDS of sprinting, then runs dry and is exhausted", function()
		local state = run(SprintStaminaFormulas.fresh(), SprintConstants.STAMINA_SECONDS - 0.5, true)
		expect(state.stamina > 0).to.equal(true)
		expect(state.exhausted).to.equal(false)
		state = run(state, 0.5, true)
		expect(state.stamina).to.equal(0)
		expect(state.exhausted).to.equal(true)
		expect(SprintStaminaFormulas.canStart(state)).to.equal(false)
	end)

	it("waits REGEN_DELAY before refilling, then refills from empty in REGEN_SECONDS", function()
		local state = run(SprintStaminaFormulas.fresh(), SprintConstants.STAMINA_SECONDS, true)
		state = run(state, SprintConstants.REGEN_DELAY, false)
		expect(state.stamina).to.be.near(0, 0.02)
		state = run(state, SprintConstants.REGEN_SECONDS, false)
		expect(state.stamina).to.equal(1)
	end)

	it("may not sprint again until the bar is back to RESTART_FRACTION", function()
		local state = run(SprintStaminaFormulas.fresh(), SprintConstants.STAMINA_SECONDS, true)
		state = run(
			state,
			SprintConstants.REGEN_DELAY + SprintConstants.REGEN_SECONDS * (SprintConstants.RESTART_FRACTION - 0.05),
			false
		)
		expect(SprintStaminaFormulas.canStart(state)).to.equal(false)
		state = run(state, SprintConstants.REGEN_SECONDS * 0.1, false)
		expect(SprintStaminaFormulas.canStart(state)).to.equal(true)
	end)

	it("never changes the state it is given, and ignores a bad step", function()
		local state = SprintStaminaFormulas.fresh()
		local after = SprintStaminaFormulas.step(state, 1, true)
		expect(state.stamina).to.equal(1)
		expect(after.stamina < 1).to.equal(true)
		expect(SprintStaminaFormulas.step(state, 0 / 0, true).stamina).to.equal(1)
		expect(SprintStaminaFormulas.step(state, -1, true).stamina).to.equal(1)
	end)
end
