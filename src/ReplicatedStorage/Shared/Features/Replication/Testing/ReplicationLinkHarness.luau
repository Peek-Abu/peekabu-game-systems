--!strict
--[=[
	Replication harness (spec 2026-09-22 §10), ported from the spike's A/B.

	A deterministic one-way link. Both systems use identical links, with the same seed, so they meet the
	same network.

	- Unreliable: each packet independently arrives after `oneWay ± jitter`, or is lost. Jitter reorders
	  naturally.
	- Reliable (ordered, the RemoteEvent contract): a lost packet is resent after one RTO (2 × oneWay +
	  jitter, a realistic floor for a retransmit), and NOTHING behind it is delivered until it lands —
	  head-of-line blocking, the cost the spec (§1.1) charges to a reliable position stream.
]=]

local ReplicationLinkHarness = {}

export type Profile = {
	name: string,
	oneWayMs: number,
	jitterMs: number,
	loss: number,
}

type InFlight = { arrivalMs: number, seq: number, payload: buffer }

export type Link = {
	profile: Profile,
	rng: Random,
	flying: { InFlight },
	seq: number,
	lastReliableArrivalMs: number,
	bytesSent: number,
	packetsSent: number,
	lost: number,
	retransmits: number,
}

ReplicationLinkHarness.PROFILES = {
	studio = { name = "studio (15 ms, 2 ms jitter, 0% loss)", oneWayMs = 15, jitterMs = 2, loss = 0 },
	good = { name = "good (40 ms, 5 ms jitter, 0.5% loss)", oneWayMs = 40, jitterMs = 5, loss = 0.005 },
	spec = { name = "spec §10 (75 ms, 15 ms jitter, 3% loss)", oneWayMs = 75, jitterMs = 15, loss = 0.03 },
	mobile = { name = "mobile (110 ms, 35 ms jitter, 5% loss)", oneWayMs = 110, jitterMs = 35, loss = 0.05 },
}

function ReplicationLinkHarness.new(profile: Profile, seed: number): Link
	return {
		profile = profile,
		rng = Random.new(seed),
		flying = {},
		seq = 0,
		lastReliableArrivalMs = 0,
		bytesSent = 0,
		packetsSent = 0,
		lost = 0,
		retransmits = 0,
	}
end

local function transit(link: Link): number
	local p = link.profile
	return p.oneWayMs + (link.rng:NextNumber() * 2 - 1) * p.jitterMs
end

function ReplicationLinkHarness.sendUnreliable(link: Link, nowMs: number, payload: buffer)
	local bytes = buffer.len(payload)
	link.bytesSent += bytes
	link.packetsSent += 1
	if link.rng:NextNumber() < link.profile.loss then
		link.lost += 1
		return
	end
	link.seq += 1
	table.insert(link.flying, { arrivalMs = nowMs + transit(link), seq = link.seq, payload = payload })
end

function ReplicationLinkHarness.sendReliable(link: Link, nowMs: number, payload: buffer)
	local bytes = buffer.len(payload)
	link.bytesSent += bytes
	link.packetsSent += 1
	local arrival = nowMs + transit(link)
	while link.rng:NextNumber() < link.profile.loss do
		link.retransmits += 1
		link.bytesSent += bytes
		arrival += 2 * link.profile.oneWayMs + link.profile.jitterMs
	end
	-- Ordered: never before the previous reliable packet.
	arrival = math.max(arrival, link.lastReliableArrivalMs)
	link.lastReliableArrivalMs = arrival
	link.seq += 1
	table.insert(link.flying, { arrivalMs = arrival, seq = link.seq, payload = payload })
end

--[=[
	Everything that has arrived by `nowMs`, in arrival order.
]=]
function ReplicationLinkHarness.receive(link: Link, nowMs: number): { buffer }
	local arrived: { InFlight } = {}
	local keep: { InFlight } = {}
	for _, packet in link.flying do
		if packet.arrivalMs <= nowMs then
			table.insert(arrived, packet)
		else
			table.insert(keep, packet)
		end
	end
	link.flying = keep
	table.sort(arrived, function(a, b)
		if a.arrivalMs == b.arrivalMs then
			return a.seq < b.seq
		end
		return a.arrivalMs < b.arrivalMs
	end)
	local out: { buffer } = {}
	for _, packet in arrived do
		table.insert(out, packet.payload)
	end
	return out
end

return ReplicationLinkHarness
