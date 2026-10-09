# Camera — design

Status: built with this spec. Roadmap item #2 (docs/ROADMAP.md).

## Goal

One owner for the camera. Systems ask for a **mode** ("spectate that player", "look through CCTV 3",
"hold this jumpscare shot") and add **effects** ("shake this hard", "kick the FOV"), and never write
`workspace.CurrentCamera` themselves — so two systems can no longer fight over the camera each frame.

## Decisions

1. **A mode stack with priorities.** `pushMode(def, priority?)` returns a token; `removeMode(token)`
   removes that entry whatever its position. The highest priority wins; equal priorities go to the most
   recent. With nothing pushed, the engine's own camera runs untouched.
2. **Mode kinds** (a tagged union, `def.kind`):
   - `default` — the engine camera (PlayerModule). Options: `firstPerson` (sets
     `Player.CameraMode = LockFirstPerson`, restored afterwards), `subject` (sets
     `Camera.CameraSubject`, restored to the local Humanoid afterwards — this is spectating), `fov`.
   - `fixed` — a still shot at a CFrame (CCTV views, a jumpscare, a held menu shot).
   - `follow` — chases a part at an offset with exponential smoothing, optionally looking at it (a
     ride/mount cam, a cutscene dolly).
   - `custom` — the caller's `update(dt) -> (CFrame, fov?)` for anything else (rails, orbits).
   Scripted kinds switch `CameraType` to `Scriptable` and back to `Custom` when the default returns.
3. **Effects are additive and layered on top of whatever mode is active**, applied after the engine
   camera updates each frame (render priority `Camera + 1`):
   - **Shake** uses the trauma model: sources `addTrauma(0..1)`, trauma decays linearly, and the
     rotation offset is `max angle × trauma² × noise` — many small sources sum naturally and a big hit
     dominates. Noise is `math.noise`, so the shake is smooth, not jittery.
   - **FOV kicks**: `kickFov(amount, duration)`, each easing out quadratically; kicks sum.
   - **Custom modifiers**: `addModifier(fn(dt) -> CFrame)` for game-specific head bob, sway or lean.
   FOV is written absolutely every frame (mode FOV or the base FOV, plus kicks), so kicks never
   accumulate into the engine's value.
4. **The UI's `cameraState` suppression seam is ours.** While a scene requests it, a `fixed` mode at
   the camera's current CFrame holds the view still (the string value is reserved for named states
   later).
5. **All maths is pure and specced** (`CameraMotionFormulas`); the stacks are pure trackers. Only the
   service touches the Camera, RunService and the Player.

To verify in Studio (cannot be unit-tested): shake over the default camera does not drift the
engine's orbit; CameraMode/CameraSubject restore correctly after spectating.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Camera | client | Data | CameraTypes | Types only: ModeDef union, Modifier |
| Camera | client | Data | CameraConstants | Tuning: shake angles, frequency, decay, render step name and priority |
| Camera | client | Utils | CameraMotionFormulas | Pure maths: shake angles, trauma decay, FOV kick curve, follow smoothing |
| Camera | client | State | CameraModeTracker | The mode stack: push by token with priority, remove, top |
| Camera | client | State | CameraEffectTracker | Trauma and active FOV kicks, stepped per frame |
| Camera | client | root | CameraServiceClient | The shell: render step, mode application, the `cameraState` handler |

## API (CameraServiceClient)

```lua
local token = CameraService:pushMode({ kind = "fixed", cframe = cctv3.CFrame, fov = 60 }, 10)
CameraService:removeMode(token)
CameraService:pushMode({ kind = "default", subject = otherPlayer.Character.Humanoid }) -- spectate
CameraService:pushMode({ kind = "default", firstPerson = true })                       -- horror games
CameraService:addTrauma(0.4)          -- a monster roar
CameraService:kickFov(8, 0.25)        -- a sprint burst
local remove = CameraService:addModifier(function(dt) return headBob(dt) end)
```
