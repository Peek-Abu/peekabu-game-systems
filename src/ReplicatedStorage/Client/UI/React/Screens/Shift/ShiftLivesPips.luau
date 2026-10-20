--!strict
--[=[
	ShiftLivesPips: a player's Gloom lives as small round pips (the kit has no heart): `livesMax` circles, `lives` of them
	filled coral, the rest empty night, every one in the kit's ink outline. `pips` is the plain row the crew list draws
	beside each name; `Local` is the local player's row under the Gloom meter (ShiftCompactHudPanel), which pops (scales
	to ShiftHudViewModel.LIVES_POP.scale and back) when a life is lost; Reduced Motion shows no pop (useToonPlay starts at
	its end). Lives are never shown on the character, only here. Presentational (exempt; story in ShiftCompactHudPanel.story;
	sizes and the pop curve specced in ShiftHudViewModel).

	@class ShiftLivesPips
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)

local e = React.createElement

local FILLED = UIToonConstants.shade("coral").base
local EMPTY = UIToonConstants.shade("night").hi

export type Sizes = typeof(ShiftHudViewModel.LIVES.phone)

export type PipsProps = {
	lives: number,
	livesMax: number,
	sizes: Sizes,
	position: UDim2,
	anchor: Vector2?,
	-- The row's scale (the loss pop), or nil for a still row.
	scale: React.Binding<number>?,
}

local ShiftLivesPips = {}

-- The width of a row of `count` pips (each with its outline) and nothing else.
function ShiftLivesPips.width(sizes: Sizes, count: number): number
	local box = sizes.pip + 2 * sizes.stroke
	return count * box + math.max(0, count - 1) * sizes.gap
end

function ShiftLivesPips.pips(props: PipsProps): React.ReactNode
	local sizes = props.sizes
	local box = sizes.pip + 2 * sizes.stroke
	local children: { [string]: React.ReactNode } = {}
	if props.scale ~= nil then
		children.scale = e("UIScale", { Scale = props.scale })
	end
	for index = 1, props.livesMax do
		children[`pip{index}`] = e("Frame", {
			Position = UDim2.fromOffset((index - 1) * (box + sizes.gap) + sizes.stroke, sizes.stroke),
			Size = UDim2.fromOffset(sizes.pip, sizes.pip),
			BackgroundColor3 = if index <= props.lives then FILLED else EMPTY,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = UIToonConstants.COLOR.ink, Thickness = sizes.stroke }),
		})
	end
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(ShiftLivesPips.width(sizes, props.livesMax), box),
		BackgroundTransparency = 1,
	}, children)
end

export type LocalProps = {
	lives: number,
	livesMax: number,
	layout: "phone" | "desktop",
	viewport: Vector2,
}

-- The local player's pips under the Gloom meter (ShiftHudViewModel.livesFrame), popping when a life is lost.
function ShiftLivesPips.Local(props: LocalProps): React.ReactNode
	local previous = React.useRef(props.lives)
	local drops, setDrops = React.useState(0)
	React.useEffect(function()
		if props.lives < previous.current then
			setDrops(function(count: number): number
				return count + 1
			end)
		end
		previous.current = props.lives
	end, { props.lives })
	-- Plays on mount too; `drops == 0` keeps that still.
	local alpha = useToonPlay(ShiftHudViewModel.LIVES_POP.seconds, 0, tostring(drops))
	local scale = alpha:map(function(t: number): number
		return if drops == 0 then 1 else ShiftHudViewModel.lossPop(t)
	end)
	local at, size = ShiftHudViewModel.livesFrame(props.layout, props.viewport)
	local sizes = if props.layout == "phone" then ShiftHudViewModel.LIVES.phone else ShiftHudViewModel.LIVES.desktop
	return ShiftLivesPips.pips({
		lives = props.lives,
		livesMax = props.livesMax,
		sizes = sizes,
		position = UDim2.fromOffset(at.X + size.X / 2, at.Y + size.Y / 2),
		-- Scaled about its centre.
		anchor = Vector2.new(0.5, 0.5),
		scale = scale,
	})
end

return ShiftLivesPips
