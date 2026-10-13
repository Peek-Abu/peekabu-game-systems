--!strict
--[=[
	EmployeeRegistry: the playable employees, by name. An employee is an art-owned character model in the
	place (never in the source tree: ReplicatedStorage keeps `$ignoreUnknownInstances`, so Rojo leaves it
	alone) plus the expressions its `Faces` folder holds. Adding an employee is one entry here and one model
	in the place: R15 MeshParts with standard joint names, a FacePlate with a "Face" SurfaceAppearance, and
	a `Faces` folder with one SurfaceAppearance per expression. The rig attachments are generated
	(EmployeeSpawnSystem), so the model does not need them.

	Each employee carries its own personality as data:
	- `expressions` maps every gameplay state (decided by the server, EmployeeFaceRules.stateOf) to the
	  face this employee shows in it. Not every employee is cheerful at work: Pippa enjoys cleaning, but
	  hauling cargo is just the job.
	- `skins` are looks for the same rig: a palette image (every MeshPart but the FacePlate shares one
	  palette texture), an optional face set, and accessories (EmployeeSkinSystem applies one).

	@class EmployeeRegistry
]=]

export type Face = "Happy" | "Worried" | "Content"

-- What the employee is doing, as far as its face is concerned (EmployeeFaceRules.stateOf).
export type GameplayState = "threatened" | "cleaning" | "carrying" | "idle"

export type SkinDef = {
	-- Its key in the employee's `skins`.
	name: string,
	-- "rbxassetid://<id>" of the palette image set as TextureID on every MeshPart but the FacePlate.
	-- nil while the art does not exist yet: the skin then leaves the model's own palette alone.
	paletteTextureId: string?,
	-- The name of a Folder on the model (beside `Faces`) holding this skin's face SurfaceAppearances, one
	-- per Face; it replaces `Faces` on the character. nil keeps the employee's own faces.
	facesFolder: string?,
	-- Names of Accessory instances under EmployeeConstants.ACCESSORIES_PATH to put on the character.
	accessories: { string },
}

export type EmployeeDef = {
	name: string,
	-- Path under ReplicatedStorage to the template model.
	templatePath: { string },
	-- The expressions the model's `Faces` folder must hold.
	faces: { Face },
	-- What the model shows before the server has decided anything.
	defaultFace: Face,
	-- The face for every gameplay state.
	expressions: { [GameplayState]: Face },
	-- The looks this employee can wear, by name, and the one everyone gets by default.
	skins: { [string]: SkinDef },
	defaultSkin: string,
}

local FACES: { Face } = { "Happy", "Worried", "Content" }
local STATES: { GameplayState } = { "threatened", "cleaning", "carrying", "idle" }

local EMPLOYEES: { [string]: EmployeeDef } = {
	Pippa = {
		name = "Pippa",
		templatePath = { "Assets", "CleanupCrew", "Characters", "Pippa" },
		faces = FACES,
		defaultFace = "Happy",
		expressions = {
			threatened = "Worried",
			cleaning = "Happy",
			carrying = "Content",
			idle = "Content",
		},
		skins = {
			-- The palette the template ships with (Pippa_v10, coral bunny).
			Default = {
				name = "Default",
				paletteTextureId = "rbxassetid://123317546570312",
				facesFolder = nil,
				accessories = {},
			},
			-- The owner's personal skin (see EmployeeSkinRegistry). Art pending: put its palette image id here.
			OwnerSpecial = {
				name = "OwnerSpecial",
				paletteTextureId = nil,
				facesFolder = nil,
				accessories = {},
			},
		},
		defaultSkin = "Default",
	},
}

local EmployeeRegistry = {
	-- The employee every player spawns as (one StarterCharacter serves the whole server).
	DEFAULT = "Pippa",
	FACES = FACES,
	STATES = STATES,
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
