# VFX — design

Status: built with this spec. Roadmap item #4 (docs/ROADMAP.md).

## Goal

Three different jobs that are all called "VFX", each with one owner, so no system hand-rolls particles,
fights another over a BlurEffect, or leaves Lighting changed behind it:

1. **Effect recipes** — "play `egg-crack` here": particles and lights from an artist-built template,
   plus an optional sound and camera shake, as one named entry.
2. **Screen effects** — blur, colour correction and depth of field requested by many systems at once
   and combined, not overwritten.
3. **Atmosphere presets** — "night", "power outage": Lighting values blended in over time and blended
   back out.

UI motion (fades, easing) is not here; it belongs to the UI framework.

## Decisions

1. **Recipes are data over artist templates.** `VfxRecipeRegistry.register(id, { template, lifetime,
   sound?, trauma?, shakeRadius? })`. `template` names a Folder in `ReplicatedStorage.Assets.Vfx`
   (artist-owned, kept by `$ignoreUnknownInstances`). Playing clones the template's children onto an
   anchor Attachment at the spot: a ParticleEmitter with a numeric `EmitCount` attribute bursts that
   many particles; any other emitter or light stays on for `lifetime` seconds; the anchor is destroyed
   once the last particle can have died. Beams and trails need two attachments, so they stay
   game-specific code.
2. **A recipe can also play a sound and shake the camera**, through the Sound and Camera services.
   The shake falls off with the camera's distance from the effect:
   `trauma × (1 − distance / shakeRadius)²`.
3. **Screen effects are requests, combined.** `requestScreen({ blur?, brightness?, contrast?,
   saturation?, tint?, depthOfField? })` returns a token. All live requests combine: blur and depth of
   field take the strongest; brightness, contrast and saturation add; tints multiply. The combined
   target is eased toward each frame, so effects fade in and out. The effects live under the Camera
   (client-only, never touching artist-owned Lighting children).
4. **The UI's `blur` suppression seam is ours**: a scene that asks for blur gets a standard blur request
   while it is open.
5. **Atmosphere presets blend Lighting properties** (ClockTime, Brightness, ExposureCompensation,
   Ambient, OutdoorAmbient, FogColor, FogStart, FogEnd). The place's own values are captured at start as
   the base; a preset only lists what it changes; `setAtmosphere(nil)` blends back to the base.
   ClockTime blends linearly (no wrap-around through midnight).
6. **The server only sends what clients cannot know**: `playAt(cframe, id, radius?)` to nearby players;
   `setAtmosphere(id?, fade)` to everyone, re-sent to players who join later. A single-player game can
   call the client's `setAtmosphere` directly.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Vfx | shared | Data | VfxTypes | Types only: Recipe, ScreenRequest, Atmosphere |
| Vfx | shared | Data | VfxConstants | Template folder names, default radius, UI blur size, smoothing |
| Vfx | shared | Data | VfxRecipeRegistry | The recipe catalog, validated |
| Vfx | shared | Data | VfxAtmosphereRegistry | The atmosphere preset catalog, validated |
| Vfx | shared | Utils | VfxFormulas | Pure: shake falloff, screen request combination, atmosphere resolve/blend |
| Vfx | shared | Net | VfxEvents | Packets: play a recipe, set the atmosphere |
| Vfx | client | State | VfxScreenTracker | Live screen-effect requests by token |
| Vfx | client | root | VfxServiceClient | Recipes, screen effects, atmosphere, the `blur` handler, listeners |
| Vfx | server | root | VfxServiceServer | Validated playAt / playForAll / setAtmosphere (+ late joiners) |
