--!strict
--[=[
	SprintServiceServer: sprinting with stamina (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §3),
	server-authoritative: the client only says whether its sprint key is held (SprintEvents.Sprint, rate limited); every
	TICK the server decides (SprintRules: alive, not frozen in a catch, not hiding, empty hands, the bar allows) and owns
	the speed, SPRINT_SPEED while sprinting and the player's own speed otherwise. The bar (SprintStaminaFormulas) drains
	only while they move at a sprint and is published as the Player's SprintStamina / Sprinting attributes (the HUD's
	bar). Sprinting feet are heard: a small noise every SPRINT_NOISE_INTERVAL while moving at a sprint (NoiseServiceServer;
	walking stays silent).

	Carrying never sprints. Carry is told the unboosted speed (CarryServiceServer:setSpeedBase), so an item picked up
	mid-sprint slows the walk speed, never the sprint, and dropping it restores the walk; the sprint then just ends.

	Spec-exempt shell (Humanoids, Players, ByteNet, RunService); the decisions are the specced SprintRules and
	SprintStaminaFormulas.

	@class SprintServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local SprintShared = ReplicatedStorage.Shared.Features.Sprint
local Observers = require(ReplicatedStorage.Packages.Observers)
local SprintConstants = require(SprintShared.Data.SprintConstants)
local SprintEvents = require(SprintShared.Net.SprintEvents)
local SprintRules = require(SprintShared.Rules.SprintRules)
local SprintStaminaFormulas = require(SprintShared.Utils.SprintStaminaFormulas)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)

type Runner = {
	requested: boolean,
	bar: SprintStaminaFormulas.Stamina,
	-- The humanoid whose speed is boosted now, and its own speed to restore (nil while not sprinting).
	boosted: Humanoid?,
	base: number?,
	-- Seconds of moving sprint since the last footstep noise.
	stepClock: number,
	published: number,
	-- Where the body was at the last tick.
	lastPosition: Vector3?,
}

local runners: { [number]: Runner } = {}
local stoppers: { () -> () } = {}
local elapsed = 0
local counters = { sprints = 0, steps = 0, refused = 0 }

local function runnerOf(player: Player): Runner
	local runner = runners[player.UserId]
	if runner == nil then
		runner = {
			requested = false,
			bar = SprintStaminaFormulas.fresh(),
			boosted = nil,
			base = nil,
			stepClock = 0,
			published = 1,
			lastPosition = nil,
		}
		runners[player.UserId] = runner
	end
	return runner
end

-- Ends a boost: the humanoid gets its own speed back, unless Carry owns the speed now (it was given the base).
local function unboost(player: Player, runner: Runner)
	local humanoid = runner.boosted
	local base = runner.base
	runner.boosted = nil
	runner.base = nil
	if humanoid ~= nil and base ~= nil and humanoid.Parent ~= nil and CarryServiceServer:getCarried(player) == nil then
		humanoid.WalkSpeed = base
	end
	player:SetAttribute(SprintConstants.SPRINTING_ATTRIBUTE, nil)
end

local onSprint = RequestHandler.wrap({
	name = "Sprint",
	rateLimitKey = "Sprint",
	rateLimit = SprintConstants.REQUEST_RATE,
	handler = function(data: unknown, player: Player)
		if type(data) == "boolean" then
			runnerOf(player).requested = data
		end
	end,
})

local function stepOne(player: Player, runner: Runner, dt: number)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local alive = humanoid ~= nil and humanoid.Health > 0 and not DeathServiceServer:isDead(player)
	local ok = SprintRules.canSprint({
		requested = runner.requested,
		alive = alive,
		frozen = root ~= nil and root:IsA("BasePart") and root.Anchored,
		hidden = HideServiceServer:isHidden(player),
		carrying = CarryServiceServer:getCarried(player) ~= nil,
		stamina = SprintStaminaFormulas.canStart(runner.bar),
	})
	if runner.boosted ~= nil and (not ok or runner.boosted ~= humanoid) then
		unboost(player, runner)
	end
	if ok and humanoid ~= nil and runner.boosted == nil then
		runner.boosted = humanoid
		runner.base = humanoid.WalkSpeed
		humanoid.WalkSpeed = SprintConstants.SPRINT_SPEED
		player:SetAttribute(SprintConstants.SPRINTING_ATTRIBUTE, true)
		counters.sprints += 1
	elseif not ok and runner.requested then
		counters.refused += 1
	end
	-- Moving: the body really goes somewhere across the floor since the last tick, measured from its positions (the
	-- client owns its physics, so its velocity is not trusted here). Pushing against a wall spends nothing.
	local position = if root ~= nil and root:IsA("BasePart") then root.Position else nil
	local last = runner.lastPosition
	runner.lastPosition = position
	local moving = position ~= nil
		and last ~= nil
		and Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude / dt >= SprintConstants.MOVING_SPEED
	local draining = runner.boosted ~= nil and moving
	runner.bar = SprintStaminaFormulas.step(runner.bar, dt, draining)
	if draining and root ~= nil and root:IsA("BasePart") then
		runner.stepClock += dt
		if runner.stepClock >= SprintConstants.SPRINT_NOISE_INTERVAL then
			runner.stepClock = 0
			counters.steps += 1
			NoiseServiceServer:emit(
				root.Position,
				SprintConstants.SPRINT_NOISE_RADIUS,
				SprintConstants.NOISE_SOURCE,
				{ player.UserId }
			)
		end
	else
		runner.stepClock = 0
	end
	local shown = math.round(runner.bar.stamina / SprintConstants.STAMINA_STEP) * SprintConstants.STAMINA_STEP
	if shown ~= runner.published then
		runner.published = shown
		player:SetAttribute(SprintConstants.STAMINA_ATTRIBUTE, shown)
	end
end

local function onHeartbeat(deltaTime: number)
	elapsed += deltaTime
	if elapsed < SprintConstants.TICK then
		return
	end
	local dt = elapsed
	elapsed = 0
	for _, player in Players:GetPlayers() do
		stepOne(player, runnerOf(player), dt)
	end
end

export type SprintServiceServer = {
	dependencies: { string },
	start: (self: SprintServiceServer) -> (),
	stop: (self: SprintServiceServer) -> (),
	getState: (self: SprintServiceServer) -> { [string]: any },
	isSprinting: (self: SprintServiceServer, player: Player) -> boolean,
	stamina: (self: SprintServiceServer, player: Player) -> number,
}

local SprintServiceServer: SprintServiceServer = {
	dependencies = { "CarryServiceServer", "DeathServiceServer", "HideServiceServer", "NoiseServiceServer" },

	--[=[
		Listens for sprint requests, tells Carry the unboosted speed, and steps everyone's sprint every TICK.
	]=]
	start = function(_self)
		CarryServiceServer:setSpeedBase(function(player: Player): number?
			local runner = runners[player.UserId]
			return if runner ~= nil and runner.boosted ~= nil then runner.base else nil
		end)
		table.insert(
			stoppers,
			SprintEvents.packets.Sprint.listen(function(data: boolean, player: Player?)
				if player then
					onSprint(data, player)
				end
			end)
		)
		local heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
			runners[player.UserId] = nil
		end)
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, _character: Model)
				-- A fresh body is fresh legs (the old one's boost went with it).
				local runner = runnerOf(player)
				runner.boosted = nil
				runner.base = nil
				runner.bar = SprintStaminaFormulas.fresh()
				runner.lastPosition = nil
				return nil
			end)
		)
		table.insert(stoppers, function()
			heartbeat:Disconnect()
			leaving:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		CarryServiceServer:setSpeedBase(nil)
		for userId, runner in runners do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				unboost(player, runner)
			end
		end
		table.clear(runners)
	end,

	isSprinting = function(_self, player)
		local runner = runners[player.UserId]
		return runner ~= nil and runner.boosted ~= nil
	end,

	--[=[
		The player's stamina bar, 0-1.
	]=]
	stamina = function(_self, player)
		local runner = runners[player.UserId]
		return if runner ~= nil then runner.bar.stamina else 1
	end,

	getState = function(_self)
		local sprinting = 0
		for _, runner in runners do
			if runner.boosted ~= nil then
				sprinting += 1
			end
		end
		return { sprinting = sprinting, counters = table.clone(counters) }
	end,
}

return SprintServiceServer
