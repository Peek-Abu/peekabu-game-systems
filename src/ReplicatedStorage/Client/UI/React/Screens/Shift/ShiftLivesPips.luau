--!strict
--[=[
	ShiftLivesPips: a player's Gloom lives as toon hearts (the kit's `heart` and `heartGloomed` renders, ink outline baked
	in): `livesMax` hearts, `lives` of them whole and the rest gloomed. `pips` is the plain row the crew list draws
	beside each name; `Local` is the local player's row under the Gloom meter (ShiftCompactHudPanel), where the heart(s)
	that just turned gloomed pop (scale to ShiftHudViewModel.LIVES_POP.scale and back); Reduced Motion shows no pop
	(useToonPlay starts at its end). Lives are never shown on the character, only here. Presentational (exempt; story in
	ShiftCompactHudPanel.story; sizes and the pop curve specced in ShiftHudViewModel, the icon choice in
	ShiftCrewViewModel.heartIcons).

	@class ShiftLivesPips
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local useToonPlay = require(Toon.useToonPlay)

local e = React.createElement

export type Sizes = typeof(ShiftHudViewModel.LIVES.phone)

export type PipsProps = {
	lives: number,
	livesMax: number,
	sizes: Sizes,
	position: UDim2,
	anchor: Vector2?,
	-- The loss pop: hearts `popFrom` to `popTo` scale by `scale` (about their own centres).
	scale: React.Binding<number>?,
	popFrom: number?,
	popTo: number?,
}

local ShiftLivesPips = {}

-- The width of a row of `count` hearts and nothing else.
function ShiftLivesPips.width(sizes: Sizes, count: number): number
	local box = sizes.pip + 2 * sizes.stroke
	return count * box + math.max(0, count - 1) * sizes.gap
end

function ShiftLivesPips.pips(props: PipsProps): React.ReactNode
	local sizes = props.sizes
	local box = sizes.pip + 2 * sizes.stroke
	local children: { [string]: React.ReactNode } = {}
	local icons = ShiftCrewViewModel.heartIcons(props.lives, props.livesMax)
	for index = 1, #icons do
		local popping = props.scale ~= nil
			and props.popFrom ~= nil
			and props.popTo ~= nil
			and index >= props.popFrom
			and index <= props.popTo
		children[`heart{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((index - 1) * (box + sizes.gap) + box / 2, box / 2),
			Size = UDim2.fromOffset(box, box),
			BackgroundTransparency = 1,
			-- The leftmost heart is on top where they overlap.
			ZIndex = props.livesMax - index + 1,
		}, {
			scale = if popping then e("UIScale", { Scale = props.scale }) else nil,
			icon = e(ToonIcon, { icon = icons[index], size = UDim2.fromScale(1, 1), drop = 0 }),
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

-- The local player's hearts under the Gloom meter (ShiftHudViewModel.livesFrame); the one(s) just gloomed pop.
function ShiftLivesPips.Local(props: LocalProps): React.ReactNode
	local previous = React.useRef(props.lives)
	-- The latest loss: how many so far, and the hearts it gloomed (`from` to `to`).
	local loss, setLoss = React.useState({ count = 0, from = 0, to = 0 })
	React.useEffect(function()
		if props.lives < previous.current then
			local from, to = props.lives + 1, previous.current
			setLoss(function(last)
				return { count = last.count + 1, from = from, to = to }
			end)
		end
		previous.current = props.lives
	end, { props.lives })
	-- Plays on mount too; `count == 0` keeps that still.
	local alpha = useToonPlay(ShiftHudViewModel.LIVES_POP.seconds, 0, tostring(loss.count))
	local scale = alpha:map(function(t: number): number
		return if loss.count == 0 then 1 else ShiftHudViewModel.lossPop(t)
	end)
	local at, size = ShiftHudViewModel.livesFrame(props.layout, props.viewport)
	local sizes = if props.layout == "phone" then ShiftHudViewModel.LIVES.phone else ShiftHudViewModel.LIVES.desktop
	return ShiftLivesPips.pips({
		lives = props.lives,
		livesMax = props.livesMax,
		sizes = sizes,
		position = UDim2.fromOffset(at.X + size.X / 2, at.Y + size.Y / 2),
		anchor = Vector2.new(0.5, 0.5),
		scale = scale,
		popFrom = loss.from,
		popTo = loss.to,
	})
end

return ShiftLivesPips
