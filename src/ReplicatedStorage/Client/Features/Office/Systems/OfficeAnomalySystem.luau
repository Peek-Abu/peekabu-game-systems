--!strict
--[=[
	OfficeAnomalySystem: plays the run's exterior anomalies on this client. The server publishes the run's ids on
	Workspace.CleanupCrewOffice (OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE, comma-joined; the model is rebuilt every
	shift and the admin `anomaly` command republishes); the slots are the OfficeExterior Models tagged SLOT_TAG with
	their id in SLOT_ATTRIBUTE, built in their default state. Every Heartbeat it applies each listed id to its slots
	and resets every slot whose id is not listed, so a new run or `none` puts each slot back exactly as it was built
	(every property it touches is captured on apply and written back on reset; what it adds is destroyed).

	Streaming is on: slots are tracked by the tag's added/removed signals; a slot streaming out is reset and
	forgotten, and one streaming back in is applied afresh. A slot Model can arrive before its parts (it streams in
	whole only near the player), so a part streaming into an applied slot re-applies it (refreshSlot), and the car's
	tail lights (outside the slot) are looked for again until found. The silhouette, once gone, stays gone for this player for
	the run (the office's LayoutSeed), whatever streams.

	Per id: silhouette (shown; seen after SILHOUETTE_SEEN_AFTER s in view — on screen, within SILHOUETTE_RANGE, not
	occluded — it hides the next time it is off screen), autoDoors (with a player within DOOR_NEAR the leaves slide
	open, hold and close every 20-40 s), carTicking (a looped engine tick at the emitter and the car's tail lights
	dimly on), welcomeScreen (the welcome text, the run's wrong line in the last 1.2 s of every 6 s), boothTv (cold
	blue Neon, a flickering SurfaceLight and a static loop), wetFloor (the sign shows), banner (turned 180° about its
	forward axis). Pending sounds (OfficeAssets) are silent.

	Systems (Instances, Sound, RunService); the timing and looks are the specced OfficeAnomalyUtils.

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
-- While none is found (not streamed in yet), look again this often.
local TAIL_LOOK_EVERY = 2
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
	appliedAt: number,
	parts: { PartDefault },
	labels: { LabelDefault },
	guis: { GuiDefault },
	-- Instances this system added (lights), destroyed on reset.
	added: { Instance },
	sound: SoundServiceClient.SoundHandle?,
	-- autoDoors
	leaves: { Leaf },
	cycle: number,
	nextCycleAt: number,
	cycleStart: number?,
	-- welcomeScreen
	wrong: string,
	label: TextLabel?,
	-- boothTv
	light: SurfaceLight?,
	-- carTicking: the emitter, and when to look again for tail lights not streamed in yet.
	emitter: BasePart?,
	tailsLit: boolean,
	nextTailLook: number,
	-- silhouette
	silhouette: OfficeAnomalyUtils.SilhouetteState,
}

-- Every slot this client has (tag added, not yet removed), and the ones an anomaly is applied to.
-- Each tracked slot's DescendantAdded connection: a part streaming in after the slot was applied re-applies it.
local tracked: { [Model]: RBXScriptConnection } = {}
local restreamed: { [Model]: boolean } = {}
local applied: { [Model]: Applied } = {}
-- The run whose silhouette this player has already seen go (its LayoutSeed).
local goneSeed: number? = nil
local connections: { RBXScriptConnection } = {}
local published: { [string]: boolean } = {}
local counters = { applies = 0, resets = 0, doorCycles = 0, silhouettesGone = 0, pending = 0 }

local function slotId(slot: Model): string?
	local id = slot:GetAttribute(OfficeAnomalyConstants.SLOT_ATTRIBUTE)
	return if type(id) == "string" then id else nil
end

local function capturePart(state: Applied, part: BasePart)
	for _, row in state.parts do
		if row.part == part then
			return
		end
	end
	table.insert(state.parts, {
		part = part,
		cframe = part.CFrame,
		transparency = part.Transparency,
		color = part.Color,
		material = part.Material,
	})
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

local function setSilhouette(slot: Model, shown: boolean)
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

-- Dims the car's tail lights on (once found; they stream separately from the slot).
local function lightTails(slot: Model, state: Applied, emitter: BasePart)
	for _, light in tailLights(slot, emitter) do
		capturePart(state, light)
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
		state.tailsLit = true
	end
end

local function startDoorCycle(state: Applied, now: number)
	state.cycle += 1
	state.cycleStart = now
	state.nextCycleAt = now + OfficeAnomalyUtils.doorEvery(state.seed, state.cycle)
	counters.doorCycles += 1
	local leaf = state.leaves[1]
	if leaf ~= nil then
		shot(OfficeAssets.AUTO_DOOR, leaf.part)
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

-- Whether the figure is in view of this client's camera: on screen, within range and not occluded.
local function inView(slot: Model): boolean
	local camera = Workspace.CurrentCamera
	local body = firstPart(slot, "FigureBody")
	if camera == nil or body == nil then
		return false
	end
	local origin = camera.CFrame.Position
	local offset = body.Position - origin
	if offset.Magnitude > OfficeAnomalyUtils.SILHOUETTE_RANGE then
		return false
	end
	local point, onScreen = camera:WorldToViewportPoint(body.Position)
	if not onScreen or point.Z <= 0 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { slot }
	local character = if Players.LocalPlayer ~= nil then Players.LocalPlayer.Character else nil
	if character ~= nil then
		table.insert(exclude, character)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local hit = Workspace:Raycast(origin, offset, params)
	return hit == nil
end

local OfficeAnomalySystem = {}

--[=[
	Applies anomaly `id` (the slot's) to `slot` for the run `seed`, beginning at `now`. Captures every property it
	will touch first; applying an applied slot again does nothing.
]=]
function OfficeAnomalySystem.applySlot(slot: Model, seed: number, now: number)
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
		appliedAt = now,
		parts = {},
		labels = {},
		guis = {},
		added = {},
		sound = nil,
		leaves = {},
		cycle = 0,
		nextCycleAt = now,
		cycleStart = nil,
		wrong = OfficeAnomalyUtils.wrongLine(seed),
		label = nil,
		light = nil,
		emitter = nil,
		tailsLit = false,
		nextTailLook = now,
		silhouette = { phase = "hidden" },
	}
	applied[slot] = state
	counters.applies += 1

	if id == "silhouette" then
		for _, d in slot:GetDescendants() do
			if d:IsA("BasePart") then
				capturePart(state, d)
			end
		end
		if goneSeed ~= seed then
			state.silhouette = { phase = "visible" }
		end
		setSilhouette(slot, OfficeAnomalyUtils.silhouetteShown(state.silhouette))
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
				d.Text = OfficeAnomalyUtils.welcomeText(0, state.wrong)
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
			light.Brightness = OfficeAnomalyUtils.tvBrightness(0)
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
	doors; the figure in view); nil checks the world.
]=]
function OfficeAnomalySystem.stepSlot(slot: Model, now: number, sensed: boolean?)
	local state = applied[slot]
	if state == nil then
		return
	end
	local id = state.id
	if id == "autoDoors" then
		local start = state.cycleStart
		local running = start ~= nil and now - start < OfficeAnomalyUtils.DOOR_CYCLE
		if not running and now >= state.nextCycleAt then
			local near = if sensed ~= nil then sensed else someoneNear(slot)
			if near then
				startDoorCycle(state, now)
				start = state.cycleStart
			end
		end
		local _, open = OfficeAnomalyUtils.doorAt(if start ~= nil then now - start else math.huge)
		for _, leaf in state.leaves do
			leaf.part.CFrame = OfficeAnomalyUtils.leafAt(leaf.closed, leaf.side, leaf.slide, open)
		end
	elseif id == "welcomeScreen" then
		local label = state.label
		if label ~= nil then
			label.Text = OfficeAnomalyUtils.welcomeText(now - state.appliedAt, state.wrong)
		end
	elseif id == "boothTv" then
		local light = state.light
		if light ~= nil then
			light.Brightness = OfficeAnomalyUtils.tvBrightness(now)
		end
	elseif id == "carTicking" then
		local emitter = state.emitter
		if emitter ~= nil and not state.tailsLit and now >= state.nextTailLook then
			state.nextTailLook = now + TAIL_LOOK_EVERY
			lightTails(slot, state, emitter)
		end
	elseif id == "silhouette" then
		if goneSeed == state.seed and state.silhouette.phase ~= "gone" then
			state.silhouette = { phase = "gone" }
		end
		if state.silhouette.phase == "visible" or state.silhouette.phase == "seen" then
			local seen = if sensed ~= nil then sensed else inView(slot)
			local nextState =
				OfficeAnomalyUtils.silhouette(state.silhouette, seen, OfficeAnomalyUtils.SILHOUETTE_SEEN_AFTER, now)
			state.silhouette = nextState
			if nextState.phase == "gone" then
				goneSeed = state.seed
				counters.silhouettesGone += 1
			end
		end
		setSilhouette(slot, OfficeAnomalyUtils.silhouetteShown(state.silhouette))
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
	slot was applied gets the anomaly too. Does nothing to a slot that is not applied.
]=]
function OfficeAnomalySystem.refreshSlot(slot: Model, now: number)
	local state = applied[slot]
	if state == nil then
		return
	end
	OfficeAnomalySystem.resetSlot(slot)
	OfficeAnomalySystem.applySlot(slot, state.seed, now)
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

local function office(): Instance?
	return Workspace:FindFirstChild(OFFICE_NAME)
end

local function step()
	local now = os.clock()
	local model = office()
	published = OfficeAnomalyUtils.parse(
		if model ~= nil then model:GetAttribute(OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE) else nil
	)
	local rawSeed = if model ~= nil then model:GetAttribute("LayoutSeed") else nil
	local seed = if type(rawSeed) == "number" then rawSeed else 0
	if goneSeed ~= nil and goneSeed ~= seed then
		goneSeed = nil
	end
	for slot in tracked do
		local id = slotId(slot)
		local state = applied[slot]
		local wanted = id ~= nil and published[id] == true
		local stale = state ~= nil and (not wanted or state.seed ~= seed)
		if stale then
			OfficeAnomalySystem.resetSlot(slot)
		elseif state ~= nil and restreamed[slot] then
			OfficeAnomalySystem.refreshSlot(slot, now)
		end
		restreamed[slot] = nil
		if wanted and (state == nil or stale) then
			OfficeAnomalySystem.applySlot(slot, seed, now)
		end
		if wanted then
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
