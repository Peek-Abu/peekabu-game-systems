--!strict
--[=[
	HideServiceServer: hiding spots (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §4). Players hide
	under desks and tables (HideSpotSystem makes a spot of every piece Office tags). Server-authoritative throughout:

	- In: a single press of the spot's prompt (C / L1, or a tap on the phone's chip). Re-checked here (HideRules: alive,
	  not frozen in a catch, not hidden, the spot free and not cooling off for them, rested REENTER_SECONDS since their
	  last stay, in range, empty-handed or holding a pocketable tiny item). The root is anchored and slides into the
	  spot's hiding frame in TUCK_SECONDS (HideSpotUtils), the spot's prompt closes, and the Player's HideSpotId /
	  HideSince attributes tell every client (the peek camera on theirs, the tucked pose on everyone's,
	  HidePoseSystem). Whether the Manager saw them go in is asked of the
	  witness (`setWitness`, OccupantServiceServer) at that moment and kept for the stay (`seenEntering`).
	- Out: the client's Exit request (a tap, not before MIN_STAY_SECONDS), or a rule: after CAMP_SECONDS in one spot they are pushed out ("cramped") and that
	  spot refuses them SPOT_COOLDOWN_SECONDS; `evict` (the Manager's catch, the behaviours to come); their character
	  dying or going; the furniture going (the office rebuilds each shift); picking up something too big. The body comes
	  out at the first clear exit (in front, behind, either side).
	- API for the Manager's behaviours (the stare-down, sitting at the desk you are under):
	  `isHidden`, `spotOf`, `seenEntering`, `setSeen`, `evict`, `spots`, `occupantOf`, `hold` (the camping push-out
	  waits while he is at your spot), and the `entered` / `exited` signals.

	Spec-exempt shell (Instances, Players, ByteNet, signals); the decisions are the specced HideRules, HideSpotUtils and
	HideOccupancyTracker.

	@class HideServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local HideShared = ReplicatedStorage.Shared.Features.Hide
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local HideConstants = require(HideShared.Data.HideConstants)
local HideTypes = require(HideShared.Data.HideTypes)
local HideEvents = require(HideShared.Net.HideEvents)
local HideRules = require(HideShared.Rules.HideRules)
local HideSpotUtils = require(HideShared.Utils.HideSpotUtils)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local HideOccupancyTracker = require(ServerScriptService.Features.Hide.State.HideOccupancyTracker)
local HideSpotSystem = require(ServerScriptService.Features.Hide.Systems.HideSpotSystem)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

type Spot = HideTypes.Spot
type SpotInfo = HideTypes.SpotInfo
type ExitReason = HideTypes.ExitReason
-- Whether the Manager sees this player right now (asked as they go in). Must not yield.
export type Witness = (player: Player) -> boolean

local log = Logger.new("HideServiceServer")

local entered: SignalTyped.Signal<Player, SpotInfo> = SignalTyped.new()
local exited: SignalTyped.Signal<Player, string, ExitReason> = SignalTyped.new()
local tracker = HideOccupancyTracker.new()
local witness: Witness? = nil
local counters: { [string]: number } =
	{ entered = 0, seen = 0, left = 0, cramped = 0, evicted = 0, gone = 0, refused = 0 }
-- The body each hiding player went in with (a respawn's new character is never moved by an old stay).
local bodies: { [number]: { root: BasePart, humanoid: Humanoid, entry: CFrame, tween: Tween } } = {}
-- When each player's last stay ended (os.clock), for the re-entry rest.
local lastLeft: { [number]: number } = {}
-- Until when each hiding player's camping push-out is held (os.clock): the Manager is at their spot.
local holds: { [number]: number } = {}
local stoppers: { () -> () } = {}
local campElapsed = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
end

-- The size of what the player holds (nil when empty-handed; "unknown" for a held thing that is not cargo).
local function heldSize(player: Player): string?
	local carried = CarryServiceServer:getCarried(player)
	if carried == nil then
		return nil
	end
	local kind = carried:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	return if def ~= nil then def.size else "unknown"
end

-- The root's height over the feet: where a standing character's root sits.
local function standHeight(root: BasePart, humanoid: Humanoid): number
	return humanoid.HipHeight + root.Size.Y / 2
end

local spotSystem: HideSpotSystem.HideSpotSystem

local function infoOf(player: Player): SpotInfo?
	local stay = tracker:of(player.UserId)
	local spot = if stay ~= nil then spotSystem:get(stay.spotId) else nil
	if stay == nil or spot == nil then
		return nil
	end
	return {
		id = spot.id,
		kind = spot.kind,
		noun = spot.noun,
		furniture = spot.furniture,
		position = spot.furniture.Position,
		since = stay.since,
		seenEntering = stay.seenEntering,
	}
end

-- The first exit with room for a body (nothing collidable but the furniture's own parts), else the front one.
local function exitFrame(spot: Spot, root: BasePart, humanoid: Humanoid, entry: CFrame?): CFrame
	local frames = HideSpotUtils.frames(spot.noun, spot.frame, spot.furniture.Size, standHeight(root, humanoid))
	local exclude: { Instance } = { spot.furniture }
	for _, other in Players:GetPlayers() do
		if other.Character ~= nil then
			table.insert(exclude, other.Character)
		end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = exclude
	overlap.RespectCanCollide = true
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Exclude
	rays.FilterDescendantsInstances = exclude
	rays.RespectCanCollide = true
	-- The front of the furniture at waist height: an exit must be reachable from it with no wall between.
	local size = spot.furniture.Size
	local mouth = (spot.frame * CFrame.new(0, -size.Y / 2 + 2, -size.Z / 2)).Position
	local function usable(frame: CFrame): boolean
		local at = frame.Position
		-- Room for a body (clear of the floor and its carpet skin), a floor under it, and no wall in the way.
		local body = frame * CFrame.new(0, HideConstants.EXIT_PROBE.Y / 2 - standHeight(root, humanoid) + 0.6, 0)
		return #Workspace:GetPartBoundsInBox(body, HideConstants.EXIT_PROBE, overlap) == 0
			and Workspace:Raycast(at, Vector3.new(0, -(standHeight(root, humanoid) + 3), 0), rays) ~= nil
			and Workspace:Raycast(mouth, Vector3.new(at.X, mouth.Y, at.Z) - mouth, rays) == nil
	end
	-- Back where they went in from first, then in front, behind, either side.
	local candidates = table.clone(frames.exits)
	if entry ~= nil then
		table.insert(candidates, 1, entry)
	end
	for _, frame in candidates do
		if usable(frame) then
			return frame
		end
	end
	return entry or frames.exits[1]
end

-- Ends a stay: the body comes out (unless its character is gone), the spot reopens, the attributes clear.
local function leave(player: Player, reason: ExitReason): boolean
	local current = tracker:of(player.UserId)
	if current == nil or (reason == "left" and not HideRules.canLeave(os.clock() - current.since)) then
		return false
	end
	local stay = tracker:leave(player.UserId)
	if stay == nil then
		return false
	end
	lastLeft[player.UserId] = os.clock()
	holds[player.UserId] = nil
	player:SetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE, nil)
	player:SetAttribute(HideConstants.PLAYER_SINCE_ATTRIBUTE, nil)
	local spot = spotSystem:get(stay.spotId)
	if spot ~= nil then
		spotSystem:setOpen(spot.id, true)
	end
	local body = bodies[player.UserId]
	bodies[player.UserId] = nil
	if body ~= nil then
		body.tween:Cancel()
	end
	if body ~= nil and body.root.Parent ~= nil then
		-- A living body comes out at an exit (also when the furniture went with them in it); a dead one just drops.
		if spot ~= nil and body.humanoid.Health > 0 then
			body.root.CFrame = exitFrame(spot, body.root, body.humanoid, body.entry)
		end
		body.root.Anchored = false
	end
	if reason == "cramped" then
		tracker:cool(player.UserId, stay.spotId, os.clock() + HideConstants.SPOT_COOLDOWN_SECONDS)
		ToastServiceServer:send(player, {
			text = "Too cramped in there: you had to climb out.",
			style = "sticky",
			duration = 3,
		})
	end
	counters[reason] = (counters[reason] or 0) + 1
	exited:Fire(player, stay.spotId, reason)
	return true
end

-- Puts `player` into `spot` if the rules allow. Never yields.
local function enter(player: Player, spot: Spot): (boolean, string?)
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	local now = os.clock()
	local ok, reason = HideRules.canEnter({
		alive = root ~= nil and humanoid ~= nil and humanoid.Health > 0 and not DeathServiceServer:isDead(player),
		-- A frozen root is a catch in progress (the Manager anchors it).
		catching = root ~= nil and root.Anchored,
		hidden = tracker:of(player.UserId) ~= nil,
		heldSize = heldSize(player),
		occupied = tracker:occupant(spot.id) ~= nil,
		cooling = tracker:cooling(player.UserId, spot.id, now),
		rested = now - (lastLeft[player.UserId] or -math.huge) >= HideConstants.REENTER_SECONDS,
		distance = if root ~= nil then (root.Position - spot.anchor.WorldPosition).Magnitude else math.huge,
	})
	if not ok or root == nil or humanoid == nil then
		counters.refused += 1
		return false, reason
	end
	local check = witness
	local seen = check ~= nil and check(player)
	tracker:enter(player.UserId, spot.id, now, seen)
	local frames = HideSpotUtils.frames(spot.noun, spot.frame, spot.furniture.Size, standHeight(root, humanoid))
	-- A quick slide in, not a teleport.
	local tween = TweenService:Create(
		root,
		TweenInfo.new(HideConstants.TUCK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = frames.hide }
	)
	bodies[player.UserId] = { root = root, humanoid = humanoid, entry = root.CFrame, tween = tween }
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	tween:Play()
	spotSystem:setOpen(spot.id, false)
	player:SetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE, spot.id)
	player:SetAttribute(HideConstants.PLAYER_SINCE_ATTRIBUTE, Workspace:GetServerTimeNow())
	counters.entered += 1
	if seen then
		counters.seen += 1
	end
	local info = infoOf(player)
	if info ~= nil then
		entered:Fire(player, info)
	end
	return true, nil
end

spotSystem = HideSpotSystem.new({
	onTrigger = function(player, spot)
		local ok, reason = enter(player, spot)
		if not ok then
			log:debug(`{player.Name} cannot hide in {spot.id}: {reason or "?"}`)
		end
	end,
	onRemoved = function(spot)
		local userId = tracker:occupant(spot.id)
		local player = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
		if player ~= nil then
			leave(player, "gone")
		end
	end,
})

local onExit = RequestHandler.wrap({
	name = "HideExit",
	rateLimitKey = "Hide",
	rateLimit = HideConstants.EXIT_RATE,
	handler = function(_data: unknown, player: Player)
		leave(player, "left")
	end,
})

-- Every quarter second: pushes out whoever camped too long.
local function onHeartbeat(deltaTime: number)
	campElapsed += deltaTime
	if campElapsed < 0.25 then
		return
	end
	campElapsed = 0
	local now = os.clock()
	for userId, stay in tracker:all() do
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			tracker:leave(userId)
			bodies[userId] = nil
		elseif HideRules.camp(now - stay.since) == "out" and now >= (holds[userId] or 0) then
			leave(player, "cramped")
		end
	end
end

export type HideServiceServer = {
	dependencies: { string },
	entered: SignalTyped.Signal<Player, SpotInfo>,
	exited: SignalTyped.Signal<Player, string, ExitReason>,
	start: (self: HideServiceServer) -> (),
	stop: (self: HideServiceServer) -> (),
	getState: (self: HideServiceServer) -> { [string]: any },
	isHidden: (self: HideServiceServer, player: Player) -> boolean,
	spotOf: (self: HideServiceServer, player: Player) -> SpotInfo?,
	seenEntering: (self: HideServiceServer, player: Player) -> boolean,
	setSeen: (self: HideServiceServer, player: Player, seen: boolean) -> boolean,
	evict: (self: HideServiceServer, player: Player, reason: ExitReason?) -> boolean,
	enter: (self: HideServiceServer, player: Player, spotId: string) -> (boolean, string?),
	spots: (self: HideServiceServer) -> { Spot },
	occupantOf: (self: HideServiceServer, spotId: string) -> Player?,
	setWitness: (self: HideServiceServer, check: Witness?) -> (),
	hold: (self: HideServiceServer, player: Player, untilTime: number) -> boolean,
}

local HideServiceServer: HideServiceServer = {
	dependencies = { "CarryServiceServer", "DeathServiceServer", "ToastServiceServer" },
	entered = entered,
	exited = exited,

	--[=[
		Builds a spot on every tagged piece of furniture, listens for Exit requests, and lets go of anyone whose
		character dies or goes, or who picks up something too big to hide with.
	]=]
	start = function(_self)
		table.insert(stoppers, spotSystem:start())
		table.insert(
			stoppers,
			HideEvents.packets.Exit.listen(function(data: boolean, player: Player?)
				if player then
					onExit(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, character: Model)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local died = if humanoid ~= nil
					then humanoid.Died:Connect(function()
						leave(player, "gone")
					end)
					else nil
				return function()
					if died ~= nil then
						died:Disconnect()
					end
					leave(player, "gone")
				end
			end)
		)
		local lifted = CarryServiceServer.pickedUp:Connect(function(player: Player)
			if tracker:of(player.UserId) ~= nil and heldSize(player) ~= HideConstants.POCKETABLE_SIZE then
				leave(player, "evicted")
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
			tracker:leave(player.UserId)
			bodies[player.UserId] = nil
			lastLeft[player.UserId] = nil
		end)
		local heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
		table.insert(stoppers, function()
			lifted:Disconnect()
			leaving:Disconnect()
			heartbeat:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, player in Players:GetPlayers() do
			leave(player, "gone")
		end
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		tracker:clear()
		table.clear(bodies)
		table.clear(lastLeft)
		table.clear(holds)
	end,

	isHidden = function(_self, player)
		return tracker:of(player.UserId) ~= nil
	end,

	--[=[
		The spot `player` hides in (its furniture, kind, since when and whether the Manager saw them go in), or nil.
	]=]
	spotOf = function(_self, player)
		return infoOf(player)
	end,

	--[=[
		Whether the Manager saw `player` go into the spot they hide in (false when not hiding).
	]=]
	seenEntering = function(_self, player)
		local stay = tracker:of(player.UserId)
		return stay ~= nil and stay.seenEntering
	end,

	--[=[
		Marks a hiding player as seen (or not) by the Manager from now on: a behaviour that finds them. False when they
		are not hiding.
	]=]
	setSeen = function(_self, player, seen)
		return tracker:setSeen(player.UserId, seen)
	end,

	--[=[
		Forces `player` out of their spot (default reason "evicted"): the Manager opening it, a catch. False when they
		were not hiding.
	]=]
	evict = function(_self, player, reason)
		return leave(player, reason or "evicted")
	end,

	--[=[
		Puts `player` into the spot `spotId` as its prompt would, with every check. A server hook (tests, admin).
	]=]
	enter = function(_self, player, spotId)
		local spot = spotSystem:get(spotId)
		if spot == nil then
			return false, "no such spot"
		end
		return enter(player, spot)
	end,

	--[=[
		Every hiding spot in the office now, sorted by id.
	]=]
	spots = function(_self)
		return spotSystem:list()
	end,

	occupantOf = function(_self, spotId)
		local userId = tracker:occupant(spotId)
		return if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	end,

	--[=[
		Sets THE witness: whether the Manager sees a player as they go in (OccupantServiceServer). Nil = nobody sees.
	]=]
	setWitness = function(_self, check)
		witness = check
	end,

	--[=[
		Holds a hiding player's camping push-out until `untilTime` (os.clock): the Manager stands at or sits over their
		spot, so being cramped never throws them into his lap. False when they are not hiding.
	]=]
	hold = function(_self, player, untilTime)
		if tracker:of(player.UserId) == nil then
			return false
		end
		holds[player.UserId] = math.max(holds[player.UserId] or 0, untilTime)
		return true
	end,

	getState = function(_self)
		local hidden: { [string]: string } = {}
		for userId, stay in tracker:all() do
			hidden[tostring(userId)] = `{stay.spotId}{if stay.seenEntering then " (seen)" else ""}`
		end
		return { spots = #spotSystem:list(), hidden = hidden, counters = table.clone(counters) }
	end,
}

return HideServiceServer
