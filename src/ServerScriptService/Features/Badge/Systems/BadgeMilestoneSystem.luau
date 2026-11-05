--!strict
--[=[
	BadgeMilestoneSystem: awards Odd Hours' badges (BadgeConstants.GAME) at the moments that earn them, with the keys
	BadgeMilestoneRules picks. BadgeServiceServer starts it.

	- `start` registers every badge whose id is filled in (BadgeRegistry) and warns once with the ones still at 0;
	  an unregistered key is skipped, so the code is live before the Dashboard ids exist.
	- Hired!: the employee is picked (a profile load or a Cosmetic change with `loadout.picked`).
	- Ranks: every rank badge up to the level reached (a profile load, RankServiceServer.changed).
	- Shifts: when a shift reaches its review, each crew member's facts (RankFormulas.factsFor, as the rank's award)
	  and the crew size.
	- Lockers: LockerServiceServer.opened's rarity. New Look: CosmeticServiceServer.equipped with a non-default skin.

	Spec-exempt shell (signals, Players); the decisions are the specced BadgeMilestoneRules.

	@class BadgeMilestoneSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local BadgeConstants = require(ReplicatedStorage.Shared.Features.Badge.Data.BadgeConstants)
local BadgeRegistry = require(ReplicatedStorage.Shared.Features.Badge.Data.BadgeRegistry)
local BadgeMilestoneRules = require(ReplicatedStorage.Shared.Features.Badge.Rules.BadgeMilestoneRules)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local RankTypes = require(ReplicatedStorage.Shared.Features.Rank.Data.RankTypes)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local LockerServiceServer = require(ServerScriptService.Features.Locker.LockerServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local RankServiceServer = require(ServerScriptService.Features.Rank.RankServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
local ShiftResultsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftResultsUtils)
local ShiftReviewSystem = require(ServerScriptService.Features.Shift.Systems.ShiftReviewSystem)

export type Award = (player: Player, key: string) -> ()

local log = Logger.new("BadgeMilestoneSystem")
local registered = false

local BadgeMilestoneSystem = {}

-- Registers every badge with an id (once per server); returns the keys still waiting for one.
function BadgeMilestoneSystem.register(): { string }
	local waiting: { string } = {}
	for _, entry in BadgeConstants.GAME do
		if entry.badgeId == 0 then
			table.insert(waiting, entry.key)
		elseif not registered then
			BadgeRegistry.register(entry.key, { badgeId = entry.badgeId })
		end
	end
	registered = true
	return waiting
end

--[=[
	Follows the moments that earn badges and hands each earned, registered key to `award`. Returns the function that
	stops it.
]=]
function BadgeMilestoneSystem.start(award: Award): () -> ()
	local waiting = BadgeMilestoneSystem.register()
	if #waiting > 0 then
		log:warn(`{#waiting} badge(s) have no Roblox id yet and are not awarded: {table.concat(waiting, ", ")}`)
	end

	local function give(userId: number, keys: { string })
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			return
		end
		for _, key in keys do
			if BadgeRegistry.get(key) ~= nil then
				award(player, key)
			end
		end
	end

	local function hiredAndRanks(userId: number)
		local profile = PlayerDataService:getProfile(userId)
		if profile ~= nil and profile.account.loadout.picked then
			give(userId, { "hired" })
		end
		local progress = RankServiceServer:progressOf(userId)
		if progress ~= nil then
			give(userId, BadgeMilestoneRules.rankKeys(progress.level.level))
		end
	end

	local connections: { SignalTyped.Connection } = {}
	table.insert(connections, PlayerDataService.profileLoaded:Connect(hiredAndRanks))
	table.insert(connections, RankServiceServer.changed:Connect(hiredAndRanks))
	table.insert(
		connections,
		CosmeticServiceServer.changed:Connect(function(userId: number)
			local profile = PlayerDataService:getProfile(userId)
			if profile ~= nil and profile.account.loadout.picked then
				give(userId, { "hired" })
			end
		end)
	)
	table.insert(
		connections,
		CosmeticServiceServer.equipped:Connect(function(userId: number, change: CosmeticTypes.Change)
			if change.kind ~= "skin" then
				return
			end
			local item = CosmeticRegistry.get(change.id)
			local key = if item ~= nil then BadgeMilestoneRules.skinKey(item.rarity) else nil
			if key ~= nil then
				give(userId, { key })
			end
		end)
	)
	table.insert(
		connections,
		LockerServiceServer.opened:Connect(function(userId: number, outcome: LockerTypes.Outcome)
			give(userId, BadgeMilestoneRules.pullKeys(outcome.rarity))
		end)
	)
	local reviewed: { [number]: true } = {}
	table.insert(
		connections,
		ShiftServiceServer.changed:Connect(function(state: ShiftTypes.ShiftState)
			if state.phase ~= "results" or reviewed[state.shift] then
				return
			end
			reviewed[state.shift] = true
			local entries: { RankTypes.CrewEntry } = {}
			for _, member in ShiftReviewSystem.crew() do
				table.insert(entries, {
					userId = member.userId,
					caught = member.caught or 0,
					piles = member.piles,
					items = member.items or 0,
					overtimeSalvage = member.overtimeSalvage or 0,
					friend = member.friend == true,
				})
			end
			local present: { number } = {}
			for _, player in ShiftAnalyticsSystem.crew() do
				table.insert(present, player.UserId)
			end
			local outcome = state.outcome or ""
			local met = ShiftResultsUtils.met(outcome, state.quotaMet)
			local review = ShiftServiceServer:getResults()
			local allSalvage = review ~= nil and BadgeMilestoneRules.allSalvage(review.salvage, review.offered)
			local ranFor = if review ~= nil then review.ranFor or 0 else 0
			for _, entry in entries do
				local facts = RankFormulas.factsFor(entries, met, present, entry.userId, outcome, ranFor)
				if facts ~= nil then
					give(
						entry.userId,
						BadgeMilestoneRules.shiftKeys({
							worked = facts.worked,
							quotaMet = facts.quotaMet,
							crewExtracted = facts.crewExtracted,
							allSalvage = allSalvage,
						}, #entries)
					)
				end
			end
		end)
	)
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

return BadgeMilestoneSystem
