--!strict
--[=[
	ShiftAnalyticsUtils: Cleanup Crew's analytics payloads (spec §6.6), pure. An event is one of the 13 names; its
	target, outcome and reason are tokens from ShiftAnalyticsConstants.VOCABULARY (anything else becomes "other", so
	no player name, chat line or id can reach a field); its value is a clamped, finite number. The engine takes three
	custom fields, so:
	- field 1 packs the context "tags|platform|party|cohort|build" (AnalyticsContextUtils.field; low cardinality),
	- field 2 is the target (a cargo kind, "kind:source", a pile kind, a noise source, a fixed word),
	- field 3 is the outcome, or "outcome:reason" when there is a failure reason.
	The full record (with the session id, which stays out of the engine fields) goes to the server log.

	Also the small decisions the watch needs: before or after the quota, the cleaning bucket, what a Carry drop reason
	means, whether a pick-up opens an optional-salvage attempt, which Harlow mode change is an event, and which noise
	he most likely heard.

	@class ShiftAnalyticsUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RoundConstants = require(ReplicatedStorage.Shared.Features.Round.Data.RoundConstants)
local AnalyticsContextUtils = require(ServerScriptService.Features.Analytics.Utils.AnalyticsContextUtils)
local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)
local ShiftAnalyticsConstants = require(ServerScriptService.Features.Shift.Data.ShiftAnalyticsConstants)

-- Which session, experiment variants, device, crew size, cohort and build an event belongs to.
export type Context = {
	session: string,
	tags: string,
	platform: string,
	party: number,
	cohort: AnalyticsTypes.Cohort,
	build: string,
}

-- What a caller says about one event; every string is checked against the vocabulary.
export type Details = {
	target: string?,
	outcome: string?,
	reason: string?,
	value: number?,
}

-- One event as sent: the spec §6.6 fields, all cleaned.
export type Record = {
	event: string,
	session: string,
	build: string,
	tags: string,
	cohort: string,
	platform: string,
	party: number,
	target: string,
	outcome: string,
	reason: string,
	value: number,
}

-- How an optional-salvage attempt ended.
export type AttemptOutcome = "banked" | "dropped" | "thrown" | "caught" | "left" | "unbanked"

-- What the watch knows when a cargo item is picked up.
export type AttemptInput = {
	category: string,
	phase: string,
	sub: string,
	quotaMet: boolean,
	inBay: boolean,
}

-- One noise anyone could hear (Noise `made`); `at` is os.clock().
export type Noise = {
	source: string,
	position: Vector3,
	radius: number,
	at: number,
	makers: { number },
}

-- Mr. Harlow's published mode and target (OccupantConstants.MODE_ATTRIBUTE / TARGET_ATTRIBUTE; 0 = nobody).
export type Harlow = {
	mode: string,
	target: number,
}

-- Carry's drop reasons that end an attempt ("forced" is pocketing or banking, "destroyed" a reset). Only Mr. Harlow
-- kills in this game, so a death drop is a catch.
local DROP_OUTCOMES: { [string]: AttemptOutcome } = {
	drop = "dropped",
	throw = "thrown",
	death = "caught",
	removed = "left",
}

local MAX_PARTY = 99

local ShiftAnalyticsUtils = {}

function ShiftAnalyticsUtils.isEvent(name: string): boolean
	return ShiftAnalyticsConstants.EVENT_SET[name] == true
end

--[=[
	A vocabulary word, or ":"-joined words, unchanged; "none" for nothing; "other" for anything else.
]=]
function ShiftAnalyticsUtils.token(raw: string?): string
	if raw == nil or raw == "" then
		return "none"
	end
	if #raw > ShiftAnalyticsConstants.TOKEN_MAX then
		return "other"
	end
	for _, part in string.split(raw, ":") do
		if ShiftAnalyticsConstants.VOCABULARY[part] ~= true then
			return "other"
		end
	end
	return raw
end

--[=[
	A finite value in 0..VALUE_MAX, rounded to a tenth (nil and NaN read 0).
]=]
function ShiftAnalyticsUtils.value(raw: number?): number
	if raw == nil or raw ~= raw then
		return 0
	end
	local clamped = math.clamp(raw, 0, ShiftAnalyticsConstants.VALUE_MAX)
	return math.floor(clamped * 10 + 0.5) / 10
end

function ShiftAnalyticsUtils.session(jobId: string): string
	return if jobId == "" then "studio" else jobId
end

local function partySize(count: number): number
	if count ~= count then
		return 0
	end
	return math.clamp(math.floor(count), 0, MAX_PARTY)
end

function ShiftAnalyticsUtils.contextField(context: Context): string
	return AnalyticsContextUtils.field(context)
end

function ShiftAnalyticsUtils.outcomeField(details: Details): string
	local outcome = ShiftAnalyticsUtils.token(details.outcome)
	local reason = details.reason
	if reason == nil then
		return outcome
	end
	return `{outcome}:{ShiftAnalyticsUtils.token(reason)}`
end

--[=[
	The three engine custom fields: context, target, outcome[:reason].
]=]
function ShiftAnalyticsUtils.fields(context: Context, details: Details): { string }
	return {
		ShiftAnalyticsUtils.contextField(context),
		ShiftAnalyticsUtils.token(details.target),
		ShiftAnalyticsUtils.outcomeField(details),
	}
end

--[=[
	The full record (every spec §6.6 field), for the log and the recent ring.
]=]
function ShiftAnalyticsUtils.record(event: string, context: Context, details: Details): Record
	local reason = details.reason
	return {
		event = event,
		session = context.session,
		build = context.build,
		tags = context.tags,
		cohort = context.cohort,
		platform = context.platform,
		party = partySize(context.party),
		target = ShiftAnalyticsUtils.token(details.target),
		outcome = ShiftAnalyticsUtils.token(details.outcome),
		reason = if reason ~= nil then ShiftAnalyticsUtils.token(reason) else "none",
		value = ShiftAnalyticsUtils.value(details.value),
	}
end

--[=[
	The one event a finished catch sends, from the lives the player has left after it: "player_hit" (a knockdown, a
	life remains; value = the lives left) or "knocked_out" (the last life; value = seconds into the shift). Never both,
	so a catch is counted once. Pure.
]=]
function ShiftAnalyticsUtils.catchEvent(livesLeft: number, quotaTag: string, elapsed: number): (string, Details)
	if livesLeft > 0 then
		return "player_hit", { target = "harlow", outcome = quotaTag, value = livesLeft }
	end
	return "knocked_out", { target = "harlow", outcome = quotaTag, value = elapsed }
end

--[=[
	The crew_wiped record when the run ended "wiped" (Round's outcome: everyone was knocked out); nil for every other
	end. `elapsed` is the seconds into the shift.
]=]
function ShiftAnalyticsUtils.wipeDetails(outcome: string, elapsed: number): Details?
	if outcome ~= RoundConstants.OUTCOME_WIPED then
		return nil
	end
	return { target = "harlow", outcome = "wiped", value = elapsed }
end

function ShiftAnalyticsUtils.quotaTag(quotaMet: boolean): string
	return if quotaMet then "after_quota" else "before_quota"
end

--[=[
	A player's cleaning this shift, bucketed for shift_ended.
]=]
function ShiftAnalyticsUtils.pileBucket(piles: number): string
	if piles <= 0 then
		return "piles_0"
	elseif piles <= 2 then
		return "piles_1_2"
	elseif piles <= 5 then
		return "piles_3_5"
	end
	return "piles_6_plus"
end

function ShiftAnalyticsUtils.dropOutcome(reason: string): AttemptOutcome?
	return DROP_OUTCOMES[reason]
end

--[=[
	A salvage pick-up during a running shift, after the quota, outside the clock-out countdown and outside the loading
	bay: the player went back into the office for optional salvage.
]=]
function ShiftAnalyticsUtils.isSalvageAttempt(input: AttemptInput): boolean
	return input.category == "salvage"
		and input.phase == "running"
		and input.sub ~= "clockout"
		and input.quotaMet
		and not input.inBay
end

function ShiftAnalyticsUtils.inBox(point: Vector3, low: Vector3, high: Vector3): boolean
	return point.X >= low.X
		and point.X <= high.X
		and point.Y >= low.Y
		and point.Y <= high.Y
		and point.Z >= low.Z
		and point.Z <= high.Z
end

--[=[
	What one banked item was worth: salvage times the multiplier (rounded like the review), trash as is.
]=]
function ShiftAnalyticsUtils.credited(category: string, value: number, multiplier: number): number
	if category == "salvage" then
		return math.floor(value * multiplier + 0.5)
	end
	return value
end

--[=[
	The user ids in `after` that are not in `before` (the crew members who just punched out); nil reads as nobody.
]=]
function ShiftAnalyticsUtils.newlyPunched(before: { number }?, after: { number }?): { number }
	local seen: { [number]: boolean } = {}
	local beforeIds: { number } = before or {}
	for _, id in beforeIds do
		seen[id] = true
	end
	local fresh: { number } = {}
	local afterIds: { number } = after or {}
	for _, id in afterIds do
		if not seen[id] then
			table.insert(fresh, id)
		end
	end
	return fresh
end

--[=[
	"noise_investigation" when he starts investigating, "chase_started" when he starts chasing someone (or switches to
	someone else); nil otherwise.
]=]
function ShiftAnalyticsUtils.harlowChange(before: Harlow?, after: Harlow): string?
	local wasMode = if before ~= nil then before.mode else nil
	local wasTarget = if before ~= nil then before.target else 0
	-- Both decisions first: a returning `if after.mode == "investigate"` would make Luau refine `after.mode` to that
	-- word below and reject the "chase" comparison.
	local investigates = after.mode == "investigate" and wasMode ~= "investigate"
	local chases = after.mode == "chase" and after.target ~= 0 and (wasMode ~= "chase" or wasTarget ~= after.target)
	if investigates then
		return "noise_investigation"
	elseif chases then
		return "chase_started"
	end
	return nil
end

--[=[
	The noise Harlow most likely heard: the newest one within NOISE_MEMORY whose heard radius (radius × scale) reached
	`listener`; nil if none.
]=]
function ShiftAnalyticsUtils.heardNoise(noises: { Noise }, listener: Vector3, scale: number, now: number): Noise?
	for index = #noises, 1, -1 do
		local noise = noises[index]
		local recent = now - noise.at <= ShiftAnalyticsConstants.NOISE_MEMORY
		if recent and (listener - noise.position).Magnitude <= noise.radius * scale then
			return noise
		end
	end
	return nil
end

--[=[
	The source of the noise Harlow most likely heard (heardNoise); "unknown" when none.
]=]
function ShiftAnalyticsUtils.heardSource(noises: { Noise }, listener: Vector3, scale: number, now: number): string
	local noise = ShiftAnalyticsUtils.heardNoise(noises, listener, scale, now)
	return if noise ~= nil then noise.source else "unknown"
end

return ShiftAnalyticsUtils
