--!strict
--[=[
	ToonServiceServer: the crew are toons. At init it installs the default toon as StarterPlayer's
	StarterCharacter (ToonSpawnSystem), before any service starts loading characters; at start it respawns
	anyone whose character loaded before that (a player who joined during boot), then runs the expression
	pass (ToonExpressionSystem) every EXPRESSION_INTERVAL from the Manager's mind (Occupant) and each
	player's activity (Vacuum, Carry, Cargo pockets).

	@class ToonServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonRegistry = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonRegistry)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local ToonExpressionSystem = require(ServerScriptService.Features.Toon.Systems.ToonExpressionSystem)
local ToonSpawnSystem = require(ServerScriptService.Features.Toon.Systems.ToonSpawnSystem)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

local log = Logger.new("ToonServiceServer")

local installed = false
local installError: string? = nil
local respawned = 0
local connections: { RBXScriptConnection } = {}

local expressions = ToonExpressionSystem.new({
	mind = function()
		return OccupantServiceServer:getMind()
	end,
	managerPosition = function()
		local harlow = OccupantServiceServer:getHarlow()
		return if harlow ~= nil and harlow.Parent ~= nil then harlow:GetPivot().Position else nil
	end,
	now = os.clock,
})

local function isBusy(player: Player): boolean
	return VacuumServiceServer:isVacuuming(player)
		or CarryServiceServer:getCarried(player) ~= nil
		or #CargoServiceServer:pocketsOf(player) > 0
end

local function subjects(): { ToonExpressionSystem.Subject }
	local list: { ToonExpressionSystem.Subject } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil and character.Parent ~= nil then
			table.insert(list, { userId = player.UserId, character = character, busy = isBusy(player) })
		end
	end
	return list
end

export type ToonServiceServer = {
	dependencies: { string },
	init: (self: ToonServiceServer) -> (),
	start: (self: ToonServiceServer) -> (),
	stop: (self: ToonServiceServer) -> (),
	getState: (self: ToonServiceServer) -> { [string]: unknown },
}

local ToonServiceServer: ToonServiceServer = {
	dependencies = { "OccupantServiceServer", "VacuumServiceServer", "CarryServiceServer", "CargoServiceServer" },

	init = function(_self)
		local def = ToonRegistry.get(ToonRegistry.DEFAULT)
		if def == nil then
			installError = `unknown default toon {ToonRegistry.DEFAULT}`
		else
			local ok, reason = ToonSpawnSystem.install(def, ReplicatedStorage, StarterPlayer)
			installed = ok
			installError = reason
		end
		if not installed then
			log:warn(`players keep their avatars: {installError}`)
		end
	end,

	start = function(_self)
		if installed then
			-- Anyone who spawned before the install (joined during boot) gets the toon now.
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character ~= nil and character:GetAttribute(ToonConstants.NAME_ATTRIBUTE) == nil then
					respawned += 1
					task.spawn(function()
						player:LoadCharacterAsync()
					end)
				end
			end
		end
		local elapsed = 0
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function(dt: number)
				elapsed += dt
				if elapsed < ToonConstants.EXPRESSION_INTERVAL then
					return
				end
				elapsed = 0
				expressions.tick(subjects())
			end)
		)
		table.insert(
			connections,
			Players.PlayerRemoving:Connect(function(player: Player)
				expressions.forget(player.UserId)
			end)
		)
	end,

	stop = function(_self)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end,

	getState = function(_self)
		return {
			toon = ToonRegistry.DEFAULT,
			installed = installed,
			installError = installError,
			respawned = respawned,
			expressions = expressions.getState(),
		}
	end,
}

return ToonServiceServer
