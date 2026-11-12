"""clipkit: author kit-rig clips in Python and write them straight to .rbxmx (no Studio round trip).

The same conventions as the clerk/coach CommandBar builders: joint turns are degrees about X, Y, Z in CFrame.Angles
order (R = Rx * Ry * Rz) over the rest pose, `Root` drops the LowerTorso (studs) and the legs are solved for it, keys
ease InOut unless a key says "in"/"out"/"const", unkeyed poses get Weight 0. A clip module defines FRAMES
({time: {joint: degrees, ...}}) and calls `write(name, frames, loop, markers, path)`.

`checksum_free(path)` is the order-free check: (pose count, sum over keyed poses of rounded components + style*3 +
dir*7 + weight*11), the same number OrderFreeChecksum.CommandBar.luau computes from a KeyframeSequence in Studio.
"""

import math
import re

THIGH, SHIN = 0.31, 0.373
HIP_SCALE = 0.93

PARENT = {
    "LowerTorso": "HumanoidRootPart", "UpperTorso": "LowerTorso", "Head": "UpperTorso",
    "RightUpperArm": "UpperTorso", "RightLowerArm": "RightUpperArm", "RightHand": "RightLowerArm",
    "LeftUpperArm": "UpperTorso", "LeftLowerArm": "LeftUpperArm", "LeftHand": "LeftLowerArm",
    "RightUpperLeg": "LowerTorso", "RightLowerLeg": "RightUpperLeg", "RightFoot": "RightLowerLeg",
    "LeftUpperLeg": "LowerTorso", "LeftLowerLeg": "LeftUpperLeg", "LeftFoot": "LeftLowerLeg",
}
JOINT_PART = {
    "Waist": "UpperTorso", "Neck": "Head", "RightShoulder": "RightUpperArm", "RightElbow": "RightLowerArm",
    "RightWrist": "RightHand", "LeftShoulder": "LeftUpperArm", "LeftElbow": "LeftLowerArm", "LeftWrist": "LeftHand",
    "RightHip": "RightUpperLeg", "RightKnee": "RightLowerLeg", "RightAnkle": "RightFoot",
    "LeftHip": "LeftUpperLeg", "LeftKnee": "LeftLowerLeg", "LeftAnkle": "LeftFoot",
}
# (EasingStyle, EasingDirection) token values: CubicV2 = 5, Constant = 1; In = 0, Out = 1, InOut = 2.
EASE = {"inout": (5, 2), "in": (5, 0), "out": (5, 1), "const": (1, 0)}
SKIP = {"ease", "easeJ", "armOnly"}


def f(n):
    return n / 30


def mirror(d):
    return [d[0], -d[1], -d[2]]


def legs(drop):
    if drop <= 0:
        return 0.0, 0.0
    reach = THIGH + SHIN - drop
    knee = math.acos(max(-1, min(1, (THIGH ** 2 + SHIN ** 2 - reach ** 2) / (2 * THIGH * SHIN))))
    hip = math.acos(max(-1, min(1, (THIGH ** 2 + reach ** 2 - SHIN ** 2) / (2 * THIGH * reach))))
    return math.degrees(hip) * HIP_SCALE, 180 - math.degrees(knee)


def with_legs(t):
    if t.get("Root") is not None:
        hip, knee = legs(-t["Root"])
        for side in ("Right", "Left"):
            t[side + "Hip"] = [-hip, 0, 0]
            t[side + "Knee"] = [knee, 0, 0]
            t[side + "Ankle"] = [hip - knee, 0, 0]
    return t


def angles(d):
    x, y, z = (math.radians(v) for v in d)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

    r = mul(mul(rx, ry), rz)
    return [0.0, 0.0, 0.0] + [r[i][j] for i in range(3) for j in range(3)]


def _pose_tree(frame):
    poses, keyed = {}, {}

    def at(part):
        if part not in poses:
            poses[part] = {"name": part, "cf": [0.0] * 3 + [1, 0, 0, 0, 1, 0, 0, 0, 1], "style": 0, "dir": 0,
                           "weight": 1, "children": []}
            parent = PARENT.get(part)
            if parent:
                at(parent)["children"].append(poses[part])
        return poses[part]

    at("HumanoidRootPart")
    for joint, d in frame.items():
        if joint in SKIP:
            continue
        key = (frame.get("easeJ") or {}).get(joint) or frame.get("ease") or "inout"
        if joint == "Root":
            p = at("LowerTorso")
            p["cf"] = [0.0, float(d), 0.0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
            part = "LowerTorso"
        elif joint == "Pelvis":
            # [dy, dz, pitch]: the pelvis moved up dy and back dz (-dz slides it forward) and tipped by pitch (deg, X)
            p = at("LowerTorso")
            p["cf"] = [0.0, float(d[0]), float(d[1])] + angles([d[2], 0, 0])[3:]
            part = "LowerTorso"
        else:
            part = JOINT_PART[joint]
            p = at(part)
            p["cf"] = angles(d)
        p["style"], p["dir"] = EASE[key]
        keyed[part] = True
    for part, p in poses.items():
        if not keyed.get(part):
            p["weight"] = 0
            p["style"], p["dir"] = 0, 0
    return poses["HumanoidRootPart"]


def write(name, frames, loop, markers, path, priority=2):
    from ks_json_to_rbxmx import pose_xml, ref
    from xml.sax.saxutils import escape

    out = ['<roblox version="4">', f'<Item class="KeyframeSequence" referent="{ref()}"><Properties>',
           f'<string name="Name">{escape(name)}</string>',
           f'<bool name="Loop">{"true" if loop else "false"}</bool>',
           f'<token name="Priority">{priority}</token>', "</Properties>"]
    for t in sorted(frames):
        out.append(f'<Item class="Keyframe" referent="{ref()}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{float(t)!r}</float></Properties>')
        pose_xml(_pose_tree(frames[t]), out)
        for m in (markers or {}).get(t, []):
            out.append(f'<Item class="KeyframeMarker" referent="{ref()}"><Properties>'
                       f'<string name="Name">{escape(m)}</string><string name="Value"></string></Properties></Item>')
        out.append("</Item>")
    out.append("</Item></roblox>")
    open(path, "w", encoding="utf-8").write("".join(out))
    return checksum_free(path)


def checksum_free(path):
    """(pose count, order-free sum) over every Pose in the file."""
    xml = open(path, encoding="utf-8").read()
    count, total = 0, 0.0
    for item in re.finditer(r'<Item class="Pose".*?<Properties>(.*?)</Properties>', xml, re.S):
        props = item.group(1)
        comps = [float(v) for v in re.findall(r"<(?:X|Y|Z|R\d\d)>([^<]+)<", props)]
        style = int(re.search(r'name="EasingStyle">(\d+)<', props).group(1))
        direction = int(re.search(r'name="EasingDirection">(\d+)<', props).group(1))
        weight = float(re.search(r'name="Weight">([^<]+)<', props).group(1))
        total += sum(round(v, 3) for v in comps) + style * 3 + direction * 7 + weight * 11
        count += 1
    return count, round(total, 2)


def luau_builder(clips, folder):
    """Luau that builds `clips` ({name: (frames, loop, markers)}) as KeyframeSequences in
    ReplicatedStorage.<folder>, with exactly clipkit's poses (for Studio previews and the order-free check)."""
    def num(v):
        return f"{v:.6g}"

    def frame_src(frame):
        parts = []
        for joint, d in frame.items():
            if joint in ("ease",):
                parts.append(f'ease="{d}"')
            elif joint == "easeJ":
                parts.append("easeJ={" + ",".join(f'{k}="{v}"' for k, v in d.items()) + "}")
            elif joint == "armOnly":
                continue
            elif joint == "Root":
                parts.append(f"Root={num(d)}")
            elif joint == "Pelvis":
                parts.append(f"Pelvis={{{','.join(num(x) for x in d)}}}")
            else:
                parts.append(f"{joint}={{{','.join(num(x) for x in d)}}}")
        return "{" + ",".join(parts) + "}"

    lines = ["local CLIPS = {"]
    for name, (frames, loop, markers) in clips.items():
        fr = ",".join(f"[{num(t)}]={frame_src(frames[t])}" for t in sorted(frames))
        mk = ",".join(f'[{num(t)}]={{{",".join(chr(34) + m + chr(34) for m in ms)}}}' for t, ms in (markers or {}).items())
        lines.append(f'{name}={{loop={"true" if loop else "false"},markers={{{mk}}},frames={{{fr}}}}},')
    lines.append("}")
    lines.append('''local PARENT = { LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso", RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm", LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm", RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg", LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg" }
local JOINT_PART = { Waist = "UpperTorso", Neck = "Head", RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", RightWrist = "RightHand", LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand", RightHip = "RightUpperLeg", RightKnee = "RightLowerLeg", RightAnkle = "RightFoot", LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg", LeftAnkle = "LeftFoot" }
local EASE = { inout = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.InOut }, ["in"] = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.In }, out = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.Out }, const = { Enum.PoseEasingStyle.Constant, Enum.PoseEasingDirection.In } }
local RS = game:GetService("ReplicatedStorage")
local old = RS:FindFirstChild("''' + folder + '''") if old then old:Destroy() end
local dest = Instance.new("Folder") dest.Name = "''' + folder + '''"
local report = {}
for name, clip in CLIPS do
	local ks = Instance.new("KeyframeSequence") ks.Name = name ks.Loop = clip.loop ks.Priority = Enum.AnimationPriority.Action
	local times = {} for t in clip.frames do table.insert(times, t) end table.sort(times)
	for _, t in times do
		local frame = clip.frames[t] local kf = Instance.new("Keyframe") kf.Time = t local poses, keyed = {}, {}
		local function at(part) if poses[part] then return poses[part] end local p = Instance.new("Pose") p.Name = part p.Weight = 1 local parent = PARENT[part] p.Parent = if parent then at(parent) else kf poses[part] = p return p end
		at("HumanoidRootPart")
		for joint, d in frame do
			if joint == "ease" or joint == "easeJ" then continue end
			local key = (frame.easeJ and frame.easeJ[joint]) or frame.ease or "inout"
			local p
			if joint == "Root" then p = at("LowerTorso") p.CFrame = CFrame.new(0, d, 0) keyed.LowerTorso = true
			elseif joint == "Pelvis" then p = at("LowerTorso") p.CFrame = CFrame.new(0, d[1], d[2]) * CFrame.Angles(math.rad(d[3]), 0, 0) keyed.LowerTorso = true
			else p = at(JOINT_PART[joint]) p.CFrame = CFrame.Angles(math.rad(d[1]), math.rad(d[2]), math.rad(d[3])) keyed[JOINT_PART[joint]] = true end
			p.EasingStyle = EASE[key][1] p.EasingDirection = EASE[key][2]
		end
		for part, p in poses do if not keyed[part] then p.Weight = 0 p.EasingStyle = Enum.PoseEasingStyle.Linear p.EasingDirection = Enum.PoseEasingDirection.In end end
		for _, m in clip.markers[t] or {} do local km = Instance.new("KeyframeMarker") km.Name = m kf:AddMarker(km) end
		kf.Parent = ks
	end
	local count, total = 0, 0
	for _, p in ks:GetDescendants() do if p:IsA("Pose") then count += 1 for _, v in { p.CFrame:GetComponents() } do total += math.round(v * 1000) / 1000 end total += p.EasingStyle.Value * 3 + p.EasingDirection.Value * 7 + p.Weight * 11 end end
	table.insert(report, string.format("%s: %d poses, %.2f", name, count, total))
	ks.Parent = dest
end
dest.Parent = RS
table.sort(report)
return table.concat(report, "\n")''')
    return "\n".join(lines)
