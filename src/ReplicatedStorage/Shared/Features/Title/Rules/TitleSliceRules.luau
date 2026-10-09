--!strict
--[=[
	TitleSliceRules: the PURE data-layer invariants for the two title slices (titles design spec,
	Decision 2). Registered as the per-slice validators via PlayerDataSliceSystem, so they hold for ANY write
	path into the slice — a service method, an admin command, or a raw transaction() op none of
	them anticipated.

	LENIENT-VS-HARD ASYMMETRY (the spec's validation table):
	- `titles.earned`: ids must be non-empty strings stored as `true` (HARD); an id no longer in
	  TitleRegistry is TOLERATED — the retired-cosmetic rule. This validator runs against the
	  WHOLE resulting slice on every write, so rejecting a dead id would freeze the entire save
	  until the corpse was removed; nothing is lost by allowing it, since every write path asserts
	  registration before storing.
	- `equippedTitle.equipped`: absent (wearing nothing) or a non-empty string (HARD). Unknown ids
	  are likewise tolerated — a retired id must not freeze a slot either.

	CROSS-SLICE MEMBERSHIP IS DELIBERATELY NOT HERE. A per-slice validator receives only its own
	slice's value (the exact limitation PlayerDataConstants.validateSlotState documents), so
	"equipped ∈ earned" cannot be checked from inside the slot slice. It is enforced where
	Customization enforces cosmetic ownership — POLICY in the service: TitleServiceServer:equip
	refuses unearned ids, and revoke clears equipped ATOMICALLY in the same transaction that
	removes the earn. Same shape/policy split Inventory and Customization already use.

	Parameters are TYPED and still runtime-guarded, matching validateBank/validateAppearance: the
	data layer hands over raw persisted values, so the type(...) checks are what actually defend.

	@class TitleSliceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local TitleSliceRules = {}

--[=[
	The account-wide "titles" slice invariant: `earned` exists and maps non-empty string ids to
	`true`. Registry membership is intentionally NOT checked (retirement leniency — see header).
	@param titles PlayerDataTypes.Titles -- the raw slice value
	@return boolean -- ok
	@return string? -- reason on failure
]=]
function TitleSliceRules.validateTitles(titles: PlayerDataTypes.Titles): (boolean, string?)
	if type(titles) ~= "table" then
		return false, `titles must be a table, got {type(titles)}`
	end
	if type(titles.earned) ~= "table" then
		return false, `titles.earned must be a table, got {type(titles.earned)}`
	end
	for id, flag in titles.earned do
		if type(id) ~= "string" or id == "" then
			return false, `titles.earned has a non-string or empty id {tostring(id)}`
		end
		if flag ~= true then
			return false, `titles.earned."{id}" must be stored as true`
		end
		-- LENIENT: an id missing from TitleRegistry passes. Retirement must never freeze a save
		-- (the 5c retired-cosmetic rule; see the class header for the full reasoning).
	end
	return true
end

--[=[
	The slot-scoped "equippedTitle" slice invariant: `equipped` is absent or a non-empty string.
	Earn-membership is intentionally NOT checked here (cross-slice; see the class header).
	@param state PlayerDataTypes.EquippedTitle -- the raw slice value
	@return boolean -- ok
	@return string? -- reason on failure
]=]
function TitleSliceRules.validateEquippedTitle(state: PlayerDataTypes.EquippedTitle): (boolean, string?)
	if type(state) ~= "table" then
		return false, `equippedTitle must be a table, got {type(state)}`
	end
	local equipped = state.equipped
	if equipped == nil then
		return true
	end
	if type(equipped) ~= "string" or equipped == "" then
		return false, `equippedTitle.equipped must be a non-empty string when present, got {tostring(equipped)}`
	end
	return true
end

return TitleSliceRules
