local Visual = require(script.Parent.DepotBoardVisualSystem)

return function()
	local folder, board

	beforeEach(function()
		folder = Instance.new("Folder")
		board = Instance.new("Part")
		board.Name = "ContractBoard"
		board.Size = Vector3.new(12, 8, 1)
		board.Transparency = 1
		board.Anchored = true
		board.CFrame = CFrame.new(-966, 5.25, 12) * CFrame.Angles(0, math.rad(30), 0)
		board.Parent = folder
	end)

	afterEach(function()
		folder:Destroy()
	end)

	local function parts(model)
		local found = {}
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") then
				found[child.Name] = found[child.Name] or {}
				table.insert(found[child.Name], child)
			end
		end
		return found
	end

	-- A part's extent along the board's local axis (min, max).
	local function extent(part, axis)
		local half = part.Size / 2
		local low, high = math.huge, -math.huge
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = board.CFrame:PointToObjectSpace(
						(part.CFrame * CFrame.new(half.X * x, half.Y * y, half.Z * z)).Position
					)
					local value = if axis == "X" then corner.X elseif axis == "Y" then corner.Y else corner.Z
					low = math.min(low, value)
					high = math.max(high, value)
				end
			end
		end
		return low, high
	end

	describe("build", function()
		it("leaves the board part alone (the sign's adornee, collision and prompt anchor)", function()
			Visual.build(board, folder)
			expect(board.Size).to.equal(Vector3.new(12, 8, 1))
			expect(board.Transparency).to.equal(1)
		end)

		it("gives the board real thickness: a framed body behind the whole sign face", function()
			local model = Visual.build(board, folder)
			local found = parts(model)
			expect(#found.Rail).to.equal(4)
			expect(#found.Backing).to.equal(1)
			local front, back = -math.huge, math.huge
			local left, right, bottom, top = math.huge, -math.huge, math.huge, -math.huge
			for _, rail in found.Rail do
				local zLow, zHigh = extent(rail, "Z")
				local xLow, xHigh = extent(rail, "X")
				local yLow, yHigh = extent(rail, "Y")
				front, back = math.max(front, zHigh), math.min(back, zLow)
				left, right = math.min(left, xLow), math.max(right, xHigh)
				bottom, top = math.min(bottom, yLow), math.max(top, yHigh)
			end
			expect(front - back >= 0.4).to.equal(true)
			-- Inset from the outline, so the sign's rounded corners cover it from the front.
			local inset =
				require(game:GetService("ServerScriptService").Features.Depot.Data.DepotLayoutConstants).BOARD_BODY.INSET
			expect(left).to.be.near(-6 + inset, 1e-3)
			expect(right).to.be.near(6 - inset, 1e-3)
			expect(bottom).to.be.near(-4 + inset, 1e-3)
			expect(top).to.be.near(4 - inset, 1e-3)
		end)

		it("puts nothing in front of the sign's face (the GUI is on the front face only)", function()
			local model = Visual.build(board, folder)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					local _, high = extent(part, "Z")
					expect(high <= board.Size.Z / 2 - 0.01).to.equal(true)
				end
			end
		end)

		it("finishes the back: battens, a kickstand to the floor and the company sticker facing back", function()
			local model = Visual.build(board, folder)
			local found = parts(model)
			expect(#found.Batten >= 3).to.equal(true)
			expect(#found.Strut).to.equal(2)
			for _, strut in found.Strut do
				local low = extent(strut, "Y")
				expect(low >= -board.Size.Y / 2 - 1e-3 and low < -board.Size.Y / 2 + 0.35).to.equal(true)
				local zLow = extent(strut, "Z")
				expect(zLow < -1.5).to.equal(true)
			end
			expect(#found.FloorPad).to.equal(2)
			for _, pad in found.FloorPad do
				expect((extent(pad, "Y"))).to.be.near(-board.Size.Y / 2, 1e-3)
			end
			local sticker = found.Sticker[1]
			local gui = sticker:FindFirstChildWhichIsA("SurfaceGui")
			expect(gui).never.to.equal(nil)
			expect(gui.Face).to.equal(Enum.NormalId.Front)
			-- Front of the sticker part faces away from the sign (the sign faces the board's +Z).
			expect(sticker.CFrame.LookVector:Dot(board.CFrame.LookVector) > 0.99).to.equal(true)
			local text = {}
			for _, label in gui:GetDescendants() do
				if label:IsA("TextLabel") then
					table.insert(text, label.Text)
				end
			end
			expect(string.find(table.concat(text, " "), "MORROW", 1, true)).never.to.equal(nil)
		end)

		it("is anchored, untouchable, and only the kickstand collides", function()
			local model = Visual.build(board, folder)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Anchored).to.equal(true)
					expect(part.CanTouch).to.equal(false)
					expect(part.CanQuery).to.equal(false)
					expect(part.CanCollide).to.equal(part.Name == "Strut" or part.Name == "FloorPad")
				end
			end
		end)
	end)

	describe("backer", function()
		-- A small sign's face 3 studs up, facing +x (its readers), its frame's +Z toward them like a board's.
		local face = CFrame.new(10, 4, 20) * CFrame.Angles(0, math.rad(90), 0)
		local size = Vector2.new(4, 2)
		local function local_(part)
			local half = part.Size / 2
			local low, high =
				Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = face:PointToObjectSpace(
							(part.CFrame * CFrame.new(half.X * x, half.Y * y, half.Z * z)).Position
						)
						low = low:Min(corner)
						high = high:Max(corner)
					end
				end
			end
			return low, high
		end

		it("puts a solid back behind the whole face and nothing in front of it", function()
			local model = Visual.backer("SignBacker", face, size, 1, folder)
			local backing = model:FindFirstChild("Backing")
			expect(backing).never.to.equal(nil)
			local low, high = local_(backing)
			expect(low.X <= -size.X / 2).to.equal(true)
			expect(high.X >= size.X / 2).to.equal(true)
			expect(low.Y <= -size.Y / 2).to.equal(true)
			expect(high.Y >= size.Y / 2).to.equal(true)
			expect(high.Z - low.Z >= 0.2).to.equal(true)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					local _, partHigh = local_(part)
					expect(partHigh.Z <= -0.01).to.equal(true)
				end
			end
		end)

		it("stands a raised back on legs down to the floor", function()
			local model = Visual.backer("SignBacker", face, size, 1, folder)
			local legs, feet = 0, 0
			for _, part in model:GetChildren() do
				if part.Name == "Leg" then
					legs += 1
					local low = local_(part)
					expect(low.Y + face.Y).to.be.near(1, 0.13)
					expect(part.CanCollide).to.equal(true)
				elseif part.Name == "Foot" then
					feet += 1
					local low = local_(part)
					expect(low.Y + face.Y).to.be.near(1, 1e-3)
				end
			end
			expect(legs).to.equal(2)
			expect(feet).to.equal(2)
		end)

		it("needs no legs when the back already reaches the floor", function()
			local model = Visual.backer("SignBacker", face, size, face.Y - size.Y / 2, folder)
			expect(model:FindFirstChild("Leg")).to.equal(nil)
			local low = local_(model:FindFirstChild("Backing"))
			expect(low.Y + face.Y).to.be.near(face.Y - size.Y / 2, 1e-3)
		end)

		it("is anchored and untouchable", function()
			local model = Visual.backer("SignBacker", face, size, 1, folder)
			expect(model.Parent).to.equal(folder)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Anchored).to.equal(true)
					expect(part.CanTouch).to.equal(false)
					expect(part.CanQuery).to.equal(false)
				end
			end
		end)
	end)
end
