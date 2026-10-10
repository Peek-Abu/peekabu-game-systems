--!strict
--[=[
	OfficeServiceClient: the Harlow & Finch office on this client (Cleanup Crew spec §6.2 "Office: … atmosphere
	presets"; §7 "The office at night"). Starts OfficeAtmosphereSystem (presets per phase and tier, overtime red,
	broken fluorescents, the hum). Everything it does is client-local presentation; the office itself is the
	server's.

	Spec-exempt shell (starts the systems).

	@class OfficeServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAtmosphereSystem = require(ReplicatedStorage.Client.Features.Office.Systems.OfficeAtmosphereSystem)

export type OfficeClientState = {
	atmosphere: OfficeAtmosphereSystem.OfficeAtmosphereState,
}

export type OfficeServiceClient = {
	dependencies: { string },
	start: (self: OfficeServiceClient) -> (),
	stop: (self: OfficeServiceClient) -> (),
	getState: (self: OfficeServiceClient) -> OfficeClientState,
}

local OfficeServiceClient: OfficeServiceClient = {
	dependencies = { "StateSyncServiceClient", "SoundServiceClient", "VfxServiceClient" },

	start = function(_self)
		OfficeAtmosphereSystem.start()
	end,

	stop = function(_self)
		OfficeAtmosphereSystem.stop()
	end,

	getState = function(_self)
		return { atmosphere = OfficeAtmosphereSystem.getState() }
	end,
}

return OfficeServiceClient
