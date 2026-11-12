# Sleepy Cappy v2 gates (owner 11-11: "look sleepier")

Clips: SofaDoze_v2 (loop), SeatedWave_v2. Generic kit-rig clips, any employee.

- [x] G1 Slouch: doze waist lean >= 26 deg back, head drooped (neck X <= -45) and to the side (|neck Z| >= 12) at rest.
  CHECK: python -I lounge_check.py slouch
  EVIDENCE: lounge_check slouch: waist 30 + pelvis tip 14, head -40 deg world, tilt 14 (PASS x3)
- [x] G2 Slow breathing: breath period >= 3.5 s, chest amplitude 1.5-4 deg, never a frozen run >= 15 frames.
  CHECK: python -I lounge_check.py breath
  EVIDENCE: lounge_check breath: period 4.00 s, chest 2.5 deg, longest frozen run 6 f (PASS x3)
- [x] G3 Real nod-off: head sinks >= 18 deg past rest over >= 0.8 s, last segment eases In (accelerating drop), then
  the catch lifts it >= 35 deg in <= 0.25 s (Out).
  CHECK: python -I lounge_check.py nod
  EVIDENCE: lounge_check nod: sinks 22 deg over 1.83 s, last segment In, catch +61 deg in 0.20 s Out (PASS x4)
- [x] G4 Arms relaxed and not twins: L/R arm poses differ by >= 15 deg at rest.
  CHECK: python -I lounge_check.py arms
  EVIDENCE: lounge_check arms: L/R differ 25 deg (right hand on belly, left limp by hip; FK-solved on Cappy)
- [x] G5 Startle then lazy wave: head up >= 40 deg within 0.2 s of the start, shoulders shrug, wave starts >= 0.5 s
  after the startle, >= 3 elbow swings slower than the coach's (>= 0.3 s per swing), arm falls back, ends at the doze
  rest pose.
  CHECK: python -I lounge_check.py wave
  EVIDENCE: lounge_check wave: head up 63 deg in 0.13 s, shrug 20+, wave from 1.40 s, 4 swings >= 0.33 s, ends at rest (PASS x5)
- [x] G6 The rbxmx files equal the Studio build (order-free checksum).
  EVIDENCE: Studio build SofaDoze 154 poses 5760.92, SeatedWave 136 poses 4248.13 == python write()
- [x] G7 Seen on Cappy at the sofa spot in Edit (captures at every beat opened with Read): slouched on the cushion, no
  limb through the sofa, head drop and catch read, startle reads before the wave.
  EVIDENCE: Edit captures at 16 beats read with Read (hub-r4-sleepy-cappy-v2-look.jpg); on the cushion, head drop + catch + startle read
- [x] G8 Plays in Play on a client (real Animator, seated on the spot) without errors.
  EVIDENCE: Play client: doze 12.00 s looped, pelvis gap 0.000 after seat, head y range 0.57 over the loop, wave 4.20 s finished, no errors
- [x] G9 Look sheet + short video in the notes folder.
  EVIDENCE: notes folder: hub-r4-sleepy-cappy-v2-look.jpg, hub-r4-sleepy-cappy-v2.mp4 (304 KB)
