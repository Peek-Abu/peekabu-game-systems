# Character replication R5 — robustness, voice, chat settings

Status: DRAFT for developer review. Written 2026-10-05. Builds on
`docs/superpowers/specs/2026-09-22-character-replication-design.md` (CP1–CP12; CP3 voice and CP12 are the
evidence for this release) and the R4 appearance design. Branch `feature/replication-chat-voice`, cut from
`feature/replication-appearance` (R4, PR #34). R2–R5 merge together once R5 is verified.

Scope, in order of priority:

1. **Robustness pass** — prove the real build never loses a body (join, rejoin, stall), with a tripwire that
   makes any such failure loud and explained.
2. **Voice on client-built bodies**, with the engine's own speaking icon.
3. **Small items** — #32 (two hygiene fixes) and the chat/voice place settings.

## Settled decisions

1. **Bubbles off.** Old Venture had none. `BubbleChatConfiguration.Enabled = false`. A client-set
   `Character` would give native bubbles cheaply later (CP12), so this is reversible.
2. **Chat runs on `TextChatService`**, never the legacy system (removed by Roblox on 2025-04-30).
3. **Voice uses the CP3 client-wired route.** The engine's default voice cannot drive our bodies: it wires
   the server's `Character`, which is nil (CP12 T4: icon shown, nobody heard). No server speaker parts, so no
   position leak.
4. **Remote players' `Player.Character` is set on each client to their puppet.** This gives the engine's
   own speaking icon, animated, with zero icon code (CP12 T5a). Bubbles off keeps the icon (T5c). It is
   client-local: the server keeps `Character = nil` (measured).
5. **Voice range** full to 10 studs, silent at 80 (approved at CP3). Constants in code, not attributes.
6. **No server voice culling** (`SetUserIdAccessList`). Proven in CP12, not needed until bandwidth says so.
7. **The tripwire is a test instrument, gated off.** A general Workspace attribute `Diagnostics` (default
   off). Off = the tripwire is not connected at all. No auto-recovery: everything it can report is a bug to
   root-cause, never a state to heal. Gating the *existing* diagnostics behind the same switch is #35, not
   R5.
8. **#33 (`tuneoffset` on live servers) stays Studio-only** and out of R5.
9. **The CP9 kinematic `AnimationConstraint` move joint is withdrawn** as a candidate (CP12: on some joins
   it stopped driving the unanchored root and the bodies fell). The real build keeps anchored roots + one
   `BulkMoveTo`.

## Section 1 — robustness pass

### 1.1 What the real build already guarantees (read from the code)

- **Join handshake.** The client connects every listener, then sends `Ready`; the server answers with
  `Session`, the whole slot table and (on join) `Spawn`. A repeated `Ready` resets that viewer's stream.
- **Visibility is server-decided.** A body is shown from a reliable `Enter` (carrying a full-state record,
  placed at once) and hidden only on a reliable `Leave`. There is no client-side timeout.
- **A stall holds.** `RemoteBodies.frame` keeps placing a body whose samples ran out (`hold`, dead-reckoned
  for at most `MAX_RECKON_MS` = 60 ms) at its last place.
- **A held puppet is hidden only when** its buffer is empty (just after a respawn, until the first
  new-epoch sample), it is not dressed yet (≤ 1 s, then the default look), its `Player` has not replicated
  to this client yet (`unheld.noPlayer`), or the pool is empty (`unheld.poolEmpty`).

The prototype failures in CP12 (bodies falling; bodies vanishing during stalls) came from two
prototype-only mechanisms (the constraint move mode and a 1.5 s release timeout) that the real build does not
have. What the real build lacks is *evidence*: the rejoiner's side and a real stall were never exercised.

### 1.2 `ReplicationTripwire` (client, pure, specced)

New `src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire.luau`.

- **Pure:** `ReplicationTripwire.new()`, `check(tripwire, snapshot, nowSeconds) -> { Episode }` (episodes
  that started or ended this check), `getState(tripwire)`. The client service builds the snapshot; the
  module never touches instances.
- **Snapshot** (built once a second by the service): every other `Player` with the time this client first
  saw them; the slot table's known userIds; each visible body (slot, userId, generation, epoch) with whether
  it is held, placed last frame, dressed, buffer empty, and its `Player` present; each held puppet's owner;
  and each remote player's current `Character`.
- **Checks** (an *episode* starts when a condition first holds past its allowance and ends when it clears):

| Check | Condition | Allowance |
|---|---|---|
| `missing` | a visible body has no placed puppet | not dressed 1.5 s · empty buffer after a respawn 2 s · `Player` not replicated 3 s · otherwise 0.5 s |
| `unknownPlayer` | another player has been in the game with no slot-table entry | 3 s from first seen |
| `orphan` | a held puppet whose slot has no visible body, or whose owner differs from the body | 0.5 s |
| `duplicate` | two held puppets for one userId | none |
| `characterMismatch` | a remote player's `Character` is neither the registry's puppet for them nor nil when they have none | 0.5 s |

- **Output:** one `log:warn` per episode start and one per end, naming check, reason, slot, generation,
  epoch, userId and duration. Counters per check plus the open episodes in `getState().tripwire` (F4).
- **Gate:** the client service watches Workspace `Diagnostics`. `true` connects a 1 Hz check; anything else
  disconnects it and drops its state. The attribute listener is the only cost when off.
- **No recovery path.** No `Ready` resend, no rebuild: an episode in testing is a bug to root-cause.

### 1.3 Stall test (no repo change)

Studio's network setting `settings().Network.IncomingReplicationLag` holds everything arriving at one
process; raising it mid-session and dropping it back to 0 is a stall followed by a burst. Set on a client's
window it stalls that viewer's downlink; on the server's window it stalls the uplink. To verify first: that
the setting is per Studio process in a multi-client test. Fallback if not: a local, **uncommitted** gate on
the client listeners, reverted after the run.

The uplink half also checks enforcement: after a 2.5 s uplink silence the owner's next samples are far from
its last accepted one; the movement rules must accept them (they are time-stamped) without a violation or a
correction storm.

### 1.4 Join / rejoin / stall matrix

Run with `Diagnostics = true`. **Pass:** zero tripwire episodes in every row, except that rows 7–8 may show
`hold` in the stats (a stall is not an episode).

| # | Case | Who / where |
|---|---|---|
| 1 | Join a server that already has players: the joiner sees everyone, everyone sees the joiner | me, Studio 3 clients; developer, staging |
| 2 | Rejoin within ~1 s (slot reused at once) — both the rejoiner's and the stayer's view | developer, staging |
| 3 | Rejoin after 60 s+ | developer, staging |
| 4 | Rejoin while the other player is out of range, then walk into range | developer, staging |
| 5 | Leave during a respawn | developer, staging |
| 6 | Two players rejoin at the same time | developer, staging |
| 7 | 2.5 s stall, each direction: bodies hold, nothing vanishes, no slide on recovery, no violation | me, Studio |
| 8 | 10 s stall, each direction: the same, plus a clean catch-up of the render delay | me, Studio |

Every row that can be expressed as a spec gets one first (e.g. a slot entry that arrives before its
`Player` replicates; an `Enter` for a body whose slot generation is stale).

## Section 2 — voice and the native speaking icon

### 2.1 Remote `Character` assignment (replication client)

- **One writer:** the client's rig registry in `CharacterReplicationServiceClient`.
  - `registerRig(player, puppet)` (remote players only) sets `player.Character = puppet`.
  - `unregisterRig(player, puppet)` sets it to nil **only if it still points at that puppet**, so a stale
    unregister never clears a newer assignment.
  - The owner rig keeps its own path (`OwnerRig` sets `LocalPlayer.Character`).
- **Ordering on reuse:** a pooled puppet is always unregistered from its old owner on release, before
  `PuppetPool.acquire` can hand it to a new owner — two players never share a model.
- **When it happens:** a puppet is registered when another player enters this client's view (≤ 600 studs)
  and unregistered on `Leave` (past 630), on leaving the game, or when the slot is replaced. Respawns,
  stalls and dressing do not register or unregister.
- **The registry stays the source of truth.** No code reads a remote player's `Character`. Everything that
  reads `Character` today reads `LocalPlayer`'s (`VitalsHud`, `AnimationServiceClient`, `TuneOffsetClient`,
  `OwnerRig`).
- **Cost, measured before shipping (2.5):** one property write per register/unregister on our side; on the
  engine's side the core UI builds its per-character billboard on assignment.

### 2.2 `VoiceServiceServer`

New `src/ServerScriptService/Services/VoiceService/VoiceServiceServer.luau`.

- On player join: one `AudioDeviceInput` named `VoiceInput`, `.Player = player`, parented to the `Player`
  (the server must create it for it to replicate). It is destroyed with the `Player`.
- On start: creates inputs for existing and new players first, then checks the script-readable place
  settings it depends on (2.4) and logs an error for each that is wrong. A settings problem never blocks
  voice input creation.
- `getState()`: inputs created, settings check result.

### 2.3 `VoiceServiceClient` and `VoiceWiring`

New `src/ReplicatedStorage/Client/Services/VoiceService/VoiceServiceClient.luau` (depends on
`CharacterReplicationServiceClient`) and pure `VoiceWiring.luau` beside it.

- **Listener:** an `AudioListener` on the current camera, wired to an `AudioDeviceOutput`; it follows
  `CurrentCamera` changes.
- **Per remote player:** wire once both exist — the player's `VoiceInput` (which may replicate after the
  puppet; the service watches `ChildAdded` on the `Player`) and the puppet's `Head` (from `bodySpawned`).
  Wiring = an `AudioEmitter` on the head with `SetDistanceAttenuation({[0]=1, [10]=1, [45]=0.35, [80]=0})`
  and a `Wire` from the input to it.
- **Unwire** on `bodyDespawned`, and on `PlayerRemoving` as a guard (CP10: a rejoiner was wired twice).
  Reuse of a pooled puppet for another player is despawn → spawn, so its old emitter never carries over.
- No emitter on the local player's own rig (you never hear yourself).
- **`VoiceWiring` (pure)** holds per-userId state: input present, head present, wired. Its functions return
  the actions to take (`wire(userId)`, `unwire(userId)`); the service performs them on instances.
- **Bubbles off:** set by a `default.project.json` child node,
  `TextChatService.BubbleChatConfiguration.Enabled = false` (Rojo 7.7.0 pairs the engine's existing instance
  by name and class; verified at Task 10's first serve: exactly one BubbleChatConfiguration, Enabled false,
  no rojo error; fallback: a hand-set place setting like ChatVersion). The voice icon shares the
  bubble-chat billboard (it moves with `VerticalStudsOffset`) and stays: "icon yes, text bubble no" (T5c).
  `VoiceSettings` checks it at server start.

### 2.4 Place settings

Checked against Rojo's reflection database (rbx-dom, version 0.741). **Runtime startup check covers only script-readable settings** (ChatVersion, CreateDefaultTextChannels, BubbleChatConfiguration.Enabled). The two VoiceChatService settings are PluginSecurity-protected and cannot be read by game scripts; they are enforced by `default.project.json` only.

| Setting | Value | How | Runtime check |
|---|---|---|---|
| `VoiceChatService.EnableDefaultVoice` | `false` | `default.project.json` property-only node (ReadWrite, serializes) | No — Read: PluginSecurity (game scripts cannot read) |
| `VoiceChatService.UseAudioApi` | `Enabled` | same | No — Read: PluginSecurity (game scripts cannot read) |
| `TextChatService.CreateDefaultTextChannels` | `true` | `default.project.json` property-only node (the spike place had it `false`, which silently disables chat) | **Yes** — `VoiceSettings` checks at start |
| `TextChatService.ChatVersion` | `TextChatService` | **Place setting, set by hand** — scripts can only read it, so `rojo serve` cannot write it. `VoiceServiceServer` logs an error at start if it is not `TextChatService`. The dev place currently says `LegacyChatService` | **Yes** — `VoiceSettings` checks at start |
| `TextChatService.BubbleChatConfiguration.Enabled` | `false` | `default.project.json` child node (2.3; pairing verified at Task 10's first serve) | **Yes** — `VoiceSettings` checks at start |

**Why `ChatVersion` cannot be automated (checked 2026-10-05).** It is an engine restriction, not a Rojo bug
or an outdated version: Roblox's API reference lists it as *Write: RobloxScriptSecurity* (only Roblox's own
code and the Studio Properties panel may write it), and a plugin-context write in Studio fails with "lacking
capability RobloxScript". Rojo 7.7.0's database (`Scriptability: Read`) just mirrors that. Ways considered:

**Found in Studio (2026-10-05):** The first live test of VoiceServiceServer failed with "cannot read 'EnableDefaultVoice' (lacking capability Plugin)" because game scripts cannot read VoiceChatService settings (PluginSecurity). The fix removed these from the runtime check; they are enforced by the project file only. Inputs are created before any settings check, so a settings problem never blocks voice input creation.

| Way | Verdict |
|---|---|
| `rojo serve` / any script or plugin | Impossible (RobloxScriptSecurity) |
| `rojo build` writes it into an `.rbxl` | Works for files, but we deploy by serving into the art-bearing place, not by building |
| Editing the place file offline (Lune / rbx-dom) | Possible, but fights Team Create and the manual-publish model |
| Rely on Roblox's forced migration | Rejected: live may be forced onto `TextChatService`, but **Studio is not** — in a Play of the dev place (`LegacyChatService`) the legacy `ChatServiceRunner` / `ChatScript` run and `TextChatService` has no channels, so Studio and live would differ |
| **Set it once in the Studio Properties panel, per place** (dev, staging, live) | **Chosen.** It saves with the place; `VoiceServiceServer` logs an error at start if it is wrong |

`AGENTS.md`'s deployment section gains a short list of place-owned settings (`ChatVersion`), next to the
property-only nodes it already documents.

`production.project.json` is a preserved, unused recipe that already lacks R2's settings
(`CharacterAutoLoads`, `Workspace.Retargeting`, ReplicatedStorage's `$ignoreUnknownInstances`). R5 does not
half-update it; a separate issue syncs it.

### 2.5 Measurement: the cost of `Character` assignment

In Studio, 3 clients, with a probe script inserted at runtime (no repo code): time the frames around
players entering view, one at a time and several at once (driven by moving the owner rigs across the 600-stud
edge), comparing assignment on against a run with the write removed locally. Recorded in this doc. If
entering view shows a frame spike attributable to the assignment, it is reported before R5 ships.

## Section 3 — #32 and settings checks

### 3.1 `StatsServiceServer.stop()`

`stop = function(_self) janitor:Cleanup() end`, like `CustomizationServiceServer.stop`. No manual
`activeSubscriptions = 0`: `BodyObservers`' disposer runs every per-body cleanup, each of which decrements the
counter, so it returns to 0 by itself — a forced reset would hide a leak.

Spec: start → stop → start leaves exactly one subscription per body; the counter is 0 after stop; a stat
change applies once.

### 3.2 `RequestHandler.wrap` guards the custom clock

`clock(data, player)` (`RequestHandler.luau:224`) runs under `pcall`. A throw rejects the packet through the
existing `reject` path, counted as a validation reject with the error as its message; the handler is not
called and nothing escapes the ByteNet listener. Well-formed packets are unchanged; validation still runs
first.

Spec: a throwing clock → rejected, reject counter up, handler not called, no error escapes.

## Testing summary

- **Specs (TestEZ):** `ReplicationTripwire` (every check, allowances, episode start/end, gate off = nothing
  runs); `VoiceWiring` (input before/after head, puppet reuse for another player, leave while wired, rejoin
  with a new `Player` and the same id, input replaced); the registry's `Character` rules (set on register,
  cleared on unregister, a stale unregister leaves a newer assignment, reuse never leaves the old owner
  pointing at the puppet); #32's two specs; `VoiceServiceServer` input creation and settings check.
- **Studio, 3 clients (me):** matrix rows 1, 7, 8; every remote puppet's head has exactly one emitter wired
  to the right input and none on your own rig, through reuse, respawn and leave; `Character` matches the
  registry; the five settings read their values in Play and chat works; the 2.5 measurement. Tripwire on,
  zero episodes.
- **Staging, two accounts (developer):** matrix rows 1–6 with `Diagnostics = true`; voice spatial with the
  10/80 falloff; the native icon shows and animates; top-bar and per-player mute; volume sliders; no text
  bubbles; chat works; all of it after a rejoin.

## Files

| New | Purpose |
|---|---|
| `Client/Services/CharacterReplicationService/RigRegistry.luau` + spec | 2.1 — registry moved out of the client service (it was at the 400-line cap); one writer of remote `Character` |
| `Client/Services/CharacterReplicationService/ReplicationTripwire.luau` + spec | 1.2 — the checks (pure) |
| `Client/Services/CharacterReplicationService/ReplicationDiagnostics.luau` + spec | 1.2 — the snapshot and the `Diagnostics` gate |
| `ServerScriptService/Services/VoiceService/VoiceSettings.luau` + spec | 2.4 — the settings check (pure) |
| `ServerScriptService/Services/VoiceService/VoiceServiceServer.luau` (spec-exempt shell) | 2.2 |
| `Client/Services/VoiceService/VoiceWiring.luau` + spec | 2.3 — the wiring state machine (pure) |
| `Client/Services/VoiceService/VoiceServiceClient.luau` (spec-exempt shell) | 2.3 |
| `StarterPlayer/StarterPlayerScripts/RbxCharacterSounds.client.luau` (empty override of the engine default) | 2.5 follow-up |

| Changed | What |
|---|---|
| `CharacterReplicationServiceClient.luau` | `Character` in register/unregister; tripwire snapshot + `Diagnostics` gate; `getState().tripwire`. Logic stays in modules — the service only wires |
| `StatsServiceServer.luau` + spec | 3.1 |
| `RequestHandler.luau` + spec | 3.2 |
| `default.project.json` | `VoiceChatService` and `TextChatService` property-only nodes, plus the `BubbleChatConfiguration` child node under `TextChatService` |
| `AGENTS.md`, `docs/architecture.md` | place-owned settings; voice; the `Diagnostics` switch |
| this doc | 2.5 measurement and the Studio results |

## Out of scope

Text bubbles; server voice culling; the engine's default voice; a custom speaking icon; #33; #35 (gating
existing diagnostics); syncing `production.project.json`; sound handling (much later).

## Open questions

None blocking. Two facts are verified during implementation, each with a stated fallback:
`IncomingReplicationLag` being per-process (1.3), and the 2.5 measurement.

## R5 Studio results (2026-10-05)

Dev place (local `character-replication.rbxl`, place id 0), Clients and Servers test, 3 players, Workspace
`Diagnostics = true` on the server. Live module state was read through probe Scripts / LocalScripts inserted
into the Play DataModel (the execute_luau context has its own require cache: its copy of the replication
service reports `hasBody = false`).

**Run 1** found that `VoiceServiceServer` failed to start: `EnableDefaultVoice` / `UseAudioApi` are
Read: PluginSecurity. Fixed in 32bf50d (the runtime check reads only script-readable settings and runs
after the inputs exist). Every result below is from run 2.

| Step | Result |
|---|---|
| 1 Settings | `ChatVersion = TextChatService`, bubble config `Enabled = false`, server `settingsProblems = []`, `inputs = 3`, every player has an `AudioDeviceInput` `VoiceInput` |
| 1 Chat | Typed chat shows no bubble. **Cross-client delivery is not testable in a local file**: the sender's message reaches `Success` and the server's `ShouldDeliverCallback` routes it to every recipient, but the receiving client's `MessageReceived` never fires. That stays true with the sender's `Character` cleared on the receiver, so it is not caused by the assignment. Cause: place id 0, so per-recipient filtering cannot run (the same thing was seen in the spike, where published chat worked). Moved to the staging checklist |
| 2 Wiring | On every client, for each remote player: `Character` is the puppet, `GetPlayerFromCharacter` matches, exactly one `VoiceEmitter` on the head whose `Wire.SourceInstance` is that player's `VoiceInput`; no emitter on the own rig; listener on the camera; `VoiceServiceClient:getState()` = `{wired 2, emitters 2, listener true}` |
| 2 Respawn | Server `respawn(Player1)`: both viewers re-pointed `Character` to the new puppet, one emitter, wired to `Player1.VoiceInput` |
| 2 Out of range | Player1 respawned about 820 studs out (SpawnLocation moved for the session): both viewers' `Player1.Character = nil` and emitter gone, and Player1 saw nobody (0 emitters); respawned back in range, all three re-wired with 2 emitters each |
| 2 Leave | Player3 closed: the stayers dropped it from the players list, puppets and emitters (1 emitter left each), and the tripwire stayed clean. Rejoin cannot be done mid-session in Studio, so it moves to the staging checklist |
| 3 Matrix row 1 | Players 2 and 3 joined with others already present: everyone sees everyone, tripwire counts empty |
| Tripwire | 0 episodes on every client over the whole run (about 730–970 checks each), including respawns, 15 range cycles, all stalls and the leave |

**Stall test (step 4).** `IncomingReplicationLag` is per-process (set on one client; the other client and the
server read 0). Player1 walked a 30-stud square with `Humanoid:MoveTo` while a viewer sampled its puppet.

| Stall | Observed |
|---|---|
| Client 2.5 s | The viewer's track trails the true path by about 2.7 s, smooth, never gone (`Character` present every sample) |
| Client 10 s | Puppet held at its last pose for about 10 s, then the walk played back smoothly; never gone |
| Server 10 s | Every uplink sample arrives about 10 s old and is rejected as `stale` (Player1: 714 → 4357); `tooFast 0`, `ahead 0`, no correction storm. Viewers hold the body at its last accepted position; after the lag clears, server and viewers converge on the true position within 15 s |

The stalled stretch of a server stall is dropped, not replayed: viewers see one jump to the current position.
This is the stale-sample rule working as designed, not a vanish. It is noted here as the one place where the
behavior differs from engine replication.

**Assignment cost (step 5).** A frame-time probe on one client recorded 20 view entries (Player2 ×5, Player3 ×5,
both ×5, each a far respawn and back). Unfocused Studio windows render at about 15 fps (p50 66.6 ms, p99
73.3 ms), and the worst frame within 500 ms of each entry (67–81 ms) sits inside that noise, so frame times
cannot resolve the cost here. The cost was measured directly instead (50 iterations, in-client):

| Operation | Time |
|---|---|
| `player.Character = rig` (set) | about 3.5 ms |
| `player.Character = nil` (clear) | about 1.0 ms |
| clear + set pair, second run | about 12.4 ms |
| `player.Character = rig` when already that rig | about 0.2 µs |
| `ObjectValue.Value` pair (baseline) | about 0.4 µs |

**Follow-up measurement (2026-10-05, 2 clients).** The cost is not the assignment: the engine's default
`RbxCharacterSounds` LocalScript reacts to every player's `Character` and synchronously adds 9 Sounds
(Running, Jumping, Landing, …) plus Humanoid hooks to the puppet. Median set times on the real puppet: about
9–10 ms with the default script, about 2 ms for a clone of the same puppet (which the script skips), and
**0.8 ms with the script disabled** (all under the same throttled conditions; Humanoid-model baselines with 100
extra parts, welds, textures or accessories stay at 1.5–2.4 ms, so puppet size is not the driver). Decision
(developer, option 1): replace `RbxCharacterSounds` with an empty LocalScript in `StarterPlayerScripts`. That
removes the cost and the risk of engine movement sounds on puppets; the local body's own movement sounds go
silent until the later sound work. The one-per-frame budget is not needed.

**Verified with the override live (2026-10-05, 2 clients, still throttled at 15 fps):** the place's
`RbxCharacterSounds` is the empty override; 100 assignments added 0 descendants to the puppet (only the
rig's own `Walk` sound is present, on remote and own bodies alike). Median set: real puppet 0.96–1.14 ms,
Humanoid-only model 0.25 ms (it was 1.5 ms with the default script), ObjectValue control 0.6 µs. Voice wiring
unchanged (one emitter per remote head, wired to that player's `VoiceInput`).

Ruling: this replaces the plan's comment-out comparison, because a source edit does not reach a running
session and the direct timing isolates the assignment exactly. The cost is engine-side work: no first-party
code listens to a remote player's `CharacterAdded`. It is paid once per entry into view, never per frame, but
it is milliseconds and not microseconds (machine loaded with four Studio processes, so the true figure is
lower). Many bodies entering in one frame (for example a join into a full server) would stack into a visible
hitch. Follow-up for the developer to decide: re-measure in the staging place with the MicroProfiler, and if
it holds, budget assignments to one per frame.

## Developer staging checklist

Before publishing to staging: serve this branch into the place, set `TextChatService.ChatVersion =
TextChatService` by hand in the Properties panel, and set Workspace `Diagnostics = true`. Publish, then
test with two accounts (each check from both views):

- [ ] Matrix rows 1–6 (§1.4), each from both views: (1) join a server that already has players; (2) rejoin
      within ~1 s (slot reused at once); (3) rejoin after 60 s+; (4) rejoin while the other player is out of
      range, then walk into range; (5) leave during a respawn; (6) two players rejoin at the same time.
- [ ] Chat: a message from either account appears in the **other** account's chat window (could not be
      tested in the local file: place id 0).
- [ ] No text bubble over either head.
- [ ] Voice is spatial: full volume within 10 studs, fading to silent at 80.
- [ ] The native speaking icon shows above the speaker and animates while they talk.
- [ ] Top-bar mute silences you for the other account; per-player mute from the player list works.
- [ ] The engine's voice volume sliders change what you hear.
- [ ] All of the above again after one account leaves and rejoins.
- [ ] F4 → Services → `CharacterReplicationServiceClient` → `tripwire` on both clients:
      enabled, `checks` rising, no episodes.
- [ ] No engine character sounds (footsteps, jump, landing) from either body, your own included: the default
      `RbxCharacterSounds` is replaced by an empty script (intended until the later sound work).
- [ ] Optional: MicroProfiler while the other account enters view: the `Character` assignment should be
      well under 1 ms now that the default sounds script is gone.

Set Workspace `Diagnostics` back to false before any publish to live.


## Staging run 1 (2026-10-05)

| Check | Result |
|---|---|
| Chat between accounts | Works both ways (confirms the local-file limitation) |
| No text bubbles | Confirmed |
| Voice spatial | Confirmed |
| Top-bar mute | Silences you for everyone |
| No engine character sounds | Confirmed |
| Native speaking icon / mute icon over heads | **Missing**. With bubbles turned on in the place for a test, remote players' bubbles are missing too: only your own bubble shows. So nothing the engine anchors to a remote `Character` appears. Open |
| Spawn | The place had no SpawnLocation, so the server used the live map's fallback point, which sits 5 studs past the staging baseplate's edge: endless fall and respawn. A SpawnLocation was added to staging's baseplate, and the server now warns when it falls back |
| Loose boots at spawn | Root cause found in the rig art: each foot of `StarterPlayer.StarterCharacter` still holds the old boot geometry (`LeftFoot.LeftFoot`, `RightFoot.RightFoot`) left behind when the boots moved into `Boots1`, welded only to itself through a weld with an empty `Part1`. It drops off every body at spawn, in every place. The server now logs an error at boot naming such parts (`RigIntegrity`) |
| Remote body missing hair and shoes | Seen once after the fall loop; not reproduced since. Watch on the rerun |
| Rejoin rows | Not run yet |

## Staging run 2–3 (2026-10-06)

| Check | Result |
|---|---|
| Spawn | On the new baseplate SpawnLocation; no fall loop |
| Loose boots | Gone (leftover foot boot models removed from `StarterCharacter` in the dev and staging places; the boot check reports nothing) |
| Voice icon + bubbles (bubbles on, diagnostic build) | Both show over the other player |
| Voice icon after a respawn | Survives |
| Voice icon, bubbles off (the shipped setting) | Shows. The run-1 failure came with the endless fall-and-respawn loop and is not reproduced since |
| Remote body bald and barefoot | **Root cause found and reproduced on demand**: A rejoins the same server, then B joins or rejoins fresh: B draws A bald and barefoot. `CustomizationServiceServer.onBodySpawn` decided "first publish" from `lastPublishedSlot`, which survives a leave while the public entry does not, so the rejoin published nothing and fresh viewers dressed the empty placeholder. Viewers that already held A's puppet masked it (they ignore a version not newer than the one worn) |
| Fix 1 (ec53f9e) | First publish is read from the entry (absent, or the version-0 placeholder) |
| Fix 2 (f529a03) | `PublicPlayerState` keeps each user's appearance version climbing for the server's lifetime, so a viewer holding the old puppet accepts the new session's look |
| Rejoin repro after both fixes | Dressed correctly every time |
| Fix 3 (ac5aff0, from review) | The body can spawn before the profile loads (most likely on a same-server rejoin, which waits on the old session's lock), and then nothing published the look. `PlayerDataService.profileLoaded` now fires on session start, and `AppearancePublisher` (split out of CustomizationServiceServer) publishes on it while the entry is still the placeholder. Not yet seen live; covered by specs |

Both customization bugs predate R5 (R4 code); they surfaced because a same-server rejoin had never run against R4.
