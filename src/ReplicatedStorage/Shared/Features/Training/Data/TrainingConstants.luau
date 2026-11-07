--!strict
--[=[
	TrainingConstants: the training run (tutorial design v2, owner-approved 11-06). A new player rides the one-seat
	Training truck from the hub to a small Training map in the Shift place: one hall of 5 stops, built in Studio and
	read by its tags and attributes (so a builder can restyle it), run as a real shift on the real vacuum, cargo, hiding
	spots and Mr. Harlow. A catch costs one life but never knocks the player out; finishing pays REWARD_GLEAM once.

	The authored map: one Model tagged MAP_TAG; each gameplay part inside it carries ROLE_ATTRIBUTE (a Role) and, where
	its role needs them, STOP_ATTRIBUTE (which stop, 1-5), ORDER_ATTRIBUTE (its place in a sequence) and KIND_ATTRIBUTE
	(a pile or cargo kind). The map also holds a "Truck" folder with a "TruckBed" part (the cargo bed). Hiding furniture
	uses the game's own HideFurniture tag. TrainingMapRules checks all of it.

	@class TrainingConstants
]=]

-- What a part in the Training map is for.
export type Role =
	"spawn" -- where the player lands (CFrame)
	| "stop" -- where a stop starts: a catch sends the player back here (STOP)
	| "zone" -- a box: walking into it starts its stop (STOP)
	| "door" -- shuts the way on until its stop is done (STOP)
	| "pile" -- a Gloom pile spawns here (STOP, KIND: a pile kind)
	| "item" -- a cargo item spawns here (STOP, KIND: a cargo id)
	| "route" -- one of Mr. Harlow's patrol points (ORDER)
	| "rest" -- where Mr. Harlow takes his break
	| "safe" -- a box Mr. Harlow never enters (the start)
	| "bay" -- a box he walks but never lingers in
	| "light" -- a hall light; they go out in ORDER at stop 3 (client)
	| "creep" -- a Gloom patch that creeps in at stop 3, in ORDER (client)
	| "sign" -- where a stop's sign hangs (STOP; client)

-- What finishes a stop: its piles cleared, its treasure loaded, or walking into the next stop.
export type Goal = "piles" | "banked" | "walk" | "finish"

-- Pippa's pose for a line (EmployeePoseRegistry's coach poses: shared, so any employee could coach).
export type CoachPose = "point" | "warn" | "cheer" | "shh" | "hide"

-- One thing Pippa says, and how she stands while she says it.
export type CoachLine = { text: string, pose: CoachPose }

-- A stop's goal bar: its title, one short line, and its icon (a ToonIcon name; "!" = the coral danger mark).
export type GoalCard = { title: string, line: string, icon: string }

export type Stop = {
	id: string,
	goal: Goal,
	-- The stop's sign, at a kid's reading level.
	sign: string,
}

local ROLES: { Role } = {
	"spawn",
	"stop",
	"zone",
	"door",
	"pile",
	"item",
	"route",
	"rest",
	"safe",
	"bay",
	"light",
	"creep",
	"sign",
}

local STOPS: { Stop } = {
	{ id = "dust", goal = "piles", sign = "Hold to vacuum the Gloom!" },
	{ id = "treasure", goal = "banked", sign = "Clean the treasure. Leave the trash!" },
	{ id = "quiet", goal = "walk", sign = "Shh! He hears running." },
	{ id = "hide", goal = "walk", sign = "He's coming! Hide!" },
	{ id = "done", goal = "finish", sign = "You did it! Time for a real shift." },
}
for _, stop in STOPS do
	table.freeze(stop)
end

local COACH_POSES: { CoachPose } = { "point", "warn", "cheer", "shh", "hide" }

local COACH: { [string]: CoachLine } = {
	dust = { text = "Follow the gold arrows! Then hold the vacuum on the purple goo.", pose = "point" },
	treasure = { text = "Grab the mug and take it to the truck. Leave the trash!", pose = "point" },
	carrying = { text = "Now put it in the truck!", pose = "point" },
	quiet = { text = "Uh oh, the lights! Don't stop. Stay on the arrows.", pose = "warn" },
	hide = { text = "I hear him! Run to the glowing desk and hide!", pose = "hide" },
	hidden = { text = "Shh! Wait for him to go. Then follow the arrows.", pose = "shh" },
	done = { text = "You did it! You're ready for a real shift!", pose = "cheer" },
	open = { text = "The door is open! Follow the arrows.", pose = "point" },
	caught = { text = "Try again! Run to the glowing desk before he sees you.", pose = "shh" },
	shop = { text = "This is the Shop! Spend your Gleam here.", pose = "point" },
	trucks = { text = "Hop on a truck with your crew!", pose = "cheer" },
	vacuum = { text = "This is your vacuum! Pick it, then hold to suck up Gloom.", pose = "point" },
	power = { text = "This is your power! Tap it now to try it.", pose = "point" },
}

local GOALS: { [string]: GoalCard } = {
	dust = { title = "SUCK UP THE GLOOM!", line = "Walk to the purple goo. Hold to vacuum it.", icon = "vacuum" },
	treasure = { title = "SAVE THE TREASURE!", line = "Take the mug to the truck. Leave the trash.", icon = "monitor" },
	quiet = { title = "FOLLOW THE ARROWS!", line = "The lights are going out. Keep going!", icon = "flashlight" },
	hide = { title = "HIDE UNDER THE DESK!", line = "Mr. Harlow is coming. Hide and stay still.", icon = "!" },
	done = { title = "TRAINING DONE!", line = "You're ready for a real shift.", icon = "trophy" },
}

local TrainingConstants = {
	-- The ticket payload key and value a Training truck departs with (QueueTypes.QueuePayload).
	MODE_KEY = "mode",
	MODE = "training",
	-- The return payload's value (under MODE_KEY) after PLAY AGAIN on the finish screen: the hub points the player
	-- at the Training pad.
	AGAIN = "trainingAgain",

	-- The hub's Training truck: the pad's tag (DepotBuildSystem builds one today; a Studio-built hub tags its own).
	TRUCK_TAG = "TrainingTruck",
	TRUCK_CAPACITY = 1,
	TRUCK_COUNTDOWN = 3,

	-- The authored map.
	MAP_TAG = "TrainingMap",
	ROLE_ATTRIBUTE = "TrainingRole",
	STOP_ATTRIBUTE = "TrainingStop",
	ORDER_ATTRIBUTE = "TrainingOrder",
	KIND_ATTRIBUTE = "TrainingKind",
	ROLES = table.freeze(ROLES),
	STOPS = table.freeze(STOPS),

	-- The training run's world entry (StateSyncWorldStore): the stop the player is on, for the client's hall effects.
	WORLD_ENTRY = "training",

	-- Never fewer lives than this in training: the last catch costs nothing, so nobody is knocked out.
	LIVES_FLOOR = 1,
	-- After a catch's knock-down, the player is moved back to the start of their stop (while the screen is dark:
	-- CATCH_BEAT.dark to .back).
	RETURN_DELAY = 2.0,
	-- After "Play training again", how long the hub's chevron trail leads a trained player to the pad (seconds).
	AGAIN_TRAIL_SECONDS = 60,
	-- The catch beat, in seconds from the grab: a goo splat on a heart, the red card, the screen going dark (the move
	-- back happens here), back at the stop with Pippa's tip, done.
	CATCH_BEAT = table.freeze({ splat = 0.3, card = 0.6, dark = 1.6, back = 2.4, done = 5.4 }),
	-- Seconds from finishing to the ride back to the hub.
	HOME_DELAY = 5,

	-- The tags the spotlight finds its UI targets by (React.Tag on the button).
	SPOTLIGHT_TAGS = table.freeze({
		shop = "TrainingSpotShop",
		vacuum = "TrainingSpotVacuum",
		power = "TrainingSpotPower",
	}),

	-- The hotbar tour's mark in the tips slice (TipServiceServer:once): shown once per account, on the first run.
	HOTBAR_TIP = "hotbarTour",
	-- Seconds after a run starts before the hotbar tour shows (the load screen lifts first).
	HOTBAR_DELAY = 2,
	-- How long each hotbar step shows at most (the steps the player must do wait for it instead).
	HOTBAR_SECONDS = 8,
	-- The run step passes after this many seconds of real sprinting.
	RUN_SECONDS = 1,

	-- The guide (tutorial v3): a floor trail of chevrons scrolling toward the goal, a bobbing arrow over it and a ring
	-- on the floor under it. Gold, red at the hide stop. The images are Icey Labs uploads, white so they tint.
	GUIDE = table.freeze({
		chevron = "rbxassetid://137999532377528",
		arrow = "rbxassetid://130801617656931",
		calm = Color3.fromRGB(255, 205, 64),
		danger = Color3.fromRGB(255, 84, 112),
		-- The trail: studs per chevron, scroll speed (studs a second toward the goal), width, lift off the floor.
		chevronLength = 3,
		speed = 1.6,
		width = 2.4,
		lift = 0.12,
		-- Re-path when the player has moved this far, or this often.
		repathDistance = 4,
		repathSeconds = 0.75,
		-- The arrow: size (px), height over the target (studs), bob height (studs) and speed.
		arrowSize = 72,
		arrowHeight = 5,
		bob = 0.6,
		bobSpeed = 3,
		-- The ring under the target: diameter (studs).
		ring = 5,
		-- Within this distance of the treasure, the player counts as carrying it (the guide moves on to the truck).
		carryRange = 6,
	}),

	-- The hide stop's screen on top of DARK_SCREEN: redder.
	DANGER_SCREEN = table.freeze({
		tint = Color3.fromRGB(255, 196, 204),
		saturation = -0.1,
	}),

	COACH_POSES = table.freeze(COACH_POSES),

	-- Pippa's lines (the stop's own line first; `open` once its door is open). Kid reading level.
	COACH = table.freeze(COACH),

	-- The goal bar per stop (TrainingGoalBar), in place of the Gloom meter.
	GOALS = table.freeze(GOALS),

	-- A training trip's contract (in place of the night's client): the ride's route slip says where you are going.
	CONTRACT = table.freeze({
		id = "training",
		client = "Training Room",
		job = "Learn the job",
		note = "No rush. Pippa will show you.",
	}),
	-- The route slip's site line on a training trip.
	ROOM_SITE = "Morrow & Morrow · learn the job",

	-- If the player picks nothing on the finish screen, the ride home leaves after this long.
	FINISH_WAIT = 30,

	-- The one-time thank-you (owner: 100 Gleam).
	REWARD_GLEAM = 100,

	-- Seconds between two hall lights going out at stop 3, and a creep patch's grow time.
	LIGHT_STEP = 0.45,
	CREEP_SECONDS = 2.5,
	-- The screen at stops 3-4 (a Vfx screen request): darker, greyer and cold, whatever the place's own lighting.
	DARK_SCREEN = table.freeze({
		brightness = -0.22,
		saturation = -0.35,
		tint = Color3.fromRGB(190, 182, 232),
	}),

	TEXT = table.freeze({
		truckSign = "New here? Start training!",
		truckTag = "TRAINING",
		finished = "Great job! You're ready.",
		finishTitle = "TRAINING DONE!",
		finishGleam = "Gleam for finishing training!",
		finishAgain = "You already got your Gleam. Nice practice!",
		finishLine = "You're ready for a real shift! Spend your Gleam in the Shop.",
		back = "BACK TO THE DEPOT",
		playAgain = "PLAY AGAIN",
		caughtCard = "CAUGHT! YOU LOST A LIFE",
		caughtLine = "It's OK! Try again from the start of this stop.",
		you = "YOU",
		reward = "Training done!",
		failed = "Training could not start. Try again soon.",
		tourShop = "You got 100 Gleam! Spend it in the Shop.",
		tourTrucks = "Hop on a truck with your crew!",
		again = "Step on the TRAINING pad to play again!",
		againButton = "PLAY TRAINING AGAIN",
		tourVacuum = "This is your vacuum! Pick it, then hold to suck up Gloom.",
		tourPower = "This is your power! Tap it now to try it.",
		tourRun = "Run! Hold Shift to run fast.",
		tourRunPad = "Run! Press the left stick to run fast.",
	}),
}

return TrainingConstants
