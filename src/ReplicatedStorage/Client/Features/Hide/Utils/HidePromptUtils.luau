--!strict
--[=[
	HidePromptUtils: finds the hiding spots' pieces in the world on this client (reads only). Split out of
	HideServiceClient.

	- `isHidePrompt`: whether an instance is a hiding spot's prompt (on its tagged anchor or one of its reach sides).
	- `spotAnchor`: the tagged anchor attachment of the spot with an id, if it is in the world.

	@class HidePromptUtils
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

local HidePromptUtils = {}

-- A spot's prompt: on its tagged anchor, or on one of its other sides (an untagged HideReach attachment carrying the
-- spot's id: a desk or a table is reached from all round).
function HidePromptUtils.isHidePrompt(instance: Instance): boolean
	local parent = instance.Parent
	return instance:IsA("ProximityPrompt")
		and instance.Name == HideConstants.PROMPT_NAME
		and parent ~= nil
		and (
			parent:HasTag(HideConstants.SPOT_TAG)
			or (parent.Name == HideConstants.REACH_NAME and parent:GetAttribute(HideConstants.SPOT_ID_ATTRIBUTE) ~= nil)
		)
end

function HidePromptUtils.spotAnchor(spotId: string): Attachment?
	for _, tagged in CollectionService:GetTagged(HideConstants.SPOT_TAG) do
		if tagged:IsA("Attachment") and tagged:GetAttribute(HideConstants.SPOT_ID_ATTRIBUTE) == spotId then
			return tagged
		end
	end
	return nil
end

return HidePromptUtils
