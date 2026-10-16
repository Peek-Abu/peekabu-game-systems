--!strict
--[=[
	HideViewModel: what the hiding chip and the peek overlay say (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4). Outside a spot, the chip is the spot's prompt ("[C] HIDE UNDER
	desk"; a hold strip only for a prompt that has a hold); inside, it is the way out ("[C] LEAVE desk"), turning into a
	warning once the stay is cramped ("CRAMPED · out in 6s", HideRules). The overlay frames the peek: the underside of
	the furniture above you, or the louvred door of the supply cabinet you stand in. Nil while the HUD is hidden (the scare beat, or caught). Pure.

	@class HideViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideRules = require(ReplicatedStorage.Shared.Features.Hide.Rules.HideRules)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)

export type ChipView = {
	key: string,
	text: string,
	-- The hold strip's fill (0-1) while entering; nil when there is no hold.
	fill: number?,
	-- Cramped: drawn as a warning.
	warn: boolean,
}

export type Overlay = "under" | "slats"

local HideViewModel = {}

function HideViewModel.chip(
	prompt: HideStore.PromptView?,
	hidden: HideStore.HiddenView?,
	key: string,
	now: number,
	hudHidden: boolean
): ChipView?
	if hudHidden then
		return nil
	end
	if hidden ~= nil then
		local elapsed = now - hidden.since
		if HideRules.camp(elapsed) ~= "ok" then
			return { key = key, text = `CRAMPED · out in {HideRules.secondsLeft(elapsed)}s`, fill = nil, warn = true }
		end
		return { key = key, text = `LEAVE {string.lower(hidden.noun)}`, fill = nil, warn = false }
	end
	if prompt == nil then
		return nil
	end
	local fill: number? = nil
	if prompt.hold > 0 then
		local started = prompt.holdStartedAt
		fill = if started ~= nil then math.clamp((now - started) / prompt.hold, 0, 1) else 0
	end
	return {
		key = key,
		text = `{string.upper(prompt.action)} {string.lower(prompt.noun)}`,
		fill = fill,
		warn = false,
	}
end

--[=[
	The peek overlay for the spot the player hides in, or nil when not hiding: the furniture's underside, or a supply
	cabinet's louvred door ("slats").
]=]
function HideViewModel.overlay(hidden: HideStore.HiddenView?): Overlay?
	if hidden == nil then
		return nil
	end
	return if hidden.kind == "inside" then "slats" else "under"
end

return HideViewModel
