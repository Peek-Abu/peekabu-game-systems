--!strict
--[=[
	ShiftLeavingSystem: the client half of the load screen in the place being left (the server half is the server's
	ShiftLeavingSystem; owner 2026-11-14: no walking around after the teleport is decided).

	- Leaving (ShiftEvents.Leaving, the moment the server decides a teleport): the trip goes to ShiftTransitStore.leaving,
	  so the transit screen shows the arrival's own card at once, over everything (ShiftTransitRules.cover: the trip's
	  route slip, or the welcome card on the way home). Movement is locked (InputControlsSystem, owner "leaving") and
	  game input sunk (a "ui" input context). Once the card is drawn, a still copy of it (the Overlay layer's ScreenGui,
	  made opaque) is handed to TeleportService:SetTeleportGui, so the teleport's own loading screen carries the same
	  card.
	- Staying: a Leaving packet saying the trip failed, or LEAVING_CLIENT_TIMEOUT with this client still here
	  (ShiftTransitRules.leavingExpired), takes the card down, clears the teleport GUI and gives control back.
	- Arriving by teleport: the copy the place left handed over (TeleportService:GetArrivingTeleportGui) is kept on
	  screen, above the boot's black, until this place's own cover shows a card or clears (at most ARRIVING_GUI_SECONDS).

	Spec-exempt shell (ByteNet, TeleportService, PlayerGui, input); the cover and the timeout are the specced
	ShiftTransitRules, the wire format the specced ShiftTransitUtils.

	@class ShiftLeavingSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ShiftEvents = require(ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftTransitUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftTransitUtils)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local InputControlsSystem = require(ReplicatedStorage.Client.Features.Input.Systems.InputControlsSystem)
local ShiftTransitRules = require(ReplicatedStorage.Client.Features.Shift.Rules.ShiftTransitRules)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)

local log = Logger.new("ShiftLeavingSystem")

-- The transit screen's layer root (UILayerHost names it UILayer_<layer>; the screen is mounted on Overlay).
local OVERLAY_GUI = "UILayer_Overlay"
-- The teleport GUI copy: its name, and its DisplayOrder (just over the Overlay layer's 300, under Debug's 1000).
local TELEPORT_GUI = "TransitTeleportGui"
local TELEPORT_GUI_ORDER = 301
-- How long the leaving card may take to draw before the copy is taken anyway (s).
local TELEPORT_GUI_DRAW_SECONDS = 1
-- The arriving copy comes down by itself this long after it was put up, whatever the cover does (s).
local ARRIVING_GUI_SECONDS = 20
-- The movement lock's owner name (InputControlsSystem).
local LOCK_OWNER = "leaving"

export type ShiftLeavingState = {
	leaving: string,
	since: number,
	locked: boolean,
	handedOver: number,
	arrivingCard: boolean,
}

local stoppers: { () -> () } = {}
-- Since when (os.clock()) this client has been leaving.
local since = 0
-- Bumped on every trip and every stay, so a copy taken for an old trip is never handed over.
local serial = 0
-- The "ui" input context sinking game input while leaving (nil: not held).
local inputToken: number? = nil
-- How many cards were handed to the teleport (the debugger's view).
local handedOver = 0
-- The arriving teleport GUI kept on screen, and until when (os.clock()).
local arrivingGui: ScreenGui? = nil
local arrivingUntil = 0

local function overlayGui(): ScreenGui?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui ~= nil then playerGui:FindFirstChild(OVERLAY_GUI) else nil
	return if gui ~= nil and gui:IsA("ScreenGui") then gui else nil
end

-- Whether the transit panel has drawn a card (its cover CanvasGroup holds the "slip" or "welcome" frame).
local function cardDrawn(): boolean
	local gui = overlayGui()
	local cover = if gui ~= nil then gui:FindFirstChild("cover") else nil
	return cover ~= nil and (cover:FindFirstChild("slip") ~= nil or cover:FindFirstChild("welcome") ~= nil)
end

-- Hands a still, opaque copy of the leaving card to the teleport's loading screen once it is drawn (at most
-- TELEPORT_GUI_DRAW_SECONDS after the trip), unless the trip is over by then.
local function handOver(trip: number)
	local deadline = os.clock() + TELEPORT_GUI_DRAW_SECONDS
	while not cardDrawn() and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	-- One more frame so the card's text and bar have laid out.
	RunService.Heartbeat:Wait()
	local gui = overlayGui()
	if trip ~= serial or ShiftTransitStore.leaving() == nil or gui == nil then
		return
	end
	local copy = gui:Clone()
	copy.Name = TELEPORT_GUI
	copy.DisplayOrder = TELEPORT_GUI_ORDER
	copy.ResetOnSpawn = false
	-- The live card may still be fading in: the copy is drawn fully opaque.
	local cover = copy:FindFirstChild("cover")
	if cover ~= nil and cover:IsA("CanvasGroup") then
		cover.GroupTransparency = 0
	end
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(copy)
	end)
	if ok then
		handedOver += 1
	else
		log:warn(`setting the teleport's loading screen failed: {err}`)
	end
end

local function lock(locked: boolean)
	if locked and inputToken == nil then
		inputToken = InputServiceClient:pushContext("ui", { sink = true })
	elseif not locked then
		local token = inputToken
		inputToken = nil
		if token ~= nil then
			InputServiceClient:removeContext(token)
		end
	end
	task.spawn(InputControlsSystem.setLocked, LOCK_OWNER, locked)
end

-- The trip failed (or never came): the card comes down and control comes back.
local function stay()
	serial += 1
	if ShiftTransitStore.leaving() == nil then
		return
	end
	ShiftTransitStore.leaving(nil)
	lock(false)
	-- An old card must never ride a later teleport; the next trip hands over its own.
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(nil)
	end)
	if not ok then
		log:warn(`clearing the teleport's loading screen failed: {err}`)
	end
end

local function leave(trip: ShiftTypes.TransitLeaving)
	serial += 1
	local wasLeaving = ShiftTransitStore.leaving() ~= nil
	since = os.clock()
	ShiftTransitStore.fadeSeconds(nil)
	ShiftTransitStore.leaving(trip)
	if not wasLeaving then
		lock(true)
	end
	task.spawn(handOver, serial)
end

local function onLeaving(packet: ShiftTypes.LeavingPacket)
	local trip = ShiftTransitUtils.leavingOf(packet)
	if trip == nil then
		stay()
	else
		leave(trip)
	end
end

local function dropArrivingCard()
	local kept = arrivingGui
	arrivingGui = nil
	if kept ~= nil then
		kept:Destroy()
	end
end

-- Arriving by teleport: keeps the card the place we left handed over on screen until this place's own cover takes over.
local function keepArrivingCard()
	local ok, gui = pcall(function(): Instance?
		return TeleportService:GetArrivingTeleportGui()
	end)
	if not ok or gui == nil or not gui:IsA("ScreenGui") then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		gui:Destroy()
		return
	end
	gui.DisplayOrder = TELEPORT_GUI_ORDER
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	arrivingGui = gui
	arrivingUntil = os.clock() + ARRIVING_GUI_SECONDS
end

local function tick()
	local now = os.clock()
	if ShiftTransitStore.leaving() ~= nil and ShiftTransitRules.leavingExpired(since, now) then
		log:warn("still here long after the teleport was decided; giving control back")
		stay()
	end
	if arrivingGui ~= nil then
		local cover = ShiftTransitStore.coverOf(
			ShiftTransitStore.covered(),
			ShiftTransitStore.slip(),
			ShiftTransitStore.welcome()
		)
		if cover ~= "black" or now >= arrivingUntil then
			dropArrivingCard()
		end
	end
end

local ShiftLeavingSystem = {}

function ShiftLeavingSystem.start()
	if #stoppers > 0 then
		return
	end
	keepArrivingCard()
	local stopLeaving = ShiftEvents.packets.Leaving.listen(onLeaving)
	local ticking = RunService.Heartbeat:Connect(tick)
	-- A card shown only for the arrival's black: the moment the cover changes, the live screen takes over.
	local stopCover = Charm.subscribe(ShiftTransitStore.covered, tick)
	table.insert(stoppers, function()
		stopLeaving()
		ticking:Disconnect()
		stopCover()
	end)
end

function ShiftLeavingSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	stay()
	dropArrivingCard()
end

function ShiftLeavingSystem.getState(): ShiftLeavingState
	local trip = ShiftTransitStore.leaving()
	return {
		leaving = if trip == nil then "" elseif trip.home then "home" else "shift",
		since = since,
		locked = inputToken ~= nil,
		handedOver = handedOver,
		arrivingCard = arrivingGui ~= nil,
	}
end

return ShiftLeavingSystem
