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
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local OccupantHeadRules = require(OccupantServer.Rules.OccupantHeadRules)
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

--[=[
	A camera report's position and unit look, or nil when either is not finite or the look is (near) zero.
]=]
function OccupantWatchSystem.parseReport(data: { position: Vector3, look: Vector3 }): (Vector3?, Vector3?)
	local position, look = data.position, data.look
	if typeof(position) ~= "Vector3" or typeof(look) ~= "Vector3" then
		return nil, nil
	end
	if not finite(position) or not finite(look) or look.Magnitude < 1e-3 then
		return nil, nil
	end
	return position, look.Unit
end

--[=[
	The rig's three points a watcher may see: its head, its chest (the root) and its knees (halfway down its legs).
]=]
function OccupantWatchSystem.points(rig: Rig): { Vector3 }
	local root = rig.root
	local knees = root.Position - Vector3.new(0, root.Size.Y / 2 + rig.humanoid.HipHeight / 2, 0)
	return { rig.head.Position, root.Position, knees }
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
	validate = function(data: { position: Vector3, look: Vector3 }, _player: Player): (boolean, string?, Report?)
		local position, look = OccupantWatchSystem.parseReport(data)
		if position == nil or look == nil then
			return false, "bad camera report", nil
		end
		return true, nil, { position = position, look = look, receivedAt = os.clock() }
	end,
	handler = function(_data: { position: Vector3, look: Vector3 }, player: Player, report: Report?)
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

-- Whether some body point is in the camera's cone and range (worth the rays).
local function inView(report: Report, points: { Vector3 }): boolean
	for _, point in points do
		if
			OccupantWatchRules.inRange(report.position, point)
			and OccupantWatchRules.inCone(report.position, report.look, point)
		then
			return true
		end
	end
	return false
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
		or not inView(report, points)
	then
		return false
	end
	viewer.report = report
	viewer.cameraClear = clearLine(viewer.head, report.position, params)
	if viewer.cameraClear then
		for _, point in points do
			table.insert(viewer.sightlines, { point = point, clear = clearLine(report.position, point, params) })
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
	local stopReports = OccupantEvents.packets.CameraReport.listen(
		function(data: { position: Vector3, look: Vector3 }, player: Player?)
			if player ~= nil then
				onReport(data, player)
			end
		end
	)
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
