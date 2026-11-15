--!strict
--[=[
	ShiftHelperViewModel: the phone's helper button (Layout 2, owner pick 11-15): the one thing the player can do right
	here, as a round button beside the big VACUUM / THROW button, in place of the HIDE and interaction chips. One button
	whose word changes (the DOORS model): LEAVE while hiding; else HIDE when he is near (`danger`, the urgent one); else
	the shown prompt's action (BANK at the truck, lit); else HIDE at a hiding spot; else nothing (the button is not
	drawn). Pure.

	@class ShiftHelperViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local HideViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Hide.HideViewModel)

export type HelperKind = "prompt" | "hide" | "leave"

export type HelperView = {
	-- What a press does: hold the shown prompt, hold the hiding prompt, or come out of the spot.
	kind: HelperKind,
	label: string,
	-- Lit (mint): BANK at the truck.
	ready: boolean,
	-- Coral: the hiding stay is cramped (HideRules), get out.
	warn: boolean,
	-- 0-1 while a hold prompt is held; 0 for a hold prompt not yet held; nil for a press.
	fill: number?,
}

export type HelperInput = {
	prompt: ShiftPromptStore.PromptView?,
	hidePrompt: HideStore.PromptView?,
	hidden: HideStore.HiddenView?,
	danger: boolean,
	-- Server time.
	now: number,
	-- The scare beat, or the local player is caught.
	hudHidden: boolean,
}

local ShiftHelperViewModel = {}

-- The longest word the 76 px round button draws at the arc's label size.
ShiftHelperViewModel.MAX_LETTERS = 9

--[=[
	The button's word for a prompt: BANK for the truck's Load prompt; else the action in capitals, cut to its last word
	when it runs past MAX_LETTERS ("Start overtime" -> OVERTIME).
]=]
function ShiftHelperViewModel.word(action: string, kind: string?): string
	if kind == CargoConstants.LOAD_KIND then
		return "BANK"
	end
	local upper = string.upper(action)
	if #upper > ShiftHelperViewModel.MAX_LETTERS then
		local words = string.split(upper, " ")
		return words[#words]
	end
	return upper
end

local function fillOf(hold: number, started: number?, now: number): number?
	if hold <= 0 then
		return nil
	end
	return if started ~= nil then math.clamp((now - started) / hold, 0, 1) else 0
end

local function hideView(prompt: HideStore.PromptView, now: number): HelperView
	return {
		kind = "hide",
		label = "HIDE",
		ready = false,
		warn = false,
		fill = fillOf(prompt.hold, prompt.holdStartedAt, now),
	}
end

function ShiftHelperViewModel.helper(input: HelperInput): HelperView?
	if input.hudHidden then
		return nil
	end
	local hidden = input.hidden
	if hidden ~= nil then
		local chip = HideViewModel.chip(nil, hidden, "", input.now, false)
		return { kind = "leave", label = "LEAVE", ready = false, warn = chip ~= nil and chip.warn, fill = nil }
	end
	local hidePrompt = input.hidePrompt
	if hidePrompt ~= nil and input.danger then
		return hideView(hidePrompt, input.now)
	end
	local prompt = input.prompt
	if prompt ~= nil then
		return {
			kind = "prompt",
			label = ShiftHelperViewModel.word(prompt.action, prompt.kind),
			ready = prompt.kind == CargoConstants.LOAD_KIND,
			warn = false,
			fill = fillOf(prompt.hold, prompt.holdStartedAt, input.now),
		}
	end
	if hidePrompt ~= nil then
		return hideView(hidePrompt, input.now)
	end
	return nil
end

return ShiftHelperViewModel
