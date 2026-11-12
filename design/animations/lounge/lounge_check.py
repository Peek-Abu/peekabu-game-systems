"""Numeric gates for the lounge clips (GATES.md G1-G5). python -I lounge_check.py <slouch|breath|nod|arms|wave|all>
Prints PASS/FAIL lines with the measured numbers; exits 1 on any FAIL."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lounge_clips as L  # noqa: E402

FPS = 30
fails = []


def report(ok, text):
    print(("PASS " if ok else "FAIL ") + text)
    if not ok:
        fails.append(text)


def keys(frames):
    return sorted(frames)


def at(frames, t, joint):
    """Linear stand-in for the curve between keys (enough for amplitudes and frozen runs)."""
    ts = [k for k in keys(frames) if joint in frames[k]]
    if t <= ts[0]:
        return frames[ts[0]][joint]
    for a, b in zip(ts, ts[1:]):
        if a <= t <= b:
            u = (t - a) / (b - a)
            # CubicV2 InOut-ish smoothstep, so a key is a stop only where the curve really stops
            u = u * u * (3 - 2 * u)
            return [x + (y - x) * u for x, y in zip(frames[a][joint], frames[b][joint])]
    return frames[ts[-1]][joint]


def slouch():
    rest = L.DOZE[0]
    report(rest["Waist"][0] >= 26, f"G1 waist lean {rest['Waist'][0]} >= 26")
    report(L.REST_HEAD[0] <= -35, f"G1 head hangs {L.REST_HEAD[0]} deg (world) <= -35")
    report(abs(rest["Neck"][2]) >= 12, f"G1 neck side tilt {rest['Neck'][2]} >= 12")


def breath():
    d = L.DOZE
    peaks = [t for t in keys(d) if t < 8 and d[t]["Waist"][0] > L.REST_WAIST + 1]
    period = (peaks[1] - peaks[0]) if len(peaks) > 1 else 0
    report(period >= 3.5, f"G2 breath period {period:.2f}s >= 3.5")
    amp = max(d[t]["Waist"][0] for t in peaks) - L.REST_WAIST
    report(1.5 <= amp <= 4, f"G2 chest amplitude {amp:.2f} in 1.5-4")
    end = keys(d)[-1]
    run = longest = 0
    prev = None
    for i in range(int(end * FPS) + 1):
        pose = [v for j in ("Waist", "Neck", "RightShoulder") for v in at(d, i / FPS, j)]
        if prev is not None and max(abs(a - b) for a, b in zip(pose, prev)) < 0.01:
            run += 1
            longest = max(longest, run)
        else:
            run = 0
        prev = pose
    report(longest < 15, f"G2 longest frozen run {longest} frames < 15")


def nod():
    d = L.DOZE
    ts = keys(d)
    rest = d[0]["Neck"][0]
    low_t = min(ts, key=lambda t: d[t]["Neck"][0])
    sink = rest - d[low_t]["Neck"][0]
    report(sink >= 18, f"G3 head sinks {sink:.1f} deg past rest >= 18")
    start = max(t for t in ts if t < low_t and abs(d[t]["Neck"][0] - rest) < 1)
    report(low_t - start >= 0.8, f"G3 sink takes {low_t - start:.2f}s >= 0.8")
    before = max(t for t in ts if t < low_t)
    report(d[before].get("ease") == "in", f"G3 last drop segment eases {d[before].get('ease')} == in")
    catch_t = min(t for t in ts if t > low_t)
    lift = d[catch_t]["Neck"][0] - d[low_t]["Neck"][0]
    report(lift >= 35 and catch_t - low_t <= 0.25 + 1e-6 and d[low_t].get("ease") == "out",
           f"G3 catch lifts {lift:.1f} deg in {catch_t - low_t:.2f}s (out)")


def arms():
    r = L.DOZE[0]
    pairs = [(r["RightShoulder"], r["LeftShoulder"]), (r["RightElbow"], r["LeftElbow"])]
    diff = max(max(abs(a - b) for a, b in zip(rr, L.mirror(ll))) for rr, ll in pairs)
    report(diff >= 15, f"G4 L/R arm difference {diff:.1f} deg >= 15")


def wave():
    s = L.SEATED
    ts = keys(s)
    startle = [t for t in ts if t <= 0.2 + 1e-6]
    up = max(s[t]["Neck"][0] for t in startle) - s[0]["Neck"][0]
    report(up >= 40, f"G5 head up {up:.1f} deg within 0.2 s")
    shrug = max(s[t]["RightShoulder"][2] for t in startle) - s[0]["RightShoulder"][2]
    report(shrug >= 10, f"G5 shoulder shrug {shrug:.1f} deg")
    # the wave = elbow reversals while the arm is raised (shoulder Z above -15); repeated values (lag keys) dropped
    elbows = []
    for t in ts:
        if s[t]["RightShoulder"][2] > -15 and (not elbows or elbows[-1][1] != s[t]["RightElbow"][2]):
            elbows.append((t, s[t]["RightElbow"][2]))
    turns = [t for (pt, pv), (t, v), (nt, nv) in zip(elbows, elbows[1:], elbows[2:]) if (v - pv) * (nv - v) < 0]
    first = turns[0] if turns else 0
    report(first >= 0.13 + 0.5, f"G5 wave starts at {first:.2f}s, >= 0.5 s after the startle")
    gaps = [b - a for a, b in zip(turns, turns[1:])]
    report(len(turns) >= 3 and min(gaps) >= 0.3 - 1e-6,
           f"G5 {len(turns)} elbow swings, shortest {min(gaps) if gaps else 0:.2f}s >= 0.3")
    end = s[ts[-1]]
    rest = L.DOZE[0]
    same = all(math.isclose(a, b) for j in ("Waist", "Neck", "RightShoulder", "RightElbow", "LeftShoulder")
               for a, b in zip(end[j], rest[j]))
    report(same, "G5 ends at the doze rest pose")


CHECKS = {"slouch": slouch, "breath": breath, "nod": nod, "arms": arms, "wave": wave}
for name in (CHECKS if sys.argv[1] == "all" else [sys.argv[1]]):
    CHECKS[name]()
sys.exit(1 if fails else 0)
