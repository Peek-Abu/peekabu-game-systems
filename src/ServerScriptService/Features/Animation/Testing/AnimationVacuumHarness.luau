--!strict
--[=[
	AnimationVacuumHarness: the vacuum hold validator. Holds the hand wand on every test carrier in every vacuum skin
	and judges what the engine shows, so a rig, skin, clip or hold change that would take a hand off the wand fails
	instead of reaching a playtest.

	For each holder (AnimationCarryRigHarness; by default only the employee, Pippa as EmployeeSpawnSystem installs her:
	every player spawns as an employee, so nobody else holds the wand) and each skin (VacuumSkinRegistry), `run`:
	1. shows a frame of the stock fall clip (PLAN_CLIP) and only then makes the Tool (VacuumToolSystem.create, which
	   plans the hold): the game makes it as a shift starts, while the crew, just placed in the truck, is falling onto
	   its bed (Studio, 2026-10-16: Freefall, this clip at 0.53 s, the UpperTorso 0.36 stud forward and pitched 23
	   degrees), never at a chosen pose. A hold read from that pose put Pippa's left hand's target out of her reach,
	   and that arm hung at full stretch, swaying with the idle, 0.21-0.30 stud off the wand;
	2. equips it as the game does (the Tool into the character: AnimationVacuumHoldSystem holds the arms);
	3. lets the engine's Animator solve the IK over the carrier's own clips and judges each frame: idle (two),
	   walk (two), sprint (two) and vacuuming (the vacuum's use clip over the idle and the walk when one is
	   registered, else the locomotion it plays over); each frame is shown once its clip has loaded and confirmed
	   shown at its time and full weight (AnimationCarryClipHarness);
	4. in each frame, lays every motion layer on the rig at its extremes (LAYERS: rest, aim up, out and in, the brace
	   and the brace with each aim, the pop's recoil and its rebound, the shimmy each way, the wand's sway each way,
	   aimed at the look point each way and all at once; the wand always aimed at the look point, as every client
	   aims it; VacuumMotionRigSystem, exactly as every client does, in PreSimulation after the
	   Animator's IK) and judges each: each paw's wrap point (VacuumVisualSystem.wrapOf, inside the paw) must be on
	   its grip, the right on the wand's GripUpper and the left on its GripLower (the grip contract), within
	   GRIP_TOLERANCE (the left also within reachSlack: it may slip); each grip must lie inside its paw (the paw closes round the wand); the floor head's
	   lowest corner must be over the floor (FLOOR_TOLERANCE); and no hand or forearm may sit inside the torso
	   (CLIP_TOLERANCE, an ellipsoid per torso part). Each layer's worst line also gives how far out the floor head
	   sits on average (the camera tilt's travel).
	`format` prints the report; the spec asserts it. Needs a real runtime (TestEZ in Studio): run it with
	`Workspace.RunTests = true`, or from a server Script: `print(Harness.format(Harness.run({})))`.

	@class AnimationVacuumHarness
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumMotionConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VacuumMotionRigSystem = require(ReplicatedStorage.Shared.Features.Vacuum.Systems.VacuumMotionRigSystem)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)
local AnimationCarryClipHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryClipHarness)
local AnimationCarryRigHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryRigHarness)
local VacuumToolSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumToolSystem)
local VacuumVisualSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumVisualSystem)

type Carrier = AnimationCarryRigHarness.Carrier

export type Frame = {
	state: string,
	name: string,
	-- The motion layer laid on (LAYERS).
	layer: string,
	-- How far each paw's wrap point is from its grip on the wand (studs); nil when it could not be measured.
	right: number?,
	left: number?,
	-- The floor head's lowest corner over the floor (studs).
	clear: number?,
	-- How far out the floor head sits from the root, flat (studs).
	out: number?,
	-- How deep the deepest hand or forearm point sits inside the torso (studs; 0 when none is).
	clip: number?,
	problems: { string },
}
export type Entry = {
	rig: string,
	skin: string,
	frames: { Frame },
	problems: { string },
	ok: boolean,
	-- The wand's aim turn about its pivot (degrees, left positive) looking straight ahead, and at the look's most
	-- left and right (VacuumMotionFormulas.aimYaw).
	turns: { ahead: number, left: number, right: number }?,
}
export type Result = { ok: boolean, entries: { Entry }, notes: { string } }
-- The worst of a layer's frames: the furthest each paw sat from its grip, and the floor head's least clearance.
type Worst = { right: number, left: number, clear: number, clip: number, out: number, count: number }
export type Options = { rigs: { string }?, skins: { string }? }

local AnimationVacuumHarness = {}

-- How far a paw's wrap point may sit from its grip on the wand (studs).
local GRIP_TOLERANCE = 0.05
-- The left paw may also slip along the wand by up to the reach guard's slack (VacuumMotionConstants.reachSlack,
-- feel pass batch 2 2026-11-06): its arm goes straight instead of the move being cancelled.
local LEFT_TOLERANCE = GRIP_TOLERANCE + VacuumMotionConstants.reachSlack
-- How deep a hand or forearm may sit inside the torso (studs): the paws rest against a round belly.
local CLIP_TOLERANCE = 0.03
-- How far the floor head's lowest corner may dip under the floor (studs).
local FLOOR_TOLERANCE = 0.02
-- Each motion layer at its extremes (VacuumMotionFormulas.Layers), laid on every frame.
-- A layers' state: every layer off but those given (the shimmy as a fraction of its amplitude, each way).
type Given = {
	raise: number?,
	reach: number?,
	brace: number?,
	kick: number?,
	shimmy: number?,
	swayYaw: number?,
	swayPitch: number?,
	-- The look's heading off the body (radians, left positive): the wand aims at it, the upper body twists toward it.
	look: number?,
}
local function layered(given: Given): VacuumMotionFormulas.Layers
	local shimmy = given.shimmy or 0
	return {
		raise = given.raise or 0,
		reach = given.reach or 0,
		brace = given.brace or 0,
		kick = given.kick or 0,
		shimmyYaw = shimmy * VacuumMotionConstants.shimmy.yaw,
		shimmyRoll = shimmy * VacuumMotionConstants.shimmy.roll,
		swayYaw = given.swayYaw or 0,
		swayPitch = given.swayPitch or 0,
		lookYaw = given.look or 0,
	}
end
local UP = VacuumMotionConstants.aim.maxUp
-- The biggest kick (a pile at maxScale, at its peak).
local KICK = VacuumMotionConstants.kick.maxScale
local SWAY_YAW = VacuumMotionConstants.sway.maxYaw
local SWAY_PITCH = VacuumMotionConstants.sway.maxPitch
local LOOK = VacuumMotionConstants.aim.maxLook
local LAYERS: { { name: string, layers: VacuumMotionFormulas.Layers } } = {
	{ name = "rest", layers = layered({}) },
	{ name = "aim up", layers = layered({ raise = UP }) },
	{ name = "aim out", layers = layered({ reach = 1 }) },
	{ name = "aim in", layers = layered({ reach = -1 }) },
	{ name = "brace", layers = layered({ brace = 1 }) },
	{ name = "brace+out", layers = layered({ reach = 1, brace = 1 }) },
	{ name = "brace+in", layers = layered({ reach = -1, brace = 1 }) },
	{ name = "brace+up", layers = layered({ raise = UP, brace = 1 }) },
	-- The pop: the kick's peak, and the spring's rebound the other way.
	{ name = "recoil", layers = layered({ brace = 1, kick = KICK }) },
	{ name = "recoil back", layers = layered({ reach = 1, brace = 1, kick = -0.4 * KICK }) },
	{ name = "recoil+up", layers = layered({ raise = UP, kick = KICK }) },
	-- The shimmy at its full amplitude, each way.
	{ name = "shimmy+", layers = layered({ reach = 1, brace = 1, shimmy = 1 }) },
	{ name = "shimmy-", layers = layered({ brace = 1, shimmy = -1 }) },
	-- The wand's lag at its most: swung each way on a turn, slid on at a stop, trailing while aimed up.
	{ name = "sway left", layers = layered({ swayYaw = SWAY_YAW }) },
	{ name = "sway right", layers = layered({ swayYaw = -SWAY_YAW, reach = 1 }) },
	{ name = "sway stop", layers = layered({ swayPitch = SWAY_PITCH, swayYaw = SWAY_YAW }) },
	{ name = "sway+up", layers = layered({ raise = UP, swayPitch = -SWAY_PITCH, swayYaw = -SWAY_YAW }) },
	-- Aimed at the look point at its most each way (aim fix 2026-11-06: the floor head points at it, the upper
	-- body twists toward it), and braced.
	{ name = "aim left", layers = layered({ look = LOOK }) },
	{ name = "aim right", layers = layered({ look = -LOOK }) },
	{ name = "brace+left", layers = layered({ look = LOOK, brace = 1 }) },
	{ name = "brace+right", layers = layered({ look = -LOOK, brace = 1, reach = 1 }) },
	-- Everything at once.
	{
		name = "all",
		layers = layered({ raise = UP, brace = 1, kick = KICK, shimmy = 1, swayYaw = SWAY_YAW, swayPitch = SWAY_PITCH }),
	},
}
-- Frames to let the Animator settle after a change.
local SETTLE = 4
-- The pose the plan is read in: the stock fall (AnimationLocomotionRegistry), at this fraction of the clip.
local PLAN_CLIP = "fall"
local PLAN_AT = 0.5
-- The holders validated unless `Options.rigs` names others. A stock R15 is not one (every player spawns as an
-- employee); its left hand does not reach GripLower (2.18 studs from its shoulder at rest, 2.02 of reach), so it
-- holds the wand one-handed.
-- Cappy and Prickles can be judged by name (`Options.rigs`); both hold the wand two-handed (Cappy since batch 2.6:
-- left paw at most 0.142 stud off), but their floor heads still dip under the floor in the brace (Studio,
-- 2026-11-06: Cappy 0.037-0.083 stud in idle B / walk B, Prickles 0.021-0.026 in sprint B), so they join the default
-- once that is fixed (Launch List g-prickles-floor-dip).
local DEFAULT_RIGS = { "Pippa" }
-- The vacuum's use clip (AnimationVacuumSystem), when registered.
local USE_CLIP = "cleanupVacuumUse"

type Sample = { state: string, name: string, id: string?, at: number, over: string? }

local function descendant(container: Instance, name: string): Attachment?
	local found = container:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

local function handOf(model: Model, side: string): BasePart?
	local found = model:FindFirstChild(side .. "Hand")
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- How far the paw's wrap point (hand space) is from the grip on the wand, and whether the grip is inside the paw.
local function onPaw(hand: BasePart?, wrap: Vector3?, grip: Attachment?): (number?, boolean)
	if hand == nil or wrap == nil or grip == nil then
		return nil, false
	end
	local inHand = hand.CFrame:PointToObjectSpace(grip.WorldPosition)
	local half = hand.Size / 2
	local inside = math.abs(inHand.X) <= half.X and math.abs(inHand.Y) <= half.Y and math.abs(inHand.Z) <= half.Z
	return (hand.CFrame:PointToWorldSpace(wrap) - grip.WorldPosition).Magnitude, inside
end

-- How deep the deepest hand or forearm point sits inside the torso (studs): each arm part's centre and the ends of
-- its long axis, against an ellipsoid filling each torso part (round bodies).
local function armClip(model: Model): number
	local deepest = 0
	local torsos: { BasePart } = {}
	for _, name in { "UpperTorso", "LowerTorso" } do
		local part = model:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			table.insert(torsos, part)
		end
	end
	for _, name in { "RightHand", "RightLowerArm", "LeftHand", "LeftLowerArm" } do
		local part = model:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			local size = part.Size
			local along = if size.Y >= size.X and size.Y >= size.Z
				then Vector3.new(0, size.Y / 2, 0)
				elseif size.X >= size.Z then Vector3.new(size.X / 2, 0, 0)
				else Vector3.new(0, 0, size.Z / 2)
			for _, offset in { Vector3.zero, along, -along } do
				local point = part.CFrame:PointToWorldSpace(offset)
				for _, torso in torsos do
					local local_ = torso.CFrame:PointToObjectSpace(point)
					local half = torso.Size / 2
					local reach = (local_.X / half.X) ^ 2 + (local_.Y / half.Y) ^ 2 + (local_.Z / half.Z) ^ 2
					if reach < 1 then
						local smallest = math.min(half.X, half.Y, half.Z)
						deepest = math.max(deepest, (1 - math.sqrt(reach)) * smallest)
					end
				end
			end
		end
	end
	return deepest
end

-- How far out the floor head sits from `model`'s root, flat (studs).
local function outOf(model: Model, head: BasePart?): number?
	local root = model:FindFirstChild("HumanoidRootPart")
	if head == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local flat = root.CFrame:PointToObjectSpace(head.Position)
	return Vector2.new(flat.X, flat.Z).Magnitude
end

-- The floor head's lowest corner over the floor under `model`'s root (studs).
local function clearance(model: Model, head: BasePart?): number?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if head == nil or root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil
	end
	local floor = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight)
	local half = head.Size / 2
	local low = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				low = math.min(low, head.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z)).Y)
			end
		end
	end
	return low - floor
end

--[=[
	The pose VacuumMotionSystem lays on a bound rig for `layers` (its springs settled there): the wand aimed at the
	look point (the look's heading, `distance` studs out; the far one by default), the upper body twisted with the wand's turn.
]=]
function AnimationVacuumHarness.poseOf(
	rig: VacuumMotionRigSystem.Rig,
	layers: VacuumMotionFormulas.Layers,
	distance: number?
): VacuumMotionRigSystem.Pose
	local look = layers.lookYaw or 0
	local aimed = table.clone(layers)
	aimed.aimYaw = VacuumMotionFormulas.aimYaw(rig.rest, look, distance or VacuumMotionConstants.aim.far)
	local drop, lean = VacuumMotionFormulas.body(layers.brace)
	local twist = VacuumMotionFormulas.bodyTwist(rig.rest, aimed, drop, lean)
	local wand = VacuumMotionFormulas.wand(
		rig.rest,
		VacuumMotionFormulas.offsetOf(aimed),
		VacuumMotionConstants.floorMargin,
		VacuumMotionFormulas.motion(rig.rest.waist, drop, lean, twist)
	)
	return { wand = wand, drop = drop, lean = lean, twist = twist }
end

--[=[
	Whether this place can build the employee carrier (it needs her art template).
]=]
function AnimationVacuumHarness.hasEmployee(): boolean
	local model = AnimationCarryRigHarness.employee(Vector3.new(0, 4000, -400))
	if model == nil then
		return false
	end
	model:Destroy()
	return true
end

-- The frames sampled on `carrier`.
local function samples(carrier: Carrier): ({ Sample }, string?)
	local list: { Sample } = {
		{ state = "idle", name = "idle A", id = carrier.idle, at = 0.25 },
		{ state = "idle", name = "idle B", id = carrier.idle, at = 0.75 },
		{ state = "walk", name = "walk A", id = carrier.walk, at = 0.25 },
		{ state = "walk", name = "walk B", id = carrier.walk, at = 0.6 },
		{ state = "sprint", name = "sprint A", id = carrier.run, at = 0.25 },
		{ state = "sprint", name = "sprint B", id = carrier.run, at = 0.6 },
	}
	local use = AnimationRegistry.get(USE_CLIP)
	local note: string? = nil
	if use ~= nil then
		table.insert(list, { state = "vacuum", name = "vacuum idle", id = carrier.idle, at = 0.5, over = use.assetId })
		table.insert(list, { state = "vacuum", name = "vacuum walk", id = carrier.walk, at = 0.4, over = use.assetId })
	else
		-- Vacuuming plays no clip of its own (AnimationVacuumRegistry is empty): the hold rides the locomotion.
		note = `no {USE_CLIP} clip registered: vacuuming is sampled as the hold over the locomotion`
		table.insert(list, { state = "vacuum", name = "vacuum idle", id = carrier.idle, at = 0.5 })
		table.insert(list, { state = "vacuum", name = "vacuum walk", id = carrier.walk, at = 0.4 })
	end
	return list, note
end

-- Holds the wand in `skin` on `carrier`, planned mid-fall, and judges every frame.
local function hold(carrier: Carrier, skin: VacuumSkinRegistry.SkinDef): Entry
	local entry: Entry = { rig = carrier.name, skin = skin.name, frames = {}, problems = {}, ok = false }
	local model = carrier.model
	local animator = AnimationCarryRigHarness.animator(model)
	if animator == nil then
		table.insert(entry.problems, "no Animator")
		return entry
	end
	-- 1. The plan, read while the carrier is falling.
	local planTrack: AnimationTrack? = nil
	local fall = AnimationRegistry.get(PLAN_CLIP)
	if fall == nil then
		table.insert(entry.problems, `plan pose: no {PLAN_CLIP} clip registered`)
	else
		local track, err = AnimationCarryClipHarness.show(animator, fall.assetId, PLAN_AT)
		if track == nil then
			table.insert(entry.problems, `plan pose: {err}`)
		end
		planTrack = track
		AnimationCarryRigHarness.settle(SETTLE)
	end
	local backpack: VacuumVisualSystem.WornBackpack = {
		model = Instance.new("Model"),
		skin = skin,
		setHeld = function(_inlet: Attachment?) end,
		destroy = function() end,
	}
	local tool = VacuumToolSystem.create(model, backpack)
	if planTrack ~= nil then
		planTrack:Stop(0)
		planTrack:Destroy()
	end
	-- 2. Equipped.
	tool.Parent = model
	AnimationCarryRigHarness.settle(SETTLE)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid:FindFirstChild("VacuumSupportIK") == nil then
		table.insert(entry.problems, "the left hand has no hold on the wand (planned out of its reach)")
	end
	local upper, lower = descendant(tool, "GripUpper"), descendant(tool, "GripLower")
	if upper == nil or lower == nil then
		table.insert(entry.problems, "the wand has no GripUpper / GripLower (the grip contract)")
	end
	local rightHand, leftHand = handOf(model, "Right"), handOf(model, "Left")
	local rightWrap, leftWrap = VacuumVisualSystem.wrapOf(model, "Right"), VacuumVisualSystem.wrapOf(model, "Left")
	local headFound = tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME)
	local head = if headFound ~= nil and headFound:IsA("BasePart") then headFound else nil
	-- 4. The motion layers, laid on as every client lays them (after the Animator's IK, every frame).
	local rig = VacuumMotionRigSystem.bind(model)
	if rig == nil then
		table.insert(entry.problems, "the motion layers could not bind the held vacuum")
	else
		local far, most = VacuumMotionConstants.aim.far, VacuumMotionConstants.aim.maxLook
		entry.turns = {
			ahead = math.deg(VacuumMotionFormulas.aimYaw(rig.rest, 0, far)),
			left = math.deg(VacuumMotionFormulas.aimYaw(rig.rest, most, far)),
			right = math.deg(VacuumMotionFormulas.aimYaw(rig.rest, -most, far)),
		}
	end
	local pose: VacuumMotionRigSystem.Pose? = nil
	local layering = RunService.PreSimulation:Connect(function()
		if rig ~= nil and pose ~= nil then
			rig.apply(pose)
		end
	end)
	-- 3. Every frame, live, under every layer.
	local list, _ = samples(carrier)
	for _, sample in list do
		local id = sample.id
		local track: AnimationTrack? = nil
		local overTrack: AnimationTrack? = nil
		local shownProblem: string? = nil
		if id == nil then
			shownProblem = "no clip"
		else
			local shown, err = AnimationCarryClipHarness.show(animator, id, sample.at)
			track = shown
			local over = sample.over
			if over ~= nil then
				overTrack = AnimationCarryClipHarness.show(animator, over, 0.5)
			end
			if shown == nil then
				shownProblem = err or "clip not shown"
			end
		end
		for _, layer in LAYERS do
			local frame: Frame = { state = sample.state, name = sample.name, layer = layer.name, problems = {} }
			if shownProblem ~= nil then
				table.insert(frame.problems, shownProblem)
			elseif track ~= nil then
				pose = if rig ~= nil then AnimationVacuumHarness.poseOf(rig, layer.layers) else nil
				AnimationCarryRigHarness.settle(SETTLE)
				local unshown = AnimationCarryClipHarness.shown(track, sample.at)
				if unshown ~= nil then
					table.insert(frame.problems, unshown)
				end
				local rightGap, rightInside = onPaw(rightHand, rightWrap, upper)
				local leftGap, leftInside = onPaw(leftHand, leftWrap, lower)
				frame.right, frame.left = rightGap, leftGap
				frame.clear = clearance(model, head)
				frame.out = outOf(model, head)
				frame.clip = armClip(model)
				if (frame.clip or 0) > CLIP_TOLERANCE then
					table.insert(frame.problems, string.format("arm %.3f stud into the body", frame.clip or 0))
				end
				local checks: { { side: string, distance: number?, inside: boolean, tolerance: number } } = {
					{ side = "right", distance = rightGap, inside = rightInside, tolerance = GRIP_TOLERANCE },
					{ side = "left", distance = leftGap, inside = leftInside, tolerance = LEFT_TOLERANCE },
				}
				for _, check in checks do
					local side, distance = check.side, check.distance
					if distance == nil then
						table.insert(frame.problems, `{side} hand not measured`)
					elseif distance > check.tolerance then
						table.insert(
							frame.problems,
							string.format("%s hand %.3f stud off its grip on the wand", side, distance)
						)
					elseif not check.inside then
						table.insert(frame.problems, `{side} grip is not inside its paw`)
					end
				end
				local clear = frame.clear
				if clear == nil then
					table.insert(frame.problems, "floor head not measured")
				elseif clear < -FLOOR_TOLERANCE then
					table.insert(frame.problems, string.format("floor head %.3f stud under the floor", -clear))
				end
			end
			for _, problem in frame.problems do
				table.insert(entry.problems, `{frame.name} / {frame.layer}: {problem}`)
			end
			table.insert(entry.frames, frame)
		end
		pose = nil
		if track ~= nil then
			track:Stop(0)
			track:Destroy()
		end
		if overTrack ~= nil then
			overTrack:Stop(0)
			overTrack:Destroy()
		end
	end
	layering:Disconnect()
	if rig ~= nil then
		rig.release()
	end
	tool:Destroy()
	entry.ok = #entry.problems == 0
	return entry
end

--[=[
	Holds the wand on the holders (DEFAULT_RIGS, or `options.rigs`) in every skin (or `options.skins`) and judges
	every frame.
]=]
function AnimationVacuumHarness.run(options: Options): Result
	local result: Result = { ok = true, entries = {}, notes = {} }
	local names: { string } = {}
	for name in VacuumSkinRegistry.SKINS do
		if options.skins == nil or table.find(options.skins, name) ~= nil then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for _, name in names do
		local skin = VacuumSkinRegistry.get(name)
		if skin ~= nil then
			-- A fresh carrier per skin: nothing of the last hold is left on it.
			for _, carrier in AnimationCarryRigHarness.carriers(options.rigs or DEFAULT_RIGS) do
				local entry = hold(carrier, skin)
				table.insert(result.entries, entry)
				result.ok = result.ok and entry.ok
				carrier.model:Destroy()
			end
		end
	end
	local probe = AnimationCarryRigHarness.carriers({ "StockR15" })[1]
	if probe ~= nil then
		local _, note = samples(probe)
		if note ~= nil then
			table.insert(result.notes, note)
		end
		probe.model:Destroy()
	end
	return result
end

--[=[
	The report: one line per carrier and skin, then each frame's grip gaps.
]=]
function AnimationVacuumHarness.format(result: Result): string
	local lines = { `Vacuum hold validator: {if result.ok then "PASS" else "FAIL"} ({#result.entries} holds)` }
	for _, note in result.notes do
		table.insert(lines, `  note: {note}`)
	end
	for _, entry in result.entries do
		table.insert(lines, `{if entry.ok then "PASS" else "FAIL"} {entry.rig} {entry.skin}`)
		local turns = entry.turns
		if turns ~= nil then
			table.insert(
				lines,
				string.format(
					"  aim turn: ahead %+.1f deg, look left %+.1f, look right %+.1f",
					turns.ahead,
					turns.left,
					turns.right
				)
			)
		end
		local worst: { [string]: Worst } = {}
		for _, frame in entry.frames do
			table.insert(
				lines,
				string.format(
					"    %-12s %-11s right %s  left %s  floor %s%s",
					frame.name,
					frame.layer,
					if frame.right ~= nil then string.format("%.3f", frame.right) else "-",
					if frame.left ~= nil then string.format("%.3f", frame.left) else "-",
					if frame.clear ~= nil then string.format("%+.3f", frame.clear) else "-",
					if #frame.problems > 0 then "  " .. table.concat(frame.problems, "; ") else ""
				)
			)
			local w: Worst = worst[frame.layer]
				or { right = 0, left = 0, clear = math.huge, clip = 0, out = 0, count = 0 }
			w.right = math.max(w.right, frame.right or 0)
			w.left = math.max(w.left, frame.left or 0)
			w.clear = math.min(w.clear, frame.clear or math.huge)
			w.clip = math.max(w.clip, frame.clip or 0)
			if frame.out ~= nil then
				w.out += frame.out
				w.count += 1
			end
			worst[frame.layer] = w
		end
		for _, layer in LAYERS do
			local w = worst[layer.name]
			if w ~= nil then
				table.insert(
					lines,
					string.format(
						"  worst %-11s right %.3f  left %.3f  floor %+.3f  clip %.3f  head out %.2f",
						layer.name,
						w.right,
						w.left,
						w.clear,
						w.clip,
						if w.count > 0 then w.out / w.count else 0
					)
				)
			end
		end
		for _, problem in entry.problems do
			if problem:find(":", 1, true) == nil then
				table.insert(lines, `    {problem}`)
			end
		end
	end
	return table.concat(lines, "\n")
end

return AnimationVacuumHarness
