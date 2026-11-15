--!strict
--[=[
	OccupantWatchSystem: the server's "watched" check for a freeze kind (Bramble; OccupantWatchRules, OccupantHeadRules).
	Active only while the Occupant rig's kind (OccupantKindRegistry.kindOf, the KIND_ATTRIBUTE attribute) has the freeze
	twist; Harlow's rig has none, so for him this system does nothing and `freezeFor` is nil.

	- Camera reports in: each client's OccupantEvents.CameraReport (rate-limited, checked finite, the look made unit),
	  stamped with the server's receive time; a player's report is dropped when they leave.
	- Every FREEZE_CHECK_INTERVAL (10 Hz): for each crew member, the cheap checks first (alive, standing, not hidden,
	  not in the truck, a fresh report, the camera near their head, a body point in the look cone and range), then the
	  rays (head to camera, camera to its head, chest and knees) with RaycastParams that exclude every character, the rig
	  and the glass sight passes through. Any watcher freezes it (OccupantWatchRules.advance).
	- Publishes: the freeze to the brain (`freezeFor`, read into OccupantTypes.Senses by OccupantServiceServer), the
	  FROZEN_ATTRIBUTE on the rig (the client's trail), and on a change wakes the NPC so it holds or moves on its very next
	  frame. The head's target (OccupantHeadRules: the brain's chase or search target, else the nearest crew member it saw
	  or heard; the 10 s swap) goes out as the HEAD_TARGET_ATTRIBUTE UserId (0 = nobody). On the check it unfreezes, the
	  kid the head held (OccupantHeadRules.lunge: not hidden, not knocked down) is kept for the brain's next think
	  (`takeLunge`, read into Senses.lunge): "when nobody watches, it lunges at that kid".

	`parseReport`, `points` and `freezes` are specced; the rest is a Players/raycast/ByteNet shell around the specced
	OccupantWatchRules and OccupantHeadRules.

	@class OccupantWatchSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantServer = ServerScriptService.Features.Occupant
local NoiseRules = require(ReplicatedStorage.Shared.Features.Noise.Rules.NoiseRules)
local NoiseTypes = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantEvents = require(OccupantShared.Net.OccupantEvents)
local OccupantKindRegistry = require(OccupantShared.Data.OccupantKindRegistry)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local VacuumMotionConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local OccupantHeadRules = require(OccupantServer.Rules.OccupantHeadRules)
local OccupantPerchRules = require(OccupantServer.Rules.OccupantPerchRules)
local OccupantWatchRules = require(OccupantServer.Rules.OccupantWatchRules)
local OccupantSightUtils = require(OccupantServer.Utils.OccupantSightUtils)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)

-- The rig as OccupantRigSystem builds it (only the parts this system reads).
export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
}

-- What OccupantServiceServer hands in: the current rig, the brain's mind and the truck's box.
export type Source = {
	rig: () -> Rig?,
	mind: () -> OccupantTypes.Mind?,
	zone: () -> OccupantTypes.Zone?,
}

type Report = OccupantWatchRules.Report

local reports: { [Player]: Report } = {}
local heardAt: { [number]: number } = {}
local freeze: OccupantWatchRules.Freeze = OccupantWatchRules.newFreeze()
local head: OccupantHeadRules.Head = OccupantHeadRules.newHead()
-- The kid to lunge at, from the check it unfroze until the brain takes it (nil: none).
local pendingLunge: number? = nil
-- The rig being watched (nil while the rig is not a freeze kind).
local watchedModel: Model? = nil
local source: Source? = nil
local stoppers: { () -> () } = {}
local counters = { checks = 0, freezes = 0, reports = 0 }

local OccupantWatchSystem = {}

local function finite(vector: Vector3): boolean
	return vector.X == vector.X
		and vector.Y == vector.Y
		and vector.Z == vector.Z
		and math.abs(vector.X) < math.huge
		and math.abs(vector.Y) < math.huge
		and math.abs(vector.Z) < math.huge
end

-- The camera report as it arrives (OccupantEvents.CameraReport).
export type ReportData = { position: Vector3, look: Vector3, up: Vector3, fov: number, aspect: number }

local function number(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

--[=[
	A camera report as the server keeps it (OccupantWatchRules.Report, less its time): its position, unit look, an up
	square to the look (world up when the sent one is broken or along the look) and its half-screen tangents
	(OccupantWatchRules.screen: the FOV and aspect held to a real screen). Nil when the position, look, FOV or aspect is
	not finite, or the look is (near) zero.
]=]
function OccupantWatchSystem.parseReport(data: ReportData): Report?
	local position, look, up = data.position, data.look, data.up
	if typeof(position) ~= "Vector3" or typeof(look) ~= "Vector3" then
		return nil
	end
	if not finite(position) or not finite(look) or look.Magnitude < 1e-3 then
		return nil
	end
	if not number(data.fov) or not number(data.aspect) then
		return nil
	end
	local unit = look.Unit
	local sent = if typeof(up) == "Vector3" and finite(up) then up else Vector3.yAxis
	local square = sent - unit * sent:Dot(unit)
	if square.Magnitude < 1e-3 then
		-- A broken up, or one along the look: square world up (or, looking straight up or down, world forward).
		local world = if math.abs(unit.Y) < 0.99 then Vector3.yAxis else Vector3.zAxis
		square = world - unit * world:Dot(unit)
	end
	local tanV, tanH = OccupantWatchRules.screen(data.fov, data.aspect)
	return { position = position, look = unit, up = square.Unit, tanV = tanV, tanH = tanH, receivedAt = 0 }
end

-- How far over the ground its feet point sits (a ray to the ground itself would end in the floor).
OccupantWatchSystem.FEET_LIFT = 0.2

--[=[
	The points of the rig a watcher may see (owner 11-14: any of it on the screen counts): the centre of every visible
	part of its body (not the invisible root or any part with Transparency 1), the top of its head, and its feet (the
	ground under its root, FEET_LIFT up).
]=]
function OccupantWatchSystem.points(rig: Rig): { Vector3 }
	local points: { Vector3 } = {}
	for _, item in rig.model:GetDescendants() do
		if item:IsA("BasePart") and item ~= rig.root and item.Transparency < 1 then
			table.insert(points, item.Position)
		end
	end
	local skull = rig.head
	table.insert(points, (skull.CFrame * CFrame.new(0, skull.Size.Y / 2, 0)).Position)
	local root = rig.root
	local ground = root.Size.Y / 2 + rig.humanoid.HipHeight - OccupantWatchSystem.FEET_LIFT
	table.insert(points, root.Position - Vector3.new(0, ground, 0))
	return points
end

-- Whether `model`'s kind has the freeze twist.
function OccupantWatchSystem.freezes(model: Model): boolean
	return OccupantKindRegistry.freezes(OccupantKindRegistry.kindOf(model))
end

--[=[
	The freeze the brain reads for `model`: nil unless this system is watching that rig (a freeze kind).
]=]
function OccupantWatchSystem.freezeFor(model: Model): OccupantWatchRules.Freeze?
	if watchedModel ~= model then
		return nil
	end
	return table.clone(freeze)
end

--[=[
	The kid `model` lunges at (OccupantHeadRules.lunge), once: taken by the brain's first think after it unfroze. Nil
	unless this system is watching that rig and it just unfroze with a valid head target.
]=]
function OccupantWatchSystem.takeLunge(model: Model): number?
	if watchedModel ~= model then
		return nil
	end
	local lunge = pendingLunge
	pendingLunge = nil
	return lunge
end

-- Whether the rig being watched is frozen right now (false when there is none).
function OccupantWatchSystem.frozen(): boolean
	return watchedModel ~= nil and freeze.frozen
end

local onReport = RequestHandler.wrap({
	name = "OccupantCameraReport",
	-- 10 a second, with room for a burst after a hitch.
	rateLimit = { maxRequests = 20, windowSeconds = 1 },
	onReject = "count",
	validate = function(data: ReportData, _player: Player): (boolean, string?, Report?)
		local report = OccupantWatchSystem.parseReport(data)
		if report == nil then
			return false, "bad camera report", nil
		end
		report.receivedAt = os.clock()
		return true, nil, report
	end,
	handler = function(_data: ReportData, player: Player, report: Report?)
		if report ~= nil and watchedModel ~= nil then
			reports[player] = report
			counters.reports += 1
		end
	end,
})

-- The rays' params: every character, the rig and the glass sight passes through are skipped; CanCollide is respected,
-- so an open door never blocks and a closed one does.
local function sightParams(rig: Rig): RaycastParams
	local exclude: { Instance } = { rig.model }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(exclude, character)
		end
	end
	for _, pane in CollectionService:GetTagged(OccupantConstants.SIGHT_THROUGH_TAG) do
		table.insert(exclude, pane)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

local function clearLine(from: Vector3, to: Vector3, params: RaycastParams): boolean
	return Workspace:Raycast(from, to - from, params) == nil
end

-- The body points on the camera's screen and in range, and ahead of the viewer's head (`eyes`) when one is given (only
-- these are worth a ray; OccupantWatchRules.ahead: nothing behind the kid's back counts).
local function onScreen(report: Report, points: { Vector3 }, eyes: Vector3?): { Vector3 }
	local shown: { Vector3 } = {}
	for _, point in points do
		if
			OccupantWatchRules.inRange(report.position, point)
			and OccupantWatchRules.onScreen(report, point)
			and (eyes == nil or OccupantWatchRules.ahead(eyes, report.look, point))
		then
			table.insert(shown, point)
		end
	end
	return shown
end

local function inView(report: Report, points: { Vector3 }): boolean
	return #onScreen(report, points) > 0
end

-- Every perch part's spot, as measured on the map, once per part (the props never move during a run).
local measured: { [BasePart]: OccupantTypes.Perch } = {}
setmetatable(measured, { __mode = "k" })

-- How far up a ceiling is looked for; the heights over the top a landing's line out runs (just over the top surface,
-- where his tucked feet start, and about his body), and the radius of those lines; how far down a floor is looked for;
-- and how high over the top his body sits (for sight checks and distances). The low line rules out a landing along a
-- bank of props: Shift run 11-14, a drop along the lockers passed just over the next locker's top (its hitbox stands
-- 0.26 over the visible top he sits on).
local CEILING_LOOK = 60
local LANDING_RADIUS = 1.2
local LANDING_LINE_HEIGHTS = { LANDING_RADIUS + 0.05, 2 }
local FLOOR_LOOK = 40
local BODY_UP = 2

--[=[
	Measures the perch spot of `instance` (a PERCH_TAG part, a child of its prop's proxy): the centre of the prop's
	visible top (its ArtVisual's box, else the proxy's: the owner's play-check 11-14 had him floating over the hitbox),
	the room over it to the ceiling, and its landings: each OccupantPerchRules.landingCandidate PERCH_LANDING_OUT past
	the prop's edge with clear, body-wide lines out to it from just over the top and higher, and a floor under it, lower
	than the top
	(so the drop never passes through a wall or lands on another prop). Rays skip the prop itself, the rigs and the crew.
]=]
local function measure(instance: BasePart, rig: Rig): OccupantTypes.Perch
	local known = measured[instance]
	if known ~= nil then
		return known
	end
	local proxy = instance.Parent
	local exclude: { Instance } = { rig.model }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(exclude, character)
		end
	end
	local frame, size = instance.CFrame, instance.Size
	if proxy ~= nil and proxy:IsA("BasePart") then
		table.insert(exclude, proxy)
		frame, size = proxy.CFrame, proxy.Size
		local visual = proxy:FindFirstChild("ArtVisual")
		if visual ~= nil and visual:IsA("Model") then
			frame, size = visual:GetBoundingBox()
		end
	end
	local top = (frame * CFrame.new(0, size.Y / 2, 0)).Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local up = Workspace:Raycast(top + Vector3.new(0, 0.05, 0), Vector3.new(0, CEILING_LOOK, 0), params)
	local landings: { Vector3 } = {}
	local reach = math.max(size.X, size.Z) / 2 + OccupantConstants.PERCH_LANDING_OUT
	for _, spot in OccupantPerchRules.landingCandidates(top, reach) do
		local out = (spot - top) * Vector3.new(1, 0, 1)
		local clear = true
		for _, height in LANDING_LINE_HEIGHTS do
			if Workspace:Spherecast(top + Vector3.new(0, height, 0), LANDING_RADIUS, out, params) ~= nil then
				clear = false
				break
			end
		end
		if not clear then
			continue
		end
		local floor = Workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -FLOOR_LOOK, 0), params)
		if floor ~= nil and floor.Position.Y < top.Y - 1 then
			table.insert(landings, floor.Position)
		end
	end
	local perch: OccupantTypes.Perch = {
		id = instance:GetFullName(),
		top = top,
		at = top + Vector3.new(0, BODY_UP, 0),
		headroom = if up ~= nil then up.Position.Y - top.Y else math.huge,
		landings = landings,
	}
	measured[instance] = perch
	return perch
end

--[=[
	Every perch on the map (OccupantConstants.PERCH_TAG parts in the Workspace, measured once: `measure`) and
	whether any crew camera sees it right now: a fresh camera report (anyone's, hidden or not) with the top in its look
	cone and range and a clear ray to it (B4, OccupantPerchRules: he only goes up where nobody can see). Empty when
	this system is not watching `rig`.
]=]
function OccupantWatchSystem.perches(rig: Rig): { OccupantTypes.PerchView }
	local views: { OccupantTypes.PerchView } = {}
	if watchedModel ~= rig.model then
		return views
	end
	local now = os.clock()
	local params = sightParams(rig)
	for _, instance in CollectionService:GetTagged(OccupantConstants.PERCH_TAG) do
		if not instance:IsA("BasePart") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local perch = measure(instance, rig)
		local seen = false
		for _, report in reports do
			if
				OccupantWatchRules.fresh(report, now)
				and inView(report, { perch.at })
				and clearLine(report.position, perch.at, params)
			then
				seen = true
				break
			end
		end
		table.insert(views, { perch = perch, seen = seen })
	end
	return views
end

-- Whether `player` watches the rig now: the cheap checks, then the rays.
local function watches(
	player: Player,
	viewer: OccupantWatchRules.Viewer,
	points: { Vector3 },
	params: RaycastParams,
	now: number
): boolean
	local report = reports[player]
	if
		report == nil
		or not OccupantWatchRules.eligible(viewer)
		or not OccupantWatchRules.fresh(report, now)
		or not OccupantWatchRules.cameraNear(viewer.head, report.position)
		or #onScreen(report, points, viewer.head) == 0
	then
		return false
	end
	viewer.report = report
	viewer.cameraClear = clearLine(viewer.head, report.position, params)
	if viewer.cameraClear then
		-- Rays only to the points on the screen, and none after the first clear one.
		for _, point in onScreen(report, points, viewer.head) do
			local clear = clearLine(report.position, point, params)
			table.insert(viewer.sightlines, { point = point, clear = clear })
			if clear then
				break
			end
		end
	end
	return OccupantWatchRules.watching(viewer, now)
end

local function setAttributes(model: Model, frozen: boolean, target: number)
	if model.Parent == nil then
		return
	end
	if model:GetAttribute(OccupantConstants.FROZEN_ATTRIBUTE) ~= frozen then
		model:SetAttribute(OccupantConstants.FROZEN_ATTRIBUTE, frozen)
	end
	if model:GetAttribute(OccupantConstants.HEAD_TARGET_ATTRIBUTE) ~= target then
		model:SetAttribute(OccupantConstants.HEAD_TARGET_ATTRIBUTE, target)
	end
end

-- Stops watching: a fresh freeze and head, the reports and the heard memory dropped, the rig's attributes cleared.
local function reset()
	local model = watchedModel
	watchedModel = nil
	freeze = OccupantWatchRules.newFreeze()
	head = OccupantHeadRules.newHead()
	pendingLunge = nil
	table.clear(reports)
	table.clear(heardAt)
	if model ~= nil then
		setAttributes(model, false, 0)
	end
end

-- One check at `now` (see the class doc).
local function check(now: number)
	local current = source
	local rig = if current ~= nil then current.rig() else nil
	if rig == nil or not OccupantWatchSystem.freezes(rig.model) then
		if watchedModel ~= nil then
			reset()
		end
		return
	end
	if watchedModel ~= rig.model then
		reset()
		watchedModel = rig.model
	end
	counters.checks += 1
	local mind = if current ~= nil then current.mind() else nil
	local zone = if current ~= nil then current.zone() else nil
	local points = OccupantWatchSystem.points(rig)
	local params = sightParams(rig)
	local watched = false
	local crew: { OccupantHeadRules.Member } = {}
	for _, player in RoundServiceServer:participants() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local headPart = if character ~= nil then character:FindFirstChild("Head") else nil
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if
			root ~= nil
			and root:IsA("BasePart")
			and headPart ~= nil
			and headPart:IsA("BasePart")
			and humanoid ~= nil
		then
			local hidden = HideServiceServer:isHidden(player)
			local heard = heardAt[player.UserId]
			table.insert(crew, {
				userId = player.UserId,
				position = root.Position,
				hidden = hidden,
				noticed = (mind ~= nil and mind.watched[player.UserId] ~= nil)
					or (heard ~= nil and now < heard + OccupantConstants.HEAD_HEARD_SECONDS),
				downed = DeathServiceServer:isDown(player) or DeathServiceServer:isDead(player),
			})
			if not watched then
				local viewer: OccupantWatchRules.Viewer = {
					alive = humanoid.Health > 0 and not DeathServiceServer:isDead(player),
					downed = DeathServiceServer:isDown(player),
					hidden = hidden,
					inTruck = OccupantSightUtils.inZone(root.Position, zone),
					vacuuming = character ~= nil
						and character:GetAttribute(VacuumMotionConstants.ACTIVE_ATTRIBUTE) == true,
					head = headPart.Position,
					report = nil,
					cameraClear = false,
					sightlines = {},
				}
				watched = watches(player, viewer, points, params, now)
			end
		end
	end
	local before = freeze.frozen
	freeze = OccupantWatchRules.advance(freeze, watched, now)
	if freeze.frozen ~= before then
		if freeze.frozen then
			counters.freezes += 1
		end
		-- The brain holds (or moves on) on the NPC's very next frame, not its next scheduled think.
		NpcServiceServer:wake(rig.model)
	end
	local kind = OccupantKindRegistry.get(OccupantKindRegistry.kindOf(rig.model))
	local twist = if kind ~= nil then kind.freeze else nil
	local target = 0
	if twist ~= nil and twist.headTurn then
		local hunting = mind ~= nil and (mind.mode == "chase" or mind.mode == "search")
		local input: OccupantHeadRules.Input = {
			position = rig.root.Position,
			brainTarget = if hunting and mind ~= nil then mind.target else nil,
			crew = crew,
			watched = freeze.frozen,
			now = now,
			swapSeconds = twist.headSwapSeconds,
		}
		local lunge = OccupantHeadRules.lunge(head, input, before)
		if lunge ~= nil then
			pendingLunge = lunge
		end
		head = OccupantHeadRules.advance(head, input)
		target = head.target or 0
	end
	setAttributes(rig.model, freeze.frozen, target)
end

-- A noise the rig hears: its makers count as "heard" for the head's target.
local function onNoise(noise: NoiseTypes.NoiseEvent)
	local current = source
	local rig = if current ~= nil then current.rig() else nil
	if rig == nil or watchedModel ~= rig.model then
		return
	end
	if NoiseRules.hears(rig.root.Position, noise.position, noise.radius, NoiseServiceServer:getHearingScale()) then
		local now = os.clock()
		for _, userId in noise.makers do
			heardAt[userId] = now
		end
	end
end

--[=[
	Starts taking camera reports and checking at FREEZE_CHECK_INTERVAL for the rig `from` gives.
]=]
function OccupantWatchSystem.start(from: Source)
	if source ~= nil then
		return
	end
	source = from
	local elapsed = 0
	local stopReports = OccupantEvents.packets.CameraReport.listen(function(data: ReportData, player: Player?)
		if player ~= nil then
			onReport(data, player)
		end
	end)
	local heartbeat = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < OccupantConstants.FREEZE_CHECK_INTERVAL then
			return
		end
		elapsed = 0
		check(os.clock())
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		reports[player] = nil
		heardAt[player.UserId] = nil
	end)
	local noises = NoiseServiceServer.made:Connect(onNoise)
	table.insert(stoppers, function()
		stopReports()
		heartbeat:Disconnect()
		leaving:Disconnect()
		noises:Disconnect()
	end)
end

function OccupantWatchSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	source = nil
	reset()
end

function OccupantWatchSystem.getState(): { [string]: number | boolean }
	return {
		watching = watchedModel ~= nil,
		frozen = freeze.frozen,
		headTarget = head.target or 0,
		checks = counters.checks,
		freezes = counters.freezes,
		reports = counters.reports,
	}
end

return OccupantWatchSystem
