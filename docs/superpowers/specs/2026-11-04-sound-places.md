# Sound places (inside / outside) — design

Status: approved by the owner 2026-11-04 (full cut, Lethal Company style), built with this spec. Backlog: "Sound
groups in SoundService" and "Inside sounds heard outside" (`docs/superpowers/launch-backlog.md`). Builds on
`2026-10-09-sound-design.md`.

## The problem

In the yard you hear the office: Mr. Harlow's footsteps, light zaps, phones, other players' steps. The building's
shell sits right against the yard (`EXTERIOR_OFFSET` is zero; the yard ends 5 studs from the dock room), the doors
are teleports, and a Sound ignores walls. So every positional sound inside reaches the yard, and the other way round.

## The rule (owner, 2026-11-04)

Like Lethal Company: **from outside you hear nothing from inside, and from inside nothing from outside.** Players by
the door do not hear Harlow coming. A short fade at the switch so nothing clicks. Voice chat is unchanged.

## How sounds play today (what this builds on)

- Every gameplay sound goes through `SoundServiceClient` (`play` / `playOneShot`, and the server's `playAt` arrives
  there as a point play). Footsteps (players' and Harlow's), Harlow's mutter, typing, voice and stings, zaps, phones,
  anomalies and the office emitters are all positional plays. One place sets each Sound's group: `configure()`.
- The client already knows where the local player is: `OfficeAtmosphereSystem` tests the character's root against
  the `Workspace.CleanupCrewOffice.Outdoors` boxes every `OUTDOOR_POLL` (0.25 s), and switches at once while the
  teleport fade covers the screen. The office's 2D bed is already stopped outside.

## Decisions

1. **A sound's place comes from where it plays.** A positional play is placed when it starts: its point inside an
   Outdoors box → `Outside`, else → `Building`. Harlow, every player and every office prop follow the rule with no
   per-sound tagging. No boxes (the hub, an authored layout without grounds) → nothing is placed → nothing changes.
2. **Untouched, as before:** every 2D sound (UI, music, the chase stems, your own stings, the heartbeat, the shift's
   PA chime and clock-out horn, which already play 2D).
3. **`heardEverywhere`**, a new optional registry flag, keeps a rare positional world sound out of the places (it
   plays in its plain volume group). **No existing sound gets it today**: the only shift-wide cues (overtime chime,
   clock-out horn) are 2D already, and the truck is in the yard, so inside you do not hear it, as the rule says. It
   is there for a future alarm or horn that must carry.
4. **Place groups nest under the volume groups:** `SFX/Building`, `SFX/Outside` (`Ambient/...` likewise), made on
   first use. A nested SoundGroup is supported by the engine (SoundGroup docs); the volume sliders and the dread's EQ
   on the parent keep applying. The other place's group sits at volume 0, the listener's at 1.
5. **The switch:** `OfficeAtmosphereSystem` hands the Sound feature the Outdoors boxes and the listener's place
   (`SoundServiceClient:setPlaces(boxes, listener, fade)`) on every apply and every poll. A change of the listener's
   place tweens the two groups: instant while the teleport fade covers the screen, `OUTDOOR_FADE` (0.3 s) otherwise.
6. **Moving loops re-check their place.** A one-shot keeps the place it started in (it is short). A looping play on
   something that moves (Harlow's mutter on his head, a vacuum loop on a player who walks through a door) is placed
   again on each poll.

## New modules

None. The pure rules go into the existing `SoundFormulas` (Sound, shared, Utils):

| Feature | Realm | Subfolder | Name | Change |
|---|---|---|---|---|
| Sound | shared | Utils | SoundFormulas | + `placeOf(point, boxes)`, `placeGain(source, listener)` (specced) |
| Sound | shared | Data | SoundTypes | + `SoundPlace`, `SoundPlaceBox`, `SoundDef.heardEverywhere` |
| Sound | shared | Data | SoundRegistry | validates `heardEverywhere` is a boolean (specced) |
| Sound | client | root | SoundServiceClient | + `setPlaces`, the place groups, loop re-check |
| Office | client | Systems | OfficeAtmosphereSystem | calls `setPlaces` with its boxes and answer |

## Done means

Inside sounds silent in the yard and yard sounds silent inside; no click at the doors; specs pass in Studio; checked
in real play walking in and out of both doors (a second client for another player's steps and Harlow).
