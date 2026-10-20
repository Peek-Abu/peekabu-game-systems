# Odd Hours: desk and table hiding that looks right to others

Status: design, waiting for owner approval. Branch `game/cleanup-crew` (the MVP, 296bfe3, plus the batch-1 UI fixes and the places split).

## Why

Hiding under a desk looks broken to other players. The owner's 2-player playtest and Claude's measurements on 2026-10-20 show three problems:
- The body clips through the desk, the chair and itself.
- The head, face plate and ears sink up to 1.06 studs into the floor.
- The character faces the desk's back panel, rear end out.

A first fix in build week 1 (HideFitSystem, HideGlideSystem, kept on `game/week1-attempt`) added a lot of fitting math and still clipped in play. It was rolled back.

What the measurements found as the root cause:
1. The MVP gives every character one fixed tuck pose (`HideConstants.TUCK_POSE`), tuned on one character.
2. It places the root at standing height (`HideSpotUtils.frames`) with one hard-coded height correction.
3. It never compares the body with the space under the furniture.
4. **The furniture is too small for the characters.** In-game Pippa is drawn 1.25× the size of her character asset, and no seated or folded pose of her fits under today's desk.

## What the owner wants

**The look:**
- The character sits on the floor under the desk or table, back against the furniture, knees hugged to the chest.
- The face looks out of the open side, toward the room and toward whoever is watching. It never faces the floor or the desk.
- Nothing clips: not walls, not the furniture (desk, table, chair), not the character's own parts. Nothing floats.
- It looks right to **other players**. That is the bar, not the hider's own view.

**Generic:**
- One pose for every employee, with no custom animation per character.
- Characters stay full size: **the furniture grows to fit the characters**. Owner's reasoning: the Manager is 9.7 studs tall, so bigger furniture looks natural in this world.

**Hide styles later:**
- How a character hides may become a paid cosmetic.
- The default pose is the first of several swappable styles, stored as data so a new style is a data change, not new code.

## Decisions

### 1. The pose is the owner's, as data

The owner posed it in the Animation Editor; Claude adjusted the ears. It is saved as `HideHug2` in `Workspace.HidePoseStudio.PippaHidePose.AnimSaves` in the hub place (Odd Hours, 113354563835664).

The game code cannot read animations stored in the place (code-only Rojo project), so the values are copied here. Each entry is a joint Transform (the `Pose.CFrame` in the joint's C0 space), keyed by the joint's **Part1** name. Angles are `CFrame.fromEulerAnglesXYZ` in degrees; positions are in studs on the **asset-size** Pippa.

```
Head          rot (25, 0, 0)
LeftEar       rot (120, 0, 10)        RightEar       rot (120, 0, -10)
UpperTorso    rot (-54.99, 0, 0)
LowerTorso    rot (10, 0, 0)          pos (0.237, -0.658, -0.332)   -- the Root joint
LeftUpperLeg  rot (105.40, 4.08, -11.29)
RightUpperLeg rot (105.40, -4.08, 11.29)
LeftLowerLeg  rot (-145, 0, 0)        RightLowerLeg  rot (-145, 0, 0)
LeftFoot      rot (35, 0, 0)          RightFoot      rot (35, 0, 0)
LeftUpperArm  rot (0, -75, 25)        RightUpperArm  rot (0, 75, -25)
LeftLowerArm  rot (0, -45, 0)         RightLowerArm  rot (0, 45, 0)
```

**How the pose applies to any employee:**
- Rotations are scale-free.
- The Root translation is a placeholder from the Edit-mode test. The real placement comes from decision 2, not from this number.
- A joint the rig doesn't have (ears on an employee without ears) is skipped.
- The pose has to look the same on every client, the hider's and every watcher's.

### 2. Placement: on the floor, back to the furniture, centred, facing out

The placement is computed from the **posed body's real extents** and the spot's free space, not from standing height:
- the lowest point of the posed body rests on the floor;
- the back rests against the inside of the furniture's back (the desk's back panel), with a small gap;
- the body is centred across the free space;
- the body faces out of the open side (the spot's front, local −Z).

This replaces the standing-height frame and the fixed per-kind offsets in `HideConstants`.

**Break tables have no back panel.** The "back" is the far edge of the table, opposite the side the player entered from, which is the side the MVP already turns to (`HideSpotUtils.spotFrame`).

**Cabinets are out of scope.** Their stand-up behaviour stays as it is.

### 3. The furniture grows (a hard rule)

This rule is also in Claude's memory as `hide-furniture-sizing`. Every hideable piece must leave a free space underneath that fits the **largest employee, at in-game size, in this pose**, plus a small margin.

| Free space | Today's desk | In-game Pippa in the pose |
|---|---|---|
| Width | 3.08 | about 3.5 |
| Height | 2.77 | about 4.1 |
| Depth | 2.65 | about 4.2 |

So desks are roughly 1.5× today's size, with the desktop at about 4.5 studs.

**Scope:**
- **Now:** enlarge the current generated desks and break tables (and their chairs, so a chair still fits a desk) as a stand-in. The office map redo will replace them later under the same rule.
- **All of them:** every desk and break table of the same kind gets the new size, not only the tagged hiding spots, so players can read what's hideable.
- **Not:** walls, rooms and other furniture.

**Claude's calls on the knock-on effects** (to check while reading):
- **Chairs:** a chair stays fully outside the free space, pulled out in front of the open side, never pushed in. It must never overlap a hider.
- **Layout (owner's call):** keep it simple, since the map is being rebuilt anyway. If a bigger desk or table doesn't fit where it stands (walls, walkways, doors), remove it. No rearranging and no shrinking.

### 4. Vacuum and backpack

- **Vacuum in hand:** hiding with the vacuum in hand returns it to the backpack automatically, and it stays there.
- **Backpack:** it stays on. With the back against the furniture, Claude measured it inside the desk. Its dome sat about 0.1 studs too high for today's desk, and the bigger furniture covers that.
- **Gear:** the vest, lanyard and ID card stay on. A 2-player check on 2026-10-20 showed they stay on the body for watchers.

### 5. Entry, exit and the rules around hiding

These stay as the MVP has them:
- the server anchors the root and slides it into the spot (`TUCK_SECONDS`);
- the pose blends in on every client;
- leaving reverses it;
- prompts, camping and cooldowns are unchanged.

## Not in scope (non-goals)

- Hide styles beyond the default, a store or any monetization. Only the seam: the pose is swappable data.
- The office map redo and its art direction.
- Cabinet hiding.
- Smoothing other players' movement into and out of spots (the week-1 HideGlideSystem idea). A separate item if the owner still sees stepping after this.

## What would make this a failure even if specs pass (anti-goals)

- Any clipping or floating visible **from a second player's screen** in real play.
- The character facing the floor or the furniture, or hidden from view entirely.
- Shrinking characters.
- Per-character animations.
- Calling it done on probes or specs alone. Done is the owner's 2-player check: hide under a desk and under a break table, watched from the other client.

## Left to the builder

- How the pose is stored in code (a constants table in the Hide feature is the obvious home) and how a style is chosen (one default style id is enough for now).
- How the posed body's extents are worked out: forward kinematics from the joints and part sizes, or a measurement on the client. It is per character, not per frame.
- Whether placement is computed on the server, on clients, or both. The server already owns the anchored root, so computing it there keeps every client in agreement.
- Exact margins, and how the furniture constants and kit pieces scale, as long as the free-space rule holds.
- What to remove from the MVP tuck code (`TUCK_POSE`, the per-kind offsets) once it is replaced.

## Verification

1. Specs for:
   - the pose data;
   - the placement maths: floor contact, back gap, centring, facing;
   - the free-space rule, checked against the furniture constants.
2. Owner play-check in a 2-player Local Server, watched from the second client, with the vacuum both in hand and on the back:
   - hide under a desk and under a break table;
   - check: face out, on the floor, nothing through anything.
