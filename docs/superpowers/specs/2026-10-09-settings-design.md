# Settings — design

Status: built with this spec. Roadmap item #10 (docs/ROADMAP.md).

## Goal

Player preferences — volumes, camera shake, keybinds, and whatever a game adds — saved with the account,
changed by the player through one validated request, and applied by the systems that own them.

## Decisions

1. **A shared settings registry.** `SettingRegistry.register(id, def)` where `def` is one of
   `{ kind = "number", default, min, max, step? }`, `{ kind = "boolean", default }`,
   `{ kind = "choice", default, options }`, or `{ kind = "keybinds", default = "" }`. Shared, because the
   server validates every change against the same definitions the client renders. The base registers
   `musicVolume`, `sfxVolume`, `uiVolume`, `ambientVolume` (0–1), `cameraShake` (0–1, accessibility) and
   `keybinds`; a game registers its own (`mouseSensitivity`, `colorblindMode`, …) at load.
2. **One account slice**, `settings = { values = { [id] = value } }`: only values that differ from the
   default are stored, so a changed default reaches every player who never touched it. The data-layer
   validator checks every stored value against its definition (unknown ids are tolerated for
   retirement).
3. **The client may write, through one validated request.** `SettingServiceClient:set(id, value)` applies
   the value locally at once (a slider stays responsive) and sends it after a short debounce; the server
   (`SettingRules.coerce`) refuses an unknown id or a wrong type, refuses out-of-range numbers and
   unknown choices, snaps numbers to `step`, and stores it. The replicated slice then confirms it. Rate
   limited through RequestHandler. `reset(id?)` returns one or every setting to its default.
4. **Keybinds are one setting**: a compact string `action=kb:E,MouseButton1/gp:ButtonX;sprint=kb:LeftShift`
   (`SettingKeybindUtils.parse` / `format`, key names checked against `Enum.KeyCode` and the mouse-button
   `UserInputType`s, length-capped). The client applies it through `InputServiceClient:setOverride`;
   actions it does not know are ignored, so a removed action never breaks a save.
5. **Applying is the client service's job**, in one table: volumes → `SoundServiceClient:setGroupVolume`,
   `cameraShake` → `CameraServiceClient:setShakeScale`, `keybinds` → Input overrides. A game's own settings
   use `observe(id, fn)` (called now and on every change).

Not now: engine settings scripts cannot write (mouse sensitivity, graphics quality — the engine owns
those), per-device profiles, a settings screen (a UI scene a game styles itself).

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Setting | shared | Data | SettingTypes | Types only: SettingDef union, SettingValue, KeybindMap |
| Setting | shared | Data | SettingConstants | Base setting ids and definitions, limits, debounce |
| Setting | shared | Data | SettingRegistry | The setting catalog, validated (base settings pre-registered) |
| Setting | shared | Rules | SettingRules | Pure: coerce a requested value, read with defaults, the slice validator, parse a request |
| Setting | shared | Utils | SettingKeybindUtils | Pure: parse / format the keybinds string |
| Setting | shared | Net | SettingEvents | Packet: set a setting (client → server) |
| Setting | server | root | SettingServiceServer | The account slice and the validated set request |
| Setting | client | root | SettingServiceClient | get / set / reset / observe, applying base settings to Sound, Camera, Input |
