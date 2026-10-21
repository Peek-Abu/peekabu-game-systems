--!strict
--[=[
	ExperimentOverrideRules: parses the developer override string (a Workspace attribute such as
	`"exp-friendskip=skip, exp-tutorial=3beats"`) into an `{ [experimentId]: variant }` map. Pairs that are malformed, name an
	unknown experiment or name a variant the experiment does not have are dropped. Pure.

	@class ExperimentOverrideRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local ExperimentRegistry = require(ServerScriptService.Features.Experiment.Data.ExperimentRegistry)

local ExperimentOverrideRules = {}

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

function ExperimentOverrideRules.parse(raw: unknown): { [string]: string }
	local parsed: { [string]: string } = {}
	if type(raw) ~= "string" then
		return parsed
	end
	for _, pair in string.split(raw, ",") do
		local parts = string.split(pair, "=")
		if #parts == 2 then
			local id = trim(parts[1])
			local variant = trim(parts[2])
			local definition = ExperimentRegistry.get(id)
			if definition ~= nil and table.find(definition.variants, variant) ~= nil then
				parsed[id] = variant
			end
		end
	end
	return parsed
end

return ExperimentOverrideRules
