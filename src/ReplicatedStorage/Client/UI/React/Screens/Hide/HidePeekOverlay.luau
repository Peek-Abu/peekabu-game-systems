--!strict
--[=[
	HidePeekOverlay: the frame round the peek view while hiding (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4). Under a desk or table the dark underside hangs over the top of the
	view and the floor shadow darkens its foot. Inside a supply cabinet the view is cut into thin bright slits between
	the louvres of its closed door, the rest of it the dark inside of the door. Drawn behind the HUD, never takes input.

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

-- The furniture's underside, nearly black in the dark office.
local SHADE = Color3.fromRGB(18, 20, 24)

-- The louvres: SLATS dark slats down the view, each SLAT_FILL of its band, the slits between them open.
local SLATS = 9
local SLAT_FILL = 0.62

local function slats(): React.ReactNode
	local children: { [string]: React.ReactNode } = {}
	local band = 1 / SLATS
	for index = 1, SLATS do
		children[`slat{index}`] = e("Frame", {
			Position = UDim2.fromScale(0, (index - 1) * band),
			Size = UDim2.fromScale(1, band * SLAT_FILL),
			BackgroundColor3 = SHADE,
			BorderSizePixel = 0,
		}, {
			-- The slat's lit lower lip, so it reads as angled metal rather than a flat bar.
			lip = e("Frame", {
				Position = UDim2.fromScale(0, 0.82),
				Size = UDim2.fromScale(1, 0.18),
				BackgroundColor3 = Color3.fromRGB(58, 66, 76),
				BorderSizePixel = 0,
			}),
		})
	end
	-- The door's dark sides round the louvre band.
	children.vignette = e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		left = e("Frame", { Size = UDim2.fromScale(0.08, 1), BackgroundColor3 = SHADE, BorderSizePixel = 0 }),
		right = e("Frame", {
			Position = UDim2.fromScale(0.92, 0),
			Size = UDim2.fromScale(0.08, 1),
			BackgroundColor3 = SHADE,
			BorderSizePixel = 0,
		}),
	})
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = -10,
	}, children)
end

local function HidePeekOverlay(): React.ReactNode
	local hidden = useAtom(HideStore.hidden)
	local overlay = HideViewModel.overlay(hidden)
	if overlay == nil then
		return nil
	end
	if overlay == "slats" then
		return slats()
	end
	local children: { [string]: React.ReactNode } = {
		underside = e("Frame", {
			Size = UDim2.fromScale(1, 0.3),
			BackgroundColor3 = SHADE,
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
		}),
		shadow = e("Frame", {
			Position = UDim2.fromScale(0, 0.8),
			Size = UDim2.fromScale(1, 0.2),
			BackgroundColor3 = SHADE,
			BorderSizePixel = 0,
		}, {
			edge = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0.3),
				}),
			}),
		}),
	}
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = -10,
	}, children)
end

return HidePeekOverlay
