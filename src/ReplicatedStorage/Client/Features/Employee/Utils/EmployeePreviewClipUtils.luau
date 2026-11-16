--!strict
--[=[
	EmployeePreviewClipUtils: which animation registry clip a character preview plays (its idle, fidget, reveal, menu
	reaction, an emote item's loop) and how far that clip reaches. Pure registry lookups. Split out of
	EmployeePreviewSystem (which still exposes them under the same names).

	@class EmployeePreviewClipUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local EmployeeRegistry = require(EmployeeShared.Data.EmployeeRegistry)
local EmployeeSkinRules = require(EmployeeShared.Rules.EmployeeSkinRules)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)

local EmployeePreviewClipUtils = {}

--[=[
	The animation registry key of the idle loop a preview plays: the chosen idle item's (`idle`, the key after the dot,
	one that fits the skin), else the skin's own showcase idle when it has one (EmployeeRegistry `showcaseIdle`), else
	the employee's idle (nil = no own locomotion).
]=]
function EmployeePreviewClipUtils.idleOf(employee: string, skin: string?, idle: string?): string?
	local def = EmployeeRegistry.get(employee)
	return if def ~= nil then EmployeeSkinRules.idleOf(def, skin, idle) else nil
end

--[=[
	How far the clip a preview plays (idleOf) carries the model and its props round its root, over the whole idle, its
	fidget and the menu reaction (measured in Studio; EmployeeRegistry `showcaseReach` / `previewReach`): a spinning
	preview's camera is fitted to it once and never refits (owner, 2026-11-14: no zoom while you look at an item).
]=]
function EmployeePreviewClipUtils.reachOf(
	employee: string,
	skin: string?,
	idle: string?
): EmployeeRegistry.PreviewReach?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local clip = EmployeeSkinRules.idleOf(def, skin, idle)
	for _, look in def.skins do
		if clip ~= nil and look.showcaseIdle == clip and look.showcaseReach ~= nil then
			return look.showcaseReach
		end
	end
	return def.previewReach
end

--[=[
	The animation registry key of the fidget a preview plays, the one that belongs to its idle (EmployeeSkinRules
	`fidgetOf`: a skin's own over its showcase idle, else the employee's); nil when there is none.
]=]
function EmployeePreviewClipUtils.fidgetOf(employee: string, skin: string?, idle: string?): string?
	local def = EmployeeRegistry.get(employee)
	return if def ~= nil then EmployeeSkinRules.fidgetOf(def, skin, idle) else nil
end

--[=[
	The animation registry key of the reveal the reveal screen plays for `employee` in `skin` (nil = a hire): the
	skin's own unlock reveal, else the employee's hire reveal worn in that skin; nil when there is none (its idle only).
]=]
function EmployeePreviewClipUtils.revealOf(employee: string, skin: string?): string?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local look = if skin ~= nil then def.skins[skin] else nil
	local own = if look ~= nil then look.unlockReveal else nil
	return own or def.hireReveal
end

--[=[
	The animation registry key of the reaction a menu hero plays when clicked (EmployeeRegistry `selectReaction`); nil
	when it has none.
]=]
function EmployeePreviewClipUtils.reactionOf(employee: string): string?
	local def = EmployeeRegistry.get(employee)
	return if def ~= nil then def.selectReaction else nil
end

--[=[
	The animation registry key of the clip an emote item (a CosmeticRegistry id) loops in a preview; nil when the id is
	not an emote or its clip is not made yet.
]=]
function EmployeePreviewClipUtils.emoteOf(itemId: string): string?
	local item = CosmeticRegistry.get(itemId)
	if item == nil or item.kind ~= "emote" then
		return nil
	end
	local key = "emote:" .. itemId
	return if AnimationRegistry.get(key) ~= nil then key else nil
end

return EmployeePreviewClipUtils
