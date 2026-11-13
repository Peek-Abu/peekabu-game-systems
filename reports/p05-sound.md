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
