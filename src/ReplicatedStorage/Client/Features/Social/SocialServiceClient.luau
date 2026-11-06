--!strict
--[=[
	SocialServiceClient: the social perks on this client (plan docs/superpowers/plans/2026-10-28-social-perks.md).

	- `invite`: Roblox's invite prompt, its LaunchData naming this player (SocialRules.launchData) so the server can
	  pay the referral when the friend finishes their first shift.
	- `joinGroup`: Roblox's group join prompt for Icey Labs, then asks the server to check and pay the one-time perk.
	- The ask: when a shift's review shows a met contract and SocialRules.shouldAsk agrees (spaced out, never once the
	  game is a favorite), the ask card comes up once (SocialAskStore) and the server stores when. `favorite` opens
	  Roblox's favorite prompt. Nothing is paid for a favorite or a like.

	@class SocialServiceClient
]=]

local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local SocialConstants = require(ReplicatedStorage.Shared.Features.Social.Data.SocialConstants)
local SocialEvents = require(ReplicatedStorage.Shared.Features.Social.Net.SocialEvents)
local SocialRules = require(ReplicatedStorage.Shared.Features.Social.Rules.SocialRules)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SocialAskStore = require(ReplicatedStorage.Client.Features.Social.State.SocialAskStore)
local SocialPromptSystem = require(ReplicatedStorage.Client.Features.Social.Systems.SocialPromptSystem)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local log = Logger.new("SocialServiceClient")
local stoppers: { () -> () } = {}
-- Whether the game is already a favorite (nil until checked once this session).
local favorited: boolean? = nil

local function isFavorite(): boolean
	if favorited == nil then
		local ok, result = pcall(function()
			return AvatarEditorService:GetFavoriteAsync(game.PlaceId, Enum.AvatarItemType.Asset)
		end)
		favorited = ok and result == true
	end
	return favorited == true
end

-- Shows the ask on a met contract's review, once per review, when SocialRules.shouldAsk agrees.
local function onSnapshot(snapshot: ShiftTypes.ShiftSnapshot?)
	if snapshot == nil or snapshot.phase ~= "results" or snapshot.results == nil then
		return
	end
	local results = snapshot.results
	local shift = snapshot.shift
	if SocialAskStore.askedShift() == shift then
		return
	end
	local social = StateSyncClientStore.social()
	if not SocialRules.shouldAsk(social, Workspace:GetServerTimeNow(), results.quotaMet, false) then
		return
	end
	task.spawn(function()
		if isFavorite() or SocialAskStore.askedShift() == shift then
			return
		end
		if SocialAskStore.show(shift) then
			SocialEvents.packets.Asked.send(true)
		end
	end)
end

export type SocialServiceClient = {
	dependencies: { string },
	social: typeof(StateSyncClientStore.social),
	start: (self: SocialServiceClient) -> (),
	stop: (self: SocialServiceClient) -> (),
	invite: (self: SocialServiceClient) -> (),
	joinGroup: (self: SocialServiceClient) -> (),
	favorite: (self: SocialServiceClient) -> (),
	dismissAsk: (self: SocialServiceClient) -> (),
}

local SocialServiceClient: SocialServiceClient = {
	dependencies = { "StateSyncServiceClient" },
	social = StateSyncClientStore.social,

	start = function(_self)
		table.insert(stoppers, Charm.subscribe(ShiftStore.snapshot, onSnapshot))
		-- The event RSVP / notification prompt after a finished shift, back in the hub.
		SocialPromptSystem.start()
		table.insert(stoppers, SocialPromptSystem.stop)
		local completed = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
			if result == Enum.AvatarPromptResult.Success then
				favorited = true
			end
		end)
		table.insert(stoppers, function()
			completed:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		SocialAskStore.reset()
	end,

	--[=[
		Opens Roblox's invite prompt (when this player may send invites).
	]=]
	invite = function(_self)
		task.spawn(function()
			local player = Players.LocalPlayer
			local ok, allowed = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if not ok or not allowed then
				log:debug(`invites unavailable: {if ok then "not allowed" else allowed}`)
				return
			end
			local options = Instance.new("ExperienceInviteOptions")
			options.LaunchData = SocialRules.launchData(player.UserId)
			options.PromptMessage = SocialConstants.TEXT.invitePrompt
			local prompted, err = pcall(function()
				SocialService:PromptGameInvite(player, options)
			end)
			if not prompted then
				log:warn(`invite prompt failed: {err}`)
			end
		end)
	end,

	--[=[
		Opens Roblox's group join prompt, then asks the server to check membership and pay the perk.
	]=]
	joinGroup = function(_self)
		task.spawn(function()
			local ok, err = pcall(function()
				GroupService:PromptJoinAsync(SocialConstants.GROUP_ID)
			end)
			if not ok then
				log:warn(`group prompt failed: {err}`)
			end
			SocialEvents.packets.CheckGroup.send(true)
		end)
	end,

	--[=[
		Opens Roblox's favorite prompt for this experience and takes the ask down.
	]=]
	favorite = function(_self)
		SocialAskStore.hide()
		local ok, err = pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
		if not ok then
			log:warn(`favorite prompt failed: {err}`)
		end
	end,

	dismissAsk = function(_self)
		SocialAskStore.hide()
	end,
}

return SocialServiceClient
