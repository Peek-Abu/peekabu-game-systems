# Sound — design

Status: built with this spec. Roadmap item #3 (docs/ROADMAP.md).

## Goal

Every sound a game plays is a named registry entry with its volume group, pitch variance and
concurrency cap declared once; gameplay code says `play("door-creak", { at = door })`, never pastes an
asset id or tunes a Sound instance inline.

## Decisions

1. **A shared registry** (`SoundRegistry`, the ItemRegistry contract: validated, loud at boot). Shared
   realm, because the server validates ids before it asks clients to play anything. Entry fields:
   `assetId` (canonical `rbxassetid://N`), `group`, `volume`, optional `pitch = { min, max }`,
   `looped`, `maxConcurrent`, `rollOffMaxDistance`. The base registers none — a game registers its own.
2. **Volume groups** are real `SoundGroup`s under SoundService: `Music`, `SFX`, `UI`, `Ambient`. Each
   played Sound joins its group, so a settings slider is one property write (`setGroupVolume`); the
   Settings system (roadmap #10) will persist it.
3. **Playback is client-side.** `play(id, { at?, volume? })`: no `at` plays 2D (parented outside the
   Workspace); `at` = a BasePart or Attachment plays from it; a Vector3 plays from a temporary Attachment
   on Terrain. One-shots clean themselves up when they end.
4. **Concurrency cap per id** (`SoundVoiceTracker`): starting an id already at its cap stops its oldest
   voice first, so a spammed footstep never stacks 40 copies.
5. **Music and ambience crossfade.** `playMusic(id?, fade)` fades the old track out while the new one
   fades in; `setAmbience(layer, id?, fade)` does the same per named layer (rain + generator hum + wind
   at once). Both loop.
6. **The server asks only when a client cannot know.** `SoundServiceServer:playAt(position, id, radius?)`
   sends one typed packet to players within the radius; `playFor(player, id)` sends 2D. Most sounds
   should instead be played by clients reacting to state they already see.
7. **Sound instances, not the Audio API**, for now: they work on every platform and cover the three
   games' needs. Filters, reverb zones and occlusion (the Audio API's strengths, good for horror) are a
   later extension behind the same `play` call.

Not now: instance pooling (a Sound is cheap to create; measure before pooling), reverb zones, Audio API.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Sound | shared | Data | SoundTypes | Types only: SoundDef, SoundGroupName, PlayOptions |
| Sound | shared | Data | SoundConstants | Group names, default group volumes, server radius |
| Sound | shared | Data | SoundRegistry | The sound catalog: register / get / ids, validated |
| Sound | shared | Utils | SoundFormulas | Pure: pitch pick, which players hear a positional sound |
| Sound | shared | Net | SoundEvents | The ByteNet packet: server → client "play this" |
| Sound | client | State | SoundVoiceTracker | Per-id voices and the concurrency cap (evicts oldest) |
| Sound | client | root | SoundServiceClient | Groups, play / music / ambience, the packet listener |
| Sound | server | root | SoundServiceServer | Validated playAt / playFor / playForAll |
