# P0.5: places menu and School (2026-11-13)

Launch List rows: `p1-places-menu`, `p1-school-danger`. Commit `a033ecef` on `game/cleanup-crew` (pushed).
Owner rules sheet (tap YES/NO, answers save to its db `answers`): https://claude.ai/artifact/FWHpDVx7QJw2QUuQf5mSvw

**Status: code is in and pushed. Specs and real play have not been run yet.** There is no headless runner, and the
coordinator hands out Studio. Both rows stay "Ready to check" until the specs pass in Studio and the owner plays it.

## What changed

### Places menu picks the map (`p1-places-menu`)
- The Jobs board is now the **PLACES** menu: one posed-scene photo card per place. The cards are Office, School
  (the approved Bramble locker-hall shot), and Hospital / Motel / Mall (still SOON).
- **The host taps a card to pick the truck's place.** Other players' taps only show that place's detail. The line
  under the header says who picks: "Tap a place to pick it!", "The host picks the place." or "Get on a truck to
  pick a place."
- **The truck's two small OFFICE / SCHOOL buttons are gone.** One **PLACE** button replaces them. It shows the
  truck's pick, and anyone's tap opens the places menu.
- **DANGER meter** on each place card (5 Gloom drops, filled to the level): Office 1, School 2.
- **The detail follows the focused place**: client, quota chip (the School's contract is bigger), tip, and the
  monster card (Harlow, or Bramble with "Stops when you look at it").
- **School is locked until bought for 2,500 Credits.** Buying takes two taps: BUY, then SURE?, which goes back to
  BUY after 4 s. If the player can't afford it, the button is greyed and says "Need more Credits".
  - Server: new account slice `places` (`DepotPlaceSystem`). One PlayerData transaction does both the
    `CurrencyServiceServer:currencyOp` spend (the same server spend path the Shop uses) and the unlock.
  - No shop entry, and no Shop or price files touched.
- **Gleam pays the rest** (`73368e33`, store-flow's owner-approved rate of 1 Gleam = 10 Credits):
  - When Credits are short, BUY says "Use N Gleam", with "You need N more Credits" under it. It still takes two
    taps.
  - The server pays through `ShopServiceServer:payOps` in the same transaction as the unlock.
  - Depot can't require the Shop: the Shop already reaches Depot through Cosmetic and Shift, so that would be a
    require cycle. Instead the Shop hands Depot its payment at init (`DepotServiceServer:setPlacePayer`), the same
    way Timecard injects its phase reader. That is a 6-line edit in `ShopServiceServer.init`/`stop`.
- **A truck plays only a place its host owns.** This is checked when the pick is made, every tick (so if a new
  host doesn't own the place, the truck goes back to the Office), and at departure.

### School is harder and pays more (`p1-school-danger`); the Office is unchanged
| | Office | School |
|---|---|---|
| Gloom goal, crews 1/2/3/4 (Big Crew 5/6) | 640/690/740/790 (840/890) | 800/865/925/990 (1050/1115), x1.25 |
| Dirty rooms | 4–6 | 5–7 |
| Piles per dirty room | 3–5 | 3–6 |
| Top-up piles (thin map) | up to 6 | up to 12 |
| Valuables | 10–14 | 13–17 |
| Valuable worth | x1 | x1.25 |
| DANGER | 1 | 2 |
| Monster | Harlow | Bramble (unchanged: chase 27, a hit takes a life) |

Every Gloom pays 1 Credit, so the School also pays more. The arrival card, the truck card title and the board quota
all post the School contract on a School run.

## Modules
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Depot | shared | Data | DepotPlaceConstants | Place prices, DANGER levels, menu words |
| Depot | shared | Rules | DepotPlaceRules (+spec) | Owns / canBuy / unlock / validate / danger / parse |
| Depot | server | Systems | DepotPlaceSystem | `places` slice; BuyPlace becomes one transaction; `owns` |
| Depot | client | Net | DepotPlaceSender | Sends the menu's PickMap and BuyPlace (avoids a require cycle with DepotServiceClient) |
| UI Depot | client | Screens | DepotPlaceCard | One places-menu card (split out of DepotBoardPanel) |
| UI Depot | client | Screens | DepotPlaceButton | Renamed from DepotMapCards: the truck's single PLACE tile |

Also edited:
- `ShiftQuotaFormulas.quota(crew, map?)`, with `ShiftConstants.QUOTA_SCALE_BY_MAP`.
- `OfficeConstants.SPAWN_BY_MAP`.
- `RollOptions.valueScale` / `topUpMax`.
- `DepotMapSystem` ownership checks.
- The new slice in `PlayerDataTypes` / `PlayerDataConstants` / StateSync, plus 17 spec fixture profiles.

## Checks
- Pass: `luau-lsp analyze`, `stylua --check`, `check_pr_rules` (vs `origin/game/cleanup-crew`), `module_map --check`.
- `selene`: 0 errors. One warning remains, in `UIPreloadRules.luau`. It was already on the branch; not mine.
- File length: `DepotBoardPanel` was already over 400 code lines on the branch. I split the cards out, so it is
  back near where it was. Many other branch files are also over the cap and were already failing.
- **Not run yet:**
  - The TestEZ suite in Studio, including the new School coverage spec: every crew's School contract coverable on
    25 generated Schools. If it fails, raise School `topUpMax` or the dirty rooms.
  - A real play check: buy School with test Credits, host picks School on a truck, crew sees it, the run is the
    School with its bigger goal, and a non-owner host gets bounced to the Office.

## Owner's answers (rules sheet, 2026-11-13)
Yes to everything except:
- **R1 (price): 2,500 Credits, not 1,500.** Applied. The owner also floated moving new employees to 5,000. That is
  the catalog / store-flow sessions' price data, so I didn't touch it; I passed it to the coordinator.
- **D1 (DANGER): School 2, not 3.** Applied. Office stays 1.
- **S5 (Bramble unchanged): NO, with no note.** The owner wants Bramble changed but didn't say how. I need a
  concrete yes/no follow-up before changing his speed or rules.
- **K1 (School photo):** the owner asked whether it is posed like the Office shot or an AI image. It looks AI-made
  (painterly, not an engine render), so it fails the "posed scene shots of our game" rule. I plan a real Studio
  capture of Bramble in a School locker hall for my Studio turn.
- **R5:** yes. Training counts as a place like the Office and School, but it doesn't need its own unlock
  mechanic.

## Menu candidates built from our posed scene shots (not built, per the brief)
1. **Hire / employee picker:** each employee posed in the hub, instead of flat portraits.
2. **Skins (locker):** the employee wearing the skin, posed on the truck bed or in the place it fits.
3. **Shift results / review:** a posed crew photo in the place they just cleaned (night lighting, Gloom gone).
4. **Monster guide / "Who's on site":** Harlow and Bramble posed in their own place, a card each, using the same
   DANGER meter.
5. **Daily reward / clock-in:** Pippa at the time clock, a scene per streak day.
6. **Rank chart:** each rank's lanyard on an employee, posed at the depot.
7. **Training stops:** each stop's card from a posed shot of that room.

## Follow-ups
- Overtime loot on the School is not scaled x1.25 yet (`rollOvertime` has its own appraisal).
- The world signs in the depot (`DepotWorldViewModel` quota ranges) still post Office numbers.
