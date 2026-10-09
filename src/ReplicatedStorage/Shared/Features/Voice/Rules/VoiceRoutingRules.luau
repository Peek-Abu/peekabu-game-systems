--!strict
--[=[
	VoiceRoutingRules: how a listener hears a speaker, from their public `dead` and `radio` fields. Pure;
	the server uses it for access lists and each client for its wiring, so both agree.

	@class VoiceRoutingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local VoiceTypes = require(ReplicatedStorage.Shared.Features.Voice.Data.VoiceTypes)

type Route = VoiceTypes.Route
type VoiceInfo = VoiceTypes.VoiceInfo

local VoiceRoutingRules = {}

function VoiceRoutingRules.route(listener: VoiceInfo, speaker: VoiceInfo, deadHearLiving: boolean): Route
	if speaker.dead then
		return if listener.dead then "direct" else "none"
	end
	if listener.dead then
		return if deadHearLiving then "spatial" else "none"
	end
	if listener.radio ~= nil and listener.radio == speaker.radio then
		return "radio"
	end
	return "spatial"
end

function VoiceRoutingRules.infoFrom(
	entry: PublicPlayerTypes.PublicPlayer?,
	deadField: string,
	radioField: string
): VoiceInfo
	if entry == nil then
		return { dead = false, radio = nil }
	end
	local radio = entry[radioField]
	return { dead = entry[deadField] == true, radio = if type(radio) == "string" then radio else nil }
end

--[=[
	Every userId (other than the speaker) whose route to `speakerId` is not `none`, sorted.
]=]
function VoiceRoutingRules.listenersOf(
	speakerId: number,
	infos: { [number]: VoiceInfo },
	deadHearLiving: boolean
): { number }
	local speaker = infos[speakerId]
	local list: { number } = {}
	if speaker == nil then
		return list
	end
	for userId, info in infos do
		if userId ~= speakerId and VoiceRoutingRules.route(info, speaker, deadHearLiving) ~= "none" then
			table.insert(list, userId)
		end
	end
	table.sort(list)
	return list
end

return VoiceRoutingRules
