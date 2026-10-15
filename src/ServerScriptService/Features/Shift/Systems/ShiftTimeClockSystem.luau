--!strict
--[=[
	ShiftTimeClockSystem: the truck's time clock (Cleanup Crew's clock out). The clock hangs inside the box on its
	front wall (DepotTruckVisualSystem.paperwork); its CLOCK_OUT_KIND prompt ("Clock out") is held CLOCK_OUT_HOLD
	seconds and reaches PAPERWORK_DISTANCE studs. A trigger counts only from an empty-handed crew member standing in
	front of the clock inside the box (ShiftTimeClockRules, the same rule the client hides the prompt by), so carrying
	cargo up the ramp to bank it can never clock the crew out. `reaches` is shared with the overtime sheet.

	Kept out of ShiftServiceServer (the service is at the 400-line cap). The decision is the specced
	ShiftTimeClockRules; the clock out itself is the service's (Deps.clockOut), and what a player carries is Carry's
	unless a spec hands in a fake.

	@class ShiftTimeClockSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTimeClockRules = require(ReplicatedStorage.Shared.Features.Shift.Rules.ShiftTimeClockRules)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)

-- Registered at load: the office's time clock carries this kind from the moment it is built.
if not InteractionRegistry.has(ShiftConstants.CLOCK_OUT_KIND) then
	InteractionRegistry.register(ShiftConstants.CLOCK_OUT_KIND, {
		actionText = "Clock out",
		objectText = "Time clock",
		holdDuration = ShiftConstants.CLOCK_OUT_HOLD,
		maxDistance = ShiftConstants.PAPERWORK_DISTANCE,
	})
end

export type Deps = {
	-- Starts the clock-out countdown (the service's clockOut).
	clockOut: (player: Player) -> (),
	-- Whether a player is carrying something; absent = Carry.
	carrying: ((player: Player) -> boolean)?,
}

export type ShiftTimeClockSystem = {
	-- Takes the clock's triggers; returns the stopper.
	start: () -> () -> (),
	-- `player` held Clock out on `target`: clocks out when they reach it. False when refused.
	punch: (player: Player, target: Instance) -> boolean,
}

local function realCarrying(player: Player): boolean
	return CarryServiceServer:getCarried(player) ~= nil
end

local ShiftTimeClockSystem = {}

--[=[
	Whether `player` may use the paperwork item `target` (the clock or the overtime sheet) now: their root stands in
	front of it inside the box, and `carrying` is false.
]=]
function ShiftTimeClockSystem.reaches(player: Player, target: Instance, carrying: boolean): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or not target:IsA("BasePart") then
		return false
	end
	local ok = ShiftTimeClockRules.canUse(target.CFrame:PointToObjectSpace(root.Position), carrying)
	return ok
end

function ShiftTimeClockSystem.new(deps: Deps): ShiftTimeClockSystem
	local carrying: (Player) -> boolean = deps.carrying or realCarrying

	local system: ShiftTimeClockSystem
	system = {
		start = function()
			InteractionServiceServer:onInteract(ShiftConstants.CLOCK_OUT_KIND, function(player, target)
				system.punch(player, target)
			end)
			-- Interaction keeps one handler per kind for the session: nothing to undo.
			return function() end
		end,

		punch = function(player, target)
			if not ShiftTimeClockSystem.reaches(player, target, carrying(player)) then
				return false
			end
			deps.clockOut(player)
			return true
		end,
	}
	return system
end

return ShiftTimeClockSystem
