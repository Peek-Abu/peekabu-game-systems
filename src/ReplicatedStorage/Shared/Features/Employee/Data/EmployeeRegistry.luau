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
	  palette texture), an optional face set, and accessories (EmployeeSkinSystem applies one). A
	  portrait that cannot draw shows the shared error tile (PortraitError), never a per-skin photo.
	- `uniform` is the company gear fitted over any skin (the rank lanyard + ID card; the hi-vis vest was dropped), as
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

-- One colour style of a skin's outfit.
export type StyleDef = {
	-- The folder under the outfit's `Styles` whose SurfaceAppearances the outfit meshes and props wear.
	folder: string,
	-- "rbxassetid://<id>" of the body palette this style gives the character (each style recolours the fur); it wins
	-- over the skin's own paletteTextureId. nil = the body keeps its own palettes (an outfit that covers it, as PJ
	-- Cappy's: his skin, hair and face are the same in every style).
	paletteTextureId: string?,
	-- Its chip in the Shop and the locker: a short name (easy words) and its colours, the fur then the outfit.
	name: string,
	swatch: { Color3 },
}

export type SkinDef = {
	-- Its key in the employee's `skins`.
	name: string,
	-- "rbxassetid://<id>" of the palette image set as TextureID on every body MeshPart (all but the FacePlate and
	-- the pieces in EmployeeConstants.PIECES_FOLDER).
	-- nil while the art does not exist yet: the skin then leaves the model's own palette alone.
	paletteTextureId: string?,
	-- Per clothing piece (a child of the template's EmployeeConstants.PIECES_FOLDER, by name): "rbxassetid://<id>" of
	-- the palette image set as TextureID on the piece's MeshParts. nil or a missing piece keeps its own palette.
	piecePalettes: { [string]: string }?,
	-- Per plain-coloured piece MeshPart in that folder, by name (a part with no palette image, e.g. Cappy's shorts):
	-- its Color.
	pieceColors: { [string]: Color3 }?,
	-- The name of a Folder on the model (beside `Faces`) holding this skin's face SurfaceAppearances, one
	-- per Face; it replaces `Faces` on the character. nil keeps the employee's own faces.
	facesFolder: string?,
	-- Names of Accessory instances, or fitted-gear Models (EmployeeGearSystem), under
	-- EmployeeConstants.ACCESSORIES_PATH to put on the character.
	accessories: { string },
	-- The name of a skinned outfit Model under EmployeeConstants.OUTFITS_PATH that EmployeeOutfitSystem fits onto the
	-- character (its Outfit meshes, Rig bones, Styles looks and Props). nil = no outfit.
	outfit: string?,
	-- The outfit's colour styles, in catalogue order (CosmeticRegistry `styles`); the player's look picks one. nil = one
	-- look only.
	styles: { StyleDef }?,
	-- An AnimationRegistry key: the skin's own looped idle that previews (shop, inventory, reveal) play in place of the
	-- employee's idle, holding the skin's props (EmotePropRegistry). nil = the employee's idle.
	showcaseIdle: string?,
	-- An AnimationRegistry key: the one-shot clip the reveal screen plays when this skin is unlocked. nil = the
	-- employee's hireReveal, worn in this skin (owner, 2026-10-29: every skin purchase gets a reveal, the Legendaries'
	-- too for now; a skin may get its own later, e.g. the registered pippabubblebuddyreveal).
	unlockReveal: string?,
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
	-- Its crouch (the Crouch feature): crouched still and crouched moving. nil = it never crouches visibly.
	crouchIdle: string?,
	crouchWalk: string?,
	-- Its rare standing move (AnimationFidgetSystem). nil = it never fidgets.
	fidget: string?,
	-- Studs/s at which the clip's feet stay planted at 1x playback (measured on the rig).
	walkPlantedSpeed: number,
	runPlantedSpeed: number,
	crouchWalkPlantedSpeed: number?,
	-- Play-rate floor (every stride) and per-stride caps.
	minRate: number,
	walkMaxRate: number,
	runMaxRate: number,
	crouchWalkMaxRate: number?,
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
	-- The FootstepAssets set its steps play (the client's FootstepSet attribute); nil = its own name in lower case.
	footstepSet: string?,
	defaultSkin: string,
	-- Its own idle/walk/run; nil = the stock locomotion.
	locomotion: LocomotionDef?,
	-- An AnimationRegistry key: the one-shot clip the reveal screen plays when this employee is hired (and for a skin
	-- with no unlockReveal of its own). nil = no reveal: the idle only.
	hireReveal: string?,
	-- An AnimationRegistry key: the one-shot clip a menu hero plays when you click this employee's pick card or open
	-- their Inventory page (never on Equip or in the Shop: owner, 2026-10-29). nil = no reaction.
	selectReaction: string?,
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
		hireReveal = "pippahirereveal",
		selectReaction = "pippaselect",
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
			},
			-- The owner's personal skin (Cosmetic item Pippa.OwnerSpecial, a gift): lavender fur and round tortoiseshell glasses
			-- (characters/pippa/skins/owner-lavender). Pippa's own faces.
			OwnerSpecial = {
				name = "OwnerSpecial",
				paletteTextureId = "rbxassetid://96382499106680",
				facesFolder = nil,
				accessories = { "PippaRoundGlasses" },
			},
			-- Gloom Locker Uncommon (Cosmetic Pippa.GloomTouched): purple recolour of the body palette
			-- (characters/skins/gloom_touched/pippa), gold bell kept (owner, 2026-10-23). Icey Labs image (decal 80439388958871).
			GloomTouched = {
				name = "GloomTouched",
				paletteTextureId = "rbxassetid://87318460677557",
				facesFolder = nil,
				accessories = {},
			},
			-- Legendary (Cosmetic Pippa.BubbleBuddy): the skinned raincoat, goggles and boots outfit, plus the bubble wand and
			-- duck float the Bubbles emote shows (characters/skins/runtime-candidates-2026-10-26/bubble_buddy/v2-2026-10-28).
			-- Each style recolours her fur too. Icey Labs images.
			BubbleBuddy = {
				name = "BubbleBuddy",
				paletteTextureId = nil,
				facesFolder = nil,
				accessories = {},
				outfit = "PippaBubbleBuddy",
				-- No showcase idle (owner, 2026-10-29: the batch-3 one was rejected): Pippa's own idle, ring at her waist.
				styles = {
					{
						folder = "BlueYellow",
						paletteTextureId = "rbxassetid://74284182744492",
						name = "Blue",
						swatch = { Color3.fromRGB(34, 150, 220), Color3.fromRGB(250, 205, 45) },
					},
					{
						folder = "PinkTurquoise",
						paletteTextureId = "rbxassetid://111714697439083",
						name = "Pink",
						swatch = { Color3.fromRGB(241, 109, 165), Color3.fromRGB(60, 200, 190) },
					},
					{
						folder = "LilacOrange",
						paletteTextureId = "rbxassetid://127175944720666",
						name = "Purple",
						swatch = { Color3.fromRGB(154, 100, 231), Color3.fromRGB(240, 140, 40) },
					},
				},
			},
		},
		defaultSkin = "Default",
		-- Company vest and static PippaLanyard removed: all employees wear the client-fitted v4 lanyard + v6 rank badge
		-- driven by the player's general rank (EmployeeLanyardSystem; gates/7f_badges_v6_info_front_icon_back.md).
		uniform = {},
		-- Pippa v1 clips (characters/pippa/anim). Caps tuned by eye in Studio: lively, not frantic.
		locomotion = {
			idle = "pippaidle",
			walk = "pippawalk",
			run = "pipparun",
			crouchIdle = "pippacrouchidle",
			crouchWalk = "pippacrouchwalk",
			fidget = "pippafidget",
			walkPlantedSpeed = 1.27,
			runPlantedSpeed = 1.52,
			-- 1.625 st/s at her 1.25 scale: planted up to 6.5 st/s at the 4x cap (about 6 steps a second, a quick
			-- scurrying sneak), which is exactly the crouch speed (CrouchConstants.CROUCH_SPEED), so the feet plant
			-- (her walk at 16 still slides 4x).
			crouchWalkPlantedSpeed = 1.3,
			minRate = 0.6,
			walkMaxRate = 2.5,
			runMaxRate = 2.2,
			crouchWalkMaxRate = 4,
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

-- The Default skin of an employee whose art is multi-palette (every garment its own palette image): it repaints nothing.
local function plainDefault(): SkinDef
	return { name = "Default", paletteTextureId = nil, facesFolder = nil, accessories = {} }
end

-- Cappy and Prickles walk at Pippa's stride caps (the same base speeds); only the planted speeds are their own.
local function locomotionOf(
	prefix: string,
	walk: number,
	run: number,
	crouchWalk: number,
	fidget: string?
): LocomotionDef
	return {
		idle = `{prefix}idle`,
		walk = `{prefix}walk`,
		run = `{prefix}run`,
		crouchIdle = `{prefix}crouchidle`,
		crouchWalk = `{prefix}crouchwalk`,
		fidget = fidget,
		walkPlantedSpeed = walk,
		runPlantedSpeed = run,
		crouchWalkPlantedSpeed = crouchWalk,
		minRate = 0.6,
		walkMaxRate = 2.5,
		runMaxRate = 2.2,
		crouchWalkMaxRate = 4,
	}
end

EMPLOYEES.Cappy = {
	name = "Cappy",
	hireReveal = "cappyhirereveal",
	selectReaction = "cappyselect",
	-- Built in each place from characters/employees_build/cappy_v6_preview.luau (v6 body, the owner's hair).
	templatePath = { "Assets", "CleanupCrew", "Characters", "Cappy" },
	scale = 1.25,
	faces = FACES,
	defaultFace = "Content",
	expressions = {
		knockedOut = "Dazed",
		threatened = "Worried",
		cleaning = "Content",
		carrying = "Content",
		idle = "Content",
	},
	skins = {
		Default = plainDefault(),
		-- Gloom Locker Uncommon (Cosmetic Cappy.GloomTouched): his clothes recoloured, skin and hair kept
		-- (characters/skins/gloom_touched/cappy). Icey Labs images (decals 89086860170857, 96407929546482,
		-- 121567969019770). The shorts carry no palette image, so they take the skin's Cloth and Waist colours.
		GloomTouched = {
			name = "GloomTouched",
			paletteTextureId = nil,
			piecePalettes = {
				Hoodie = "rbxassetid://114377324832769",
				Cap = "rbxassetid://79479179553474",
				Sneakers = "rbxassetid://84973217304648",
			},
			pieceColors = {
				Shorts_ConnectedSkinned = Color3.fromHex("C494E8"),
				VisibleWaist = Color3.fromHex("AE7DD6"),
			},
			facesFolder = nil,
			accessories = {},
		},
		-- Legendary (Cosmetic Cappy.PJ): the skinned fleece onesie, bear hood with sleep mask and shark slippers
		-- (characters/skins/runtime-candidates-2026-10-26/pj_cappy/v6-2026-10-29), over his own skin and hair: no
		-- style repaints the body. The outfit hides his hoodie, cap, socks, sneakers and shorts (its HideAccessories).
		-- Previews hold the pillow and cocoa mug in his Sleepy Sway idle. Icey Labs assets.
		PJ = {
			name = "PJ",
			paletteTextureId = nil,
			facesFolder = nil,
			accessories = {},
			outfit = "CappyPJ",
			showcaseIdle = "cappypjidle",
			styles = {
				{
					folder = "BlueButter",
					name = "Blue",
					swatch = { Color3.fromHex("6796DF"), Color3.fromHex("F0B955") },
				},
				{
					folder = "MintRose",
					name = "Mint",
					swatch = { Color3.fromHex("7ABE84"), Color3.fromHex("EFA69A") },
				},
				{
					folder = "CoralCream",
					name = "Coral",
					swatch = { Color3.fromHex("E77D6B"), Color3.fromHex("FCD6B8") },
				},
			},
		},
	},
	defaultSkin = "Default",
	-- No rank lanyard fitted to his body yet.
	uniform = {},
	locomotion = locomotionOf("cappy", 1.06, 2.06, 1.32, "cappyfidget"),
	-- Borrows Pippa's steps until his own sneaker set is made.
	footstepSet = "pippa",
}

EMPLOYEES.Prickles = {
	name = "Prickles",
	hireReveal = "prickleshirereveal",
	selectReaction = "pricklesselect",
	templatePath = { "Assets", "CleanupCrew", "Characters", "Prickles" },
	scale = 1.25,
	faces = FACES,
	defaultFace = "Content",
	expressions = {
		knockedOut = "Dazed",
		threatened = "Worried",
		cleaning = "Content",
		carrying = "Content",
		idle = "Content",
	},
	skins = {
		Default = plainDefault(),
		-- Gloom Locker Uncommon (Cosmetic Prickles.GloomTouched): purple body; his hard hat and flower keep their own
		-- yellow and pink palettes (owner, 2026-10-23), so no piece palette is set
		-- (characters/skins/gloom_touched/prickles). Icey Labs image (decal 73185602446942).
		GloomTouched = {
			name = "GloomTouched",
			paletteTextureId = "rbxassetid://78420217452858",
			facesFolder = nil,
			accessories = {},
		},
		-- Legendary (Cosmetic Prickles.Sheriff): the skinned sheriff outfit (hat, vest, boots) over his body, plus the hose
		-- lasso the emote shows (characters/skins/runtime-candidates-2026-10-26/sheriff_prickles). The outfit covers
		-- his legs and replaces his hard hat and flower (its HideParts / HideAccessories). Each style has its own body
		-- palette (the style folders' BodyPalette). Icey Labs images.
		Sheriff = {
			name = "Sheriff",
			paletteTextureId = nil,
			facesFolder = nil,
			accessories = {},
			outfit = "PricklesSheriff",
			showcaseIdle = "pricklessheriffidle",
			styles = {
				{
					folder = "BrownRed",
					paletteTextureId = "rbxassetid://114520650616235",
					name = "Brown",
					swatch = { Color3.fromRGB(150, 100, 60), Color3.fromRGB(200, 55, 45) },
				},
				{
					folder = "CharcoalBlue",
					paletteTextureId = "rbxassetid://104416112460699",
					name = "Gray",
					swatch = { Color3.fromRGB(70, 75, 85), Color3.fromRGB(60, 110, 200) },
				},
				{
					folder = "IvoryTeal",
					paletteTextureId = "rbxassetid://118528786842498",
					name = "Cream",
					swatch = { Color3.fromRGB(235, 225, 200), Color3.fromRGB(30, 150, 150) },
				},
			},
		},
	},
	defaultSkin = "Default",
	uniform = {},
	locomotion = locomotionOf("prickles", 1.03, 1.93, 1.34, "pricklesfidget"),
	-- Borrows Pippa's steps until his own root-thump set is made.
	footstepSet = "pippa",
}

local EmployeeRegistry = {
	-- The employee a player is until their loadout says otherwise (and the fallback StarterCharacter).
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
