# M5: Cleanup Crew, Analytics and the A/B Variant Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every shift sends the 13 spec §6.6 analytics events, with the spec's fields and no personal data, so the developer can answer the validation question after the sibling session; and each shift's A/B variant is picked deterministically on the server, logged, overridable for testing, and provably never changes rewards.

**Architecture:** Analytics is Shift's job (spec §6.2: Shift owns "A/B variant, analytics events"). One game-side module, **`ShiftAnalyticsSystem`**, is the only caller of the base `AnalyticsServiceServer:custom`: it whitelists the event name, turns every target/outcome/reason into a vocabulary token (catalog ids and fixed words only, so a name, chat line or id can never reach a field), packs the context, logs the full record (with the session id) and keeps a ring of recent records plus listeners (the Studio test sink: AnalyticsService sends nothing in Studio). It also keeps the experiment context: session (JobId), build (label + PlaceVersion), each shift's variant and each player's client-reported platform (a `Platform` packet parsed from a fixed enum). The facts come from the features that own them through their **existing public signals** (Shift `changed`, Round `runEnded`, Vacuum `pileCleared` + one new `vacuumStarted`, Carry `pickedUp`/`dropped`, Death `died`, Noise `made`, Harlow's replicated mode/target attributes); **`ShiftAnalyticsWatchSystem`** subscribes to them and calls `emit`, and Shift's banking handler (`ShiftBankingSystem`) emits `cargo_banked`. No Vacuum, Cargo or Occupant service carries analytics code, and the two services at the line cap (`ShiftServiceServer`, `CargoServiceServer`) grow by a handful of lines at most (Shift first sheds ~20 by moving its vote receiver into `Net/`). Every decision is a pure, specced module: payloads and tokens (`ShiftAnalyticsUtils`), platform detection and parsing (`ShiftPlatformRules`), variant choice (`ShiftVariantRules`), bookkeeping (`ShiftAnalyticsTracker`) and the optional-salvage attempt (`ShiftSalvageTracker`).

**Tech Stack:** Luau `--!strict`, Rojo, ByteNetMax (`uint8` packet), base AnalyticsServiceServer (`custom(player, event, value?, fields?)`: names trimmed to 50, up to three fields of ≤ 50 chars, never throws, **sends nothing in Studio**), RequestHandler (rate limit + validate), SignalTyped (SignalPlus, deferred), Observers (`observeTag`), TestEZ (Studio, `RunTests = true`).

**Spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (M5 row of §9, code parts only: "analytics, A/B switch"; §6.6 Analytics; §6.4 "The client-reported platform (for analytics) is accepted only from a fixed enum"; §4 Vacuum "Variant switch (A/B from the validation plan, rewards unchanged): B (default) some salvage spawns hidden under piles; A all salvage spawns exposed"; §1 the validation question). Builds on M1 (`docs/superpowers/plans/2026-10-10-m1-cleanup-crew-graybox.md` + `.superpowers/sdd/2026-10-10-m1-cleanup-crew-graybox/amendments.md`), M2 (`docs/superpowers/plans/2026-10-10-m2-cleanup-crew-harlow.md`), M4 (`overnight-handoff/2026-10-10-m4-cleanup-crew-depot.md`) and M3 (`overnight-handoff/2026-10-10-m3-cleanup-crew-feel.md`); their Interfaces blocks are treated as the real API.

**Branch / PR:** same branch `game/cleanup-crew`, after M3's commits; same PR #3 (no new PR: the controller updates its description in Task 10; never merge). **The phone pass on a real device, publishing and the sibling session are the developer's and are not tasks here**; Task 10 writes a checklist doc for them.

**Roblox analytics facts this plan relies on** (verified 2026-10-10 against create.roblox.com/docs/production/analytics/custom-events and the AnalyticsService reference): `LogCustomEvent(player, eventName, value = 1, customFields?)`; server-only and **published games only (never from Studio)**; up to **100** custom event names per experience; **three** custom fields, shown as breakdowns; custom fields have a cardinality limit (no number published), so field values must stay low-cardinality; events aggregate daily (up to 24 h before charts fill).

## Global Constraints

- `--!strict` everywhere except `*.spec.luau`. No `any`, no `::` casts without a commented justification and developer sign-off (none are planned).
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields, callers use colon syntax).
- Every new first-party module has a `<Name>.spec.luau` sibling or an `EXEMPT_MODULES` entry with a reason (`src/ServerScriptService/Core/Testing/SpecRoots.luau`). `*.story` files need neither.
- Module names `<Feature><What><RoleWord>` in an allowed subfolder; UI tree modules PascalCase (`ViewModel` suffix for view models, `use<Thing>` hooks). Requires use full addresses; a feature folder required from 3+ times in one file gets a `<Feature><Realm>` variable.
- ≤ 400 code lines per module (`scripts/python/check_file_length.py`; comments and blanks do not count).
- After adding/moving modules: `python3 scripts/python/module_map.py --write`.
- Commits: plain messages, **no `Co-Authored-By:` / `Claude-Session:` trailers** (AGENTS.md; `check_pr_rules` rejects them).
- **Rojo safety:** the developer may be connected to `rojo serve`. Implementers never run `rokit install`, `wally install`, `install.sh`, `wally-package-types` or `scripts/check.sh` (with or without `--skip-install`), and never start `rojo serve`; the per-task gate is `bash .superpowers/sdd/gate.sh` (lint, format, typecheck, rules, file length, module map). Tests run only in Studio, by the controller: steps saying "controller: Studio TestEZ" set the Workspace attribute `RunTests = true`, Play, read Output; gameplay checks run in a fresh Play with `RunTests = false` and use a temporary server `Script` / client `LocalScript` the controller injects (the plugin VM cannot reach live services). Only a solo player is available (no second client). **AnalyticsService sends nothing in Studio** (AnalyticsServiceServer logs "(studio, not sent)" and counts `skipped`), so Studio checks read `ShiftAnalyticsSystem.listen` / `recent()` (the test sink) and the server log.
- **Module-map and commit order (every task):** `git add src` → `python3 scripts/python/module_map.py --write` → `git add docs/project-structure.md` → `stylua <each new or edited .luau file>` (re-`git add` them) → `bash .superpowers/sdd/gate.sh` → `git commit -m "<message as given>"` → `python3 scripts/python/module_map.py --check` (must print no FAIL). Never run `stylua src` wholesale.
- Server-authoritative: clients only send requests (the platform report is the only new one, accepted from a fixed enum, first report wins); the server decides every event. React components never send packets.
- **Analytics rules (spec §6.6, verbatim intent):** events exactly `contract_started`, `first_cleanup_started`, `pile_cleared`, `cargo_picked_up`, `cargo_dropped`, `cargo_banked`, `noise_investigation`, `chase_started`, `player_caught`, `quota_met`, `optional_salvage_attempted`, `shift_ended`, `replay_started`; fields session (server JobId), build version, variant, platform, party size, target/object, outcome, failure reason; **no personal data, no chat** (no names, no UserIds, no free text in any field or log record).
- **Variant rules (spec §4):** B (default) some salvage hidden under piles; A all salvage exposed; **rewards unchanged** (no value, multiplier, quota or count may depend on the variant).
- Avoid M3's lines: M3 edited `ShiftConstants` (toast styles), `CargoConstants`/`CargoTypes`/`CargoServiceServer` (feel), `ShiftBankingSystem`'s tail (returns the credited bonus, toast removed). M5 edits are anchored on other lines; where a file is shared, insert, never rewrite M3's text.
- Spec numbers carried (tuning hypotheses, unchanged by M5): quota 350 clearance (trash only); shift 7:00; clock-out 10 s; break 30 s → warning 30 s → overtime (salvage ×1.5); pockets 2 tiny; `OfficeConstants.HIDE_CHANCE = 0.35` (variant B).

## Review Focus

1. **A player name, chat line, UserId or any free text reaching an analytics field or the log record** → impossible: every target/outcome/reason is a vocabulary token or becomes `"other"`. (Task 1 `ShiftAnalyticsUtils` spec "turns a player name, a chat line or a user id into other" and "checks each part of a compound token".)
2. **A spoofed or repeated platform report** (code 0, 9, 2.5, NaN, a string, a second report claiming another device) → the first valid report stands; anything else is dropped and the player stays `"unknown"`. (Task 2 `ShiftPlatformRules` spec "parses only the four reportable codes"; Task 3 `ShiftAnalyticsTracker` spec "keeps the first valid platform report"; Task 7 Step 9 checklist item 3.)
3. **One salvage item that is picked up after the quota, pocketed, taken out again, dropped to escape, picked up again and banked** → one attempt closed `failed:dropped`, a second attempt closed `banked`; the pocket round-trip never opens a duplicate. (Task 4 `ShiftSalvageTracker` spec "re-keys a player's open attempt when the same kind comes back into their hands", "counts a second go after a failed attempt"; Task 8 Step 12 checklist item 5.)
4. **A player caught by Harlow (or leaving) with after-quota salvage in hand and in a pocket** → each attempt closes exactly once as `failed:caught` / `failed:left`, even though both Death and Carry report it. (Task 4 spec "closes a player's attempts once, whoever reports it first"; Task 9 Step 8 checklist item 4.)
5. **The variant switch changes rewards, or a developer override is left on in a published place** → the same seed offers the same salvage in A and B (only where it sits differs); an override is logged at every shift start and reported as `contract_started` target `override`. (Task 5 `OfficeSpawnUtils` spec "offers the same salvage for the same seed in both variants"; Task 5 `ShiftVariantRules` spec "uses the Workspace override over everything"; Task 7 Step 9 checklist item 4; Task 10's developer checklist.)

---

## Decisions (argued from the spec and the code)

**The variant (spec §4 "B (default)"; §1 the question needs both arms).** Picked on the server at each run start by `ShiftVariantRules.pick`, in this order:
1. **Developer override:** the Workspace attribute `CleanupCrewVariant` = `"A"` or `"B"` (any case, spaces trimmed) wins; anything else is ignored. Read at every run start, so setting it from the server command bar takes effect at the next shift. Source `"override"`.
2. **`ShiftConstants.VARIANT_MODE = "fixed"`** → always `ShiftConstants.VARIANT` (B). Source `"fixed"`.
3. **`VARIANT_MODE = "alternate"` (the default in this plan)** → the server's first shift plays a start variant, then each Another shift flips it. The start is B in Studio (empty JobId: B is the default) and, on live servers, `djb2(JobId) % 2` (even → B, odd → A) so servers counterbalance the order. Source `"alternate"`.

*Why alternate per shift:* the sibling session is one crew of three in one server; alternating gives the **same players both arms** (a within-subject comparison, the only kind three players can support), deterministic from the JobId and the shift number, and logged (`shift N: variant X (source), session …, build …` at info, plus field 1 of every event and `contract_started`'s target). *Why rewards cannot change:* the variant reaches only `OfficeSpawnUtils.roll`'s hide decision; Task 5 makes A and B draw the random stream identically so the same seed offers the same salvage, and its spec pins it. Value, multiplier and quota code never read the variant (Task 5 Step 7 greps it).

**Fields (spec §6.6 lists eight; the engine takes three).** Field 1 = context `"variant|platform|party|build"` (e.g. `B|phone|3|m5-v42`: at most 2 × 5 × 100 × builds values, low cardinality); field 2 = target/object; field 3 = outcome, or `"outcome:reason"` when there is a failure reason. **The session (JobId) is not an engine field** (one value per server would grow without bound against the unpublished cardinality limit); it is in every full record in the server log and the recent ring. Build = `ShiftAnalyticsConstants.BUILD_LABEL .. "-v" .. game.PlaceVersion` (`m5-dev` in Studio), so every publish is told apart automatically. The event's `value` carries the one number that matters per event.

**Scope.** Player events go to that player. Crew events (`contract_started`, `quota_met`, `noise_investigation`, `replay_started`) go once **to each crew member** (Round participants still in the server): Roblox analytics are player-centric (funnels and per-user rates), and each member did experience it. Divide crew-event counts by party size for per-shift counts.

**`optional_salvage_attempted` (spec §1: "do players voluntarily go back for optional salvage after the quota?").** An **attempt opens** when, during a running shift with the quota met and no clock-out countdown, a player picks up a **salvage** item while **outside the loading bay** (M2's `OfficeServiceServer:safeZone()`): they went back into the office for greed after the job was done. One open attempt per item; a player whose same-kind item comes back into their hands (unpocket, swap, picking up their own scattered item) keeps their attempt (re-keyed), so pockets never duplicate one. An **attempt closes** exactly once: `banked` (that player loads that kind), or failed with a reason: `dropped`, `thrown`, `caught` (Harlow; a death drop or the catch itself, whichever arrives first), `left` (they left the server), `unbanked` (still open when the shift ended: lost at clock out or timeout). The event is sent **when the attempt closes**: target `kind:source`, outcome `banked` or `failed:<reason>`, value = seconds from quota met to the pick-up. `shift_ended` carries each player's attempt count as its value, so "did this player go back this shift" is one breakdown.

**"Does cleaning improve that decision?"** Answerable three ways: (1) compare the attempt rate between variants (field 1: B hides salvage under piles, so cleaning uncovers it; A shows it all); (2) every cargo event's target carries the item's **source** (`open`, `pile` = uncovered by vacuuming, `desk` = searched, `scatter` = dropped from a caught player's pockets), so attempts on cleaning-revealed salvage are counted directly; (3) `shift_ended`'s target is the player's cleaning bucket (`piles_0`, `piles_1_2`, `piles_3_5`, `piles_6_plus`) against their attempt count.

**`replay_started`** = a run after the first on the same server starts, i.e. an **Another shift** (M4 sends Back-to-depot crews home and the server closes when empty, so a second run on a live shift server is always an Another shift). Crews that go back to the depot and queue again are not counted as replays (open question 5).

### The event dictionary

Field 1 is always `variant|platform|party|build`. "Crew" = each crew member. "s" = seconds since the shift started (`ShiftState.startedAt`). `quota` = `before_quota` / `after_quota`.

| Event | Fires when (server) | Sent to | value | Field 2: target | Field 3: outcome[:reason] |
|---|---|---|---|---|---|
| `contract_started` | a run starts | crew | shift number on this server | variant source: `alternate` / `fixed` / `override` | `first` / `replay` |
| `first_cleanup_started` | a player starts vacuuming for the first time this shift | that player | s | pile kind (`paper`, `debris`, `cables`) | quota |
| `pile_cleared` | a pile is cleared | each player on it | s | pile kind | `solo` / `shared` |
| `cargo_picked_up` | a cargo item comes into a player's hands | that player | the item's value now | `kind:source` | quota |
| `cargo_dropped` | an item leaves the hands by drop, throw, catch or leaving | that player | the item's value | `kind:source` | `dropped` / `thrown` / `caught` / `left` |
| `cargo_banked` | each item in a Load | the loader | value credited (salvage ×1.5 in overtime) | kind | quota (before this Load) |
| `noise_investigation` | Harlow starts investigating | crew | s | the noise he most likely heard: `vacuum` / `drop` / `search` / `rattle` / `unknown` | quota |
| `chase_started` | Harlow starts chasing a player (or switches to another) | the chased player | s | what they hold: a kind or `empty` | quota |
| `player_caught` | Harlow's catch kills a player | that player | s | `harlow` | quota |
| `quota_met` | the clearance reaches the quota | crew | s | `clearance` | `met` |
| `optional_salvage_attempted` | an attempt closes (see above) | the attempter | s from quota met to the pick-up | `kind:source` | `banked` / `failed:dropped|thrown|caught|left|unbanked` |
| `shift_ended` | the run ends | each crew member | that player's attempts this shift | their cleaning bucket | `clockout|timeout|abandoned|cancelled|reset` `:quota_met|quota_missed` |
| `replay_started` | a run after the server's first starts (Another shift) | crew | shift number | `another_shift` | `same_server` |

Gameplay events count only while the shift is running; `shift_ended` and attempt closes also run as the run ends.

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Shift | server | Data | ShiftAnalyticsConstants | The 13 event names, the token vocabulary, limits, the build label |
| Shift | server | Utils | ShiftAnalyticsUtils | Event payloads: whitelist, tokens, packed fields, records, and the watch's small decisions |
| Shift | shared | Rules | ShiftPlatformRules | Detects the client's platform; the fixed enum the server accepts |
| Shift | server | State | ShiftAnalyticsTracker | Platforms, first cleanups, piles per player, quota time, recent noises and records |
| Shift | server | State | ShiftSalvageTracker | Optional-salvage attempts: open, re-key, close once, count |
| Shift | server | Rules | ShiftVariantRules | Picks each shift's variant (override, fixed, alternate from the JobId) |
| Shift | server | Net | ShiftVoteReceiver | Takes in and checks the results vote (moved out of the service for line room) |
| Shift | server | Systems | ShiftAnalyticsSystem | The one door to AnalyticsService: context, emit, platform intake, variant pick, banking events |
| Shift | server | Systems | ShiftAnalyticsWatchSystem | Turns the features' signals into analytics events |

9 new modules, all in the existing Shift feature. **No new subfolder kind, no new role word, no second service** (Shift's server realm gains `Data/` and `Net/` folders and its shared realm a `Rules/` folder: existing kinds). Modified: Shift (`ShiftTypes`, `ShiftConstants`, `ShiftEvents`, `ShiftServiceServer`, `ShiftServiceClient`, `ShiftBankingSystem`), Office (`OfficeSpawnUtils` + spec), Vacuum (`VacuumServiceServer`), Cargo (`CargoConstants`, `CargoTypes`, `CargoSpawnSystem`, one call in `CargoServiceServer`, one call in `CargoPocketSystem`), `SpecRoots` (exemptions), `docs/project-structure.md` (module map), `docs/ROADMAP.md`. Created docs: `docs/cleanup-crew-m5-checklist.md` (event dictionary + the developer's phone/publish/sibling checklist), `docs/superpowers/plans/2026-10-10-m5-cleanup-crew-analytics.md` (a copy of this plan).

## Open questions for the developer

Designed around; none blocks M5. No approval-gated layout change is needed.

1. **Variant default = alternate per shift** (Studio and even-hash servers start on B, then flip each Another shift). If you would rather every shift play B unless overridden, set `ShiftConstants.VARIANT_MODE = "fixed"` (one data edit). The override attribute `CleanupCrewVariant` lives on Workspace, which Rojo does not manage: **if you save it in a place, it ships** (Task 10's checklist says to remove it before publishing; every shift logs it).
2. **The session id stays out of the engine's three custom fields** (cardinality) and is in the server log record instead (F9 → Server log, `[ShiftAnalyticsSystem]` lines). Field 1 packs variant, platform, party and build.
3. **Crew events go to each crew member** (counts scale with party size). The alternative, one event per crew against one member, breaks per-player funnels.
4. **The optional-salvage definition** above (after quota, outside the loading bay, not during the clock-out countdown, sent when it closes). Pick-ups inside the bay and during the countdown are not "going back".
5. **`replay_started` covers Another shift only.** A crew that rides back to the depot and departs again plays its next shift on a new server and logs `contract_started … first`. Counting that as a replay needs the depot to pass "returning" in the teleport data (M4's result-card path): a later change.
6. **`noise_investigation`'s source is inferred:** the newest noise within 2 s whose heard radius reached Harlow (Occupant does not publish what he heard). A precise source needs an Occupant signal.
7. **Per-item bank values** round each salvage item (×1.5) separately; the shift's bonus total rounds the whole Load once, so per-item sums can differ by 1 from the review's bonus.
8. **`BUILD_LABEL = "m5"`** is a manual label; the PlaceVersion suffix changes on every publish by itself.

## Spec gaps found (and how this plan fills them)

- §6.6 lists eight fields; the engine takes three custom fields with a cardinality limit → field 1 packs the context, session goes to the log (Decisions).
- §6.6 does not say whether crew-wide events are per player or per crew → per crew member (Decisions).
- §6.6 names `optional_salvage_attempted` but never defines it, and §1's "does cleaning improve that decision" has no metric → the definition, item sources and cleaning buckets above.
- §4 says "B (default)" but the validation plan needs both arms, and is silent on how the server picks → alternate per shift with a JobId start, a fixed mode and a Workspace override.
- §4 "rewards unchanged" was not guaranteed by M1's spawn roll (variant A consumed fewer random numbers, so the same seed offered different salvage) → fixed and specced in Task 5.
- §6.4's "fixed enum" lists no values → `pc`, `phone`, `tablet`, `console` (console is out of scope for play, §10, but harmless to report).

---

### Task 0: Preflight

**Files:** Create: `docs/superpowers/plans/2026-10-10-m5-cleanup-crew-analytics.md` (a copy of this plan).

- [ ] **Step 1: Confirm the branch and that M2, M4 and M3 landed**

```bash
git branch --show-current
git log --oneline -60
```
Expected: `game/cleanup-crew`; the log contains M2's "docs: record Cleanup Crew M2 on the roadmap", M4's last commit and M3's "docs: record Cleanup Crew M3 feel on the roadmap". If any is missing, stop and tell the controller (M5 runs after all three).

- [ ] **Step 2: Confirm every API this plan edits or calls** (each grep prints at least one line; if one prints nothing, stop and report which):

```bash
# Shift (M1/M2/M4/M3)
grep -n "changed = changed" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "local function onRoundPhase" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "local onVote = RequestHandler.wrap" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "ShiftEvents.packets.Vote.listen" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "CargoServiceServer:onBanked(onBanked)" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n 'guarded("banking follow-up", deps.afterBank)' src/ServerScriptService/Features/Shift/Systems/ShiftBankingSystem.luau
grep -n "export type Variant = " src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau
grep -n "VARIANT = VARIANT," src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau
grep -n "startedAt" src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau
# Office (M1 roll, M2 safe zone)
grep -n 'local hideable = options.variant == "B"' src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau
grep -n "safeZone = function" src/ServerScriptService/Features/Office/OfficeServiceServer.luau
# Vacuum, Carry, Cargo
grep -n "return CarryServiceServer:getCarried(player) == nil" src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau
grep -n "pickedUp = pickedUp\|dropped = dropped\|getCarried = function" src/ServerScriptService/Features/Carry/CarryServiceServer.luau
grep -n "spawner:spawn(kind, front, parent)" src/ServerScriptService/Features/Cargo/CargoServiceServer.luau
grep -n "{ value = entry.value }" src/ServerScriptService/Features/Cargo/Systems/CargoPocketSystem.luau
grep -n "part:SetAttribute(CargoConstants.IMPACTS_ATTRIBUTE, 0)" src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau
grep -n "HIDDEN_ATTRIBUTE = " src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau
grep -n "value: number?," src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau
# Death, Noise, Occupant (M2)
grep -n "died = died" src/ServerScriptService/Features/Death/DeathServiceServer.luau
grep -n "made = made\|getHearingScale = function" src/ServerScriptService/Features/Noise/NoiseServiceServer.luau
grep -n "export type NoiseEvent" src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseTypes.luau
grep -n 'TAG = "Occupant"\|MODE_ATTRIBUTE = \|TARGET_ATTRIBUTE = ' src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau
grep -rn 'kill(humanoid, "caught"' src/ServerScriptService/Features/Occupant
grep -n "OccupantRigSystem.setMode\|SetAttribute(OccupantConstants.MODE_ATTRIBUTE" -r src/ServerScriptService/Features/Occupant
# Base analytics
grep -n "custom = function" src/ServerScriptService/Features/Analytics/AnalyticsServiceServer.luau
```

- [ ] **Step 3: Confirm no require cycle can form** (the watch requires Noise, Office, Death, Carry and Vacuum; none may require Shift or Occupant):

```bash
grep -rln "ShiftServiceServer\|OccupantServiceServer" src/ServerScriptService/Features/Noise src/ServerScriptService/Features/Office src/ServerScriptService/Features/Death src/ServerScriptService/Features/Carry src/ServerScriptService/Features/Vacuum src/ServerScriptService/Features/Round src/ServerScriptService/Features/Analytics
```
Expected: no output. If a file is listed, stop and report it.

- [ ] **Step 4: Record the code-line counts of the two capped services**

```bash
python3 -c "import sys; sys.path.insert(0,'scripts/python'); import check_file_length as c; [print(p, c.count_code_lines(open(p,encoding='utf8').read())) for p in ('src/ServerScriptService/Features/Shift/ShiftServiceServer.luau','src/ServerScriptService/Features/Cargo/CargoServiceServer.luau','src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau')]"
```
Note the numbers in your report. Task 6 lowers Shift's by about 20 before Task 7 adds 6; Cargo's does not change (Task 8 edits one existing call).

- [ ] **Step 5: Copy this plan into the repo and run the baseline gate**

```bash
cp overnight-handoff/2026-10-10-m5-cleanup-crew-analytics.md docs/superpowers/plans/2026-10-10-m5-cleanup-crew-analytics.md
bash .superpowers/sdd/gate.sh
git add docs/superpowers/plans/2026-10-10-m5-cleanup-crew-analytics.md
git commit -m "docs: M5 Cleanup Crew analytics implementation plan"
```
Expected: `==> All checks passed.` before the commit. If the gate fails before any M5 change, stop and report: it is not ours.

---
### Task 1: Analytics payload rules (vocabulary, tokens, packed fields, records; pure)

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau` (three types)
- Create: `src/ServerScriptService/Features/Shift/Data/ShiftAnalyticsConstants.luau`
- Create: `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau`
- Test: `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.spec.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `CargoRegistry.ids() -> { string }` (13 ids: `rubbishBag`, `dustBag`, `recyclingBox`, `bottleBag`, `officePlant`, `plaque`, `monitor`, `waterJug`, `printer`, `coffeeMachine`, `fishTank`, `goldenStapler`, `filingCabinet`); `VacuumConstants.PILE_KIND_LIST` (`paper`, `debris`, `cables`); `ShiftTypes.Variant`.
- Produces (ShiftTypes): `VariantMode = "alternate" | "fixed"`, `VariantSource = "alternate" | "fixed" | "override"`, `Platform = "pc" | "phone" | "tablet" | "console" | "unknown"`.
- Produces (ShiftAnalyticsConstants): `EVENTS: { string }` (the 13), `EVENT_SET: { [string]: boolean }`, `VOCABULARY: { [string]: boolean }`, `INFO_EVENTS: { [string]: boolean }`, `BUILD_LABEL = "m5"`, `TOKEN_MAX = 40`, `VALUE_MAX = 100000`, `RECENT_LIMIT = 300`, `NOISE_LIMIT = 16`, `NOISE_MEMORY = 2`, `CATCH_CAUSE = "caught"`.
- Produces (ShiftAnalyticsUtils): types `Context = { session: string, build: string, variant: Variant, platform: Platform, party: number }`, `Details = { target: string?, outcome: string?, reason: string?, value: number? }`, `Record = { event, session, build, variant, platform: string, party: number, target, outcome, reason: string, value: number }`, `AttemptOutcome = "banked" | "dropped" | "thrown" | "caught" | "left" | "unbanked"`, `AttemptInput = { category: string, phase: string, sub: string, quotaMet: boolean, inBay: boolean }`, `Noise = { source: string, position: Vector3, radius: number, at: number }`, `Harlow = { mode: string, target: number }`; functions `isEvent(name) -> boolean`, `token(raw: string?) -> string`, `value(raw: number?) -> number`, `session(jobId) -> string`, `build(label, placeVersion) -> string`, `contextField(context) -> string`, `outcomeField(details) -> string`, `fields(context, details) -> { string }` (exactly 3), `record(event, context, details) -> Record`, `quotaTag(quotaMet: boolean) -> string`, `pileBucket(piles: number) -> string`, `dropOutcome(reason: string) -> AttemptOutcome?`, `isSalvageAttempt(input: AttemptInput) -> boolean`, `inBox(point, low, high: Vector3) -> boolean`, `credited(category: string, value: number, multiplier: number) -> number`, `harlowChange(before: Harlow?, after: Harlow) -> string?`, `heardSource(noises: { Noise }, listener: Vector3, scale: number, now: number) -> string`.

- [ ] **Step 1: Add the types.** In `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau`, directly after the line `export type Variant = "A" | "B"`, insert:

```lua

-- How each shift's variant is chosen (ShiftVariantRules): "alternate" flips A/B every shift from a per-server start;
-- "fixed" always plays ShiftConstants.VARIANT.
export type VariantMode = "alternate" | "fixed"

-- Where a shift's variant came from: the alternation, the fixed default, or the developer's Workspace override.
export type VariantSource = "alternate" | "fixed" | "override"

-- The device a client reports for analytics (ShiftPlatformRules accepts only pc/phone/tablet/console from a client);
-- "unknown" until a valid report arrives.
export type Platform = "pc" | "phone" | "tablet" | "console" | "unknown"
```

- [ ] **Step 2: Write the constants** `src/ServerScriptService/Features/Shift/Data/ShiftAnalyticsConstants.luau`:

```lua
--!strict
--[=[
	ShiftAnalyticsConstants: Cleanup Crew's analytics vocabulary (spec §6.6). The 13 event names are the only ones
	ShiftAnalyticsSystem sends. Every target, outcome and reason must be a VOCABULARY word (the fixed words below,
	cargo ids and pile kinds), or a ":"-joined pair of them, so nothing a player typed or is called can reach a field.
	Static data (spec-exempt).

	@class ShiftAnalyticsConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

-- Spec §6.6, verbatim.
local EVENTS: { string } = {
	"contract_started",
	"first_cleanup_started",
	"pile_cleared",
	"cargo_picked_up",
	"cargo_dropped",
	"cargo_banked",
	"noise_investigation",
	"chase_started",
	"player_caught",
	"quota_met",
	"optional_salvage_attempted",
	"shift_ended",
	"replay_started",
}

local WORDS: { string } = {
	-- Nothing, or something outside the vocabulary.
	"none",
	"other",
	"unknown",
	"empty",
	-- contract_started / replay_started.
	"alternate",
	"fixed",
	"override",
	"first",
	"replay",
	"another_shift",
	"same_server",
	-- Before or after the quota; quota_met.
	"before_quota",
	"after_quota",
	"clearance",
	"met",
	-- pile_cleared and the cleaning buckets.
	"solo",
	"shared",
	"piles_0",
	"piles_1_2",
	"piles_3_5",
	"piles_6_plus",
	-- Where a cargo item came from.
	"open",
	"pile",
	"desk",
	"scatter",
	-- Drops and optional-salvage outcomes.
	"dropped",
	"thrown",
	"caught",
	"left",
	"banked",
	"failed",
	"unbanked",
	-- Noise sources (Vacuum, Cargo).
	"vacuum",
	"drop",
	"search",
	"rattle",
	-- player_caught.
	"harlow",
	-- How a run ended (Round's outcomes, Shift's clock out and reset) and the quota.
	"clockout",
	"timeout",
	"abandoned",
	"wiped",
	"cancelled",
	"reset",
	"quota_met",
	"quota_missed",
}

local EVENT_SET: { [string]: boolean } = {}
for _, name in EVENTS do
	EVENT_SET[name] = true
end

local VOCABULARY: { [string]: boolean } = {}
for _, word in WORDS do
	VOCABULARY[word] = true
end
for _, id in CargoRegistry.ids() do
	VOCABULARY[id] = true
end
for _, kind in VacuumConstants.PILE_KIND_LIST do
	VOCABULARY[kind] = true
end

-- Logged at info (the rest at debug): the events that tell a session's story in the server log.
local INFO_EVENTS: { [string]: boolean } = {
	contract_started = true,
	quota_met = true,
	optional_salvage_attempted = true,
	player_caught = true,
	shift_ended = true,
	replay_started = true,
}

return table.freeze({
	EVENTS = table.freeze(EVENTS),
	EVENT_SET = table.freeze(EVENT_SET),
	VOCABULARY = table.freeze(VOCABULARY),
	INFO_EVENTS = table.freeze(INFO_EVENTS),
	-- The build label; the place version is appended ("m5-v42"; "m5-dev" in Studio).
	BUILD_LABEL = "m5",
	-- A longer target/outcome/reason is "other" (the engine caps a field at 50 characters).
	TOKEN_MAX = 40,
	-- Event values are clamped to 0..VALUE_MAX and rounded to 0.1.
	VALUE_MAX = 100000,
	-- How many records the in-server ring keeps (the Studio test sink and the developer read it).
	RECENT_LIMIT = 300,
	-- How many recent noises are kept, and for how long (seconds) one can explain an investigation.
	NOISE_LIMIT = 16,
	NOISE_MEMORY = 2,
	-- The Death cause Mr. Harlow's catch kills with (OccupantCatchSystem).
	CATCH_CAUSE = "caught",
})
```

- [ ] **Step 3: Write the failing spec** `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.spec.luau`:

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftAnalyticsUtils = require(script.Parent.ShiftAnalyticsUtils)
local ShiftAnalyticsConstants = require(ServerScriptService.Features.Shift.Data.ShiftAnalyticsConstants)

local function context(overrides)
	local base = { session = "job-1", build = "m5-v12", variant = "B", platform = "phone", party = 3 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("isEvent", function()
		it("knows exactly the 13 spec events", function()
			expect(#ShiftAnalyticsConstants.EVENTS).to.equal(13)
			for _, name in ShiftAnalyticsConstants.EVENTS do
				expect(ShiftAnalyticsUtils.isEvent(name)).to.equal(true)
			end
		end)

		it("refuses anything else, including a different case", function()
			expect(ShiftAnalyticsUtils.isEvent("Contract_Started")).to.equal(false)
			expect(ShiftAnalyticsUtils.isEvent("chat")).to.equal(false)
			expect(ShiftAnalyticsUtils.isEvent("")).to.equal(false)
		end)
	end)

	describe("token", function()
		it("keeps fixed words, cargo ids and pile kinds", function()
			expect(ShiftAnalyticsUtils.token("after_quota")).to.equal("after_quota")
			expect(ShiftAnalyticsUtils.token("fishTank")).to.equal("fishTank")
			expect(ShiftAnalyticsUtils.token("cables")).to.equal("cables")
		end)

		it("keeps a compound token whose parts are all known", function()
			expect(ShiftAnalyticsUtils.token("fishTank:pile")).to.equal("fishTank:pile")
			expect(ShiftAnalyticsUtils.token("failed:caught")).to.equal("failed:caught")
		end)

		it("turns a player name, a chat line or a user id into other", function()
			expect(ShiftAnalyticsUtils.token("Builderman")).to.equal("other")
			expect(ShiftAnalyticsUtils.token("lol harlow is so slow")).to.equal("other")
			expect(ShiftAnalyticsUtils.token("123456789")).to.equal("other")
		end)

		it("checks each part of a compound token", function()
			expect(ShiftAnalyticsUtils.token("fishTank:Builderman")).to.equal("other")
			expect(ShiftAnalyticsUtils.token("fishTank:")).to.equal("other")
		end)

		it("is none for nothing and other for an over-long string", function()
			expect(ShiftAnalyticsUtils.token(nil)).to.equal("none")
			expect(ShiftAnalyticsUtils.token("")).to.equal("none")
			expect(ShiftAnalyticsUtils.token(string.rep("pile:", 10) .. "pile")).to.equal("other")
		end)
	end)

	describe("value", function()
		it("clamps, rounds to a tenth and never returns NaN", function()
			expect(ShiftAnalyticsUtils.value(nil)).to.equal(0)
			expect(ShiftAnalyticsUtils.value(0 / 0)).to.equal(0)
			expect(ShiftAnalyticsUtils.value(-5)).to.equal(0)
			expect(ShiftAnalyticsUtils.value(math.huge)).to.equal(ShiftAnalyticsConstants.VALUE_MAX)
			expect(ShiftAnalyticsUtils.value(12.34)).to.equal(12.3)
			expect(ShiftAnalyticsUtils.value(38)).to.equal(38)
		end)
	end)

	describe("session and build", function()
		it("names Studio's empty JobId and keeps a live one", function()
			expect(ShiftAnalyticsUtils.session("")).to.equal("studio")
			expect(ShiftAnalyticsUtils.session("a1b2-c3")).to.equal("a1b2-c3")
		end)

		it("appends the place version, or dev when unpublished", function()
			expect(ShiftAnalyticsUtils.build("m5", 42)).to.equal("m5-v42")
			expect(ShiftAnalyticsUtils.build("m5", 0)).to.equal("m5-dev")
		end)
	end)

	describe("fields", function()
		it("packs the context into field 1, the target into 2 and the outcome into 3", function()
			local fields = ShiftAnalyticsUtils.fields(context(), { target = "plaque:pile", outcome = "banked" })
			expect(#fields).to.equal(3)
			expect(fields[1]).to.equal("B|phone|3|m5-v12")
			expect(fields[2]).to.equal("plaque:pile")
			expect(fields[3]).to.equal("banked")
		end)

		it("joins a failure reason to the outcome", function()
			local fields =
				ShiftAnalyticsUtils.fields(context(), { target = "plaque:open", outcome = "failed", reason = "caught" })
			expect(fields[3]).to.equal("failed:caught")
		end)

		it("keeps the session out of the engine fields", function()
			for _, field in ShiftAnalyticsUtils.fields(context(), { target = "harlow", outcome = "after_quota" }) do
				expect(string.find(field, "job-1", 1, true)).to.equal(nil)
			end
		end)

		it("clamps the party size and cleans every string", function()
			local fields = ShiftAnalyticsUtils.fields(context({ party = 150 }), { target = "Bob", outcome = "hi there" })
			expect(fields[1]).to.equal("B|phone|99|m5-v12")
			expect(fields[2]).to.equal("other")
			expect(fields[3]).to.equal("other")
		end)
	end)

	describe("record", function()
		it("carries every spec field, cleaned", function()
			local record =
				ShiftAnalyticsUtils.record("pile_cleared", context(), { target = "paper", outcome = "solo", value = 61.27 })
			expect(record.event).to.equal("pile_cleared")
			expect(record.session).to.equal("job-1")
			expect(record.build).to.equal("m5-v12")
			expect(record.variant).to.equal("B")
			expect(record.platform).to.equal("phone")
			expect(record.party).to.equal(3)
			expect(record.target).to.equal("paper")
			expect(record.outcome).to.equal("solo")
			expect(record.reason).to.equal("none")
			expect(record.value).to.equal(61.3)
		end)
	end)

	describe("small decisions", function()
		it("tags before and after the quota", function()
			expect(ShiftAnalyticsUtils.quotaTag(false)).to.equal("before_quota")
			expect(ShiftAnalyticsUtils.quotaTag(true)).to.equal("after_quota")
		end)

		it("buckets the piles a player cleared", function()
			expect(ShiftAnalyticsUtils.pileBucket(0)).to.equal("piles_0")
			expect(ShiftAnalyticsUtils.pileBucket(1)).to.equal("piles_1_2")
			expect(ShiftAnalyticsUtils.pileBucket(2)).to.equal("piles_1_2")
			expect(ShiftAnalyticsUtils.pileBucket(3)).to.equal("piles_3_5")
			expect(ShiftAnalyticsUtils.pileBucket(5)).to.equal("piles_3_5")
			expect(ShiftAnalyticsUtils.pileBucket(6)).to.equal("piles_6_plus")
			expect(ShiftAnalyticsUtils.pileBucket(40)).to.equal("piles_6_plus")
		end)

		it("reads Carry's drop reasons, ignoring pocketing, banking and resets", function()
			expect(ShiftAnalyticsUtils.dropOutcome("drop")).to.equal("dropped")
			expect(ShiftAnalyticsUtils.dropOutcome("throw")).to.equal("thrown")
			expect(ShiftAnalyticsUtils.dropOutcome("death")).to.equal("caught")
			expect(ShiftAnalyticsUtils.dropOutcome("removed")).to.equal("left")
			expect(ShiftAnalyticsUtils.dropOutcome("forced")).to.equal(nil)
			expect(ShiftAnalyticsUtils.dropOutcome("destroyed")).to.equal(nil)
		end)

		it("counts an after-quota salvage pick-up outside the bay as an attempt", function()
			local base = { category = "salvage", phase = "running", sub = "normal", quotaMet = true, inBay = false }
			expect(ShiftAnalyticsUtils.isSalvageAttempt(base)).to.equal(true)
			local function with(key, value)
				local copy = table.clone(base)
				copy[key] = value
				return ShiftAnalyticsUtils.isSalvageAttempt(copy)
			end
			expect(with("category", "trash")).to.equal(false)
			expect(with("phase", "results")).to.equal(false)
			expect(with("sub", "clockout")).to.equal(false)
			expect(with("quotaMet", false)).to.equal(false)
			expect(with("inBay", true)).to.equal(false)
		end)

		it("tests a point against a box, edges included", function()
			local low, high = Vector3.new(0, 0, 0), Vector3.new(10, 10, 10)
			expect(ShiftAnalyticsUtils.inBox(Vector3.new(5, 5, 5), low, high)).to.equal(true)
			expect(ShiftAnalyticsUtils.inBox(Vector3.new(10, 0, 10), low, high)).to.equal(true)
			expect(ShiftAnalyticsUtils.inBox(Vector3.new(11, 5, 5), low, high)).to.equal(false)
			expect(ShiftAnalyticsUtils.inBox(Vector3.new(5, -1, 5), low, high)).to.equal(false)
		end)

		it("credits salvage times the multiplier, rounded like the review, and trash as is", function()
			expect(ShiftAnalyticsUtils.credited("salvage", 25, 1.5)).to.equal(38)
			expect(ShiftAnalyticsUtils.credited("salvage", 70, 1)).to.equal(70)
			expect(ShiftAnalyticsUtils.credited("trash", 15, 1.5)).to.equal(15)
		end)
	end)

	describe("harlowChange", function()
		local function change(beforeMode, beforeTarget, afterMode, afterTarget)
			local before = if beforeMode ~= nil then { mode = beforeMode, target = beforeTarget } else nil
			return ShiftAnalyticsUtils.harlowChange(before, { mode = afterMode, target = afterTarget })
		end

		it("reports the start of an investigation once", function()
			expect(change(nil, 0, "investigate", 0)).to.equal("noise_investigation")
			expect(change("patrol", 0, "investigate", 0)).to.equal("noise_investigation")
			expect(change("investigate", 0, "investigate", 0)).to.equal(nil)
		end)

		it("reports a chase start and a switch to another player, not a continuing chase", function()
			expect(change("patrol", 0, "chase", 7)).to.equal("chase_started")
			expect(change("chase", 7, "chase", 9)).to.equal("chase_started")
			expect(change("chase", 7, "chase", 7)).to.equal(nil)
		end)

		it("ignores a chase with no target and every other mode", function()
			expect(change("patrol", 0, "chase", 0)).to.equal(nil)
			expect(change("chase", 7, "search", 0)).to.equal(nil)
			expect(change("search", 0, "catch", 0)).to.equal(nil)
		end)
	end)

	describe("heardSource", function()
		local HARLOW = Vector3.new(0, 0, 0)

		it("picks the newest recent noise that reached him", function()
			local noises = {
				{ source = "vacuum", position = Vector3.new(30, 0, 0), radius = 40, at = 99 },
				{ source = "drop", position = Vector3.new(10, 0, 0), radius = 14, at = 99.5 },
			}
			expect(ShiftAnalyticsUtils.heardSource(noises, HARLOW, 1, 100)).to.equal("drop")
		end)

		it("skips a noise that did not reach him, scaled by his hearing", function()
			local noises = { { source = "search", position = Vector3.new(14, 0, 0), radius = 12, at = 100 } }
			expect(ShiftAnalyticsUtils.heardSource(noises, HARLOW, 1, 100)).to.equal("unknown")
			expect(ShiftAnalyticsUtils.heardSource(noises, HARLOW, 1.2, 100)).to.equal("search")
		end)

		it("forgets noises older than the memory", function()
			local noises = { { source = "vacuum", position = HARLOW, radius = 40, at = 90 } }
			local late = 90 + ShiftAnalyticsConstants.NOISE_MEMORY + 0.1
			expect(ShiftAnalyticsUtils.heardSource(noises, HARLOW, 1, late)).to.equal("unknown")
			expect(ShiftAnalyticsUtils.heardSource({}, HARLOW, 1, 100)).to.equal("unknown")
		end)
	end)
end
```

- [ ] **Step 4: Controller: Studio TestEZ.** Expected: FAIL — `ShiftAnalyticsUtils is not a valid member of Folder "Utils"` (module missing).

- [ ] **Step 5: Write the module** `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau`:

```lua
--!strict
--[=[
	ShiftAnalyticsUtils: Cleanup Crew's analytics payloads (spec §6.6), pure. An event is one of the 13 names; its
	target, outcome and reason are tokens from ShiftAnalyticsConstants.VOCABULARY (anything else becomes "other", so
	no player name, chat line or id can reach a field); its value is a clamped, finite number. The engine takes three
	custom fields, so:
	- field 1 packs the context "variant|platform|party|build" (low cardinality),
	- field 2 is the target (a cargo kind, "kind:source", a pile kind, a noise source, a fixed word),
	- field 3 is the outcome, or "outcome:reason" when there is a failure reason.
	The full record (with the session id, which stays out of the engine fields) goes to the server log.

	Also the small decisions the watch needs: before or after the quota, the cleaning bucket, what a Carry drop reason
	means, whether a pick-up opens an optional-salvage attempt, which Harlow mode change is an event, and which noise
	he most likely heard.

	@class ShiftAnalyticsUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftAnalyticsConstants = require(ServerScriptService.Features.Shift.Data.ShiftAnalyticsConstants)

-- Which session, build, variant, device and crew size an event belongs to.
export type Context = {
	session: string,
	build: string,
	variant: ShiftTypes.Variant,
	platform: ShiftTypes.Platform,
	party: number,
}

-- What a caller says about one event; every string is checked against the vocabulary.
export type Details = {
	target: string?,
	outcome: string?,
	reason: string?,
	value: number?,
}

-- One event as sent: the spec §6.6 fields, all cleaned.
export type Record = {
	event: string,
	session: string,
	build: string,
	variant: string,
	platform: string,
	party: number,
	target: string,
	outcome: string,
	reason: string,
	value: number,
}

-- How an optional-salvage attempt ended.
export type AttemptOutcome = "banked" | "dropped" | "thrown" | "caught" | "left" | "unbanked"

-- What the watch knows when a cargo item is picked up.
export type AttemptInput = {
	category: string,
	phase: string,
	sub: string,
	quotaMet: boolean,
	inBay: boolean,
}

-- One noise anyone could hear (Noise `made`); `at` is os.clock().
export type Noise = {
	source: string,
	position: Vector3,
	radius: number,
	at: number,
}

-- Mr. Harlow's published mode and target (OccupantConstants.MODE_ATTRIBUTE / TARGET_ATTRIBUTE; 0 = nobody).
export type Harlow = {
	mode: string,
	target: number,
}

-- Carry's drop reasons that end an attempt ("forced" is pocketing or banking, "destroyed" a reset). Only Mr. Harlow
-- kills in this game, so a death drop is a catch.
local DROP_OUTCOMES: { [string]: AttemptOutcome } = {
	drop = "dropped",
	throw = "thrown",
	death = "caught",
	removed = "left",
}

local MAX_PARTY = 99

local ShiftAnalyticsUtils = {}

function ShiftAnalyticsUtils.isEvent(name: string): boolean
	return ShiftAnalyticsConstants.EVENT_SET[name] == true
end

--[=[
	A vocabulary word, or ":"-joined words, unchanged; "none" for nothing; "other" for anything else.
]=]
function ShiftAnalyticsUtils.token(raw: string?): string
	if raw == nil or raw == "" then
		return "none"
	end
	if #raw > ShiftAnalyticsConstants.TOKEN_MAX then
		return "other"
	end
	for _, part in string.split(raw, ":") do
		if ShiftAnalyticsConstants.VOCABULARY[part] ~= true then
			return "other"
		end
	end
	return raw
end

--[=[
	A finite value in 0..VALUE_MAX, rounded to a tenth (nil and NaN read 0).
]=]
function ShiftAnalyticsUtils.value(raw: number?): number
	if raw == nil or raw ~= raw then
		return 0
	end
	local clamped = math.clamp(raw, 0, ShiftAnalyticsConstants.VALUE_MAX)
	return math.floor(clamped * 10 + 0.5) / 10
end

function ShiftAnalyticsUtils.session(jobId: string): string
	return if jobId == "" then "studio" else jobId
end

function ShiftAnalyticsUtils.build(label: string, placeVersion: number): string
	return if placeVersion > 0 then `{label}-v{placeVersion}` else `{label}-dev`
end

local function partySize(count: number): number
	if count ~= count then
		return 0
	end
	return math.clamp(math.floor(count), 0, MAX_PARTY)
end

function ShiftAnalyticsUtils.contextField(context: Context): string
	return `{context.variant}|{context.platform}|{partySize(context.party)}|{context.build}`
end

function ShiftAnalyticsUtils.outcomeField(details: Details): string
	local outcome = ShiftAnalyticsUtils.token(details.outcome)
	local reason = details.reason
	if reason == nil then
		return outcome
	end
	return `{outcome}:{ShiftAnalyticsUtils.token(reason)}`
end

--[=[
	The three engine custom fields: context, target, outcome[:reason].
]=]
function ShiftAnalyticsUtils.fields(context: Context, details: Details): { string }
	return {
		ShiftAnalyticsUtils.contextField(context),
		ShiftAnalyticsUtils.token(details.target),
		ShiftAnalyticsUtils.outcomeField(details),
	}
end

--[=[
	The full record (every spec §6.6 field), for the log and the recent ring.
]=]
function ShiftAnalyticsUtils.record(event: string, context: Context, details: Details): Record
	local reason = details.reason
	return {
		event = event,
		session = context.session,
		build = context.build,
		variant = context.variant,
		platform = context.platform,
		party = partySize(context.party),
		target = ShiftAnalyticsUtils.token(details.target),
		outcome = ShiftAnalyticsUtils.token(details.outcome),
		reason = if reason ~= nil then ShiftAnalyticsUtils.token(reason) else "none",
		value = ShiftAnalyticsUtils.value(details.value),
	}
end

function ShiftAnalyticsUtils.quotaTag(quotaMet: boolean): string
	return if quotaMet then "after_quota" else "before_quota"
end

--[=[
	A player's cleaning this shift, bucketed for shift_ended.
]=]
function ShiftAnalyticsUtils.pileBucket(piles: number): string
	if piles <= 0 then
		return "piles_0"
	elseif piles <= 2 then
		return "piles_1_2"
	elseif piles <= 5 then
		return "piles_3_5"
	end
	return "piles_6_plus"
end

function ShiftAnalyticsUtils.dropOutcome(reason: string): AttemptOutcome?
	return DROP_OUTCOMES[reason]
end

--[=[
	A salvage pick-up during a running shift, after the quota, outside the clock-out countdown and outside the loading
	bay: the player went back into the office for optional salvage.
]=]
function ShiftAnalyticsUtils.isSalvageAttempt(input: AttemptInput): boolean
	return input.category == "salvage"
		and input.phase == "running"
		and input.sub ~= "clockout"
		and input.quotaMet
		and not input.inBay
end

function ShiftAnalyticsUtils.inBox(point: Vector3, low: Vector3, high: Vector3): boolean
	return point.X >= low.X
		and point.X <= high.X
		and point.Y >= low.Y
		and point.Y <= high.Y
		and point.Z >= low.Z
		and point.Z <= high.Z
end

--[=[
	What one banked item was worth: salvage times the multiplier (rounded like the review), trash as is.
]=]
function ShiftAnalyticsUtils.credited(category: string, value: number, multiplier: number): number
	if category == "salvage" then
		return math.floor(value * multiplier + 0.5)
	end
	return value
end

--[=[
	"noise_investigation" when he starts investigating, "chase_started" when he starts chasing someone (or switches to
	someone else); nil otherwise.
]=]
function ShiftAnalyticsUtils.harlowChange(before: Harlow?, after: Harlow): string?
	local wasMode = if before ~= nil then before.mode else nil
	local wasTarget = if before ~= nil then before.target else 0
	if after.mode == "investigate" and wasMode ~= "investigate" then
		return "noise_investigation"
	end
	if after.mode == "chase" and after.target ~= 0 and (wasMode ~= "chase" or wasTarget ~= after.target) then
		return "chase_started"
	end
	return nil
end

--[=[
	The source of the newest noise within NOISE_MEMORY seconds whose heard radius (radius × scale) reached `listener`;
	"unknown" when none did.
]=]
function ShiftAnalyticsUtils.heardSource(noises: { Noise }, listener: Vector3, scale: number, now: number): string
	for index = #noises, 1, -1 do
		local noise = noises[index]
		local recent = now - noise.at <= ShiftAnalyticsConstants.NOISE_MEMORY
		if recent and (listener - noise.position).Magnitude <= noise.radius * scale then
			return noise.source
		end
	end
	return "unknown"
end

return ShiftAnalyticsUtils
```

- [ ] **Step 6: Exempt the constants.** In `src/ServerScriptService/Core/Testing/SpecRoots.luau`, in `EXEMPT_MODULES`, directly after the line starting `["ServerScriptService.Features.Shift.Systems.ShiftBankingSystem"]`, insert:

```lua
	["ServerScriptService.Features.Shift.Data.ShiftAnalyticsConstants"] = "static analytics vocabulary and limits (no logic; exercised by ShiftAnalyticsUtils.spec)",
```

- [ ] **Step 7: Controller: Studio TestEZ.** Expected: every `ShiftAnalyticsUtils` case passes; `assertAllModulesSpecced` passes; nothing else regresses.

- [ ] **Step 8: Gate and commit** (Global Constraints order):

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau src/ServerScriptService/Features/Shift/Data/ShiftAnalyticsConstants.luau src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.spec.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): analytics vocabulary, tokens and payload rules"
python3 scripts/python/module_map.py --check
```
Expected: `==> All checks passed.`; `--check` prints no FAIL.

- [ ] **Step 9: Studio verification checklist** (controller): the TestEZ output lists every `ShiftAnalyticsUtils` case passing; a fresh Play with `RunTests = false` boots with no new server or client errors (nothing requires these modules at runtime until Task 7).

---

### Task 2: The platform report (fixed enum, client detection, packet)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Shift/Rules/ShiftPlatformRules.luau`
- Test: `src/ReplicatedStorage/Shared/Features/Shift/Rules/ShiftPlatformRules.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Net/ShiftEvents.luau` (a `Platform` packet)
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau` (one key)
- Modify: `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau` (report once)

**Interfaces:**
- Consumes: `ShiftTypes.Platform` (Task 1).
- Produces (ShiftPlatformRules): `type Signals = { touch: boolean, keyboard: boolean, gamepad: boolean, tenFoot: boolean, shortSide: number }`; `PHONE_SHORT_SIDE = 600`; `detect(signals: Signals) -> Platform`; `code(platform: Platform) -> number` (1 pc, 2 phone, 3 tablet, 4 console, 0 unknown); `parse(raw: unknown) -> Platform?` (only codes 1..4).
- Produces (ShiftEvents): `packets.Platform` (client → server, `ByteNet.uint8`).
- Produces (ShiftConstants): `PLATFORM_REPORT_DELAY = 2`.
- Produces (ShiftServiceClient): sends `Platform` once, `PLATFORM_REPORT_DELAY` seconds after start, when the code is not 0. The server half (accept and remember) is Task 7.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Shared/Features/Shift/Rules/ShiftPlatformRules.spec.luau`:

```lua
local ShiftPlatformRules = require(script.Parent.ShiftPlatformRules)

local function signals(overrides)
	local base = { touch = false, keyboard = true, gamepad = false, tenFoot = false, shortSide = 1080 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("detect", function()
		it("calls a keyboard device a pc, even with a touch screen", function()
			expect(ShiftPlatformRules.detect(signals())).to.equal("pc")
			expect(ShiftPlatformRules.detect(signals({ touch = true }))).to.equal("pc")
		end)

		it("splits touch-only devices into phone and tablet by the short side", function()
			expect(ShiftPlatformRules.detect(signals({ touch = true, keyboard = false, shortSide = 390 }))).to.equal("phone")
			expect(ShiftPlatformRules.detect(signals({ touch = true, keyboard = false, shortSide = 768 }))).to.equal("tablet")
			local edge = ShiftPlatformRules.PHONE_SHORT_SIDE
			expect(ShiftPlatformRules.detect(signals({ touch = true, keyboard = false, shortSide = edge }))).to.equal("tablet")
		end)

		it("calls a ten-foot interface or a gamepad-only device a console", function()
			expect(ShiftPlatformRules.detect(signals({ tenFoot = true }))).to.equal("console")
			expect(ShiftPlatformRules.detect(signals({ keyboard = false, gamepad = true }))).to.equal("console")
		end)

		it("is unknown with nothing to go on", function()
			expect(ShiftPlatformRules.detect(signals({ keyboard = false }))).to.equal("unknown")
		end)
	end)

	describe("code and parse", function()
		it("round-trips the four reportable platforms", function()
			for _, platform in { "pc", "phone", "tablet", "console" } do
				local code = ShiftPlatformRules.code(platform)
				expect(code >= 1 and code <= 4).to.equal(true)
				expect(ShiftPlatformRules.parse(code)).to.equal(platform)
			end
		end)

		it("gives unknown no code", function()
			expect(ShiftPlatformRules.code("unknown")).to.equal(0)
		end)

		it("parses only the four reportable codes", function()
			for _, raw in { 0, 5, 9, 255, -1, 2.5, 0 / 0, math.huge, "2", true } do
				expect(ShiftPlatformRules.parse(raw)).to.equal(nil)
			end
			expect(ShiftPlatformRules.parse(nil)).to.equal(nil)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: FAIL — `ShiftPlatformRules` missing.

- [ ] **Step 3: Write the module** `src/ReplicatedStorage/Shared/Features/Shift/Rules/ShiftPlatformRules.luau`:

```lua
--!strict
--[=[
	ShiftPlatformRules: the device a client reports for analytics (Cleanup Crew spec §6.4: "The client-reported
	platform (for analytics) is accepted only from a fixed enum"). The client `detect`s its platform from engine
	signals and sends its `code`; the server `parse`s the code and accepts only 1..4. Nothing gameplay-related ever
	reads the platform. Pure.

	@class ShiftPlatformRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type Platform = ShiftTypes.Platform

-- What the client can see about its device.
export type Signals = {
	touch: boolean,
	keyboard: boolean,
	gamepad: boolean,
	tenFoot: boolean,
	-- The viewport's shorter side in pixels.
	shortSide: number,
}

-- The fixed enum: a platform's code is its index ("unknown" has none and is never sent).
local BY_CODE: { Platform } = { "pc", "phone", "tablet", "console" }

local ShiftPlatformRules = {}

-- A touch-only screen whose short side is below this is a phone; otherwise a tablet.
ShiftPlatformRules.PHONE_SHORT_SIDE = 600

function ShiftPlatformRules.detect(signals: Signals): Platform
	if signals.tenFoot then
		return "console"
	end
	if signals.touch and not signals.keyboard then
		return if signals.shortSide < ShiftPlatformRules.PHONE_SHORT_SIDE then "phone" else "tablet"
	end
	if signals.keyboard then
		return "pc"
	end
	if signals.gamepad then
		return "console"
	end
	return "unknown"
end

function ShiftPlatformRules.code(platform: Platform): number
	return table.find(BY_CODE, platform) or 0
end

--[=[
	The platform for a reported code, or nil for anything outside the fixed enum.
]=]
function ShiftPlatformRules.parse(raw: unknown): Platform?
	if type(raw) ~= "number" then
		return nil
	end
	if raw % 1 ~= 0 or raw < 1 or raw > #BY_CODE then
		return nil
	end
	return BY_CODE[raw]
end

return ShiftPlatformRules
```

- [ ] **Step 4: The packet.** In `src/ReplicatedStorage/Shared/Features/Shift/Net/ShiftEvents.luau`, inside `packets = { ... }`, after the `Vote = ByteNet.definePacket({ ... }),` entry, add:

```lua
			-- The client's platform code (ShiftPlatformRules: 1 pc, 2 phone, 3 tablet, 4 console), analytics only;
			-- the server drops any other value and keeps the first valid report.
			Platform = ByteNet.definePacket({
				value = ByteNet.uint8,
				reliabilityType = "reliable",
			}),
```
In the header, change "The server parses the vote (ShiftVoteRules) and ignores it outside results." to "The server parses the vote (ShiftVoteRules) and ignores it outside results, and accepts a platform report only from ShiftPlatformRules' fixed enum."

- [ ] **Step 5: The delay.** In `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`, directly after the line `	VARIANT = VARIANT,`, insert:

```lua
	-- Seconds after the client starts before it reports its platform (the viewport has its real size by then).
	PLATFORM_REPORT_DELAY = 2,
```

- [ ] **Step 6: Report once from the client.** In `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`:
  1. Services: replace the line `local ReplicatedStorage = game:GetService("ReplicatedStorage")` with
     ```lua
     local GuiService = game:GetService("GuiService")
     local ReplicatedStorage = game:GetService("ReplicatedStorage")
     local UserInputService = game:GetService("UserInputService")
     local Workspace = game:GetService("Workspace")
     ```
  2. Requires: after `local ShiftEvents = require(ShiftShared.Net.ShiftEvents)` add `local ShiftPlatformRules = require(ShiftShared.Rules.ShiftPlatformRules)`.
  3. After `local unsubscribers: { () -> () } = {}`, add:
     ```lua

     -- Tells the server this device's platform once (analytics only; the server accepts ShiftPlatformRules' codes).
     local function reportPlatform()
     	local camera = Workspace.CurrentCamera
     	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.zero
     	local platform = ShiftPlatformRules.detect({
     		touch = UserInputService.TouchEnabled,
     		keyboard = UserInputService.KeyboardEnabled,
     		gamepad = UserInputService.GamepadEnabled,
     		tenFoot = GuiService:IsTenFootInterface(),
     		shortSide = math.min(viewport.X, viewport.Y),
     	})
     	local code = ShiftPlatformRules.code(platform)
     	if code > 0 then
     		ShiftEvents.packets.Platform.send(code)
     	end
     end
     ```
  4. At the top of `start = function(_self)`, before the first `table.insert(`, add `task.delay(ShiftConstants.PLATFORM_REPORT_DELAY, reportPlatform)`.
  5. Header: after "(clearing it when results end)." add " It also reports this device's platform once (ShiftPlatformRules, analytics only)."

- [ ] **Step 7: Controller: Studio TestEZ.** Expected: `ShiftPlatformRules` specs pass; nothing regresses.

- [ ] **Step 8: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Shift/Rules/ShiftPlatformRules.luau src/ReplicatedStorage/Shared/Features/Shift/Rules/ShiftPlatformRules.spec.luau src/ReplicatedStorage/Shared/Features/Shift/Net/ShiftEvents.luau src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): client platform report from a fixed enum"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 9: Studio verification checklist** (controller; Play Solo, `RunTests = false`). Before Play, inject a temporary server `Script` in ServerScriptService:

```lua
local ShiftEvents = require(game:GetService("ReplicatedStorage").Shared.Features.Shift.Net.ShiftEvents)
ShiftEvents.packets.Platform.listen(function(code, player)
	print("[M5] platform code", code, player and player.Name)
end)
```
1. About 2 s after the client loads, the server Output prints `[M5] platform code 1 <your name>` (a PC).
2. Client Output: no error from ShiftServiceClient.
3. With Studio's device emulator set to a phone, a fresh Play prints code `1` or `2` (emulation can keep the keyboard enabled, so `1` is acceptable here; the real-device check is the developer's phone pass in Task 10's doc).
Remove the injected Script afterwards.

---

### Task 3: Analytics bookkeeping (platforms, first cleanups, piles, quota time, noises, records)

**Files:**
- Create: `src/ServerScriptService/Features/Shift/State/ShiftAnalyticsTracker.luau`
- Test: `src/ServerScriptService/Features/Shift/State/ShiftAnalyticsTracker.spec.luau`

**Interfaces:**
- Consumes: `ShiftTypes.Platform` (Task 1); `ShiftAnalyticsUtils.Noise`, `ShiftAnalyticsUtils.Record` (Task 1).
- Produces (ShiftAnalyticsTracker): `new(recentLimit: number, noiseLimit: number) -> ShiftAnalyticsTracker` with methods `setPlatform(userId, platform) -> boolean` (first valid report wins; `"unknown"` refused), `platformOf(userId) -> Platform` (`"unknown"` by default), `forget(userId)`, `beginShift()` (clears first cleanups, piles, quota time and noises; keeps platforms), `firstCleanup(userId) -> boolean` (true once per player per shift), `addPile(userId)`, `pilesOf(userId) -> number`, `markQuota(at: number) -> boolean` (first per shift), `quotaAt() -> number?`, `noteNoise(noise: Noise)`, `noises() -> { Noise }` (oldest first, a copy), `remember(record: Record)`, `recent() -> { Record }` (oldest first, a copy).

- [ ] **Step 1: Write the failing spec** `src/ServerScriptService/Features/Shift/State/ShiftAnalyticsTracker.spec.luau`:

```lua
local ShiftAnalyticsTracker = require(script.Parent.ShiftAnalyticsTracker)

local function record(event)
	return {
		event = event,
		session = "studio",
		build = "m5-dev",
		variant = "B",
		platform = "pc",
		party = 1,
		target = "none",
		outcome = "none",
		reason = "none",
		value = 0,
	}
end

return function()
	describe("platforms", function()
		it("keeps the first valid platform report", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			expect(tracker:setPlatform(7, "phone")).to.equal(true)
			expect(tracker:setPlatform(7, "pc")).to.equal(false)
			expect(tracker:platformOf(7)).to.equal("phone")
		end)

		it("refuses unknown and reads unknown for a player who never reported", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			expect(tracker:setPlatform(7, "unknown")).to.equal(false)
			expect(tracker:platformOf(7)).to.equal("unknown")
			expect(tracker:setPlatform(7, "tablet")).to.equal(true)
		end)

		it("forgets a player who left, and keeps platforms across shifts", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			tracker:setPlatform(7, "phone")
			tracker:setPlatform(8, "pc")
			tracker:beginShift()
			expect(tracker:platformOf(8)).to.equal("pc")
			tracker:forget(7)
			expect(tracker:platformOf(7)).to.equal("unknown")
		end)
	end)

	describe("per shift", function()
		it("reports a player's first cleanup once per shift", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			expect(tracker:firstCleanup(7)).to.equal(true)
			expect(tracker:firstCleanup(7)).to.equal(false)
			expect(tracker:firstCleanup(8)).to.equal(true)
			tracker:beginShift()
			expect(tracker:firstCleanup(7)).to.equal(true)
		end)

		it("counts piles per player and clears them with a new shift", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			tracker:addPile(7)
			tracker:addPile(7)
			tracker:addPile(8)
			expect(tracker:pilesOf(7)).to.equal(2)
			expect(tracker:pilesOf(8)).to.equal(1)
			expect(tracker:pilesOf(9)).to.equal(0)
			tracker:beginShift()
			expect(tracker:pilesOf(7)).to.equal(0)
		end)

		it("remembers only the first quota time in a shift", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			expect(tracker:quotaAt()).to.equal(nil)
			expect(tracker:markQuota(200)).to.equal(true)
			expect(tracker:markQuota(250)).to.equal(false)
			expect(tracker:quotaAt()).to.equal(200)
			tracker:beginShift()
			expect(tracker:quotaAt()).to.equal(nil)
		end)
	end)

	describe("rings", function()
		it("keeps the newest noises up to the limit, oldest first", function()
			local tracker = ShiftAnalyticsTracker.new(10, 2)
			for index = 1, 3 do
				tracker:noteNoise({ source = "vacuum", position = Vector3.new(index, 0, 0), radius = 40, at = index })
			end
			local noises = tracker:noises()
			expect(#noises).to.equal(2)
			expect(noises[1].at).to.equal(2)
			expect(noises[2].at).to.equal(3)
			tracker:beginShift()
			expect(#tracker:noises()).to.equal(0)
		end)

		it("keeps the newest records up to the limit and hands out a copy", function()
			local tracker = ShiftAnalyticsTracker.new(2, 4)
			tracker:remember(record("contract_started"))
			tracker:remember(record("pile_cleared"))
			tracker:remember(record("quota_met"))
			local recent = tracker:recent()
			expect(#recent).to.equal(2)
			expect(recent[1].event).to.equal("pile_cleared")
			expect(recent[2].event).to.equal("quota_met")
			table.clear(recent)
			expect(#tracker:recent()).to.equal(2)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: FAIL — `ShiftAnalyticsTracker` missing.

- [ ] **Step 3: Write the module** `src/ServerScriptService/Features/Shift/State/ShiftAnalyticsTracker.luau`:

```lua
--!strict
--[=[
	ShiftAnalyticsTracker: what Cleanup Crew's analytics remembers between events (spec §6.6, §6.4). Plain bookkeeping
	nothing subscribes to:
	- each player's platform: the first valid report wins ("unknown" is never accepted, a second report is ignored),
	  forgotten when they leave;
	- per shift: who has started their first cleanup, piles cleared per player, when the quota was met (seconds into
	  the shift);
	- the last few noises (which one Mr. Harlow most likely heard) and the last records (the in-server log the Studio
	  checks and the developer read).

	@class ShiftAnalyticsTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftAnalyticsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftAnalyticsUtils)

type Platform = ShiftTypes.Platform
type Noise = ShiftAnalyticsUtils.Noise
type Record = ShiftAnalyticsUtils.Record

export type ShiftAnalyticsTracker = {
	setPlatform: (self: ShiftAnalyticsTracker, userId: number, platform: Platform) -> boolean,
	platformOf: (self: ShiftAnalyticsTracker, userId: number) -> Platform,
	forget: (self: ShiftAnalyticsTracker, userId: number) -> (),
	beginShift: (self: ShiftAnalyticsTracker) -> (),
	firstCleanup: (self: ShiftAnalyticsTracker, userId: number) -> boolean,
	addPile: (self: ShiftAnalyticsTracker, userId: number) -> (),
	pilesOf: (self: ShiftAnalyticsTracker, userId: number) -> number,
	markQuota: (self: ShiftAnalyticsTracker, at: number) -> boolean,
	quotaAt: (self: ShiftAnalyticsTracker) -> number?,
	noteNoise: (self: ShiftAnalyticsTracker, noise: Noise) -> (),
	noises: (self: ShiftAnalyticsTracker) -> { Noise },
	remember: (self: ShiftAnalyticsTracker, record: Record) -> (),
	recent: (self: ShiftAnalyticsTracker) -> { Record },
}

local ShiftAnalyticsTracker = {}

-- Appends `item`, dropping the oldest entries past `limit`.
local function push<T>(list: { T }, item: T, limit: number)
	table.insert(list, item)
	while #list > limit do
		table.remove(list, 1)
	end
end

function ShiftAnalyticsTracker.new(recentLimit: number, noiseLimit: number): ShiftAnalyticsTracker
	local platforms: { [number]: Platform } = {}
	local cleaned: { [number]: boolean } = {}
	local piles: { [number]: number } = {}
	local quotaMetAt: number? = nil
	local noiseList: { Noise } = {}
	local records: { Record } = {}

	local tracker: ShiftAnalyticsTracker = {
		setPlatform = function(_self, userId, platform)
			if platform == "unknown" or platforms[userId] ~= nil then
				return false
			end
			platforms[userId] = platform
			return true
		end,

		platformOf = function(_self, userId)
			return platforms[userId] or "unknown"
		end,

		forget = function(_self, userId)
			platforms[userId] = nil
			cleaned[userId] = nil
			piles[userId] = nil
		end,

		beginShift = function(_self)
			table.clear(cleaned)
			table.clear(piles)
			quotaMetAt = nil
			table.clear(noiseList)
		end,

		firstCleanup = function(_self, userId)
			if cleaned[userId] then
				return false
			end
			cleaned[userId] = true
			return true
		end,

		addPile = function(_self, userId)
			piles[userId] = (piles[userId] or 0) + 1
		end,

		pilesOf = function(_self, userId)
			return piles[userId] or 0
		end,

		markQuota = function(_self, at)
			if quotaMetAt ~= nil then
				return false
			end
			quotaMetAt = at
			return true
		end,

		quotaAt = function(_self)
			return quotaMetAt
		end,

		noteNoise = function(_self, noise)
			push(noiseList, noise, noiseLimit)
		end,

		noises = function(_self)
			return table.clone(noiseList)
		end,

		remember = function(_self, record)
			push(records, record, recentLimit)
		end,

		recent = function(_self)
			return table.clone(records)
		end,
	}
	return tracker
end

return ShiftAnalyticsTracker
```

- [ ] **Step 4: Controller: Studio TestEZ.** Expected: every `ShiftAnalyticsTracker` case passes.

- [ ] **Step 5: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/State/ShiftAnalyticsTracker.luau src/ServerScriptService/Features/Shift/State/ShiftAnalyticsTracker.spec.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): analytics bookkeeping tracker"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 6: Studio verification checklist** (controller): TestEZ lists the eight `ShiftAnalyticsTracker` cases passing; `assertAllModulesSpecced` passes. (No runtime wiring yet.)

---

### Task 4: The optional-salvage attempt (open, re-key, close once, count)

**Files:**
- Create: `src/ServerScriptService/Features/Shift/State/ShiftSalvageTracker.luau`
- Test: `src/ServerScriptService/Features/Shift/State/ShiftSalvageTracker.spec.luau`

**Interfaces:**
- Consumes: `ShiftAnalyticsUtils.AttemptOutcome` (Task 1).
- Produces (ShiftSalvageTracker): `type Attempt = { itemId: number, userId: number, kind: string, source: string, sinceQuota: number, outcome: AttemptOutcome? }`; `new() -> ShiftSalvageTracker` with methods `open(itemId, userId, kind, source, sinceQuota) -> boolean` (true only for a new attempt), `resolveItem(itemId, outcome) -> Attempt?`, `resolveBanked(userId, kinds: { string }) -> { Attempt }`, `resolvePlayer(userId, outcome) -> { Attempt }`, `resolveAll(outcome) -> { Attempt }`, `openCount() -> number`, `attemptsBy(userId) -> number` (attempts opened this shift), `clear()`. Every returned attempt is closed (its `outcome` set) and gone from the tracker, so nothing closes twice.

The definition this tracker implements (Decisions): an attempt opens on an after-quota salvage pick-up outside the loading bay (the watch decides that with `ShiftAnalyticsUtils.isSalvageAttempt`); **one open attempt per item**; a teammate picking up an item that already has an open attempt opens nothing; a player whose open attempt's **kind** comes back into their hands under a new item id (unpocket, swap, picking up their own scattered item) keeps that attempt, re-keyed to the new id; it closes once as banked or failed.

- [ ] **Step 1: Write the failing spec** `src/ServerScriptService/Features/Shift/State/ShiftSalvageTracker.spec.luau`:

```lua
local ShiftSalvageTracker = require(script.Parent.ShiftSalvageTracker)

return function()
	describe("open", function()
		it("opens one attempt per item and counts it for the player", function()
			local tracker = ShiftSalvageTracker.new()
			expect(tracker:open(1, 7, "fishTank", "open", 12)).to.equal(true)
			expect(tracker:open(1, 7, "fishTank", "open", 15)).to.equal(false)
			expect(tracker:openCount()).to.equal(1)
			expect(tracker:attemptsBy(7)).to.equal(1)
		end)

		it("opens nothing for a teammate picking up an item that already has an attempt", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 7, "printer", "open", 5)
			expect(tracker:open(1, 8, "printer", "open", 9)).to.equal(false)
			expect(tracker:attemptsBy(8)).to.equal(0)
		end)

		it("re-keys a player's open attempt when the same kind comes back into their hands", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 7, "plaque", "pile", 20)
			-- Pocketed (no close), then taken out again as a new item id.
			expect(tracker:open(2, 7, "plaque", "pile", 40)).to.equal(false)
			expect(tracker:attemptsBy(7)).to.equal(1)
			expect(tracker:resolveItem(1, "dropped")).to.equal(nil)
			local closed = tracker:resolveItem(2, "dropped")
			expect(closed.itemId).to.equal(2)
			expect(closed.sinceQuota).to.equal(20)
			expect(closed.outcome).to.equal("dropped")
		end)

		it("counts a second go after a failed attempt", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 7, "fishTank", "open", 10)
			tracker:resolveItem(1, "dropped")
			expect(tracker:open(1, 7, "fishTank", "open", 30)).to.equal(true)
			expect(tracker:attemptsBy(7)).to.equal(2)
		end)
	end)

	describe("closing", function()
		it("closes an item's attempt once", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 7, "monitor", "desk", 3)
			expect(tracker:resolveItem(1, "thrown").outcome).to.equal("thrown")
			expect(tracker:resolveItem(1, "dropped")).to.equal(nil)
			expect(tracker:resolveItem(99, "dropped")).to.equal(nil)
			expect(tracker:openCount()).to.equal(0)
		end)

		it("banks the loader's oldest open attempt of each banked kind", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 7, "plaque", "open", 1)
			tracker:open(2, 7, "goldenStapler", "desk", 2)
			tracker:open(3, 8, "plaque", "open", 3)
			local banked = tracker:resolveBanked(7, { "plaque", "rubbishBag", "goldenStapler" })
			expect(#banked).to.equal(2)
			expect(banked[1].kind).to.equal("plaque")
			expect(banked[1].userId).to.equal(7)
			expect(banked[1].outcome).to.equal("banked")
			expect(banked[2].kind).to.equal("goldenStapler")
			expect(tracker:openCount()).to.equal(1)
		end)

		it("banks nothing for kinds the loader has no attempt for", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 8, "printer", "open", 1)
			expect(#tracker:resolveBanked(7, { "printer" })).to.equal(0)
			expect(#tracker:resolveBanked(8, {})).to.equal(0)
			expect(tracker:openCount()).to.equal(1)
		end)

		it("closes a player's attempts once, whoever reports it first", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 7, "waterJug", "open", 4)
			tracker:open(2, 7, "plaque", "pile", 6)
			tracker:open(3, 8, "printer", "open", 8)
			-- Carry's death drop of the jug arrives first, then Death's catch.
			expect(tracker:resolveItem(1, "caught").outcome).to.equal("caught")
			local caught = tracker:resolvePlayer(7, "caught")
			expect(#caught).to.equal(1)
			expect(caught[1].kind).to.equal("plaque")
			expect(#tracker:resolvePlayer(7, "left")).to.equal(0)
			expect(tracker:openCount()).to.equal(1)
		end)

		it("closes everything still open at the end of the shift, in the order they opened", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 7, "printer", "open", 1)
			tracker:open(2, 8, "coffeeMachine", "open", 2)
			local ended = tracker:resolveAll("unbanked")
			expect(#ended).to.equal(2)
			expect(ended[1].itemId).to.equal(1)
			expect(ended[2].outcome).to.equal("unbanked")
			expect(tracker:openCount()).to.equal(0)
		end)

		it("clears attempts and counts for a new shift", function()
			local tracker = ShiftSalvageTracker.new()
			tracker:open(1, 7, "printer", "open", 1)
			tracker:clear()
			expect(tracker:openCount()).to.equal(0)
			expect(tracker:attemptsBy(7)).to.equal(0)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: FAIL — `ShiftSalvageTracker` missing.

- [ ] **Step 3: Write the module** `src/ServerScriptService/Features/Shift/State/ShiftSalvageTracker.luau`:

```lua
--!strict
--[=[
	ShiftSalvageTracker: optional-salvage attempts (Cleanup Crew spec §1: "do players voluntarily go back for optional
	salvage after the quota?"). The watch opens an attempt when a player picks up salvage after the quota outside the
	loading bay (ShiftAnalyticsUtils.isSalvageAttempt). This tracker keeps them:
	- one open attempt per item; a teammate picking up that item opens nothing;
	- a player whose open attempt's kind comes back into their hands under a new item id (unpocket, swap, their own
	  scattered item) keeps that attempt, re-keyed, so pockets never duplicate one;
	- every close removes the attempt, so it closes exactly once: banked (that player loads that kind) or failed
	  (dropped, thrown, caught, left, unbanked at the shift's end);
	- how many attempts each player opened this shift (shift_ended's value).

	@class ShiftSalvageTracker
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local ShiftAnalyticsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftAnalyticsUtils)

type AttemptOutcome = ShiftAnalyticsUtils.AttemptOutcome

export type Attempt = {
	itemId: number,
	userId: number,
	kind: string,
	-- Where the item came from ("open", "pile", "desk", "scatter").
	source: string,
	-- Seconds from the quota being met to the pick-up.
	sinceQuota: number,
	-- Set when the attempt closes.
	outcome: AttemptOutcome?,
}

export type ShiftSalvageTracker = {
	open: (
		self: ShiftSalvageTracker,
		itemId: number,
		userId: number,
		kind: string,
		source: string,
		sinceQuota: number
	) -> boolean,
	resolveItem: (self: ShiftSalvageTracker, itemId: number, outcome: AttemptOutcome) -> Attempt?,
	resolveBanked: (self: ShiftSalvageTracker, userId: number, kinds: { string }) -> { Attempt },
	resolvePlayer: (self: ShiftSalvageTracker, userId: number, outcome: AttemptOutcome) -> { Attempt },
	resolveAll: (self: ShiftSalvageTracker, outcome: AttemptOutcome) -> { Attempt },
	openCount: (self: ShiftSalvageTracker) -> number,
	attemptsBy: (self: ShiftSalvageTracker, userId: number) -> number,
	clear: (self: ShiftSalvageTracker) -> (),
}

local ShiftSalvageTracker = {}

function ShiftSalvageTracker.new(): ShiftSalvageTracker
	-- Open attempts, oldest first.
	local pending: { Attempt } = {}
	local counts: { [number]: number } = {}

	-- Removes the attempt at `index` and closes it with `outcome`.
	local function take(index: number, outcome: AttemptOutcome): Attempt?
		local attempt = table.remove(pending, index)
		if attempt ~= nil then
			attempt.outcome = outcome
		end
		return attempt
	end

	local tracker: ShiftSalvageTracker = {
		open = function(_self, itemId, userId, kind, source, sinceQuota)
			for _, attempt in pending do
				if attempt.itemId == itemId then
					return false
				end
				if attempt.userId == userId and attempt.kind == kind then
					-- The same kind back in the same hands (unpocket, swap, a scattered pick-up): one attempt.
					attempt.itemId = itemId
					return false
				end
			end
			table.insert(pending, {
				itemId = itemId,
				userId = userId,
				kind = kind,
				source = source,
				sinceQuota = sinceQuota,
				outcome = nil,
			})
			counts[userId] = (counts[userId] or 0) + 1
			return true
		end,

		resolveItem = function(_self, itemId, outcome)
			for index, attempt in pending do
				if attempt.itemId == itemId then
					return take(index, outcome)
				end
			end
			return nil
		end,

		resolveBanked = function(_self, userId, kinds)
			local closed: { Attempt } = {}
			for _, kind in kinds do
				for index, attempt in pending do
					if attempt.userId == userId and attempt.kind == kind then
						local attemptClosed = take(index, "banked")
						if attemptClosed ~= nil then
							table.insert(closed, attemptClosed)
						end
						break
					end
				end
			end
			return closed
		end,

		resolvePlayer = function(_self, userId, outcome)
			local closed: { Attempt } = {}
			for index = #pending, 1, -1 do
				if pending[index].userId == userId then
					local attemptClosed = take(index, outcome)
					if attemptClosed ~= nil then
						table.insert(closed, 1, attemptClosed)
					end
				end
			end
			return closed
		end,

		resolveAll = function(_self, outcome)
			local closed: { Attempt } = {}
			while #pending > 0 do
				local attemptClosed = take(1, outcome)
				if attemptClosed ~= nil then
					table.insert(closed, attemptClosed)
				end
			end
			return closed
		end,

		openCount = function(_self)
			return #pending
		end,

		attemptsBy = function(_self, userId)
			return counts[userId] or 0
		end,

		clear = function(_self)
			table.clear(pending)
			table.clear(counts)
		end,
	}
	return tracker
end

return ShiftSalvageTracker
```

- [ ] **Step 4: Controller: Studio TestEZ.** Expected: every `ShiftSalvageTracker` case passes.

- [ ] **Step 5: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/State/ShiftSalvageTracker.luau src/ServerScriptService/Features/Shift/State/ShiftSalvageTracker.spec.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): optional-salvage attempt tracker"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 6: Studio verification checklist** (controller): TestEZ lists the ten `ShiftSalvageTracker` cases passing. (Runtime behaviour is checked in Tasks 8 and 9.)

---

### Task 5: The variant switch rules and a fair spawn roll

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Rules/ShiftVariantRules.luau`
- Test: `src/ServerScriptService/Features/Shift/Rules/ShiftVariantRules.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau` (two keys)
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau` (draw the hide roll in both variants)
- Test: `src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.spec.luau` (one case)

**Interfaces:**
- Consumes: `ShiftTypes.Variant`, `VariantMode`, `VariantSource` (Task 1).
- Produces (ShiftConstants): `VARIANT_MODE: VariantMode = "alternate"`, `VARIANT_ATTRIBUTE = "CleanupCrewVariant"`.
- Produces (ShiftVariantRules): `type PickInput = { mode: VariantMode, fixed: Variant, override: unknown, session: string, shift: number }`; `parseOverride(raw: unknown) -> Variant?`; `hash(text: string) -> number` (djb2, 0..2147483646); `other(variant) -> Variant`; `pick(input) -> (Variant, VariantSource)`.
- Produces (OfficeSpawnUtils): unchanged API; the same seed now offers the same salvage in A and B.

- [ ] **Step 1: Write the failing variant spec** `src/ServerScriptService/Features/Shift/Rules/ShiftVariantRules.spec.luau`:

```lua
local ShiftVariantRules = require(script.Parent.ShiftVariantRules)

local function pick(overrides)
	local input = { mode = "alternate", fixed = "B", override = nil, session = "studio", shift = 1 }
	for key, value in overrides or {} do
		input[key] = value
	end
	return ShiftVariantRules.pick(input)
end

return function()
	describe("parseOverride", function()
		it("accepts A or B in any case, spaces trimmed", function()
			expect(ShiftVariantRules.parseOverride("A")).to.equal("A")
			expect(ShiftVariantRules.parseOverride(" b ")).to.equal("B")
		end)

		it("ignores anything else", function()
			for _, raw in { "C", "", "AB", 1, true, nil } do
				expect(ShiftVariantRules.parseOverride(raw)).to.equal(nil)
			end
		end)
	end)

	describe("pick", function()
		it("uses the Workspace override over everything", function()
			local variant, source = pick({ override = "A", mode = "fixed" })
			expect(variant).to.equal("A")
			expect(source).to.equal("override")
			local alternate, alternateSource = pick({ override = "b", shift = 2 })
			expect(alternate).to.equal("B")
			expect(alternateSource).to.equal("override")
		end)

		it("ignores an override that is not A or B", function()
			local variant, source = pick({ override = "C" })
			expect(variant).to.equal("B")
			expect(source).to.equal("alternate")
		end)

		it("always plays the fixed variant in fixed mode", function()
			for shift = 1, 4 do
				local variant, source = pick({ mode = "fixed", shift = shift, session = "job-7" })
				expect(variant).to.equal("B")
				expect(source).to.equal("fixed")
			end
		end)

		it("starts on the default B in Studio and flips every shift", function()
			local expected = { "B", "A", "B", "A" }
			for shift, variant in expected do
				expect((pick({ shift = shift }))).to.equal(variant)
			end
			expect((pick({ session = "", shift = 1 }))).to.equal("B")
		end)

		it("treats a shift number below 1 as the first shift", function()
			expect((pick({ shift = 0 }))).to.equal("B")
		end)

		it("is the same for the same session and shift", function()
			for shift = 1, 3 do
				expect((pick({ session = "job-7", shift = shift }))).to.equal((pick({ session = "job-7", shift = shift })))
			end
		end)

		it("flips each shift from a live session's start", function()
			local first = pick({ session = "job-7", shift = 1 })
			expect((pick({ session = "job-7", shift = 2 }))).to.equal(ShiftVariantRules.other(first))
			expect((pick({ session = "job-7", shift = 3 }))).to.equal(first)
		end)

		it("starts some live sessions on A and some on B", function()
			local seen = {}
			for index = 1, 40 do
				seen[pick({ session = `job-{index}`, shift = 1 })] = true
			end
			expect(seen.A).to.equal(true)
			expect(seen.B).to.equal(true)
		end)
	end)

	describe("hash", function()
		it("is stable and inside 0..2147483646", function()
			expect(ShiftVariantRules.hash("abc")).to.equal(ShiftVariantRules.hash("abc"))
			local value = ShiftVariantRules.hash("8f3c1e2a-0b7d-4c55-9e1f-6a2b3c4d5e6f")
			expect(value >= 0 and value < 2147483647).to.equal(true)
			expect(value % 1).to.equal(0)
		end)
	end)
end
```

- [ ] **Step 2: Add the fairness case** to `src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.spec.luau`, inside `return function()`, after the case `it("hides some salvage under piles in variant B", ...)`:

```lua
	it("offers the same salvage for the same seed in both variants (only where it sits differs)", function()
		local function salvageOf(plan)
			local kinds = {}
			for _, item in plan.items do
				if CargoRegistry.get(item.kind).category == "salvage" then
					table.insert(kinds, item.kind)
				end
			end
			for _, pile in plan.piles do
				if pile.hides ~= nil then
					table.insert(kinds, pile.hides)
				end
			end
			table.sort(kinds)
			return table.concat(kinds, ",")
		end
		for seed = 1, 30 do
			local a = roll(seed, "A")
			local b = roll(seed, "B")
			expect(salvageOf(a)).to.equal(salvageOf(b))
			expect(#a.piles).to.equal(#b.piles)
			expect(a.greed.kind).to.equal(b.greed.kind)
		end
	end)
```

- [ ] **Step 3: Controller: Studio TestEZ.** Expected: `ShiftVariantRules` FAILS (module missing); the new `OfficeSpawnUtils` case FAILS on some seed (variant A skips the hide roll, so its random stream drifts from B's after the first hideable salvage).

- [ ] **Step 4: Write the rules** `src/ServerScriptService/Features/Shift/Rules/ShiftVariantRules.luau`:

```lua
--!strict
--[=[
	ShiftVariantRules: which A/B variant a shift plays (Cleanup Crew spec §4 "Variant switch (A/B from the validation
	plan, rewards unchanged): B (default) some salvage spawns hidden under piles; A all salvage spawns exposed"). In
	order:
	1. the developer's Workspace override ("A" or "B", any case) wins: source "override";
	2. "fixed" mode always plays the fixed variant (B): source "fixed";
	3. "alternate" mode plays a start variant on the server's first shift and flips it every shift after: B in Studio
	   (no JobId: the default), else djb2(JobId) even → B, odd → A, so live servers counterbalance the order. The same
	   crew plays both arms in one session. Source "alternate".
	The variant only decides where salvage spawns (OfficeSpawnUtils); no value, multiplier or quota reads it. Pure.

	@class ShiftVariantRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type Variant = ShiftTypes.Variant

export type PickInput = {
	mode: ShiftTypes.VariantMode,
	fixed: Variant,
	-- The Workspace attribute's raw value (anything; only "A"/"B" count).
	override: unknown,
	-- ShiftAnalyticsUtils.session(game.JobId): "studio" when there is no JobId.
	session: string,
	-- Shifts started on this server, counting this one.
	shift: number,
}

local HASH_MODULUS = 2147483647

local ShiftVariantRules = {}

function ShiftVariantRules.parseOverride(raw: unknown): Variant?
	if type(raw) ~= "string" then
		return nil
	end
	local trimmed = string.upper(string.match(raw, "^%s*(.-)%s*$") or "")
	if trimmed == "A" then
		return "A"
	elseif trimmed == "B" then
		return "B"
	end
	return nil
end

--[=[
	djb2 over the bytes of `text`, kept below 2^31 - 1.
]=]
function ShiftVariantRules.hash(text: string): number
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + string.byte(text, index)) % HASH_MODULUS
	end
	return value
end

function ShiftVariantRules.other(variant: Variant): Variant
	return if variant == "A" then "B" else "A"
end

function ShiftVariantRules.pick(input: PickInput): (Variant, ShiftTypes.VariantSource)
	local override = ShiftVariantRules.parseOverride(input.override)
	if override ~= nil then
		return override, "override"
	end
	if input.mode == "fixed" then
		return input.fixed, "fixed"
	end
	local first: Variant
	if input.session == "" or input.session == "studio" then
		first = input.fixed
	elseif ShiftVariantRules.hash(input.session) % 2 == 0 then
		first = "B"
	else
		first = "A"
	end
	local shift = math.max(1, math.floor(input.shift))
	local variant = if shift % 2 == 1 then first else ShiftVariantRules.other(first)
	return variant, "alternate"
end

return ShiftVariantRules
```

- [ ] **Step 5: The mode and the override name.** In `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`:
  1. After the line `local VARIANT: ShiftTypes.Variant = "B"`, add:
     ```lua
     -- How each shift's variant is chosen (ShiftVariantRules): "alternate" flips A/B per shift; "fixed" always plays VARIANT.
     local VARIANT_MODE: ShiftTypes.VariantMode = "alternate"
     ```
  2. After the line `	PLATFORM_REPORT_DELAY = 2,` (Task 2), add:
     ```lua
     	VARIANT_MODE = VARIANT_MODE,
     	-- The Workspace attribute a developer sets to "A" or "B" to force the next shifts' variant (testing only;
     	-- remove it before publishing: Workspace is the place's, so a saved attribute ships).
     	VARIANT_ATTRIBUTE = "CleanupCrewVariant",
     ```

- [ ] **Step 6: Make the roll fair.** In `src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau`, in step 4 (salvage), replace

```lua
		local hideable = options.variant == "B" and OfficeConstants.HIDEABLE[def.size] == true
		local pile = if hideable and rng:NextNumber() < OfficeConstants.HIDE_CHANCE then freePile(false) else nil
```
with
```lua
		-- Drawn in both variants, so A and B consume `rng` alike: the same seed offers the same salvage and only
		-- where it sits differs (spec §4: the variant never changes rewards).
		local hideRoll = rng:NextNumber()
		local hideable = options.variant == "B" and OfficeConstants.HIDEABLE[def.size] == true
		local pile = if hideable and hideRoll < OfficeConstants.HIDE_CHANCE then freePile(false) else nil
```
In the header, change item 4 to: "4. salvage: a count in `options.salvage`; in variant "B" a hideable one may go under a free pile (the hide roll is drawn in both variants, so a seed offers the same salvage in A and B);".

- [ ] **Step 7: Controller: Studio TestEZ.** Expected: `ShiftVariantRules` passes; every `OfficeSpawnUtils` case passes, including the new one and "meets every guarantee for fifty seeds in both variants". If the new case still fails only because variant A ran out of item markers (`takeMarker` returned nil, so A placed fewer salvage), stop and report it: the layout's roll capacity (`OfficeLayoutRules`) must then cover A's worst case, which is a layout decision. Then confirm nothing outside the spawn roll reads the variant:

```bash
grep -rn "variant" src/ServerScriptService/Features/Cargo src/ServerScriptService/Features/Shift/Systems/ShiftBankingSystem.luau src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.luau
```
Expected: only `ShiftPhaseRules` lines that copy `variant` through the state (`variant = variant` / `variant = state.variant`); nothing in Cargo, banking or results.

- [ ] **Step 8: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/Rules/ShiftVariantRules.luau src/ServerScriptService/Features/Shift/Rules/ShiftVariantRules.spec.luau src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.spec.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): variant switch rules; spawn roll offers the same salvage in A and B"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 9: Studio verification checklist** (controller): TestEZ green for `ShiftVariantRules` and `OfficeSpawnUtils` (11 cases); a fresh Play (`RunTests = false`) still starts a shift and the office still spawns piles and items (variant B, as before; the per-shift pick is wired in Task 7).

---

### Task 6: Make room in ShiftServiceServer (the vote receiver moves to Net)

`ShiftServiceServer` sits at or near the 400-code-line cap after M2-M4 (396 before them). Task 7 adds 6 lines; this task moves the results-vote intake (rate limit, parse, listen; about 25 lines) into a `Net/` receiver first. Behaviour is unchanged.

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Net/ShiftVoteReceiver.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ShiftEvents.packets.Vote` (string, client → server), `ShiftVoteRules.parse(data: string) -> Vote?`, `RequestHandler.wrap`, `ShiftServiceServer:vote(player, choice) -> boolean`.
- Produces (ShiftVoteReceiver): `listen(onVote: (player: Player, choice: ShiftTypes.Vote) -> ()) -> () -> ()` (returns the disconnect).

- [ ] **Step 1: Check what M4 left in the vote intake.** Read the `local onVote = RequestHandler.wrap({ ... })` block in `ShiftServiceServer.luau`. M1's handler body is exactly `if choice ~= nil then ShiftServiceServer:vote(player, choice) end`. If M4 added any other check inside `validate` or `handler` (for example "only crew members vote"), move that check to the top of the `vote = function(_self, player, choice)` method body (returning `false` when it refuses) so the receiver below stays a pure intake; report that you did.

- [ ] **Step 2: Write the receiver** `src/ServerScriptService/Features/Shift/Net/ShiftVoteReceiver.luau`:

```lua
--!strict
--[=[
	ShiftVoteReceiver: takes in the results vote (ShiftEvents `Vote`, client → server): rate-limited, parsed by
	ShiftVoteRules (anything but "another" / "depot" is dropped), then handed to the service, which decides whether it
	counts. Moved out of ShiftServiceServer in M5 to keep the service under the line cap.

	Spec-exempt shell (ByteNet, RequestHandler); parsing is the specced ShiftVoteRules.

	@class ShiftVoteReceiver
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftEvents = require(ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ShiftVoteRules = require(ServerScriptService.Features.Shift.Rules.ShiftVoteRules)

local ShiftVoteReceiver = {}

--[=[
	Listens for votes and calls `onVote` with each valid one. Returns the disconnect.
]=]
function ShiftVoteReceiver.listen(onVote: (player: Player, choice: ShiftTypes.Vote) -> ()): () -> ()
	local handle = RequestHandler.wrap({
		name = "ShiftVote",
		rateLimit = { maxRequests = 6, windowSeconds = 5 },
		validate = function(data: string, _player: Player): (boolean, string?, ShiftTypes.Vote?)
			local choice: ShiftTypes.Vote? = ShiftVoteRules.parse(data)
			if not choice then
				return false, "unknown vote", nil
			end
			return true, nil, choice
		end,
		handler = function(_data: string, player: Player, choice: ShiftTypes.Vote?)
			if choice ~= nil then
				onVote(player, choice)
			end
		end,
	})
	return ShiftEvents.packets.Vote.listen(function(data: string, player: Player?)
		if player then
			handle(data, player)
		end
	end)
end

return ShiftVoteReceiver
```

If luau-lsp rejects returning the packet's `listen` result as `() -> ()` (ByteNetMax's `listen` returns its disconnect function at runtime, `packet.luau:101`; the service already stores it in `stoppers: { () -> () }`), report it instead of casting.

- [ ] **Step 3: Use it in the service.** In `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`:
  1. Delete the whole `local onVote = RequestHandler.wrap({` … `})` block (from that line through its closing `})`).
  2. In `start`, replace the block
     ```lua
     		table.insert(
     			stoppers,
     			ShiftEvents.packets.Vote.listen(function(data: string, player: Player?)
     				if player then
     					onVote(data, player)
     				end
     			end)
     		)
     ```
     with
     ```lua
     		table.insert(
     			stoppers,
     			ShiftVoteReceiver.listen(function(player: Player, choice: ShiftTypes.Vote)
     				self:vote(player, choice)
     			end)
     		)
     ```
  3. Requires: after `local ShiftBankingSystem = require(ShiftServer.Systems.ShiftBankingSystem)` add `local ShiftVoteReceiver = require(ShiftServer.Net.ShiftVoteReceiver)`. Then run `selene src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`: delete each require it reports as unused (expected: `RequestHandler`, `ShiftEvents`). Keep the forward declaration `local ShiftServiceServer: ShiftServiceServer` and the later `ShiftServiceServer = {` assignment as they are.
  4. Header: in the list, after the clock-out bullet, add `- votes come in through ShiftVoteReceiver (Net); \`vote\` decides whether they count;`.

- [ ] **Step 4: Exempt the receiver.** In `src/ServerScriptService/Core/Testing/SpecRoots.luau`, after the `ShiftAnalyticsConstants` line (Task 1), insert:

```lua
	["ServerScriptService.Features.Shift.Net.ShiftVoteReceiver"] = "ByteNet/RequestHandler intake shell (vote parsing is specced in ShiftVoteRules)",
```

- [ ] **Step 5: Check the line count dropped**

```bash
python3 -c "import sys; sys.path.insert(0,'scripts/python'); import check_file_length as c; print(c.count_code_lines(open('src/ServerScriptService/Features/Shift/ShiftServiceServer.luau',encoding='utf8').read()))"
```
Expected: at least 15 lower than Task 0 Step 4's number, and ≤ 394.

- [ ] **Step 6: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/Net/ShiftVoteReceiver.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "refactor(shift): move the results-vote intake into ShiftVoteReceiver"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 7: Studio verification checklist** (controller; TestEZ first: `ShiftVoteRules` and every Shift spec still pass; then Play Solo, `RunTests = false`, through M4's Studio loop: board a truck in the depot and depart):
1. Clock out at the truck; results show; press **Another shift**: the vote registers on the HUD and a new shift starts (the reset happens as before).
2. In the next results, press **Back to depot**: the M4 return trip runs as before.
3. Spam the vote button ~10 times in a second: no errors; the server Output may log RequestHandler rate-limit rejections; the vote still resolves once.

---

### Task 7: The analytics door, shift events, banking events and the per-shift variant

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsSystem.luau`
- Create: `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (2 requires, the variant pick, the watch start)
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftBankingSystem.luau` (cargo_banked)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: Tasks 1-5 (`ShiftAnalyticsConstants`, `ShiftAnalyticsUtils`, `ShiftPlatformRules.parse`, `ShiftEvents.packets.Platform`, `ShiftAnalyticsTracker`, `ShiftSalvageTracker`, `ShiftVariantRules.pick`, `ShiftConstants.VARIANT_MODE / VARIANT_ATTRIBUTE / VARIANT`); `AnalyticsServiceServer:custom(player, event, value?, fields?)`; `RoundServiceServer:participants() -> { Player }`, `RoundServiceServer.runEnded: Signal<string>`; `ShiftServiceServer`'s local `changed: Signal<ShiftState>` (a copy per state change, deferred); `CargoTypes.Deposit = { clearance, bonus, items: { { kind, category, value } } }`; ShiftBankingSystem's local `multiplier`.
- Produces (ShiftAnalyticsSystem, module-level; `Scope = Player | "crew"`): `start()`, `stop()`, `emit(event: string, scope: Scope, details: ShiftAnalyticsUtils.Details) -> number` (records sent), `pickVariant(shift: number) -> Variant`, `variantSource() -> string`, `setShift(state: ShiftState)`, `shift() -> ShiftState?`, `beginShift()`, `elapsed() -> number` (seconds since the shift started; 0 when not running), `quotaTag() -> string`, `sinceQuota() -> number`, `crew() -> { Player }`, `banked(player, deposit: CargoTypes.Deposit, multiplier: number)`, `closeAttempts(attempts: { ShiftSalvageTracker.Attempt })`, `listen(listener: (Record) -> ()) -> () -> ()`, `recent() -> { Record }`, `getState() -> { [string]: string | number }`; fields `tracker: ShiftAnalyticsTracker`, `salvage: ShiftSalvageTracker`.
- Produces (ShiftAnalyticsWatchSystem): `start(changed: SignalTyped.Signal<ShiftTypes.ShiftState>) -> () -> ()` (starts ShiftAnalyticsSystem too; the returned function stops both). This task emits `contract_started`, `replay_started`, `quota_met`, `shift_ended`, `optional_salvage_attempted` (closes at the shift's end and on leaving) and, from ShiftBankingSystem, `cargo_banked` (+ banked attempt closes). Tasks 8 and 9 add the rest to the watch.

- [ ] **Step 1: Write the analytics door** `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsSystem.luau`:

```lua
--!strict
--[=[
	ShiftAnalyticsSystem: Cleanup Crew's one door to analytics (spec §6.6, §6.4, §1). Every game event goes through
	`emit`: the name must be one of the 13 (ShiftAnalyticsConstants.EVENTS); target, outcome and reason become
	vocabulary tokens (ShiftAnalyticsUtils.token: catalog ids and fixed words only, so no name, chat line or id can reach
	a field). Each record goes to:
	- AnalyticsServiceServer:custom(player, event, value, { context, target, outcome }): the engine takes three custom
	  fields, so field 1 packs "variant|platform|party|build" (AnalyticsServiceServer sends nothing in Studio);
	- the server log, key events at info and the rest at debug, with the session id (JobId) the engine fields leave out;
	- a ring of recent records and any `listen` callbacks (the Studio test sink).
	"crew" events go once to each crew member (Round participants still in the server).

	It also keeps the experiment context: the session, the build (BUILD_LABEL + PlaceVersion), each shift's variant
	(`pickVariant`: ShiftVariantRules over the Workspace override, ShiftConstants.VARIANT_MODE and the JobId, logged at
	info), each player's platform (the `Platform` packet, parsed by ShiftPlatformRules, first report wins) and the shift
	state the watch hands it. `banked` (ShiftBankingSystem) sends cargo_banked per item and closes the loader's
	optional-salvage attempts; `closeAttempts` sends optional_salvage_attempted for each closed attempt.

	Spec-exempt shell (AnalyticsService, Players, ByteNet, a Workspace attribute); payloads, tokens, variant, platform
	and attempts are the specced ShiftAnalyticsUtils, ShiftVariantRules, ShiftPlatformRules, ShiftAnalyticsTracker and
	ShiftSalvageTracker.

	@class ShiftAnalyticsSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local ShiftServer = ServerScriptService.Features.Shift
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftEvents = require(ShiftShared.Net.ShiftEvents)
local ShiftPlatformRules = require(ShiftShared.Rules.ShiftPlatformRules)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local AnalyticsServiceServer = require(ServerScriptService.Features.Analytics.AnalyticsServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftAnalyticsConstants = require(ShiftServer.Data.ShiftAnalyticsConstants)
local ShiftVariantRules = require(ShiftServer.Rules.ShiftVariantRules)
local ShiftAnalyticsTracker = require(ShiftServer.State.ShiftAnalyticsTracker)
local ShiftSalvageTracker = require(ShiftServer.State.ShiftSalvageTracker)
local ShiftAnalyticsUtils = require(ShiftServer.Utils.ShiftAnalyticsUtils)

export type Scope = Player | "crew"

type Record = ShiftAnalyticsUtils.Record
type Details = ShiftAnalyticsUtils.Details

local log = Logger.new("ShiftAnalyticsSystem")
local session = ShiftAnalyticsUtils.session(game.JobId)
local build = ShiftAnalyticsUtils.build(ShiftAnalyticsConstants.BUILD_LABEL, game.PlaceVersion)
local tracker = ShiftAnalyticsTracker.new(ShiftAnalyticsConstants.RECENT_LIMIT, ShiftAnalyticsConstants.NOISE_LIMIT)
local salvage = ShiftSalvageTracker.new()
local listeners: { (Record) -> () } = {}
local counters = { sent = 0, unknown = 0 }
local variant: ShiftTypes.Variant = ShiftConstants.VARIANT
local variantSource: ShiftTypes.VariantSource = "fixed"
local shiftState: ShiftTypes.ShiftState? = nil
local stoppers: { () -> () } = {}

local ShiftAnalyticsSystem = {}

ShiftAnalyticsSystem.tracker = tracker
ShiftAnalyticsSystem.salvage = salvage

-- Crew members still in the server (Round's participants).
function ShiftAnalyticsSystem.crew(): { Player }
	local list: { Player } = {}
	for _, player in RoundServiceServer:participants() do
		if player.Parent ~= nil then
			table.insert(list, player)
		end
	end
	return list
end

-- One record for one player: AnalyticsService, the log, the ring, the listeners.
local function send(event: string, player: Player, party: number, details: Details)
	local context: ShiftAnalyticsUtils.Context = {
		session = session,
		build = build,
		variant = variant,
		platform = tracker:platformOf(player.UserId),
		party = party,
	}
	local record = ShiftAnalyticsUtils.record(event, context, details)
	tracker:remember(record)
	AnalyticsServiceServer:custom(player, event, record.value, ShiftAnalyticsUtils.fields(context, details))
	counters.sent += 1
	local line = `{record.event} target={record.target} outcome={record.outcome} reason={record.reason} value={record.value} variant={record.variant} platform={record.platform} party={record.party} build={record.build} session={record.session}`
	if ShiftAnalyticsConstants.INFO_EVENTS[event] then
		log:info(line)
	else
		log:debug(line)
	end
	for _, listener in table.clone(listeners) do
		local ok, err = pcall(listener, record)
		if not ok then
			log:warn(`analytics listener failed: {err}`)
		end
	end
end

--[=[
	Sends `event` to one player, or to each crew member for "crew". Returns how many records went out (0 for an unknown
	event, which is dropped and counted).
]=]
function ShiftAnalyticsSystem.emit(event: string, scope: Scope, details: Details): number
	if not ShiftAnalyticsUtils.isEvent(event) then
		counters.unknown += 1
		log:warn(`unknown analytics event "{event}" dropped`)
		return 0
	end
	local members = ShiftAnalyticsSystem.crew()
	if typeof(scope) == "Instance" then
		if scope.Parent == nil then
			return 0
		end
		send(event, scope, math.max(#members, 1), details)
		return 1
	end
	for _, player in members do
		send(event, player, #members, details)
	end
	return #members
end

--[=[
	The variant for the shift about to start (ShiftVariantRules); remembered for every event's context and logged.
	Never throws: ShiftServiceServer calls it inside its phase handler.
]=]
function ShiftAnalyticsSystem.pickVariant(shift: number): ShiftTypes.Variant
	local picked, source = ShiftVariantRules.pick({
		mode = ShiftConstants.VARIANT_MODE,
		fixed = ShiftConstants.VARIANT,
		override = Workspace:GetAttribute(ShiftConstants.VARIANT_ATTRIBUTE),
		session = session,
		shift = shift,
	})
	variant = picked
	variantSource = source
	log:info(`shift {shift}: variant {picked} ({source}), session {session}, build {build}`)
	return picked
end

function ShiftAnalyticsSystem.variantSource(): string
	return variantSource
end

function ShiftAnalyticsSystem.setShift(state: ShiftTypes.ShiftState)
	shiftState = state
end

function ShiftAnalyticsSystem.shift(): ShiftTypes.ShiftState?
	return shiftState
end

-- A new run: per-shift bookkeeping and attempts start empty.
function ShiftAnalyticsSystem.beginShift()
	tracker:beginShift()
	salvage:clear()
end

function ShiftAnalyticsSystem.elapsed(): number
	local state = shiftState
	local startedAt = if state ~= nil then state.startedAt else nil
	if startedAt == nil then
		return 0
	end
	return math.max(0, Workspace:GetServerTimeNow() - startedAt)
end

function ShiftAnalyticsSystem.quotaTag(): string
	local state = shiftState
	return ShiftAnalyticsUtils.quotaTag(state ~= nil and state.quotaMet)
end

function ShiftAnalyticsSystem.sinceQuota(): number
	local at = tracker:quotaAt()
	if at == nil then
		return 0
	end
	return math.max(0, ShiftAnalyticsSystem.elapsed() - at)
end

--[=[
	optional_salvage_attempted for each closed attempt whose player is still here.
]=]
function ShiftAnalyticsSystem.closeAttempts(attempts: { ShiftSalvageTracker.Attempt })
	for _, attempt in attempts do
		local player = Players:GetPlayerByUserId(attempt.userId)
		if player ~= nil then
			local outcome = attempt.outcome or "unbanked"
			local banked = outcome == "banked"
			ShiftAnalyticsSystem.emit("optional_salvage_attempted", player, {
				target = `{attempt.kind}:{attempt.source}`,
				outcome = if banked then "banked" else "failed",
				reason = if banked then nil else outcome,
				value = attempt.sinceQuota,
			})
		end
	end
end

--[=[
	A Load (ShiftBankingSystem, after the counters moved): cargo_banked per item (salvage at the credited value), then
	the loader's attempts for the banked salvage kinds close as banked.
]=]
function ShiftAnalyticsSystem.banked(player: Player, deposit: CargoTypes.Deposit, multiplier: number)
	local tag = ShiftAnalyticsSystem.quotaTag()
	local salvageKinds: { string } = {}
	for _, item in deposit.items do
		ShiftAnalyticsSystem.emit("cargo_banked", player, {
			target = item.kind,
			outcome = tag,
			value = ShiftAnalyticsUtils.credited(item.category, item.value, multiplier),
		})
		if item.category == "salvage" then
			table.insert(salvageKinds, item.kind)
		end
	end
	ShiftAnalyticsSystem.closeAttempts(salvage:resolveBanked(player.UserId, salvageKinds))
end

function ShiftAnalyticsSystem.listen(listener: (Record) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index ~= nil then
			table.remove(listeners, index)
		end
	end
end

function ShiftAnalyticsSystem.recent(): { Record }
	return tracker:recent()
end

-- The platform report: rate-limited, parsed from the fixed enum, first valid report wins.
local onPlatform = RequestHandler.wrap({
	name = "ShiftPlatform",
	rateLimit = { maxRequests = 3, windowSeconds = 10 },
	validate = function(data: number, _player: Player): (boolean, string?, ShiftTypes.Platform?)
		local platform: ShiftTypes.Platform? = ShiftPlatformRules.parse(data)
		if platform == nil then
			return false, "unknown platform", nil
		end
		return true, nil, platform
	end,
	handler = function(_data: number, player: Player, platform: ShiftTypes.Platform?)
		if platform ~= nil and tracker:setPlatform(player.UserId, platform) then
			log:debug(`platform {platform} reported`)
		end
	end,
})

--[=[
	Takes platform reports; a leaving player's open attempts close as "left" and their bookkeeping is forgotten.
]=]
function ShiftAnalyticsSystem.start()
	table.insert(
		stoppers,
		ShiftEvents.packets.Platform.listen(function(data: number, player: Player?)
			if player then
				onPlatform(data, player)
			end
		end)
	)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		ShiftAnalyticsSystem.closeAttempts(salvage:resolvePlayer(player.UserId, "left"))
		tracker:forget(player.UserId)
	end)
	table.insert(stoppers, function()
		leaving:Disconnect()
	end)
end

function ShiftAnalyticsSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	shiftState = nil
end

function ShiftAnalyticsSystem.getState(): { [string]: string | number }
	return {
		session = session,
		build = build,
		variant = variant,
		variantSource = variantSource,
		sent = counters.sent,
		unknown = counters.unknown,
		openAttempts = salvage:openCount(),
		recent = #tracker:recent(),
	}
end

return ShiftAnalyticsSystem
```

If luau-lsp does not narrow `scope` to `Player` inside `if typeof(scope) == "Instance" then`, report it (no cast); the fallback is `if scope ~= "crew" then` with the same body.

- [ ] **Step 2: Write the watch (shift events)** `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau`:

```lua
--!strict
--[=[
	ShiftAnalyticsWatchSystem: turns what the features already announce into Cleanup Crew's analytics events (spec
	§6.6), so no feature carries analytics code and no service near the line cap grows. Every event goes out through
	ShiftAnalyticsSystem.emit; banking's events are ShiftBankingSystem's (ShiftAnalyticsSystem.banked).

	- Shift `changed`: contract_started when a run starts (target = how the variant was chosen), replay_started when
	  that run is not the server's first (an Another shift), quota_met when the quota is met;
	- Round `runEnded`: open optional-salvage attempts close as "unbanked", then shift_ended for each crew member (value
	  = their attempts this shift, target = their cleaning bucket, outcome = how the run ended : whether the quota was
	  met).

	Spec-exempt shell (signals); the decisions are the specced ShiftAnalyticsUtils, ShiftAnalyticsTracker and
	ShiftSalvageTracker.

	@class ShiftAnalyticsWatchSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
local ShiftAnalyticsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftAnalyticsUtils)

-- The last shift state seen (the `changed` copies arrive in order).
local before: ShiftTypes.ShiftState? = nil

local function onChanged(state: ShiftTypes.ShiftState)
	local previous = before
	before = state
	ShiftAnalyticsSystem.setShift(state)
	if state.phase ~= "running" then
		return
	end
	if previous == nil or previous.phase ~= "running" then
		ShiftAnalyticsSystem.beginShift()
		local replay = state.shift > 1
		ShiftAnalyticsSystem.emit("contract_started", "crew", {
			target = ShiftAnalyticsSystem.variantSource(),
			outcome = if replay then "replay" else "first",
			value = state.shift,
		})
		if replay then
			ShiftAnalyticsSystem.emit("replay_started", "crew", {
				target = "another_shift",
				outcome = "same_server",
				value = state.shift,
			})
		end
	elseif previous ~= nil and state.quotaMet and not previous.quotaMet then
		local at = ShiftAnalyticsSystem.elapsed()
		ShiftAnalyticsSystem.tracker:markQuota(at)
		ShiftAnalyticsSystem.emit("quota_met", "crew", { target = "clearance", outcome = "met", value = at })
	end
end

local function onRunEnded(outcome: string)
	ShiftAnalyticsSystem.closeAttempts(ShiftAnalyticsSystem.salvage:resolveAll("unbanked"))
	local state = ShiftAnalyticsSystem.shift()
	local reason = if state ~= nil and state.quotaMet then "quota_met" else "quota_missed"
	for _, player in ShiftAnalyticsSystem.crew() do
		ShiftAnalyticsSystem.emit("shift_ended", player, {
			target = ShiftAnalyticsUtils.pileBucket(ShiftAnalyticsSystem.tracker:pilesOf(player.UserId)),
			outcome = outcome,
			reason = reason,
			value = ShiftAnalyticsSystem.salvage:attemptsBy(player.UserId),
		})
	end
end

local ShiftAnalyticsWatchSystem = {}

--[=[
	Starts ShiftAnalyticsSystem and subscribes to the features. Returns the function that undoes both.
]=]
function ShiftAnalyticsWatchSystem.start(changed: SignalTyped.Signal<ShiftTypes.ShiftState>): () -> ()
	ShiftAnalyticsSystem.start()
	local stops: { () -> () } = {}
	local function keep(stop: () -> ())
		table.insert(stops, stop)
	end
	local shiftChanged = changed:Connect(onChanged)
	keep(function()
		shiftChanged:Disconnect()
	end)
	local ended = RoundServiceServer.runEnded:Connect(onRunEnded)
	keep(function()
		ended:Disconnect()
	end)
	return function()
		for _, stop in stops do
			stop()
		end
		before = nil
		ShiftAnalyticsSystem.stop()
	end
end

return ShiftAnalyticsWatchSystem
```

- [ ] **Step 3: cargo_banked from the banking handler.** In `src/ServerScriptService/Features/Shift/Systems/ShiftBankingSystem.luau`:
  1. Requires: after `local ShiftRosterTracker = require(ServerScriptService.Features.Shift.State.ShiftRosterTracker)` add `local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)` (two requires from `ServerScriptService.Features.Shift` stay full addresses; if M3 left a third there, introduce `local ShiftServer = ServerScriptService.Features.Shift` and require all of them through it, project-structure rule 7).
  2. Directly **before** the line `guarded("banking follow-up", deps.afterBank)` insert:
     ```lua
     		-- Analytics (M5): cargo_banked per item, at the quota tag before this Load; closes the loader's attempts.
     		guarded("banking analytics", function()
     			ShiftAnalyticsSystem.banked(player, deposit, multiplier)
     		end)
     ```
     (`multiplier` is the local the handler already computed with `deps.multiplier()`.)
  3. Header: add the sentence "Each accepted Load is reported to ShiftAnalyticsSystem (cargo_banked, optional-salvage attempts)."

- [ ] **Step 4: Wire the service.** In `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`:
  1. Requires: after `local ShiftVoteReceiver = require(ShiftServer.Net.ShiftVoteReceiver)` (Task 6) add
     ```lua
     local ShiftAnalyticsSystem = require(ShiftServer.Systems.ShiftAnalyticsSystem)
     local ShiftAnalyticsWatchSystem = require(ShiftServer.Systems.ShiftAnalyticsWatchSystem)
     ```
  2. In `onRoundPhase`, directly before the line `	setState(nextState)` that is followed by `if nextState.phase == "running" and before ~= "running" then` / `beginRun()`, insert:
     ```lua
     	if nextState.phase == "running" and before ~= "running" then
     		-- Each run's A/B variant (spec §4; rewards never read it), chosen before anyone hears of the run.
     		nextState.variant = ShiftAnalyticsSystem.pickVariant(nextState.shift)
     	end
     ```
  3. In `start`, directly after `CargoServiceServer:onBanked(onBanked)`, add `table.insert(stoppers, ShiftAnalyticsWatchSystem.start(changed))`.
  4. Header: add the bullet `- analytics and the A/B variant (M5): each run's variant comes from ShiftAnalyticsSystem.pickVariant; ShiftAnalyticsWatchSystem turns the shift's and the other features' signals into the spec §6.6 events;`.
  5. Check the cap:
     ```bash
     python3 -c "import sys; sys.path.insert(0,'scripts/python'); import check_file_length as c; print(c.count_code_lines(open('src/ServerScriptService/Features/Shift/ShiftServiceServer.luau',encoding='utf8').read()))"
     ```
     Expected ≤ 400. If it is over, stop and report the number (do not compress code to fit).

- [ ] **Step 5: Exempt the two systems.** In `src/ServerScriptService/Core/Testing/SpecRoots.luau`, after the `ShiftVoteReceiver` line (Task 6), insert:

```lua
	["ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem"] = "AnalyticsService/Players/ByteNet/Workspace shell (payloads, tokens, variant, platform and attempts are specced)",
	["ServerScriptService.Features.Shift.Systems.ShiftAnalyticsWatchSystem"] = "signal/attribute subscription shell (every decision is specced in ShiftAnalyticsUtils and the trackers)",
```

- [ ] **Step 6: Controller: Studio TestEZ.** Expected: everything green (no new specs; `assertAllModulesSpecced` passes with the two exemptions).

- [ ] **Step 7: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsSystem.luau src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau src/ServerScriptService/Features/Shift/Systems/ShiftBankingSystem.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): analytics door, shift and banking events, per-shift variant"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 8: The Studio test sink.** For Steps 9 (and Tasks 8-10), before pressing Play the controller injects a temporary server `Script` in ServerScriptService:

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local A = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
_G.A = A
_G.S = require(ServerScriptService.Features.Shift.ShiftServiceServer)
_G.R = require(ServerScriptService.Features.Round.RoundServiceServer)
A.listen(function(r)
	print("[M5]", r.event, r.target, r.outcome, r.reason, r.value, r.variant, r.platform, r.party, r.build, r.session)
end)
```
Lines read: event, target, outcome, reason, value, variant, platform, party, build, session.

- [ ] **Step 9: Studio verification checklist** (controller; Play Solo, `RunTests = false`, the sink injected; start shifts through M4's Studio loop: board a truck, depart):
1. Server Output: `shift 1: variant B (alternate), session studio, build m5-dev` at info, then `[M5] contract_started alternate first none 1 B pc 1 m5-dev studio` (platform `unknown` instead of `pc` is acceptable only if the shift starts within 2 s of joining; it must read `pc` by the next event).
2. Bank a rubbish bag: `[M5] cargo_banked rubbishBag before_quota none 10 B pc 1 …`. Then `_G.R:addTeam("clearance", 340)` in the server command bar and bank another bag: `[M5] cargo_banked … before_quota …` followed by `[M5] quota_met clearance met none <seconds> …`.
3. **Platform spoof:** inject a client LocalScript running `require(game.ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents).packets.Platform.send(9)` and then `.send(2)`: later records still read `pc` (9 is dropped; the second valid report is ignored).
4. **Override:** in the server command bar run `workspace:SetAttribute("CleanupCrewVariant", "A")`, clock out, vote Another shift: `shift 2: variant A (override)`, `[M5] contract_started override replay none 2 A …` and `[M5] replay_started another_shift same_server none 2 A …`. Clear it with `workspace:SetAttribute("CleanupCrewVariant", nil)`; the next Another shift logs `shift 3: variant B (alternate)` (shift 3 of the Studio session starts on B).
5. Clock out of a shift with the quota met: `[M5] shift_ended piles_0 clockout quota_met 0 …` (reason column `quota_met`; field 3 in AnalyticsService is `clockout:quota_met`). A timeout shows `timeout`.
6. Variant A shift (from item 4): no salvage spawns under piles (vacuum a few piles: nothing is revealed); variant B shifts reveal some. Item values on labels are identical in both.
7. `print(require(game.ServerScriptService.Features.Analytics.AnalyticsServiceServer):getState().skipped)` in the server command bar grows with every record: nothing was sent from Studio.
8. `_G.A.getState()` shows `unknown = 0` and `sent` equal to the number of `[M5]` lines.

---

### Task 8: Crew-action events (cleanup, piles, pick-ups, drops) and the optional-salvage attempt

**Files:**
- Modify: `src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau` (a `vacuumStarted` signal)
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau` (one key)
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau` (one optional field)
- Modify: `src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau` (stamp the source)
- Modify: `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau` (one existing call: searched items are `"desk"`)
- Modify: `src/ServerScriptService/Features/Cargo/Systems/CargoPocketSystem.luau` (one existing call: scattered items are `"scatter"`)
- Modify (replace whole file): `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau`

**Interfaces:**
- Consumes: Task 7 (`ShiftAnalyticsSystem.*`); `CarryServiceServer.pickedUp: Signal<Player, Instance>`, `CarryServiceServer.dropped: Signal<Player, Instance, DropReason>` (`"drop" | "throw" | "forced" | "death" | "removed" | "destroyed"`); `VacuumServiceServer.pileCleared: Signal<BasePart, { Player }>` (fired after the pile is destroyed; its attributes are still readable); `VacuumConstants.PILE_KIND_ATTRIBUTE = "PileKind"`; `CarryConstants.KIND_ATTRIBUTE = "CarryKind"`; `CargoConstants.ID_ATTRIBUTE = "CargoId"`, `VALUE_ATTRIBUTE = "CargoValue"`; `CargoRegistry.has / get`; `OfficeServiceServer:safeZone() -> (Vector3, Vector3)` (M2: the loading bay's world min/max).
- Produces (VacuumServiceServer): `vacuumStarted: SignalTyped.Signal<Player, BasePart>`: fired when a player's allowed channel lands on a pile they were not already vacuuming (Interaction asks `canChannel` at the start and every tick; the first allowed ask on a new pile is the start).
- Produces (CargoConstants): `SOURCE_ATTRIBUTE = "CargoSource"`. (CargoTypes): `SpawnOptions.source: string?`. (CargoSpawnSystem): every spawned item carries `CargoSource` = `options.source`, else `"pile"` when hidden, else `"open"`.
- Produces (ShiftAnalyticsWatchSystem): also emits `first_cleanup_started`, `pile_cleared`, `cargo_picked_up`, `cargo_dropped`; opens optional-salvage attempts on qualifying pick-ups and closes them on drops.

- [ ] **Step 1: The vacuum start signal.** In `src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau`:
  1. After `local noiseMade: SignalTyped.Signal<Vector3, number, string> = SignalTyped.new()` add
     ```lua
     local vacuumStarted: SignalTyped.Signal<Player, BasePart> = SignalTyped.new()
     ```
  2. After `local fills: { [number]: number } = {}` add
     ```lua
     -- The pile each player was last allowed to vacuum (vacuumStarted fires when it changes).
     local vacuuming: { [number]: Instance } = {}
     ```
  3. Replace the channel's `canChannel`
     ```lua
     			canChannel = function(player, _target)
     				return CarryServiceServer:getCarried(player) == nil
     			end,
     ```
     with
     ```lua
     			canChannel = function(player, target)
     				if CarryServiceServer:getCarried(player) ~= nil then
     					return false
     				end
     				-- Asked at the start and every tick: the first allowed ask on a new pile is a start (never yields).
     				if vacuuming[player.UserId] ~= target and target:IsA("BasePart") then
     					vacuuming[player.UserId] = target
     					vacuumStarted:Fire(player, target)
     				end
     				return true
     			end,
     ```
  4. In the `PlayerRemoving` handler, after `fills[player.UserId] = nil` add `vacuuming[player.UserId] = nil`. In `reset`, after `table.clear(fills)` add `table.clear(vacuuming)`.
  5. In `export type VacuumServiceServer`, after `noiseMade: SignalTyped.Signal<Vector3, number, string>,` add `vacuumStarted: SignalTyped.Signal<Player, BasePart>,`. In the literal, after `noiseMade = noiseMade,` add `vacuumStarted = vacuumStarted,`.
  6. Header: after the `pileCleared` bullet add `- fires \`vacuumStarted(player, pile)\` when a player starts vacuuming a pile (Shift's analytics: first_cleanup_started);`.

- [ ] **Step 2: Where an item came from.**
  1. `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`: after the line `	HIDDEN_ATTRIBUTE = "CargoHidden",` add
     ```lua
     	-- Where an item came from, for analytics: "open", "pile" (uncovered by vacuuming), "desk" (searched), "scatter".
     	SOURCE_ATTRIBUTE = "CargoSource",
     ```
  2. `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau`: in `export type SpawnOptions`, after `	value: number?,` add
     ```lua
     	-- Where it came from, for analytics: "desk" (searched) or "scatter" (a caught or leaving player's pockets);
     	-- absent = "pile" when hidden, else "open".
     	source: string?,
     ```
  3. `src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau`: in `spawn`, after `part:SetAttribute(CargoConstants.IMPACTS_ATTRIBUTE, 0)` add
     ```lua
     			local source = if options ~= nil and options.source ~= nil then options.source elseif hidden then "pile" else "open"
     			part:SetAttribute(CargoConstants.SOURCE_ATTRIBUTE, source)
     ```
  4. `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau`: change the search's `spawner:spawn(kind, front, parent)` to `spawner:spawn(kind, front, parent, { source = "desk" })` (one existing line; no new line).
  5. `src/ServerScriptService/Features/Cargo/Systems/CargoPocketSystem.luau`: change `{ value = entry.value }` to `{ value = entry.value, source = "scatter" }`.
  6. Check Cargo's cap is untouched:
     ```bash
     python3 -c "import sys; sys.path.insert(0,'scripts/python'); import check_file_length as c; print(c.count_code_lines(open('src/ServerScriptService/Features/Cargo/CargoServiceServer.luau',encoding='utf8').read()))"
     ```
     Expected: the same number as Task 0 Step 4 (stylua may wrap the call; if that adds a line and the file goes over 400, stop and report).

- [ ] **Step 3: Replace the watch** `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau` with:

```lua
--!strict
--[=[
	ShiftAnalyticsWatchSystem: turns what the features already announce into Cleanup Crew's analytics events (spec
	§6.6), so no feature carries analytics code and no service near the line cap grows. Every event goes out through
	ShiftAnalyticsSystem.emit; banking's events are ShiftBankingSystem's (ShiftAnalyticsSystem.banked).

	- Shift `changed`: contract_started when a run starts (target = how the variant was chosen), replay_started when
	  that run is not the server's first (an Another shift), quota_met when the quota is met;
	- Round `runEnded`: open optional-salvage attempts close as "unbanked", then shift_ended for each crew member (value
	  = their attempts this shift, target = their cleaning bucket, outcome = how the run ended : whether the quota was
	  met);
	- Vacuum `vacuumStarted`: first_cleanup_started (once per player per shift); `pileCleared`: pile_cleared for each
	  player on the pile (and their cleaning count);
	- Carry `pickedUp`: cargo_picked_up, and an optional-salvage attempt opens when ShiftAnalyticsUtils.isSalvageAttempt
	  says so (after the quota, outside the loading bay); `dropped`: the item's attempt closes (dropped / thrown /
	  caught / left) and cargo_dropped is sent. Pocketing, banking and resets ("forced", "destroyed") are not drops.
	Gameplay events count only while the shift is running.

	Spec-exempt shell (signals, attributes); the decisions are the specced ShiftAnalyticsUtils, ShiftAnalyticsTracker
	and ShiftSalvageTracker.

	@class ShiftAnalyticsWatchSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
local ShiftAnalyticsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftAnalyticsUtils)

-- The last shift state seen (the `changed` copies arrive in order).
local before: ShiftTypes.ShiftState? = nil

local function running(): boolean
	local state = ShiftAnalyticsSystem.shift()
	return state ~= nil and state.phase == "running"
end

-- A cargo part's kind (nil for anything that is not cargo), where it came from, and its value now.
local function cargoOf(object: Instance): (string?, string, number)
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	if type(kind) ~= "string" or not CargoRegistry.has(kind) then
		return nil, "open", 0
	end
	local source = object:GetAttribute(CargoConstants.SOURCE_ATTRIBUTE)
	local value = object:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)
	return kind, if type(source) == "string" then source else "open", if type(value) == "number" then value else 0
end

local function itemIdOf(object: Instance): number?
	local id = object:GetAttribute(CargoConstants.ID_ATTRIBUTE)
	return if type(id) == "number" then id else nil
end

local function pileKindOf(pile: Instance): string
	local kind = pile:GetAttribute(VacuumConstants.PILE_KIND_ATTRIBUTE)
	return if type(kind) == "string" then kind else "unknown"
end

-- Standing in the loading bay (Mr. Harlow's safe zone)?
local function inBay(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local low, high = OfficeServiceServer:safeZone()
	return ShiftAnalyticsUtils.inBox(root.Position, low, high)
end

local function onChanged(state: ShiftTypes.ShiftState)
	local previous = before
	before = state
	ShiftAnalyticsSystem.setShift(state)
	if state.phase ~= "running" then
		return
	end
	if previous == nil or previous.phase ~= "running" then
		ShiftAnalyticsSystem.beginShift()
		local replay = state.shift > 1
		ShiftAnalyticsSystem.emit("contract_started", "crew", {
			target = ShiftAnalyticsSystem.variantSource(),
			outcome = if replay then "replay" else "first",
			value = state.shift,
		})
		if replay then
			ShiftAnalyticsSystem.emit("replay_started", "crew", {
				target = "another_shift",
				outcome = "same_server",
				value = state.shift,
			})
		end
	elseif previous ~= nil and state.quotaMet and not previous.quotaMet then
		local at = ShiftAnalyticsSystem.elapsed()
		ShiftAnalyticsSystem.tracker:markQuota(at)
		ShiftAnalyticsSystem.emit("quota_met", "crew", { target = "clearance", outcome = "met", value = at })
	end
end

local function onRunEnded(outcome: string)
	ShiftAnalyticsSystem.closeAttempts(ShiftAnalyticsSystem.salvage:resolveAll("unbanked"))
	local state = ShiftAnalyticsSystem.shift()
	local reason = if state ~= nil and state.quotaMet then "quota_met" else "quota_missed"
	for _, player in ShiftAnalyticsSystem.crew() do
		ShiftAnalyticsSystem.emit("shift_ended", player, {
			target = ShiftAnalyticsUtils.pileBucket(ShiftAnalyticsSystem.tracker:pilesOf(player.UserId)),
			outcome = outcome,
			reason = reason,
			value = ShiftAnalyticsSystem.salvage:attemptsBy(player.UserId),
		})
	end
end

local function onVacuumStarted(player: Player, pile: BasePart)
	if not running() or not ShiftAnalyticsSystem.tracker:firstCleanup(player.UserId) then
		return
	end
	ShiftAnalyticsSystem.emit("first_cleanup_started", player, {
		target = pileKindOf(pile),
		outcome = ShiftAnalyticsSystem.quotaTag(),
		value = ShiftAnalyticsSystem.elapsed(),
	})
end

local function onPileCleared(pile: BasePart, players: { Player })
	if not running() then
		return
	end
	local kind = pileKindOf(pile)
	local outcome = if #players > 1 then "shared" else "solo"
	for _, player in players do
		ShiftAnalyticsSystem.tracker:addPile(player.UserId)
		ShiftAnalyticsSystem.emit("pile_cleared", player, {
			target = kind,
			outcome = outcome,
			value = ShiftAnalyticsSystem.elapsed(),
		})
	end
end

local function onPickedUp(player: Player, object: Instance)
	if not running() then
		return
	end
	local kind, source, value = cargoOf(object)
	if kind == nil then
		return
	end
	ShiftAnalyticsSystem.emit("cargo_picked_up", player, {
		target = `{kind}:{source}`,
		outcome = ShiftAnalyticsSystem.quotaTag(),
		value = value,
	})
	local def = CargoRegistry.get(kind)
	local state = ShiftAnalyticsSystem.shift()
	local id = itemIdOf(object)
	if def == nil or state == nil or id == nil then
		return
	end
	local attempt = ShiftAnalyticsUtils.isSalvageAttempt({
		category = def.category,
		phase = state.phase,
		sub = state.sub,
		quotaMet = state.quotaMet,
		inBay = inBay(player),
	})
	if attempt then
		ShiftAnalyticsSystem.salvage:open(id, player.UserId, kind, source, ShiftAnalyticsSystem.sinceQuota())
	end
end

local function onDropped(player: Player, object: Instance, reason: string)
	local outcome = ShiftAnalyticsUtils.dropOutcome(reason)
	if outcome == nil then
		return
	end
	local id = itemIdOf(object)
	if id ~= nil then
		local closed = ShiftAnalyticsSystem.salvage:resolveItem(id, outcome)
		if closed ~= nil then
			ShiftAnalyticsSystem.closeAttempts({ closed })
		end
	end
	if not running() then
		return
	end
	local kind, source, value = cargoOf(object)
	if kind == nil then
		return
	end
	ShiftAnalyticsSystem.emit("cargo_dropped", player, { target = `{kind}:{source}`, outcome = outcome, value = value })
end

local ShiftAnalyticsWatchSystem = {}

--[=[
	Starts ShiftAnalyticsSystem and subscribes to the features. Returns the function that undoes both.
]=]
function ShiftAnalyticsWatchSystem.start(changed: SignalTyped.Signal<ShiftTypes.ShiftState>): () -> ()
	ShiftAnalyticsSystem.start()
	local stops: { () -> () } = {}
	local function keep(stop: () -> ())
		table.insert(stops, stop)
	end
	local shiftChanged = changed:Connect(onChanged)
	keep(function()
		shiftChanged:Disconnect()
	end)
	local ended = RoundServiceServer.runEnded:Connect(onRunEnded)
	keep(function()
		ended:Disconnect()
	end)
	local started = VacuumServiceServer.vacuumStarted:Connect(onVacuumStarted)
	keep(function()
		started:Disconnect()
	end)
	local cleared = VacuumServiceServer.pileCleared:Connect(onPileCleared)
	keep(function()
		cleared:Disconnect()
	end)
	local picked = CarryServiceServer.pickedUp:Connect(onPickedUp)
	keep(function()
		picked:Disconnect()
	end)
	local dropped = CarryServiceServer.dropped:Connect(onDropped)
	keep(function()
		dropped:Disconnect()
	end)
	return function()
		for _, stop in stops do
			stop()
		end
		before = nil
		ShiftAnalyticsSystem.stop()
	end
end

return ShiftAnalyticsWatchSystem
```

If luau-lsp rejects `onDropped` as the listener of a `Signal<Player, Instance, CarryTypes.DropReason>` (a `string` parameter accepting the narrower `DropReason` should pass), change the parameter to `reason: CarryTypes.DropReason` with `local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)`; no cast.

- [ ] **Step 4: Controller: Studio TestEZ.** Expected: everything green (Vacuum, Cargo and Office specs unchanged and passing).

- [ ] **Step 5: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau src/ServerScriptService/Features/Cargo/CargoServiceServer.luau src/ServerScriptService/Features/Cargo/Systems/CargoPocketSystem.luau src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): cleanup, pile, pick-up and drop events; optional-salvage attempts"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 6: Studio verification checklist** (controller; Play Solo, `RunTests = false`, Task 7's sink injected; a variant B shift through M4's Studio loop):
1. Start vacuuming a pile: one `[M5] first_cleanup_started paper|debris|cables before_quota none <s> …`; release and resume on another pile: no second one this shift. Finish the pile: `[M5] pile_cleared <kind> solo none <s> …`.
2. Pick up a rubbish bag: `[M5] cargo_picked_up rubbishBag:open before_quota none 10 …`; drop it (G): `[M5] cargo_dropped rubbishBag:open dropped none 10 …`; throw it (F): `… thrown …`. Pocket a plaque (Q): no `cargo_dropped` line (pocketing is "forced"). Bank: no drop line.
3. Vacuum piles until a hidden item is revealed; pick it up: target ends in `:pile`. Search a desk until it yields an item; pick it up: target ends in `:desk`. A dust bag reads `dustBag:open`.
4. **An attempt, banked:** `_G.R:addTeam("clearance", 345)`, bank a trash item (quota met). Walk out of the loading bay, pick up a salvage item: no `optional_salvage_attempted` yet (it is sent on close); `_G.A.getState().openAttempts` is 1. Carry it into the truck bed and Load: `[M5] cargo_banked <kind> after_quota none <value> …` then `[M5] optional_salvage_attempted <kind>:<source> banked none <s since quota> …`; `openAttempts` is 0.
5. **Pockets never duplicate:** after the quota, outside the bay, pick up a plaque (attempt 1 opens), pocket it, take it back out with swap (X), drop it (G): exactly one `[M5] optional_salvage_attempted plaque:… failed dropped …`. Pick it up again outside the bay and bank it: one more, `banked`. Clock out: `[M5] shift_ended <bucket> clockout quota_met 2 …` (value 2).
6. A salvage item picked up **inside** the loading bay after the quota opens no attempt (`openAttempts` stays 0); one picked up **before** the quota opens none either.
7. Hold an after-quota salvage item when the clock-out countdown ends: `[M5] optional_salvage_attempted … failed unbanked …` before `[M5] shift_ended …`.

---

### Task 9: Mr. Harlow's events (investigations, chases, catches)

**Files:**
- Modify (replace whole file): `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau`

**Interfaces:**
- Consumes: Task 8's watch; `DeathServiceServer.died: Signal<Player, DeathTypes.DeathInfo>` (`info.cause`; Harlow's catch kills with cause `"caught"`, `ShiftAnalyticsConstants.CATCH_CAUSE`); `NoiseServiceServer.made: Signal<NoiseTypes.NoiseEvent>` (`{ position, radius, source }`) and `NoiseServiceServer:getHearingScale() -> number`; Harlow's model tagged `OccupantConstants.TAG` with string attribute `MODE_ATTRIBUTE` (`patrol | investigate | chase | search | rest | catch`) and number attribute `TARGET_ATTRIBUTE` (a UserId; 0 = nobody), set together by `OccupantRigSystem.setMode`; `Observers.observeTag(tag, fn) -> () -> ()`; `CarryServiceServer:getCarried(player) -> Instance?`.
- Produces (ShiftAnalyticsWatchSystem): also emits `noise_investigation` (crew; target = the noise he most likely heard), `chase_started` (the chased player; target = what they hold or `empty`), `player_caught` (that player), and closes the caught player's open attempts as `caught`. The watch never requires `OccupantServiceServer` (Occupant requires Shift; reading the replicated attributes avoids the cycle).

- [ ] **Step 1: Replace the watch** `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau` with the final version:

```lua
--!strict
--[=[
	ShiftAnalyticsWatchSystem: turns what the features already announce into Cleanup Crew's analytics events (spec
	§6.6), so no feature carries analytics code and no service near the line cap grows. Every event goes out through
	ShiftAnalyticsSystem.emit; banking's events are ShiftBankingSystem's (ShiftAnalyticsSystem.banked).

	- Shift `changed`: contract_started when a run starts (target = how the variant was chosen), replay_started when
	  that run is not the server's first (an Another shift), quota_met when the quota is met;
	- Round `runEnded`: open optional-salvage attempts close as "unbanked", then shift_ended for each crew member (value
	  = their attempts this shift, target = their cleaning bucket, outcome = how the run ended : whether the quota was
	  met);
	- Vacuum `vacuumStarted`: first_cleanup_started (once per player per shift); `pileCleared`: pile_cleared for each
	  player on the pile (and their cleaning count);
	- Carry `pickedUp`: cargo_picked_up, and an optional-salvage attempt opens when ShiftAnalyticsUtils.isSalvageAttempt
	  says so (after the quota, outside the loading bay); `dropped`: the item's attempt closes (dropped / thrown /
	  caught / left) and cargo_dropped is sent. Pocketing, banking and resets ("forced", "destroyed") are not drops;
	- Death `died` with Harlow's cause: the player's open attempts close as "caught", then player_caught;
	- Mr. Harlow's mode/target attributes (the `Occupant` tag; read, never required, since Occupant requires Shift):
	  noise_investigation for the crew, with the noise he most likely heard (Noise `made`, kept a few seconds), and
	  chase_started for the chased player, with what they hold.
	Gameplay events count only while the shift is running.

	Spec-exempt shell (signals, attributes, CollectionService); the decisions are the specced ShiftAnalyticsUtils,
	ShiftAnalyticsTracker and ShiftSalvageTracker.

	@class ShiftAnalyticsWatchSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftServer = ServerScriptService.Features.Shift
local Observers = require(ReplicatedStorage.Packages.Observers)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathTypes = require(ReplicatedStorage.Shared.Features.Death.Data.DeathTypes)
local NoiseTypes = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local ShiftAnalyticsConstants = require(ShiftServer.Data.ShiftAnalyticsConstants)
local ShiftAnalyticsSystem = require(ShiftServer.Systems.ShiftAnalyticsSystem)
local ShiftAnalyticsUtils = require(ShiftServer.Utils.ShiftAnalyticsUtils)

-- The last shift state seen (the `changed` copies arrive in order).
local before: ShiftTypes.ShiftState? = nil
-- Mr. Harlow's last mode and target (nil until his model is seen).
local harlow: ShiftAnalyticsUtils.Harlow? = nil

local function running(): boolean
	local state = ShiftAnalyticsSystem.shift()
	return state ~= nil and state.phase == "running"
end

-- A cargo part's kind (nil for anything that is not cargo), where it came from, and its value now.
local function cargoOf(object: Instance): (string?, string, number)
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	if type(kind) ~= "string" or not CargoRegistry.has(kind) then
		return nil, "open", 0
	end
	local source = object:GetAttribute(CargoConstants.SOURCE_ATTRIBUTE)
	local value = object:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)
	return kind, if type(source) == "string" then source else "open", if type(value) == "number" then value else 0
end

local function itemIdOf(object: Instance): number?
	local id = object:GetAttribute(CargoConstants.ID_ATTRIBUTE)
	return if type(id) == "number" then id else nil
end

local function pileKindOf(pile: Instance): string
	local kind = pile:GetAttribute(VacuumConstants.PILE_KIND_ATTRIBUTE)
	return if type(kind) == "string" then kind else "unknown"
end

-- Standing in the loading bay (Mr. Harlow's safe zone)?
local function inBay(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local low, high = OfficeServiceServer:safeZone()
	return ShiftAnalyticsUtils.inBox(root.Position, low, high)
end

-- The kind in a player's hands, or "empty".
local function held(player: Player): string
	local carried = CarryServiceServer:getCarried(player)
	local kind = if carried ~= nil then cargoOf(carried) else nil
	return kind or "empty"
end

local function onChanged(state: ShiftTypes.ShiftState)
	local previous = before
	before = state
	ShiftAnalyticsSystem.setShift(state)
	if state.phase ~= "running" then
		return
	end
	if previous == nil or previous.phase ~= "running" then
		ShiftAnalyticsSystem.beginShift()
		local replay = state.shift > 1
		ShiftAnalyticsSystem.emit("contract_started", "crew", {
			target = ShiftAnalyticsSystem.variantSource(),
			outcome = if replay then "replay" else "first",
			value = state.shift,
		})
		if replay then
			ShiftAnalyticsSystem.emit("replay_started", "crew", {
				target = "another_shift",
				outcome = "same_server",
				value = state.shift,
			})
		end
	elseif previous ~= nil and state.quotaMet and not previous.quotaMet then
		local at = ShiftAnalyticsSystem.elapsed()
		ShiftAnalyticsSystem.tracker:markQuota(at)
		ShiftAnalyticsSystem.emit("quota_met", "crew", { target = "clearance", outcome = "met", value = at })
	end
end

local function onRunEnded(outcome: string)
	ShiftAnalyticsSystem.closeAttempts(ShiftAnalyticsSystem.salvage:resolveAll("unbanked"))
	local state = ShiftAnalyticsSystem.shift()
	local reason = if state ~= nil and state.quotaMet then "quota_met" else "quota_missed"
	for _, player in ShiftAnalyticsSystem.crew() do
		ShiftAnalyticsSystem.emit("shift_ended", player, {
			target = ShiftAnalyticsUtils.pileBucket(ShiftAnalyticsSystem.tracker:pilesOf(player.UserId)),
			outcome = outcome,
			reason = reason,
			value = ShiftAnalyticsSystem.salvage:attemptsBy(player.UserId),
		})
	end
end

local function onVacuumStarted(player: Player, pile: BasePart)
	if not running() or not ShiftAnalyticsSystem.tracker:firstCleanup(player.UserId) then
		return
	end
	ShiftAnalyticsSystem.emit("first_cleanup_started", player, {
		target = pileKindOf(pile),
		outcome = ShiftAnalyticsSystem.quotaTag(),
		value = ShiftAnalyticsSystem.elapsed(),
	})
end

local function onPileCleared(pile: BasePart, players: { Player })
	if not running() then
		return
	end
	local kind = pileKindOf(pile)
	local outcome = if #players > 1 then "shared" else "solo"
	for _, player in players do
		ShiftAnalyticsSystem.tracker:addPile(player.UserId)
		ShiftAnalyticsSystem.emit("pile_cleared", player, {
			target = kind,
			outcome = outcome,
			value = ShiftAnalyticsSystem.elapsed(),
		})
	end
end

local function onPickedUp(player: Player, object: Instance)
	if not running() then
		return
	end
	local kind, source, value = cargoOf(object)
	if kind == nil then
		return
	end
	ShiftAnalyticsSystem.emit("cargo_picked_up", player, {
		target = `{kind}:{source}`,
		outcome = ShiftAnalyticsSystem.quotaTag(),
		value = value,
	})
	local def = CargoRegistry.get(kind)
	local state = ShiftAnalyticsSystem.shift()
	local id = itemIdOf(object)
	if def == nil or state == nil or id == nil then
		return
	end
	local attempt = ShiftAnalyticsUtils.isSalvageAttempt({
		category = def.category,
		phase = state.phase,
		sub = state.sub,
		quotaMet = state.quotaMet,
		inBay = inBay(player),
	})
	if attempt then
		ShiftAnalyticsSystem.salvage:open(id, player.UserId, kind, source, ShiftAnalyticsSystem.sinceQuota())
	end
end

local function onDropped(player: Player, object: Instance, reason: string)
	local outcome = ShiftAnalyticsUtils.dropOutcome(reason)
	if outcome == nil then
		return
	end
	local id = itemIdOf(object)
	if id ~= nil then
		local closed = ShiftAnalyticsSystem.salvage:resolveItem(id, outcome)
		if closed ~= nil then
			ShiftAnalyticsSystem.closeAttempts({ closed })
		end
	end
	if not running() then
		return
	end
	local kind, source, value = cargoOf(object)
	if kind == nil then
		return
	end
	ShiftAnalyticsSystem.emit("cargo_dropped", player, { target = `{kind}:{source}`, outcome = outcome, value = value })
end

local function onDied(player: Player, info: DeathTypes.DeathInfo)
	if info.cause ~= ShiftAnalyticsConstants.CATCH_CAUSE then
		return
	end
	ShiftAnalyticsSystem.closeAttempts(ShiftAnalyticsSystem.salvage:resolvePlayer(player.UserId, "caught"))
	if running() then
		ShiftAnalyticsSystem.emit("player_caught", player, {
			target = "harlow",
			outcome = ShiftAnalyticsSystem.quotaTag(),
			value = ShiftAnalyticsSystem.elapsed(),
		})
	end
end

local function onNoise(event: NoiseTypes.NoiseEvent)
	ShiftAnalyticsSystem.tracker:noteNoise({
		source = event.source,
		position = event.position,
		radius = event.radius,
		at = os.clock(),
	})
end

-- Reads Harlow's mode and target (OccupantRigSystem.setMode writes both) and sends what changed.
local function readHarlow(model: Instance)
	local mode = model:GetAttribute(OccupantConstants.MODE_ATTRIBUTE)
	local target = model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE)
	local now: ShiftAnalyticsUtils.Harlow = {
		mode = if type(mode) == "string" then mode else "patrol",
		target = if type(target) == "number" then target else 0,
	}
	local event = ShiftAnalyticsUtils.harlowChange(harlow, now)
	harlow = now
	if event == nil or not running() then
		return
	end
	if event == "noise_investigation" then
		local position = if model:IsA("PVInstance") then model:GetPivot().Position else Vector3.zero
		local scale = NoiseServiceServer:getHearingScale()
		ShiftAnalyticsSystem.emit("noise_investigation", "crew", {
			target = ShiftAnalyticsUtils.heardSource(ShiftAnalyticsSystem.tracker:noises(), position, scale, os.clock()),
			outcome = ShiftAnalyticsSystem.quotaTag(),
			value = ShiftAnalyticsSystem.elapsed(),
		})
		return
	end
	local victim = Players:GetPlayerByUserId(now.target)
	if victim ~= nil then
		ShiftAnalyticsSystem.emit("chase_started", victim, {
			target = held(victim),
			outcome = ShiftAnalyticsSystem.quotaTag(),
			value = ShiftAnalyticsSystem.elapsed(),
		})
	end
end

-- Follows one Harlow model; both attributes change together, so one deferred read covers both.
local function watchHarlow(model: Instance): () -> ()
	harlow = nil
	local pending = false
	local function schedule()
		if pending then
			return
		end
		pending = true
		task.defer(function()
			pending = false
			if model.Parent ~= nil then
				readHarlow(model)
			end
		end)
	end
	local modeChanged = model:GetAttributeChangedSignal(OccupantConstants.MODE_ATTRIBUTE):Connect(schedule)
	local targetChanged = model:GetAttributeChangedSignal(OccupantConstants.TARGET_ATTRIBUTE):Connect(schedule)
	return function()
		modeChanged:Disconnect()
		targetChanged:Disconnect()
		harlow = nil
	end
end

local ShiftAnalyticsWatchSystem = {}

--[=[
	Starts ShiftAnalyticsSystem and subscribes to the features. Returns the function that undoes both.
]=]
function ShiftAnalyticsWatchSystem.start(changed: SignalTyped.Signal<ShiftTypes.ShiftState>): () -> ()
	ShiftAnalyticsSystem.start()
	local stops: { () -> () } = {}
	local function keep(stop: () -> ())
		table.insert(stops, stop)
	end
	local shiftChanged = changed:Connect(onChanged)
	keep(function()
		shiftChanged:Disconnect()
	end)
	local ended = RoundServiceServer.runEnded:Connect(onRunEnded)
	keep(function()
		ended:Disconnect()
	end)
	local started = VacuumServiceServer.vacuumStarted:Connect(onVacuumStarted)
	keep(function()
		started:Disconnect()
	end)
	local cleared = VacuumServiceServer.pileCleared:Connect(onPileCleared)
	keep(function()
		cleared:Disconnect()
	end)
	local picked = CarryServiceServer.pickedUp:Connect(onPickedUp)
	keep(function()
		picked:Disconnect()
	end)
	local dropped = CarryServiceServer.dropped:Connect(onDropped)
	keep(function()
		dropped:Disconnect()
	end)
	local died = DeathServiceServer.died:Connect(onDied)
	keep(function()
		died:Disconnect()
	end)
	local noise = NoiseServiceServer.made:Connect(onNoise)
	keep(function()
		noise:Disconnect()
	end)
	keep(Observers.observeTag(OccupantConstants.TAG, watchHarlow))
	return function()
		for _, stop in stops do
			stop()
		end
		before = nil
		harlow = nil
		ShiftAnalyticsSystem.stop()
	end
end

return ShiftAnalyticsWatchSystem
```

If Task 8 had to type `onDropped`'s `reason` as `CarryTypes.DropReason`, keep that change here. If luau-lsp rejects `watchHarlow` as `observeTag`'s callback (VacuumServiceServer passes one returning `(() -> ())?`), keep the signature and report it; no cast.

- [ ] **Step 2: Check the cap.**

```bash
python3 scripts/python/check_file_length.py
```
Expected: no failure (the watch is about 270 code lines).

- [ ] **Step 3: Controller: Studio TestEZ.** Expected: everything green.

- [ ] **Step 4: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau
git add src
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): Harlow's investigation, chase and catch events"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 5: Studio verification checklist** (controller; Play Solo, `RunTests = false`, Task 7's sink injected; a shift through M4's Studio loop):
1. Vacuum within Harlow's hearing (out of sight): `[M5] noise_investigation vacuum before_quota none <s> …` once when the "?" appears; no repeat while he keeps investigating the same noise.
2. Drop a heavy item near him out of sight: the next investigation reads `drop`. (An investigation started more than 2 s after the noise reads `unknown`; that is expected.)
3. Let him see you empty-handed: `[M5] chase_started empty before_quota none <s> …` once per chase (not every tick). Get seen holding a printer: `chase_started printer …`.
4. **Caught with after-quota salvage in hand and in a pocket:** `_G.R:addTeam("clearance", 345)`, bank trash, walk out, pocket a plaque, pick up a monitor, let him catch you: exactly one `[M5] optional_salvage_attempted monitor:… failed caught …`, one `[M5] optional_salvage_attempted plaque:… failed caught …`, one `[M5] player_caught harlow after_quota none <s> …`; `[M5] cargo_dropped monitor:… caught …` may also appear; nothing twice.
5. Clock out: `[M5] shift_ended …` lists your attempt count as its value.
6. Another shift: the new Harlow is watched (step 1 works again in shift 2, with variant A logged for it).

---

### Task 10: Full-loop analytics playtest, the developer checklist doc, roadmap, PR update

**Files:**
- Create: `docs/cleanup-crew-m5-checklist.md`
- Modify: `docs/ROADMAP.md` (the Cleanup Crew row)
- (Module map: already current from each task.)

**Interfaces:** none new.

- [ ] **Step 1: Write the doc** `docs/cleanup-crew-m5-checklist.md`:

````markdown
# Cleanup Crew: M5 analytics, the A/B switch and the developer checklist

Spec: `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (§1, §4 variant switch, §6.4, §6.6, M5 row of §9).
Plan: `docs/superpowers/plans/2026-10-10-m5-cleanup-crew-analytics.md`.

## Where analytics go

- Every event goes through `ShiftAnalyticsSystem` (Shift, server) to the base `AnalyticsServiceServer:custom`, which
  calls Roblox's `AnalyticsService:LogCustomEvent`. **Nothing is sent from Studio** (Roblox accepts custom events from
  published games only); in Studio read the server log instead.
- Roblox dashboard: Creator Dashboard → the experience → Analytics → Custom events (Explore). Charts can take up to
  24 h to fill. Each event has three custom fields, used as breakdowns:
  - **field 1** `variant|platform|party|build`, e.g. `B|phone|3|m5-v42`;
  - **field 2** the target (a cargo kind, `kind:source`, a pile kind, a noise source, a word);
  - **field 3** the outcome, or `outcome:reason` for a failure (`failed:caught`).
- Server log (Studio Output, or F9 → Server in a live server you are in): every event as
  `[ShiftAnalyticsSystem] <event> target=… outcome=… reason=… value=… variant=… platform=… party=… build=… session=<JobId>`;
  key events at info, the rest at debug. The session id is only here (it would blow up a dashboard field).
- No personal data: no names, UserIds or chat in any field or log line. Field values are catalog ids and fixed words
  only; anything else is written as `other`.

## The events

"Crew" events are sent once to each crew member (divide by party size for per-shift counts). "s" = seconds since the
shift started. `quota` = `before_quota` / `after_quota`.

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
| player_caught | Harlow catches someone | that player | s | `harlow` | quota |
| quota_met | clearance reaches the quota | crew | s | `clearance` | `met` |
| optional_salvage_attempted | an attempt closes | attempter | s from quota to pick-up | `kind:source` | `banked` / `failed:dropped|thrown|caught|left|unbanked` |
| shift_ended | the run ends | each crew member | that player's attempts | `piles_0` / `piles_1_2` / `piles_3_5` / `piles_6_plus` | `clockout|timeout|…` `:quota_met|quota_missed` |
| replay_started | an Another shift starts | crew | shift # | `another_shift` | `same_server` |

Item sources: `open` (on the floor), `pile` (uncovered by vacuuming), `desk` (searched), `scatter` (dropped from a
caught or leaving player's pockets).

**An optional-salvage attempt** opens when someone picks up salvage after the quota, outside the loading bay, while no
clock-out countdown runs; it closes once, as `banked` or failed with a reason.

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
````

- [ ] **Step 2: ROADMAP row.** In `docs/ROADMAP.md`, in the "Games on this base" table, append to the Cleanup Crew row's built-so-far cell (after the M3 sentence, before "Spec: ..."):

```markdown
M5 code: the 13 spec §6.6 analytics events through one game-side door (`ShiftAnalyticsSystem`: vocabulary-only fields, context packed into field 1, session in the server log) fed by the features' existing signals (`ShiftAnalyticsWatchSystem`); a client platform report from a fixed enum; an optional-salvage attempt metric for the validation question; and the A/B variant picked per shift on the server (alternate from the JobId, a fixed mode, a Workspace override), with a spawn roll that offers the same salvage in A and B. Developer checklist: `docs/cleanup-crew-m5-checklist.md`.
```

- [ ] **Step 3: Gate and commit**

```bash
python3 scripts/python/module_map.py --check
bash .superpowers/sdd/gate.sh
git add docs/cleanup-crew-m5-checklist.md docs/ROADMAP.md
git commit -m "docs: Cleanup Crew M5 analytics, A/B switch and developer checklist"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 4: Controller: full TestEZ run in Studio** (`RunTests = true`). Expected: every spec passes; `assertAllModulesSpecced` and `assertAllSpecsCovered` pass.

- [ ] **Step 5: Controller: full-loop analytics playtest** (Play Solo, `RunTests = false`, Task 7's sink injected; through M4's Studio loop). Run one complete shift and one Another shift, then:
1. **Every event appears at least once** across the two shifts: `contract_started`, `first_cleanup_started`, `pile_cleared`, `cargo_picked_up`, `cargo_dropped`, `cargo_banked`, `noise_investigation`, `chase_started`, `player_caught`, `quota_met`, `optional_salvage_attempted`, `shift_ended`, `replay_started`. Check with `for _, r in _G.A.recent() do print(r.event) end` and tick them off.
2. **No personal data:** scan `_G.A.recent()`: no record's `target`, `outcome` or `reason` contains your name or UserId; every value is a vocabulary word or `other`.
3. Every record has `session = studio`, `build = m5-dev`, `platform = pc`, `party = 1`, and the variant of its shift (shift 1 `B`, shift 2 `A`).
4. `_G.A.getState().unknown == 0`; `AnalyticsServiceServer:getState().failed == 0` and `.skipped` equals `_G.A.getState().sent`.
5. Nothing else regressed: HUD, banking floaters (M3), Harlow, the vote and the depot trip behave as before; no new errors in server or client Output.
6. Remove the injected Script; confirm Workspace has no `CleanupCrewVariant` attribute left from testing.

- [ ] **Step 6: Controller: update PR #3's description (never merge).**

```bash
git push origin game/cleanup-crew
gh pr view 3 --json body -q .body > "<scratchpad>/cc-pr-body.md"
cat >> "<scratchpad>/cc-pr-body.md" <<'EOF'

## M5 (code): analytics and the A/B variant switch

Code half of milestone M5 of docs/superpowers/specs/2026-10-10-cleanup-crew-design.md (plan: docs/superpowers/plans/2026-10-10-m5-cleanup-crew-analytics.md). The phone pass, publishing and the sibling session are the developer's: docs/cleanup-crew-m5-checklist.md.

- Analytics: the 13 spec §6.6 events go through one game-side module (ShiftAnalyticsSystem → AnalyticsServiceServer:custom). Field 1 packs variant|platform|party|build; fields 2-3 are target and outcome[:reason]; every string is a vocabulary token (no names, ids or chat); the session (JobId) is in the server log record. Studio sends nothing; a listener/ring is the test sink.
- Facts come from the owning features' existing signals (ShiftAnalyticsWatchSystem): Shift changed, Round runEnded, Vacuum pileCleared + new vacuumStarted, Carry pickedUp/dropped, Death died, Noise made, Harlow's mode/target attributes; ShiftBankingSystem sends cargo_banked.
- Validation question: optional_salvage_attempted (after-quota salvage pick-up outside the loading bay, closed once as banked or failed:<reason>), item sources (open/pile/desk/scatter) and per-player cleaning buckets on shift_ended.
- Platform: a client report parsed from a fixed enum (pc/phone/tablet/console), first report wins.
- Variant: picked per shift on the server: Workspace override CleanupCrewVariant > fixed mode > alternate (Studio starts B; live starts from the JobId), logged and reported. The spawn roll now offers the same salvage for a seed in A and B (rewards unchanged, specced).
- ShiftServiceServer's vote intake moved to Net/ShiftVoteReceiver for line room.

Open questions: see the M5 plan (alternate vs fixed default, session only in the log, crew events per member, the attempt definition, depot re-queues not counted as replays, inferred noise source, per-item rounding, manual build label).

Verified: .superpowers/sdd/gate.sh green; TestEZ green in Studio; Studio checklists in Tasks 1-10 (solo).
EOF
gh pr edit 3 --body-file "<scratchpad>/cc-pr-body.md"
```
Replace `<scratchpad>` with the controller's scratchpad directory. Do not merge.

---

## Self-review (planner)

- **Spec coverage:** §6.6 events (all 13: Tasks 7-9), fields (Task 1 packing + log record; session in the log, an open question), "through AnalyticsServiceServer:custom" (Task 7), no personal data (Task 1 tokens, Task 10 item 2); §6.4 platform fixed enum (Tasks 2, 3, 7); §4 variant switch, B default, rewards unchanged (Tasks 5, 7); §1 the validation question (attempt definition Task 4, sources Task 8, buckets Task 7/8, doc recipes Task 10). Phone pass, publish and sibling session: doc only (Task 10), as instructed.
- **Placeholders:** none; every code step carries complete code or an exact one-line edit with its anchor.
- **Type consistency:** `ShiftAnalyticsUtils.Details/Record/Noise/Harlow/AttemptOutcome` are used unchanged by the trackers (Tasks 3-4), the system (Task 7) and the watch (Tasks 7-9); `ShiftSalvageTracker.Attempt.sinceQuota` is what `closeAttempts` sends; `ShiftAnalyticsSystem.tracker/salvage` match the tracker APIs; `VacuumServiceServer.vacuumStarted: Signal<Player, BasePart>` matches `onVacuumStarted`.
- **Review Focus:** each of the five lines has its spec case or checklist item in the owning task.
