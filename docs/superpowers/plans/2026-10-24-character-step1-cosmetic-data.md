# Character systems step 1: cosmetic catalog, loadout save, server rules — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything a player can own and wear (employees, skins, styles, idles, emotes, stickers) exists as data, ownership is saved, what each player wears is saved, and the server changes it only when the rules allow; no UI and no spawn changes yet (those are step 2/3).

**Architecture:** A new game feature **Cosmetic**. Ownership reuses the existing account slice `entitlements` (EntitlementServiceServer): each catalog item is registered there under its kind as category. What the player wears is a new account slice `loadout` owned by CosmeticServiceServer. Pure rules (shared) decide ownership, resolve a look with fallbacks and check/apply an equip; the service adds the profile, shift lock and network boundary. Admin commands drive it until the UI exists.

**Tech Stack:** Luau `--!strict`, TestEZ specs in Studio, ByteNet (requests), charm-sync (state), Cmdr (admin).

**Spec:** `docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md` (sections 1–3; approved). Step 0 report: `reports/2026-10-24-character-spawn-spike.md`.

## Changes from the design doc (my calls, recorded in the doc)
1. Ownership lives in the existing `entitlements` slice, not in a new `owned` map (Marketplace purchases already grant through `EntitlementServiceServer:grantOp`, so a purchase + unlock stays one transaction). The new slice holds only what you wear.
2. Free defaults (each employee's Default skin, Classic idle, default emote, and Pippa herself) are never stored: `source = "default"` items count as owned.
3. No migration: existing players get the default loadout, `picked = false`, so they see the pick screen once (they choose, Pippa is preselected). Fine at this stage (family playtests).

## Global Constraints
- No `any`, no casts except at the network trust boundary (`payload :: { [string]: unknown }`, as TitleRequestRules does).
- Spec first: every new module gets a `.spec.luau` sibling or an `EXEMPT_MODULES` entry with a reason.
- Player-facing text (names, lore) at about a 3rd-grade reading level.
- Never stage `SpecRoots.luau` hunks you did not write; stage files by name. Plain commit messages, no trailers.
- Changes are refused while the player's shift is not in phase `"lobby"` (owner: no changes during a shift).
- Ids are 1–64 characters (EntitlementRules.isKey). Item id form: `<Employee>.<Name>` for employee-bound items, plain for shared ones.

## Review Focus
1. A saved look that names a retired or no-longer-owned item → the resolved look falls back to that employee's default, never errors (CosmeticRules spec: "falls back").
2. A skin of one employee equipped onto another → refused (CosmeticRules spec: "refuses another employee's skin").
3. An emote slot or style index out of range (0, 5, 1.5, -1) → refused (CosmeticRules + request-parse specs).
4. A hostile client payload (wrong types, unknown kind, huge strings) → dropped at the parse, no write (CosmeticRequestRules spec).
5. Granting a bundle twice or granting an item already owned → idempotent, no error, bundle parts granted once (service spec).

## New modules (docs/project-structure.md)

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Cosmetic | shared | Data | CosmeticTypes | item, look, loadout and change types |
| Cosmetic | shared | Data | CosmeticConstants | slot counts, default employee, slice name |
| Cosmetic | shared | Data | CosmeticRegistry | the catalog; registers items into EntitlementRegistry |
| Cosmetic | shared | Rules | CosmeticRules | owns / look resolution / equip check+apply / loadout validator |
| Cosmetic | shared | Rules | CosmeticRequestRules | build/parse the network payloads |
| Cosmetic | shared | Net | CosmeticEvents | EquipRequest, PickRequest packets |
| Cosmetic | server | root | CosmeticServiceServer | owns `loadout`; equip, pick, grant, look, lock |
| Cosmetic | client | root | CosmeticServiceClient | read facade + requests |
| Commands | server | — | CosmeticGrant(+Server), CosmeticEquip(+Server) | admin commands |

Touched: `PlayerDataTypes` (Loadout type + `PlayerAccount.loadout`), `PlayerDataConstants.emptyAccount`, `StateSyncSliceRegistry` (`loadout`, owner-only), `StateSyncClientStore` (`loadout` atom), and the 10 spec fixtures that list every account slice (add `loadout = CosmeticConstants.defaultLoadout()`-equivalent literal).

---

### Task 1: Types, constants and the catalog

**Files:** Create `src/ReplicatedStorage/Shared/Features/Cosmetic/Data/{CosmeticTypes,CosmeticConstants,CosmeticRegistry}.luau` + specs for Constants and Registry (Types exempt-by-pattern like other `*Types`).

**Interfaces — Produces:**
- `CosmeticTypes.Kind = "employee" | "skin" | "idle" | "emote" | "stickerPack" | "sticker"`; `Rarity = "default" | "uncommon" | "rare" | "epic" | "legendary" | "odd"`; `Source = "default" | "credits" | "gleam" | "gloomLocker" | "gleamLocker" | "goal" | "event" | "gift" | "later"`.
- `CosmeticTypes.Item = { id: string, kind: Kind, name: string, rarity: Rarity, source: Source, employee: string?, price: number?, styles: number?, lore: string, bundle: { string }?, pack: string? }`.
- `CosmeticTypes.Look = { skin: string, style: number, idle: string, wheel: { string } }` (wheel: exactly `WHEEL_SLOTS` strings, `""` = empty).
- `CosmeticTypes.Loadout = PlayerDataTypes.Loadout` = `{ current: string, picked: boolean, looks: { [string]: Look }, stickers: { string }, seen: { [string]: boolean } }`.
- `CosmeticTypes.Change = { kind: "employee", id: string } | { kind: "skin", id: string, style: number } | { kind: "idle", employee: string, id: string } | { kind: "emote", employee: string, slot: number, id: string } | { kind: "sticker", slot: number, id: string }` (emote/sticker `id = ""` clears the slot).
- `CosmeticConstants`: `SLICE = "loadout"`, `DEFAULT_EMPLOYEE = "Pippa"`, `WHEEL_SLOTS = 4`, `STICKER_SLOTS = 4`, `MAX_STYLES = 9`, `defaultLoadout(): Loadout` (current Pippa, picked false, looks {}, stickers 4×"", seen {}).
- `CosmeticRegistry.get(id): Item?`, `.has(id)`, `.all(): { Item }` (sorted by id), `.ofKind(kind, employee?): { Item }`, `.defaultOf(employee, kind): Item` (the employee's `source="default"` skin/idle/emote), `.employees(): { string }`. At load it calls `EntitlementRegistry.register(item.kind, item.id, { name = item.name })` for every kind except `sticker` (stickers are owned through their pack); guarded with `EntitlementRegistry.has` so a hot reload never double-registers.

**Catalog content (placeholder prices/lore are fine; names from the requirements doc):**
- Employees: `Pippa` (default), `Cappy` (credits 2500), `Prickles` (credits 2500).
- Per employee: `<E>.Default` skin (default), `<E>.Classic` idle (default), default emote `Pippa.Wave` / `Cappy.FistBump` / `Prickles.Huff` (default).
- Pippa skins: `Pippa.OwnerSpecial` (rare, gift), `Pippa.BubbleBuddy` (legendary, gleam 1500, styles 3, bundle {`Pippa.Bubbles`, `BubblePack`}), `Pippa.GloomTouched` (uncommon, gloomLocker), `Pippa.Gloomkeeper` (epic, gloomLocker).
- Cappy skins: `Cappy.PJ` (legendary, gleam 1500, styles 3, bundle {`Cappy.CocoaSip`, `SleepySway`, `CozyPack`}), `Cappy.GloomTouched` (uncommon), `Cappy.GhostDebunker` (epic).
- Prickles skins: `Prickles.Sheriff` (legendary, gleam 1500, styles 3, bundle {`Prickles.Lasso`, `SheriffPack`}), `Prickles.GloomTouched`, `Prickles.PotKnight` (epic).
- Emotes (employee-bound, legendary, source = the skin's): `Pippa.Bubbles`, `Cappy.CocoaSip`, `Prickles.Lasso`. Idle: `SleepySway` (shared, epic, gleam 400).
- Sticker packs (shared, rare, gleam 150): `CozyPack`, `BubblePack`, `SheriffPack`; 3 stickers each, kind `sticker`, `pack = <pack>`, ids `<Pack>.<Name>`.

- [ ] **Step 1: Write the failing registry spec** — asserts: every id is unique and 1–64 chars; every employee has exactly one default skin, idle and emote (`defaultOf` returns them); every `employee` field names a registered employee; every `bundle` entry and `pack` names a registered item; every non-default, non-later item has a `price` when its source is `credits`/`gleam`; `styles` is nil or 1..MAX_STYLES; every non-sticker item is registered in EntitlementRegistry under its kind; `Pippa` is the only free employee.
- [ ] **Step 2: Run in Studio (RunTests), see it fail** (module missing).
- [ ] **Step 3: Write Types, Constants (+ spec: defaultLoadout shape, 4 empty slots), Registry.**
- [ ] **Step 4: Run, PASS.**
- [ ] **Step 5: Commit** "Cosmetic: catalog of employees, skins, idles, emotes and stickers".

### Task 2: Pure rules

**Files:** Create `Shared/Features/Cosmetic/Rules/CosmeticRules.luau` + spec.

**Interfaces — Consumes:** Task 1. **Produces:**
- `CosmeticRules.owns(entitlements: PlayerDataTypes.Entitlements, id: string): boolean` — unknown id → false; `source == "default"` → true; `sticker` → owns its pack; else `EntitlementRules.owns(entitlements, item.kind, id)`.
- `CosmeticRules.lookFor(loadout, employee: string, owns: (id: string) -> boolean): Look` — resolves with fallbacks: skin must exist, be a `skin` of this employee and be owned, else `<E>.Default`; style clamped to 1..(skin.styles or 1); idle owned and (shared or this employee's) else `<E>.Classic`; each wheel slot an owned emote usable by this employee else `""`; a missing look → all defaults with the default emote in slot 1.
- `CosmeticRules.currentEmployee(loadout, owns): string` — `loadout.current` if it is an owned employee, else DEFAULT_EMPLOYEE.
- `CosmeticRules.checkEquip(loadout, change: Change, owns): (boolean, string?)` — reasons: `"not owned"`, `"wrong employee"`, `"bad slot"`, `"bad style"`, `"unknown item"`, `"wrong kind"`, `"no change"`.
- `CosmeticRules.applyEquip(loadout, change: Change, owns): boolean` — mutates in place (call only after checkEquip); creates the employee's look from `lookFor` when missing.
- `CosmeticRules.validateLoadout(value: unknown): (boolean, string?)` — the slice's data-layer validator, STRUCTURE only (retired ids allowed): `current` non-empty ≤64; `picked` boolean; `looks` map of ≤64-char keys to looks with string skin/idle, integer style 1..MAX_STYLES, wheel exactly WHEEL_SLOTS strings; `stickers` exactly STICKER_SLOTS strings; `seen` map of string → true.

- [ ] **Step 1: Failing spec**, cases: owns default/unowned/owned/sticker-via-pack/unknown; lookFor falls back on retired skin, another employee's skin, unowned idle, style 0 and 7 on a 3-style skin, unowned emote in a slot; currentEmployee falls back when Cappy is not owned; checkEquip refuses another employee's skin, slot 0/5/1.5, style 0/4 on 3 styles, unowned emote, a sticker whose pack isn't owned, accepts clearing a slot with `""`; applyEquip writes skin+style, creates a missing look; validateLoadout accepts defaultLoadout, rejects wheel of 3, style 1.5, picked "yes", non-true seen value, accepts an unknown skin id.
- [ ] **Step 2: FAIL.** **Step 3: Implement.** **Step 4: PASS.**
- [ ] **Step 5: Commit** "Cosmetic: ownership, look fallbacks and equip rules".

### Task 3: Request contract and packets

**Files:** Create `Shared/Features/Cosmetic/Rules/CosmeticRequestRules.luau` + spec; `Shared/Features/Cosmetic/Net/CosmeticEvents.luau` (copy TitleEvents' shape; namespace `"CosmeticEvents"`, packets `EquipRequest`, `PickRequest`, both `ByteNet.unknown` reliable).

**Produces:** `buildEquip(change: Change): { [string]: unknown }`, `parseEquip(payload: unknown): (Change?, string?)`, `buildPick(employee: string)`, `parsePick(payload: unknown): (string?, string?)`. Parse checks shape only: kind is one of the five, strings 1–64 chars (`""` allowed only for emote/sticker `id`), `slot`/`style` integers.

- [ ] **Step 1: Failing spec** (round-trip every kind; rejects non-table, unknown kind, 65-char id, slot "2", style 1.5, missing employee on idle/emote).
- [ ] **Steps 2–4: FAIL → implement → PASS.** **Step 5: Commit** "Cosmetic: request contract and packets".

### Task 4: The `loadout` slice and the server service

**Files:** Modify `Shared/Data/PlayerDataTypes.luau` (add `Look`, `Loadout`, `PlayerAccount.loadout`), `PlayerDataConstants.luau` (`emptyAccount().loadout`), `StateSyncSliceRegistry.luau` (`loadout` reading `profile.account.loadout`), `StateSyncClientStore.luau` (atom defaulted to the default loadout), the 10 fixture specs listed by `grep -rln "firstSeen = { at" src`. Create `ServerScriptService/Features/Cosmetic/CosmeticServiceServer.luau` + spec.

**Interfaces — Produces (CosmeticServiceServer):**
- `dependencies = { "PlayerDataServiceServer", "EntitlementServiceServer", "ShiftServiceServer" }`
- `changed: SignalTyped.Signal<number>` (userId) — fires after any committed loadout change or grant (step 2 rebuilds the character on it).
- `getLoadout(userId): Loadout?`, `owns(userId, id): boolean`, `currentEmployee(userId): string`, `lookOf(userId, employee: string?): Look?` (resolved; employee defaults to current).
- `isLocked(): boolean` — `ShiftServiceServer:getShift().phase ~= "lobby"`.
- `equip(player: Player, change: Change): (boolean, string?)` — refuses `"locked during a shift"`, `"no profile loaded"`, then CosmeticRules; writes via the slice's mutate.
- `pick(player, employee): (boolean, string?)` — only while `picked == false`; employee must be owned (Pippa free); sets `current` and `picked = true`.
- `grant(userId, id): (boolean, string?)` — registered non-sticker item; grants it and every bundle part through `EntitlementServiceServer:grant` (already-owned parts are fine); `"already owned"` only when nothing new was granted; fires `changed`.
- `grantOps(userId, id): { PlayerDataService.TransactionOperation }` — the same as ops (`EntitlementServiceServer:grantOp` per item) for a Shop/Marketplace transaction.
- `_onEquipRequest`, `_onPickRequest` test seams (RequestHandler.wrap, rate limit 10 per 10 s), listeners wired in `init`.

- [ ] **Step 1: Failing spec** (fake profiles seeded like TitleServiceServer.spec; ShiftServiceServer.getShift stubbed): equip skin persists and fires `changed`; equip refused during phase "running"; equip another employee's skin refused; pick works once then refused; pick of unowned Cappy refused, works after `grant("Cappy")`; grant `Cappy.PJ` also owns `Cappy.CocoaSip`, `SleepySway`, `CozyPack`; second grant returns false "already owned" and grants nothing; `lookOf` after granting then revoking the skin (EntitlementServiceServer:revoke) falls back to Default; `_onEquipRequest` with a bad payload writes nothing.
- [ ] **Step 2: FAIL.** **Step 3: Implement** (mirror TitleServiceServer's structure: slice registered at module load with `CosmeticRules.validateLoadout`, `equipImpl` shared by handler and method). **Step 4: PASS, and the whole suite still passes** (fixtures updated).
- [ ] **Step 5: Commit** "Cosmetic: loadout slice and server service (equip, pick, grant, shift lock)".

### Task 5: Client facade and admin commands

**Files:** Create `Client/Features/Cosmetic/CosmeticServiceClient.luau` + spec (getLoadout from the atom, `owns(id)` via `StateSyncClientStore.entitlements()` + CosmeticRules, `lookOf(employee?)`, `requestEquip(change)` / `requestPick(employee)` send built payloads only when the local rules allow). Create `ServerScriptService/Commands/CosmeticGrant.luau` + `CosmeticGrantServer.luau` (+spec) — `cosmeticgrant <player> <id>`; `CosmeticEquip.luau` + `CosmeticEquipServer.luau` (+spec) — `cosmeticequip <player> <kind> <id> [slot] [style] [employee]`, builds a Change and calls `equip`, reporting the reason on refusal. Both in group `Admins`, plain `string`/`number` arg types.

- [ ] **Step 1: Failing specs** (command handlers call the service with the right arguments and echo its reason; client `requestEquip` does not send for an unowned item).
- [ ] **Steps 2–4.** **Step 5: Commit** "Cosmetic: client facade and admin grant/equip commands".

### Task 6: Verify in Studio and report

- [ ] Run the full suite in Studio (Shift window, `studio-playtest-shift.lock`, RunTests on, then cleared). Expected: 0 failures.
- [ ] Play (RunTests off): `cosmeticgrant me Cappy.PJ`, `cosmeticequip me employee Cappy`, `cosmeticequip me skin Cappy.PJ 0 2`; read `StateSyncClientStore.loadout()` on the client: current Cappy, look skin `Cappy.PJ` style 2. (No visible change yet: spawning from the loadout is step 2.)
- [ ] Update the design doc's section 2 with "Changes from the design doc" above; report in `reports/2026-10-24-character-step1.md`; commit.
