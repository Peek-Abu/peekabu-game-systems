# Gameplay repair verification — 2026-10-13

Final isolated Studio TestEZ: **2305 passed,0failed**. Full source Selene,StyLua,strict Luau-LSP src/tasks,module inventory,PRrules and400-code-line checks passed. No Wally regeneration during live Rojo.

Native evidence:
- Real recyclingBox pickup/drop into bed credited0→15 and consumed it. RubbishBag pickup/throw left15 unchanged in flight, then credited25 on landing and consumed it. Ordinary recycling retained same ID/art, anchored=true/noncolliding.
- Real imported-art map seed900356780:24workrooms,52total room/corridor/bay rectangles,54nonbay doorway paths allSuccess.
- Final10-stud doorports: seed4/minZ40paths,seed1/minX54,seed3/maxX36,seed2/maxZ44. **174/174 passed** with radius2,height8,no jumping,infinite safe-zone cost. Earlier7-stud actual aperture failed with radius2,passed radius1; widening fixed it without shrinking NPCs.
- Straight chase: initial24-stud gap,catch4.4678s,zero recurring>=.2s waypoint pauses under the measured fast-runner conditions.
- Corner chase seed108669707/work1:maxX entry→minZ exit,19.5speed at turn/exit,minimum post-acceleration chase19.4777,catch5.4728s. Raw samples:design/gameplay-repair-review/pursuit-controls.json.
- Opaque-wall control: visible target acquired; search lastSeen stayed1093,4,-32 through three different hidden positions.
- Client memo/cue visible in clear view,hidden by opaque wall. See manager-ui-clear.jpg and manager-ui-blocked.jpg. Both shells AlwaysOnTop=false.
- Desk search moved6drawer components,no overlay; filingCabinet3×5×3.5 bottomY1. Locker moved6door/decor components,door180degrees,no overlay; printer3×3×3 bottomY1.
- WaterJug/printer bottom2.376135349 matched counter worktop2.376135296. Tap bbox is separate from support height/collision. Mounted counter/shelf/board rear gap<.00006stud.
- Office floor topY1 versus preserved Baseplate topY0; backing below recessed carpet. Shelf collision enabled; chairs/small cargo noncolliding intentionally.
- Client blackout: light1.2→0→1.2 with enabled restoration; emitting panel Neon→darkPlastic→authoredNeon/color. Cancel/stop/destruction instance specs pass. Native comparison:16range/1.2brightness too dark at floor;30/2.4washed out;final22/.7readable. Final coverage regression passes. Balanced comparison displayed inline in chat; saved dark SDK shots are diagnostic, not approval evidence.

Scope and limits:
46artist models retained;calendar excluded. Added FrontAxis metadata on26furniture/cargo templates and support heights on counter/table; import organizer repeats them. No upload,publish,destructive art overwrite or official Figma MCP.

Corridor links are straight; winding routes turn through room junctions. Separate L/T corridor pieces, richer archetype furnishing/density/wayfinding and co-op quota/travel/scare balancing remain future work. Hollow furniture rigs still need final art/material finishing. Printer,recycling interior,static fish-tank replacement and dust-bag badge are queued in the remodel backlog. Vacuum hearing remains deferred by user request.

Remaining broad work: art/animations/audio; complete manual device/co-op loop; multiplayer manager tuning; onboarding;saved goals/uniform/rank presentation;public retention tests;cosmetic monetization;analytics and release/persistence/performance/travel QA. See remaining-work tracker.
