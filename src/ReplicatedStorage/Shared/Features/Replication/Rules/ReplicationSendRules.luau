--!strict
--[=[
	When to send a body's record (Verdict: the v3 send policy, measured in the spike's A/B). Used for both links:
	the owner's uplink and each body's downlink.

	  change   the record differs from the last one sent (`changed`): send it.
	  resend   after the last change, `resends` more copies `resendSpacingMs` apart. Without them, losing the final
	           change before a body goes still (a respawn, a stop) leaves viewers drawing the old spot until the
	           repair: measured once in 32 mobile runs, 97 studs off.
	  repair   `repairMs` after the last send of any kind, so a still body is confirmed and a new viewer catches up.

	Pure: time is passed in (ms).

	@class ReplicationSendRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationRecordCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)

local ReplicationSendRules = {}

export type Config = {
	repairMs: number,
	resends: number,
	resendSpacingMs: number,
}

local DEFAULT_CONFIG: Config = {
	repairMs = 1000,
	resends = 2,
	resendSpacingMs = 50,
}
table.freeze(DEFAULT_CONFIG)
ReplicationSendRules.DEFAULT_CONFIG = DEFAULT_CONFIG

export type Decision = "change" | "resend" | "repair"

export type Policy = {
	config: Config,
	lastSentMs: number,
	resendsLeft: number,
	nextResendMs: number,
}

-- Below these, two records draw the same body (quantisation is 1/64 stud and ~1.4°).
local POSITION_EPSILON = 0.02
local VELOCITY_EPSILON = 0.05
local ANGLE_EPSILON = 0.03
local ROTATION_EPSILON = 1e-3

local function angleDelta(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

local function rotationChanged(a: CFrame?, b: CFrame?): boolean
	if a == nil or b == nil then
		return a ~= b
	end
	return not a:FuzzyEq(b, ROTATION_EPSILON)
end

function ReplicationSendRules.new(config: Config?): Policy
	return {
		config = config or DEFAULT_CONFIG,
		lastSentMs = -math.huge,
		resendsLeft = 0,
		nextResendMs = 0,
	}
end

--[=[
	Whether `current` draws a different body from `previous` (the timestamp field `ageMs` is ignored).
	`previous` must be the last record SENT (not the last one seen), so drift below the thresholds still accumulates
	into a send.
]=]
function ReplicationSendRules.changed(
	previous: ReplicationRecordCodec.Record?,
	current: ReplicationRecordCodec.Record
): boolean
	if previous == nil then
		return true
	end
	return (previous.position - current.position).Magnitude >= POSITION_EPSILON
		or (previous.velocity - current.velocity).Magnitude >= VELOCITY_EPSILON
		or angleDelta(previous.yaw, current.yaw) >= ANGLE_EPSILON
		or math.abs(previous.pitch - current.pitch) >= ANGLE_EPSILON
		or previous.state ~= current.state
		or previous.grounded ~= current.grounded
		or previous.epoch ~= current.epoch
		or previous.hasAction ~= current.hasAction
		or rotationChanged(previous.rotation, current.rotation)
end

--[=[
	What to send at `nowMs`, given whether the record changed since the last send. `nil` = send nothing.
]=]
function ReplicationSendRules.decide(policy: Policy, nowMs: number, changed: boolean): Decision?
	local cfg = policy.config
	local decision: Decision? = nil
	if changed then
		policy.resendsLeft = cfg.resends
		policy.nextResendMs = nowMs + cfg.resendSpacingMs
		decision = "change"
	elseif policy.resendsLeft > 0 and nowMs >= policy.nextResendMs then
		policy.resendsLeft -= 1
		policy.nextResendMs = nowMs + cfg.resendSpacingMs
		decision = "resend"
	elseif nowMs - policy.lastSentMs >= cfg.repairMs then
		decision = "repair"
	end
	if decision ~= nil then
		policy.lastSentMs = nowMs
	end
	return decision
end

return ReplicationSendRules
