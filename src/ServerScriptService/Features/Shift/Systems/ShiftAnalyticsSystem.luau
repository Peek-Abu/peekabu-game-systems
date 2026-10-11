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
	"crew" events go once to each crew member (Round participants still in the server).

	It also keeps the experiment context: the session, the build (BUILD_LABEL + PlaceVersion), each shift's variant
	(`pickVariant`: ShiftVariantRules over the Workspace override, ShiftConstants.VARIANT_MODE and the JobId, logged at
	info), each player's platform (the `Platform` packet, parsed by ShiftPlatformRules, first report wins) and the shift
	state the watch hands it. `banked` (ShiftBankingSystem) sends cargo_banked per item and closes the loader's
	optional-salvage attempts; `closeAttempts` sends optional_salvage_attempted for each closed attempt.

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

local ShiftAnalyticsSystem = {}

ShiftAnalyticsSystem.tracker = tracker
ShiftAnalyticsSystem.salvage = salvage

-- Crew members still in the server (Round's participants).
function ShiftAnalyticsSystem.crew(): { Player }
	local list: { Player } = {}
	for _, player in RoundServiceServer:participants() do
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
	for _, listener in table.clone(listeners) do
		local ok, err = pcall(function()
			listener(record)
		end)
		if not ok then
			log:warn(`analytics listener failed: {err}`)
		end
	end
end

--[=[
	Sends `event` to one player, or to each crew member for "crew". Returns how many records went out (0 for an unknown
	event, which is dropped and counted).
]=]
function ShiftAnalyticsSystem.emit(event: string, scope: Scope, details: Details): number
	if not ShiftAnalyticsUtils.isEvent(event) then
		counters.unknown += 1
		log:warn(`unknown analytics event "{event}" dropped`)
		return 0
	end
	local members = ShiftAnalyticsSystem.crew()
	if typeof(scope) == "Instance" then
		if scope.Parent == nil then
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
	optional_salvage_attempted for each closed attempt whose player is still here.
]=]
function ShiftAnalyticsSystem.closeAttempts(attempts: { ShiftSalvageTracker.Attempt })
	for _, attempt in attempts do
		local player = Players:GetPlayerByUserId(attempt.userId)
		if player ~= nil then
			local outcome = attempt.outcome or "unbanked"
			local banked = outcome == "banked"
			ShiftAnalyticsSystem.emit("optional_salvage_attempted", player, {
				target = `{attempt.kind}:{attempt.source}`,
				outcome = if banked then "banked" else "failed",
				reason = if banked then nil else outcome,
				value = attempt.sinceQuota,
			})
		end
	end
end

--[=[
	A Load (ShiftBankingSystem, after the counters moved): cargo_banked per item (salvage at the credited value), then
	the loader's attempts for the banked salvage kinds close as banked.
]=]
function ShiftAnalyticsSystem.banked(player: Player, deposit: CargoTypes.Deposit, multiplier: number)
	local tag = ShiftAnalyticsSystem.quotaTag()
	local salvageKinds: { string } = {}
	for _, item in deposit.items do
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
]=]
function ShiftAnalyticsSystem.start()
	table.insert(
		stoppers,
		ShiftEvents.packets.Platform.listen(function(data: number, player: Player?)
			if player then
				onPlatform(data, player)
			end
		end)
	)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		ShiftAnalyticsSystem.closeAttempts(salvage:resolvePlayer(player.UserId, "left"))
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
