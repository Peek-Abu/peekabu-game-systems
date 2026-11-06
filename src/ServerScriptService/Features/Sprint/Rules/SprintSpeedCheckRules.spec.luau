local ServerScriptService = game:GetService("ServerScriptService")

local SprintSpeedCheckRules = require(ServerScriptService.Features.Sprint.Rules.SprintSpeedCheckRules)

local DT = 0.05

-- Steps a check `ticks` times at `speed` studs/s with the walk at `limit`.
local function run(state, ticks, speed, limit, exempt)
	local verdict, anchor
	for index = 1, ticks do
		local last = Vector3.new((index - 1) * speed * DT, 0, 0)
		verdict, anchor = SprintSpeedCheckRules.step(state, {
			dt = DT,
			last = last,
			position = last + Vector3.new(speed * DT, 0, 0),
			limit = limit,
			exempt = exempt == true,
		})
		if verdict ~= "ok" then
			return verdict, anchor, index
		end
	end
	return verdict, anchor
end

return function()
	it("lets a player run at their own speed, and a little over it, forever", function()
		local state = SprintSpeedCheckRules.fresh()
		expect(run(state, 200, 16, 16)).to.equal("ok")
		expect(run(state, 200, 16 * SprintSpeedCheckRules.TOLERANCE, 16)).to.equal("ok")
	end)

	it("lets a short burst over the limit go (a bump, a slope, a replication hiccup)", function()
		local state = SprintSpeedCheckRules.fresh()
		local ticks = math.floor(SprintSpeedCheckRules.STREAK_SECONDS / DT) - 2
		expect(run(state, ticks, 80, 16)).to.equal("ok")
		expect(run(state, 1, 16, 16)).to.equal("ok")
		expect(run(state, ticks, 80, 16)).to.equal("ok")
	end)

	it("sends a player who keeps going too fast back to where the streak began", function()
		local state = SprintSpeedCheckRules.fresh()
		local verdict, anchor, at = run(state, 200, 60, 16)
		expect(verdict).to.equal("rubberband")
		expect(anchor).to.equal(Vector3.new(0, 0, 0))
		expect(at * DT >= SprintSpeedCheckRules.STREAK_SECONDS - 1e-6).to.equal(true)
	end)

	it("counts vertical speed for nothing (falling is fine)", function()
		local state = SprintSpeedCheckRules.fresh()
		local verdict = SprintSpeedCheckRules.step(state, {
			dt = DT,
			last = Vector3.new(0, 100, 0),
			position = Vector3.new(0, 0, 0),
			limit = 16,
			exempt = false,
		})
		expect(verdict).to.equal("ok")
	end)

	it("calls one huge step a jump (a server teleport) and never counts it", function()
		local state = SprintSpeedCheckRules.fresh()
		local verdict = SprintSpeedCheckRules.step(state, {
			dt = DT,
			last = Vector3.zero,
			position = Vector3.new(SprintSpeedCheckRules.JUMP_STUDS + 1, 0, 0),
			limit = 16,
			exempt = false,
		})
		expect(verdict).to.equal("jump")
		expect(state.streak).to.equal(0)
	end)

	it("checks nothing while exempt (ragdolled, anchored, seated, hiding)", function()
		local state = SprintSpeedCheckRules.fresh()
		expect(run(state, 200, 200, 16, true)).to.equal("ok")
	end)
end
