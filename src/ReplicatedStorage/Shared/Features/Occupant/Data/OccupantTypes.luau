--!strict
--[=[
	OccupantTypes: Mr. Harlow's shapes (Cleanup Crew spec §4 "Mr. Harlow"). Shared: the client reads his mode
	from an attribute. Types only (spec-exempt).

	@class OccupantTypes
]=]

-- What he is doing: walking his route, checking a noise, chasing someone he sees, searching where he lost
-- them, on the shift's break, standing over a catch, working at a desk (his routine, or sitting at the desk someone
-- hides under: `sitIn`), or staring at a hiding spot.
export type Mode = "patrol" | "investigate" | "chase" | "search" | "rest" | "catch" | "work" | "stare"

-- Where he is inside a mode (published as an attribute; the client's typing, face and gestures follow it):
-- work: walking to the desk, typing, the ambush (stopped dead, head swivelled); a sit-in also tips his head down under
-- the desk, holds it there and brings it back up, then types a little more; stare: walking to the spot, holding still,
-- bending down to look under (a desk or table), or opening the door (a secure supply cabinet: slower, telegraphed).
export type Phase =
	"toDesk"
	| "type"
	| "ambush"
	| "tip"
	| "tipHold"
	| "tipBack"
	| "typeMore"
	| "approach"
	| "hold"
	| "check"
	| "open"

-- A moment worth a speech bubble (OccupantConstants.LINES).
export type Cue = "spotted" | "curious" | "giveUp" | "resting" | "caught" | "ambush" | "sitIn"

-- A desk he can sit at: the root's frame on its chair (standing height, facing the desk), whether the chair is on the
-- knee-hole side (only then can he sit at the desk someone hides under), and its hiding spot.
export type Desk = {
	id: string,
	seat: CFrame,
	front: boolean,
	spotId: string?,
	-- The desk itself (its frame and size): standing up must end clear of it (OccupantDeskUtils.standUp).
	frame: CFrame?,
	size: Vector3?,
}

-- A hiding spot as he knows it: its centre, where he stands to stare at it, its desk (nil for a table or cabinet), and
-- whether it is secure (a closed supply cabinet: he cannot look in casually, he must open it).
export type Spot = {
	id: string,
	center: Vector3,
	stand: Vector3,
	-- Which side of the spot's centre line the stand point is (the sign of its local X; 0 straight out): his check
	-- tips his head toward the centre line from there (OccupantGestureFormulas.gestureFor).
	side: number?,
	deskId: string?,
	secure: boolean?,
}

-- A crew member hiding: in which spot, and whether he knows (Hide's seenEntering).
export type Hider = {
	userId: number,
	spotId: string,
	seen: boolean,
}

-- Something the brain asks the service to do this think (beyond the NPC intent).
export type Effect =
	{ kind: "sit", seat: CFrame, desk: CFrame?, deskSize: Vector3? }
	| { kind: "stand", speed: number }
	| { kind: "plant", frame: CFrame }
	| { kind: "release" }
	| { kind: "seen", userId: number, seen: boolean }
	| { kind: "holdCamp", userId: number, untilTime: number }
	| { kind: "catch", userId: number }
	| { kind: "door", spotId: string, open: boolean }
	-- Stuck where no path starts: lifted to this route point (OccupantStuckRules).
	| { kind: "unstick", position: Vector3 }

-- How the director paces him (from the shift and the crew).
export type Pacing = {
	tier: number,
	solo: boolean,
	overtime: boolean,
}

-- An axis-aligned box in the world (the truck's box, the one safe place; or the loading bay around it).
export type Zone = {
	min: Vector3,
	max: Vector3,
}

-- His memory between thinks. Times are os.clock() seconds.
export type Mind = {
	mode: Mode,
	-- When the current mode began.
	since: number,
	-- The route point he is walking to, and which way round he walks (1 or -1).
	routeIndex: number,
	routeStep: number,
	-- The UserId he is chasing.
	target: number?,
	-- Where he last saw his target (always outside the truck's box).
	lastSeen: Vector3?,
	-- Bounded, authored nearby locations checked after the last sighting; never live hidden positions.
	searchPoints: { Vector3 }?,
	searchIndex: number?,
	-- The noise he is investigating.
	noise: Vector3?,
	-- When he reached the investigate / search point (looking around since).
	arrivedAt: number?,
	-- UserId → the os.clock() until which he ignores them (after a catch).
	grace: { [number]: number },
	-- When he walked into the loading bay (nil while outside it), and until when he keeps out of it after lingering
	-- there BAY_LINGER_SECONDS (he never body-blocks the truck's ramp).
	bayAt: number?,
	bayBarredUntil: number?,
	-- Inside a work or stare mode: where he is, since when, and how long it lasts (rolled when it began).
	phase: Phase?,
	phaseAt: number?,
	hold: number?,
	-- The desk he works at (or sits at over a hider), the spot he stares at and the hider in it (nil for a suspicion
	-- stare), whether this is a sit-in, whether a noise came from near the spot meanwhile, whether the stare is a hunch
	-- (he lost his chase near the spot and did not see where they went), and when he got near its stand point.
	desk: Desk?,
	spot: Spot?,
	quarry: number?,
	sitIn: boolean?,
	noisy: boolean?,
	hunch: boolean?,
	nearAt: number?,
	-- The point the ambush turned to; until when his head stays swivelled to it.
	point: Vector3?,
	swivelUntil: number?,
	-- His body: on a chair (the sit clip, root anchored), or planted still at a spot (root anchored).
	seated: boolean?,
	planted: boolean?,
	-- Standing up from a chair, or startled (a hider bolting): no move before these.
	standUntil: number?,
	reactUntil: number?,
	-- Seconds he had each player in sight (decaying), and how far from him (flat studs) he saw each hider go into their
	-- spot.
	watched: { [number]: number },
	entered: { [number]: number },
	-- A crew member far down a clear line (LONG_SIGHT_RANGE, the narrow cone) he is noticing: who, and for how many
	-- seconds; he chases once that reaches the notice delay for the distance.
	noticeId: number?,
	noticeSeconds: number?,
	-- Spot id → until when he leaves that spot alone (after a stare that ended in him walking away).
	cleared: { [string]: number },
	-- The routine: when the next work break is due, and the last desk he used.
	nextWorkAt: number,
	lastDesk: string?,
	-- The director: the next steer, the point he is steered to, the menace gauge, the breather, sit-ins this shift and
	-- the last one, and the last think (for the gauge's rate).
	nextSteerAt: number,
	steer: Vector3?,
	menace: number,
	breatherUntil: number?,
	sitIns: number,
	lastSitInAt: number?,
	lastThink: number?,
	-- Progress on a walk (OccupantStuckRules): where and when he last moved STUCK_MOVE, and how often in a row he has
	-- been stuck since.
	stuckFrom: Vector3?,
	stuckAt: number?,
	stuckCount: number?,
}

-- One crew member as the service saw them this think; `clear` is the line-of-sight ray's verdict.
export type Glimpse = {
	feetY: number?,
	userId: number,
	position: Vector3,
	clear: boolean,
	-- In a hiding spot (Hide), and whether he saw them go in: unseen, he cannot see them at all; seen, he knows exactly
	-- where they are (through the furniture).
	hidden: boolean?,
	seen: boolean?,
}

-- Everything the brain decides from, gathered by OccupantServiceServer each think.
export type Senses = {
	reachTopY: number?,
	position: Vector3,
	look: Vector3,
	now: number,
	sightRange: number,
	sightAngle: number,
	-- His long sight straight ahead (absent = none): out to longRange in the narrow longAngle cone, noticed over a beat.
	longRange: number?,
	longAngle: number?,
	players: { Glimpse },
	-- The last noise he heard since the previous think (already through NoiseRules).
	heard: Vector3?,
	-- The shift's break: he walks to `restPoint` and ignores everyone.
	resting: boolean,
	route: { Vector3 },
	restPoint: Vector3,
	-- The truck's box: nobody inside it is seen, no noise inside it is followed.
	zone: Zone,
	-- The loading bay around the truck: he may walk it, but never lingers (absent = no bay rule).
	bay: Zone?,
	-- Uniform 0..1 numbers for this think's random choices (absent = 0.5 each).
	rolls: { number }?,
	-- The desks he can sit at, every hiding spot, who hides where, and the pacing (absent = none / a crew at tier 0).
	desks: { Desk }?,
	spots: { Spot }?,
	hiders: { Hider }?,
	pacing: Pacing?,
}

-- What the catch rule needs about a would-be catch.
export type CatchInput = {
	reachable: boolean?,
	clear: boolean?,
	distance: number,
	position: Vector3,
	alive: boolean,
	-- Their catch sequence is already running.
	catching: boolean,
	inGrace: boolean,
	resting: boolean,
	zone: Zone,
	-- In a hiding spot he did not see them go in (one he did see is fair game).
	hidden: boolean?,
	-- A hider he found at their spot (the check, a cabinet he opened, a sit-in): he may reach FOUND_REACH further.
	found: boolean?,
}

-- What the caught player is told (OccupantEvents.CatchReport, M3 UI incident report): the room, the shift clock's
-- seconds left at the catch, the server time they are back, and the names of the items they dropped.
export type CatchReport = {
	room: string,
	clock: number,
	backAt: number,
	dropped: { string },
}

-- How strongly the dread shows on this client (OccupantDreadFormulas; client-local, from replicated state). A dread
-- "stage": nothing; he is near and unaware of you; he sees you or is hunting; he chases you; a crewmate near you is
-- being chased.
export type DreadStage = "none" | "near" | "aware" | "chase" | "crew"

-- One frame of the dread's look and mix. Volumes are scales of the sound's registered volume; screen values 0..1;
-- `red` and `edge` are the peaks the heartbeat pulses to; `squeeze` FOV degrees; `duck` and `muffle` dB (<= 0).
export type DreadLook = {
	heart: number,
	dread: number,
	vignette: number,
	desaturate: number,
	grain: number,
	red: number,
	edge: number,
	squeeze: number,
	duck: number,
	muffle: number,
}

return {}
