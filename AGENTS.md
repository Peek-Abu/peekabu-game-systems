# AGENTS.md

Guidance for AI coding agents working in this repo. Human-facing docs live in
[README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), and `docs/` — read those for the full
picture. This file covers what you can't infer from the code.

## Where to look

This file holds the non-negotiable rules and decisions; descriptive reference material lives in
`docs/` so each doc has one job:

| Doc | What's in it |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How the pieces are wired at runtime — boot sequence, `ServiceController`, the data layer, transactions, networking, the reactive spine. |
| [docs/project-structure.md](docs/project-structure.md) | The feature layout and naming rules, where new code goes, service discovery, the spec-sibling rule, the add-a-slice recipe, and the generated module map. |
| [docs/tech-stack.md](docs/tech-stack.md) | The Rokit toolchain, the CI pipeline stages, and each Wally dependency's sanctioned role here. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phase-by-phase porting plan and status — what's landed, in flight, and next. |
| [docs/testing.md](docs/testing.md) | How to write and run TestEZ specs, and what `SpecRoots` enforces. |
| [docs/animation.md](docs/animation.md) | The animation system — registry, AnimationPlayerSystem, AnimationLocomotionSystem, how to add/play an animation, interruption classes, the Retargeting gotcha, verification tools. |

## What this project is

A strongly-typed, server-authoritative **game-systems base for Roblox** that is being used to
**rewrite "Venture"**, a messy ~5-year-old live Roblox game currently built on Knit, hand-rolled
metatable classes, DataStore2, and state smuggled into the Instance tree.

The code in `src/` is the *target* architecture (the base, with reference Currency + Inventory
domains). The old game is the *source*. Ongoing work = porting Venture's systems onto this base.
Track it in `docs/REFACTORHANDOFF.md`.

## Non-negotiable working rules

- **No `any`, no casts.** `--!strict` everywhere. A `::` cast needs genuine justification, a comment
  at the site, and sign-off. Fix the type, not the symptom.
- **Root fixes, not band-aids.** Don't patch a symptom to make an error go away, and don't claim an
  API behaves a certain way without verifying it against the docs or the code.
- **Spec-first TDD.** Write `<Name>.spec.luau` before the implementation.
  `SpecRoots.assertAllModulesSpecced` **fails the build** if a first-party module has no `.spec`
  sibling and isn't in `SpecRoots.EXEMPT_MODULES` (with a reason). Spec files are intentionally
  untyped — that is fine and expected.
- **Module placement.** Every new module's feature, realm, subfolder and name are stated in the plan
  before it is written, and follow [docs/project-structure.md](docs/project-structure.md). Use the
  `module-placement` skill when planning, adding a module, or reviewing. A new subfolder kind (three
  modules that share it **and** the developer's approval), a new role word, or a second service in one
  feature needs the developer's approval; `check_pr_rules` fails any file that breaks the layout.
- **Commits: plain messages only.** Do **not** add `Co-Authored-By:` or `Claude-Session:` trailers.
- **PR merges: merge commit (never squash — branches stack), subject `Merge PR #N: <short description>`.**
  Via CLI: `gh pr merge N --merge --subject "Merge PR #N: ..."`. In the GitHub UI: edit the default
  subject to match before confirming. After a merge, rebase still-open stacked branches onto the new
  main so their PR views stay clean.
- **Server-authoritative always.** Clients never write authoritative state.

## Architecture in one screen

- **ServiceController** — lifecycle (`init` → `start` → `stop`, topological dependency sort).
  Services are auto-discovered under each realm's `Features/` root by the `*ServiceServer` / `*ServiceClient` filename suffix.
- **Service shape: lean annotated literal.** `export type MyService = {...}` + `local MyService:
  MyService = {...}` with methods as *fields*. No `function MyService:method()` statements, no
  `typeof(self)` intersections, no `self` casts. Types are declared once in the interface and flow
  down into the bodies. Callers still use colon syntax.
- **PlayerDataService** — ProfileStore-backed. **All** writes go through `mutate()` / `transaction()`
  (atomic, rollback, session-locked). Each domain owns a **profile slice** via
  `PlayerDataSliceSystem.register(slice, default, read, validate?)` → typed `get` / `mutate` / `op`. The
  per-slice validator is enforced by the data layer, so it holds for *any* path into the slice.
- **Reactive state** — server writes mirror into Charm `StateSyncServerStore` atoms → charm-sync ships deltas
  → client `StateSyncClientStore` atoms (read reactively, incl. React UI).
- **ByteNet** — typed packets for discrete events / RPCs. **Not** for queryable state; state rides
  the charm-sync spine.
- **Guard** — shared runtime validators (`userId`, `positiveAmount`, …). Validate once at the
  boundary.
- **Reference implementations to mirror when porting a domain:** `CurrencyServiceServer` and
  `InventoryServiceServer` (+ their clients). Copy their structure.

Also in the base: in-game Debugger overlay (F4), Cmdr admin commands with a fail-closed allowlist,
`PlayerDataMigrationSystem` (schema versioning, for *future* evolution — there is no legacy migration).

## Commands

Run from the repo root. On Windows use **Git Bash** for the `.sh` scripts.

| Task | Command |
|---|---|
| Full local gate (lint + format + typecheck + ruff) | `bash scripts/check.sh` |
| Same, skipping `wally install` | `bash scripts/check.sh --skip-install` |
| Lint / format / auto-format | `selene src` / `stylua --check src` / `stylua src` |
| Sync to Studio | `rojo serve` |
| Build a place file | `rojo build -o venture.rbxl default.project.json` |
| Run tests | Studio only: `rojo serve`, connect, set Workspace attribute `RunTests = true`, hit Play, read Output. **Opt-in on purpose** — the suite mutates real module singletons (destroys the live charm-sync transport), so a test session is never a play session. CI runs TestEZ on Open Cloud. |
| Preview UI (no Play) | `rojo serve`, then the **UI Labs** Studio plugin in EDIT mode — it renders any `*.story.luau` and re-renders on sync. Use this for visual iteration instead of booting the game; see [docs/testing.md](docs/testing.md). |

There is **no headless test runner** — TestEZ needs a real Roblox runtime (Studio or Open Cloud).

## Gotchas (learned the hard way — don't rediscover these)

- `rokit install` prompts for tool trust non-interactively → use `rokit install --no-trust-check`.
- **`wally-package-types` is NOT idempotent.** Running it twice corrupts link files
  (`'REQUIRED_MODULE' is not a function call`). Run `scripts/check.sh` *with* its `wally install`
  step so links are regenerated fresh first.
- Type exports must be generated for **every realm** (`Packages/`, `ServerPackages/`, `DevPackages/`)
  — ProfileStore lives in `ServerPackages/`, and skipping it types the whole data layer as `Unknown`.
- Open Cloud place upload **409 "Server is busy"** = the target place has Team Create ON or is open
  in Studio.

## Deployment model — read before touching CI

**This is a code-only Rojo project.** `Workspace` / `Lighting` / `ServerStorage` are deliberately
**not mounted**, because the map, terrain, and decorated builds are owned by the Studio place and
edited by non-coder devs in Team Create. Rojo must never be able to overwrite artist content.

One sanctioned exception: **property-only service nodes** (`$properties` with NO `$path`, like
`SoundService.RespectFilteringEnabled`, `Workspace.Retargeting = Disabled` and
`Players.CharacterAutoLoads = false`). These manage
exactly the listed properties and cannot create or delete children, so artist content stays
untouchable — a node with `$path` on an artist-owned service remains forbidden.
(`Workspace.Retargeting` MUST stay `Disabled`: the custom-proportioned rig uses standard R15
joint names, and retargeting visibly breaks every animation pose. `Players.CharacterAutoLoads` MUST stay
`false`: bodies are client-only — see docs/architecture.md, "Bodies".)
`TextChatService` also carries one `$className` child node, `BubbleChatConfiguration` (no `$path`, so unknown
siblings are kept), to set `Enabled = false` on the instance the engine already creates; Rojo 7.7.0 pairs it with
the engine's existing `BubbleChatConfiguration` by name and class (verified at R5's first serve: exactly one
instance, `Enabled = false`); a hand-set place setting remains the fallback if that ever regresses.

**Place-owned settings (set by hand, per place).** A few properties cannot be written by Rojo or any script,
so each place (dev, staging, live) must have them set in the Studio Properties panel:

| Setting | Value | Why it can't be automated |
|---|---|---|
| `TextChatService.ChatVersion` | `TextChatService` | Write is RobloxScriptSecurity. A place still on `LegacyChatService` runs the old chat in Studio. `VoiceServiceServer` logs an error at start if it is wrong. |

The two `VoiceChatService` settings (`EnableDefaultVoice = false`, `UseAudioApi = Enabled`) are NOT hand-set — `default.project.json` writes them (Rojo runs as a plugin). They cannot be checked at runtime: Read is PluginSecurity, so game scripts cannot read them. `VoiceServiceServer`'s startup check covers only script-readable settings (`ChatVersion`, `CreateDefaultTextChannels`, `BubbleChatConfiguration.Enabled`).

⚠ **`ReplicatedStorage` sets `$ignoreUnknownInstances: true`, and must keep it.** That container IS
mounted (`src/ReplicatedStorage`), so by default Rojo owns it outright and DELETES every child not in
the source tree — including `Assets/`, where customization art lives. Art has to sit in
`ReplicatedStorage` because clients need it replicated, and it cannot live in the source tree because
it is artist-owned binary content. Without this flag a `rojo serve` silently deletes the art: that is
exactly what happened during 5b, where a vanished models folder cost a full debugging round and looked
like a code bug.

**The trade-off, accepted deliberately:** Rojo will no longer prune stale first-party instances from
`ReplicatedStorage` either, so **cutover must clean the old game's `ReplicatedStorage` folders by hand**
(`Effects`, `Events`, `Modules`, `UI`, `Skills`, …) rather than relying on the publish to remove them.
That moves `ReplicatedStorage` into the same "clean it manually" bucket the unmounted containers are
already in. `ServerScriptService` deliberately does NOT set the flag, so old server scripts are still
deleted by a publish.

Because a Roblox publish overwrites the *whole* place, **there is no CD**: CI is validation-only
(lint / format / typecheck / ruff / TestEZ on Open Cloud), and production is deployed **manually** —
`rojo serve` code into the art-bearing place from Studio, then Publish. Don't add a deploy job.

| Tier | Experience | Data | Deploy |
|---|---|---|---|
| CI | `Venture[Test]` (universe `10488238788`, place `97354325370574`) — Team Create OFF, no humans | throwaway | Open Cloud, automated |
| Staging/QA | the place currently named `Venture[Prod]` | separate, wipeable | manual Studio publish |
| Live | the existing prod experience (arenas etc.) | fresh (old data wiped) | manual Studio publish |

## Refactor decisions already locked in

1. **Old data is disposable — wipe it.** The 5-year-old DataStore2 data is not migrated. ProfileStore
   uses different keys, so old data is simply never read. No migration adapter.
2. **Reuse the existing live experience** for cutover (keeps game passes, dev products, badges,
   favorites, discovery standing) rather than shipping a new one.
3. **Cutover = `rojo serve` into the live art-bearing place + Publish from Studio.** This deletes the
   old Knit scripts in the mounted code containers (intended) and preserves art in the unmounted
   ones. Watch for old logic hiding in unmounted containers (Workspace / ServerStorage).
4. **Sequencing: foundation and leaves first, combat core LAST** — it's the hub with 10+ deps and
   needs a genuine server-authoritative hit-detection redesign, not a port.

## Inspecting the live game

The old game's source of truth is the **live Studio place**, not this repo. Use the
`Roblox_Studio` MCP (`mcp__Roblox_Studio__*`, e.g. `execute_luau`) against the open Studio session to
walk the real hierarchy.

> **READ-ONLY. Never edit `VentureTestingPlace`.** Inspection only — enumerate instances, read
> `ClassName` / properties / `.Source`. Do **not** create, delete, move, or set properties on any
> instance, and do not publish. It is the reference copy of the old game.

If the tools aren't loaded:

```bash
claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
```

then restart the session and trust the server when prompted.
