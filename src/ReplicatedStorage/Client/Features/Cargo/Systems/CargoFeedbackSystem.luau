--!strict
--[=[
	CargoFeedbackSystem: how cargo feels on this client (Cleanup Crew spec §7 "Banking: item swoops into the
	truck, cha-ching, '+15' floater, clearance bar fills"; §4 "Office plant: leaves partly block your view").
	- `Banked` (server → all): a ghost of each loaded item swoops on an arc into the truck bed, shrinking and
	  spinning (CargoFeedbackUtils.arc), and as each lands its Gloom is refined into Gleam in the bed (CargoVfxConstants
	  cargoBankRefine: wisps turning from purple-black to gold, gold sparkles rising); when the last lands, a cha-ching
	  at the bed and a rising, fading load floater per amount, drawn in the V1 kit (CargoLoadFloater: "+15 CLEARED", the gold "+40 Gleam" with the coin;
	  CargoWorldViewModel.floater; CargoFeedbackUtils.floaters). The clearance bar is the HUD's.
	- Your public fields: a pickup sound when something new comes into your hands, a pocket sound when an item
	  slot fills, and plant leaves in front of your camera while your hands hold a blocksView item.
	Drop, rattle and search sounds are the server's (CargoServiceServer). Client-local instances; pending sounds
	(CargoAssets) are skipped silently and counted.

	Spec-exempt shell (Instances, tweens, RunService, ByteNet, Charm); the choices and the arc are the specced
	CargoFeedbackUtils.

	@class CargoFeedbackSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoAssets = require(CargoShared.Data.CargoAssets)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoEvents = require(CargoShared.Net.CargoEvents)
local CargoFeedbackUtils = require(CargoShared.Utils.CargoFeedbackUtils)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoSwoopSystem = require(ReplicatedStorage.Client.Features.Cargo.Systems.CargoSwoopSystem)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local CargoVfxConstants = require(ReplicatedStorage.Client.Features.Cargo.Data.CargoVfxConstants)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local CargoLoadFloater = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoLoadFloater)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

local e = React.createElement

type Swoop = {
	ghost: CargoSwoopSystem.Ghost,
	from: Vector3,
	to: Vector3,
	rotation: CFrame,
	started: number,
}

-- A floater on screen: its anchor (which holds the BillboardGui and the fade value) and its React root.
type Floating = {
	anchor: Attachment,
	root: UIBillboards.BillboardHandle,
}

export type CargoFeedbackState = {
	swooping: number,
	floating: number,
	leaves: number,
	counters: { [string]: number },
}

local log = Logger.new("CargoFeedbackSystem")

-- Registered at load (CargoLootFeedbackSystem registers the same set; whichever loads first does it).
for id, preset in CargoVfxConstants.PRESETS do
	if not VfxBurstRegistry.has(id) then
		VfxBurstRegistry.register(id, preset)
	end
end

local ghosts = CargoSwoopSystem.new()
local session = 0
local swoops: { Swoop } = {}
local floating: { Floating } = {}
local leaves: { BasePart } = {}
local lastHands: string? = nil
local lastPockets = 0
local counters =
	{ banked = 0, swoops = 0, refines = 0, floaters = 0, pickups = 0, pockets = 0, played = 0, pending = 0 }
local stoppers: { () -> () } = {}

local function play(id: string, options: SoundTypes.PlayOptions?)
	if CargoAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not a CargoAssets sound`)
		return
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return
	end
	counters.played += 1
	SoundServiceClient:playOneShot(id, options)
end

-- Unmounts a floater's root, then destroys its anchor (and with it the BillboardGui). Once per floater.
local function release(entry: Floating)
	local index = table.find(floating, entry)
	if index == nil then
		return
	end
	table.remove(floating, index)
	entry.root.unmount()
	entry.root.destroy()
	entry.anchor:Destroy()
end

local function floater(at: Vector3, index: number, item: CargoFeedbackUtils.Floater)
	local anchor = Instance.new("Attachment")
	anchor.Name = "CargoFloater"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = at + Vector3.new(0, 1 + index * CargoConstants.FLOATER_SPACING, 0)
	local size = CargoConstants.FLOATER_PX
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.MaxDistance = CargoConstants.FLOATER_DISTANCE
	gui.Adornee = anchor
	gui.Parent = anchor
	local fade, setFade = React.createBinding(0)
	local entry: Floating = { anchor = anchor, root = UIBillboardHost.factory(gui) }
	table.insert(floating, entry)
	entry.root.render(e(WorldBillboard, { design = size, sizing = "pixels" }, {
		floater = e(CargoLoadFloater, { view = CargoWorldViewModel.floater(item), fade = fade }),
	}))
	local info = TweenInfo.new(CargoConstants.FLOATER_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, CargoConstants.FLOATER_RISE, 0) }):Play()
	-- The fade tweens a value that drives the floater's transparency binding; the React tree itself is never tweened.
	local alpha = Instance.new("NumberValue")
	alpha.Parent = anchor
	alpha.Changed:Connect(function(value: number)
		setFade(value)
	end)
	local fadeOut = TweenService:Create(alpha, info, { Value = 1 })
	fadeOut.Completed:Once(function()
		release(entry)
	end)
	fadeOut:Play()
	counters.floaters += 1
end

local function swoop(
	kind: string,
	from: Vector3,
	to: Vector3,
	identity: CargoTypes.VisualIdentity?,
	expectedSession: number
)
	if #stoppers == 0 or session ~= expectedSession then
		return
	end
	local rotation = if identity ~= nil then identity.rotation else CFrame.identity
	local ghost = ghosts:spawn(kind, CFrame.new(from) * rotation, identity)
	if ghost == nil then
		return
	end
	table.insert(swoops, { ghost = ghost, from = from, to = to, rotation = rotation, started = os.clock() })
	counters.swoops += 1
end

local function onBanked(data: CargoFeedbackUtils.ReceivedBankedMessage)
	local expectedSession = session
	counters.banked += 1
	play("cargoSwoosh", { at = data.from })
	for index, kind in data.kinds do
		task.delay(
			(index - 1) * CargoConstants.SWOOP_STAGGER,
			swoop,
			kind,
			data.from,
			data.to,
			if data.visuals ~= nil then data.visuals[index] else nil,
			expectedSession
		)
	end
	local landing = math.max(0, #data.kinds - 1) * CargoConstants.SWOOP_STAGGER + CargoConstants.SWOOP_SECONDS
	task.delay(landing, function()
		if #stoppers == 0 or session ~= expectedSession then
			return
		end
		play("cargoChaChing", { at = data.to })
		for index, item in CargoFeedbackUtils.floaters(data.clearance, data.bonus) do
			floater(data.to, index - 1, item)
		end
	end)
end

local function showLeaves(on: boolean)
	if not on then
		for _, leaf in leaves do
			leaf:Destroy()
		end
		table.clear(leaves)
		return
	end
	local camera = Workspace.CurrentCamera
	if #leaves > 0 or camera == nil then
		return
	end
	for index = 1, #CargoConstants.LEAF_OFFSETS do
		local leaf = Instance.new("Part")
		leaf.Name = "CargoLeaf"
		leaf.Size = CargoConstants.LEAF_SIZE
		leaf.Color = CargoConstants.LEAF_COLORS[(index - 1) % #CargoConstants.LEAF_COLORS + 1]
		leaf.Material = Enum.Material.SmoothPlastic
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CanQuery = false
		leaf.CanTouch = false
		leaf.CastShadow = false
		-- Parts under the camera exist only on this client.
		leaf.Parent = camera
		table.insert(leaves, leaf)
	end
end

local function step()
	local now = os.clock()
	for index = #swoops, 1, -1 do
		local item = swoops[index]
		local alpha = (now - item.started) / CargoConstants.SWOOP_SECONDS
		if alpha >= 1 then
			item.ghost:destroy()
			table.remove(swoops, index)
			-- It lands in the bed: its Gloom is refined into Gleam.
			if VfxBurstSystem.polished() then
				counters.refines += 1
				VfxBurstSystem.play("cargoBankRefine", item.to)
			end
		else
			local scale = 1 + (CargoConstants.SWOOP_END_SCALE - 1) * alpha
			item.ghost:update(
				CFrame.new(CargoFeedbackUtils.arc(item.from, item.to, alpha, CargoConstants.SWOOP_HEIGHT))
					* item.rotation
					* CFrame.Angles(0, alpha * math.pi * 2, 0),
				scale
			)
		end
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		for index, leaf in leaves do
			local sway = CFrame.Angles(0, 0, math.sin(now * 2 + index) * 0.05)
			leaf.CFrame = camera.CFrame * CargoConstants.LEAF_OFFSETS[index] * sway
		end
	end
end

-- The local player's hands kind and how many item slots hold something, from the public fields.
local function readMine(map: PublicPlayerTypes.PublicPlayerMap): (string?, number)
	local me = map[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	if me == nil then
		return nil, 0
	end
	local hands = me[CarryConstants.PUBLIC_FIELD]
	local pockets = 0
	for _, fields in CargoConstants.SLOT_FIELDS do
		if me[fields.kind] ~= nil then
			pockets += 1
		end
	end
	return if type(hands) == "string" then hands else nil, pockets
end

local function onPublic(map: PublicPlayerTypes.PublicPlayerMap)
	local hands, pockets = readMine(map)
	if CargoFeedbackUtils.pickedUp(lastHands, hands) then
		counters.pickups += 1
		play("cargoPickup")
	end
	if CargoFeedbackUtils.pocketed(lastPockets, pockets) then
		counters.pockets += 1
		play("cargoPocket")
	end
	showLeaves(CargoFeedbackUtils.blocksView(hands))
	lastHands = hands
	lastPockets = pockets
end

local CargoFeedbackSystem = {}

function CargoFeedbackSystem.start()
	if #stoppers > 0 then
		return
	end
	session += 1
	-- The current fields are the baseline: no pickup sound for what you already hold.
	lastHands, lastPockets = readMine(StateSyncClientStore.publicPlayers())
	showLeaves(CargoFeedbackUtils.blocksView(lastHands))
	table.insert(stoppers, Charm.subscribe(StateSyncClientStore.publicPlayers, onPublic))
	table.insert(stoppers, CargoEvents.packets.Banked.listen(onBanked))
	local connection = RunService.RenderStepped:Connect(function(_deltaTime: number)
		step()
	end)
	table.insert(stoppers, function()
		connection:Disconnect()
	end)
end

function CargoFeedbackSystem.stop()
	session += 1
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for _, item in swoops do
		item.ghost:destroy()
	end
	table.clear(swoops)
	while #floating > 0 do
		release(floating[1])
	end
	showLeaves(false)
	lastHands = nil
	lastPockets = 0
end

function CargoFeedbackSystem.getState(): CargoFeedbackState
	return { swooping = #swoops, floating = #floating, leaves = #leaves, counters = table.clone(counters) }
end

return CargoFeedbackSystem
