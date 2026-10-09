# Small shared services — design

Status: built with this spec. Roadmap item #14 (docs/ROADMAP.md): leaderstats, badges, analytics, daily
rewards and weighted loot tables. Each is small, generic and data-driven.

## Leaderstats (`Leaderstat`)

Roblox's player list reads a `leaderstats` folder. `LeaderstatRegistry.register(name, { order, read })`
declares a column; `read(player)` returns a number or string from wherever the game keeps it (a currency,
a round score). The service builds the folder (IntValue / NumberValue / StringValue by the value read),
re-reads every column on an interval and on `refresh(player)`. The folder is display only; nothing reads
it back.

## Badges (`Badge`)

`BadgeRegistry.register(key, { badgeId })` (shared). `BadgeServiceServer:award(player, key)` checks a
per-player cache, then `UserHasBadgeAsync` once, then `AwardBadgeAsync` with retries; one award per key per
player is ever in flight (`BadgeAwardTracker`). `has(player, key)` reads the cache (checking once).

## Analytics (`Analytics`)

A thin, safe wrapper over `AnalyticsService`: `custom(player, event, value?, fields?)`, `economy(player,
flow, currency, amount, endingBalance, transactionType, sku?)`, `funnel(player, funnel, step, stepName?)`,
`progression(player, path, status, level, levelName?)`. `AnalyticsRules` trims names and turns up to three
custom field values into the engine's `CustomField01..03` keys. Calls never throw into game code (each is
isolated and counted), and in Studio they only log.

## Daily rewards (`DailyReward`)

An account slice `dailyReward = { lastDay, streak }` (days since the epoch, UTC by default with an
optional hour offset). `DailyRewardRules` decides: claimable once per day; claiming the day after the last
claim continues the streak, a gap restarts it at 1, and the streak cycles every `CYCLE_LENGTH` days. The
game says what day N gives: `setRewards(function(player, day) return { ops } end)`; a claim commits the
streak and the reward ops in one transaction. Clients claim through one rate-limited request and read the
replicated slice (`canClaim` uses server time). Admin: `dailyrewardreset`.

## Weighted loot tables (`Loot`)

`LootRegistry.register(id, { rolls?, entries = { { id, weight, min?, max? } | { nothing = true, weight } } })`
(shared, validated: positive weights, min ≤ max). `LootRules.roll(table, random)` is pure (the random
source is passed in, so drops are testable and seedable) and returns `{ { id, count } }`, merging repeats.
What an id means — an item type, a currency, an egg — is the game's.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Leaderstat | server | Data | LeaderstatRegistry | The player-list columns: name, order, reader |
| Leaderstat | server | root | LeaderstatServiceServer | The leaderstats folder, kept current |
| Badge | shared | Data | BadgeRegistry | Badges by game key |
| Badge | server | State | BadgeAwardTracker | Owned and in-flight awards per player |
| Badge | server | root | BadgeServiceServer | award / has with caching and retries |
| Analytics | server | Rules | AnalyticsRules | Pure: name trimming, custom field keys |
| Analytics | server | root | AnalyticsServiceServer | Safe AnalyticsService wrapper |
| DailyReward | shared | Data | DailyRewardConstants | Cycle length, day offset |
| DailyReward | shared | Rules | DailyRewardRules | Pure: day index, claimability, streak, validator |
| DailyReward | shared | Net | DailyRewardEvents | Packet: claim (client → server) |
| DailyReward | server | root | DailyRewardServiceServer | The slice, claims in one transaction |
| DailyReward | client | root | DailyRewardServiceClient | Status and the claim request |
| Loot | shared | Data | LootTypes | Types only: LootTable, LootEntry, Drop |
| Loot | shared | Data | LootRegistry | Loot tables, validated |
| Loot | shared | Rules | LootRules | Pure: roll a table with an injected random source |
