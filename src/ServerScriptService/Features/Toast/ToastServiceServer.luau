--!strict
--[=[
	ToastServiceServer: shows a short message on one player's or everyone's screen ("QUOTA MET",
	"You hear Harlow pacing faster…"). Requests are normalized by ToastRules; the client draws them in
	the style named (ToastRegistry).

	Spec-exempt shell (ByteNet); the decision is the specced ToastRules.

	@class ToastServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastShared = ReplicatedStorage.Shared.Features.Toast
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ToastEvents = require(ToastShared.Net.ToastEvents)
local ToastRegistry = require(ToastShared.Data.ToastRegistry)
local ToastRules = require(ToastShared.Rules.ToastRules)
local ToastTypes = require(ToastShared.Data.ToastTypes)

local log = Logger.new("ToastServiceServer")
local counters = { sent = 0, refused = 0 }

export type ToastServiceServer = {
	dependencies: { string },
	getState: (self: ToastServiceServer) -> { [string]: any },
	send: (self: ToastServiceServer, target: Player | "all", request: ToastTypes.ToastRequest) -> boolean,
}

local ToastServiceServer: ToastServiceServer = {
	dependencies = {},

	--[=[
		Shows `request` to one player or to "all". False (and a warning) for empty text.
	]=]
	send = function(_self, target, request)
		local toast, reason = ToastRules.normalize(request, ToastRegistry.has)
		if toast == nil then
			counters.refused += 1
			log:warn(`toast refused: {reason or "?"}`)
			return false
		end
		if target == "all" then
			ToastEvents.packets.Show.sendToAll(toast)
		else
			ToastEvents.packets.Show.sendTo(toast, target)
		end
		counters.sent += 1
		return true
	end,

	getState = function(_self)
		return { counters = table.clone(counters) }
	end,
}

return ToastServiceServer
