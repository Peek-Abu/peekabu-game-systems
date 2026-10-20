--!strict
--[=[
	ShiftClockOutSystem: clocking out, one card per crew member (ShiftClockOutRules has the rule). A crew member who
	punches at the truck's time clock (ShiftTimeClockSystem, through the service's clockOut) is moved onto the truck bed
	at their crew spot (the same arrival spot they started the shift on, OfficeServiceServer.spawnCFrame) and waits
	there: the truck's box is the one place the Manager never sees, hears or catches anyone (OfficeServiceServer.safeZone,
	OccupantMindUtils), and `hold` puts a punched member who walks off it straight back, so once punched you are out.

	`settle` runs every TICK_INTERVAL while the system runs, and right after each punch: it counts the crew still in (the
	crew in the server minus whoever is caught and spectating), records it, starts the truck's countdown at half and ends
	the run at once when everyone still in has punched (a solo punch, or the last one inside caught or gone). The run
	itself ends on the service's clock step (ShiftPhaseRules.tick, ShiftClockOutRules.countdownOver), the same path as
	before, so overtime and the review are untouched. Everyone hears who punched and the count, and the countdown's
	start (ShiftNoticeUtils); the sounds and the HUD board come from the snapshot on each client.

	Kept out of ShiftServiceServer (the service is at the 400-line cap). The decisions are the specced
	ShiftClockOutRules and ShiftNoticeUtils; the shift's state is the service's, handed in as Deps, and the effects (Death,
	Office, the characters, Toast) are the real services unless a spec hands in fakes.

	@class ShiftClockOutSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)
local ShiftClockOutRules = require(ServerScriptService.Features.Shift.Rules.ShiftClockOutRules)
local ShiftNoticeUtils = require(ServerScriptService.Features.Shift.Utils.ShiftNoticeUtils)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

export type Deps = {
	-- The shift's state now, and the service's one way to change it (notices, publish, `changed`).
	getState: () -> ShiftTypes.ShiftState,
	setState: (nextState: ShiftTypes.ShiftState) -> (),
	-- Server time.
	now: () -> number,
	-- The crew in the server (ShiftTripSystem.crew), and whether a player is on it.
	crew: () -> { Player },
	eligible: (player: Player) -> boolean,
	-- Effects; absent = the real ones (specs hand in fakes): whether a player is out (caught: dead and spectating),
	-- moving a player onto the truck bed at crew spot `index`, whether a player is inside the truck's box (nil without
	-- a character), and telling everyone.
	isOut: ((player: Player) -> boolean)?,
	-- Whether a player is knocked out for the shift (no lives left; Shift's lives tracker). Absent = never. A member who
	-- is out but not knocked out is only down for now: the truck does not leave at once while they have not punched.
	isKnockedOut: ((player: Player) -> boolean)?,
	board: ((player: Player, index: number) -> ())?,
	aboard: ((player: Player) -> boolean?)?,
	announce: ((toasts: { ToastTypes.ToastRequest }) -> ())?,
}

export type ShiftClockOutSystem = {
	-- Settles and holds every TICK_INTERVAL; returns the stopper.
	start: () -> () -> (),
	-- `player` punched their card at the time clock (already checked to reach it). False when refused.
	punch: (player: Player) -> boolean,
	-- Brings the countdown up to date with the crew still in.
	settle: () -> (),
	-- Puts every punched member who left the truck's box back on the bed.
	hold: () -> (),
	isPunched: (player: Player) -> boolean,
	-- A crew member still working (on the crew, not punched): who may sign the overtime sheet.
	working: (player: Player) -> boolean,
}

-- The real effects (Deps' absent fields).
local function realIsOut(player: Player): boolean
	return DeathServiceServer:isDead(player)
end

local function realBoard(player: Player, index: number)
	local character = player.Character
	if character == nil then
		return
	end
	character:PivotTo(OfficeServiceServer:spawnCFrame(index))
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function realAboard(player: Player): boolean?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local low, high = OfficeServiceServer:safeZone()
	return ShiftClockOutRules.aboard(root.Position, low, high)
end

local function realAnnounce(toasts: { ToastTypes.ToastRequest })
	for _, toast in toasts do
		ToastServiceServer:send("all", toast)
	end
end

local ShiftClockOutSystem = {}

function ShiftClockOutSystem.new(deps: Deps): ShiftClockOutSystem
	local isOut: (Player) -> boolean = deps.isOut or realIsOut
	local isKnockedOut: (Player) -> boolean = deps.isKnockedOut
		or function(_player: Player): boolean
			return false
		end
	local board: (Player, number) -> () = deps.board or realBoard
	local aboard: (Player) -> boolean? = deps.aboard or realAboard
	local announce: ({ ToastTypes.ToastRequest }) -> () = deps.announce or realAnnounce

	-- The crew's userIds (in crew order), the ones still in now, and the ones down but coming back (out, not knocked out).
	local function count(): ({ number }, { number }, { number })
		local ids: { number } = {}
		local out: { number } = {}
		local waiting: { number } = {}
		for _, player in deps.crew() do
			table.insert(ids, player.UserId)
			if isOut(player) then
				table.insert(out, player.UserId)
				if not isKnockedOut(player) then
					table.insert(waiting, player.UserId)
				end
			end
		end
		return ids, ShiftClockOutRules.stillIn(ids, out), waiting
	end

	-- Settles the state; true when the truck's countdown started just now (not leaving at once).
	local function settleState(): boolean
		local now = deps.now()
		local before = deps.getState()
		local _, stillIn, waiting = count()
		local nextState = ShiftClockOutRules.settle(before, stillIn, now, waiting)
		if nextState == nil then
			return false
		end
		deps.setState(nextState)
		local at = nextState.clockOutAt
		return before.sub ~= "clockout" and nextState.sub == "clockout" and at ~= nil and at > now
	end

	local system: ShiftClockOutSystem
	system = {
		start = function()
			local elapsed = 0
			local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
				elapsed += deltaTime
				if elapsed < ShiftConstants.TICK_INTERVAL then
					return
				end
				elapsed = 0
				system.settle()
				system.hold()
			end)
			return function()
				connection:Disconnect()
			end
		end,

		punch = function(player)
			if not deps.eligible(player) then
				return false
			end
			local nextState = ShiftClockOutRules.punch(deps.getState(), player.UserId)
			if nextState == nil then
				return false
			end
			deps.setState(nextState)
			local ids = count()
			board(player, table.find(ids, player.UserId) or 1)
			local started = settleState()
			local settled = deps.getState()
			local at = settled.clockOutAt
			if settled.sub == "clockout" and at ~= nil and at <= deps.now() then
				-- Everyone still in has punched: the truck leaves now, and the review says the rest.
				return true
			end
			local _, stillIn = count()
			local punched, total = ShiftClockOutRules.tally(settled, stillIn)
			local toasts = { ShiftNoticeUtils.punched(player.DisplayName, punched, total) }
			if started then
				for _, toast in ShiftNoticeUtils.truckLeaving() do
					table.insert(toasts, toast)
				end
			end
			announce(toasts)
			return true
		end,

		settle = function()
			if settleState() then
				announce(ShiftNoticeUtils.truckLeaving())
			end
		end,

		hold = function()
			local state = deps.getState()
			if state.phase ~= "running" or state.punched == nil then
				return
			end
			for index, player in deps.crew() do
				local punched = ShiftClockOutRules.isPunched(state, player.UserId)
				if punched and not isOut(player) and aboard(player) == false then
					board(player, index)
				end
			end
		end,

		isPunched = function(player)
			return ShiftClockOutRules.isPunched(deps.getState(), player.UserId)
		end,

		working = function(player)
			return deps.eligible(player) and not ShiftClockOutRules.isPunched(deps.getState(), player.UserId)
		end,
	}
	return system
end

return ShiftClockOutSystem
