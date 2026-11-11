--!strict
--[=[
	OccupantCatchStore: the local player's catch as the UI sees it (Cleanup Crew M3 UI): `scaring` while the 0.6 s scare
	beat runs (the HUD goes dark), the incident report the server sent at the throw (the CCTV's slip, the Rehired card's
	"Dropped: ..."), who caught the player (`caughtBy`: the catching kind's name, OccupantKindRegistry.wordsOf; the
	Manager when unnamed), and when the rehire notice arrived (os.clock). Written only by OccupantServiceClient from the
	server's packets; nothing here is sent back.

	@class OccupantCatchStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

local scaring = Charm.atom(false)
local initialReport: OccupantTypes.CatchReport? = nil
local report = Charm.atom(initialReport)
-- The Manager: Harlow's words, the default kind's.
local DEFAULT_CAUGHT_BY = OccupantKindRegistry.wordsOf(OccupantKindRegistry.DEFAULT).caughtBy
local caughtBy = Charm.atom(DEFAULT_CAUGHT_BY)
local initialRehired: number? = nil
local rehiredAt = Charm.atom(initialRehired)

local OccupantCatchStore = {
	scaring = scaring,
	report = report,
	caughtBy = caughtBy,
	rehiredAt = rehiredAt,
}

function OccupantCatchStore.snap()
	scaring(true)
end

function OccupantCatchStore.endSnap()
	scaring(false)
end

-- A new catch: its report (and who caught them, `by`; nil: the Manager) replaces the last one, and the last rehire
-- notice is forgotten.
function OccupantCatchStore.setReport(value: OccupantTypes.CatchReport, by: string?)
	report({ room = value.room, clock = value.clock, backAt = value.backAt, dropped = table.clone(value.dropped) })
	caughtBy(by or DEFAULT_CAUGHT_BY)
	rehiredAt(nil)
end

function OccupantCatchStore.rehired(now: number)
	rehiredAt(now)
end

function OccupantCatchStore.clear()
	scaring(false)
	report(nil)
	caughtBy(DEFAULT_CAUGHT_BY)
	rehiredAt(nil)
end

return OccupantCatchStore
