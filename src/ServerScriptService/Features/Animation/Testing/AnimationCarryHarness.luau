--!strict
--[=[
	AnimationCarryHarness: the carry validator. Holds every carry template on every test carrier and judges what
	shows, so a template, rig or rule change that would display a hold wrong fails instead of reaching a playtest.

	For each carrier (AnimationCarryRigHarness: Pippa as EmployeeSpawnSystem installs her, and a stock R15 avatar) and
	each cargo template
	(`ReplicatedStorage.Assets.CleanupCrew.ArtKits.<kit>.cargo`, fitted to its proxy as ArtVisualSystem fits it in
	play), `run`:
	1. checks the template's contract: every visible MeshPart has PreciseConvexDecomposition collision (its rays are
	   the "visible surface"; Default was measured up to 0.44 stud off). A visible MeshPart with no mesh at all is the
	   art's problem, not the hold's (it renders nothing; the hold is planned on its collision box): a warning;
	2. plans the hold with the game's own code (AnimationCarrySystem.prepare) and keeps its AnimationCarryPoseRules
	   report;
	3. mounts and binds it as CarryServiceServer does, lets the engine's Animator solve the IK over the carrier's own
	   idle and walk clips (two walk frames), and judges the LIVE pose with the same rules.
	`format` prints the report; the spec asserts it. Needs a real runtime (TestEZ in Studio): run it with
	`Workspace.RunTests = true`, or from a server Script: `print(Harness.format(Harness.run({})))`.

	@class AnimationCarryHarness
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared.Features
local AnimationTypes = require(Shared.Animation.Data.AnimationTypes)
local AnimationCarryPoseRules = require(Shared.Animation.Rules.AnimationCarryPoseRules)
local ArtKitRegistry = require(Shared.Art.Data.ArtKitRegistry)
local ArtVisualSystem = require(Shared.Art.Systems.ArtVisualSystem)
local CargoConstants = require(Shared.Cargo.Data.CargoConstants)
local CargoRegistry = require(Shared.Cargo.Data.CargoRegistry)
local CarryFormulas = require(Shared.Carry.Utils.CarryFormulas)
local AnimationCarrySystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySystem)
local AnimationCarrySurfaceSystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySurfaceSystem)
local AnimationCarryRigHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryRigHarness)

type Report = AnimationCarryPoseRules.Report
type Hold = AnimationTypes.CarryHold

type Carrier = AnimationCarryRigHarness.Carrier
export type Entry = {
	rig: string,
	kind: string,
	style: string?,
	planned: Report?,
	-- The live pose's report per sampled frame ("idle", "walk A", "walk B").
	live: { [string]: Report },
	-- The template's contract failures (collision fidelity), and what is wrong with its art but not its hold.
	contract: { string },
	warnings: { string },
	ok: boolean,
	-- With `Options.record`: per live frame, every part of the carrier and the item's pivot, relative to the carrier's
	-- root, as they showed (for a contact sheet rendered from them).
	poses: { [string]: { [string]: CFrame } },
}
export type Result = { ok: boolean, entries: { Entry }, skipped: { string } }
export type Options = { rigs: { string }?, kinds: { string }?, live: boolean?, keep: boolean?, record: boolean? }

local AnimationCarryHarness = {}

-- Frames to let the Animator settle after a change.
local SETTLE = 4
-- The walk frames sampled, as fractions of the clip.
local WALK_FRAMES: { { name: string, at: number } } = { { name = "walk A", at = 0.25 }, { name = "walk B", at = 0.6 } }
local settle = AnimationCarryRigHarness.settle
local folder = AnimationCarryRigHarness.folder
local animator = AnimationCarryRigHarness.animator

local function cargoFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local crew = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	local kits = if crew ~= nil then crew:FindFirstChild("ArtKits") else nil
	local kit = if kits ~= nil then kits:FindFirstChild(ArtKitRegistry.DEFAULT_KIT) else nil
	return if kit ~= nil then kit:FindFirstChild("cargo") else nil
end

--[=[
	The carry templates to validate: every model in the default kit's cargo folder (so a new template is validated
	the moment it lands), by name.
]=]
function AnimationCarryHarness.kinds(only: { string }?): { string }
	local found: { string } = {}
	local cargo = cargoFolder()
	if cargo == nil then
		return found
	end
	for _, child in cargo:GetChildren() do
		if child:IsA("Model") and (only == nil or table.find(only, child.Name) ~= nil) then
			table.insert(found, child.Name)
		end
	end
	table.sort(found)
	return found
end

--[=[
	The template's contract failures (a visible MeshPart without precise collision) and warnings (a visible MeshPart
	with no mesh).
]=]
function AnimationCarryHarness.contract(kind: string): ({ string }, { string })
	local failures: { string } = {}
	local warnings: { string } = {}
	local cargo = cargoFolder()
	local template = if cargo ~= nil then cargo:FindFirstChild(kind) else nil
	if template == nil then
		return { "no template" }, warnings
	end
	for _, descendant in template:GetDescendants() do
		if descendant:IsA("MeshPart") and descendant.Transparency < 1 then
			if descendant.MeshContent.SourceType == Enum.ContentSourceType.None then
				table.insert(warnings, `{descendant.Name} has no mesh (it renders nothing)`)
			elseif descendant.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition then
				table.insert(
					failures,
					`{descendant.Name} collision is {descendant.CollisionFidelity.Name}, not PreciseConvexDecomposition`
				)
			end
		end
	end
	return failures, warnings
end

--[=[
	The item as the game builds it: an invisible proxy of its cargo size class (or the template's own size) with the
	art fitted inside, standing on the floor in front of `carrier`; and its carry weight. Nil without the template.
]=]
function AnimationCarryHarness.item(kind: string, carrier: Model): (BasePart?, number)
	local def = CargoRegistry.get(kind)
	local cargo = cargoFolder()
	local template = if cargo ~= nil then cargo:FindFirstChild(kind) else nil
	local baseSize = if template ~= nil then template:GetAttribute("BaseSize") else nil
	local size = if def ~= nil then def.partSize elseif typeof(baseSize) == "Vector3" then baseSize else nil
	if size == nil then
		return nil, 0
	end
	local root = carrier:FindFirstChild("HumanoidRootPart")
	local humanoid = carrier:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil, 0
	end
	local floor = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local proxy = Instance.new("Part")
	proxy.Name = kind
	proxy.Size = size
	proxy.Anchored = true
	proxy.CanCollide = false
	proxy.CFrame = CFrame.new(root.Position + Vector3.new(0, 0, -8))
		* CFrame.new(0, floor - root.Position.Y + size.Y / 2, 0)
	proxy.Parent = folder()
	if ArtVisualSystem.attach(proxy, "cargo", kind) == nil then
		proxy:Destroy()
		return nil, 0
	end
	local weight = if def ~= nil then CargoConstants.WEIGHT[def.size] or 0 else 0
	return proxy, weight
end

-- The live hold: the planned one with the arms and the item where the engine shows them now.
local function liveHold(carrier: Model, hold: Hold, target: PVInstance, box: CFrame): Hold?
	local space = AnimationCarrySystem.liveSpace(carrier, hold)
	if space == nil then
		return nil
	end
	local right = AnimationCarrySystem.livePose(carrier, "Right", space)
	local left = if hold.leftPose ~= nil then AnimationCarrySystem.livePose(carrier, "Left", space) else nil
	if right == nil then
		return nil
	end
	return {
		style = hold.style,
		offset = space(target:GetPivot() * box),
		right = hold.right,
		left = hold.left,
		rightPose = right,
		leftPose = left,
		mount = hold.mount,
	}
end

local function judgeLive(carrier: Model, hold: Hold, target: BasePart, box: CFrame): Report?
	local rig = AnimationCarrySystem.measure(carrier)
	local live = liveHold(carrier, hold, target, box)
	if rig == nil or live == nil then
		return nil
	end
	local _, size = AnimationCarrySystem.visibleBox(target)
	local space = AnimationCarrySystem.liveSpace(carrier, hold)
	local turn = if space ~= nil then AnimationCarrySystem.liveTorsoTurn(carrier, space) else CFrame.identity
	local surface = AnimationCarrySurfaceSystem.open(target, target:GetPivot() * box)
	local report = AnimationCarryPoseRules.check(rig, live, surface.probe, size, turn)
	surface.release()
	return report
end

-- Holds `kind` on `carrier` as CarryServiceServer does and judges the plan and the live frames.
local function hold(carrier: Carrier, kind: string, live: boolean, record: boolean): Entry
	local contract, warnings = AnimationCarryHarness.contract(kind)
	local entry: Entry = {
		rig = carrier.name,
		kind = kind,
		live = {},
		contract = contract,
		warnings = warnings,
		ok = false,
		poses = {},
	}
	local target, weight = AnimationCarryHarness.item(kind, carrier.model)
	if target == nil then
		table.insert(entry.contract, "could not build the item")
		return entry
	end
	local prepared = AnimationCarrySystem.prepare(carrier.model, target, kind, weight)
	if prepared == nil then
		table.insert(entry.contract, "no hold planned")
		target:Destroy()
		return entry
	end
	entry.style = prepared.hold.style
	entry.planned = prepared.report
	local ok = prepared.report.ok and #entry.contract == 0
	if live then
		for _, bodyPart in target:GetDescendants() do
			if bodyPart:IsA("BasePart") then
				bodyPart.Massless = true
			end
		end
		target.Massless = true
		target:PivotTo(prepared.pivot)
		local root = target
		local boxInRoot = root.CFrame:ToObjectSpace(target:GetPivot() * prepared.box)
		local mount = AnimationCarrySystem.mount(carrier.model, root, prepared.hold, boxInRoot)
		local controller = AnimationCarrySystem.bind(carrier.model, root, prepared.hold)
		-- As CarryServiceServer joins it; a pushed item's slide is CarryPushSystem's, applied here as a client would.
		local follow: Motor6D? = nil
		local rest: Vector3? = nil
		if mount ~= nil then
			local joint: JointInstance = if mount.joint ~= "weld" then Instance.new("Motor6D") else Instance.new("Weld")
			joint.Part0 = mount.part
			joint.Part1 = root
			joint.C0 = mount.c0
			joint.C1 = mount.c1
			joint.Parent = root
			root.Anchored = false
			if mount.joint == "follow" and joint:IsA("Motor6D") then
				follow, rest = joint, mount.torsoRest
			end
		end
		local carrierRoot = carrier.model:FindFirstChild("HumanoidRootPart")
		local carrierTorso = carrier.model:FindFirstChild("UpperTorso")
		local function slide()
			if
				follow ~= nil
				and rest ~= nil
				and carrierRoot ~= nil
				and carrierRoot:IsA("BasePart")
				and carrierTorso ~= nil
				and carrierTorso:IsA("BasePart")
			then
				follow.Transform = CarryFormulas.pushFollow(
					carrierRoot.CFrame:PointToObjectSpace(carrierTorso.Position) - rest,
					follow.C0
				)
			end
		end
		local track: AnimationTrack? = nil
		local animatorOf = animator(carrier.model)
		local function pose(id: string?, at: number?)
			if track ~= nil then
				track:Stop(0)
				track:Destroy()
				track = nil
			end
			if id ~= nil and animatorOf ~= nil then
				local animation = Instance.new("Animation")
				animation.AnimationId = id
				local loaded = animatorOf:LoadAnimation(animation)
				loaded:Play(0)
				loaded:AdjustSpeed(0)
				if at ~= nil and loaded.Length > 0 then
					loaded.TimePosition = loaded.Length * at
				end
				track = loaded
			end
			settle(SETTLE)
			slide()
			settle(SETTLE)
		end
		local frames: { { name: string, id: string?, at: number? } } =
			{ { name = "idle", id = carrier.idle, at = 0.3 } }
		for _, walk in WALK_FRAMES do
			table.insert(frames, { name = walk.name, id = carrier.walk, at = walk.at })
		end
		for _, frame in frames do
			pose(frame.id, frame.at)
			local report = judgeLive(carrier.model, prepared.hold, target, prepared.box)
			local carrierRootPart = carrier.model:FindFirstChild("HumanoidRootPart")
			if record and carrierRootPart ~= nil and carrierRootPart:IsA("BasePart") then
				local shown: { [string]: CFrame } =
					{ ["@item"] = carrierRootPart.CFrame:ToObjectSpace(target:GetPivot()) }
				for _, bodyPart in carrier.model:GetChildren() do
					if bodyPart:IsA("BasePart") then
						shown[bodyPart.Name] = carrierRootPart.CFrame:ToObjectSpace(bodyPart.CFrame)
					end
				end
				entry.poses[frame.name] = shown
			end
			if report ~= nil then
				entry.live[frame.name] = report
				ok = ok and report.ok
			else
				ok = false
			end
		end
		pose(nil, nil)
		if controller ~= nil then
			controller.destroy()
		end
	end
	target:Destroy()
	entry.ok = ok
	return entry
end

--[=[
	Validates every carry template on every carrier (see the class). `options.live` (default true) also binds and
	judges the engine's live pose; `options.keep` leaves the carriers built.
]=]
function AnimationCarryHarness.run(options: Options): Result
	local result: Result = { ok = true, entries = {}, skipped = {} }
	local kinds = AnimationCarryHarness.kinds(options.kinds)
	if #kinds == 0 then
		table.insert(result.skipped, "no cargo templates in this place (ReplicatedStorage.Assets is art-owned)")
	end
	local carriers = AnimationCarryRigHarness.carriers(options.rigs)
	if #carriers < 2 and options.rigs == nil then
		table.insert(result.skipped, "no employee template in this place: only the stock avatar is validated")
	end
	for _, carrier in carriers do
		for _, kind in kinds do
			local entry = hold(carrier, kind, options.live ~= false, options.record == true)
			table.insert(result.entries, entry)
			result.ok = result.ok and entry.ok
		end
		if not options.keep then
			carrier.model:Destroy()
		end
	end
	return result
end

local function describe(report: Report?): string
	if report == nil then
		return "-"
	end
	local function side(name: string, measured: AnimationCarryPoseRules.Side?): string
		if measured == nil then
			return ""
		end
		local a = measured.angles
		return string.format(
			" %s palm %s elbow %.0f wrist %.0f roll %s",
			name,
			if measured.contact ~= nil then string.format("%+.3f", measured.contact) else "?",
			a.flex,
			a.wristFlex,
			if a.roll ~= nil then string.format("%.0f", a.roll) else "-"
		)
	end
	return string.format(
		"floor %+.2f chin %+.2f head %.2f%s%s",
		report.floorGap,
		report.overChin,
		report.headDepth,
		side("R", report.right),
		side("L", report.left)
	)
end

--[=[
	The result as a printable report: one line per carrier and template, then every violation.
]=]
function AnimationCarryHarness.format(result: Result): string
	local lines: { string } = { `Carry validator: {if result.ok then "PASS" else "FAIL"} ({#result.entries} holds)` }
	for _, note in result.skipped do
		table.insert(lines, `  skipped: {note}`)
	end
	for _, entry in result.entries do
		table.insert(
			lines,
			string.format(
				"  %-4s %-9s %-14s %-6s plan: %s",
				if entry.ok then "ok" else "FAIL",
				entry.rig,
				entry.kind,
				entry.style or "-",
				describe(entry.planned)
			)
		)
		for name, report in entry.live do
			table.insert(lines, string.format("%40s live %-7s %s", "", name, describe(report)))
		end
		local problems: { string } = table.clone(entry.contract)
		if entry.planned ~= nil then
			for _, violation in entry.planned.violations do
				table.insert(problems, `plan {violation}`)
			end
		end
		for name, report in entry.live do
			for _, violation in report.violations do
				table.insert(problems, `{name} {violation}`)
			end
		end
		for _, problem in problems do
			table.insert(lines, `        ! {problem}`)
		end
		for _, warning in entry.warnings do
			table.insert(lines, `        warning (art, not the hold): {warning}`)
		end
	end
	return table.concat(lines, "\n")
end

return AnimationCarryHarness
