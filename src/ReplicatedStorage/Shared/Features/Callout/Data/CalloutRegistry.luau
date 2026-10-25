--!strict
--[=[
	CalloutRegistry: the pings (design §8): free, the same for everyone, each one word on a spot you aim at, with a
	small sound everyone on the server hears. In wheel order (clockwise from the top). Stickers are not here: they are
	Cosmetic items (`sticker` kind, owned through their pack) worn in the loadout's 4 sticker slots.

	@class CalloutRegistry
]=]

export type Ping = { id: string, word: string }

local PINGS: { Ping } = {
	{ id = "gloom", word = "Gloom here" },
	{ id = "loot", word = "Loot here" },
	{ id = "manager", word = "Manager!" },
	{ id = "help", word = "Help me!" },
	{ id = "truck", word = "To the truck" },
	{ id = "okay", word = "Okay!" },
}

local byId: { [string]: Ping } = {}
for _, ping in PINGS do
	byId[ping.id] = table.freeze(ping)
end

local CalloutRegistry = {}

function CalloutRegistry.pings(): { Ping }
	return PINGS
end

function CalloutRegistry.ping(id: string): Ping?
	return byId[id]
end

table.freeze(PINGS)
return table.freeze(CalloutRegistry)
