local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local Uplink = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationUplinkCodec)

local function record(overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200, 40, -350),
		yaw = 0.5,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
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

local function sample(sampleMs, overrides)
	return { record = record(overrides), sampleMs = sampleMs }
end

return function()
	describe("encode", function()
		it("writes the send time, the count and newest-first records aged from the send time", function()
			local b = Uplink.encode(5000, { sample(5000), sample(4983), sample(4966) })
			expect(Uplink.size(3)).to.equal(5 + 48)
			expect(buffer.len(b)).to.equal(Uplink.size(3))
			expect(buffer.readu32(b, 0)).to.equal(5000)
			expect(buffer.readu8(b, 4)).to.equal(3)
			expect(Codec.readRecord(b, 5).ageMs).to.equal(0)
			expect(Codec.readRecord(b, 21).ageMs).to.equal(17)
			expect(Codec.readRecord(b, 37).ageMs).to.equal(34)
		end)

		it("leaves out previous samples older than 1023 ms", function()
			local b = Uplink.encode(5000, { sample(5000), sample(4000), sample(3000) })
			expect(buffer.readu8(b, 4)).to.equal(2)
			expect(buffer.len(b)).to.equal(Uplink.size(2))
		end)

		it("writes at most three records", function()
			local b = Uplink.encode(100, { sample(100), sample(84), sample(68), sample(52) })
			expect(buffer.readu8(b, 4)).to.equal(3)
		end)
	end)

	describe("decode", function()
		it("round-trips the send time, sample times and records", function()
			local b = Uplink.encode(5000, {
				sample(5000, { position = Vector3.new(-1200, 40, -350) }),
				sample(4983, { position = Vector3.new(-1201, 40, -350) }),
			})
			local ok, reason, uplink = Uplink.decode(b)
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
			expect(uplink.sentMs).to.equal(5000)
			expect(#uplink.samples).to.equal(2)
			expect(uplink.samples[1].sampleMs).to.equal(5000)
			expect(uplink.samples[2].sampleMs).to.equal(4983)
			expect(uplink.samples[2].record.position.X).to.be.near(-1201, 0.02)
		end)

		it("rejects empty, short and oversized packets before decoding", function()
			for _, length in { 0, 4, 5, 20, 22, 70 } do
				local ok, reason = Uplink.decode(buffer.create(length))
				expect(ok).to.equal(false)
				expect(reason).to.equal("size")
			end
		end)

		it("rejects a packet whose length does not match its count", function()
			local b = Uplink.encode(5000, { sample(5000), sample(4983) })
			buffer.writeu8(b, 4, 3)
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("size")
		end)

		it("rejects a count of zero", function()
			local b = Uplink.encode(5000, { sample(5000) })
			buffer.writeu8(b, 4, 0)
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("size")
		end)

		it("rejects the ragdoll state (ragdoll is server-granted)", function()
			local b = Uplink.encode(5000, { sample(5000, { state = Codec.STATE_RAGDOLL }) })
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("ragdoll")
		end)

		it("rejects an owner-claimed action extension bit", function()
			local b = Uplink.encode(5000, { sample(5000, { hasAction = true }) })
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("action")
		end)

		it("rejects samples that are not strictly newest first", function()
			local b = Uplink.encode(5000, { sample(5000), sample(4983) })
			local second = Codec.readRecord(b, 21)
			second.ageMs = 0
			Codec.writeRecord(b, 21, second)
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("order")
		end)

		it("never reads an old sample as a future one (no 10-bit owner-time alias)", function()
			-- A previous sample 1000 ms old: the 10-bit unwrap would have read it as 24 ms in the future.
			local b = Uplink.encode(10000, { sample(10000), sample(9000) })
			local ok, _, uplink = Uplink.decode(b)
			expect(ok).to.equal(true)
			expect(uplink.samples[2].sampleMs).to.equal(9000)
		end)
	end)
end
