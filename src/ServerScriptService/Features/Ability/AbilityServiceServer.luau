--!strict
--[=[
	AbilityServiceServer: each employee's ability (docs/superpowers/specs/2026-10-29-employee-abilities-design.md),
	server-authoritative. The client only asks (AbilityEvents.Use; Cancel ends a plant); every use is checked here
	(AbilityRules.canUse: a running shift, playing it, alive, not caught, not hiding, ready, and the ability's own needs)
	and a refusal spends nothing and says why in kid words (a toast). An accepted use spends the cooldown (the Player's
	AbilityReadyAt, server time; everyone is ready when a shift starts) and starts the effect at once, before any clip:

	- Let's Go! (Pippa): Pippa and every participant within its radius run faster (SprintServiceServer:boost, the one
	  non-stacking speed scale).
	- Spot It! (Cappy): the closest treasure (AbilityTreasureUtils: a grimy valuable nobody claimed, buried or not) is
	  sent to Cappy alone (AbilityEvents.Spotted); his client draws it through walls.
	- Potted Plant (Prickles): stealth in the shared Npc layer (NpcServiceServer:conceal): every monster that did not
	  see it begin can neither see nor catch him. It ends at once (AbilityRules.plantEnds) when he moves, jumps, acts,
	  asks, dies, is caught or the cap passes, and then he is revealed.

	The character's AbilityActive names the effect while it runs (others' clients draw it). Clips play over the
	effect (AnimationServiceServer:play) and never gate it: a refused or cut clip changes nothing; a full-body clip is
	stopped when its user moves (the upper-body one plays instead when they were already moving).

	Spec-exempt shell (Players, Humanoids, ByteNet, RunService, CollectionService); the decisions are the specced
	AbilityRules, AbilityRegistry, AbilityCooldownTracker and AbilityTreasureUtils.

	@class AbilityServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local AbilityShared = ReplicatedStorage.Shared.Features.Ability
local AbilityServer = ServerScriptService.Features.Ability
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AbilityConstants = require(AbilityShared.Data.AbilityConstants)
local AbilityRegistry = require(AbilityShared.Data.AbilityRegistry)
local AbilityTypes = require(AbilityShared.Data.AbilityTypes)
local AbilityEvents = require(AbilityShared.Net.AbilityEvents)
local AbilityRules = require(AbilityShared.Rules.AbilityRules)
local AbilityCooldownTracker = require(AbilityServer.State.AbilityCooldownTracker)
local AbilityTreasureUtils = require(AbilityServer.Utils.AbilityTreasureUtils)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)
local OccupantCatchSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantCatchSystem)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local SprintServiceServer = require(ServerScriptService.Features.Sprint.SprintServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

type AbilityDef = AbilityTypes.AbilityDef

-- A timed effect's AbilityActive (Let's Go!, Spot It!): cleared at `untilTime` (os.clock).
type Timed = { character: Model, untilTime: number }
-- A full-body clip that a move stops (os.clock until it would end on its own).
type FullBody = { key: string, untilTime: number }

-- Above this flat speed (studs/s) a user counts as moving: the upper-body clip, and a full-body clip stops.
local MOVING_SPEED = 1.5

local log = Logger.new("AbilityServiceServer")
local tracker = AbilityCooldownTracker.new()
local timed: { [number]: Timed } = {}
local fullBodies: { [number]: FullBody } = {}
local stoppers: { () -> () } = {}
local elapsed = 0
local counters = { used = 0, refused = 0, plantsEnded = 0 }

local function bodyOf(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local found = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local root = if found ~= nil and found:IsA("BasePart") then found else nil
	return character, humanoid, root
end

local function aliveOf(player: Player, humanoid: Humanoid?): boolean
	return humanoid ~= nil and humanoid.Health > 0 and not DeathServiceServer:isDead(player)
end

local function flatSpeed(root: BasePart): number
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function running(): boolean
	return ShiftServiceServer:getShift().phase == "running"
end

local function say(player: Player, reason: string)
	local words = AbilityConstants.REASON_WORDS[reason]
	if words ~= nil then
		ToastServiceServer:send(player, { text = words, duration = AbilityConstants.TOAST_SECONDS })
	end
end

local function publishReady(player: Player, readyAt: number)
	player:SetAttribute(AbilityConstants.READY_AT_ATTRIBUTE, readyAt)
end

-- The closest treasure to `origin`: a cargo part (CargoId, a grimy kind), not claimed, not in anyone's hands, still in
-- the world. Buried items (CargoHidden) count: the glow shows which pile to vacuum.
local function closestTreasure(origin: Vector3): (number?, BasePart?)
	local carried: { [Instance]: true } = {}
	for _, player in Players:GetPlayers() do
		local object = CarryServiceServer:getCarried(player)
		if object ~= nil then
			carried[object] = true
		end
	end
	local parts: { [number]: BasePart } = {}
	local candidates: { AbilityTreasureUtils.Candidate } = {}
	for _, tagged in CollectionService:GetTagged(CarryConstants.TAG) do
		local id = tagged:GetAttribute(CargoConstants.ID_ATTRIBUTE)
		local kind = tagged:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
		if tagged:IsA("BasePart") and type(id) == "number" and type(kind) == "string" then
			local def = CargoRegistry.get(kind)
			parts[id] = tagged
			table.insert(candidates, {
				id = id,
				position = tagged.Position,
				grimy = def ~= nil and def.grimy,
				claimed = carried[tagged] == true
					or not tagged:IsDescendantOf(Workspace)
					or CargoServiceServer:isClaimed(tagged),
			})
		end
	end
	local best = AbilityTreasureUtils.closest(origin, candidates)
	return best, if best ~= nil then parts[best] else nil
end

-- Plays an ability clip over the effect (never gates it): the full-body one standing still, else the upper-body one.
local function playClip(player: Player, root: BasePart, clips: AbilityTypes.AbilityClips)
	local full, upper = clips.full, clips.upper
	local moving = flatSpeed(root) > MOVING_SPEED
	local key = if moving or full == nil then upper else full
	if key == nil then
		return
	end
	local ok, reason = AnimationServiceServer:play(player, key)
	if not ok then
		log:debug(`{player.Name}: clip {key} not played ({reason})`)
		return
	end
	local def = AnimationRegistry.get(key)
	if key == full and def ~= nil and def.durationMs ~= nil then
		fullBodies[player.UserId] = { key = key, untilTime = os.clock() + def.durationMs / 1000 }
	end
end

local function markTimed(player: Player, character: Model, def: AbilityDef)
	character:SetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE, def.id)
	timed[player.UserId] = { character = character, untilTime = os.clock() + def.duration }
end

local function letsGo(player: Player, character: Model, root: BasePart, def: AbilityDef)
	local radius = def.radius or 0
	local scale = def.scale or 1
	for _, mate in RoundServiceServer:participants() do
		local _, humanoid, mateRoot = bodyOf(mate)
		if
			mateRoot ~= nil
			and aliveOf(mate, humanoid)
			and not OccupantCatchSystem.isCatching(mate.UserId)
			and (mate == player or (mateRoot.Position - root.Position).Magnitude <= radius)
		then
			SprintServiceServer:boost(mate, scale, def.duration)
		end
	end
	markTimed(player, character, def)
	playClip(player, root, def.clips)
end

local function spotIt(player: Player, character: Model, root: BasePart, def: AbilityDef, cargoId: number)
	AbilityEvents.packets.Spotted.sendTo({ cargoId = cargoId }, player)
	markTimed(player, character, def)
	playClip(player, root, def.clips)
end

-- The plant's clips: enter, then the hold looping once the enter is done (if the same plant still runs).
local function plantClips(player: Player, def: AbilityDef, startedAt: number)
	local enter, hold = def.clips.enter, def.clips.hold
	local enterDef = if enter ~= nil then AnimationRegistry.get(enter) else nil
	if enter ~= nil then
		AnimationServiceServer:play(player, enter)
	end
	if hold == nil then
		return
	end
	local delay = if enterDef ~= nil and enterDef.durationMs ~= nil then enterDef.durationMs / 1000 else 0
	task.delay(delay, function()
		local plant = tracker:plantOf(player.UserId)
		if plant ~= nil and plant.startedAt == startedAt and player.Parent ~= nil then
			AnimationServiceServer:play(player, hold)
		end
	end)
end

local function pottedPlant(player: Player, character: Model, root: BasePart, def: AbilityDef)
	NpcServiceServer:conceal(player, AbilityConstants.PLANT_SOURCE)
	local startedAt = os.clock()
	tracker:startPlant(player.UserId, { startedAt = startedAt, origin = root.Position, cancelled = false })
	character:SetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE, def.id)
	plantClips(player, def, startedAt)
end

-- Ends `player`'s plant: revealed to every monster at once, then the visuals (the exit clip only for a calm end).
local function endPlant(player: Player, reason: AbilityTypes.EndReason, calm: boolean)
	if tracker:plantOf(player.UserId) == nil then
		return
	end
	NpcServiceServer:reveal(player, AbilityConstants.PLANT_SOURCE)
	tracker:endPlant(player.UserId)
	counters.plantsEnded += 1
	local character = player.Character
	if character ~= nil then
		character:SetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE, nil)
	end
	local def = AbilityRegistry.get("pottedPlant")
	local clips = if def ~= nil then def.clips else nil
	if clips ~= nil then
		if clips.enter ~= nil then
			AnimationServiceServer:stop(player, clips.enter)
		end
		if clips.hold ~= nil then
			AnimationServiceServer:stop(player, clips.hold)
		end
		if calm and clips.exit ~= nil then
			AnimationServiceServer:play(player, clips.exit)
		end
	end
	say(player, reason)
end

local function onUse(player: Player)
	local character, humanoid, root = bodyOf(player)
	local name = if character ~= nil then character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) else nil
	local def = if type(name) == "string" then AbilityRegistry.forEmployee(name) else nil
	local now = Workspace:GetServerTimeNow()
	local cargoId: number? = nil
	if def ~= nil and def.id == "spotIt" and root ~= nil then
		cargoId = closestTreasure(root.Position)
	end
	local ok, reason = AbilityRules.canUse({
		running = running(),
		participant = RoundServiceServer:isParticipant(player),
		alive = aliveOf(player, humanoid),
		caught = OccupantCatchSystem.isCatching(player.UserId),
		hidden = HideServiceServer:isHidden(player),
		now = now,
		readyAt = tracker:readyAt(player.UserId),
		def = def,
		grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air,
		holding = CarryServiceServer:getCarried(player) ~= nil,
		hasTarget = cargoId ~= nil,
	})
	if not ok or def == nil or character == nil or root == nil then
		counters.refused += 1
		if reason ~= nil then
			say(player, reason)
		end
		return
	end
	counters.used += 1
	publishReady(player, tracker:spend(player.UserId, now, def.cooldown))
	if def.id == "letsGo" then
		letsGo(player, character, root, def)
	elseif def.id == "spotIt" and cargoId ~= nil then
		spotIt(player, character, root, def, cargoId)
	elseif def.id == "pottedPlant" then
		pottedPlant(player, character, root, def)
	end
end

local handleUse = RequestHandler.wrap({
	name = "AbilityUse",
	rateLimitKey = "Ability",
	rateLimit = AbilityConstants.REQUEST_RATE,
	handler = function(_data: unknown, player: Player)
		onUse(player)
	end,
})

local handleCancel = RequestHandler.wrap({
	name = "AbilityCancel",
	rateLimitKey = "Ability",
	rateLimit = AbilityConstants.REQUEST_RATE,
	handler = function(_data: unknown, player: Player)
		local plant = tracker:plantOf(player.UserId)
		if plant ~= nil then
			plant.cancelled = true
		end
	end,
})

-- Whether `player` is doing anything but standing as a plant: sprinting, vacuuming, hiding, holding something.
local function acting(player: Player): boolean
	return SprintServiceServer:isSprinting(player)
		or VacuumServiceServer:isVacuuming(player)
		or HideServiceServer:isHidden(player)
		or CarryServiceServer:getCarried(player) ~= nil
end

local function stepPlants(now: number)
	for _, userId in tracker:planters() do
		local player = Players:GetPlayerByUserId(userId)
		local plant = tracker:plantOf(userId)
		if player ~= nil and plant ~= nil then
			local _, humanoid, root = bodyOf(player)
			local moved = if root ~= nil
				then Vector3.new(root.Position.X - plant.origin.X, 0, root.Position.Z - plant.origin.Z).Magnitude
				else math.huge
			local grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
			local def = AbilityRegistry.get("pottedPlant")
			local reason: AbilityTypes.EndReason? = AbilityRules.plantEnds({
				now = now,
				startedAt = plant.startedAt,
				maxSeconds = if def ~= nil then def.duration else 0,
				moved = moved,
				grounded = grounded,
				acting = acting(player),
				alive = root ~= nil and aliveOf(player, humanoid),
				caught = OccupantCatchSystem.isCatching(userId),
				cancelled = plant.cancelled,
			})
			if reason ~= nil then
				endPlant(player, reason, reason == "timeout" and grounded)
			end
		end
	end
end

local function stepTimed(now: number)
	for userId, entry in timed do
		if now >= entry.untilTime then
			timed[userId] = nil
			entry.character:SetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE, nil)
		end
	end
	for userId, entry in fullBodies do
		local player = Players:GetPlayerByUserId(userId)
		if now >= entry.untilTime or player == nil then
			fullBodies[userId] = nil
			continue
		end
		local _, _, root = bodyOf(player)
		if root ~= nil and flatSpeed(root) > MOVING_SPEED then
			-- Moving cancels the full-body clip (its contract); the effect is untouched.
			fullBodies[userId] = nil
			AnimationServiceServer:stop(player, entry.key)
		end
	end
end

local function onHeartbeat(deltaTime: number)
	elapsed += deltaTime
	if elapsed < AbilityConstants.TICK then
		return
	end
	elapsed = 0
	local now = os.clock()
	stepPlants(now)
	stepTimed(now)
end

-- A new shift: everyone ready. A shift that stops running ends every plant and timed effect.
local function onShift(state: ShiftTypes.ShiftState)
	if state.phase == "running" then
		for _, userId in tracker:resetAll() do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				publishReady(player, 0)
			end
		end
		return
	end
	for _, userId in tracker:planters() do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			endPlant(player, "cancelled", false)
		else
			tracker:endPlant(userId)
		end
	end
	for userId, entry in timed do
		timed[userId] = nil
		entry.character:SetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE, nil)
	end
end

export type AbilityServiceServer = {
	dependencies: { string },
	start: (self: AbilityServiceServer) -> (),
	stop: (self: AbilityServiceServer) -> (),
	getState: (self: AbilityServiceServer) -> { [string]: any },
	readyAt: (self: AbilityServiceServer, player: Player) -> number,
	isPlanted: (self: AbilityServiceServer, player: Player) -> boolean,
}

local AbilityServiceServer: AbilityServiceServer = {
	dependencies = {
		"AnimationServiceServer",
		"CargoServiceServer",
		"CarryServiceServer",
		"DeathServiceServer",
		"HideServiceServer",
		"NpcServiceServer",
		"RoundServiceServer",
		"ShiftServiceServer",
		"SprintServiceServer",
		"ToastServiceServer",
		"VacuumServiceServer",
	},

	--[=[
		Listens for ability requests and the shift, and checks running effects every TICK.
	]=]
	start = function(_self)
		table.insert(
			stoppers,
			AbilityEvents.packets.Use.listen(function(data: boolean, player: Player?)
				if player then
					handleUse(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			AbilityEvents.packets.Cancel.listen(function(data: boolean, player: Player?)
				if player then
					handleCancel(data, player)
				end
			end)
		)
		local heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
		local shift = ShiftServiceServer.changed:Connect(onShift)
		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
			NpcServiceServer:reveal(player, AbilityConstants.PLANT_SOURCE)
			tracker:clear(player.UserId)
			timed[player.UserId] = nil
			fullBodies[player.UserId] = nil
		end)
		table.insert(
			stoppers,
			Observers.observePlayer(function(player: Player)
				publishReady(player, tracker:readyAt(player.UserId))
				return nil
			end)
		)
		table.insert(stoppers, function()
			heartbeat:Disconnect()
			shift:Disconnect()
			leaving:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		for _, userId in tracker:planters() do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				endPlant(player, "cancelled", false)
			end
		end
	end,

	--[=[
		When `player`'s ability is ready again (server time; 0 = ready).
	]=]
	readyAt = function(_self, player)
		return tracker:readyAt(player.UserId)
	end,

	isPlanted = function(_self, player)
		return tracker:plantOf(player.UserId) ~= nil
	end,

	getState = function(_self)
		return { planted = #tracker:planters(), counters = table.clone(counters) }
	end,
}

return AbilityServiceServer
