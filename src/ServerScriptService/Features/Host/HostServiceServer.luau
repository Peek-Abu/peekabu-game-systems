--!strict
--[=[
	HostServiceServer: crew hosting in the hub (characters/launch/crew-hosting/DESIGN.md). A truck is a held Queue
	pad (QueuePad tagged, QueueHold = true): Queue keeps who is aboard, the seats, the countdown and the trip; this
	keeps who hosts it.

	- Every tick each held pad's members (boarding order) and countdown are synced into HostTruckTracker: the first
	  player in hosts, and when the host leaves the earliest member left takes over. The hosted trucks are published
	  as the `host` world entry, and each pad carries its host's UserId as the HOST_ATTRIBUTE attribute (the hub's
	  ghost bays and popping trucks read it).
	- START (host only) starts Queue's START_SECONDS countdown; CANCEL (host only) stops it; LEAVE (any member) puts
	  the player on the floor in front of the truck (HostRules.exit), so Queue drops them on its next sample.
	- A truck that nobody started for IDLE_SECONDS starts on its own, so an away host can't trap kids aboard.
	- KICK (host only) keeps a member off the truck until it empties; SET LOCK (host only) makes it friends only (the
	  host's Roblox friends, from Social's SocialFriendTracker; a pair not checked yet counts as not friends). Queue's
	  board filter asks HostRules.canBoard every sample; a refused player (a kicked member included) is put outside
	  with a toast saying why.
	- A friend who joins from an invite (Social's LaunchData, SocialRules.referrerFrom) is told, once their screen has
	  loaded, when the inviter is waiting in a truck.

	Spec-exempt shell (CollectionService, characters, ByteNet, the tick); the decisions are the specced HostRules,
	HostTruckTracker and HostSnapshotUtils.

	@class HostServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local HostShared = ReplicatedStorage.Shared.Features.Host
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local HostConstants = require(HostShared.Data.HostConstants)
local HostEvents = require(HostShared.Net.HostEvents)
local HostRules = require(HostShared.Rules.HostRules)
local HostTypes = require(HostShared.Data.HostTypes)
local HostTruckTracker = require(ServerScriptService.Features.Host.State.HostTruckTracker)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local SocialFriendTracker = require(ServerScriptService.Features.Social.State.SocialFriendTracker)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local SocialRules = require(ReplicatedStorage.Shared.Features.Social.Rules.SocialRules)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

local log = Logger.new("HostServiceServer")

local tracker = HostTruckTracker.new()
-- The held pads seen at the last tick, by Queue pad id.
local padById: { [string]: BasePart } = {}
local connections: { RBXScriptConnection } = {}
local stoppers: { () -> () } = {}
local accumulated = 0
local counters = { starts = 0, cancels = 0, leaves = 0, idleStarts = 0, kicks = 0, locks = 0, refused = 0 }

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function idsOf(players: { Player }): { number }
	local ids: { number } = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
end

local function isHeld(pad: BasePart): boolean
	return pad:GetAttribute(QueueConstants.HOLD_ATTRIBUTE) == true
end

local function publish()
	StateSyncWorldStore.set(HostConstants.WORLD_ENTRY, tracker:snapshot())
end

-- Syncs every held pad, forgets vanished ones, starts idle trucks, and publishes on change.
local function tick(now: number)
	local pads = QueueServiceServer.pads
	local seen: { [string]: BasePart } = {}
	local changed = false
	for _, instance in CollectionService:GetTagged(QueueConstants.TAG) do
		local padId = if instance:IsA("BasePart") and isHeld(instance) then pads:padIdOf(instance) else nil
		if padId ~= nil and instance:IsA("BasePart") then
			seen[padId] = instance
			local members = idsOf(pads:membersOf(instance))
			if tracker:sync(padId, members, pads:endsAtOf(instance) ~= nil, now) then
				changed = true
			end
			local host = tracker:hostOf(padId)
			if instance:GetAttribute(HostConstants.HOST_ATTRIBUTE) ~= host then
				instance:SetAttribute(HostConstants.HOST_ATTRIBUTE, host)
			end
		end
	end
	for padId in padById do
		local still: BasePart? = seen[padId]
		if still == nil then
			tracker:remove(padId)
			changed = true
		end
	end
	padById = seen
	for _, padId in tracker:idleDue(now) do
		local pad: BasePart? = padById[padId]
		if pad ~= nil and pads:startCountdown(pad, now, HostConstants.START_SECONDS) then
			counters.idleStarts += 1
			tracker:sync(padId, idsOf(pads:membersOf(pad)), true, now)
		end
	end
	if changed then
		publish()
	end
end

-- Queue's board filter: whether `player` may be aboard held pad `pad` now. Runs in Queue's tick: no yields.
local function boardFilter(pad: BasePart, player: Player, members: { Player }): boolean
	local padId = if isHeld(pad) then QueueServiceServer.pads:padIdOf(pad) else nil
	if padId == nil then
		return true
	end
	local host = tracker:hostOf(padId)
	local friend = host ~= nil and SocialFriendTracker.shared:areFriends(player.UserId, host)
	local kicked = tracker:isKicked(padId, player.UserId)
	local ok = HostRules.canBoard(player.UserId, host, idsOf(members), tracker:locked(padId), kicked, friend)
	return ok
end

-- A refused player: outside the truck, told why.
local function onRefused(pad: BasePart, player: Player)
	local padId = QueueServiceServer.pads:padIdOf(pad)
	if padId == nil then
		return
	end
	counters.refused += 1
	local character = player.Character
	if character ~= nil then
		character:PivotTo(HostRules.exit(pad.CFrame, pad.Size))
	end
	local text = HostConstants.TEXT.kicked
	if not tracker:isKicked(padId, player.UserId) then
		local host = tracker:hostOf(padId)
		local hostPlayer = if host ~= nil then Players:GetPlayerByUserId(host) else nil
		local name = if hostPlayer ~= nil then hostPlayer.DisplayName else HostConstants.TEXT.hostFallback
		text = string.format(HostConstants.TEXT.friendsOnly, name)
	end
	ToastServiceServer:send(player, { text = text })
end

-- A friend who came from an invite: told where the inviter is, if they wait in a truck.
local function onJoined(player: Player)
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	local launch = if ok and type(data) == "table" then data.LaunchData else nil
	local inviterId = SocialRules.referrerFrom(if type(launch) == "string" then launch else nil, player.UserId)
	if inviterId == nil then
		return
	end
	task.delay(HostConstants.INVITED_TOAST_DELAY, function()
		local inviter = Players:GetPlayerByUserId(inviterId)
		local pad = if inviter ~= nil then QueueServiceServer:padOf(inviter) else nil
		if inviter ~= nil and pad ~= nil and isHeld(pad) and player.Parent == Players then
			ToastServiceServer:send(player, { text = string.format(HostConstants.TEXT.invited, inviter.DisplayName) })
		end
	end)
end

-- The held truck `player` is aboard and whether they may do `action` there (to `target`), or nil.
local function truckFor(player: Player, action: HostTypes.Action, target: number?): BasePart?
	local pad = QueueServiceServer:padOf(player)
	if pad == nil or not isHeld(pad) then
		return nil
	end
	local padId = QueueServiceServer.pads:padIdOf(pad)
	if padId == nil then
		return nil
	end
	local members = idsOf(QueueServiceServer.pads:membersOf(pad))
	if not HostRules.canAct(action, player.UserId, tracker:hostOf(padId), members, target) then
		return nil
	end
	return pad
end

local function leave(player: Player, pad: BasePart)
	local character = player.Character
	if character == nil then
		return
	end
	character:PivotTo(HostRules.exit(pad.CFrame, pad.Size))
	counters.leaves += 1
end

local function handler(action: HostTypes.Action): (unknown, Player) -> ()
	return RequestHandler.wrap({
		name = `Host{action}`,
		rateLimit = HostConstants.REQUEST_RATE,
		handler = function(_data: unknown, player: Player)
			local pad = truckFor(player, action)
			if pad == nil then
				return
			end
			if action == "start" then
				if QueueServiceServer.pads:startCountdown(pad, serverNow(), HostConstants.START_SECONDS) then
					counters.starts += 1
				end
			elseif action == "cancel" then
				if QueueServiceServer.pads:cancelCountdown(pad) then
					counters.cancels += 1
				end
			elseif action == "leave" then
				leave(player, pad)
			end
		end,
	})
end

local onStart = handler("start")
local onCancel = handler("cancel")
local onLeave = handler("leave")

local onKick = RequestHandler.wrap({
	name = "Hostkick",
	rateLimit = HostConstants.REQUEST_RATE,
	validate = function(data: number, _player: Player)
		local ok = pcall(Guard.userId, data)
		return ok, if ok then nil else "not a UserId"
	end,
	handler = function(data: number, player: Player)
		local pad = truckFor(player, "kick", data)
		local padId = if pad ~= nil then QueueServiceServer.pads:padIdOf(pad) else nil
		-- Queue's filter now refuses them: its next sample takes them off and onRefused puts them outside.
		if padId ~= nil and tracker:kick(padId, data) then
			counters.kicks += 1
		end
	end,
})

local onSetLock = RequestHandler.wrap({
	name = "Hostlock",
	rateLimit = HostConstants.REQUEST_RATE,
	handler = function(data: boolean, player: Player)
		local pad = truckFor(player, "lock")
		local padId = if pad ~= nil then QueueServiceServer.pads:padIdOf(pad) else nil
		if padId ~= nil and tracker:setLocked(padId, data == true) then
			counters.locks += 1
			publish()
		end
	end,
})

export type HostServiceServer = {
	dependencies: { string },
	start: (self: HostServiceServer) -> (),
	stop: (self: HostServiceServer) -> (),
	getState: (self: HostServiceServer) -> { [string]: any },
	hostOf: (self: HostServiceServer, pad: BasePart) -> number?,
}

local HostServiceServer: HostServiceServer = {
	dependencies = { "QueueServiceServer", "StateSyncServiceServer", "ToastServiceServer" },

	--[=[
		Listens for Start, Cancel, Leave, Kick and SetLock, sets Queue's board filter, and ticks the trucks.
	]=]
	start = function(_self)
		publish()
		QueueServiceServer.pads:setBoardFilter(boardFilter)
		local refusedConnection = QueueServiceServer.pads.refused:Connect(onRefused)
		table.insert(stoppers, function()
			refusedConnection:Disconnect()
		end)
		table.insert(connections, Players.PlayerAdded:Connect(onJoined))
		local function listen(listener: (unknown, Player) -> ()): (data: boolean, player: Player?) -> ()
			return function(data, player)
				if player then
					listener(data, player)
				end
			end
		end
		table.insert(stoppers, HostEvents.packets.Start.listen(listen(onStart)))
		table.insert(stoppers, HostEvents.packets.Cancel.listen(listen(onCancel)))
		table.insert(stoppers, HostEvents.packets.Leave.listen(listen(onLeave)))
		table.insert(
			stoppers,
			HostEvents.packets.Kick.listen(function(data: number, player: Player?)
				if player then
					onKick(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			HostEvents.packets.SetLock.listen(function(data: boolean, player: Player?)
				if player then
					onSetLock(data, player)
				end
			end)
		)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function(deltaTime)
				accumulated += deltaTime
				if accumulated >= HostConstants.TICK_INTERVAL then
					accumulated = 0
					tick(serverNow())
				end
			end)
		)
		log:info("crew hosting started")
	end,

	stop = function(_self)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		QueueServiceServer.pads:setBoardFilter(nil)
		for _, pad in padById do
			pad:SetAttribute(HostConstants.HOST_ATTRIBUTE, nil)
		end
		for padId in padById do
			tracker:remove(padId)
		end
		padById = {}
		StateSyncWorldStore.clear(HostConstants.WORLD_ENTRY)
	end,

	-- The host of a held pad (a truck), or nil when nobody is aboard.
	hostOf = function(_self, pad)
		local padId = QueueServiceServer.pads:padIdOf(pad)
		return if padId ~= nil then tracker:hostOf(padId) else nil
	end,

	getState = function(_self)
		local hosted = 0
		for padId in padById do
			if tracker:hostOf(padId) ~= nil then
				hosted += 1
			end
		end
		return {
			trucks = hosted,
			counters = table.clone(counters),
		}
	end,
}

return HostServiceServer
