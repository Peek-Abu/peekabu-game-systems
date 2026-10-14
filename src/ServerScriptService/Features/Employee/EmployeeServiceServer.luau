--!strict
--[=[
	EmployeeServiceServer: the crew are employees. At init it installs the default employee as StarterPlayer's
	StarterCharacter (EmployeeSpawnSystem), before any service starts loading characters; at start it respawns
	anyone whose character loaded before that (a player who joined during boot), then runs the expression
	pass (EmployeeExpressionSystem) every EXPRESSION_INTERVAL from the Manager's mind (Occupant) and each
	player's activity (Vacuum, Carry, Cargo pockets) and condition (dead or ragdolled: Death). Every employee character that spawns is dressed in
	its player's skin (EmployeeSkinSystem; who wears what is EmployeeSkinRegistry, MVP only), then in the company
	uniform over it (EmployeeGearSystem: the employee's `uniform`), whose lanyard and ID card show the player's name and
	rank, repainted whenever Rank publishes a new rank for them.

	@class EmployeeServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeSkinRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeSkinRegistry)
local EmployeeFaceRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeFaceRules)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local EmployeeExpressionSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeExpressionSystem)
local EmployeeGearSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeGearSystem)
local EmployeeSkinSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeSkinSystem)
local EmployeeSpawnSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeSpawnSystem)
local RankServiceServer = require(ServerScriptService.Features.Rank.RankServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

local log = Logger.new("EmployeeServiceServer")

local installed = false
local installError: string? = nil
local respawned = 0
-- Characters dressed in a skin that changed something, and the last skin each player was given.
local skinned = 0
local skinOf: { [number]: string } = {}
-- Characters given a uniform piece.
local uniformed = 0
local connections: { RBXScriptConnection } = {}
local rankConnection: SignalTyped.Connection? = nil

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

local function isKnockedOut(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local health = if humanoid ~= nil then humanoid.Health else 0
	return EmployeeFaceRules.isKnockedOut(health, character:GetAttribute(DeathConstants.RAGDOLL_NAME) == true)
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
				knockedOut = isKnockedOut(character),
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

-- The player's lanyard: their name and their published rank (level 1 until Rank has loaded it).
local function badgeOf(player: Player): EmployeeGearSystem.Badge
	local progress = RankServiceServer:progressOf(player.UserId)
	local level = if progress ~= nil then progress.level else RankFormulas.progress(0).level
	return {
		holder = player.DisplayName,
		title = level.name,
		band = `RANK: {string.upper(level.name)}`,
		colour = level.lanyard,
	}
end

-- Dresses a spawned employee character in its player's skin, then the uniform over it (server-side, so it
-- replicates). The skin goes first: its palette is for the body's MeshParts, never the uniform's.
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
	if EmployeeGearSystem.wear(character, def.uniform, accessorySource()) > 0 then
		uniformed += 1
		EmployeeGearSystem.badge(character, badgeOf(player))
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
	dependencies = {
		"OccupantServiceServer",
		"VacuumServiceServer",
		"CarryServiceServer",
		"CargoServiceServer",
		"RankServiceServer",
	},

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
		-- A promotion (or the rank loading after the spawn) repaints that player's lanyard at once.
		rankConnection = RankServiceServer.changed:Connect(function(userId: number)
			local player = Players:GetPlayerByUserId(userId)
			local character = if player ~= nil then player.Character else nil
			if player ~= nil and character ~= nil then
				EmployeeGearSystem.badge(character, badgeOf(player))
			end
		end)
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
		if rankConnection ~= nil then
			rankConnection:Disconnect()
			rankConnection = nil
		end
	end,

	getState = function(_self)
		return {
			employee = EmployeeRegistry.DEFAULT,
			installed = installed,
			installError = installError,
			respawned = respawned,
			skinned = skinned,
			uniformed = uniformed,
			skins = skinOf,
			expressions = expressions.getState(),
		}
	end,
}

return EmployeeServiceServer
