--!strict
--[=[
	InputContextTracker: the input context stack (bottom first). A push returns a token; removing by
	token rather than popping lets two systems add and remove contexts in any order without removing
	each other's. The base context is implicit (see InputBindingRules.reachable) and never on the stack.

	@class InputContextTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputTypes = require(ReplicatedStorage.Client.Features.Input.Data.InputTypes)

type ContextEntry = InputTypes.ContextEntry

export type InputContextTracker = {
	push: (self: InputContextTracker, name: string, sink: boolean) -> number,
	remove: (self: InputContextTracker, token: number) -> boolean,
	snapshot: (self: InputContextTracker) -> { ContextEntry },
}

local InputContextTracker = {}

function InputContextTracker.new(): InputContextTracker
	local stack: { ContextEntry } = {}
	local nextToken = 0

	local tracker: InputContextTracker = {
		push = function(_self, name, sink)
			nextToken += 1
			table.insert(stack, { token = nextToken, name = name, sink = sink })
			return nextToken
		end,

		remove = function(_self, token)
			for index, entry in stack do
				if entry.token == token then
					table.remove(stack, index)
					return true
				end
			end
			return false
		end,

		snapshot = function(_self)
			return table.clone(stack)
		end,
	}
	return tracker
end

return InputContextTracker
