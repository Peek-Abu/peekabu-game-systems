local ServerScriptService = game:GetService("ServerScriptService")

local OfficeKitRegistry = require(script.Parent.OfficeKitRegistry)
local OfficeKitRules = require(ServerScriptService.Features.Office.Rules.OfficeKitRules)
local OfficeLayoutRules = require(ServerScriptService.Features.Office.Rules.OfficeLayoutRules)
local OfficeKitUtils = require(ServerScriptService.Features.Office.Utils.OfficeKitUtils)

local ROOM_TYPES = { "pods", "conference", "breakout", "storage", "server", "reception" }
local FACINGS = { "minZ", "minX", "maxZ", "maxX" }

-- One placed kit as a whole layout, its truck a point at the room's centre.
local function layoutOf(placement)
	local room = placement.room
	local cx, cz = (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
	return {
		startRoom = room.id,
		rooms = { room },
		doors = {},
		markers = placement.markers,
		truck = { minX = cx, minZ = cz, maxX = cx, maxZ = cz, clockX = cx, clockZ = cz },
		route = {},
		rest = "",
	}
end

return function()
	it("every kit passes OfficeKitRules", function()
		for _, kit in OfficeKitRegistry.KITS do
			local ok, errors = OfficeKitRules.check(kit)
			expect(`{kit.id}: {table.concat(errors, "; ")}`).to.equal(`{kit.id}: `)
			expect(ok).to.equal(true)
		end
	end)

	it("every kit places as a valid one-room layout in every facing and mirror", function()
		for _, kit in OfficeKitRegistry.KITS do
			for _, facing in FACINGS do
				for _, mirrored in { false, true } do
					local layout = layoutOf(OfficeKitUtils.place(kit, "r", 100, 100, facing, mirrored))
					local ok, errors = OfficeLayoutRules.validate(layout)
					local tag = `{kit.id} {facing} mirrored={mirrored}`
					expect(`{tag}: {table.concat(errors, "; ")}`).to.equal(`{tag}: `)
					expect(ok).to.equal(true)
					for _, marker in layout.markers do
						expect(`{tag} {marker.id} {OfficeLayoutRules.markerFits(layout, marker)}`).to.equal(
							`{tag} {marker.id} true`
						)
					end
				end
			end
		end
	end)

	it("covers the lean set", function()
		for _, roomType in ROOM_TYPES do
			expect(#OfficeKitRegistry.ofType(roomType) > 0).to.equal(true)
		end
		expect(#OfficeKitRegistry.ofType("reception")).to.equal(1)
		expect(#OfficeKitRegistry.ofType("server") >= 1).to.equal(true)
		expect(#OfficeKitRegistry.ofType("breakout") >= 1).to.equal(true)
	end)

	it("keeps rest markers to breakout kits", function()
		for _, kit in OfficeKitRegistry.KITS do
			local hasRest = false
			for _, marker in kit.markers do
				if marker.kind == "rest" then
					hasRest = true
				end
			end
			expect(hasRest).to.equal(kit.roomType == "breakout")
		end
	end)

	it("ids are unique and get finds them", function()
		local seen = {}
		for _, kit in OfficeKitRegistry.KITS do
			expect(seen[kit.id]).to.equal(nil)
			seen[kit.id] = true
			expect(OfficeKitRegistry.get(kit.id)).to.equal(kit)
		end
		expect(OfficeKitRegistry.get("nope")).to.equal(nil)
	end)
end
