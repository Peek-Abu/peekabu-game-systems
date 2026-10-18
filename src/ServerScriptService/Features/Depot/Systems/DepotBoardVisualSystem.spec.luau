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
end
