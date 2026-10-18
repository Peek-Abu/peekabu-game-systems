--!strict
--[=[
	OccupantClearanceSystem: keeps the Manager's keyed gestures (the stare's check, the sit-in's head under the desk;
	OccupantGestureFormulas.along) clear of the furniture on this client (2026-10-17: his head arced over the desk and
	down through its top, in full view of the hider under it).

	- `reach`: how much of a gesture's draw-back fits behind him (a ray back from his root, past his own chair; a wall
	  closer than that scales the path down, keeping SLACK studs from it).
	- `carry`: while he sits (the sit-in), his chair goes back and forth with his body, so he rolls in it rather than
	  floating off it. Every client moves the chair art locally and puts it back after.
	- `guard`: for the hider only (the local player hiding in a spot), any part of their spot's furniture his body meets
	  while he gestures is faded out for them (LocalTransparencyModifier), and shown again as soon as it is clear. The
	  sampled paths meet nothing, so this only acts where a wall cut his draw-back short.

	Spec-exempt shell (Instances, raycasts); the paths and the box test are the specced OccupantGestureFormulas.

	@class OccupantClearanceSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local OccupantGestureFormulas = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantGestureFormulas)

-- His chair stands under his root (a sit-in sits SIT_IN_BACK behind its centre): the nearest chair this close.
local CHAIR_RADIUS = 2.5
-- Studs kept between his drawn-back body and a wall behind him.
local SLACK = 1
-- Touching is not meeting.
local MARGIN = 0.05
-- His body parts that bend with a gesture (above the waist), and the face plate on his head.
local BENT = {
	"UpperTorso",
	"Head",
	"FacePlate",
	"NeckColumn",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
}

type Carried = { chair: BasePart, parts: { [BasePart]: CFrame } }

local carried: { [Model]: Carried } = {}
local faded: { [BasePart]: number } = {}
local counters = { reaches = 0, carries = 0, fades = 0 }

local function chairNear(root: BasePart): BasePart?
	local best: BasePart? = nil
	local bestDistance = CHAIR_RADIUS
	-- By tag (OfficeDecorSystem): `carry` asks every frame of a sit-in until it finds his chair, and a scan of the
	-- whole workspace each of those frames was a visible hitch on phones.
	for _, part in CollectionService:GetTagged(OfficeDecorConstants.CHAIR_TAG) do
		if part:IsA("BasePart") then
			local offset = part.Position - root.Position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance < bestDistance then
				best = part
				bestDistance = distance
			end
		end
	end
	return best
end

-- The furniture the local player hides in (the spot's attachment hangs on it), or nil.
local function hidingIn(): BasePart?
	local spotId = Players.LocalPlayer:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE)
	if type(spotId) ~= "string" then
		return nil
	end
	for _, spot in CollectionService:GetTagged(HideConstants.SPOT_TAG) do
		local parent = spot.Parent
		if
			spot:GetAttribute(HideConstants.SPOT_ID_ATTRIBUTE) == spotId
			and parent ~= nil
			and parent:IsA("BasePart")
		then
			return parent
		end
	end
	return nil
end

local OccupantClearanceSystem = {}

--[=[
	The share (0..1) of a draw-back of `back` studs that fits behind `model`'s root.
]=]
function OccupantClearanceSystem.reach(model: Model, back: number): number
	local root = model:FindFirstChild("HumanoidRootPart")
	if back <= 0 or root == nil or not root:IsA("BasePart") then
		return 1
	end
	counters.reaches += 1
	local ignore: { Instance } = { model }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	local chair = chairNear(root)
	if chair ~= nil then
		table.insert(ignore, chair)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local direction = root.CFrame:VectorToWorldSpace(Vector3.new(0, 0, back + SLACK))
	local hit = Workspace:Raycast(root.Position, direction, params)
	if hit == nil then
		return 1
	end
	return math.clamp((hit.Distance - SLACK) / back, 0, 1)
end

--[=[
	Moves the chair under seated `model` `back` studs along his root's back (0 puts it where it stood).
]=]
function OccupantClearanceSystem.carry(model: Model, back: number)
	local current = carried[model]
	local root = model:FindFirstChild("HumanoidRootPart")
	if back <= 1e-3 or root == nil or not root:IsA("BasePart") then
		if current ~= nil then
			for part, frame in current.parts do
				part.CFrame = frame
			end
			carried[model] = nil
		end
		return
	end
	if current == nil then
		local chair = chairNear(root)
		if chair == nil then
			return
		end
		local parts: { [BasePart]: CFrame } = { [chair] = chair.CFrame }
		for _, part in chair:GetDescendants() do
			if part:IsA("BasePart") then
				parts[part] = part.CFrame
			end
		end
		current = { chair = chair, parts = parts }
		carried[model] = current
		counters.carries += 1
	end
	local shift = CFrame.new(root.CFrame:VectorToWorldSpace(Vector3.new(0, 0, back)))
	for part, frame in current.parts do
		part.CFrame = shift * frame
	end
end

--[=[
	For the hider only: fades every part of their spot's furniture that `model`'s bent body meets now (`gesturing`),
	and shows again any that no longer meets it.
]=]
function OccupantClearanceSystem.guard(model: Model?, gesturing: boolean)
	local meeting: { [BasePart]: boolean } = {}
	local furniture = if model ~= nil and gesturing then hidingIn() else nil
	if model ~= nil and furniture ~= nil then
		local body: { OccupantGestureFormulas.Box } = {}
		for _, name in BENT do
			local part = model:FindFirstChild(name, true)
			if part ~= nil and part:IsA("BasePart") and part.Transparency < 1 then
				table.insert(body, { cframe = part.CFrame, size = part.Size })
			end
		end
		local pieces: { BasePart } = { furniture }
		for _, part in furniture:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(pieces, part)
			end
		end
		-- A piece whose box holds the hider's own camera is a hollow mesh round them (a table modelled as one mesh):
		-- its box says nothing about where its surfaces are, so it is never faded.
		local eye = Workspace.CurrentCamera.CFrame.Position
		for _, piece in pieces do
			local inside = piece.CFrame:PointToObjectSpace(eye)
			local around = math.abs(inside.X) < piece.Size.X / 2
				and math.abs(inside.Y) < piece.Size.Y / 2
				and math.abs(inside.Z) < piece.Size.Z / 2
			if piece.Transparency < 1 and not around then
				local box = { cframe = piece.CFrame, size = piece.Size }
				for _, limb in body do
					if OccupantGestureFormulas.overlaps(limb, box, MARGIN) then
						meeting[piece] = true
						break
					end
				end
			end
		end
	end
	for piece in meeting do
		if faded[piece] == nil then
			faded[piece] = piece.LocalTransparencyModifier
			piece.LocalTransparencyModifier = 1
			counters.fades += 1
		end
	end
	for piece, before in faded do
		if not meeting[piece] then
			piece.LocalTransparencyModifier = before
			faded[piece] = nil
		end
	end
end

--[=[
	Puts every carried chair back and shows every faded part (the system stopping).
]=]
function OccupantClearanceSystem.reset()
	for model in carried do
		OccupantClearanceSystem.carry(model, 0)
	end
	OccupantClearanceSystem.guard(nil, false)
end

function OccupantClearanceSystem.getState(): { [string]: number }
	local state = table.clone(counters)
	local count = 0
	for _ in faded do
		count += 1
	end
	state.faded = count
	return state
end

return OccupantClearanceSystem
