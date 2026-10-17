--!strict
--[=[
	UISoundFormulas: which UI sound plays (Cleanup Crew round-2 UI picks, the paperwork hierarchy hover < click < confirm
	< CTA, with back and error beside it). A button's tier is the one its caller names, else its look's default (a filled
	action button confirms, everything else clicks); a disabled button answers a press with the error; a hold prompt's
	wind-up is stretched to fill its hold, and the prompt that is a CTA (clock out) completes with the CTA. Pure.

	@class UISoundFormulas
]=]

export type Tier = "hover" | "click" | "confirm" | "back" | "error" | "cta" | "hold" | "done"

-- The PaperButton looks whose default is the confirm (the rest default to the click).
local CONFIRMS: { [string]: boolean } = { go = true, primary = true, danger = true }

local UISoundFormulas = {}

-- The wind-up's PlaybackSpeed bounds (a 0.25 s or a 4 s hold still sounds like the same wind-up).
UISoundFormulas.MIN_SPEED = 0.25
UISoundFormulas.MAX_SPEED = 4

--[=[
	The sound tier of a button with the look `variant`: `explicit` when its caller names one, else the look's default.
]=]
function UISoundFormulas.buttonTier(variant: string, explicit: Tier?): Tier
	if explicit ~= nil then
		return explicit
	end
	return if CONFIRMS[variant] then "confirm" else "click"
end

--[=[
	What a press plays: the button's tier, or the error (dull: denied) when the button is disabled.
]=]
function UISoundFormulas.pressTier(tier: Tier, disabled: boolean): Tier
	return if disabled then "error" else tier
end

--[=[
	Whether pointing at a button plays the hover: an enabled button with a pointer look (the touch surfaces never hover).
]=]
function UISoundFormulas.hovers(variant: string, disabled: boolean): boolean
	return not disabled and variant ~= "surface"
end

--[=[
	The hold wind-up's PlaybackSpeed for a prompt held `holdDuration` seconds (the clip is 1 s at speed 1), within
	MIN_SPEED..MAX_SPEED; nil for a tap prompt.
]=]
function UISoundFormulas.holdSpeed(holdDuration: number): number?
	if holdDuration <= 0 then
		return nil
	end
	return math.clamp(1 / holdDuration, UISoundFormulas.MIN_SPEED, UISoundFormulas.MAX_SPEED)
end

--[=[
	What a completed hold prompt plays: the CTA for an Interaction kind in `ctaKinds`, else the done sound.
]=]
function UISoundFormulas.doneTier(kind: string?, ctaKinds: { string }): Tier
	if kind ~= nil and table.find(ctaKinds, kind) ~= nil then
		return "cta"
	end
	return "done"
end

return UISoundFormulas
