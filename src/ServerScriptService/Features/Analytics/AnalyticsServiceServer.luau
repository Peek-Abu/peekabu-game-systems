--!strict
--[=[
	AnalyticsServiceServer: a safe wrapper over Roblox's AnalyticsService (design:
	docs/superpowers/specs/2026-10-09-small-services-design.md).

	`custom`, `economy`, `funnel` and `progression` clean names (AnalyticsRules), build custom fields from
	up to three values, and never throw into game code: each call is isolated, counted, and logged on
	failure. In Studio nothing is sent; the event is logged at debug level instead.

	It also takes what other features report for the tracking picks, each behind its own off switch
	(AnalyticsSwitchConstants; Creator Hub's configs flip them live, AnalyticsSwitchSystem): `recordEconomy` (a
	purchase or reward, after its transaction committed: AnalyticsEconomySystem), and for the visit events
	(AnalyticsVisitSystem) `place`, `moment`, `shiftWorked`, `trainingStep` and `trainingSkipped`.

	Spec-exempt shell (AnalyticsService); naming and fields are the specced AnalyticsRules.

	@class AnalyticsServiceServer
]=]

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsServer = ServerScriptService.Features.Analytics

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AnalyticsRules = require(AnalyticsServer.Rules.AnalyticsRules)
-- Required at load so the firstSeen slice registers before PlayerDataServiceServer init (ServerHandler requires
-- every service module first).
local AnalyticsFirstSeenSystem = require(AnalyticsServer.Systems.AnalyticsFirstSeenSystem)
local AnalyticsEconomySystem = require(AnalyticsServer.Systems.AnalyticsEconomySystem)
local AnalyticsSessionSystem = require(AnalyticsServer.Systems.AnalyticsSessionSystem)
local AnalyticsSwitchSystem = require(AnalyticsServer.Systems.AnalyticsSwitchSystem)
-- Required at load too: it registers the "visit" slice.
local AnalyticsVisitSystem = require(AnalyticsServer.Systems.AnalyticsVisitSystem)
local AnalyticsTypes = require(AnalyticsServer.Data.AnalyticsTypes)

export type ProgressionStatus = "start" | "complete" | "fail"

local log = Logger.new("AnalyticsServiceServer")
local counters = { sent = 0, skipped = 0, failed = 0 }
local stopFirstSeen: (() -> ())? = nil
local stopSession: (() -> ())? = nil
local stopEconomy: (() -> ())? = nil
local stopSwitches: (() -> ())? = nil
local stopVisit: (() -> ())? = nil

local function send(label: string, call: () -> ())
	if RunService:IsStudio() then
		counters.skipped += 1
		log:debug(`(studio, not sent) {label}`)
		return
	end
	local ok, err = pcall(function()
		call()
	end)
	if ok then
		counters.sent += 1
	else
		counters.failed += 1
		log:warn(`analytics {label} failed: {err}`)
	end
end

export type AnalyticsServiceServer = {
	dependencies: { string },
	start: (self: AnalyticsServiceServer) -> (),
	stop: (self: AnalyticsServiceServer) -> (),
	custom: (self: AnalyticsServiceServer, player: Player, event: string, value: number?, fields: { string }?) -> (),
	economy: (
		self: AnalyticsServiceServer,
		player: Player,
		flow: "source" | "sink",
		currency: string,
		amount: number,
		endingBalance: number,
		transactionType: string,
		sku: string?,
		fields: { string }?
	) -> (),
	funnel: (
		self: AnalyticsServiceServer,
		player: Player,
		funnel: string,
		step: number,
		stepName: string?,
		fields: { string }?
	) -> (),
	progression: (
		self: AnalyticsServiceServer,
		player: Player,
		path: string,
		status: ProgressionStatus,
		level: number,
		levelName: string?,
		fields: { string }?
	) -> (),
	-- A purchase or reward, reported once its transaction committed.
	recordEconomy: (self: AnalyticsServiceServer, userId: number, record: AnalyticsTypes.EconomyRecord) -> (),
	-- Where the player is now (quits).
	place: (self: AnalyticsServiceServer, player: Player, place: AnalyticsTypes.Place) -> (),
	-- A catch, chase or knock-out (quits).
	moment: (self: AnalyticsServiceServer, player: Player, moment: AnalyticsTypes.Moment) -> (),
	-- One real shift worked (shifts per visit).
	shiftWorked: (self: AnalyticsServiceServer, player: Player) -> (),
	-- A training funnel step (AnalyticsConstants.TRAINING_STEPS).
	trainingStep: (self: AnalyticsServiceServer, player: Player, step: string) -> (),
	trainingSkipped: (self: AnalyticsServiceServer, player: Player) -> (),
	getState: (self: AnalyticsServiceServer) -> { [string]: any },
}

local AnalyticsServiceServer: AnalyticsServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"ExperimentServiceServer",
		"QueueServiceServer",
		"CurrencyServiceServer",
		"MarketplaceServiceServer",
	},

	--[=[
		Starts stamping each account's first-seen time as its profile loads, and the session system (platform,
		assignment log, hub funnel) and the economy system, handing them a Sender over this service's own calls.
	]=]
	start = function(self)
		if stopSwitches == nil then
			stopSwitches = AnalyticsSwitchSystem.start()
		end
		if stopFirstSeen == nil then
			stopFirstSeen = AnalyticsFirstSeenSystem.start()
		end
		if stopSession == nil then
			local sender: AnalyticsTypes.Sender = {
				custom = function(player, event, value, fields)
					self:custom(player, event, value, fields)
				end,
				funnel = function(player, funnel, step, stepName, fields)
					self:funnel(player, funnel, step, stepName, fields)
				end,
				economy = function(player, call, fields)
					self:economy(
						player,
						call.flow,
						call.currency,
						call.amount,
						call.endingBalance,
						call.transactionType,
						call.sku,
						fields
					)
				end,
			}
			stopSession = AnalyticsSessionSystem.start(sender)
			stopEconomy = AnalyticsEconomySystem.start(sender)
			stopVisit = AnalyticsVisitSystem.start(sender)
		end
	end,

	stop = function(_self)
		if stopVisit ~= nil then
			stopVisit()
			stopVisit = nil
		end
		if stopEconomy ~= nil then
			stopEconomy()
			stopEconomy = nil
		end
		if stopSession ~= nil then
			stopSession()
			stopSession = nil
		end
		if stopFirstSeen ~= nil then
			stopFirstSeen()
			stopFirstSeen = nil
		end
		if stopSwitches ~= nil then
			stopSwitches()
			stopSwitches = nil
		end
	end,

	--[=[
		A custom event ("egg-stolen", "jumpscare-seen"), with an optional value and up to three fields.
	]=]
	custom = function(_self, player, event, value, fields)
		local name = AnalyticsRules.name(event)
		if name == nil then
			return
		end
		local customFields = AnalyticsRules.customFields(fields)
		send(`custom {name}{AnalyticsRules.describe(fields)}`, function()
			AnalyticsService:LogCustomEvent(player, name, value, customFields)
		end)
	end,

	--[=[
		Currency in (`source`) or out (`sink`): amount, the balance after, and what kind of transaction
		("Gameplay", "Shop", "IAP", …).
	]=]
	economy = function(_self, player, flow, currency, amount, endingBalance, transactionType, sku, fields)
		local flowType = if flow == "source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		local customFields = AnalyticsRules.customFields(fields)
		send(`economy {flow} {currency}{AnalyticsRules.describe(fields)}`, function()
			AnalyticsService:LogEconomyEvent(
				player,
				flowType,
				currency,
				amount,
				endingBalance,
				transactionType,
				sku,
				customFields
			)
		end)
	end,

	--[=[
		A funnel step (onboarding, a shop flow): steps count from 1.
	]=]
	funnel = function(_self, player, funnel, step, stepName, fields)
		local name = AnalyticsRules.name(funnel)
		if name == nil then
			return
		end
		local customFields = AnalyticsRules.customFields(fields)
		send(`funnel {name} {step}{AnalyticsRules.describe(fields)}`, function()
			AnalyticsService:LogFunnelStepEvent(player, name, nil, step, stepName, customFields)
		end)
	end,

	--[=[
		Progress along a path (nights, levels, events): started, completed or failed at `level`.
	]=]
	progression = function(_self, player, path, status, level, levelName, fields)
		local name = AnalyticsRules.name(path)
		if name == nil then
			return
		end
		local customFields = AnalyticsRules.customFields(fields)
		send(`progression {name} {status} {level}`, function()
			if status == "start" then
				AnalyticsService:LogProgressionStartEvent(player, name, level, levelName, customFields)
			elseif status == "complete" then
				AnalyticsService:LogProgressionCompleteEvent(player, name, level, levelName, customFields)
			else
				AnalyticsService:LogProgressionFailEvent(player, name, level, levelName, customFields)
			end
		end)
	end,

	recordEconomy = function(_self, userId, record)
		AnalyticsEconomySystem.record(userId, record)
	end,

	place = function(_self, player, place)
		AnalyticsVisitSystem.place(player, place)
	end,

	moment = function(_self, player, moment)
		AnalyticsVisitSystem.moment(player, moment)
	end,

	shiftWorked = function(_self, player)
		AnalyticsVisitSystem.worked(player)
	end,

	trainingStep = function(_self, player, step)
		AnalyticsVisitSystem.trainingStep(player, step)
	end,

	trainingSkipped = function(_self, player)
		AnalyticsVisitSystem.trainingSkipped(player)
	end,

	getState = function(_self)
		local state: { [string]: any } = table.clone(counters)
		state.switches = AnalyticsSwitchSystem.states()
		return state
	end,
}

return AnalyticsServiceServer
