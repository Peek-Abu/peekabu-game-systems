"""Pose set for the outfit gates with Prickles' LIVE clips after the A3 overwrite (2026-11-16): one deform matrix per
body part per keyframe, as ../showstopper_tails/gait_all.py, from explicit rbxmx files.
python pose_set_a3.py -> pose_a3.json"""
import json, sys, xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np
C = Path('E:/Projects/peekabu-game-systems/characters')
F = C / 'prickles/idle-arms-2026-11-16/clips/final'
CLIPS = {'Idle': F / 'idle_A3.rbxmx', 'CrouchIdle': F / 'crouchidle_A3.rbxmx', 'Walk': C / 'prickles/anim/Prickles_Walk.rbxmx',
         'Run': C / 'prickles/anim/Prickles_Run.rbxmx', 'CrouchWalk': C / 'prickles/anim/Prickles_CrouchWalk.rbxmx',
         'Fidget': F / 'fidget_A3.rbxmx', 'Select': F / 'select_A3.rbxmx', 'Hire': F / 'hire_A3.rbxmx', 'Emote': F / 'emote_A3.rbxmx',
         'PlantEnter': F / 'plantenter_A3.rbxmx', 'PlantExit': F / 'plantexit_A3.rbxmx'}
M = np.array([[-1., 0, 0], [0, 0, 1], [0, 1, 0]]); M4 = np.eye(4); M4[:3, :3] = M
PARENT = {'LowerTorso': None, 'UpperTorso': 'LowerTorso', 'Head': 'UpperTorso'}
for side in ['Left', 'Right']:
    for part, parent in [('UpperArm', 'UpperTorso'), ('LowerArm', side + 'UpperArm'), ('Hand', side + 'LowerArm'),
                         ('UpperLeg', 'LowerTorso'), ('LowerLeg', side + 'UpperLeg'), ('Foot', side + 'LowerLeg')]:
        PARENT[side + part] = parent
rig = json.loads((C / 'prickles/v4/Prickles_rig.json').read_text())
piv = {j['part1']: np.array([-j['pos'][0], j['pos'][1], -j['pos'][2]]) for j in rig['joints'].values()}
out = {}
for role, path in CLIPS.items():
    keys = sorted([e for e in ET.parse(path).getroot().iter('Item') if e.get('class') == 'Keyframe'],
                  key=lambda e: float(e.find('./Properties/float[@name="Time"]').text))
    samples = []
    for i, key in enumerate(keys):
        local = {}
        for e in key.iter('Item'):
            if e.get('class') != 'Pose': continue
            name = e.find('./Properties/string[@name="Name"]').text; cf = e.find('./Properties/CoordinateFrame')
            if name not in PARENT or cf is None: continue
            t = np.eye(4); t[:3, 3] = [float(cf.find(a).text) for a in 'XYZ']
            t[:3, :3] = [[float(cf.find(f'R{a}{b}').text) for b in range(3)] for a in range(3)]; local[name] = t
        native = {}; frame = {}
        for part, parent in PARENT.items():
            a = np.eye(4); a[:3, 3] = piv[part]; b = np.eye(4); b[:3, 3] = -piv[part]
            native[part] = (native[parent] if parent else np.eye(4)) @ a @ local.get(part, np.eye(4)) @ b
            frame[part] = (M4.T @ native[part] @ M4).tolist()
        samples.append({'frame': i, 'time': float(key.find('./Properties/float[@name="Time"]').text), 'skin': frame})
    out[role] = {'role': role, 'file': str(path), 'samples': samples}
    print(role, len(samples))
json.dump(out, open(Path(__file__).parent / 'pose_a3.json', 'w'))
