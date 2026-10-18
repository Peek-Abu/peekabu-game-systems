--!strict
--[=[
	ToastStore: the toasts on screen, as one Charm atom the HUD reads (ToastStack). Written only by
	ToastServiceClient.

	@class ToastStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local ToastConstants = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastConstants)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)
local ToastQueueUtils = require(ReplicatedStorage.Shared.Features.Toast.Utils.ToastQueueUtils)

local initial: { ToastTypes.Toast } = {}
local toasts = Charm.atom(initial)
local nextId = 0

local ToastStore = {
	toasts = toasts,
}

function ToastStore.push(text: string, style: string, duration: number, now: number)
	nextId += 1
	toasts(ToastQueueUtils.push(toasts(), {
		id = nextId,
		text = text,
		style = style,
		expiresAt = now + duration,
	}, ToastConstants.MAX_VISIBLE))
end

function ToastStore.expire(now: number)
	local list, changed = ToastQueueUtils.expire(toasts(), now)
	if changed then
		toasts(list)
	end
end

return ToastStore
