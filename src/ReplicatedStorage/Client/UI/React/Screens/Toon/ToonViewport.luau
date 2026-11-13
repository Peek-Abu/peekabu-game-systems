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
	- `reveal` (live only): the hero plays its reveal once (EmployeePreviewSystem.playReveal: the skin's unlock reveal,
	  else the employee's hire reveal in the skin), then its idle; its faces follow the clip's Face markers
	  (EmoteEffectSystem, faces only here). Closing cancels it: the props hide and the clip's listeners go.
	The model is rebuilt only when the employee, skin, colour style, framing or live flag changes, and destroyed with the component.
	A live full figure is re-measured while it moves and the camera eases out to take in anything that leaves the
	fitted box (PortraitViewModel.grow), so a reveal or idle never cuts off an arm or ears.
	`platform` stands the model on a round 3D platform in the given colours (built in the viewport, so it is lit and
	turns with the model's world, never a flat shape behind it); the camera frames the two together.
	`outfit` shows a whole player's look instead (EmployeePreviewSystem.outfit: your own character cloned, with the
	rank lanyard and the outfit's vacuum on its pack); `vacuum` with no employee or outfit shows that vacuum skin's
	canister on its own (VacuumPreviewSystem.alone); `turn` swings the camera round (180 = from behind, to see a
	vacuum on the back).
	`spin` lets the player turn the model round (owner, 2026-11-14): drag it with the mouse (either button) or a finger,
	flick it to coast, or push the controller's right stick (ToonSpinViewModel). The viewport turns its camera and light
	together, so the model reads as turning in place; an emote hero turns on the stage (EmployeeStageSystem `turn`).
	The angle starts at the front for each new item and is kept through a colour style change.
	`dim` darkens it (a locked item). With no art for the employee in the place it stays blank, then shows the loud error
	tile (PortraitError, timing in PortraitViewModel.missing). Exempt (needs a renderer); story in ToonViewport.story.

	@class ToonViewport
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local VacuumPreviewSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumPreviewSystem)
local EmoteEffectSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteEffectSystem)
local EmotePropSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmotePropSystem)
local EmoteVfxSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteVfxSystem)
local EmployeeStageSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeStageSystem)
local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeePoseRules = require(EmployeeShared.Rules.EmployeePoseRules)
local EmployeePoseFormulas = require(EmployeeShared.Utils.EmployeePoseFormulas)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local PortraitError = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitError)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)
local ToonSpinViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSpinViewModel)
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
	-- A live hero plays its reveal once, then its idle.
	reveal: boolean?,
	-- A click's time: a live hero plays its menu reaction, once per time, then its idle. The same model waits out
	-- REACT_COOLDOWN between two clicks; a click that rebuilds the model reacts on the new one.
	react: number?,
	framing: PortraitViewModel.Framing,
	context: EmployeePoseRegistry.PortraitContext?,
	tone: PortraitViewModel.Tone?,
	dim: boolean?,
	-- The player can turn the model round (drag, flick, right stick).
	spin: boolean?,
	platform: Platform?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	layoutOrder: number?,
}

-- Live heroes' prop and face tracking (a skin's showcase idle holds its props out; a reveal changes faces). Only the
-- face effect runs here: particles do not render in a ViewportFrame (emotes play on EmployeeStageSystem instead).
local previewProps = EmotePropSystem.new()
local previewFaces = EmoteEffectSystem.live(function(id: string, character: Model, value: string): (() -> ())?
	return if id == "face" then EmoteVfxSystem.start(id, character, value) else nil
end)
-- How much taller than the model at rest an emote hero's frame is (Bubble Ride floats up inside her bubble).
local EMOTE_HEADROOM = 0.35
-- A live full figure is re-measured this often (seconds) while it moves, and the camera eases out at this rate (per
-- second) when the figure reaches past its fitted box (PortraitViewModel.grow).
local GROW_EVERY = 0.1
local GROW_EASE = 8
-- Seconds before a hero reacts to another click, so spam-clicking does not restart it every frame.
local REACT_COOLDOWN = 1.5

-- A drag that has not moved for this long (seconds) before letting go does not coast.
local SPIN_HOLD_STILL = 0.08
-- Each spinning viewport binds the right stick under its own action name.
local spinActions = 0

-- The click the last reaction answered. It lives here so a hero rebuilt on a tab change does not react to it again.
local reactAnswered: number? = nil

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

-- The live hero a reaction plays on.
type Hero = { model: Model, who: string, skin: string? }

local function ToonViewport(props: ToonViewportProps): React.ReactNode
	local noFrame: ViewportFrame? = nil
	local frame, setFrame = React.useState(noFrame)
	local shown, setShown = React.useState(true)
	local noHero: Hero? = nil
	local hero = React.useRef(noHero)
	local noStop: (() -> ())? = nil
	local stopReaction = React.useRef(noStop)
	local reactedAt = React.useRef(0)
	local spinState = React.useRef(ToonSpinViewModel.new())
	local noApply: ((angle: number) -> ())? = nil
	-- Shows an angle on the model built now (set by the build, cleared with it).
	local applySpin = React.useRef(noApply)

	-- A new item starts from the front (a colour style change keeps the angle).
	local subjectKey = if props.outfit ~= nil
		then `outfit|{props.outfit.employee}|{props.outfit.vacuum}`
		else `{props.employee or ""}|{props.skin or ""}|{props.vacuum or ""}`
	React.useEffect(function()
		spinState.current = ToonSpinViewModel.new()
	end, { subjectKey })

	local function answerClick(cooled: boolean)
		local click = props.react
		local live = hero.current
		-- With no live hero yet (a page still mounting) the click waits for the build.
		if click == nil or click == reactAnswered or live == nil then
			return
		end
		reactAnswered = click
		local now = os.clock()
		if cooled and now - reactedAt.current < REACT_COOLDOWN then
			return
		end
		reactedAt.current = now
		local stop = stopReaction.current
		if stop ~= nil then
			stop()
		end
		stopReaction.current = EmployeePreviewSystem.playReaction(live.model, live.who, live.skin)
	end

	local platform = props.platform
	local platformKey = if platform ~= nil then platform.top:ToHex() .. platform.side:ToHex() else ""
	local deps: { unknown } = {
		frame,
		lookKey(props),
		props.live == true,
		props.framing,
		platformKey,
		props.turn or 0,
		props.emote or "",
		props.reveal == true,
	}
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
		local stageTurn: ((degrees: number) -> ())? = nil
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
				stageTurn = stage.turn
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
		local baseLight = PortraitViewModel.lighting(props.tone or "light").direction
		-- The camera's turn round the model: the caller's, plus the player's spin.
		local function turnNow(): number
			return (props.turn or 0) + spinState.current.angle
		end
		local function fit()
			if bounds ~= nil then
				local view = PortraitViewModel.camera(bounds, props.framing, aspectOf(frame), turnNow())
				camera.FieldOfView = view.fov
				camera.CFrame = view.cframe
			end
		end
		-- The light swings round with the camera, so the side facing the player stays lit as the model turns.
		local function light()
			frame.LightDirection = CFrame.Angles(0, -math.rad(spinState.current.angle), 0):VectorToWorldSpace(baseLight)
		end
		fit()
		light()
		local onStage = stageTurn
		applySpin.current = function(angle: number)
			fit()
			light()
			if onStage ~= nil then
				onStage(angle)
			end
		end
		if onStage ~= nil then
			onStage(spinState.current.angle)
		end
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
			table.insert(untrack, previewFaces.track(model))
			local stopReveal = if props.reveal == true then EmployeePreviewSystem.playReveal(model, who, skin) else nil
			if stopReveal ~= nil then
				table.insert(untrack, stopReveal)
			else
				EmployeePreviewSystem.playIdle(model, who, skin)
			end
			local stopFidgets = EmployeePreviewSystem.playFidgets(model, who, skin)
			if stopFidgets ~= nil then
				table.insert(untrack, stopFidgets)
			end
			if props.reveal ~= true then
				hero.current = { model = model, who = who, skin = skin }
				answerClick(false)
			end
		end
		local resized = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		-- A live full figure moves out of its rest-pose box (a reveal's raised arm or hop, an idle's ears): keep
		-- measuring it and ease the camera out to take in all of it, never in (owner, 2026-11-12: never cut off).
		local growing: RBXScriptConnection? = nil
		if moving and props.framing == "full" and bounds ~= nil then
			local live: Model = model
			local target: CFrame? = nil
			local since = 0
			growing = RunService.Heartbeat:Connect(function(dt: number)
				since += dt
				local fitted = bounds
				if since >= GROW_EVERY and fitted ~= nil then
					since = 0
					local seen = EmployeePoseFormulas.bounds(EmployeePortraitSystem.boxes(live, nil))
					local grown = if seen ~= nil then PortraitViewModel.grow(fitted, seen) else nil
					if grown ~= nil then
						bounds = grown
						target = PortraitViewModel.camera(grown, props.framing, aspectOf(frame), turnNow()).cframe
					end
				end
				if target ~= nil then
					camera.CFrame = camera.CFrame:Lerp(target, math.min(1, dt * GROW_EASE))
				end
			end)
		end
		return function()
			applySpin.current = nil
			hero.current = nil
			local stop = stopReaction.current
			if stop ~= nil then
				stop()
				stopReaction.current = nil
			end
			resized:Disconnect()
			if growing ~= nil then
				growing:Disconnect()
			end
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

	local spinDeps: { unknown } = { frame, props.spin == true }
	-- The player's spin: a drag on the frame (either mouse button or a finger), the right stick, and the coast after a
	-- flick, one frame at a time.
	React.useEffect(function(): () -> ()
		local window = frame
		if not window or props.spin ~= true then
			return function() end
		end
		local function set(state: ToonSpinViewModel.State)
			local was = spinState.current.angle
			spinState.current = state
			local apply = applySpin.current
			if apply ~= nil and state.angle ~= was then
				apply(state.angle)
			end
		end
		local noGrip: InputObject? = nil
		local grip = noGrip
		local lastX, lastAt = 0, 0
		local stick = 0
		local began = window.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if grip ~= nil then
				return
			end
			if
				kind == Enum.UserInputType.MouseButton1
				or kind == Enum.UserInputType.MouseButton2
				or kind == Enum.UserInputType.Touch
			then
				grip = input
				lastX, lastAt = input.Position.X, os.clock()
				set(ToonSpinViewModel.drag(spinState.current, 0, window.AbsoluteSize.X, 0))
			end
		end)
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			local held = grip
			if held == nil then
				return
			end
			local follows = if held.UserInputType == Enum.UserInputType.Touch
				then input == held
				else input.UserInputType == Enum.UserInputType.MouseMovement
			if not follows then
				return
			end
			local now, x = os.clock(), input.Position.X
			set(ToonSpinViewModel.drag(spinState.current, x - lastX, window.AbsoluteSize.X, now - lastAt))
			lastX, lastAt = x, now
		end)
		local function letGo()
			grip = nil
			local now = os.clock()
			local state = spinState.current
			if now - lastAt > SPIN_HOLD_STILL then
				state = ToonSpinViewModel.drag(state, 0, window.AbsoluteSize.X, now - lastAt)
			end
			set(ToonSpinViewModel.release(state))
		end
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			local held = grip
			if held == nil then
				return
			end
			local same = if held.UserInputType == Enum.UserInputType.Touch
				then input == held
				else input.UserInputType == held.UserInputType
			if same then
				letGo()
			end
		end)
		spinActions += 1
		local action = `ToonSpin{spinActions}`
		ContextActionService:BindActionAtPriority(
			action,
			function(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
				stick = if state == Enum.UserInputState.Change or state == Enum.UserInputState.Begin
					then input.Position.X
					else 0
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.Thumbstick2
		)
		local stepping = RunService.Heartbeat:Connect(function(dt: number)
			set(ToonSpinViewModel.step(spinState.current, dt, stick))
		end)
		return function()
			began:Disconnect()
			moved:Disconnect()
			ended:Disconnect()
			stepping:Disconnect()
			ContextActionService:UnbindAction(action)
			if grip ~= nil then
				grip = nil
				spinState.current = ToonSpinViewModel.release(spinState.current)
			end
		end
	end, spinDeps)

	-- A click on the model already live. Declared after the build, so a click that rebuilds it finds the new one.
	React.useEffect(function()
		answerClick(true)
	end, { props.react or 0 })

	local subject = if props.outfit ~= nil then props.outfit.employee else props.employee
	local light = PortraitViewModel.lighting(props.tone or "light")
	local tint = if props.dim == true then DIM_COLOR else Color3.new(1, 1, 1)
	return e("ViewportFrame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		-- A spinning model takes the drag (the world's camera does not turn under it).
		Active = props.spin == true,
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
