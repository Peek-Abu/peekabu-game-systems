local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local Batch = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationBatchCodec)

local function record(overrides)
	local r = {
		slot = 3,
		generation = 1,
		epoch = 2,
		ageMs = 10,
		position = Vector3.new(-1200, 40, -350),
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

-- `records`: a list of record overrides; `actions[i]`: the action written after record i when it has one.
local function batch(records, actions, extraBytes)
	local total = Codec.HEADER_BYTES + (extraBytes or 0)
	for _, overrides in records do
		total += if overrides.hasAction then Codec.RECORD_BYTES + Codec.ACTION_BYTES else Codec.RECORD_BYTES
	end
	local b = buffer.create(total)
	Codec.writeHeader(b, 0, { seq = 1, batchTimeMs = 1000, count = #records })
	local offset = Codec.HEADER_BYTES
	for i, overrides in records do
		local r = record(overrides)
		Codec.writeRecord(b, offset, r)
		offset += Codec.RECORD_BYTES
		if r.hasAction then
			Codec.writeAction(b, offset, (actions or {})[i] or { index = 0, variant = 0, elapsedMs = 0 })
			offset += Codec.ACTION_BYTES
		end
	end
	return b
end

return function()
	describe("validate", function()
		it("accepts a well-formed batch of plain records", function()
			expect(Batch.validate(batch({ {}, { slot = 4 }, { slot = 5 } }), 0)).to.equal(true)
		end)

		it("accepts a record carrying an action whose index is in the registry", function()
			local b = batch({ {}, { hasAction = true } }, { [2] = { index = 4, variant = 0, elapsedMs = 64 } })
			expect(Batch.validate(b, 5)).to.equal(true)
		end)

		it("rejects an action index beyond the registry", function()
			local b = batch({ { hasAction = true } }, { { index = 5, variant = 0, elapsedMs = 0 } })
			local ok, reason = Batch.validate(b, 5)
			expect(ok).to.equal(false)
			expect(reason).to.equal("action")
		end)

		it("rejects a count larger than the records present", function()
			local b = batch({ {}, {} })
			buffer.writeu8(b, 6, 3)
			local ok, reason = Batch.validate(b, 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("truncated")
		end)

		it("rejects trailing bytes after the last record", function()
			local ok, reason = Batch.validate(batch({ {} }, nil, 3), 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("trailing")
		end)

		it("rejects a batch shorter than its header, and an empty batch", function()
			local ok, reason = Batch.validate(buffer.create(6), 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("short")
			ok, reason = Batch.validate(batch({}), 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("empty")
		end)
	end)

	describe("hasActionAt", function()
		it("reads the action bit without decoding the record", function()
			local b = batch({ {}, { hasAction = true } })
			expect(Batch.hasActionAt(b, Codec.HEADER_BYTES)).to.equal(false)
			expect(Batch.hasActionAt(b, Codec.HEADER_BYTES + Codec.RECORD_BYTES)).to.equal(true)
		end)
	end)
end
