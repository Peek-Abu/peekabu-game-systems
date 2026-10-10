--!strict
--[=[
	NoiseServiceServer: noise from any source, as one stream (Cleanup Crew spec §4, §6.2 "Noise"). Vacuum's
	pulses and Cargo's drops, splashes, searches and rattles arrive on their `noiseMade` signals; anything else
	may call `emit`. Every noise fires `made` (Occupant decides whether Harlow hears it, through NoiseRules) and
	shows every client a ripple at the radius Harlow hears it at (the hearing scale Occupant keeps current).

	Spec-exempt shell (signals, ByteNet); the hearing rule is the specced NoiseRules.

	@class NoiseServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NoiseShared = ReplicatedStorage.Shared.Features.Noise
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local NoiseTypes = require(NoiseShared.Data.NoiseTypes)
local NoiseEvents = require(NoiseShared.Net.NoiseEvents)
local NoiseRules = require(NoiseShared.Rules.NoiseRules)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

local made: SignalTyped.Signal<NoiseTypes.NoiseEvent> = SignalTyped.new()
local hearingScale = 1
local total = 0
local bySource: { [string]: number } = {}
local stoppers: { () -> () } = {}

export type NoiseServiceServer = {
	dependencies: { string },
	made: SignalTyped.Signal<NoiseTypes.NoiseEvent>,
	start: (self: NoiseServiceServer) -> (),
	stop: (self: NoiseServiceServer) -> (),
	getState: (self: NoiseServiceServer) -> { [string]: any },
	emit: (self: NoiseServiceServer, position: Vector3, radius: number, source: string) -> (),
	setHearingScale: (self: NoiseServiceServer, scale: number) -> (),
	getHearingScale: (self: NoiseServiceServer) -> number,
}

local NoiseServiceServer: NoiseServiceServer = {
	dependencies = { "VacuumServiceServer", "CargoServiceServer" },
	made = made,

	--[=[
		Relays Vacuum's and Cargo's noise.
	]=]
	start = function(self)
		local vacuum = VacuumServiceServer.noiseMade:Connect(function(position: Vector3, radius: number, source: string)
			self:emit(position, radius, source)
		end)
		local cargo = CargoServiceServer.noiseMade:Connect(function(position: Vector3, radius: number, source: string)
			self:emit(position, radius, source)
		end)
		table.insert(stoppers, function()
			vacuum:Disconnect()
			cargo:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		One noise: fires `made` and draws a ripple for everyone. A noise with no usable radius or position is ignored.
	]=]
	emit = function(_self, position, radius, source)
		if not NoiseRules.valid(position, radius) then
			return
		end
		total += 1
		bySource[source] = (bySource[source] or 0) + 1
		local event: NoiseTypes.NoiseEvent = { position = position, radius = radius, source = source }
		made:Fire(event)
		NoiseEvents.packets.Ripple.sendToAll({
			position = position,
			radius = NoiseRules.heardRadius(radius, hearingScale),
		})
	end,

	--[=[
		Harlow's hearing scale (OccupantServiceServer keeps it current); it sizes the ripples.
	]=]
	setHearingScale = function(_self, scale)
		assert(
			NoiseRules.validScale(scale),
			"NoiseServiceServer:setHearingScale: the scale must be finite and positive"
		)
		hearingScale = scale
	end,

	getHearingScale = function(_self)
		return hearingScale
	end,

	getState = function(_self)
		return { total = total, bySource = table.clone(bySource), hearingScale = hearingScale }
	end,
}

return NoiseServiceServer
