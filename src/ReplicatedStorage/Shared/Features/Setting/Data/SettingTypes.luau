--!strict
--[=[
	SettingTypes: setting definitions and the keybinds shape (design:
	docs/superpowers/specs/2026-10-09-settings-design.md).

	@class SettingTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

export type SettingValue = PlayerDataTypes.SettingValue

-- A slider: requests outside [min, max] are refused; `step` snaps accepted values.
export type NumberSetting = { kind: "number", default: number, min: number, max: number, step: number? }
export type BooleanSetting = { kind: "boolean", default: boolean }
-- One of a fixed list of strings (a quality preset, a colourblind mode).
export type ChoiceSetting = { kind: "choice", default: string, options: { string } }
-- The player's rebinds, as the compact string SettingKeybindUtils parses.
export type KeybindsSetting = { kind: "keybinds", default: string }

export type SettingDef = NumberSetting | BooleanSetting | ChoiceSetting | KeybindsSetting

-- Key NAMES per device for one action (Enum.KeyCode names, plus MouseButton1-3 on the keyboard list).
export type KeyNames = { keyboard: { string }, gamepad: { string } }

-- Rebinds by action id.
export type KeybindMap = { [string]: KeyNames }

-- What the client asks the server for (SettingRules.parseRequest).
export type SettingRequest =
	{ kind: "set", id: string, value: SettingValue }
	| { kind: "reset", id: string }
	| { kind: "resetAll" }

return {}
