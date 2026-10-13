--!strict
--[=[
	EmployeeServiceServer: the crew are employees. At init it installs the default employee as StarterPlayer's
	StarterCharacter (EmployeeSpawnSystem), before any service starts loading characters; at start it respawns
	anyone whose character loaded before that (a player who joined during boot), then runs the expression
	pass (EmployeeExpressionSystem) every EXPRESSION_INTERVAL from the Manager's mind (Occupant) and each
	player's activity (Vacuum, Carry, Cargo pockets). Every employee character that spawns is dressed in
	its player's skin (EmployeeSkinSystem; who wears what is EmployeeSkinRegistry, MVP only).

	@class EmployeeServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeSkinRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeSkinRegistry)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local EmployeeExpressionSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeExpressionSystem)
local EmployeeSkinSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeSkinSystem)
local EmployeeSpawnSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeSpawnSystem)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

local log = Logger.new("EmployeeServiceServer")

local installed = false
local installError: string? = nil
local respawned = 0
-- Characters dressed in a skin that changed something, and the last skin each player was given.
local skinned = 0
local skinOf: { [number]: string } = {}
local connections: { RBXScriptConnection } = {}

local expressions = EmployeeExpressionSystem.new({
	mind = function()
		return OccupantServiceServer:getMind()
	end,
	managerPosition = function()
		local harlow = OccupantServiceServer:getHarlow()
		return if harlow ~= nil and harlow.Parent ~= nil then harlow:GetPivot().Position else nil
	end,
	now = os.clock,
})

local function isCarrying(player: Player): boolean
	return CarryServiceServer:getCarried(player) ~= nil or #CargoServiceServer:pocketsOf(player) > 0
end

local function subjects(): { EmployeeExpressionSystem.Subject }
	local list: { EmployeeExpressionSystem.Subject } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil and character.Parent ~= nil then
			table.insert(list, {
				userId = player.UserId,
				character = character,
				vacuuming = VacuumServiceServer:isVacuuming(player),
				carrying = isCarrying(player),
			})
		end
	end
	return list
end

local function accessorySource(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, name in EmployeeConstants.ACCESSORIES_PATH do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- Dresses a spawned employee character in its player's skin (server-side, so it replicates).
local function dress(player: Player, character: Model)
	local name = character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)
	local def = if type(name) == "string" then EmployeeRegistry.get(name) else nil
	if def == nil then
		return
	end
	local skin = EmployeeSkinRules.select(def, EmployeeSkinRegistry.skinFor(player.UserId))
	if skin == nil then
		log:warn(`{def.name} has no default skin {def.defaultSkin}`)
		return
	end
	skinOf[player.UserId] = skin.name
	local result = EmployeeSkinSystem.apply(character, skin, accessorySource())
	if result.textured > 0 or result.facesSwapped or result.accessories > 0 then
		skinned += 1
	end
end

local function watchSpawns(player: Player)
	table.insert(
		connections,
		player.CharacterAdded:Connect(function(character: Model)
			dress(player, character)
		end)
	)
	local character = player.Character
	if character ~= nil then
		dress(player, character)
	end
end

export type EmployeeServiceServer = {
	dependencies: { string },
	init: (self: EmployeeServiceServer) -> (),
	start: (self: EmployeeServiceServer) -> (),
	stop: (self: EmployeeServiceServer) -> (),
	getState: (self: EmployeeServiceServer) -> { [string]: unknown },
}

local EmployeeServiceServer: EmployeeServiceServer = {
	dependencies = { "OccupantServiceServer", "VacuumServiceServer", "CarryServiceServer", "CargoServiceServer" },

	init = function(_self)
		local def = EmployeeRegistry.get(EmployeeRegistry.DEFAULT)
		if def == nil then
			installError = `unknown default employee {EmployeeRegistry.DEFAULT}`
		else
			local ok, reason = EmployeeSpawnSystem.install(def, ReplicatedStorage, StarterPlayer)
			installed = ok
			installError = reason
		end
		if not installed then
			log:warn(`players keep their avatars: {installError}`)
		end
	end,

	start = function(_self)
		if installed then
			-- Anyone who spawned before the install (joined during boot) gets the employee now.
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character ~= nil and character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == nil then
					respawned += 1
					task.spawn(function()
						player:LoadCharacterAsync()
					end)
				end
			end
		end
		for _, player in Players:GetPlayers() do
			watchSpawns(player)
		end
		table.insert(connections, Players.PlayerAdded:Connect(watchSpawns))
		local elapsed = 0
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function(dt: number)
				elapsed += dt
				if elapsed < EmployeeConstants.EXPRESSION_INTERVAL then
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
				skinOf[player.UserId] = nil
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
			employee = EmployeeRegistry.DEFAULT,
			installed = installed,
			installError = installError,
			respawned = respawned,
			skinned = skinned,
			skins = skinOf,
			expressions = expressions.getState(),
		}
	end,
}

return EmployeeServiceServer
