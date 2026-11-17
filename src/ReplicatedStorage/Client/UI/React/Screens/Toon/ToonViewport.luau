--!strict
--[=[
	ToonViewport: an employee in a skin, in 3D, inside the UI (a card's art, a page's or the pick screen's hero). The
	model comes from EmployeePreviewSystem, dressed exactly as the server dresses a real character, and is framed by
	PortraitViewModel.camera (refitted on resize without a rebuild).
	- `live = false` (default, cards): a static posed copy, every part anchored, no Animator: drawn once, the cost of
	  an image. The pose is the employee's `context` pose (EmployeePoseRules; default "idle": the employee held in its
	  own idle).
	- `live = true` (the hero): the model in a WorldModel with its idle loop playing (the skin's own showcase idle when
	  it has one). Past the live cap (two at once) it quietly shows the static copy instead.
	- `emote` (a Cosmetic emote id, live only; not while its screen is covered, ToonCoveredContext): the hero loops
	  that emote on the 3D preview stage instead
	  (EmployeeStageSystem; owner, 2026-10-29: a ViewportFrame draws no particles, so its effects would not show): the
	  viewport stays empty and the stage's camera puts the model in this frame's place on the screen.
	  A live hero's props follow its clip's markers (EmotePropSystem): a skin's showcase idle holds them out.
	- `reveal` (live only): the hero plays its reveal once (EmployeePreviewSystem.playReveal: the skin's unlock reveal,
	  else the employee's hire reveal in the skin), then its idle; its faces follow the clip's Face markers
	  (EmoteEffectSystem, faces only here). Closing cancels it: the props hide and the clip's listeners go.
	The model is rebuilt only when the employee, skin, colour style, framing or live flag changes, and destroyed with the component.
	A new model shows only once its meshes and textures are loaded, or after EmployeePreviewSystem.PRELOAD_SECONDS
	(`whenLoaded`): never half drawn (owner, 2026-11-16: a new outfit mesh missing on an item page).
	A live full figure is re-measured while it moves and the camera eases out to take in anything that leaves the
	fitted box (PortraitViewModel.grow), so a reveal or idle never cuts off an arm or ears.
	`platform` stands the model on a round 3D platform in the given colours (built in the viewport, so it is lit and
	turns with the model's world, never a flat shape behind it); the camera frames the two together.
	`outfit` shows a whole player's look instead (EmployeePreviewSystem.outfit: your own character cloned, with the
	rank lanyard and the outfit's vacuum on its pack); `vacuum` with no employee or outfit shows that vacuum skin's
	canister on its own (VacuumPreviewSystem.alone); `turn` swings the camera round (180 = from behind, to see a
	vacuum on the back).
	`spin` lets the player turn the model round (owner, 2026-11-14): drag it with the mouse (either button) or a finger,
	flick it to coast, or push the controller's right stick (ToonSpinViewModel). Only the model turns, about the upright
	axis through its own root; the camera, the light and the platform stay still (owner, 2026-11-14: the first version
	orbited the camera round the model's box, so the model drifted off-centre and the platform seemed to swing). The
	camera is fitted once to a box that holds the model at every angle, centred on its root (ToonSpinViewModel.around),
	so it never moves while the model turns. That box also takes in everywhere the hero's clips and props reach
	(measured per clip, EmployeePreviewSystem.reachOf), and a spinning hero never grows to fit: the camera holds still for
	as long as you look at the item (owner, 2026-11-14: no zoom). An emote hero turns on the stage (EmployeeStageSystem
	`turn`).
	The angle starts at the front for each new item and is kept through a colour style change.
	`dim` darkens it (a locked item). With no art for the employee in the place it stays blank, then shows the loud error
	tile (PortraitError, timing in PortraitViewModel.missing). Exempt (needs a renderer); story in ToonViewport.story.
	The props type and the model build are ToonViewportModel's, the platform ToonViewportPlatform's, and the spin
	input useToonSpin's.

	@class ToonViewport
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local EmoteEffectSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteEffectSystem)
local EmotePropSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmotePropSystem)
local EmoteVfxSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteVfxSystem)
local EmployeeStageSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeStageSystem)
local ToonCoveredContext = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonCoveredContext)
local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeePoseRules = require(EmployeeShared.Rules.EmployeePoseRules)
local EmployeePoseFormulas = require(EmployeeShared.Utils.EmployeePoseFormulas)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local PortraitError = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitError)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)
local ToonSpinViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSpinViewModel)
local UIBuildQueueSystem = require(ReplicatedStorage.Client.Features.UI.Systems.UIBuildQueueSystem)
local ToonViewportModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonViewportModel)
local ToonViewportPlatform = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonViewportPlatform)
local useToonSpin = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonSpin)

local e = React.createElement

-- A locked item's art: darkened, a little cool.
local DIM_COLOR = Color3.fromRGB(70, 60, 96)

-- The platform's colours: its top face and its side.
export type Platform = ToonViewportPlatform.Platform

export type ToonViewportProps = ToonViewportModel.ToonViewportProps

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

-- The click the last reaction answered. It lives here so a hero rebuilt on a tab change does not react to it again.
local reactAnswered: number? = nil

local function aspectOf(frame: ViewportFrame): number
	local size = frame.AbsoluteSize
	return if size.X > 0 and size.Y > 0 then size.X / size.Y else 1
end

-- The live hero a reaction plays on.
type Hero = { model: Model, who: string, skin: string?, idle: string? }

local function ToonViewport(props: ToonViewportProps): React.ReactNode
	-- On a screen covered by a full-screen scene (ToonCoveredContext), an emote hero lets go of the 3D stage, so the
	-- screen on top can have it (one stage at a time); it takes it back when uncovered.
	local covered = React.useContext(ToonCoveredContext.Context)
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
		stopReaction.current = EmployeePreviewSystem.playReaction(live.model, live.who, live.skin, live.idle)
	end

	local platform = props.platform
	local platformKey = if platform ~= nil then platform.top:ToHex() .. platform.side:ToHex() else ""
	local deps: { unknown } = {
		frame,
		ToonViewportModel.lookKey(props),
		props.live == true,
		props.framing,
		platformKey,
		props.turn or 0,
		if covered then "" else props.emote or "",
		props.reveal == true,
		props.idle or "",
	}
	React.useEffect(function(): () -> ()
		if frame == nil then
			return function() end
		end
		-- Builds the model into the frame and returns its teardown.
		local function mount(): () -> ()
			local model, moving = ToonViewportModel.build(props)
			setShown(model ~= nil)
			if model == nil then
				return function() end
			end
			local bounds =
				EmployeePoseFormulas.bounds(EmployeePortraitSystem.boxes(model, PortraitViewModel.parts(props.framing)))
			-- A spinning model turns about its own root: the camera and platform centre there, on a box fitted ONCE to
			-- everywhere its clips and props reach (EmployeePreviewSystem.reachOf, measured), so the camera never refits.
			local root: Vector3? = nil
			if props.spin == true and bounds ~= nil then
				local rootPart = model:FindFirstChild("HumanoidRootPart")
				local at = if rootPart ~= nil and rootPart:IsA("BasePart")
					then rootPart.Position
					else (bounds.min + bounds.max) / 2
				root = at
				local outfit = props.outfit
				local reach = if outfit ~= nil
					then EmployeePreviewSystem.reachOf(outfit.employee, CosmeticRegistry.keyOf(outfit.look.skin))
					elseif props.employee ~= nil then EmployeePreviewSystem.reachOf(
						props.employee,
						props.skin,
						props.idle
					)
					else nil
				bounds = ToonSpinViewModel.reach(bounds, at, reach)
			end
			local emote = if moving and not covered then props.emote else nil
			if emote ~= nil and bounds ~= nil then
				local height = bounds.max.Y - bounds.min.Y
				bounds = { min = bounds.min, max = bounds.max + Vector3.new(0, height * EMOTE_HEADROOM, 0) }
			end
			local unplatformed = bounds
			local stand: Model? = nil
			if platform ~= nil and bounds ~= nil then
				stand, bounds = ToonViewportPlatform.platformFor(bounds, platform)
			end
			local who = if props.outfit ~= nil then props.outfit.employee else props.employee
			local skin = if props.outfit ~= nil then nil else props.skin
			local cleanups: { () -> () } = {}
			local stageTurn: ((degrees: number) -> ())? = nil
			local pose = if emote ~= nil and who ~= nil
				then EmployeePoseRules.select(EmployeePoseRegistry.get(who), props.context or "idle", {})
				else nil
			-- The live model goes to the stage; until the stage is live (its assets loaded), this viewport shows a posed copy
			-- of it on its own platform, dropped in the frame the stage takes over.
			local standIn = if pose ~= nil then EmployeePortraitSystem.build(model, pose, true) else nil
			if emote ~= nil and who ~= nil and bounds ~= nil and standIn ~= nil then
				local standInPlatform: Model? = nil
				if platform ~= nil and unplatformed ~= nil then
					standInPlatform = ToonViewportPlatform.platformFor(unplatformed, platform)
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
			local function fit()
				if bounds ~= nil then
					local view = PortraitViewModel.camera(bounds, props.framing, aspectOf(frame), props.turn)
					camera.FieldOfView = view.fov
					camera.CFrame = view.cframe
				end
			end
			fit()
			-- The player's spin turns the model shown here (and the stage's), never the camera or the platform.
			local spun: Model = model
			local home = spun:GetPivot()
			local onStage = stageTurn
			local axis = root
			if axis ~= nil then
				local spinAxis: Vector3 = axis
				local function apply(angle: number)
					spun:PivotTo(ToonSpinViewModel.turn(home, spinAxis, angle))
					if onStage ~= nil then
						onStage(angle)
					end
				end
				applySpin.current = apply
				if spinState.current.angle ~= 0 then
					apply(spinState.current.angle)
				end
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
			-- Hidden until its meshes and textures are in (EmployeePreviewSystem.whenLoaded; owner, 2026-11-16: an item
			-- page showed the textured Showstopper's coat and hat but not its new bloomer mesh). A still copy is drawn
			-- once, so it is put back in its frame once loaded to be drawn again with everything.
			-- Already loaded (a warm cache, the usual case): shown at once, no wait and no redraw (Shift 11-16: those cost
			-- the warm Shop open ~30 ms).
			local drawn: Model, drawnIn: Instance, still = model, holder, not moving
			local loading: { Instance } = { model }
			if stand ~= nil then
				table.insert(loading, stand)
			end
			local cancelLoad = function() end
			if not EmployeePreviewSystem.loaded(loading) then
				frame.ImageTransparency = 1
				cancelLoad = EmployeePreviewSystem.whenLoaded(loading, function()
					if still and drawn.Parent == drawnIn then
						drawn.Parent = nil
						drawn.Parent = drawnIn
					end
					frame.ImageTransparency = 0
				end)
			end
			local untrack: { () -> () } = {}
			if moving and who ~= nil then
				table.insert(untrack, previewProps.track(model))
				table.insert(untrack, previewFaces.track(model))
				local idle = if props.outfit ~= nil then nil else props.idle
				local stopReveal = if props.reveal == true
					then EmployeePreviewSystem.playReveal(model, who, skin, idle)
					else nil
				if stopReveal ~= nil then
					table.insert(untrack, stopReveal)
				else
					EmployeePreviewSystem.playIdle(model, who, skin, nil, idle)
				end
				local stopFidgets = EmployeePreviewSystem.playFidgets(model, who, skin, idle)
				if stopFidgets ~= nil then
					table.insert(untrack, stopFidgets)
				end
				if props.reveal ~= true then
					hero.current = { model = model, who = who, skin = skin, idle = idle }
					answerClick(false)
				end
			end
			local resized = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
			-- A live full figure moves out of its rest-pose box (a reveal's raised arm or hop, an idle's ears): keep
			-- measuring it and ease the camera out to take in all of it, never in (owner, 2026-11-12: never cut off).
			local growing: RBXScriptConnection? = nil
			-- (Not a spinning hero: its camera was fitted once to its measured reach and holds; owner, 2026-11-14.)
			if moving and props.framing == "full" and bounds ~= nil and root == nil then
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
							target = PortraitViewModel.camera(grown, props.framing, aspectOf(frame), props.turn).cframe
						end
					end
					if target ~= nil then
						camera.CFrame = camera.CFrame:Lerp(target, math.min(1, dt * GROW_EASE))
					end
				end)
			end
			return function()
				cancelLoad()
				frame.ImageTransparency = 0
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
		end
		-- A live model (a hero, an emote, a reveal) mounts now. A still card waits its turn on the build queue, so a
		-- screen of cards clones about two models a frame instead of all of them in the frame it opens
		-- (UIBuildQueueSystem; Lobby 2026-11-15: the Shop's 12 cards were one 60-100 ms frame).
		if props.live == true then
			return mount()
		end
		local unmount: (() -> ())? = nil
		local cancel = UIBuildQueueSystem.enqueue(function()
			unmount = mount()
		end)
		return function()
			cancel()
			local teardown = unmount
			if teardown ~= nil then
				teardown()
			end
		end
	end, deps)

	useToonSpin(frame, props.spin, spinState, applySpin)

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
