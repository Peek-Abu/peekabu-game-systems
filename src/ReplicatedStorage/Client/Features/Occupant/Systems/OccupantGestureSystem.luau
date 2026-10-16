--!strict
--[=[
	OccupantGestureSystem: the Manager's procedural gestures on this client (docs/superpowers/specs/2026-10-15-cleanup-
	crew-manager-behaviours-design.md §1–§3, §6): his head swivelling to an ambush point, bending down to look under a
	spot, tipping upside down under the desk he sits at, and the catch's head tilt. The server publishes which gesture
	(OccupantConstants.GESTURE_ATTRIBUTE), the swivel's point and the tilt on his model; every step
	(RunService.PreSimulation, the slot the engine documents for overriding Motor6D.Transform) this lays the gesture's
	offsets (OccupantGestureFormulas) over whatever his clips put on his Neck and Waist, easing from the last pose to
	the new one. Visual only: the server's own copy of him never bends.

	Spec-exempt shell (Motor6Ds, RunService); the poses and their easing are the specced OccupantGestureFormulas.

	@class OccupantGestureSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantGestureFormulas = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantGestureFormulas)

type Offsets = OccupantGestureFormulas.Offsets

type Body = {
	model: Model,
	torso: BasePart?,
	joints: { [string]: Motor6D },
	complete: boolean,
	gesture: string,
	since: number,
	-- The offsets shown when the gesture changed (the blend starts from them), and the last ones shown.
	from: Offsets,
	shown: Offsets,
	tiltSince: number?,
	-- What this wrote on each joint last step, and the offset in it: a joint no clip rewrote since must not stack.
	written: { [Motor6D]: { value: CFrame, offset: CFrame } },
}

export type OccupantGestureState = { bodies: number, joints: number, written: number, gestures: { [string]: number } }

local POSED = { "Neck", "Waist" }

local bodies: { [Model]: Body } = {}
local connection: RBXScriptConnection? = nil
local counters: { [string]: number } = {}

-- Finds his posed joints and his torso (again until all have streamed in: a model arrives part by part).
local function scan(body: Body)
	local joints: { [string]: Motor6D } = {}
	local found = 0
	for _, item in body.model:GetDescendants() do
		if item:IsA("Motor6D") and table.find(POSED, item.Name) ~= nil then
			joints[item.Name] = item
			found += 1
		end
	end
	body.joints = joints
	body.complete = found >= #POSED
	local torso = body.model:FindFirstChild("UpperTorso")
	body.torso = if torso ~= nil and torso:IsA("BasePart") then torso else nil
end

local function bodyOf(model: Model): Body
	local existing = bodies[model]
	if existing ~= nil then
		if not existing.complete or existing.torso == nil then
			scan(existing)
		end
		return existing
	end
	local body: Body = {
		model = model,
		torso = nil,
		joints = {},
		complete = false,
		gesture = "",
		since = os.clock(),
		from = {},
		shown = {},
		tiltSince = nil,
		written = {},
	}
	scan(body)
	bodies[model] = body
	return body
end

local function step()
	local now = os.clock()
	for model in bodies do
		if model.Parent == nil then
			bodies[model] = nil
		end
	end
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		if not instance:IsA("Model") then
			continue
		end
		local body = bodyOf(instance)
		local value = instance:GetAttribute(OccupantConstants.GESTURE_ATTRIBUTE)
		local gesture = if type(value) == "string" then value else ""
		if gesture ~= body.gesture then
			body.from = body.shown
			body.gesture = gesture
			body.since = now
			counters[gesture] = (counters[gesture] or 0) + 1
		end
		local tilting = instance:GetAttribute(OccupantConstants.TILT_ATTRIBUTE) == true
		if tilting and body.tiltSince == nil then
			body.tiltSince = now
		elseif not tilting then
			body.tiltSince = nil
		end
		local yaw = 0
		local target = instance:GetAttribute(OccupantConstants.GESTURE_TARGET_ATTRIBUTE)
		local torso = body.torso
		if gesture == "swivel" and typeof(target) == "Vector3" and torso ~= nil then
			yaw = OccupantGestureFormulas.yawTo(torso.CFrame, target)
		end
		local pose = OccupantGestureFormulas.pose(gesture, yaw)
		local shown =
			OccupantGestureFormulas.blend(body.from, pose, OccupantGestureFormulas.progress(gesture, now - body.since))
		body.shown = shown
		local tiltSince = body.tiltSince
		for name, motor in body.joints do
			local offset = shown[name] or CFrame.identity
			if name == "Neck" and tiltSince ~= nil then
				offset = offset * OccupantGestureFormulas.tilt(now - tiltSince, true)
			end
			local current = motor.Transform
			local last = body.written[motor]
			local base = if last ~= nil and current == last.value then last.value * last.offset:Inverse() else current
			local posed = base * offset
			motor.Transform = posed
			body.written[motor] = { value = posed, offset = offset }
		end
	end
end

local OccupantGestureSystem = {}

function OccupantGestureSystem.start()
	if connection ~= nil then
		return
	end
	connection = RunService.PreSimulation:Connect(step)
end

function OccupantGestureSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	table.clear(bodies)
end

function OccupantGestureSystem.getState(): OccupantGestureState
	local count, joints, written = 0, 0, 0
	for _, body in bodies do
		count += 1
		for _ in body.joints do
			joints += 1
		end
		for _ in body.written do
			written += 1
		end
	end
	return { bodies = count, joints = joints, written = written, gestures = table.clone(counters) }
end

return OccupantGestureSystem
