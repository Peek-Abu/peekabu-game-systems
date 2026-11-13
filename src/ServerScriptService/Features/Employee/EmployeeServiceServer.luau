--!strict
--[=[
	EmployeeServiceServer: the crew are employees. At init it installs the default employee as StarterPlayer's
	StarterCharacter (EmployeeSpawnSystem), before any service starts loading characters; at start it respawns
	anyone whose character loaded before that (a player who joined during boot), then runs the expression
	pass (EmployeeExpressionSystem) every EXPRESSION_INTERVAL from the Manager's mind (Occupant) and each
	player's activity (Vacuum, Carry, Cargo pockets) and condition (dead or ragdolled: Death). Every employee character that spawns is dressed in
	its player's skin (EmployeeSkinSystem; who wears what is the player's Cosmetic loadout), then in the company
	uniform over it (EmployeeGearSystem: the employee's `uniform`), whose lanyard and ID card show the player's name and
	rank, repainted whenever Rank publishes a new rank for them.

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
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeFaceRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeFaceRules)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local EmployeeCharacterSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeCharacterSystem)
local EmployeeExpressionSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeExpressionSystem)
local EmployeeGearSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeGearSystem)
local EmployeeSkinSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeSkinSystem)
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
-- Characters dressed in a skin that changed something, and the last skin each player was given.
local skinned = 0
local skinOf: { [number]: string } = {}
-- Characters given a uniform piece.
local uniformed = 0
local connections: { RBXScriptConnection } = {}
-- What each player's current character was built as (employee, skin key and colour style), to tell whether a
-- loadout change needs a new character.
local worn: { [number]: EmployeeSkinRules.Worn } = {}
local swapped = 0
-- The hub (where the welcome card shows and employees are swapped), and the players whose first character there has
-- been rebuilt once already (EmployeeConstants.WARM_SWAP_DELAY).
local isHub = game.PlaceId == DepotConstants.HUB_PLACE_ID
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

local function resolve(path: { string }): Instance?
	local current: Instance? = ReplicatedStorage
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function accessorySource(): Instance?
	return resolve(EmployeeConstants.ACCESSORIES_PATH)
end

-- The art-owned skinned outfits a skin can name (EmployeeOutfitSystem).
local function outfitSource(): Instance?
	return resolve(EmployeeConstants.OUTFITS_PATH)
end

-- The player's general account rank level (1..7; level 1 until Rank has loaded it).
local function rankLevelOf(userId: number)
	local progress = RankServiceServer:progressOf(userId)
	return if progress ~= nil then progress.level else RankFormulas.progress(0).level
end

-- The player's lanyard: their name and their published rank (level 1 until Rank has loaded it).
local function badgeOf(player: Player): EmployeeGearSystem.Badge
	local level = rankLevelOf(player.UserId)
	return {
		holder = player.DisplayName,
		title = level.name,
		band = `RANK: {string.upper(level.name)}`,
		colour = level.lanyard,
	}
end

-- The skin key (EmployeeRegistry `skins`) the player's loadout puts on `employee`: the Cosmetic skin id after the
-- dot (Pippa.OwnerSpecial -> OwnerSpecial); nil before the loadout loads. A skin without art yet falls back to the
-- Default (EmployeeSkinRules.select).
local function skinKeyOf(userId: number, employee: string): string?
	local look = CosmeticServiceServer:lookOf(userId, employee)
	if look == nil then
		return nil
	end
	return string.match(look.skin, "^[^%.]+%.(.+)$")
end

-- The chosen idle item's key (after the dot) for `employee`: only a non-free idle that fits the worn skin
-- (CosmeticRules.lookFor already drops one that does not); nil = the skin's own idle.
local function idleKeyOf(userId: number, employee: string): string?
	local look = CosmeticServiceServer:lookOf(userId, employee)
	local item = if look ~= nil then CosmeticRegistry.get(look.idle) else nil
	if item == nil or item.source == "default" then
		return nil
	end
	return CosmeticRegistry.keyOf(item.id)
end

-- Names the idle the player's look picks on their character (Animate rebinds its idle when it changes): no rebuild.
local function markIdle(userId: number, character: Model, employee: string)
	local key = idleKeyOf(userId, employee)
	if character:GetAttribute(EmployeeConstants.IDLE_ATTRIBUTE) ~= key then
		character:SetAttribute(EmployeeConstants.IDLE_ATTRIBUTE, key)
	end
end

-- The colour style the player's loadout picks for `skin` on `employee`, clamped to one the skin has (1 before the
-- loadout loads, or for a skin with no styles).
local function styleOf(userId: number, employee: string, skin: EmployeeRegistry.SkinDef): number
	local look = CosmeticServiceServer:lookOf(userId, employee)
	return EmployeeSkinRules.styleIndex(skin, if look ~= nil then look.style else nil)
end

-- Names the vacuum the player's outfit wants on their character (VacuumServiceServer wears it, and swaps the pack
-- when it changes); nothing before the loadout loads (Standard Issue).
local function markVacuum(userId: number, character: Model)
	local outfit = CosmeticServiceServer:outfitOf(userId)
	if outfit ~= nil then
		local key = CosmeticRegistry.keyOf(outfit.vacuum)
		if character:GetAttribute(VacuumConstants.SKIN_ATTRIBUTE) ~= key then
			character:SetAttribute(VacuumConstants.SKIN_ATTRIBUTE, key)
		end
	end
end

-- Dresses a spawned employee character in its player's skin, then the uniform over it (server-side, so it
-- replicates). The skin goes first: its palette is for the body's MeshParts, never the uniform's.
local function dress(player: Player, character: Model)
	local name = character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)
	local def = if type(name) == "string" then EmployeeRegistry.get(name) else nil
	if def == nil then
		return
	end
	local skin = EmployeeSkinRules.select(def, skinKeyOf(player.UserId, def.name))
	if skin == nil then
		log:warn(`{def.name} has no default skin {def.defaultSkin}`)
		return
	end
	local style = styleOf(player.UserId, def.name, skin)
	skinOf[player.UserId] = skin.name
	worn[player.UserId] = { employee = def.name, skin = skin.name, style = style }
	-- The skin the outfit asks for (its art may still be the Default's): a preview of the outfit matches on it.
	character:SetAttribute(EmployeeConstants.SKIN_ATTRIBUTE, skinKeyOf(player.UserId, def.name) or skin.name)
	character:SetAttribute(EmployeeConstants.STYLE_ATTRIBUTE, style)
	markIdle(player.UserId, character, def.name)
	character:SetAttribute(EmployeeConstants.RANK_ATTRIBUTE, rankLevelOf(player.UserId).level)
	for _, legacyName in { "PippaVest", "PippaLanyard" } do
		local legacy = character:FindFirstChild(legacyName)
		if legacy ~= nil then
			legacy:Destroy()
		end
	end
	local result = EmployeeSkinSystem.apply(character, skin, accessorySource(), style, outfitSource())
	if skin.outfit ~= nil and not result.outfit then
		log:warn(`{def.name} skin {skin.name}: outfit {skin.outfit} could not be fitted`)
	end
	if result.textured > 0 or result.facesSwapped or result.accessories > 0 or result.outfit then
		skinned += 1
	end
	if EmployeeGearSystem.wear(character, def.uniform, accessorySource()) > 0 then
		uniformed += 1
		EmployeeGearSystem.badge(character, badgeOf(player))
	end
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

-- The hub's one hidden swap (EmployeeConstants.WARM_SWAP_DELAY): the same employee rebuilt where it stands, with no
-- goo puff, while the welcome card still covers the screen.
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
	markVacuum(player.UserId, model)
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
	markVacuum(player.UserId, model)
	EmployeeCharacterSystem.assign(player, model, nil, false)
	if isHub and not warmed[player.UserId] then
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
	markVacuum(userId, character)
	local employee = CosmeticServiceServer:currentEmployee(userId)
	-- A new idle needs no rebuild either: the character's idle attribute changes and its Animate rebinds.
	local current = worn[userId]
	if current ~= nil and current.employee == employee then
		markIdle(userId, character, employee)
	end
	local def = EmployeeRegistry.get(employee)
	if def == nil or current == nil then
		return
	end
	local wantedSkin = EmployeeSkinRules.select(def, skinKeyOf(userId, employee))
	if
		wantedSkin ~= nil
		and not EmployeeSkinRules.wornChanged(current, employee, wantedSkin.name, styleOf(userId, employee, wantedSkin))
	then
		return
	end
	local model = buildFor(player)
	if model == nil then
		return
	end
	model:SetAttribute(EmployeeConstants.SWAP_ATTRIBUTE, true)
	markVacuum(userId, model)
	swapped += 1
	EmployeeCharacterSystem.assign(player, model, character:GetPivot(), true)
end

local function watchSpawns(player: Player)
	local watching: RBXScriptConnection? = spawnWatches[player]
	if watching ~= nil then
		return
	end
	spawnWatches[player] = player.CharacterAdded:Connect(function(character: Model)
		dress(player, character)
	end)
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
				character:SetAttribute(EmployeeConstants.RANK_ATTRIBUTE, rankLevelOf(userId).level)
				EmployeeGearSystem.badge(character, badgeOf(player))
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
				skinOf[player.UserId] = nil
				worn[player.UserId] = nil
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
			worn = worn,
			skinned = skinned,
			uniformed = uniformed,
			skins = skinOf,
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
		markVacuum(player.UserId, model)
		EmployeeCharacterSystem.assign(player, model, character:GetPivot(), true)
		return true, nil
	end,
}

return EmployeeServiceServer
