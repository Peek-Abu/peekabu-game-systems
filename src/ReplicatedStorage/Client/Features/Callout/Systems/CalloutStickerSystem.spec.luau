local CalloutStickerSystem = require(script.Parent.CalloutStickerSystem)

return function()
	local folder

	beforeEach(function()
		folder = Instance.new("Folder")
	end)

	afterEach(function()
		folder:Destroy()
	end)

	it("pins the sticker at its spot on a still, invisible, untouchable anchor", function()
		local gui = CalloutStickerSystem.show(folder, 7, Vector3.new(1, 2, 3), "rbxassetid://1", true)
		local anchor = gui.Parent
		expect(anchor.Parent).to.equal(folder)
		expect(anchor:IsA("BasePart")).to.equal(true)
		expect(anchor.Anchored).to.equal(true)
		expect(anchor.CanCollide or anchor.CanQuery or anchor.CanTouch).to.equal(false)
		expect(anchor.Transparency).to.equal(1)
		expect(anchor.Position).to.equal(Vector3.new(1, 2, 3))
		expect(gui.Adornee).to.equal(anchor)
		expect(gui.Picture.Image).to.equal("rbxassetid://1")
	end)

	it("starts a thrown sticker at the hand, not at its spot", function()
		local gui =
			CalloutStickerSystem.show(folder, 7, Vector3.new(0, 10, 0), "rbxassetid://1", false, Vector3.new(1, 2, 3))
		expect(gui.Parent.Position).to.equal(Vector3.new(1, 2, 3))
		expect(gui.Parent.Position).never.to.equal(Vector3.new(0, 10, 0))
	end)

	it("shows it at its spot at once with reduced motion, wherever the hand is", function()
		local gui =
			CalloutStickerSystem.show(folder, 7, Vector3.new(0, 10, 0), "rbxassetid://1", true, Vector3.new(1, 2, 3))
		expect(gui.Parent.Position).to.equal(Vector3.new(0, 10, 0))
	end)

	it("replaces a sender's sticker still showing, and keeps other senders' stickers", function()
		local first = CalloutStickerSystem.show(folder, 7, Vector3.zero, "rbxassetid://1", true)
		local other = CalloutStickerSystem.show(folder, 8, Vector3.zero, "rbxassetid://3", true)
		local second = CalloutStickerSystem.show(folder, 7, Vector3.new(0, 5, 0), "rbxassetid://2", true)
		expect(first.Parent).never.to.be.ok()
		expect(#folder:GetChildren()).to.equal(2)
		expect(other.Parent.Parent).to.equal(folder)
		expect(second.Picture.Image).to.equal("rbxassetid://2")
		expect(second.Parent.Position).to.equal(Vector3.new(0, 5, 0))
	end)
end
