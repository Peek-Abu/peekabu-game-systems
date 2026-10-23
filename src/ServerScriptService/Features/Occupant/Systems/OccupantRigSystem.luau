--!strict
--[=[
	OccupantRigSystem: Mr. Harlow's body and his placeholder tells. `build` makes the rig: a clone of the art-owned
	"A - Smile Mask" template (OccupantAssets.TEMPLATE_PATH: a very tall porcelain-faced manager, R15 joints, a long
	neck the head turns on, his painted faces in a `Faces` folder) or, in a place without it, the old fallback (spec
	§7: "a tall, too-thin suited R15 rig built from a HumanoidDescription in code";
	Players:CreateHumanoidModelFromDescription, which may yield). It removes any Animate script (the base Npc
	plays his idle / walk / run), makes sure his Humanoid has an Animator (otherwise the base's pose code
	waits for one inside the NPC think), gives him an empty line attribute (nothing is drawn over his head since
	2026-10-16: his lines are only voiced, OccupantPresenceSystem), tags him Occupant (the client's tells find him by
	it) and, last, Npc with his NpcKind so
	NpcServiceServer adopts him. `present` publishes what he shows and puts the painted face on his mask.

	Twin guard: `sweep` despawns every manager rig (a model tagged OccupantConstants.TAG) but the one kept and warns
	"removed N stray manager rig(s)": there is only ever one Harlow, so any other is a twin a past cleanup missed (a
	shift transit whose cleanup errored; it runs guarded). `build` sweeps before it builds; OccupantServiceServer's
	despawn sweeps after it removes the current rig.

	An Instance builder; `sweep` is specced.

	@class OccupantRigSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantFaceUtils = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantFaceUtils)
local OccupantTellRules = require(ReplicatedStorage.Shared.Features.Occupant.Rules.OccupantTellRules)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)

local log = Logger.new("OccupantRigSystem")

export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
}

-- The latest line per rig, so an older line's timer never hides a newer one. Weak keys.
local speechTokens: { [Model]: number } = {}
setmetatable(speechTokens, { __mode = "k" })

-- The art template under ReplicatedStorage, if the place has it.
local function template(): Model?
	local current: Instance? = ReplicatedStorage
	for _, name in OccupantAssets.TEMPLATE_PATH do
		current = if current ~= nil then current:FindFirstChild(name) else nil
	end
	return if current ~= nil and current:IsA("Model") then current else nil
end

-- The fallback body, its description set from OccupantConstants.BODY. Yields.
local function generate(): Model
	local body = OccupantConstants.BODY
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = body.height
	description.WidthScale = body.width
	description.DepthScale = body.depth
	description.HeadScale = body.head
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	description.HeadColor = body.skin
	description.TorsoColor = body.shirt
	description.LeftArmColor = body.suit
	description.RightArmColor = body.suit
	description.LeftLegColor = body.suit
	description.RightLegColor = body.suit
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	description:Destroy()
	return model
end

-- His body: the template's clone, else the fallback; named, with no Animate script.
local function body(): Model
	local art = template()
	local model = if art ~= nil then art:Clone() else generate()
	model.Name = OccupantConstants.DISPLAY_NAME
	local animate = model:FindFirstChild("Animate")
	if animate ~= nil then
		animate:Destroy()
	end
	return model
end

local function set(instance: Instance, name: string, value: string | number | boolean | Vector3)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

local OccupantRigSystem = {}

--[=[
	Despawns every manager rig in `tagged` (default: every instance tagged OccupantConstants.TAG) that is a Model other
	than `keep`, through `remove` (default NpcServiceServer:despawn), warns with the count when there were any, and
	returns it.
]=]
function OccupantRigSystem.sweep(keep: Model?, tagged: { Instance }?, remove: ((Model) -> ())?): number
	local removed = 0
	for _, instance in tagged or CollectionService:GetTagged(OccupantConstants.TAG) do
		if instance:IsA("Model") and instance ~= keep then
			if remove ~= nil then
				remove(instance)
			else
				NpcServiceServer:despawn(instance)
			end
			removed += 1
		end
	end
	if removed > 0 then
		log:warn(`removed {removed} stray manager rig(s)`)
	end
	return removed
end

--[=[
	Builds Harlow at `at` under `parent` and returns his rig, after sweeping away any manager rig already standing (a
	twin). Yields (the rig is generated from a description).
]=]
function OccupantRigSystem.build(at: CFrame, parent: Instance): Rig
	OccupantRigSystem.sweep()
	local model = body()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if humanoid ~= nil and root ~= nil and root:IsA("BasePart") and head ~= nil and head:IsA("BasePart") then
		humanoid.DisplayName = OccupantConstants.DISPLAY_NAME
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		-- The base pose code (AnimationServiceServer:playOnRig) waits up to 5 s for an Animator, inside the
		-- NPC think, if the generated rig has none.
		if humanoid:FindFirstChildOfClass("Animator") == nil then
			Instance.new("Animator").Parent = humanoid
		end
		model:SetAttribute(OccupantConstants.LINE_ATTRIBUTE, "")
		model:SetAttribute(OccupantConstants.MODE_ATTRIBUTE, "patrol")
		OccupantRigSystem.setFace(model, OccupantFaceUtils.faceFor("patrol"))
		model:SetAttribute(OccupantConstants.TARGET_ATTRIBUTE, 0)
		model:SetAttribute(NpcConstants.KIND_ATTRIBUTE, OccupantConstants.NPC_KIND)
		model:PivotTo(at)
		CollectionService:AddTag(model, OccupantConstants.TAG)
		model.Parent = parent
		-- Last: NpcServiceServer adopts a tagged model with a registered kind.
		CollectionService:AddTag(model, NpcConstants.TAG)
		return {
			model = model,
			humanoid = humanoid,
			root = root,
			head = head,
		}
	end
	model:Destroy()
	error("OccupantRigSystem: the generated rig has no Humanoid, HumanoidRootPart or Head")
end

--[=[
	Gives him a line for SPEECH_SECONDS (a newer line replaces it), as his model's attribute; the client voices it (the
	words are never shown).
]=]
function OccupantRigSystem.say(rig: Rig, line: string)
	local token = (speechTokens[rig.model] or 0) + 1
	speechTokens[rig.model] = token
	rig.model:SetAttribute(OccupantConstants.LINE_ATTRIBUTE, line)
	task.delay(OccupantConstants.SPEECH_SECONDS, function()
		if speechTokens[rig.model] == token and rig.model.Parent ~= nil then
			-- Cleared so the next identical line changes the attribute and the client voices it again.
			rig.model:SetAttribute(OccupantConstants.LINE_ATTRIBUTE, "")
		end
	end)
end

--[=[
	Puts a painted face on his mask: a copy of the template's `Faces`/<face> replaces the FacePlate's SurfaceAppearance
	(named FACE_APPEARANCE, stamped FACE_ATTRIBUTE). No-op when it already shows, or on the fallback body (no plate).
	@return boolean -- whether the face changed
]=]
function OccupantRigSystem.setFace(model: Model, face: OccupantAssets.Face): boolean
	local plate = model:FindFirstChild(OccupantAssets.FACE_PLATE)
	local faces = model:FindFirstChild(OccupantAssets.FACES_FOLDER)
	local source = if faces ~= nil then faces:FindFirstChild(face) else nil
	if plate == nil or source == nil or not source:IsA("SurfaceAppearance") then
		return false
	end
	local current = plate:FindFirstChild(OccupantAssets.FACE_APPEARANCE)
	if current ~= nil and current:GetAttribute(OccupantAssets.FACE_ATTRIBUTE) == face then
		return false
	end
	local copy = source:Clone()
	copy.Name = OccupantAssets.FACE_APPEARANCE
	copy:SetAttribute(OccupantAssets.FACE_ATTRIBUTE, face)
	copy.Parent = plate
	if current ~= nil then
		current:Destroy()
	end
	return true
end

--[=[
	Publishes what he shows (OccupantTellRules.view) as attributes: his mode and target (the client's heartbeat, the
	crew's faces, analytics), his phase (the typing), the gesture and its point and the catch tilt (the client's
	OccupantGestureSystem), and puts the face on his mask. Only what changed is written.
]=]
function OccupantRigSystem.present(rig: Rig, view: OccupantTellRules.View)
	local model = rig.model
	set(model, OccupantConstants.MODE_ATTRIBUTE, view.mode)
	set(model, OccupantConstants.TARGET_ATTRIBUTE, view.target)
	set(model, OccupantConstants.PHASE_ATTRIBUTE, view.phase)
	set(model, OccupantConstants.GESTURE_ATTRIBUTE, view.gesture)
	set(model, OccupantConstants.TILT_ATTRIBUTE, view.tilt)
	local point = view.gestureTarget
	if point ~= nil then
		set(model, OccupantConstants.GESTURE_TARGET_ATTRIBUTE, point)
	end
	OccupantRigSystem.setFace(model, view.face)
end

return OccupantRigSystem
