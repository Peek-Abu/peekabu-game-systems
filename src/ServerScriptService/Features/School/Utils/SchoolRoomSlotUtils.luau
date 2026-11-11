--!strict
--[=[
	SchoolRoomSlotUtils: where the School's rooms may go on a hall network (SchoolNetworkUtils). Pure; every roll comes
	from the given Random.

	- `slots(network, rng)`: the room places, in a seeded order. Every lattice block that is not a landmark splits into
	  quarters (at its middle lines); a quarter may face each of its drawn halls (its row hall, its column hall), so it
	  offers one or two slots. Outside each edge hall the wall band offers slots BAND_DEPTH deep, the hall's run cut into
	  pieces about BAND_SLOT long. A slot's run lies within its hall's run (junction face to junction face) and a room
	  that stays in its slot clears every hall, every junction and every other place.
	- `front(slot, cursor, width)`: the front-left corner and facing (OfficeKitUtils.place) of a kit `width` wide whose
	  front starts at `cursor` along the slot's hall.

	@class SchoolRoomSlotUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeCorridorUtils = require(ServerScriptService.Features.Office.Utils.OfficeCorridorUtils)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)
local SchoolNetworkUtils = require(script.Parent.SchoolNetworkUtils)

type Edge = OfficeTypes.Edge
type Run = OfficeCorridorUtils.Run
type Network = SchoolNetworkUtils.Network

-- One place a room may go: facing `segment` on its `side` (+1 toward +x/+z, -1 toward -x/-z), its front within
-- from..to along the hall, at most `depth` deep.
export type Slot = { segment: Run, side: number, from: number, to: number, depth: number }

local SchoolRoomSlotUtils = {}

local function shuffle<T>(rng: Random, list: { T })
	for index = #list, 2, -1 do
		local other = rng:NextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
end

--[=[
	The front-left corner and facing of a kit `width` wide whose front starts at `cursor` along `slot`'s hall
	(OfficeLayoutGenerationUtils' slotFront).
]=]
function SchoolRoomSlotUtils.front(slot: Slot, cursor: number, width: number): (number, number, Edge)
	local room = slot.segment.room
	local x: number, z: number, facing: Edge
	if slot.segment.horizontal then
		if slot.side > 0 then
			x, z, facing = cursor, room.maxZ, "minZ"
		else
			x, z, facing = cursor + width, room.minZ, "maxZ"
		end
	elseif slot.side > 0 then
		x, z, facing = room.maxX, cursor + width, "minX"
	else
		x, z, facing = room.minX, cursor, "maxX"
	end
	return x, z, facing
end

-- The quarter (quarterX, quarterZ: 0 or 1) of block (col, row): a slot facing its row hall and one facing its column
-- hall, each where drawn, in a seeded order.
local function quarter(network: Network, rng: Random, col: number, row: number, quarterX: number, quarterZ: number)
	local mx = (network.lineX[col] + network.lineX[col + 1]) / 2
	local mz = (network.lineZ[row] + network.lineZ[row + 1]) / 2
	local options: { Slot } = {}
	local across = SchoolNetworkUtils.hall(
		network,
		{ col = col, row = row + quarterZ },
		{ col = col + 1, row = row + quarterZ }
	)
	if across ~= nil then
		local side = if quarterZ == 0 then 1 else -1
		table.insert(options, {
			segment = across,
			side = side,
			from = if quarterX == 0 then across.from else mx,
			to = if quarterX == 0 then mx else across.to,
			depth = if side > 0 then mz - across.room.maxZ else across.room.minZ - mz,
		})
	end
	local down = SchoolNetworkUtils.hall(
		network,
		{ col = col + quarterX, row = row },
		{ col = col + quarterX, row = row + 1 }
	)
	if down ~= nil then
		local side = if quarterX == 0 then 1 else -1
		table.insert(options, {
			segment = down,
			side = side,
			from = if quarterZ == 0 then down.from else mz,
			to = if quarterZ == 0 then mz else down.to,
			depth = if side > 0 then mx - down.room.maxX else down.room.minX - mx,
		})
	end
	shuffle(rng, options)
	return options
end

--[=[
	The room places on `network`, in a seeded order: each entry is one room's alternatives (a block quarter facing one
	of its drawn halls), or one stretch of the wall band.
]=]
function SchoolRoomSlotUtils.slots(network: Network, rng: Random): { { Slot } }
	local cols, rows = SchoolConstants.LATTICE_COLS, SchoolConstants.LATTICE_ROWS
	local landmarkAt: { [string]: boolean } = {}
	for _, landmark in network.landmarks do
		landmarkAt[`{landmark.col},{landmark.row}`] = true
	end
	local places: { { Slot } } = {}
	for row = 1, rows - 1 do
		for col = 1, cols - 1 do
			if not landmarkAt[`{col},{row}`] then
				for quarterZ = 0, 1 do
					for quarterX = 0, 1 do
						local options = quarter(network, rng, col, row, quarterX, quarterZ)
						if #options > 0 then
							table.insert(places, options)
						end
					end
				end
			end
		end
	end
	-- The wall band outside the edge halls, each run cut into slots about BAND_SLOT long.
	local function band(segment: Run?, side: number)
		if segment == nil then
			return
		end
		local length = segment.to - segment.from
		local count = math.max(1, math.floor(length / SchoolConstants.BAND_SLOT))
		local step = length / count
		for index = 1, count do
			local from = segment.from + (index - 1) * step
			table.insert(places, {
				{ segment = segment, side = side, from = from, to = from + step, depth = SchoolConstants.BAND_DEPTH },
			})
		end
	end
	for col = 1, cols - 1 do
		band(SchoolNetworkUtils.hall(network, { col = col, row = 1 }, { col = col + 1, row = 1 }), -1)
		band(SchoolNetworkUtils.hall(network, { col = col, row = rows }, { col = col + 1, row = rows }), 1)
	end
	for row = 1, rows - 1 do
		band(SchoolNetworkUtils.hall(network, { col = 1, row = row }, { col = 1, row = row + 1 }), -1)
		band(SchoolNetworkUtils.hall(network, { col = cols, row = row }, { col = cols, row = row + 1 }), 1)
	end
	shuffle(rng, places)
	return places
end

return SchoolRoomSlotUtils
