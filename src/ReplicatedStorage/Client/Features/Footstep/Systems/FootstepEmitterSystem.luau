--!strict
--[=[
	FootstepEmitterSystem: one character's footsteps on this client, from its own feet. Every frame each foot's height
	(the foot part's centre minus the HumanoidRootPart's, read from the pose the Animator gave it this frame; not its
	lowest corner, which dips below the stance as the foot rolls heel to toe) goes through
	FootstepPlantFormulas; on the frame a foot lands, and only while the character is moving on the ground (its root
	really crossing the floor, a floor under it, alive, not seated), it plays one variant of its set's pool for the
	surface under it (FootstepSurfaceUtils), scaled by its gait (FootstepGaitFormulas), 3D on that foot.

	Works for any rig whose Animator this client sees: a player's own character, another player's (the engine
	replicates the tracks its owner plays) and a server NPC (the server's tracks replicate the same way), so the steps
	follow whatever clip, speed and stride the feet actually show.

	Spec-exempt shell (Instances, raycasts, Sound); the decisions are the specced FootstepPlantFormulas,
	FootstepGaitFormulas and FootstepSurfaceUtils.

	@class FootstepEmitterSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FootstepAssets = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepAssets)
local FootstepConstants = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepConstants)
local FootstepTypes = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepTypes)
local FootstepGaitFormulas = require(ReplicatedStorage.Client.Features.Footstep.Utils.FootstepGaitFormulas)
local FootstepPlantFormulas = require(ReplicatedStorage.Client.Features.Footstep.Utils.FootstepPlantFormulas)
local FootstepSurfaceUtils = require(ReplicatedStorage.Client.Features.Footstep.Utils.FootstepSurfaceUtils)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

type Gait = FootstepTypes.Gait
type Surface = FootstepTypes.Surface

-- The foot parts of an R15 rig, else an R6 one.
local FOOT_NAMES: { { string } } = { { "LeftFoot", "RightFoot" }, { "Left Leg", "Right Leg" } }

type FootTrack = {
	part: BasePart,
	foot: FootstepPlantFormulas.Foot?,
	-- The variant this foot played last (never twice in a row).
	last: number?,
}

export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	setName: string,
	set: FootstepTypes.FootstepSet,
	gaitInput: () -> FootstepGaitFormulas.GaitInput,
	feet: { FootTrack },
	lastRoot: Vector3?,
	speed: number,
}

export type StepRecord = {
	at: number,
	model: string,
	set: string,
	foot: string,
	gait: Gait,
	surface: Surface,
	speed: number,
	volume: number,
}

export type Counters = {
	steps: number,
	gated: number,
	silent: number,
}

local rng = Random.new()

local function feetOf(model: Model): { FootTrack }?
	for _, names in FOOT_NAMES do
		local left = model:FindFirstChild(names[1])
		local right = model:FindFirstChild(names[2])
		if left ~= nil and left:IsA("BasePart") and right ~= nil and right:IsA("BasePart") then
			return { { part = left }, { part = right } }
		end
	end
	return nil
end

-- The floor under the rig and its surface; nil when nothing is under it (airborne).
local function floorUnder(rig: Rig): Surface?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rig.model }
	local reach = rig.humanoid.HipHeight + rig.root.Size.Y / 2 + FootstepConstants.GROUND_SLACK
	local hit = Workspace:Raycast(rig.root.Position, Vector3.new(0, -reach, 0), params)
	if hit == nil then
		return nil
	end
	local floor: Instance? = hit.Instance
	local override: unknown = nil
	while floor ~= nil and floor ~= Workspace do
		override = floor:GetAttribute(FootstepConstants.SURFACE_ATTRIBUTE)
		if override ~= nil then
			break
		end
		floor = floor.Parent
	end
	return FootstepSurfaceUtils.surfaceFor(hit.Material, override)
end

local FootstepEmitterSystem = {}

--[=[
	A rig for `model` playing `setName` (a FootstepAssets set), its gait read from `gaitInput` at each step; nil when
	the model has no Humanoid, root or feet yet, or the set is unknown.
]=]
function FootstepEmitterSystem.new(model: Model, setName: string, gaitInput: () -> FootstepGaitFormulas.GaitInput): Rig?
	local set = FootstepAssets.SETS[setName]
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local feet = feetOf(model)
	if set == nil or humanoid == nil or root == nil or not root:IsA("BasePart") or feet == nil then
		return nil
	end
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		setName = setName,
		set = set,
		gaitInput = gaitInput,
		feet = feet,
		lastRoot = nil,
		speed = 0,
	}
end

--[=[
	Forgets the rig's feet and speed (it left the sampled range, or respawned its pose): the next frame starts fresh.
]=]
function FootstepEmitterSystem.reset(rig: Rig)
	rig.lastRoot = nil
	rig.speed = 0
	for _, track in rig.feet do
		track.foot = nil
	end
end

--[=[
	One frame for `rig`: samples its feet and plays a step for each that lands while it moves on the ground.
	@return { StepRecord } -- the steps played this frame
]=]
function FootstepEmitterSystem.update(rig: Rig, dt: number, counters: Counters): { StepRecord }
	local played: { StepRecord } = {}
	if dt <= 0 then
		return played
	end
	local position = rig.root.Position
	local previous = rig.lastRoot
	rig.lastRoot = position
	if previous ~= nil then
		local flat = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z).Magnitude
		if flat < FootstepConstants.TELEPORT then
			local alpha = 1 - math.exp(-dt / FootstepConstants.SPEED_SMOOTHING)
			rig.speed += (flat / dt - rig.speed) * alpha
		end
	end

	local scale = math.max(rig.humanoid.HipHeight, 0.5)
	local landed: { FootTrack } = {}
	for _, track in rig.feet do
		local height = track.part.Position.Y - position.Y
		local foot = track.foot
		if foot == nil then
			track.foot = FootstepPlantFormulas.fresh(height)
		elseif FootstepPlantFormulas.step(foot, height, dt, scale) then
			table.insert(landed, track)
		end
	end
	if #landed == 0 then
		return played
	end

	local humanoid = rig.humanoid
	if rig.speed < FootstepConstants.MOVING_SPEED or humanoid.Health <= 0 or humanoid.Sit or rig.root.Anchored then
		counters.gated += #landed
		return played
	end
	local surface: Surface? = floorUnder(rig)
	if surface == nil then
		counters.gated += #landed
		return played
	end
	local gait: Gait = FootstepGaitFormulas.gaitFor(rig.gaitInput())
	local gaitScale = FootstepGaitFormulas.scale(rig.set, gait, rig.speed)
	if gaitScale.volume <= 0 then
		counters.silent += #landed
		return played
	end
	local pool = FootstepSurfaceUtils.poolFor(FootstepAssets.SOUND_IDS[rig.setName], surface)
	for _, track in landed do
		local index = FootstepSurfaceUtils.pick(#pool, rng:NextNumber(), track.last)
		if index == nil then
			continue
		end
		track.last = index
		SoundServiceClient:play(
			pool[index],
			{ at = track.part, volumeScale = gaitScale.volume, pitchScale = gaitScale.pitch }
		)
		counters.steps += 1
		local record: StepRecord = {
			at = os.clock(),
			model = rig.model.Name,
			set = rig.setName,
			foot = track.part.Name,
			gait = gait,
			surface = surface,
			speed = rig.speed,
			volume = gaitScale.volume,
		}
		table.insert(played, record)
	end
	return played
end

return FootstepEmitterSystem
