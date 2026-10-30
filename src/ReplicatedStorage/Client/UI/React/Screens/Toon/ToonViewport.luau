--!strict
--[=[
	ToonViewport: an employee in a skin, in 3D, inside the UI (a card's art, a page's or the pick screen's hero). The
	model comes from EmployeePreviewSystem, dressed exactly as the server dresses a real character, and is framed by
	PortraitViewModel.camera (refitted on resize without a rebuild).
	- `live = false` (default, cards): a static posed copy, every part anchored, no Animator: drawn once, the cost of
	  an image. The pose is the employee's `context` pose (EmployeePoseRules; default "crew").
	- `live = true` (the hero): the model in a WorldModel with its idle loop playing (the skin's own showcase idle when
	  it has one). Past the live cap (two at once) it quietly shows the static copy instead.
	- `emote` (a Cosmetic emote id, live only): the hero loops that emote on the 3D preview stage instead
	  (EmployeeStageSystem; owner, 2026-10-29: a ViewportFrame draws no particles, so its effects would not show): the
	  viewport stays empty and the stage's camera puts the model in this frame's place on the screen.
	  A live hero's props follow its clip's markers (EmotePropSystem): a skin's showcase idle holds them out.
	The model is rebuilt only when the employee, skin, colour style, framing or live flag changes, and destroyed with the component.
	`platform` stands the model on a round 3D platform in the given colours (built in the viewport, so it is lit and
	turns with the model's world, never a flat shape behind it); the camera frames the two together.
	`outfit` shows a whole player's look instead (EmployeePreviewSystem.outfit: your own character cloned, with the
	rank lanyard and the outfit's vacuum on its pack); `vacuum` with no employee or outfit shows that vacuum skin's
	canister on its own (VacuumPreviewSystem.alone); `turn` swings the camera round (180 = from behind, to see a
	vacuum on the back).
	`dim` darkens it (a locked item). With no art for the employee in the place it stays blank, then shows the loud error
	tile (PortraitError, timing in PortraitViewModel.missing). Exempt (needs a renderer); story in ToonViewport.story.

	@class ToonViewport
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local VacuumPreviewSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumPreviewSystem)
local EmotePropSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmotePropSystem)
local EmployeeStageSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeStageSystem)
local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeePoseRules = require(EmployeeShared.Rules.EmployeePoseRules)
local EmployeePoseFormulas = require(EmployeeShared.Utils.EmployeePoseFormulas)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local PortraitError = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitError)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

-- A locked item's art: darkened, a little cool.
local DIM_COLOR = Color3.fromRGB(70, 60, 96)

-- The platform's colours: its top face and its side.
export type Platform = { top: Color3, side: Color3 }

export type ToonViewportProps = {
	employee: string?,
	-- A whole player's look (takes the place of employee + skin).
	outfit: CosmeticTypes.Outfit?,
	-- A VacuumSkinRegistry key: with no employee or outfit, that vacuum alone.
	vacuum: string?,
	-- Degrees round the model (180 = from behind).
	turn: number?,
	-- An EmployeeRegistry skin key (nil = the default look).
	skin: string?,
	-- The skin's colour style (nil = 1); an outfit look carries its own.
	style: number?,
	live: boolean?,
	-- A Cosmetic emote id: a live hero loops it.
	emote: string?,
	framing: PortraitViewModel.Framing,
	context: EmployeePoseRegistry.PortraitContext?,
	tone: PortraitViewModel.Tone?,
	dim: boolean?,
	platform: Platform?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	layoutOrder: number?,
}

-- Live heroes' prop tracking (a skin's showcase idle holds its props out).
local previewProps = EmotePropSystem.new()
-- How much taller than the model at rest an emote hero's frame is (Bubble Ride floats up inside her bubble).
local EMOTE_HEADROOM = 0.35

local function aspectOf(frame: ViewportFrame): number
	local size = frame.AbsoluteSize
	return if size.X > 0 and size.Y > 0 then size.X / size.Y else 1
end

-- The platform's radius and thickness as shares of the model's height.
local PLATFORM_RADIUS = 0.34
local PLATFORM_HEIGHT = 0.07

-- One flat round slab (a Roblox cylinder lies along X: turned upright), its top face at `topY`.
local function slab(name: string, centre: Vector3, topY: number, radius: number, height: number, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(centre.X, topY - height / 2, centre.Z) * CFrame.Angles(0, 0, math.pi / 2)
	return part
end

--[=[
	The platform under the model's feet (the bounds' bottom): a light top, a thin ink line at its rim, the side, and
	an ink foot (the kit's outline and drop, in 3D). Returns it and the bounds grown to hold it.
]=]
local function platformFor(bounds: EmployeePoseFormulas.Bounds, colors: Platform): (Model, EmployeePoseFormulas.Bounds)
	local tall = bounds.max.Y - bounds.min.Y
	local radius = tall * PLATFORM_RADIUS
	local height = tall * PLATFORM_HEIGHT
	local centre = (bounds.min + bounds.max) / 2
	local feet = bounds.min.Y
	local line = height * 0.12
	local model = Instance.new("Model")
	model.Name = "Platform"
	slab("Top", centre, feet, radius, line * 1.5, colors.top).Parent = model
	slab("Rim", centre, feet - line * 1.5, radius * 1.025, line, UIToonConstants.COLOR.ink).Parent = model
	slab("Side", centre, feet - line * 2.5, radius, height - line * 3.5, colors.side).Parent = model
	slab("Foot", centre, feet - height + line, radius * 1.05, line * 1.4, UIToonConstants.COLOR.ink).Parent = model
	local reach = radius * 1.05
	local grown: EmployeePoseFormulas.Bounds = {
		min = Vector3.new(
			math.min(bounds.min.X, centre.X - reach),
			feet - height - line,
			math.min(bounds.min.Z, centre.Z - reach)
		),
		max = Vector3.new(
			math.max(bounds.max.X, centre.X + reach),
			bounds.max.Y,
			math.max(bounds.max.Z, centre.Z + reach)
		),
	}
	return model, grown
end

-- The model to show and whether it moves: a live one when asked and a slot is free, else the static posed copy.
local function build(props: ToonViewportProps): (Model?, boolean)
	local outfit = props.outfit
	if outfit ~= nil then
		local pose = EmployeePoseRules.select(EmployeePoseRegistry.get(outfit.employee), props.context or "crew", {})
		local mine = Players.LocalPlayer
		return EmployeePreviewSystem.outfit(
			outfit,
			ReplicatedStorage,
			if mine ~= nil then mine.Character else nil,
			props.live == true,
			pose
		)
	end
	local employee = props.employee
	if employee == nil then
		local vacuum = props.vacuum
		return if vacuum ~= nil
			then VacuumPreviewSystem.alone(VacuumSkinRules.select(vacuum), ReplicatedStorage)
			else nil,
			false
	end
	if props.live == true then
		local model = EmployeePreviewSystem.live(employee, props.skin, ReplicatedStorage, props.style)
		if model ~= nil then
			return model, true
		end
	end
	local pose = EmployeePoseRules.select(EmployeePoseRegistry.get(employee), props.context or "crew", {})
	return EmployeePreviewSystem.static(employee, props.skin, ReplicatedStorage, pose, props.style), false
end

-- What the model shows, as one string (the effect rebuilds only when it changes).
local function lookKey(props: ToonViewportProps): string
	local outfit = props.outfit
	if outfit ~= nil then
		return `{outfit.employee}|{outfit.look.skin}|{outfit.look.style}|{outfit.vacuum}`
	end
	return `{props.employee or ""}|{props.skin or ""}|{props.style or 1}|{props.vacuum or ""}`
end

local function ToonViewport(props: ToonViewportProps): React.ReactNode
	local noFrame: ViewportFrame? = nil
	local frame, setFrame = React.useState(noFrame)
	local shown, setShown = React.useState(true)

	local platform = props.platform
	local platformKey = if platform ~= nil then platform.top:ToHex() .. platform.side:ToHex() else ""
	local deps: { unknown } =
		{ frame, lookKey(props), props.live == true, props.framing, platformKey, props.turn or 0, props.emote or "" }
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
		local emote = if moving then props.emote else nil
		if emote ~= nil and bounds ~= nil then
			local height = bounds.max.Y - bounds.min.Y
			bounds = { min = bounds.min, max = bounds.max + Vector3.new(0, height * EMOTE_HEADROOM, 0) }
		end
		local unplatformed = bounds
		local stand: Model? = nil
		if platform ~= nil and bounds ~= nil then
			stand, bounds = platformFor(bounds, platform)
		end
		local who = if props.outfit ~= nil then props.outfit.employee else props.employee
		local skin = if props.outfit ~= nil then nil else props.skin
		local cleanups: { () -> () } = {}
		local pose = if emote ~= nil and who ~= nil
			then EmployeePoseRules.select(EmployeePoseRegistry.get(who), props.context or "crew", {})
			else nil
		-- The live model goes to the stage; until the stage is live (its assets loaded), this viewport shows a posed copy
		-- of it on its own platform, dropped in the frame the stage takes over.
		local standIn = if pose ~= nil then EmployeePortraitSystem.build(model, pose, true) else nil
		if emote ~= nil and who ~= nil and bounds ~= nil and standIn ~= nil then
			local standInPlatform: Model? = nil
			if platform ~= nil and unplatformed ~= nil then
				standInPlatform = platformFor(unplatformed, platform)
			end
			local stage = EmployeeStageSystem.show({
				model = model,
				platform = stand,
				bounds = bounds,
				employee = who,
				skin = skin,
				emote = emote,
				onReady = function()
					standIn:Destroy()
					if standInPlatform ~= nil then
						standInPlatform:Destroy()
					end
				end,
			})
			if stage ~= nil then
				local window: ViewportFrame = frame
				local function place()
					stage.place({ position = window.AbsolutePosition, size = window.AbsoluteSize })
				end
				place()
				local moved = window:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
				local sized = window:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
				table.insert(cleanups, function()
					moved:Disconnect()
					sized:Disconnect()
					-- Destroys the live model and its platform and puts the camera back.
					stage.release()
				end)
				model, moving, stand = standIn, false, standInPlatform
			else
				standIn:Destroy()
				if standInPlatform ~= nil then
					standInPlatform:Destroy()
				end
			end
		end
		local camera = Instance.new("Camera")
		local function fit()
			if bounds ~= nil then
				local view = PortraitViewModel.camera(bounds, props.framing, aspectOf(frame), props.turn)
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
		if stand ~= nil then
			stand.Parent = frame
		end
		local untrack: { () -> () } = {}
		if moving and who ~= nil then
			table.insert(untrack, previewProps.track(model))
			EmployeePreviewSystem.playIdle(model, who, skin)
		end
		local resized = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		return function()
			resized:Disconnect()
			for _, cleanup in cleanups do
				cleanup()
			end
			for _, release in untrack do
				release()
			end
			-- Frees a live slot at once: the rebuild that follows (another style, skin or framing) may need it now.
			EmployeePreviewSystem.release(model)
			if stand ~= nil then
				stand:Destroy()
			end
			if holder ~= frame then
				holder:Destroy()
			end
			camera:Destroy()
		end
	end, deps)

	local subject = if props.outfit ~= nil then props.outfit.employee else props.employee
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
		-- No art for this employee in the place: the loud error (a vacuum alone shows nothing).
		missing = if subject == nil
			then nil
			else e(PortraitError, { shown = shown, subject = subject, zIndex = props.zIndex }),
	})
end

return ToonViewport
