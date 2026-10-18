--!strict
--[=[
	ToastServiceClient: receives toasts, plays their style's sound, keeps ToastStore current and expires
	toasts on time. Registers the ToastStack HUD widget during init (before the UI starts).

	Spec-exempt shell (ByteNet, RunService, Sound); the list moves are the specced ToastStore /
	ToastQueueUtils.

	@class ToastServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ToastEvents = require(ReplicatedStorage.Shared.Features.Toast.Net.ToastEvents)
local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local ToastStack = require(ReplicatedStorage.Client.UI.React.Screens.Hud.ToastStack)

-- Above the game's widgets, so a toast is never drawn under a HUD panel.
local HUD_ORDER = 1000
local EXPIRE_INTERVAL = 0.25

local stoppers: { () -> () } = {}

export type ToastServiceClient = {
	dependencies: { string },
	init: (self: ToastServiceClient) -> (),
	start: (self: ToastServiceClient) -> (),
	stop: (self: ToastServiceClient) -> (),
}

local ToastServiceClient: ToastServiceClient = {
	dependencies = { "SoundServiceClient" },

	init = function(_self)
		if not HudRegistry.has("toasts") then
			HudRegistry.register("toasts", ToastStack, HUD_ORDER)
		end
	end,

	start = function(_self)
		table.insert(
			stoppers,
			ToastEvents.packets.Show.listen(function(data)
				ToastStore.push(data.text, data.style, data.duration, os.clock())
				local style = ToastRegistry.get(data.style)
				local sound = if style ~= nil then style.sound else nil
				if sound ~= nil and SoundRegistry.has(sound) then
					SoundServiceClient:play(sound)
				end
			end)
		)
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= EXPIRE_INTERVAL then
				elapsed = 0
				ToastStore.expire(os.clock())
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,
}

return ToastServiceClient
