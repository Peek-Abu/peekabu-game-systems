--!strict
--[=[
	SkillCheckServiceServer: the closing-ring skill check (owner-approved idea k1, 2026-11-17). While a player vacuums a
	pile on a running shift (never training, never the hub, never a grimy valuable: VacuumServiceServer.vacuumingTarget, a
	VacuumConstants.PILE_TAG part),
	rings come one after another (SkillCheckRingTracker, every SkillCheckConstants.STEP_INTERVAL): the server picks each
	ring's opening, its width (narrower as the pile's progress rises) and its arrival on the server clock, and sends it
	to that player alone (SkillCheckEvents.Ring). Their client draws it and, at the arrival, reports the icon's angle
	(SkillCheckEvents.Report, rate-limited and checked by SkillCheckReportRules behind RequestHandler). The server judges
	it against the opening; a report for another ring is ignored, and none in the window is a miss. Each verdict goes
	back to the player (SkillCheckEvents.Result, their client's clunk or tick); a miss is a loud noise at the player
	(NoiseServiceServer:emit, SkillCheckConstants.MISS_NOISE_RADIUS) that Harlow may hear. The pile's own clean time and
	the pay are untouched: the ring sits on top of vacuuming. SkillCheckConstants.ENABLED = false starts no rings.

	Spec-exempt shell (Players, RunService, signals, ByteNet); the decisions are the specced SkillCheckRingTracker,
	SkillCheckReportRules and SkillCheckAngleFormulas.

	@class SkillCheckServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local SkillCheckShared = ReplicatedStorage.Shared.Features.SkillCheck
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local SkillCheckConstants = require(SkillCheckShared.Data.SkillCheckConstants)
local SkillCheckTypes = require(SkillCheckShared.Data.SkillCheckTypes)
local SkillCheckEvents = require(SkillCheckShared.Net.SkillCheckEvents)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local SkillCheckReportRules = require(ServerScriptService.Features.SkillCheck.Rules.SkillCheckReportRules)
local SkillCheckRingTracker = require(ServerScriptService.Features.SkillCheck.State.SkillCheckRingTracker)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

type ReportData = { id: number, angle: number }

local log = Logger.new("SkillCheckServiceServer")
local janitor = Janitor.new()
local random = Random.new()
local counters = { rings = 0, hits = 0, misses = 0, ignored = 0 }

local tracker = SkillCheckRingTracker.new({
	travel = SkillCheckConstants.TRAVEL,
	firstDelay = SkillCheckConstants.FIRST_DELAY,
	between = SkillCheckConstants.BETWEEN,
	widthStart = SkillCheckConstants.WIDTH_START,
	widthEnd = SkillCheckConstants.WIDTH_END,
	minShift = SkillCheckConstants.MIN_SHIFT,
	tolerance = SkillCheckConstants.TOLERANCE,
	early = SkillCheckConstants.REPORT_EARLY,
	late = SkillCheckConstants.REPORT_LATE,
}, function(): number
	return random:NextNumber()
end)

-- Whether rings may run at all on this server right now: switched on, a shift running, not training.
local function live(): boolean
	return SkillCheckConstants.ENABLED
		and ShiftServiceServer:getShift().phase == "running"
		and not ShiftServiceServer:isTraining()
end

-- The pile (never a grimy valuable) `player` is vacuuming and its progress (0 to 1), or nil.
local function pileOf(player: Player): (BasePart?, number)
	local target = VacuumServiceServer:vacuumingTarget(player)
	if
		target == nil
		or not target:IsA("BasePart")
		or target.Parent == nil
		or not CollectionService:HasTag(target, VacuumConstants.PILE_TAG)
	then
		return nil, 0
	end
	local progress = target:GetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
	return target, if type(progress) == "number" then progress else 0
end

-- Tells the player the verdict; a miss makes a loud noise where they stand.
local function settle(verdict: SkillCheckTypes.Verdict)
	local player = Players:GetPlayerByUserId(verdict.userId)
	if verdict.hit then
		counters.hits += 1
	else
		counters.misses += 1
	end
	if player == nil then
		return
	end
	SkillCheckEvents.packets.Result.sendTo({ id = verdict.ring.id, hit = verdict.hit }, player)
	if verdict.hit then
		return
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		NoiseServiceServer:emit(
			root.Position,
			SkillCheckConstants.MISS_NOISE_RADIUS,
			SkillCheckConstants.MISS_NOISE_SOURCE,
			{ player.UserId }
		)
	end
end

-- One beat: rings start for players on a pile, closed windows become misses.
local function step()
	local now = Workspace:GetServerTimeNow()
	local running = live()
	for _, player in Players:GetPlayers() do
		local pile, progress = pileOf(player)
		local ring = tracker:step(player.UserId, running and pile ~= nil, progress, now)
		if ring ~= nil then
			counters.rings += 1
			SkillCheckEvents.packets.Ring.sendTo(ring, player)
		end
	end
	for _, verdict in tracker:expire(now) do
		settle(verdict)
	end
end

local onReport = RequestHandler.wrap({
	name = "SkillCheckReport",
	rateLimit = SkillCheckConstants.REPORT_LIMIT,
	validate = function(data: ReportData, _player: Player): (boolean, string?, SkillCheckTypes.Report?)
		local report, reason = SkillCheckReportRules.parse(data.id, data.angle)
		return report ~= nil, reason, report
	end,
	handler = function(_data: ReportData, player: Player, report: SkillCheckTypes.Report?)
		if report == nil then
			return
		end
		local verdict, reason = tracker:report(player.UserId, report.id, report.angle, Workspace:GetServerTimeNow())
		if verdict == nil then
			counters.ignored += 1
			log:debug(`skill check report ignored: {reason or "?"}`)
			return
		end
		settle(verdict)
	end,
})

export type SkillCheckServiceServer = {
	dependencies: { string },
	start: (self: SkillCheckServiceServer) -> (),
	stop: (self: SkillCheckServiceServer) -> (),
	getState: (self: SkillCheckServiceServer) -> { [string]: any },
}

local SkillCheckServiceServer: SkillCheckServiceServer = {
	dependencies = { "VacuumServiceServer", "NoiseServiceServer", "ShiftServiceServer" },

	--[=[
		Listens for reports, steps the rings on a beat, forgets leavers and drops every ring when a shift stops running.
	]=]
	start = function(_self)
		janitor:Add(
			SkillCheckEvents.packets.Report.listen(function(data: ReportData, player: Player?)
				if player then
					onReport(data, player)
				end
			end),
			true
		)
		local elapsed = 0
		janitor:Add(
			RunService.Heartbeat:Connect(function(deltaTime: number)
				elapsed += deltaTime
				if elapsed >= SkillCheckConstants.STEP_INTERVAL then
					elapsed = 0
					step()
				end
			end),
			"Disconnect"
		)
		janitor:Add(
			ShiftServiceServer.changed:Connect(function(state: ShiftTypes.ShiftState)
				if state.phase ~= "running" then
					tracker:clear()
				end
			end),
			"Disconnect"
		)
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				tracker:forget(player.UserId)
			end),
			"Disconnect"
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
		tracker:clear()
	end,

	getState = function(_self)
		return { enabled = SkillCheckConstants.ENABLED, live = live(), counters = table.clone(counters) }
	end,
}

return SkillCheckServiceServer
