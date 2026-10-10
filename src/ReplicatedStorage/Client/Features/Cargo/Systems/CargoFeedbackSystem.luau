--!strict
--[=[
	CargoFeedbackSystem: how cargo feels on this client (Cleanup Crew spec §7 "Banking: item swoops into the
	truck, cha-ching, '+15' floater, clearance bar fills"; §4 "Office plant: leaves partly block your view").
	- `Banked` (server → all): a ghost of each loaded item swoops on an arc into the truck bed, shrinking and
	  spinning (CargoFeedbackUtils.arc); when the last lands, a cha-ching at the bed and a rising "+N" per amount
	  (clearance green, bonus blue; CargoFeedbackUtils.floaters). The clearance bar is the HUD's.
	- Your public fields: a pickup sound when something new comes into your hands, a pocket sound when a pocket
	  fills, and plant leaves in front of your camera while your hands hold a blocksView item.
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
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoAssets = require(CargoShared.Data.CargoAssets)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoEvents = require(CargoShared.Net.CargoEvents)
local CargoFeedbackUtils = require(CargoShared.Utils.CargoFeedbackUtils)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

type Swoop = {
	part: Part,
	from: Vector3,
	to: Vector3,
	size: Vector3,
	started: number,
}

export type CargoFeedbackState = {
	swooping: number,
	leaves: number,
	counters: { [string]: number },
}

local log = Logger.new("CargoFeedbackSystem")

local swoops: { Swoop } = {}
local leaves: { BasePart } = {}
local lastHands: string? = nil
local lastPockets = 0
local counters = { banked = 0, swoops = 0, floaters = 0, pickups = 0, pockets = 0, played = 0, pending = 0 }
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
	SoundServiceClient:play(id, options)
end

local function floater(at: Vector3, index: number, item: CargoFeedbackUtils.Floater)
	local anchor = Instance.new("Attachment")
	anchor.Name = "CargoFloater"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = at + Vector3.new(0, 1 + index * CargoConstants.FLOATER_SPACING, 0)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 48)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = CargoConstants.FLOATER_DISTANCE
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = CargoConstants.FLOATER_FONT
	label.TextScaled = true
	label.Text = item.text
	label.TextColor3 = if item.tone == "bonus" then CargoConstants.BONUS_COLOR else CargoConstants.CLEARANCE_COLOR
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = anchor
	local info = TweenInfo.new(CargoConstants.FLOATER_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, CargoConstants.FLOATER_RISE, 0) }):Play()
	local fade = TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
	fade.Completed:Once(function()
		anchor:Destroy()
	end)
	fade:Play()
	counters.floaters += 1
end

local function swoop(kind: string, from: Vector3, to: Vector3)
	-- A delayed swoop that lands after stop() would leak a part nothing steps or cleans up.
	if #stoppers == 0 then
		return
	end
	local def = CargoRegistry.get(kind)
	if def == nil then
		return
	end
	local part = Instance.new("Part")
	part.Name = "CargoSwoop"
	part.Size = def.partSize
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(from)
	part.Parent = Workspace
	table.insert(swoops, { part = part, from = from, to = to, size = def.partSize, started = os.clock() })
	counters.swoops += 1
end

local function onBanked(data: CargoFeedbackUtils.BankedMessage)
	counters.banked += 1
	play("cargoSwoosh", { at = data.from })
	for index, kind in data.kinds do
		task.delay((index - 1) * CargoConstants.SWOOP_STAGGER, swoop, kind, data.from, data.to)
	end
	local landing = math.max(0, #data.kinds - 1) * CargoConstants.SWOOP_STAGGER + CargoConstants.SWOOP_SECONDS
	task.delay(landing, function()
		if #stoppers == 0 then
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
			item.part:Destroy()
			table.remove(swoops, index)
		else
			local scale = 1 + (CargoConstants.SWOOP_END_SCALE - 1) * alpha
			item.part.Size = item.size * scale
			item.part.CFrame = CFrame.new(
				CargoFeedbackUtils.arc(item.from, item.to, alpha, CargoConstants.SWOOP_HEIGHT)
			) * CFrame.Angles(0, alpha * math.pi * 2, 0)
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

-- The local player's hands kind and pocket count, from the public fields.
local function readMine(map: PublicPlayerTypes.PublicPlayerMap): (string?, number)
	local me = map[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	if me == nil then
		return nil, 0
	end
	local hands = me[CarryConstants.PUBLIC_FIELD]
	local pockets = 0
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		if me[field] ~= nil then
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
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for _, item in swoops do
		item.part:Destroy()
	end
	table.clear(swoops)
	showLeaves(false)
	lastHands = nil
	lastPockets = 0
end

function CargoFeedbackSystem.getState(): CargoFeedbackState
	return { swooping = #swoops, leaves = #leaves, counters = table.clone(counters) }
end

return CargoFeedbackSystem
