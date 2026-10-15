# Harlow pursuit correction

Scope: existing Occupant server Rules/OccupantBrainRules + sibling spec, shared Data/OccupantTypes and OccupantConstants, server Utils/OccupantTuningFormulas + spec; existing Shift shared Data/ShiftConstants owns pressure speed knobs. Existing Npc server Rules/NpcPathRules + spec and Systems/NpcMoverSystem, Data/NpcConstants own navigation recovery. No new implementation modules, new roles/subfolders or services. Preserve other agent art/layout files and keep Studio exclusive to asset agent.

Spec first: regression tests for retained target outside acquisition cone, hidden target not tracked through walls, last-seen search plus two nearby authored route probes, search noise stays urgent, search timeout/safe-zone/grace, speed pressure progression. Path regressions for blocked-ahead versus behind and bounded stalled movement. Navigation has one in-flight computation, retains a usable prior path while refreshing, cancels stale/stop results, and rebuilds blocked/stalled paths without bypassing costs. Tight waypoint reach avoids cutting corners.

Draft tuning: crew17 / solo16.5 chase, +0.5 per pressure tier; 10-second scan per search point, maximum32-second search. Actual balance remains unverified until isolated TestEZ and real corner/door chase tests when Studio is released. No live Studio calls while asset agent controls it.
