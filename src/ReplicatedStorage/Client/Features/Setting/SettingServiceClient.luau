--!strict
--[=[
	SettingServiceClient: the local player's settings (design:
	docs/superpowers/specs/2026-10-09-settings-design.md).

	- `get(id)` reads the replicated `settings` slice with registered defaults, overlaid by values this
	  client has just set (so a dragged slider never snaps back while the request travels).
	- `set(id, value)` checks the value with the same SettingRules the server uses, applies it locally at
	  once, and sends it after SEND_DEBOUNCE. The server's confirmation (the replicated slice) replaces the
	  local value; if none arrives within PENDING_TIMEOUT the slice's value wins again.
	- `observe(id, fn)` calls `fn(value)` now and on every change. The base settings are applied here:
	  volumes → Sound groups, `cameraShake` → Camera, `keybinds` → Input overrides.

	Spec-exempt shell (Charm subscription, timers, ByteNet, the other services); the rules are the specced
	SettingRules, SettingRegistry and SettingKeybindUtils.

	@class SettingServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local SettingConstants = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingConstants)
local SettingRegistry = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingRegistry)
local SettingEvents = require(ReplicatedStorage.Shared.Features.Setting.Net.SettingEvents)
local SettingRules = require(ReplicatedStorage.Shared.Features.Setting.Rules.SettingRules)
local SettingKeybindUtils = require(ReplicatedStorage.Shared.Features.Setting.Utils.SettingKeybindUtils)
local SoundConstants = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundConstants)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputTypes = require(ReplicatedStorage.Client.Features.Input.Data.InputTypes)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

type SettingValue = PlayerDataTypes.SettingValue
type Observer = (value: SettingValue) -> ()
type Pending = { value: SettingValue }

local log = Logger.new("SettingServiceClient")

local pending: { [string]: Pending } = {}
local observers: { [string]: { Observer } } = {}
local lastNotified: { [string]: SettingValue } = {}
local sendTimers: { [string]: thread } = {}
-- Actions the keybinds setting currently overrides, so a removed rebind restores the default.
local overridden: { [string]: true } = {}
local stoppers: { () -> () } = {}

local function current(id: string): SettingValue?
	local local_ = pending[id]
	if local_ ~= nil then
		return local_.value
	end
	return SettingRules.valueOf(StateSyncClientStore.settings(), id)
end

local function notify(id: string)
	local value = current(id)
	if value == nil or lastNotified[id] == value then
		return
	end
	lastNotified[id] = value
	local list = observers[id]
	if list == nil then
		return
	end
	for _, observer in list do
		task.spawn(function()
			local ok, err = pcall(function()
				observer(value)
			end)
			if not ok then
				log:error(`setting "{id}" observer errored: {err}`)
			end
		end)
	end
end

-- Shows `value` locally now and sends `payload` once the player stops changing this setting.
local function stage(id: string, value: SettingValue, payload: { [string]: SettingValue })
	local entry: Pending = { value = value }
	pending[id] = entry
	notify(id)
	local timer = sendTimers[id]
	if timer ~= nil then
		task.cancel(timer)
	end
	sendTimers[id] = task.delay(SettingConstants.SEND_DEBOUNCE, function()
		sendTimers[id] = nil
		SettingEvents.packets.Request.send(payload)
		task.delay(SettingConstants.PENDING_TIMEOUT, function()
			if pending[id] == entry then
				pending[id] = nil
				notify(id)
			end
		end)
	end)
end

local function toInputBindings(names: { keyboard: { string }, gamepad: { string } }): InputTypes.Bindings
	local keys = SettingKeybindUtils.toBindings(names)
	return {
		keyboard = if #keys.keyboard > 0 then keys.keyboard else nil,
		gamepad = if #keys.gamepad > 0 then keys.gamepad else nil,
	}
end

local function applyKeybinds(value: SettingValue)
	if type(value) ~= "string" then
		return
	end
	local map = SettingKeybindUtils.parse(value)
	if map == nil then
		return
	end
	for actionId in overridden do
		if map[actionId] == nil and InputActionRegistry.has(actionId) then
			InputServiceClient:setOverride(actionId, nil)
		end
	end
	table.clear(overridden)
	for actionId, names in map do
		-- An action this game no longer has is ignored, so a removed action never breaks a save.
		if InputActionRegistry.has(actionId) then
			InputServiceClient:setOverride(actionId, toInputBindings(names))
			overridden[actionId] = true
		end
	end
end

export type SettingServiceClient = {
	dependencies: { string },
	start: (self: SettingServiceClient) -> (),
	stop: (self: SettingServiceClient) -> (),
	get: (self: SettingServiceClient, id: string) -> SettingValue?,
	set: (self: SettingServiceClient, id: string, value: SettingValue) -> (boolean, string?),
	reset: (self: SettingServiceClient, id: string?) -> (),
	observe: (self: SettingServiceClient, id: string, observer: Observer) -> () -> (),
	getState: (self: SettingServiceClient) -> { [string]: any },
}

local SettingServiceClient: SettingServiceClient = {
	dependencies = { "StateSyncServiceClient", "SoundServiceClient", "CameraServiceClient", "InputServiceClient" },

	--[=[
		Follows the replicated slice (clearing local values the server has confirmed) and applies the base
		settings.
	]=]
	start = function(self)
		table.insert(
			stoppers,
			Charm.subscribe(StateSyncClientStore.settings, function(settings: PlayerDataTypes.Settings)
				for id, entry in pending do
					if SettingRules.valueOf(settings, id) == entry.value then
						pending[id] = nil
					end
				end
				for id in observers do
					notify(id)
				end
			end)
		)

		-- One call per group (not a loop): iterating a list of group names widens them to `string`.
		local function bindVolume(group: SoundTypes.SoundGroupName)
			local baseVolume = SoundConstants.DEFAULT_GROUP_VOLUMES[group]
			table.insert(
				stoppers,
				self:observe(SettingConstants.VOLUME_SETTINGS[group], function(value)
					if type(value) == "number" then
						SoundServiceClient:setGroupVolume(group, baseVolume * value)
					end
				end)
			)
		end
		bindVolume("Music")
		bindVolume("SFX")
		bindVolume("UI")
		bindVolume("Ambient")
		table.insert(
			stoppers,
			self:observe(SettingConstants.CAMERA_SHAKE, function(value)
				if type(value) == "number" then
					CameraServiceClient:setShakeScale(value)
				end
			end)
		)
		table.insert(stoppers, self:observe(SettingConstants.KEYBINDS, applyKeybinds))
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		A setting's current value (nil for an unregistered id).
	]=]
	get = function(_self, id)
		return current(id)
	end,

	--[=[
		Changes a setting: checked locally with the server's own rules, shown at once, sent after a short
		debounce. False with a reason (nothing sent) when the value does not fit the definition.
	]=]
	set = function(_self, id, value)
		local def = SettingRegistry.get(id)
		if def == nil then
			return false, `unknown setting "{id}"`
		end
		local coerced, reason = SettingRules.coerce(def, value)
		if coerced == nil then
			return false, reason
		end
		stage(id, coerced, SettingRules.buildSet(id, coerced))
		return true, nil
	end,

	--[=[
		Returns one setting (or, with no id, every setting) to its default.
	]=]
	reset = function(_self, id)
		if id ~= nil then
			local def = SettingRegistry.get(id)
			if def ~= nil then
				stage(id, def.default, SettingRules.buildReset(id))
			end
			return
		end
		for _, settingId in SettingRegistry.ids() do
			local def = SettingRegistry.get(settingId)
			if def ~= nil then
				pending[settingId] = { value = def.default }
				notify(settingId)
			end
		end
		SettingEvents.packets.Request.send(SettingRules.buildResetAll())
	end,

	--[=[
		Calls `observer(value)` now and whenever the setting changes. Returns a function that stops it.
	]=]
	observe = function(_self, id, observer)
		local list = observers[id]
		if list == nil then
			list = {}
			observers[id] = list
		end
		table.insert(list, observer)
		local value = current(id)
		if value ~= nil then
			lastNotified[id] = value
			task.spawn(observer, value)
		end
		return function()
			local remaining = observers[id]
			local index = if remaining ~= nil then table.find(remaining, observer) else nil
			if remaining ~= nil and index ~= nil then
				table.remove(remaining, index)
			end
		end
	end,

	getState = function(_self)
		local values: { [string]: SettingValue } = {}
		for _, id in SettingRegistry.ids() do
			local value = current(id)
			if value ~= nil then
				values[id] = value
			end
		end
		local waiting = 0
		for _ in pending do
			waiting += 1
		end
		return { values = values, pending = waiting }
	end,
}

return SettingServiceClient
