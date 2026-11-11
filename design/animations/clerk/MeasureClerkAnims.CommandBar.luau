--[[
	Measures the clerk clips (ReplicatedStorage.ClaudeClerkAnims, from BuildClerkAnims) against GATES.md on every
	employee, frame by frame at 30 fps. Run in the Studio command bar in Edit, after the build script: it poses a
	temporary copy of each employee far from the map with Animator:StepAnimations, measures, and deletes it.

	The stamp prop: a red base under a short handle, welded to RightHand with GRIP. GRIP is solved on the first employee
	so the stamp face points straight down at the contact (t = 0.86) and reused unchanged for the others (one generic
	grip, like the game will use). The parcel: placed so its top meets the stamp face at the contact, on a counter
	COUNTER studs above the feet; it hops from the "Lift" marker.
]]

local RS = game:GetService("ReplicatedStorage")
local KSP = game:GetService("KeyframeSequenceProvider")

local FPS = 30
local CONTACT, LIFT, PEAK = 0.86, 1.05, 0.7
local COUNTER = 0.85 -- the Supply Counter top above the clerk's feet (riser top 3.6, counter top 4.45)
local HOP = { APEX = 0.55, SECONDS = 0.34 }
local STAMP_SIZE = { base = Vector3.new(0.42, 0.14, 0.3), handle = Vector3.new(0.12, 0.3, 0.12) }

local EMPLOYEES = { "Cappy", "Pippa", "Prickles" }
local anims = RS:FindFirstChild("ClaudeClerkAnims")
assert(anims, "run BuildClerkAnims first")

local function angle(cf)
	local _, a = cf:ToAxisAngle()
	return math.deg(math.abs(a))
end

-- An ellipsoid test: < 1 inside the part's inscribed ellipsoid.
local function inside(part, p)
	local l = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return (l.X / h.X) ^ 2 + (l.Y / h.Y) ^ 2 + (l.Z / h.Z) ^ 2
end

local function corners(part)
	local h = part.Size / 2
	local out = { part.Position }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, (part.CFrame * CFrame.new(h.X * sx, h.Y * sy, h.Z * sz)).Position)
			end
		end
	end
	return out
end

local function setup(name, slot)
	local src = RS.Assets.CleanupCrew.Characters:FindFirstChild(name)
	local m = src:Clone()
	m.Name = "ClaudeClerkMeasure_" .. name
	local hrp = m:FindFirstChild("HumanoidRootPart")
	hrp.Anchored = true
	m:PivotTo(CFrame.new(400 + slot * 12, 300, 400))
	m.Parent = workspace
	local hum = m:FindFirstChildOfClass("Humanoid")
	local animator = m:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum or m:FindFirstChildOfClass("AnimationController")
	end
	return m, animator
end

local function load(animator, ks)
	local a = Instance.new("Animation")
	a.AnimationId = KSP:RegisterKeyframeSequence(ks)
	local track = animator:LoadAnimation(a)
	-- StepAnimations only applies a track that has started at a real speed; freeze it after one step
	track:Play(0, 1, 1)
	animator:StepAnimations(1 / 60)
	track:AdjustSpeed(0)
	return track
end

local function at(animator, track, t)
	track.TimePosition = math.min(t, track.Length - 1e-4)
	animator:StepAnimations(0.001)
end

local GRIP -- hand-space CFrame of the stamp's handle centre (solved once)
local function stamp(m)
	local hand = m.RightHand
	local base = Instance.new("Part")
	base.Name = "ClaudeStampBase"
	base.Size = STAMP_SIZE.base
	base.Color = Color3.fromRGB(214, 48, 49)
	local handle = Instance.new("Part")
	handle.Name = "ClaudeStampHandle"
	handle.Size = STAMP_SIZE.handle
	handle.Color = Color3.fromRGB(120, 78, 45)
	for _, p in { base, handle } do
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.Parent = m
	end
	local w1 = Instance.new("Weld")
	w1.Part0, w1.Part1, w1.C0 = hand, handle, GRIP
	w1.Parent = handle
	local w2 = Instance.new("Weld")
	w2.Part0, w2.Part1 = handle, base
	w2.C0 = CFrame.new(0, -(STAMP_SIZE.handle.Y + STAMP_SIZE.base.Y) / 2, 0)
	w2.Parent = base
	return base, handle
end

local report = {}
local function line(s)
	table.insert(report, s)
end

local function measure(name, slot)
	local m, animator = setup(name, slot)
	local stampKs, greetKs = anims.ClerkStamp, anims.ClerkGreet
	local track = load(animator, stampKs)
	local hrp = m.HumanoidRootPart

	if GRIP == nil then
		-- stamp face straight down at the contact, the handle centred a little below the hand's centre
		at(animator, track, CONTACT)
		local hand = m.RightHand.CFrame
		local look = hrp.CFrame.LookVector
		local want = CFrame.lookAt(hand.Position, hand.Position + look) * CFrame.new(0, -0.12, 0)
		GRIP = hand:Inverse() * want
		local rx, ry, rz = GRIP:ToEulerAnglesXYZ()
		line(
			string.format(
				"GRIP pos(%.3f,%.3f,%.3f) rot(%.1f,%.1f,%.1f)",
				GRIP.X,
				GRIP.Y,
				GRIP.Z,
				math.deg(rx),
				math.deg(ry),
				math.deg(rz)
			)
		)
	end
	local base, handle = stamp(m)

	local motors = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end

	local N = math.floor(stampKs:GetKeyframes()[#stampKs:GetKeyframes()].Time * FPS + 0.5)
	local frames = {}
	for i = 0, N do
		at(animator, track, i / FPS)
		local f = { t = i / FPS, tf = {} }
		for jn, mo in motors do
			f.tf[jn] = mo.Transform
		end
		f.pelvis = hrp.CFrame:PointToObjectSpace(m.LowerTorso.Position).Y
		f.rfoot, f.lfoot = m.RightFoot.Position, m.LeftFoot.Position
		f.face = (base.CFrame * CFrame.new(0, -base.Size.Y / 2, 0)).Position
		f.faceUp = base.CFrame.UpVector.Y
		f.handOff = (m.RightHand.CFrame:Inverse() * handle.CFrame).Position
		f.hands = { m.RightHand.Position, m.LeftHand.Position }
		local worst, who = 99, ""
		for _, body in { "Head", "UpperTorso" } do
			for _, p in corners(base) do
				local v = inside(m[body], p)
				if v < worst then
					worst, who = v, "stamp/" .. body
				end
			end
			for hi, p in f.hands do
				local v = inside(m[body], p)
				if v < worst then
					worst, who = v, (if hi == 1 then "RHand/" else "LHand/") .. body
				end
			end
		end
		f.clip, f.clipWho = worst, who
		f.rhLocal = hrp.CFrame:PointToObjectSpace(m.RightHand.Position)
		frames[i] = f
	end
	local function fi(t)
		return frames[math.floor(t * FPS + 0.5)]
	end
	local function speed(i, jn)
		if i == 0 then
			return 0
		end
		return angle(frames[i - 1].tf[jn]:Inverse() * frames[i].tf[jn])
	end

	-- G1 timing
	local CORE = { "Waist", "Neck", "RightShoulder", "RightElbow" }
	local function activity(i)
		local a = 0
		for _, jn in CORE do
			a = math.max(a, speed(i, jn))
		end
		return a
	end
	local wPeak = 0
	for i = 1, math.floor(PEAK * FPS) do
		wPeak = math.max(wPeak, activity(i))
	end
	local still = 0
	local stillRun = 0
	for i = math.floor(0.55 * FPS), math.floor(CONTACT * FPS) do
		if activity(i) < 0.25 * wPeak then
			stillRun += 1
			still = math.max(still, stillRun)
		else
			stillRun = 0
		end
	end
	local holdFrames = 0
	for i = math.floor(CONTACT * FPS) + 1, N do
		if speed(i, "RightShoulder") < 0.05 and speed(i, "RightElbow") < 0.05 then
			holdFrames += 1
		else
			break
		end
	end
	line(
		string.format(
			"%s G1 windupPeak %.1f deg/f, peak still run %d f (%.2fs), arm hold after contact %d f (%.2fs)",
			name,
			wPeak,
			still,
			still / FPS,
			holdFrames,
			holdFrames / FPS
		)
	)

	-- G2 strike speed table + stutters
	local st = {}
	for i = math.floor(0.74 * FPS), math.floor(0.92 * FPS) do
		table.insert(st, string.format("%.2f:%.1f", i / FPS, speed(i, "RightShoulder")))
	end
	line(name .. " G2 strike RightShoulder deg/f " .. table.concat(st, " "))
	local stutters = {}
	for jn in motors do
		for i = 2, N - 1 do
			local a, b, c = speed(i - 1, jn), speed(i, jn), speed(i + 1, jn)
			if a > 0.6 and c > 0.6 and b < 0.5 * math.min(a, c) then
				local d1 = frames[i - 1].tf[jn]:Inverse() * frames[i].tf[jn]
				local d2 = frames[i].tf[jn]:Inverse() * frames[i + 1].tf[jn]
				local ax1 = d1:ToAxisAngle()
				local ax2 = d2:ToAxisAngle()
				if ax1:Dot(ax2) > 0.5 then
					table.insert(stutters, string.format("%s@%.2f(%.1f>%.1f<%.1f)", jn, i / FPS, a, b, c))
				end
			end
		end
	end
	line(name .. " G2 stutters: " .. (if #stutters == 0 then "none" else table.concat(stutters, " ")))

	-- G3 anticipation: dip, arch, onsets
	local rest = frames[0].pelvis
	local dip = 0
	for i = 0, math.floor(PEAK * FPS) do
		dip = math.min(dip, frames[i].pelvis - rest)
	end
	local onset = {}
	for _, jn in { "Root", "Waist", "Neck", "RightShoulder" } do
		for i = 1, N do
			if speed(i, jn) > 0.3 then
				onset[jn] = i
				break
			end
		end
	end
	line(
		string.format(
			"%s G3 dip %.3f, rise into peak %.3f, arch Waist pitch at peak %.1f, onsets Root %s Waist %s Neck %s Shoulder %s",
			name,
			dip,
			fi(PEAK).pelvis - (rest + dip),
			select(1, fi(PEAK).tf.Waist:ToEulerAnglesXYZ()) * 180 / math.pi,
			tostring(onset.Root),
			tostring(onset.Waist),
			tostring(onset.Neck),
			tostring(onset.RightShoulder)
		)
	)

	-- G4 squash + follow-through
	local cP = fi(CONTACT).pelvis - rest
	local lowT, low = CONTACT, cP
	for i = math.floor(CONTACT * FPS), math.floor((CONTACT + 0.3) * FPS) do
		if frames[i].pelvis - rest < low then
			low, lowT = frames[i].pelvis - rest, i / FPS
		end
	end
	local headMove = angle(fi(CONTACT).tf.Neck:Inverse() * fi(CONTACT + 0.2).tf.Neck)
	local faceDrift = 0
	for i = math.floor(CONTACT * FPS), math.floor(LIFT * FPS) do
		faceDrift = math.max(faceDrift, (frames[i].face - fi(CONTACT).face).Magnitude)
	end
	line(
		string.format(
			"%s G4 pelvis@contact %.3f, lowest %.3f at %.2fs (+%.2fs), head turn 0.2s after %.1f deg, face drift in hold %.3f, face up %.2f",
			name,
			cP,
			low,
			lowT,
			lowT - CONTACT,
			headMove,
			faceDrift,
			fi(CONTACT).faceUp
		)
	)

	-- G5 parcel: top at the contact face; hop from LIFT; clearance from the stamp and hands
	local feetY = math.min(frames[0].rfoot.Y, frames[0].lfoot.Y) - m.RightFoot.Size.Y / 2
	local top0 = fi(CONTACT).face.Y
	local parcelH = top0 - (feetY + COUNTER)
	local minClear = 99
	for i = math.floor(LIFT * FPS), math.floor((LIFT + HOP.SECONDS + 0.1) * FPS) do
		local t = i / FPS - LIFT
		local hop = if t <= HOP.SECONDS then HOP.APEX * math.sin(math.pi * t / HOP.SECONDS) else 0
		local topY = top0 + hop
		local dx = (frames[i].face - fi(CONTACT).face) * Vector3.new(1, 0, 1)
		if dx.Magnitude < 0.6 then
			minClear = math.min(minClear, frames[i].face.Y - topY)
		end
	end
	line(
		string.format(
			"%s G5 parcel height on the counter %.2f studs (top %.2f above feet), stamp clearance over the hopping parcel min %.3f",
			name,
			parcelH,
			top0 - feetY,
			minClear
		)
	)

	-- G6 stamp stays in hand
	local offVar = 0
	for i = 0, N do
		offVar = math.max(offVar, (frames[i].handOff - frames[0].handOff).Magnitude)
	end
	line(string.format("%s G6 stamp offset from hand varies %.4f", name, offVar))

	-- G7 clipping
	local worst, wt, who = 99, 0, ""
	for i = 0, N do
		if frames[i].clip < worst then
			worst, wt, who = frames[i].clip, frames[i].t, frames[i].clipWho
		end
	end
	line(string.format("%s G7 stamp closest to inside %s: %.2f at %.2fs (<1 = inside)", name, who, worst, wt))

	-- G8 feet
	local drift = 0
	for i = 0, N do
		drift = math.max(
			drift,
			(frames[i].rfoot - frames[0].rfoot).Magnitude,
			(frames[i].lfoot - frames[0].lfoot).Magnitude
		)
	end
	line(string.format("%s G8 foot drift max %.3f", name, drift))

	-- G9 seam
	local seam = 0
	for jn in motors do
		seam = math.max(seam, angle(frames[0].tf[jn]:Inverse() * frames[N].tf[jn]))
	end
	local endSpeed, startSpeed = 0, 0
	for jn in motors do
		endSpeed = math.max(endSpeed, speed(N, jn))
		startSpeed = math.max(startSpeed, speed(1, jn))
	end
	local frozen, run = 0, 0
	for i = 1, N do
		local any = 0
		for jn in motors do
			any = math.max(any, speed(i, jn))
		end
		if any < 0.05 then
			run += 1
			frozen = math.max(frozen, run)
		else
			run = 0
		end
	end
	line(
		string.format(
			"%s G9 seam pose diff %.2f deg, speed end %.2f / start %.2f deg/f, longest frozen run %d f",
			name,
			seam,
			endSpeed,
			startSpeed,
			frozen
		)
	)

	-- G10/G11 greet
	track:Stop(0)
	local g = load(animator, greetKs)
	local gN = math.floor(greetKs:GetKeyframes()[#greetKs:GetKeyframes()].Time * FPS + 0.5)
	local xs, rock, gclip, gwho, gt = {}, {}, 99, "", 0
	for _, t in { 0.6, 0.85, 1.1, 1.35, 1.6 } do
		at(animator, g, t)
		table.insert(xs, string.format("%.2f", hrp.CFrame:PointToObjectSpace(m.RightHand.Position).X))
		local _, _, rz = motors.Waist.Transform:ToEulerAnglesXYZ()
		table.insert(rock, string.format("%.0f", math.deg(rz)))
	end
	for i = 0, gN do
		at(animator, g, i / FPS)
		for _, body in { "Head", "UpperTorso" } do
			for _, p in corners(base) do
				local v = inside(m[body], p)
				if v < gclip then
					gclip, gwho, gt = v, "stamp/" .. body, i / FPS
				end
			end
			for hi, p in { m.RightHand.Position, m.LeftHand.Position } do
				local v = inside(m[body], p)
				if v < gclip then
					gclip, gwho, gt = v, (if hi == 1 then "RHand/" else "LHand/") .. body, i / FPS
				end
			end
		end
	end
	at(animator, g, 0)
	local g0 = {}
	for jn, mo in motors do
		g0[jn] = mo.Transform
	end
	at(animator, g, gN / FPS)
	local gEnd, gStart = 0, 0
	for jn, mo in motors do
		gEnd = math.max(gEnd, angle(frames[0].tf[jn]:Inverse() * mo.Transform))
		gStart = math.max(gStart, angle(frames[0].tf[jn]:Inverse() * g0[jn]))
	end
	line(
		string.format(
			"%s G10 wave hand x %s, waist roll %s, closest %s %.2f at %.2fs",
			name,
			table.concat(xs, "/"),
			table.concat(rock, "/"),
			gwho,
			gclip,
			gt
		)
	)
	line(string.format("%s G11 greet start vs stamp ready %.2f deg, end %.2f deg", name, gStart, gEnd))

	m:Destroy()
end

for slot, name in EMPLOYEES do
	measure(name, slot)
end
return table.concat(report, "\n")
