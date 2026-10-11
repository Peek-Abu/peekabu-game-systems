--!strict
--[=[
	ShiftAnalyticsConstants: Cleanup Crew's analytics vocabulary (spec §6.6). The 13 event names are the only ones
	ShiftAnalyticsSystem sends. Every target, outcome and reason must be a VOCABULARY word (the fixed words below,
	cargo ids and pile kinds), or a ":"-joined pair of them, so nothing a player typed or is called can reach a field.
	Static data (spec-exempt).

	@class ShiftAnalyticsConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

-- Spec §6.6, verbatim.
local EVENTS: { string } = {
	"contract_started",
	"first_cleanup_started",
	"pile_cleared",
	"cargo_picked_up",
	"cargo_dropped",
	"cargo_banked",
	"noise_investigation",
	"chase_started",
	"player_caught",
	"quota_met",
	"optional_salvage_attempted",
	"shift_ended",
	"replay_started",
}

local WORDS: { string } = {
	-- Nothing, or something outside the vocabulary.
	"none",
	"other",
	"unknown",
	"empty",
	-- contract_started / replay_started.
	"alternate",
	"fixed",
	"override",
	"first",
	"replay",
	"another_shift",
	"same_server",
	-- Before or after the quota; quota_met.
	"before_quota",
	"after_quota",
	"clearance",
	"met",
	-- pile_cleared and the cleaning buckets.
	"solo",
	"shared",
	"piles_0",
	"piles_1_2",
	"piles_3_5",
	"piles_6_plus",
	-- Where a cargo item came from.
	"open",
	"pile",
	"desk",
	"scatter",
	-- Drops and optional-salvage outcomes.
	"dropped",
	"thrown",
	"caught",
	"left",
	"banked",
	"failed",
	"unbanked",
	-- Noise sources (Vacuum, Cargo).
	"vacuum",
	"drop",
	"search",
	"rattle",
	-- player_caught.
	"harlow",
	-- How a run ended (Round's outcomes, Shift's clock out and reset) and the quota.
	"clockout",
	"timeout",
	"abandoned",
	"wiped",
	"cancelled",
	"reset",
	"quota_met",
	"quota_missed",
}

local EVENT_SET: { [string]: boolean } = {}
for _, name in EVENTS do
	EVENT_SET[name] = true
end

local VOCABULARY: { [string]: boolean } = {}
for _, word in WORDS do
	VOCABULARY[word] = true
end
for _, id in CargoRegistry.ids() do
	VOCABULARY[id] = true
end
for _, kind in VacuumConstants.PILE_KIND_LIST do
	VOCABULARY[kind] = true
end

-- Logged at info (the rest at debug): the events that tell a session's story in the server log.
local INFO_EVENTS: { [string]: boolean } = {
	contract_started = true,
	quota_met = true,
	optional_salvage_attempted = true,
	player_caught = true,
	shift_ended = true,
	replay_started = true,
}

return table.freeze({
	EVENTS = table.freeze(EVENTS),
	EVENT_SET = table.freeze(EVENT_SET),
	VOCABULARY = table.freeze(VOCABULARY),
	INFO_EVENTS = table.freeze(INFO_EVENTS),
	-- The build label; the place version is appended ("m5-v42"; "m5-dev" in Studio).
	BUILD_LABEL = "m5",
	-- A longer target/outcome/reason is "other" (the engine caps a field at 50 characters).
	TOKEN_MAX = 40,
	-- Event values are clamped to 0..VALUE_MAX and rounded to 0.1.
	VALUE_MAX = 100000,
	-- How many records the in-server ring keeps (the Studio test sink and the developer read it).
	RECENT_LIMIT = 300,
	-- How many recent noises are kept, and for how long (seconds) one can explain an investigation.
	NOISE_LIMIT = 16,
	NOISE_MEMORY = 2,
	-- The Death cause Mr. Harlow's catch kills with (OccupantCatchSystem).
	CATCH_CAUSE = "caught",
})
