--!strict
--[=[
	DeathServiceServer: one death flow for players and NPCs (design:
	docs/superpowers/specs/2026-10-09-death-design.md).

	- `damage(humanoid, amount, source)` records who hit (DeathCreditTracker) and applies the damage;
	  `kill(humanoid, cause)` kills outright. A death is credited to the last source in `creditWindow`.
	- Characters get `BreakJointsOnDeath = false` and ragdoll on death (Motor6Ds → limited
	  BallSocketConstraints). NPCs opt in through `track(model)`.
	- A player's death sets the public `dead` field (cleared on the next spawn), ends their granted
	  animations (`AnimationServiceServer:stopAll`) and fires `died`; every tracked death fires
	  `humanoidDied`.
	- Respawn policy: `auto` (the engine, after `respawnDelay`) or `manual` (only `respawn(player)`).
	- `setSpawnPoint(resolver)` chooses where characters appear; `kill(..., { launch })` throws the body as it dies.

	Spec-exempt shell (Humanoids, joints, Players); the rules are the specced DeathCreditTracker,
	DeathRagdollUtils and DeathSpectateRules.

	@class DeathServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DeathData = ReplicatedStorage.Shared.Features.Death.Data
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local DeathConstants = require(DeathData.DeathConstants)
local DeathTypes = require(DeathData.DeathTypes)
local DeathRagdollUtils = require(ReplicatedStorage.Shared.Features.Death.Utils.DeathRagdollUtils)
local DeathCreditTracker = require(ServerScriptService.Features.Death.State.DeathCreditTracker)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

type DeathInfo = DeathTypes.DeathInfo
type DeathConfig = DeathTypes.DeathConfig

local log = Logger.new("DeathServiceServer")

local died: SignalTyped.Signal<Player, DeathInfo> = SignalTyped.new()
local humanoidDied: SignalTyped.Signal<Model, DeathInfo> = SignalTyped.new()

local config: DeathConfig = table.clone(DeathConstants.DEFAULT_CONFIG)
local credits = DeathCreditTracker.new()
-- An explicit cause from kill(), read when the humanoid dies. Weak keys, like the credit tracker.
local causes: { [Humanoid]: string } = {}
setmetatable(causes, { __mode = "k" })
-- A launch from kill(), applied when the humanoid dies. Weak keys, like `causes`.
local launches: { [Humanoid]: Vector3 } = {}
setmetatable(launches, { __mode = "k" })
local spawnResolver: DeathTypes.SpawnResolver? = nil
local counters = { playerDeaths = 0, rigDeaths = 0, ragdolls = 0 }
local stoppers: { () -> () } = {}

local function infoFor(humanoid: Humanoid): DeathInfo
	local source = credits:credit(humanoid, os.clock(), config.creditWindow)
	local cause = causes[humanoid]
	credits:forget(humanoid)
	causes[humanoid] = nil
	return {
		killerUserId = if source ~= nil then source.userId else nil,
		killerName = if source ~= nil then source.name else nil,
		cause = cause,
	}
end

local function humanoidOf(model: Model): Humanoid?
	return model:FindFirstChildOfClass("Humanoid")
end

-- Swaps every non-root Motor6D for a limited ball socket. False when already ragdolled.
local function ragdollModel(model: Model): boolean
	if model:GetAttribute(DeathConstants.RAGDOLL_NAME) == true then
		return false
	end
	model:SetAttribute(DeathConstants.RAGDOLL_NAME, true)
	local jointParts: { [BasePart]: true } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and not DeathRagdollUtils.isRootJoint(descendant.Name) then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			if part0 ~= nil and part1 ~= nil then
				local limits = DeathRagdollUtils.limitsFor(descendant.Name)
				local attachment0 = Instance.new("Attachment")
				attachment0.Name = DeathConstants.RAGDOLL_NAME
				attachment0.CFrame = descendant.C0
				attachment0.Parent = part0
				local attachment1 = Instance.new("Attachment")
				attachment1.Name = DeathConstants.RAGDOLL_NAME
				attachment1.CFrame = descendant.C1
				attachment1.Parent = part1
				local socket = Instance.new("BallSocketConstraint")
				socket.Name = DeathConstants.RAGDOLL_NAME
				socket.Attachment0 = attachment0
				socket.Attachment1 = attachment1
				socket.LimitsEnabled = true
				socket.UpperAngle = limits.upperAngle
				socket.TwistLimitsEnabled = true
				socket.TwistLowerAngle = limits.twistLower
				socket.TwistUpperAngle = limits.twistUpper
				socket.Parent = part1
				descendant.Enabled = false
				jointParts[part0] = true
				jointParts[part1] = true
			end
		end
	end
	-- Limbs collide so the body lies on the floor; the root follows the torso without colliding.
	for part in jointParts do
		part.CanCollide = part.Name ~= "HumanoidRootPart"
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		root.CanCollide = false
		root.Massless = true
	end
	counters.ragdolls += 1
	return true
end

-- Takes the body from its owner and throws it. A player's character is simulated by that player's
-- client, which would ignore a velocity the server sets, so ownership moves to the server first.
local function launchModel(model: Model, velocity: Vector3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(nil)
			end)
			descendant.AssemblyLinearVelocity = velocity
		end
	end
end

-- Wires one humanoid's death. `player` is set for a player's character.
local function watch(model: Model, humanoid: Humanoid, player: Player?): RBXScriptConnection
	if config.ragdoll then
		humanoid.BreakJointsOnDeath = false
	end
	return humanoid.Died:Connect(function()
		local info = infoFor(humanoid)
		if player ~= nil then
			counters.playerDeaths += 1
			StateSyncPublicPlayerStore.set(player.UserId, { [DeathConstants.PUBLIC_FIELD] = true })
			AnimationServiceServer:stopAll(player)
		else
			counters.rigDeaths += 1
		end
		if config.ragdoll then
			ragdollModel(model)
		end
		local launch: Vector3? = launches[humanoid]
		launches[humanoid] = nil
		if launch ~= nil then
			launchModel(model, launch)
		end
		if player ~= nil then
			died:Fire(player, info)
		end
		humanoidDied:Fire(model, info)
	end)
end

local function applyRespawnPolicy()
	Players.RespawnTime = config.respawnDelay
	Players.CharacterAutoLoads = config.respawn == "auto"
end

export type DeathServiceServer = {
	dependencies: { string },
	died: SignalTyped.Signal<Player, DeathInfo>,
	humanoidDied: SignalTyped.Signal<Model, DeathInfo>,

	start: (self: DeathServiceServer) -> (),
	stop: (self: DeathServiceServer) -> (),
	getState: (self: DeathServiceServer) -> { [string]: any },

	configure: (self: DeathServiceServer, update: DeathTypes.DeathConfigUpdate) -> (),
	damage: (self: DeathServiceServer, humanoid: Humanoid, amount: number, source: DeathTypes.DamageSource?) -> (),
	kill: (self: DeathServiceServer, humanoid: Humanoid, cause: string?, options: DeathTypes.KillOptions?) -> (),
	setSpawnPoint: (self: DeathServiceServer, resolver: DeathTypes.SpawnResolver?) -> (),
	track: (self: DeathServiceServer, model: Model) -> (),
	ragdoll: (self: DeathServiceServer, model: Model) -> boolean,
	respawn: (self: DeathServiceServer, player: Player) -> boolean,
	isDead: (self: DeathServiceServer, player: Player) -> boolean,
}

local DeathServiceServer: DeathServiceServer = {
	dependencies = { "StateSyncServiceServer", "AnimationServiceServer" },
	died = died,
	humanoidDied = humanoidDied,

	--[=[
		Applies the respawn policy and watches every player's character.
	]=]
	start = function(_self)
		applyRespawnPolicy()
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, character: Model)
				local resolver = spawnResolver
				if resolver ~= nil then
					local ok, cframe = pcall(resolver, player)
					if not ok then
						log:warn(`spawn resolver failed for {player.Name}: {cframe}`)
					elseif typeof(cframe) == "CFrame" then
						-- Deferred: the engine places a new character after CharacterAdded fires.
						task.defer(function()
							if character.Parent ~= nil then
								character:PivotTo(cframe)
							end
						end)
					elseif cframe ~= nil then
						log:warn(`spawn resolver for {player.Name} returned {typeof(cframe)}, not a CFrame`)
					end
				end
				StateSyncPublicPlayerStore.clearField(player.UserId, DeathConstants.PUBLIC_FIELD)
				local humanoid = humanoidOf(character)
				if humanoid == nil then
					local found = character:WaitForChild("Humanoid", 5)
					humanoid = if found ~= nil and found:IsA("Humanoid") then found else nil
				end
				if humanoid == nil then
					log:warn(`{player.Name}'s character has no Humanoid; death is not tracked`)
					return nil
				end
				local connection = watch(character, humanoid, player)
				return function()
					connection:Disconnect()
				end
			end)
		)
		-- Under the manual policy the engine loads nobody, so joining players are loaded here.
		table.insert(
			stoppers,
			Observers.observePlayer(function(player: Player)
				if not Players.CharacterAutoLoads and player.Character == nil then
					task.spawn(function()
						player:LoadCharacterAsync()
					end)
				end
				return nil
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
		Changes the config (only the fields given) and applies the respawn policy at once.
	]=]
	configure = function(_self, update)
		local nextConfig = table.clone(config)
		for key, value in update do
			nextConfig[key] = value
		end
		assert(nextConfig.respawnDelay >= 0, "respawnDelay must not be negative")
		assert(nextConfig.creditWindow > 0, "creditWindow must be positive")
		assert(
			nextConfig.respawn == "auto" or nextConfig.respawn == "manual",
			`unknown respawn policy "{nextConfig.respawn}"`
		)
		config = nextConfig
		applyRespawnPolicy()
	end,

	--[=[
		Damages a humanoid and credits `source` for a kill within the credit window. Respects
		ForceFields (Humanoid:TakeDamage). Ignored for a dead humanoid or a non-positive amount.
	]=]
	damage = function(_self, humanoid, amount, source)
		if humanoid.Health <= 0 or amount <= 0 then
			return
		end
		if source ~= nil then
			credits:record(humanoid, source, os.clock())
		end
		humanoid:TakeDamage(amount)
	end,

	--[=[
		Kills a humanoid outright, with an optional cause ("fell", "caught", "round-ended") and an optional
		launch velocity applied to the body as it dies.
	]=]
	kill = function(_self, humanoid, cause, options)
		if humanoid.Health <= 0 then
			return
		end
		if cause ~= nil then
			causes[humanoid] = cause
		end
		if options ~= nil and options.launch ~= nil then
			launches[humanoid] = options.launch
		end
		humanoid.Health = 0
	end,

	--[=[
		Sets where every player's next character appears (a loading bay, a team base); nil restores the
		engine's choice. A resolver returning nil for a player leaves that spawn alone.
	]=]
	setSpawnPoint = function(_self, resolver)
		spawnResolver = resolver
	end,

	--[=[
		Gives a non-player rig (an NPC) the same death flow: ragdoll and `humanoidDied`.
	]=]
	track = function(_self, model)
		local humanoid = humanoidOf(model)
		if humanoid == nil then
			log:warn(`track: "{model.Name}" has no Humanoid`)
			return
		end
		watch(model, humanoid, nil)
	end,

	ragdoll = function(_self, model)
		return ragdollModel(model)
	end,

	--[=[
		Loads a new character for the player (the manual policy's way back). False if they left.
	]=]
	respawn = function(_self, player)
		if player.Parent == nil then
			return false
		end
		task.spawn(function()
			player:LoadCharacterAsync()
		end)
		return true
	end,

	isDead = function(_self, player)
		local entry = StateSyncPublicPlayerStore.get(player.UserId)
		return entry ~= nil and entry[DeathConstants.PUBLIC_FIELD] == true
	end,

	getState = function(_self)
		return {
			respawn = config.respawn,
			respawnDelay = config.respawnDelay,
			ragdoll = config.ragdoll,
			spawnResolver = spawnResolver ~= nil,
			counters = table.clone(counters),
		}
	end,
}

return DeathServiceServer
