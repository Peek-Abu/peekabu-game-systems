--!strict
--[=[
	EmployeeRegistry: the playable employees, by name. An employee is an art-owned character model in the place
	(never in the source tree: ReplicatedStorage keeps `$ignoreUnknownInstances`, so Rojo leaves it alone)
	plus the expressions its `Faces` folder holds. Adding an employee is one entry here and one model in
	the place: R15 MeshParts with standard joint names, a FacePlate with a "Face" SurfaceAppearance, and a
	`Faces` folder with one SurfaceAppearance per expression. The rig attachments are generated
	(EmployeeSpawnSystem), so the model does not need them.

	@class EmployeeRegistry
]=]

export type Face = "Happy" | "Worried" | "Content"

export type EmployeeDef = {
	name: string,
	-- Path under ReplicatedStorage to the template model.
	templatePath: { string },
	-- The expressions the model's `Faces` folder must hold.
	faces: { Face },
	-- What the model shows before the server has decided anything.
	defaultFace: Face,
}

local FACES: { Face } = { "Happy", "Worried", "Content" }

local EMPLOYEES: { [string]: EmployeeDef } = {
	Pippa = {
		name = "Pippa",
		templatePath = { "Assets", "CleanupCrew", "Characters", "Pippa" },
		faces = FACES,
		defaultFace = "Happy",
	},
}

local EmployeeRegistry = {
	-- The employee every player spawns as (one StarterCharacter serves the whole server).
	DEFAULT = "Pippa",
	FACES = FACES,
}

function EmployeeRegistry.get(name: string): EmployeeDef?
	return EMPLOYEES[name]
end

function EmployeeRegistry.names(): { string }
	local names = {}
	for name in EMPLOYEES do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- Narrows an untrusted value (a replicated attribute) to a Face.
function EmployeeRegistry.toFace(value: unknown): Face?
	if value == "Happy" then
		return "Happy"
	elseif value == "Worried" then
		return "Worried"
	elseif value == "Content" then
		return "Content"
	end
	return nil
end

return EmployeeRegistry
