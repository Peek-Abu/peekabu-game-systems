--!strict
--[=[
	VacuumMotionSystem: the held vacuum's motion layers on this client, for every holder it sees (docs: characters/qa/
	vacuum-dynamic-ideas.md). Purely visual; the server's hold, suction and targeting are untouched.

	- Aim: the wand pitches with where its holder looks, about the left paw's grip: looking up raises the floor head (the
	  nozzle points ahead), looking down reaches for the floor (the hands go down and out, the wand flattens so the head
	  slides further out). The local player's own camera drives theirs at once; it is sent to the server
	  (VacuumEvents.Aim, quantised, throttled, only on change), which puts it on the character for everyone else
	  (VacuumMotionConstants.AIM_ATTRIBUTE).
	- Lean and brace: while a holder sucks (the server's ACTIVE_ATTRIBUTE, or the local player's own trigger at once),
	  their hips drop, their knees fold and they lean in over the wand, deeper as the pile at their floor head nears
	  done (its progress, VacuumFeedbackSystem.progressNear); letting go springs them back upright.
	- Suction juice: while sucking, the floor head shimmies, more as the pile nears done; when a pile pops
	  (VacuumFeedbackSystem.onPop) the wand of every holder who was just sucking it kicks back and up and settles.

	Each layer eases on a spring (VacuumMotionFormulas.step) and the pose is laid on the rig in RunService.PreSimulation,
	after the frame's animation and IK (VacuumMotionRigSystem).

	Spec-exempt shell (Players, Camera, RunService, ByteNet); the maths is the specced VacuumMotionFormulas.

	@class VacuumMotionSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumEvents = require(ReplicatedStorage.Shared.Features.Vacuum.Net.VacuumEvents)
local VacuumMotionRigSystem = require(ReplicatedStorage.Shared.Features.Vacuum.Systems.VacuumMotionRigSystem)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)
local VacuumFeedbackSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFeedbackSystem)

type Spring = { x: number, v: number }
type Holder = {
	character: Model,
	rig: VacuumMotionRigSystem.Rig?,
	raise: Spring,
	reach: Spring,
	brace: Spring,
	kick: Spring,
	-- When it last sucked (a pop within the kick's window of it kicks its wand).
	activeAt: number,
}

export type Options = {
	-- Whether the local player is holding the trigger now (their brace starts before the server says so).
	localActive: () -> boolean,
}

export type VacuumMotionState = { holders: number, bound: number, sent: number }

local VacuumMotionSystem = {}

-- How far from a holder's floor head the pile they suck is looked for (studs).
local PILE_RANGE = 6
-- A remote holder who has sent no aim yet looks the default third-person way.
local DEFAULT_LOOK = math.rad(-20)

local holders: { [Player]: Holder } = {}
local connection: RBXScriptConnection? = nil
local stopPops: (() -> ())? = nil
local options: Options? = nil
local lastSent: number? = nil
local sentAt = -math.huge
local sent = 0

local function spring(): Spring
	return { x = 0, v = 0 }
end

local function ease(s: Spring, target: number, dt: number, frequency: number, damping: number): number
	s.x, s.v = VacuumMotionFormulas.step(s.x, s.v, target, dt, frequency, damping)
	return s.x
end

local function cameraLook(): number
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)) else DEFAULT_LOOK
end

local function lookOf(player: Player, character: Model): number
	if player == Players.LocalPlayer then
		return cameraLook()
	end
	local degrees = character:GetAttribute(Constants.AIM_ATTRIBUTE)
	return if type(degrees) == "number" then math.rad(degrees) else DEFAULT_LOOK
end

local function activeOf(player: Player, character: Model): boolean
	local current = options
	if player == Players.LocalPlayer and current ~= nil and current.localActive() then
		return true
	end
	return character:GetAttribute(Constants.ACTIVE_ATTRIBUTE) == true
end

local function release(holder: Holder)
	local rig = holder.rig
	if rig ~= nil then
		rig.release()
	end
	holder.rig = nil
end

-- Sends the local player's look pitch when it changed, at most aim.rate a second.
local function sendAim(now: number)
	if now - sentAt < 1 / Constants.aim.rate then
		return
	end
	local byte = VacuumMotionFormulas.encodeAim(cameraLook())
	if byte == lastSent then
		return
	end
	lastSent = byte
	sentAt = now
	sent += 1
	VacuumEvents.packets.Aim.send(byte)
end

-- The holder's bound rig: rebound when its Tool or targets changed, nil while it holds no vacuum.
local function rigOf(holder: Holder): VacuumMotionRigSystem.Rig?
	local current = holder.rig
	if current ~= nil and current.valid() then
		return current
	end
	release(holder)
	if holder.character:FindFirstChild(VacuumConstants.TOOL_NAME) == nil then
		return nil
	end
	local bound = VacuumMotionRigSystem.bind(holder.character)
	if bound ~= nil then
		holder.rig = bound
		holder.raise, holder.reach, holder.brace, holder.kick = spring(), spring(), spring(), spring()
	end
	return bound
end

local function stepHolder(player: Player, holder: Holder, dt: number)
	local character = holder.character
	local rig = rigOf(holder)
	if rig == nil then
		return
	end
	local aim, brace, kick = Constants.aim, Constants.brace, Constants.kick
	local raiseTarget, reachTarget = VacuumMotionFormulas.aim(lookOf(player, character), aim)
	local head = rig.tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME)
	local active = activeOf(player, character)
	if active then
		holder.activeAt = os.clock()
	end
	local progress = if active
			and head ~= nil
			and head:IsA("BasePart")
		then VacuumFeedbackSystem.progressNear(head.Position, PILE_RANGE) or 0
		else 0
	local braced =
		ease(holder.brace, VacuumMotionFormulas.braceTarget(active, progress), dt, brace.frequency, brace.damping)
	-- The shimmy fades in and out with the brace (0 upright, 1 at the brace's start depth).
	local shimmyYaw, shimmyRoll =
		VacuumMotionFormulas.shimmy(os.clock(), player.UserId % 997, progress, braced / brace.base)
	local layers: VacuumMotionFormulas.Layers = {
		raise = ease(holder.raise, raiseTarget, dt, aim.frequency, aim.damping),
		reach = ease(holder.reach, reachTarget, dt, aim.frequency, aim.damping),
		brace = braced,
		kick = ease(holder.kick, 0, dt, kick.frequency, kick.damping),
		shimmyYaw = shimmyYaw,
		shimmyRoll = shimmyRoll,
	}
	local drop, lean = VacuumMotionFormulas.body(math.max(layers.brace, 0))
	local wand = VacuumMotionFormulas.wand(
		rig.rest,
		VacuumMotionFormulas.offsetOf(layers),
		Constants.floorMargin,
		VacuumMotionFormulas.motion(rig.rest.waist, drop, lean)
	)
	rig.apply({ wand = wand, drop = drop, lean = lean })
end

-- A pile popped: every holder who was sucking just now, close to it, kicks (bigger piles harder).
local function onPop(position: Vector3, size: number)
	local tuning = Constants.kick
	local now = os.clock()
	for _, holder in holders do
		local rig = holder.rig
		local root = holder.character:FindFirstChild("HumanoidRootPart")
		if
			rig ~= nil
			and root ~= nil
			and root:IsA("BasePart")
			and now - holder.activeAt <= tuning.window
			and (root.Position - position).Magnitude <= tuning.range
		then
			holder.kick.v += VacuumMotionFormulas.kickImpulse(VacuumMotionFormulas.kickScale(size))
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	for player, holder in holders do
		if player.Parent == nil or player.Character ~= holder.character then
			release(holder)
			holders[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character == nil then
			continue
		end
		local holder = holders[player]
		if holder == nil then
			holder = {
				character = character,
				rig = nil,
				raise = spring(),
				reach = spring(),
				brace = spring(),
				kick = spring(),
				activeAt = -math.huge,
			}
			holders[player] = holder
		end
		stepHolder(player, holder, dt)
		if player == Players.LocalPlayer and holder.rig ~= nil then
			sendAim(now)
		end
	end
end

function VacuumMotionSystem.start(given: Options)
	if connection ~= nil then
		return
	end
	options = given
	connection = RunService.PreSimulation:Connect(step)
	stopPops = VacuumFeedbackSystem.onPop(onPop)
end

function VacuumMotionSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
	end
	connection = nil
	local pops = stopPops
	if pops ~= nil then
		pops()
	end
	stopPops = nil
	for _, holder in holders do
		release(holder)
	end
	table.clear(holders)
	options = nil
	lastSent = nil
end

function VacuumMotionSystem.getState(): VacuumMotionState
	local count, bound = 0, 0
	for _, holder in holders do
		count += 1
		if holder.rig ~= nil then
			bound += 1
		end
	end
	return { holders = count, bound = bound, sent = sent }
end

return VacuumMotionSystem
