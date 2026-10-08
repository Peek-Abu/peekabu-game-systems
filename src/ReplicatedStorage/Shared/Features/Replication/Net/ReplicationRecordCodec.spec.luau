local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)

local function record(overrides)
	local r = {
		slot = 5,
		generation = 2,
		epoch = 3,
		ageMs = 40,
		position = Vector3.new(-1200.3, 42.7, -350.9),
		yaw = 1.2,
		pitch = -0.3,
		velocity = Vector3.new(12.5, -30.25, 0.75),
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

local function roundTrip(r)
	local b = buffer.create(Codec.RECORD_BYTES)
	Codec.writeRecord(b, 0, r)
	return Codec.readRecord(b, 0)
end

-- Half a companding step at |v| (the worst quantisation error for that speed).
local function velocityTolerance(v)
	return math.sqrt(768 * math.abs(v)) / 1023 + 1e-3
end

local function angleDelta(a, b)
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

return function()
	describe("sizes", function()
		it("uses a 16 B record, a 7 B header and a 2 B action extension", function()
			expect(Codec.RECORD_BYTES).to.equal(16)
			expect(Codec.HEADER_BYTES).to.equal(7)
			expect(Codec.ACTION_BYTES).to.equal(2)
		end)

		it("counts the action extension in recordBytes", function()
			expect(Codec.recordBytes(record())).to.equal(16)
			expect(Codec.recordBytes(record({ hasAction = true }))).to.equal(18)
		end)
	end)

	describe("record round trip", function()
		it("keeps every integer field exactly, including maximum values", function()
			local out =
				roundTrip(record({ slot = 127, generation = 3, epoch = 7, ageMs = 1023, state = 31, hasAction = true }))
			expect(out.slot).to.equal(127)
			expect(out.generation).to.equal(3)
			expect(out.epoch).to.equal(7)
			expect(out.ageMs).to.equal(1023)
			expect(out.state).to.equal(31)
			expect(out.grounded).to.equal(true)
			expect(out.hasAction).to.equal(true)
		end)

		it("keeps position within half a quantisation step", function()
			local r = record()
			local out = roundTrip(r)
			expect(math.abs(out.position.X - r.position.X) <= 1 / 128 + 1e-6).to.equal(true)
			expect(math.abs(out.position.Z - r.position.Z) <= 1 / 128 + 1e-6).to.equal(true)
			expect(math.abs(out.position.Y - r.position.Y) <= 1 / 64 + 1e-6).to.equal(true)
		end)

		it("encodes a yaw just below zero without wrapping it to 358 degrees", function()
			local out = roundTrip(record({ yaw = -0.005 }))
			expect(angleDelta(out.yaw, -0.005) <= math.pi / 256 + 1e-6).to.equal(true)
		end)

		it("keeps yaw within 1.4 degrees and pitch within 2.9 degrees", function()
			for _, yaw in { -3.1, -1, 0, 0.5, 3.1, 7 } do
				local out = roundTrip(record({ yaw = yaw }))
				expect(angleDelta(out.yaw, yaw) <= math.pi / 256 + 1e-6).to.equal(true)
			end
			for _, pitch in { -1.5, -0.2, 0, 0.9, 1.5 } do
				local out = roundTrip(record({ pitch = pitch }))
				expect(math.abs(out.pitch - pitch) <= math.pi / 63 + 1e-6).to.equal(true)
			end
		end)

		it("keeps velocity within half a companding step, sign included", function()
			for _, v in { 0, 0.3, -2, 10, -16, 50.9, -185, 400, 767 } do
				local out = roundTrip(record({ velocity = Vector3.new(v, -v, v / 2) }))
				expect(math.abs(out.velocity.X - v) <= velocityTolerance(v)).to.equal(true)
				expect(math.abs(out.velocity.Y + v) <= velocityTolerance(v)).to.equal(true)
				expect(math.abs(out.velocity.Z - v / 2) <= velocityTolerance(v / 2)).to.equal(true)
			end
		end)

		it("clamps out-of-range values to the edge of their field", function()
			local out = roundTrip(record({
				position = Vector3.new(-1228 + 5000, 5000, -363 - 5000),
				velocity = Vector3.new(2000, -2000, 0),
				ageMs = 5000,
			}))
			expect(out.position.X).to.be.near(-1228 + 2048 - 1 / 64, 0.02)
			expect(out.position.Z).to.be.near(-363 - 2048, 0.02)
			expect(out.position.Y).to.be.near(1536 - 1 / 32, 0.04)
			expect(out.velocity.X).to.be.near(768, 0.01)
			expect(out.velocity.Y).to.be.near(-768, 0.01)
			expect(out.ageMs).to.equal(1023)
		end)

		it("encodes NaN and infinities as finite values without disturbing other fields", function()
			local nan = 0 / 0
			local out = roundTrip(record({
				position = Vector3.new(nan, math.huge, -math.huge),
				velocity = Vector3.new(nan, math.huge, -math.huge),
				yaw = nan,
				pitch = nan,
				slot = 9,
				state = 12,
			}))
			for _, value in
				{
					out.position.X,
					out.position.Y,
					out.position.Z,
					out.velocity.X,
					out.velocity.Y,
					out.velocity.Z,
					out.yaw,
					out.pitch,
				}
			do
				expect(value == value).to.equal(true)
				expect(math.abs(value) < math.huge).to.equal(true)
			end
			expect(out.slot).to.equal(9)
			expect(out.state).to.equal(12)
		end)

		it("carries a full rotation instead of velocity on a ragdoll record", function()
			local rotation = CFrame.Angles(0.4, -1.1, 2.2)
			local out = roundTrip(record({ state = Codec.STATE_RAGDOLL, rotation = rotation }))
			expect(out.rotation).to.be.ok()
			local _, angle = (out.rotation:Inverse() * rotation):ToAxisAngle()
			expect(math.abs(angle) < math.rad(0.3)).to.equal(true)
			expect(out.velocity).to.equal(Vector3.zero)
		end)

		it("encodes an identity rotation when a ragdoll record has none", function()
			local out = roundTrip(record({ state = Codec.STATE_RAGDOLL, rotation = nil }))
			expect(out.rotation).to.be.ok()
			local _, angle = out.rotation:ToAxisAngle()
			expect(math.abs(angle) < math.rad(0.3)).to.equal(true)
		end)

		it("decodes scrambled ragdoll rotation bits to a unit rotation", function()
			local b = buffer.create(Codec.RECORD_BYTES)
			Codec.writeRecord(b, 0, record({ state = Codec.STATE_RAGDOLL, rotation = CFrame.identity }))
			-- Bits 88..119 (the first 32 of the 33 rotation bits) are bytes 11..14; the state field (bits 121..125) is untouched.
			for i = 11, 14 do
				buffer.writeu8(b, i, bit32.bor(buffer.readu8(b, i), 0xFF))
			end
			local out = Codec.readRecord(b, 0)
			expect(out.state).to.equal(Codec.STATE_RAGDOLL)
			expect(math.abs(out.rotation.XVector.Magnitude - 1) < 1e-3).to.equal(true)
			expect(math.abs(out.rotation.XVector:Dot(out.rotation.YVector)) < 1e-3).to.equal(true)
		end)

		it("writes at an offset without touching neighbouring bytes", function()
			local b = buffer.create(3 + Codec.RECORD_BYTES + 3)
			buffer.fill(b, 0, 0xAB)
			Codec.writeRecord(b, 3, record())
			for i = 0, 2 do
				expect(buffer.readu8(b, i)).to.equal(0xAB)
				expect(buffer.readu8(b, 3 + Codec.RECORD_BYTES + i)).to.equal(0xAB)
			end
			expect(Codec.readRecord(b, 3).slot).to.equal(5)
		end)
	end)

	describe("header", function()
		it("round-trips and wraps seq at 16 bits and batch time at 32 bits", function()
			local b = buffer.create(Codec.HEADER_BYTES)
			Codec.writeHeader(b, 0, { seq = 65536 + 3, batchTimeMs = 4294967296 + 5, count = 43 })
			local h = Codec.readHeader(b, 0)
			expect(h.seq).to.equal(3)
			expect(h.batchTimeMs).to.equal(5)
			expect(h.count).to.equal(43)
		end)
	end)

	describe("action extension", function()
		it("round-trips index, variant and elapsed time in 32 ms steps", function()
			local b = buffer.create(Codec.ACTION_BYTES)
			Codec.writeAction(b, 0, { index = 100, variant = 5, elapsedMs = 330 })
			local a = Codec.readAction(b, 0)
			expect(a.index).to.equal(100)
			expect(a.variant).to.equal(5)
			expect(a.elapsedMs).to.equal(320)
		end)

		it("saturates elapsed time at 2016 ms", function()
			local b = buffer.create(Codec.ACTION_BYTES)
			Codec.writeAction(b, 0, { index = 1, variant = 0, elapsedMs = 9000 })
			expect(Codec.readAction(b, 0).elapsedMs).to.equal(Codec.ACTION_ELAPSED_MAX_MS)
		end)
	end)

	describe("unwrapOwnerTime", function()
		it("recovers an owner timestamp from its low 10 bits", function()
			expect(Codec.unwrapOwnerTime(5000, 4970 % 1024)).to.equal(4970)
		end)

		it("recovers a timestamp across a 1024 ms boundary", function()
			expect(Codec.unwrapOwnerTime(1030, 1020 % 1024)).to.equal(1020)
		end)

		it("tolerates an owner up to 64 ms ahead of the server clock", function()
			expect(Codec.unwrapOwnerTime(5000, 5040 % 1024)).to.equal(5040)
		end)

		it("aliases a sample older than 959 ms into the future (documented; R2 ingest detects it)", function()
			expect(Codec.unwrapOwnerTime(5000, (5000 - 1000) % 1024)).to.equal(5024)
		end)

		it("reads a timestamp 900 ms old as old, not as ahead", function()
			expect(Codec.unwrapOwnerTime(5000, 4100 % 1024)).to.equal(4100)
		end)
	end)
	describe("Y floor", function()
		it("exports the lowest encodable Y", function()
			expect(Codec.Y_FLOOR).to.equal(-512)
		end)

		it("clamps a position below the floor to it", function()
			local out = roundTrip(record({ position = Vector3.new(-1200, -900, -350) }))
			expect(out.position.Y).to.equal(Codec.Y_FLOOR)
		end)
	end)
end
