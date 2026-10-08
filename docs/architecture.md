# Architecture

A technical reference for how the framework is wired together. For the lifecycle/style rules
authors must follow, see [conventions.md](conventions.md); for known trade-offs, see
[limitations.md](limitations.md).

---

## Realms

The project is split by Roblox realm and assembled by Rojo ([default.project.json](../default.project.json)):

- **`ReplicatedStorage/Shared`** — code that runs on both sides: `ServiceController`, `Logger`,
  pure utils (`CurrencyUtils`, `InventoryUtils`), constants, item definitions, ByteNet event
  definitions, shared types, and the reactive-state contract (`Shared/Features/StateSync/Data/StateSyncConstants`).
- **`ReplicatedStorage/Client`** — `*ServiceClient` modules, the React UI (`Client/UI`), and the
  client reactive store (`Client/Features/StateSync/State/StateSyncClientStore`) the UI reads via `useAtom`.
- **`ServerScriptService`** — `*ServiceServer` modules, the server reactive projection
  (`ServerScriptService/Features/StateSync/State/StateSyncServerStore`), the `RequestHandler` middleware, Cmdr command
  definitions, and the two entry-point scripts.

The server is authoritative for all state. Clients mirror data pushed to them and never write
authoritative values.

---

## Boot sequence

**Server** ([ServerHandler.server.luau](../src/ServerScriptService/ServerHandler.server.luau)):

1. Walk `ServerScriptService.Features` and `require`/`register` every `*ServiceServer` module at a feature root.
   Requiring a slice-owning service runs its top-level `PlayerDataSliceSystem.registerSlot` / `registerAccount`
   call (which registers the slice's dotted profile path), so the profile template is assembled as
   a side effect of loading.
2. `ItemContentRegistry.init()` builds item/currency definitions.
3. `initService("PlayerDataServiceServer", config)` is called explicitly first because it needs
   config (store name, mock flag, the assembled template).
4. `ServiceController:initAll()` initializes the rest in dependency order.
5. `ServiceController:startAll()` starts everything; cross-service calls are now safe.

**Client** ([ClientHandler.client.luau](../src/StarterPlayer/StarterPlayerScripts/ClientHandler.client.luau))
is the same shape minus data config: `ItemContentRegistry.init()` first (the client needs the same
`ItemRegistry` registry the server has, or applying a replicated inventory delta throws
`invalid item type` locally), then register every `*ServiceClient`, then `initAll()` → `startAll()`.

Discovery is by name: the loaders match modules whose names contain `Service` and end in
`Server`/`Client`. Renaming a service file off that pattern silently unregisters it.

---

## ServiceController

[ServiceController.luau](../src/ReplicatedStorage/Shared/Core/ServiceController.luau) owns the
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

[PlayerDataServiceServer.luau](../src/ServerScriptService/Features/PlayerData/PlayerDataServiceServer.luau)
wraps [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore).

- **Sessions.** `observePlayer` starts a session on join (`StartSessionAsync`), reconciles against
  the template, and ends it on leave. Load failure or session end **kicks** the player — the
  standard ProfileStore pattern to avoid playing without valid data. In Studio a `Mock` store is
  used so test sessions never touch live data.
- **`profileLoaded` (userId).** Fires once a session has started and the reactive mirror is seeded. A body
  can spawn before this, because the client's `Ready` does not wait for data, so anything that publishes from
  the profile (the public look: `CustomizationPublishSystem`) listens here as well as to the spawn.
- **Per-player cleanup.** Each player gets its own `Janitor` holding session-scoped connections
  (`OnSessionEnd`, `OnSave`), destroyed on leave so connections never accumulate across sessions.
  `_cleanupPlayer` (and `stop()`) also sweep any lingering `profilesInTransaction` lock for the
  user, so a lock can never outlive the session and refuse a future one.
- **The `mutate()` choke point.** All writes go through
  `mutate(userId, path, mutator)`, where `path` is a dotted `ProfilePath` (`slots.2.currency`,
  `account.settings`) resolved against `profile.Data` at call time. It refuses to run if the
  profile is locked by a transaction, isn't loaded, or if the call is itself nested inside another
  mutator (see the atomicity note under Transactions), then snapshots the slice, applies the
  mutator to the resolved container, and audit-logs success. Like `transaction()`, it is
  all-or-nothing per call: a mutator that yields, errors, or returns `false` is rolled back to the
  snapshot — so a `false` return ("no change") guarantees the stored state is unchanged even if the
  mutator wrote before aborting, and no partial write can leak into the next auto-save. Domain
  services never touch `profile.Data` directly.
- **Profile paths** are registered, not enumerated — see
  [limitations.md #3](limitations.md#3-profilepath-registry-vs-compile-time-paths).
- **Schema migrations.** Each profile carries a `_schemaVersion`. On join, `onPlayerAdded` reads
  the stored version *before* `Reconcile()` and runs `PlayerDataMigrationSystem.apply()` to bring old
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
   mirrored into `StateSyncServerStore`.

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
mirrors the changed slice into `StateSyncServerStore`; charm-sync diffs the atom and ships the delta over its
dedicated `RemoteEvent`; the client's `StateSyncClientStore` atom updates and the UI re-renders. **The
charm-sync readiness ping (`CharmSyncReady`) is part of this channel** — it rides the same dedicated
`RemoteEvent`, *not* ByteNet, because it belongs to the state transport (this is the documented
RemoteEvent exception in [Reactive state](#reactive-state)). If you catch yourself wanting to send a
value the client could also *ask for* — it's state; put it in an atom.

**2. Everything else → [ByteNet](https://github.com/ffrostfall/ByteNet), the default.** Discrete,
fixed-schema, fire-and-forget messages that are **not** backed by queryable state — an inbound action
request, a one-off "you levelled up" / "show this VFX" signal, an RPC. These are defined as ByteNet
packets under `Shared/Features/<Feature>/Net`. ByteNet's value is its buffer encoder, so a packet needs a static
struct — which is exactly why it *can't* carry the dynamically-shaped charm-sync payload, and why
state uses the RemoteEvent instead. The **first live ByteNet consumer** is
[`Shared/Features/Debugger/Net/DebuggerEvents.luau`](../src/ReplicatedStorage/Shared/Features/Debugger/Net/DebuggerEvents.luau) — the
Service & State Debugger's `SetSubscription` (typed `bool`), `Snapshot`, and `ClearServerLogs` packets.
Copy that module's shape (a shared namespace both realms require, with the client boot-timing guard)
for any new event set.

> Rule of thumb: **state → atom (charm-sync); event → packet (ByteNet).** If it has a current value
> the client can read at any time, it's state. If it's a momentary "this just happened" with nothing
> to query afterward, it's an event.

> *Continuous, high-rate, per-viewer state (character motion) is a third case: it rides typed **unreliable**
> ByteNet packets owned by the character replication service. It is not an atom, because charm-sync is
> reliable-ordered, diffs every frame, and is identical for every viewer. It is not a one-off event either.*
> The packets live in [`Shared/Features/Replication/Net/ReplicationEvents.luau`](../src/ReplicatedStorage/Shared/Features/Replication/Net/ReplicationEvents.luau)
> (the repo's first unreliable packets); see [Bodies](#bodies-character-replication).

[RequestHandler.luau](../src/ServerScriptService/Core/Net/RequestHandler.luau) is opt-in middleware
for *inbound* client requests: wrap a handler to add per-player rate limiting, validation, audit
logging, and `xpcall` protection.

### Provisioned dependencies

Both dependencies that were once staged-but-unused now have a live consumer: the **Service & State
Debugger** (`DebuggerService`, the F4 in-game overlay) is the reference integration for each. New
systems should copy how it uses them.

- **ByteNetMax** — the default transport for discrete/event packets (see [Networking](#networking)).
  Live in [`DebuggerEvents`](../src/ReplicatedStorage/Shared/Features/Debugger/Net/DebuggerEvents.luau): typed
  `SetSubscription` and `ClearServerLogs` packets plus a `Snapshot` packet. The snapshot uses
  `ByteNet.unknown` for the same
  reason the charm-sync channel is exempt from a static struct — it aggregates arbitrary `getState()`
  shapes and live atom values that no fixed struct can describe. For a *fixed*-shape event, define a
  real struct instead. Reach for ByteNet under `Shared/Features/<Feature>/Net`, never raw `RemoteEvent`s.
- **Promise** — the standard async primitive for any system doing yielding or parallel work (batched
  I/O, retries, `Promise.all`-style fan-out). Live in
  [`DebuggerServiceServer`](../src/ServerScriptService/Features/Debugger/DebuggerServiceServer.luau):
  each service's `getState()` is assembled through `Promise.try():timeout()` so one hanging or
  yielding `getState` is contained (reported as a per-service `stateError`) instead of stalling the
  whole snapshot. Prefer it over hand-rolled callback/coroutine plumbing.

Treat them as available building blocks — the debugger modules above are the reference `require`s.

---

## Reactive state

Replicated player state (currency, inventory, and any future synced slice) flows through one spine,
built on [Charm](https://github.com/littensy/charm) atoms + [charm-sync](https://github.com/littensy/charm-sync),
ready to feed any future [react-charm](https://github.com/littensy/react-charm) HUD via `useAtom`
(the debugger overlay already reads its own `DebuggerStore` atoms this way):

```
mutate()/transaction()
   └─► StateSyncServerStore atoms ──► charm-sync (diff + Heartbeat batch) ──► RemoteEvent ──►
        └─► StateSyncClientStore atoms ──► { domain client services via getters,  future React UI via useAtom }
```

- **`StateSyncServerStore`** (`ServerScriptService/Features/StateSync/State`) — the server-authoritative reactive mirror. On
  profile load, every registered slice is deep-copied into its Charm atom (`syncFromProfile`); after
  a committed `mutate`/`transaction`, only the slice(s) that path actually touched are re-mirrored
  (`sync`), not the whole profile. The deep copy is required: `mutate` edits the live profile table
  in place, so without a copy charm-sync's diff would see no change.
- **`StateSyncClientStore`** (`Client/Features/StateSync/State`) — the **single** client source of truth.
  `CurrencyServiceClient`/`InventoryServiceClient` are thin read-facades over it, and any future
  React UI reads it with `useAtom`.
- **`StateSyncConstants`** (`Shared/Features/StateSync/Data`) — the shared contract: the `SLICES` list, the player-scoped
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

Adding a synced slice: add one entry to `StateSyncSliceRegistry` (`Shared/Features/StateSync/Data/StateSyncSliceRegistry.luau`, the
single declaration site — name + profile reader), and declare its atom + registry line in
`StateSyncClientStore` (kept in the client realm so the UI-facing atoms stay narrowly typed).
`StateSyncConstants.SLICES` and the entire `StateSyncServerStore` registry derive from the manifest, so neither is an
edit site, and the StateSync services are unchanged. `StateSyncClientStore` validates its registry against
the manifest at require time — a missing atom fails loudly at boot rather than the first time a
client tries to sync it. See
[conventions: Owning a profile slice](conventions.md#adding-a-service-that-owns-a-profile-slice).

---

## Bodies (character replication)

There is **no engine character**. `Players.CharacterAutoLoads` is `false` (a property-only node in
`default.project.json`); the server destroys any engine character that appears and holds, per player, a
replication slot, a body epoch, the validated newest sample, and server-owned health — never a model. Each
client builds its own rig (`LocalPlayer.Character`, simulated by a normal Humanoid) and draws everyone else as
pooled, anchored **puppets**. Design: `docs/superpowers/specs/2026-09-22-character-replication-design.md`.

**One body API.** No system reads `player.Character` for another player's body.

| Side | API | Meaning |
|---|---|---|
| Server (`ReplicationServiceServer`) | `bodySpawned(player, epoch)` / `bodyDespawned(player, epoch)` | A body began / ended (join, respawn, slot switch, leave). SignalPlus: delivered deferred, in order |
| | `observeBodies(callback) -> disconnect` | `callback(player, epoch)` for every live body now and later; the cleanup it returns runs at despawn |
| | `hasBody(player)`, `getBodyPosition(player)` | The live body and its newest accepted position |
| | `respawn(player, reason)` | New epoch, server-chosen spawn; the owner rebuilds. Does not yield |
| | `setMaxHealth(userId, maxHealth)` | Health is server state; clamped down, published on the public slice |
| Client (`ReplicationServiceClient`) | `bodySpawned(player, rig)` / `bodyDespawned(player, rig)` | A rig this client shows appeared / went (the owner rig, or a puppet). Delivered deferred too (SignalPlus), so a `bodyDespawned(player, rig)` handler runs after that puppet is back in the pool: consumers must not keep using the rig |
| | `getRig(player)`, `getPlayerFromRig(rig)`, `getLocalRig()` | The rig registry. Resolve owners by id through it, never by instance name |

**Lifecycle.** Join → slot claimed and broadcast → the client's `Ready` → `Session` (time epoch), the whole
slot table, `Spawn` → the owner builds its rig and streams send-on-change samples (unreliable `Uplink`,
through `RequestHandler`). Every Heartbeat the server relays bodies to the viewers that have them loaded
(600 studs in, 630 out; reliable `Enter` / `Leave`; unreliable `Downlink` ≤ 700 B per viewer-frame).

**Timed body state (R3).** A timed state on a body that every observer, including a late one, must see
(an action today; lasting VFX statuses later). A consumer defines its kind once at start,
`defineBodyState(kind, senders)`, and gets a typed channel (`set(player, key, data, startMs, durationMs?)`,
`clear`, `get`); the kind brings its own typed reliable packets, the service decides who receives them and
when (`ReplicationBodyStateTracker` core, `ReplicationBodyStateSender`): Started to the owner and its observers, Stopped only on an
early stop, a replay right after every `Enter`, silent clearing on respawn, slot switch and leave, at most
8 states per body per kind, and a 30 s safety cap on open-ended states. Relevance helpers for later
effects: `observersOf(player)`, `observersNear(position, radius)`, `sendToObservers(player, packet, data)`;
`nowMs()` is the session clock states are stamped with. Animation is the first consumer: see
[animation.md](animation.md), "Replicated actions".

| Transport | Shape | Examples |
|---|---|---|
| Replication, unreliable records | Continuous, body-tied, nearby only | Position, movement state, ragdoll pose |
| Replication, reliable timed body state | A timed state on a body that observers (incl. late ones) must see | Actions, lasting VFX statuses |
| Replication, `sendToObservers` / `observersNear` | One-off, nearby-only events | An explosion at a point, a hit spark |
| charm-sync | Queryable state | Inventory, stats, cooldown timers, public slice |
| ByteNet reliable to one player | Outcomes for one player | Purchase result, denial reasons |

**Public data.** What any client may know about another player (R2: health) rides charm-sync as the
public slice: `StateSyncPublicPlayerStore` on the server, `StateSyncClientStore.publicPlayers` on the client, filtered to the
players relevant to that client (its loaded bodies plus itself). A body whose entry has not arrived yet
renders with defaults.

**Remote `Character` (R5).** Each client sets every remote player's `Player.Character` to that player's
puppet (`ReplicationRigTracker`, the one writer), and clears it when the puppet is released. It is client-local (the
server keeps `Character = nil`). Its only purpose is the engine's own voice speaking icon; nothing in our code
reads a remote `Character` — use `getRig` / `getPlayerFromRig`.
The engine's default `RbxCharacterSounds` is replaced by an empty LocalScript of that name
(`StarterPlayerScripts`): the default builds sounds for every `Character`, which made each assignment cost
about 9 ms; without it an assignment is under 1 ms. Character sounds, the local body's included, come with the
later sound work.

**Voice (R5).** `VoiceServiceServer` gives each player an `AudioDeviceInput` named `VoiceInput`;
`VoiceServiceClient` wires every other player's input to an `AudioEmitter` on their puppet head (full to 10
studs, silent at 80) and listens through the camera. Text bubbles are off
(`default.project.json` sets `TextChatService.BubbleChatConfiguration.Enabled = false`); the speaking icon stays.

**`Diagnostics` (Workspace attribute, default off).** `true` turns on test-only checks. Today: the
replication tripwire (`ReplicationViewCheck`, once a second), which logs a warning when a body the server says
you should see has no puppet, a player has no slot entry, or a puppet is orphaned or duplicated, or a remote player's `Character` disagrees with the registry (`characterMismatch`). Off = the
checks are not connected at all. Turn it on for a test, off after.

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
| [Logger](../src/ReplicatedStorage/Shared/Core/Logger.luau) | Leveled logging (`DEBUG`/`INFO`/`WARN`/`ERROR`/`AUDIT`) with per-context prefixes. Records every line into a ring buffer (`getHistory`/`subscribe`, read by the debug overlay); WARN/ERROR also `warn` to the console and AUDIT also `print`s (so the economy trail reaches server output). `audit` is the hook for persistent economy logging. |
| [Janitor](https://github.com/howmanysmall/Janitor) | Connection/instance cleanup, used per-player and per-service. |
| [Cmdr](https://eryn.io/Cmdr/) | Admin command registration + the `BeforeRun` permission gate in `AdminServiceServer`. |
| [Observers](https://github.com/Sleitnick/Observers) | `observePlayer` lifecycle binding. |
| sift | Immutable table helpers: deep copies for transaction/migration rollback (`copyDeep`) and deep-frozen read snapshots (`freezeDeep`, behind `getProfile` / the per-slice `_getSliceShell`). |
