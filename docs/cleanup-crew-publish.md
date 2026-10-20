# Cleanup Crew: publishing the hub and shift places

How to turn the Studio build (one server playing both roles) into a published experience with a hub place
and a shift place. Do this yourself; agents never publish or upload. Spec:
`docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` §5.

## What you end up with

- One experience, owned by your personal account, with **two places**: the **hub** (the depot role; the
  start place, id `113354563835664`, public servers, the lobby) and the **Shift** place (the shift role;
  reserved servers only, made by the Queue for each party). You have already created the Shift place; its
  id is filled in later (section 2).
- The same code synced to both (`rojo serve`), because one codebase plays both roles. A server learns its
  role from its PlaceId through `HUB_PLACE_ID` and `SHIFT_PLACE_ID` in
  `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau`.
- While `SHIFT_PLACE_ID` is `0` (the placeholder), the live hub plays both roles in one server, even though the
  hub's own id is real: the code treats either id being `0` as "not split yet" and ignores both. The trip out
  and Back to depot are then local moves inside that one server, and the Output shows `queue in local mode`.
  Nobody is teleported until you fill in the shift id.
- A role is only reachable if its world exists in the server: Queue needs an arrival point for the role,
  or the departure fails and the party stays on its pad. The code registers the shift's arrival point (the
  loading bay) and the hub's (the spawn points) itself.

### What runs where

| Service | Hub (depot role) | Shift role |
|---|---|---|
| Depot (garage, board, pads, result card, hub spawns) | runs | travel-card listeners only (the arrival card shows in the Shift server) |
| Office | inert | builds the office |
| Shift (trip, vote, clock-out, site, review, crew status), Occupant (Harlow) | inert | runs |
| Round, Npc, Cargo, Carry, Hide, Noise, Vacuum | idle (nothing to react to) | runs |
| Everything shared (UI, backpack look, Queue, profile, and so on) | runs | runs |

In the hub there is therefore no office, no Harlow and no shift timer, and the hub plays its evening light
and music.

## 1. Create the Shift place (done)

You already made it: **View -> Asset Manager -> Places -> Add New Place**, named `Shift`, under the Odd
Hours experience. If you ever need to redo it:

1. Open the experience's start place (the hub) in Roblox Studio.
2. **View -> Asset Manager -> Places**. Right-click the empty area -> **Add New Place**. Name it `Shift`.
3. Double-click the new place to open it. Keep the baseplate and its SpawnLocation (players are moved to
   the office's loading bay by the code, but the baseplate catches anyone who spawns before that).
4. Turn **Team Create off** in both places while you sync and publish (Rojo and publishing are simpler
   with it off).

## 2. Fill in the Shift PlaceId

1. In Asset Manager -> Places, right-click the Shift place -> **Copy ID to Clipboard** (or run
   `print(game.PlaceId)` in its command bar).
2. Tell the agent the number. In `DepotConstants.luau` only `SHIFT_PLACE_ID` changes (the hub id is
   already in); the `OWNER:` comment is removed. While it is `0`, both roles play in one server even when
   published. `DepotServiceServer` registers the ids in Queue's `QueueRegistry` at load.
3. Commit on `game/cleanup-crew` (`fix(depot): real PlaceId for the shift place`).

The two ids must differ (`QueueRegistry.register` refuses one real PlaceId playing two roles at boot).

Filled in: `SHIFT_PLACE_ID` is `118845637680835`.

## 3. Sync and publish both places

Publish **both** places from the **same commit**, the hub first, then Shift. Warning: a Shift place
published with an older build (one where the shift id was still `0`) plays every role locally and builds a
depot inside the office place.

For **each** place:

1. Open the place in Studio.
2. In the repo: `rojo serve` (if it is not already running). In Studio: Rojo plugin -> **Connect**. Wait until
   the sync finishes (ReplicatedStorage, ServerScriptService, StarterPlayer filled in; no Rojo errors).
3. Press **Play** once in Studio: Output should say `depot built: 3 trucks, ...`. Studio is always local
   mode, so it plays both roles in that one place. Stop.
4. **File -> Publish to Roblox**. Disconnect Rojo.

This build migrates saved data to v3, so publish both places together: a player who moves from a v3 server to an older-build server is refused ("too_new").

Both places get the same code; the server decides at run time which role it plays. In a live server's
Output (F9 -> Server) expect:

- **Hub server:** `queue in live mode, role depot`, `hub spawns: the depot places players`, and the three
  lines `not a shift server: the office is not built`, `not a shift server: the shift does not run here`
  and `not a shift server: the Manager does not run here`. Also `depot built: 3 trucks`.
- **A party's Shift server:** `queue in live mode, role shift, reserved server`, and **no** `depot built`
  line.
- **A public server of the Shift place** (a stranger): `a public server of the shift place: every player is
  sent to the hub`.

## 4. Let the second account in

In **Game Settings -> Permissions** (or Creator Hub -> the experience -> Access), make the experience playable by
your second account (for example Public; Creator Hub may ask you to complete the experience questionnaire
first). Teleports between places of the same experience need no extra setting.

## 5. Live checklist

Use two accounts on the published places, with F9 -> Server open on the owner account. Tick each item.

- [ ] Studio, before publishing (local mode, one place): the whole loop still works, solo and in a
      2-player Local Server.
- [ ] Hub log: `queue in live mode, role depot`, `hub spawns: the depot places players` and
      `depot built: 3 trucks`. There is no office in the hub, no Harlow, no shift timer on the HUD, and
      the hub's evening light and music play. Players spawn on the depot's spawn points, wearing the vacuum
      backpack but holding no vacuum tool.
- [ ] A party of 2 departs from truck 1: the drive card shows, then both land in **one** reserved Shift
      server. Its log reads `queue in live mode, role shift, reserved server` with no `depot built` line.
      The arrival card shows and the shift starts in the loading bay.
- [ ] A full shift plays: Harlow patrols, the vacuum works and valuables bank.
- [ ] Vote **Back to depot**: both land in a hub server and each sees **their** result card on the result
      board, plus the toast.
- [ ] **Stranger redirect, public server:** join the Shift place directly (open
      `https://www.roblox.com/games/<shift id>` and press Play; if Roblox refuses a direct join to a
      non-start place, note that and tick this as covered by the refusal). The Shift log shows
      `a public server of the shift place: every player is sent to the hub`, and the player lands in a hub
      server. If that teleport fails, they are kicked after 130 s with "This shift server is empty. Rejoin
      from the depot."
- [ ] **Stranger, reserved server:** a third account tries to follow a crew member into their Shift server
      through the profile. Note what Roblox shows; they must end up in a hub server, never inside the
      crew's shift.
- [ ] **Return failure:** if a return trip fails (Queue gives up after its retries), the player stays in
      the Shift server and sees two toasts: Queue's "Couldn't travel. Try again in a moment." right after
      the vote, then, 130 s after the vote, "The truck couldn't get back to the depot. Another shift it
      is." once per player; the next shift can then start. Not easy to force; if it happens, check both
      texts and that the next shift starts.
- [ ] Everyone leaves a Shift server: rejoining never puts you back in it (empty servers close).

Failure and timing checks worth keeping:

- [ ] Both accounts stand in **truck 1**: its label says `2/4 aboard`, and the countdown restarts when the
      second player steps in. One account stepping off during the countdown leaves the party.
- [ ] Close one client mid-teleport: the other arrives; the shift starts after about 25 s (the 20 s
      arrival timeout, then the 5 s countdown). Both players see the arrival card even when one client
      loads slowly.
- [ ] Vote **Another shift**: a new shift starts in the same reserved server.
- [ ] Optional failure check: temporarily set `SHIFT_PLACE_ID` to a PlaceId of a place in **another**
      experience you own, publish the hub, depart: after 3 retries the party is back on the pad with
      "Couldn't leave. You're back on the pad." (with Queue's 30 s watchdog this can take up to two
      minutes). Put the real id back and republish.

### Things to measure while testing

- **Retry count per real failure.** Queue retries on `TeleportInitFailed` (delays 1 s, 2 s, 4 s). It is not
  known whether a `TeleportAsync` error also fires `TeleportInitFailed`. In the optional failure check,
  count the `retrying N player(s) in Ns: ...` lines in the server log for the one failed departure:
  3 lines is right; 6 means each failure is reported twice and Queue's retry accounting needs a look.
- **Slow reserved-server start.** Note how long the players stay in the hub (the source server) between
  Depart now and the load screen on a cold reserved server. Queue's watchdog is 30 s (`TELEPORT_WATCHDOG`):
  if starting a reserved server regularly takes longer, a healthy trip is reported as failed and the party
  returns to the pad while it is still on its way.

## Troubleshooting

- **"Couldn't leave. You're back on the pad."** every time: `SHIFT_PLACE_ID` is wrong or the shift place
  is not published.
- **Everyone plays in one server after publishing:** `SHIFT_PLACE_ID` is still `0` or a PlaceId does not match its place
  (the Output line `queue in local mode` on a live server says so).
- **409 "Server is busy"** only concerns Open Cloud uploads (CI), not Studio publishing.
- Live logs: F9 → **Server** tab (Developer Console), as the experience owner.
- Teleports never work inside Studio; that is why Studio plays both roles locally.
