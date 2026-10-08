--!strict
--[=[
	ExperienceBar: the top-centre XP bar, rebuilt from the authored `ExpUI` — cleaner internals, same
	look and behaviour. A `ClippedBar` (with the XP sprite-set) flanked by the current/next level labels
	(`LVL. N` … bar … `LVL. N+1`). The authored bar has an `EXP (x/y)` number too, but it ships hidden
	(`Visible = false`), so this omits it to match what Venture actually shows.

	Reinvented, not transcribed: the authored bar buried the fill under a doubled sprite nesting
	(`EXPTopbarUnder → Frame → EXPTopbar → Frame → EXPTopbar`) driven from CameraScript. This renders the
	same visual through one clip layer, with the segmented backdrop BEHIND the fill (it's a solid sprite,
	so a front layer would hide the fill). The level-up badge popup and fill sweep are deferred; the bar
	itself updates live.

	@class ExperienceBar
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ClippedBar = require(ReplicatedStorage.Client.UI.React.Primitives.ClippedBar)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local VitalsViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Vitals.VitalsViewModel)

local e = React.createElement

-- The label the view-model uses at the level cap (a full bar with no "next").
local CAP_LABEL = "MAX"

-- The XP bar's look, matching the authored ExpBar: the authored dark track BEHIND the fill (drawn
-- translucent so it's a recessed slot, not a black slab), the textured fill sprite, and the notch ticks.
local XP_SPRITES: ClippedBar.BarSprites = {
	backdrop = { image = UIAssets.xp.track, tint = Color3.fromRGB(171, 171, 171), transparency = 0.5 },
	fill = UIAssets.xp.fill,
	tick = { image = UIAssets.xp.tick, tint = Color3.fromRGB(255, 255, 255), heightScale = 1.4 },
}
-- Authored colours: a light peach fill and a DARK olive lead (the lead is the darker "to-be-filled"
-- preview the bright fill rises into — same as health's darker trail).
local XP_COLOR = Color3.fromRGB(255, 213, 153)
local XP_LEAD_TINT = Color3.fromRGB(129, 114, 67)
local XP_SEGMENTS = 8

-- Bar footprint (top-left) and the shared vertical centre of the flanking labels, all screen-scale,
-- centred on x=0.5. Thin top bar transcribed from the authored ExpBar (~0.38 wide, ~0.011 tall).
local BAR = { pos = UDim2.fromScale(0.31, 0.03), size = UDim2.fromScale(0.38, 0.011) }
local BAR_MID_Y = 0.0355

export type ExperienceBarProps = {
	xp: VitalsViewModel.XpDisplay,
	-- Eased by ExperienceHud (see the gain-lead note there): the fill tweens up, the lead races ahead.
	fraction: React.Binding<number>,
	catchup: React.Binding<number>,
}

-- One HUD text label (flanking level or centred progress number), with the standard dark outline.
local function textLabel(
	position: UDim2,
	anchor: Vector2,
	alignment: Enum.TextXAlignment,
	text: string,
	muted: boolean
): React.ReactNode
	return e("TextLabel", {
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(120, Tokens.textSize.sm + Tokens.space.xs),
		BackgroundTransparency = 1,
		Font = Tokens.font.bold,
		TextSize = Tokens.textSize.sm,
		TextXAlignment = alignment,
		TextColor3 = if muted then Tokens.color.textMuted else Tokens.color.text,
		Text = text,
	}, {
		outline = e("UIStroke", { Color = Tokens.color.background, Thickness = Tokens.stroke.thin }),
	})
end

--[=[
	@param props ExperienceBarProps
	@return React.ReactNode
]=]
local function ExperienceBar(props: ExperienceBarProps): React.ReactNode
	local xp = props.xp
	local atCap = xp.label == CAP_LABEL

	local prevText = if xp.loading then "LVL. —" else `LVL. {xp.level}`
	local nextText = if xp.loading then "LVL. —" elseif atCap then CAP_LABEL else `LVL. {xp.level + 1}`

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		bar = e(ClippedBar, {
			position = BAR.pos,
			size = BAR.size,
			color = XP_COLOR,
			fraction = props.fraction,
			sprites = XP_SPRITES,
			ticks = XP_SEGMENTS - 1,
			catchup = { fraction = props.catchup, tint = XP_LEAD_TINT },
		}),
		prevLevel = textLabel(
			UDim2.fromScale(0.3, BAR_MID_Y),
			Vector2.new(1, 0.5),
			Enum.TextXAlignment.Right,
			prevText,
			xp.loading
		),
		nextLevel = textLabel(
			UDim2.fromScale(0.7, BAR_MID_Y),
			Vector2.new(0, 0.5),
			Enum.TextXAlignment.Left,
			nextText,
			xp.loading
		),
	})
end

return ExperienceBar
