# Architecture

A technical reference for how the framework is wired together. For the lifecycle/style rules
authors must follow, see [conventions.md](conventions.md); for known trade-offs, see
[limitations.md](limitations.md).

---

## Realms

The project is split by Roblox realm and assembled by Rojo ([default.project.json](../default.project.json)):

- **`ReplicatedStorage/Shared`** — code that runs on both sides: `ServiceController`, `Logger`,
  pure utils (`CurrencyUtils`, `InventoryUtils`), constants, item definitions, ByteNet event
  definitions, shared types, and the reactive-state contract (`Shared/State/SyncState`).
- **`ReplicatedStorage/Client`** — `*ServiceClient` modules, the React UI (`Client/UI`), and the
  client reactive store (`Client/State/ClientStore`) the UI reads via `useAtom`.
- **`ServerScriptService`** — `*ServiceServer` modules, the server reactive projection
  (`ServerScriptService/State/ServerStore`), the `RequestHandler` middleware, Cmdr command
  definitions, and the two entry-point scripts.

The server is authoritative for all state. Clients mirror data pushed to them and never write
authoritative values.

---

## Boot sequence

**Server** ([ServerHandler.server.luau](../src/ServerScriptService/ServerHandler.server.luau)):

1. Walk `ServerScriptService.Services` and `require`/`register` every `*ServiceServer` module.
   Requiring a slice-owning service runs its top-level `SliceOwner.register(...)` call (which
   registers the profile path), so the profile template is assembled as a side effect of loading.
2. `GameItems.init()` builds item/currency definitions.
3. `initService("PlayerDataServiceServer", config)` is called explicitly first because it needs
   config (store name, mock flag, the assembled template).
4. `ServiceController:initAll()` initializes the rest in dependency order.
5. `ServiceController:startAll()` starts everything; cross-service calls are now safe.

**Client** ([ClientHandler.client.luau](../src/StarterPlayer/StarterPlayerScripts/ClientHandler.client.luau))
is the same shape minus data config: `GameItems.init()` first (the client needs the same
`ItemDefinitions` registry the server has, or applying a replicated inventory delta throws
`invalid item type` locally), then register every `*ServiceClient`, then `initAll()` → `startAll()`.

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

**Failure isolation.** `start`/`stop` run under `xpcall`, so one service erroring there is logged
and skipped rather than aborting the whole boot. `init` failures are deliberately fatal: `initAll()`
collects every failure and then errors the boot ("N service(s) failed to init") — a service that
couldn't set itself up must not be silently absent at start time. Circular dependencies are also a
hard error: level computation detects the cycle and throws, naming the participating services.

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
  `_cleanupPlayer` (and `stop()`) also sweep any lingering `profilesInTransaction` lock for the
  user, so a lock can never outlive the session and refuse a future one.
- **The `mutate()` choke point.** All writes go through
  `mutate(userId, path, mutator)`. It refuses to run if the profile is locked by a transaction,
  isn't loaded, or if the call is itself nested inside another mutator (see the atomicity note
  under Transactions), then snapshots the slice, applies the mutator to `profile.Data[path]`, and
  audit-logs success. Like `transaction()`, it is all-or-nothing per call: a mutator that yields,
  errors, or returns `false` is rolled back to the snapshot — so a `false` return ("no change")
  guarantees the stored state is unchanged even if the mutator wrote before aborting, and no
  partial write can leak into the next auto-save. Domain services never touch `profile.Data`
  directly.
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

`PlayerDataServiceServer:transaction(operations, options?)` runs multiple mutations atomically
across one or more profiles (e.g. trades). Flow:

1. **Validate** every op is well-formed (numeric `userId`, string `path`, function `mutator`), every
   referenced profile is loaded, and every referenced path exists — a pass with no side effects, so
   bailing (or a malformed-op assert) here can never leave an earlier profile locked. A profile
   already inside another transaction is refused (re-entry guard) rather than re-locked.
2. **Lock & snapshot** each affected profile (`profilesInTransaction[userId]`) and take an in-memory
   deep copy of each touched path as the rollback anchor. There is **no** forced `Save()`, no
   `LastSavedData`, and no timeout wait — mutators can't yield (next step), so nothing interleaves
   between the snapshot and commit, which makes an in-memory copy a complete rollback point.
3. **Apply** each operation's mutator in a coroutine (not `pcall`) so a yield is actively detected:
   mutators MUST be synchronous, and a yielding one is rejected. Any crash, any mutator returning
   `false`, a yield, or an auto-save detected mid-transaction rolls **all** profiles back from their
   snapshots. While a mutator runs, **every** nested `mutate()`/`transaction()` call is refused —
   even on a profile the transaction does not touch — because a nested write commits outside this
   transaction's snapshots and would survive its rollback. Compose multi-profile writes as sibling
   ops of one transaction instead.
4. **Commit** by clearing the locks. By default this is an **in-memory commit only** — the change
   rides the normal ProfileStore auto-save, exactly like `mutate()`. Pass `{ persist = true }` for
   economy-critical writes to force an immediate save per profile with bounded retries; because
   ProfileStore's `Save()` only *dispatches* the write, durability is confirmed by waiting
   (bounded) for each profile's `OnAfterSave` — the returned `TransactionResult` reports
   `persisted` and any `failedUserIds`. On commit, only the slices that actually changed are
   mirrored into `ServerStore`.

Before committing, every affected profile is re-checked for `IsActive()`; if one ended its session
mid-transaction the whole thing rolls back rather than committing an asymmetric result. While a
profile is locked, ordinary `mutate()` calls against it return `false` (logged). This is
single-server only — cross-server atomicity is out of scope (see
[limitations.md](limitations.md#5-profilestore-locking-nuances)).

---

## Networking

There are two channels, split by *what kind of thing* is being sent:

**1. Reactive state → the charm-sync spine.** Anything that is queryable player state (currency,
inventory, any future synced slice) flows through the reactive spine (see [Reactive
state](#reactive-state) below), never a per-change packet. A write mutates the profile; `mutate`
mirrors the changed slice into `ServerStore`; charm-sync diffs the atom and ships the delta over its
dedicated `RemoteEvent`; the client's `ClientStore` atom updates and the UI re-renders. **The
charm-sync readiness ping (`CharmSyncReady`) is part of this channel** — it rides the same dedicated
`RemoteEvent`, *not* ByteNet, because it belongs to the state transport (this is the documented
RemoteEvent exception in [Reactive state](#reactive-state)). If you catch yourself wanting to send a
value the client could also *ask for* — it's state; put it in an atom.

**2. Everything else → [ByteNet](https://github.com/ffrostfall/ByteNet), the default.** Discrete,
fixed-schema, fire-and-forget messages that are **not** backed by queryable state — an inbound action
request, a one-off "you levelled up" / "show this VFX" signal, an RPC. These are defined as ByteNet
packets under `Shared/Events`. ByteNet's value is its buffer encoder, so a packet needs a static
struct — which is exactly why it *can't* carry the dynamically-shaped charm-sync payload, and why
state uses the RemoteEvent instead. The **first live ByteNet consumer** is
[`Shared/Events/DebuggerEvents.luau`](../src/ReplicatedStorage/Shared/Events/DebuggerEvents.luau) — the
Service & State Debugger's `SetSubscription` (typed `bool`), `Snapshot`, and `ClearServerLogs` packets.
Copy that module's shape (a shared namespace both realms require, with the client boot-timing guard)
for any new event set.

> Rule of thumb: **state → atom (charm-sync); event → packet (ByteNet).** If it has a current value
> the client can read at any time, it's state. If it's a momentary "this just happened" with nothing
> to query afterward, it's an event.

[RequestHandler.luau](../src/ServerScriptService/Modules/RequestHandler.luau) is opt-in middleware
for *inbound* client requests: wrap a handler to add per-player rate limiting, validation, audit
logging, and `xpcall` protection.

### Provisioned dependencies

Both dependencies that were once staged-but-unused now have a live consumer: the **Service & State
Debugger** (`DebuggerService`, the F4 in-game overlay) is the reference integration for each. New
systems should copy how it uses them.

- **ByteNetMax** — the default transport for discrete/event packets (see [Networking](#networking)).
  Live in [`DebuggerEvents`](../src/ReplicatedStorage/Shared/Events/DebuggerEvents.luau): typed
  `SetSubscription` and `ClearServerLogs` packets plus a `Snapshot` packet. The snapshot uses
  `ByteNet.unknown` for the same
  reason the charm-sync channel is exempt from a static struct — it aggregates arbitrary `getState()`
  shapes and live atom values that no fixed struct can describe. For a *fixed*-shape event, define a
  real struct instead. Reach for ByteNet under `Shared/Events`, never raw `RemoteEvent`s.
- **Promise** — the standard async primitive for any system doing yielding or parallel work (batched
  I/O, retries, `Promise.all`-style fan-out). Live in
  [`DebuggerServiceServer`](../src/ServerScriptService/Services/DebuggerService/DebuggerServiceServer.luau):
  each service's `getState()` is assembled through `Promise.try():timeout()` so one hanging or
  yielding `getState` is contained (reported as a per-service `stateError`) instead of stalling the
  whole snapshot. Prefer it over hand-rolled callback/coroutine plumbing.

Treat them as available building blocks — the debugger modules above are the reference `require`s.

---

## Reactive state

Replicated player state (currency, inventory, and any future synced slice) flows through one spine,
built on [Charm](https://github.com/littensy/charm) atoms + [charm-sync](https://github.com/littensy/charm-sync),
ready to feed any future [react-charm](https://github.com/littensy/react-charm) HUD via `useAtom`
(the debugger overlay already reads its own `DebuggerState` atoms this way):

```
mutate()/transaction()
   └─► ServerStore atoms ──► charm-sync (diff + Heartbeat batch) ──► RemoteEvent ──►
        └─► ClientStore atoms ──► { domain client services via getters,  future React UI via useAtom }
```

- **`ServerStore`** (`ServerScriptService/State`) — the server-authoritative reactive mirror. On
  profile load, every registered slice is deep-copied into its Charm atom (`syncFromProfile`); after
  a committed `mutate`/`transaction`, only the slice(s) that path actually touched are re-mirrored
  (`sync`), not the whole profile. The deep copy is required: `mutate` edits the live profile table
  in place, so without a copy charm-sync's diff would see no change.
- **`ClientStore`** (`Client/State`) — the **single** client source of truth.
  `CurrencyServiceClient`/`InventoryServiceClient` are thin read-facades over it, and any future
  React UI reads it with `useAtom`.
- **`SyncState`** (`Shared/State`) — the shared contract: the `SLICES` list, the player-scoped
  `key(slice, userId)` helper, and the transport `REMOTE_NAME`. Both StateSync services iterate
  `SLICES`, so they never name an individual slice.
- **`StateSyncServiceServer` / `StateSyncServiceClient`** — the transport. charm-sync is
  transport-agnostic; the server forwards its diff payloads over a **dedicated `RemoteEvent`** and
  the client applies them with `client.patch`.

**Why a `RemoteEvent`, not a ByteNet packet** (a deliberate exception to the Networking convention):
charm-sync's payload is a dynamically-shaped diff (`{type, data: {[string]: any}}`), so no static
ByteNet struct can describe it. The only ByteNet type that could carry it (`ByteNet.unknown`) ships
the value via Roblox's default serializer anyway — byte-for-byte identical to a plain RemoteEvent,
with **zero** encoding benefit — while adding a second per-frame coalescing hop and coupling
charm-sync to ByteNet. So the reactive channel keeps its own RemoteEvent. ByteNet stays the right
tool for discrete typed events; reactive whole-slice state is charm-sync's job.

**Deltas.** Atoms replicate current *state*, not per-mutation events. A consumer that needs "what
changed" derives it from `Charm.subscribe(atom, function(new, old) … end)` (net-per-frame, since
charm-sync coalesces on Heartbeat). There is no standing per-domain signal layer.

Adding a synced slice: add one entry to `SliceManifest` (`Shared/State/SliceManifest.luau`, the
single declaration site — name + profile reader), and declare its atom + registry line in
`ClientStore` (kept in the client realm so the UI-facing atoms stay narrowly typed).
`SyncState.SLICES` and the entire `ServerStore` registry derive from the manifest, so neither is an
edit site, and the StateSync services are unchanged. `ClientStore` validates its registry against
the manifest at require time — a missing atom fails loudly at boot rather than the first time a
client tries to sync it. See
[conventions: Owning a profile slice](conventions.md#adding-a-service-that-owns-a-profile-slice).

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
| [Logger](../src/ReplicatedStorage/Shared/Modules/Logger.luau) | Leveled logging (`DEBUG`/`INFO`/`WARN`/`ERROR`/`AUDIT`) with per-context prefixes. Records every line into a ring buffer (`getHistory`/`subscribe`, read by the debug overlay); WARN/ERROR also `warn` to the console and AUDIT also `print`s (so the economy trail reaches server output). `audit` is the hook for persistent economy logging. |
| [Janitor](https://github.com/howmanysmall/Janitor) | Connection/instance cleanup, used per-player and per-service. |
| [Cmdr](https://eryn.io/Cmdr/) | Admin command registration + the `BeforeRun` permission gate in `AdminServiceServer`. |
| [Observers](https://github.com/Sleitnick/Observers) | `observePlayer` lifecycle binding. |
| sift | Immutable table helpers: deep copies for transaction/migration rollback (`copyDeep`) and deep-frozen read snapshots (`freezeDeep`, behind `getProfile` / the per-slice `_getSliceShell`). |
