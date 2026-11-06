--!strict
--[=[
	SocialPromptSystem: Roblox's own event RSVP and notification opt-in prompts, at a calm moment: when the player is
	back in the hub from a finished shift (their review card appears on the depot board: the depot's `review` shell
	in their PlayerGui), PROMPT_DELAY seconds later, at most one prompt per visit (SocialPromptUtils.pick): the RSVP for
	the next upcoming event they have not answered (SocialService, so the launch event needs no id in the code), else
	the notification opt-in when Roblox says it may show (ExperienceNotificationService:CanPromptOptInAsync, false once
	they opted in or said no). Each is asked once a session; Roblox draws and words the prompts.

	Spec-exempt shell (SocialService, ExperienceNotificationService, CollectionService); the choice is the specced
	SocialPromptUtils.

	@class SocialPromptSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local SocialConstants = require(ReplicatedStorage.Shared.Features.Social.Data.SocialConstants)
local SocialPromptUtils = require(ReplicatedStorage.Client.Features.Social.Utils.SocialPromptUtils)

local log = Logger.new("SocialPromptSystem")

local asked: SocialPromptUtils.Asked = {}
local busy = false
local connections: { RBXScriptConnection } = {}

-- The next event that has not started, and the player's answer to it ("None", "Going", "NotGoing"); nil without one.
local function nextEvent(): (string?, string?)
	local ok, events = pcall(function()
		return SocialService:GetUpcomingExperienceEventsAsync()
	end)
	if not ok or type(events) ~= "table" then
		return nil, nil
	end
	for _, event in events do
		if
			type(event) == "table"
			and event.HasStarted ~= true
			and event.HasEnded ~= true
			and type(event.Id) == "string"
		then
			local id: string = event.Id
			local answered, status = pcall(function()
				return SocialService:GetEventRsvpStatusAsync(id)
			end)
			if answered then
				return id, status.Name
			end
			return nil, nil
		end
	end
	return nil, nil
end

local function canOptIn(): boolean
	local ok, allowed = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	return ok and allowed == true
end

-- Back in the hub with a review card: one prompt, after a moment to read the board.
local function onReturned()
	if busy then
		return
	end
	busy = true
	task.delay(SocialConstants.PROMPT_DELAY, function()
		local eventId, rsvp = nextEvent()
		local prompt = SocialPromptUtils.pick({ rsvp = rsvp, canOptIn = canOptIn(), asked = asked })
		if prompt == "rsvp" and eventId ~= nil then
			asked.rsvp = true
			local ok, err = pcall(function()
				SocialService:PromptRsvpToEventAsync(eventId)
			end)
			if not ok then
				log:debug(`RSVP prompt failed: {tostring(err)}`)
			end
		elseif prompt == "notifications" then
			asked.notifications = true
			local ok, err = pcall(function()
				ExperienceNotificationService:PromptOptIn()
			end)
			if not ok then
				log:debug(`notification prompt failed: {tostring(err)}`)
			end
		end
		busy = false
	end)
end

local SocialPromptSystem = {}

function SocialPromptSystem.start()
	if #connections > 0 then
		return
	end
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(DepotConstants.BILLBOARD_TAGS.review):Connect(onReturned)
	)
	if #CollectionService:GetTagged(DepotConstants.BILLBOARD_TAGS.review) > 0 then
		onReturned()
	end
end

function SocialPromptSystem.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

return SocialPromptSystem
