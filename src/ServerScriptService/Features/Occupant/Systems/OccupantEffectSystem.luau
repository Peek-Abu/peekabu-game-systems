--!strict
--[=[
	OccupantEffectSystem: carries out what a think of the Manager's brain asks beyond the NPC intent
	(OccupantTypes.Effect; docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-design.md): his body
	(OccupantSeatSystem: sit, stand, plant, release), whether he knows a hider (Hide's `setSeen`), holding a hider's
	camping push-out while he is at their spot (Hide's `hold`), a supply cabinet's door swinging open as he checks it
	(Hide's `setDoor`) and a catch (the service's `catch`, re-checked there). Effects naming a player who left are
	skipped. Never yields.

	Spec-exempt shell (Players, Hide); which effects a think makes is the specced OccupantBrainRules.

	@class OccupantEffectSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local OccupantSeatSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantSeatSystem)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)

local counters = { sits = 0, stands = 0, stares = 0, seen = 0, holds = 0, catches = 0, doors = 0 }

local OccupantEffectSystem = {}

function OccupantEffectSystem.apply(
	rig: OccupantRigSystem.Rig,
	effects: { OccupantTypes.Effect },
	catch: (player: Player) -> ()
)
	for _, effect in effects do
		if effect.kind == "sit" then
			counters.sits += 1
			OccupantSeatSystem.sit(rig, effect.seat, effect.desk, effect.deskSize)
		elseif effect.kind == "stand" then
			counters.stands += 1
			OccupantSeatSystem.stand(rig, effect.speed)
		elseif effect.kind == "plant" then
			counters.stares += 1
			OccupantSeatSystem.plant(rig, effect.frame)
		elseif effect.kind == "release" then
			OccupantSeatSystem.release(rig)
		elseif effect.kind == "door" then
			counters.doors += 1
			HideServiceServer:setDoor(effect.spotId, effect.open)
		else
			local player = Players:GetPlayerByUserId(effect.userId)
			if player == nil then
				continue
			end
			if effect.kind == "seen" then
				counters.seen += 1
				HideServiceServer:setSeen(player, effect.seen)
			elseif effect.kind == "holdCamp" then
				counters.holds += 1
				HideServiceServer:hold(player, effect.untilTime)
			elseif effect.kind == "catch" then
				counters.catches += 1
				catch(player)
			end
		end
	end
end

function OccupantEffectSystem.getState(): { [string]: number }
	return table.clone(counters)
end

return OccupantEffectSystem
