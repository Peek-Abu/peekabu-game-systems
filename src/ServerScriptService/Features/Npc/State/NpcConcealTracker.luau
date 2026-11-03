--!strict
--[=[
	NpcConcealTracker: who is concealed from NPCs (a stealth move, a hiding spot), by which sources, and which NPCs
	witnessed each source begin. A player is concealed from an NPC while any source holds them that this NPC did not
	see begin; a witness keeps seeing them through that source.

	@class NpcConcealTracker
]=]

-- One source's hold on a player: the NPC ids (NpcRosterTracker) that saw it begin.
type Hold = { [number]: true }

export type NpcConcealTracker = {
	conceal: (self: NpcConcealTracker, userId: number, source: string, witnesses: { number }) -> (),
	reveal: (self: NpcConcealTracker, userId: number, source: string) -> (),
	isConcealed: (self: NpcConcealTracker, userId: number) -> boolean,
	isConcealedFrom: (self: NpcConcealTracker, userId: number, npcId: number) -> boolean,
	forgetNpc: (self: NpcConcealTracker, npcId: number) -> (),
	clear: (self: NpcConcealTracker, userId: number) -> (),
}

local NpcConcealTracker = {}

function NpcConcealTracker.new(): NpcConcealTracker
	local holds: { [number]: { [string]: Hold } } = {}

	local tracker: NpcConcealTracker = {
		conceal = function(_self, userId, source, witnesses)
			local sources = holds[userId]
			if sources == nil then
				sources = {}
				holds[userId] = sources
			end
			local hold: Hold = {}
			for _, npcId in witnesses do
				hold[npcId] = true
			end
			sources[source] = hold
		end,

		reveal = function(_self, userId, source)
			local sources = holds[userId]
			if sources == nil then
				return
			end
			sources[source] = nil
			if next(sources) == nil then
				holds[userId] = nil
			end
		end,

		isConcealed = function(_self, userId)
			return holds[userId] ~= nil
		end,

		isConcealedFrom = function(_self, userId, npcId)
			local sources = holds[userId]
			if sources == nil then
				return false
			end
			for _, hold in sources do
				if hold[npcId] == nil then
					return true
				end
			end
			return false
		end,

		forgetNpc = function(_self, npcId)
			for _, sources in holds do
				for _, hold in sources do
					hold[npcId] = nil
				end
			end
		end,

		clear = function(_self, userId)
			holds[userId] = nil
		end,
	}
	return tracker
end

return NpcConcealTracker
