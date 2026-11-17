--!strict
--[=[
	AnalyticsSwitchSystem: answers whether a tracking pick is on (`isOn`). It reads Roblox's experience configs
	(ConfigService, server only) once at start in the background and refreshes them whenever Roblox says newer values
	are out (ConfigSnapshot.UpdateAvailable), so a config published in Creator Hub reaches a live server in about a
	minute with no place update. Until the configs load, or when one is missing, not a boolean, or unreadable, the
	code's constant decides (AnalyticsSwitchConstants, AnalyticsSwitchUtils.resolve). Each change of a switch is logged
	at info.

	Every tracking path asks `isOn` at the moment it would run, so a flip takes effect without restarting anything.

	Spec-exempt shell (ConfigService); the rule is the specced AnalyticsSwitchUtils and the switches the specced
	AnalyticsSwitchConstants.

	@class AnalyticsSwitchSystem
]=]

local ConfigService = game:GetService("ConfigService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsServer = ServerScriptService.Features.Analytics

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AnalyticsSwitchConstants = require(AnalyticsServer.Data.AnalyticsSwitchConstants)
local AnalyticsTypes = require(AnalyticsServer.Data.AnalyticsTypes)
local AnalyticsSwitchUtils = require(AnalyticsServer.Utils.AnalyticsSwitchUtils)

type Switch = AnalyticsTypes.Switch

local log = Logger.new("AnalyticsSwitchSystem")

local snapshot: ConfigSnapshot? = nil
local updates: RBXScriptConnection? = nil
-- Bumped by every start and stop, so a load that finishes after a stop is dropped.
local generation = 0
-- The last state logged for each switch.
local logged: { [Switch]: boolean } = {}

local AnalyticsSwitchSystem = {}

--[=[
	Whether `switch`'s tracking runs right now: Creator Hub's boolean config when set, else the code's constant.
	Never yields or throws.
]=]
function AnalyticsSwitchSystem.isOn(switch: Switch): boolean
	local fallback = AnalyticsSwitchConstants.SWITCHES[switch]
	local current = snapshot
	if current == nil then
		return fallback
	end
	local key = AnalyticsSwitchConstants.CONFIG_KEYS[switch]
	local ok, value = pcall(function(): unknown
		return current:GetValue(key)
	end)
	if not ok then
		return fallback
	end
	return AnalyticsSwitchUtils.resolve(value, fallback)
end

--[=[
	Every switch's current state (the debug state).
]=]
function AnalyticsSwitchSystem.states(): { [string]: boolean }
	local states: { [string]: boolean } = {}
	for _, switch: Switch in AnalyticsSwitchConstants.ORDER do
		states[switch] = AnalyticsSwitchSystem.isOn(switch)
	end
	return states
end

-- Logs each switch whose state changed since the last report.
local function report()
	for _, switch: Switch in AnalyticsSwitchConstants.ORDER do
		local on = AnalyticsSwitchSystem.isOn(switch)
		if logged[switch] ~= on then
			logged[switch] = on
			log:info(`tracking {switch} is {if on then "on" else "OFF"}`)
		end
	end
end

--[=[
	Loads the configs in the background and follows their updates. Returns the stopper.
]=]
function AnalyticsSwitchSystem.start(): () -> ()
	generation += 1
	local mine = generation
	report()
	task.spawn(function()
		local ok, result = pcall(function(): ConfigSnapshot
			return ConfigService:GetConfigAsync()
		end)
		if mine ~= generation then
			return
		end
		if not ok then
			log:warn(`the experience configs did not load; the code's switches decide: {result}`)
			return
		end
		local loaded: ConfigSnapshot = result
		snapshot = loaded
		updates = loaded.UpdateAvailable:Connect(function()
			local refreshed, err = pcall(function()
				loaded:Refresh()
			end)
			if not refreshed then
				log:warn(`refreshing the experience configs failed: {err}`)
			end
			report()
		end)
		report()
	end)
	return function()
		generation += 1
		local connection = updates
		if connection ~= nil then
			connection:Disconnect()
		end
		updates = nil
		snapshot = nil
	end
end

return AnalyticsSwitchSystem
