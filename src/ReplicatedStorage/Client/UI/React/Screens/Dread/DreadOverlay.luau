--!strict
--[=[
	DreadOverlay: the Manager's dread on screen (a HUD widget, drawn behind the rest of the HUD, never takes input): the
	vignette, the grain and the heartbeat's edge fringe DreadViewModel lays out from OccupantDreadTracker's frame. It
	reads the tracker every render step through bindings, so the per-frame motion never re-renders React. No icons, no
	text: screen-space mood only.

	@class DreadOverlay
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantDreadTracker = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantDreadTracker)
local DreadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Dread.DreadViewModel)

local e = React.createElement
local DREAD = OccupantConstants.DREAD

local HIDDEN: DreadViewModel.Layers = {
	vignetteTransparency = 1,
	vignetteScale = 1,
	grainTransparency = 1,
	grainOffset = Vector2.zero,
	edgeTransparency = 1,
	redScale = 1,
	cyanScale = 1,
}

-- A centred full-screen copy of the vignette image at `scale` of the screen.
local function vignette(
	layers: React.Binding<DreadViewModel.Layers>,
	scale: (DreadViewModel.Layers) -> number,
	transparency: (DreadViewModel.Layers) -> number,
	color: Color3,
	zIndex: number
): React.ReactElement
	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = layers:map(function(value: DreadViewModel.Layers): UDim2
			local s = scale(value)
			return UDim2.fromScale(s, s)
		end),
		BackgroundTransparency = 1,
		Image = OccupantAssets.IMAGES.dreadVignette,
		ImageColor3 = color,
		ImageTransparency = layers:map(transparency),
		ZIndex = zIndex,
	})
end

local function DreadOverlay(): React.ReactNode
	local layers, setLayers = React.useBinding(HIDDEN)
	React.useEffect(function(): () -> ()
		local connection = RunService.RenderStepped:Connect(function()
			setLayers(DreadViewModel.layers(OccupantDreadTracker.get(), os.clock()) or HIDDEN)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ClipsDescendants = true,
		ZIndex = -9,
	}, {
		vignette = vignette(layers, function(value)
			return value.vignetteScale
		end, function(value)
			return value.vignetteTransparency
		end, DREAD.VIGNETTE_COLOR, 1),
		red = vignette(layers, function(value)
			return value.redScale
		end, function(value)
			return value.edgeTransparency
		end, DREAD.EDGE_RED, 2),
		cyan = vignette(layers, function(value)
			return value.cyanScale
		end, function(value)
			return value.edgeTransparency
		end, DREAD.EDGE_CYAN, 2),
		grain = e("ImageLabel", {
			Size = UDim2.new(1, DREAD.GRAIN_TILE, 1, DREAD.GRAIN_TILE),
			Position = layers:map(function(value: DreadViewModel.Layers): UDim2
				return UDim2.fromOffset(-value.grainOffset.X, -value.grainOffset.Y)
			end),
			BackgroundTransparency = 1,
			Image = OccupantAssets.IMAGES.dreadGrain,
			ImageTransparency = layers:map(function(value: DreadViewModel.Layers): number
				return value.grainTransparency
			end),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(DREAD.GRAIN_TILE, DREAD.GRAIN_TILE),
			ZIndex = 3,
		}),
	})
end

return DreadOverlay
