--!strict
--[=[
	AbilityRegistry: every employee ability by id, and each employee's. The gameplay numbers live here (the cards read
	the cooldown from here: EmployeeProfileRegistry keeps only the words). Spec:
	docs/superpowers/specs/2026-10-29-employee-abilities-design.md.

	@class AbilityRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityTypes = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityTypes)

type AbilityDef = AbilityTypes.AbilityDef

local DEFS: { AbilityDef } = {
	{
		-- Pippa and the crew near her run faster.
		id = "letsGo",
		employee = "Pippa",
		cooldown = 45,
		duration = 4,
		radius = 20,
		scale = 1.25,
		clips = { full = "pippaletsgo", upper = "pippaletsgoupper" },
	},
	{
		-- The closest treasure shows through walls, to Cappy only.
		id = "spotIt",
		employee = "Cappy",
		cooldown = 40,
		duration = 5,
		clips = { full = "cappyspotit", upper = "cappyspotitupper" },
	},
	{
		-- Stand still as a potted plant: monsters that did not see it begin cannot see or catch him.
		id = "pottedPlant",
		employee = "Prickles",
		cooldown = 45,
		duration = 8,
		clips = { enter = "pricklesplantenter", hold = "pricklesplanthold", exit = "pricklesplantexit" },
	},
}

local byId: { [string]: AbilityDef } = {}
local byEmployee: { [string]: AbilityDef } = {}
for _, def in DEFS do
	table.freeze(def.clips)
	table.freeze(def)
	byId[def.id] = def
	byEmployee[def.employee] = def
end

local AbilityRegistry = {}

function AbilityRegistry.get(id: string): AbilityDef?
	return byId[id]
end

--[=[
	The ability of the employee named `name` (EmployeeRegistry), or nil.
]=]
function AbilityRegistry.forEmployee(name: string): AbilityDef?
	return byEmployee[name]
end

function AbilityRegistry.all(): { AbilityDef }
	return table.clone(DEFS)
end

return AbilityRegistry
