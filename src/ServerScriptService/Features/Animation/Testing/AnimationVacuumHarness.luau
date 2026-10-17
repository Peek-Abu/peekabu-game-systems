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
	4. in each frame, lays every motion layer on the rig at its extremes (LAYERS: rest, aim up, aim down, the brace
	   and the brace with each aim, the pop's recoil and its rebound, the shimmy each way, the wand's sway each way
	   and all at once; VacuumMotionRigSystem, exactly as every client does, in PreSimulation after the
	   Animator's IK) and judges each: each paw's wrap point (VacuumVisualSystem.wrapOf, inside the paw) must be on
	   its grip, the right on the wand's GripUpper and the left on its GripLower (the grip contract), within
	   GRIP_TOLERANCE; each grip must lie inside its paw (the paw closes round the wand); and the floor head's
	   lowest corner must be over the floor (FLOOR_TOLERANCE).
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
	problems: { string },
}
export type Entry = {
	rig: string,
	skin: string,
	frames: { Frame },
	problems: { string },
	ok: boolean,
}
export type Result = { ok: boolean, entries: { Entry }, notes: { string } }
-- The worst of a layer's frames: the furthest each paw sat from its grip, and the floor head's least clearance.
type Worst = { right: number, left: number, clear: number }
export type Options = { rigs: { string }?, skins: { string }? }

local AnimationVacuumHarness = {}

-- How far a paw's wrap point may sit from its grip on the wand (studs).
local GRIP_TOLERANCE = 0.05
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
	}
end
local UP = VacuumMotionConstants.aim.maxUp
-- The biggest kick (a pile at maxScale, at its peak).
local KICK = VacuumMotionConstants.kick.maxScale
local SWAY_YAW = VacuumMotionConstants.sway.maxYaw
local SWAY_PITCH = VacuumMotionConstants.sway.maxPitch
local LAYERS: { { name: string, layers: VacuumMotionFormulas.Layers } } = {
	{ name = "rest", layers = layered({}) },
	{ name = "aim up", layers = layered({ raise = UP }) },
	{ name = "aim down", layers = layered({ reach = 1 }) },
	{ name = "brace", layers = layered({ brace = 1 }) },
	{ name = "brace+down", layers = layered({ reach = 1, brace = 1 }) },
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
	The pose VacuumMotionSystem lays on a bound rig for `layers` (its springs settled there).
]=]
function AnimationVacuumHarness.poseOf(
	rig: VacuumMotionRigSystem.Rig,
	layers: VacuumMotionFormulas.Layers
): VacuumMotionRigSystem.Pose
	local drop, lean = VacuumMotionFormulas.body(layers.brace)
	local wand = VacuumMotionFormulas.wand(
		rig.rest,
		VacuumMotionFormulas.offsetOf(layers),
		VacuumMotionConstants.floorMargin,
		VacuumMotionFormulas.motion(rig.rest.waist, drop, lean)
	)
	return { wand = wand, drop = drop, lean = lean }
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
				local checks: { { side: string, distance: number?, inside: boolean } } = {
					{ side = "right", distance = rightGap, inside = rightInside },
					{ side = "left", distance = leftGap, inside = leftInside },
				}
				for _, check in checks do
					local side, distance = check.side, check.distance
					if distance == nil then
						table.insert(frame.problems, `{side} hand not measured`)
					elseif distance > GRIP_TOLERANCE then
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
			local w: Worst = worst[frame.layer] or { right = 0, left = 0, clear = math.huge }
			w.right = math.max(w.right, frame.right or 0)
			w.left = math.max(w.left, frame.left or 0)
			w.clear = math.min(w.clear, frame.clear or math.huge)
			worst[frame.layer] = w
		end
		for _, layer in LAYERS do
			local w = worst[layer.name]
			if w ~= nil then
				table.insert(
					lines,
					string.format(
						"  worst %-11s right %.3f  left %.3f  floor %+.3f",
						layer.name,
						w.right,
						w.left,
						w.clear
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
