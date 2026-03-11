# Architecture

A technical reference for how the framework is wired together. For the lifecycle/style rules
authors must follow, see [conventions.md](conventions.md); for known trade-offs, see
[limitations.md](limitations.md).

---

## Realms

The project is split by Roblox realm and assembled by Rojo ([default.project.json](../default.project.json)):

- **`ReplicatedStorage/Shared`** — code that runs on both sides: `ServiceController`, `Logger`,
  pure utils (`CurrencyUtils`, `InventoryUtils`), constants, item definitions, ByteNet event
  definitions, and shared types.
- **`ReplicatedStorage/Client`** — `*ServiceClient` modules and the signals UI subscribes to.
- **`ServerScriptService`** — `*ServiceServer` modules, the `RequestHandler` middleware, Cmdr
  command definitions, and the two entry-point scripts.

The server is authoritative for all state. Clients mirror data pushed to them and never write
authoritative values.

---

## Boot sequence

**Server** ([ServerHandler.server.luau](../src/ServerScriptService/ServerHandler.server.luau)):

1. Walk `ServerScriptService.Services` and `require`/`register` every `*ServiceServer` module.
   Requiring a service runs its top-level `registerProfilePath(...)` call, so the profile
   template is assembled as a side effect of loading.
2. `GameItems.init()` builds item/currency definitions.
3. `initService("PlayerDataServiceServer", config)` is called explicitly first because it needs
   config (store name, mock flag, the assembled template).
4. `ServiceController:initAll()` initializes the rest in dependency order.
5. `ServiceController:startAll()` starts everything; cross-service calls are now safe.

**Client** ([ClientHandler.client.luau](../src/StarterPlayer/StarterPlayerScripts/ClientHandler.client.luau))
is the same shape minus data config: register every `*ServiceClient`, then `initAll()` → `startAll()`.

Discovery is by name: the loaders match modules whose names contain `Service` and end in
`Server`/`Client`. Renaming a service file off that pattern silently unregisters it.

---

## ServiceController

[ServiceController.luau](../src/ReplicatedStorage/Shared/Modules/ServiceController.luau) owns the
service registry and lifecycle. Phases: `registering → initializing → starting → running`
(`stopping` on shutdown).

**Lifecycle methods** (all optional, defined as fields in the service literal — see
[conventions: Service Module Shape](conventions.md#service-module-shape)):

| Method | When it runs | Rule |
|--------|--------------|------|
| `init(self)` | once, in dependency order | internal setup only — **do not** call other services |
| `start(self)` | after *all* services are initialized | safe to call other services |
| `stop(self)` | on shutdown, reverse order | disconnect events, end sessions, release resources |

**Dependency ordering.** Each service declares `dependencies = { "OtherServiceName" }`.
`_getTopologicalOrder()` assigns every service a level equal to its deepest dependency depth
(level 0 = no dependencies) and groups them. The result is cached and invalidated on each new
`register()`.

**Concurrency model.** `startAll()` walks levels in order. Within a level, services start
concurrently via `task.spawn`; the controller yields the caller and only advances to the next
level once every service in the current level has *fully completed* `start()` (a coroutine-resume
join counts pending services). So when your `start()` runs, every service you depend on has
finished its own `start()`. `stopAll()` does the same in reverse.

**Failure isolation.** `init`/`start`/`stop` run under `xpcall`, so one service erroring is logged
and skipped rather than aborting the whole boot. Circular dependencies are detected during level
computation and `warn`'d (not thrown) — the cycle's services land at the same level.

**Direct `require` is intentional.** Services `require()` each other directly for autocomplete and
types; the `dependencies` array (not the require) is what guarantees ordering. Luau caches modules,
so multiple requires load once. This is documented at length at the top of the module.

---

## Data layer

[PlayerDataServiceServer.luau](../src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau)
wraps [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore).

- **Sessions.** `observePlayer` starts a session on join (`StartSessionAsync`), reconciles against
  the template, and ends it on leave. Load failure or session end **kicks** the player — the
  standard ProfileStore pattern to avoid playing without valid data. In Studio a `Mock` store is
  used so test sessions never touch live data.
- **Per-player cleanup.** Each player gets its own `Janitor` holding session-scoped connections
  (`OnSessionEnd`, `OnSave`), destroyed on leave so connections never accumulate across sessions.
- **The `mutate()` choke point.** All writes go through
  `mutate(userId, path, mutator)`. It refuses to run if the profile is locked by a transaction or
  isn't loaded, applies the mutator to `profile.Data[path]`, and audit-logs success. Domain
  services never touch `profile.Data` directly.
- **Profile paths** are registered, not enumerated — see
  [limitations.md #3](limitations.md#3-profilepath-registry-vs-compile-time-paths).
- **Schema migrations.** Each profile carries a `_schemaVersion`. On join, `onPlayerAdded` reads
  the stored version *before* `Reconcile()` and runs `PlayerDataMigrations.apply()` to bring old
  profiles up to the current schema (rename/retype/remove fields that `Reconcile` can't). New
  profiles are stamped current by the template and skip migration. Migrations run on a copy, so a
  failed migration kicks the player rather than persisting a half-transformed profile. See
  [limitations.md #6](limitations.md#6-schema-versioning).

---

## Transactions

`PlayerDataServiceServer:transaction(operations)` runs multiple mutations atomically across one or
more profiles (e.g. trades). Flow:

1. **Validate** every referenced profile is loaded (no side effects — safe to bail).
2. **Lock & pre-save** each affected profile (`profilesInTransaction[userId]`), forcing a `Save()`
   to establish a fresh `LastSavedData` rollback point. Waits for saves with a 10s timeout.
3. **Apply** each operation's mutator under `pcall`. Any crash, any mutator returning `false`, or
   an auto-save detected mid-transaction rolls **all** profiles back from `LastSavedData`.
4. **Commit** by clearing locks and force-saving.

While a profile is locked, ordinary `mutate()` calls against it return `false` (logged). This is
single-server only — cross-server atomicity is out of scope (see
[limitations.md](limitations.md#5-profilestore-locking-nuances)).

---

## Networking

Events are defined as [ByteNet](https://github.com/ffrostfall/ByteNet) packets under
`Shared/Events`. Servers push deltas to the owning client (`sendTo`); for example
`CurrencyServiceServer:addCurrency` mutates, then broadcasts `{ currencyType, newAmount, delta }`.
Clients listen, apply the change through their own client-side data store, and fire a signal
(`CurrencySignals.Changed`) for UI. Currency/inventory deltas are sent per-change — see
[limitations.md #4](limitations.md#4-no-network-batching) on batching for high-frequency updates.

[RequestHandler.luau](../src/ServerScriptService/Modules/RequestHandler.luau) is opt-in middleware
for *inbound* client requests: wrap a handler to add per-player rate limiting, validation, audit
logging, and `xpcall` protection.

---

## Type synchronization

Two domain types can't be derived by Luau's checker and are handled explicitly:

- **`CurrencyType`** — a hand-maintained union in `CurrencyConstants.luau`, validated against the
  `CURRENCIES` table on boot in `CurrencyServiceServer.init()` (fails loudly on drift).
- **`ProfilePath`** — typed as `string`; correctness is enforced at runtime by the registry and
  `mutate()` rather than at compile time.

Details and rationale in [limitations.md #1](limitations.md#1-manual-type-synchronization-required).

---

## Cross-cutting utilities

| Module | Role |
|--------|------|
| [Logger](../src/ReplicatedStorage/Shared/Modules/Logger.luau) | Leveled logging (`DEBUG`/`INFO`/`WARN`/`ERROR`/`AUDIT`) with per-context prefixes; `audit` is the hook for persistent economy logging. |
| [Janitor](https://github.com/howmanysmall/Janitor) | Connection/instance cleanup, used per-player and per-service. |
| [Cmdr](https://eryn.io/Cmdr/) | Admin command registration + the `BeforeRun` permission gate in `AdminServiceServer`. |
| [Observers](https://github.com/Sleitnick/Observers) | `observePlayer` lifecycle binding. |
| sift | Deep table copies used in transaction rollback. |
