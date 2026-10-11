--!strict
--[=[
	ShiftVariantRules: which A/B variant a shift plays (Cleanup Crew spec §4 "Variant switch (A/B from the validation
	plan, rewards unchanged): B (default) some salvage spawns hidden under piles; A all salvage spawns exposed"). In
	order:
	1. the developer's Workspace override ("A" or "B", any case) wins: source "override";
	2. "fixed" mode always plays the fixed variant (B): source "fixed";
	3. "alternate" mode plays a start variant on the server's first shift and flips it every shift after: the fixed
	   variant (B) in Studio (no JobId), else djb2(JobId) even → B, odd → A, so live servers counterbalance the order. The same
	   crew plays both arms in one session. Source "alternate".
	The variant only decides where salvage spawns (OfficeSpawnUtils); no value, multiplier or quota reads it. Pure.

	@class ShiftVariantRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type Variant = ShiftTypes.Variant

export type PickInput = {
	mode: ShiftTypes.VariantMode,
	fixed: Variant,
	-- The Workspace attribute's raw value (anything; only "A"/"B" count).
	override: unknown,
	-- ShiftAnalyticsUtils.session(game.JobId): "studio" when there is no JobId.
	session: string,
	-- Shifts started on this server, counting this one.
	shift: number,
}

local HASH_MODULUS = 2147483647

local ShiftVariantRules = {}

function ShiftVariantRules.parseOverride(raw: unknown): Variant?
	if type(raw) ~= "string" then
		return nil
	end
	local trimmed = string.upper(string.match(raw, "^%s*(.-)%s*$") or "")
	if trimmed == "A" then
		return "A"
	elseif trimmed == "B" then
		return "B"
	end
	return nil
end

--[=[
	djb2 over the bytes of `text`, kept below 2^31 - 1.
]=]
function ShiftVariantRules.hash(text: string): number
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + string.byte(text, index)) % HASH_MODULUS
	end
	return value
end

function ShiftVariantRules.other(variant: Variant): Variant
	return if variant == "A" then "B" else "A"
end

function ShiftVariantRules.pick(input: PickInput): (Variant, ShiftTypes.VariantSource)
	-- Annotated locals: Luau widens an unannotated singleton-union local to `string`.
	local override: Variant? = ShiftVariantRules.parseOverride(input.override)
	if override ~= nil then
		return override, "override"
	end
	if input.mode == "fixed" then
		return input.fixed, "fixed"
	end
	local first: Variant
	if input.session == "" or input.session == "studio" then
		first = input.fixed
	elseif ShiftVariantRules.hash(input.session) % 2 == 0 then
		first = "B"
	else
		first = "A"
	end
	local shift = math.max(1, math.floor(input.shift))
	local variant: Variant = if shift % 2 == 1 then first else ShiftVariantRules.other(first)
	return variant, "alternate"
end

return ShiftVariantRules
