--!strict
--[=[
	HidePeekOverlay: the frame round the peek view while hiding (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4). Inside a locker or cabinet the screen is the dark back of its door
	with three slits to look through; under a desk or table the dark underside hangs over the top of the view and the
	floor shadow darkens its foot. Drawn behind the HUD, never takes input.

	A HUD widget: it reads HideStore and draws what HideViewModel.overlay decides.

	@class HidePeekOverlay
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)
local HideViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Hide.HideViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- The door's painted steel, nearly black in the dark office.
local DOOR = Color3.fromRGB(18, 20, 24)
-- The slits: three bands across the middle of the screen, as fractions of its height.
local SLITS: { { top: number, height: number } } = {
	{ top = 0.36, height = 0.07 },
	{ top = 0.47, height = 0.07 },
	{ top = 0.58, height = 0.07 },
}

local function band(top: number, height: number): React.ReactNode
	return e("Frame", {
		Position = UDim2.fromScale(0, top),
		Size = UDim2.fromScale(1, height),
		BackgroundColor3 = DOOR,
		BorderSizePixel = 0,
	})
end

local function HidePeekOverlay(): React.ReactNode
	local hidden = useAtom(HideStore.hidden)
	local overlay = HideViewModel.overlay(hidden)
	if overlay == nil then
		return nil
	end
	local children: { [string]: React.ReactNode } = {}
	if overlay == "inside" then
		-- Door steel everywhere but the slits.
		local top = 0
		for index, slit in SLITS do
			children[`door{index}`] = band(top, slit.top - top)
			top = slit.top + slit.height
		end
		children.doorFoot = band(top, 1 - top)
	else
		children.underside = e("Frame", {
			Size = UDim2.fromScale(1, 0.3),
			BackgroundColor3 = DOOR,
			BorderSizePixel = 0,
		}, {
			edge = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.8, 0.1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		children.shadow = e("Frame", {
			Position = UDim2.fromScale(0, 0.8),
			Size = UDim2.fromScale(1, 0.2),
			BackgroundColor3 = DOOR,
			BorderSizePixel = 0,
		}, {
			edge = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0.3),
				}),
			}),
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = -10,
	}, children)
end

return HidePeekOverlay
