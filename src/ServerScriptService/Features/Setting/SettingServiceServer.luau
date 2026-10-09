--!strict
--[=[
	SettingServiceServer: the account-wide `settings` slice and the one client-writable path into it
	(design: docs/superpowers/specs/2026-10-09-settings-design.md).

	A client's request (SettingEvents.Request) is rate limited by RequestHandler, parsed by
	SettingRules.parseRequest, refused for an unregistered id, coerced against the definition, and stored —
	defaults as absence. The slice validator (SettingRules.validate) guards every other write path too.

	@class SettingServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SettingShared = ReplicatedStorage.Shared.Features.Setting
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local SettingRegistry = require(SettingShared.Data.SettingRegistry)
local SettingEvents = require(SettingShared.Net.SettingEvents)
local SettingRules = require(SettingShared.Rules.SettingRules)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)

local settingsSlice = PlayerDataSliceSystem.registerAccount("settings", {
	values = {},
}, function(account)
	return account.settings
end, SettingRules.validate)

local log = Logger.new("SettingServiceServer")

local stoppers: { () -> () } = {}

export type SettingServiceServer = {
	dependencies: { string },
	init: (self: SettingServiceServer) -> (),
	stop: (self: SettingServiceServer) -> (),
	get: (self: SettingServiceServer, userId: number, id: string) -> PlayerDataTypes.SettingValue?,
	set: (self: SettingServiceServer, userId: number, id: string, value: unknown) -> (boolean, string?),
	reset: (self: SettingServiceServer, userId: number, id: string?) -> boolean,
	-- TEST SEAM: the RequestHandler-wrapped request handler (the TitleServiceServer convention).
	_onRequest: (payload: unknown, player: Player) -> any,
	getState: (self: SettingServiceServer) -> { [string]: any },
}

local SettingServiceServer: SettingServiceServer

local onRequest = RequestHandler.wrap({
	name = "SettingRequest",
	rateLimit = { maxRequests = 20, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local request, reason = SettingRules.parseRequest(payload)
		if request == nil then
			log:warn(`bad setting request from {player.Name}: {reason or "?"}`)
			return
		end
		if request.kind == "resetAll" then
			SettingServiceServer:reset(player.UserId, nil)
		elseif request.kind == "reset" then
			SettingServiceServer:reset(player.UserId, request.id)
		else
			local ok, refused = SettingServiceServer:set(player.UserId, request.id, request.value)
			if not ok and refused ~= nil then
				log:debug(`setting "{request.id}" refused for {player.Name}: {refused}`)
			end
		end
	end,
})

SettingServiceServer = {
	dependencies = { "PlayerDataServiceServer" },

	init = function(_self)
		table.insert(
			stoppers,
			SettingEvents.packets.Request.listen(function(payload: unknown, player: Player?)
				if player then
					onRequest(payload, player)
				end
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		A setting's value for a player (the default when they never changed it), or nil when the profile
		is not loaded or the id is not registered.
	]=]
	get = function(_self, userId, id)
		local settings = settingsSlice.get(userId)
		return if settings ~= nil then SettingRules.valueOf(settings, id) else nil
	end,

	--[=[
		Sets a registered setting after checking the value against its definition (numbers snap to their
		step). False with a reason when refused or unchanged.
	]=]
	set = function(_self, userId, id, value)
		Guard.userId(userId)
		local def = SettingRegistry.get(id)
		if def == nil then
			return false, `unknown setting "{id}"`
		end
		local coerced, reason = SettingRules.coerce(def, value)
		if coerced == nil then
			return false, reason
		end
		local changed, rejected = settingsSlice.mutate(userId, function(settings)
			return SettingRules.store(settings, id, coerced)
		end)
		if changed then
			return true, nil
		end
		return false, rejected or "unchanged or profile not loaded"
	end,

	--[=[
		Returns one setting (or, with no id, every setting) to its default. True when anything changed.
	]=]
	reset = function(_self, userId, id)
		Guard.userId(userId)
		local changed = settingsSlice.mutate(userId, function(settings)
			return if id ~= nil then SettingRules.clear(settings, id) else SettingRules.clearAll(settings)
		end)
		return changed
	end,

	_onRequest = onRequest,

	getState = function(_self)
		return { settings = SettingRegistry.ids() }
	end,
}

return SettingServiceServer
