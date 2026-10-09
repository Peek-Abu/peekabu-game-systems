# Voice — design

Status: built with this spec. Roadmap item #13 (docs/ROADMAP.md).

## Goal

Proximity voice on native characters through the Audio API, with the routing co-op horror needs: the
living hear each other by distance, a radio carries across the map, and the dead talk among themselves
without the living hearing them.

## Decisions

1. **One microphone input per player, made by the server.** An `AudioDeviceInput` named `VoiceInput` with
   `.Player` set, parented to the Player (the server must create it for it to replicate). The place runs
   `VoiceChatService.UseAudioApi = Enabled` and `EnableDefaultVoice = false` (property-only project nodes).
2. **Routing is one pure rule**, `VoiceRoutingRules.route(listener, speaker)`, over two public fields — the
   Death feature's `dead` and Voice's `radio` (a channel name):
   - the living never hear the dead;
   - the dead hear each other as a flat channel (`direct`) and, by default, the living spatially (ghosts
     listening in);
   - two living players on the same radio channel hear each other through the radio (`radio`), otherwise
     by distance (`spatial`).
3. **The server enforces who can hear whom.** Each speaker's input gets `AccessType = Allow` and an access
   list of the listeners whose route is not `none`, recomputed when anything changes. A modified client
   cannot eavesdrop on the dead channel or another team's radio.
4. **Clients wire what they may hear** (`VoiceWiringTracker`, pure; `VoiceServiceClient`, the shell):
   `spatial` → an `AudioEmitter` on the speaker's `Head` with the falloff curve (full to 10 studs, silent at
   80) heard by an `AudioListener` on the camera; `radio` → a band-limited `AudioEqualizer` straight to the
   speakers; `direct` → straight to the speakers. A route, input or head change rewires.
5. **Server API:** `setRadio(player, channel?)`, `setMuted(player, muted)` (the input's `Muted`, so nobody
   hears them), `radioOf(player)`.

Not now: speaking indicators beyond the engine's, push-to-talk (the engine's mic toggle covers it),
occlusion and reverb zones (the Audio API can add them behind the same emitters).

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Voice | shared | Data | VoiceTypes | Types only: Route, VoiceInfo |
| Voice | shared | Data | VoiceConstants | Input name, public field, falloff, radio tuning |
| Voice | shared | Rules | VoiceRoutingRules | Pure: a listener's route to a speaker, a speaker's allowed listeners |
| Voice | server | root | VoiceServiceServer | Inputs, access lists, radio and mute |
| Voice | client | State | VoiceWiringTracker | Pure: which speakers are wired, how, and the actions to rewire |
| Voice | client | root | VoiceServiceClient | Listener, emitters and radio / direct chains |
