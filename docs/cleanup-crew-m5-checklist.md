# Cleanup Crew: M5 analytics, the A/B switch and the developer checklist

Spec: `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (§1, §4 variant switch, §6.4, §6.6, M5 row of §9).
Plan: `docs/superpowers/plans/2026-10-10-m5-cleanup-crew-analytics.md`.

## Where analytics go

- Every event goes through `ShiftAnalyticsSystem` (Shift, server) to the base `AnalyticsServiceServer:custom`, which
  calls Roblox's `AnalyticsService:LogCustomEvent`. **Nothing is sent from Studio** (Roblox accepts custom events from
  published games only); in Studio read the server log instead.
- Roblox dashboard: Creator Dashboard → the experience → Analytics → Custom events (Explore). Charts can take up to
  24 h to fill. Each event has three custom fields, used as breakdowns:
  - **field 1** `tags|platform|party|cohort|build`, e.g. `5beats+skip|phone|3|new|w1-v42` (`tags` = the variants of the experiments that affect the event, `-` when none; `cohort` = `new` / `ret` / `unk`; built by `AnalyticsContextUtils`);
  - **field 2** the target (a cargo kind, `kind:source`, a pile kind, a noise source, a word);
  - **field 3** the outcome, or `outcome:reason` for a failure (`failed:caught`).
- Server log (Studio Output, or F9 → Server in a live server you are in): every event as
  `[ShiftAnalyticsSystem] <event> target=… outcome=… reason=… value=… tags=… platform=… party=… cohort=… build=… session=<JobId>`;
  key events at info, the rest at debug. The session id is only here (it would blow up a dashboard field).
- No personal data: no names, UserIds or chat in any field or log line. Field values are catalog ids and fixed words
  only; anything else is written as `other`.

## The events

"Crew" events are sent once to each member of the shift's own crew (the players who rode the truck, from
`ShiftTripSystem`), so divide by party size for per-shift counts. The crew is the trip's, not Round's participants:
Round clears those before its deferred `runEnded` arrives, so `shift_ended` would otherwise find nobody. "s" = seconds
since the shift started. `quota` = `before_quota` / `after_quota`. For `cargo_banked` it is the tag from before that
Load's own effect: the Load that meets the quota still reads `before_quota`.

Any target or outcome can also read `unknown` (a pile with no kind attribute) or `other` (a value outside the
vocabulary): these are the token fallbacks, never personal data.

| Event | When | To | value | target | outcome[:reason] |
|---|---|---|---|---|---|
| contract_started | a run starts | crew | shift # on the server | `alternate` / `fixed` / `override` | `first` / `replay` |
| first_cleanup_started | first vacuum start this shift | player | s | pile kind | quota |
| pile_cleared | a pile is cleared | each player on it | s | pile kind | `solo` / `shared` |
| cargo_picked_up | an item comes into the hands | player | item value | `kind:source` | quota |
| cargo_dropped | drop, throw, caught or left with an item | player | item value | `kind:source` | `dropped` / `thrown` / `caught` / `left` |
| cargo_banked | each item in a Load | loader | value credited | kind | quota |
| noise_investigation | Harlow starts investigating | crew | s | noise he most likely heard | quota |
| chase_started | Harlow starts chasing someone | that player | s | held kind or `empty` | quota |
| player_hit | Harlow catches someone who has lives left (a knockdown) | that player | lives left after it | `harlow` | quota |
| knocked_out | Harlow catches someone on their last life | that player | s | `harlow` | quota |
| crew_wiped | the run ends `wiped` (everyone knocked out) | crew | s | `harlow` | `wiped` |
| quota_met | clearance reaches the quota | crew | s | `clearance` | `met` |
| optional_salvage_attempted | an attempt closes | attempter | s from quota to pick-up | `kind:source` | `banked`, or `failed:` + `dropped` / `thrown` / `caught` / `left` / `unbanked` |
| shift_ended | the run ends | each crew member | that player's attempts | `piles_0` / `piles_1_2` / `piles_3_5` / `piles_6_plus` | how the run ended (`clockout` / `timeout` / …) + `:quota_met` / `:quota_missed` |
| replay_started | an Another shift starts | crew | shift # | `another_shift` | `same_server` |

Item sources: `open` (on the floor), `pile` (uncovered by vacuuming), `desk` (searched), `scatter` (dropped from a
caught or leaving player's pockets).

**An optional-salvage attempt** opens when someone picks up salvage after the quota, outside the loading bay, while no
clock-out countdown runs; it closes once, as `banked` or failed with a reason.

## Known limits (read before trusting a number)

- **Pocket round-trip (N4).** Pocketing an item and taking it out again makes its source read `open`, whatever it was
  before. Unpocketing inside the loading bay keeps the optional-salvage attempt open until the item is banked (or the
  run ends and it closes as `unbanked`).
- **Two salvage of the same kind (M2).** If a player pockets salvage K (attempt open) and then picks up a second K,
  the attempt moves to the second item and still counts as one. Dropping that second item closes it as
  `failed:dropped` while the first is still pocketed, and banking the first later closes nothing: a slight undercount
  and a wrong outcome, only when one player holds two salvage of the same kind. The real fix needs the same Cargo
  extraction as N4.
- **`caught` includes any death (N5).** A `caught` drop or attempt failure comes from the death that follows the
  catch, so it also counts a reset button or a fall, not only Mr. Harlow. (`knocked_out` is Harlow-only: it
  comes from his catch, not from the death.)
- **`cargo_dropped … left` is effectively never sent for a leaving player.** The deferred Carry "removed" signal for a
  leaving player fires after the player has gone, so the record has no recipient. (It is sent on a non-death respawn,
  below.)
- **A leaving player's attempts** close once, as `left`, in the `PlayerRemoving` handler, which hands the leaving
  Player straight to `optional_salvage_attempted` (no lookup, no Parent check), so the record is sent even when the
  deferred handler runs after the Player is unparented. Not yet verified live that Roblox's dashboard keeps a custom
  event logged for a player who is leaving; the server log line is written either way.
- **A non-death respawn** (`LoadCharacter`) closes held attempts as `left`.
- **Studio's mid-run reset** sends `shift_ended` with outcome `cancelled`, and its reason always reads `quota_missed`
  (the reset sets the lobby state before the deferred run end is handled), even if the quota was met.
- **The build label (N6).** In Studio the build reads `m5-dev`, or `m5-v<N>` if a published place version is open
  (`ShiftAnalyticsUtils.build`: `-v<PlaceVersion>` when the version is above 0).

## Open question for the developer (N7)

The session id (the server's JobId) is logged but **not** sent as one of the three custom fields, because one value
per server would explode a dashboard breakdown's cardinality. That means the dashboard cannot group events by server;
only the server log can. Decide before publishing whether that is enough for the sibling session (the log of each
shift is read with the crew anyway), or whether a field must change.

## Answering the validation question (spec §1)

- *Do players go back for optional salvage after the quota?* Among `shift_ended` with reason `quota_met`, the share
  with value ≥ 1 (per player per shift). The `optional_salvage_attempted` count and its `banked` share say how often
  it paid off; its value says how long after the quota they went.
- *Does cleaning improve that decision?* (1) That share in variant B vs variant A (field 1); (2) attempts whose target
  ends in `:pile` (salvage found by cleaning); (3) `shift_ended`'s cleaning bucket (target) against its value.
- With three players this is a story, not statistics: read the server log after each shift with the crew.

## The A/B switch

- B hides some salvage under piles; A shows all of it. **Rewards never change** (same values, multiplier and quota;
  the same seed offers the same salvage in both).
- Default `ShiftConstants.VARIANT_MODE = "alternate"`: the server's first shift plays B in Studio (live: B or A from
  the server's JobId, so servers balance the order), then every Another shift flips it. `"fixed"` always plays B.
- **Override for testing:** set the Workspace attribute `CleanupCrewVariant` to `A` or `B` (server command bar:
  `workspace:SetAttribute("CleanupCrewVariant", "A")`); it applies from the next shift and logs
  `variant A (override)`. Remove it with `workspace:SetAttribute("CleanupCrewVariant", nil)`.

## Developer checklist (not code)

### Before publishing
- [ ] In both places (depot and shift), Workspace has **no** `CleanupCrewVariant` attribute (unless you mean to pin a
      variant for the whole test; it ships with the place).
- [ ] Decide the N7 question above (session id only in the log).
- [ ] Optional: bump `ShiftAnalyticsConstants.BUILD_LABEL` (the place version is appended on its own).
- [ ] Publish both places by following `docs/cleanup-crew-publish.md` (M4's walkthrough).
- [ ] In a live server, open F9 → Server log and confirm a `shift 1: variant …` line and `[ShiftAnalyticsSystem]`
      lines appear; set the log filter to include debug if only info lines show.

### Phone pass on a real device
- [ ] Join the published experience from a phone; the server log shows `platform=phone` (a tablet: `tablet`).
- [ ] Hold-to-vacuum, Pocket, Drop, Throw and Swap buttons are reachable with thumbs and do not cover the HUD.
- [ ] The HUD (timer, clearance bar, canister, pockets), sticky notes, stamps and the results vote are legible.
- [ ] The catch scare, spectate and "Rehired." read on a small screen; frame rate holds in the open office.
- [ ] Loading at the truck and clocking out work by touch; note anything that needed two tries.

### Sibling session (3 players)
- [ ] Everyone joins from the depot and rides one truck; play at least **two shifts** with Another shift so the crew
      plays both variants (the log shows which).
- [ ] Do not tell them about the salvage question; after the quota, watch whether anyone goes back on their own.
- [ ] After each shift, note from the log: variant, quota-met time, attempts (and banked), catches, and ask "fun? 1-5".
- [ ] Afterwards (up to 24 h later), compare with the dashboard: Custom events → `optional_salvage_attempted`,
      `shift_ended`, broken down by field 1.

| Shift | Variant | Quota met at | Attempts (banked) | Catches | Fun 1-5 | Notes |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
