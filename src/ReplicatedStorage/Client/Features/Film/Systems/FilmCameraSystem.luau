--!strict
--[=[
	FilmCameraSystem: the film camera for the trailer (admin-only; FilmServiceClient turns it on and off with F8).

	While on, it is the top camera mode (a custom mode high above gameplay modes) and the player's own controls and
	gameplay keys are silenced (a sinking input context, the character's controls off, and its keys sunk at a high
	ContextActionService priority so Q, C, 1-5 and the rest do nothing in the game).

	Keys:
	- W A S D fly, E up, Q down; hold Shift to go slow; the mouse wheel changes the speed.
	- Hold the right mouse button to look around.
	- Z zooms in, C zooms out (field of view).
	- Ctrl + 1..9 saves a camera mark; 1..9 glides to it.
	- P plays every saved mark in order (P again stops); [ and ] make the glide shorter or longer; Backspace clears
	  the marks.
	- F follows the next target (Mr. Harlow, then each player), looking at it; flying moves the offset. O orbits the
	  target. G goes back to free flight.

	A small status line shows in the HUD (FilmCameraStatus); F6 hides it with the rest.

	Spec-exempt shell (input, camera, RunService); the maths is specced in FilmFlyFormulas and
	FilmPathFormulas, the marks in FilmMarkTracker.

	@class FilmCameraSystem
]=]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FilmFlyFormulas = require(ReplicatedStorage.Client.Features.Film.Utils.FilmFlyFormulas)
local FilmPathFormulas = require(ReplicatedStorage.Client.Features.Film.Utils.FilmPathFormulas)
local FilmMarkTracker = require(ReplicatedStorage.Client.Features.Film.State.FilmMarkTracker)

export type Target = { name: string, part: BasePart }

export type Deps = {
	-- The camera mode stack (CameraServiceClient): push returns a token.
	pushMode: (update: (dt: number) -> (CFrame, number?)) -> number,
	removeMode: (token: number) -> (),
	-- Silences gameplay input while on (InputServiceClient context + the character's controls).
	silence: (silenced: boolean) -> (),
	-- What F can follow, in order.
	targets: () -> { Target },
	-- The status line (nil: none; FilmCameraStore through the FilmCameraStatus HUD widget).
	setStatus: (text: string?) -> (),
}

export type FilmCameraSystem = {
	toggle: () -> (),
	isActive: () -> boolean,
	stop: () -> (),
}

local SINK_ACTION = "FilmCameraKeys"
local WHEEL_ACTION = "FilmCameraWheel"
local SINK_PRIORITY = Enum.ContextActionPriority.High.Value + 100
local FLY_SHARPNESS = 6
local SLOW_FACTOR = 0.25
local LOOK_SENSITIVITY = 0.25
local ZOOM_RATE = 30
local ORBIT_DEGREES_PER_SECOND = 12
local GLIDE_TO_SECONDS = 1.5
local DEFAULT_PATH_SECONDS = 6

local DIGITS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local SUNK_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Q,
	Enum.KeyCode.E,
	Enum.KeyCode.Z,
	Enum.KeyCode.C,
	Enum.KeyCode.F,
	Enum.KeyCode.G,
	Enum.KeyCode.O,
	Enum.KeyCode.P,
	Enum.KeyCode.Space,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.LeftBracket,
	Enum.KeyCode.RightBracket,
	Enum.KeyCode.Backspace,
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local FilmCameraSystem = {}

function FilmCameraSystem.new(deps: Deps): FilmCameraSystem
	local marks = FilmMarkTracker.new()
	local active = false
	local token: number? = nil
	local held: { [Enum.KeyCode]: boolean } = {}
	local position = Vector3.zero
	local yaw, pitch = 0, 0
	local velocity = Vector3.zero
	local speed = 12
	local fov = 70
	local pathSeconds = DEFAULT_PATH_SECONDS
	-- A glide (to one mark, or through all of them), and what is followed.
	local glide: { path: FilmPathFormulas.Path, seconds: number, elapsed: number }? = nil
	local follow: Target? = nil
	local followIndex = 0
	local offset = Vector3.zero
	local orbiting = false
	local frame: RBXScriptConnection? = nil

	local function lookVector(): Vector3
		return (CFrame.fromOrientation(pitch, yaw, 0)).LookVector
	end

	local function current(): CFrame
		return CFrame.new(position) * CFrame.fromOrientation(pitch, yaw, 0)
	end

	local function setFromCFrame(cframe: CFrame)
		position = cframe.Position
		local look = cframe.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		pitch = math.asin(math.clamp(look.Y, -1, 1))
	end

	local function refresh()
		if not active then
			return
		end
		local parts = {
			"FILM CAM",
			`speed {math.round(speed)}`,
			`fov {math.round(fov)}`,
			`marks {marks:count()}`,
			`glide {pathSeconds} s`,
		}
		local target = follow
		if target ~= nil then
			table.insert(parts, (if orbiting then "orbit " else "follow ") .. target.name)
		end
		if glide ~= nil then
			table.insert(parts, "playing")
		end
		deps.setStatus(table.concat(parts, "   "))
	end

	local function startGlide(list: { FilmPathFormulas.Mark }, seconds: number)
		if #list == 0 then
			return
		end
		follow, orbiting = nil, false
		glide = { path = FilmPathFormulas.build(list), seconds = seconds, elapsed = 0 }
		velocity = Vector3.zero
		refresh()
	end

	local function here(): FilmPathFormulas.Mark
		return { position = position, look = lookVector(), fov = fov }
	end

	local function nextFollow()
		local list = deps.targets()
		if #list == 0 then
			follow = nil
			return
		end
		followIndex = followIndex % #list + 1
		local target = list[followIndex]
		follow = target
		glide = nil
		offset = position - target.part.Position
		refresh()
	end

	local function key(keyCode: Enum.KeyCode)
		local ctrl = held[Enum.KeyCode.LeftControl] or held[Enum.KeyCode.RightControl]
		local digit = DIGITS[keyCode]
		if digit ~= nil then
			if ctrl then
				marks:set(digit, here())
			else
				local mark = marks:get(digit)
				if mark ~= nil then
					startGlide({ here(), mark }, GLIDE_TO_SECONDS)
				end
			end
		elseif keyCode == Enum.KeyCode.P then
			if glide ~= nil then
				glide = nil
			else
				startGlide(marks:ordered(), pathSeconds)
			end
		elseif keyCode == Enum.KeyCode.LeftBracket then
			pathSeconds = math.max(1, pathSeconds - 1)
		elseif keyCode == Enum.KeyCode.RightBracket then
			pathSeconds = math.min(60, pathSeconds + 1)
		elseif keyCode == Enum.KeyCode.Backspace then
			marks:clear()
		elseif keyCode == Enum.KeyCode.F then
			nextFollow()
		elseif keyCode == Enum.KeyCode.O then
			orbiting = follow ~= nil and not orbiting
		elseif keyCode == Enum.KeyCode.G then
			follow, orbiting, glide = nil, false, nil
		end
		refresh()
	end

	local function axis(plus: Enum.KeyCode, minus: Enum.KeyCode): number
		return (if held[plus] then 1 else 0) - (if held[minus] then 1 else 0)
	end

	local function update(dt: number): (CFrame, number?)
		-- Zoom.
		local zoom = axis(Enum.KeyCode.C, Enum.KeyCode.Z)
		if zoom ~= 0 then
			fov = FilmFlyFormulas.fov(fov, zoom * ZOOM_RATE * dt)
		end
		local running = glide
		if running ~= nil then
			running.elapsed += dt
			local t = math.clamp(running.elapsed / running.seconds, 0, 1)
			local cframe, glideFov = FilmPathFormulas.sample(running.path, t)
			setFromCFrame(cframe)
			fov = glideFov
			if t >= 1 then
				glide = nil
				refresh()
			end
			return cframe, fov
		end
		-- Look (right mouse button held), unless locked on a target.
		if follow == nil and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			yaw, pitch = FilmFlyFormulas.look(yaw, pitch, UserInputService:GetMouseDelta(), LOOK_SENSITIVITY)
		end
		local slow = held[Enum.KeyCode.LeftShift] or held[Enum.KeyCode.RightShift]
		local input = Vector3.new(
			axis(Enum.KeyCode.D, Enum.KeyCode.A),
			axis(Enum.KeyCode.E, Enum.KeyCode.Q),
			axis(Enum.KeyCode.S, Enum.KeyCode.W)
		)
		local wanted = FilmFlyFormulas.wanted(current(), input, speed * (if slow then SLOW_FACTOR else 1))
		velocity = FilmFlyFormulas.approach(velocity, wanted, dt, FLY_SHARPNESS)
		local target = follow
		if target ~= nil and target.part.Parent ~= nil then
			offset += velocity * dt
			if orbiting then
				offset = FilmFlyFormulas.orbit(offset, ORBIT_DEGREES_PER_SECOND * dt)
			end
			local focus = target.part.Position
			position = focus + offset
			if (focus - position).Magnitude > 0.1 then
				setFromCFrame(CFrame.lookAt(position, focus))
			end
		else
			if target ~= nil then
				follow, orbiting = nil, false
				refresh()
			end
			position += velocity * dt
		end
		return current(), fov
	end

	local function onKeys(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		local keyCode = input.KeyCode
		if state == Enum.UserInputState.Begin then
			held[keyCode] = true
			key(keyCode)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			held[keyCode] = nil
		end
		return Enum.ContextActionResult.Sink
	end

	local function onWheel(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		if state == Enum.UserInputState.Change then
			speed = FilmFlyFormulas.speed(speed, math.sign(input.Position.Z))
			refresh()
		end
		return Enum.ContextActionResult.Sink
	end

	local system: FilmCameraSystem
	system = {
		toggle = function()
			if active then
				system.stop()
				return
			end
			active = true
			local camera = Workspace.CurrentCamera
			if camera ~= nil then
				setFromCFrame(camera.CFrame)
				fov = camera.FieldOfView
			end
			velocity = Vector3.zero
			glide, follow, orbiting = nil, nil, false
			table.clear(held)
			deps.silence(true)
			ContextActionService:BindActionAtPriority(
				SINK_ACTION,
				onKeys,
				false,
				SINK_PRIORITY,
				table.unpack(SUNK_KEYS)
			)
			ContextActionService:BindActionAtPriority(
				WHEEL_ACTION,
				onWheel,
				false,
				SINK_PRIORITY,
				Enum.UserInputType.MouseWheel
			)
			token = deps.pushMode(update)
			frame = RunService.RenderStepped:Connect(function()
				local looking = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
				UserInputService.MouseBehavior = if looking
					then Enum.MouseBehavior.LockCurrentPosition
					else Enum.MouseBehavior.Default
			end)
			refresh()
		end,

		isActive = function()
			return active
		end,

		stop = function()
			if not active then
				return
			end
			active = false
			ContextActionService:UnbindAction(SINK_ACTION)
			ContextActionService:UnbindAction(WHEEL_ACTION)
			local pushed = token
			if pushed ~= nil then
				deps.removeMode(pushed)
				token = nil
			end
			local connection = frame
			if connection ~= nil then
				connection:Disconnect()
				frame = nil
			end
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			deps.setStatus(nil)
			table.clear(held)
			deps.silence(false)
		end,
	}
	return system
end

return FilmCameraSystem
