--!strict
--[=[
	LockerStore: client state for the Lost & Found Lockers:
	- `restricted`: whether paid random items are restricted for this player (starts `true`, fail-closed, until the
	  server sends `LockerEvents.Status`).
	- `selected`: which Locker's "What's inside" list is shown (`"gloom"` or `"gleam"`).
	- `oddsFor`: which Locker's odds sheet is open (`nil` when closed).
	- `opening`: the `LockerTypes.Outcome` currently playing its stage-1 opening animation (`nil` when idle).
	- `result`: the last refusal from the server (`{ locker, reason }`), cleared when switching Lockers or starting an
	  open.

	@class LockerStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)

type LockerId = LockerTypes.LockerId
type Outcome = LockerTypes.Outcome

export type Result = { locker: string, reason: string }

local restricted = Charm.atom(true)
local initialSelected: LockerId = "gloom"
local selected = Charm.atom(initialSelected)
local noOdds: LockerId? = nil
local oddsFor = Charm.atom(noOdds)
local noOpening: Outcome? = nil
local opening = Charm.atom(noOpening)
local noResult: Result? = nil
local result = Charm.atom(noResult)

local LockerStore = {
	restricted = restricted,
	selected = selected,
	oddsFor = oddsFor,
	opening = opening,
	result = result,
}

function LockerStore.setRestricted(value: boolean)
	restricted(value)
end

function LockerStore.select(id: LockerId)
	selected(id)
	result(nil)
end

function LockerStore.openOdds(id: LockerId)
	oddsFor(id)
end

function LockerStore.closeOdds()
	oddsFor(nil)
end

function LockerStore.startOpening(outcome: Outcome)
	result(nil)
	opening(table.clone(outcome))
end

function LockerStore.finishOpening(): Outcome?
	local current = opening()
	opening(nil)
	return current
end

function LockerStore.setResult(value: Result?)
	result(value)
end

function LockerStore.reset()
	restricted(true)
	selected("gloom")
	oddsFor(nil)
	opening(nil)
	result(nil)
end

return LockerStore
