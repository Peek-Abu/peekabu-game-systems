--!strict
--[=[
	OccupantRigSystem: Mr. Harlow's body and his placeholder tells (Cleanup Crew spec §7: "a tall, too-thin
	suited R15 rig built from a HumanoidDescription in code, so no place art is needed"). `build` makes the rig
	(Players:CreateHumanoidModelFromDescription, which may yield), removes any Animate script (the base Npc
	plays his idle / walk / run), makes sure his Humanoid has an Animator (otherwise the base's pose code
	waits for one inside the NPC think), adds a cue billboard ("?" / "!") and a plain speech bubble over his
	head, tags him Occupant (the client's tells find him by it) and, last, Npc with his NpcKind so
	NpcServiceServer adopts him. M3 replaces the cues and bubble with the final face, voice and art.

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
	cue: TextLabel,
	speech: TextLabel,
	bubble: BillboardGui,
}

local CUE_COLOR = Color3.fromRGB(255, 220, 90)
local SPOTTED_COLOR = Color3.fromRGB(255, 70, 60)

-- The latest line per rig, so an older line's timer never hides a newer one. Weak keys.
local speechTokens: { [Model]: number } = {}
setmetatable(speechTokens, { __mode = "k" })

local function billboard(name: string, size: UDim2, offset: Vector3, parent: Instance): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = CUE_COLOR
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = gui
	gui.Parent = parent
	return gui, label
end

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

-- His cue and speech billboards on his head (the bubble starts hidden).
local function tells(head: BasePart): (TextLabel, TextLabel, BillboardGui)
	local _, cue = billboard(OccupantConstants.CUE_NAME, UDim2.fromScale(2.5, 2.5), Vector3.new(0, 2.5, 0), head)
	local bubble, speech =
		billboard(OccupantConstants.SPEECH_NAME, UDim2.fromOffset(260, 56), Vector3.new(0, 4.5, 0), head)
	bubble.Enabled = false
	speech.BackgroundTransparency = 0.1
	speech.BackgroundColor3 = Color3.new(1, 1, 1)
	speech.TextColor3 = Color3.fromRGB(20, 20, 24)
	speech.TextStrokeTransparency = 1
	speech.Font = Enum.Font.SourceSansSemibold
	return cue, speech, bubble
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
		local cue, speech, bubble = tells(head)
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
			bubble = bubble,
		}
	end
	model:Destroy()
	error("OccupantRigSystem: the generated rig has no Humanoid, HumanoidRootPart or Head")
end

--[=[
	The text over his head ("?", "!" or nothing).
]=]
function OccupantRigSystem.setCue(rig: Rig, text: string)
	rig.cue.Text = text
	rig.cue.TextColor3 = if text == "!" then SPOTTED_COLOR else CUE_COLOR
end

--[=[
	Shows a line in his speech bubble for SPEECH_SECONDS (a newer line replaces it).
]=]
function OccupantRigSystem.say(rig: Rig, line: string)
	local token = (speechTokens[rig.model] or 0) + 1
	speechTokens[rig.model] = token
	rig.speech.Text = line
	rig.bubble.Enabled = true
	task.delay(OccupantConstants.SPEECH_SECONDS, function()
		if speechTokens[rig.model] == token and rig.bubble.Parent ~= nil then
			rig.bubble.Enabled = false
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
