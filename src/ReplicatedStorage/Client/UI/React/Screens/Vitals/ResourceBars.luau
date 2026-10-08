--!strict
--[=[
	ResourceBars: the three stacked bottom-centre resource bars (health / rot / stamina), each a
	`ClippedBar` with the shared resource sprite-set and a per-resource tint / tick count.

	Health's fill is a driven binding (a live fraction, passed in). Rot and Stamina are shown FULL and
	undriven — no live current value exists yet; they light up when the spell-shield (rot) and Stamina
	systems drive a fraction. Footprints, colours and tick counts are transcribed from the authored HUD
	(top-left anchored, so the positions/sizes are the authored values verbatim). Stamina has no ticks;
	only Rot carries the authored purple fill outline.

	@class ResourceBars
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ClippedBar = require(ReplicatedStorage.Client.UI.React.Primitives.ClippedBar)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

local e = React.createElement

-- The look shared by all three resource bars: the fill sprite (tinted per bar), a translucent inner
-- shade over it, the HOLLOW frame in front (the fill shows through it), and the divider sprite.
local RESOURCE_SPRITES: ClippedBar.BarSprites = {
	fill = UIAssets.bar.fill,
	overlay = { image = UIAssets.bar.innerShade, tint = Color3.fromRGB(109, 109, 109), transparency = 0.5 },
	frame = { image = UIAssets.bar.frame, tint = Color3.fromRGB(255, 255, 255) },
	tick = { image = UIAssets.bar.tick, tint = Color3.fromRGB(212, 212, 212), heightScale = 1 },
}

-- The health drain trail (authored HealthbarCatchup): the fill sprite in a dark red, lagging behind.
local HEALTH_CATCHUP_TINT = Color3.fromRGB(74, 32, 32)

-- Bar footprints (top-left position + size, screen-scale), per-resource fill tint and tick count,
-- transcribed from the authored HUD.
local HEALTH = {
	pos = UDim2.fromScale(0.407, 0.88),
	size = UDim2.fromScale(0.182, 0.014),
	color = Color3.fromRGB(173, 75, 75),
	ticks = 3,
}
local ROT = {
	pos = UDim2.fromScale(0.427, 0.895),
	size = UDim2.fromScale(0.143, 0.012),
	color = Color3.fromRGB(230, 213, 255),
	ticks = 3,
	-- The authored rot fill carries a saturated purple outline (its pale tint reads washed out without it).
	stroke = { color = Color3.fromRGB(199, 129, 240), thickness = 1, transparency = 0 },
}
local STAMINA = {
	pos = UDim2.fromScale(0.433, 0.87),
	size = UDim2.fromScale(0.13, 0.007),
	color = Color3.fromRGB(177, 205, 247),
	ticks = 0,
}
local FULL = 1

export type ResourceBarsProps = {
	healthFill: React.Binding<number>,
	-- The lagging drain trail behind health — eased by VitalsHud (see the damage-trail note there).
	healthCatchup: React.Binding<number>,
}

--[=[
	@param props ResourceBarsProps
	@return React.ReactNode
]=]
local function ResourceBars(props: ResourceBarsProps): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		stamina = e(ClippedBar, {
			position = STAMINA.pos,
			size = STAMINA.size,
			color = STAMINA.color,
			fraction = FULL,
			sprites = RESOURCE_SPRITES,
			ticks = STAMINA.ticks,
		}),
		rot = e(ClippedBar, {
			position = ROT.pos,
			size = ROT.size,
			color = ROT.color,
			fraction = FULL,
			sprites = RESOURCE_SPRITES,
			ticks = ROT.ticks,
			stroke = ROT.stroke,
		}),
		health = e(ClippedBar, {
			position = HEALTH.pos,
			size = HEALTH.size,
			color = HEALTH.color,
			fraction = props.healthFill,
			sprites = RESOURCE_SPRITES,
			ticks = HEALTH.ticks,
			catchup = { fraction = props.healthCatchup, tint = HEALTH_CATCHUP_TINT },
		}),
	})
end

return ResourceBars
