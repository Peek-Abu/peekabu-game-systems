# Cleanup Crew: publishing the depot and shift places

How to turn the Studio build (one server playing both roles) into a published experience with a depot
place and a shift place. Do this yourself; agents never publish or upload. Spec:
`docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` §5.

## What you end up with

- One experience, owned by your personal account, with **two places**: the **depot** (the start place,
  public servers, the lobby) and the **shift** (reserved servers only, made by the Queue for each party).
- The same code synced to both (`rojo serve`), because one codebase plays both roles. A server learns its
  role from its PlaceId through the place-role table in
  `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau` (`PLACE_IDS`).
- While a PlaceId is `0` (the placeholder), that role is reached by a local move. A published depot place
  with `shift = 0` plays the trip out in the same server (a local move); Back to depot then teleports the
  crew to a depot server, possibly a different one, because the depot's PlaceId is real. You can publish
  the depot first and add the shift place later, but only the all-placeholder setup (Studio, or both ids
  `0`) plays the whole loop in one server.
- A role is only reachable if its world exists in the server: Queue needs an arrival point for the role,
  or the departure fails and the party stays on its pad. The code registers the shift's arrival point (the
  loading bay) and the depot's (the spawn points) itself.

## 1. Create the shift place

1. Open the experience's start place (the depot) in Roblox Studio.
2. **View → Asset Manager → Places**. Right-click the empty area → **Add New Place**. Name it `Shift`.
3. Double-click the new place to open it. It starts from the Baseplate template; keep the baseplate and
   its SpawnLocation (players are moved to the office's loading bay by the code, but the baseplate catches
   anyone who spawns before that).
4. Turn **Team Create off** in both places while you sync and publish (Rojo and publishing are simpler
   with it off).

## 2. Fill in the PlaceIds

1. In Asset Manager → Places, right-click each place → **Copy ID to Clipboard** (or run `print(game.PlaceId)`
   in each place's command bar).
2. In `DepotConstants.luau`, set `PLACE_IDS.depot` and `PLACE_IDS.shift` to the two numbers and remove the
   two `PLACEHOLDER` comments. `DepotServiceServer` registers the table in Queue's `QueueRegistry` at load.
3. Commit on `game/cleanup-crew` (`fix(depot): real PlaceIds for the depot and shift places`).

The two ids must differ (`QueueRegistry.register` refuses one real PlaceId playing two roles at boot).

## 3. Sync and publish both places

For **each** place (depot first, then shift):

1. Open the place in Studio.
2. In the repo: `rojo serve` (if it is not already running). In Studio: Rojo plugin → **Connect**. Wait until
   the sync finishes (ReplicatedStorage, ServerScriptService, StarterPlayer filled in; no Rojo errors).
3. Press **Play** once in Studio: Output should say `depot built: 3 trucks, ...`. With the PlaceIds filled
   in (section 2) the role is printed (`role depot` in the depot place, `role shift` in the shift place);
   the mode is still `local` (Studio is always local). Stop.
4. **File → Publish to Roblox**. Disconnect Rojo.

Both places get the same code; the server decides at run time which role it plays. In a live server's
Output (F9 → Server) look for `queue in live mode, role depot` in the depot and
`queue in live mode, role shift, reserved server` in a party's shift server.

## 4. Let the second account in

In **Game Settings → Permissions** (or Creator Hub → the experience → Access), make the experience playable by
your second account (for example Public; Creator Hub may ask you to complete the experience questionnaire
first). Teleports between places of the same experience need no extra setting.

## 5. Test with two accounts

Use two devices or two Roblox clients signed in to different accounts. Tick each item. Open F9 → Server
on the owner account for the logs named below.

- [ ] Both accounts join the experience from its page: both land in the same depot server (join the
      second through the first's profile → **Join** if Roblox splits them).
- [ ] Both stand in **truck 1**: its label says `2/4 aboard`; each sees the pad panel (`2/4 aboard`,
      `Leaving in 15s`), and the countdown restarts when the second player steps in.
- [ ] One presses **Depart now**: both see the drive card, then load into **one** reserved shift server
      together; the arrival card shows; a 5 s countdown; the shift starts in the loading bay.
- [ ] **Verify: the arrival card is not missed.** The client now tells the server when it listens
      (`DepotEvents.Ready`) and the server holds a card until then. Both players see the arrival card even
      when one client loads slowly (throttle one client, or join it last), and a member who joins late sees
      it too.
- [ ] One account steps off the truck during the countdown: it leaves the party; the other departs alone.
- [ ] Close one client mid-teleport: the other arrives; the shift starts after ~25 s (the 20 s arrival timeout, then the 5 s countdown).
- [ ] A third account (or the second, rejoining) joins a crew member through their profile while the crew
      is still arriving: a stranger following a friend into a reserved server is expected to be refused
      (only the party's ticket holders are expected), so observe what they see and that they end up in a
      depot server; once the shift has started a straggler from the party is seated in the loading bay.
- [ ] Play to results, vote **Back to depot**: both land in a depot server (not necessarily the one you
      left), each sees **their** result card on the result board and the toast.
- [ ] **Failed-return toasts.** If a return trip fails (Queue gives up after its retries), the player is
      still in the shift server and sees two toasts: Queue's "Couldn't travel. Try again in a moment."
      right after the vote, then, 130 s after the vote (the leaving window), "The truck couldn't get back
      to the depot. Another shift it is." once per player; the next shift can then start. Not easy to
      force; if it happens, check both texts, the single send per player, and that the next shift starts.
- [ ] Vote **Another shift**: a new shift starts in the same reserved server.
- [ ] Everyone leaves a shift server: rejoining never puts you back in it (empty servers close).
- [ ] **Stranded player on a public shift server.** If a player reaches a public server of the shift place
      (the log says `a public server of the shift place: every player is sent to the depot`), they are sent
      to the depot through `returnParty`. If that teleport fails, they are kicked after the
      130 s leaving window with "This shift server is empty. Rejoin from the depot." Not easy to force;
      if it happens, check that the kick text shows and that rejoining lands in the depot.
- [ ] Optional failure check: temporarily set `PLACE_IDS.shift` to a PlaceId of a place in **another**
      experience you own, publish the depot, depart: after 3 retries the party is back on the pad with
      "Couldn't leave. You're back on the pad." (with Queue's 30 s watchdog this can take up to two
      minutes). Put the real id back and republish.

### Things to measure while testing

- **Retry count per real failure.** Queue retries on `TeleportInitFailed` (delays 1 s, 2 s, 4 s). It is not
  known whether a `TeleportAsync` error also fires `TeleportInitFailed`. In the optional failure check,
  count the `retrying N player(s) in Ns: ...` lines in the server log for the one failed departure:
  3 lines is right; 6 means each failure is reported twice and Queue's retry accounting needs a look.
- **Slow reserved-server start.** Note how long the players stay in the depot (the source server) between
  Depart now and the load screen on a cold reserved server. Queue's watchdog is 30 s (`TELEPORT_WATCHDOG`):
  if starting a reserved server regularly takes longer, a healthy trip is reported as failed and the party
  returns to the pad while it is still on its way.

## Troubleshooting

- **"Couldn't leave. You're back on the pad."** every time: the shift PlaceId is wrong or the shift place
  is not published.
- **Everyone plays in one server after publishing:** a PlaceId is still `0` or does not match the place
  (the Output line `queue in local mode` on a live server says so).
- **409 "Server is busy"** only concerns Open Cloud uploads (CI), not Studio publishing.
- Live logs: F9 → **Server** tab (Developer Console), as the experience owner.
- Teleports never work inside Studio; that is why Studio plays both roles locally.
