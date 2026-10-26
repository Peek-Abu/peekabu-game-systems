--!strict
--[=[
	CosmeticRevealStore: the reveals this client has to show, one at a time. `current` is a Charm atom the reveal
	scene reads; `push` takes a grant from the server (CosmeticEvents.Granted) and shows it at once or queues it
	behind the one on screen (at most MAX_QUEUED wait; the oldest waiting one is dropped); `next` moves on when the
	player closes a reveal. A mirror of what the server sent; nothing here is sent back.

	@class CosmeticRevealStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Reveal = {
	ids: { string },
	source: string,
	-- A duplicate from a Locker open: the ribbon says what was refunded instead of "New ...".
	duplicate: boolean?,
	refund: number?,
	currency: ("gloom" | "gleam")?,
}

local MAX_QUEUED = 4

local initial: Reveal? = nil
local current = Charm.atom(initial)
local queue: { Reveal } = {}

local CosmeticRevealStore = {
	MAX_QUEUED = MAX_QUEUED,
	current = current,
}

function CosmeticRevealStore.push(reveal: Reveal)
	if #reveal.ids == 0 then
		return
	end
	local copy: Reveal = {
		ids = table.clone(reveal.ids),
		source = reveal.source,
		duplicate = reveal.duplicate,
		refund = reveal.refund,
		currency = reveal.currency,
	}
	if current() == nil then
		current(copy)
		return
	end
	table.insert(queue, copy)
	while #queue > MAX_QUEUED do
		table.remove(queue, 1)
	end
end

function CosmeticRevealStore.next()
	-- Through a local: table.remove on an empty queue returns no value at all, and an atom called with no value
	-- reads instead of clearing.
	local following: Reveal? = table.remove(queue, 1)
	current(following)
end

-- Forgets everything (between specs).
function CosmeticRevealStore.reset()
	table.clear(queue)
	current(nil)
end

return CosmeticRevealStore
