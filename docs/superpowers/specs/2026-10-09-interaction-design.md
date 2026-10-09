# Interaction — design

Status: built with this spec. Roadmap item #5 (docs/ROADMAP.md).

## Goal

"Press E on this" works the same way in every game, on every platform, and the server — never the
client — decides whether a press counts.

## Decisions

1. **Builders tag, code registers kinds.** A world object (a BasePart, or a Model with a PrimaryPart)
   gets the `Interactable` CollectionService tag and an `InteractionKind` attribute. A kind is a
   registry entry (`InteractionRegistry.register(kind, { actionText, objectText?, holdDuration?,
   maxDistance?, cooldown?, requiresLineOfSight? })`) and exactly one server handler
   (`InteractionServiceServer:onInteract(kind, function(player, target) ... end)`).
2. **Engine prompts for the UX.** The server creates a `ProximityPrompt` on each tagged object, so
   keyboard, gamepad and touch, hold-to-interact and the on-screen prompt all come from the engine. The
   client re-keys prompts to the player's `interact` Input binding.
3. **The server re-checks every trigger** (InteractionRules): the player has a character, is within
   `maxDistance` (+ a small tolerance for latency) of the object, the object is still enabled, and
   the per-player-per-object cooldown has passed. Only then does the kind's handler run (isolated: a
   handler error is logged, never thrown into the engine).
4. **Enabling is an attribute** (`InteractionEnabled = false` hides the prompt), so builders and code
   use the same switch; `setEnabled(target, enabled)` is the code path.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Interaction | shared | Data | InteractionTypes | Types only: InteractionDef |
| Interaction | shared | Data | InteractionConstants | Tag and attribute names, default distance, tolerance |
| Interaction | shared | Data | InteractionRegistry | The interaction kinds, validated |
| Interaction | server | Rules | InteractionRules | Pure: is this trigger allowed (character, distance, enabled, cooldown) |
| Interaction | server | State | InteractionCooldownTracker | Last use per player per object |
| Interaction | server | root | InteractionServiceServer | Prompts on tagged objects, validated dispatch to handlers |
| Interaction | client | root | InteractionServiceClient | Re-keys prompts to the `interact` Input binding |
