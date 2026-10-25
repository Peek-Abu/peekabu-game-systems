--!strict
--[=[
	ToonViewport: an employee in a skin, in 3D, inside the UI (a card's art, a page's or the pick screen's hero). The
	model comes from EmployeePreviewSystem, dressed exactly as the server dresses a real character, and is framed by
	PortraitViewModel.camera (refitted on resize without a rebuild).
	- `live = false` (default, cards): a static posed copy, every part anchored, no Animator: drawn once, the cost of
	  an image. The pose is the employee's `context` pose (EmployeePoseRules; default "crew").
	- `live = true` (the hero): the model in a WorldModel with its idle loop playing. Past the live cap (two at once)
	  it quietly shows the static copy instead.
	The model is rebuilt only when the employee, skin, framing or live flag changes, and destroyed with the component.
	`dim` darkens it (a locked item). With no art for the employee in the place it shows their ID-card photo
	(PortraitViewModel.fallback). Exempt (needs a renderer); story in ToonViewport.story.

	@class ToonViewport
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeePoseRules = require(EmployeeShared.Rules.EmployeePoseRules)
local EmployeePoseFormulas = require(EmployeeShared.Utils.EmployeePoseFormulas)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)

local e = React.createElement

-- A locked item's art: darkened, a little cool.
local DIM_COLOR = Color3.fromRGB(70, 60, 96)

export type ToonViewportProps = {
	employee: string,
	-- An EmployeeRegistry skin key (nil = the default look).
	skin: string?,
	live: boolean?,
	framing: PortraitViewModel.Framing,
	context: EmployeePoseRegistry.PortraitContext?,
	tone: PortraitViewModel.Tone?,
	dim: boolean?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	layoutOrder: number?,
}

local function aspectOf(frame: ViewportFrame): number
	local size = frame.AbsoluteSize
	return if size.X > 0 and size.Y > 0 then size.X / size.Y else 1
end

-- The model to show and whether it moves: a live one when asked and a slot is free, else the static posed copy.
local function build(props: ToonViewportProps): (Model?, boolean)
	if props.live == true then
		local model = EmployeePreviewSystem.live(props.employee, props.skin, ReplicatedStorage)
		if model ~= nil then
			return model, true
		end
	end
	local pose = EmployeePoseRules.select(EmployeePoseRegistry.get(props.employee), props.context or "crew", {})
	return EmployeePreviewSystem.static(props.employee, props.skin, ReplicatedStorage, pose), false
end

local function ToonViewport(props: ToonViewportProps): React.ReactNode
	local noFrame: ViewportFrame? = nil
	local frame, setFrame = React.useState(noFrame)
	local shown, setShown = React.useState(true)

	local deps: { unknown } = { frame, props.employee, props.skin or "", props.live == true, props.framing }
	React.useEffect(function(): () -> ()
		if frame == nil then
			return function() end
		end
		local model, moving = build(props)
		setShown(model ~= nil)
		if model == nil then
			return function() end
		end
		local bounds =
			EmployeePoseFormulas.bounds(EmployeePortraitSystem.boxes(model, PortraitViewModel.parts(props.framing)))
		local camera = Instance.new("Camera")
		local function fit()
			if bounds ~= nil then
				local view = PortraitViewModel.camera(bounds, props.framing, aspectOf(frame))
				camera.FieldOfView = view.fov
				camera.CFrame = view.cframe
			end
		end
		fit()
		camera.Parent = frame
		frame.CurrentCamera = camera
		local holder: Instance = frame
		if moving then
			local world = Instance.new("WorldModel")
			world.Parent = frame
			holder = world
		end
		model.Parent = holder
		if moving then
			EmployeePreviewSystem.playIdle(model, props.employee)
		end
		local resized = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		return function()
			resized:Disconnect()
			model:Destroy()
			if holder ~= frame then
				holder:Destroy()
			end
			camera:Destroy()
		end
	end, deps)

	local light = PortraitViewModel.lighting(props.tone or "light")
	local tint = if props.dim == true then DIM_COLOR else Color3.new(1, 1, 1)
	return e("ViewportFrame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		Ambient = light.ambient,
		LightColor = light.color,
		LightDirection = light.direction,
		ImageColor3 = tint,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
		ref = setFrame,
	}, {
		-- No art for this employee in the place yet: their ID-card photo instead.
		photo = if shown
			then nil
			else e("ImageLabel", {
				-- Fitted inside the frame (never spilling past it).
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = PortraitViewModel.fallback(props.employee, props.skin),
				ImageColor3 = tint,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = props.zIndex,
			}),
	})
end

return ToonViewport
