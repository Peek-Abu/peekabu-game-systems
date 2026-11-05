# Podium banner: cut, and its anomaly moves to a leaning lamp post (design)

Status: **banner cut; leaning lamp built** (owner yes, 2026-11-04). Steps 1-4 done (see Result); the owner's real-play look is still to do.

Backlog item: "The 'TOGETHER WE THRIVE' banner is off-style ... keeping its default and upside-down states."

## What happened

- **Today:** the `banner` anomaly slot is on the podium front: `OfficeExterior/AnomalySlots/AnomalySlot_banner`,
  50 x 5.5 studs. It holds `BannerCloth` (navy Fabric, a GothamBlack "TOGETHER WE THRIVE" SurfaceGui), a `BannerRod`
  and two `BannerBracket`s. `OfficeAnomalySystem` turns `BannerCloth` 180° about its forward axis on runs that roll
  the anomaly.
- **Round 1 (rejected):** three redraws in the crew's own UI style (`design/production-art/podium-banner/`). The owner
  rejected all of them: the sparkle stars look AI-made and so does the font. The owner also asked why the banner
  exists at all.
- **Why it existed:** only as one of the 7 exterior anomalies (stage 4), a quiet "something is off tonight" clue. The
  building is the client's (Harlow & Finch), so a motivational banner there never belonged to our crew, and drawing it
  in our UI style made that worse.
- **Decision (owner, 2026-11-04):** **cut the banner.** Move the clue to something else outside: the cheapest one that
  reads best.

## The replacement: a leaning lamp post (recommended)

One of the sodium poles along the walk from the truck to the dock stands straight on a normal run. On a run that rolls
the anomaly, it **leans about 15°**, as if something bumped it in the night. Its lamp stays lit, so its pool of light
lies off-centre on the asphalt.

**Why this one over a car parked backwards:**

| | Leaning lamp post | Car parked backwards |
|---|---|---|
| Who sees it | everyone: it is on the 12.5-second walk every crew takes, twice per trip | only crews who take the lobby door (the west car park) |
| How it reads | a tall shape against the sky, plus the light pool moving on the ground: plain at a glance | a subtle difference among similar cars: easy to miss |
| Cost | no new art (an existing pole); one turn of its upper parts about the base, the same code pattern as the banner's | the blockout cars get replaced by the set dressing anyway, so the slot would be rebuilt twice |

**Details:**
- The pole leans **away** from the walk, so its head never hangs over players.
- The concrete base stays put; the shaft, arm, head, lens and light anchor turn about the shaft's lower end.
- The light (its own invisible anchor part in the slot) moves with it.
- Reset restores the captured CFrames, as for the banner.

## Build plan

| Step | What | Who |
|---|---|---|
| 1 | **Code, spec first.** The id `banner` becomes `leaningLamp` in `OfficeAnomalyConstants` (`AnomalyId`, `IDS`), with a `LEAN_DEGREES = 15` tuning value there. In `OfficeAnomalySystem`, the `banner` branch becomes `leaningLamp`: it turns every part in the slot except `PoleBase` by `LEAN_DEGREES` about the shaft's lower end, toward the slot model's `LeanDirection` attribute (away from the walk). Update the specs that name the id: `OfficeAnomalySystem.spec`, `OfficeAnomalyUtils.spec`, `AnomalyServer.spec`, `OfficeServiceServer.spec`. | code session |
| 2 | **Builder script.** In `BuildExterior.CommandBar.luau`, remove the banner block. Wrap the middle walk pole (z -160) in `AnomalySlot_leaningLamp` (tagged `OfficeAnomalySlot`, `AnomalyId = "leaningLamp"`, `LeanDirection = (-1, 0, 0)`). Its parts keep their names: `PoleBase`, `Pole`, `PoleArm`, `PoleHead`, `PoleLens`, `LightAnchor`. Update the exterior README's slot table. | code session |
| 3 | **The place.** In the Shift place only, in Edit: delete `AnomalySlot_banner`, and apply step 2 to the live pole. One Studio session, after the coordinator frees Studio; the lobby place has no exterior. | Studio session (Claude via Studio MCP) |
| 4 | **Check.** Force the anomaly with the Cmdr `anomaly` command, capture both states, run the Office specs in Studio, and do a real-play walk with a second client. | Studio session, then the owner |

New modules: none. No upload.

## Question for the owner

1. **Rules:** replace the banner clue with a **sodium lamp post on the walk that leans about 15°** on some runs?
   (No: the car parked backwards in the west car park.)

## Result (2026-11-04)

- Steps 1-3 are done. In the Shift place, `AnomalySlot_banner` is deleted. The walk pole at (1142, -160) is now
  `OfficeExterior/SiteLights/AnomalySlot_leaningLamp`, made by a targeted edit, not a full rebuild. The owner must
  save the place.
- **Specs** (Studio, with the changes synced): 5443 passed, 1 failed. The failure is the known old
  `RankServiceServer.spec:178`, not from this change. All Office specs pass.
- **Live check:** the server forced the anomaly through `OfficeServiceServer:forceAnomalies`, the same path the Cmdr
  `anomaly` command uses. On the client the pole leaned 15.00° toward -X, its base stayed put, and its head moved
  about 5.7 studs away from the walk. Clearing the anomaly stood it upright again (0.00°).
- **Captures:** `design/production-art/map-kits/odd-hours-b1/exterior/captures/s5_leaningLamp_on.jpg` and `_off.jpg`.
- **Still open:** the owner's own look in real play. A second-client check was not run.
