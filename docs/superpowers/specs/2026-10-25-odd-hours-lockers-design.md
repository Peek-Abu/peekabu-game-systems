# Odd Hours: Lost & Found Lockers (design, 2026-10-25)

Status: written from the owner's answers on 2026-10-25; the owner said to continue to the build. Items marked
**(my call)** are open for the owner to change; they live in data (LockerConstants / CosmeticRegistry) so a change is a
number, not a rewrite.

## Why

Lockers are the game's cosmetic gacha: the main way to get exclusive looks, and the "one more open" loop between
shifts. They must feel like a top gacha opening (a real 3D cutscene with the game's own models), stay fair and
readable for kids (odds and pity in plain numbers), and follow Roblox's rules for paid random items.

## Owner's answers (2026-10-25)

- Saved Gloom stays at 10% (~100 Gloom a shift).
- Pity: **an Epic-or-better is guaranteed**, and the number of opens is **worked out from the odds**.
- **Most Locker items are Locker-only.** They are never sold in the Shop. Locker items and Shop items stay separate.
- Players where paid random items are not allowed (Roblox PolicyService `ArePaidRandomItemsRestricted`) cannot open a
  paid Locker; for them the same Locker lists its items **for direct purchase at a raised price**, still inside the
  Locker screen (not the Shop), so Locker items stay Locker items.
- The opening is a **3D cutscene** built from the real in-game models, guided by owner-made AI video references
  (frames: Figma "Locker Cutscene (video refs)", scene: Workspace.LockerStage_Ref in the Odd Hours place). Until that
  lands, a simpler opening ships.

## The two Lockers

| | Gloom Locker | Gleam Locker |
|---|---|---|
| Key paid with | Gloom (earned on shifts) | Gleam (premium, bought with Robux) |
| Key price **(my call)** | 300 Gloom (about 3 shifts) | 100 Gleam (about 49 Robux) |
| Paid random item? | No: Gloom is only earned, never bought, so it opens for everyone **(my call; to confirm against Roblox's policy text)** | Yes: restricted players get direct purchase instead |
| Pool | items with `source = "gloomLocker"` | items with `source = "gleamLocker"` (none exist yet: owner to pick) |

Odds are **by rarity**, then even among the items of that rarity in the pool. A rarity with no items in the pool drops
out and the others scale up, so the shown odds are always the real ones.

Starting odds **(my call)**:
- Gloom: Uncommon 72%, Rare 20%, Epic 7%, Legendary 1%.
- Gleam: Rare 60%, Epic 32%, Legendary 8%.

**Pity:** a per-Locker counter of opens since the last Epic-or-better. The guarantee is
`ceil(1.5 / chance of Epic+)` opens **(my call: 1.5 × the average wait)**. With the odds above that is 19 for Gloom and
4 for Gleam. The Locker screen shows it live: "Epic or better in 7 opens or sooner." The counter resets on any Epic+
(lucky or guaranteed), is saved, and never moves between Lockers.

**Duplicates:** an item you already own gives back part of that Locker's currency **(my call: Uncommon 15%, Rare 30%,
Epic 60%, Legendary 100% of the key price)**. Duplicates still count for pity.

**Keys:** saved per Locker. "Open" uses a key you have; if you have none it buys one and opens, in the same
transaction. Goals and events can later grant keys (the save holds them; nothing grants them yet).

**Restricted players (Gleam Locker):** the Open button is replaced by the item list with direct prices **(my call:
Uncommon 150, Rare 300, Epic 750, Legendary 1500 Gleam)**, the same buy path as the Shop (one transaction, reveal
after). The check runs on the server (PolicyService per player, cached for the session); if the check fails, the
player is treated as restricted (fail closed).

## Rules every open follows (server-authoritative)

1. Not in a shift (same lock as the Shop), the profile is loaded, the Locker exists, and its pool has items.
2. Restricted players cannot open a paid Locker (server check, not the client's).
3. The roll happens on the server with a per-server `Random`; pity forces Epic+ at the guarantee.
4. One PlayerData transaction: spend the key (or its price), grant the item (or the duplicate refund), update pity and
   the open count. All or nothing.
5. Rate limit: one open per second.
6. The client is told what came out (item, rarity, duplicate/refund, new pity) and plays the opening, then the
   existing reveal screen.

## The opening (two stages)

**Stage 1 (now): a simple opening that already feels good.** A full-screen scene over the hub: the Locker render
(the Shop icon) shakes, the key flies in, the screen flashes the rarity colour, rays spin, then the existing reveal
screen shows the item at its rarity (Uncommon flip … Legendary foil and confetti). Skip after the first second.

**Stage 2 (after the owner's video): the 3D cutscene.** The Lost & Found back room on its own staging spot, the
player's own employee walks up with the key, the camera path, VFX and timing rebuilt from the video. Stage 1's
screen stays as the fallback (low-end devices, and "Skip").

## Screens

- **Shop → Lockers tab** (now live, no longer "Soon"): both Lockers as big cards (render, key count, price, odds
  button, pity line, Open), and "What's inside" listing every item with its rarity and an Owned tick.
- **Odds sheet:** each rarity's chance, each item's chance, the pity rule in one sentence, and the duplicate refunds.
- **Restricted view:** the Gleam Locker card shows "Buy directly" and the priced item list instead of Open.

Words follow the kid reading level: "Open", "Epic or better in 7 opens", "You already have this! +90 Gloom back".

## Not in this build

Multi-open (×10), limited/event banners, key rewards from goals, Locker sounds beyond the existing reveal stings,
the 3D cutscene itself (stage 2).

## Owner decisions still open

1. **What goes in the Gleam Locker** (no `gleamLocker` items exist yet).
2. Key prices, odds, pity factor, refund and restricted prices above (all my calls).
3. Whether the Gloom Locker counts as paid random (only if Gloom could ever be bought).
