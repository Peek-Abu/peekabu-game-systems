local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Interp = require(ReplicatedStorage.Shared.Features.Replication.State.ReplicationSampleTracker)

local function sample(timeMs, x, overrides)
	local s = {
		timeMs = timeMs,
		position = Vector3.new(x, 10, 0),
		velocity = Vector3.new(16, 0, 0),
		yaw = 0,
		state = 8,
		grounded = true,
		rotation = nil,
	}
	for key, value in overrides or {} do
		s[key] = value
	end
	return s
end

-- A body walking +X at 16 studs/s, one sample every 16.67 ms.
local function walking(count, epoch)
	local b = Interp.newBuffer()
	for i = 0, count - 1 do
		local t = i * 1000 / 60
		Interp.push(b, epoch or 0, sample(t, 16 * t / 1000))
	end
	return b
end

return function()
	describe("push", function()
		it("keeps samples in time order and drops exact duplicates", function()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(20, 1))
			Interp.push(b, 0, sample(10, 0))
			Interp.push(b, 0, sample(20, 5))
			expect(#b.samples).to.equal(2)
			expect(b.samples[1].timeMs).to.equal(10)
			expect(b.samples[2].position.X).to.equal(1)
		end)

		it("keeps at most MAX_SAMPLES, dropping the oldest", function()
			local b = walking(Interp.MAX_SAMPLES + 5)
			expect(#b.samples).to.equal(Interp.MAX_SAMPLES)
			expect(b.samples[1].timeMs).to.be.near(5 * 1000 / 60, 1e-6)
		end)

		it("flushes on the next epoch and reports it", function()
			local b = walking(5, 3)
			expect(Interp.push(b, 4, sample(500, 90))).to.equal("flushed")
			expect(#b.samples).to.equal(1)
			expect(b.epoch).to.equal(4)
		end)

		it("treats 7 -> 0 as the next epoch", function()
			local b = walking(3, 7)
			expect(Interp.push(b, 0, sample(500, 90))).to.equal("flushed")
			expect(b.epoch).to.equal(0)
		end)

		it("drops a record from an older epoch after a flush", function()
			local b = walking(3, 3)
			Interp.push(b, 4, sample(500, 90))
			expect(Interp.push(b, 3, sample(510, 1))).to.equal("dropped")
			expect(#b.samples).to.equal(1)
			expect(b.samples[1].position.X).to.equal(90)
			expect(b.epoch).to.equal(4)
		end)

		it("accepts any epoch on an empty buffer", function()
			local b = Interp.newBuffer()
			expect(Interp.push(b, 6, sample(0, 0))).to.equal("flushed")
			expect(b.epoch).to.equal(6)
		end)

		it("reports newest, inserted and dropped", function()
			local b = Interp.newBuffer()
			expect(Interp.push(b, 0, sample(20, 1))).to.equal("flushed") -- the first sample sets the epoch
			expect(Interp.push(b, 0, sample(40, 2))).to.equal("newest")
			expect(Interp.push(b, 0, sample(30, 3))).to.equal("inserted")
			expect(Interp.push(b, 0, sample(30, 9))).to.equal("dropped")
		end)

		it("reports a sample older than a full buffer as dropped", function()
			local b = walking(Interp.MAX_SAMPLES)
			expect(Interp.push(b, 0, sample(-100, 0))).to.equal("dropped")
			expect(#b.samples).to.equal(Interp.MAX_SAMPLES)
			expect(b.samples[1].timeMs).to.equal(0)
		end)

		it("counts only newest and flushed as new samples", function()
			expect(Interp.isNewSample("newest")).to.equal(true)
			expect(Interp.isNewSample("flushed")).to.equal(true)
			expect(Interp.isNewSample("inserted")).to.equal(false)
			expect(Interp.isNewSample("dropped")).to.equal(false)
		end)
	end)

	describe("evaluate", function()
		it("evaluate on an empty buffer reports empty", function()
			expect(Interp.evaluate(Interp.newBuffer(), 0).mode).to.equal("empty")
			local _, mode = Interp.evaluatePosition(Interp.newBuffer(), 0, Interp.newHint())
			expect(mode).to.equal("empty")
		end)

		it("passes exactly through the samples", function()
			local b = walking(10)
			local s = b.samples[4]
			expect((Interp.evaluate(b, s.timeMs).position - s.position).Magnitude < 1e-6).to.equal(true)
		end)

		it("follows a straight walk between samples", function()
			local b = walking(10)
			local e = Interp.evaluate(b, 60)
			expect(e.mode).to.equal("interpolate")
			expect(e.position.X).to.be.near(16 * 0.06, 1e-3)
		end)

		it("does not dip below either endpoint when grounded flips (landing)", function()
			local b = Interp.newBuffer()
			Interp.push(
				b,
				0,
				sample(0, 0, { position = Vector3.new(0, 20, 0), velocity = Vector3.new(0, -150, 0), grounded = false })
			)
			Interp.push(
				b,
				0,
				sample(33, 0, { position = Vector3.new(0, 10, 0), velocity = Vector3.new(0, 0, 0), grounded = true })
			)
			for t = 0, 33, 3 do
				expect(Interp.evaluate(b, t).position.Y >= 10 - 1e-6).to.equal(true)
			end
		end)

		it("reports behind before the oldest sample and hold past the extrapolation window", function()
			local b = walking(5)
			expect(Interp.evaluate(b, -50).mode).to.equal("behind")
			local newest = b.samples[#b.samples].timeMs
			expect(Interp.evaluate(b, newest + 50).mode).to.equal("extrapolate")
			expect(Interp.evaluate(b, newest + 500).mode).to.equal("hold")
		end)

		it("evaluatePosition matches evaluate at every frame of a walk", function()
			local b = walking(20)
			local hint = Interp.newHint()
			for t = 0, 300, 7 do
				local position, mode = Interp.evaluatePosition(b, t, hint)
				local e = Interp.evaluate(b, t)
				expect(mode).to.equal(e.mode)
				expect((position - e.position).Magnitude < 1e-6).to.equal(true)
			end
		end)
	end)

	describe("reckon", function()
		it("reckon with one sample moves it along its horizontal velocity", function()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(0, 0))
			local p = Interp.reckon(b, 50, 60, nil)
			expect(p.X).to.be.near(0.8, 1e-6)
			expect(p.Y).to.equal(10)
		end)

		it("returns nil on an empty buffer", function()
			expect(Interp.reckon(Interp.newBuffer(), 0, 60, nil)).to.equal(nil)
		end)

		it("stops at maxAheadMs", function()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(0, 0))
			expect(Interp.reckon(b, 1000, 60, nil).X).to.be.near(16 * 0.06, 1e-6)
		end)

		it("applies gravity to an airborne body and stops it at the ground", function()
			local b = Interp.newBuffer()
			Interp.push(
				b,
				0,
				sample(0, 0, { position = Vector3.new(0, 11, 0), velocity = Vector3.new(0, -100, 0), grounded = false })
			)
			local free = Interp.reckon(b, 60, 60, nil)
			expect(free.Y).to.equal(11) -- no world query: never guess a body through a floor
			local grounded = Interp.reckon(b, 60, 60, function()
				return 10
			end)
			expect(grounded.Y).to.equal(10)
			local open = Interp.reckon(b, 60, 60, function()
				return -500
			end)
			expect(open.Y).to.be.near(11 - 100 * 0.06 - 0.5 * 185 * 0.06 * 0.06, 1e-6)
		end)
	end)

	describe("reach", function()
		it("reach is unlimited until the buffer is full", function()
			expect(Interp.reachMs(walking(3), 1000)).to.equal(math.huge)
		end)

		it("is the age of the oldest sample once the buffer is full", function()
			local b = walking(Interp.MAX_SAMPLES)
			expect(Interp.reachMs(b, 1000)).to.be.near(1000 - b.samples[1].timeMs, 1e-6)
		end)

		it("reports the newest sample time", function()
			expect(Interp.newestTimeMs(Interp.newBuffer())).to.equal(nil)
			expect(Interp.newestTimeMs(walking(4))).to.be.near(50, 1e-6)
		end)
	end)

	describe("resetEpoch", function()
		it("lets a buffer skip lost epochs when the slot table says so", function()
			local b = walking(3, 2)
			expect(Interp.push(b, 4, sample(500, 90))).to.equal("dropped") -- epoch 3's records were all lost
			Interp.resetEpoch(b, 12) -- the slot table's full 8-bit epoch; 12 % 8 == 4
			expect(#b.samples).to.equal(0)
			expect(b.epoch).to.equal(4)
			expect(Interp.push(b, 4, sample(500, 90))).to.equal("newest")
		end)
	end)

	describe("isStarving", function()
		it("is true only for hold — behind is a too-large delay, not late samples", function()
			expect(Interp.isStarving("hold")).to.equal(true)
			expect(Interp.isStarving("behind")).to.equal(false)
			expect(Interp.isStarving("extrapolate")).to.equal(false)
			expect(Interp.isStarving("interpolate")).to.equal(false)
			expect(Interp.isStarving("empty")).to.equal(false)
		end)
	end)

	describe("motionAt (puppet locomotion, R3)", function()
		local function jump()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(0, 0))
			Interp.push(b, 0, sample(20, 0.3, { state = 5, grounded = false, velocity = Vector3.new(16, -20, 0) }))
			return b
		end

		it("reports the nearest sample's state, grounded flag and velocity", function()
			local b = jump()
			local hint = Interp.newHint()
			local state, grounded, velocity = Interp.motionAt(b, 9, hint)
			expect(state).to.equal(8)
			expect(grounded).to.equal(true)
			expect(velocity.Y).to.equal(0)
			state, grounded, velocity = Interp.motionAt(b, 11, hint)
			expect(state).to.equal(5)
			expect(grounded).to.equal(false)
			expect(velocity.Y).to.equal(-20)
		end)

		it("uses the edge samples outside the buffer", function()
			local b = jump()
			local hint = Interp.newHint()
			expect((Interp.motionAt(b, -50, hint))).to.equal(8)
			expect((Interp.motionAt(b, 500, hint))).to.equal(5)
		end)

		it("reports a standing default on an empty buffer", function()
			local state, grounded, velocity = Interp.motionAt(Interp.newBuffer(), 0, Interp.newHint())
			expect(state).to.equal(0)
			expect(grounded).to.equal(true)
			expect(velocity).to.equal(Vector3.zero)
		end)
	end)

	describe("evaluatePose", function()
		it("matches evaluate's position and yaw while turning across ±π", function()
			local b = Interp.newBuffer()
			for i = 0, 20 do
				local t = i * 1000 / 60
				Interp.push(b, 0, sample(t, 16 * t / 1000, { yaw = 3.0 + i * 0.05 }))
			end
			local hint = Interp.newHint()
			for t = 0, 333, 7 do
				local position, yaw, mode = Interp.evaluatePose(b, t, hint)
				local e = Interp.evaluate(b, t)
				expect(mode).to.equal(e.mode)
				expect((position - e.position).Magnitude < 1e-3).to.equal(true)
				local delta = math.abs((yaw - e.yaw + math.pi) % (2 * math.pi) - math.pi)
				expect(delta < 1e-6).to.equal(true)
			end
		end)

		it("reports empty with zero yaw on an empty buffer", function()
			local _, yaw, mode = Interp.evaluatePose(Interp.newBuffer(), 10, Interp.newHint())
			expect(mode).to.equal("empty")
			expect(yaw).to.equal(0)
		end)
	end)
end
