--!strict
--[=[
	OccupantGestureSystem: the Manager's procedural gestures on this client (docs/superpowers/specs/2026-10-15-cleanup-
	crew-manager-behaviours-design.md §1–§3, §6): his head swivelling to an ambush point, bending down to look under a
	spot, tipping upside down under the desk he sits at, and the catch's head tilt. The server publishes which gesture
	(OccupantConstants.GESTURE_ATTRIBUTE), the swivel's point and the tilt on his model; every step
	(RunService.PreSimulation, the slot the engine documents for overriding Motor6D.Transform) this lays the gesture's
	offsets (OccupantGestureFormulas) over whatever his clips put on his Neck and Waist, easing from the last pose to
	the new one. A keyed gesture (the check, the sit-in) follows its path instead, drawing his whole body back on the
	Root joint (scaled to the room behind him) and, seated, his chair with it; leaving one plays its exit path back to
	rest first (OccupantClearanceSystem: the room, the chair, the hider's fade). Visual only: the server's own copy of
	him never bends.

	Spec-exempt shell (Motor6Ds, RunService); the poses and their easing are the specced OccupantGestureFormulas.

	@class OccupantGestureSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantGestureFormulas = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantGestureFormulas)
local OccupantClearanceSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantClearanceSystem)

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
	-- Leaving a keyed gesture: its exit path, from where, since when and for how long.
	exit: Exit?,
	-- The share of a keyed path's draw-back that fits behind him (OccupantClearanceSystem.reach).
	reach: number,
}

type Exit = {
	gesture: string,
	keys: { OccupantConstants.GestureKey },
	start: OccupantGestureFormulas.Waypoint,
	since: number,
	seconds: number,
}

export type OccupantGestureState = { bodies: number, joints: number, written: number, gestures: { [string]: number } }

local POSED = { "Neck", "Waist", "Root" }
-- The joint the draw-back moves (his whole body, along his root's back), laid before the clip's own root motion.
local ROOT = "Root"
-- The gestures he makes seated: his chair goes back and forth with the draw-back.
local SEATED: { [string]: boolean } = { under = true }

local bodies: { [Model]: Body } = {}
local connection: RBXScriptConnection? = nil
local guarding: RBXScriptConnection? = nil
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
		exit = nil,
		reach = 1,
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
			local exitKeys, exitSeconds, exitStart = OccupantGestureFormulas.exit(body.gesture)
			if exitKeys ~= nil and body.exit == nil then
				body.exit =
					{ gesture = body.gesture, keys = exitKeys, start = exitStart, since = now, seconds = exitSeconds }
			end
			local keys = OccupantGestureFormulas.keyed(gesture)
			if keys ~= nil then
				local deepest = 0
				for _, key in keys do
					deepest = math.max(deepest, key.back)
				end
				body.reach = OccupantClearanceSystem.reach(instance, deepest)
			end
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
		local shown: Offsets
		local back = 0
		local seated = SEATED[gesture] == true
		local exit = body.exit
		local keys, seconds = OccupantGestureFormulas.keyed(gesture)
		if exit ~= nil and now - exit.since < exit.seconds then
			-- Out of a keyed gesture the way it went in, before whatever comes next.
			shown, back = OccupantGestureFormulas.along(exit.keys, (now - exit.since) / exit.seconds, exit.start)
			seated = SEATED[exit.gesture] == true
		else
			if exit ~= nil then
				body.exit = nil
				body.from = {}
				body.since = math.max(body.since, exit.since + exit.seconds)
			end
			if keys ~= nil then
				shown, back = OccupantGestureFormulas.along(keys, (now - body.since) / seconds)
			else
				local pose = OccupantGestureFormulas.pose(gesture, yaw)
				local progress = OccupantGestureFormulas.progress(gesture, now - body.since)
				shown = OccupantGestureFormulas.blend(body.from, pose, progress)
			end
		end
		back *= body.reach
		body.shown = shown
		OccupantClearanceSystem.carry(instance, if seated then back else 0)
		local tiltSince = body.tiltSince
		for name, motor in body.joints do
			local root = name == ROOT
			local offset = if root then CFrame.new(0, 0, back) else shown[name] or CFrame.identity
			if name == "Neck" and tiltSince ~= nil then
				offset = offset * OccupantGestureFormulas.tilt(now - tiltSince, true)
			end
			local current = motor.Transform
			local last = body.written[motor]
			local base = current
			if last ~= nil and current == last.value then
				base = if root then last.offset:Inverse() * last.value else last.value * last.offset:Inverse()
			end
			-- The draw-back goes before the clip's root motion (along his root's back), the bends after theirs.
			local posed = if root then offset * base else base * offset
			motor.Transform = posed
			body.written[motor] = { value = posed, offset = offset }
		end
	end
end

-- After the step: the hider's fade, from where his body actually is now.
local function guard()
	local model: Model? = nil
	local gesturing = false
	for _, body in bodies do
		if body.exit ~= nil or OccupantGestureFormulas.keyed(body.gesture) ~= nil then
			model = body.model
			gesturing = true
		end
	end
	OccupantClearanceSystem.guard(model, gesturing)
end

local OccupantGestureSystem = {}

function OccupantGestureSystem.start()
	if connection ~= nil then
		return
	end
	connection = RunService.PreSimulation:Connect(step)
	guarding = RunService.PostSimulation:Connect(guard)
end

function OccupantGestureSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	local watching = guarding
	if watching ~= nil then
		watching:Disconnect()
		guarding = nil
	end
	OccupantClearanceSystem.reset()
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
