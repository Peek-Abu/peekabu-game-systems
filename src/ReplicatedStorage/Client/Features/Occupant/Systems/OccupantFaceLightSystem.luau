--!strict
--[=[
	OccupantFaceLightSystem: lights the Manager's face on this client while a camera frames it (the catch's jumpscare,
	OccupantServiceClient; the hider's reveal, OccupantWarningSystem). Root cause it answers (user, 2026-10-17: "his
	face is too dark"): a catch kills every light within LIGHTS_OUT_RADIUS and the reveal is shot from inside a desk or
	cabinet, so nothing in the room lit the face the camera was pointed at.

	`frame(owner, head)` hangs two client-only PointLights on Attachments in his head (OccupantVfxConstants FACE_KEY:
	a soft warm key in front of his face; FACE_RIM: a cool rim behind his head), shared by every owner; `release(owner)`
	lets go, and the lights go with the last owner. `framing()` tells OccupantDreadSystem to ease the screen back
	(OccupantDreadFormulas.framed). Created on the client, so no other player sees them.

	@class OccupantFaceLightSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantVfxConstants = require(ReplicatedStorage.Client.Features.Occupant.Data.OccupantVfxConstants)

type LightDef = { offset: Vector3, color: Color3, brightness: number, range: number }
type Rig = { head: BasePart, parts: { Instance } }

local owners: { [string]: true } = {}
local rig: Rig? = nil
local framed = 0

local function light(name: string, head: BasePart, def: LightDef): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = def.offset
	local point = Instance.new("PointLight")
	point.Color = def.color
	point.Brightness = def.brightness
	point.Range = def.range
	point.Shadows = false
	point.Parent = attachment
	attachment.Parent = head
	return attachment
end

local function teardown()
	local current = rig
	rig = nil
	if current ~= nil then
		for _, part in current.parts do
			part:Destroy()
		end
	end
end

local OccupantFaceLightSystem = {}

--[=[
	`owner` frames his `head`: lights it (once, shared by every owner; moved if the head changed).
]=]
function OccupantFaceLightSystem.frame(owner: string, head: BasePart)
	owners[owner] = true
	local current = rig
	if current ~= nil and current.head == head and current.head.Parent ~= nil then
		return
	end
	teardown()
	framed += 1
	rig = {
		head = head,
		parts = {
			light("FaceKeyLight", head, OccupantVfxConstants.FACE_KEY),
			light("FaceRimLight", head, OccupantVfxConstants.FACE_RIM),
		},
	}
end

--[=[
	`owner` stops framing his face; the lights go with the last owner.
]=]
function OccupantFaceLightSystem.release(owner: string)
	if owners[owner] == nil then
		return
	end
	owners[owner] = nil
	if next(owners) == nil then
		teardown()
	end
end

--[=[
	Whether a camera frames his (still present) face right now.
]=]
function OccupantFaceLightSystem.framing(): boolean
	local current = rig
	return current ~= nil and current.head.Parent ~= nil
end

--[=[
	Drops every owner and the lights (service stop, specs).
]=]
function OccupantFaceLightSystem.clear()
	table.clear(owners)
	teardown()
end

function OccupantFaceLightSystem.getState(): { framing: boolean, owners: number, framed: number }
	local count = 0
	for _ in owners do
		count += 1
	end
	return { framing = OccupantFaceLightSystem.framing(), owners = count, framed = framed }
end

return OccupantFaceLightSystem
