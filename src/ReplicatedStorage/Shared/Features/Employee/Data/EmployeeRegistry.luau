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
	  palette texture), an optional face set, accessories (EmployeeSkinSystem applies one), and the ID-card photo
	  of that look (`portrait`; the employee's own `portrait` when a skin has none).
	- `uniform` is the company gear fitted over any skin (the hi-vis vest and the rank lanyard + ID card), as
	  fitted-gear names (EmployeeGearSystem); the lanyard is painted in the wearer's rank colour.
	- `locomotion` is the employee's own idle/walk/run (keys in the animation registry's `employee`
	  domain) and how fast its feet plant in each; the character's Animate script plays them instead of
	  the stock set. nil = the stock locomotion.
	- `backpack` is where back-worn equipment (the vacuum's canister backpack) sits on this employee, so a
	  body with another shape (a skin, an outfit, a legendary body) can be fitted. nil = fitted from the
	  UpperTorso's size, as for a stock avatar.

	@class EmployeeRegistry
]=]

export type Face = "Happy" | "Worried" | "Content" | "Dazed"

-- What the employee is doing, as far as its face is concerned (EmployeeFaceRules.stateOf).
export type GameplayState = "knockedOut" | "threatened" | "cleaning" | "carrying" | "idle"

export type SkinDef = {
	-- Its key in the employee's `skins`.
	name: string,
	-- "rbxassetid://<id>" of the palette image set as TextureID on every MeshPart but the FacePlate.
	-- nil while the art does not exist yet: the skin then leaves the model's own palette alone.
	paletteTextureId: string?,
	-- The name of a Folder on the model (beside `Faces`) holding this skin's face SurfaceAppearances, one
	-- per Face; it replaces `Faces` on the character. nil keeps the employee's own faces.
	facesFolder: string?,
	-- Names of Accessory instances, or fitted-gear Models (EmployeeGearSystem), under
	-- EmployeeConstants.ACCESSORIES_PATH to put on the character.
	accessories: { string },
	-- "rbxassetid://<image id>" of this look's ID-card photo (a headshot rendered in Blender,
	-- characters/identity/render_portraits.py). nil = the employee's `portrait`.
	portrait: string?,
}

--[=[
	An employee's own locomotion clips and stride tuning. A stride plays at
	`clamp(horizontal speed / plantedSpeed, minRate, maxRate)`: at its planted speed the feet do not slide;
	faster than `plantedSpeed * maxRate` they slide (accepted: a 0.68-stud-legged toon cannot plant at
	WalkSpeed 16 at any sane cadence). The walk/run switch is the base's threshold (run at >= 18 st/s).
]=]
export type LocomotionDef = {
	-- AnimationRegistry keys.
	idle: string,
	walk: string,
	run: string,
	-- Studs/s at which the clip's feet stay planted at 1x playback (measured on the rig).
	walkPlantedSpeed: number,
	runPlantedSpeed: number,
	-- Play-rate floor (both strides) and per-stride caps.
	minRate: number,
	walkMaxRate: number,
	runMaxRate: number,
}

--[=[
	Where a backpack sits on an employee, in the template's authored studs (the employee's `scale` is applied on
	top). The backpack was modelled on Pippa (characters/vacuum/build_backpack_vacuum.py), so her fit is the
	identity apart from its mount.
]=]
export type BackpackFit = {
	-- The pack's mount (the middle of its harness pad, where it meets the back) relative to the UpperTorso's
	-- CFrame: +Y up, +Z back.
	mount: CFrame,
	-- The pack's size relative to as modelled.
	size: number,
	-- The straps' frame relative to the UpperTorso, and how far they are stretched (x across, y up, z through
	-- the torso) relative to as modelled on Pippa: a wider or deeper torso widens the loops.
	strapOffset: CFrame,
	strapStretch: Vector3,
}

export type EmployeeDef = {
	name: string,
	-- Path under ReplicatedStorage to the template model.
	templatePath: { string },
	-- The size every player spawns at, relative to the template as authored (Model:ScaleTo at install, so the
	-- joints, rig and grip attachments, HipHeight and animations all follow). Tools and props were sized for a
	-- stock avatar (head ~5 studs); a chibi is scaled up toward that rather than every prop down to it.
	scale: number,
	-- The expressions the model's `Faces` folder must hold.
	faces: { Face },
	-- What the model shows before the server has decided anything.
	defaultFace: Face,
	-- The face for every gameplay state.
	expressions: { [GameplayState]: Face },
	-- The looks this employee can wear, by name, and the one everyone gets by default.
	skins: { [string]: SkinDef },
	-- "rbxassetid://<image id>" of the ID-card photo for a skin without its own (the default look's headshot).
	portrait: string,
	defaultSkin: string,
	-- Its own idle/walk/run; nil = the stock locomotion.
	locomotion: LocomotionDef?,
	-- Where the vacuum's backpack sits; nil = fitted from the torso's size.
	backpack: BackpackFit?,
	-- The company uniform it wears over every skin: names of fitted-gear Models under
	-- EmployeeConstants.ACCESSORIES_PATH, modelled for THIS employee's body (another torso supplies its own pieces).
	uniform: { string },
}

local FACES: { Face } = { "Happy", "Worried", "Content", "Dazed" }
local STATES: { GameplayState } = { "knockedOut", "threatened", "cleaning", "carrying", "idle" }

local EMPLOYEES: { [string]: EmployeeDef } = {
	Pippa = {
		name = "Pippa",
		templatePath = { "Assets", "CleanupCrew", "Characters", "Pippa" },
		-- Authored at 3.9 studs to the head top (5.4 with ears); 1.25 puts the head at ~4.9, a stock avatar's
		-- height, so the crew reads at eye level with props and the Manager. Tunable: everything follows it
		-- (strides, hip height, carry reach, the vacuum's fit).
		scale = 1.25,
		faces = FACES,
		defaultFace = "Happy",
		expressions = {
			-- Ragdolled or dead (a catch ends in the throw, which is both): the knocked-out face.
			knockedOut = "Dazed",
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
				-- CC ID Portrait Pippa Default v1 (decal 110853442477171).
				portrait = "rbxassetid://114200006283845",
			},
			-- The owner's personal skin (see EmployeeSkinRegistry): lavender fur and round tortoiseshell glasses
			-- (characters/pippa/skins/owner-lavender). Pippa's own faces.
			OwnerSpecial = {
				name = "OwnerSpecial",
				paletteTextureId = "rbxassetid://96382499106680",
				facesFolder = nil,
				accessories = { "PippaRoundGlasses" },
				-- CC ID Portrait Pippa Owner Lavender v1 (decal 106237445017897): lavender, glasses on.
				portrait = "rbxassetid://73949141158412",
			},
		},
		defaultSkin = "Default",
		portrait = "rbxassetid://114200006283845",
		-- Fitted to Pippa v10's torso (characters/identity).
		uniform = { "PippaVest", "PippaLanyard" },
		-- Pippa v1 clips (characters/pippa/anim). Caps tuned by eye in Studio: lively, not frantic.
		locomotion = {
			idle = "pippaidle",
			walk = "pippawalk",
			run = "pipparun",
			walkPlantedSpeed = 1.27,
			runPlantedSpeed = 1.52,
			minRate = 0.6,
			walkMaxRate = 2.5,
			runMaxRate = 2.2,
		},
		-- High on the back, between the head's overhang and the tail (the pack was modelled on her), its pad on
		-- the hi-vis vest's back (outer surface 0.505 there, characters/identity/README.md).
		backpack = {
			mount = CFrame.new(0, 0.16, 0.51),
			size = 1,
			strapOffset = CFrame.identity,
			strapStretch = Vector3.one,
		},
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
	elseif value == "Dazed" then
		return "Dazed"
	end
	return nil
end

return EmployeeRegistry
