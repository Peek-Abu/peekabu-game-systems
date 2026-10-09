--!strict
--[=[
	VfxScreenTracker: the live screen-effect requests, by token, in the order they were made.
	VfxFormulas.combineScreen turns the list into one target state.

	@class VfxScreenTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)

type ScreenRequest = VfxTypes.ScreenRequest

export type VfxScreenTracker = {
	add: (self: VfxScreenTracker, request: ScreenRequest) -> number,
	update: (self: VfxScreenTracker, token: number, request: ScreenRequest) -> boolean,
	remove: (self: VfxScreenTracker, token: number) -> boolean,
	list: (self: VfxScreenTracker) -> { ScreenRequest },
}

local VfxScreenTracker = {}

function VfxScreenTracker.new(): VfxScreenTracker
	local entries: { { token: number, request: ScreenRequest } } = {}
	local nextToken = 0

	local function indexOf(token: number): number?
		for index, entry in entries do
			if entry.token == token then
				return index
			end
		end
		return nil
	end

	local tracker: VfxScreenTracker = {
		add = function(_self, request)
			nextToken += 1
			table.insert(entries, { token = nextToken, request = request })
			return nextToken
		end,

		update = function(_self, token, request)
			local index = indexOf(token)
			if index == nil then
				return false
			end
			entries[index].request = request
			return true
		end,

		remove = function(_self, token)
			local index = indexOf(token)
			if index == nil then
				return false
			end
			table.remove(entries, index)
			return true
		end,

		list = function(_self)
			local list: { ScreenRequest } = {}
			for _, entry in entries do
				table.insert(list, entry.request)
			end
			return list
		end,
	}
	return tracker
end

return VfxScreenTracker
