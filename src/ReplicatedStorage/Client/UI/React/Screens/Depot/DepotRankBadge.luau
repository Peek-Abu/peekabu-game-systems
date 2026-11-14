--!strict
--[=[
	DepotRankBadge: a rank's real v6 lanyard badge (`LanyardBadges.R<rank>`, the model every employee wears;
	EmployeeConstants.LANYARD_BADGES_PATH) in a ViewportFrame, turned to its back so the rank's icon shows (NEW!, broom,
	sponge, vacuum, clipboard, keys, #1 mug). The rank chart's steps and NEXT RANK card use it, so the chart always
	shows exactly the badge a rank-up hangs on you, with nothing to upload. The copy is anchored and never moves, so
	the viewport renders it once. A missing model draws nothing. Presentational.

	@class DepotRankBadge
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)

local e = React.createElement

-- The camera's field of view, degrees: narrow, so the thin badge reads flat like a sticker.
local FIELD_OF_VIEW = 30
-- Room left around the badge, as a share of its height.
local MARGIN = 0.06

export type DepotRankBadgeProps = {
	rank: number,
	anchor: Vector2?,
	position: UDim2?,
	size: UDim2,
	rotation: number?,
	-- A rank not reached yet: greyed and see-through.
	faded: boolean?,
	zIndex: number?,
}

local function template(rank: number): Model?
	local current: Instance? = ReplicatedStorage
	for _, name in EmployeeConstants.LANYARD_BADGES_PATH do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	local found = if current ~= nil then current:FindFirstChild(`R{rank}`) else nil
	return if found ~= nil and found:IsA("Model") then found else nil
end

local function DepotRankBadge(props: DepotRankBadgeProps): React.ReactNode
	local noFrame: ViewportFrame? = nil
	local frame, setFrame = React.useState(noFrame)
	local deps: { unknown } = { frame, props.rank }
	React.useEffect(function(): () -> ()
		local source = template(props.rank)
		if frame == nil or source == nil then
			return function() end
		end
		local window: ViewportFrame = frame
		local copy = source:Clone()
		for _, part in copy:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		copy:PivotTo(CFrame.identity)
		local centre, extent = copy:GetBoundingBox()
		-- The icon is on the badge's -Z face (the side against the wearer's chest faces +Z).
		local reach = math.max(extent.Y, extent.X) * (0.5 + MARGIN) / math.tan(math.rad(FIELD_OF_VIEW / 2))
		local camera = Instance.new("Camera")
		camera.FieldOfView = FIELD_OF_VIEW
		camera.CFrame = CFrame.lookAt(centre.Position - Vector3.new(0, 0, reach), centre.Position)
		copy.Parent = window
		camera.Parent = window
		window.CurrentCamera = camera
		return function()
			copy:Destroy()
			camera:Destroy()
		end
	end, deps)
	local light = PortraitViewModel.lighting("light")
	return e("ViewportFrame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		Rotation = props.rotation or 0,
		BackgroundTransparency = 1,
		Ambient = light.ambient,
		LightColor = light.color,
		LightDirection = light.direction,
		ImageColor3 = if props.faded == true then Color3.fromRGB(150, 146, 170) else Color3.new(1, 1, 1),
		ImageTransparency = if props.faded == true then 0.25 else 0,
		ZIndex = props.zIndex,
		ref = setFrame,
	})
end

return DepotRankBadge
