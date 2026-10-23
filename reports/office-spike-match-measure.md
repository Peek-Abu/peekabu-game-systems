# Office spike match: generator measure (seeds 1-20)

Measured at commit 0400ed1c in Studio Play with `OfficeLayoutMeasureHarness` (seeds 1-20). The numbers are defined as
follows:

- **Rooms:** kit rooms, reception and server included.
- **Area:** every room's floor except the bay's, hallways included.
- **Walk:** the longest walk from the bay to any room, in studs and in seconds at walk speed 16.
- **Hide:** desks plus closets.
- **Gloom:** the site's total Gloom from the first spawn roll that meets the biggest crew's contract.

## Per seed

| Seed | Rooms (pods) | Area | Walk (studs) | Walk (s) | Hide | Gloom |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 11 (4) | 23,354 | 335 | 20.9 | 36 | 1,205 |
| 2 | 8 (2) | 17,160 | 335 | 20.9 | 17 | 1,025 |
| 3 | 9 (3) | 16,632 | 325 | 20.3 | 32 | 1,100 |
| 4 | 11 (5) | 24,304 | 325 | 20.3 | 49 | 1,335 |
| 5 | 12 (2) | 20,954 | 323 | 20.2 | 34 | 1,210 |
| 6 | 8 (3) | 19,472 | 384 | 24.0 | 32 | 1,078 |
| 7 | 11 (3) | 22,622 | 325 | 20.3 | 31 | 1,360 |
| 8 | 6 (2) | 18,250 | 323 | 20.2 | 19 | 1,010 |
| 9 | 7 (1) | 17,676 | 394 | 24.6 | 16 | 993 |
| 10 | 9 (6) | 26,350 | 323 | 20.2 | 64 | 1,030 |
| 11 | 10 (3) | 24,374 | 335 | 20.9 | 30 | 1,025 |
| 12 | 8 (2) | 20,108 | 396 | 24.8 | 29 | 1,000 |
| 13 | 11 (5) | 26,622 | 479 | 29.9 | 53 | 1,115 |
| 14 | 7 (1) | 19,388 | 381 | 23.8 | 17 | 1,140 |
| 15 | 9 (3) | 23,004 | 335 | 20.9 | 35 | 1,213 |
| 16 | 7 (4) | 18,042 | 323 | 20.2 | 37 | 1,025 |
| 17 | 10 (2) | 22,214 | 383 | 23.9 | 26 | 1,203 |
| 18 | 10 (2) | 17,940 | 385 | 24.1 | 24 | 1,040 |
| 19 | 8 (3) | 18,192 | 381 | 23.8 | 33 | 1,155 |
| 20 | 6 (2) | 20,278 | 323 | 20.2 | 17 | 1,485 |

All 20 seeds generated with no errors.

## Means against the targets

| Measure | Mean | Min to max | Target | Result |
|---|---:|---:|---|---|
| Floor area | 20,847 | 16,632 to 26,622 | 24,300 ±30 % (17,010 to 31,590) | OK (the mean is in the band; see the note) |
| Longest walk | 355 studs (22.2 s) | 323 to 479 (29.9 s) | at most 640 (40 s) on every seed | OK |
| Hide spots | 31.6 | 16 to 64 | at least 8 on every seed | OK |
| Kit rooms | 8.9 | 6 to 12 | KIT_ROOMS 6 to 12 | OK |
| Pods share | 33 % | | at least 25 % | OK |
| Gloom | 1,137 | 993 to 1,485 | the contract is met on every seed | OK |

Note on area: the band applies to the mean. One seed is below 17,010 (seed 3 at 16,632). The other seeds lie between
17,160 and 26,622.

Compared with the old map (stage 1 measure, seeds 1-20): the area mean was 24,256 with 14-20 rooms. The building is
now about 14 % smaller in floor area (20,847), with about half as many rooms (6-12, mean 8.9). The rooms are bigger,
and the halls are wider (14 and 10 wide).

Full suite: 4,275 passed, 0 failed. Traversal harness, seeds 1-20, every door closed: 927 paths, 0 failures.

## Final constants

`OfficeConstants`:

- `CORRIDOR_WIDE` 14, `CORRIDOR_NARROW` 10, `NARROW_CHANCE` 0.35.
- `JUNCTION_MIN` 20 (new), `ATRIUM_SIZE` 26.
- `LATTICE_COLS` 4, `LATTICE_ROWS` 3, `LATTICE_STEP_X` 84, `LATTICE_STEP_Z` 76, `LATTICE_JITTER` 3.
- `DOCK_NODE` (3, 1), `LOBBY_NODE` (1, 3).
- `CORRIDOR_EDGES` 8-11, `LOOPS` 1-2.
- `KIT_ROOMS` 6-12, `ROOM_MARGIN` 44, `ROOM_STEP` 4.
- `KIT_WEIGHTS`: pods 60, conference 18, storage 12, breakout 10.
- `PERIMETER_CONFERENCE_BOOST` 1.5, `GENERATE_ATTEMPTS` 8.

`OfficeLayoutGenerationUtils`:

- `SLOT_DEPTH` is now derived: the mean depth of the drawn kits in `OfficeKitRegistry`, 26 today.
- The segments are lined round-robin: each round, every segment gets one room, alternating between its sides. This
  spreads the rooms out, so the clustered dust keeps a clean room between dirty rooms.
