--!strict
--[=[
	OccupantEffectSystem: carries out what a think of the Manager's brain asks beyond the NPC intent
	(OccupantTypes.Effect; docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-design.md): his body
	(OccupantSeatSystem: sit, stand, plant, release), whether he knows a hider (Hide's `setSeen`), holding a hider's
	camping push-out while he is at their spot (Hide's `hold`), a catch (the service's `catch`, re-checked there), and
	the PA call-out naming a crew member (OccupantEvents.Pa to everyone, a line from PA_CALLOUTS). Effects naming a
	player who left are skipped. Never yields.

	Spec-exempt shell (Players, ByteNet, Hide); which effects a think makes is the specced OccupantBrainRules.

	@class OccupantEffectSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local OccupantEvents = require(OccupantShared.Net.OccupantEvents)
local OccupantTellRules = require(OccupantShared.Rules.OccupantTellRules)
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local OccupantSeatSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantSeatSystem)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)

local rng = Random.new()
local counters = { sits = 0, stands = 0, stares = 0, seen = 0, holds = 0, catches = 0, callouts = 0 }

local OccupantEffectSystem = {}

function OccupantEffectSystem.apply(
	rig: OccupantRigSystem.Rig,
	effects: { OccupantTypes.Effect },
	catch: (player: Player) -> ()
)
	for _, effect in effects do
		if effect.kind == "sit" then
			counters.sits += 1
			OccupantSeatSystem.sit(rig, effect.seat)
		elseif effect.kind == "stand" then
			counters.stands += 1
			OccupantSeatSystem.stand(rig, effect.speed)
		elseif effect.kind == "plant" then
			counters.stares += 1
			OccupantSeatSystem.plant(rig, effect.frame)
		elseif effect.kind == "release" then
			OccupantSeatSystem.release(rig)
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
			elseif effect.kind == "callout" then
				counters.callouts += 1
				local lines = OccupantConstants.PA_CALLOUTS
				OccupantEvents.packets.Pa.sendToAll({
					line = OccupantTellRules.paLine(lines[rng:NextInteger(1, #lines)], player.DisplayName),
					userId = player.UserId,
				})
			end
		end
	end
end

function OccupantEffectSystem.getState(): { [string]: number }
	return table.clone(counters)
end

return OccupantEffectSystem
