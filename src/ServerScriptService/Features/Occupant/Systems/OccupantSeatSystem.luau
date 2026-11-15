--!strict
--[=[
	OccupantSeatSystem: the Manager's body for the behaviour set (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-
	behaviours-design.md §1–§3), carrying out the brain's body effects on his rig:

	- `sit`: the seat contract (OccupantAssets.SEAT): his root anchored and slid (SLIDE_SECONDS) onto the seat frame
	  (over the chair at standing height, facing the desk), the clipboard hidden, the sit-and-type clip (at Action
	  priority, over the base NPC's idle pose).
	- `typing`: his hands type only while the brain says he types (OccupantTellRules.typing): the sit-and-type clip is
	  held still (speed 0, the seated pose kept) through the ambush, a slow turn from the chair and the whole sit-in
	  motion (the roll back, the fold, the look under, the way back up), so he never types while his chair rolls.
	- `stand`: the stand-up clip at `speed` (Action2, over the sit clip it fades from); when it ends, the root moves
	  SEAT.standOffset (where the clip ended him), pulled back clear of the desk he sat at (OccupantDeskUtils.standUp,
	  STAND_CLEAR: never inside or behind it, where no path exists), and is let go, the clipboard back. Without the
	  clip: at once.
	- `plant`: anchored and slid onto a frame (staring at a spot, perfectly still); `release` lets go.
	- `unstick`: let go and lifted onto a route point (stuck where no path starts: OccupantStuckRules).
	- `perch` / `drop`: a perch kind set (unseen, in a blackout) crouched on a prop's visible top, and its hop, fall,
	  squash and rise back down to a checked landing past the edge (B4, OccupantPerchRules).
	- `look`: turning him while he looks around on arriving somewhere (investigate, search), per frame.
	- `jerk`: his body snapping round to his already-turned head as a slow turn ends in a chase (behaviours design
	  §11.4: OccupantTurnRules.jerkYaw over JERK_SECONDS from when his root is free), per frame.
	- Let go always hands his root back to the server's physics (SetNetworkOwner(nil)).

	A newer call cancels an older one's pending end (a token per rig). Spec-exempt shell (Instances, tweens, clips).

	@class OccupantSeatSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantTellRules = require(ReplicatedStorage.Shared.Features.Occupant.Rules.OccupantTellRules)
local OccupantGestureFormulas = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantGestureFormulas)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)
local OccupantPerchRules = require(ServerScriptService.Features.Occupant.Rules.OccupantPerchRules)
local OccupantTurnRules = require(ServerScriptService.Features.Occupant.Rules.OccupantTurnRules)
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local OccupantDeskUtils = require(ServerScriptService.Features.Occupant.Utils.OccupantDeskUtils)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)

type Rig = OccupantRigSystem.Rig

type Body = {
	token: number,
	sitting: AnimationPlayerSystem.PlayHandle?,
	-- Whether the sit-and-type clip runs (his hands typing) or is held still.
	typing: boolean,
	tween: Tween?,
	clipboard: number?,
	-- The seat he sits on and its desk (frame and size), for where standing up ends.
	seat: CFrame?,
	desk: CFrame?,
	deskSize: Vector3?,
	-- His heading when he began looking around (`look`).
	lookBase: number?,
	-- The jerk he is snapping round in (its phaseAt), his heading when it began and since when his root was free.
	jerkOf: number?,
	jerkBase: number?,
	jerkStart: number?,
}

-- He slides onto a seat or a stare's spot (the last stride the path left him short) at SLIDE_SPEED studs a second,
-- taking at least SLIDE_SECONDS.
local SLIDE_SECONDS = 0.35
local SLIDE_SPEED = 8

local bodies: { [Model]: Body } = {}
setmetatable(bodies, { __mode = "k" })

local function bodyOf(rig: Rig): Body
	local body = bodies[rig.model]
	if body == nil then
		body = { token = 0, typing = true }
		bodies[rig.model] = body
	end
	return body
end

local function clipboard(rig: Rig): BasePart?
	local part = rig.model:FindFirstChild(OccupantAssets.CLIPBOARD)
	return if part ~= nil and part:IsA("BasePart") then part else nil
end

local function showClipboard(rig: Rig, body: Body, shown: boolean)
	local part = clipboard(rig)
	if part == nil then
		return
	end
	if shown then
		part.Transparency = body.clipboard or 0
		body.clipboard = nil
	elseif body.clipboard == nil then
		body.clipboard = part.Transparency
		part.Transparency = 1
	end
end

local function slide(rig: Rig, body: Body, frame: CFrame)
	local running = body.tween
	if running ~= nil then
		running:Cancel()
	end
	rig.root.Anchored = true
	rig.root.AssemblyLinearVelocity = Vector3.zero
	local seconds = math.max(SLIDE_SECONDS, (frame.Position - rig.root.Position).Magnitude / SLIDE_SPEED)
	local tween = TweenService:Create(
		rig.root,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = frame }
	)
	body.tween = tween
	tween:Play()
end

local function letGo(rig: Rig, body: Body)
	local running = body.tween
	if running ~= nil then
		running:Cancel()
		body.tween = nil
	end
	rig.root.Anchored = false
	pcall(function()
		rig.root:SetNetworkOwner(nil)
	end)
end

-- His leg's two lengths (studs): hip to knee and knee to ankle, from the left leg's joints (0, 0 for a rig without
-- them, which then never comes down for a crouch).
local function legOf(rig: Rig): (number, number)
	local hip = rig.model:FindFirstChild("LeftHip", true)
	local knee = rig.model:FindFirstChild("LeftKnee", true)
	local ankle = rig.model:FindFirstChild("LeftAnkle", true)
	if hip == nil or knee == nil or ankle == nil then
		return 0, 0
	end
	if not hip:IsA("Motor6D") or not knee:IsA("Motor6D") or not ankle:IsA("Motor6D") then
		return 0, 0
	end
	return (knee.C0.Position - hip.C1.Position).Magnitude, (ankle.C0.Position - knee.C1.Position).Magnitude
end

-- His shape as plain data (OccupantGestureFormulas.posedBox), read once per rig.
local shapes: { [Model]: OccupantGestureFormulas.RigShape } = {}
setmetatable(shapes, { __mode = "k" })

local function shapeOf(rig: Rig): OccupantGestureFormulas.RigShape
	local known = shapes[rig.model]
	if known ~= nil then
		return known
	end
	local sizes: { [string]: Vector3 } = {}
	local motors: { OccupantGestureFormulas.RigMotor } = {}
	for _, item in rig.model:GetDescendants() do
		if item:IsA("BasePart") then
			sizes[item.Name] = item.Size
		elseif item:IsA("Motor6D") then
			local part0, part1 = item.Part0, item.Part1
			if part0 ~= nil and part1 ~= nil then
				table.insert(
					motors,
					{ name = item.Name, part0 = part0.Name, part1 = part1.Name, c0 = item.C0, c1 = item.C1 }
				)
			end
		end
	end
	local shape: OccupantGestureFormulas.RigShape = { root = rig.root.Name, sizes = sizes, motors = motors }
	shapes[rig.model] = shape
	return shape
end

-- The box round his perched body, in his root's space (the perch gesture's pose on his own parts).
local function perchBox(rig: Rig): (Vector3, Vector3)
	return OccupantGestureFormulas.posedBox(shapeOf(rig), OccupantConstants.GESTURES.perch.joints)
end

-- How far his root stands above the floor.
local function standHeight(rig: Rig): number
	return rig.humanoid.HipHeight + rig.root.Size.Y / 2
end

local function stopSitting(body: Body, fade: number)
	local handle = body.sitting
	body.sitting = nil
	if handle ~= nil then
		handle:stop(fade)
	end
end

local OccupantSeatSystem = {}

function OccupantSeatSystem.sit(rig: Rig, seat: CFrame, desk: CFrame?, deskSize: Vector3?)
	local body = bodyOf(rig)
	body.token += 1
	body.seat = seat
	body.desk = desk
	body.deskSize = deskSize
	slide(rig, body, seat)
	showClipboard(rig, body, false)
	stopSitting(body, 0)
	body.typing = true
	if AnimationRegistry.get("harlowSitType") ~= nil then
		body.sitting = AnimationServiceServer:playOnRig(
			rig.model,
			"harlowSitType",
			{ priority = Enum.AnimationPriority.Action, fadeTime = SLIDE_SECONDS }
		)
	end
end

--[=[
	Runs his seated typing while `mind` types (OccupantTellRules.typing), else holds it still in the seated pose. Per
	think; only a change touches the clip.
]=]
function OccupantSeatSystem.typing(rig: Rig?, mind: OccupantTypes.Mind)
	if rig == nil then
		return
	end
	local body = bodyOf(rig)
	local handle = body.sitting
	local typing = OccupantTellRules.typing(mind.mode, mind.phase)
	if handle == nil or body.typing == typing then
		return
	end
	body.typing = typing
	handle:adjustSpeed(if typing then 1 else 0)
end

function OccupantSeatSystem.stand(rig: Rig, speed: number)
	local body = bodyOf(rig)
	body.token += 1
	local token = body.token
	local function finish()
		if body.token ~= token or rig.model.Parent == nil then
			return
		end
		local seat, desk, deskSize = body.seat, body.desk, body.deskSize
		local offset = OccupantAssets.SEAT.standOffset
		rig.root.CFrame = if seat ~= nil
				and desk ~= nil
				and deskSize ~= nil
			then OccupantDeskUtils.standUp(seat, offset, desk, deskSize, OccupantConstants.STAND_CLEAR)
			else rig.root.CFrame * CFrame.new(offset)
		body.seat = nil
		showClipboard(rig, body, true)
		letGo(rig, body)
	end
	local handle = if AnimationRegistry.get("harlowStandUp") ~= nil
		then AnimationServiceServer:playOnRig(
			rig.model,
			"harlowStandUp",
			{ priority = Enum.AnimationPriority.Action2, speed = speed, fadeTime = 0.1 }
		)
		else nil
	stopSitting(body, 0.15)
	if handle == nil then
		finish()
		return
	end
	-- The brain waits STAND_SECONDS / speed too (a just-loaded track may not know its length yet).
	local length = handle:length()
	local seconds = (if length > 0 then length else OccupantConstants.STAND_SECONDS) / math.max(speed, 0.1)
	task.delay(seconds - 0.03, function()
		local current = body.token == token
		finish()
		if current then
			handle:stop(0)
		end
	end)
end

function OccupantSeatSystem.plant(rig: Rig, frame: CFrame)
	local body = bodyOf(rig)
	body.token += 1
	slide(rig, body, frame)
end

--[=[
	How tall he is perched (his crouch's lowest to highest point, measured on his own parts at his own scale): the brain
	offers only perches with that much room under the ceiling (Senses.perchHeight, OccupantPerchRules.fits).
]=]
function OccupantSeatSystem.perchHeight(rig: Rig): number
	local low, high = perchBox(rig)
	return high.Y - low.Y
end

--[=[
	Moves him (unseen) up onto a perch's `top` (the centre of the prop's visible top), held there (anchored), turned
	toward `facing` (B4, OccupantPerchRules), in the dark (owner play-check 11-14): it marks his rig
	(PERCH_FLASH_ATTRIBUTE, and PERCH_FLASH_TARGET_ATTRIBUTE = `at`, where his body will sit) so every client darks the
	lights round where he is and round the perch (OccupantTellSystem), and moves him PERCH_DARK_LEAD later, set down so
	the lowest point of his crouch (`perchBox`) rests on the top. The drop is `drop`.
]=]
function OccupantSeatSystem.perch(rig: Rig, top: Vector3, facing: Vector3, at: Vector3)
	local body = bodyOf(rig)
	body.token += 1
	local token = body.token
	body.seat = nil
	stopSitting(body, 0)
	local running = body.tween
	if running ~= nil then
		running:Cancel()
		body.tween = nil
	end
	local flashes = rig.model:GetAttribute(OccupantConstants.PERCH_FLASH_ATTRIBUTE)
	rig.model:SetAttribute(OccupantConstants.PERCH_FLASH_TARGET_ATTRIBUTE, at)
	rig.model:SetAttribute(
		OccupantConstants.PERCH_FLASH_ATTRIBUTE,
		(if type(flashes) == "number" then flashes else 0) + 1
	)
	rig.root.Anchored = true
	rig.root.AssemblyLinearVelocity = Vector3.zero
	local low = perchBox(rig)
	local position = top - Vector3.new(0, low.Y, 0)
	local toward = Vector3.new(facing.X, position.Y, facing.Z)
	local frame = if (toward - position).Magnitude > 1e-3
		then CFrame.lookAt(position, toward)
		else CFrame.new(position) * rig.root.CFrame.Rotation
	task.delay(OccupantConstants.PERCH_DARK_LEAD, function()
		if body.token ~= token or rig.model.Parent == nil then
			return
		end
		rig.root.CFrame = frame
	end)
end

--[=[
	The drop off a perch (B4): from where he crouches on the top, a hop and a fall onto the floor point `point` over
	DROP_FALL_SECONDS (OccupantPerchRules.fallAt), the squash held, the rise to standing, then let go. His root stays
	anchored throughout and follows the drop gesture's legs (OccupantGestureFormulas.jointAt), lowered by their leg drop
	at every moment, so the feet that every client bends stay on the floor once he lands. A newer call stops it.
]=]
function OccupantSeatSystem.drop(rig: Rig, point: Vector3)
	local body = bodyOf(rig)
	body.token += 1
	local token = body.token
	body.seat = nil
	stopSitting(body, 0)
	showClipboard(rig, body, true)
	local running = body.tween
	if running ~= nil then
		running:Cancel()
		body.tween = nil
	end
	local keys = OccupantConstants.GESTURES.drop.keys or {}
	local thigh, shin = legOf(rig)
	local function legDrop(t: number): number
		return OccupantGestureFormulas.crouchDrop(thigh, shin, {
			LeftHip = OccupantGestureFormulas.jointAt(keys, t, "LeftHip"),
			LeftKnee = OccupantGestureFormulas.jointAt(keys, t, "LeftKnee"),
		})
	end
	local rotation = rig.root.CFrame.Rotation
	-- Where he would stand, were he not crouched: the path runs between standing heights; the legs come off it.
	local from = rig.root.Position + Vector3.new(0, legDrop(0), 0)
	local to = point + Vector3.new(0, standHeight(rig), 0)
	rig.root.Anchored = true
	rig.root.AssemblyLinearVelocity = Vector3.zero
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		if body.token ~= token or rig.model.Parent == nil then
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		if elapsed >= OccupantConstants.DROP_SECONDS then
			if connection ~= nil then
				connection:Disconnect()
			end
			rig.root.CFrame = CFrame.new(to) * rotation
			letGo(rig, body)
			return
		end
		local path = OccupantPerchRules.fallAt(
			from,
			to,
			elapsed / OccupantConstants.DROP_FALL_SECONDS,
			OccupantConstants.DROP_HOP
		)
		local down = legDrop(elapsed / OccupantConstants.DROP_SECONDS)
		rig.root.CFrame = CFrame.new(path - Vector3.new(0, down, 0)) * rotation
	end)
end

--[=[
	Lifts him, let go, onto the floor point `point` (a route point, where a path exists), keeping his heading: the last
	resort when he is stuck where no path starts (OccupantStuckRules).
]=]
function OccupantSeatSystem.unstick(rig: Rig, point: Vector3)
	local body = bodyOf(rig)
	body.token += 1
	body.seat = nil
	stopSitting(body, 0)
	showClipboard(rig, body, true)
	letGo(rig, body)
	local height = rig.humanoid.HipHeight + rig.root.Size.Y / 2
	rig.root.CFrame = CFrame.new(point + Vector3.new(0, height, 0)) * rig.root.CFrame.Rotation
	rig.root.AssemblyLinearVelocity = Vector3.zero
end

--[=[
	Turns him while he looks around (`mind` investigating or searching, arrived): his heading swept by
	OccupantBrainRules.lookYaw from where he faced on arriving. Never while his body is anchored. Per frame.
]=]
function OccupantSeatSystem.look(rig: Rig?, mind: OccupantTypes.Mind?, now: number)
	if rig == nil then
		return
	end
	local body = bodyOf(rig)
	local arrivedAt = if mind ~= nil then mind.arrivedAt else nil
	local looking = mind ~= nil and (mind.mode == "investigate" or mind.mode == "search")
	if not looking or arrivedAt == nil or rig.root.Anchored then
		body.lookBase = nil
		return
	end
	local facing = rig.root.CFrame.LookVector
	local base: number = body.lookBase or math.atan2(-facing.X, -facing.Z)
	body.lookBase = base
	local yaw = base + OccupantBrainRules.lookYaw(now - arrivedAt)
	rig.root.CFrame = CFrame.new(rig.root.Position) * CFrame.Angles(0, yaw, 0)
end

--[=[
	Snaps his body round to face the player in the jerk (`mind` in a chase, phase `jerk`): from his heading when his root
	was first free (at once standing; after the fast stand-up from a chair) to the jerk's point, over JERK_SECONDS. Per
	frame; never while his body is anchored.
]=]
function OccupantSeatSystem.jerk(rig: Rig?, mind: OccupantTypes.Mind?, now: number)
	if rig == nil then
		return
	end
	local body = bodyOf(rig)
	local point = if mind ~= nil then mind.point else nil
	local phaseAt = if mind ~= nil then mind.phaseAt else nil
	if mind == nil or mind.mode ~= "chase" or mind.phase ~= "jerk" or point == nil or phaseAt == nil then
		body.jerkOf = nil
		return
	end
	if body.jerkOf ~= phaseAt then
		body.jerkOf = phaseAt
		body.jerkBase = nil
		body.jerkStart = nil
	end
	if rig.root.Anchored then
		return
	end
	local facing = rig.root.CFrame.LookVector
	local base: number = body.jerkBase or OccupantTurnRules.yawOf(facing)
	local start: number = body.jerkStart or now
	body.jerkBase = base
	body.jerkStart = start
	if now - start > OccupantConstants.JERK_SECONDS + 0.05 then
		return
	end
	local offset = point - rig.root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local yaw = OccupantTurnRules.jerkYaw(base, OccupantTurnRules.yawOf(flat.Unit), now - start)
	rig.root.CFrame = CFrame.new(rig.root.Position) * CFrame.Angles(0, yaw, 0)
end

function OccupantSeatSystem.release(rig: Rig)
	local body = bodyOf(rig)
	body.token += 1
	stopSitting(body, 0.2)
	showClipboard(rig, body, true)
	letGo(rig, body)
end

return OccupantSeatSystem
