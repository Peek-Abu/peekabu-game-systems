--!strict
--[=[
	SettingConstants: the base's own settings, limits and client timing. A game registers more through
	SettingRegistry.register at load.

	@class SettingConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingTypes = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingTypes)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

export type BaseSetting = { id: string, def: SettingTypes.SettingDef }

-- Volumes multiply each Sound group's default volume (SoundConstants.DEFAULT_GROUP_VOLUMES).
local BASE: { BaseSetting } = {
	{ id = "musicVolume", def = { kind = "number", default = 1, min = 0, max = 1, step = 0.05 } },
	{ id = "sfxVolume", def = { kind = "number", default = 1, min = 0, max = 1, step = 0.05 } },
	{ id = "uiVolume", def = { kind = "number", default = 1, min = 0, max = 1, step = 0.05 } },
	{ id = "ambientVolume", def = { kind = "number", default = 1, min = 0, max = 1, step = 0.05 } },
	-- Accessibility: scales every camera shake (0 = none).
	{ id = "cameraShake", def = { kind = "number", default = 1, min = 0, max = 1, step = 0.05 } },
	{ id = "keybinds", def = { kind = "keybinds", default = "" } },
}

-- The volume setting that drives each Sound group.
local volumeSettings: { [SoundTypes.SoundGroupName]: string } = {
	Music = "musicVolume",
	SFX = "sfxVolume",
	UI = "uiVolume",
	Ambient = "ambientVolume",
}

-- Annotated (the SoundConstants pattern) so freezing the module keeps the group names' literal types.
local SettingConstants: {
	BASE: { BaseSetting },
	VOLUME_SETTINGS: { [SoundTypes.SoundGroupName]: string },
	CAMERA_SHAKE: string,
	KEYBINDS: string,
	MAX_KEY_LENGTH: number,
	MAX_KEYBINDS_LENGTH: number,
	MAX_KEYS_PER_DEVICE: number,
	MAX_STORED: number,
	SEND_DEBOUNCE: number,
	PENDING_TIMEOUT: number,
} =
	table.freeze({
		BASE = BASE,
		VOLUME_SETTINGS = volumeSettings,
		CAMERA_SHAKE = "cameraShake",
		KEYBINDS = "keybinds",
		-- Setting ids, action ids and choice options are 1-64 characters.
		MAX_KEY_LENGTH = 64,
		-- The keybinds string's length cap, and keys per device per action.
		MAX_KEYBINDS_LENGTH = 1024,
		MAX_KEYS_PER_DEVICE = 4,
		-- Stored (non-default) values per account.
		MAX_STORED = 64,
		-- The client sends a changed setting this long after the last change (a dragged slider sends once).
		SEND_DEBOUNCE = 0.3,
		-- How long the client shows a sent value before falling back to what the server confirmed.
		PENDING_TIMEOUT = 3,
	})

return SettingConstants
