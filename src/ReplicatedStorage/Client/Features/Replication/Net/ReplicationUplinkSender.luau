--!strict
--[=[
	ReplicationUplinkSender: when the owner sends a sample, and the packet it sends (spec §6.3; Verdict: send-on-change
	uplink; plan R2 Task 10).

	At most one sample every 15 ms (≤ 60 Hz, honest timestamps — no accumulator repeating positions). The v3
	send policy decides: a changed sample goes at once; a still body sends two resends 50 ms apart and then a
	repair every second. Each packet carries the new sample plus the two previously SENT samples (survives
	two consecutive losses), newest first, aged from the packet's send time (ReplicationUplinkCodec).

	`isGrounded` follows the spike's measured rule: the most authoritative local signal is the Humanoid STATE
	machine (FloorMaterial lags a jump by several frames), so grounded needs both a non-airborne state and a
	floor.

	Pure: time is passed in (session ms, integer).

	@class ReplicationUplinkSender
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationShared = ReplicatedStorage.Shared.Features.Replication
local ReplicationRecordCodec = require(ReplicationShared.Net.ReplicationRecordCodec)
local ReplicationUplinkCodec = require(ReplicationShared.Net.ReplicationUplinkCodec)
local ReplicationSendRules = require(ReplicationShared.Rules.ReplicationSendRules)

local ReplicationUplinkSender = {}

local MIN_SPACING_MS = 15
ReplicationUplinkSender.MIN_SPACING_MS = MIN_SPACING_MS

local AIRBORNE: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Flying] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
}

export type Sender = {
	policy: ReplicationSendRules.Policy,
	lastSent: ReplicationRecordCodec.Record?,
	history: { ReplicationUplinkCodec.UplinkSample }, -- newest first, at most MAX_RECORDS
	lastSampleMs: number,
	sent: number,
}

function ReplicationUplinkSender.new(): Sender
	return {
		policy = ReplicationSendRules.new(),
		lastSent = nil,
		history = {},
		lastSampleMs = -math.huge,
		sent = 0,
	}
end

-- A new body: nothing of the previous one is resent.
function ReplicationUplinkSender.reset(sender: Sender)
	sender.policy = ReplicationSendRules.new()
	sender.lastSent = nil
	table.clear(sender.history)
	sender.lastSampleMs = -math.huge
end

function ReplicationUplinkSender.isGrounded(state: Enum.HumanoidStateType, floorMaterial: Enum.Material): boolean
	return not AIRBORNE[state] and floorMaterial ~= Enum.Material.Air
end

--[=[
	Offer the owner's current sample at `nowMs`. Returns the packet to send, or nil. `record` must be a fresh
	table (the sender keeps it and writes its `ageMs` per packet).
]=]
function ReplicationUplinkSender.step(sender: Sender, nowMs: number, record: ReplicationRecordCodec.Record): buffer?
	if nowMs - sender.lastSampleMs < MIN_SPACING_MS then
		return nil
	end
	local decision =
		ReplicationSendRules.decide(sender.policy, nowMs, ReplicationSendRules.changed(sender.lastSent, record))
	if decision == nil then
		return nil
	end
	sender.lastSent = record
	sender.lastSampleMs = nowMs
	table.insert(sender.history, 1, { record = record, sampleMs = nowMs })
	if #sender.history > ReplicationUplinkCodec.MAX_RECORDS then
		table.remove(sender.history)
	end
	sender.sent += 1
	return ReplicationUplinkCodec.encode(nowMs, sender.history)
end

return ReplicationUplinkSender
