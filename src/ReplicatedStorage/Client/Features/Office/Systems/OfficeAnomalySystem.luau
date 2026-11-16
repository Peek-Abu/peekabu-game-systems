--!strict
--[=[
	OfficeAnomalySystem: plays the run's exterior anomalies on this client. The server publishes the run's ids on
	Workspace.CleanupCrewOffice (OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE, comma-joined; the model is rebuilt every
	shift and the admin `anomaly` command republishes); the slots are the OfficeExterior Models tagged SLOT_TAG with
	their id in SLOT_ATTRIBUTE, built in their default state. It caches the published set and the run's LayoutSeed
	from the model's attribute-changed signals (and the model being rebuilt), and every Heartbeat decides per slot
	(OfficeAnomalyUtils.slotAction) whether to apply, reset, re-apply for a new run or refresh it, so a new run or
	`none` puts each slot back exactly as it was built (every property it touches is captured on apply and written
	back on reset; what it adds is destroyed). Time is Workspace:GetServerTimeNow(), so co-op players see the
	welcome screen's wrong line together.

	Streaming is on: slots are tracked by the tag's added/removed signals; a slot streaming out is reset and
	forgotten, and one streaming back in is applied afresh. A slot Model can arrive before its parts (it streams in
	whole only near the player), so a part streaming into an applied slot re-applies it (refreshSlot, keeping the
	silhouette's progress and the door cycle count), and the car's tail lights (outside the slot) are looked for every
	TAIL_LOOK_EVERY s (new ones lit, gone ones dropped). The silhouette, once gone, stays gone for this player for the
	run (the office's LayoutSeed), whatever streams.

	Per id: silhouette (shown; seen after SILHOUETTE_SEEN_AFTER s in view — on screen, within SILHOUETTE_RANGE, not
	occluded, see-through parts not counting — it hides the next time it is off screen, never while on screen),
	autoDoors (the leaves slide open, hold and close on OfficeAnomalyUtils.doorStep's clock: never the moment a player
	comes near; each cycle 20-40 s after the last, or after a player arrives or the slot re-streams, and only with a
	player within DOOR_NEAR when it comes due), carTicking (a looped engine tick at the emitter and the car's tail
	lights dimly on), welcomeScreen (the welcome text, the run's wrong line in the last 1.2 s of every 6 s), boothTv
	(cold blue Neon, a flickering SurfaceLight and a static loop), wetFloor (the sign shows), leaningLamp (the walk's
	lamp post leans LEAN_DEGREES toward the slot's LeanDirection, its base left standing). Pending sounds
	(OfficeAssets) are silent.

	Systems (Instances, Sound, RunService); the timing, looks and per-slot decisions are the specced
	OfficeAnomalyUtils. Putting a look on and taking it off is OfficeAnomalyLookSystem (split out of this file), and
	what it reads from the world (parts by name, a player near, the figure in view) is OfficeAnomalySenseUtils.

	@class OfficeAnomalySystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local OfficeAssets = require(OfficeClient.Data.OfficeAssets)
local OfficeAnomalyUtils = require(OfficeClient.Utils.OfficeAnomalyUtils)
local OfficeAnomalyLookSystem = require(OfficeClient.Systems.OfficeAnomalyLookSystem)
local OfficeAnomalySenseUtils = require(OfficeClient.Utils.OfficeAnomalySenseUtils)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

local OFFICE_NAME = "CleanupCrewOffice"
-- Tail lights stream separately from the slot: look for new (and gone) ones this often.
local TAIL_LOOK_EVERY = 2

export type OfficeAnomalyState = {
	published: { string },
	slots: number,
	active: { string },
	silhouette: string,
	counters: { [string]: number },
}

type Applied = OfficeAnomalyLookSystem.Applied
type Carry = OfficeAnomalyLookSystem.Carry

-- Every slot this client has (tag added, not yet removed), with its DescendantAdded connection: a part streaming
-- in after the slot was applied marks it restreamed (refreshed next step).
local tracked: { [Model]: RBXScriptConnection } = {}
local restreamed: { [Model]: boolean } = {}
local applied: { [Model]: Applied } = {}
-- The run whose silhouette this player has already seen go (its LayoutSeed).
local goneSeed: number? = nil
local connections: { RBXScriptConnection } = {}
-- The published set and the run's seed, cached from the office model's attributes.
local published: { [string]: boolean } = {}
local runSeed = 0
local office: Instance? = nil
local officeConnections: { RBXScriptConnection } = {}
local counters = { applies = 0, resets = 0, refreshes = 0, doorCycles = 0, silhouettesGone = 0, pending = 0 }

local function slotId(slot: Model): string?
	local id = slot:GetAttribute(OfficeAnomalyConstants.SLOT_ATTRIBUTE)
	return if type(id) == "string" then id else nil
end

local setSilhouette = OfficeAnomalyLookSystem.setSilhouette
local lightTails = OfficeAnomalyLookSystem.lightTails
local someoneNear = OfficeAnomalySenseUtils.someoneNear
local views = OfficeAnomalySenseUtils.views

local function loop(id: string, at: BasePart): SoundServiceClient.SoundHandle?
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	return SoundServiceClient:play(id, { at = at })
end

local function shot(id: string, at: BasePart)
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return
	end
	SoundServiceClient:playOneShot(id, { at = at })
end

local OfficeAnomalySystem = {}

--[=[
	Applies anomaly `id` (the slot's) to `slot` for the run `seed`, beginning at `now`. Captures every property it
	will touch first; applying an applied slot again does nothing. `carry` (refreshSlot) keeps the silhouette's
	progress and the door cycle count.
]=]
function OfficeAnomalySystem.applySlot(slot: Model, seed: number, now: number, carry: Carry?)
	if applied[slot] ~= nil then
		return
	end
	local id = slotId(slot)
	if id == nil then
		return
	end
	local state: Applied = {
		id = id,
		seed = seed,
		parts = {},
		labels = {},
		guis = {},
		added = {},
		sound = nil,
		leaves = {},
		-- Nothing scheduled: the first cycle is 20-40 s after a player is near (also after a re-stream).
		door = { cycle = if carry ~= nil then carry.door.cycle else 0 },
		lastOpen = 0,
		wrong = OfficeAnomalyUtils.wrongLine(seed),
		label = nil,
		light = nil,
		emitter = nil,
		nextTailLook = now + TAIL_LOOK_EVERY,
		silhouette = { phase = "hidden" },
		shown = nil,
	}
	applied[slot] = state
	counters.applies += 1

	OfficeAnomalyLookSystem.dress(slot, state, now, carry, goneSeed, loop)
end

--[=[
	Moves an applied slot on to `now`. `sensed` overrides the world check where one is made (a player near the
	doors; the figure in view) and `onScreen` the figure being on screen (nil: as `sensed`); nil checks the world.
]=]
function OfficeAnomalySystem.stepSlot(slot: Model, now: number, sensed: boolean?, onScreen: boolean?)
	local state = applied[slot]
	if state == nil then
		return
	end
	local id = state.id
	if id == "autoDoors" then
		local near = if sensed ~= nil then sensed else someoneNear(slot)
		local before = state.door.startedAt
		state.door = OfficeAnomalyUtils.doorStep(state.door, state.seed, near, now)
		local startedAt = state.door.startedAt
		if startedAt ~= nil and startedAt ~= before then
			counters.doorCycles += 1
			local leaf = state.leaves[1]
			if leaf ~= nil then
				shot(OfficeAssets.AUTO_DOOR, leaf.part)
			end
		end
		local open = OfficeAnomalyUtils.doorOpen(state.door, now)
		if open ~= state.lastOpen then
			state.lastOpen = open
			for _, leaf in state.leaves do
				leaf.part.CFrame = OfficeAnomalyUtils.leafAt(leaf.closed, leaf.side, leaf.slide, open)
			end
		end
	elseif id == "welcomeScreen" then
		local label = state.label
		if label ~= nil then
			local text = OfficeAnomalyUtils.welcomeText(now, state.wrong)
			if label.Text ~= text then
				label.Text = text
			end
		end
	elseif id == "boothTv" then
		local light = state.light
		if light ~= nil then
			light.Brightness = OfficeAnomalyUtils.tvBrightness(now)
		end
	elseif id == "carTicking" then
		local emitter = state.emitter
		if emitter ~= nil and now >= state.nextTailLook then
			state.nextTailLook = now + TAIL_LOOK_EVERY
			lightTails(slot, state, emitter)
		end
	elseif id == "silhouette" then
		if goneSeed == state.seed and state.silhouette.phase ~= "gone" then
			state.silhouette = { phase = "gone" }
		end
		if state.silhouette.phase == "visible" or state.silhouette.phase == "seen" then
			local screen, view
			if sensed ~= nil then
				view = sensed
				screen = if onScreen ~= nil then onScreen else sensed
			else
				screen, view = views(slot)
			end
			local nextState = OfficeAnomalyUtils.silhouette(
				state.silhouette,
				screen,
				view,
				OfficeAnomalyUtils.SILHOUETTE_SEEN_AFTER,
				now
			)
			state.silhouette = nextState
			if nextState.phase == "gone" then
				goneSeed = state.seed
				counters.silhouettesGone += 1
			end
		end
		setSilhouette(slot, state, OfficeAnomalyUtils.silhouetteShown(state.silhouette))
	end
end

--[=[
	Puts `slot` back in its default state (every captured property written back, everything added destroyed, its
	sound stopped). Harmless on a slot that is not applied.
]=]
function OfficeAnomalySystem.resetSlot(slot: Model)
	local state = applied[slot]
	if state == nil then
		return
	end
	applied[slot] = nil
	counters.resets += 1
	OfficeAnomalyLookSystem.restore(state)
end

--[=[
	Re-applies an applied slot from scratch (reset, then apply for the same run): a part that streamed in after the
	slot was applied gets the anomaly too. The silhouette keeps its progress; the doors keep their cycle count and
	schedule their next cycle afresh (20-40 s after a player is near). Does nothing to a slot that is not applied.
]=]
function OfficeAnomalySystem.refreshSlot(slot: Model, now: number)
	local state = applied[slot]
	if state == nil then
		return
	end
	counters.refreshes += 1
	local carry: Carry = { door = state.door, silhouette = state.silhouette }
	OfficeAnomalySystem.resetSlot(slot)
	OfficeAnomalySystem.applySlot(slot, state.seed, now, carry)
end

--[=[
	Marks the silhouette as gone for the run `seed` (this player saw it go).
]=]
function OfficeAnomalySystem.markSilhouetteGone(seed: number)
	goneSeed = seed
end

--[=[
	Forgets the run's silhouette memory (a new run).
]=]
function OfficeAnomalySystem.forgetRun()
	goneSeed = nil
end

-- Re-reads the published set and the seed from the office model (none standing: nothing published).
local function readOffice()
	local model = office
	published = OfficeAnomalyUtils.parse(
		if model ~= nil then model:GetAttribute(OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE) else nil
	)
	local rawSeed = if model ~= nil then model:GetAttribute("LayoutSeed") else nil
	runSeed = if type(rawSeed) == "number" then rawSeed else 0
	if goneSeed ~= nil and goneSeed ~= runSeed then
		goneSeed = nil
	end
end

-- Follows the office model now in Workspace (it is rebuilt every shift) and its two attributes.
local function bindOffice()
	for _, connection in officeConnections do
		connection:Disconnect()
	end
	table.clear(officeConnections)
	local model = Workspace:FindFirstChild(OFFICE_NAME)
	office = model
	if model ~= nil then
		table.insert(
			officeConnections,
			model:GetAttributeChangedSignal(OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE):Connect(readOffice)
		)
		table.insert(officeConnections, model:GetAttributeChangedSignal("LayoutSeed"):Connect(readOffice))
	end
	readOffice()
end

local function officeChanged(child: Instance)
	if child.Name == OFFICE_NAME then
		bindOffice()
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for slot in tracked do
		local state = applied[slot]
		local action = OfficeAnomalyUtils.slotAction(
			slotId(slot),
			published,
			runSeed,
			if state ~= nil then state.seed else nil,
			restreamed[slot] == true
		)
		restreamed[slot] = nil
		if action == "reset" then
			OfficeAnomalySystem.resetSlot(slot)
		elseif action == "reapply" then
			OfficeAnomalySystem.resetSlot(slot)
			OfficeAnomalySystem.applySlot(slot, runSeed, now)
		elseif action == "apply" then
			OfficeAnomalySystem.applySlot(slot, runSeed, now)
		elseif action == "refresh" then
			OfficeAnomalySystem.refreshSlot(slot, now)
		end
		if applied[slot] ~= nil then
			OfficeAnomalySystem.stepSlot(slot, now)
		end
	end
end

local function track(instance: Instance)
	if instance:IsA("Model") and not tracked[instance] then
		tracked[instance] = instance.DescendantAdded:Connect(function(added: Instance)
			-- Only parts streaming in (not the lights and voices this system adds).
			if added:IsA("BasePart") and applied[instance] ~= nil then
				restreamed[instance] = true
			end
		end)
	end
end

local function untrack(instance: Instance)
	if instance:IsA("Model") then
		local connection: RBXScriptConnection? = tracked[instance]
		if connection then
			connection:Disconnect()
		end
		tracked[instance] = nil
		restreamed[instance] = nil
		OfficeAnomalySystem.resetSlot(instance)
	end
end

function OfficeAnomalySystem.start()
	if #connections > 0 then
		return
	end
	for _, instance in CollectionService:GetTagged(OfficeAnomalyConstants.SLOT_TAG) do
		track(instance)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(OfficeAnomalyConstants.SLOT_TAG):Connect(track))
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(OfficeAnomalyConstants.SLOT_TAG):Connect(untrack)
	)
	table.insert(connections, Workspace.ChildAdded:Connect(officeChanged))
	table.insert(connections, Workspace.ChildRemoved:Connect(officeChanged))
	bindOffice()
	table.insert(connections, RunService.Heartbeat:Connect(step))
end

function OfficeAnomalySystem.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for slot in applied do
		OfficeAnomalySystem.resetSlot(slot)
	end
	for _, connection in tracked do
		connection:Disconnect()
	end
	table.clear(tracked)
	table.clear(restreamed)
	for _, connection in officeConnections do
		connection:Disconnect()
	end
	table.clear(officeConnections)
	office = nil
	table.clear(published)
end

function OfficeAnomalySystem.getState(): OfficeAnomalyState
	local list: { string } = {}
	for id in published do
		table.insert(list, id)
	end
	table.sort(list)
	local active: { string } = {}
	local silhouette = "none"
	local slots = 0
	for _ in tracked do
		slots += 1
	end
	for _, state in applied do
		table.insert(active, state.id)
		if state.id == "silhouette" then
			silhouette = state.silhouette.phase
		end
	end
	table.sort(active)
	return {
		published = list,
		slots = slots,
		active = active,
		silhouette = silhouette,
		counters = table.clone(counters),
	}
end

return OfficeAnomalySystem
