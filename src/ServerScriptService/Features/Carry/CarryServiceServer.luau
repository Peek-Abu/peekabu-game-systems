--!strict
--[=[
	CarryServiceServer: server-owned carrying of tagged world objects (design:
	docs/superpowers/specs/2026-10-09-carry-design.md).

	Objects tagged `Carryable` (with a registered `CarryKind`) are made interactable with the `carry`
	interaction kind, so picking up goes through Interaction's prompt and checks. A held object is welded
	to the carrier's body where its hold puts it (AnimationCarrySystem.mount: the UpperTorso for an item on the
	forearms, the right hand for a hanging bag, the HumanoidRootPart for a cart), so it moves with the idle, walk and
	run like part of the character (massless and non-colliding while held: no physics fight), slows the carrier
	by its weight, and is published (`CarriedBy` attribute, public `carrying` field). Drop / throw arrive
	as validated packets; death, respawn and leaving drop it. Whatever is put down or thrown stays inside
	the building (CarryPlacementSystem: no placement through a wall or off the carrier's floor, no
	tunnelling). `forceDrop` is the hook for game rules (stealing an egg is forceDrop on the victim, then
	pickUp for the thief).
	`pickedUp` / `dropped(player, object, reason)` signals let a game react (banking, noise, analytics).

	Spec-exempt shell (Instances, physics, Players, ByteNet); the rules are the specced CarryRegistry,
	CarryFormulas and CarryHoldTracker.

	@class CarryServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CarryShared = ReplicatedStorage.Shared.Features.Carry
local InteractionData = ReplicatedStorage.Shared.Features.Interaction.Data
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CarryConstants = require(CarryShared.Data.CarryConstants)
local CarryRegistry = require(CarryShared.Data.CarryRegistry)
local CarryTypes = require(CarryShared.Data.CarryTypes)
local CarryFormulas = require(CarryShared.Utils.CarryFormulas)
local CarryCarrierRules = require(CarryShared.Rules.CarryCarrierRules)
local CarryEvents = require(CarryShared.Net.CarryEvents)
local InteractionConstants = require(InteractionData.InteractionConstants)
local InteractionRegistry = require(InteractionData.InteractionRegistry)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CarryHoldTracker = require(ServerScriptService.Features.Carry.State.CarryHoldTracker)
local CarryPlacementSystem = require(ServerScriptService.Features.Carry.Systems.CarryPlacementSystem)
local AnimationCarrySystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySystem)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

-- Pick-up is an ordinary interaction kind; registered here so every carryable shares it.
if not InteractionRegistry.has(CarryConstants.INTERACTION_KIND) then
	InteractionRegistry.register(CarryConstants.INTERACTION_KIND, { actionText = "Pick up" })
end

type SavedPart = { part: BasePart, massless: boolean, canCollide: boolean }

type Held = {
	target: PVInstance,
	root: BasePart,
	kind: string,
	weld: JointInstance,
	contact: AnimationCarrySystem.Controller?,
	saved: { SavedPart },
	humanoid: Humanoid?,
	savedWalkSpeed: number?,
}

local log = Logger.new("CarryServiceServer")

local pickedUp: SignalTyped.Signal<Player, Instance> = SignalTyped.new()
local dropped: SignalTyped.Signal<Player, Instance, CarryTypes.DropReason> = SignalTyped.new()

local holds = CarryHoldTracker.new()
local objectIds: { [Instance]: number } = {}
local objectsById: { [number]: Instance } = {}
local nextObjectId = 0
local held: { [number]: Held } = {} -- by UserId
local counters = { pickedUp = 0, dropped = 0, thrown = 0, refused = 0 }
local stoppers: { () -> () } = {}

local function rootPartOf(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function kindOf(target: Instance): string?
	local kind = target:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	return if type(kind) == "string" and CarryRegistry.has(kind) then kind else nil
end

local function partsOf(target: Instance): { BasePart }
	local parts: { BasePart } = {}
	if target:IsA("BasePart") then
		table.insert(parts, target)
	end
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Ends a hold: unwelds and restores the object, restores the carrier's speed, clears the published
-- state. Returns the object's root part (so a throw can launch it), or nil when nothing was held.
local function release(player: Player): BasePart?
	local state = held[player.UserId]
	holds:release(player.UserId)
	if state == nil then
		return nil
	end
	held[player.UserId] = nil
	if state.contact ~= nil then
		state.contact.destroy()
	end
	state.weld:Destroy()
	for _, saved in state.saved do
		saved.part.Massless = saved.massless
		saved.part.CanCollide = saved.canCollide
	end
	local humanoid = state.humanoid
	local speed = state.savedWalkSpeed
	if humanoid ~= nil and speed ~= nil and humanoid.Parent ~= nil then
		humanoid.WalkSpeed = speed
	end
	state.target:SetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE, nil)
	state.target:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, nil)
	StateSyncPublicPlayerStore.clearField(player.UserId, CarryConstants.PUBLIC_FIELD)
	return state.root
end

local function playerRootOf(player: Player): BasePart?
	local character = player.Character
	local playerRoot = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if playerRoot ~= nil and playerRoot:IsA("BasePart") then playerRoot else nil
end

-- Moves `target` (pivot at `desired`) to the nearest point on the way out from the player's root that stays
-- inside (CarryPlacementSystem.placeInside).
local function placeInside(player: Player, target: PVInstance, desired: CFrame)
	local playerRoot = playerRootOf(player)
	if playerRoot ~= nil then
		CarryPlacementSystem.placeInside(playerRoot.Position, target, desired)
	end
end

-- Places a released object in front of where the player stands (or leaves it where it is).
local function placeDropped(player: Player, root: BasePart, target: PVInstance)
	local playerRoot = playerRootOf(player)
	if playerRoot ~= nil then
		placeInside(player, target, playerRoot.CFrame * CarryConstants.DROP_OFFSET)
	end
	root.Anchored = false
end

export type CarryServiceServer = {
	dependencies: { string },
	pickedUp: SignalTyped.Signal<Player, Instance>,
	dropped: SignalTyped.Signal<Player, Instance, CarryTypes.DropReason>,
	start: (self: CarryServiceServer) -> (),
	stop: (self: CarryServiceServer) -> (),
	getState: (self: CarryServiceServer) -> { [string]: any },
	pickUp: (self: CarryServiceServer, player: Player, target: Instance) -> (boolean, string?),
	drop: (self: CarryServiceServer, player: Player) -> boolean,
	throw: (self: CarryServiceServer, player: Player, aim: Vector3) -> (boolean, string?),
	forceDrop: (self: CarryServiceServer, player: Player, reason: CarryTypes.DropReason?) -> boolean,
	getCarried: (self: CarryServiceServer, player: Player) -> Instance?,
}

local CarryServiceServer: CarryServiceServer

local onDrop = RequestHandler.wrap({
	name = "CarryDrop",
	rateLimitKey = "Carry",
	rateLimit = { maxRequests = 10, windowSeconds = 5 },
	handler = function(_data: unknown, player: Player)
		CarryServiceServer:drop(player)
	end,
})

local onThrow = RequestHandler.wrap({
	name = "CarryThrow",
	rateLimitKey = "Carry",
	rateLimit = { maxRequests = 10, windowSeconds = 5 },
	handler = function(data: unknown, player: Player)
		if typeof(data) == "Vector3" then
			CarryServiceServer:throw(player, data)
		end
	end,
})

CarryServiceServer = {
	dependencies = { "InteractionServiceServer" },
	pickedUp = pickedUp,
	dropped = dropped,

	--[=[
		Makes tagged objects interactable, handles the `carry` interaction, drops on death / respawn /
		leave, and listens for drop and throw requests.
	]=]
	start = function(self)
		InteractionServiceServer:onInteract(CarryConstants.INTERACTION_KIND, function(player, target)
			local ok, reason = self:pickUp(player, target)
			if not ok then
				log:debug(`pick-up refused for {player.Name}: {reason or "?"}`)
			end
		end)

		table.insert(
			stoppers,
			Observers.observeTag(CarryConstants.TAG, function(target: Instance)
				if kindOf(target) == nil then
					log:warn(
						`{target:GetFullName()} is Carryable but has no registered {CarryConstants.KIND_ATTRIBUTE}`
					)
					return nil
				end
				nextObjectId += 1
				local objectId = nextObjectId
				objectIds[target] = objectId
				objectsById[objectId] = target
				target:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, CarryConstants.INTERACTION_KIND)
				CollectionService:AddTag(target, InteractionConstants.TAG)
				return function()
					local holder = holds:holderOf(objectId)
					local player = if holder ~= nil then Players:GetPlayerByUserId(holder) else nil
					if player ~= nil then
						release(player)
						dropped:Fire(player, target, "destroyed")
					end
					objectIds[target] = nil
					objectsById[objectId] = nil
				end
			end)
		)

		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, character: Model)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local died = if humanoid ~= nil
					then humanoid.Died:Connect(function()
						self:forceDrop(player, "death")
					end)
					else nil
				return function()
					if died ~= nil then
						died:Disconnect()
					end
					self:forceDrop(player, "removed")
				end
			end)
		)

		table.insert(
			stoppers,
			CarryEvents.packets.Drop.listen(function(data: boolean, player: Player?)
				if player then
					onDrop(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			CarryEvents.packets.Throw.listen(function(data: Vector3, player: Player?)
				if player then
					onThrow(data, player)
				end
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Picks `target` up for `player`. Refuses (with a reason) an unregistered object, one already held,
		a player already carrying, or a player with no character.
	]=]
	pickUp = function(_self, player, target)
		local kind = kindOf(target)
		local objectId = objectIds[target]
		local root = rootPartOf(target)
		if kind == nil or objectId == nil or root == nil or not target:IsA("PVInstance") then
			counters.refused += 1
			return false, "not carryable"
		end
		local def = CarryRegistry.get(kind)
		local character = player.Character
		local playerRoot = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if
			def == nil
			or playerRoot == nil
			or not playerRoot:IsA("BasePart")
			or not CarryCarrierRules.isAlive(if humanoid ~= nil then humanoid.Health else nil)
		then
			counters.refused += 1
			return false, "no character"
		end
		if not holds:hold(player.UserId, objectId) then
			counters.refused += 1
			return false, "already carrying, or already carried"
		end

		local saved: { SavedPart } = {}
		for _, part in partsOf(target) do
			table.insert(saved, { part = part, massless = part.Massless, canCollide = part.CanCollide })
			part.Massless = true
			part.CanCollide = false
		end
		root.Anchored = false
		local prepared = if character ~= nil
			then AnimationCarrySystem.prepare(character, target, kind, def.holdOffset)
			else nil
		target:PivotTo(
			if prepared ~= nil
				then prepared.pivot
				else playerRoot.CFrame * (def.holdOffset or CarryConstants.DEFAULT_HOLD_OFFSET)
		)
		local contact: AnimationCarrySystem.Controller? = nil
		local joint: AnimationCarrySystem.Mount = {
			part = playerRoot,
			c0 = playerRoot.CFrame:ToObjectSpace(root.CFrame),
			c1 = CFrame.identity,
			swings = false,
		}
		if prepared ~= nil and character ~= nil then
			-- The contacts are on the item's visible art, not its invisible proxy (AnimationCarrySystem.visibleBox).
			local boxFromRoot = root.CFrame:ToObjectSpace(target:GetPivot() * prepared.box)
			local layout: AnimationCarrySystem.Layout = {
				offset = prepared.layout.offset,
				right = boxFromRoot * prepared.layout.right,
				left = if prepared.layout.left ~= nil then boxFromRoot * prepared.layout.left else nil,
				under = prepared.layout.under,
				hang = prepared.layout.hang,
				hug = prepared.layout.hug,
				mount = prepared.layout.mount,
			}
			contact = AnimationCarrySystem.bind(character, root, layout)
			joint = AnimationCarrySystem.mount(character, root, layout) or joint
		end
		-- Part of the character's assembly while held, on the body part its hold rides (so it inherits the animation).
		-- A hanging bag's joint is a Motor6D at its handle: every client swings it there (CarrySwaySystem); the server
		-- never moves it, so its physics stay those of a weld.
		local weld: JointInstance = if joint.swings then Instance.new("Motor6D") else Instance.new("Weld")
		weld.Name = "CarryWeld"
		weld.Part0 = joint.part
		weld.Part1 = root
		weld.C0 = joint.c0
		weld.C1 = joint.c1
		weld.Parent = root
		if joint.swings then
			CollectionService:AddTag(weld, CarryConstants.HANG_TAG)
		end

		local savedWalkSpeed = if humanoid ~= nil then humanoid.WalkSpeed else nil
		if humanoid ~= nil and savedWalkSpeed ~= nil then
			humanoid.WalkSpeed = CarryFormulas.walkSpeedFor(
				savedWalkSpeed,
				def.weight,
				CarryConstants.SLOW_PER_WEIGHT,
				CarryConstants.MIN_SPEED_MULTIPLIER
			)
		end
		held[player.UserId] = {
			target = target,
			root = root,
			kind = kind,
			weld = weld,
			contact = contact,
			saved = saved,
			humanoid = humanoid,
			savedWalkSpeed = savedWalkSpeed,
		}
		target:SetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE, player.UserId)
		-- Nobody can pick up what someone is already holding.
		target:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, false)
		StateSyncPublicPlayerStore.set(player.UserId, { [CarryConstants.PUBLIC_FIELD] = kind })
		counters.pickedUp += 1
		pickedUp:Fire(player, target)
		return true, nil
	end,

	--[=[
		Drops what `player` carries in front of them. False when they carry nothing.
	]=]
	drop = function(_self, player)
		local state = held[player.UserId]
		local root = release(player)
		if state == nil or root == nil then
			return false
		end
		placeDropped(player, root, state.target)
		counters.dropped += 1
		dropped:Fire(player, state.target, "drop")
		return true
	end,

	--[=[
		Throws what `player` carries along `aim` (normalized here; a malformed aim is refused). Refuses a
		kind that is not throwable.
	]=]
	throw = function(_self, player, aim)
		local state = held[player.UserId]
		if state == nil then
			return false, "not carrying"
		end
		local def = CarryRegistry.get(state.kind)
		if def == nil or def.throwable ~= true then
			return false, "not throwable"
		end
		local velocity = CarryFormulas.throwVelocity(
			aim,
			def.throwSpeed or CarryConstants.DEFAULT_THROW_SPEED,
			CarryConstants.THROW_LIFT
		)
		if velocity == nil then
			counters.refused += 1
			return false, "bad aim"
		end
		local root = release(player)
		if root == nil then
			return false, "not carrying"
		end
		placeDropped(player, root, state.target)
		root.AssemblyLinearVelocity = velocity
		-- However fast it flies, it cannot tunnel out of the building.
		CarryPlacementSystem.watch(
			root,
			CarryPlacementSystem.ignoreFor(state.target),
			CarryPlacementSystem.marginFor(state.target),
			CarryConstants.THROW_GUARD_SECONDS
		)
		counters.thrown += 1
		dropped:Fire(player, state.target, "throw")
		return true, nil
	end,

	--[=[
		Drops whatever `player` carries, where it is (death, leaving, or a game rule). `reason` is reported
		on `dropped` (default "forced"). False when nothing.
	]=]
	forceDrop = function(_self, player, reason)
		local state = held[player.UserId]
		local root = release(player)
		if state == nil or root == nil then
			return false
		end
		-- Where it was held, unless that was through a wall the carrier stood against (judged from the carrier's
		-- own body: not from a respawned one).
		local humanoid = state.humanoid
		if humanoid ~= nil and player.Character ~= nil and humanoid.Parent == player.Character then
			placeInside(player, state.target, state.target:GetPivot())
		end
		root.Anchored = false
		counters.dropped += 1
		dropped:Fire(player, state.target, reason or "forced")
		return true
	end,

	getCarried = function(_self, player)
		local state = held[player.UserId]
		return if state ~= nil then state.target else nil
	end,

	getState = function(_self)
		local carriers = 0
		for _ in held do
			carriers += 1
		end
		local objects = 0
		for _ in objectsById do
			objects += 1
		end
		return { carriers = carriers, objects = objects, counters = table.clone(counters) }
	end,
}

return CarryServiceServer
