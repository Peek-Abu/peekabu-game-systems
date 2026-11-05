--!strict
--[=[
	OfficeServiceClient: the Harlow & Finch office on this client (Cleanup Crew spec §6.2 "Office: … atmosphere
	presets"; §7 "The office at night"). Starts OfficeAtmosphereSystem (presets per phase and tier, overtime red,
	broken fluorescents, the hum) and OfficeAmbienceSystem (phones ringing in empty rooms, the
	elevator, typing that stops when you come close) and OfficeAnomalySystem (the run's exterior anomalies the server
	publishes on the office model). Everything it does is client-local presentation; the office itself is the
	server's.

	Spec-exempt shell (starts the systems).

	@class OfficeServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAmbienceSystem = require(ReplicatedStorage.Client.Features.Office.Systems.OfficeAmbienceSystem)
local OfficeAnomalySystem = require(ReplicatedStorage.Client.Features.Office.Systems.OfficeAnomalySystem)
local OfficeAtmosphereSystem = require(ReplicatedStorage.Client.Features.Office.Systems.OfficeAtmosphereSystem)

export type OfficeClientState = {
	atmosphere: OfficeAtmosphereSystem.OfficeAtmosphereState,
	ambience: OfficeAmbienceSystem.OfficeAmbienceState,
	anomalies: OfficeAnomalySystem.OfficeAnomalyState,
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
		OfficeAmbienceSystem.start()
		OfficeAnomalySystem.start()
	end,

	stop = function(_self)
		OfficeAnomalySystem.stop()
		OfficeAmbienceSystem.stop()
		OfficeAtmosphereSystem.stop()
	end,

	getState = function(_self)
		return {
			atmosphere = OfficeAtmosphereSystem.getState(),
			ambience = OfficeAmbienceSystem.getState(),
			anomalies = OfficeAnomalySystem.getState(),
		}
	end,
}

return OfficeServiceClient
