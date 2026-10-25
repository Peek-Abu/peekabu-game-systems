--!strict
--[=[
	ChatWheelViewModel: what the chat wheel (hold T) shows (design §8, the Chat wheel concept): the six pings on an
	inner ring (CalloutRegistry order, the first at the top, clockwise) and the player's 4 sticker slots at the
	corners (top-left, top-right, bottom-right, bottom-left), each with its picture or "+" when empty; and which one
	the pointer leans toward: a ping inside the ring's split, a sticker slot (by corner) outside it, nothing in the
	middle.

	@class ChatWheelViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalloutRegistry = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local CalloutAssets = require(ReplicatedStorage.Client.Features.Callout.Data.CalloutAssets)
local CalloutWheelStore = require(ReplicatedStorage.Client.Features.Callout.State.CalloutWheelStore)

export type PingView = { id: string, word: string, image: string }
export type StickerSlot = { slot: number, id: string?, name: string, image: string?, empty: boolean }
export type View = { pings: { PingView }, stickers: { StickerSlot } }
export type Pick = CalloutWheelStore.Pick

local VM = {}

VM.SCENE = "chatWheel"

function VM.view(loadout: CosmeticTypes.Loadout, owns: (id: string) -> boolean): View
	local pings: { PingView } = {}
	for _, ping in CalloutRegistry.pings() do
		table.insert(pings, { id = ping.id, word = ping.word, image = CalloutAssets.pingImage(ping.id) })
	end
	local stickers: { StickerSlot } = {}
	for slot, id in loadout.stickers do
		local item = if id ~= "" then CosmeticRegistry.get(id) else nil
		-- A sticker is owned through its pack.
		local pack = if item ~= nil then item.pack else nil
		local usable = item ~= nil and item.kind == "sticker" and (owns(id) or (pack ~= nil and owns(pack)))
		table.insert(stickers, {
			slot = slot,
			id = if usable and item ~= nil then item.id else nil,
			name = if usable and item ~= nil then item.name else "Empty",
			image = if usable then CalloutAssets.stickerImage(id) else nil,
			empty = not usable,
		})
	end
	return { pings = pings, stickers = stickers }
end

-- Where ping `index` of `count` sits from the centre (the first straight up, clockwise; +Y is down).
function VM.pingPosition(index: number, count: number, radius: number): Vector2
	local angle = (index - 1) / count * 2 * math.pi
	return Vector2.new(math.sin(angle) * radius, -math.cos(angle) * radius)
end

-- Where sticker slot `slot` sits: the corners, top-left first, clockwise.
function VM.stickerPosition(slot: number, reach: number): Vector2
	local corner = ({ Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(1, 1), Vector2.new(-1, 1) })[slot]
		or Vector2.zero
	return corner * reach
end

--[=[
	What the pointer (an offset from the centre) leans toward: nothing inside `dead`, a ping inside `split`, a sticker
	slot (by corner) beyond it.
]=]
function VM.pick(offset: Vector2, pings: { PingView }, dead: number, split: number): Pick?
	local distance = offset.Magnitude
	if distance < dead then
		return nil
	end
	if distance < split then
		local count = #pings
		local angle = math.atan2(offset.X, -offset.Y) % (2 * math.pi)
		local step = 2 * math.pi / count
		local index = math.floor((angle + step / 2) / step) % count + 1
		return { kind = "ping", id = pings[index].id }
	end
	local slot = if offset.Y < 0 then (if offset.X < 0 then 1 else 2) else (if offset.X < 0 then 4 else 3)
	return { kind = "sticker", slot = slot }
end

return VM
