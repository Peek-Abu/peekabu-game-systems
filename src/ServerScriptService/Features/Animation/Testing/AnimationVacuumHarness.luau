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
	   shown at its time and full weight (AnimationCarryClipHarness). In every frame the RightGripAttachment must be
	   on the wand's GripUpper and the LeftGripAttachment on its GripLower (the grip contract), within GRIP_TOLERANCE.
	`format` prints the report; the spec asserts it. Needs a real runtime (TestEZ in Studio): run it with
	`Workspace.RunTests = true`, or from a server Script: `print(Harness.format(Harness.run({})))`.

	@class AnimationVacuumHarness
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local AnimationCarryClipHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryClipHarness)
local AnimationCarryRigHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryRigHarness)
local VacuumToolSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumToolSystem)
local VacuumVisualSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumVisualSystem)

type Carrier = AnimationCarryRigHarness.Carrier

export type Frame = {
	state: string,
	name: string,
	-- How far each hand's grip attachment is from its grip on the wand (studs); nil when it could not be measured.
	right: number?,
	left: number?,
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
export type Options = { rigs: { string }?, skins: { string }? }

local AnimationVacuumHarness = {}

-- How far a hand's grip attachment may sit from its grip on the wand (studs).
local GRIP_TOLERANCE = 0.05
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

local function handGrip(model: Model, side: string): Attachment?
	local hand = model:FindFirstChild(side .. "Hand")
	local found = if hand ~= nil then hand:FindFirstChild(side .. "GripAttachment") else nil
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

local function gap(a: Attachment?, b: Attachment?): number?
	return if a ~= nil and b ~= nil then (a.WorldPosition - b.WorldPosition).Magnitude else nil
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
	local right, left = handGrip(model, "Right"), handGrip(model, "Left")
	if upper == nil or lower == nil then
		table.insert(entry.problems, "the wand has no GripUpper / GripLower (the grip contract)")
	end
	-- 3. Every frame, live.
	local list, _ = samples(carrier)
	for _, sample in list do
		local frame: Frame = { state = sample.state, name = sample.name, problems = {} }
		local id = sample.id
		if id == nil then
			table.insert(frame.problems, "no clip")
		else
			local track, err = AnimationCarryClipHarness.show(animator, id, sample.at)
			local overTrack: AnimationTrack? = nil
			local over = sample.over
			if over ~= nil then
				overTrack = AnimationCarryClipHarness.show(animator, over, 0.5)
			end
			if track == nil then
				table.insert(frame.problems, err or "clip not shown")
			else
				AnimationCarryRigHarness.settle(SETTLE)
				local unshown = AnimationCarryClipHarness.shown(track, sample.at)
				if unshown ~= nil then
					table.insert(frame.problems, unshown)
				end
				frame.right = gap(right, upper)
				frame.left = gap(left, lower)
				local checks: { { side: string, distance: number? } } = {
					{ side = "right", distance = frame.right },
					{ side = "left", distance = frame.left },
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
					end
				end
				track:Stop(0)
				track:Destroy()
			end
			if overTrack ~= nil then
				overTrack:Stop(0)
				overTrack:Destroy()
			end
		end
		for _, problem in frame.problems do
			table.insert(entry.problems, `{frame.name}: {problem}`)
		end
		table.insert(entry.frames, frame)
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
		for _, frame in entry.frames do
			table.insert(
				lines,
				string.format(
					"    %-12s right %s  left %s%s",
					frame.name,
					if frame.right ~= nil then string.format("%.3f", frame.right) else "-",
					if frame.left ~= nil then string.format("%.3f", frame.left) else "-",
					if #frame.problems > 0 then "  " .. table.concat(frame.problems, "; ") else ""
				)
			)
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
