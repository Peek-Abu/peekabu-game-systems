--!strict
--[=[
	AnimationGrantTracker: the server's record of which action each player's character is playing, per
	layer, so AnimationServiceServer can apply the interruption rule (a `protected` action holds its layer)
	and end grants early.

	Native characters replicate their own animations: the OWNING client plays the track on its
	character's Animator and Roblox replicates it to every other client. So a grant is one packet to the
	owner (`senders.started`), and ending it early is another (`senders.stopped`). The tracker only
	remembers what it sent: an entry with a duration expires on its own, and a looped (open-ended) entry
	lasts until it is cleared or replaced.

	Pure: the clock, the "does this player have a character" check and the packet senders are injected,
	so the spec runs without Players, characters or ByteNet.

	@class AnimationGrantTracker
]=]

export type Entry<D> = {
	key: string,
	data: D,
	startMs: number,
	durationMs: number?,
}

export type Senders<D> = {
	started: (player: Player, key: string, data: D, durationMs: number?) -> (),
	stopped: (player: Player, key: string) -> (),
}

-- Matches the channel results AnimationServiceServer already handles.
export type SetResult = "created" | "replaced" | "no-body"

export type Tracker<D> = {
	get: (self: Tracker<D>, player: Player, key: string) -> Entry<D>?,
	set: (self: Tracker<D>, player: Player, key: string, data: D, startMs: number, durationMs: number?) -> SetResult,
	clear: (self: Tracker<D>, player: Player, key: string) -> boolean,
	-- Forget a player's entries WITHOUT sending anything (they left, or their character was replaced and
	-- its tracks died with it).
	forget: (self: Tracker<D>, player: Player) -> (),
}

local AnimationGrantTracker = {}

--[=[
	@param senders Senders<D> -- packet senders to the owning client
	@param nowMs () -> number -- the clock grants are stamped and expired against
	@param hasBody (player: Player) -> boolean -- whether the player has a character to play on
	@return Tracker<D>
]=]
function AnimationGrantTracker.new<D>(
	senders: Senders<D>,
	nowMs: () -> number,
	hasBody: (player: Player) -> boolean
): Tracker<D>
	local byPlayer: { [Player]: { [string]: Entry<D> } } = {}

	-- The live entry on `key`, dropping it first if its duration has run out.
	local function live(player: Player, key: string): Entry<D>?
		local entries = byPlayer[player]
		local entry = if entries ~= nil then entries[key] else nil
		if entry == nil then
			return nil
		end
		local durationMs = entry.durationMs
		if durationMs ~= nil and nowMs() >= entry.startMs + durationMs then
			entries[key] = nil
			return nil
		end
		return entry
	end

	local tracker: Tracker<D> = {
		get = function(_self, player, key)
			return live(player, key)
		end,

		set = function(_self, player, key, data, startMs, durationMs)
			if not hasBody(player) then
				return "no-body"
			end
			local replacing = live(player, key) ~= nil
			local entries = byPlayer[player]
			if entries == nil then
				entries = {}
				byPlayer[player] = entries
			end
			entries[key] = { key = key, data = data, startMs = startMs, durationMs = durationMs }
			senders.started(player, key, data, durationMs)
			return if replacing then "replaced" else "created"
		end,

		clear = function(_self, player, key)
			if live(player, key) == nil then
				return false
			end
			local entries = byPlayer[player]
			if entries ~= nil then
				entries[key] = nil
			end
			senders.stopped(player, key)
			return true
		end,

		forget = function(_self, player)
			byPlayer[player] = nil
		end,
	}
	return tracker
end

return AnimationGrantTracker
