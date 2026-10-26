# Character systems: what to test, and what's still left (2026-10-24)

## Before you start
- Studio does not keep save data, so every Play is a brand-new player (the pick screen opens every time).
- Admin commands: press **F2** or **`** and type:
  - `premiumadd me 3000` gives Gleam;
  - `currencyadd me credits 5000` gives Credits;
  - `cosmeticgrant me Pippa.OwnerSpecial` unlocks an item (any catalogue id, like `Prickles`, `Cappy.PJ`,
    `Pippa.Gloomkeeper`).
- Phone: Studio's device emulator (Test tab > Device), e.g. an iPhone in landscape.

## Test list (real clicks)
1. **Pick** (opens by itself): click each card (Pippa / Cappy / Prickles). Locked ones say how many more Credits;
   with 5,000 Credits (command, then reopen by rejoining) they say **Hire for 2,500**. Click **Start as Pippa!**
   -> the **hire reveal** should play (white flash, Pippa pops in, a bright sweep, confetti falling) -> **Start!**.
2. **Inventory** (hub tile): the stripes should drift and the rays turn.
   - Crew: **Skins** on Pippa; on a locked card **Look**. Grant `Prickles`, then **Equip** on Prickles: you swap on
     the spot with a goo puff.
   - Pippa's page: click every card; **Wear** an owned skin (grant `Pippa.OwnerSpecial` first); a **New!** item
     loses its tag once you click it; **See in Shop** on Bubble Buddy opens its Shop page.
   - Tabs Skins / Idles / About; back with **Crew**; **Vacuums** opens the old equipment page; **Chat wheel** greyed.
3. **Shop** (SHOP tile under the gift):
   - Featured banner + Today's picks; click a pick -> its page; the page's back button.
   - **Skins** tab: the employee filters; owned items stamped OWNED.
   - **Gleam** tab: the 4 bundles should now be real buttons -> Roblox's purchase prompt (a test purchase in
     Studio) -> the Gleam goes up once.
   - **Lockers** tab: Gloom Locker (300 Gloom) and Gleam Locker (100 Gleam) cards with key count, live pity line,
     **Odds** button (shows real scaled rarity/item chances and duplicate refunds), and **What's inside** list.
     Test: `currencyadd me gloom 1200`, open Gloom Locker -> stage-1 opening (shaking Locker, flying key, Skip after
     1s) -> reveal (or duplicate refund ribbon `"You already have this! +45 Gloom back"`).
   - **Passes** greyed with Soon.
   - Buy with enough Gleam: **Yes / No** question -> **Yes** -> the **reveal** (LEGENDARY! with confetti) -> **Wear
     it!** (your character changes) or **Later**.
   - Not enough Gleam: the button says **Need X more** and takes you to the Gleam tab.
4. **Phone**: the same screens in the emulator; tell me anything that overlaps or gets cut.
5. **Two players** (Test > Clients and Servers > 2 players): each buys/wears something; the other should see the new
   skin on their character.

## What's still left for these systems
### Step 5 (built 2026-10-25, commit 6845c036)
- **Emotes**: Pippa's page > **Emotes** tab: cards show their slot; **Add to wheel** / the **Your wheel** row put
  an emote in a slot. In game **hold B** (L1; a round button on phones): the wheel shows your current employee's 4
  slots. Every emote says **Soon** for now: the clips are yours to supply (AnimationEmoteRegistry); without a clip
  the server refuses it. Emotes work in shifts too; moving stops one.
- **Chat wheel**: Inventory > **Chat wheel** tab: your 4 sticker slots (press a slot, then a sticker), the pings,
  every pack. In game **hold T** (d-pad up; a round button on phones), let go over a ping (marks where you aimed,
  with a sound, 6 s) or a sticker (pops over your head and beside your name in the crew list, 2.5 s, silent).
  Test: `cosmeticgrant me BubblePack`, put Ducky in a slot, then T. **Two players** to see each other's.
- Sticker pictures are stand-ins (kit icons) until the sticker sheets are approved and uploaded.

### Planned, not built yet
- **Lockers** (Gloom Locker / Gleam Locker): keys, odds, pity, the opening reveal. The tab is greyed until then.
- **Passes**: the tab is greyed until there are passes to sell.
- **Idles in the game**: an idle you wear is saved, but **no idle plays in the game yet, for anyone**; the idle
  previews show the employee's normal idle. Needs an animation clip per idle item; then the server plays your
  chosen idle so everyone sees it. (Same for emotes in step 5.)
- **Clips in previews**: the hero and reveals play the employee's normal idle, not the item's own clip (no clips yet).
- **Legendary reveal clip** with its prop (the concept's PJ Cappy sipping cocoa): animation work.
- **Reveal sounds**: one sting per rarity (a sound task); today it uses the normal UI sounds.
- **Hover = live preview** on grid cards (design §7): cards are still pictures; only the big middle one moves.
- **Art**: skin art for Bubble Buddy, PJ Cappy, Sheriff Prickles, the Gloom-Touched three, Gloomkeeper, Ghost
  Debunker, Pot Knight; colour-style art (the Styles buttons stay greyed); **Cappy's model** (he shows Pippa's
  placeholder photo everywhere); real portraits for Cappy and Prickles.
- **Shop**: crossed-out sale prices (waiting for your price list), event offers with dates, Gleam spent in the
  Shop reported to the economy analytics.
- **Shift place**: Cappy's model and the Rojo hookup there.
- **Base**: the Death respawn hooks need their own base pull request.

### New from your notes
- **Gleam art match**: done (v2 bundle pictures made from the real Gleam gem, live).
- **Fixed 2026-10-25** (commit 0fd9145e): ribbons no longer cut at list edges, "Soon" shows the whole word; Prickles
  and Cappy posed on cards (no T-pose); a 3D platform under every hero (pick, Inventory, Shop page, reveal); lore told
  about the employee, with a quote mark only on lines picked as spoken (`quote = true`), else a lore book icon.
- **Locker padlock icon**: the white inside the shackle is now see-through (characters/ui/character-ui/upload/
  lock_night_v2.png); upload waits for your OK.
- **Idles per crew**: each crew shows its own idle plus Sleepy Sway, the one idle made for everyone (design: idles can
  be shared). Your call whether shared idles should exist.
- **Vacuums tab** (2026-10-25, commit 9db8c0b6): option A built. Inventory > Vacuums lists every vacuum; the
  middle shows YOU (your employee, rank lanyard and all) from behind in the selected one; Wear swaps your pack on
  the spot (one vacuum for the whole crew). Brass Bellows is in the Shop (Featured rotation, Gleam 600, price not
  final) with its page and reveal on you. The old Company Equipment page is gone. Test: `cosmeticgrant me
  Vacuum.BrassBellows`, then Inventory > Vacuums > Wear; Shop > Skins > Brass Bellows.
- **Cappy's model** (Workspace.Cappy) is now the template in ReplicatedStorage.Assets.CleanupCrew.Characters.Cappy
  in the Odd Hours place: save/publish the place to keep it. In menus his shorts don't bend with his legs (their
  bend comes from a script on the model, and previews never run scripts).
