--!strict
--[=[
	OfficeChairUtils: where a desk's office chair stands, split out of OfficeDecorSystem. `chairAt` tries the four sides of
	the desk (-Z first), keeping OFFICE_CHAIR_GAP clear of the desk edge, inside the desk's room, off other floor
	furniture and away from every doorway of that room, and returns the chair's floor CFrame (facing the desk), or nil
	when no side is clear.

	@class OfficeChairUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

local function chairAt(layout: OfficeTypes.Layout, desk: OfficeTypes.Marker, origin: CFrame): CFrame?
	local room = OfficeLayoutUtils.room(layout, desk.room)
	-- A chair stands OFFICE_CHAIR_GAP clear of the desk edge and is never pushed under it.
	local gap = OfficeConstants.OFFICE_CHAIR_GAP
	local chair = OfficeConstants.OFFICE_CHAIR_SIZE
	local alongZ = OfficeConstants.DESK_SIZE.Z / 2 + chair.Z / 2 + gap
	local alongX = OfficeConstants.DESK_SIZE.X / 2 + chair.Z / 2 + gap
	local candidates = {
		-- officeChair art seats toward its CFrame LookVector: at turn 0 the backrest sits on the
		-- +Z side (live Studio screenshot 2026-10-13), so each side needs the half-turn more than
		-- the naive orientation to face the sitter toward the desk.
		{ x = 0, z = -alongZ, turn = math.pi },
		{ x = 0, z = alongZ, turn = 0 },
		{ x = -alongX, z = 0, turn = -math.pi / 2 },
		{ x = alongX, z = 0, turn = math.pi / 2 },
	}
	for _, candidate in candidates do
		local offset = CFrame.Angles(0, desk.rotation or 0, 0)
			:VectorToWorldSpace(Vector3.new(candidate.x, 0, candidate.z))
		local x, z = desk.x + offset.X, desk.z + offset.Z
		local half = math.max(chair.X, chair.Z) / 2
		local clear = room == nil
			or (
				x - half > room.minX + 0.2
				and x + half < room.maxX - 0.2
				and z - half > room.minZ + 0.2
				and z + half < room.maxZ - 0.2
			)
		if clear then
			for _, other in layout.markers do
				-- Floor furniture (a standing board too) and floor props block a chair; wall hangings, desk-top props,
				-- rugs and plants do not.
				local size: Vector3? = nil
				if other.kind ~= "plant" and (other.kind ~= "prop" or OfficeLayoutUtils.isFloorProp(other)) then
					size = OfficeLayoutUtils.markerSize(other)
				end
				if other.id ~= desk.id and size ~= nil then
					if
						math.abs(x - other.x)
							< half + (if math.abs(math.sin(other.rotation or 0)) > 0.5 then size.Z else size.X) / 2
						and math.abs(z - other.z)
							< half + (if math.abs(math.sin(other.rotation or 0)) > 0.5 then size.X else size.Z) / 2
					then
						clear = false
						break
					end
				end
			end
		end
		if clear then
			for _, door in layout.doors do
				if door.a == desk.room or door.b == desk.room then
					-- Keep a walkable approach around every doorway, including a four-exit room.
					if
						math.abs(x - door.x) < door.width / 2 + half
						and math.abs(z - door.z) < door.width / 2 + half
					then
						clear = false
						break
					end
				end
			end
		end
		if clear then
			return origin * CFrame.new(x, 0, z) * CFrame.Angles(0, candidate.turn + (desk.rotation or 0), 0)
		end
	end
	-- A future tightly packed layout may have no clear candidate; omit art rather than clip through a wall.
	return nil
end

local OfficeChairUtils = {}

OfficeChairUtils.chairAt = chairAt

return OfficeChairUtils
