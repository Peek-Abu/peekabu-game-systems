--!strict
--[=[
	HideServiceClient: the local side of hiding (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §4).
	The server decides everything; this client:

	- draws the hiding spots' prompts on paper (HideChip: the engine's own card is switched off with the Custom style)
	  and keeps HideStore.prompt current from the engine's Shown / Hidden events; a single press of C / L1, or a tap on
	  the chip (`press`), goes in;
	- offers no spot while the hands hold something too big to hide with, or while already hidden (a local zero range;
	  the server re-checks);
	- while the Player's HideSpotId attribute says it hides: the peek camera (the spot's HidePeek frame, looking about
	  with the mouse), its own body hidden from itself, the controls off, every other prompt off, the peek overlay; and
	  a tap of the `hide` action (C / L1), E, Jump or the chip asks to come out (HideEvents.Exit);
	- every hiding player's tucked pose, for everyone (HidePoseSystem).

	Spec-exempt shell (ProximityPrompts, Camera, PlayerModule, ByteNet); the words are the specced HideViewModel and the
	state the specced HideStore.

	@class HideServiceClient
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HideEvents = require(ReplicatedStorage.Shared.Features.Hide.Net.HideEvents)
local HideRules = require(ReplicatedStorage.Shared.Features.Hide.Rules.HideRules)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local CameraTypes = require(ReplicatedStorage.Client.Features.Camera.Data.CameraTypes)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)
local HidePoseSystem = require(ReplicatedStorage.Client.Features.Hide.Systems.HidePoseSystem)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local InputControlsSystem = require(ReplicatedStorage.Client.Features.Input.Systems.InputControlsSystem)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local HideChip = require(ReplicatedStorage.Client.UI.React.Screens.Hide.HideChip)
local HidePeekOverlay = require(ReplicatedStorage.Client.UI.React.Screens.Hide.HidePeekOverlay)

local player = Players.LocalPlayer
local stoppers: { () -> () } = {}
-- Each hiding prompt this client knows, with its store id.
local ids: { [ProximityPrompt]: number } = {}
local nextId = 0
local current: ProximityPrompt? = nil
local held: ProximityPrompt? = nil
local peekToken: number? = nil
local hiddenSpot: string? = nil
-- When the local player went into the current spot (server time), and the spots that push-outs closed to them.
local hiddenSince = 0
local cooling: { [string]: number } = {}
local counters = { exits = 0, entered = 0 }

local function isHidePrompt(instance: Instance): boolean
	return instance:IsA("ProximityPrompt")
		and instance.Name == HideConstants.PROMPT_NAME
		and instance.Parent ~= nil
		and instance.Parent:HasTag(HideConstants.SPOT_TAG)
end

-- The hand item's size, or nil when empty-handed.
local function heldSize(): string?
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(player.UserId)]
	local kind = if entry ~= nil then entry[CarryConstants.PUBLIC_FIELD] else nil
	if type(kind) ~= "string" then
		return nil
	end
	local def = CargoRegistry.get(kind)
	return if def ~= nil then def.size else "unknown"
end

local function release()
	local prompt = held
	held = nil
	if prompt ~= nil and prompt.Parent ~= nil then
		prompt:InputHoldEnd()
	end
end

local function adopt(prompt: ProximityPrompt)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	if ids[prompt] == nil then
		nextId += 1
		ids[prompt] = nextId
	end
end

local function forget(prompt: ProximityPrompt)
	if held == prompt then
		release()
	end
	local id = ids[prompt]
	if id ~= nil then
		HideStore.hidePrompt(id)
	end
	ids[prompt] = nil
	if current == prompt then
		current = nil
	end
end

-- A spot is offered only with empty hands or a small item, and never while hiding.
local function settleRanges()
	local size = heldSize()
	local open = hiddenSpot == nil and (size == nil or HideConstants.POCKETABLE_SIZES[size] == true)
	local now = os.clock()
	for prompt in ids do
		local parent = prompt.Parent
		local spotId = if parent ~= nil then parent:GetAttribute(HideConstants.SPOT_ID_ATTRIBUTE) else nil
		local untilTime = if type(spotId) == "string" then cooling[spotId] else nil
		local range = if open and (untilTime == nil or now >= untilTime) then HideConstants.ENTER_RANGE else 0
		if prompt.MaxActivationDistance ~= range then
			prompt.MaxActivationDistance = range
		end
	end
end

local function spotAnchor(spotId: string): Attachment?
	for _, tagged in CollectionService:GetTagged(HideConstants.SPOT_TAG) do
		if tagged:IsA("Attachment") and tagged:GetAttribute(HideConstants.SPOT_ID_ATTRIBUTE) == spotId then
			return tagged
		end
	end
	return nil
end

-- The local body hidden from (or shown back to) its own peek camera.
local function setBodyShown(shown: boolean)
	local character = player.Character
	if character == nil then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = if shown then 0 else 1
		end
	end
end

local function requestExit()
	if hiddenSpot ~= nil then
		counters.exits += 1
		HideEvents.packets.Exit.send(true)
	end
end

-- The peek: the spot's frame, turned toward the mouse (or the last touch) within PEEK_YAW / PEEK_PITCH.
local function peekMode(base: CFrame): CameraTypes.ModeDef
	return {
		kind = "custom",
		update = function(_dt: number): (CFrame, number?)
			local camera = Workspace.CurrentCamera
			local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1, 1)
			local mouse = UserInputService:GetMouseLocation()
			local x = math.clamp((mouse.X / math.max(viewport.X, 1)) * 2 - 1, -1, 1)
			local y = math.clamp((mouse.Y / math.max(viewport.Y, 1)) * 2 - 1, -1, 1)
			local turn = CFrame.Angles(0, -x * math.rad(HideConstants.PEEK_YAW), 0)
				* CFrame.Angles(-y * math.rad(HideConstants.PEEK_PITCH), 0, 0)
			return base * turn, HideConstants.PEEK_FOV
		end,
	}
end

-- Follows the server's word on where the local player hides.
local function onHiddenChanged()
	local spotId = player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE)
	local since = player:GetAttribute(HideConstants.PLAYER_SINCE_ATTRIBUTE)
	local nextSpot = if type(spotId) == "string" then spotId else nil
	if nextSpot == hiddenSpot then
		return
	end
	local left = hiddenSpot
	hiddenSpot = nextSpot
	local token = peekToken
	if token ~= nil then
		CameraServiceClient:removeMode(token)
		peekToken = nil
	end
	if nextSpot == nil then
		-- Pushed out for camping: the server refuses that spot a while, so it is not offered either.
		if left ~= nil and HideRules.camp(Workspace:GetServerTimeNow() - hiddenSince) == "out" then
			cooling[left] = os.clock() + HideConstants.SPOT_COOLDOWN_SECONDS
		end
		HideStore.setHidden(nil)
		setBodyShown(true)
		ProximityPromptService.Enabled = true
		task.spawn(InputControlsSystem.setEnabled, true)
		settleRanges()
		return
	end
	counters.entered += 1
	hiddenSince = if type(since) == "number" then since else Workspace:GetServerTimeNow()
	release()
	local anchor = spotAnchor(nextSpot)
	local kind = if anchor ~= nil then anchor:GetAttribute(HideConstants.SPOT_KIND_ATTRIBUTE) else nil
	local noun = if anchor ~= nil then anchor:GetAttribute(HideConstants.SPOT_NOUN_ATTRIBUTE) else nil
	local peek = if anchor ~= nil then anchor:GetAttribute(HideConstants.PEEK_ATTRIBUTE) else nil
	HideStore.setHidden({
		spotId = nextSpot,
		kind = if type(kind) == "string" then kind else "under",
		noun = if type(noun) == "string" then noun else "spot",
		since = if type(since) == "number" then since else Workspace:GetServerTimeNow(),
	})
	if typeof(peek) == "CFrame" then
		peekToken = CameraServiceClient:pushMode(peekMode(peek), HideConstants.PEEK_PRIORITY)
	end
	setBodyShown(false)
	ProximityPromptService.Enabled = false
	task.spawn(InputControlsSystem.setEnabled, false)
	settleRanges()
end

--[=[
	Holds (`down`) or releases the shown hiding prompt: the chip's touch path.
]=]
local function press(down: boolean)
	if not down then
		release()
		return
	end
	local prompt = current
	if prompt == nil or prompt.Parent == nil or held ~= nil then
		return
	end
	held = prompt
	prompt:InputHoldBegin()
end

-- The HUD widgets, given their presses as props (module-level, so their identity is stable).
local function ChipWidget(): React.ReactNode
	return React.createElement(HideChip, { onPress = press, onLeave = requestExit })
end

local function OverlayWidget(): React.ReactNode
	return React.createElement(HidePeekOverlay)
end

export type HideServiceClient = {
	dependencies: { string },
	init: (self: HideServiceClient) -> (),
	start: (self: HideServiceClient) -> (),
	stop: (self: HideServiceClient) -> (),
	getState: (self: HideServiceClient) -> { [string]: any },
	isHidden: (self: HideServiceClient) -> boolean,
	leave: (self: HideServiceClient) -> (),
}

local HideServiceClient: HideServiceClient = {
	dependencies = { "InputServiceClient", "CameraServiceClient", "StateSyncServiceClient" },

	init = function(_self)
		if not InputActionRegistry.has(HideConstants.ACTION) then
			InputActionRegistry.register(HideConstants.ACTION, {
				context = "gameplay",
				bindings = { keyboard = { HideConstants.KEYBOARD_KEY }, gamepad = { HideConstants.GAMEPAD_KEY } },
				description = "Hide in a spot (hold); leave it",
			})
		end
		if not HudRegistry.has("hidePeek") then
			HudRegistry.register("hidePeek", OverlayWidget, -100)
		end
		if not HudRegistry.has("hideChip") then
			HudRegistry.register("hideChip", ChipWidget, 1010)
		end
	end,

	start = function(_self)
		for _, instance in Workspace:GetDescendants() do
			if instance:IsA("ProximityPrompt") and isHidePrompt(instance) then
				adopt(instance)
			end
		end
		local added = Workspace.DescendantAdded:Connect(function(instance: Instance)
			if instance:IsA("ProximityPrompt") and instance.Name == HideConstants.PROMPT_NAME then
				-- The attachment's tag may land a frame after the prompt replicates.
				task.defer(function()
					if isHidePrompt(instance) then
						adopt(instance)
						settleRanges()
					end
				end)
			end
		end)
		local removing = Workspace.DescendantRemoving:Connect(function(instance: Instance)
			if instance:IsA("ProximityPrompt") and ids[instance] ~= nil then
				forget(instance)
			end
		end)
		local shown = ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
			if not isHidePrompt(prompt) then
				return
			end
			adopt(prompt)
			current = prompt
			local parent = prompt.Parent
			local noun = if parent ~= nil then parent:GetAttribute(HideConstants.SPOT_NOUN_ATTRIBUTE) else nil
			HideStore.showPrompt({
				id = ids[prompt],
				action = prompt.ActionText,
				noun = if type(noun) == "string" then noun else prompt.ObjectText,
				key = prompt.KeyboardKeyCode.Name,
				hold = prompt.HoldDuration,
			})
		end)
		local hidden = ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
			local id = ids[prompt]
			if id == nil then
				return
			end
			if held == prompt then
				release()
			end
			if current == prompt then
				current = nil
			end
			HideStore.hidePrompt(id)
		end)
		local holdBegan = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
			local id = ids[prompt]
			if id ~= nil and who == player then
				HideStore.holdBegan(id, Workspace:GetServerTimeNow())
			end
		end)
		local holdEnded = ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, who)
			local id = ids[prompt]
			if id ~= nil and who == player then
				HideStore.holdEnded(id)
			end
		end)
		local spotChanged =
			player:GetAttributeChangedSignal(HideConstants.PLAYER_SPOT_ATTRIBUTE):Connect(onHiddenChanged)
		local jumped = UserInputService.JumpRequest:Connect(requestExit)
		-- The hiding key's press (not its hold: the prompt keeps the hold) leaves a spot.
		local unbindHide = InputServiceClient:bind(HideConstants.ACTION, function(phase)
			if phase == "begin" then
				requestExit()
			end
		end)
		local unbindInteract = InputServiceClient:bind("interact", function(phase)
			if phase == "begin" then
				requestExit()
			end
		end)
		local elapsed = 0
		local ranges = RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			if elapsed >= 0.2 then
				elapsed = 0
				settleRanges()
			end
		end)
		local respawned = player.CharacterAdded:Connect(function()
			-- A new body: the server cleared the stay with the old one.
			task.defer(onHiddenChanged)
		end)
		table.insert(stoppers, function()
			added:Disconnect()
			removing:Disconnect()
			shown:Disconnect()
			hidden:Disconnect()
			holdBegan:Disconnect()
			holdEnded:Disconnect()
			spotChanged:Disconnect()
			jumped:Disconnect()
			unbindHide()
			unbindInteract()
			ranges:Disconnect()
			respawned:Disconnect()
		end)
		table.insert(stoppers, HidePoseSystem.start())
		onHiddenChanged()
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		release()
		local token = peekToken
		if token ~= nil then
			CameraServiceClient:removeMode(token)
			peekToken = nil
		end
		ProximityPromptService.Enabled = true
		table.clear(ids)
		HideStore.clear()
	end,

	isHidden = function(_self)
		return hiddenSpot ~= nil
	end,

	--[=[
		Asks to come out of the spot (nothing when not hiding).
	]=]
	leave = function(_self)
		requestExit()
	end,

	getState = function(_self)
		local prompts = 0
		for _ in ids do
			prompts += 1
		end
		return { hidden = hiddenSpot, prompts = prompts, counters = table.clone(counters) }
	end,
}

return HideServiceClient
