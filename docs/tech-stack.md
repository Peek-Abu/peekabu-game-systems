# Tech Stack

The toolchain, CI pipeline, and third-party dependencies this project is built on — what each piece
is for and its sanctioned role here. For how these pieces are actually wired into the codebase (which
module is the reference integration for each library), see [architecture.md](architecture.md),
particularly [Provisioned dependencies](architecture.md#provisioned-dependencies) and
[Cross-cutting utilities](architecture.md#cross-cutting-utilities).

---

## Toolchain (Rokit)

Managed by [Rokit](https://github.com/rojo-rbx/rokit) via [rokit.toml](../rokit.toml). Run
`rokit install --no-trust-check` to install (see the gotcha in
[AGENTS.md](../AGENTS.md#gotchas-learned-the-hard-way--dont-rediscover-these) — plain `rokit install`
prompts for tool trust non-interactively).

| Tool | Version | Role |
|---|---|---|
| [rojo](https://github.com/rojo-rbx/rojo) | 7.6.1 | Syncs `src/` into Studio (`rojo serve`) and builds place files (`rojo build`) — the project's Roblox<->filesystem bridge. |
| [wally](https://github.com/UpliftGames/wally) | 0.3.2 | The package manager; installs everything in `wally.toml` into `Packages/`, `ServerPackages/`, `DevPackages/`. |
| [wally-package-types](https://github.com/JohnnyMorganz/wally-package-types) | 1.6.2 | Generates `.d.luau` type exports for installed packages so `luau-lsp analyze` can type-check across the package boundary. **Not idempotent** — see the gotcha in AGENTS.md. |
| [selene](https://github.com/Kampfkarren/selene) | 0.31.0 | Lints `src` (`selene src`); its `std = "roblox+testez"` config recognizes TestEZ's injected globals in spec files. |
| [stylua](https://github.com/JohnnyMorganz/StyLua) | 2.5.2 | Enforces/auto-fixes formatting (`stylua --check src` / `stylua src`). |
| [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) | 1.68.1 | Provides `luau-lsp analyze`, the blocking `--!strict` type-check gate; also powers editor tooling. Its release tag must stay in lockstep with the `globalTypes.d.luau` fetch in CI (see below). |

`scripts/check.sh` runs the full local gate (lint + format + typecheck + the Python `ruff` checks)
in one command; see the [Commands table in AGENTS.md](../AGENTS.md#commands).

---

## CI pipeline

Defined in [`.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml). Every push runs lint,
format, typecheck, and the Python script checks; only the full test suite is gated to PRs into
`main` (and pushes to `main`). Jobs:

1. **`lint`** — `selene src`.
2. **`format`** — `stylua --check src`.
3. **`typecheck`** — installs Wally packages, generates a Rojo sourcemap, runs
   `wally-package-types` across *every* package realm (`Packages/`, `ServerPackages/`,
   `DevPackages/` — skipping `ServerPackages/` would leave ProfileStore, and the whole data layer,
   typed as `Unknown`), downloads Roblox's global type definitions pinned to the same release tag as
   `luau-lsp` in `rokit.toml`, then runs `luau-lsp analyze` over `src` and `tasks` (spec files
   excluded — they rely on TestEZ's injected globals). This is the **blocking merge gate**.
4. **`scripts-lint`** — lints the Python Open Cloud upload scripts with `ruff`, enforces a
   code-line cap per module (`check_file_length.py`, doc comments and specs exempt), and runs
   `check_pr_rules.py origin/main` — project rules (no `any`/`::` casts, no commit trailers, no
   placeholder currencies) judged only on lines a PR *adds*, so it ratchets forward without
   re-litigating history.
5. **`test`** — needs `[lint, format, typecheck, scripts-lint]`; only runs on PRs into `main` or
   pushes to `main` (it hits real Roblox infrastructure). Builds a place with `rojo build`, then
   `upload_and_run_task.py` uploads it and runs `tasks/runTests.luau` via **Open Cloud Luau
   Execution** — there is no headless local test runner, so this is the only place TestEZ actually
   executes outside Studio. Concurrency is capped at 1 (`luau-execution` group) because Open Cloud
   allows only 2 concurrent runs per universe.

There is deliberately **no CD job** — see the deployment model in
[AGENTS.md](../AGENTS.md#deployment-model--read-before-touching-ci).

---

## Wally dependencies

From [wally.toml](../wally.toml). Each entry below is the sanctioned role in *this* codebase — not
just what the library does in general.

### Charm
`littensy/charm@0.11.0` — atomic reactive state. The atoms in `StateSyncServerStore`
(server-authoritative mirror) and `StateSyncClientStore` (client source of truth) are Charm atoms; all
replicated player state flows through them. See
[architecture.md: Reactive state](architecture.md#reactive-state).

### CharmSync
`littensy/charm-sync@0.4.0` — diffs Charm atoms and ships deltas server->client. This is the
transport for *all* queryable player state (currency, inventory, stats, equipment, …), riding a
dedicated `RemoteEvent` rather than ByteNet — a deliberate exception documented in
[architecture.md](architecture.md#reactive-state).

### ByteNetMax
`elitriare/bytenet-max@0.2.5` — the sanctioned transport for discrete/event packets: inbound
action requests, one-off signals, RPCs. Reach for this under `Shared/Features/<Feature>/Net`, never a raw
`RemoteEvent`. Live reference: `Shared/Features/Debugger/Net/DebuggerEvents.luau` (the Service & State Debugger's
`SetSubscription`/`Snapshot`/`ClearServerLogs` packets). See
[architecture.md: Networking](architecture.md#networking).

### Cmdr
`evaera/cmdr@1.12.0` — admin command framework. Command definitions live in
`ServerScriptService/Commands/*.luau`; `AdminServiceServer` wires Cmdr's `BeforeRun` hook into a
fail-closed permission allowlist. See
[conventions.md: Adding Admin Commands](conventions.md#adding-admin-commands-cmdr).

### ProfileStore
`lm-loleris/profilestore@1.0.3` (server-only realm) — the DataStore wrapper backing
`PlayerDataServiceServer`: sessions, auto-save, and the `mutate()`/`transaction()` choke point all
sit on top of it. **Marked in `wally.toml` as not an official release by its creator** — pinned
deliberately; see [architecture.md: Data layer](architecture.md#data-layer). Lives in
`ServerPackages/`, which is why the typecheck job's `wally-package-types` pass must cover that realm
too.

### React / ReactRoblox / ReactCharm
`jsdotlua/react@17.2.1`, `jsdotlua/react-roblox@17.2.1` (React-lua, a Luau port of React 17) +
`littensy/react-charm@0.4.0` (the `useAtom` hook bridging Charm atoms into React). The Debugger
overlay (`Client/UI/React/Debugger`) is the reference integration — copy its structure and the
`ScreenGui`-mounting rule in
[conventions.md: Mounting React UI](conventions.md#mounting-react-ui-the-playergui-reset-trap) for
any new UI.

### Observers
`sleitnick/observers@0.5.0` — `observePlayer`/`observeCharacter`/`observeTag`/`observeAttribute`
lifecycle helpers. `PlayerDataServiceServer` uses `observePlayer` to start/end ProfileStore sessions
on join/leave.

### Janitor
`howmanysmall/janitor@1.18.3` — connection/instance cleanup. Used per-player (session-scoped
connections torn down on leave) and per-service (`stop()` cleanup). See
[architecture.md: Data layer](architecture.md#data-layer).

### Signal
`lightwxve/signalplus@3.5.0` — the signal primitive behind `SignalTyped`, the typed wrapper module
that isolates the one `any` cast needed at that untyped-package boundary (see
[conventions.md: Casts](conventions.md#casts)). **Marked in `wally.toml` as not an official release
by its creator.**

### sift
`csqrl/sift@0.0.11` — immutable table helpers. `copyDeep` backs transaction/migration rollback
snapshots and the `StateSyncServerStore` atom mirroring (a live profile table must never alias an atom);
`freezeDeep` backs read-only profile snapshots (`getProfile`, the per-slice shell). Marked in
`wally.toml` as "not necessary, but recommended" — this project has adopted it project-wide for
these two operations rather than hand-rolling them.

### Promise
`evaera/promise@4.0.0` — the standard async primitive for yielding/parallel work (batched I/O,
retries, fan-out). Live reference: `DebuggerServiceServer`, where each service's `getState()` runs
through `Promise.try():timeout()` so one hanging service can't stall the whole snapshot. Prefer it
over hand-rolled callback/coroutine plumbing. See
[architecture.md: Provisioned dependencies](architecture.md#provisioned-dependencies).

### TestEZ
`roblox/testez@0.4.1` (dev-only realm) — the BDD-style test framework (`describe`/`it`/`expect`).
Runs via the Studio `TestRunner.server.luau` script or, in CI, via Open Cloud Luau Execution — see
[testing.md](testing.md) and the [CI pipeline](#ci-pipeline) section above.
