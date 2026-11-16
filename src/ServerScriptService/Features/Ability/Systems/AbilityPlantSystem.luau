--!strict
--[=[
	AbilityPlantSystem: Prickles' Potted Plant once it is accepted. It starts the stealth in the shared Npc layer
	(NpcServiceServer:conceal), puts the wand away and plays the enter then hold clips; every TICK it checks each plant
	(AbilityRules.plantEnds: he moves, jumps, acts, asks, dies, is caught or the cap passes) and ends it: revealed to
	every monster at once, then the visuals and a toast saying why. Split out of AbilityServiceServer, which owns the
	bookkeeping (the AbilityCooldownTracker, its counters) and passes it in with its body reads (a Context).

	Spec-exempt shell (Players, Humanoids, NpcServiceServer, AnimationServiceServer); the decisions are the specced
	AbilityRules and AbilityCooldownTracker.

	@class AbilityPlantSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AbilityShared = ReplicatedStorage.Shared.Features.Ability
local AbilityServer = ServerScriptService.Features.Ability
local AbilityConstants = require(AbilityShared.Data.AbilityConstants)
local AbilityRegistry = require(AbilityShared.Data.AbilityRegistry)
local AbilityTypes = require(AbilityShared.Data.AbilityTypes)
local AbilityRules = require(AbilityShared.Rules.AbilityRules)
local AbilityClipSystem = require(AbilityServer.Systems.AbilityClipSystem)
local AbilityCooldownTracker = require(AbilityServer.State.AbilityCooldownTracker)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)
local OccupantCatchSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantCatchSystem)
local SprintServiceServer = require(ServerScriptService.Features.Sprint.SprintServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local VacuumToolSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumToolSystem)

type AbilityDef = AbilityTypes.AbilityDef

-- What a plant needs from AbilityServiceServer: its bookkeeping, its body reads and its toast.
export type Context = {
	tracker: AbilityCooldownTracker.AbilityCooldownTracker,
	counters: { used: number, refused: number, plantsEnded: number },
	bodyOf: AbilityClipSystem.BodyOf,
	aliveOf: (player: Player, humanoid: Humanoid?) -> boolean,
	say: (player: Player, reason: string) -> (),
}

local AbilityPlantSystem = {}

-- The plant's clips: enter, then the hold looping once the enter is done (if the same plant still runs).
local function plantClips(ctx: Context, player: Player, def: AbilityDef, startedAt: number)
	local tracker = ctx.tracker
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

--[=[
	Starts `player`'s plant (the use was accepted and the cooldown spent).
]=]
function AbilityPlantSystem.plant(ctx: Context, player: Player, character: Model, root: BasePart, def: AbilityDef)
	local tracker = ctx.tracker
	NpcServiceServer:conceal(player, AbilityConstants.PLANT_SOURCE)
	local startedAt = os.clock()
	tracker:startPlant(player.UserId, { startedAt = startedAt, origin = root.Position, cancelled = false })
	character:SetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE, def.id)
	-- The wand goes away as he plants (its IK grip would fight the clip that brings out the pot); slot 1 brings it back.
	if VacuumToolSystem.isEquipped(character) then
		VacuumServiceServer:setEquipped(player, false)
	end
	plantClips(ctx, player, def, startedAt)
end

--[=[
	Ends `player`'s plant: revealed to every monster at once, then the visuals (the exit clip only for a calm end).
]=]
function AbilityPlantSystem.endPlant(ctx: Context, player: Player, reason: AbilityTypes.EndReason, calm: boolean)
	local tracker, counters, say = ctx.tracker, ctx.counters, ctx.say
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

-- Whether `player` is doing anything but standing as a plant: sprinting, vacuuming, hiding, holding something.
local function acting(player: Player): boolean
	return SprintServiceServer:isSprinting(player)
		or VacuumServiceServer:isVacuuming(player)
		or HideServiceServer:isHidden(player)
		or CarryServiceServer:getCarried(player) ~= nil
end

--[=[
	Checks every running plant (`now` is os.clock) and ends each one AbilityRules.plantEnds ends.
]=]
function AbilityPlantSystem.step(ctx: Context, now: number)
	local tracker, bodyOf, aliveOf = ctx.tracker, ctx.bodyOf, ctx.aliveOf
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
				AbilityPlantSystem.endPlant(ctx, player, reason, reason == "timeout" and grounded)
			end
		end
	end
end

return AbilityPlantSystem
