--!strict
--[=[
	OccupantScareSystem: the catch scare on this client (Cleanup Crew spec §4 "Catch" step 1: "camera snaps to his
	face ~0.6 s, nearby lights die, distorted sting, stretched-grin face"; kid-safe). `snap` (on CatchCam, which
	only the caught player gets) plays the distorted sting and, for SNAP_SECONDS, on the fallback body only (the Smile
	Mask shows its own Hunting face), puts a grin over his face that stretches wide: the uploaded grin image (OccupantAssets.IMAGES.grin) or, while it is pending, a cartoon grin
	built from frames (white eyes, a wide toothy mouth). `lightsOut` (everyone) plays the power-down and his grab
	where it happened. The camera, the red screen and the dark lights are M2's (OccupantServiceClient,
	OccupantTellSystem).

	Spec-exempt shell (Instances, tweens, Sound).

	@class OccupantScareSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OccupantAssets = require(OccupantShared.Data.OccupantAssets)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

local log = Logger.new("OccupantScareSystem")

export type OccupantScareState = {
	scares: number,
	grins: number,
	lightsOut: number,
	played: number,
	pending: number,
}

local counters: OccupantScareState = { scares = 0, grins = 0, lightsOut = 0, played = 0, pending = 0 }

local function play(id: string, options: SoundTypes.PlayOptions?)
	if OccupantAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not an OccupantAssets sound`)
		return
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return
	end
	counters.played += 1
	SoundServiceClient:playOneShot(id, options)
end

local function headOf(): BasePart?
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		local head = instance:FindFirstChild("Head")
		if head ~= nil and head:IsA("BasePart") then
			return head
		end
	end
	return nil
end

local function frame(parent: Instance, size: UDim2, position: UDim2, color: Color3, round: boolean): Frame
	local item = Instance.new("Frame")
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = item
	end
	item.Parent = parent
	return item
end

-- The frame-built grin (while the image is pending); returns the mouth, which stretches.
local function drawGrin(gui: BillboardGui): Frame
	local white = OccupantConstants.GRIN_WHITE
	local ink = OccupantConstants.GRIN_INK
	for _, x in { 0.32, 0.68 } do
		local eye = frame(gui, UDim2.fromScale(0.2, 0.16), UDim2.fromScale(x, 0.32), white, true)
		frame(eye, UDim2.fromScale(0.35, 0.45), UDim2.fromScale(0.5, 0.55), ink, true)
	end
	local mouth = frame(gui, UDim2.fromScale(0.45, 0.16), UDim2.fromScale(0.5, 0.68), white, true)
	local outline = Instance.new("UIStroke")
	outline.Color = ink
	outline.Thickness = 3
	outline.Parent = mouth
	for index = 1, OccupantConstants.GRIN_TEETH - 1 do
		frame(mouth, UDim2.new(0, 2, 1, 0), UDim2.fromScale(index / OccupantConstants.GRIN_TEETH, 0.5), ink, false)
	end
	return mouth
end

local OccupantScareSystem = {}

--[=[
	The caught player's scare beat: the sting, the grin over his face for SNAP_SECONDS, and FIRED on the throw.
]=]
function OccupantScareSystem.snap()
	counters.scares += 1
	play("harlowCatchSting")
	-- FIRED: its stamp lands on the throw, SNAP_SECONDS after the catch (OccupantCatchSystem).
	task.delay(math.max(0, OccupantConstants.SNAP_SECONDS - OccupantAssets.FIRED_HIT), function()
		play("catchFired")
	end)
	local head = headOf()
	-- The Smile Mask has its own Hunting face (the server shows it): the grin is only for the fallback body.
	if head == nil or (head.Parent ~= nil and head.Parent:FindFirstChild(OccupantAssets.FACE_PLATE) ~= nil) then
		return
	end
	counters.grins += 1
	local gui = Instance.new("BillboardGui")
	gui.Name = OccupantConstants.GRIN_NAME
	gui.Adornee = head
	-- A BillboardGui's scale size is in studs.
	gui.Size = UDim2.fromScale(OccupantConstants.GRIN_SIZE, OccupantConstants.GRIN_SIZE)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local stretch = TweenInfo.new(OccupantConstants.SNAP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local image = OccupantAssets.IMAGES.grin
	if image ~= OccupantAssets.PENDING then
		local picture = Instance.new("ImageLabel")
		picture.AnchorPoint = Vector2.new(0.5, 0.5)
		picture.Position = UDim2.fromScale(0.5, 0.5)
		picture.Size = UDim2.fromScale(0.7, 0.7)
		picture.BackgroundTransparency = 1
		picture.Image = image
		picture.Parent = gui
		TweenService:Create(picture, stretch, { Size = UDim2.fromScale(1, 0.85) }):Play()
	else
		local mouth = drawGrin(gui)
		TweenService:Create(mouth, stretch, { Size = UDim2.fromScale(OccupantConstants.GRIN_STRETCH, 0.2) }):Play()
	end
	-- Under his head on this client only (a client-made child of a replicated part never replicates).
	gui.Parent = head
	task.delay(OccupantConstants.SNAP_SECONDS, function()
		gui:Destroy()
	end)
end

--[=[
	A catch somewhere: the lights' power-down and his grab, heard from there.
]=]
function OccupantScareSystem.lightsOut(position: Vector3)
	counters.lightsOut += 1
	play("harlowPowerDown", { at = position })
	play("harlowGrab", { at = position })
end

--[=[
	You are back after a catch (the Rehired card shows): the time clock punches you back in (2D).
]=]
function OccupantScareSystem.rehired()
	play("catchRehired")
end

function OccupantScareSystem.getState(): OccupantScareState
	return table.clone(counters)
end

return OccupantScareSystem
