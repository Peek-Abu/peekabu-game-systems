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
| [docs/ROADMAP.md](docs/ROADMAP.md) | What the base has, what was deliberately left out, and the ordered list of shared systems still to build. |
| [docs/testing.md](docs/testing.md) | How to write and run TestEZ specs, and what `SpecRoots` enforces. |
| [docs/animation.md](docs/animation.md) | The animation system — registry, AnimationPlayerSystem, AnimationLocomotionSystem, how to add/play an animation, interruption classes, server-granted actions, Retargeting, verification tools. |

## What this project is

A strongly-typed, server-authoritative **game-systems base for Roblox** that every game of this team
starts from (today: a rodeo-stampede / steal-an-egg / ride-a-pet game, a cleaning-sim × co-op horror
game, and a night-shift horror game). A game is built in its own repo or branch on top of this base; the
base holds only what several games need unchanged.

It was re-seeded from `venture-game-systems` (a rewrite of the RPG "Venture" on this same architecture)
and stripped of Venture's content and of its custom character replication. Characters here are **native
engine characters**. See [docs/ROADMAP.md](docs/ROADMAP.md) for what is in, what was left out, and what
comes next.

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
- **Reference implementations to mirror when adding a domain:** `CurrencyServiceServer`,
  `InventoryServiceServer` and `TitleServiceServer` (+ their clients). Copy their structure.
- **Slots are dormant.** `PlayerDataConstants.MAX_SLOTS = 1`: "slot-scoped" means "the player's save".
  Multi-slot specs are gated (`itMultiSlot`) and re-enable if a game raises it.
- **Characters are native.** Read `player.Character`; never trust a client's position or claim for
  gameplay — validate on the server.

Also in the base: in-game Debugger overlay (F4), Cmdr admin commands with a fail-closed allowlist,
`PlayerDataMigrationSystem` (schema versioning), the animation system, and the React UI framework
(layers, scene stack, HUD registry).

## Commands

Run from the repo root. On Windows use **Git Bash** for the `.sh` scripts.

| Task | Command |
|---|---|
| Full local gate (lint + format + typecheck + ruff) | `bash scripts/check.sh` |
| Same, skipping `wally install` | `bash scripts/check.sh --skip-install` |
| Lint / format / auto-format | `selene src` / `stylua --check src` / `stylua src` |
| Sync to Studio | `rojo serve` |
| Build a place file | `rojo build -o peekabu.rbxl default.project.json` |
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
**not mounted**, because each game's map, terrain, and decorated builds are owned by its Studio place and
edited by builders in Team Create. Rojo must never be able to overwrite artist content.

One sanctioned exception: **property-only service nodes** (`$properties` with NO `$path`, like
`SoundService.RespectFilteringEnabled`, and `VoiceChatService.UseAudioApi = Enabled` /
`EnableDefaultVoice = false`, which the Voice feature's Audio API wiring needs). These manage exactly the listed properties and cannot create or
delete children, so artist content stays untouchable — a node with `$path` on an artist-owned service
remains forbidden. A game sets its own place-level properties this way (for example
`Workspace.Retargeting = Disabled` for a custom-proportioned rig).

⚠ **`ReplicatedStorage` sets `$ignoreUnknownInstances: true`, and must keep it.** That container IS
mounted (`src/ReplicatedStorage`), so by default Rojo owns it outright and DELETES every child not in
the source tree — including an `Assets/` folder of artist-owned models. Art has to sit in
`ReplicatedStorage` when clients need it replicated, and it cannot live in the source tree because it is
artist-owned binary content. Without this flag a `rojo serve` silently deletes the art.

**The trade-off, accepted deliberately:** Rojo will no longer prune stale first-party instances from
`ReplicatedStorage` either, so a renamed or deleted top-level folder there must be cleaned by hand in the
place. `ServerScriptService` deliberately does NOT set the flag, so old server scripts are still deleted by
a sync.

Because a Roblox publish overwrites the *whole* place, **there is no CD**: CI is validation-only
(lint / format / typecheck / ruff / TestEZ on Open Cloud), and a game is deployed **manually** —
`rojo serve` code into its art-bearing place from Studio, then Publish. Don't add a deploy job.

CI runs TestEZ in a dedicated test place configured through the repository's Actions variables and
secrets (see [docs/ci-cd.md](docs/ci-cd.md)): Team Create OFF, no humans, throwaway data.
