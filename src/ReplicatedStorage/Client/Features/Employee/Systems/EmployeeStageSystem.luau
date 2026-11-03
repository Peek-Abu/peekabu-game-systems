--!strict
--[=[
	EmployeeStageSystem: the 3D preview stage (owner, 2026-10-29: a shop or inventory emote preview must show the real
	effects, which a ViewportFrame cannot draw: no particles, billboards or lights there). A live preview model (the
	caller's, from EmployeePreviewSystem) and its platform are moved to a stage far from the map, built on this client
	only, and played there with the game's own emote systems (EmotePropSystem, EmoteEffectSystem with
	EmoteVfxSystem: the same bubbles, giant bubble, dust and faces players see). While a stage is up:
	- the camera is held (Scriptable, every frame after the game's camera) so the model sits in the UI window the
	  caller names (`place`), seen from its front (EmployeeStageFormulas.camera);
	- `wall` holds a SurfaceGui on a wall behind the stage that fills the screen exactly (EmployeeStageFormulas.wall):
	  ToonBackdrop draws the menu's background there instead of over the world, so the screen looks as before;
	- one stage at a time: a new `show` releases the old one.
	It goes live only when it is right from its first frame (owner, 2026-10-29: the skin read dark, then washed out,
	after a visible delay; the causes were the place's live Lighting, two point lights blooming under the place's
	Bloom, the skin's textures not yet loaded, and the camera moving before the wall was drawn):
	1. the model's and platform's assets are loaded (ContentProvider, at most PRELOAD_SECONDS); the caller shows its
	   posed copy meanwhile (`onReady` says when to drop it);
	2. Lighting takes the stage's own values (EmployeeStageFormulas.LIGHTING: flat and bright, no shadows, fog or sky
	   light) and the place's post effects and Atmosphere pause; no lights are added;
	3. `wall` is set and the camera is taken once the backdrop is drawn on it, and `live` turns true in that frame
	   (ToonBackdrop keeps its on-screen copy until then); the clip starts.
	`release` puts the camera back as it was (type, subject, frame, field of view), puts back the Lighting values the
	place has not changed meanwhile (EmployeeStageFormulas.restore) and the paused effects, and destroys the stage.
	Exempt from specs (camera, Instances and the emote shells); the maths is specced in EmployeeStageFormulas.

	@class EmployeeStageSystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local EmployeePoseFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeePoseFormulas)
local EmoteEffectSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteEffectSystem)
local EmotePropSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmotePropSystem)
local EmoteVfxConstants = require(ReplicatedStorage.Client.Features.Emote.Data.EmoteVfxConstants)
local EmoteVfxSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteVfxSystem)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local EmployeeStageFormulas = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeStageFormulas)

-- Far above the map, so nothing of a place's art is in view.
local ORIGIN = Vector3.new(0, 4000, 0)
-- The camera's vertical field of view, and how far behind the model the backdrop wall stands.
local FOV = 30
local WALL_BEHIND = 40
-- The camera turns this far round the model (degrees), as the UI previews do (PortraitViewModel).
local YAW = 20
local RENDER_STEP = "EmployeeStage"
-- The longest the stage waits for its assets before it goes live anyway.
local PRELOAD_SECONDS = 3
-- The most frames it waits for the backdrop to be drawn on its wall.
local WALL_FRAMES = 10

export type Spec = {
	-- A live preview (EmployeePreviewSystem.live): the stage takes it over and destroys it on release.
	model: Model,
	-- The platform under it, built where the model stands now (or nil), and their joint box at that spot.
	platform: Model?,
	bounds: EmployeePoseFormulas.Bounds,
	employee: string,
	skin: string?,
	-- A Cosmetic emote id to loop (else the idle plays).
	emote: string?,
	-- Called once, in the frame the stage goes live (the caller drops its stand-in then).
	onReady: (() -> ())?,
}

export type Stage = {
	-- The UI window (pixels from the screen's top-left) the model shows in.
	place: (rect: EmployeeStageFormulas.Rect) -> (),
	release: () -> (),
}

local props = EmotePropSystem.new()
-- The emote's effects, but not its sounds: a preview loops, so a sound would repeat on every loop (the menus stay
-- silent; the sounds are for a real emote in the world).
local effects = EmoteEffectSystem.live(function(id: string, character: Model, value: string): (() -> ())?
	return if EmoteVfxConstants.SOUND_CUES[id] ~= nil then nil else EmoteVfxSystem.start(id, character, value)
end)

local EmployeeStageSystem = {}

--[=[
	The SurfaceGui on the stage's backdrop wall while a stage is up, else nil (ToonBackdrop draws into it).
]=]
local noWall: SurfaceGui? = nil
EmployeeStageSystem.wall = Charm.atom(noWall)
--[=[
	True from the frame the stage's camera is held: ToonBackdrop drops its on-screen copy then.
]=]
EmployeeStageSystem.live = Charm.atom(false)

local current: Stage? = nil

type LightValues = { [string]: EmployeeStageFormulas.LightValue }

-- The Lighting properties EmployeeStageFormulas.LIGHTING names, as they are now.
local function readLighting(): LightValues
	return {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ExposureCompensation = Lighting.ExposureCompensation,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		GlobalShadows = Lighting.GlobalShadows,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
	}
end

local function number(values: LightValues, name: string): number?
	local value = values[name]
	return if type(value) == "number" then value else nil
end

local function color(values: LightValues, name: string): Color3?
	local value = values[name]
	return if typeof(value) == "Color3" then value else nil
end

-- Writes the values given (a missing one is left as it is).
local function writeLighting(values: LightValues)
	Lighting.ClockTime = number(values, "ClockTime") or Lighting.ClockTime
	Lighting.Brightness = number(values, "Brightness") or Lighting.Brightness
	Lighting.Ambient = color(values, "Ambient") or Lighting.Ambient
	Lighting.OutdoorAmbient = color(values, "OutdoorAmbient") or Lighting.OutdoorAmbient
	Lighting.ExposureCompensation = number(values, "ExposureCompensation") or Lighting.ExposureCompensation
	Lighting.EnvironmentDiffuseScale = number(values, "EnvironmentDiffuseScale") or Lighting.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = number(values, "EnvironmentSpecularScale") or Lighting.EnvironmentSpecularScale
	local shadows = values.GlobalShadows
	if type(shadows) == "boolean" then
		Lighting.GlobalShadows = shadows
	end
	Lighting.FogStart = number(values, "FogStart") or Lighting.FogStart
	Lighting.FogEnd = number(values, "FogEnd") or Lighting.FogEnd
end

-- Gives Lighting the stage's values and pauses the place's post effects and Atmosphere; returns the undo.
local function takeLighting(): () -> ()
	local saved = readLighting()
	writeLighting(EmployeeStageFormulas.LIGHTING)
	local paused: { PostEffect } = {}
	local hazes: { [Atmosphere]: { density: number, haze: number } } = {}
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") and child.Enabled then
			child.Enabled = false
			table.insert(paused, child)
		elseif child:IsA("Atmosphere") then
			hazes[child] = { density = child.Density, haze = child.Haze }
			child.Density = 0
			child.Haze = 0
		end
	end
	return function()
		writeLighting(EmployeeStageFormulas.restore(saved, readLighting()))
		for _, effect in paused do
			if effect.Parent ~= nil and not effect.Enabled then
				effect.Enabled = true
			end
		end
		for atmosphere, was in hazes do
			if atmosphere.Parent ~= nil and atmosphere.Density == 0 then
				atmosphere.Density = was.density
				atmosphere.Haze = was.haze
			end
		end
	end
end

local function anchored(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

function EmployeeStageSystem.show(spec: Spec): Stage?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local old = current
	if old ~= nil then
		old.release()
	end

	local folder = Instance.new("Folder")
	folder.Name = "EmployeeStage"
	-- Moved so the feet's centre stands on ORIGIN; the bounds move with it.
	local feet = Vector3.new(
		(spec.bounds.min.X + spec.bounds.max.X) / 2,
		spec.bounds.min.Y,
		(spec.bounds.min.Z + spec.bounds.max.Z) / 2
	)
	local shift = ORIGIN - feet
	spec.model:PivotTo(spec.model:GetPivot() + shift)
	local platform = spec.platform
	if platform ~= nil then
		platform:PivotTo(platform:GetPivot() + shift)
		platform.Parent = folder
	end
	local yaw = math.rad(YAW)
	local front = CFrame.lookAt(ORIGIN, ORIGIN + Vector3.new(math.sin(yaw), 0, -math.cos(yaw)))
	-- The box in the stage's facing: every corner turned, then boxed again.
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, x in { spec.bounds.min.X, spec.bounds.max.X } do
		for _, y in { spec.bounds.min.Y, spec.bounds.max.Y } do
			for _, z in { spec.bounds.min.Z, spec.bounds.max.Z } do
				local corner = front:PointToObjectSpace(Vector3.new(x, y, z) + shift)
				low, high = low:Min(corner), high:Max(corner)
			end
		end
	end
	local bounds: EmployeeStageFormulas.Bounds = { min = low, max = high }

	local wallPart = anchored("Wall", Vector3.new(1, 1, 0.2))
	wallPart.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StageBackdrop"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.ResetOnSpawn = false
	gui.Parent = wallPart
	wallPart.Parent = folder
	folder.Parent = workspace
	spec.model.Parent = folder

	local saved = {
		cameraType = camera.CameraType,
		subject = camera.CameraSubject,
		cframe = camera.CFrame,
		fov = camera.FieldOfView,
	}
	local window: EmployeeStageFormulas.Rect? = nil
	local released = false
	local live = false
	local held = false
	local restoreLighting: (() -> ())? = nil
	local stopEmote: (() -> ())? = nil
	local untrack: { () -> () } = {}

	local function frame()
		local rect = window
		local screen = camera.ViewportSize
		if rect == nil or screen.X <= 0 or screen.Y <= 0 or rect.size.X <= 0 or rect.size.Y <= 0 then
			return
		end
		local view = EmployeeStageFormulas.camera(bounds, rect, screen, FOV, front)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FOV
		camera.CFrame = view
		local distance = (front.Position - view.Position):Dot(view.LookVector) + WALL_BEHIND
		local wallFrame, size = EmployeeStageFormulas.wall(view, screen, FOV, distance)
		wallPart.CFrame = wallFrame
		wallPart.Size = Vector3.new(size.X, size.Y, 0.2)
		gui.CanvasSize = screen
	end

	-- Steps 2 and 3 of the header, once the assets are in (or PRELOAD_SECONDS ran out).
	local function goLive()
		if released or live then
			return
		end
		live = true
		restoreLighting = takeLighting()
		EmployeeStageSystem.wall(gui)
		local waited = 0
		while #gui:GetChildren() == 0 and waited < WALL_FRAMES and not released do
			RunService.RenderStepped:Wait()
			waited += 1
		end
		if released then
			return
		end
		held = true
		RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, frame)
		frame()
		EmployeeStageSystem.live(true)
		table.insert(untrack, props.track(spec.model))
		table.insert(untrack, effects.track(spec.model))
		local emote = spec.emote
		stopEmote = if emote ~= nil
			then EmployeePreviewSystem.playEmote(spec.model, spec.employee, spec.skin, emote)
			else nil
		if stopEmote == nil then
			EmployeePreviewSystem.playIdle(spec.model, spec.employee, spec.skin)
		end
		local onReady = spec.onReady
		if onReady ~= nil then
			onReady()
		end
	end

	task.spawn(function()
		local assets: { Instance } = { spec.model }
		if platform ~= nil then
			table.insert(assets, platform)
		end
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
		goLive()
	end)
	task.delay(PRELOAD_SECONDS, goLive)

	local stage: Stage
	stage = {
		place = function(rect)
			window = rect
		end,
		release = function()
			if released then
				return
			end
			released = true
			if current == stage then
				current = nil
			end
			RunService:UnbindFromRenderStep(RENDER_STEP)
			if EmployeeStageSystem.wall() == gui then
				EmployeeStageSystem.wall(nil)
				EmployeeStageSystem.live(false)
			end
			local stop = stopEmote
			if stop ~= nil then
				stop()
			end
			for _, release in untrack do
				release()
			end
			local undo = restoreLighting
			if undo ~= nil then
				undo()
			end
			if held then
				camera.CameraType = saved.cameraType
				camera.CameraSubject = saved.subject
				camera.FieldOfView = saved.fov
				camera.CFrame = saved.cframe
			end
			EmployeePreviewSystem.release(spec.model)
			folder:Destroy()
		end,
	}
	current = stage
	return stage
end

return EmployeeStageSystem
