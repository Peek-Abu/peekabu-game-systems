--!strict
--[=[
	SoundVoiceTracker: the playing voices of each sound id, oldest first, and the per-id concurrency cap.
	`start` hands out a token and, when the id is already at its cap, names the oldest voice to stop.
	`finish` forgets a voice (it ended, or was stopped).

	@class SoundVoiceTracker
]=]

export type SoundVoiceTracker = {
	start: (self: SoundVoiceTracker, id: string, maxConcurrent: number?) -> (number, number?),
	finish: (self: SoundVoiceTracker, token: number) -> (),
	count: (self: SoundVoiceTracker, id: string) -> number,
}

local SoundVoiceTracker = {}

function SoundVoiceTracker.new(): SoundVoiceTracker
	local voices: { [string]: { number } } = {}
	local idOf: { [number]: string } = {}
	local nextToken = 0

	local tracker: SoundVoiceTracker = {
		start = function(self, id, maxConcurrent)
			local list = voices[id]
			if list == nil then
				list = {}
				voices[id] = list
			end
			local evicted: number? = nil
			if maxConcurrent ~= nil and #list >= maxConcurrent then
				evicted = list[1]
				self:finish(list[1])
			end
			nextToken += 1
			table.insert(list, nextToken)
			idOf[nextToken] = id
			return nextToken, evicted
		end,

		finish = function(_self, token)
			local id = idOf[token]
			if id == nil then
				return
			end
			idOf[token] = nil
			local list = voices[id]
			if list ~= nil then
				local index = table.find(list, token)
				if index ~= nil then
					table.remove(list, index)
				end
			end
		end,

		count = function(_self, id)
			local list = voices[id]
			return if list ~= nil then #list else 0
		end,
	}
	return tracker
end

return SoundVoiceTracker
