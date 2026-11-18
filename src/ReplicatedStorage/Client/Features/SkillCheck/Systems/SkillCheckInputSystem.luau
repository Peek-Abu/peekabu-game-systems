--!strict
--[=[
	SkillCheckInputSystem: where this player's icon sits on the closing ring (an angle in screen degrees), from whatever
	they steer with, while a ring shows (`setRing` gives the ring's centre in screen px, inset-free like
	InputObject.Position, and its inner radius; nil: no ring, input ignored):

	- a free mouse: the pointer's angle round the ring's centre;
	- a mouse the camera has locked (MouseBehavior not Default): each mouse delta nudges a virtual cursor held to the
	  ring, so pushing sideways at the edge swings the icon round;
	- a gamepad: the right stick's direction (outside SkillCheckConstants.STICK_DEADZONE);
	- touch: any finger moving within SkillCheckConstants.TOUCH_REACH inner radii of the ring (the thumbstick and the
	  vacuum button stay out of reach).

	The angle holds where it was whenever nothing steers. The maths is the specced SkillCheckInputFormulas; this is the
	UserInputService shell (spec-exempt).

	@class SkillCheckInputSystem
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SkillCheckConstants = require(ReplicatedStorage.Shared.Features.SkillCheck.Data.SkillCheckConstants)
local SkillCheckAngleFormulas = require(ReplicatedStorage.Shared.Features.SkillCheck.Utils.SkillCheckAngleFormulas)
local SkillCheckInputFormulas = require(ReplicatedStorage.Client.Features.SkillCheck.Utils.SkillCheckInputFormulas)

-- Within this many px of the centre a pointer has no direction.
local DEAD_CENTRE = 4

local angle = 0
local centre: Vector2? = nil
local radius = 1
-- The virtual cursor for a locked mouse, relative to the ring's centre.
local cursor = Vector2.zero

local function setAngle(value: number?)
	if value ~= nil then
		angle = value
	end
end

-- The pointer's place in inset-free screen px (as InputObject.Position reports it).
local function pointer(): Vector2
	local inset = GuiService:GetGuiInset()
	return UserInputService:GetMouseLocation() - inset
end

local function onInput(input: InputObject)
	local at = centre
	if at == nil then
		return
	end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseMovement then
		if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
			setAngle(
				SkillCheckInputFormulas.fromPoint(Vector2.new(input.Position.X, input.Position.Y), at, DEAD_CENTRE)
			)
		else
			cursor = SkillCheckInputFormulas.nudge(cursor, Vector2.new(input.Delta.X, input.Delta.Y), radius)
			setAngle(SkillCheckInputFormulas.fromPoint(cursor, Vector2.zero, 1))
		end
	elseif kind == Enum.UserInputType.Touch then
		local point = Vector2.new(input.Position.X, input.Position.Y)
		if SkillCheckInputFormulas.withinReach(point, at, radius * SkillCheckConstants.TOUCH_REACH) then
			setAngle(SkillCheckInputFormulas.fromPoint(point, at, DEAD_CENTRE))
		end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		setAngle(
			SkillCheckInputFormulas.stick(
				Vector2.new(input.Position.X, input.Position.Y),
				SkillCheckConstants.STICK_DEADZONE
			)
		)
	end
end

local SkillCheckInputSystem = {}

--[=[
	Follows input; returns the stop.
]=]
function SkillCheckInputSystem.start(): () -> ()
	local changed = UserInputService.InputChanged:Connect(onInput)
	local began = UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			onInput(input)
		end
	end)
	return function()
		changed:Disconnect()
		began:Disconnect()
		centre = nil
	end
end

--[=[
	The ring now on screen: its centre (inset-free screen px) and inner radius (px); nil when none shows. A ring
	appearing starts the locked-mouse cursor at the icon's angle and, with a free mouse, takes the pointer's angle now.
]=]
function SkillCheckInputSystem.setRing(at: Vector2?, innerRadius: number)
	local appeared = centre == nil and at ~= nil
	centre = at
	radius = math.max(innerRadius, 1)
	if at ~= nil and appeared then
		cursor = SkillCheckAngleFormulas.toVector(angle) * radius
		if UserInputService.MouseEnabled and UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
			setAngle(SkillCheckInputFormulas.fromPoint(pointer(), at, DEAD_CENTRE))
		end
	end
end

--[=[
	The icon's angle now (screen degrees).
]=]
function SkillCheckInputSystem.angle(): number
	return angle
end

return SkillCheckInputSystem
