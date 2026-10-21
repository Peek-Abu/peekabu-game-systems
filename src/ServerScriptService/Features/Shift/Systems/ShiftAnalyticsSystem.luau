--!strict
--[=[
	ShiftAnalyticsSystem: Cleanup Crew's one door to analytics (spec §6.6, §6.4, §1). Every game event goes through
	`emit`: the name must be one of the 13 (ShiftAnalyticsConstants.EVENTS); target, outcome and reason become
	vocabulary tokens (ShiftAnalyticsUtils.token: catalog ids and fixed words only, so no name, chat line or id can reach
	a field). Each record goes to:
	- AnalyticsServiceServer:custom(player, event, value, { context, target, outcome }): the engine takes three custom
	  fields, so field 1 packs "variant|platform|party|build" (AnalyticsServiceServer sends nothing in Studio);
	- the server log, key events at info and the rest at debug, with the session id (JobId) the engine fields leave out;
	- a ring of recent records and any `listen` callbacks (the Studio test sink).
	"crew" events go once to each crew member still in the server: the shift's crew (ShiftTripSystem, handed to
	`start`), not Round's participants, which Round clears on its way back to the lobby before its deferred
	`runEnded` reaches the watch (Shift runs Round with no results time), so shift_ended would find nobody.

	It also keeps the experiment context: the session, the build (BUILD_LABEL + PlaceVersion), each shift's variant
	(`pickVariant`: ShiftVariantRules over the Workspace override, ShiftConstants.VARIANT_MODE and the JobId, logged at
	info), each player's platform (the `Platform` packet, parsed by ShiftPlatformRules, first report wins) and the shift
	state the watch hands it. `banked` (ShiftBankingSystem) sends cargo_banked per item and closes the loader's
	optional-salvage attempts; `closeAttempts` sends optional_salvage_attempted for each closed attempt. `banked` also
	fires `loaded` (the loader, the items and salvage items in the Load, and how many are overtime loot), which
	ShiftReviewSystem counts into the roster for the company rank's award.

	Spec-exempt shell (AnalyticsService, Players, ByteNet, a Workspace attribute); payloads, tokens, variant, platform
	and attempts are the specced ShiftAnalyticsUtils, ShiftVariantRules, ShiftPlatformRules, ShiftAnalyticsTracker and
	ShiftSalvageTracker.

	@class ShiftAnalyticsSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local ShiftServer = ServerScriptService.Features.Shift
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftEvents = require(ShiftShared.Net.ShiftEvents)
local ShiftPlatformRules = require(ShiftShared.Rules.ShiftPlatformRules)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local AnalyticsServiceServer = require(ServerScriptService.Features.Analytics.AnalyticsServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftAnalyticsConstants = require(ShiftServer.Data.ShiftAnalyticsConstants)
local ShiftVariantRules = require(ShiftServer.Rules.ShiftVariantRules)
local ShiftAnalyticsTracker = require(ShiftServer.State.ShiftAnalyticsTracker)
local ShiftSalvageTracker = require(ShiftServer.State.ShiftSalvageTracker)
local ShiftAnalyticsUtils = require(ShiftServer.Utils.ShiftAnalyticsUtils)

export type Scope = Player | "crew"

type Record = ShiftAnalyticsUtils.Record
type Details = ShiftAnalyticsUtils.Details

local log = Logger.new("ShiftAnalyticsSystem")
local session = ShiftAnalyticsUtils.session(game.JobId)
local build = ShiftAnalyticsUtils.build(ShiftAnalyticsConstants.BUILD_LABEL, game.PlaceVersion)
local tracker = ShiftAnalyticsTracker.new(ShiftAnalyticsConstants.RECENT_LIMIT, ShiftAnalyticsConstants.NOISE_LIMIT)
local salvage = ShiftSalvageTracker.new()
local listeners: { (Record) -> () } = {}
local counters = { sent = 0, unknown = 0 }
local variant: ShiftTypes.Variant = ShiftConstants.VARIANT
local variantSource: ShiftTypes.VariantSource = "fixed"
local shiftState: ShiftTypes.ShiftState? = nil
local stoppers: { () -> () } = {}
-- The shift's crew (set by `start`); before that, Round's participants.
local crewSource: (() -> { Player })? = nil

-- Every accepted Load: the loader, its item count, its salvage count, and how many of its items are overtime loot.
local loaded: SignalTyped.Signal<Player, number, number, number> = SignalTyped.new()

local ShiftAnalyticsSystem = {}

ShiftAnalyticsSystem.tracker = tracker
ShiftAnalyticsSystem.loaded = loaded
ShiftAnalyticsSystem.salvage = salvage

-- Crew members still in the server.
function ShiftAnalyticsSystem.crew(): { Player }
	local list: { Player } = {}
	local source = crewSource
	local members: { Player } = if source ~= nil then source() else RoundServiceServer:participants()
	for _, player in members do
		if player.Parent ~= nil then
			table.insert(list, player)
		end
	end
	return list
end

-- One record for one player: AnalyticsService, the log, the ring, the listeners.
local function send(event: string, player: Player, party: number, details: Details)
	local context: ShiftAnalyticsUtils.Context = {
		session = session,
		build = build,
		variant = variant,
		platform = tracker:platformOf(player.UserId),
		party = party,
	}
	local record = ShiftAnalyticsUtils.record(event, context, details)
	tracker:remember(record)
	AnalyticsServiceServer:custom(player, event, record.value, ShiftAnalyticsUtils.fields(context, details))
	counters.sent += 1
	local line =
		`{record.event} target={record.target} outcome={record.outcome} reason={record.reason} value={record.value} variant={record.variant} platform={record.platform} party={record.party} build={record.build} session={record.session}`
	if ShiftAnalyticsConstants.INFO_EVENTS[event] then
		log:info(line)
	else
		log:debug(line)
	end
	-- Each listener runs on its own thread: it runs at once (records still reach it in order), but a listener that
	-- yields can never hold the caller open (Cargo's Load claims, adds and destroys in one synchronous step), and an
	-- error stays in its thread.
	for _, listener in table.clone(listeners) do
		task.spawn(function()
			local ok, err = pcall(function()
				listener(record)
			end)
			if not ok then
				log:warn(`analytics listener failed: {err}`)
			end
		end)
	end
end

-- `emit` for one known event. `leaving` lets a Player that is on its way out through (PlayerRemoving): under deferred
-- signals its Parent may already be nil when the handler runs, and its records would otherwise be lost.
local function emitTo(event: string, scope: Scope, details: Details, leaving: boolean): number
	if not ShiftAnalyticsUtils.isEvent(event) then
		counters.unknown += 1
		log:warn(`unknown analytics event "{event}" dropped`)
		return 0
	end
	local members = ShiftAnalyticsSystem.crew()
	if typeof(scope) == "Instance" then
		if scope.Parent == nil and not leaving then
			return 0
		end
		send(event, scope, math.max(#members, 1), details)
		return 1
	end
	for _, player in members do
		send(event, player, #members, details)
	end
	return #members
end

--[=[
	Sends `event` to one player, or to each crew member for "crew". Returns how many records went out (0 for an unknown
	event, which is dropped and counted).
]=]
function ShiftAnalyticsSystem.emit(event: string, scope: Scope, details: Details): number
	return emitTo(event, scope, details, false)
end

--[=[
	The variant for the shift about to start (ShiftVariantRules); remembered for every event's context and logged.
	Never throws: ShiftServiceServer calls it inside its phase handler.
]=]
function ShiftAnalyticsSystem.pickVariant(shift: number): ShiftTypes.Variant
	-- Annotated: Luau widens unannotated singleton-union locals to `string`.
	local picked: ShiftTypes.Variant, source: ShiftTypes.VariantSource = ShiftVariantRules.pick({
		mode = ShiftConstants.VARIANT_MODE,
		fixed = ShiftConstants.VARIANT,
		override = Workspace:GetAttribute(ShiftConstants.VARIANT_ATTRIBUTE),
		session = session,
		shift = shift,
	})
	variant = picked
	variantSource = source
	log:info(`shift {shift}: variant {picked} ({source}), session {session}, build {build}`)
	return picked
end

function ShiftAnalyticsSystem.variantSource(): string
	return variantSource
end

function ShiftAnalyticsSystem.setShift(state: ShiftTypes.ShiftState)
	shiftState = state
end

function ShiftAnalyticsSystem.shift(): ShiftTypes.ShiftState?
	return shiftState
end

-- A new run: per-shift bookkeeping and attempts start empty.
function ShiftAnalyticsSystem.beginShift()
	tracker:beginShift()
	salvage:clear()
end

function ShiftAnalyticsSystem.elapsed(): number
	local state = shiftState
	local startedAt = if state ~= nil then state.startedAt else nil
	if startedAt == nil then
		return 0
	end
	return math.max(0, Workspace:GetServerTimeNow() - startedAt)
end

function ShiftAnalyticsSystem.quotaTag(): string
	local state = shiftState
	return ShiftAnalyticsUtils.quotaTag(state ~= nil and state.quotaMet)
end

function ShiftAnalyticsSystem.sinceQuota(): number
	local at = tracker:quotaAt()
	if at == nil then
		return 0
	end
	return math.max(0, ShiftAnalyticsSystem.elapsed() - at)
end

--[=[
	optional_salvage_attempted for each closed attempt whose player is still here, or is `leaving` (the PlayerRemoving
	path hands its Player straight in: by then GetPlayerByUserId may no longer find them, nor their Parent be set).
	The attempts are already closed (taken from the tracker), so each is reported at most once.
]=]
function ShiftAnalyticsSystem.closeAttempts(attempts: { ShiftSalvageTracker.Attempt }, leaving: Player?)
	for _, attempt in attempts do
		local isLeaver = leaving ~= nil and leaving.UserId == attempt.userId
		local player = if isLeaver then leaving else Players:GetPlayerByUserId(attempt.userId)
		if player ~= nil then
			local outcome = attempt.outcome or "unbanked"
			local banked = outcome == "banked"
			emitTo("optional_salvage_attempted", player, {
				target = `{attempt.kind}:{attempt.source}`,
				outcome = if banked then "banked" else "failed",
				reason = if banked then nil else outcome,
				value = attempt.sinceQuota,
			}, isLeaver)
		end
	end
end

--[=[
	A Load (ShiftBankingSystem, after the counters moved): cargo_banked per item (salvage at the credited value), then
	the loader's attempts for the banked salvage kinds close as banked.
]=]
function ShiftAnalyticsSystem.banked(player: Player, deposit: CargoTypes.Deposit)
	local tag = ShiftAnalyticsSystem.quotaTag()
	local salvageKinds: { string } = {}
	local salvageCount = 0
	local overtimeCount = 0
	for _, item in deposit.items do
		if item.category == "salvage" then
			salvageCount += 1
			if item.overtime == true then
				overtimeCount += 1
			end
		end
	end
	loaded:Fire(player, #deposit.items, salvageCount, overtimeCount)
	for _, item in deposit.items do
		local multiplier = if item.overtime == true
			then ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER
			else ShiftConstants.SALVAGE_MULTIPLIER
		ShiftAnalyticsSystem.emit("cargo_banked", player, {
			target = item.kind,
			outcome = tag,
			value = ShiftAnalyticsUtils.credited(item.category, item.value, multiplier),
		})
		if item.category == "salvage" then
			table.insert(salvageKinds, item.kind)
		end
	end
	ShiftAnalyticsSystem.closeAttempts(salvage:resolveBanked(player.UserId, salvageKinds))
end

-- Adds a listener (the Studio test sink). It is called on its own thread per record, so it may yield or throw
-- without affecting the event's caller.
function ShiftAnalyticsSystem.listen(listener: (Record) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index ~= nil then
			table.remove(listeners, index)
		end
	end
end

function ShiftAnalyticsSystem.recent(): { Record }
	return tracker:recent()
end

-- The platform report: rate-limited, parsed from the fixed enum, first valid report wins.
local onPlatform = RequestHandler.wrap({
	name = "ShiftPlatform",
	rateLimit = { maxRequests = 3, windowSeconds = 10 },
	-- Count, don't warn: the default warn line carries the sender's UserId, and no analytics path logs one.
	onReject = "count",
	validate = function(data: number, _player: Player): (boolean, string?, ShiftTypes.Platform?)
		local platform: ShiftTypes.Platform? = ShiftPlatformRules.parse(data)
		if platform == nil then
			return false, "unknown platform", nil
		end
		return true, nil, platform
	end,
	handler = function(_data: number, player: Player, platform: ShiftTypes.Platform?)
		if platform ~= nil and tracker:setPlatform(player.UserId, platform) then
			log:debug(`platform {platform} reported`)
		end
	end,
})

--[=[
	Takes platform reports; a leaving player's open attempts close as "left" and their bookkeeping is forgotten.
	`crew` lists the shift's crew (ShiftTripSystem), which outlives Round's post-run cleanup.
]=]
function ShiftAnalyticsSystem.start(crew: () -> { Player })
	crewSource = crew
	table.insert(
		stoppers,
		ShiftEvents.packets.Platform.listen(function(data: number, player: Player?)
			if player then
				onPlatform(data, player)
			end
		end)
	)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		ShiftAnalyticsSystem.closeAttempts(salvage:resolvePlayer(player.UserId, "left"), player)
		tracker:forget(player.UserId)
	end)
	table.insert(stoppers, function()
		leaving:Disconnect()
	end)
end

function ShiftAnalyticsSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	shiftState = nil
	crewSource = nil
end

function ShiftAnalyticsSystem.getState(): { [string]: string | number }
	return {
		session = session,
		build = build,
		variant = variant,
		variantSource = variantSource,
		sent = counters.sent,
		unknown = counters.unknown,
		openAttempts = salvage:openCount(),
		recent = #tracker:recent(),
	}
end

return ShiftAnalyticsSystem
