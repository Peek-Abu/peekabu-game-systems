local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationSendRules = require(ReplicatedStorage.Shared.Features.Replication.Rules.ReplicationSendRules)

local function record(overrides)
	local r = {
		slot = 1,
		generation = 0,
		epoch = 0,
		ageMs = 0,
		position = Vector3.new(0, 10, 0),
		yaw = 0,
		pitch = 0,
		velocity = Vector3.zero,
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return r
end

return function()
	describe("changed", function()
		it("treats a first record as a change", function()
			expect(ReplicationSendRules.changed(nil, record())).to.equal(true)
		end)

		it("ignores sub-threshold jitter and the timestamp field", function()
			local a = record()
			local b = record({ position = Vector3.new(0.01, 10, 0), velocity = Vector3.new(0.02, 0, 0), ageMs = 500 })
			expect(ReplicationSendRules.changed(a, b)).to.equal(false)
		end)

		it("sees movement, state, grounded, epoch, action and aim", function()
			local a = record()
			expect(ReplicationSendRules.changed(a, record({ position = Vector3.new(0.05, 10, 0) }))).to.equal(true)
			expect(ReplicationSendRules.changed(a, record({ velocity = Vector3.new(0, 0.1, 0) }))).to.equal(true)
			expect(ReplicationSendRules.changed(a, record({ state = 3 }))).to.equal(true)
			expect(ReplicationSendRules.changed(a, record({ grounded = false }))).to.equal(true)
			expect(ReplicationSendRules.changed(a, record({ epoch = 1 }))).to.equal(true)
			expect(ReplicationSendRules.changed(a, record({ hasAction = true }))).to.equal(true)
			expect(ReplicationSendRules.changed(a, record({ yaw = 0.1 }))).to.equal(true)
			expect(ReplicationSendRules.changed(a, record({ pitch = 0.1 }))).to.equal(true)
		end)

		it("compares yaw across the ±π seam", function()
			expect(ReplicationSendRules.changed(record({ yaw = math.pi - 0.005 }), record({ yaw = -math.pi + 0.005 }))).to.equal(
				false
			)
		end)

		it("sees a ragdoll rotation change and ignores an identical one", function()
			local a = record({ state = 29, rotation = CFrame.Angles(0, 1, 0) })
			expect(ReplicationSendRules.changed(a, record({ state = 29, rotation = CFrame.Angles(0, 1, 0) }))).to.equal(
				false
			)
			expect(ReplicationSendRules.changed(a, record({ state = 29, rotation = CFrame.Angles(0, 1.2, 0) }))).to.equal(
				true
			)
			expect(ReplicationSendRules.changed(a, record({ state = 29, rotation = nil }))).to.equal(true)
		end)
	end)

	describe("decide", function()
		it("sends every change", function()
			local p = ReplicationSendRules.new()
			for t = 0, 100, 16 do
				expect(ReplicationSendRules.decide(p, t, true)).to.equal("change")
			end
		end)

		it("resends the last change twice, 50 ms apart, then goes quiet", function()
			local p = ReplicationSendRules.new()
			expect(ReplicationSendRules.decide(p, 0, true)).to.equal("change")
			local decisions = {}
			for t = 16, 900, 16 do
				local d = ReplicationSendRules.decide(p, t, false)
				if d ~= nil then
					table.insert(decisions, { t = t, d = d })
				end
			end
			expect(#decisions).to.equal(2)
			expect(decisions[1].d).to.equal("resend")
			expect(decisions[1].t).to.equal(64)
			expect(decisions[2].d).to.equal("resend")
			expect(decisions[2].t).to.equal(128)
		end)

		it("repairs 1 s after the last send", function()
			local p = ReplicationSendRules.new()
			ReplicationSendRules.decide(p, 0, true)
			ReplicationSendRules.decide(p, 64, false)
			ReplicationSendRules.decide(p, 128, false)
			expect(ReplicationSendRules.decide(p, 1127, false)).to.equal(nil)
			expect(ReplicationSendRules.decide(p, 1128, false)).to.equal("repair")
			expect(ReplicationSendRules.decide(p, 1500, false)).to.equal(nil)
			expect(ReplicationSendRules.decide(p, 2128, false)).to.equal("repair")
		end)

		it("restarts the resends on a new change", function()
			local p = ReplicationSendRules.new()
			ReplicationSendRules.decide(p, 0, true)
			ReplicationSendRules.decide(p, 64, false)
			ReplicationSendRules.decide(p, 80, true)
			expect(ReplicationSendRules.decide(p, 112, false)).to.equal(nil)
			expect(ReplicationSendRules.decide(p, 130, false)).to.equal("resend")
			expect(ReplicationSendRules.decide(p, 180, false)).to.equal("resend")
			expect(ReplicationSendRules.decide(p, 240, false)).to.equal(nil)
		end)

		it("honours a custom config", function()
			local p = ReplicationSendRules.new({ repairMs = 200, resends = 0, resendSpacingMs = 50 })
			ReplicationSendRules.decide(p, 0, true)
			expect(ReplicationSendRules.decide(p, 100, false)).to.equal(nil)
			expect(ReplicationSendRules.decide(p, 200, false)).to.equal("repair")
		end)
	end)
end
