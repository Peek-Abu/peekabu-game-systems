# Peekabu Game Systems

A strongly-typed, server-authoritative **game systems base for Roblox** — a reusable foundation you can drop into any game. It ships a service lifecycle framework, persistent player data with atomic transactions, currency and inventory systems, an admin command suite, and a full lint → format → test → deploy CI/CD pipeline.

Built with Luau `--!strict` throughout, [Rojo](https://rojo.space/), [Wally](https://wally.run/), and [Rokit](https://github.com/rojo-rbx/rokit).

---

## Contents

- [Features](#features)
- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Getting started](#getting-started)
- [Everyday commands](#everyday-commands)
- [Adding a new service](#adding-a-new-service)
- [Admin commands](#admin-commands)
- [Testing](#testing)
- [CI/CD](#cicd)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Service lifecycle framework** — `register → init → start → stop` with a topological dependency sort. Services at the same dependency level start concurrently; a level only begins once every service in the previous level has fully finished `start()`. Circular dependencies are detected and reported. See [ServiceController.luau](src/ReplicatedStorage/Shared/Modules/ServiceController.luau).
- **Persistent player data** — built on [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) with session locking, reconciliation, and a single `mutate()` choke point for all writes.
- **Atomic transactions** — multi-profile, all-or-nothing mutations (e.g. trades) with in-memory per-path snapshot rollback and auto-save-mid-transaction detection. See `PlayerDataServiceServer:transaction()`.
- **Currency & inventory systems** — capped currencies, stackable/unique items, batch operations, and reactive client sync via [Charm](https://github.com/littensy/charm)/[charm-sync](https://github.com/littensy/charm-sync) atoms.
- **Admin commands** — [Cmdr](https://eryn.io/Cmdr/) integration with a secure-by-default allowlist gate. See [AdminServiceServer.luau](src/ServerScriptService/Services/AdminService/AdminServiceServer.luau).
- **Request middleware** — per-player rate limiting, validation, and audit logging for network handlers. See [RequestHandler.luau](src/ServerScriptService/Modules/RequestHandler.luau).
- **Structured logging** — leveled logger (`DEBUG`/`INFO`/`WARN`/`ERROR`/`AUDIT`) with per-context prefixes. See [Logger.luau](src/ReplicatedStorage/Shared/Modules/Logger.luau).
- **Tooling baked in** — `--!strict` everywhere, Selene linting, StyLua formatting, TestEZ specs, and a CI pipeline that runs the suite in a real Roblox runtime via Open Cloud.

---

## Architecture

The codebase is split by realm and wired together by `ServiceController`.

```
Server boot (ServerHandler.server.luau)            Client boot (ClientHandler.client.luau)
  1. Auto-require every *ServiceServer module         1. GameItems.init()  (item/currency definitions)
  2. GameItems.init()  (item/currency definitions)    2. Auto-require every *ServiceClient module
  3. initService("PlayerDataServiceServer", config)   3. ServiceController:initAll()
  4. ServiceController:initAll()                       4. ServiceController:startAll()
  5. ServiceController:startAll()
```

**Lifecycle contract** (see [docs/conventions.md](docs/conventions.md)):

- `init(self)` — internal setup only. **Do not** call other services here.
- `start(self)` — runs after *all* services are initialized; safe to call other services.
- `stop(self)` — teardown (disconnect events, end sessions, release resources).

Services are written as **one annotated table literal** — an explicit `export type MyService = { ... }` interface plus `local MyService: MyService = { ... }` with methods as fields — so signatures flow from the interface into method bodies with no inline annotations or casts (the full rationale lives in the header of [ServiceController.luau](src/ReplicatedStorage/Shared/Modules/ServiceController.luau)). Callers still invoke public methods with colon syntax (`service:doThing()`).

**Data flow** is server-authoritative: services mutate `PlayerDataServiceServer` profiles via `mutate()`/`transaction()`, which mirrors the changed slice into `ServerStore` (a Charm atom); charm-sync diffs it and ships the delta to the owning client's `ClientStore` atom, which domain client services (and any future React UI) read reactively. Clients never write authoritative state. See [docs/architecture.md](docs/architecture.md#reactive-state) for the full spine.

---

## Repository layout

```
src/
├─ ReplicatedStorage/
│  ├─ Shared/
│  │  ├─ Modules/        ServiceController, Logger, GameItems, ItemDefinitions, Utils/, Constants/
│  │  ├─ State/          SyncState — the shared charm-sync slice/key/transport contract
│  │  └─ Types/          Shared Luau types (PlayerDataTypes)
│  └─ Client/
│     ├─ Services/       *ServiceClient modules (incl. StateSyncServiceClient, DebuggerServiceClient)
│     ├─ State/          ClientStore — the client's reactive atoms, populated by charm-sync
│     └─ UI/React/       React-lua debugger overlay (F4), driven by DebuggerState atoms via useAtom
├─ ServerScriptService/
│  ├─ Services/          *ServiceServer modules (PlayerData, Currency, Inventory, Admin, StateSync)
│  ├─ State/             ServerStore — the server's reactive mirror, mirrored into by mutate()/transaction()
│  ├─ Modules/           RequestHandler, Constants/
│  ├─ Commands/          Cmdr command definitions + server implementations
│  ├─ ServerHandler.server.luau   Server entry point
│  └─ TestRunner.server.luau      Runs the TestEZ suite
├─ StarterPlayer/StarterPlayerScripts/ClientHandler.client.luau   Client entry point
└─ Workspace/, Lighting/  Baseplate / camera / lighting source

docs/        Conventions, testing, error strategy, pcall guide, limitations, CI/CD
scripts/     Python helpers for Open Cloud upload + Luau execution
tasks/       runTests.luau (CI test entry)
```

---

## Getting started

### Prerequisites

Install [Rokit](https://github.com/rojo-rbx/rokit) (the toolchain manager). It pins exact versions of every tool from [rokit.toml](rokit.toml): Rojo, Wally, wally-package-types, Selene, StyLua, and luau-lsp.

### Setup

```bash
rokit install            # install the pinned toolchain
wally install            # install Wally packages into Packages/, ServerPackages/, DevPackages/
rojo sourcemap default.project.json --output sourcemap.json

# Generate package type exports for EVERY realm, not just Packages/ — ProfileStore lives in
# ServerPackages/, and without its pass the entire data layer type-checks as `Unknown`.
wally-package-types -s sourcemap.json Packages/
wally-package-types -s sourcemap.json ServerPackages/
wally-package-types -s sourcemap.json DevPackages/
```

> A convenience script, [install.sh](install.sh), runs the above and produces a build in one go.

### Open in Studio

```bash
rojo serve               # then connect via the Rojo Studio plugin
```

Or build a standalone place file:

```bash
rojo build -o peekabu-game-systems.rbxl default.project.json
```

> The built `.rbxl` is a generated artifact and is **git-ignored** — don't commit it. The source of truth is the Rojo project under `src/`.

---

## Everyday commands

| Task | Command |
|------|---------|
| Sync to Studio | `rojo serve` |
| Build a place file | `rojo build -o peekabu-game-systems.rbxl default.project.json` |
| Lint | `selene src` |
| Check formatting | `stylua --check src` |
| Auto-format | `stylua src` |
| Install / update packages | `wally install` |

---

## Adding a new service

1. **Create the module** at `src/ServerScriptService/Services/<Name>/<Name>ServiceServer.luau` (or `src/ReplicatedStorage/Client/Services/...` for client). The `*ServiceServer` / `*ServiceClient` suffix is how the boot loaders auto-discover it.
2. **Declare dependencies**: `MyService.dependencies = { "PlayerDataServiceServer" } :: { string }`.
3. **Implement lifecycle** methods (`init`, `start`, `stop`) as fields on the annotated literal — only the ones you need.
4. **Write the spec first** — create `<Name>ServiceServer.spec.luau` alongside it (this project is test-driven; see [docs/testing.md](docs/testing.md)).
5. That's it — `ServerHandler`/`ClientHandler` register, init, and start it automatically.

See the full service template and conventions in [docs/conventions.md](docs/conventions.md).

---

## Admin commands

Administrative actions go through [Cmdr](https://eryn.io/Cmdr/), never by mutating state directly. Commands live in [src/ServerScriptService/Commands/](src/ServerScriptService/Commands/) as a definition file plus a `*Server` implementation. The permission gate in [AdminServiceServer.luau](src/ServerScriptService/Services/AdminService/AdminServiceServer.luau) **fails closed**: only Cmdr's harmless built-in groups (`DefaultUtil`, `Help`) run ungated — every other group, including unknown or missing ones, requires the invoker to be in the `UserId` allowlist in [Admin.luau](src/ReplicatedStorage/Shared/Modules/Admin.luau) (Studio sessions are always allowed for testing). Denials and runs are audit-logged.

---

## Testing

Tests use [TestEZ](https://github.com/Roblox/testez); spec files live next to the code they cover as `*.spec.luau`.

- **In Studio:** `rojo serve`, connect, then run `TestRunner.server.luau` and read the Output window.
- **In CI:** the suite runs inside a real Roblox runtime via Open Cloud Luau Execution (see below).

This is a test-driven codebase — write the spec before the implementation. Full guidance, matchers, and coverage targets are in [docs/testing.md](docs/testing.md).

---

## CI/CD

[.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) runs six jobs:

1. **Lint** (`selene src`) on every push.
2. **Format** (`stylua --check src`) on every push.
3. **Typecheck** (`luau-lsp analyze`) — the blocking type gate over `src` and `tasks/` (the CI test
   entry point). Generates package type exports for all realms (so ProfileStore in `ServerPackages/`
   type-checks) and must pass with zero errors. It gates **Test** via that job's `needs:`, so a type
   error transitively blocks merges and deploys.
4. **Scripts lint** (`ruff check scripts/python`) — the Python Open Cloud upload/publish scripts are
   the deploy mechanism itself, so they're gated like first-party code.
5. **Test** — builds the place and runs TestEZ on real Roblox infrastructure (Open Cloud), gating merges into `main`.
6. **Deploy** — on push to `main`, publishes to the production place behind a manual-approval GitHub Environment.

Configure these secrets/variables: `ROBLOX_API_KEY` (test-scoped repo secret), `ROBLOX_PROD_API_KEY` (production-scoped secret on the `production` environment), and `ROBLOX_TEST_*` / `ROBLOX_PRODUCTION_*` universe & place vars. Details in [docs/ci-cd.md](docs/ci-cd.md).

---

## Documentation

| Doc | What it covers |
|-----|----------------|
| [architecture.md](docs/architecture.md) | How the framework is wired: boot flow, ServiceController, data/transactions, networking |
| [conventions.md](docs/conventions.md) | Method syntax, assertions, error handling, naming, file templates |
| [testing.md](docs/testing.md) | Writing/running tests, TDD workflow, coverage goals |
| [error-strategy.md](docs/error-strategy.md) | When to assert vs. return vs. pcall |
| [pcall-guide.md](docs/pcall-guide.md) | Targeted error-handling patterns |
| [limitations.md](docs/limitations.md) | Known trade-offs and future considerations |
| [ci-cd.md](docs/ci-cd.md) | Pipeline setup and required secrets |

---

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR. It covers setup, the test-driven
workflow, the local check script, code conventions, and what CI enforces. In short: write the spec
first, keep `--!strict` clean with zero type errors, and run `bash scripts/check.sh` before pushing.

---

## License

**Proprietary — All Rights Reserved.** This code is not open source. See [LICENSE](LICENSE) for terms. Copying, distribution, or reuse outside this project requires the copyright holder's written permission.
