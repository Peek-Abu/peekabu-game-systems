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

--[=[
	A supply cabinet's louvred door as the peek sees it: `slats` dark slats down the view, each `fill` of its band, the
	slits between them open, and a dark `side` strip of the door frame at either edge. 2026-10-16 playtest: wider
	slits (was 9 slats at 0.62, sides 0.08: a third of the screen open) so more of the room shows.
]=]
HideViewModel.LOUVRE = table.freeze({ slats = 7, fill = 0.42, side = 0.05 })

--[=[
	The share of the screen the louvred door leaves open.
]=]
function HideViewModel.openShare(): number
	local louvre = HideViewModel.LOUVRE
	return (1 - louvre.fill) * (1 - 2 * louvre.side)
end

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
	cabinet's louvred door ("slats"); none once that door stands open (the Manager opening it: his face must not be
	behind slats that are no longer there).
]=]
function HideViewModel.overlay(hidden: HideStore.HiddenView?): Overlay?
	if hidden == nil then
		return nil
	end
	if hidden.kind == "inside" then
		return if hidden.doorOpen == true then nil else "slats"
	end
	return "under"
end

return HideViewModel
