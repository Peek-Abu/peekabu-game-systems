--!strict
--[=[
	AnimationTypes: the shared type vocabulary of the animation registry (Phase 6 spec, Decision 1).

	Every animation the game plays is declared as an `AnimationDef` in a domain registry in
	`Shared/Features/Animation/Data/`, composed by `AnimationRegistry`. The old game kept ids in six-plus
	places with no metadata; here the id's behaviour — priority, looping, interruption class —
	travels WITH the id, so a consumer can never play an animation "its own way".

	@class AnimationTypes
]=]

--[=[
	How an animation relates to bulk-stop verbs (spec Decision 4). Declared per entry, replacing the
	old name-substring matching (`"lighthit"` → attack, `"dodge"` → protected) that flipped combat
	semantics on a rename.

	- `attack` — stoppable by the stop-attacks verb.
	- `protected` — never bulk-stopped (reactions, dodges, blocks, death, emotes).
	- `ambient` — locomotion-level; bulk stops ignore it, an individual stop still works.
	@type InterruptionClass "attack" | "protected" | "ambient"
]=]
export type InterruptionClass = "attack" | "protected" | "ambient"

--[=[
	The grant slot a server-granted action occupies on a character: one grant per layer per character, and a new grant on a layer replaces the old one under the interruption rules. Engine
	blending is still decided by each entry's `priority`; the layer only decides what replaces what.

	- `full` — whole-body actions: attacks, dodges, hit reactions, emotes.
	- `upper` — upper-body actions layered over locomotion: casting while moving, carrying, aiming.
	- `overlay` — small additive or cosmetic clips that never block the others (a flinch, a hand pose).
	@type AnimationLayer "full" | "upper" | "overlay"
]=]
export type AnimationLayer = "full" | "upper" | "overlay"

--[=[
	One registered animation.
	@interface AnimationDef
	.assetId string -- canonical "rbxassetid://N" only; the registry rejects every other form
	.priority Enum.AnimationPriority
	.looped boolean
	.interruption InterruptionClass
	.variants { string }? -- optional extra asset ids; a play rolls ONE of assetId + variants
	.replicable boolean? -- true = the server may grant it as a replicated action (R3); locomotion stays local
	.wireId number? -- replicable only: a stable 1-65535 id on the wire, never reused or renumbered
	.layer AnimationLayer? -- replicable only: the grant slot it occupies
	.durationMs number? -- replicable one-shots only: the clip's length at speed 1 (looped entries omit it)
]=]
export type AnimationDef = {
	assetId: string,
	priority: Enum.AnimationPriority,
	looped: boolean,
	interruption: InterruptionClass,
	variants: { string }?,
	replicable: boolean?,
	wireId: number?,
	layer: AnimationLayer?,
	durationMs: number?,
}

--[=[
	A domain module's export: entry key -> definition. Keys are stable ids ("idle", "walk") unique
	ACROSS domains — the composed registry enforces that.
	@type AnimationDomain { [string]: AnimationDef }
]=]
export type AnimationDomain = { [string]: AnimationDef }

-- Annotated before freezing: `table.freeze`'s generic would otherwise widen the literals to
-- `{string}` before the annotation could narrow them to the union.
local classList: { InterruptionClass } = { "attack", "protected", "ambient" }
local INTERRUPTION_CLASSES = table.freeze(classList)

local CLASS_SET: { [string]: boolean } = {}
for _, class in INTERRUPTION_CLASSES do
	CLASS_SET[class] = true
end

-- Order is the wire encoding (index 1..3): append only, never reorder.
local layerList: { AnimationLayer } = { "full", "upper", "overlay" }
local ANIMATION_LAYERS = table.freeze(layerList)

local LAYER_INDEX: { [string]: number } = {}
for index, layer in ANIMATION_LAYERS do
	LAYER_INDEX[layer] = index
end
-- Spelled out: a loop over the list widens each layer to `string`, which no longer narrows to the type.
local LAYER_BY_NAME: { [string]: AnimationLayer } = { full = "full", upper = "upper", overlay = "overlay" }

local AnimationTypes = {
	INTERRUPTION_CLASSES = INTERRUPTION_CLASSES,
	ANIMATION_LAYERS = ANIMATION_LAYERS,
	-- The largest wire id a uint16 carries.
	MAX_WIRE_ID = 65535,
	-- The largest variant count a uint8 variant index carries (0 = the entry's own asset).
	MAX_VARIANTS = 255,
}

--[=[
	True iff `value` names a declared interruption class. The runtime guard behind the type, for
	boundaries (Cmdr args, packet payloads) where the type has been erased.
	@param value unknown
	@return boolean
]=]
function AnimationTypes.isInterruptionClass(value: unknown): boolean
	return type(value) == "string" and CLASS_SET[value] == true
end

--[=[
	True iff `value` is the ONE canonical asset-id form, `rbxassetid://N`. The old game mixed this
	with `http://www.roblox.com/asset/?id=N`; the registry admits only the canonical form so ids are
	comparable as plain strings.
	@param value unknown
	@return boolean
]=]
function AnimationTypes.isCanonicalAssetId(value: unknown): boolean
	return type(value) == "string" and string.match(value, "^rbxassetid://%d+$") ~= nil
end

--[=[
	True iff `value` names a declared animation layer.
	@param value unknown
	@return boolean
]=]
function AnimationTypes.isAnimationLayer(value: unknown): boolean
	return type(value) == "string" and LAYER_BY_NAME[value] ~= nil
end

--[=[
	The layer named `name`, or nil (narrows a string from a command or a channel key to the type).
	@param name string
	@return AnimationLayer?
]=]
function AnimationTypes.layerNamed(name: string): AnimationLayer?
	return LAYER_BY_NAME[name]
end

--[=[
	A layer's wire index (1-based, the order of `ANIMATION_LAYERS`), or nil for a name that is no layer.
	@param layer string
	@return number?
]=]
function AnimationTypes.layerIndex(layer: string): number?
	return LAYER_INDEX[layer]
end

--[=[
	The layer at a wire index, or nil for an index no layer has (a malformed packet).
	@param index number
	@return AnimationLayer?
]=]
function AnimationTypes.layerAt(index: number): AnimationLayer?
	return ANIMATION_LAYERS[index]
end

-- ===================================================================================================
-- Carrying (AnimationCarryArmUtils, AnimationCarryHoldRules, AnimationCarryContactUtils,
-- AnimationCarryPoseRules, AnimationCarrySystem). Everything is in the carrier's HumanoidRootPart space at the rig's
-- rest pose unless it says otherwise. The contract is in docs/animation.md ("Holding things").
-- ===================================================================================================

--[=[
	How an item is held: `hand` (one hand, hanging from the relaxed right hand by its handle and swinging),
	`under` (both hands under it, palms up on its real bottom surface, riding the upper torso) or `push` (it stands on
	the floor in front, both palms flat on its near face, riding the root).
	@type CarryStyle "hand" | "under" | "push"
]=]
export type CarryStyle = "hand" | "under" | "push"

-- The body part a held item is joined to: the root (pushed), the UpperTorso (under) or the RightHand (hand).
export type CarryMount = "root" | "torso" | "rightHand"

--[=[
	One arm of a carrier, read from its rig at rest (AnimationCarryArmUtils).
	@interface CarryArm
	.side number -- 1 right, -1 left
	.shoulder Vector3 -- the shoulder joint
	.upperRest CFrame -- the UpperArm, LowerArm and Hand part frames
	.lowerRest CFrame
	.handRest CFrame
	.shoulderInUpper Vector3 -- joint pivots in their parts' space
	.elbowInUpper Vector3
	.elbowInLower Vector3
	.wristInLower Vector3
	.wristInHand Vector3
	.palmInHand CFrame -- the palm: LookVector along the fingers, UpVector out of the palm
	.gripInHand CFrame -- where a closed hand holds a handle (its GripAttachment), turned as the palm
	.handLength number -- the hand along its fingers
]=]
export type CarryArm = {
	side: number,
	shoulder: Vector3,
	upperRest: CFrame,
	lowerRest: CFrame,
	handRest: CFrame,
	shoulderInUpper: Vector3,
	elbowInUpper: Vector3,
	elbowInLower: Vector3,
	wristInLower: Vector3,
	wristInHand: Vector3,
	palmInHand: CFrame,
	gripInHand: CFrame,
	handLength: number,
}

-- An arm's three part frames.
export type CarryPose = { upper: CFrame, lower: CFrame, hand: CFrame }

-- A body part, or one slice of it, as an ellipsoid.
export type CarryBody = { centre: Vector3, radii: Vector3 }

--[=[
	The carrier as the carry planner sees it.
	@interface CarryRig
	.right CarryArm
	.left CarryArm
	.front number -- the torso's front (most negative Z)
	.headFront number -- the head's front (most negative Z)
	.headBottom number -- the head's lowest and highest points (Y)
	.headTop number
	.floor number -- the floor under the feet (Y)
	.torsoHalfWidth number -- the torso's half width (X): a shoulder inside it is a round body's (Pippa)
	.body { CarryBody } -- the torso (UpperTorso, LowerTorso) the arms keep out of, as stacked slices of its real
	surface
	.head { CarryBody } -- the head an item keeps out of, the same way
]=]
export type CarryRig = {
	right: CarryArm,
	left: CarryArm,
	front: number,
	headFront: number,
	headBottom: number,
	headTop: number,
	floor: number,
	torsoHalfWidth: number,
	body: { CarryBody },
	head: { CarryBody },
}

--[=[
	A ray against an item's VISIBLE surface, in its box space (the box around its visible parts, centred on the
	origin): from `from` along `along` (its length is the reach). Returns the first hit and the surface's outward
	normal there, or nil.
	@type CarryProbe (from: Vector3, along: Vector3) -> (Vector3?, Vector3?)
]=]
export type CarryProbe = (from: Vector3, along: Vector3) -> (Vector3?, Vector3?)

--[=[
	An item to hold, in its box space: the size of the box around its visible parts, a probe of their real surface,
	and what its art authors (`CarryHandle`: the point a hand holds it by; `CarryBodyFront`: the depth held against
	the body).
	@interface CarryItem
	.size Vector3
	.probe CarryProbe
	.handle Vector3?
	.bodyZ number?
]=]
export type CarryItem = { size: Vector3, probe: CarryProbe, handle: Vector3?, bodyZ: number? }

--[=[
	A planned hold (AnimationCarryContactUtils.plan).
	@interface CarryHold
	.style CarryStyle
	.offset CFrame -- the item's box in root space
	.right CFrame -- the right palm's contact, box space (a palm frame: UpVector into the item)
	.left CFrame? -- the left palm's (nil for one hand)
	.rightPose CarryPose -- the arms' poses that reach them (root space)
	.leftPose CarryPose?
	.mount CarryMount
]=]
export type CarryHold = {
	style: CarryStyle,
	offset: CFrame,
	right: CFrame,
	left: CFrame?,
	rightPose: CarryPose,
	leftPose: CarryPose?,
	mount: CarryMount,
}

return AnimationTypes
