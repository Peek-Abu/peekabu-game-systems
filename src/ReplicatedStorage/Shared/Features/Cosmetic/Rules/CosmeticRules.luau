--!strict
--[=[
	CosmeticRules: pure cosmetic logic, shared by both realms.

	- `owns`: free defaults always; a sticker through its pack; everything else through the `entitlements` slice
	  under its kind.
	- `lookFor`: one employee's look with every fallback applied (a retired, unowned or other employee's item and an
	  out-of-range style fall back to that employee's defaults), so a save can never put an employee in something
	  invalid.
	- `checkEquip` / `applyEquip`: whether a change is allowed, and the in-place write (the data layer's mutator
	  contract). Refusal reasons: "unknown item", "wrong kind", "not owned", "wrong employee", "bad slot",
	  "bad style", "no change".
	- `validateLoadout`: the `loadout` slice's data-layer invariant, structure only, so retiring an id never needs a
	  migration.

	@class CosmeticRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local CosmeticConstants = require(Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(Cosmetic.Data.CosmeticTypes)
local EntitlementRules = require(ReplicatedStorage.Shared.Features.Entitlement.Rules.EntitlementRules)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

type Item = CosmeticTypes.Item
type Look = CosmeticTypes.Look
type Loadout = CosmeticTypes.Loadout
type Change = CosmeticTypes.Change
type Owns = (id: string) -> boolean

local CosmeticRules = {}

local function isSlot(value: number, count: number): boolean
	return value == math.floor(value) and value >= 1 and value <= count
end

-- An item of `kind` this employee may use (its own, or a shared one).
local function usable(id: string, kind: CosmeticTypes.Kind, employee: string): Item?
	local item = CosmeticRegistry.get(id)
	if item == nil or item.kind ~= kind then
		return nil
	end
	if item.employee ~= nil and item.employee ~= employee then
		return nil
	end
	return item
end

local function isEmployee(id: string): boolean
	local item = CosmeticRegistry.get(id)
	return item ~= nil and item.kind == "employee"
end

function CosmeticRules.owns(entitlements: PlayerDataTypes.Entitlements, id: string): boolean
	local item = CosmeticRegistry.get(id)
	if item == nil then
		return false
	end
	if item.source == "default" then
		return true
	end
	if item.kind == "sticker" then
		local pack = item.pack
		return pack ~= nil and CosmeticRules.owns(entitlements, pack)
	end
	return EntitlementRules.owns(entitlements, item.kind, id)
end

--[=[
	The employee's look with every fallback applied, as a fresh table. With no saved look: the employee's free skin,
	idle and emote (in slot 1).
]=]
function CosmeticRules.lookFor(loadout: Loadout, employee: string, owns: Owns): Look
	local defaultSkin = CosmeticRegistry.defaultOf(employee, "skin").id
	local defaultIdle = CosmeticRegistry.defaultOf(employee, "idle").id
	local wheel = CosmeticConstants.emptyWheel()
	local saved = loadout.looks[employee]
	if saved == nil then
		wheel[1] = CosmeticRegistry.defaultOf(employee, "emote").id
		return { skin = defaultSkin, style = 1, idle = defaultIdle, wheel = wheel }
	end
	local skin = defaultSkin
	local style = 1
	local skinItem = usable(saved.skin, "skin", employee)
	if skinItem ~= nil and owns(saved.skin) then
		skin = saved.skin
		if isSlot(saved.style, skinItem.styles or 1) then
			style = saved.style
		end
	end
	local idle = defaultIdle
	if usable(saved.idle, "idle", employee) ~= nil and owns(saved.idle) then
		idle = saved.idle
	end
	for slot = 1, CosmeticConstants.WHEEL_SLOTS do
		local id = saved.wheel[slot]
		if type(id) == "string" and usable(id, "emote", employee) ~= nil and owns(id) then
			wheel[slot] = id
		end
	end
	return { skin = skin, style = style, idle = idle, wheel = wheel }
end

-- The employee the player plays as: the saved one when it is a registered, owned employee, else the default.
function CosmeticRules.currentEmployee(loadout: Loadout, owns: Owns): string
	if isEmployee(loadout.current) and owns(loadout.current) then
		return loadout.current
	end
	return CosmeticConstants.DEFAULT_EMPLOYEE
end

-- Checks a wheel or sticker slot change shared by emotes and stickers.
local function checkSlotItem(
	id: string,
	current: string,
	kind: CosmeticTypes.Kind,
	employee: string?,
	owns: Owns
): (boolean, string?)
	if id == "" then
		if current == "" then
			return false, "no change"
		end
		return true, nil
	end
	local item = CosmeticRegistry.get(id)
	if item == nil then
		return false, "unknown item"
	end
	if item.kind ~= kind then
		return false, "wrong kind"
	end
	if employee ~= nil and item.employee ~= nil and item.employee ~= employee then
		return false, "wrong employee"
	end
	if not owns(id) then
		return false, "not owned"
	end
	if current == id then
		return false, "no change"
	end
	return true, nil
end

function CosmeticRules.checkEquip(loadout: Loadout, change: Change, owns: Owns): (boolean, string?)
	if change.kind == "employee" then
		if not CosmeticRegistry.has(change.id) then
			return false, "unknown item"
		end
		if not isEmployee(change.id) then
			return false, "wrong kind"
		end
		if not owns(change.id) then
			return false, "not owned"
		end
		if CosmeticRules.currentEmployee(loadout, owns) == change.id then
			return false, "no change"
		end
		return true, nil
	elseif change.kind == "skin" then
		local item = CosmeticRegistry.get(change.id)
		if item == nil then
			return false, "unknown item"
		end
		local employee = item.employee
		if item.kind ~= "skin" or employee == nil then
			return false, "wrong kind"
		end
		if not owns(change.id) then
			return false, "not owned"
		end
		if not isSlot(change.style, item.styles or 1) then
			return false, "bad style"
		end
		local look = CosmeticRules.lookFor(loadout, employee, owns)
		if look.skin == change.id and look.style == change.style then
			return false, "no change"
		end
		return true, nil
	elseif change.kind == "idle" then
		if not isEmployee(change.employee) then
			return false, "unknown item"
		end
		local item = CosmeticRegistry.get(change.id)
		if item == nil then
			return false, "unknown item"
		end
		if item.kind ~= "idle" then
			return false, "wrong kind"
		end
		if item.employee ~= nil and item.employee ~= change.employee then
			return false, "wrong employee"
		end
		if not owns(change.id) then
			return false, "not owned"
		end
		if CosmeticRules.lookFor(loadout, change.employee, owns).idle == change.id then
			return false, "no change"
		end
		return true, nil
	elseif change.kind == "emote" then
		if not isEmployee(change.employee) then
			return false, "unknown item"
		end
		if not isSlot(change.slot, CosmeticConstants.WHEEL_SLOTS) then
			return false, "bad slot"
		end
		local current = CosmeticRules.lookFor(loadout, change.employee, owns).wheel[change.slot]
		return checkSlotItem(change.id, current, "emote", change.employee, owns)
	else
		if not isSlot(change.slot, CosmeticConstants.STICKER_SLOTS) then
			return false, "bad slot"
		end
		local current = loadout.stickers[change.slot] or ""
		return checkSlotItem(change.id, current, "sticker", nil, owns)
	end
end

-- The employee's saved look, created from its resolved look when missing.
local function ensureLook(loadout: Loadout, employee: string, owns: Owns): Look
	local look = loadout.looks[employee]
	if look == nil then
		look = CosmeticRules.lookFor(loadout, employee, owns)
		loadout.looks[employee] = look
	end
	return look
end

-- Puts `id` in `slots[slot]`, taking it out of any other slot (an item sits in one slot at a time).
local function place(slots: { string }, slot: number, id: string)
	if id ~= "" then
		for index, other in slots do
			if other == id then
				slots[index] = ""
			end
		end
	end
	slots[slot] = id
end

--[=[
	Writes a change that `checkEquip` allowed, in place. Returns true (the mutator's "changed").
]=]
function CosmeticRules.applyEquip(loadout: Loadout, change: Change, owns: Owns): boolean
	if change.kind == "employee" then
		loadout.current = change.id
	elseif change.kind == "skin" then
		local item = CosmeticRegistry.get(change.id)
		local employee = if item ~= nil then item.employee else nil
		if employee == nil then
			return false
		end
		local look = ensureLook(loadout, employee, owns)
		look.skin = change.id
		look.style = change.style
	elseif change.kind == "idle" then
		ensureLook(loadout, change.employee, owns).idle = change.id
	elseif change.kind == "emote" then
		place(ensureLook(loadout, change.employee, owns).wheel, change.slot, change.id)
	else
		place(loadout.stickers, change.slot, change.id)
	end
	return true
end

local function isId(value: unknown): boolean
	return type(value) == "string" and #value >= 1 and #value <= CosmeticConstants.MAX_ID_LENGTH
end

-- Typed as a list, checked as if it were anything (a save written by older code, or a bad op).
local function isSlotList(value: { string }, count: number): boolean
	if type(value) ~= "table" then
		return false
	end
	local n = 0
	for key: unknown, entry: unknown in pairs(value) do
		if type(key) ~= "number" or not isSlot(key, count) then
			return false
		end
		if type(entry) ~= "string" or #entry > CosmeticConstants.MAX_ID_LENGTH then
			return false
		end
		n += 1
	end
	return n == count
end

--[=[
	The `loadout` slice's invariant: structure only. Unknown ids pass (lookFor falls back), so retiring an item never
	needs a migration.
]=]
function CosmeticRules.validateLoadout(loadout: Loadout): (boolean, string?)
	if not isId(loadout.current) then
		return false, "loadout.current must be a 1-64 character id"
	end
	if type(loadout.picked) ~= "boolean" then
		return false, "loadout.picked must be a boolean"
	end
	if type(loadout.looks) ~= "table" then
		return false, "loadout.looks must be a table"
	end
	for employee, look in loadout.looks do
		if not isId(employee) or type(look) ~= "table" then
			return false, "loadout.looks has a bad entry"
		end
		if not isId(look.skin) or not isId(look.idle) then
			return false, `loadout.looks.{employee} needs a skin and an idle`
		end
		if type(look.style) ~= "number" or not isSlot(look.style, CosmeticConstants.MAX_STYLES) then
			return false, `loadout.looks.{employee}.style must be 1-{CosmeticConstants.MAX_STYLES}`
		end
		if not isSlotList(look.wheel, CosmeticConstants.WHEEL_SLOTS) then
			return false, `loadout.looks.{employee}.wheel must be {CosmeticConstants.WHEEL_SLOTS} ids`
		end
	end
	if not isSlotList(loadout.stickers, CosmeticConstants.STICKER_SLOTS) then
		return false, `loadout.stickers must be {CosmeticConstants.STICKER_SLOTS} ids`
	end
	if type(loadout.seen) ~= "table" then
		return false, "loadout.seen must be a table"
	end
	for id, value in loadout.seen do
		if not isId(id) or value ~= true then
			return false, "loadout.seen has a bad entry"
		end
	end
	return true, nil
end

return CosmeticRules
