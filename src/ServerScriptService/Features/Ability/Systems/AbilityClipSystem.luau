--!strict
--[=[
	AbilityClipSystem: the clips that play over an ability's effect (Let's Go!, Spot It!) and never gate it
	(AbilityClipUtils): the full-body clip only standing still with empty hands, the upper-body cut on the move,
	nothing while the vacuum's wand is out or something is carried (their IK grip holds the arms); a playing clip
	stops the moment that stops being true. Remembers each playing clip until it ends on its own. Split out of
	AbilityServiceServer, which calls it.

	Spec-exempt shell (AnimationServiceServer, Humanoid root velocity); the clip choice is the specced AbilityClipUtils.

	@class AbilityClipSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AbilityShared = ReplicatedStorage.Shared.Features.Ability
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AbilityTypes = require(AbilityShared.Data.AbilityTypes)
local AbilityClipUtils = require(AbilityShared.Utils.AbilityClipUtils)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local VacuumToolSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumToolSystem)

-- A character's body parts, as AbilityServiceServer reads them.
export type BodyOf = (player: Player) -> (Model?, Humanoid?, BasePart?)

-- A playing ability clip (Let's Go!, Spot It!): its kind, and os.clock until it would end on its own.
type Playing = { key: string, kind: AbilityClipUtils.ClipKind, untilTime: number }

-- Above this flat speed (studs/s) a user counts as moving: the upper-body clip, and a full-body clip stops.
local MOVING_SPEED = 1.5

local log = Logger.new("AbilityServiceServer")
local playing: { [number]: Playing } = {}

local AbilityClipSystem = {}

local function flatSpeed(root: BasePart): number
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

-- Whether `player`'s hands are busy: the vacuum's wand out, or something carried (their arms are on an IK grip).
local function handsBusy(player: Player, character: Model?): boolean
	return VacuumToolSystem.isEquipped(character) or CarryServiceServer:getCarried(player) ~= nil
end

--[=[
	Plays an ability clip over the effect (never gates it), as AbilityClipUtils picks: the full-body one standing still,
	the upper-body one moving, none with busy hands.
]=]
function AbilityClipSystem.play(player: Player, character: Model, root: BasePart, clips: AbilityTypes.AbilityClips)
	local key, kind = AbilityClipUtils.pick(clips, flatSpeed(root) > MOVING_SPEED, handsBusy(player, character))
	if key == nil or kind == nil then
		return
	end
	local ok, reason = AnimationServiceServer:play(player, key)
	if not ok then
		log:debug(`{player.Name}: clip {key} not played ({reason})`)
		return
	end
	local def = AnimationRegistry.get(key)
	if def ~= nil and def.durationMs ~= nil then
		local clipKind: AbilityClipUtils.ClipKind = if kind == "full" then "full" else "upper"
		local entry: Playing = { key = key, kind = clipKind, untilTime = os.clock() + def.durationMs / 1000 }
		playing[player.UserId] = entry
	end
end

--[=[
	Drops every clip that has ended on its own, and stops one that moving or busy hands cut (`now` is os.clock).
]=]
function AbilityClipSystem.step(now: number, bodyOf: BodyOf)
	for userId, entry in playing do
		local player = Players:GetPlayerByUserId(userId)
		if now >= entry.untilTime or player == nil then
			playing[userId] = nil
			continue
		end
		local character, _, root = bodyOf(player)
		local moving = root ~= nil and flatSpeed(root) > MOVING_SPEED
		if not AbilityClipUtils.keeps(entry.kind, moving, handsBusy(player, character)) then
			-- Moving cuts a full-body clip; busy hands cut any clip. The effect is untouched.
			playing[userId] = nil
			AnimationServiceServer:stop(player, entry.key)
		end
	end
end

--[=[
	Forgets `userId`'s playing clip (they left).
]=]
function AbilityClipSystem.forget(userId: number)
	playing[userId] = nil
end

return AbilityClipSystem
