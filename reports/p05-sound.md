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

## Open questions
- **SFX generator:** on 11-07 the owner held the round-8 in-house SFX (locker by rarity, shop buy, rank up, quota tick,
  hide in/out, hub ambience, truck) "waiting for a better sound generator". The ElevenLabs MCP is now connected, but its
  key is the key ID, not the `sk_` key, so every call fails. It's also paid. Waiting on the coordinator/owner: use
  ElevenLabs (fix the key, OK a cost), or local SA3 + samples?
- **GPU:** asked the coordinator for the local Stable Audio GPU. No answer yet.

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
- Builds (outside git): `E:/AudioTools/work/p05-sound/`. Scores in `build/p05music.py`, tonal cues in
  `build/sfx_tonal.py`. Renders, stems and masters in `music/<track>/`, `sfx-tonal/`.
