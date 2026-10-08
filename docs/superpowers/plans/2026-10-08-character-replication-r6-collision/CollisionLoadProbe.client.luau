--!strict
--[=[
	CollisionLoadProbe — THROWAWAY end-check probe for R6 (spec 2026-10-08 §6, plan Task 6). Never shipped:
	it lives with the plan, not in src/.

	Run it as a LocalScript in a Studio Play session (the controller inserts it under the local player's
	PlayerScripts). It builds COUNT puppets the way ReplicationPuppetPool does (template clone, scripts out,
	no collision, anchored root), moves them with ONE BulkMoveTo per PreRender around where the local root
	stood at start, and runs every scene with collision OFF and ON, ROUNDS times each. The player must stand
	still while it runs (about 2 minutes). It waits for the character to land before taking the ring centre.

	It drives a PRIVATE CollisionBlockerSystem state with the SAME two steps CollisionServiceClient runs, so
	the live service's own state is untouched. Each result prints one line starting with "R6PROBE".

	Measured per window: Stats.PhysicsStepTimeMs and Stats.HeartbeatTimeMs (frame averages), the probe's own
	timing of the collision step (ms per frame), and solid/not-solid flips per second.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local CollisionBlockerSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionBlockerSystem)
local CollisionSlideOffSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionSlideOffSystem)

local COUNT = 30
local NEAR = 8
local WARMUP_SECONDS = 2
local MEASURE_SECONDS = 6
local ROUNDS = 2
local SCENES = { "busy", "jitter", "sweep", "idle" }

local function localRoot(): BasePart
	while true do
		local character = Players.LocalPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			return root
		end
		task.wait(0.2)
	end
end

local templateInstance = ReplicatedStorage:WaitForChild("CharacterRigTemplate")
assert(templateInstance:IsA("Model"), "CharacterRigTemplate is not a Model")
local template: Model = templateInstance

local folder = Instance.new("Folder")
folder.Name = "R6ProbePuppets"
folder.Parent = Workspace

local models: { Model } = {}
local roots: { BasePart } = {}
for _ = 1, COUNT do
	local model = template:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.EvaluateStateMachine = false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(root ~= nil and root:IsA("BasePart"), "template has no HumanoidRootPart")
	root.Anchored = true
	model.Parent = folder
	table.insert(models, model)
	table.insert(roots, root)
end

local me = localRoot()
-- Take the ring centre only after the character has landed: a late vertical drop pushes ring puppets out of range.
local SETTLE_SECONDS = 1
local SETTLE_CAP_SECONDS = 15
local settleBegan = os.clock()
local stillSince = -1 -- when vertical velocity went under the threshold; -1 while moving
while os.clock() - settleBegan < SETTLE_CAP_SECONDS do
	if math.abs(me.AssemblyLinearVelocity.Y) < 0.05 then
		if stillSince < 0 then
			stillSince = os.clock()
		end
		if os.clock() - stillSince >= SETTLE_SECONDS then
			break
		end
	else
		stillSince = -1
	end
	task.wait(0.1)
end
local centre = me.Position
local scene = "idle"
local started = os.clock()
local phaseStarted = os.clock() -- start of the current measure() phase

local function radiusFor(index: number, t: number): number
	if scene == "busy" then
		return if index <= NEAR then 6 + (index - 1) * 1.5 else 30 + index
	elseif scene == "jitter" then
		-- Start at 19 (solid) for the first second so every puppet is solid, then jitter inside the 20..22
		-- buffer: a correct buffer holds them solid, so no flips follow.
		if os.clock() - phaseStarted < 1 then
			return 19
		end
		return 21 + 0.9 * math.sin(t * 7 + index)
	elseif scene == "sweep" then
		return 21 + 3 * math.sin(t * (2 * math.pi / 4) + index) -- 18..24, one cycle per 4 s
	end
	return 40 + index -- idle
end

local cframes: { CFrame } = table.create(COUNT)
local moveConnection = RunService.PreRender:Connect(function()
	local t = os.clock() - started
	for index = 1, COUNT do
		local angle = index * (2 * math.pi / COUNT) + t * 0.4
		local radius = radiusFor(index, t)
		local position = centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		cframes[index] = CFrame.lookAt(position, position + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
	end
	Workspace:BulkMoveTo(roots, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)

local state = CollisionBlockerSystem.new(false)
local collisionOn = false
local stepSeconds = 0
local stepConnection = RunService.PreSimulation:Connect(function(dt: number)
	if not collisionOn then
		return
	end
	local clock = os.clock()
	CollisionBlockerSystem.step(state, dt, me.Position)
	CollisionSlideOffSystem.step(state, me)
	stepSeconds += os.clock() - clock
end)

local function setCollision(on: boolean)
	collisionOn = on
	for _, model in models do
		if on then
			CollisionBlockerSystem.addPuppet(state, model)
		else
			CollisionBlockerSystem.remove(state, model)
		end
	end
end

local function measure(): (number, number, number, number)
	phaseStarted = os.clock()
	task.wait(WARMUP_SECONDS)
	local frames, physics, heartbeat = 0, 0, 0
	stepSeconds = 0
	local writesAtStart = state.writes
	local connection = RunService.Heartbeat:Connect(function()
		frames += 1
		physics += Stats.PhysicsStepTimeMs
		heartbeat += Stats.HeartbeatTimeMs
	end)
	task.wait(MEASURE_SECONDS)
	connection:Disconnect()
	local n = math.max(frames, 1)
	return physics / n, heartbeat / n, stepSeconds / n * 1000, (state.writes - writesAtStart) / MEASURE_SECONDS
end

for _, name in SCENES do
	scene = name
	for round = 1, ROUNDS do
		for _, on in { false, true } do
			setCollision(on)
			local physics, heartbeat, stepMs, flips = measure()
			print(
				string.format(
					"R6PROBE scene=%s round=%d collision=%s physics=%.3f heartbeat=%.3f step=%.4f flips/s=%.1f",
					name,
					round,
					if on then "on" else "off",
					physics,
					heartbeat,
					stepMs,
					flips
				)
			)
		end
	end
end
setCollision(false)
moveConnection:Disconnect()
stepConnection:Disconnect()
folder:Destroy()
print("R6PROBE done")
