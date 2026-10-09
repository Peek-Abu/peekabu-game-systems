# Input — design

Status: built with this spec. Roadmap item #1 (docs/ROADMAP.md).

## Goal

Gameplay code asks "did the player press **Interact**?", never "did they press E or ButtonX?". Every game
on the base declares its actions once, as data, with keyboard/mouse and gamepad bindings; menus and other
modes can block gameplay actions without each system checking UI state.

## Decisions

1. **Actions are data.** `InputActionRegistry.register(id, { context, bindings, description })`. A
   binding set has two device lists: `keyboard` (KeyCodes and mouse-button UserInputTypes) and
   `gamepad` (KeyCodes). Registration validates loudly (unknown context, empty bindings, duplicate
   id, a gamepad list holding a non-gamepad key) — the ItemRegistry contract.
2. **Contexts are a stack.** `gameplay` is always at the bottom. A system pushes a context
   (`pushContext(name, { sink = true })`) and gets a token back; removing by token (not LIFO pop)
   means two systems can come and go in any order. An action fires only while its context is
   *reachable*: walking the stack from the top, every context down to and including the first sinking
   one is reachable. So opening a menu (`ui`, sinking) silences every `gameplay` action at once.
3. **Held actions end when they become unreachable.** If Sprint is held and a menu opens, Sprint gets
   its `end` immediately — no system is left thinking a key is still down.
4. **Rebinding is an override layer**, `setOverride(actionId, bindings?)`, in memory. Persisting it is
   the Settings system's job (roadmap #10); the API it will call already exists.
5. **Input is ignored while typing**: a focused TextBox or a `gameProcessed` press never *begins* an
   action. A release always *ends* one (so held state can never stick).
6. **The UI's `movement` suppression seam is ours.** A scene that declares `suppress.movement` gets:
   the character's controls disabled (PlayerModule `GetControls():Disable()`) and a sinking `ui`
   context pushed, both undone on release.
7. **Backend: UserInputService, behind our own API.** The pure resolution core is fully specced. Roblox's
   Input Action System could replace the backend later without changing `bind` / `pushContext` /
   `setOverride`; that evaluation is deferred until a game needs touch-button parity, and nothing here
   assumes how that system behaves.

Out of scope now: on-screen touch buttons, analog axes (movement stays the engine's), chorded inputs,
persisted rebinding.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Input | client | Data | InputTypes | Types only: InputKey, Bindings, ActionDef, Phase |
| Input | client | Data | InputConstants | The context names and the base's default actions |
| Input | client | Data | InputActionRegistry | The action catalog: register / get / ids, validated |
| Input | client | Rules | InputBindingRules | Pure: which contexts are reachable; which actions a key triggers |
| Input | client | State | InputContextTracker | The context stack: push by token, remove, snapshot |
| Input | client | State | InputActionTracker | Held-action bookkeeping and the begin/end transitions |
| Input | client | Systems | InputControlsSystem | Disables / enables the character's PlayerModule controls |
| Input | client | root | InputServiceClient | The shell: UserInputService in, callbacks out, the `movement` handler |

All client realm: the server never sees raw input (an action that matters to the server is a validated
request from the system that owns it).

## API (InputServiceClient)

```lua
local disconnect = InputService:bind("interact", function(phase: "begin" | "end") ... end)
InputService:isHeld("sprint") --> boolean
local token = InputService:pushContext("vehicle", { sink = false })
InputService:removeContext(token)
InputService:setOverride("interact", { keyboard = { Enum.KeyCode.F } }) -- nil restores the default
InputService:bindingsFor("interact") --> the effective Bindings (for button prompts)
```
