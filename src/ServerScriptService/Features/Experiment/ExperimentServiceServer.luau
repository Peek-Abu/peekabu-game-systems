--!strict
--[=[
	ExperimentServiceServer: the one door other systems use to read a player's or crew's experiment variant.
	A variant is the stable hash split of the unit (see ExperimentAssignUtils), unless the developer override
	(a Workspace string attribute, `ExperimentOverride`, e.g. `"exp-friendskip=skip, exp-tutorial=3beats"`) names one, which
	wins in any place. Overrides are read fresh on every call. The crew id is this shift server's JobId: a
	reserved Shift server holds exactly one crew, so it is stable through that crew's Another-shift replays.

	This service must never require anything in Analytics (Analytics reads it; the reverse would be a cycle).

	@class ExperimentServiceServer
]=]

local Workspace = game:GetService("Workspace")

local ExperimentRegistry = require(script.Parent.Data.ExperimentRegistry)
local ExperimentOverrideRules = require(script.Parent.Rules.ExperimentOverrideRules)
local ExperimentAssignUtils = require(script.Parent.Utils.ExperimentAssignUtils)

local OVERRIDE_ATTRIBUTE = "ExperimentOverride"

export type Source = "hash" | "override"

export type Assignment = {
	experimentId: string,
	unit: ExperimentRegistry.Unit,
	variant: string,
	source: Source,
}

export type ExperimentServiceServer = {
	dependencies: { string },
	OVERRIDE_ATTRIBUTE: string,

	crewVariant: (self: ExperimentServiceServer, crewId: string, experimentId: string) -> string,
	playerVariant: (self: ExperimentServiceServer, player: Player, experimentId: string) -> string,
	variantOf: (self: ExperimentServiceServer, player: Player, experimentId: string) -> string,
	crewId: (self: ExperimentServiceServer) -> string,
	assignments: (self: ExperimentServiceServer, player: Player, includeCrew: boolean) -> { Assignment },
	getState: (self: ExperimentServiceServer) -> { [string]: any },
}

local function currentOverrides(): { [string]: string }
	return ExperimentOverrideRules.parse(Workspace:GetAttribute(OVERRIDE_ATTRIBUTE))
end

local function definitionFor(experimentId: string, unit: ExperimentRegistry.Unit): ExperimentRegistry.Definition
	local definition = ExperimentRegistry.get(experimentId)
	if definition == nil then
		error(`unknown experiment "{experimentId}"`, 3)
	end
	if definition.unit ~= unit then
		error(`experiment "{experimentId}" is assigned per {definition.unit}, not per {unit}`, 3)
	end
	return definition
end

-- The override wins over the hash.
local function resolve(
	definition: ExperimentRegistry.Definition,
	unitKey: string,
	overrides: { [string]: string }
): (string, Source)
	local override = overrides[definition.id]
	if override ~= nil then
		return override, "override"
	end
	return ExperimentAssignUtils.variantFor(definition, unitKey), "hash"
end

local ExperimentServiceServer: ExperimentServiceServer = {
	dependencies = {},
	OVERRIDE_ATTRIBUTE = OVERRIDE_ATTRIBUTE,

	--[=[
		The variant this crew gets in a per-crew experiment. Errors on an unknown id or a per-player experiment.
	]=]
	crewVariant = function(_self, crewId, experimentId)
		local variant = resolve(definitionFor(experimentId, "crew"), crewId, currentOverrides())
		return variant
	end,

	--[=[
		The variant this player gets in a per-player experiment. Errors on an unknown id or a per-crew experiment.
	]=]
	playerVariant = function(_self, player, experimentId)
		local variant = resolve(definitionFor(experimentId, "player"), tostring(player.UserId), currentOverrides())
		return variant
	end,

	--[=[
		The variant for this player, picked by the experiment's unit; crew experiments use this server's crew id.
	]=]
	variantOf = function(self, player, experimentId)
		local definition = ExperimentRegistry.get(experimentId)
		if definition == nil then
			error(`unknown experiment "{experimentId}"`, 2)
		end
		if definition.unit == "crew" then
			return self:crewVariant(self:crewId(), experimentId)
		end
		return self:playerVariant(player, experimentId)
	end,

	--[=[
		This server's crew: the JobId ("studio" when there is none).
	]=]
	crewId = function(_self)
		if game.JobId == "" then
			return "studio"
		end
		return game.JobId
	end,

	--[=[
		Every assignment for this player, in registry order. Crew experiments are included only when `includeCrew`.
	]=]
	assignments = function(self, player, includeCrew)
		local overrides = currentOverrides()
		local crewId = self:crewId()
		local result: { Assignment } = {}
		for _, definition in ExperimentRegistry.list() do
			if definition.unit == "player" or includeCrew then
				local unitKey = if definition.unit == "crew" then crewId else tostring(player.UserId)
				local variant, source = resolve(definition, unitKey, overrides)
				table.insert(result, {
					experimentId = definition.id,
					unit = definition.unit,
					variant = variant,
					source = source,
				})
			end
		end
		return result
	end,

	--[=[
		@return { [string]: any } -- This server's crew id and the active overrides, for the Debugger
	]=]
	getState = function(self)
		return {
			crewId = self:crewId(),
			overrides = currentOverrides(),
		}
	end,
}

return ExperimentServiceServer
