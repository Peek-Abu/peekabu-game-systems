# Character systems step 3: first-join pick and the Inventory (2026-10-24)

Plan: `docs/superpowers/plans/2026-10-24-character-step3-screens.md`. Status: **ready to check** (not done until you
play-check it).

## What you get
- **First-join pick.** Opens by itself in the depot when your save says you have not picked yet. Tinted in the
  selected employee's colour, live 3D hero (idle playing), About card (bio, five stats with the new icons, ability),
  big mint **Start as Pippa!**. No close button. Locked employees can be looked at; the button then says
  "Hire in the Shop soon".
- **Inventory** replaces the hub's LOCKER tile (the tile now says INVENTORY).
  - Top bar: Crew · Vacuums · Chat wheel (greyed, "Soon"), your Credits, close.
  - **Crew tab:** a card per employee in their colour, posed in the skin they wear, skin name on a flag. Buttons:
    Wearing + Skins / Equip + Skins / locked: price + Look. Then a "???" Coming soon card. No skin counts.
  - **Employee page:** back button, Skins · Idles · About.
    - Skins/Idles: grid of 3D cards on rarity-coloured stages (Legendary halo + sparkles, Odd red glow + goo),
      rarity flag, New! flag, the footer band (gold price / Gloom Locker / goal / Missed it / Coming later, mint
      Wearing on the worn one).
    - Middle: the selected skin live, rays and platform in its rarity colour.
    - Right: rarity + New! flags, name, lore, Styles row only when the skin has more than one style (greyed
      "Coming soon" until style art exists), Comes with, and the main button (Wear / Wearing / In the Shop soon /
      Gloom Locker / Missed it / Coming later).
    - About: kind, 3 words, bio, fun fact, stats, ability, "Every employee can finish every job, even alone."
  - **Vacuums** opens the old equipment page, now titled VACUUMS (the board's LOCKER tab says VACUUMS too).
- **Everything is data-driven:** cards, skins, prices, stats and colours come from CosmeticRegistry,
  EmployeeProfileRegistry and EmployeeRegistry. Adding an employee or skin there shows it on every screen.

## How it's built
- Kit pieces: `ToonViewport` (3D preview, static for cards / live for the hero, max 2 live; shows the ID photo when a
  place has no art for that employee), `ToonFlag`, `ToonSourceBand`, `ToonRarityFrame`; rarity colours in
  `UIToonConstants`; `ToonSurface` takes a custom colour.
- `InventoryViewModel` and `CharacterPickViewModel` hold every rule (specced). Screens only draw them.
- Wear/Equip/Start send requests through `CosmeticServiceClient`; the screens change only when the synced loadout
  does.
- The pick opens and closes from `DepotServiceClient` (only after your real save has arrived, so returning players
  never see it flash).

## Verified (hub window)
- Full suite: **4626 passed, 0 failed** (twice: before and after the layout fixes).
- Play, using the real request paths (sent from a test script; no clicks):
  - fresh save → the pick opened by itself; `requestPick("Pippa")` → saved, and the pick closed by itself;
  - Inventory opened from its scene; Crew tab with live data;
  - granted Lavender Specs, then `requestEquip` it → Pippa's page updated on its own (Wearing moved, hero lavender
    on a blue Rare platform) and the character in the depot swapped to lavender with glasses and lanyard.
- Screenshots (`reports/`): `step3-pick-desktop`, `step3-pick-phone`, `step3-crew-desktop`, `step3-crew-phone`,
  `step3-pippa-skins-desktop`, `step3-pippa-skins-phone`, `step3-pippa-wear-lavender`, `step3-pippa-about-desktop`,
  `step3-pippa-about-phone`, `step3-hub-lavender-world`.
- Studio left clean (test scripts removed, RunTests off, lock removed).

## Not checked yet / known gaps
- **Real clicks** (tabs, cards, Wear, Start) and a **second client** were not exercised: please play-check.
- Phone captures were taken in a phone-sized frame on a desktop window, not on a device.
- Skins without art yet (Gloom-Touched, Gloomkeeper, Bubble Buddy...) preview in the default look.
- Cappy shows Pippa's placeholder photo (his model is parked); Prickles' head is dark in previews (his art's colours).
- **New!** never clears: nothing marks items as seen yet (needs a small "seen" request; a later step).
- The **Gloom Locker** band text shrinks to "Gloom" on small phone cards; the "Chat wheel" tab text is partly under its
  Soon badge; the phone "Wearing" button text clips. Small polish items.
- Gleam has no account balance yet, so only the Credits wallet shows.
- Studio does not keep save data, so the pick opens on every Studio Play (expected; a live server keeps it).
