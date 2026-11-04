--!strict
--[=[
	CalloutServiceClient: the chat wheel on this client (design §8; plan 2026-10-25 step 5).

	- Hold the `chatWheel` action (T, or d-pad up) to open the wheel (its scene is registered here, at init). The spot
	  a ping would mark is aimed as T goes down: where the mouse points (the screen's centre on a phone or gamepad),
	  out to CalloutConstants.PING_RANGE. Letting go over a ping or sticker sends it; a click or tap sends at once.
	- On phones, two round HUD buttons open the emote wheel and this wheel (ChatWheelButtons, registered here).
	- What the server tells everyone (CalloutEvents.Shown) is shown here: a sticker is thrown from the
	  sender's hand to where the server pinned it, above and ahead of them as they sent it, and stays there as they
	  move on (CalloutStickerSystem); it is kept for the crew list (CalloutStore). The sender's own client plays the
	  toss (one shared clip, faded over their idle; the engine shows it to everyone), unless they are hiding,
	  carrying, vacuuming or knocked out (EmployeeBusyUtils): then the sticker still flies, from where the hand is. A ping marks its spot (CalloutPingSystem) with a small sound.

	Spec-exempt shell (input, camera, packets); decisions in CalloutRules and ChatWheelViewModel, the effects in
	the specced systems.

	@class CalloutServiceClient
]=]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local React = require(ReplicatedStorage.Packages.React)
local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)
local CalloutRegistry = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutRegistry)
local CalloutEvents = require(ReplicatedStorage.Shared.Features.Callout.Net.CalloutEvents)
local CalloutRequestRules = require(ReplicatedStorage.Shared.Features.Callout.Rules.CalloutRequestRules)
local CalloutAssets = require(ReplicatedStorage.Client.Features.Callout.Data.CalloutAssets)
local CalloutStore = require(ReplicatedStorage.Client.Features.Callout.State.CalloutStore)
local CalloutWheelStore = require(ReplicatedStorage.Client.Features.Callout.State.CalloutWheelStore)
local CalloutPingSystem = require(ReplicatedStorage.Client.Features.Callout.Systems.CalloutPingSystem)
local CalloutStickerSystem = require(ReplicatedStorage.Client.Features.Callout.Systems.CalloutStickerSystem)
local AnimationServiceClient = require(ReplicatedStorage.Client.Features.Animation.AnimationServiceClient)
local EmployeeBusyUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeBusyUtils)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local UISoundSystem = require(ReplicatedStorage.Client.Features.UI.Systems.UISoundSystem)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local EmoteServiceClient = require(ReplicatedStorage.Client.Features.Emote.EmoteServiceClient)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local ChatWheelButtons = require(ReplicatedStorage.Client.UI.React.Screens.ChatWheel.ChatWheelButtons)
local ChatWheelScreen = require(ReplicatedStorage.Client.UI.React.Screens.ChatWheel.ChatWheelScreen)
local ChatWheelViewModel = require(ReplicatedStorage.Client.UI.React.Screens.ChatWheel.ChatWheelViewModel)

local janitor = Janitor.new()
-- The world folders pings and stickers show in, by name, made on first use.
local folders: { [string]: Folder } = {}

-- The spot a ping would mark now: where the mouse (or the screen's centre) points, within range of the body.
local function aimSpot(): Vector3?
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if camera == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local useMouse = UserInputService.MouseEnabled and not UserInputService.TouchEnabled
	local point = if useMouse
		then UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		else camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local reach = CalloutConstants.PING_RANGE * 0.9
	local hit = workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	local spot = if hit ~= nil then hit.Position else ray.Origin + ray.Direction * 30
	-- Kept inside the server's range of the body.
	local offset = spot - root.Position
	if offset.Magnitude > reach then
		spot = root.Position + offset.Unit * reach
	end
	return spot
end

local function send(pick: ChatWheelViewModel.Pick, spot: Vector3?)
	if pick.kind == "sticker" then
		CalloutEvents.packets.Request.send(CalloutRequestRules.build({ kind = "sticker", slot = pick.slot }))
	elseif spot ~= nil then
		CalloutEvents.packets.Request.send(CalloutRequestRules.build({ kind = "ping", id = pick.id, at = spot }))
	end
end

local function openWheel()
	if not CalloutWheelStore.open() then
		CalloutWheelStore.show(aimSpot())
		SceneStack.push(ChatWheelViewModel.SCENE)
	end
end

local function closeWheel(): (ChatWheelViewModel.Pick?, Vector3?)
	local pick, spot = CalloutWheelStore.hide()
	SceneStack.remove(ChatWheelViewModel.SCENE)
	return pick, spot
end

local function folder(name: string): Folder
	local existing: Folder? = folders[name]
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = workspace
	folders[name] = made
	return made
end

-- This player's own toss as their sticker goes out: the shared clip faded in over their idle and back out.
local function toss()
	local character = Players.LocalPlayer.Character
	if character == nil or EmployeeBusyUtils.busy(character) then
		return
	end
	local handle =
		AnimationServiceClient:play(CalloutConstants.TOSS_ANIMATION, { fadeTime = CalloutConstants.TOSS_FADE_IN })
	if handle ~= nil then
		task.delay(CalloutConstants.TOSS_FADE_START, function()
			handle:stop(CalloutConstants.TOSS_FADE_OUT)
		end)
	end
end

local function onShown(data: CalloutRequestRules.ShownPacket)
	local shown = CalloutRequestRules.shown(data)
	if shown == nil then
		return
	end
	local sender = Players:GetPlayerByUserId(shown.userId)
	if shown.kind == "sticker" then
		local at = os.clock()
		CalloutStore.sticker(shown.userId, shown.id, at)
		task.delay(CalloutConstants.STICKER_SECONDS, CalloutStore.expire, shown.userId, at)
		local spot = shown.at
		if spot ~= nil and shown.userId == Players.LocalPlayer.UserId then
			toss()
		end
		if spot ~= nil then
			-- It leaves the sender's throwing hand at the toss's release, as this client sees that hand.
			task.delay(CalloutConstants.STICKER_RELEASE, function()
				local character = if sender ~= nil then sender.Character else nil
				local hand = if character ~= nil then character:FindFirstChild("RightHand") else nil
				CalloutStickerSystem.show(
					folder("CalloutStickers"),
					shown.userId,
					spot,
					CalloutAssets.stickerImage(shown.id),
					GuiService.ReducedMotionEnabled,
					if hand ~= nil and hand:IsA("BasePart") then hand.Position else nil
				)
			end)
		end
	else
		local ping = CalloutRegistry.ping(shown.id)
		local at = shown.at
		if ping ~= nil and at ~= nil then
			CalloutPingSystem.show(folder("CalloutPings"), {
				userId = shown.userId,
				image = CalloutAssets.pingImage(ping.id),
				word = ping.word,
				who = if sender ~= nil then sender.DisplayName else "",
				at = at,
			})
			UISoundSystem.play(CalloutAssets.PING_SOUND)
		end
	end
end

export type CalloutServiceClient = {
	dependencies: { string },
	init: (self: CalloutServiceClient) -> (),
	start: (self: CalloutServiceClient) -> (),
	stop: (self: CalloutServiceClient) -> (),
	openWheel: (self: CalloutServiceClient) -> (),
}

local CalloutServiceClient: CalloutServiceClient = {
	dependencies = { "InputServiceClient", "EmoteServiceClient", "AnimationServiceClient" },

	init = function(_self)
		-- Phones: round buttons that open the emote and chat wheels (keys do it on PC and gamepads).
		if not HudRegistry.has("chatWheelButtons") then
			HudRegistry.register("chatWheelButtons", function()
				return React.createElement(ChatWheelButtons, {
					onEmotes = function()
						EmoteServiceClient:openWheel()
					end,
					onChat = openWheel,
				})
			end, 20)
		end
		if not SceneRegistry.has(ChatWheelViewModel.SCENE) then
			SceneRegistry.register({
				name = ChatWheelViewModel.SCENE,
				screens = {
					{
						layer = "Wheel",
						key = "chatWheel",
						component = function()
							return React.createElement(ChatWheelScreen, {
								onPick = function(pick: ChatWheelViewModel.Pick)
									local _, spot = closeWheel()
									send(pick, spot)
								end,
								onClose = function()
									closeWheel()
								end,
							})
						end,
					},
				},
				suppress = { mouse = true },
			})
		end
		if not InputActionRegistry.has(CalloutConstants.WHEEL_ACTION) then
			InputActionRegistry.register(CalloutConstants.WHEEL_ACTION, {
				context = "gameplay",
				bindings = {
					keyboard = { CalloutConstants.WHEEL_KEY },
					gamepad = { CalloutConstants.WHEEL_GAMEPAD },
				},
				description = "Hold to open the chat wheel (pings and stickers)",
			})
		end
	end,

	start = function(_self)
		local unbind = InputServiceClient:bind(CalloutConstants.WHEEL_ACTION, function(phase)
			if phase == "begin" then
				openWheel()
			else
				local pick, spot = closeWheel()
				if pick ~= nil then
					send(pick, spot)
				end
			end
		end)
		janitor:Add(unbind, true)
		janitor:Add(CalloutEvents.packets.Shown.listen(onShown), true)
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				CalloutStore.forget(player.UserId)
			end),
			"Disconnect"
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
		for name, made in folders do
			made:Destroy()
			folders[name] = nil
		end
	end,

	openWheel = function(_self)
		openWheel()
	end,
}

return CalloutServiceClient
