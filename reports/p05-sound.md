# P0.5 sound pass: report (2026-11-13)

Launch List row `p1-sound-pass`. Status: **round 1 is waiting on the owner's picks.** Nothing is uploaded or wired yet.

## Done
1. **Audit:** [reports/p05-sound-audit.md](p05-sound-audit.md), commit `3df1aafb`. It lists every registered sound, where
   it plays, and keep / split / replace / new.
   - One CTA sound plays for 13 different moments: shop buy, locker open, hire, reveal, start shift and clock-out.
   - Every hold prompt shares one wind-up and one "done" sound: hide, search, overtime and clock-out.
   - Five files are each reused for two unrelated moments: the horn, the bell, body-fall vs tumble, countdown vs
     scanner, and the punch-in.
2. **The owner's video:** checked; it's in the audit, §6. It shows YuE 2 via ComfyUI. YuE 2's weights are
   non-commercial (CC-BY-NC), so we can't ship them, and the model doesn't keep time. Our MIDI route already covers
   the useful parts: take many versions and pick by ear, and make a "same song, faster" variant.
3. **Listening page, round 1:** https://claude.ai/artifact/YB6VbfWHCjWXTpXbSDyr8z. Picks save to its db collection
   `picks` as `p05r1-01` to `p05r1-09`. Everything on it is in-house, made on the CPU, and passed the
   too-simple, LUFS/peak and cut-off gates.

   | # | Card | Options | Notes |
   |---|---|---|---|
   | 1 | Hub radio track 2 "Coffee Break" | A | F major bossa, 96 bpm, 16 bars (40 s), flute + vibes |
   | 2 | Hub radio track 3 "Lunch Line" | A | Bb major pizzicato march, 120 bpm, 16 bars (32 s) |
   | 3 | Yard (outside) music | A, B | D minor (holds the motif F-A-C-Bb; no tritone clash with the F booth radio) |
   | 4 | In-shift calm music | A, B | B minor (the office hum), ends each loop on the chase's music-box B-D-F-Ab |
   | 5 | PA chime before overtime (replace library) | A, B, C | the company motif |
   | 6 | Pressure-tier sting (replace the brass library sting) | A, B | F dim7 |
   | 7 | Overtime sting (replace library) | A, B | F dim7 + clock |
   | 8 | Teammate callout ping (new; was `uiConfirm`) | A, B | |
   | 9 | Hub shift bell (new; was the office far ding) | A, B | |

   Music masters are -20 (hub), -21 (yard) and -22 (calm) LUFS, bar-exact 48 kHz OGG loops, with stems kept.

4. **Listening page, round 2 (foley):** https://claude.ai/artifact/2UCQgxuE3Hf4EfJv1mFzyp. It has 14 cards and 29
   options, and picks save as `p05r2-01` to `p05r2-14`.
   - **Cards:** shop buy, locker open by rarity (a 4-tier ladder, 2 door families), hire, rank up, quota tick, hide in,
     hide out, pushed out of a hiding spot, glass break, truck door, truck engine start, truck drive-by, scanner beep
     and Bramble steps.
   - **How they were made:** local Stable Audio 3 Medium foley stems (16 prompts x 3 takes, picked by measured
     onsets and attack), plus CC0 instrument layers in F major.
   - **Plain options:** the world foley (hide, tumble, glass, truck, drive-by, Bramble) has a version with the event
     alone. It passes every gate except layer count, which the owner's 11-04 verdict waives for world events. The
     page shows gate tags only on the layered cues.
   - **Truck engine:** round-1 truck D (approved 10-16, never wired) is option C.
5. **Owner picks so far (round 1):**
   - hub track 3 "Lunch Line" = **A**;
   - yard music = **A**, with the note "This should be for hub too!", so it also goes on the hub radio;
   - hub shift bell = **A**;
   - teammate ping = **none**: needs a new round.

6. **Owner's new direction (11-13, via the coordinator):** "forget music for outside or in shift - quiet / ambiance is
   better", and "prioritize events / things that dont have a DEDICATED SOUND! I.E: more UI stuff... dialogue /
   tutorial pop ups". The yard and calm-shift music are dropped. Yard A becomes a hub radio track (the owner's note
   on it).
7. **UI inventory:** done with a read-only sweep of the code. No panel, scene, coach card, welcome card, reveal,
   wheel or tab plays any sound. Several raw buttons are fully silent: the hotbar slot tap, mobile action buttons,
   sliders, card tiles and wheel backdrops. So are about 12 unstyled toast calls (refusals, invites, queue/transit,
   work orders). Hiding is a tap prompt with no sound at all. The holds are `cargo-search`, `shift-overtime` and
   `shift-clockout`.
8. **Listening page, round 3 (UI):** https://claude.ai/artifact/3DvELeJDK7skwfBhT5sfuR. It has 21 cards and 35
   options, and picks save as `p05r3-01` to `p05r3-21`. All are on the CPU, built from the approved round-2 UI
   masters, today's desk foley stems and CC0 instruments, and every one passes the gates.
   - **Cards:** coach card pop, tutorial next step, training finished, panel open, panel close, tab switch, notice
     toast, refused toast, work-order tick, work-order done, equip, claim gift, reveal drumroll, ARRIVED stamp,
     wheel open, slider tick and card tap.
   - **Hold wind-ups:** search and overtime each get their own.
   - **Also on it:** a new teammate ping (C) and the hub ambience bed B. Hub ambience A failed the movement gate
     and was left out.
9. **Round 2 additions:** card 15, shop buy as a rarity ladder, made from the owner's shop-buy note (A's register +
   coins, with the locker's value layers by rarity).

## Owner picks (all three pages, read 11-13 evening)

| Page | Picked | None | Unpicked |
|---|---|---|---|
| R1 | Lunch Line A; yard tune A, which goes on the hub radio; shift bell A | teammate ping A/B | Coffee Break, PA chime, pressure sting, overtime sting (in-shift music dropped) |
| R2 | hide in A, hide out A, pushed out A, glass break A, truck door A, truck engine A, Bramble steps A | shop buy, shop buy by rarity, locker open, hire, rank up, quota tick, drive-by | scanner beep |
| R3 | none | none | all 21 cards (asked the coordinator to have the owner check the page saved) |

Owner notes:
- **On hire, rank up and shop buy:** "We are always using same instruments (pizzicato, marimba, weird chord, I think
  timpani, etc!)". The next reward round needs a new palette.
- **On Bramble steps:** "super quiet / pretty much quiet as a bat until pretty close and then his footsteps suddenly
  sound loud and quick!"

## Wiring plan for the picks (ready; it lands with the upload)

The upload files are in `E:/AudioTools/work/p05-sound/upload/`. They're gated and cut-off checked. Lunch Line's only
flags are its staccato note ends, which are the march style the owner heard and picked. Effective level
E = loudest-0.4 s RMS + 20 log10(volume), against the 2026-11-10 mix spec bands.

| Key (file) | Registry home | Call site | Space / roll-off | Volume (E) |
|---|---|---|---|---|
| `depotHubLunch` (depotHubLunch.ogg, 32 s loop) | DepotAssets | `DepotSpotConstants.STATIONS`: new station "Lunch Line" | 2D Music, looped | 1.0 (matches the hub theme, -20 LUFS master) |
| `depotHubNightLot` (depotHubNightLot.ogg, 40 s loop) | DepotAssets | new station "Night Lot" | 2D Music, looped | 1.12 (+1 dB: its master is -21 LUFS) |
| `depotShiftBell` (depotShiftBell.wav) | DepotAssets: **replace the id** (it was the office far ding) | unchanged (DepotSpotSystem bell) | 3D, 18/140 kept | 0.8 (E ≈ -17) |
| `hideIn` (hideIn.wav) | HideAssets: new | HideServiceServer `enter`: `playAt(root.Position, IN, HIDE_SOUND_RADIUS)` | 3D, roll-off 45 | 1.0 (E ≈ -24.5, the Action band) |
| `hideOut` (hideOut.wav) | HideAssets: new | HideServiceServer `leave`, not cramped, at `outAt` | 3D, roll-off 45 | 1.0 (E ≈ -23) |
| `hideTumble` (hideTumble.wav) | HideAssets: **replace the id** (it was the body fall) | unchanged (cramped push-out) | 3D, roll-off 45 | 0.9, pitch 0.97-1.03 (E ≈ -20) |
| `cargoShatter` (cargoShatter.wav) | CargoAssets: **replace the id** (was library PSE 9114597147) | unchanged (CargoFeedbackUtils fragile drop) | 3D, as today | 0.9 (E ≈ -21) |
| `shiftTruckDoor` / `shiftTruckStart` (truckDoor.wav, truckStart.wav) | ShiftAssets: new (shared, so the server can validate) | DepotServiceServer `departing`: door at the pad, engine 0.9 s later. Adds `SoundServiceServer` to its dependencies | 3D at the pad, roll-off 120 | 0.9 / 0.8 (E ≈ -21 / -20) |
| `footstep_bramble_1..4` (footstep_bramble_N.wav, 4 variants matched to -20 dB loudest window) | FootstepAssets: new `bramble` set with `proximity = { silentBeyond = 18, loudVolume = 1.6, quickPitch = 1.12 }` (the proximity gate p075-monsters added in 95e03499; tune by ear) | OccupantKindRegistry bramble `sounds.footsteps = "bramble"` (spec line 238 changes from nil to "bramble") | 3D on the foot. Quiet as a bat until about 18 studs, then suddenly loud and quick (the gate) | set volume 0.9; the gate raises it to 1.6 |

Not wired this round:
- **Truck door and engine at the shift clock-out:** the truck leaves inside ShiftClockOutSystem's state flow, which
  is another session's logic. Hub departure only for now.
- **Everything picked "none" or left unpicked.**

## Open questions
- **SFX generator:** settled by the coordinator. Use local SA3 + CC0, with no ElevenLabs: the owner prefers free tools.
  The ElevenLabs key (the key ID was saved instead of the `sk_` key) has been passed to the owner. The GPU was used in
  one short batch and is idle again; ComfyUI is stopped and `gpu.lock` is removed.
- **Upload OK:** asked on the row. After the owner finishes both pages, the picks go to Icey Labs and get wired in.
- **Still to make:** hub ambience (garage room tone; SA3 bed stems exist in `stems/garage_bed_*`) and a new teammate
  ping.

## Next
- **Round 2 (foley-type SFX, once the generator is decided):** shop buy, locker open by rarity, hire, hide in/out,
  search hold, tumble out, scanner beep, truck drive-by, door and engine, rank up, quota tick, glass break, hub
  ambience, Bramble steps.
- **After the picks:** upload to Icey Labs (189923277) with the owner's OK. Then wire:
  - new ids in each feature's `Data/*Assets`;
  - new UI tiers or per-kind sounds for the split moments (`UIAssets.soundTiers`, `UISoundSystem` by Interaction
    kind);
  - the radio stations (`DepotSpotConstants.STATIONS`);
  - yard music and calm-shift music slots (`OfficeAtmosphereSystem`).

## Where things are
- Builds (outside git): `E:/AudioTools/work/p05-sound/`. Scores in `build/p05music.py`, foley stems `build/gen_stems.py` + mixes `build/mix_foley.py`, tonal cues in
  `build/sfx_tonal.py`. Renders, stems and masters in `music/<track>/`, `sfx-tonal/`.
