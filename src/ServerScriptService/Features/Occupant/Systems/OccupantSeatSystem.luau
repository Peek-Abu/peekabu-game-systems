--!strict
--[=[
	OccupantSeatSystem: the Manager's body for the behaviour set (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-
	behaviours-design.md §1–§3), carrying out the brain's body effects on his rig:

	- `sit`: the seat contract (OccupantAssets.SEAT): his root anchored and slid (SLIDE_SECONDS) onto the seat frame
	  (over the chair at standing height, facing the desk), the clipboard hidden, the sit-and-type clip (at Action
	  priority, over the base NPC's idle pose).
	- `stand`: the stand-up clip at `speed` (Action2, over the sit clip it fades from); when it ends, the root moves
	  SEAT.standOffset (where the clip ended him) and is let go, the clipboard back. Without the clip: at once.
	- `plant`: anchored and slid onto a frame (staring at a spot, perfectly still); `release` lets go.
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
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)

type Rig = OccupantRigSystem.Rig

type Body = {
	token: number,
	sitting: AnimationPlayerSystem.PlayHandle?,
	tween: Tween?,
	clipboard: number?,
}

-- How long he slides onto a seat or a stare's spot (the last stride the path left him short).
local SLIDE_SECONDS = 0.35

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
	local tween = TweenService:Create(
		rig.root,
		TweenInfo.new(SLIDE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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

function OccupantSeatSystem.sit(rig: Rig, seat: CFrame)
	local body = bodyOf(rig)
	body.token += 1
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
		rig.root.CFrame = rig.root.CFrame * CFrame.new(OccupantAssets.SEAT.standOffset)
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

function OccupantSeatSystem.release(rig: Rig)
	local body = bodyOf(rig)
	body.token += 1
	stopSitting(body, 0.2)
	showClipboard(rig, body, true)
	letGo(rig, body)
end

return OccupantSeatSystem
