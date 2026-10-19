--!strict
--[=[
	AnalyticsServiceServer: a safe wrapper over Roblox's AnalyticsService (design:
	docs/superpowers/specs/2026-10-09-small-services-design.md).

	`custom`, `economy`, `funnel` and `progression` clean names (AnalyticsRules), build custom fields from
	up to three values, and never throw into game code: each call is isolated, counted, and logged on
	failure. In Studio nothing is sent; the event is logged at debug level instead.

	Spec-exempt shell (AnalyticsService); naming and fields are the specced AnalyticsRules.

	@class AnalyticsServiceServer
]=]

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AnalyticsConstants = require(ServerScriptService.Features.Analytics.Data.AnalyticsConstants)
local AnalyticsRules = require(ServerScriptService.Features.Analytics.Rules.AnalyticsRules)
-- Required at load so the firstSeen slice registers before PlayerDataServiceServer init (ServerHandler requires
-- every service module first).
local AnalyticsFirstSeenSystem = require(ServerScriptService.Features.Analytics.Systems.AnalyticsFirstSeenSystem)
local AnalyticsEconomySystem = require(ServerScriptService.Features.Analytics.Systems.AnalyticsEconomySystem)
local AnalyticsSessionSystem = require(ServerScriptService.Features.Analytics.Systems.AnalyticsSessionSystem)
local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)

export type ProgressionStatus = "start" | "complete" | "fail"

local log = Logger.new("AnalyticsServiceServer")
local counters = { sent = 0, skipped = 0, failed = 0 }
local stopFirstSeen: (() -> ())? = nil
local stopSession: (() -> ())? = nil
local stopEconomy: (() -> ())? = nil

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
		if stopFirstSeen == nil then
			stopFirstSeen = AnalyticsFirstSeenSystem.start()
		end
		if stopSession == nil then
			local sender: AnalyticsTypes.Sender = {
				custom = function(player, event, value, fields)
					self:custom(player, event, value, fields)
				end,
				funnel = function(player, step, stepName, fields)
					self:funnel(player, AnalyticsConstants.FUNNEL, step, stepName, fields)
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
		end
	end,

	stop = function(_self)
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

	getState = function(_self)
		return table.clone(counters)
	end,
}

return AnalyticsServiceServer
