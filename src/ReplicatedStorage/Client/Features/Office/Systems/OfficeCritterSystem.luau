--!strict
--[=[
	OfficeCritterSystem: the yard's critters on this client (yard design doc §4, Y4: harmless dressing, never a
	threat; the outside stays a safe zone). Critters are Models the builder places, tagged
	OfficeCritterConstants.TAG with their kind (cat, crow, raccoon) and the way they run off. Each idles in place
	(a small turn now and then); when any player comes within its kind's `near`, it flees on this client only: the cat
	hops off its perch, lands FleeDrop lower and runs; the crow flies up and away; the raccoon ducks into its bin.
	Then it is hidden (LocalTransparencyModifier, so the place's own Transparency is never touched) and comes back
	where it was built after its `returnAfter`, once nobody is within RETURN_CLEAR, so no one sees it pop in.

	Streaming is on: critters are tracked by the tag's added/removed signals; one that arrives before its parts is
	picked up when they stream in, and one streaming out is put back and forgotten.

	The phase rule (nextPhase) and the flee paths (fleePose) are pure and specced with stepCritter; the shell reads
	players' positions and drives it every frame.

	@class OfficeCritterSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeCritterConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeCritterConstants)

export type Phase = "idle" | "flee" | "gone"

export type OfficeCritterState = {
	critters: number,
	idle: number,
	fleeing: number,
	gone: number,
}

type Critter = {
	kind: OfficeCritterConstants.CritterKind,
	home: CFrame,
	dir: Vector3,
	drop: number,
	phase: Phase,
	since: number,
	nearest: number,
	-- Per-critter offset so a row of crows does not turn in step.
	seed: number,
}

local critters: { [Model]: Critter } = {}
local pending: { [Model]: RBXScriptConnection } = {}
local connections: { RBXScriptConnection } = {}
local lastSense = -math.huge

local OfficeCritterSystem = {}

-- The kinds a model's attribute may name (anything else is not a critter).
local KIND_NAMES: { [string]: OfficeCritterConstants.CritterKind } = {
	cat = "cat",
	crow = "crow",
	raccoon = "raccoon",
}

local function kindOf(model: Model): OfficeCritterConstants.CritterKind?
	local kind = model:GetAttribute(OfficeCritterConstants.KIND_ATTRIBUTE)
	return if typeof(kind) == "string" then KIND_NAMES[kind] else nil
end

local function hasPart(model: Model): boolean
	return model:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function setHidden(model: Model, hidden: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- The horizontal run-off direction: the model's attribute, else straight back from where it faces.
local function fleeDirection(model: Model, home: CFrame): Vector3
	local raw = model:GetAttribute(OfficeCritterConstants.DIRECTION_ATTRIBUTE)
	local v = if typeof(raw) == "Vector3" then raw else -home.LookVector
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 1e-6 then
		return Vector3.new(1, 0, 0)
	end
	return flat.Unit
end

--[=[
	The phase after `elapsed` seconds in `phase`, with the nearest player `nearest` studs away (math.huge: none).
]=]
function OfficeCritterSystem.nextPhase(
	kind: OfficeCritterConstants.CritterKind,
	phase: Phase,
	elapsed: number,
	nearest: number
): Phase
	local tuning = OfficeCritterConstants.KINDS[kind]
	if phase == "idle" then
		if nearest < tuning.near then
			return "flee"
		end
		return "idle"
	elseif phase == "flee" then
		if elapsed >= tuning.fleeTime then
			return "gone"
		end
		return "flee"
	end
	if elapsed >= tuning.returnAfter and nearest > OfficeCritterConstants.RETURN_CLEAR then
		return "idle"
	end
	return "gone"
end

--[=[
	Where a fleeing critter is `t` seconds into its flee from `home`, running along the horizontal unit `dir`, with
	the ground `drop` studs below its perch (the cat).
]=]
function OfficeCritterSystem.fleePose(
	kind: OfficeCritterConstants.CritterKind,
	home: CFrame,
	dir: Vector3,
	drop: number,
	t: number
): CFrame
	local tuning = OfficeCritterConstants.KINDS[kind]
	local at = home.Position
	if kind == "raccoon" then
		local s = math.clamp(t / tuning.fleeTime, 0, 1)
		return home - Vector3.new(0, tuning.duck * s, 0)
	elseif kind == "cat" then
		local height: number
		if t < tuning.hopTime then
			local s = t / tuning.hopTime
			height = tuning.hopHeight * math.sin(math.pi * s) - drop * s * s
		else
			height = -drop
		end
		local pos = at + dir * (tuning.speed * t) + Vector3.new(0, height, 0)
		return if t > 0 then CFrame.lookAt(pos, pos + dir) else home
	end
	local pos = at + dir * (tuning.speed * t) + Vector3.new(0, tuning.climb * t, 0)
	return if t > 0 then CFrame.lookAt(pos, pos + dir) else home
end

-- The idle turn at `now`: holds a small yaw, easing to a new one each idleTurnEvery s.
local function idleYaw(critter: Critter, now: number): number
	local tuning = OfficeCritterConstants.KINDS[critter.kind]
	if tuning.idleTurnDegrees <= 0 or tuning.idleTurnEvery <= 0 then
		return 0
	end
	local span = now / tuning.idleTurnEvery + critter.seed
	local index = math.floor(span)
	local target = function(i: number): number
		return math.noise(i * 0.618, critter.seed) * 2 * math.rad(tuning.idleTurnDegrees)
	end
	local ease = math.clamp((span - index) * tuning.idleTurnEvery / 0.4, 0, 1)
	return target(index - 1) + (target(index) - target(index - 1)) * ease
end

--[=[
	Starts tracking a critter at the pose it was built in. Ignored for an unknown kind; a Model with no parts yet
	(streaming) is picked up when its first part arrives.
]=]
function OfficeCritterSystem.addCritter(model: Model)
	if critters[model] or pending[model] then
		return
	end
	local kind: OfficeCritterConstants.CritterKind? = kindOf(model)
	if not kind then
		return
	end
	if not hasPart(model) then
		pending[model] = model.DescendantAdded:Connect(function(added: Instance)
			if added:IsA("BasePart") then
				local connection = pending[model]
				if connection then
					connection:Disconnect()
				end
				pending[model] = nil
				OfficeCritterSystem.addCritter(model)
			end
		end)
		return
	end
	local home = model:GetPivot()
	local drop = model:GetAttribute(OfficeCritterConstants.DROP_ATTRIBUTE)
	local critter: Critter = {
		kind = kind,
		home = home,
		dir = fleeDirection(model, home),
		drop = if typeof(drop) == "number" then math.max(drop, 0) else 0,
		phase = "idle",
		since = 0,
		nearest = math.huge,
		seed = (home.Position.X * 0.37 + home.Position.Z * 0.61) % 7,
	}
	critters[model] = critter
end

--[=[
	Stops tracking a critter and puts it back exactly where it was built, shown.
]=]
function OfficeCritterSystem.removeCritter(model: Model)
	local connection = pending[model]
	if connection then
		connection:Disconnect()
		pending[model] = nil
	end
	local critter = critters[model]
	if critter == nil then
		return
	end
	critters[model] = nil
	if model.Parent ~= nil and hasPart(model) then
		model:PivotTo(critter.home)
		setHidden(model, false)
	end
end

function OfficeCritterSystem.phaseOf(model: Model): Phase?
	local critter = critters[model]
	return if critter then critter.phase else nil
end

--[=[
	Advances one critter to `now` with the nearest player `nearest` studs away, and poses it.
]=]
function OfficeCritterSystem.stepCritter(model: Model, now: number, nearest: number)
	local critter = critters[model]
	if critter == nil then
		return
	end
	critter.nearest = nearest
	local was: Phase = critter.phase
	local phase: Phase = OfficeCritterSystem.nextPhase(critter.kind, was, now - critter.since, nearest)
	local changed = phase ~= was
	if changed then
		critter.phase = phase
		critter.since = now
		if phase == "gone" then
			setHidden(model, true)
		elseif was == "gone" then
			setHidden(model, false)
		end
	end
	if phase == "idle" then
		model:PivotTo(critter.home * CFrame.Angles(0, idleYaw(critter, now), 0))
	elseif phase == "flee" then
		model:PivotTo(
			OfficeCritterSystem.fleePose(critter.kind, critter.home, critter.dir, critter.drop, now - critter.since)
		)
	end
end

-- The distance from `at` to the nearest player's character, or math.huge with none.
local function nearestPlayer(at: Vector3): number
	local best = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			best = math.min(best, (root.Position - at).Magnitude)
		end
	end
	return best
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local sense = now - lastSense >= OfficeCritterConstants.SENSE_EVERY
	if sense then
		lastSense = now
	end
	for model, critter in critters do
		local nearest = if sense then nearestPlayer(critter.home.Position) else critter.nearest
		OfficeCritterSystem.stepCritter(model, now, nearest)
	end
end

local function track(instance: Instance)
	if instance:IsA("Model") then
		OfficeCritterSystem.addCritter(instance)
	end
end

local function untrack(instance: Instance)
	if instance:IsA("Model") then
		OfficeCritterSystem.removeCritter(instance)
	end
end

function OfficeCritterSystem.start()
	if #connections > 0 then
		return
	end
	for _, instance in CollectionService:GetTagged(OfficeCritterConstants.TAG) do
		track(instance)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(OfficeCritterConstants.TAG):Connect(track))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(OfficeCritterConstants.TAG):Connect(untrack))
	table.insert(connections, RunService.Heartbeat:Connect(step))
end

function OfficeCritterSystem.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	local models: { Model } = {}
	for model in critters do
		table.insert(models, model)
	end
	for model in pending do
		table.insert(models, model)
	end
	for _, model in models do
		OfficeCritterSystem.removeCritter(model)
	end
	lastSense = -math.huge
end

function OfficeCritterSystem.getState(): OfficeCritterState
	local state: OfficeCritterState = { critters = 0, idle = 0, fleeing = 0, gone = 0 }
	for _, critter in critters do
		state.critters += 1
		if critter.phase == "idle" then
			state.idle += 1
		elseif critter.phase == "flee" then
			state.fleeing += 1
		else
			state.gone += 1
		end
	end
	return state
end

return OfficeCritterSystem
