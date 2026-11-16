--!strict
--[=[
	ToonViewportModel: what a ToonViewport shows. Its props type; `build`, the model to show and whether it moves (a
	whole player's look, a vacuum alone, a live hero when asked and a slot is free, else the static posed copy); and
	`lookKey`, the look as one string, so the viewport rebuilds only when it changes. Split out of ToonViewport.

	@class ToonViewportModel
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local VacuumPreviewSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumPreviewSystem)
local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeePoseRules = require(EmployeeShared.Rules.EmployeePoseRules)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)
local ToonViewportPlatform = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonViewportPlatform)

type Platform = ToonViewportPlatform.Platform

export type ToonViewportProps = {
	employee: string?,
	-- A whole player's look (takes the place of employee + skin).
	outfit: CosmeticTypes.Outfit?,
	-- A VacuumSkinRegistry key: with no employee or outfit, that vacuum alone.
	vacuum: string?,
	-- Degrees round the model (180 = from behind).
	turn: number?,
	-- An EmployeeRegistry skin key (nil = the default look).
	skin: string?,
	-- The skin's colour style (nil = 1); an outfit look carries its own.
	style: number?,
	-- A live hero's idle item (the key after the dot, one that fits the skin; nil = the skin's own idle).
	idle: string?,
	-- true: the employee preview wears your rank lanyard (a surface that shows YOU: the Inventory employee page, the
	-- employee page's title art). nil or false: none (owner 11-15: an item, a hire or a coach shows the employee, not you). An
	-- outfit (your own look) always keeps what you wear.
	lanyard: boolean?,
	live: boolean?,
	-- A Cosmetic emote id: a live hero loops it.
	emote: string?,
	-- A live hero plays its reveal once, then its idle.
	reveal: boolean?,
	-- A click's time: a live hero plays its menu reaction, once per time, then its idle. The same model waits out
	-- REACT_COOLDOWN between two clicks; a click that rebuilds the model reacts on the new one.
	react: number?,
	framing: PortraitViewModel.Framing,
	context: EmployeePoseRegistry.PortraitContext?,
	tone: PortraitViewModel.Tone?,
	dim: boolean?,
	-- The player can turn the model round (drag, flick, right stick).
	spin: boolean?,
	platform: Platform?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	layoutOrder: number?,
}

local ToonViewportModel = {}

-- The model to show and whether it moves: a live one when asked and a slot is free, else the static posed copy.
function ToonViewportModel.build(props: ToonViewportProps): (Model?, boolean)
	local outfit = props.outfit
	if outfit ~= nil then
		local pose = EmployeePoseRules.select(EmployeePoseRegistry.get(outfit.employee), props.context or "idle", {})
		local mine = Players.LocalPlayer
		return EmployeePreviewSystem.outfit(
			outfit,
			ReplicatedStorage,
			if mine ~= nil then mine.Character else nil,
			props.live == true,
			pose
		)
	end
	local employee = props.employee
	if employee == nil then
		local vacuum = props.vacuum
		return if vacuum ~= nil
			then VacuumPreviewSystem.alone(VacuumSkinRules.select(vacuum), ReplicatedStorage)
			else nil,
			false
	end
	if props.live == true then
		local model =
			EmployeePreviewSystem.live(employee, props.skin, ReplicatedStorage, props.style, props.lanyard == true)
		if model ~= nil then
			return model, true
		end
	end
	local pose = EmployeePoseRules.select(EmployeePoseRegistry.get(employee), props.context or "idle", {})
	return EmployeePreviewSystem.static(
		employee,
		props.skin,
		ReplicatedStorage,
		pose,
		props.style,
		props.lanyard == true
	),
		false
end

-- What the model shows, as one string (the effect rebuilds only when it changes).
function ToonViewportModel.lookKey(props: ToonViewportProps): string
	local outfit = props.outfit
	if outfit ~= nil then
		return `{outfit.employee}|{outfit.look.skin}|{outfit.look.style}|{outfit.vacuum}`
	end
	local lanyard = if props.lanyard == true then "lanyard" else ""
	return `{props.employee or ""}|{props.skin or ""}|{props.style or 1}|{props.vacuum or ""}|{lanyard}`
end

return ToonViewportModel
