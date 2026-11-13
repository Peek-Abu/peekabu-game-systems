# Odd Hours sound audit (P0.5, 2026-11-13)

Launch List row `p1-sound-pass`. Every sound registered in code on `game/cleanup-crew` at `1c0532a9`, where it plays,
and what to do with it. Nothing was changed by this audit.

**How it was made:** a script read every `SoundRegistry.register` table (13 `Data/*Assets` files plus the emote
sounds in `EmoteVfxConstants`), then searched `src/` for every place that names each id. Provenance: an id listed in
`characters/audio/shipped-assets.md` or in a sound session's notes is in-house; the rest are Creator Store library
picks from the M3 build.

**Verdicts:** **keep** = fits, used for one moment. **split** = fine sound, but it plays for moments that need their own
sound (the owner's main complaint). **replace** = the sound itself is weak or off-style. **new** = a moment with no sound
of its own today.

## 1. The reuse problems (the owner's main complaint)

These are the places where one sound plays for moments that mean different things.

| # | Sound (id) | Plays for | Why it's wrong | Fix |
|---|---|---|---|---|
| R1 | `uiCta` (78569365251759) | **13 moments:** buy in the shop (ShopScreen, ShopPassesPanel, DealBanner, DealChooserScreen), open a locker (LockerPanel), hire a new employee (CharacterPickScreen x2), leave the reveal (RevealScreen), start a shift (DepotBoardPanel x2, DepotNextShiftCard), and finish the clock-out hold | Buying, opening a locker, hiring and starting a shift all sound the same | New: **shop buy** (cash register), **locker open** (rarity ladder; the reveal's own sound), **hire** (punch card + ta-da), **start shift** (truck door + engine). Keep `uiCta` only for "start shift" buttons and generic big buttons |
| R2 | `uiPromptHold` + `uiPromptDone` (105267179969138 + 134811176097827) | **Every hold prompt:** searching a desk, **hiding**, starting overtime and clocking out. Also training's "done" | Hiding sounds like paperwork. Searching a desk sounds like hiding | Give a hold prompt a sound per Interaction kind. **Hide in/out**: cloth, furniture creak, a soft thump. **Search**: rummage (`cargoRummage` already exists). Keep the wind-up for overtime and clock-out |
| R3 | `uiConfirm` (83738970696959) | The default for every filled button (go / primary / danger), plus hub panels, the shift review tab, and the **teammate callout ping** (CalloutAssets.PING_SOUND) | A ping to teammates is a world event, not a button press | New **callout ping**: a short desk-bell "ding" that teammates can tell apart from UI |
| R4 | `uiClick` (122165734026820) | Every other button: tabs, lists, cards | Expected for a click. Tabs and cards could get a lighter page flick | **Keep**. Optional: a "tab" variant |
| R5 | `shiftPunchIn` (109228401071501) | Shift start, plus the timecard's "clock" and "punch" moments (TimecardMomentSystem) | Three timecard beats play one sound | **Split** the timecard moments: card slide-in, then the punch clunk |
| R6 | `shiftCountdownTick` (135218748578686) | The truck countdown, and the hub truck scanner's beep (DepotTruckScannerSystem) | A scanner beep and a countdown are different things | New **scanner beep** (a handheld barcode chirp) |
| R7 | file 121905159563801 | `shiftClockOutHorn` (the truck about to leave), and `depotDriveByHorn` (a truck driving past the hub) | The "hurry up" horn plays as hub ambience, so it loses meaning | New **drive-by**: a far engine pass with a soft honk. Keep the clock-out horn |
| R8 | file 136430418224601 | `depotShiftBell` (the shift bell in the hub), and `officeFarDing1` (a far ding in the office ambience) | The bell you ring to start a shift also plays at random in the office | New **shift bell**: a real counter/school bell, rung by hand |
| R9 | file 83428002679573 | `BODY_FALL` (a crew member knocked down), and `hideTumble` (pushed out of a hiding spot, marked PLACEHOLDER in HideAssets) | Being knocked down and tumbling out of a desk are different | New **tumble out**: furniture bump, plush roll, toy squeak |
| R10 | `shiftContractMet` + `canisterChime` | Both play when the contract is met | Two reward sounds land on one moment | Drop the canister chime at that moment, or fold it into the jingle |
| R11 | `shiftStickyNote` (99429190384090) | Every "sticky" toast: coffee, hiding, training, shift notices | One paper rustle for every message is fine for UI | **Keep** |
| R12 | Bramble (School monster) | Has its own catch and unfreeze, but **no footsteps** (silent) and no patrol or tell sounds | The School's monster is silent while it moves | New: **Bramble steps** (soft foam thump), plus a tell/creak set |
| R13 | `woodWhooshQuickSwings4` (emote) | Three beats of Big Roundup (shake out, then two spins) | Repeating it within one emote is fine | **Keep** |

`officeTyping` and `harlowTyping` share 71155319819913. That one is right: it's the same typewriter in the building.

## 2. Moments with no sound at all (new)

| Moment | Where it would hook in | Notes |
|---|---|---|
| Locker open, by rarity (Common, Rare, Epic, Legendary) | LockerOpeningScreen, LockerCutsceneSystem | Round 8 made in-house candidates (family A/B). On 11-07 the owner put them on hold "waiting for a better sound generator" |
| Shop buy | ShopScreen, ShopPassesPanel, Deal* (replacing `uiCta`) | Cash register + coins + F-major arpeggio |
| Rank up | RankSlip / RankViewModel | Lanyard clip + glock motif F-A-C-Bb + small fanfare |
| Quota tick | Canister gauge (`canisterTick` exists) | Today it's an identical click with pitch jitter. Could climb in pitch as the gauge fills |
| Glass break | `cargoShatter` (library 9114597147) | Plays when a fragile item breaks. Check that it reads as a kid-safe "ceramic tinkle", not a real smash |
| Hide in / hide out | HideServiceServer (in/out), replacing the prompt "done" | See R2 |
| Hub ambience | Hub (lounge/garage) | The hub only has the lounge record. It needs a room bed: garage hum, far traffic, vending, a radio |
| Truck door + engine | Shift start (truck), clock-out | Round-1 truck **D** (local) was "good" and never wired. Truck door is new |
| Bramble steps | FootstepAssets `bramble` set | See R12 |
| Hire / new employee | CharacterPickScreen | See R1 |

## 3. Music (what exists)

| Place | Today | Gap |
|---|---|---|
| Hub (Lobby) | `depotHubTheme`, the in-house 60 s lounge cha-cha loop (F major, 96 bpm). The hub radio has 2 stations: "Garage Tunes" (the theme) and "Quiet Night" (silence) | **One 60 s loop for the whole hub session.** Needs 2-3 more tracks for the radio to rotate |
| Outside / yard | Booth radio (in-house warped lounge, 3D at the booth) + yard beds | **No music outside.** Needs a yard theme: lonely, night, sparse |
| In shift (office) | Office beds + dread + chase stems (B minor, 144 bpm) + overtime ticking | **No music while it's calm.** Needs a quiet exploration layer that hands off to the dread |
| Results | Met / overtime / missed jingles (in-house) | Keep |

## 4. Every registered sound

Columns: key · asset id · source (IH = in-house, Lib = library) · where it plays · verdict.

### UI (UIAssets, UISoundSystem)
| Key | Id | Src | Plays | Verdict |
|---|---|---|---|---|
| uiHover | 125412787340819 | IH (r2 P) | the pointer entering any button | keep |
| uiClick | 122165734026820 | IH (r2 P) | the default for buttons | keep (R4) |
| uiConfirm | 83738970696959 | IH (r2 S) | filled buttons, hub panels, review tab, callout ping | split (R3) |
| uiBack | 130280445606800 | IH (r2 P) | back/close (Locker, Reveal, Shop, Toon menu, social ask) | keep |
| uiError | 139831732223870 | IH (r2 P) | pressing a disabled button | keep |
| uiCta | 78569365251759 | IH (r2 S) | 13 moments (R1) | split (R1) |
| uiPromptHold | 105267179969138 | IH (r3 A) | every hold prompt's wind-up | split (R2) |
| uiPromptDone | 134811176097827 | IH (r3 C) | every completed hold, and training "done" | split (R2) |

### Shift (ShiftAssets, ShiftFeedbackSystem, TimecardMomentSystem, Toasts)
| Key | Id | Src | Plays | Verdict |
|---|---|---|---|---|
| shiftPunchIn | 109228401071501 | Lib | shift start, timecard clock and punch | split (R5) |
| shiftContractMet | 75263082800024 | IH (r3 M1) | contract met mid-shift | keep |
| shiftResultsMet / Overtime / Missed | 109779942246814 / 122358530335366 / 136628215898951 | IH | the performance review jingle | keep |
| shiftTierSting | 136159590763818 | Lib | the pressure tier rises | **replace**: a "low brass sting", and brass is on the doesn't-fit list. Use an F°7 pizz/music-box stinger |
| shiftWarningChime | 126147740959997 | Lib | the PA chime before overtime | **replace**: round 1 called every PA chime "poor". In-house PA ding-dong on the company motif F-A-C |
| shiftOvertimeSting | 95766845390235 | Lib | overtime starts | replace (same F°7 family as the tier sting, bigger) |
| shiftTicking | 118452299844030 | Lib | the overtime clock layer (loop) | keep |
| shiftClockOutHorn | 121905159563801 | Lib | the truck is leaving | keep (R7: drive-by gets its own) |
| shiftCountdownTick | 135218748578686 | Lib | the truck countdown, scanner beep | split (R6) |
| shiftStickyNote | 99429190384090 | Lib | the sticky toasts | keep (R11) |
| shiftStamp | 121483921177102 | Lib | the stamp toasts, timecard stamp | keep |

### Cargo / loot (CargoAssets)
| Key | Id | Src | Plays | Verdict |
|---|---|---|---|---|
| cargoSwoosh / cargoChaChing | 130905132369531 / 110411418261024 | Lib | banking an item into the truck | keep |
| cargoPickup | 95113352299095 | Lib | picking an item up | keep |
| cargoPocket | 9121003380 | Lib | pocketing an item | keep |
| cargoThudLight / Heavy | 82279308966281 / 77274323915881 | Lib | dropping an item, by weight | keep |
| cargoShatter | 9114597147 | Lib (PSE) | a fragile item breaks | **replace**: the "glass break" ask. A cartoony ceramic shatter with a toy tinkle tail |
| cargoSplash | 87333978366779 | Lib | a wet item dropped | keep |
| cargoRattle | 103584623487822 | Lib | a rattly item dropped | keep |
| cargoRummage | 9114061295 | Lib (PSE) | searching | keep, and reuse it for the search hold (R2) |
| cargoRevealLow / Mid / High / Jackpot | 103029093745671 / 127359448338833 / 114181554867050 / 119747942358809 | IH (r2 family C) | loot reveal by value | keep |
| cargoAppraise / cargoJackpot | 78325157618409 / 112524045440299 | IH (r2 A1 / r3 A) | appraisal | keep |
| cargoGlint | 100033229972306 | IH (r2 A) | a valuable item glints | keep |
| cargoSelect | 81438361671526 | IH | selecting a pocket slot | keep |

### Vacuum (VacuumAssets)
| Key | Id | Src | Plays | Verdict |
|---|---|---|---|---|
| vacuumWhine | 107917509032443 | Lib | the vacuum running (loop) | keep (heard all shift, so check it against the new music) |
| vacuumStop | 77219631283212 | Lib | release | keep |
| vacuumPop | 91652457132086 | Lib | the last bit of a pile goes up the hose | keep |
| canisterTick | 112926891018046 | Lib | the gauge rising | **replace** with a "quota tick" that climbs in pitch as it fills |
| canisterChime | 134210659787428 | Lib | the gauge full = contract met | split (R10) |

### The Manager, Bramble, catch, dread, chase (OccupantAssets)
| Key | Id | Src | Plays | Verdict |
|---|---|---|---|---|
| harlowMutter / Curious / Sigh | 135690215756036 / 95530818541505 / 126145488520317 | Lib/IH (r7 voice) | his tells | keep |
| harlowTyping | 71155319819913 | IH (r1 A) | him typing at a desk | keep |
| harlowSit, deskSwivel (+ Chair, Bend library layers) | 118633870993827, 80676054119585, 9117143754, 9043357191 | IH r3 A / r2 A | sitting, swivelling | keep |
| harlowAmbush / Creak / Crack | 90232187116807 / 114994366629386 / 120508741459350 | IH | ambush, porcelain creak, neck crack | keep |
| harlowSpotted, harlowChaseSting | 71081947321557, 136144780062166 | Lib / IH r2 | spotted, chase starts | keep |
| harlowChase_ostinato / low / motif / ticks / pulse | 124748025140120 / 139872525713729 / 82959779790252 / 89441335118534 / 105316282966706 | IH r2 B | the chase music stems | keep |
| harlowDread, harlowHeartbeat | 89353947977345, 123214528916758 | IH r4 / Lib | dread bed, heartbeat | keep |
| harlowGibberish1-4 | 112161993953770, … | IH r7 | his voice clips | keep |
| harlowCatchSting, catchFired, catchRehired | 88133727845312, 99003711272251, 80163458987401 | IH | the catch, fired card, rehired | keep |
| harlowGrab | 9113482942 | Lib (PSE) | the grab | keep |
| harlowPowerDown | 95527531363916 | Lib | lights out on a catch | keep |
| brambleCatch, brambleUnfreeze | 107173701194509, 77118119360513 | IH (11-12) | Bramble's catch, unfreeze | keep. **New: Bramble steps** (R12) |

### Footsteps (FootstepAssets)
| Key | Src | Plays | Verdict |
|---|---|---|---|
| pippa / harlow / cappy / prickles sets (6 takes each) | IH (r3 C / B) | every step, one set per character | keep |
| asphalt / grass / gravel / puddle layers | IH (yard r2 A, puddle r3 D) | outdoor surfaces | keep |
| footstepLand + cappy / prickles lands | IH (r3 B) | landing | keep |
| footstepJump1-4 + cappy / prickles jumps | IH (r3 bell research) | jumping | keep |
| footstepBodyFall (83428002679573) | IH (r3 C) | knocked down; also the hide tumble | split (R9) |
| **bramble set** | none | Bramble walking | **new** (R12) |

### Office and yard ambience (OfficeAssets)
| Key(s) | Src | Plays | Verdict |
|---|---|---|---|
| officeBedHum / Tube / Air / Colour | IH (r2 bed A) | the office bed, 2D | keep |
| officeCeilingTick, Drawer, FarDing3, TypeKey, FloorCreak, MusicBox, PipeKnock | IH (r2) | office sweeteners, 3D around you | keep |
| officeFarDing1 (136430418224601) | IH (r2) | an office sweetener; also the hub shift bell | keep here, split the bell (R8) |
| officeLightZap, officePhoneRing, officeElevatorDing, tvStatic, autoDoor, carTick | Lib | office anomalies and spots | keep |
| yardBedLamp / Wind / Crickets, yardLampBuzz, yardVendingHum, yardBoothRadio | IH (yard 11-04) | yard beds and spots | keep |
| yardOwl1-3, Fence1-3, Can1-3, FarCar1-3 | IH (yard r2 A2) | yard sweeteners | keep |
| yardTraffic | Lib | far road | keep |

### Hub, training, abilities, emotes
| Key | Id | Src | Plays | Verdict |
|---|---|---|---|---|
| depotHubTheme | 113418650275760 | IH (r2 hub A) | hub music / radio "Garage Tunes" | keep, and **add tracks** (§3) |
| depotShiftBell | 136430418224601 | IH (office far ding) | ringing the shift bell | split (R8) |
| depotDriveByHorn | 121905159563801 | Lib | a truck driving past | split (R7) |
| trainingDoorCreak / Slam / Relief | 96876231304223 / 121982576409852 / 9042046037 | Lib | the training hide stop | keep |
| abilityLetsGo, abilitySpotPing, abilitySpotPhone, abilityPlantIn / Out | 139330570557645, 118490563116936, 106880741715758, 88077512145082 / 137494633014979 | IH/Lib | employee abilities | keep |
| emote sounds: mugQuieterAtTail8, teaSip2, slideWhistle6, bubbleWobble…, bubbleBloop…, clothMovement24, woodWhoosh…, buggyWhip…, ropeImpacts4 | 9117037749 … 9118717475 | Lib (owner picks 11-03) | Cocoa Sip, Bubble Ride, Big Roundup | keep |

## 5. Priority for the new sounds

1. **Split the reuse** (R1-R3, R6-R10). This fixes the owner's complaint directly: shop buy, locker open by rarity,
   hire, hide in/out, search hold, callout ping, scanner beep, drive-by, shift bell, tumble out.
2. **The rest of `s-new-systems`:** rank up, quota tick, glass break, hub ambience, truck door and engine.
3. **Music:** 2-3 more hub tracks, a yard theme, and a calm in-shift layer.
4. **Replace the off-style library stings:** tier sting (brass), overtime sting, PA chime.
5. **Bramble:** steps and tells.

## 6. The owner's video (YorusDevs, "How I made all my Roblox game music with AI for free")

It's a 7.5-minute walk-through: ComfyUI + the **YuE 2** music model, prompted by an AI agent. The steps are:
- prompt a style and leave the lyrics empty;
- move the vocal line onto an instrument line, because it "really wants to sing", and run a vocal remover;
- make ~10 seeds per song and pick by ear (348 takes for 40 songs);
- "music cover" to make a faster, angrier version of your own song;
- crossfade the last 3 s into the start to loop;
- bulk-upload with an Open Cloud key (2,000 audio uploads a month when ID-verified).

**Is it useful? Mostly no.** YuE 2's weights are **CC-BY-NC-4.0** (non-commercial). Our sound skill already bans them
for a game that sells passes. The video itself says a company must ask first. It also admits YuE doesn't keep time
(a 2:17 score played 2:04), and our loops must be bar-exact. Our route already does the useful parts: the LLM writes
the score as MIDI per stem, we render it, and loops are cut on the bar. Two ideas are worth borrowing:
- **many takes per track, picked by ear**, for the new hub tracks;
- **a "same song, faster" variant**, which we can do cleanly from our own MIDI. One use: the hub theme played faster
  in overtime.

## 7. Tools note

The ElevenLabs MCP is connected, but its key is set wrong: it holds the key's **ID**, not the key that starts with
`sk_`. Every call fails with `invalid_api_key`. If the owner wants ElevenLabs as the "better generator" they were
waiting for on 11-07, the key needs fixing first. It's also a paid service, so it needs a cost OK.
