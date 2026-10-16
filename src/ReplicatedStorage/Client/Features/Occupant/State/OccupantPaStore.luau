--!strict
--[=[
	OccupantPaStore: the PA's paper subtitle as the UI sees it (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-
	behaviours-design.md §5): the line on screen, whether it names someone (a call-out), and until when it shows
	(os.clock). Written only by OccupantWarningSystem (a corporate line in the mid warning stage, or the server's
	call-out); a newer line replaces the last.

	@class OccupantPaStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Notice = {
	line: string,
	callout: boolean,
	untilTime: number,
}

local initial: Notice? = nil
local notice = Charm.atom(initial)

local OccupantPaStore = {
	notice = notice,
}

function OccupantPaStore.show(line: string, callout: boolean, untilTime: number)
	notice({ line = line, callout = callout, untilTime = untilTime })
end

--[=[
	Clears the notice once `now` is past it (a newer one stays).
]=]
function OccupantPaStore.expire(now: number)
	local current = notice()
	if current ~= nil and now >= current.untilTime then
		notice(nil)
	end
end

function OccupantPaStore.clear()
	notice(nil)
end

return OccupantPaStore
