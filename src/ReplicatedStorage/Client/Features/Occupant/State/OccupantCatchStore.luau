--!strict
--[=[
	OccupantCatchStore: the local player's catch as the UI sees it (Cleanup Crew M3 UI): `scaring` while the 0.6 s scare
	beat runs (the HUD goes dark), the incident report the server sent at the throw (the CCTV's slip, the Rehired card's
	"Dropped: ..."), and when the rehire notice arrived (os.clock). Written only by OccupantServiceClient from the
	server's packets; nothing here is sent back.

	@class OccupantCatchStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

local scaring = Charm.atom(false)
local initialReport: OccupantTypes.CatchReport? = nil
local report = Charm.atom(initialReport)
local initialRehired: number? = nil
local rehiredAt = Charm.atom(initialRehired)

local OccupantCatchStore = {
	scaring = scaring,
	report = report,
	rehiredAt = rehiredAt,
}

function OccupantCatchStore.snap()
	scaring(true)
end

function OccupantCatchStore.endSnap()
	scaring(false)
end

-- A new catch: its report replaces the last one, and the last rehire notice is forgotten.
function OccupantCatchStore.setReport(value: OccupantTypes.CatchReport)
	report({ room = value.room, clock = value.clock, backAt = value.backAt, dropped = table.clone(value.dropped) })
	rehiredAt(nil)
end

function OccupantCatchStore.rehired(now: number)
	rehiredAt(now)
end

function OccupantCatchStore.clear()
	scaring(false)
	report(nil)
	rehiredAt(nil)
end

return OccupantCatchStore
