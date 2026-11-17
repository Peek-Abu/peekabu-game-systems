--!strict
--[=[
	EmployeeServiceServer: the crew are employees. At init it installs the default employee as StarterPlayer's
	StarterCharacter (EmployeeSpawnSystem), before any service starts loading characters; at start it respawns
	anyone whose character loaded before that (a player who joined during boot), then runs the expression
	pass (EmployeeExpressionSystem) every EXPRESSION_INTERVAL from the Manager's mind (Occupant) and each
	player's activity (Vacuum, Carry, Cargo pockets) and condition (dead or ragdolled: Death). Every employee
	character that spawns is dressed in its player's skin and the company uniform (EmployeeDressSystem), whose
	lanyard is repainted whenever Rank publishes a new rank for them.

	Each player plays as their own employee (character systems step 2): Death calls `spawnFor` for every join and
	respawn (setCharacterLoader), which builds the character from the loadout (EmployeeCharacterSystem); the
	StarterCharacter stays installed only as the engine's fallback. When the loadout changes in the depot
	(CosmeticServiceServer.changed) and the player wears a different employee or skin than it names, the character is
	rebuilt where it stands (KeepPlace) and marked for the clients' goo puff (EmployeeConstants.SWAP_ATTRIBUTE).

	Every character built gets its player's five stat bars (EmployeeStatSystem: the employee's own, with any admin
	override from `overrideStats`, the `employeestatset` command, which rebuilds the character where it stands).

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
local EmployeeFaceRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeFaceRules)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local EmployeeCharacterSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeCharacterSystem)
local EmployeeDressSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeDressSystem)
local EmployeeExpressionSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeExpressionSystem)
local EmployeeGearSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeGearSystem)
local EmployeeSpawnSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeSpawnSystem)
local EmployeeStatSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeStatSystem)
local EmployeeStatOverrideTracker = require(ServerScriptService.Features.Employee.State.EmployeeStatOverrideTracker)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local RankServiceServer = require(ServerScriptService.Features.Rank.RankServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

local log = Logger.new("EmployeeServiceServer")

local installed = false
local installError: string? = nil
local respawned = 0
-- What the dressing did: skinned / uniformed counts, each player's last skin and what their character was built as.
local tally = EmployeeDressSystem.newTally()
local connections: { RBXScriptConnection } = {}
local swapped = 0
-- The players whose first character in this server has been rebuilt once already (EmployeeConstants.WARM_SWAP_DELAY).
local warmed: { [number]: true } = {}
local warmSwaps = 0
local cosmeticConnection: SignalTyped.Connection? = nil
-- Each player's CharacterAdded watch, disconnected when they leave (one per join otherwise piles up).
local spawnWatches: { [Player]: RBXScriptConnection } = {}
local rankConnection: SignalTyped.Connection? = nil
-- Admin stat overrides for testing (employeestatset).
local statOverrides = EmployeeStatOverrideTracker.new()

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

-- The employee the player should be and its built character (falling back to the default employee when this place
-- has no art for theirs); nil when even that is missing.
local function buildFor(player: Player): Model?
	local wanted = CosmeticServiceServer:currentEmployee(player.UserId)
	local scripts = StarterPlayer:FindFirstChild("StarterCharacterScripts") or Instance.new("Folder")
	for _, name in { wanted, EmployeeRegistry.DEFAULT } do
		local def = EmployeeRegistry.get(name)
		if def ~= nil then
			local model = EmployeeCharacterSystem.build(def, ReplicatedStorage, scripts)
			if model ~= nil then
				EmployeeStatSystem.apply(model, statOverrides:barsFor(player.UserId, def.name))
				return model
			end
			log:warn(`no art for employee {name} in this place; trying the default`)
		end
	end
	return nil
end

-- The one hidden swap per player per server (EmployeeConstants.WARM_SWAP_DELAY): the same employee rebuilt where it
-- stands, with no goo puff, while the arrival card (the hub's welcome card, the shift's route slip) still covers the
-- screen.
local function warmSwap(player: Player)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if
		player.Parent == nil
		or character == nil
		or character.Parent == nil
		or humanoid == nil
		or humanoid.Health <= 0
		or character:GetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE) ~= nil
	then
		return
	end
	local model = buildFor(player)
	if model == nil then
		return
	end
	EmployeeDressSystem.markVacuum(player.UserId, model)
	warmSwaps += 1
	EmployeeCharacterSystem.assign(player, model, character:GetPivot(), true)
end

--[=[
	Death's character loader: every join and respawn. Waits (up to LOADOUT_WAIT) for the saved loadout so the first
	spawn is already the right employee, then builds and assigns it at Death's spawn point. Falls back to the engine
	(the StarterCharacter) when nothing can be built.
]=]
local function spawnFor(player: Player)
	local waited = 0
	while CosmeticServiceServer:getLoadout(player.UserId) == nil and waited < EmployeeConstants.LOADOUT_WAIT do
		waited += task.wait(0.1)
	end
	if player.Parent == nil then
		return
	end
	local model = buildFor(player)
	if model == nil then
		player:LoadCharacterAsync()
		return
	end
	EmployeeDressSystem.markVacuum(player.UserId, model)
	EmployeeCharacterSystem.assign(player, model, nil, false)
	if not warmed[player.UserId] then
		warmed[player.UserId] = true
		task.delay(EmployeeConstants.WARM_SWAP_DELAY, warmSwap, player)
	end
end

-- Rebuilds the player's character where it stands when their loadout names another employee, skin or style than they wear.
local function swapIfChanged(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local character = if player ~= nil then player.Character else nil
	if player == nil or character == nil or character.Parent == nil or CosmeticServiceServer:isLocked() then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 or character:GetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE) ~= nil then
		return
	end
	-- A new vacuum needs no rebuild: the pack is swapped on the character as it stands.
	EmployeeDressSystem.markVacuum(userId, character)
	local employee = CosmeticServiceServer:currentEmployee(userId)
	-- A new idle needs no rebuild either: the character's idle attribute changes and its Animate rebinds.
	local current = tally.worn[userId]
	if current ~= nil and current.employee == employee then
		EmployeeDressSystem.markIdle(userId, character, employee)
	end
	local def = EmployeeRegistry.get(employee)
	if def == nil or current == nil then
		return
	end
	local wantedSkin = EmployeeSkinRules.select(def, EmployeeDressSystem.skinKeyOf(userId, employee))
	if
		wantedSkin ~= nil
		and not EmployeeSkinRules.wornChanged(
			current,
			employee,
			wantedSkin.name,
			EmployeeDressSystem.styleOf(userId, employee, wantedSkin)
		)
	then
		return
	end
	local model = buildFor(player)
	if model == nil then
		return
	end
	model:SetAttribute(EmployeeConstants.SWAP_ATTRIBUTE, true)
	EmployeeDressSystem.markVacuum(userId, model)
	swapped += 1
	EmployeeCharacterSystem.assign(player, model, character:GetPivot(), true)
end

local function watchSpawns(player: Player)
	EmployeeDressSystem.watch(tally, spawnWatches, player)
end

export type EmployeeServiceServer = {
	dependencies: { string },
	init: (self: EmployeeServiceServer) -> (),
	start: (self: EmployeeServiceServer) -> (),
	stop: (self: EmployeeServiceServer) -> (),
	getState: (self: EmployeeServiceServer) -> { [string]: unknown },
	overrideStats: (
		self: EmployeeServiceServer,
		player: Player,
		stats: { EmployeeProfileRegistry.Stat },
		bars: number?
	) -> (boolean, string?),
}

local EmployeeServiceServer: EmployeeServiceServer = {
	dependencies = {
		"OccupantServiceServer",
		"VacuumServiceServer",
		"CarryServiceServer",
		"CargoServiceServer",
		"RankServiceServer",
		"DeathServiceServer",
		"CosmeticServiceServer",
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
		-- Before Death starts loading joining players: every join and respawn builds the player's own employee.
		DeathServiceServer:setCharacterLoader(spawnFor)
	end,

	start = function(_self)
		if installed then
			-- Anyone who spawned before the install (joined during boot) gets the employee now.
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character ~= nil and character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == nil then
					respawned += 1
					task.spawn(spawnFor, player)
				end
			end
		end
		for _, player in Players:GetPlayers() do
			watchSpawns(player)
		end
		table.insert(connections, Players.PlayerAdded:Connect(watchSpawns))
		-- A promotion (or the rank loading after the spawn) updates that player's general rank attribute and lanyard at once.
		rankConnection = RankServiceServer.changed:Connect(function(userId: number)
			local player = Players:GetPlayerByUserId(userId)
			local character = if player ~= nil then player.Character else nil
			if player ~= nil and character ~= nil then
				character:SetAttribute(EmployeeConstants.RANK_ATTRIBUTE, EmployeeDressSystem.rankLevelOf(userId).level)
				EmployeeGearSystem.badge(character, EmployeeDressSystem.badgeOf(player))
			end
		end)
		cosmeticConnection = CosmeticServiceServer.changed:Connect(swapIfChanged)
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
				local watch: RBXScriptConnection? = spawnWatches[player]
				if watch ~= nil then
					watch:Disconnect()
					spawnWatches[player] = nil
				end
				expressions.forget(player.UserId)
				tally.skinOf[player.UserId] = nil
				tally.worn[player.UserId] = nil
				warmed[player.UserId] = nil
				statOverrides:forget(player.UserId)
			end)
		)
	end,

	stop = function(_self)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, watch in spawnWatches do
			watch:Disconnect()
		end
		table.clear(spawnWatches)
		if rankConnection ~= nil then
			rankConnection:Disconnect()
			rankConnection = nil
		end
		if cosmeticConnection ~= nil then
			cosmeticConnection:Disconnect()
			cosmeticConnection = nil
		end
		DeathServiceServer:setCharacterLoader(nil)
	end,

	getState = function(_self)
		return {
			employee = EmployeeRegistry.DEFAULT,
			installed = installed,
			installError = installError,
			respawned = respawned,
			swapped = swapped,
			warmSwaps = warmSwaps,
			worn = tally.worn,
			skinned = tally.skinned,
			uniformed = tally.uniformed,
			skins = tally.skinOf,
			statOverrides = statOverrides:count(),
			expressions = expressions.getState(),
		}
	end,

	--[=[
		Admin testing (employeestatset): overrides `stats` to `bars` for `player` (nil = back to their employee's own),
		then rebuilds their character where it stands so every speed starts from the new bars. False with the reason
		when the character cannot be rebuilt now (dead, knocked down, no character); the override still holds for
		their next spawn.
	]=]
	overrideStats = function(_self, player, stats, bars)
		for _, stat: EmployeeProfileRegistry.Stat in stats do
			if bars ~= nil then
				statOverrides:set(player.UserId, stat, bars)
			else
				statOverrides:clear(player.UserId, stat)
			end
		end
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if character == nil or character.Parent == nil or humanoid == nil or humanoid.Health <= 0 then
			return false, "no living character; it applies on the next spawn"
		end
		if character:GetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE) ~= nil then
			return false, "knocked down; it applies on the next spawn"
		end
		local model = buildFor(player)
		if model == nil then
			return false, "no employee art in this place"
		end
		model:SetAttribute(EmployeeConstants.SWAP_ATTRIBUTE, true)
		EmployeeDressSystem.markVacuum(player.UserId, model)
		EmployeeCharacterSystem.assign(player, model, character:GetPivot(), true)
		return true, nil
	end,
}

return EmployeeServiceServer
