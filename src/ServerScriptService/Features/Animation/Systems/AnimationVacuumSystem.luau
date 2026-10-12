--!strict
-- Server tool selection and accepted suction drive the shared animation grant owner.
-- This system never loads tracks, moves rig joints or trusts a client animation request.
export type Snapshot = {
	character: Model?,
	equipped: boolean,
	active: boolean,
	carrying: boolean,
	alive: boolean,
	authorized: boolean,
}
export type Sink = {
	available: (id: string) -> boolean,
	play: (id: string) -> boolean,
	stop: (id: string) -> (),
}
export type Controller = {
	update: (snapshot: Snapshot, now: number) -> (),
	stop: () -> (),
}
local AnimationVacuumSystem = {}
local EQUIP_SECONDS = 0.65
local STOW_SECONDS = 0.45
function AnimationVacuumSystem.new(sink: Sink): Controller
	local character: Model? = nil
	local selected = false
	local playing: string? = nil
	local equipUntil = 0
	local stowUntil = 0
	local function clear()
		if playing ~= nil then
			sink.stop(playing)
			playing = nil
		end
	end
	local function choose(id: string?)
		if playing == id then
			return
		end
		clear()
		if id ~= nil and sink.available(id) and sink.play(id) then
			playing = id
		end
	end
	local controller: Controller = {
		update = function(snapshot, now)
			if character ~= snapshot.character then
				clear()
				character = snapshot.character
				selected = false
				equipUntil = 0
				stowUntil = 0
			end
			if character == nil or not snapshot.alive or not snapshot.authorized or snapshot.carrying then
				clear()
				selected = false
				equipUntil = 0
				stowUntil = 0
				return
			end
			if snapshot.equipped and not selected then
				equipUntil = now + EQUIP_SECONDS
				stowUntil = 0
			elseif not snapshot.equipped and selected then
				stowUntil = now + STOW_SECONDS
				equipUntil = 0
			end
			selected = snapshot.equipped
			if selected then
				if now < equipUntil and sink.available("cleanupVacuumEquip") then
					choose("cleanupVacuumEquip")
				elseif snapshot.active then
					choose("cleanupVacuumUse")
				else
					choose("cleanupVacuumHold")
				end
			elseif now < stowUntil then
				choose("cleanupVacuumStow")
			else
				choose(nil)
			end
		end,
		stop = function()
			clear()
			character = nil
			selected = false
			equipUntil = 0
			stowUntil = 0
		end,
	}
	return controller
end
return AnimationVacuumSystem
