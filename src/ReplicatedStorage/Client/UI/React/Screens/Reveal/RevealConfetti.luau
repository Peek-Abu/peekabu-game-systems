--!strict
--[=[
	RevealConfetti: the Legendary reveal's confetti falling for good behind the hero (each piece its own column,
	speed, start and sway, one looping clock, a fixed pattern). Split out of RevealScreen. Presentational (exempt;
	story in RevealScreen.story).

	@class RevealConfetti
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

type Nodes = { [string]: React.ReactNode }

local CONFETTI_COLORS = {
	Color3.fromHex("FFC93A"),
	Color3.fromHex("33E8A9"),
	Color3.fromHex("FF4F6E"),
	Color3.fromHex("5CC8FF"),
	Color3.fromHex("B48BFF"),
}

-- Confetti falling for good: each piece has its own column, speed, start and sway, driven by one looping clock (a
-- fixed pattern, the same every time; still under Reduce Motion).
local FALL_SECONDS = 6

local function Confetti(props: { count: number }): React.ReactNode
	local clock = useToonPlay(FALL_SECONDS, 0, nil, true)
	local nodes: Nodes = {}
	local state = 7
	local function nextNumber(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	for index = 1, props.count do
		local x = nextNumber()
		local start = nextNumber()
		local speed = 1 + math.floor(nextNumber() * 2)
		local spin = math.floor(nextNumber() * 360)
		nodes[`c{index}`] = e("Frame", {
			Position = clock:map(function(alpha: number): UDim2
				local fall = (start + alpha * speed) % 1
				return UDim2.fromScale(x + 0.02 * math.sin((alpha * speed + start) * math.pi * 4), fall * 1.1 - 0.05)
			end),
			Rotation = clock:map(function(alpha: number): number
				return spin + alpha * 360 * speed
			end),
			Size = UDim2.fromOffset(14, 26),
			BackgroundColor3 = CONFETTI_COLORS[index % #CONFETTI_COLORS + 1],
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, nodes)
end

return Confetti
