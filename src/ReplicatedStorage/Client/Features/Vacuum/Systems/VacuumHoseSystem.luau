--!strict
--[=[
	VacuumHoseSystem: the live hose (vacuum feel pass batch 2, 2026-11-06; purely visual, on this machine only). While a
	holder's wand is out (the hose Beam's far end on the held Tool), its two curve sizes swing with the wand's move
	against the body (the inlet's velocity in root space, up and forward, on an underdamped spring so it overshoots)
	and wiggle while sucking (VacuumFeelFormulas.hose, tuned by VacuumMotionConstants.hose). The curve the server
	planned is read when the wand comes out and put back when this lets go of a hose still held; a stowed hose is the
	server's and is never touched. Stepped by VacuumMotionSystem for every holder.

	Spec-exempt shell (Beam, attachments); the maths is the specced VacuumFeelFormulas.hose and VacuumMotionFormulas.step.

	@class VacuumHoseSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)
local VacuumFeelFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeelFormulas)

local HOSE_NAME = "VacuumHose"

type Hose = {
	beam: Beam,
	inlet: Attachment,
	base0: number,
	base1: number,
	last: Vector3?,
	x: number,
	v: number,
	suck: number,
	seed: number,
}

local hoses: { [Model]: Hose } = {}

local VacuumHoseSystem = {}

-- `character`'s hose Beam with its far end on a held Tool, and that end; nil while stowed or missing.
local function heldHose(character: Model): (Beam?, Attachment?)
	local backpack = character:FindFirstChild(VacuumConstants.BACKPACK_NAME)
	local found = if backpack ~= nil then backpack:FindFirstChild(HOSE_NAME, true) else nil
	if found == nil or not found:IsA("Beam") then
		return nil, nil
	end
	local inlet = found.Attachment1
	if inlet == nil or inlet:FindFirstAncestorOfClass("Tool") == nil then
		return nil, nil
	end
	return found, inlet
end

local function letGo(character: Model, hose: Hose)
	-- Still held (this stopped, not the server): the server's curve back.
	if hose.beam.Attachment1 == hose.inlet then
		hose.beam.CurveSize0 = hose.base0
		hose.beam.CurveSize1 = hose.base1
	end
	hoses[character] = nil
end

--[=[
	Steps `character`'s hose for this frame: `root` its HumanoidRootPart, `active` whether it is sucking.
]=]
function VacuumHoseSystem.step(character: Model, root: BasePart?, active: boolean, dt: number, seed: number)
	local tuning = Constants.hose
	local current = hoses[character]
	local beam, inlet = heldHose(character)
	if not tuning.enabled or beam == nil or inlet == nil or root == nil then
		if current ~= nil then
			letGo(character, current)
		end
		return
	end
	if current == nil or current.beam ~= beam or current.inlet ~= inlet then
		if current ~= nil then
			letGo(character, current)
		end
		current = {
			beam = beam,
			inlet = inlet,
			base0 = beam.CurveSize0,
			base1 = beam.CurveSize1,
			last = nil,
			x = 0,
			v = 0,
			suck = 0,
			seed = seed,
		}
		hoses[character] = current
	end
	local hose: Hose = current
	local at = root.CFrame:PointToObjectSpace(inlet.WorldPosition)
	local last = hose.last
	local target = 0
	if last ~= nil then
		local velocity = (at - last) / dt
		-- Up and forward (root -Z) both throw the hose's curve out.
		target = math.clamp((velocity.Y - velocity.Z) * tuning.gain, -tuning.max, tuning.max)
	end
	hose.last = at
	hose.x, hose.v = VacuumMotionFormulas.step(hose.x, hose.v, target, dt, tuning.frequency, tuning.damping)
	hose.suck += ((if active then 1 else 0) - hose.suck) * (1 - math.exp(-dt / 0.15))
	beam.CurveSize0, beam.CurveSize1 =
		VacuumFeelFormulas.hose(hose.base0, hose.base1, hose.x, os.clock(), hose.seed, hose.suck, tuning)
end

--[=[
	Lets go of `character`'s hose (puts the server's curve back if it is still held).
]=]
function VacuumHoseSystem.forget(character: Model)
	local hose = hoses[character]
	if hose ~= nil then
		letGo(character, hose)
	end
end

function VacuumHoseSystem.forgetAll()
	for character, hose in hoses do
		letGo(character, hose)
	end
end

return VacuumHoseSystem
