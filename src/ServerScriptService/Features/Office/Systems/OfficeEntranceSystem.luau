--!strict
--[=[
	OfficeEntranceSystem: the Lethal-style entrances of a generated office (stage 3). A crew member interacts with an
	entrance's outside door (OfficeConstants.ENTER_KIND, "Enter") or its inside exit (LEAVE_KIND, "Leave"); their
	screen fades to black over OUTSIDE.FADE_OUT, they are set down at the entrance's fixed inside (enter) or outside
	(leave) frame, SPAWN_HEIGHT up, and the screen fades back in over OUTSIDE.FADE_IN. The same spot every time.

	`request(player, kind, entranceId, now)` is refused (false, nothing happens) when the player is not on the running
	shift's crew still working (`deps.inCrew`: a clocked-out player is done for the shift), is dead, down or caught (`deps.alive`, a dead humanoid, or the catch's anchored root),
	stands farther than OUTSIDE.ENTRANCE_REACH from every part of that kind and entrance, or already has a teleport
	pending (spamming the prompt, Review Focus 2). A pending flag that never cleared expires after PENDING_SECONDS.
	The same checks run again when the move is due and again after the target streams in (that yields): a player
	caught, killed, respawned, clocked out or past the shift's end meanwhile stays put; the screen still uncovers and
	the pending flag still clears. Stopping the system drops every pending teleport.

	What a player carries travels with them: Carry holds an object with a Weld (or a Motor6D) from the character's body
	into the object, so it is part of the character's assembly, and `teleport` sets the root's CFrame, which moves the
	whole assembly at once (Review Focus 1).

	The kinds register at load (the prompts' words). Instance shell; the decisions are the pure `target` and `allowed`.

	@class OfficeEntranceSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)

local OUTSIDE = OfficeConstants.OUTSIDE
-- How long a pending teleport may stand before a new request is taken anyway (the teleport errored or never ran).
local PENDING_SECONDS = 10
-- How long the server waits for the target area to stream in around the player.
local STREAM_TIMEOUT = 2

local log = Logger.new("OfficeEntranceSystem")

-- Registered at load: the generated office's entrance parts carry these kinds from the moment they are built.
for kind, words in { [OfficeConstants.ENTER_KIND] = "Enter", [OfficeConstants.LEAVE_KIND] = "Leave" } do
	if not InteractionRegistry.has(kind) then
		InteractionRegistry.register(kind, {
			actionText = words,
			objectText = "Office",
			maxDistance = OUTSIDE.ENTRANCE_REACH,
		})
	end
end

export type State = {
	inCrew: boolean,
	alive: boolean,
	-- Studs from the player's root to the nearest part of the kind and entrance they used.
	distance: number,
	pending: boolean,
}

export type Deps = {
	-- Whether the player is on the running shift's crew and still working (not clocked out).
	inCrew: (player: Player) -> boolean,
	-- Whether the player is up and playing (not dead, knocked down or knocked out); absent = true. The system also
	-- refuses a dead humanoid and an anchored root (a catch in progress) by itself.
	alive: ((player: Player) -> boolean)?,
	-- The entrance's world outside and inside frames (OfficeServiceServer:entrance).
	entrance: (id: OfficeTypes.EntranceId) -> (CFrame?, CFrame?),
	-- The parts of `kind` for entrance `id` (the outside door's hit box, or the exit's leaves); absent = the tagged
	-- Interaction parts carrying that kind and EntranceId.
	parts: ((kind: string, id: OfficeTypes.EntranceId) -> { BasePart })?,
	-- Tells the player's client to cover (true) or uncover (false) its screen over `seconds`.
	fade: (player: Player, covered: boolean, seconds: number) -> (),
	-- Runs `run` after `seconds`; absent = task.delay.
	after: ((seconds: number, run: () -> ()) -> ())?,
	-- Streams the area around `position` in for the player; absent = Player:RequestStreamAroundAsync.
	stream: ((player: Player, position: Vector3) -> ())?,
}

export type OfficeEntranceSystem = {
	-- Takes the entrances' interacts; returns the stopper.
	start: () -> () -> (),
	-- `player` used entrance `entranceId`'s `kind` part at server time `now`: starts the teleport. False when refused.
	request: (player: Player, kind: string, entranceId: OfficeTypes.EntranceId, now: number) -> boolean,
}

local OfficeEntranceSystem = {}

--[=[
	Where a teleport of `kind` sets the player down: the inside frame to enter, the outside frame to leave.
]=]
function OfficeEntranceSystem.target(kind: string, outsideFrame: CFrame, insideFrame: CFrame): CFrame
	return if kind == OfficeConstants.ENTER_KIND then insideFrame else outsideFrame
end

--[=[
	Whether a request may teleport: on the crew, alive, within ENTRANCE_REACH of the part used, nothing pending.
]=]
function OfficeEntranceSystem.allowed(state: State): boolean
	return state.inCrew and state.alive and state.distance <= OUTSIDE.ENTRANCE_REACH and not state.pending
end

--[=[
	Moves `character` so its root stands at `frame`, with everything welded to it (what Carry holds) along: setting
	the root's CFrame moves its whole assembly. Its momentum is cleared.
]=]
function OfficeEntranceSystem.teleport(character: Model, frame: CFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	root.CFrame = frame
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function asEntranceId(value: unknown): OfficeTypes.EntranceId?
	if value == "dock" then
		return "dock"
	elseif value == "lobby" then
		return "lobby"
	end
	return nil
end

local function taggedParts(kind: string, id: OfficeTypes.EntranceId): { BasePart }
	local found: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(InteractionConstants.TAG) do
		if
			instance:IsA("BasePart")
			and instance:GetAttribute(InteractionConstants.KIND_ATTRIBUTE) == kind
			and instance:GetAttribute("EntranceId") == id
		then
			table.insert(found, instance)
		end
	end
	return found
end

local function realStream(player: Player, position: Vector3)
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(position, STREAM_TIMEOUT)
	end)
	if not ok then
		log:debug(`stream around for {player.Name} failed: {tostring(err)}`)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

function OfficeEntranceSystem.new(deps: Deps): OfficeEntranceSystem
	local partsOf: (kind: string, id: OfficeTypes.EntranceId) -> { BasePart } = deps.parts or taggedParts
	local after: (seconds: number, run: () -> ()) -> () = deps.after
		or function(seconds: number, run: () -> ())
			task.delay(seconds, run)
		end
	local stream: (player: Player, position: Vector3) -> () = deps.stream or realStream
	-- userId -> the server time the pending teleport stops blocking new requests.
	local pending: { [number]: number } = {}
	-- Bumped by the stopper: a teleport requested before a stop never lands after it.
	local generation = 0

	local function isAlive(player: Player, root: BasePart): boolean
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid == nil or humanoid.Health <= 0 or root.Anchored then
			return false
		end
		return deps.alive == nil or deps.alive(player)
	end

	local function distanceTo(parts: { BasePart }, position: Vector3): number
		local nearest = math.huge
		for _, part in parts do
			nearest = math.min(nearest, (part.Position - position).Magnitude)
		end
		return nearest
	end

	local system: OfficeEntranceSystem
	system = {
		start = function()
			for _, kind in { OfficeConstants.ENTER_KIND, OfficeConstants.LEAVE_KIND } do
				InteractionServiceServer:onInteract(kind, function(player, target)
					local id: OfficeTypes.EntranceId? = asEntranceId(target:GetAttribute("EntranceId"))
					if id ~= nil then
						system.request(player, kind, id, Workspace:GetServerTimeNow())
					end
				end)
			end
			-- Interaction keeps one handler per kind for the session; stopping drops every pending teleport.
			return function()
				generation += 1
				table.clear(pending)
			end
		end,

		request = function(player, kind, entranceId, now)
			if kind ~= OfficeConstants.ENTER_KIND and kind ~= OfficeConstants.LEAVE_KIND then
				return false
			end
			local root = rootOf(player)
			local outsideFrame, insideFrame = deps.entrance(entranceId)
			if root == nil or outsideFrame == nil or insideFrame == nil then
				return false
			end
			local userId = player.UserId
			local blockedUntil = pending[userId]
			local ok = OfficeEntranceSystem.allowed({
				inCrew = deps.inCrew(player),
				alive = isAlive(player, root),
				distance = distanceTo(partsOf(kind, entranceId), root.Position),
				pending = blockedUntil ~= nil and now < blockedUntil,
			})
			if not ok then
				return false
			end
			pending[userId] = now + PENDING_SECONDS
			deps.fade(player, true, OUTSIDE.FADE_OUT)
			local character = player.Character
			local requested = generation
			-- Whether the teleport may still land: the same character, alive and not caught, still on the running
			-- shift's crew and working, and the system not stopped since the request.
			local function stillGoing(): boolean
				local current = rootOf(player)
				return requested == generation
					and character ~= nil
					and player.Character == character
					and current ~= nil
					and isAlive(player, current)
					and deps.inCrew(player)
			end
			-- Caught, killed, respawned, clocked out or the shift over during the fade or the stream: they stay put.
			local function land()
				if not stillGoing() then
					return
				end
				-- The frames now (the office could have been rebuilt since the request).
				local outsideNow, insideNow = deps.entrance(entranceId)
				if outsideNow == nil or insideNow == nil or character == nil then
					return
				end
				local frame = OfficeEntranceSystem.target(kind, outsideNow, insideNow)
					+ Vector3.new(0, OfficeConstants.SPAWN_HEIGHT, 0)
				-- Streaming yields (up to STREAM_TIMEOUT): a catch or the shift's end can come meanwhile.
				stream(player, frame.Position)
				if stillGoing() then
					OfficeEntranceSystem.teleport(character, frame)
				end
			end
			after(OUTSIDE.FADE_OUT, function()
				local moved, err = pcall(function()
					land()
				end)
				if not moved then
					log:warn(`{kind} {entranceId} for {player.Name} failed: {tostring(err)}`)
				end
				-- Clear first: a failing send (the player just left) must not leave the entrance pending.
				if requested == generation then
					pending[userId] = nil
				end
				local sent, sendErr = pcall(function()
					deps.fade(player, false, OUTSIDE.FADE_IN)
				end)
				if not sent then
					log:warn(`fade-in for {player.Name} failed: {tostring(sendErr)}`)
				end
			end)
			return true
		end,
	}
	return system
end

return OfficeEntranceSystem
