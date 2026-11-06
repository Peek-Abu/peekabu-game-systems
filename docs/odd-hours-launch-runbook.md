# Odd Hours: launch-day runbook (draft, 2026-11-06)

The order of operations for taking Odd Hours public on **Thu 2026-11-26**. The owner does every publish, upload,
setting and payment step; agents only prepare and check. Publishing mechanics (Rojo sync, which place plays which role,
the live log lines to expect) are in [cleanup-crew-publish.md](cleanup-crew-publish.md); this page is the calendar
and the checklist around it. Rows on the Launch List (Launch area) link here.

Places: hub "Odd Hours" `113354563835664` (start place, public servers), "Odd Hours: Shift" `118845637680835`
(reserved servers only). Owner: the **Icey Labs** group (189923277), never VentureMMO.

## T-7 days (Thu 11-19): lock the build

- [ ] Content lock is Sun 11-22: after it, only fixes.
- [ ] Every Launch List row is `done` or `cut`; nothing in `check` that touches the first shift.
- [ ] The full TestEZ suite passes in Studio (RunTests = true), 0 failed.
- [ ] Every asset the game uses is **Approved** in moderation and owned by Icey Labs (row l-assets). A pending or
      rejected audio plays silence; a rejected image shows grey.
- [ ] Debug leftovers are gone from both places (row l-cleanup: PippaPreview rigs, CleanupCrewVariant overrides).
      Cmdr admin commands stay, but only the Admins group can run them (fail-closed allowlist).
- [ ] Test ranks and saves are reset (row p-rank-wipe): bump `RANK_SEASON` in RankConstants, and either rename the
      DataStore (`PlayerStore` -> `PlayerStore_launch`) or clear it in the Creator Dashboard.
- [ ] Experience questionnaire answered (maturity label), genre, description, the icon and 3-5 thumbnails uploaded
      by the owner (rows l-questionnaire, l-thumbs).
- [ ] Developer products and passes exist with their final prices, and each was bought once end to end in the
      published game with a test account (row st-purchase-qa), including the "I paid and got nothing" path.

## T-3 days (Mon 11-23): publish privately

1. Turn **Team Create off** in both places (Rojo and publishing are simpler with it off).
2. From ONE commit of `game/cleanup-crew`: sync and publish the **hub first, then Shift**
   ([cleanup-crew-publish.md §3](cleanup-crew-publish.md)). Write the commit hash here: `________`.
3. Keep the experience **private** (or friends-only for the second account).
4. Run the live checklist with two accounts ([cleanup-crew-publish.md §5](cleanup-crew-publish.md)): hub to Shift and
   back, Credits and Gloom after a rejoin, 4 players, someone leaving mid-shift (row l-published-tests).
5. Create the launch **Event** in the Creator Dashboard (Thanksgiving, starts 11-26), with its thumbnail, so players
   can RSVP; link it from the group and socials (rows so-event, so-rsvp).

## Launch day (Thu 11-26)

1. Morning: open both places' **Version History** and note the published version numbers (the rollback target).
2. Check nothing changed since T-3: if a fix landed, publish hub then Shift again from one commit.
3. Make the experience **Public**.
4. Join from a phone and a PC: a full first shift, solo and with a friend.
5. Turn on any ads or sponsored slots only after step 4 passes.
6. Post on the socials (trailer, creator kit) with the game link (row l-socials).

## Watching it live (first 48 h)

- Creator Dashboard -> the experience -> **Error Report**: new script errors per hour. Anything over a handful a
  minute is a hotfix.
- Developer Console (F9 -> Server) in a live server as the owner: the role lines from cleanup-crew-publish.md, and
  no repeating warnings.
- Analytics: players reaching their first shift, shift length, quits during the first shift (the funnel).
- Purchases: Creator Dashboard -> Monetization; compare product sales with grants (a sale with no grant is the
  "paid and got nothing" case: grant it by hand with the Cmdr entitlement command and fix the cause).

## Hotfix and rollback

- **Hotfix:** fix on `game/cleanup-crew`, run the suite in Studio, publish hub then Shift from the same commit. A
  publish does not move players already in a server: use the Creator Dashboard's **Migrate to latest update** (or
  "Restart servers") when the fix must reach everyone. There is no in-game soft shutdown yet, so a restart drops
  players out of their shift (Live-game safety row p-gaps).
- **Rollback:** Version History -> revert BOTH places to the noted versions (a hub and a Shift on different builds can
  refuse saves with "too_new" after a data migration).
- **Saves:** never delete the DataStore on a live game; a bad save is fixed per player.

## Open items this runbook depends on

- p-gaps: no soft shutdown on updates, no AFK handling, no Ban API wiring yet.
- p-teleport-party: the crew list rides the teleport data; storing it server-side (MemoryStore) is still to do.
- p-reserved: the TeleportOptions reserved-server field should be checked against the current Roblox docs.
