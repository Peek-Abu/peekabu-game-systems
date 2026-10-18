--!strict
--[=[
	WorldBillboard: maps a component's Figma px design onto the shell that carries it (M3b world UI). The caller builds
	its component at the design's px size; this wrapper draws it centred in a full-size transparent Frame under a
	UIScale. Presentational; the maths is the specced WorldBillboardViewModel.

	- "studs": a stud-sized BillboardGui shell. The outer Frame's drawn size changes with distance, so its AbsoluteSize
	  feeds a binding and the UIScale is `fit(AbsoluteSize, design)` (no re-render per frame). It starts at the design
	  size, so the first scale is 1, never 0.
	- "pixels": a px-sized shell (offset-sized at the design size). The UIScale is `screenScale(viewport)`, which shrinks
	  the sign on small screens and never grows it past 1.

	@class WorldBillboard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

local e = React.createElement

export type Sizing = "studs" | "pixels"

export type WorldBillboardProps = {
	-- The component's Figma px size.
	design: Vector2,
	sizing: Sizing,
	children: { [string]: React.ReactNode }?,
}

local function WorldBillboard(props: WorldBillboardProps): React.ReactNode
	local design = props.design
	local viewport = usePaperViewport()
	local absolute, setAbsolute = React.useBinding(design)

	local screen = WorldBillboardViewModel.screenScale(viewport)
	local sizing = props.sizing
	-- One binding per sizing/screen/design (it is also the PaperScaleContext value, so it must keep its identity).
	local scale = React.useMemo(function(): React.Binding<number>
		if sizing == "studs" then
			return absolute:map(function(size: Vector2): number
				return WorldBillboardViewModel.fit(size, design)
			end)
		end
		local binding = React.createBinding(screen)
		return binding
	end, { `{sizing}:{screen}:{design.X}x{design.Y}` })

	-- A world sign shrinks with distance, so its fitted text has no readable floor (screen UI keeps READABLE_PX).
	return e(PaperScaleContext.Context.Provider, { value = scale }, {
		readable = e(PaperScaleContext.Readable.Provider, { value = 1 }, {
			root = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[React.Change.AbsoluteSize] = if props.sizing == "studs"
					then function(rbx: Frame)
						setAbsolute(rbx.AbsoluteSize)
					end
					else nil,
			}, {
				design = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(design.X, design.Y),
					BackgroundTransparency = 1,
				}, {
					scale = e("UIScale", { Scale = scale }),
					content = e("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
					}, props.children),
				}),
			}),
		}),
	})
end

return WorldBillboard
