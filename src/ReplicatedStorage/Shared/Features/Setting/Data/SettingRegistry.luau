--!strict
--[=[
	SettingRegistry: the settings catalogue (the ItemRegistry contract: validated, loud at boot, no
	re-registration). Shared, because the server validates every change against the same definitions the
	client renders. The base settings (SettingConstants.BASE) are registered at load; a game registers its
	own at load too. `ids()` keeps registration order, so a settings screen lists them as declared.

	@class SettingRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingConstants = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingConstants)
local SettingTypes = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingTypes)
local SettingKeybindUtils = require(ReplicatedStorage.Shared.Features.Setting.Utils.SettingKeybindUtils)

type SettingDef = SettingTypes.SettingDef

local defs: { [string]: SettingDef } = {}
local order: { string } = {}

local function check(id: string, def: SettingDef)
	assert(#id >= 1 and #id <= SettingConstants.MAX_KEY_LENGTH, `setting id "{id}" must be 1-64 characters`)
	assert(defs[id] == nil, `setting "{id}" is already registered`)
	if def.kind == "number" then
		assert(def.min < def.max, `setting "{id}": min must be below max`)
		assert(def.default >= def.min and def.default <= def.max, `setting "{id}": default is out of range`)
		local step = def.step
		if step ~= nil then
			assert(step > 0, `setting "{id}": step must be positive`)
		end
	elseif def.kind == "choice" then
		assert(#def.options > 0, `setting "{id}": a choice needs options`)
		assert(table.find(def.options, def.default) ~= nil, `setting "{id}": default is not an option`)
	elseif def.kind == "keybinds" then
		local map, reason = SettingKeybindUtils.parse(def.default)
		assert(map ~= nil, `setting "{id}": bad default keybinds ({reason})`)
	end
end

local SettingRegistry = {}

function SettingRegistry.register(id: string, def: SettingDef)
	check(id, def)
	defs[id] = table.freeze(table.clone(def))
	table.insert(order, id)
end

function SettingRegistry.get(id: string): SettingDef?
	return defs[id]
end

--[=[
	Every setting id, in registration order (base settings first).
]=]
function SettingRegistry.ids(): { string }
	return table.clone(order)
end

for _, base in SettingConstants.BASE do
	SettingRegistry.register(base.id, base.def)
end

return SettingRegistry
