# Carry — design

Status: built with this spec. Roadmap item #6 (docs/ROADMAP.md).

## Goal

Pick up a world object, carry it, drop it or throw it — an egg, a scrap pile, a body bag, a crate —
with the server owning who holds what. Holding an *item* (a flashlight) stays the engine's Tool /
Backpack, which native characters keep; this system is for physical world objects.

## Decisions

1. **Builders tag, code registers kinds.** A world object gets the `Carryable` tag and a `CarryKind`
   attribute naming a registry entry: `CarryRegistry.register(kind, { weight, throwable?, throwSpeed?,
   holdOffset? })`.
2. **Pick-up is an interaction.** The Carry server tags carryables `Interactable` with the `carry`
   interaction kind, so the prompt, distance and cooldown checks all come from Interaction.
3. **One object at a time, server-owned.** `CarryHoldTracker` maps players ↔ objects; a second pick-up
   or a pick-up of a held object is refused. The object is welded in front of the HumanoidRootPart
   (made massless and non-colliding while held), so it moves with the player's own character.
4. **Weight slows you:** `walkSpeed = base × max(minMultiplier, 1 − weight × slowPerWeight)`, applied on
   the server and restored on drop.
5. **Drop and throw are Input actions** (`drop`, `throw`) sending one validated packet each. A throw
   uses the camera's look direction (normalized and checked on the server) and the kind's throw speed.
6. **Everyone can see who carries what**: the object gets a `CarriedBy` attribute and the carrier's
   public-player record gets `carrying = kind`.
7. **Death, respawn or leaving drops the object.** `forceDrop(player)` is also the hook for game rules
   such as stealing.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Carry | shared | Data | CarryTypes | Types only: CarryDef |
| Carry | shared | Data | CarryConstants | Tag/attribute names, slowdown, drop and throw tuning |
| Carry | shared | Data | CarryRegistry | The carryable kinds, validated |
| Carry | shared | Utils | CarryFormulas | Pure: walk speed for a weight, throw velocity |
| Carry | shared | Net | CarryEvents | Packets: drop, throw (client → server) |
| Carry | server | State | CarryHoldTracker | Who holds what (one object per player) |
| Carry | server | root | CarryServiceServer | Pick up, drop, throw, force-drop; the `carry` interaction |
| Carry | client | root | CarryServiceClient | The drop / throw Input actions → packets |

## 2026-10-10 additions

Carry now tells a game when something is held or let go. `CarryServiceServer.pickedUp(player, object)` fires after a pickup. `CarryServiceServer.dropped(player, object, reason)` fires when the object is released. A `DropReason` is `"drop"`, `"throw"`, `"forced"`, `"death"`, `"removed"` or `"destroyed"`. `forceDrop(player, reason?)` takes the same reasons.
