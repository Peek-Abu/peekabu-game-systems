--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Charm = require(ReplicatedStorage.Packages.Charm)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)
local EquipmentBonusFormulas = require(ReplicatedStorage.Shared.Features.Equipment.Utils.EquipmentBonusFormulas)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local CharacterReplicationService = require(ServerScriptService.Features.Replication.ReplicationServiceServer)

-- The stats invariant, enforced by the DATA LAYER on every write into the slice (see PlayerDataSliceSystem's
-- `validate`). The service methods below already respect it, but registering it here makes it hold
-- for ANY path into the slice — including a raw `PlayerDataService:transaction()` op via statsOp that
-- never calls invest/addExperience. Runs after a mutator, inside the no-yield region, so it must stay
-- pure/synchronous.
--
-- The conservation rule (spent <= earned, per pool) is the load-bearing clause: because unspent is
-- DERIVED (earned - spent) and never stored, an over-invested build is *unrepresentable* in stored
-- data no matter which code path wrote it — the validator rejects it before commit rather than a
-- stored pool counter drifting negative. That is why invest can treat its own pointsUnspent check as
-- a friendly pre-flight (a nice error string) rather than the actual guarantee: this is the guarantee.
local function validateStats(stats: PlayerDataTypes.StatsSlice): (boolean, string?)
	-- totalXp: integer, 0 .. maxTotalXp. The no-overflow clamp addExperience applies is ALSO a stored
	-- invariant here, so a raw op cannot bank XP past the cap.
	if type(stats.totalXp) ~= "number" or stats.totalXp ~= math.floor(stats.totalXp) then
		return false, `totalXp must be an integer, got {stats.totalXp}`
	end
	if stats.totalXp < 0 or stats.totalXp > StatFormulas.maxTotalXp() then
		return false, `totalXp out of range ({stats.totalXp})`
	end
	-- investments: registered ids only, non-negative integers. The key set is part of the invariant
	-- (same rule as CurrencyConstants): an unknown key would otherwise persist and replicate, bypassing
	-- StatConstants as the single source of truth for what stats exist.
	for id, points in stats.investments do
		if not StatConstants.isValidStatId(id) then
			return false, `"{id}" is not a registered stat`
		end
		if type(points) ~= "number" or points ~= math.floor(points) or points < 0 then
			return false, `investment "{id}" must be a non-negative integer, got {points}`
		end
	end
	-- conservation: spent may not exceed earned, per pool.
	local unspent = StatFormulas.pointsUnspent(stats.totalXp, stats.investments)
	if unspent.main < 0 or unspent.sub < 0 then
		return false, `investments exceed earned points (main {unspent.main}, sub {unspent.sub})`
	end
	return true
end

-- Registers "stats" as a SLOT-SCOPED slice: each character carries its own progression. The reader
-- projects the slice off ONE slot, which is what lets PlayerDataSliceSystem serve both `get` (the active
-- character) and `getForSlot` (a slot-select preview) from one typed closure. The service never learns
-- that slots exist.
local statsSlice = PlayerDataSliceSystem.registerSlot("stats", {
	totalXp = 0,
	investments = {},
}, function(slot)
	return slot.stats
end, validateStats)

local log = Logger.new("StatServiceServer")
local janitor = Janitor.new()

-- Diagnostic counter for getState: how many live Charm.subscribe pairs start()'s observeBodies callback
-- currently holds (one pair per live body). Incremented at the top of the callback, decremented in its
-- returned cleanup — see start() below.
local activeSubscriptions = 0

--[=[
	Public interface of the service — the SINGLE place method/field types are declared. Annotating the
	table literal below pushes each signature down into the matching body, so the methods carry no
	inline annotations and there are zero casts (see CurrencyServiceServer for the same shape).

	This service owns the "stats" profile slice. NOTHING derived (level, unspent pools, max health) is
	ever stored or replicated: only { totalXp, investments } persists, and StatFormulas re-derives
	everything else on demand — so level and xp cannot desync, and point conservation is structural
	rather than a counter that could drift. Writes reach the owning client through the reactive path
	only: a mutation updates the profile, PlayerDataService mirrors the slice into StateSyncServerStore, and
	charm-sync ships the delta. There is no per-write broadcast packet.
]=]
export type StatServiceServer = {
	dependencies: { string },

	init: (self: StatServiceServer) -> (),
	start: (self: StatServiceServer) -> (),
	stop: (self: StatServiceServer) -> (),
	getStats: (self: StatServiceServer, userId: number) -> PlayerDataTypes.StatsSlice?,
	getProgress: (self: StatServiceServer, userId: number) -> StatFormulas.Progress?,
	getDerived: (self: StatServiceServer, userId: number) -> { [string]: number }?,
	getUnspentPoints: (self: StatServiceServer, userId: number) -> StatFormulas.PoolTotals?,
	addExperience: (self: StatServiceServer, userId: number, amount: number) -> (boolean, boolean),
	invest: (self: StatServiceServer, userId: number, statId: string, points: number) -> (boolean, string?),
	respec: (self: StatServiceServer, userId: number) -> boolean,
	applyToBody: (self: StatServiceServer, userId: number) -> (),
	statsOp: (
		self: StatServiceServer,
		userId: number,
		fn: (stats: PlayerDataTypes.StatsSlice) -> boolean
	) -> PlayerDataService.TransactionOperation,
	getState: (self: StatServiceServer) -> { [string]: any },
}

local StatServiceServer: StatServiceServer = {
	dependencies = { "PlayerDataServiceServer", "ReplicationServiceServer" },

	--[=[
		Initializes the StatServiceServer.
		@param self StatServiceServer -- The service instance
	]=]
	init = function(_self)
		log:debug("StatServiceServer initialized")
	end,

	--[=[
		Wires the body's maximum health to every body spawn AND to every later change in the "stats" or
		"equipment" mirror. Bodies are client-only (character replication): the server holds health on the
		body and the owner mirrors it onto its Humanoid, so this pushes the derived maximum to
		ReplicationServiceServer instead of writing a Humanoid. `observeBodies` replays live bodies,
		so one that spawned before this start() is covered. Any committed write to either slice, through ANY
		path, re-derives and re-applies. `Charm.computed` wraps `StateSyncServerStore.getterFor`'s zero-arg reader
		because `computed`'s getter takes one parameter; `Charm.subscribe` fires only on an actual change,
		synchronously inside the write. Both subscriptions are torn down when the body despawns.
		@param self StatServiceServer -- The service instance
	]=]
	start = function(self)
		janitor:Add(
			CharacterReplicationService:observeBodies(function(player, _epoch)
				activeSubscriptions += 1
				local userId = player.UserId
				self:applyToBody(userId)

				local readStats = StateSyncServerStore.getterFor("stats", userId)
				local readEquipment = StateSyncServerStore.getterFor("equipment", userId)
				local statsSelector = Charm.computed(function(_previous)
					return readStats()
				end)
				local equipmentSelector = Charm.computed(function(_previous)
					return readEquipment()
				end)
				local unsubStats = Charm.subscribe(statsSelector, function()
					self:applyToBody(userId)
				end)
				local unsubEquipment = Charm.subscribe(equipmentSelector, function()
					self:applyToBody(userId)
				end)

				return function()
					unsubStats()
					unsubEquipment()
					activeSubscriptions -= 1
				end
			end),
			true
		)
		log:debug("StatServiceServer started")
	end,

	--[=[
		Undoes start(): the body observer and every per-body subscription (#32). No manual counter reset —
		ReplicationBodyObserverSystem' disposer runs each body's cleanup, which decrements `activeSubscriptions`, so it returns
		to 0 by itself and a leak would show.
		@param _self StatServiceServer -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
		log:debug("StatServiceServer stopped")
	end,

	--[=[
		Gets the persisted stats slice ({ totalXp, investments }) for a user's ACTIVE character.
		@param userId number -- The user ID
		@return PlayerDataTypes.StatsSlice? -- The slice, or nil if the profile is not loaded
	]=]
	getStats = function(_self, userId)
		return statsSlice.get(userId)
	end,

	--[=[
		Gets the UI-facing progression (level, xp into level, xp to next) DERIVED from totalXp.
		@param userId number -- The user ID
		@return StatFormulas.Progress? -- nil if the profile is not loaded
	]=]
	getProgress = function(self, userId)
		local stats = self:getStats(userId)
		if not stats then
			return nil
		end
		return StatFormulas.progress(stats.totalXp)
	end,

	--[=[
		Gets the DERIVED stat values (base + points*perPoint + equipment bonuses) for every registered
		stat.

		Equipment bonuses are read off the ALREADY-MIRRORED "equipment" slice via `StateSyncServerStore`, NOT by
		requiring `EquipmentServiceServer` — `EquipmentServiceServer` already has a normal top-of-file
		require of `StatServiceServer` (its equip-time level check), so a require in the other
		direction is a genuine circular MODULE dependency. Placing that require inside this function
		body (deferred to call time) does NOT avoid it: `luau-lsp`'s static analyzer resolves every
		`require()` expression as a dependency edge on the FILE regardless of where in the file it is
		textually written, so it still rejects the cycle (`Cyclic module dependency`) even though the
		require would only ever execute long after both modules finish loading. The fix has to be
		architectural, not a placement trick — see `EquipmentBonusFormulas`'s header for the extraction this
		led to.

		Reading through `StateSyncServerStore` instead needs no dependency on `EquipmentServiceServer` at all:
		`PlayerDataService` mirrors "equipment" into `StateSyncServerStore` on login (`syncFromProfile`), on every
		slot switch, and after every committed write, so it is never stale for a player whose profile is
		loaded — and `getStats` above already proved this player's profile (hence session) IS loaded.
		The snapshot is `unknown` at this generic boundary by design (see `StateSyncServerStore`'s header); the
		cast below is the same one-site, documented narrowing `StateSyncClientStore`'s atoms perform at the same
		boundary, not a fresh cast invented to dodge strictness.
		@param userId number -- The user ID
		@return { [string]: number }? -- Keyed by stat id; nil if the profile is not loaded
	]=]
	getDerived = function(self, userId)
		local stats = self:getStats(userId)
		if not stats then
			return nil
		end
		local equipmentSnapshot = StateSyncServerStore.getterFor("equipment", userId)() :: PlayerDataTypes.Equipment? -- narrowing the generic StateSyncServerStore boundary, see above
		local bonuses = EquipmentBonusFormulas.aggregate(equipmentSnapshot)
		return StatFormulas.derive(stats.investments, { bonuses })
	end,

	--[=[
		Gets the DERIVED unspent points per pool (earned - spent). There is no stored pool counter.
		@param userId number -- The user ID
		@return StatFormulas.PoolTotals? -- nil if the profile is not loaded
	]=]
	getUnspentPoints = function(self, userId)
		local stats = self:getStats(userId)
		if not stats then
			return nil
		end
		return StatFormulas.pointsUnspent(stats.totalXp, stats.investments)
	end,

	--[=[
		Grants lifetime XP, clamped to maxTotalXp (overflow is discarded by design — see
		StatFormulas.maxTotalXp). `leveledUp` is derived AROUND the mutate (levelOf(after) vs
		levelOf(before)), so a single grant that crosses several levels still reports one true — there
		is no carry loop. Returns (false, false) when already capped: a no-change mutate mirrors nothing.
		@param userId number -- The user ID
		@param amount number -- XP to grant (positive integer)
		@return boolean, boolean -- (changed, leveledUp)
	]=]
	addExperience = function(_self, userId, amount)
		Guard.userId(userId)
		assert(
			type(amount) == "number" and amount > 0 and amount == math.floor(amount),
			`amount must be a positive integer, got {tostring(amount)}`
		)

		local leveledUp = false
		local changed = statsSlice.mutate(userId, function(stats)
			local before = stats.totalXp
			local after = math.min(before + amount, StatFormulas.maxTotalXp())
			if after == before then
				return false -- already at the cap; no change so nothing mirrors
			end
			leveledUp = StatFormulas.levelOf(after) ~= StatFormulas.levelOf(before)
			stats.totalXp = after
			return true
		end)

		if changed and leveledUp then
			log:audit(`userId={userId}`, "STAT_LEVEL_UP", `granted={amount}`)
		end
		return changed, leveledUp
	end,

	--[=[
		Spends points from a pool into a stat. Returns (false, reason) rather than throwing for
		player-driven runtime conditions (unknown stat, insufficient pool) — this will eventually be
		wired to client input, where bad input is expected, not a developer error. The numeric SHAPE
		(positive integer) is still a developer contract, so it asserts.

		The pointsUnspent pre-check produces a friendly error BEFORE mutating; the data-layer validator
		(conservation) is the real backstop that also covers raw statsOp writes.
		@param userId number -- The user ID
		@param statId string -- A registered stat id (StatConstants.DEFINITIONS)
		@param points number -- Points to invest (positive integer)
		@return boolean, string? -- (ok, reason-on-failure)
	]=]
	invest = function(self, userId, statId, points)
		Guard.userId(userId)
		if not StatConstants.isValidStatId(statId) then
			return false, `"{statId}" is not a registered stat`
		end
		assert(
			type(points) == "number" and points > 0 and points == math.floor(points),
			`points must be a positive integer, got {tostring(points)}`
		)

		local stats = self:getStats(userId)
		if not stats then
			return false, `no profile loaded for userId {userId}`
		end

		-- isValidStatId proved the id is registered; assert re-narrows DEFINITIONS[statId] for the type
		-- checker and documents that the two must not drift.
		local definition = StatConstants.DEFINITIONS[statId]
		assert(definition, `stat "{statId}" passed isValidStatId but is missing from DEFINITIONS`)

		local unspent = StatFormulas.pointsUnspent(stats.totalXp, stats.investments)
		local available = if definition.pool == "main" then unspent.main else unspent.sub
		if available < points then
			return false, `not enough {definition.pool} points for "{statId}" (have {available}, need {points})`
		end

		local changed = statsSlice.mutate(userId, function(current)
			current.investments[statId] = (current.investments[statId] or 0) + points
			return true
		end)
		return changed
	end,

	--[=[
		Refunds every invested point by wiping the investments map. Returns whether anything was cleared.

		The mutator receives the slice VALUE, so the investments table is emptied IN PLACE
		(`stats.investments[id] = nil` for each key) — assigning a fresh `{}` to a local would write
		nothing (the mutate contract only reads the mutator's boolean, never a returned value). Setting an
		existing key to nil during `for id in ...` iteration is the one table mutation Lua permits mid-traversal.
		@param userId number -- The user ID
		@return boolean -- True if any investment was cleared
	]=]
	respec = function(_self, userId)
		Guard.userId(userId)
		local changed = statsSlice.mutate(userId, function(stats)
			local cleared = false
			for id in stats.investments do
				stats.investments[id] = nil
				cleared = true
			end
			return cleared
		end)
		return changed
	end,

	--[=[
		Pushes the player's derived health to their body as its maximum. The replication service clamps
		current health DOWN to it (never heals up) and publishes it; the owner's Humanoid mirrors it. An
		unloaded profile is a no-op.
		@param userId number -- The player whose body to update
	]=]
	applyToBody = function(self, userId)
		local derived = self:getDerived(userId)
		if not derived then
			return
		end
		CharacterReplicationService:setMaxHealth(userId, derived.health)
	end,

	--[=[
		Mints a typed TransactionOperation over the stats slice, for composing multi-slice / multi-player
		atomic writes via `PlayerDataService:transaction()` (the typed alternative to a raw op table). The
		conservation validator still runs on the result, so a raw op cannot over-invest. Pure packaging:
		nothing runs until transaction() executes.
		@param userId number -- The user ID the op targets
		@param fn (stats: StatsSlice) -> boolean -- Typed mutator; return false to abort the transaction
		@return PlayerDataService.TransactionOperation
	]=]
	statsOp = function(_self, userId, fn)
		return statsSlice.op(userId, fn)
	end,

	--[=[
		Returns DIAGNOSTIC debugger state: how many live mirror-subscription pairs start()'s
		observeBodies callback currently holds — not derivable from any synced slice, since it
		measures server-side reactive wiring rather than persisted data.
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		return {
			activeSubscriptions = activeSubscriptions,
		}
	end,
}

return StatServiceServer
