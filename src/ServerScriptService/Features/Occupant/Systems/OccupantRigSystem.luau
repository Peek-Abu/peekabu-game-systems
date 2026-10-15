--!strict
--[=[
	OccupantRigSystem: Mr. Harlow's body and his placeholder tells (Cleanup Crew spec §7: "a tall, too-thin
	suited R15 rig built from a HumanoidDescription in code, so no place art is needed"). `build` makes the rig
	(Players:CreateHumanoidModelFromDescription, which may yield), removes any Animate script (the base Npc
	plays his idle / walk / run), makes sure his Humanoid has an Animator (otherwise the base's pose code
	waits for one inside the NPC think), adds two empty tagged shells over his head (his cue and his memo; the
	server writes only their attributes, the client draws them: OccupantBillboardSystem, and voices each line:
	OccupantPresenceSystem), tags him Occupant (the client's tells find him by it) and, last, Npc with his NpcKind so
	NpcServiceServer adopts him.

	Spec-exempt shell (Instances).

	@class OccupantRigSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)

export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	cue: BillboardGui,
	speech: BillboardGui,
}

-- The latest line per rig, so an older line's timer never hides a newer one. Weak keys.
local speechTokens: { [Model]: number } = {}
setmetatable(speechTokens, { __mode = "k" })

-- The generated model, its description set from OccupantConstants.BODY. Yields.
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
	model.Name = OccupantConstants.DISPLAY_NAME
	local animate = model:FindFirstChild("Animate")
	if animate ~= nil then
		animate:Destroy()
	end
	return model
end

-- An empty shell over his head for the client to draw into (OccupantBillboardSystem): its attribute starts "", then
-- the tag, then the parent.
local function shell(
	name: string,
	size: UDim2,
	offset: Vector3,
	tag: string,
	attribute: string,
	head: BasePart,
	sizeOffset: Vector2
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffset = offset
	gui.SizeOffset = sizeOffset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute(attribute, "")
	CollectionService:AddTag(gui, tag)
	gui.Parent = head
	return gui
end

-- His cue disc and memo shells on his head.
local function tells(head: BasePart): (BillboardGui, BillboardGui)
	local studs = OccupantConstants.CUE_STUDS
	local memo = OccupantConstants.MEMO_PX
	local cue = shell(
		OccupantConstants.CUE_NAME,
		UDim2.fromScale(studs, studs),
		Vector3.new(0, 2.5, 0),
		OccupantConstants.CUE_TAG,
		OccupantConstants.CUE_ATTRIBUTE,
		head,
		Vector2.zero
	)
	local speech = shell(
		OccupantConstants.SPEECH_NAME,
		UDim2.fromOffset(memo.X, memo.Y),
		-- Its bottom edge sits on the cue disc's top edge (SizeOffset lifts the shell by half its own height), so the
		-- fixed-px memo can never cover the "!" however far away it draws.
		Vector3.new(0, 2.5 + studs / 2, 0),
		OccupantConstants.SPEECH_TAG,
		OccupantConstants.LINE_ATTRIBUTE,
		head,
		Vector2.new(0, 0.5)
	)
	return cue, speech
end

local OccupantRigSystem = {}

--[=[
	Builds Harlow at `at` under `parent` and returns his rig. Yields (the rig is generated from a description).
]=]
function OccupantRigSystem.build(at: CFrame, parent: Instance): Rig
	local model = generate()
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
		local cue, speech = tells(head)
		model:SetAttribute(OccupantConstants.MODE_ATTRIBUTE, "patrol")
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
			cue = cue,
			speech = speech,
		}
	end
	model:Destroy()
	error("OccupantRigSystem: the generated rig has no Humanoid, HumanoidRootPart or Head")
end

--[=[
	The cue over his head ("?", "!" or ""), as the cue shell's attribute; the client draws the disc.
]=]
function OccupantRigSystem.setCue(rig: Rig, text: string)
	rig.cue:SetAttribute(OccupantConstants.CUE_ATTRIBUTE, text)
end

--[=[
	Puts a line on his memo for SPEECH_SECONDS (a newer line replaces it), as the speech shell's attribute; the client
	types and voices it.
]=]
function OccupantRigSystem.say(rig: Rig, line: string)
	local token = (speechTokens[rig.model] or 0) + 1
	speechTokens[rig.model] = token
	rig.speech:SetAttribute(OccupantConstants.LINE_ATTRIBUTE, line)
	task.delay(OccupantConstants.SPEECH_SECONDS, function()
		if speechTokens[rig.model] == token and rig.speech.Parent ~= nil then
			-- Cleared so the next identical line changes the attribute and the client types and voices it again.
			rig.speech:SetAttribute(OccupantConstants.LINE_ATTRIBUTE, "")
		end
	end)
end

--[=[
	Publishes his mode and target as attributes (the client's heartbeat reads them).
]=]
function OccupantRigSystem.setMode(rig: Rig, mode: OccupantTypes.Mode, target: number?)
	rig.model:SetAttribute(OccupantConstants.MODE_ATTRIBUTE, mode)
	rig.model:SetAttribute(OccupantConstants.TARGET_ATTRIBUTE, target or 0)
end

return OccupantRigSystem
