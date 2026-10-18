--!strict
--[=[
	QueueTypes: the Queue feature's shapes. Types only (spec-exempt).

	@class QueueTypes
]=]

-- A pad's settings, read once from its attributes when it is tagged (QueuePadRules.config).
export type PadConfig = {
	capacity: number,
	countdown: number,
	destination: string,
}

export type PadStatus = "open" | "departing"

-- Game data riding a teleport: a match id on the way out, a summary on the way back. Flat and
-- capped (QueueConstants.MAX_PAYLOAD_*). Never security data: teleport data travels through the client.
export type QueuePayload = { [string]: string | number | boolean }

export type TicketKind = "depart" | "return"

-- What a teleport carries (JSON teleport data). `party` lists the user ids the arrival server expects;
-- the reserved server's access code, not this list, is what keeps strangers out.
export type QueueTicket = {
	kind: TicketKind,
	from: string?,
	role: string,
	party: { number },
	capacity: number,
	payload: QueuePayload,
}

-- One pad as every client sees it (the `queue` world entry). `endsAt` is server time
-- (workspace:GetServerTimeNow()); absent while nobody is aboard and while departing.
export type PadSnapshot = {
	members: { number },
	capacity: number,
	destination: string,
	endsAt: number?,
	departing: boolean,
}

export type QueueSnapshot = {
	pads: { [string]: PadSnapshot },
}

-- "live": this server is a registered place and teleports for real. "local": Studio or an unknown place;
-- every role runs in this one server and a teleport becomes a move.
export type Mode = "live" | "local"

export type Route = { kind: "local" } | { kind: "teleport", placeId: number }

-- What happens to a player joining an arrival server.
export type Admission = "crew" | "late" | "redirect"

export type QueueConfig = {
	-- Where a stranger is sent from a full arrival server (default: the party's source role).
	homeRole: string?,
	-- Studio verification only: route as a live server so the teleport path and its failure handling
	-- run (every teleport fails in Studio).
	forceLive: boolean,
}

export type QueueConfigUpdate = {
	homeRole: string?,
	forceLive: boolean?,
}

-- Builds the payload for a departing party (a match id). An error or a payload over the limits
-- sends `{}` instead. Runs inside the Heartbeat tick: it MUST NOT yield.
export type DepartDataResolver = (pad: BasePart, party: { Player }) -> QueuePayload

-- Where a player lands when a local move takes them to a role. `index` is their place in the party
-- (1-based), so a game can spread them out. Runs inside the Heartbeat tick: it MUST NOT yield. Returning
-- nil for any player fails the whole party's local move (the party stays on its pad).
export type ArrivalPoint = (player: Player, index: number) -> CFrame?

return {}
