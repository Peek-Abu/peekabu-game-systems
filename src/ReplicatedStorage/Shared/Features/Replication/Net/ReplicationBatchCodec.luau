--!strict
--[=[
	Downlink batch validation (spec §6.2 batch header; R1 review: decode-side checks; plan R2 Task 3).

	A batch is the 7 B header (`u16 seq · u32 batchTimeMs · u8 count`) and `count` records back to back,
	each 16 B, or 18 B when its `hasAction` bit carries the 2 B action extension. `validate` walks the
	records by their action bit alone (no decoding) and proves, before a viewer decodes anything, that
	`count` records fit exactly, nothing trails them, and every action index is inside the registry
	(`actionCount` = `#AnimationRegistry.ids()`; indices are 0-based positions in that list).

	Pure.

	@class ReplicationBatchCodec
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationRecordCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)

local ReplicationBatchCodec = {}

local HEADER_BYTES = ReplicationRecordCodec.HEADER_BYTES
local RECORD_BYTES = ReplicationRecordCodec.RECORD_BYTES
local ACTION_BYTES = ReplicationRecordCodec.ACTION_BYTES

-- `hasAction` is the record's last bit (bit 127): the top bit of its 16th byte (little-endian words).
function ReplicationBatchCodec.hasActionAt(b: buffer, offset: number): boolean
	return bit32.btest(buffer.readu8(b, offset + RECORD_BYTES - 1), 0x80)
end

function ReplicationBatchCodec.validate(b: buffer, actionCount: number): (boolean, string?)
	local length = buffer.len(b)
	if length < HEADER_BYTES then
		return false, "short"
	end
	local count = buffer.readu8(b, 6)
	if count == 0 then
		return false, "empty"
	end
	local offset = HEADER_BYTES
	for _ = 1, count do
		if offset + RECORD_BYTES > length then
			return false, "truncated"
		end
		if ReplicationBatchCodec.hasActionAt(b, offset) then
			if offset + RECORD_BYTES + ACTION_BYTES > length then
				return false, "truncated"
			end
			local index = bit32.band(buffer.readu16(b, offset + RECORD_BYTES), 127)
			if index >= actionCount then
				return false, "action"
			end
			offset += RECORD_BYTES + ACTION_BYTES
		else
			offset += RECORD_BYTES
		end
	end
	if offset ~= length then
		return false, "trailing"
	end
	return true, nil
end

return ReplicationBatchCodec
