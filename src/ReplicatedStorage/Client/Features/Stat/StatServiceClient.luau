--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)
local EquipmentBonusFormulas = require(ReplicatedStorage.Shared.Features.Equipment.Utils.EquipmentBonusFormulas)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	A thin read-facade over `StateSyncClientStore.stats`, the one client source of truth (populated by
	charm-sync). Reactive UI reads the atom directly via `useAtom` and calls `StatFormulas` in
	render; imperative callers use these point-in-time accessors. There is no listener, cache, or
	signal here — those retired when the reactive store became the single client store.
]=]
export type StatServiceClient = {
	dependencies: { string },

	getStats: (self: StatServiceClient) -> PlayerDataTypes.StatsSlice?,
	getProgress: (self: StatServiceClient) -> StatFormulas.Progress?,
	getDerived: (self: StatServiceClient) -> { [string]: number }?,
	getUnspentPoints: (self: StatServiceClient) -> StatFormulas.PoolTotals?,
	getState: (self: StatServiceClient) -> { [string]: any },
}

local StatServiceClient: StatServiceClient = {
	dependencies = {},

	--[=[
		Gets the active character's stats snapshot from the reactive store.
		@return PlayerDataTypes.StatsSlice? -- The stats slice, or nil until the first sync lands
	]=]
	getStats = function(_self)
		return StateSyncClientStore.stats()
	end,

	--[=[
		Gets the level/xp-into-level/xp-to-next progress for the synced totalXp.
		@return StatFormulas.Progress? -- Progress, or nil until the first sync lands
	]=]
	getProgress = function(self)
		local stats = self:getStats()
		if not stats then
			return nil
		end
		return StatFormulas.progress(stats.totalXp)
	end,

	--[=[
		Gets the derived stat values (base + points * perPoint, per registered stat) for the synced
		investments.
		@return { [string]: number }? -- Derived values keyed by stat id, or nil until the first sync lands
	]=]
	getDerived = function(self)
		local stats = self:getStats()
		if not stats then
			return nil
		end
		return StatFormulas.derive(stats.investments)
	end,

	--[=[
		Gets the unspent point pools (earned - spent, per pool) for the synced stats.
		@return StatFormulas.PoolTotals? -- Unspent points, or nil until the first sync lands
	]=]
	getUnspentPoints = function(self)
		local stats = self:getStats()
		if not stats then
			return nil
		end
		return StatFormulas.pointsUnspent(stats.totalXp, stats.investments)
	end,

	--[=[
		Returns DERIVED debugger state: progression + the full derived stat block (base + points +
		equipment bonuses), none of which the State tab's raw "stats" slice view shows on its own.
		`{ synced = false }` before the first sync — every other field would otherwise be nil.
		@return { [string]: any } -- Service state
	]=]
	getState = function(self)
		local stats = self:getStats()
		if not stats then
			return { synced = false }
		end
		local progress = StatFormulas.progress(stats.totalXp)
		local unspent = StatFormulas.pointsUnspent(stats.totalXp, stats.investments)
		local bonuses = EquipmentBonusFormulas.aggregate(StateSyncClientStore.equipment())
		return {
			synced = true,
			level = progress.level,
			xpIntoLevel = progress.xpIntoLevel,
			xpToNext = progress.xpToNext,
			unspentMain = unspent.main,
			unspentSub = unspent.sub,
			derived = StatFormulas.derive(stats.investments, { bonuses }),
		}
	end,
}

return StatServiceClient
