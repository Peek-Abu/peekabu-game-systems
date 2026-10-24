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
	(cold blue Neon, a flickering SurfaceLight and a static loop), wetFloor (the sign shows), banner (turned 180° about
	its forward axis). Pending sounds (OfficeAssets) are silent.

	Systems (Instances, Sound, RunService); the timing, looks and per-slot decisions are the specced
	OfficeAnomalyUtils.

	@class OfficeAnomalySystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local OfficeAssets = require(OfficeClient.Data.OfficeAssets)
local OfficeAnomalyUtils = require(OfficeClient.Utils.OfficeAnomalyUtils)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

local OFFICE_NAME = "CleanupCrewOffice"
-- The parked car's tail lights within this of the carTicking emitter dim on.
local TAIL_LIGHT_RADIUS = 16
-- Tail lights stream separately from the slot: look for new (and gone) ones this often.
local TAIL_LOOK_EVERY = 2
-- A ray to the figure passes through at most this many see-through parts (glass, invisible walls).
local SEE_THROUGH_HITS = 6
local TAIL_LIGHT_COLOR = Color3.fromRGB(255, 45, 35)
local TV_COLOR = Color3.fromRGB(95, 140, 210)
local TV_LIGHT_COLOR = Color3.fromRGB(150, 190, 255)

export type OfficeAnomalyState = {
	published: { string },
	slots: number,
	active: { string },
	silhouette: string,
	counters: { [string]: number },
}

type PartDefault = {
	part: BasePart,
	cframe: CFrame,
	transparency: number,
	color: Color3,
	material: Enum.Material,
}
type LabelDefault = { label: TextLabel, text: string, textTransparency: number }
type GuiDefault = { gui: SurfaceGui, lightInfluence: number, brightness: number }
type Leaf = { part: BasePart, closed: CFrame, side: number, slide: number }

type Applied = {
	id: string,
	seed: number,
	parts: { PartDefault },
	labels: { LabelDefault },
	guis: { GuiDefault },
	-- Instances this system added (lights), destroyed on reset.
	added: { Instance },
	sound: SoundServiceClient.SoundHandle?,
	-- autoDoors, and how open the leaves were last written (written only when it changes).
	leaves: { Leaf },
	door: OfficeAnomalyUtils.DoorTimer,
	lastOpen: number,
	-- welcomeScreen
	wrong: string,
	label: TextLabel?,
	-- boothTv
	light: SurfaceLight?,
	-- carTicking: the emitter, and when to look again for tail lights.
	emitter: BasePart?,
	nextTailLook: number,
	-- silhouette, and whether its parts are drawn now (written only when it changes).
	silhouette: OfficeAnomalyUtils.SilhouetteState,
	shown: boolean?,
}

-- What a refresh keeps from the state it replaces.
type Carry = {
	door: OfficeAnomalyUtils.DoorTimer,
	silhouette: OfficeAnomalyUtils.SilhouetteState,
}

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
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local counters = { applies = 0, resets = 0, refreshes = 0, doorCycles = 0, silhouettesGone = 0, pending = 0 }

local function slotId(slot: Model): string?
	local id = slot:GetAttribute(OfficeAnomalyConstants.SLOT_ATTRIBUTE)
	return if type(id) == "string" then id else nil
end

-- Captures `part`'s default once; true when it was not captured yet.
local function capturePart(state: Applied, part: BasePart): boolean
	for _, row in state.parts do
		if row.part == part then
			return false
		end
	end
	table.insert(state.parts, {
		part = part,
		cframe = part.CFrame,
		transparency = part.Transparency,
		color = part.Color,
		material = part.Material,
	})
	return true
end

local function captureLabel(state: Applied, label: TextLabel)
	table.insert(state.labels, { label = label, text = label.Text, textTransparency = label.TextTransparency })
end

local function captureGui(state: Applied, gui: SurfaceGui)
	table.insert(state.guis, { gui = gui, lightInfluence = gui.LightInfluence, brightness = gui.Brightness })
end

local function namedParts(slot: Model, name: string): { BasePart }
	local list: { BasePart } = {}
	for _, d in slot:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			table.insert(list, d)
		end
	end
	return list
end

local function firstPart(slot: Model, name: string): BasePart?
	return namedParts(slot, name)[1]
end

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

local function setSilhouette(slot: Model, state: Applied, shown: boolean)
	if state.shown == shown then
		return
	end
	state.shown = shown
	for _, d in slot:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if shown then 0 else 1
		end
	end
end

-- The car's tail lights near the emitter (siblings of the slot under OfficeExterior, outside the slot itself).
local function tailLights(slot: Model, emitter: BasePart): { BasePart }
	local list: { BasePart } = {}
	local exterior = slot:FindFirstAncestor("OfficeExterior")
	if exterior == nil then
		return list
	end
	for _, d in exterior:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.Name == "TailLight"
			and (d.Position - emitter.Position).Magnitude <= TAIL_LIGHT_RADIUS
		then
			table.insert(list, d)
		end
	end
	return list
end

-- Dims on every tail light in reach not lit yet, and forgets lit ones that streamed out of the exterior (they come
-- back as new instances, lit on a later look). A light still under the exterior is never re-captured: its captured
-- row holds the default, and capturing it again while lit would make the lit look its "default".
local function lightTails(slot: Model, state: Applied, emitter: BasePart)
	local exterior = slot:FindFirstAncestor("OfficeExterior")
	for index = #state.parts, 1, -1 do
		local part = state.parts[index].part
		if exterior == nil or not part:IsDescendantOf(exterior) then
			table.remove(state.parts, index)
		end
	end
	for _, light in tailLights(slot, emitter) do
		if not capturePart(state, light) then
			continue
		end
		light.Color = TAIL_LIGHT_COLOR
		light.Material = Enum.Material.Neon
		local glow = Instance.new("PointLight")
		glow.Name = "AnomalyTailGlow"
		glow.Color = TAIL_LIGHT_COLOR
		glow.Brightness = 0.6
		glow.Range = 7
		glow.Shadows = false
		glow.Parent = light
		table.insert(state.added, glow)
	end
end

-- Whether any player's character is within DOOR_NEAR of the slot.
local function someoneNear(slot: Model): boolean
	local centre = slot:GetPivot().Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if
			root ~= nil
			and root:IsA("BasePart")
			and (root.Position - centre).Magnitude <= OfficeAnomalyUtils.DOOR_NEAR
		then
			return true
		end
	end
	return false
end

-- A part the eye sees through: it never hides the figure.
local function seeThrough(part: BasePart): boolean
	return part.Transparency >= 0.5 or part.Material == Enum.Material.Glass
end

-- The figure against this client's camera: on screen (in the frustum, in front), and in view (on screen, within
-- SILHOUETTE_RANGE and not hidden behind anything solid). A figure not streamed in is off screen.
local function views(slot: Model): (boolean, boolean)
	local camera = Workspace.CurrentCamera
	local body = firstPart(slot, "FigureBody")
	if camera == nil or body == nil then
		return false, false
	end
	local point, visible = camera:WorldToViewportPoint(body.Position)
	if not visible or point.Z <= 0 then
		return false, false
	end
	local origin = camera.CFrame.Position
	local offset = body.Position - origin
	if offset.Magnitude > OfficeAnomalyUtils.SILHOUETTE_RANGE then
		return true, false
	end
	local exclude: { Instance } = { slot }
	local character = if Players.LocalPlayer ~= nil then Players.LocalPlayer.Character else nil
	if character ~= nil then
		table.insert(exclude, character)
	end
	for _ = 1, SEE_THROUGH_HITS do
		rayParams.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(origin, offset, rayParams)
		if hit == nil then
			return true, true
		end
		local part = hit.Instance
		if not (part:IsA("BasePart") and seeThrough(part)) then
			return true, false
		end
		table.insert(exclude, part)
	end
	return true, false
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

	if id == "silhouette" then
		for _, d in slot:GetDescendants() do
			if d:IsA("BasePart") then
				capturePart(state, d)
			end
		end
		if goneSeed == seed then
			state.silhouette = { phase = "gone" }
		elseif carry ~= nil and carry.silhouette.phase ~= "hidden" then
			state.silhouette = carry.silhouette
		else
			state.silhouette = { phase = "visible" }
		end
		setSilhouette(slot, state, OfficeAnomalyUtils.silhouetteShown(state.silhouette))
	elseif id == "autoDoors" then
		for _, leaf in namedParts(slot, "LobbyDoorLeaf") do
			capturePart(state, leaf)
			local side = leaf:GetAttribute("Side")
			local slide = leaf:GetAttribute("SlideStuds")
			table.insert(state.leaves, {
				part = leaf,
				closed = leaf.CFrame,
				side = if type(side) == "number" then side else 1,
				slide = if type(slide) == "number" then slide else 2.2,
			})
		end
	elseif id == "carTicking" then
		local emitter = firstPart(slot, "Emitter")
		if emitter ~= nil then
			state.emitter = emitter
			state.sound = loop(OfficeAssets.CAR_TICK, emitter)
			lightTails(slot, state, emitter)
		end
	elseif id == "welcomeScreen" then
		for _, d in slot:GetDescendants() do
			if d:IsA("TextLabel") and d.Name == "Text" then
				captureLabel(state, d)
				state.label = d
				local gui = d:FindFirstAncestorWhichIsA("SurfaceGui")
				if gui ~= nil then
					captureGui(state, gui)
					-- Lit from within: the night does not dim it.
					gui.LightInfluence = 0
				end
				d.Text = OfficeAnomalyUtils.welcomeText(now, state.wrong)
				break
			end
		end
	elseif id == "boothTv" then
		local tv = firstPart(slot, "BoothTV")
		if tv ~= nil then
			capturePart(state, tv)
			tv.Material = Enum.Material.Neon
			tv.Color = TV_COLOR
			local light = Instance.new("SurfaceLight")
			light.Name = "AnomalyTvGlow"
			light.Face = Enum.NormalId.Front
			light.Color = TV_LIGHT_COLOR
			light.Range = 12
			light.Angle = 120
			light.Brightness = OfficeAnomalyUtils.tvBrightness(now)
			light.Shadows = false
			light.Parent = tv
			state.light = light
			table.insert(state.added, light)
			state.sound = loop(OfficeAssets.TV_STATIC, tv)
		end
	elseif id == "wetFloor" then
		for _, d in slot:GetDescendants() do
			if d:IsA("BasePart") then
				capturePart(state, d)
				d.Transparency = 0
			elseif d:IsA("TextLabel") then
				captureLabel(state, d)
				d.TextTransparency = 0
			end
		end
	elseif id == "banner" then
		local cloth = firstPart(slot, "BannerCloth")
		if cloth ~= nil then
			capturePart(state, cloth)
			-- Turned about its own forward axis: upside down, the text still on the same face.
			cloth.CFrame = cloth.CFrame * CFrame.Angles(0, 0, math.pi)
		end
	end
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
	local sound = state.sound
	if sound ~= nil then
		sound:stop(0.3)
	end
	for _, instance in state.added do
		instance:Destroy()
	end
	for _, row in state.parts do
		row.part.CFrame = row.cframe
		row.part.Transparency = row.transparency
		row.part.Color = row.color
		row.part.Material = row.material
	end
	for _, row in state.labels do
		row.label.Text = row.text
		row.label.TextTransparency = row.textTransparency
	end
	for _, row in state.guis do
		row.gui.LightInfluence = row.lightInfluence
		row.gui.Brightness = row.brightness
	end
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
