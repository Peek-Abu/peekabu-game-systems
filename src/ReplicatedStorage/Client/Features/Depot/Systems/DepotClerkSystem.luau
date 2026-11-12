--!strict
--[=[
	DepotClerkSystem: the Supply Counter clerk on this client (owner 11-11, "Stamp & Stack"; DepotSpotConstants.CLERK).
	Pippa (CLERK.EMPLOYEE: she ran the front desk before night shifts; the same on every client, so nothing replicates)
	stands on the floor on the part tagged CLERK.TAG behind the counter, facing its LookVector, a red rubber stamp in
	her right hand, a parcel on the counter in front of her. She plays an active idle (DepotAssets.CLERK_IDLE, looped)
	and every few seconds breaks into a fidget picked by weight (DepotClerkRules.pickFidget: the stamp most of the
	time, sometimes a stretch and yawn), then fades back to the idle. The parcel is sized once from the stamp clip
	itself: the clip is posed at the contact, the stamp's face is measured and the counter found under it, so the stamp
	lands on it for any employee (DepotClerkRules.parcelHeight). On the stamp's Thunk marker the parcel squashes a
	little; on Lift it hops (DepotClerkRules.hop). A player walking up, or opening the Shop at the counter (`greet`),
	gets a wave (DepotAssets.CLERK_GREET, DepotClerkRules.greets), which cuts any fidget short.

	Spec-exempt shell (Instances, the Animator, the camera-free character build); the decisions are the specced
	DepotClerkRules.

	@class DepotClerkSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotClerkRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotClerkRules)
local DepotAssets = require(ReplicatedStorage.Client.Features.Depot.Data.DepotAssets)

local CLERK = DepotSpotConstants.CLERK
local STAMP = CLERK.STAMP
local PARCEL = CLERK.PARCEL
-- Seconds the clips blend into each other.
local FADE = 0.2
-- Studs the counter is searched for under the stamp's face.
local COUNTER_SEARCH = 4
-- How much the parcel squashes under the stamp while it presses (a share of its height).
local PRESS = 0.12

type Clerk = {
	spot: BasePart,
	model: Model,
	idle: AnimationTrack,
	stamp: AnimationTrack,
	greet: AnimationTrack,
	-- The fidgets by name (CLERK.FIDGETS), the one playing, the last one and when the next is due (os.clock).
	fidgets: { [string]: AnimationTrack },
	fidget: AnimationTrack?,
	lastFidget: string?,
	nextFidgetAt: number,
	parcel: Part?,
	tape: Part?,
	parcelHeight: number,
	parcelBase: Vector3,
	-- os.clock of the last lift (the parcel is hopping), or nil.
	liftAt: number?,
	lastGreet: number?,
	-- The local player is within the greet radius (a wave comes when they walk in, not while they stand there).
	near: boolean,
	connections: { RBXScriptConnection },
}

local clerks: { [BasePart]: Clerk } = {}

local function characterSource(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local crew = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	local characters = if crew ~= nil then crew:FindFirstChild("Characters") else nil
	local source = if characters ~= nil then characters:FindFirstChild(name) else nil
	return if source ~= nil and source:IsA("Model") then source else nil
end

local random = Random.new()

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Size = size
	made.Color = color
	made.Material = material
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.Massless = true
	made.Parent = parent
	return made
end

local function weld(to: BasePart, piece: BasePart, offset: CFrame)
	local joint = Instance.new("Weld")
	joint.Part0 = to
	joint.Part1 = piece
	joint.C0 = offset
	joint.Parent = piece
end

-- The rubber stamp in the right hand; returns its base (the face is the base's bottom).
local function holdStamp(model: Model): BasePart?
	local hand = model:FindFirstChild("RightHand")
	if hand == nil or not hand:IsA("BasePart") then
		return nil
	end
	local degrees = STAMP.GRIP_DEGREES
	local grip = CFrame.new(STAMP.GRIP_POSITION)
		* CFrame.fromEulerAnglesXYZ(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
	local handle = part(
		"StampHandle",
		Vector3.new(STAMP.HANDLE_LENGTH, STAMP.HANDLE_WIDTH, STAMP.HANDLE_WIDTH),
		STAMP.WOOD_COLOR,
		Enum.Material.Wood,
		model
	)
	handle.Shape = Enum.PartType.Cylinder
	weld(hand, handle, grip * CFrame.Angles(0, 0, math.rad(90)))
	local base = part("StampBase", STAMP.BASE, STAMP.BASE_COLOR, Enum.Material.SmoothPlastic, model)
	weld(hand, base, grip * CFrame.new(0, -(STAMP.HANDLE_LENGTH + STAMP.BASE.Y) / 2, 0))
	local knob = part("StampKnob", Vector3.one * STAMP.KNOB, STAMP.WOOD_COLOR, Enum.Material.Wood, model)
	knob.Shape = Enum.PartType.Ball
	weld(hand, knob, grip * CFrame.new(0, STAMP.HANDLE_LENGTH / 2 + 0.01, 0))
	return base
end

local function face(base: BasePart): Vector3
	return (base.CFrame * CFrame.new(0, -base.Size.Y / 2, 0)).Position
end

-- Shapes the parcel: `lift` studs off the counter, its height scaled by `scale` (a squash also widens it a little).
local function shapeParcel(clerk: Clerk, lift: number, scale: number)
	local parcel, tape = clerk.parcel, clerk.tape
	if parcel == nil or tape == nil then
		return
	end
	local height = clerk.parcelHeight * scale
	local spread = 1 + (1 - scale) * 0.5
	local at = CFrame.new(clerk.parcelBase + Vector3.new(0, lift + height / 2, 0))
		* CFrame.fromOrientation(0, math.rad(clerk.spot.Orientation.Y), 0)
	parcel.Size = Vector3.new(PARCEL.WIDTH * spread, height, PARCEL.DEPTH * spread)
	parcel.CFrame = at
	tape.Size = Vector3.new(PARCEL.TAPE_WIDTH, height + 0.02, PARCEL.DEPTH * spread + 0.02)
	tape.CFrame = at
end

-- The parcel under the stamp: the clip is posed at the contact, the face measured, the counter found below it.
local function placeParcel(clerk: Clerk, base: BasePart)
	clerk.stamp:Play(0, 1, 0)
	clerk.stamp.TimePosition = CLERK.CONTACT_TIME
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	local at = face(base)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { clerk.model }
	local hit = Workspace:Raycast(at + Vector3.new(0, 0.05, 0), Vector3.new(0, -COUNTER_SEARCH, 0), params)
	local counterY = if hit ~= nil then hit.Position.Y else at.Y - PARCEL.MIN_HEIGHT
	clerk.parcelHeight = DepotClerkRules.parcelHeight(at.Y, counterY)
	-- It stands on the counter (a clamped height never leaves it floating).
	clerk.parcelBase = Vector3.new(at.X, counterY, at.Z)
	local parcel = Instance.new("Part")
	parcel.Name = "ClerkParcel"
	parcel.Anchored = true
	parcel.CanCollide = false
	parcel.CanQuery = false
	parcel.CanTouch = false
	parcel.Color = PARCEL.COLOR
	parcel.Material = Enum.Material.Cardboard
	local tape = parcel:Clone()
	tape.Name = "Tape"
	tape.Color = PARCEL.TAPE_COLOR
	tape.Material = Enum.Material.SmoothPlastic
	tape.Parent = parcel
	parcel.Parent = clerk.model
	clerk.parcel, clerk.tape = parcel, tape
	shapeParcel(clerk, 0, 1)
	clerk.stamp:Stop(0)
	clerk.idle:Play(0, 1, 1)
end

local function remove(spot: BasePart)
	local clerk = clerks[spot]
	if clerk == nil then
		return
	end
	clerks[spot] = nil
	for _, connection in clerk.connections do
		connection:Disconnect()
	end
	clerk.model:Destroy()
end

local function build(spot: BasePart)
	local source = characterSource(CLERK.EMPLOYEE)
	if source == nil then
		return
	end
	local model = source:Clone()
	model.Name = "SupplyClerk"
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return
	end
	root.Anchored = true
	local top = spot.Position + Vector3.new(0, spot.Size.Y / 2, 0)
	local look = spot.CFrame.LookVector
	model:PivotTo(CFrame.lookAt(top, top + Vector3.new(look.X, 0, look.Z)))
	local frame, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, top.Y - (frame.Position.Y - size.Y / 2), 0))
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid or model
		animator = made
	end
	local base = holdStamp(model)
	model.Parent = Workspace
	if animator == nil or base == nil then
		model:Destroy()
		return
	end
	local function load(id: string, looped: boolean, priority: Enum.AnimationPriority): AnimationTrack
		local clip = Instance.new("Animation")
		clip.AnimationId = id
		local track = animator:LoadAnimation(clip)
		track.Looped = looped
		track.Priority = priority
		return track
	end
	local stamp = load(DepotAssets.CLERK_STAMP, false, Enum.AnimationPriority.Action)
	local clerk: Clerk = {
		spot = spot,
		model = model,
		idle = load(DepotAssets.CLERK_IDLE, true, Enum.AnimationPriority.Idle),
		stamp = stamp,
		greet = load(DepotAssets.CLERK_GREET, false, Enum.AnimationPriority.Action2),
		fidgets = {
			stamp = stamp,
			stretch = load(DepotAssets.CLERK_STRETCH, false, Enum.AnimationPriority.Action),
		},
		fidget = nil,
		lastFidget = nil,
		nextFidgetAt = DepotClerkRules.nextFidgetAt(os.clock(), random:NextNumber()),
		parcel = nil,
		tape = nil,
		parcelHeight = PARCEL.MIN_HEIGHT,
		parcelBase = top,
		liftAt = nil,
		lastGreet = nil,
		near = false,
		connections = {},
	}
	clerks[spot] = clerk
	table.insert(
		clerk.connections,
		clerk.stamp:GetMarkerReachedSignal(CLERK.THUNK_MARKER):Connect(function()
			shapeParcel(clerk, 0, 1 - PRESS)
		end)
	)
	table.insert(
		clerk.connections,
		clerk.stamp:GetMarkerReachedSignal(CLERK.LIFT_MARKER):Connect(function()
			clerk.liftAt = os.clock()
		end)
	)
	-- After a fidget or the wave: back to the idle, the next fidget due a few seconds later.
	for _, track in { clerk.greet, clerk.fidgets.stamp, clerk.fidgets.stretch } do
		table.insert(
			clerk.connections,
			track.Stopped:Connect(function()
				if clerk.fidget == track then
					clerk.fidget = nil
				end
				clerk.nextFidgetAt = DepotClerkRules.nextFidgetAt(os.clock(), random:NextNumber())
			end)
		)
	end
	table.insert(
		clerk.connections,
		RunService.RenderStepped:Connect(function()
			local liftAt = clerk.liftAt
			if liftAt == nil then
				return
			end
			local t = os.clock() - liftAt
			local lift, scale = DepotClerkRules.hop(t)
			shapeParcel(clerk, lift, scale)
			if DepotClerkRules.hopDone(t) then
				clerk.liftAt = nil
				shapeParcel(clerk, 0, 1)
			end
		end)
	)
	task.spawn(placeParcel, clerk, base)
end

-- Breaks from the idle into a fidget when one is due (none playing, no wave).
local function fidget(clerk: Clerk)
	if clerk.fidget ~= nil or clerk.greet.IsPlaying or os.clock() < clerk.nextFidgetAt then
		return
	end
	local name = DepotClerkRules.pickFidget(random:NextNumber(), clerk.lastFidget)
	local track: AnimationTrack? = clerk.fidgets[name]
	if track == nil then
		return
	end
	clerk.lastFidget = name
	clerk.fidget = track
	track:Play(FADE, 1, 1)
end

-- The clerk waves at the local player, `distance` studs away, if the rules allow it now.
local function wave(clerk: Clerk, distance: number)
	local now = os.clock()
	if not DepotClerkRules.greets(distance, clerk.lastGreet, now) or clerk.greet.IsPlaying then
		return
	end
	clerk.lastGreet = now
	local playing = clerk.fidget
	if playing ~= nil then
		clerk.fidget = nil
		playing:Stop(FADE)
	end
	-- The wave interrupts a hop or a press: the parcel settles.
	clerk.liftAt = nil
	shapeParcel(clerk, 0, 1)
	clerk.greet:Play(FADE, 1, 1)
end

local function distanceTo(clerk: Clerk): number?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	return (character:GetPivot().Position - clerk.spot.Position).Magnitude
end

local DepotClerkSystem = {}

--[=[
	The player opened the Shop at the counter: the clerk waves (if it has not just waved).
]=]
function DepotClerkSystem.greet()
	for _, clerk in clerks do
		wave(clerk, 0)
	end
end

-- Puts the clerk on every clerk spot; returns the stopper.
function DepotClerkSystem.start(): () -> ()
	local stopSpots = Observers.observeTag(CLERK.TAG, function(instance: Instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		build(instance)
		return function()
			remove(instance)
		end
	end)
	local greeter = RunService.Heartbeat:Connect(function()
		for _, clerk in clerks do
			fidget(clerk)
			local distance = distanceTo(clerk)
			local near = distance ~= nil and distance <= CLERK.GREET.RADIUS
			if near and not clerk.near and distance ~= nil then
				wave(clerk, distance)
			end
			clerk.near = near
		end
	end)
	return function()
		greeter:Disconnect()
		stopSpots()
		for spot in clerks do
			remove(spot)
		end
	end
end

return DepotClerkSystem
