# Cleanup Crew: the hotbar inventory

Date: 2026-10-16. Status: built on `game/cleanup-crew`, ready for the user to check. Replaces the two-pocket rule in
the [Cleanup Crew design](2026-10-10-cleanup-crew-design.md) §4 ("Hands" and "Pockets") and the pocket and swap
requests in §6. The rules are the user's.

## 1. The rules

- **Five hotbar slots**, like the Roblox HUD: **slot 1 is the vacuum**, **slots 2-5 are four item slots**.
- **E picks an item up into the inventory.** There is no "pick up, then pocket".
  - A **small item** (size `tiny` or `light`) goes straight into the first free item slot. The hands and the tool stay
    as they were, so the player keeps moving (and keeps vacuuming).
  - A **big item** (`medium`, `heavy`, `bulky`) also takes the first free item slot, but it goes into **both hands**.
    The small hands item goes back into its own slot first, and the vacuum is put away. It comes back by itself when
    the big item is dropped, if it was out when the big item was picked up.
- **Choosing a slot** (keys 1-5, d-pad left / right, or a tap or click on the hotbar) holds that
  slot's small item in one hand. Choosing slot 1 takes the vacuum out. Choosing the slot already chosen puts its
  item away (the vacuum away, or the hands item back into its slot). Choosing an empty item slot leaves the hands
  empty.
- **A big item locks the hotbar.** While it is in the hands the player can't switch slots, can't use the vacuum and
  can't pick anything else up. The pick-up prompts are not offered, and a slot key gets the sticky note "Hands full:
  drop it first". **Drop** (G, the existing drop key) frees the hands. So a player can end up with 3 small items and
  1 big one by picking the small ones up first and the big one last, or by dropping the big one, picking up another
  small one, then picking the big one up again.
- **Drop** drops the item in the hands. Small items in the other slots stay pocketed. **Throw** works as before.
- **Banking at the truck banks the whole inventory at once:** the hands item and every pocketed item, with the one
  Bank prompt.
- **On a catch** (and on death or leaving), everything drops: Carry drops the hands item where it was held and the
  pocketed items scatter around the player (`SCATTER_RADIUS`), as the pockets did.
- **Grime lock, appraisal tags and hold poses keep working.** Pocketing an item counts as its first pick-up, so a
  dirty valuable's grime locks as it goes in. Every slot keeps its item's appraisal: base value, cleanliness,
  appraised, jackpot and lock. A drawn item uses the carry hold system's own pose for its size and shape.
- **Hiding:** a player may hide holding any small item (tiny or light), but not a big one.

## 2. Speed: the load

The load is **`SMALL_LOAD` (0.5) per small item in the inventory**, pocketed or in one hand, **plus the big hands
item's carry weight** (`CargoConstants.WEIGHT`: medium 4, heavy 7, bulky 10). Carry slows the walk by it
(`CarryFormulas.carrierSpeed`: × max(0.4, 1 − 0.05 × load)), and the sprint follows the same factor (23 × the
factor). So switching slots never changes the speed.

| Carrying | Load | Walk | Sprint |
|---|---|---|---|
| nothing | 0 | 16 | 23 |
| 1 small | 0.5 | 15.6 | 22.4 |
| 2 small | 1.0 | 15.2 | 21.9 |
| 3 small | 1.5 | 14.8 | 21.3 |
| 4 small | 2.0 | 14.4 | 20.7 |
| monitor (medium) + 3 small | 5.5 | 11.6 | 16.7 |
| water jug (heavy) | 7 | 10.4 | 15.0 |
| filing cabinet (bulky) | 10 | 8 | 11.5 |

Four small items slow a player a little. A sprint with four small items still edges past the Manager's chase (20).
A big item slows them a lot, as before.

How it is wired: the walk slow moved out of `CarryServiceServer` into `CarrySpeedSystem` (Carry tells it the hands
item's weight on every pick-up and release). The inventory names the whole load (`CarrySpeedSystem.setLoadSource`)
and re-applies it whenever it changes (`CarrySpeedSystem.apply`), and Sprint reads the same load
(`CarrySpeedSystem.weightFor`). Carry's per-kind weights stay as they were, because the hold planner reads them.

## 3. Server

- `CargoInventoryRules` (shared, pure, specced) decides what E does (`pickUpPlan`), what choosing a slot does
  (`selectPlan`), the d-pad's step (`step`), whether the hands leave pick-ups open (`handsFree`) and the load
  (`load`).
- `CargoInventoryTracker` (server State, specced) stores the four slots per player, the slot whose item is in the
  hands, and the slot chosen with empty hands. A pocketed item is an entry (kind, value, visual, appraisal). The hands
  slot keeps the snapshot taken when the item went into the hands.
- `CargoInventorySystem` (server shell) routes cargo pick-ups through `CarryServiceServer:setPickUpRoute`. It answers
  the `Select` packet (rate limited) and empties the hands slot whenever Carry's hold ends. To draw an item, it respawns
  it at the player's feet and hands it to Carry. To stash one, it claims, records, releases and destroys it. It also
  publishes the slots (`CargoInventoryUtils.published`, pure) and is the load source. `CargoScatterSystem` puts a
  caught, dead or leaving player's pocketed items back in the world.
- Each player's public fields: `inv1`-`inv4` (kind), `invNValue` (the value once known: trash always, a valuable once
  appraised), `invNVariant` (an appraised jackpot's name), `invHands` (the item slot in the hands), `invSelected` (the
  empty-hands choice). The vacuum's `vacuumEquipped` says when slot 1 is out.
- `VacuumServiceServer:setEquipped(player, on, resume?)` takes the vacuum out or puts it away for slot 1.
- Analytics: an item pocketed straight from the world fires `CargoServiceServer.collected`, and
  `ShiftAnalyticsWatchSystem` counts it as a `cargo_picked_up` (source unchanged). An item drawn from a slot is a
  pick-up with source `hotbar`.

## 4. UI

The engine's Backpack hotbar is turned off, because it can't be styled. The Shift HUD draws `ShiftHotbar` instead: five
cream index cards with the key number in the corner. Each card shows:

- the vacuum (slot 1): its drawing and the canister fill;
- an item: its own art in a small viewport and its tag. The tag is `$???` until the item is appraised, then its value
  (the HOLDING slip names the hands item, with the jackpot name). Trash shows `+N`. A fragile item's tag is red.

**Sizes** (`ShiftHotbarViewModel.metrics`, follow-up the same day: the user found the first cards too big). Desktop
cards are half the first ones: 48 x 56 px (were 96 x 112), 24 px art, 5 px gaps and lift, so the bar is 260 px wide.
The text stays readable rather than halving: the key and tag at 12 px, the HANDS FULL stamp at 11 px on two lines.
A 48 px card can't fit the item's name at a readable size, so the name is left to the art. Phone cards stay 44 x 48
px (were 62 x 70): half would be 31 x 35, under a thumb's 44 px tap target, so they are about 70% of before, with
11 px text.

The chosen card is lifted and pinned. A big item's card gets a red **HANDS FULL** stamp, and the other cards fade
while it locks them. Above the desktop hotbar a slip names the hands item, its worth and its keys ("HOLDING MONITOR
$??? / fragile", "G drop"). The hotbar sits at the bottom centre on desktop and at the top centre on phone, between the
crew button and the time card. Every card is a button, so taps and clicks choose slots. The phone action arc loses its
POCKET button.

The old pocket UI is gone: `ShiftCarryPanel`, the compact HUD's tool card and cargo slip, the POCKET touch button, and
the Q (pocket) and X (swap) actions.

## 5. The small pocketable valuables

Five new small valuables, all grimy (appraised by vacuuming, `$???` until then). Their art is in the client-office-slate
kit's chunky parts style (`design/production-art/map-kits/client-office-slate/build_small_valuables.py`), uploaded to
the Icey Labs group, at `ReplicatedStorage.Assets.CleanupCrew.ArtKits["client-office-slate"].cargo.<key>`.

| Key | Name | Size | Base value | Jackpot | Traits | Open / desk weight |
|---|---|---|---|---|---|---|
| coffeeMug | Coffee mug | tiny | 40-70 | World's Best Boss, 10%, ×3 | fragile, buriable | 4 / 3 |
| wristwatch | Wristwatch | tiny | 90-170 | Gold, 8%, ×2.5 | buriable | 3 / 4 |
| deskClock | Desk clock | tiny | 55-95 | Brass carriage, 10%, ×2 | | 4 / 2 |
| snowGlobe | Snow globe | tiny | 60-110 | Musical, 12%, ×2 | fragile | 3 / 3 |
| keyring | Keyring | tiny | 30-60 | Master, 10%, ×3 | rattly (jingles in the hand), buriable | 2 / 4 |

- **More small items:** the plaque's open-floor weight goes from 2 to 3. Small kinds are now about 68% of the
  open-floor valuable roll (19 of 28), so a trip naturally fills 2-4 slots.
- **No desk phone** (cut by the user the same day). A sixth item, the desk phone (light, 50-90, open 3 / desk 1), was
  removed from the registry, the spawn tables, the art kit keys and the place's templates. Its open-floor weight went
  to the watch (2 → 3), the clock (3 → 4) and the globe (2 → 3), which keeps the small share at 68% and raises the
  average open valuable a little (the phone was below average).
- **Values:** a small item is worth about what the big one it replaces in the roll was worth. That way a map full of
  them still pays the biggest crew's quota (the office-generation guarantee, 1200 value for a quota of 900).
- **Placement:** the mug, clock and globe can sit on tables, and the clock and globe on cabinet tops
  (`OfficeSpawnRules`).
- **Proxy boxes:** each new item has its own proxy box (`partSize`), which the art is fitted into.
- **Hold poses:** the carry validator (`AnimationCarryHarness`) passes every new template on Pippa and a stock R15. On
  Pippa the hold rules pick the two-palm `under` hold for the mug, clock and globe, and the one-hand `hand` hold
  for the keyring and watch. For the keyring and watch to pass, their templates author a `CarryHandle` at an edge (the
  keyring's ring end, the watch's side). Held from their middle, the planner can't place Pippa's fist on these very
  thin items (it is 0.15 stud off), even though the live pose reaches.

## 6. Open questions for the user

- ~~The mouse wheel steps the hotbar~~ Answered: the wheel zooms the camera again (the engine's zoom, like I / O);
  the hotbar is keys 1-5, a click or tap, and the d-pad.
- **Pocket-sized items mostly use two palms on Pippa** (the `under` hold), because the automatic hold rules choose by
  shape and weight. Should small items always hang from one hand?
- **The Manager's PA "staff notice" strip** is drawn over the bottom-centre hotbar. One of them needs to move.
