local RoomUtils = require(script.Parent.OfficeLayoutRoomUtils)
return function()
	describe("room archetype marker packing", function()
		it("uses explicit inward yaws, stocked surfaces and clear central door approaches", function()
			for seed = 1, 40 do
				-- Give Studio a scheduler slice without reducing seed coverage.
				if seed % 5 == 0 then
					task.wait()
				end
				local room = { id = "work", name = "Work", minX = 0, minZ = 0, maxX = 30, maxZ = 28, zone = "meeting" }
				local markers = RoomUtils.markers(room, Random.new(seed))
				local counts = {}
				for _, marker in markers do
					counts[marker.kind] = (counts[marker.kind] or 0) + 1
					expect(type(marker.rotation)).to.equal("number")
					expect(marker.x > 0 and marker.x < 30 and marker.z > 0 and marker.z < 28).to.equal(true)
					if marker.kind ~= "patrol" and marker.kind ~= "rest" then
						expect(math.abs(marker.x - 15) > 5 and math.abs(marker.z - 14) > 5).to.equal(true)
					end
				end
				expect(counts.pile >= 2).to.equal(true)
				expect(counts.item >= 4).to.equal(true)
				expect(counts.counter >= 1 and counts.desk >= 1).to.equal(true)
			end
		end)
		it(
			"stands at most one supply cabinet per room, against a wall, its door to the room; most rooms get one",
			function()
				local Constants = require(game:GetService("ServerScriptService").Features.Office.Data.OfficeConstants)
				local wall = Constants.WALL_THICKNESS / 2
				local rooms, withCloset = 0, 0
				for seed = 1, 40 do
					if seed % 5 == 0 then
						task.wait()
					end
					local maxX, maxZ = 30 + seed % 11, 28 + seed * 3 % 11
					local room =
						{ id = "work", name = "Work", minX = 0, minZ = 0, maxX = maxX, maxZ = maxZ, zone = "office" }
					local closets = {}
					for _, marker in RoomUtils.markers(room, Random.new(seed)) do
						if marker.kind == "closet" then
							table.insert(closets, marker)
						end
					end
					rooms += 1
					expect(#closets <= 1).to.equal(true)
					local closet = closets[1]
					if closet ~= nil then
						withCloset += 1
						-- Its back to the nearest wall, its front (local -Z) toward the room's centre.
						local frame = CFrame.new(closet.x, 0, closet.z) * CFrame.Angles(0, closet.rotation, 0)
						local back = frame:PointToWorldSpace(Vector3.new(0, 0, Constants.CLOSET_SIZE.Z / 2))
						local toWall = math.min(back.X, maxX - back.X, back.Z, maxZ - back.Z)
						expect(math.abs(toWall - wall) < 0.05).to.equal(true)
						local toCentre = Vector3.new(maxX / 2 - closet.x, 0, maxZ / 2 - closet.z)
						expect(frame.LookVector:Dot(toCentre) > 0).to.equal(true)
					end
				end
				expect(withCloset >= rooms / 2).to.equal(true)
			end
		)
		it("varies functional furniture inventories and keeps all occupied footprints separated", function()
			local Constants = require(game:GetService("ServerScriptService").Features.Office.Data.OfficeConstants)
			local sizes = {
				desk = Constants.DESK_SIZE,
				locker = Constants.LOCKER_SIZE,
				shelf = Constants.SHELF_SIZE,
				counter = Constants.COUNTER_SIZE,
				table = Constants.TABLE_SIZE,
				cabinet = Constants.CABINET_SIZE,
				closet = Constants.CLOSET_SIZE,
				plant = Constants.PLANT_SIZE,
				pile = Vector3.new(4, 1, 4),
				item = Vector3.new(3.6, 1, 3.6),
			}
			local function half(marker)
				local size = sizes[marker.kind]
				if not size then
					return nil
				end
				local cosine, sine = math.abs(math.cos(marker.rotation)), math.abs(math.sin(marker.rotation))
				return Vector2.new((size.X * cosine + size.Z * sine) / 2, (size.X * sine + size.Z * cosine) / 2)
			end
			local inventories = {}
			for _, zone in
				{ "meeting", "kitchenette", "training", "storage", "office", "records", "laboratory", "breakRoom" }
			do
				for seed = 1, 30 do
					-- Give Studio a scheduler slice without reducing seed coverage.
					if seed % 5 == 0 then
						task.wait()
					end
					local markers = RoomUtils.markers({
						id = "work",
						name = "Work",
						zone = zone,
						minX = 0,
						minZ = 0,
						maxX = 30 + seed % 11,
						maxZ = 28 + seed * 3 % 11,
					}, Random.new(seed))
					local names = {}
					for index, marker in markers do
						table.insert(names, marker.kind)
						local h = half(marker)
						if h then
							for otherIndex = index + 1, #markers do
								local other = markers[otherIndex]
								local oh = half(other)
								if oh then
									expect(
										math.abs(marker.x - other.x) >= h.X + oh.X + 0.25
											or math.abs(marker.z - other.z) >= h.Y + oh.Y + 0.25
									).to.equal(true)
								end
							end
						end
					end
					inventories[table.concat(names, ":")] = true
				end
			end
			local distinct = 0
			for _ in inventories do
				distinct += 1
			end
			expect(distinct >= 4).to.equal(true)
		end)
	end)
end
