--!strict
--[=[
	EmoteWheelViewModel: what the in-game emote wheel (hold B) shows: the current employee's 4 wheel slots
	(CosmeticRules.lookFor), each with the emote's name, whether it is empty, and whether its clip is still to come
	(AnimationEmoteRegistry); where each slot sits on the circle (slot 1 at the top, clockwise); and which slot the
	pointer leans toward (none inside the middle).

	@class EmoteWheelViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local EmoteRules = require(ReplicatedStorage.Shared.Features.Emote.Rules.EmoteRules)

export type Slot = { slot: number, id: string?, name: string, empty: boolean, comingSoon: boolean }
export type View = { employee: string, slots: { Slot } }

local VM = {}

VM.SCENE = "emoteWheel"

function VM.view(loadout: CosmeticTypes.Loadout, owns: (id: string) -> boolean): View
	local employee = CosmeticRules.currentEmployee(loadout, owns)
	local slots: { Slot } = {}
	for slot, id in CosmeticRules.lookFor(loadout, employee, owns).wheel do
		local item = if id ~= "" then CosmeticRegistry.get(id) else nil
		table.insert(slots, {
			slot = slot,
			id = if item ~= nil then item.id else nil,
			name = if item ~= nil then item.name else "Empty",
			empty = item == nil,
			comingSoon = item ~= nil and AnimationRegistry.get(EmoteRules.clipKey(item.id)) == nil,
		})
	end
	return { employee = employee, slots = slots }
end

-- Where slot `slot` of `count` sits, from the wheel's centre (slot 1 straight up, then clockwise; +Y is down).
function VM.position(slot: number, count: number, radius: number): Vector2
	local angle = (slot - 1) / count * 2 * math.pi
	return Vector2.new(math.sin(angle) * radius, -math.cos(angle) * radius)
end

-- The slot the pointer (an offset from the centre) leans toward; nil inside `dead` (the middle).
function VM.pick(offset: Vector2, count: number, dead: number): number?
	if offset.Magnitude < dead then
		return nil
	end
	-- Angle clockwise from straight up, 0..2pi; each slot owns the arc centred on it.
	local angle = math.atan2(offset.X, -offset.Y) % (2 * math.pi)
	local step = 2 * math.pi / count
	return math.floor((angle + step / 2) / step) % count + 1
end

return VM
