--!strict
--[=[
	FilmMarkTracker: the film camera's saved camera marks, slots 1 to 9 (Ctrl + a number saves one). The glide plays
	them in slot order. Kept for this session only.

	@class FilmMarkTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FilmPathFormulas = require(ReplicatedStorage.Client.Features.Film.Utils.FilmPathFormulas)

type Mark = FilmPathFormulas.Mark

export type FilmMarkTracker = {
	_marks: { [number]: Mark },
	set: (self: FilmMarkTracker, slot: number, mark: Mark) -> boolean,
	get: (self: FilmMarkTracker, slot: number) -> Mark?,
	ordered: (self: FilmMarkTracker) -> { Mark },
	count: (self: FilmMarkTracker) -> number,
	clear: (self: FilmMarkTracker) -> (),
}

local SLOTS = 9

local FilmMarkTracker = {}

function FilmMarkTracker.new(): FilmMarkTracker
	local tracker: FilmMarkTracker = {
		_marks = {},

		set = function(self, slot, mark)
			if slot ~= math.floor(slot) or slot < 1 or slot > SLOTS then
				return false
			end
			self._marks[slot] = mark
			return true
		end,

		get = function(self, slot)
			return self._marks[slot]
		end,

		ordered = function(self)
			local list = {}
			for slot = 1, SLOTS do
				local mark = self._marks[slot]
				if mark ~= nil then
					table.insert(list, mark)
				end
			end
			return list
		end,

		count = function(self)
			return #self:ordered()
		end,

		clear = function(self)
			table.clear(self._marks)
		end,
	}
	return tracker
end

return FilmMarkTracker
