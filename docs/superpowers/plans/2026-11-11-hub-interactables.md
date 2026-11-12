# Hub interactables (Night Garage), 2026-11-11

The owner's picks from the lobby research (`side-session-notes/.../hub-lobby-research-2026-11-11.md`):

- **A.** Supply Counter → the Shop.
- **B.** Employee standees → the Shop on that employee's page.
- **C.** Coffee machine → the coffee choice (Robux or Gleam); the coffee time runs on the next shift.
- **D.** Crew photo wall → the weekly crew board, big.
- **E.** Rank chart → your rank on the 7-rank ladder.
- **F.** Radio → the next station, just for you.
- **G.** Seats you can sit in.
- **H.** Shift bell → a ding everyone hears.
- **L.** Life outside: a delivery truck drives past now and then.

Not now: the secret, the boards, the mailbox. The owner allows a bigger hub; keep the walk from spawn to the trucks short
and phones fast.

## How it works

- **Studio tags the spots.** Every spot is a Studio part with the base Interaction tag (`InteractionConstants.TAG`) and
  `InteractionKind` set to one of the `depot-spot-*` kinds. A standee also carries `DepotEmployee = <employee id>`.
  A seat is a plain `Seat` and needs no code. The drive-by road is two or more parts tagged `DepotDriveBy` with
  `Order = 1..N`.
- **The server owns every prompt.** It registers the kinds and checks every use through `DepotSpotRules`. It then
  sends the player `DepotEvents.Spot` (what to open), or, for the bell, sends `DepotEvents.Bell` to everyone. Each bell
  has a cooldown.
- **The client opens the screen.**
  - Shop and standees: `ShopStore.open(id)` plus the Shop scene.
  - Coffee, crew wall and rank: new small scenes.
  - Radio: `DepotStore` station, which the atmosphere system plays as the hub music.
  - Bell: the registered bell sound, played at the bell.
- **The drive-by is client-only** and purely visual (`DepotDriveBySystem`).

## Words (3rd-grade level)

| Spot | Prompt | Screen words |
|---|---|---|
| Supply Counter | "Shop" · "Supply Counter" | |
| Standee | "Meet" · employee name | |
| Coffee machine | "Coffee" · "Coffee machine" | the coffee choice, its line "2x pay on your next shift!" |
| Crew wall | "Look" · "Top crews" | the crew board |
| Rank chart | "Look" · "Rank chart" | "You are here!" and "X more XP to <next rank>" |
| Radio | "Next song" · "Radio" | toast: station name |
| Bell | "Ring" · "Shift bell" | |

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Depot | shared | Data | DepotSpotConstants | The hub spots' kinds, prompt words, attributes, radio stations, bell cooldown and drive-by timing |
| Depot | shared | Rules | DepotSpotRules | Is a spot use valid, and what it opens; the next radio station; whether the bell is ready; the next drive-by delay |
| Depot | server | Systems | DepotSpotSystem | Registers the spot prompts and answers them (Spot to the player, Bell to everyone) |
| Depot | client | Systems | DepotSpotSystem | Opens what a Spot says (Shop, coffee, crew wall, rank chart, radio) and plays the bell |
| Depot | client | Systems | DepotDriveBySystem | Drives the delivery truck past the yard now and then |
| (UI) | client | Screens/Depot | DepotSpotScene, DepotCrewWallScreen, DepotRankChart, DepotRankChartViewModel | The coffee, crew-wall and rank-chart scenes and their words |

Edited: `DepotEvents` (Spot, Bell), `DepotStore` (radio station), `DepotAssets` (bell, horn), `OfficeAtmosphereSystem`
(plays the station), `DepotServiceServer` / `DepotServiceClient` (start the systems).

Specs: `DepotSpotRules.spec`, `DepotStore.spec` (station), `DepotRankChartViewModel.spec`. Both `DepotSpotSystem`s and
`DepotDriveBySystem` are spec-exempt shells; their decisions are the specced rules.

## Round 3 (owner notes 2026-11-11)

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Training | client | Systems | TrainingCoachSystem | The coach (Pippa, waving) beside the Training pad while this player still needs training |
| (UI) | client | Screens/World | DepotClockSign, DepotDailySign | The time clock's sign and the daily bonus sheet in the game's kit |

Also: the hub's small "Find a truck!" tab (DepotHubViewModel.findTruck), the bell's swing and ring wave
(DepotSpotRules.bellSwing), the radio's music notes (DepotSpotRules.noteRate; the image waits on the owner's upload OK).

Round 3 (owner 2026-11-11): a ninth spot, `locker` (`depot-spot-locker`): the Gloom and the Gleam Locker doors in the
hub's locker row open the Shop on its Lockers tab (`ShopStore.openTab`); any spot may name itself on its prompt
(`DepotLabel`). The radio notes image is uploaded (Icey Labs).

## The Supply Counter clerk ("Stamp & Stack", owner 2026-11-11)

Today's clerk stands behind the Supply Counter stamping parcels (ClerkStamp, a 2.6 s loop; markers Thunk and Lift) and
waves when you walk up or open the Shop there (ClerkGreet). One employee a day for everyone (the server's day number),
so it is the same clerk on every client and nothing replicates. Clips uploaded to Icey Labs (stamp 109774578542575,
greet 105235060315952; design/animations/clerk).

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Depot | shared | Rules | DepotClerkRules | Which employee clerks today; when the clerk greets; the parcel's height and its hop |
| Depot | client | Systems | DepotClerkSystem | Builds today's clerk at the DepotClerkSpot (stamp in hand, parcel on the counter) and plays the clips |

Edited: `DepotSpotConstants` (CLERK), `DepotAssets` (the two clip ids), `DepotSpotSystem` (the Shop greets),
`DepotServiceClient` (starts it). Spec: `DepotClerkRules.spec`; `DepotClerkSystem` is a spec-exempt shell.
