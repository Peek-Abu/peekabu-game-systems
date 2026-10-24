# Office anomaly sounds (Odd Hours, stage 4)

Method: procedurally synthesised with numpy (script was in the session scratchpad; seed 7). No library or third-party audio, so no licence encumbrance. 48 kHz, WAV master + OGG Vorbis. Not uploaded.

| Cue | File | Length | Loudness | Notes |
|---|---|---|---|---|
| carTick | carTick.ogg/.wav | 8.0 s loop | -33 LUFS, peak -13 dB | brown-ish bed + 10 irregular metallic ticks (inharmonic partials 0.9-2.4 kHz) |
| tvStatic | tvStatic.ogg/.wav | 8.0 s loop | -31 LUFS, peak -16 dB | band noise (two slowly moving bands), 60 Hz hum + harmonics, 15.75 kHz whine, low rumble |
| autoDoor | autoDoor.ogg/.wav | 2.0 s one-shot | -20 LUFS, peak -8 dB | 0.6 s motor whoosh, then chime E6 + C6 (30 cents flat) |

Loop points: whole file, sample 0 to end. Noise is periodic by construction (FFT phase), ticks wrap circularly, modulations use integer cycles per loop, hum is an integer number of cycles in 8 s. Seam RMS step: carTick -1.0 dB, tvStatic +0.2 dB (50 ms windows).
Gates (game-sound-design qa_gates): autoDoor PASS (sfx). Loops pass every gate except the ambience LUFS floor (-26..-16), which is deliberately undershot: both are quiet beds. Set Sound.Volume in code.

Uploaded (owner approved) to group Icey Labs (189923277): carTick rbxassetid://127728592892514, tvStatic rbxassetid://90442376147683, autoDoor rbxassetid://100859403341825. Moderation was "Reviewing" at upload; autoDoor verified group-owned via the economy API.
