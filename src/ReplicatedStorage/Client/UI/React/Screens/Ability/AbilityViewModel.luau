--!strict
--[=[
	AbilityViewModel: what the ability button shows (AbilityButton): the employee's ability (its name and icon from
	EmployeeProfileRegistry, its cooldown from AbilityRegistry), whether it is ready, the whole seconds left and how
	much of the cooldown is still to go (the dark sweep), whether its effect runs now, the key to press (Q, Y on a
	gamepad; none on a touch screen, where the button is the key) and where it sits: on the phone's action arc
	(ShiftHudViewModel.arcFor) or bottom right on a desktop. Nothing shows outside a running shift or while the HUD is
	hidden (the scare beat, caught). Pure.

	@class AbilityViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityConstants = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityConstants)
local AbilityRegistry = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityRegistry)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local AbilityStore = require(ReplicatedStorage.Client.Features.Ability.State.AbilityStore)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type Input = {
	abilityId: string?,
	-- The shift's phase (nil: no shift).
	phase: string?,
	hidden: boolean,
	readyAt: number,
	active: string?,
	-- Server time now.
	now: number,
	touch: boolean,
	-- The last input was a gamepad.
	gamepad: boolean,
	-- The viewport's shorter side (px): picks the phone or tablet arc.
	shortSide: number,
}

export type ButtonView = {
	name: string,
	-- A UIAssets icon key.
	icon: string,
	ready: boolean,
	active: boolean,
	-- Whole seconds left as printed on the button; nil when ready.
	seconds: string?,
	-- 1 just used .. 0 ready.
	remaining: number,
	key: string?,
	spot: ShiftHudViewModel.ArcSpot,
}

-- Bottom right on a desktop: 88 px, in from the corner, above the engine's bottom-right core buttons.
local DESKTOP_SPOT: ShiftHudViewModel.ArcSpot = table.freeze({ x = -128, y = -168, size = 88 })

-- The keys as the button prints them: "Q", and "Y" for the gamepad's ButtonY.
local KEYBOARD_LABEL = ShiftHudViewModel.keyName(AbilityConstants.KEYBOARD_KEY)
local GAMEPAD_LABEL = (string.gsub(AbilityConstants.GAMEPAD_KEY.Name, "^Button", ""))

local AbilityViewModel = {}

function AbilityViewModel.button(input: Input): ButtonView?
	local id = input.abilityId
	local def = if id ~= nil then AbilityRegistry.get(id) else nil
	local profile = if def ~= nil then EmployeeProfileRegistry.get(def.employee) else nil
	if def == nil or profile == nil or input.phase ~= "running" or input.hidden then
		return nil
	end
	local left = AbilityStore.secondsLeft(input.readyAt, input.now)
	return {
		name = profile.ability.name,
		icon = profile.ability.icon,
		ready = left <= 0,
		active = input.active == def.id,
		seconds = if left > 0 then tostring(left) else nil,
		remaining = AbilityStore.remaining(input.readyAt, input.now, def.cooldown),
		key = if input.touch then nil elseif input.gamepad then GAMEPAD_LABEL else KEYBOARD_LABEL,
		spot = if input.touch then ShiftHudViewModel.arcFor(input.shortSide).ability else DESKTOP_SPOT,
	}
end

return AbilityViewModel
