--!strict
--[=[
	VacuumMotionConstants: the tuning of the held vacuum's client-side motion layers (VacuumMotionSystem on every
	client, VacuumMotionRigSystem on the rig, the maths in VacuumMotionFormulas). Purely visual: nothing here moves
	anything the server decides. Angles in radians, lengths in studs (Pippa's 1.25x rig), springs as a frequency (Hz)
	and a damping ratio (1 = critically damped, below 1 overshoots). Every number is a tuning hypothesis, chosen to
	read at gameplay distance without jitter (characters/qa/vacuum-hold/dynamic). Static data (spec-exempt).

	@class VacuumMotionConstants
]=]

return table.freeze({
	-- Aim with the camera. The camera's look pitch (VacuumMotionFormulas.aim): between `deadLow` and `deadHigh` (the
	-- default third-person view sits about 20 degrees down) the wand holds its planned pose. Looking up past
	-- `deadHigh` raises the floor head about the wand's pivot, `gainUp` per radian, to `maxUp` (the nozzle points
	-- ahead). Looking down past `deadLow` reaches for the floor: up to `reachDrop` down and `reachForward` forward with
	-- the hands, fully at `fullDown`, the wand flattening so the head stays on the floor further out.
	-- The look pitch is replicated quantised to `quantum`, at most `rate` times a second, only when it changes; every
	-- client eases toward it with a critically damped spring.
	aim = table.freeze({
		deadLow = math.rad(-32),
		deadHigh = math.rad(-8),
		gainUp = 0.9,
		maxUp = math.rad(38),
		fullDown = math.rad(-70),
		reachDrop = 0.16,
		reachForward = 0.14,
		quantum = math.rad(5),
		rate = 10,
		frequency = 3,
		damping = 1,
	}),
	-- Lean and brace while sucking: the hips drop `drop` (the knees fold, feet planted) and the torso leans
	-- `lean` forward over the waist; the hands come down `handDrop` and in `pull` toward the body (the wand flattens
	-- so its head stays on the floor). A holder who starts sucking braces to `base` of it, deepening to all of it as
	-- the pile nears done; letting go springs her back upright.
	brace = table.freeze({
		drop = 0.2,
		lean = math.rad(11),
		handDrop = 0.14,
		pull = 0.1,
		base = 0.55,
		frequency = 2.6,
		damping = 0.85,
	}),
	-- The pop kick: the wand jolts back and up `lift` (studs; `back` of it toward the body) and the floor head hops
	-- `pitch`, then settles in about 0.3 s. A bigger pile kicks harder: its size against `sizeRef`, between `minScale`
	-- and `maxScale`. Only holders who were sucking within `window` seconds, within `range` studs of the pile, kick.
	kick = table.freeze({
		lift = 0.15,
		back = 0.6,
		pitch = math.rad(7),
		frequency = 4.5,
		damping = 0.42,
		sizeRef = 5.8,
		minScale = 0.7,
		maxScale = 1.3,
		window = 0.6,
		range = 10,
	}),
	-- The suction shimmy: while sucking, the floor head shimmies (a yaw and a roll about the wand's pivot, layered
	-- sines at about `frequency` Hz, seeded per holder), from `base` of the full amplitude at the start of a pile to
	-- all of it as it nears done (the progress squared). Slow enough to read as strain, not jitter.
	shimmy = table.freeze({
		yaw = math.rad(2.6),
		roll = math.rad(2.2),
		frequency = 5.5,
		base = 0.15,
	}),
	-- Never let the floor head under the floor: its lowest corner stays `floorMargin` above it.
	floorMargin = 0.01,
	-- Never move the wand where the left paw cannot follow: its grip stays within `reachUse` of the left arm's reach
	-- from its shoulder (as the hold is planned), the layers scaled back together until it does. Turned about the
	-- right hand, the aim, the reach for the floor and the sway to the right took GripLower 0.08-0.34 stud past
	-- Pippa's left arm (AnimationVacuumHarness, Studio 2026-10-17), and capped there the aim all but vanished; so the
	-- wand turns about the left paw's grip, and this only guards the translations.
	reachUse = 0.95,
	-- The left paw turns `leftTurn` of the wand's turn about its own grip (it stays on it): Pippa's left wrist,
	-- near its full reach, could not follow the whole of the aim's 38 degrees (0.053 stud off, vacuum idle).
	leftTurn = 0.5,
	-- A frame longer than `maxStep` only advances the springs that far.
	maxStep = 0.1,
	-- Replicated state on the character (set by the server): the look pitch in degrees, and whether its vacuum is
	-- sucking.
	AIM_ATTRIBUTE = "VacuumAim",
	ACTIVE_ATTRIBUTE = "VacuumActive",
	-- The rest frame each IK target attachment was created at (the server's plan; clients move their copies).
	REST_ATTRIBUTE = "VacuumRest",
	-- On the left IK target: its point on the wand (GripLower), the left shoulder (both root space, at rest) and the
	-- arm's reach to its paw's wrap point.
	AT_ATTRIBUTE = "VacuumAt",
	SHOULDER_ATTRIBUTE = "VacuumShoulder",
	REACH_ATTRIBUTE = "VacuumReach",
})
