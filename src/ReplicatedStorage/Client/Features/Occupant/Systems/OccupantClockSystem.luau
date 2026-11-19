--!strict
--[=[
	OccupantClockSystem: spins the Manager's clock-head hands on this client (owner pick S1, 2026-11-18: the hands spin
	while he hunts and on the catch). Every step (RunService.PreSimulation, the slot the engine documents for
	overriding Motor6D.Transform) it reads each occupant's mode and the face his mask shows, winds his clock
	(OccupantClockFormulas) and turns each hand's Motor6D (OccupantAssets.CLOCK_HANDS) about the clock's centre. No clip
	keys those joints, so nothing else writes them. A rig without the hand joints (the fallback body, a perch kind) is
	skipped. Visual only: every client winds its own copy; the server's never turns.

	Spec-exempt shell (Motor6Ds, RunService); the winding is the specced OccupantClockFormulas.

	@class OccupantClockSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantClockFormulas = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantClockFormulas)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

type Hands = { minute: Motor6D, hour: Motor6D, clock: OccupantClockFormulas.Clock }

local hands: { [Model]: Hands } = {}
local connection: RBXScriptConnection? = nil
local spun = 0

local function motorIn(model: Model, name: string): Motor6D?
	local found = model:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("Motor6D") then found else nil
end

local function handsOf(model: Model): Hands?
	local known = hands[model]
	if known ~= nil and known.minute.Parent ~= nil and known.hour.Parent ~= nil then
		return known
	end
	local minute = motorIn(model, OccupantAssets.CLOCK_HANDS.minute)
	local hour = motorIn(model, OccupantAssets.CLOCK_HANDS.hour)
	if minute == nil or hour == nil then
		hands[model] = nil
		return nil
	end
	local found: Hands = { minute = minute, hour = hour, clock = OccupantClockFormulas.REST }
	hands[model] = found
	return found
end

local function faceOf(model: Model): string?
	local plate = model:FindFirstChild(OccupantAssets.FACE_PLATE)
	local appearance = if plate ~= nil then plate:FindFirstChild(OccupantAssets.FACE_APPEARANCE) else nil
	local face = if appearance ~= nil then appearance:GetAttribute(OccupantAssets.FACE_ATTRIBUTE) else nil
	return if type(face) == "string" then face else nil
end

-- A clockwise turn (seen from the front) of `degrees`: each hand joint's frames face out of the clock (+Z toward the
-- viewer, OccupantAssets.CLOCK_HANDS), so clockwise is a negative turn about Z.
local function turn(degrees: number): CFrame
	return CFrame.Angles(0, 0, -math.rad(degrees))
end

local function step(dt: number)
	for model in hands do
		if model.Parent == nil then
			hands[model] = nil
		end
	end
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		if not instance:IsA("Model") then
			continue
		end
		local found = handsOf(instance)
		if found == nil then
			continue
		end
		local value = instance:GetAttribute(OccupantConstants.MODE_ATTRIBUTE)
		local mode = if type(value) == "string" then value else ""
		local target = OccupantClockFormulas.targetSpeed(mode, faceOf(instance))
		local clock = OccupantClockFormulas.step(found.clock, target, dt)
		if clock.turns ~= found.clock.turns then
			spun += 1
		end
		found.clock = clock
		local minute, hour = OccupantClockFormulas.angles(clock)
		found.minute.Transform = turn(minute)
		found.hour.Transform = turn(hour)
	end
end

local OccupantClockSystem = {}

function OccupantClockSystem.start()
	if connection ~= nil then
		return
	end
	connection = RunService.PreSimulation:Connect(step)
end

function OccupantClockSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	table.clear(hands)
end

function OccupantClockSystem.getState(): { clocks: number, spun: number }
	local count = 0
	for _ in hands do
		count += 1
	end
	return { clocks = count, spun = spun }
end

return OccupantClockSystem
