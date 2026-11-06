--!strict
--[=[
	TipRegistry: the one-line tips a player sees the first time something happens (the first catch, the overtime
	offer, the first ability use), each shown once per account (TipServiceServer). Shared, because it also registers
	the Tips setting (on by default) that the hub's Settings page shows and the server checks; requiring this module
	is what makes that setting exist in a realm.

	Player-facing words: about a 3rd-grade reading level, one line each.

	@class TipRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingRegistry = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingRegistry)

local SETTING = "tips"

local TEXT: { [string]: string } = {
	firstCatch = "Mr. Harlow got you! Hide under a desk when you hear him coming.",
	overtime = "Overtime! Sign the sheet in the truck: treasures pay more, but Mr. Harlow gets faster.",
	firstAbility = "Nice! Your power needs a little time to charge before you can use it again.",
}

if SettingRegistry.get(SETTING) == nil then
	SettingRegistry.register(SETTING, { kind = "boolean", default = true })
end

local TipRegistry = {
	-- The setting id that turns every tip on or off.
	SETTING = SETTING,
	-- How long a tip stays on screen (seconds), and the longest a tip may be.
	SECONDS = 7,
	MAX_LENGTH = 100,
}

function TipRegistry.text(id: string): string?
	return TEXT[id]
end

function TipRegistry.has(id: string): boolean
	return TEXT[id] ~= nil
end

return table.freeze(TipRegistry)
