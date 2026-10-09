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
local AnalyticsRules = require(ServerScriptService.Features.Analytics.Rules.AnalyticsRules)

export type ProgressionStatus = "start" | "complete" | "fail"

local log = Logger.new("AnalyticsServiceServer")
local counters = { sent = 0, skipped = 0, failed = 0 }

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
	dependencies = {},

	--[=[
		A custom event ("egg-stolen", "jumpscare-seen"), with an optional value and up to three fields.
	]=]
	custom = function(_self, player, event, value, fields)
		local name = AnalyticsRules.name(event)
		if name == nil then
			return
		end
		local customFields = AnalyticsRules.customFields(fields)
		send(`custom {name}`, function()
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
		send(`economy {flow} {currency}`, function()
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
		send(`funnel {name} {step}`, function()
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
