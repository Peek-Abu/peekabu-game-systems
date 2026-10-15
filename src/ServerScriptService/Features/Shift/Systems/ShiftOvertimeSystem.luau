--!strict
--[=[
	ShiftOvertimeSystem: opt-in overtime (docs/cleanup-crew-lore.md "Contract sequence": once the quota is met the
	crew chooses to leave or to begin optional overtime recovery; staying is a deliberate choice). The truck's
	overtime sheet, beside the time clock inside the box, carries the OVERTIME_KIND prompt ("Start overtime", held
	OVERTIME_HOLD seconds); like the clock, it counts only from an empty-handed crew member standing in front of it
	(ShiftTimeClockSystem.reaches). Any one crew member signing starts the overtime warning for the whole crew, the
	same any-player rule as the clock out, and is announced by name so nobody is surprised; anyone may still clock
	out during the warning or in overtime. `sync` shows the prompt exactly while ShiftPhaseRules.canStartOvertime holds; `start` runs it on every
	shift state change and takes the prompt's triggers.

	Kept out of ShiftServiceServer (the service is at the 400-line cap). The decisions are the specced
	ShiftPhaseRules.canStartOvertime / startOvertime; the shift's state is the service's, handed in as Deps, and the
	effects (the sheet's prompt, the toast) are Office, Interaction and Toast unless a spec hands in fakes.

	@class ShiftOvertimeSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ShiftPhaseRules = require(ServerScriptService.Features.Shift.Rules.ShiftPhaseRules)
local ShiftTimeClockSystem = require(ServerScriptService.Features.Shift.Systems.ShiftTimeClockSystem)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

-- Registered at load: the office builds the overtime sheet with this kind (its prompt off until overtime may start).
if not InteractionRegistry.has(ShiftConstants.OVERTIME_KIND) then
	InteractionRegistry.register(ShiftConstants.OVERTIME_KIND, {
		actionText = "Start overtime",
		objectText = "Optional recovery",
		holdDuration = ShiftConstants.OVERTIME_HOLD,
		maxDistance = ShiftConstants.PAPERWORK_DISTANCE,
	})
end

export type Deps = {
	-- The shift's state now, and the service's one way to change it (notices, publish, `sync`).
	getState: () -> ShiftTypes.ShiftState,
	setState: (nextState: ShiftTypes.ShiftState) -> (),
	-- Whether a player is in the crew (only the crew may sign).
	eligible: (player: Player) -> boolean,
	-- Server time.
	now: () -> number,
	-- Every shift state change (the service's `changed`).
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	-- Effects; absent = the real services (specs hand in fakes): the overtime sheet (nil before the office is built),
	-- showing / hiding its prompt, and telling the whole crew (a sticky note).
	sheet: (() -> BasePart?)?,
	setEnabled: ((target: BasePart, enabled: boolean) -> ())?,
	announce: ((text: string) -> ())?,
	-- Whether a player may use the sheet now (empty hands, in front of it in the box); absent = the time clock's rule.
	reaches: ((player: Player, target: Instance) -> boolean)?,
}

export type ShiftOvertimeSystem = {
	-- Follows `changed` and takes the sheet's triggers; returns the stopper.
	start: () -> () -> (),
	-- Shows the sheet's prompt exactly while overtime may start.
	sync: () -> (),
	-- `player` signed the sheet (nil: a developer's call). Starts the overtime warning; false when refused.
	begin: (player: Player?) -> boolean,
	-- `player` held Start overtime on `target`: begins when they reach it. False when refused.
	sign: (player: Player, target: Instance) -> boolean,
}

-- The real effects (Deps' absent fields).
local function realSheet(): BasePart?
	return OfficeServiceServer:overtimeSheet()
end

local function realSetEnabled(target: BasePart, enabled: boolean)
	InteractionServiceServer:setEnabled(target, enabled)
end

local function realReaches(player: Player, target: Instance): boolean
	return ShiftTimeClockSystem.reaches(player, target, CarryServiceServer:getCarried(player) ~= nil)
end

local function realAnnounce(text: string)
	ToastServiceServer:send("all", {
		text = text,
		style = ShiftConstants.TOAST_STICKY,
		duration = ShiftConstants.NOTICE_SECONDS,
	})
end

local ShiftOvertimeSystem = {}

function ShiftOvertimeSystem.new(deps: Deps): ShiftOvertimeSystem
	local sheet: () -> BasePart? = deps.sheet or realSheet
	local setEnabled: (BasePart, boolean) -> () = deps.setEnabled or realSetEnabled
	local announce: (string) -> () = deps.announce or realAnnounce
	local reaches: (Player, Instance) -> boolean = deps.reaches or realReaches

	local system: ShiftOvertimeSystem
	system = {
		start = function()
			InteractionServiceServer:onInteract(ShiftConstants.OVERTIME_KIND, function(player, target)
				system.sign(player, target)
			end)
			local following = deps.changed:Connect(function()
				system.sync()
			end)
			system.sync()
			return function()
				following:Disconnect()
			end
		end,

		sync = function()
			local target = sheet()
			if target ~= nil then
				setEnabled(target, ShiftPhaseRules.canStartOvertime(deps.getState()))
			end
		end,

		sign = function(player, target)
			return reaches(player, target) and system.begin(player)
		end,

		begin = function(player)
			if player ~= nil and not deps.eligible(player) then
				return false
			end
			local nextState = ShiftPhaseRules.startOvertime(deps.getState(), deps.now())
			if nextState == nil then
				return false
			end
			deps.setState(nextState)
			announce(`{if player ~= nil then player.DisplayName else "Someone"} signed the overtime sheet!`)
			return true
		end,
	}
	return system
end

return ShiftOvertimeSystem
