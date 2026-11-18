--!strict
--[=[
	SkillCheckStore: this client's closing ring. `ring` is the ring the server sent (nil: none showing), `result` the
	server's last verdict (which ring, hit or miss, and when it came, on os.clock) and `seen` how many rings this player
	has seen this session (the "Line it up!" hint shows for the first few). SkillCheckServiceClient writes them; the
	ring HUD (SkillCheckHud) reads them. Charm atoms.

	@class SkillCheckStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local SkillCheckTypes = require(ReplicatedStorage.Shared.Features.SkillCheck.Data.SkillCheckTypes)

export type Result = { id: number, hit: boolean, at: number }

local noRing: SkillCheckTypes.Ring? = nil
local noResult: Result? = nil
local ring = Charm.atom(noRing)
local result = Charm.atom(noResult)
local seen = Charm.atom(0)

local SkillCheckStore = {
	ring = ring,
	result = result,
	seen = seen,
}

-- Shows `next`, counting it once.
function SkillCheckStore.show(next: SkillCheckTypes.Ring)
	local current = ring()
	if current == nil or current.id ~= next.id then
		seen(seen() + 1)
	end
	ring(next)
end

-- Keeps the server's verdict on ring `id`, which came at `at`.
function SkillCheckStore.judged(id: number, hit: boolean, at: number)
	result({ id = id, hit = hit, at = at })
end

-- Takes ring `id` off the screen (a later ring stays).
function SkillCheckStore.hide(id: number)
	local current = ring()
	if current ~= nil and current.id == id then
		ring(nil)
	end
end

-- Forgets everything (a new session, specs).
function SkillCheckStore.reset()
	ring(nil)
	result(nil)
	seen(0)
end

return SkillCheckStore
