--!strict
--[=[
	OccupantStageSystem: a filmmaker's staging of Mr. Harlow (the admin-only `harlow` command, through
	OccupantServiceServer:stage; the decisions are OccupantStageRules).

	Holds the stage (freeze, or a walk to a spot that ends frozen) and a queued chase. While staged, `intent` is his
	intent and the service skips his brain (no sight, hearing or catches). `takeChase` hands the queued chase to his
	next think, once. `command` carries out one action: `here` moves his rig, `chase` wakes him, `calm` returns his new
	mind. `reset` clears it all (he despawned). `direct` carries out a game system's Order (OccupantStageRules.Order);
	`current` is the stage now (nil: his brain thinks), so a director knows when a walk has arrived (it is frozen).

	@class OccupantStageSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)
local OccupantStageRules = require(ServerScriptService.Features.Occupant.Rules.OccupantStageRules)
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)

export type Request = {
	rig: OccupantRigSystem.Rig,
	mind: OccupantTypes.Mind,
	-- The caller's root and hip height (where `come`, `rush` and `here` aim).
	caller: BasePart,
	callerHip: number,
	action: OccupantStageRules.Action,
	-- Who `chase` chases.
	target: Player?,
}

local staged: OccupantStageRules.Stage? = nil
local pendingChase: number? = nil

local OccupantStageSystem = {}

function OccupantStageSystem.reset()
	staged = nil
	pendingChase = nil
end

--[=[
	His intent at `position` while staged (nil when not: his brain thinks as normal).
]=]
function OccupantStageSystem.intent(position: Vector3): NpcTypes.Intent?
	local stage = staged
	if stage == nil then
		return nil
	end
	local intent, nextStage = OccupantStageRules.intent(stage, position)
	staged = nextStage
	return intent
end

--[=[
	The UserId a staged chase starts on, once (nil when none is queued).
]=]
function OccupantStageSystem.takeChase(): number?
	local userId = pendingChase
	pendingChase = nil
	return userId
end

function OccupantStageSystem.current(): OccupantStageRules.Stage?
	return staged
end

-- Moves his rig so its root sits at `goal`.
local function moveRoot(rig: OccupantRigSystem.Rig, goal: CFrame)
	rig.model:PivotTo(goal * rig.root.CFrame:Inverse() * rig.model:GetPivot())
end

--[=[
	Carries out a game system's order on `rig`.
]=]
function OccupantStageSystem.direct(rig: OccupantRigSystem.Rig, order: OccupantStageRules.Order)
	if order.kind == "park" then
		-- The frame is where his feet stand: his root goes his own height above it.
		moveRoot(rig, order.cframe * CFrame.new(0, rig.humanoid.HipHeight + rig.root.Size.Y / 2, 0))
		staged = { kind = "freeze" }
	elseif order.kind == "walk" then
		staged = { kind = "goTo", position = order.position, run = order.run }
		NpcServiceServer:wake(rig.model)
	elseif order.kind == "face" then
		moveRoot(rig, OccupantStageRules.facing(rig.root.CFrame, order.position))
		staged = { kind = "freeze" }
	elseif order.kind == "freeze" then
		staged = { kind = "freeze" }
	elseif order.kind == "free" then
		staged = nil
		NpcServiceServer:wake(rig.model)
	else
		staged = nil
		pendingChase = order.userId
		NpcServiceServer:wake(rig.model)
	end
end

--[=[
	Carries out one staging action. Returns whether it was done, a short line for the caller, and his new mind when the
	action changed it (`calm`).
]=]
function OccupantStageSystem.command(request: Request): (boolean, string, OccupantTypes.Mind?)
	local action, caller = request.action, request.caller
	if action == "chase" then
		local target = request.target
		if target == nil then
			return false, "name the player to chase", nil
		end
		staged = nil
		pendingChase = target.UserId
		NpcServiceServer:wake(request.rig.model)
		return true, `he chases {target.DisplayName}`, nil
	elseif action == "calm" then
		staged = nil
		local userIds = {}
		for _, participant in RoundServiceServer:participants() do
			table.insert(userIds, participant.UserId)
		end
		local calmed = OccupantStageRules.calm(request.mind, userIds, os.clock())
		return true, `he ignores everyone for {OccupantStageRules.CALM_SECONDS} s`, calmed
	elseif action == "free" then
		staged = nil
		return true, "he is back to normal", nil
	elseif action == "here" then
		local rig = request.rig
		local feetY = caller.Position.Y - request.callerHip - caller.Size.Y / 2
		local goal = OccupantStageRules.standIn(caller.CFrame, feetY, rig.humanoid.HipHeight + rig.root.Size.Y / 2)
		moveRoot(rig, goal)
		staged = { kind = "freeze" }
		return true, "he stands where you stood, frozen (free him with: harlow free)", nil
	elseif action == "come" or action == "rush" then
		staged = { kind = "goTo", position = caller.Position, run = action == "rush" }
		return true, "he is coming to where you stand, then he freezes", nil
	end
	staged = { kind = "freeze" }
	return true, "frozen (free him with: harlow free)", nil
end

return OccupantStageSystem
