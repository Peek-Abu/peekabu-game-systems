# Which way should Odd Hours make its sounds? (2026-11-13)

The owner's verdict on the P0.5 rounds: "I really dont like most of the sound picks... how basic and similar everything
sounded!! ... Did we upgrade to a better sound gen model?!" This report answers that. It has research on what we can
ship, an A/B of the same 4 sounds made 6 ways, and a recommendation. **Nothing was uploaded.**

**Listen:** https://claude.ai/artifact/BMLNnvsYVgWxsAWamG9u3Q. The cues are a UI panel opening, a tutorial pop-up,
a Rare shop buy and hiding under a desk. The letters are routes, the same on every card. Picks save to the page's
`picks` collection as `route-01` to `route-04`.

## Why it sounded basic

Rounds 1-3 built most cues on the CPU: CC0 sampled instruments (pizzicato, marimba, glockenspiel, timpani) plus
numpy synthesis, around a few Stable Audio stems. That is one small palette reused everywhere, which is exactly the
owner's "always the same instruments". Also, every generated stem so far used **SA3 Medium**, which the model card
aims at music. **SA3 Small-SFX**, the same family's model made for sound effects, has been installed all along and
was never used until today.

## What we can actually ship (research, weights licences checked)

| Route | Commercial? | Runs here? | Notes |
|---|---|---|---|
| Stable Audio 3 Small-SFX | Yes, Stability Community License (free under $1M/yr revenue) | Yes, installed: 4 takes in ~10 s | Made for SFX/foley. Today: the cleanest tonal stems (bells, music box, celesta) and short events |
| Stable Audio 3 Medium | Same licence | Yes, installed (what we used) | Music-leaning. Today it made the better *whole* swishes and dives |
| MOSS-SoundEffect v2.0 (May 2026) | Yes, Apache 2.0 | Probably (1.3B params); not verified | The only new open SFX model with commercial weights. No ComfyUI node and no independent reviews. Needs a model download, which needs the owner's OK |
| Roblox Creator Store (ProSoundEffects, APM, Roblox) | Yes, free inside Roblox | n/a | Professionally recorded, plays in place. A mix of partner sounds can't be re-uploaded, but the game can play 2-3 ids together |
| ElevenLabs Sound Effects | Paid plans only (Starter $6/mo ≈ 150 sounds) | Cloud | The hosted quality leader. Not wanted (free tools), and the MCP key is wrong anyway |
| TangoFlux, MMAudio, AudioLDM 2, AudioGen, AudioX, ThinkSound, Sony Woosh | **No**: non-commercial or research-only weights | - | Excluded, however good the demos. That includes YuE 2 from the owner's video, which is CC-BY-NC |
| HunyuanVideo-Foley | Conditional, and not valid in the EU/UK/Korea | 16 GB | Video-to-foley; a poor fit for UI |

## The A/B (the same 4 cues, loudness-matched)

| Letter | Route | What it means in production |
|---|---|---|
| A | Creator Store, one sound | Free, instant. It can't be shaped, and other games use the same sounds |
| B | Creator Store, two sounds played together | Free. Code plays both ids |
| C | SA3 Medium, one generation | Our old generator, used plainly |
| D | SA3 Small-SFX, one generation | The SFX model, used plainly |
| E | SA3 layered (Small-SFX stems + Medium) | Each cue built from 3-4 generated events (pop + chime + chime a 5th up + sparkle; register + coins + music box + sparkle; swish + dive + wood bump), in one room. It uses a new reward palette: no pizzicato, marimba, timpani or diminished chord |
| F | Before (the CPU sample route) | For comparison |

Measured, not heard:
- Only **E** passes every quality gate on all four cues. That covers layers, active octaves, band balance, movement,
  loudness, true peak and cut-off.
- The single-file routes (A, C, D) fail the "too simple" gates on the pop-up, the shop buy and the hide.
- SA3 Medium's pop-up render has notes that cut off inside the file.
- Small-SFX's whole "panel open" came out mostly as noise. Its stems were clean.

## Recommendation (pending the owner's listen)

1. **Default route: E, layered SA3, with Small-SFX for the stems.** It's free, commercial use is OK, it runs on this
   GPU, and it's the only route here that passes every gate. The fresh palette per moment is what fixes "always
   the same instruments".
2. **Use the Creator Store (B) for realistic foley** when its recording is better: doors, glass, cloth, footsteps.
   It plays in place for free.
3. **Optional pilot: MOSS-SoundEffect v2.0.** It's Apache 2.0. Download it only with the owner's OK, then run it on
   the same 4 cues for a second page.
4. **No paid services** unless the owner asks. ElevenLabs Starter at about $6 a month is the cheap step up if they do.

The owner picks the route on the page (or with a note). The next rounds use that route.

## Where things are
- Generation: `E:/AudioTools/work/p05-sound/build/ab_gen.py` (4 whole-cue and 9 stem prompts, n=4 each, Small-SFX and
  Medium). Takes are in `ab/`, with the spectrogram grid at `ab/spec_grid.png`.
- Mixes: `build/ab_mix.py`, output in `abmix/`. Library downloads (anonymous asset delivery, partner ids) are in `lib/`.
- The GPU was used for about 4 minutes. ComfyUI is stopped and `gpu.lock` is removed.

## The owner's route pick (2026-11-14)

The owner picked the **Creator Store library on all four cards**:
- panel open: A, Roblox GUI - Swipe `17208405682`;
- tutorial pop-up: B, Roblox GUI - Notification High `17208361335` + Roblox_UI_Cute_Pop `15675055424`, played
  together;
- Rare shop buy: A, Roblox GUI - Purchase `17208380755`;
- hide in: B, PSE Ninja Robe Swish `9125715516` + Body Fall Wood 2 `9113481839`.

So UI and reward cues go library-first. They play in place, so there's nothing to upload. Some cues are a pair the
code plays together. The in-house sounds the owner already liked (hide in/out, tumble, glass, truck, Bramble steps,
the two hub tracks) still need the upload OK. MOSS wasn't needed.

**Library round:** https://claude.ai/artifact/WuAiY17bzCHmkAXZFAMpkD. It has 23 cards and 67 options, and picks save
as `lib-01` to `lib-23`.
- **UI:** panel close, tab switch, tutorial next, training finished, notice toast, refused toast, work-order tick,
  work-order done, equip, claim gift, reveal build-up, ARRIVED stamp, wheel open, slider tick, card tap, the search
  and overtime hold sounds, teammate ping and quota tick.
- **Rewards:** hire and rank up, plus shop buy and locker open as rarity ladders. Each ladder is a base sound plus a
  sparkle pair that grows by tier.

Every option is a Roblox, ProSoundEffects or APM partner sound, verified free. No id serves two moments. Previews
have their leading silence trimmed (code sets the same start offset) and are loudness-matched per cue type. The ids,
names and preview builds are in `E:/AudioTools/work/p05-sound/build/lib_page.py`.
