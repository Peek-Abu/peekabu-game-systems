--!strict
--[=[
	PlayerDataPathUtils: the path algebra for the slot-aware profile.

	Profile data is addressed by a DOTTED path (`slots.2.currency`, `account.settings`) rather than a
	bare root key, because slots nest inside the profile (see the character-slots design). Two derived
	forms matter and are easy to conflate, so they get names here rather than being re-derived ad hoc:

	- The PATTERN (`slots.*.currency`) is the REGISTRATION key: a slice is registered once, and its
	  default/validator apply to every slot. Looking a validator up by the concrete path would find
	  nothing for slot 2 and silently enforce the invariant on slot 1 only.
	- The SLICE NAME (`currency`) is the StateSyncServerStore ATOM key: the reactive mirror is per slice, not
	  per slot (the manifest's reader projects the active slot), so the atom name must not carry the
	  slot index.

	@class PlayerDataPathUtils
]=]

local SLOTS = "slots"
local ACCOUNT = "account"
local WILDCARD = "*"

local PlayerDataPathUtils = {}

PlayerDataPathUtils.SLOTS = SLOTS
PlayerDataPathUtils.ACCOUNT = ACCOUNT

--[=[
	Splits a dotted path into its segments.
	@param path string -- e.g. "slots.2.currency" (must be non-empty)
	@return { string } -- e.g. { "slots", "2", "currency" }
]=]
function PlayerDataPathUtils.segments(path: string): { string }
	assert(path ~= "", "PlayerDataPathUtils: path must not be empty")
	local out: { string } = {}
	for segment in string.gmatch(path, "[^.]+") do
		table.insert(out, segment)
	end
	return out
end

--[=[
	The concrete path to one slice of one slot.
	@param slice string -- The slice name (e.g. "currency")
	@param slotIndex number -- A positive integer, 1..MAX_SLOTS
	@return string -- e.g. "slots.2.currency"
]=]
function PlayerDataPathUtils.forSlot(slice: string, slotIndex: number): string
	assert(
		slotIndex == math.floor(slotIndex) and slotIndex > 0,
		`PlayerDataPathUtils.forSlot: slotIndex must be a positive integer, got {slotIndex}`
	)
	return `{SLOTS}.{slotIndex}.{slice}`
end

--[=[
	The path to one account-wide slice.
	@param slice string -- The slice name (e.g. "settings")
	@return string -- e.g. "account.settings"
]=]
function PlayerDataPathUtils.forAccount(slice: string): string
	return `{ACCOUNT}.{slice}`
end

--[=[
	The REGISTRATION key for a slot-scoped slice: slot-index-agnostic.
	@param slice string -- The slice name
	@return string -- e.g. "slots.*.currency"
]=]
function PlayerDataPathUtils.slotPattern(slice: string): string
	return `{SLOTS}.{WILDCARD}.{slice}`
end

--[=[
	Normalises a concrete path to its registration pattern by wildcarding the slot-index POSITION
	(segment 2, only when segment 1 is "slots") — never by sniffing whether a segment looks numeric.
	A numerically-named slice (e.g. "123") must normalise identically to any other name.
	`pattern(forSlot(slice, n)) == slotPattern(slice)` for every n and every slice — that identity is
	what makes a validator registered once hold for EVERY slot.
	@param path string -- A concrete path
	@return string -- Its pattern
]=]
function PlayerDataPathUtils.pattern(path: string): string
	local segs = PlayerDataPathUtils.segments(path)
	if segs[1] == SLOTS and segs[2] ~= nil then
		segs[2] = WILDCARD
	end
	return table.concat(segs, ".")
end

--[=[
	The slice name (last segment) — the StateSyncServerStore atom key for this path.
	@param path string
	@return string
]=]
function PlayerDataPathUtils.sliceName(path: string): string
	local segments = PlayerDataPathUtils.segments(path)
	return segments[#segments]
end

--[=[
	The slot this path addresses, or nil if it is not slot-scoped (account path or bare root key).
	Callers use this to skip mirroring a write aimed at a NON-active slot (the atom holds the active
	slot only, so re-mirroring on such a write would be a no-op at best and misleading at worst).
	@param path string
	@return number? -- The slot index, or nil
]=]
function PlayerDataPathUtils.slotIndex(path: string): number?
	local segments = PlayerDataPathUtils.segments(path)
	if segments[1] ~= SLOTS then
		return nil
	end
	return tonumber(segments[2])
end

return PlayerDataPathUtils
