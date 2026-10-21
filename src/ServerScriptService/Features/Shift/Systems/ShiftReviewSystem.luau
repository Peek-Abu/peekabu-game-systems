--!strict
--[=[
	ShiftReviewSystem: keeps each crew member's review stats while a shift runs (Cleanup Crew M3 UI: the performance
	review's joke awards). It listens to the features that own the facts and writes the roster (ShiftRosterTracker):
	- Vacuum `pileCleared`: a pile for everyone on it, and Round's per-player `piles` score (moved from
	  ShiftServiceServer);
	- Carry `dropped`: a drop by hand, or a throw of a fragile item (a break), with the item's kind and value then.
	  Catch drops ("death"), pocketing and banking ("forced") and resets never count;
	- Noise `made`: one noise for each maker;
	- ShiftAnalyticsWatchSystem `investigated`: Harlow went to investigate a noise; each of its makers woke him once;
	- ShiftAnalyticsSystem `loaded`: each accepted Load's cargo items, and its salvage when the shift is in overtime
	  (the company rank's award reads both off the review; RankFormulas).

	`results` builds the performance review at the end of a shift (ShiftResultsUtils): everyone taking part is listed,
	even with nothing done yet (leavers stay from the roster); a bare review when building it throws, so the shift can
	always end (moved from ShiftServiceServer).

	`crew()` reads the running roster back (copies) for the company rank's award at the end of the shift
	(RankShiftSystem); empty when the system is not running.

	Spec-exempt shell (signals, Players); the counting is the specced ShiftRosterTracker, the awards the specced
	ShiftResultsUtils.

	@class ShiftReviewSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)
local NoiseTypes = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local ShiftRosterTracker = require(ServerScriptService.Features.Shift.State.ShiftRosterTracker)
local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
local ShiftAnalyticsWatchSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsWatchSystem)
local ShiftResultsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftResultsUtils)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)

local log = Logger.new("ShiftReviewSystem")

-- What the end of a shift hands the review.
export type ReviewInput = {
	outcome: string,
	quota: number,
	quotaMet: boolean,
	-- The crew still here (everyone taking part is listed, even with nothing done yet).
	crew: { Player },
	roster: ShiftRosterTracker.ShiftRosterTracker,
	-- Salvage the run's roll offered.
	offered: number,
}

local function nameOf(userId: number): string?
	local player = Players:GetPlayerByUserId(userId)
	return if player ~= nil then player.DisplayName else nil
end

-- The roster the running system writes (nil when stopped).
local current: ShiftRosterTracker.ShiftRosterTracker? = nil

local ShiftReviewSystem = {}

-- Every crew member's run this shift (copies; ShiftRosterTracker.list), or empty when the system is not running.
function ShiftReviewSystem.crew(): { ShiftTypes.CrewStats }
	local roster = current
	return if roster ~= nil then roster:list() else {}
end

local function build(input: ReviewInput): ShiftTypes.ShiftResults
	for _, player in input.crew do
		input.roster:record(player.UserId, player.DisplayName, {})
	end
	return ShiftResultsUtils.build({
		outcome = input.outcome,
		quota = input.quota,
		cleared = RoundServiceServer:teamValue(ShiftConstants.CLEARANCE),
		dust = RoundServiceServer:teamValue(ShiftConstants.DUST),
		bonus = RoundServiceServer:teamValue(ShiftConstants.BONUS),
		quotaMet = input.quotaMet,
		crew = input.roster:list(),
		offered = input.offered,
		lookup = CargoRegistry.get,
	})
end

-- The review from Round's counters (read before Round clears them), or a bare one when building it throws: the shift
-- must always be able to end.
function ShiftReviewSystem.results(input: ReviewInput): ShiftTypes.ShiftResults
	local ok, built = pcall(build, input)
	if ok then
		return built
	end
	log:error(`building the results failed: {built}`)
	return ShiftResultsUtils.bare(input.outcome, input.quota, input.quotaMet)
end

function ShiftReviewSystem.start(roster: ShiftRosterTracker.ShiftRosterTracker, running: () -> boolean): () -> ()
	current = roster
	local function each(makers: { number }, delta: ShiftRosterTracker.Delta)
		if not running() then
			return
		end
		for _, userId in makers do
			local name = nameOf(userId)
			if name ~= nil then
				roster:record(userId, name, delta)
			end
		end
	end

	local piles = VacuumServiceServer.pileCleared:Connect(function(_pile: BasePart, players: { Player })
		if not running() then
			return
		end
		for _, player in players do
			if player.Parent ~= nil then
				RoundServiceServer:addScore(player, ShiftConstants.SCORE_PILES, 1)
				roster:record(player.UserId, player.DisplayName, { piles = 1 })
			end
		end
	end)

	local drops = CarryServiceServer.dropped:Connect(
		function(player: Player, object: Instance, reason: CarryTypes.DropReason)
			local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
			local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
			if not running() or def == nil or player.Parent == nil then
				return
			end
			if reason == "drop" or (reason == "throw" and def.fragile) then
				local value = object:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)
				roster:noteDrop(
					player.UserId,
					player.DisplayName,
					def.id,
					if type(value) == "number" then value else def.value
				)
			end
		end
	)

	local noises = NoiseServiceServer.made:Connect(function(event: NoiseTypes.NoiseEvent)
		each(event.makers, { noise = 1 })
	end)

	local woke = ShiftAnalyticsWatchSystem.investigated:Connect(function(makers: { number })
		each(makers, { woke = 1 })
	end)

	local loads = ShiftAnalyticsSystem.loaded:Connect(
		function(player: Player, items: number, _salvage: number, overtimeLoot: number)
			if not running() or player.Parent == nil then
				return
			end
			roster:record(player.UserId, player.DisplayName, {
				items = items,
				overtimeSalvage = overtimeLoot,
			})
		end
	)

	return function()
		if current == roster then
			current = nil
		end
		loads:Disconnect()
		piles:Disconnect()
		drops:Disconnect()
		noises:Disconnect()
		woke:Disconnect()
	end
end

return ShiftReviewSystem
