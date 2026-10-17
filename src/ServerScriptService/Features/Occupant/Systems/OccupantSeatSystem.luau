--!strict
--[=[
	OccupantSeatSystem: the Manager's body for the behaviour set (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-
	behaviours-design.md §1–§3), carrying out the brain's body effects on his rig:

	- `sit`: the seat contract (OccupantAssets.SEAT): his root anchored and slid (SLIDE_SECONDS) onto the seat frame
	  (over the chair at standing height, facing the desk), the clipboard hidden, the sit-and-type clip (at Action
	  priority, over the base NPC's idle pose).
	- `stand`: the stand-up clip at `speed` (Action2, over the sit clip it fades from); when it ends, the root moves
	  SEAT.standOffset (where the clip ended him), pulled back clear of the desk he sat at (OccupantDeskUtils.standUp,
	  STAND_CLEAR: never inside or behind it, where no path exists), and is let go, the clipboard back. Without the
	  clip: at once.
	- `plant`: anchored and slid onto a frame (staring at a spot, perfectly still); `release` lets go.
	- `unstick`: let go and lifted onto a route point (stuck where no path starts: OccupantStuckRules).
	- `look`: turning him while he looks around on arriving somewhere (investigate, search), per frame.
	- Let go always hands his root back to the server's physics (SetNetworkOwner(nil)).

	A newer call cancels an older one's pending end (a token per rig). Spec-exempt shell (Instances, tweens, clips).

	@class OccupantSeatSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local OccupantDeskUtils = require(ServerScriptService.Features.Occupant.Utils.OccupantDeskUtils)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)

type Rig = OccupantRigSystem.Rig

type Body = {
	token: number,
	sitting: AnimationPlayerSystem.PlayHandle?,
	tween: Tween?,
	clipboard: number?,
	-- The seat he sits on and its desk (frame and size), for where standing up ends.
	seat: CFrame?,
	desk: CFrame?,
	deskSize: Vector3?,
	-- His heading when he began looking around (`look`).
	lookBase: number?,
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
		body = { token = 0 }
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
	if AnimationRegistry.get("harlowSitType") ~= nil then
		body.sitting = AnimationServiceServer:playOnRig(
			rig.model,
			"harlowSitType",
			{ priority = Enum.AnimationPriority.Action, fadeTime = SLIDE_SECONDS }
		)
	end
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

function OccupantSeatSystem.release(rig: Rig)
	local body = bodyOf(rig)
	body.token += 1
	stopSitting(body, 0.2)
	showClipboard(rig, body, true)
	letGo(rig, body)
end

return OccupantSeatSystem
